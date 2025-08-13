use anyhow::Result;
use bincode;
use memmap2::{Mmap, MmapMut, MmapOptions};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tracing::{debug, info};

use crate::accelerator::DualAcceleratorManager;

const EMBEDDING_DIM: usize = 512;
const MFCC_DIM: usize = 20;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceProfile {
    pub user_id: String,
    pub name: String,
    pub embedding: [f32; EMBEDDING_DIM],
    pub mfcc_mean: [f32; MFCC_DIM],
    pub mfcc_std: [f32; MFCC_DIM],
    pub pitch_range: (f32, f32),
    pub num_samples: usize,
    pub total_duration_ms: u64,
}

impl VoiceProfile {
    pub fn distance(&self, embedding: &[f32]) -> f32 {
        // SIMD-optimized cosine distance
        let mut dot = 0.0f32;
        let mut norm_a = 0.0f32;
        let mut norm_b = 0.0f32;
        
        // Use chunks for potential auto-vectorization
        for (a, b) in self.embedding.chunks(8).zip(embedding.chunks(8)) {
            for i in 0..a.len() {
                dot += a[i] * b[i];
                norm_a += a[i] * a[i];
                norm_b += b[i] * b[i];
            }
        }
        
        1.0 - (dot / (norm_a.sqrt() * norm_b.sqrt()))
    }
}

pub struct VoiceBiometricSystem {
    profiles: Arc<RwLock<HashMap<String, VoiceProfile>>>,
    profile_dir: PathBuf,
    accelerator: Arc<DualAcceleratorManager>,
    identification_threshold: f32,
    verification_threshold: f32,
    // Memory-mapped profile storage for fast loading
    mmap_profiles: Option<Mmap>,
}

impl VoiceBiometricSystem {
    pub async fn new(accelerator: Arc<DualAcceleratorManager>) -> Result<Self> {
        let profile_dir = PathBuf::from("./data/profiles");
        std::fs::create_dir_all(&profile_dir)?;
        
        let mut system = Self {
            profiles: Arc::new(RwLock::new(HashMap::new())),
            profile_dir: profile_dir.clone(),
            accelerator,
            identification_threshold: 0.75,
            verification_threshold: 0.85,
            mmap_profiles: None,
        };
        
        system.load_profiles().await?;
        Ok(system)
    }
    
    async fn load_profiles(&mut self) -> Result<()> {
        let profile_file = self.profile_dir.join("profiles.bin");
        
        if profile_file.exists() {
            // Memory-map the profiles file for fast access
            let file = File::open(&profile_file)?;
            let mmap = unsafe { MmapOptions::new().map(&file)? };
            
            // Deserialize profiles
            let profiles: HashMap<String, VoiceProfile> = bincode::deserialize(&mmap)?;
            
            *self.profiles.write() = profiles;
            self.mmap_profiles = Some(mmap);
            
            info!("Loaded {} voice profiles", self.profiles.read().len());
        }
        
        Ok(())
    }
    
    pub async fn enroll(
        &self,
        name: String,
        audio_samples: Vec<Vec<f32>>,
    ) -> Result<String> {
        if audio_samples.len() < 3 {
            return Err(anyhow::anyhow!("Need at least 3 samples for enrollment"));
        }
        
        info!("Enrolling user: {}", name);
        
        // Process samples in parallel using rayon
        let embeddings: Vec<Vec<f32>> = audio_samples
            .iter()
            .map(|audio| self.extract_embedding(audio))
            .collect::<Result<Vec<_>>>()?;
        
        // Average embeddings
        let mut avg_embedding = [0.0f32; EMBEDDING_DIM];
        for embedding in &embeddings {
            for (i, &val) in embedding.iter().enumerate() {
                avg_embedding[i] += val / embeddings.len() as f32;
            }
        }
        
        // Extract MFCC features
        let (mfcc_mean, mfcc_std) = self.extract_mfcc_stats(&audio_samples[0])?;
        
        // Create profile
        let user_id = format!("{:x}", md5::compute(&name));
        let profile = VoiceProfile {
            user_id: user_id.clone(),
            name,
            embedding: avg_embedding,
            mfcc_mean,
            mfcc_std,
            pitch_range: (80.0, 250.0), // Placeholder
            num_samples: audio_samples.len(),
            total_duration_ms: audio_samples.iter()
                .map(|s| s.len() as u64 * 1000 / 16000)
                .sum(),
        };
        
        // Save profile
        self.profiles.write().insert(user_id.clone(), profile);
        self.save_profiles().await?;
        
        Ok(user_id)
    }
    
    pub async fn identify(&self, audio: &[f32]) -> Result<Option<(String, f32)>> {
        let embedding = self.extract_embedding(audio)?;
        
        let profiles = self.profiles.read();
        let mut best_match = None;
        let mut best_score = f32::MAX;
        
        // Parallel search using rayon
        use rayon::prelude::*;
        let results: Vec<(String, f32)> = profiles
            .par_iter()
            .map(|(id, profile)| {
                let distance = profile.distance(&embedding);
                (id.clone(), distance)
            })
            .collect();
        
        for (id, distance) in results {
            if distance < best_score {
                best_score = distance;
                best_match = Some((id, 1.0 - distance)); // Convert to similarity
            }
        }
        
        if let Some((id, similarity)) = best_match {
            if similarity >= self.identification_threshold {
                debug!("Identified speaker: {} (similarity: {:.2})", id, similarity);
                return Ok(Some((id, similarity)));
            }
        }
        
        Ok(None)
    }
    
    pub async fn verify(&self, user_id: &str, audio: &[f32]) -> Result<bool> {
        let profiles = self.profiles.read();
        let profile = profiles.get(user_id)
            .ok_or_else(|| anyhow::anyhow!("Profile not found"))?;
        
        let embedding = self.extract_embedding(audio)?;
        let similarity = 1.0 - profile.distance(&embedding);
        
        Ok(similarity >= self.verification_threshold)
    }
    
    fn extract_embedding(&self, audio: &[f32]) -> Result<Vec<f32>> {
        // Use GNA for efficient embedding extraction
        if self.accelerator.has_gna() {
            // This would call the actual model
            // For now, return placeholder
            Ok(vec![0.0f32; EMBEDDING_DIM])
        } else {
            // Fallback to simple feature extraction
            self.extract_simple_embedding(audio)
        }
    }
    
    fn extract_simple_embedding(&self, audio: &[f32]) -> Result<Vec<f32>> {
        // Simple statistical features as fallback
        let mut features = Vec::with_capacity(EMBEDDING_DIM);
        
        // Basic statistics
        let mean: f32 = audio.iter().sum::<f32>() / audio.len() as f32;
        let variance: f32 = audio.iter().map(|x| (x - mean).powi(2)).sum::<f32>() 
            / audio.len() as f32;
        
        features.push(mean);
        features.push(variance.sqrt());
        
        // Zero-crossing rate
        let zcr = audio.windows(2)
            .filter(|w| w[0] * w[1] < 0.0)
            .count() as f32 / audio.len() as f32;
        features.push(zcr);
        
        // Pad to full dimension
        features.resize(EMBEDDING_DIM, 0.0);
        
        Ok(features)
    }
    
    fn extract_mfcc_stats(&self, audio: &[f32]) -> Result<([f32; MFCC_DIM], [f32; MFCC_DIM])> {
        // Placeholder MFCC extraction
        // In production, use mel-spec crate
        let mean = [0.0f32; MFCC_DIM];
        let std = [1.0f32; MFCC_DIM];
        Ok((mean, std))
    }
    
    async fn save_profiles(&self) -> Result<()> {
        let profile_file = self.profile_dir.join("profiles.bin");
        let profiles = self.profiles.read();
        
        let serialized = bincode::serialize(&*profiles)?;
        
        // Use memory-mapped file for efficiency
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .open(&profile_file)?;
        
        file.set_len(serialized.len() as u64)?;
        
        let mut mmap = unsafe { MmapMut::map_mut(&file)? };
        mmap.copy_from_slice(&serialized);
        mmap.flush()?;
        
        debug!("Saved {} profiles", profiles.len());
        Ok(())
    }
    
    pub fn adapt(&self, user_id: &str, audio: &[f32], transcript: &str) -> Result<()> {
        // Continuous learning - update profile with new sample
        let mut profiles = self.profiles.write();
        
        if let Some(profile) = profiles.get_mut(user_id) {
            // Update embedding with exponential moving average
            let new_embedding = self.extract_embedding(audio)?;
            let alpha = 0.1; // Learning rate
            
            for (i, &new_val) in new_embedding.iter().enumerate() {
                profile.embedding[i] = (1.0 - alpha) * profile.embedding[i] + alpha * new_val;
            }
            
            profile.num_samples += 1;
            profile.total_duration_ms += audio.len() as u64 * 1000 / 16000;
            
            debug!("Adapted profile for {} (samples: {})", user_id, profile.num_samples);
        }
        
        Ok(())
    }
}