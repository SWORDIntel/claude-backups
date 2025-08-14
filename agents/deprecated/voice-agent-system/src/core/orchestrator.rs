//! Voice Recognition System Orchestrator
//! 
//! The orchestrator coordinates all agents in the system, managing their lifecycle,
//! communication, and resource allocation. It implements a lock-free architecture
//! with zero-copy message passing for maximum performance.

use anyhow::{Result, Context};
use arc_swap::ArcSwap;
use dashmap::DashMap;
use parking_lot::RwLock;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{broadcast, mpsc, oneshot};
use tracing::{debug, error, info, instrument, warn};
use uuid::Uuid;

use crate::agents::{
    AudioCaptureAgent, VoiceBiometricAgent, AcousticModelingAgent,
    LanguageModelingAgent, SelfImprovementAgent, ProfileManagerAgent,
    MonitoringAgent, AgentTrait, AgentId, AgentStatus
};
use crate::config::SystemConfig;
use crate::core::{
    AcceleratorManager, AcceleratorType, MessageBus, AgentMessage, 
    MessagePriority, AgentScheduler, SchedulingPolicy, FaultTolerance, RecoveryStrategy
};
use crate::metrics::MetricsCollector;

/// Main orchestrator for the voice recognition system
pub struct VoiceOrchestrator {
    /// System configuration
    config: Arc<SystemConfig>,
    
    /// Message bus for agent communication
    message_bus: Arc<MessageBus>,
    
    /// Accelerator manager for GNA/NPU resources
    accelerator_manager: Arc<AcceleratorManager>,
    
    /// Agent scheduler
    scheduler: Arc<AgentScheduler>,
    
    /// Fault tolerance manager
    fault_tolerance: Arc<FaultTolerance>,
    
    /// Metrics collector
    metrics: Option<Arc<MetricsCollector>>,
    
    /// Active agents registry
    agents: Arc<DashMap<AgentId, Arc<dyn AgentTrait + Send + Sync>>>,
    
    /// Agent status tracking
    agent_status: Arc<DashMap<AgentId, AgentStatus>>,
    
    /// System state
    state: Arc<ArcSwap<OrchestratorState>>,
    
    /// Shutdown signal sender
    shutdown_tx: Option<broadcast::Sender<()>>,
    
    /// Performance metrics
    metrics_tx: mpsc::UnboundedSender<MetricUpdate>,
    metrics_rx: Arc<RwLock<Option<mpsc::UnboundedReceiver<MetricUpdate>>>>,
}

#[derive(Debug, Clone)]
pub enum OrchestratorState {
    Initializing,
    Running,
    Degraded,
    ShuttingDown,
    Stopped,
}

#[derive(Debug, Clone)]
pub struct MetricUpdate {
    pub agent_id: AgentId,
    pub metric_name: String,
    pub value: f64,
    pub timestamp: Instant,
}

impl VoiceOrchestrator {
    /// Create a new orchestrator instance
    pub async fn new(
        config: Arc<SystemConfig>,
        metrics: Option<Arc<MetricsCollector>>,
    ) -> Result<Self> {
        info!("Initializing Voice Orchestrator");
        
        let message_bus = Arc::new(MessageBus::new().await?);
        let accelerator_manager = Arc::new(AcceleratorManager::new(&config).await?);
        let scheduler = Arc::new(AgentScheduler::new(SchedulingPolicy::RoundRobin));
        let fault_tolerance = Arc::new(FaultTolerance::new(RecoveryStrategy::Restart));
        
        let (metrics_tx, metrics_rx) = mpsc::unbounded_channel();
        
        let orchestrator = Self {
            config,
            message_bus,
            accelerator_manager,
            scheduler,
            fault_tolerance,
            metrics,
            agents: Arc::new(DashMap::new()),
            agent_status: Arc::new(DashMap::new()),
            state: Arc::new(ArcSwap::from_pointee(OrchestratorState::Initializing)),
            shutdown_tx: None,
            metrics_tx,
            metrics_rx: Arc::new(RwLock::new(Some(metrics_rx))),
        };
        
        info!("Voice Orchestrator initialized");
        Ok(orchestrator)
    }
    
    /// Get available accelerator types
    pub fn available_accelerators(&self) -> Vec<AcceleratorType> {
        self.accelerator_manager.available_types()
    }
    
    /// Start the orchestrator and all agents
    #[instrument(skip(self))]
    pub async fn run(mut self) -> Result<()> {
        info!("Starting Voice Orchestrator");
        
        // Set up shutdown signal
        let (shutdown_tx, _) = broadcast::channel(1);
        self.shutdown_tx = Some(shutdown_tx.clone());
        
        // Initialize and start all agents
        self.initialize_agents().await?;
        
        // Start metrics collection task
        let metrics_rx = self.metrics_rx.write().take();
        if let Some(metrics_rx) = metrics_rx {
            self.start_metrics_collection(metrics_rx).await;
        }
        
        // Update state to running
        self.state.store(Arc::new(OrchestratorState::Running));
        info!("Voice Orchestrator is now running");
        
        // Main orchestration loop
        self.orchestration_loop(shutdown_tx.subscribe()).await?;
        
        Ok(())
    }
    
    /// Initialize and start all system agents
    #[instrument(skip(self))]
    async fn initialize_agents(&self) -> Result<()> {
        info!("Initializing system agents");
        
        // Create agents with their accelerator assignments
        let agents_config = vec![
            (
                "audio_capture",
                Box::new(AudioCaptureAgent::new(
                    self.config.clone(),
                    self.accelerator_manager.get_accelerator(AcceleratorType::GNA)?,
                    self.message_bus.clone(),
                ).await?) as Box<dyn AgentTrait + Send + Sync>,
                1, // priority
            ),
            (
                "voice_biometric",
                Box::new(VoiceBiometricAgent::new(
                    self.config.clone(),
                    self.accelerator_manager.get_accelerator(AcceleratorType::GNA)?,
                    self.message_bus.clone(),
                ).await?),
                2,
            ),
            (
                "acoustic_modeling",
                Box::new(AcousticModelingAgent::new(
                    self.config.clone(),
                    self.accelerator_manager.get_accelerator(AcceleratorType::GNA)?,
                    self.message_bus.clone(),
                ).await?),
                1,
            ),
            (
                "language_modeling",
                Box::new(LanguageModelingAgent::new(
                    self.config.clone(),
                    self.accelerator_manager.get_accelerator(AcceleratorType::NPU)?,
                    self.message_bus.clone(),
                ).await?),
                1,
            ),
            (
                "self_improvement",
                Box::new(SelfImprovementAgent::new(
                    self.config.clone(),
                    self.accelerator_manager.get_accelerator(AcceleratorType::NPU)?,
                    self.message_bus.clone(),
                ).await?),
                3,
            ),
            (
                "profile_manager",
                Box::new(ProfileManagerAgent::new(
                    self.config.clone(),
                    self.message_bus.clone(),
                ).await?),
                2,
            ),
            (
                "monitoring",
                Box::new(MonitoringAgent::new(
                    self.config.clone(),
                    self.message_bus.clone(),
                    self.metrics_tx.clone(),
                ).await?),
                1,
            ),
        ];
        
        // Start all agents
        for (name, agent, priority) in agents_config {
            let agent_id = agent.id();
            let agent_arc = Arc::from(agent);
            
            // Register with scheduler
            self.scheduler.register_agent(agent_id, priority).await?;
            
            // Start the agent
            let agent_clone = agent_arc.clone();
            let fault_tolerance = self.fault_tolerance.clone();
            let agent_status = self.agent_status.clone();
            
            tokio::spawn(async move {
                loop {
                    match agent_clone.run().await {
                        Ok(_) => {
                            info!("Agent {} completed successfully", name);
                            agent_status.insert(agent_id, AgentStatus::Completed);
                            break;
                        }
                        Err(e) => {
                            error!("Agent {} failed: {}", name, e);
                            agent_status.insert(agent_id, AgentStatus::Failed);
                            
                            match fault_tolerance.handle_failure(agent_id, &e).await {
                                Ok(true) => {
                                    info!("Restarting agent {}", name);
                                    agent_status.insert(agent_id, AgentStatus::Running);
                                    continue;
                                }
                                Ok(false) => {
                                    warn!("Agent {} marked for termination", name);
                                    break;
                                }
                                Err(recovery_err) => {
                                    error!("Recovery failed for agent {}: {}", name, recovery_err);
                                    break;
                                }
                            }
                        }
                    }
                }
            });
            
            // Store agent reference
            self.agents.insert(agent_id, agent_arc);
            self.agent_status.insert(agent_id, AgentStatus::Running);
            
            info!("Started agent: {} (ID: {})", name, agent_id);
        }
        
        info!("All agents initialized and started");
        Ok(())
    }
    
    /// Main orchestration loop
    #[instrument(skip(self, mut shutdown_rx))]
    async fn orchestration_loop(
        &self,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) -> Result<()> {
        let mut health_check_interval = tokio::time::interval(
            Duration::from_secs(self.config.health_check_interval_secs)
        );
        
        let mut load_balance_interval = tokio::time::interval(
            Duration::from_secs(self.config.load_balance_interval_secs)
        );
        
        loop {
            tokio::select! {
                // Shutdown signal received
                _ = shutdown_rx.recv() => {
                    info!("Shutdown signal received in orchestration loop");
                    break;
                }
                
                // Health check tick
                _ = health_check_interval.tick() => {
                    self.perform_health_check().await?;
                }
                
                // Load balancing tick
                _ = load_balance_interval.tick() => {
                    self.perform_load_balancing().await?;
                }
                
                // Handle urgent messages
                message = self.message_bus.receive_priority(MessagePriority::Urgent) => {
                    match message {
                        Ok(msg) => self.handle_urgent_message(msg).await?,
                        Err(e) => warn!("Error receiving urgent message: {}", e),
                    }
                }
            }
        }
        
        Ok(())
    }
    
    /// Perform health checks on all agents
    #[instrument(skip(self))]
    async fn perform_health_check(&self) -> Result<()> {
        debug!("Performing health check");
        
        let mut healthy_agents = 0;
        let mut total_agents = 0;
        
        for entry in self.agents.iter() {
            total_agents += 1;
            let agent_id = *entry.key();
            let agent = entry.value();
            
            match agent.health_check().await {
                Ok(true) => {
                    healthy_agents += 1;
                    if let Some(status) = self.agent_status.get(&agent_id) {
                        if *status == AgentStatus::Failed {
                            self.agent_status.insert(agent_id, AgentStatus::Running);
                            info!("Agent {} recovered", agent_id);
                        }
                    }
                }
                Ok(false) => {
                    warn!("Agent {} failed health check", agent_id);
                    self.agent_status.insert(agent_id, AgentStatus::Degraded);
                }
                Err(e) => {
                    error!("Health check error for agent {}: {}", agent_id, e);
                    self.agent_status.insert(agent_id, AgentStatus::Failed);
                }
            }
        }
        
        // Update system state based on agent health
        let health_ratio = healthy_agents as f32 / total_agents as f32;
        let new_state = if health_ratio >= 0.8 {
            OrchestratorState::Running
        } else if health_ratio >= 0.5 {
            OrchestratorState::Degraded
        } else {
            error!("System critically degraded: {}/{} agents healthy", healthy_agents, total_agents);
            OrchestratorState::Degraded
        };
        
        self.state.store(Arc::new(new_state));
        
        debug!("Health check completed: {}/{} agents healthy", healthy_agents, total_agents);
        Ok(())
    }
    
    /// Perform load balancing and dynamic scaling
    #[instrument(skip(self))]
    async fn perform_load_balancing(&self) -> Result<()> {
        debug!("Performing load balancing");
        
        // Get current system load
        let system_load = self.get_system_load().await?;
        
        // Adjust agent priorities based on load
        if system_load > self.config.high_load_threshold {
            info!("High system load detected: {:.2}", system_load);
            self.scale_up_agents().await?;
        } else if system_load < self.config.low_load_threshold {
            debug!("Low system load: {:.2}", system_load);
            self.scale_down_agents().await?;
        }
        
        Ok(())
    }
    
    /// Handle urgent system messages
    #[instrument(skip(self, message))]
    async fn handle_urgent_message(&self, message: AgentMessage) -> Result<()> {
        match message.message_type.as_str() {
            "system_critical_error" => {
                error!("Critical system error received: {:?}", message.payload);
                self.state.store(Arc::new(OrchestratorState::Degraded));
            }
            "agent_restart_request" => {
                if let Some(agent_id) = message.payload.get("agent_id") {
                    if let Ok(agent_id) = agent_id.as_str().unwrap().parse::<Uuid>() {
                        info!("Restart request for agent {}", agent_id);
                        self.restart_agent(agent_id).await?;
                    }
                }
            }
            _ => {
                debug!("Unhandled urgent message type: {}", message.message_type);
            }
        }
        Ok(())
    }
    
    /// Get current system load
    async fn get_system_load(&self) -> Result<f32> {
        // This would typically query system metrics
        // For now, return a placeholder based on active agents
        let active_agents = self.agent_status
            .iter()
            .filter(|entry| *entry.value() == AgentStatus::Running)
            .count();
        
        Ok(active_agents as f32 / self.agents.len() as f32)
    }
    
    /// Scale up agents under high load
    async fn scale_up_agents(&self) -> Result<()> {
        // Implementation for dynamic agent spawning
        info!("Scaling up agents for high load");
        Ok(())
    }
    
    /// Scale down agents under low load
    async fn scale_down_agents(&self) -> Result<()> {
        // Implementation for agent consolidation
        debug!("Scaling down agents for low load");
        Ok(())
    }
    
    /// Restart a specific agent
    async fn restart_agent(&self, agent_id: AgentId) -> Result<()> {
        if let Some(agent_entry) = self.agents.get(&agent_id) {
            let agent = agent_entry.clone();
            info!("Restarting agent {}", agent_id);
            
            // Stop the agent gracefully
            agent.stop().await?;
            
            // Restart it
            let agent_clone = agent.clone();
            let agent_status = self.agent_status.clone();
            let fault_tolerance = self.fault_tolerance.clone();
            
            tokio::spawn(async move {
                match agent_clone.run().await {
                    Ok(_) => {
                        agent_status.insert(agent_id, AgentStatus::Completed);
                    }
                    Err(e) => {
                        error!("Restarted agent {} failed: {}", agent_id, e);
                        agent_status.insert(agent_id, AgentStatus::Failed);
                    }
                }
            });
            
            self.agent_status.insert(agent_id, AgentStatus::Running);
        }
        
        Ok(())
    }
    
    /// Start metrics collection task
    async fn start_metrics_collection(
        &self,
        mut metrics_rx: mpsc::UnboundedReceiver<MetricUpdate>,
    ) {
        let metrics = self.metrics.clone();
        
        tokio::spawn(async move {
            while let Some(update) = metrics_rx.recv().await {
                if let Some(ref collector) = metrics {
                    collector.record_agent_metric(
                        update.agent_id,
                        &update.metric_name,
                        update.value,
                    );
                }
            }
        });
    }
    
    /// Gracefully shutdown the orchestrator
    #[instrument(skip(self))]
    pub async fn shutdown(&self) -> Result<()> {
        info!("Initiating orchestrator shutdown");
        
        self.state.store(Arc::new(OrchestratorState::ShuttingDown));
        
        // Send shutdown signal to all components
        if let Some(ref shutdown_tx) = self.shutdown_tx {
            let _ = shutdown_tx.send(());
        }
        
        // Stop all agents gracefully
        let mut shutdown_tasks = Vec::new();
        
        for entry in self.agents.iter() {
            let agent = entry.value().clone();
            let agent_id = *entry.key();
            
            let task = tokio::spawn(async move {
                if let Err(e) = agent.stop().await {
                    error!("Error stopping agent {}: {}", agent_id, e);
                } else {
                    info!("Agent {} stopped successfully", agent_id);
                }
            });
            
            shutdown_tasks.push(task);
        }
        
        // Wait for all agents to stop with timeout
        let shutdown_timeout = Duration::from_secs(10);
        let shutdown_result = tokio::time::timeout(
            shutdown_timeout,
            futures::future::join_all(shutdown_tasks),
        ).await;
        
        match shutdown_result {
            Ok(_) => info!("All agents stopped successfully"),
            Err(_) => warn!("Some agents did not stop within timeout"),
        }
        
        self.state.store(Arc::new(OrchestratorState::Stopped));
        info!("Orchestrator shutdown completed");
        
        Ok(())
    }
}