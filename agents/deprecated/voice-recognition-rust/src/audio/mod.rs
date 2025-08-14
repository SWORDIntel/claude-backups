use anyhow::Result;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use crossbeam::channel::{bounded, Receiver, Sender};
use dasp::{signal, Signal};
use parking_lot::RwLock;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tracing::{debug, info, warn};

pub struct AudioConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub buffer_size: usize,
}

impl Default for AudioConfig {
    fn default() -> Self {
        Self {
            sample_rate: 16000,
            channels: 1,
            buffer_size: 480, // 30ms at 16kHz
        }
    }
}

pub struct AudioBuffer {
    data: Vec<f32>,
    write_pos: usize,
    capacity: usize,
}

impl AudioBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            data: vec![0.0; capacity],
            write_pos: 0,
            capacity,
        }
    }
    
    pub fn write(&mut self, samples: &[f32]) {
        for &sample in samples {
            self.data[self.write_pos] = sample;
            self.write_pos = (self.write_pos + 1) % self.capacity;
        }
    }
    
    pub fn read(&self, count: usize) -> Vec<f32> {
        let start = (self.write_pos + self.capacity - count) % self.capacity;
        let mut result = Vec::with_capacity(count);
        
        for i in 0..count {
            result.push(self.data[(start + i) % self.capacity]);
        }
        
        result
    }
}

pub struct AudioPipeline {
    config: AudioConfig,
    stream: Option<cpal::Stream>,
    buffer: Arc<RwLock<AudioBuffer>>,
    sample_sender: Sender<Vec<f32>>,
    sample_receiver: Receiver<Vec<f32>>,
    is_running: Arc<AtomicBool>,
}

impl AudioPipeline {
    pub fn new() -> Result<Self> {
        Self::with_config(AudioConfig::default())
    }
    
    pub fn with_config(config: AudioConfig) -> Result<Self> {
        let (tx, rx) = bounded(100);
        
        Ok(Self {
            config,
            stream: None,
            buffer: Arc::new(RwLock::new(AudioBuffer::new(16000 * 30))), // 30 seconds
            sample_sender: tx,
            sample_receiver: rx,
            is_running: Arc::new(AtomicBool::new(false)),
        })
    }
    
    pub fn start(&mut self) -> Result<()> {
        if self.is_running.load(Ordering::Relaxed) {
            return Ok(());
        }
        
        let host = cpal::default_host();
        let device = host.default_input_device()
            .ok_or_else(|| anyhow::anyhow!("No input device available"))?;
        
        info!("Using audio device: {}", device.name()?);
        
        let supported_config = device.default_input_config()?;
        let sample_rate = supported_config.sample_rate().0;
        
        // Setup resampling if needed
        let needs_resampling = sample_rate != self.config.sample_rate;
        
        let buffer = self.buffer.clone();
        let sender = self.sample_sender.clone();
        let target_rate = self.config.sample_rate;
        
        let stream = match supported_config.sample_format() {
            cpal::SampleFormat::F32 => self.build_stream::<f32>(
                &device,
                &supported_config.into(),
                buffer,
                sender,
                needs_resampling,
                sample_rate,
                target_rate,
            )?,
            cpal::SampleFormat::I16 => self.build_stream::<i16>(
                &device,
                &supported_config.into(),
                buffer,
                sender,
                needs_resampling,
                sample_rate,
                target_rate,
            )?,
            cpal::SampleFormat::U16 => self.build_stream::<u16>(
                &device,
                &supported_config.into(),
                buffer,
                sender,
                needs_resampling,
                sample_rate,
                target_rate,
            )?,
            _ => return Err(anyhow::anyhow!("Unsupported sample format")),
        };
        
        stream.play()?;
        self.stream = Some(stream);
        self.is_running.store(true, Ordering::Relaxed);
        
        info!("Audio pipeline started ({}Hz -> {}Hz)", sample_rate, target_rate);
        Ok(())
    }
    
    fn build_stream<T>(
        &self,
        device: &cpal::Device,
        config: &cpal::StreamConfig,
        buffer: Arc<RwLock<AudioBuffer>>,
        sender: Sender<Vec<f32>>,
        needs_resampling: bool,
        source_rate: u32,
        target_rate: u32,
    ) -> Result<cpal::Stream>
    where
        T: cpal::Sample + cpal::SizedSample,
    {
        let channels = config.channels as usize;
        
        let stream = device.build_input_stream(
            config,
            move |data: &[T], _: &cpal::InputCallbackInfo| {
                // Convert to f32 mono
                let mut mono_samples = Vec::with_capacity(data.len() / channels);
                
                for frame in data.chunks(channels) {
                    let mut sum = 0.0f32;
                    for &sample in frame {
                        sum += sample.to_float_sample();
                    }
                    mono_samples.push(sum / channels as f32);
                }
                
                // Apply pre-emphasis filter for better speech recognition
                let pre_emphasis = 0.97;
                for i in (1..mono_samples.len()).rev() {
                    mono_samples[i] -= pre_emphasis * mono_samples[i - 1];
                }
                
                // Resample if needed
                let processed = if needs_resampling {
                    resample(&mono_samples, source_rate, target_rate)
                } else {
                    mono_samples
                };
                
                // Write to buffer
                buffer.write().write(&processed);
                
                // Send for processing
                let _ = sender.try_send(processed);
            },
            |err| warn!("Audio stream error: {}", err),
            None,
        )?;
        
        Ok(stream)
    }
    
    pub fn stop(&mut self) {
        self.is_running.store(false, Ordering::Relaxed);
        if let Some(stream) = self.stream.take() {
            drop(stream);
        }
        info!("Audio pipeline stopped");
    }
    
    pub fn get_samples(&self) -> Result<Vec<f32>> {
        self.sample_receiver
            .try_recv()
            .map_err(|e| anyhow::anyhow!("No samples available: {}", e))
    }
    
    pub fn read_buffer(&self, duration_ms: u32) -> Vec<f32> {
        let samples = (self.config.sample_rate * duration_ms / 1000) as usize;
        self.buffer.read().read(samples)
    }
    
    pub fn calculate_energy(&self, samples: &[f32]) -> f32 {
        let sum: f32 = samples.iter().map(|s| s * s).sum();
        (sum / samples.len() as f32).sqrt()
    }
    
    pub fn detect_voice_activity(&self, samples: &[f32], threshold: f32) -> bool {
        // Simple energy-based VAD
        let energy = self.calculate_energy(samples);
        
        // Zero-crossing rate for distinguishing speech from noise
        let mut zcr = 0;
        for i in 1..samples.len() {
            if samples[i - 1] * samples[i] < 0.0 {
                zcr += 1;
            }
        }
        let zcr_rate = zcr as f32 / samples.len() as f32;
        
        // Speech typically has moderate ZCR and high energy
        energy > threshold && zcr_rate > 0.1 && zcr_rate < 0.5
    }
}

fn resample(input: &[f32], source_rate: u32, target_rate: u32) -> Vec<f32> {
    if source_rate == target_rate {
        return input.to_vec();
    }
    
    let ratio = target_rate as f64 / source_rate as f64;
    let output_len = (input.len() as f64 * ratio) as usize;
    let mut output = Vec::with_capacity(output_len);
    
    // Simple linear interpolation resampling
    // For production, use rubato crate for high-quality resampling
    for i in 0..output_len {
        let source_idx = i as f64 / ratio;
        let idx = source_idx as usize;
        let frac = source_idx - idx as f64;
        
        if idx + 1 < input.len() {
            let interpolated = input[idx] * (1.0 - frac as f32) + input[idx + 1] * frac as f32;
            output.push(interpolated);
        } else if idx < input.len() {
            output.push(input[idx]);
        }
    }
    
    output
}

impl Drop for AudioPipeline {
    fn drop(&mut self) {
        self.stop();
    }
}