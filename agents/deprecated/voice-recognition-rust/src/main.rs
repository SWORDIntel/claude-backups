use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};

mod accelerator;
mod audio;
mod biometrics;
mod transcription;

use accelerator::DualAcceleratorManager;
use audio::AudioPipeline;
use biometrics::VoiceBiometricSystem;
use transcription::RealtimeASR;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_target(false)
        .with_thread_ids(true)
        .init();

    info!("Voice Recognition System - Intel Core Ultra Optimized (Rust Edition)");
    
    // Initialize dual accelerator manager
    let accelerator = Arc::new(DualAcceleratorManager::new()?);
    
    if accelerator.has_gna() && accelerator.has_npu() {
        info!("✓ Dual Accelerator Mode Active: GNA + NPU");
        info!("  GNA: Ultra-low power voice processing");
        info!("  NPU: High-performance AI inference");
    } else {
        warn!("Running in degraded mode - not all accelerators available");
    }
    
    // Initialize components with shared accelerator
    let biometrics = Arc::new(RwLock::new(
        VoiceBiometricSystem::new(accelerator.clone()).await?
    ));
    
    let audio_pipeline = AudioPipeline::new()?;
    
    let asr = RealtimeASR::new(
        accelerator.clone(),
        biometrics.clone(),
        audio_pipeline,
    )?;
    
    // Start recognition
    info!("Starting real-time recognition... Press Ctrl+C to stop");
    asr.start().await?;
    
    Ok(())
}