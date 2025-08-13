//! Voice Agent System - High-Performance Agent-Based Voice Recognition
//! 
//! This system implements a multi-agent architecture optimized for Intel Core Ultra processors
//! with dual acceleration (GNA + NPU). The architecture supports real-time voice recognition
//! with self-improvement capabilities and personalization.

use anyhow::Result;
use clap::Parser;
use std::sync::Arc;
use tracing::{info, warn, error};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod agents;
mod audio;
mod config;
mod core;
mod metrics;
mod models;
mod utils;

use crate::config::SystemConfig;
use crate::core::orchestrator::VoiceOrchestrator;
use crate::metrics::MetricsCollector;

#[derive(Parser)]
#[command(name = "voice-agent-system")]
#[command(about = "High-performance agent-based voice recognition system")]
struct Cli {
    /// Configuration file path
    #[arg(short, long, default_value = "config.toml")]
    config: std::path::PathBuf,
    
    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,
    
    /// Enable metrics server
    #[arg(long, default_value_t = true)]
    metrics: bool,
    
    /// Metrics server port
    #[arg(long, default_value = "9090")]
    metrics_port: u16,
    
    /// Enable profiling
    #[arg(long)]
    profile: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Initialize tracing
    init_tracing(&cli.log_level)?;
    
    info!("Starting Voice Agent System v{}", env!("CARGO_PKG_VERSION"));
    
    // Load configuration
    let config = Arc::new(SystemConfig::load(&cli.config).await?);
    info!("Loaded configuration from {:?}", cli.config);
    
    // Initialize metrics collector
    let metrics = if cli.metrics {
        Some(Arc::new(MetricsCollector::new(cli.metrics_port).await?))
    } else {
        None
    };
    
    // Create and start the orchestrator
    let orchestrator = VoiceOrchestrator::new(config.clone(), metrics.clone()).await?;
    
    info!("Voice Agent System initialized successfully");
    info!("Available accelerators: {:?}", orchestrator.available_accelerators());
    
    // Start metrics server if enabled
    if let Some(ref metrics_collector) = metrics {
        tokio::spawn(async move {
            if let Err(e) = metrics_collector.start_server().await {
                error!("Metrics server error: {}", e);
            }
        });
        info!("Metrics server started on port {}", cli.metrics_port);
    }
    
    // Handle graceful shutdown
    let shutdown_handler = setup_shutdown_handler();
    
    // Run the orchestrator
    tokio::select! {
        result = orchestrator.run() => {
            match result {
                Ok(_) => info!("Voice Agent System completed successfully"),
                Err(e) => error!("Voice Agent System error: {}", e),
            }
        }
        _ = shutdown_handler => {
            info!("Shutdown signal received");
            orchestrator.shutdown().await?;
            info!("Voice Agent System shut down gracefully");
        }
    }
    
    Ok(())
}

fn init_tracing(log_level: &str) -> Result<()> {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .or_else(|_| tracing_subscriber::EnvFilter::try_new(log_level))?;
    
    tracing_subscriber::registry()
        .with(filter)
        .with(
            tracing_subscriber::fmt::layer()
                .with_target(false)
                .with_thread_ids(true)
                .with_file(true)
                .with_line_number(true)
        )
        .init();
    
    Ok(())
}

async fn setup_shutdown_handler() {
    use tokio::signal;
    
    let mut sigterm = signal::unix::signal(signal::unix::SignalKind::terminate())
        .expect("Failed to install SIGTERM handler");
    let mut sigint = signal::unix::signal(signal::unix::SignalKind::interrupt())
        .expect("Failed to install SIGINT handler");
    
    tokio::select! {
        _ = sigterm.recv() => {
            info!("Received SIGTERM");
        }
        _ = sigint.recv() => {
            info!("Received SIGINT");
        }
    }
}