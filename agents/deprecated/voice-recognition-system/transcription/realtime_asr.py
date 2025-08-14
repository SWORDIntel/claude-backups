"""
Real-time Automatic Speech Recognition System
Optimized for accuracy over latency using GNA acceleration
"""

import numpy as np
import sounddevice as sd
import queue
import threading
import time
from typing import Optional, Dict, Any, List, Callable, Tuple
from dataclasses import dataclass
from pathlib import Path
import wave
import json
import logging
from collections import deque
import librosa
import webrtcvad

logger = logging.getLogger(__name__)


@dataclass
class TranscriptionResult:
    """Result from transcription engine"""
    text: str
    confidence: float
    timestamp_start: float
    timestamp_end: float
    is_final: bool
    speaker_id: Optional[str] = None
    words: Optional[List[Dict]] = None  # Word-level timestamps
    alternatives: Optional[List[Dict]] = None  # Alternative transcriptions


class AudioBuffer:
    """
    Circular buffer for audio with silence detection
    """
    
    def __init__(self, max_duration: float = 30.0, sample_rate: int = 16000):
        self.sample_rate = sample_rate
        self.max_samples = int(max_duration * sample_rate)
        self.buffer = deque(maxlen=self.max_samples)
        self.lock = threading.Lock()
        
        # VAD for silence detection
        self.vad = webrtcvad.Vad(2)  # Aggressiveness level 0-3
        self.frame_duration = 30  # ms
        self.frame_samples = int(sample_rate * self.frame_duration / 1000)
        
    def add(self, audio: np.ndarray):
        """Add audio to buffer"""
        with self.lock:
            self.buffer.extend(audio)
    
    def get_speech_segments(self) -> List[np.ndarray]:
        """Extract speech segments from buffer"""
        with self.lock:
            audio = np.array(self.buffer)
        
        if len(audio) < self.frame_samples:
            return []
        
        segments = []
        current_segment = []
        is_speech = False
        
        # Process in frames
        for i in range(0, len(audio) - self.frame_samples, self.frame_samples):
            frame = audio[i:i + self.frame_samples]
            
            # Convert to int16 for VAD
            frame_int16 = (frame * 32767).astype(np.int16)
            
            try:
                frame_is_speech = self.vad.is_speech(frame_int16.tobytes(), self.sample_rate)
            except:
                frame_is_speech = True  # Default to speech if VAD fails
            
            if frame_is_speech:
                if not is_speech:
                    # Start of speech
                    is_speech = True
                current_segment.extend(frame)
            else:
                if is_speech and len(current_segment) > self.frame_samples * 10:
                    # End of speech segment (minimum 300ms)
                    segments.append(np.array(current_segment))
                    current_segment = []
                is_speech = False
        
        # Add remaining segment
        if len(current_segment) > self.frame_samples * 10:
            segments.append(np.array(current_segment))
        
        return segments
    
    def clear(self):
        """Clear buffer"""
        with self.lock:
            self.buffer.clear()


class RealtimeASR:
    """
    Real-time speech recognition with self-improvement
    Prioritizes accuracy over latency
    """
    
    def __init__(self, 
                 accelerator_manager=None,
                 biometric_system=None,
                 model_path: Optional[str] = None,
                 language: str = "en",
                 device_index: Optional[int] = None):
        
        self.accelerator_manager = accelerator_manager
        self.biometric_system = biometric_system
        self.language = language
        self.device_index = device_index
        
        # Audio parameters
        self.sample_rate = 16000
        self.channels = 1
        self.chunk_duration = 0.5  # seconds
        self.chunk_samples = int(self.chunk_duration * self.sample_rate)
        
        # Recognition parameters
        self.energy_threshold = 0.01
        self.pause_threshold = 0.8  # seconds of silence to finalize
        self.phrase_threshold = 3.0  # seconds before forcing finalization
        
        # Buffers and queues
        self.audio_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.audio_buffer = AudioBuffer(max_duration=30.0, sample_rate=self.sample_rate)
        
        # Recognition state
        self.is_recording = False
        self.is_processing = False
        self.current_speaker = None
        self.session_transcript = []
        
        # Callbacks
        self.on_partial_result: Optional[Callable] = None
        self.on_final_result: Optional[Callable] = None
        self.on_speaker_change: Optional[Callable] = None
        
        # Performance tracking
        self.metrics = {
            'total_audio_processed': 0.0,
            'total_words': 0,
            'avg_confidence': 0.0,
            'speaker_changes': 0
        }
        
        # Threads
        self.recording_thread = None
        self.processing_thread = None
        
        self._init_models(model_path)
    
    def _init_models(self, model_path: Optional[str]):
        """Initialize ASR models on GNA"""
        
        if self.accelerator_manager and model_path:
            try:
                # Load acoustic model on GNA
                self.accelerator_manager.load_model(
                    model_path=model_path,
                    model_name="asr_acoustic",
                    accelerator="GNA",
                    model_type="acoustic"
                )
                
                # Load language model on NPU for better accuracy
                lm_path = Path(model_path).parent / "language_model.xml"
                if lm_path.exists():
                    self.accelerator_manager.load_model(
                        model_path=str(lm_path),
                        model_name="asr_language",
                        accelerator="NPU",
                        model_type="language"
                    )
                
                logger.info("ASR models loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load ASR models: {e}")
                # Fall back to CPU/library implementation
    
    def audio_callback(self, indata, frames, time_info, status):
        """Callback for audio stream"""
        
        if status:
            logger.warning(f"Audio callback status: {status}")
        
        # Convert to mono if needed
        audio = indata[:, 0] if len(indata.shape) > 1 else indata
        
        # Add to queue for processing
        self.audio_queue.put(audio.copy())
    
    def start(self):
        """Start real-time recognition"""
        
        if self.is_recording:
            logger.warning("Already recording")
            return
        
        self.is_recording = True
        self.is_processing = True
        
        # Start audio stream
        self.stream = sd.InputStream(
            device=self.device_index,
            channels=self.channels,
            samplerate=self.sample_rate,
            callback=self.audio_callback,
            blocksize=self.chunk_samples
        )
        self.stream.start()
        
        # Start processing thread
        self.processing_thread = threading.Thread(target=self._process_audio_stream)
        self.processing_thread.daemon = True
        self.processing_thread.start()
        
        logger.info("Started real-time ASR")
    
    def stop(self):
        """Stop real-time recognition"""
        
        self.is_recording = False
        self.is_processing = False
        
        if hasattr(self, 'stream'):
            self.stream.stop()
            self.stream.close()
        
        # Process remaining audio
        self._process_remaining_audio()
        
        logger.info("Stopped real-time ASR")
    
    def _process_audio_stream(self):
        """Main processing loop"""
        
        last_speech_time = time.time()
        accumulated_audio = []
        
        while self.is_processing:
            try:
                # Get audio from queue
                audio = self.audio_queue.get(timeout=0.1)
                
                # Add to buffer
                self.audio_buffer.add(audio)
                accumulated_audio.append(audio)
                
                # Check for speech
                energy = np.sqrt(np.mean(audio**2))
                
                if energy > self.energy_threshold:
                    last_speech_time = time.time()
                
                # Check if we should process
                silence_duration = time.time() - last_speech_time
                accumulated_duration = len(np.concatenate(accumulated_audio)) / self.sample_rate
                
                should_process = (
                    (silence_duration > self.pause_threshold and accumulated_duration > 0.5) or
                    accumulated_duration > self.phrase_threshold
                )
                
                if should_process and len(accumulated_audio) > 0:
                    # Process accumulated audio
                    full_audio = np.concatenate(accumulated_audio)
                    self._process_audio_chunk(full_audio, is_final=True)
                    
                    # Reset
                    accumulated_audio = []
                    last_speech_time = time.time()
                
                elif accumulated_duration > 0.5:
                    # Send partial result
                    partial_audio = np.concatenate(accumulated_audio)
                    self._process_audio_chunk(partial_audio, is_final=False)
                
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"Processing error: {e}")
    
    def _process_audio_chunk(self, audio: np.ndarray, is_final: bool):
        """Process audio chunk through recognition pipeline"""
        
        # Speaker identification (if biometric system available)
        speaker_id = None
        if self.biometric_system and is_final:
            speaker_id, confidence = self.biometric_system.identify_speaker(audio)
            
            if speaker_id and speaker_id != self.current_speaker:
                self.current_speaker = speaker_id
                self.metrics['speaker_changes'] += 1
                
                if self.on_speaker_change:
                    self.on_speaker_change(speaker_id)
        
        # Preprocess audio
        audio_processed = self._preprocess_audio(audio)
        
        # Run through ASR model
        if self.accelerator_manager and "asr_acoustic" in self.accelerator_manager.gna_models:
            # Use GNA for acoustic model
            features = self._extract_features(audio_processed)
            acoustic_output = self.accelerator_manager.infer("asr_acoustic", features)
            
            # Use NPU for language model if available
            if "asr_language" in self.accelerator_manager.npu_models:
                text_output = self.accelerator_manager.infer("asr_language", acoustic_output)
                transcription = self._decode_output(text_output)
            else:
                transcription = self._decode_output(acoustic_output)
        else:
            # Fallback to simple energy-based placeholder
            transcription = self._fallback_transcription(audio_processed)
        
        # Create result
        result = TranscriptionResult(
            text=transcription['text'],
            confidence=transcription['confidence'],
            timestamp_start=time.time() - len(audio) / self.sample_rate,
            timestamp_end=time.time(),
            is_final=is_final,
            speaker_id=speaker_id,
            words=transcription.get('words'),
            alternatives=transcription.get('alternatives')
        )
        
        # Update metrics
        self.metrics['total_audio_processed'] += len(audio) / self.sample_rate
        if is_final:
            word_count = len(result.text.split())
            self.metrics['total_words'] += word_count
            self.metrics['avg_confidence'] = (
                self.metrics['avg_confidence'] * 0.9 + result.confidence * 0.1
            )
        
        # Send to appropriate callback
        if is_final:
            self.session_transcript.append(result)
            if self.on_final_result:
                self.on_final_result(result)
        else:
            if self.on_partial_result:
                self.on_partial_result(result)
        
        # Adapt biometric profile if speaker identified
        if speaker_id and is_final and self.biometric_system:
            self.biometric_system.adapt_profile(speaker_id, audio, result.text)
    
    def _preprocess_audio(self, audio: np.ndarray) -> np.ndarray:
        """Preprocess audio for recognition"""
        
        # Normalize
        audio = audio / (np.max(np.abs(audio)) + 1e-10)
        
        # Apply pre-emphasis
        pre_emphasis = 0.97
        audio = np.append(audio[0], audio[1:] - pre_emphasis * audio[:-1])
        
        # Remove DC offset
        audio = audio - np.mean(audio)
        
        return audio
    
    def _extract_features(self, audio: np.ndarray) -> np.ndarray:
        """Extract features for acoustic model"""
        
        # Extract log mel spectrogram
        mel_spec = librosa.feature.melspectrogram(
            y=audio,
            sr=self.sample_rate,
            n_mels=80,
            n_fft=400,
            hop_length=160,
            window='hann'
        )
        
        log_mel_spec = np.log(mel_spec + 1e-10)
        
        # Add delta and delta-delta
        delta = librosa.feature.delta(log_mel_spec)
        delta_delta = librosa.feature.delta(log_mel_spec, order=2)
        
        # Stack features
        features = np.stack([log_mel_spec, delta, delta_delta], axis=0)
        
        return features
    
    def _decode_output(self, model_output: np.ndarray) -> Dict[str, Any]:
        """Decode model output to text"""
        
        # Placeholder decoder
        # In production, use CTC or attention decoder
        
        result = {
            'text': '',
            'confidence': 0.0,
            'words': [],
            'alternatives': []
        }
        
        # Simplified decoding
        # Real implementation would use beam search with language model
        
        return result
    
    def _fallback_transcription(self, audio: np.ndarray) -> Dict[str, Any]:
        """Fallback transcription when models not available"""
        
        # Very simple energy-based detection
        energy = np.sqrt(np.mean(audio**2))
        
        if energy > self.energy_threshold:
            # Placeholder text based on audio length
            duration = len(audio) / self.sample_rate
            word_count = max(1, int(duration * 2))  # Rough estimate
            text = " ".join(["[speech]"] * word_count)
            confidence = min(0.5, energy * 10)
        else:
            text = ""
            confidence = 0.0
        
        return {
            'text': text,
            'confidence': confidence,
            'words': [],
            'alternatives': []
        }
    
    def _process_remaining_audio(self):
        """Process any remaining audio in buffer"""
        
        segments = self.audio_buffer.get_speech_segments()
        
        for segment in segments:
            if len(segment) > self.sample_rate * 0.5:  # Min 0.5 seconds
                self._process_audio_chunk(segment, is_final=True)
    
    def transcribe_file(self, file_path: str) -> List[TranscriptionResult]:
        """Transcribe audio file with maximum accuracy"""
        
        # Load audio file
        audio, sr = librosa.load(file_path, sr=self.sample_rate, mono=True)
        
        # Process in chunks for better accuracy
        chunk_size = self.sample_rate * 10  # 10 second chunks
        results = []
        
        for i in range(0, len(audio), chunk_size):
            chunk = audio[i:i + chunk_size]
            
            # Process chunk
            self._process_audio_chunk(chunk, is_final=True)
            
            # Get result from queue if available
            try:
                result = self.result_queue.get_nowait()
                results.append(result)
            except queue.Empty:
                pass
        
        return results
    
    def save_transcript(self, file_path: str, format: str = "json"):
        """Save session transcript"""
        
        if format == "json":
            data = []
            for result in self.session_transcript:
                data.append({
                    'text': result.text,
                    'confidence': result.confidence,
                    'start': result.timestamp_start,
                    'end': result.timestamp_end,
                    'speaker': result.speaker_id
                })
            
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=2)
        
        elif format == "txt":
            with open(file_path, 'w') as f:
                for result in self.session_transcript:
                    speaker = f"[{result.speaker_id}] " if result.speaker_id else ""
                    f.write(f"{speaker}{result.text}\n")
        
        elif format == "srt":
            with open(file_path, 'w') as f:
                for i, result in enumerate(self.session_transcript, 1):
                    start = self._format_timestamp(result.timestamp_start)
                    end = self._format_timestamp(result.timestamp_end)
                    f.write(f"{i}\n{start} --> {end}\n{result.text}\n\n")
        
        logger.info(f"Saved transcript to {file_path}")
    
    def _format_timestamp(self, seconds: float) -> str:
        """Format timestamp for SRT"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = seconds % 60
        return f"{hours:02d}:{minutes:02d}:{secs:06.3f}".replace('.', ',')
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get performance metrics"""
        
        metrics = self.metrics.copy()
        
        if metrics['total_words'] > 0:
            metrics['avg_word_duration'] = metrics['total_audio_processed'] / metrics['total_words']
        
        return metrics
    
    def calibrate_noise(self, duration: float = 2.0):
        """Calibrate for ambient noise"""
        
        logger.info(f"Calibrating for ambient noise ({duration} seconds)...")
        
        samples = []
        start_time = time.time()
        
        with sd.InputStream(device=self.device_index, 
                          channels=self.channels,
                          samplerate=self.sample_rate) as stream:
            while time.time() - start_time < duration:
                audio, _ = stream.read(self.chunk_samples)
                samples.append(audio)
        
        # Calculate noise level
        noise_audio = np.concatenate(samples)
        noise_level = np.sqrt(np.mean(noise_audio**2))
        
        # Set threshold above noise
        self.energy_threshold = noise_level * 3
        
        logger.info(f"Noise calibration complete. Threshold: {self.energy_threshold:.4f}")