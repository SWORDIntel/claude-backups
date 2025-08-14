//! Agent Scheduler - Dynamic Load Balancing and Resource Management
//! 
//! Implements intelligent scheduling of agents based on workload, resource availability,
//! and real-time performance metrics. Supports dynamic scaling and priority-based scheduling.

use anyhow::{Result, Context};
use arc_swap::ArcSwap;
use dashmap::DashMap;
use parking_lot::RwLock;
use std::collections::{BinaryHeap, HashMap};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

use crate::agents::AgentId;

/// Scheduling policies supported by the scheduler
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SchedulingPolicy {
    /// Round-robin scheduling
    RoundRobin,
    /// Priority-based scheduling
    Priority,
    /// Load-based scheduling
    LoadBased,
    /// Adaptive scheduling based on performance metrics
    Adaptive,
    /// Real-time scheduling with deadline constraints
    RealTime,
}

/// Agent scheduling information
#[derive(Debug, Clone)]
pub struct AgentScheduleInfo {
    pub agent_id: AgentId,
    pub priority: u8,
    pub weight: f32,
    pub current_load: f32,
    pub max_load: f32,
    pub last_scheduled: Option<Instant>,
    pub total_executions: u64,
    pub avg_execution_time: Duration,
    pub failure_rate: f32,
    pub resource_requirements: ResourceRequirements,
    pub deadline_constraints: Option<Duration>,
}

/// Resource requirements for an agent
#[derive(Debug, Clone)]
pub struct ResourceRequirements {
    pub cpu_cores: f32,
    pub memory_mb: u32,
    pub gpu_memory_mb: u32,
    pub accelerator_type: Option<crate::core::AcceleratorType>,
    pub network_bandwidth_mbps: u32,
}

/// Scheduling decision made by the scheduler
#[derive(Debug, Clone)]
pub struct SchedulingDecision {
    pub agent_id: AgentId,
    pub assigned_resources: ResourceAllocation,
    pub estimated_completion_time: Duration,
    pub scheduling_reason: String,
    pub timestamp: Instant,
}

/// Resource allocation result
#[derive(Debug, Clone)]
pub struct ResourceAllocation {
    pub cpu_cores: f32,
    pub memory_mb: u32,
    pub gpu_memory_mb: u32,
    pub accelerator_type: Option<crate::core::AcceleratorType>,
    pub priority_level: u8,
}

/// System resource availability
#[derive(Debug, Clone)]
pub struct SystemResources {
    pub total_cpu_cores: u32,
    pub available_cpu_cores: f32,
    pub total_memory_mb: u32,
    pub available_memory_mb: u32,
    pub total_gpu_memory_mb: u32,
    pub available_gpu_memory_mb: u32,
    pub accelerator_availability: HashMap<crate::core::AcceleratorType, f32>,
}

/// Performance metrics for scheduling decisions
#[derive(Debug, Clone)]
pub struct AgentPerformanceMetrics {
    pub throughput_ops_per_sec: f32,
    pub latency_percentiles: LatencyPercentiles,
    pub error_rate: f32,
    pub resource_efficiency: f32,
    pub queue_depth: usize,
    pub backpressure_events: u64,
}

#[derive(Debug, Clone)]
pub struct LatencyPercentiles {
    pub p50: Duration,
    pub p90: Duration,
    pub p95: Duration,
    pub p99: Duration,
}

/// Agent scheduler with dynamic load balancing
pub struct AgentScheduler {
    /// Current scheduling policy
    policy: Arc<ArcSwap<SchedulingPolicy>>,
    
    /// Registered agents and their scheduling information
    agents: Arc<DashMap<AgentId, AgentScheduleInfo>>,
    
    /// Agent performance metrics
    performance_metrics: Arc<DashMap<AgentId, AgentPerformanceMetrics>>,
    
    /// System resource information
    system_resources: Arc<ArcSwap<SystemResources>>,
    
    /// Scheduling queue for pending tasks
    scheduling_queue: Arc<RwLock<BinaryHeap<SchedulingTask>>>,
    
    /// Recent scheduling decisions for analysis
    decision_history: Arc<RwLock<Vec<SchedulingDecision>>>,
    
    /// Scheduler configuration
    config: SchedulerConfig,
    
    /// Round-robin state
    round_robin_index: Arc<ArcSwap<usize>>,
}

/// Task to be scheduled
#[derive(Debug, Clone)]
pub struct SchedulingTask {
    pub task_id: Uuid,
    pub agent_id: Option<AgentId>,
    pub priority: u8,
    pub deadline: Option<Instant>,
    pub resource_hint: Option<ResourceRequirements>,
    pub estimated_duration: Option<Duration>,
    pub creation_time: Instant,
}

impl PartialEq for SchedulingTask {
    fn eq(&self, other: &Self) -> bool {
        self.priority == other.priority && self.creation_time == other.creation_time
    }
}

impl Eq for SchedulingTask {}

impl PartialOrd for SchedulingTask {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for SchedulingTask {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        // Higher priority first, then earlier creation time
        other.priority.cmp(&self.priority)
            .then_with(|| self.creation_time.cmp(&other.creation_time))
    }
}

#[derive(Debug, Clone)]
pub struct SchedulerConfig {
    pub max_decision_history: usize,
    pub resource_update_interval: Duration,
    pub performance_window: Duration,
    pub load_balancing_threshold: f32,
    pub adaptive_learning_rate: f32,
    pub enable_preemption: bool,
    pub max_queue_size: usize,
}

impl Default for SchedulerConfig {
    fn default() -> Self {
        Self {
            max_decision_history: 1000,
            resource_update_interval: Duration::from_secs(5),
            performance_window: Duration::from_secs(60),
            load_balancing_threshold: 0.8,
            adaptive_learning_rate: 0.1,
            enable_preemption: false,
            max_queue_size: 10000,
        }
    }
}

impl AgentScheduler {
    /// Create a new agent scheduler
    pub fn new(policy: SchedulingPolicy) -> Self {
        Self::with_config(policy, SchedulerConfig::default())
    }
    
    /// Create a scheduler with custom configuration
    pub fn with_config(policy: SchedulingPolicy, config: SchedulerConfig) -> Self {
        info!("Initializing AgentScheduler with policy: {:?}", policy);
        
        let system_resources = SystemResources {
            total_cpu_cores: num_cpus::get() as u32,
            available_cpu_cores: num_cpus::get() as f32,
            total_memory_mb: 8192, // This would typically be detected
            available_memory_mb: 6144,
            total_gpu_memory_mb: 0,
            available_gpu_memory_mb: 0,
            accelerator_availability: HashMap::new(),
        };
        
        Self {
            policy: Arc::new(ArcSwap::from_pointee(policy)),
            agents: Arc::new(DashMap::new()),
            performance_metrics: Arc::new(DashMap::new()),
            system_resources: Arc::new(ArcSwap::from_pointee(system_resources)),
            scheduling_queue: Arc::new(RwLock::new(BinaryHeap::new())),
            decision_history: Arc::new(RwLock::new(Vec::new())),
            config,
            round_robin_index: Arc::new(ArcSwap::from_pointee(0)),
        }
    }
    
    /// Register a new agent with the scheduler
    #[instrument(skip(self))]
    pub async fn register_agent(&self, agent_id: AgentId, priority: u8) -> Result<()> {
        info!("Registering agent {} with priority {}", agent_id, priority);
        
        let schedule_info = AgentScheduleInfo {
            agent_id,
            priority,
            weight: 1.0,
            current_load: 0.0,
            max_load: 1.0,
            last_scheduled: None,
            total_executions: 0,
            avg_execution_time: Duration::from_millis(100),
            failure_rate: 0.0,
            resource_requirements: ResourceRequirements::default(),
            deadline_constraints: None,
        };
        
        self.agents.insert(agent_id, schedule_info);
        
        // Initialize performance metrics
        let metrics = AgentPerformanceMetrics {
            throughput_ops_per_sec: 0.0,
            latency_percentiles: LatencyPercentiles {
                p50: Duration::from_millis(50),
                p90: Duration::from_millis(100),
                p95: Duration::from_millis(150),
                p99: Duration::from_millis(300),
            },
            error_rate: 0.0,
            resource_efficiency: 1.0,
            queue_depth: 0,
            backpressure_events: 0,
        };
        
        self.performance_metrics.insert(agent_id, metrics);
        
        debug!("Agent {} registered successfully", agent_id);
        Ok(())
    }
    
    /// Unregister an agent from the scheduler
    pub async fn unregister_agent(&self, agent_id: AgentId) -> Result<()> {
        info!("Unregistering agent {}", agent_id);
        
        self.agents.remove(&agent_id);
        self.performance_metrics.remove(&agent_id);
        
        debug!("Agent {} unregistered successfully", agent_id);
        Ok(())
    }
    
    /// Schedule the next agent to run
    #[instrument(skip(self))]
    pub async fn schedule_next(&self) -> Result<Option<SchedulingDecision>> {
        let policy = **self.policy.load();
        
        match policy {
            SchedulingPolicy::RoundRobin => self.schedule_round_robin().await,
            SchedulingPolicy::Priority => self.schedule_priority().await,
            SchedulingPolicy::LoadBased => self.schedule_load_based().await,
            SchedulingPolicy::Adaptive => self.schedule_adaptive().await,
            SchedulingPolicy::RealTime => self.schedule_real_time().await,
        }
    }
    
    /// Schedule a specific task
    #[instrument(skip(self, task))]
    pub async fn schedule_task(&self, task: SchedulingTask) -> Result<SchedulingDecision> {
        debug!("Scheduling task: {:?}", task.task_id);
        
        // Add to scheduling queue if no specific agent is requested
        if task.agent_id.is_none() {
            let mut queue = self.scheduling_queue.write();
            if queue.len() >= self.config.max_queue_size {
                return Err(anyhow::anyhow!("Scheduling queue is full"));
            }
            queue.push(task.clone());
        }
        
        // Select the best agent for this task
        let agent_id = match task.agent_id {
            Some(id) => id,
            None => self.select_best_agent(&task).await?,
        };
        
        // Create resource allocation
        let allocation = self.allocate_resources(agent_id, &task).await?;
        
        // Estimate completion time
        let completion_time = self.estimate_completion_time(agent_id, &task).await;
        
        let decision = SchedulingDecision {
            agent_id,
            assigned_resources: allocation,
            estimated_completion_time: completion_time,
            scheduling_reason: format!("Selected for task {} using policy {:?}", task.task_id, **self.policy.load()),
            timestamp: Instant::now(),
        };
        
        // Update scheduling history
        self.record_decision(decision.clone()).await;
        
        // Update agent load
        if let Some(mut agent_info) = self.agents.get_mut(&agent_id) {
            agent_info.last_scheduled = Some(Instant::now());
            agent_info.total_executions += 1;
        }
        
        debug!("Task {} scheduled to agent {}", task.task_id, agent_id);
        Ok(decision)
    }
    
    /// Update agent performance metrics
    #[instrument(skip(self, metrics))]
    pub async fn update_performance_metrics(
        &self,
        agent_id: AgentId,
        metrics: AgentPerformanceMetrics,
    ) -> Result<()> {
        self.performance_metrics.insert(agent_id, metrics);
        
        // Update scheduling information based on performance
        if let Some(mut agent_info) = self.agents.get_mut(&agent_id) {
            // Adjust weight based on performance
            let efficiency_factor = self.performance_metrics
                .get(&agent_id)
                .map(|m| m.resource_efficiency)
                .unwrap_or(1.0);
            
            agent_info.weight = (agent_info.weight * 0.9 + efficiency_factor * 0.1).max(0.1);
            
            // Update failure rate
            if let Some(perf_metrics) = self.performance_metrics.get(&agent_id) {
                agent_info.failure_rate = perf_metrics.error_rate;
            }
        }
        
        debug!("Updated performance metrics for agent {}", agent_id);
        Ok(())
    }
    
    /// Round-robin scheduling implementation
    async fn schedule_round_robin(&self) -> Result<Option<SchedulingDecision>> {
        let agent_ids: Vec<AgentId> = self.agents.iter().map(|entry| *entry.key()).collect();
        
        if agent_ids.is_empty() {
            return Ok(None);
        }
        
        let current_index = **self.round_robin_index.load();
        let next_index = (current_index + 1) % agent_ids.len();
        
        self.round_robin_index.store(Arc::new(next_index));
        
        let agent_id = agent_ids[current_index];
        
        // Check if agent is available
        if let Some(agent_info) = self.agents.get(&agent_id) {
            if agent_info.current_load >= agent_info.max_load {
                // Try next agent
                return self.schedule_round_robin().await;
            }
        }
        
        let decision = SchedulingDecision {
            agent_id,
            assigned_resources: ResourceAllocation::default(),
            estimated_completion_time: Duration::from_millis(100),
            scheduling_reason: "Round-robin selection".to_string(),
            timestamp: Instant::now(),
        };
        
        Ok(Some(decision))
    }
    
    /// Priority-based scheduling implementation
    async fn schedule_priority(&self) -> Result<Option<SchedulingDecision>> {
        let mut best_agent: Option<AgentId> = None;
        let mut highest_priority: u8 = 0;
        
        for entry in self.agents.iter() {
            let agent_id = *entry.key();
            let agent_info = entry.value();
            
            if agent_info.current_load < agent_info.max_load && agent_info.priority > highest_priority {
                highest_priority = agent_info.priority;
                best_agent = Some(agent_id);
            }
        }
        
        if let Some(agent_id) = best_agent {
            let decision = SchedulingDecision {
                agent_id,
                assigned_resources: ResourceAllocation::default(),
                estimated_completion_time: Duration::from_millis(100),
                scheduling_reason: format!("Highest priority ({})", highest_priority),
                timestamp: Instant::now(),
            };
            
            Ok(Some(decision))
        } else {
            Ok(None)
        }
    }
    
    /// Load-based scheduling implementation
    async fn schedule_load_based(&self) -> Result<Option<SchedulingDecision>> {
        let mut best_agent: Option<AgentId> = None;
        let mut lowest_load: f32 = f32::MAX;
        
        for entry in self.agents.iter() {
            let agent_id = *entry.key();
            let agent_info = entry.value();
            
            if agent_info.current_load < agent_info.max_load && agent_info.current_load < lowest_load {
                lowest_load = agent_info.current_load;
                best_agent = Some(agent_id);
            }
        }
        
        if let Some(agent_id) = best_agent {
            let decision = SchedulingDecision {
                agent_id,
                assigned_resources: ResourceAllocation::default(),
                estimated_completion_time: Duration::from_millis(100),
                scheduling_reason: format!("Lowest load ({:.2})", lowest_load),
                timestamp: Instant::now(),
            };
            
            Ok(Some(decision))
        } else {
            Ok(None)
        }
    }
    
    /// Adaptive scheduling based on performance history
    async fn schedule_adaptive(&self) -> Result<Option<SchedulingDecision>> {
        let mut best_agent: Option<AgentId> = None;
        let mut best_score: f32 = 0.0;
        
        for entry in self.agents.iter() {
            let agent_id = *entry.key();
            let agent_info = entry.value();
            
            if agent_info.current_load >= agent_info.max_load {
                continue;
            }
            
            // Calculate adaptive score based on multiple factors
            let performance_score = if let Some(metrics) = self.performance_metrics.get(&agent_id) {
                let throughput_score = metrics.throughput_ops_per_sec / 100.0; // Normalize
                let latency_score = 1.0 / (metrics.latency_percentiles.p95.as_millis() as f32 / 100.0);
                let reliability_score = 1.0 - metrics.error_rate;
                let efficiency_score = metrics.resource_efficiency;
                
                (throughput_score + latency_score + reliability_score + efficiency_score) / 4.0
            } else {
                0.5 // Default score for new agents
            };
            
            let load_score = 1.0 - (agent_info.current_load / agent_info.max_load);
            let priority_score = agent_info.priority as f32 / 255.0;
            let weight_score = agent_info.weight;
            
            let total_score = performance_score * 0.4 + load_score * 0.3 + priority_score * 0.2 + weight_score * 0.1;
            
            if total_score > best_score {
                best_score = total_score;
                best_agent = Some(agent_id);
            }
        }
        
        if let Some(agent_id) = best_agent {
            let decision = SchedulingDecision {
                agent_id,
                assigned_resources: ResourceAllocation::default(),
                estimated_completion_time: Duration::from_millis(100),
                scheduling_reason: format!("Adaptive scoring (score: {:.3})", best_score),
                timestamp: Instant::now(),
            };
            
            Ok(Some(decision))
        } else {
            Ok(None)
        }
    }
    
    /// Real-time scheduling with deadline constraints
    async fn schedule_real_time(&self) -> Result<Option<SchedulingDecision>> {
        let mut task_queue = self.scheduling_queue.write();
        
        if let Some(task) = task_queue.pop() {
            // Find agent that can meet the deadline
            let agent_id = self.select_agent_for_deadline(&task).await?;
            
            let decision = SchedulingDecision {
                agent_id,
                assigned_resources: ResourceAllocation::default(),
                estimated_completion_time: Duration::from_millis(50), // Real-time constraint
                scheduling_reason: "Real-time deadline scheduling".to_string(),
                timestamp: Instant::now(),
            };
            
            Ok(Some(decision))
        } else {
            Ok(None)
        }
    }
    
    /// Select the best agent for a specific task
    async fn select_best_agent(&self, task: &SchedulingTask) -> Result<AgentId> {
        // This is a simplified implementation
        // In practice, this would consider task requirements, agent capabilities, etc.
        
        let agent_ids: Vec<AgentId> = self.agents.iter().map(|entry| *entry.key()).collect();
        
        if agent_ids.is_empty() {
            return Err(anyhow::anyhow!("No agents available"));
        }
        
        // For now, return the first available agent
        for agent_id in agent_ids {
            if let Some(agent_info) = self.agents.get(&agent_id) {
                if agent_info.current_load < agent_info.max_load {
                    return Ok(agent_id);
                }
            }
        }
        
        Err(anyhow::anyhow!("No available agents found"))
    }
    
    /// Select agent that can meet deadline constraints
    async fn select_agent_for_deadline(&self, task: &SchedulingTask) -> Result<AgentId> {
        if let Some(deadline) = task.deadline {
            let time_remaining = deadline.saturating_duration_since(Instant::now());
            
            for entry in self.agents.iter() {
                let agent_id = *entry.key();
                let agent_info = entry.value();
                
                if agent_info.current_load < agent_info.max_load && 
                   agent_info.avg_execution_time <= time_remaining {
                    return Ok(agent_id);
                }
            }
        }
        
        self.select_best_agent(task).await
    }
    
    /// Allocate resources for a task
    async fn allocate_resources(
        &self,
        agent_id: AgentId,
        task: &SchedulingTask,
    ) -> Result<ResourceAllocation> {
        let base_allocation = ResourceAllocation::default();
        
        if let Some(agent_info) = self.agents.get(&agent_id) {
            let allocation = ResourceAllocation {
                cpu_cores: agent_info.resource_requirements.cpu_cores,
                memory_mb: agent_info.resource_requirements.memory_mb,
                gpu_memory_mb: agent_info.resource_requirements.gpu_memory_mb,
                accelerator_type: agent_info.resource_requirements.accelerator_type,
                priority_level: agent_info.priority,
            };
            
            Ok(allocation)
        } else {
            Ok(base_allocation)
        }
    }
    
    /// Estimate task completion time
    async fn estimate_completion_time(&self, agent_id: AgentId, task: &SchedulingTask) -> Duration {
        if let Some(duration) = task.estimated_duration {
            return duration;
        }
        
        if let Some(agent_info) = self.agents.get(&agent_id) {
            // Factor in current load
            let load_factor = 1.0 + agent_info.current_load;
            Duration::from_millis((agent_info.avg_execution_time.as_millis() as f32 * load_factor) as u64)
        } else {
            Duration::from_millis(100)
        }
    }
    
    /// Record a scheduling decision
    async fn record_decision(&self, decision: SchedulingDecision) {
        let mut history = self.decision_history.write();
        
        history.push(decision);
        
        // Trim history if it exceeds maximum size
        if history.len() > self.config.max_decision_history {
            history.remove(0);
        }
    }
    
    /// Change the scheduling policy
    pub fn set_policy(&self, policy: SchedulingPolicy) {
        info!("Changing scheduling policy to: {:?}", policy);
        self.policy.store(Arc::new(policy));
    }
    
    /// Get current scheduling statistics
    pub fn get_stats(&self) -> SchedulerStats {
        let total_agents = self.agents.len();
        let active_agents = self.agents
            .iter()
            .filter(|entry| entry.value().current_load > 0.0)
            .count();
        
        let avg_load = if !self.agents.is_empty() {
            self.agents
                .iter()
                .map(|entry| entry.value().current_load)
                .sum::<f32>() / self.agents.len() as f32
        } else {
            0.0
        };
        
        let queue_size = self.scheduling_queue.read().len();
        
        SchedulerStats {
            total_agents,
            active_agents,
            average_load: avg_load,
            queue_size,
            policy: **self.policy.load(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct SchedulerStats {
    pub total_agents: usize,
    pub active_agents: usize,
    pub average_load: f32,
    pub queue_size: usize,
    pub policy: SchedulingPolicy,
}

impl Default for ResourceRequirements {
    fn default() -> Self {
        Self {
            cpu_cores: 1.0,
            memory_mb: 512,
            gpu_memory_mb: 0,
            accelerator_type: None,
            network_bandwidth_mbps: 10,
        }
    }
}

impl Default for ResourceAllocation {
    fn default() -> Self {
        Self {
            cpu_cores: 1.0,
            memory_mb: 512,
            gpu_memory_mb: 0,
            accelerator_type: None,
            priority_level: 128,
        }
    }
}