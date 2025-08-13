//! Accelerator Management for GNA and NPU
//! 
//! This module provides unified management of Intel's dual acceleration architecture,
//! optimally distributing workloads between GNA (Gaussian Neural Accelerator) and
//! NPU (Neural Processing Unit) based on task characteristics.

use anyhow::{Result, Context};
use arc_swap::ArcSwap;
use dashmap::DashMap;
use parking_lot::RwLock;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{debug, error, info, instrument, warn};
use uuid::Uuid;

use crate::config::SystemConfig;

/// Accelerator types available in Intel Core Ultra processors
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum AcceleratorType {
    /// Gaussian Neural Accelerator - optimized for signal processing and audio tasks
    GNA,
    /// Neural Processing Unit - optimized for transformer models and language tasks
    NPU,
    /// CPU fallback for compatibility
    CPU,
}

/// Accelerator capability description
#[derive(Debug, Clone)]
pub struct AcceleratorCapabilities {
    pub accelerator_type: AcceleratorType,
    pub max_concurrent_tasks: usize,
    pub memory_bandwidth_gbps: f32,
    pub compute_units: usize,
    pub supported_precisions: Vec<Precision>,
    pub specialized_ops: Vec<String>,
}

/// Supported precision types
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Precision {
    FP32,
    FP16,
    INT16,
    INT8,
    BF16,
}

/// Accelerator instance for task execution
pub trait Accelerator: Send + Sync {
    /// Get the accelerator type
    fn accelerator_type(&self) -> AcceleratorType;
    
    /// Get current utilization percentage (0.0 - 1.0)
    fn utilization(&self) -> f32;
    
    /// Check if the accelerator is available for new tasks
    fn is_available(&self) -> bool;
    
    /// Execute a task on this accelerator
    async fn execute_task(&self, task: AcceleratorTask) -> Result<TaskResult>;
    
    /// Get accelerator capabilities
    fn capabilities(&self) -> &AcceleratorCapabilities;
    
    /// Perform health check
    async fn health_check(&self) -> Result<bool>;
}

/// Task to be executed on an accelerator
#[derive(Debug)]
pub struct AcceleratorTask {
    pub id: Uuid,
    pub task_type: TaskType,
    pub input_data: Vec<u8>,
    pub model_config: ModelConfig,
    pub priority: TaskPriority,
    pub deadline: Option<Instant>,
}

/// Types of tasks that can be executed
#[derive(Debug, Clone)]
pub enum TaskType {
    AudioProcessing,
    SpeechRecognition,
    LanguageModeling,
    VoiceBiometrics,
    NoiseReduction,
    FeatureExtraction,
}

/// Task execution priority
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum TaskPriority {
    Low,
    Normal,
    High,
    Critical,
}

/// Model configuration for task execution
#[derive(Debug, Clone)]
pub struct ModelConfig {
    pub model_path: String,
    pub precision: Precision,
    pub batch_size: usize,
    pub max_tokens: Option<usize>,
    pub temperature: Option<f32>,
}

/// Result from task execution
#[derive(Debug)]
pub struct TaskResult {
    pub task_id: Uuid,
    pub output_data: Vec<u8>,
    pub execution_time: Duration,
    pub accelerator_type: AcceleratorType,
    pub metadata: serde_json::Value,
}

/// GNA (Gaussian Neural Accelerator) implementation
pub struct GNAAccelerator {
    capabilities: AcceleratorCapabilities,
    utilization: Arc<ArcSwap<f32>>,
    active_tasks: Arc<DashMap<Uuid, Instant>>,
    config: Arc<SystemConfig>,
}

/// NPU (Neural Processing Unit) implementation
pub struct NPUAccelerator {
    capabilities: AcceleratorCapabilities,
    utilization: Arc<ArcSwap<f32>>,
    active_tasks: Arc<DashMap<Uuid, Instant>>,
    config: Arc<SystemConfig>,
    ort_session: Arc<RwLock<Option<ort::Session>>>,
}

/// CPU fallback accelerator
pub struct CPUAccelerator {
    capabilities: AcceleratorCapabilities,
    utilization: Arc<ArcSwap<f32>>,
    active_tasks: Arc<DashMap<Uuid, Instant>>,
}

/// Main accelerator manager
pub struct AcceleratorManager {
    accelerators: DashMap<AcceleratorType, Arc<dyn Accelerator>>,
    task_scheduler: Arc<AcceleratorTaskScheduler>,
    config: Arc<SystemConfig>,
}

/// Intelligent task scheduler for accelerators
pub struct AcceleratorTaskScheduler {
    pending_tasks: Arc<DashMap<Uuid, AcceleratorTask>>,
    task_history: Arc<DashMap<TaskType, TaskPerformanceStats>>,
}

#[derive(Debug, Clone)]
pub struct TaskPerformanceStats {
    pub avg_execution_time: Duration,
    pub preferred_accelerator: AcceleratorType,
    pub success_rate: f32,
    pub last_updated: Instant,
}

impl AcceleratorManager {
    /// Create a new accelerator manager
    pub async fn new(config: &SystemConfig) -> Result<Self> {
        info!("Initializing Accelerator Manager");
        
        let mut accelerators = DashMap::new();
        
        // Initialize GNA if available
        match GNAAccelerator::new(config.clone()).await {
            Ok(gna) => {
                info!("GNA accelerator initialized successfully");
                accelerators.insert(AcceleratorType::GNA, Arc::new(gna) as Arc<dyn Accelerator>);
            }
            Err(e) => {
                warn!("Failed to initialize GNA: {}. Falling back to CPU", e);
            }
        }
        
        // Initialize NPU if available
        match NPUAccelerator::new(config.clone()).await {
            Ok(npu) => {
                info!("NPU accelerator initialized successfully");
                accelerators.insert(AcceleratorType::NPU, Arc::new(npu) as Arc<dyn Accelerator>);
            }
            Err(e) => {
                warn!("Failed to initialize NPU: {}. Falling back to CPU", e);
            }
        }
        
        // Always have CPU fallback
        let cpu = CPUAccelerator::new();
        accelerators.insert(AcceleratorType::CPU, Arc::new(cpu) as Arc<dyn Accelerator>);
        info!("CPU accelerator initialized");
        
        let task_scheduler = Arc::new(AcceleratorTaskScheduler::new());
        
        Ok(Self {
            accelerators,
            task_scheduler,
            config: config.clone(),
        })
    }
    
    /// Get available accelerator types
    pub fn available_types(&self) -> Vec<AcceleratorType> {
        self.accelerators.iter().map(|entry| *entry.key()).collect()
    }
    
    /// Get specific accelerator instance
    pub fn get_accelerator(&self, accel_type: AcceleratorType) -> Result<Arc<dyn Accelerator>> {
        self.accelerators
            .get(&accel_type)
            .map(|entry| entry.value().clone())
            .context(format!("Accelerator {:?} not available", accel_type))
    }
    
    /// Get the best accelerator for a specific task type
    #[instrument(skip(self))]
    pub fn get_optimal_accelerator(&self, task_type: TaskType) -> Arc<dyn Accelerator> {
        // Use performance history to make intelligent decisions
        if let Some(stats) = self.task_scheduler.task_history.get(&task_type) {
            if let Some(accelerator) = self.accelerators.get(&stats.preferred_accelerator) {
                if accelerator.is_available() {
                    debug!("Using preferred accelerator {:?} for {:?}", stats.preferred_accelerator, task_type);
                    return accelerator.clone();
                }
            }
        }
        
        // Fallback to rule-based assignment
        let optimal_type = match task_type {
            TaskType::AudioProcessing | TaskType::SpeechRecognition | TaskType::VoiceBiometrics | TaskType::NoiseReduction => {
                AcceleratorType::GNA
            }
            TaskType::LanguageModeling => {
                AcceleratorType::NPU
            }
            TaskType::FeatureExtraction => {
                // Choose based on current load
                if self.get_accelerator(AcceleratorType::GNA).map_or(false, |a| a.utilization() < 0.7) {
                    AcceleratorType::GNA
                } else {
                    AcceleratorType::NPU
                }
            }
        };
        
        self.accelerators
            .get(&optimal_type)
            .map(|entry| entry.value().clone())
            .or_else(|| self.accelerators.get(&AcceleratorType::CPU).map(|entry| entry.value().clone()))
            .expect("CPU accelerator should always be available")
    }
    
    /// Execute a task on the optimal accelerator
    #[instrument(skip(self, task))]
    pub async fn execute_task(&self, task: AcceleratorTask) -> Result<TaskResult> {
        let accelerator = self.get_optimal_accelerator(task.task_type.clone());
        
        debug!("Executing task {} on {:?}", task.id, accelerator.accelerator_type());
        
        let start_time = Instant::now();
        let result = accelerator.execute_task(task).await;
        let execution_time = start_time.elapsed();
        
        // Update performance statistics
        match &result {
            Ok(task_result) => {
                self.task_scheduler.update_task_stats(
                    task_result.task_id,
                    &task_result.metadata["task_type"].as_str().unwrap().parse().unwrap(),
                    accelerator.accelerator_type(),
                    execution_time,
                    true,
                );
            }
            Err(_) => {
                if let Some(task_type_str) = task.task_type.to_string().as_str().get(0..1) {
                    // Update failure stats - this is a simplified example
                    debug!("Task execution failed, updating stats");
                }
            }
        }
        
        result
    }
    
    /// Get system-wide accelerator utilization
    pub fn get_system_utilization(&self) -> f32 {
        let total_utilization: f32 = self.accelerators
            .iter()
            .map(|entry| entry.value().utilization())
            .sum();
        
        total_utilization / self.accelerators.len() as f32
    }
    
    /// Perform health check on all accelerators
    pub async fn health_check(&self) -> Result<Vec<(AcceleratorType, bool)>> {
        let mut results = Vec::new();
        
        for entry in self.accelerators.iter() {
            let accel_type = *entry.key();
            let accelerator = entry.value();
            
            match accelerator.health_check().await {
                Ok(healthy) => results.push((accel_type, healthy)),
                Err(e) => {
                    error!("Health check failed for {:?}: {}", accel_type, e);
                    results.push((accel_type, false));
                }
            }
        }
        
        Ok(results)
    }
}

impl GNAAccelerator {
    pub async fn new(config: Arc<SystemConfig>) -> Result<Self> {
        // Initialize GNA capabilities
        let capabilities = AcceleratorCapabilities {
            accelerator_type: AcceleratorType::GNA,
            max_concurrent_tasks: 4,
            memory_bandwidth_gbps: 25.6,
            compute_units: 2,
            supported_precisions: vec![Precision::INT16, Precision::INT8, Precision::FP16],
            specialized_ops: vec![
                "convolution".to_string(),
                "matrix_multiply".to_string(),
                "activation".to_string(),
                "pooling".to_string(),
            ],
        };
        
        #[cfg(feature = "gna-support")]
        {
            // Initialize OpenVINO for GNA
            // This would typically involve loading the OpenVINO runtime
            debug!("Initializing GNA with OpenVINO support");
        }
        
        Ok(Self {
            capabilities,
            utilization: Arc::new(ArcSwap::from_pointee(0.0)),
            active_tasks: Arc::new(DashMap::new()),
            config,
        })
    }
}

impl Accelerator for GNAAccelerator {
    fn accelerator_type(&self) -> AcceleratorType {
        AcceleratorType::GNA
    }
    
    fn utilization(&self) -> f32 {
        **self.utilization.load()
    }
    
    fn is_available(&self) -> bool {
        self.active_tasks.len() < self.capabilities.max_concurrent_tasks
    }
    
    async fn execute_task(&self, task: AcceleratorTask) -> Result<TaskResult> {
        let task_id = task.id;
        let start_time = Instant::now();
        
        self.active_tasks.insert(task_id, start_time);
        
        // Update utilization
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        // Simulate GNA processing
        // In a real implementation, this would invoke OpenVINO with GNA device
        let processing_time = match task.task_type {
            TaskType::AudioProcessing => Duration::from_millis(10),
            TaskType::SpeechRecognition => Duration::from_millis(50),
            TaskType::VoiceBiometrics => Duration::from_millis(30),
            TaskType::NoiseReduction => Duration::from_millis(15),
            _ => Duration::from_millis(25),
        };
        
        tokio::time::sleep(processing_time).await;
        
        // Clean up
        self.active_tasks.remove(&task_id);
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        let mut metadata = serde_json::Map::new();
        metadata.insert("task_type".to_string(), serde_json::Value::String(format!("{:?}", task.task_type)));
        metadata.insert("precision".to_string(), serde_json::Value::String(format!("{:?}", task.model_config.precision)));
        
        Ok(TaskResult {
            task_id,
            output_data: vec![0u8; 1024], // Placeholder output
            execution_time: start_time.elapsed(),
            accelerator_type: AcceleratorType::GNA,
            metadata: serde_json::Value::Object(metadata),
        })
    }
    
    fn capabilities(&self) -> &AcceleratorCapabilities {
        &self.capabilities
    }
    
    async fn health_check(&self) -> Result<bool> {
        // Perform GNA-specific health checks
        Ok(true)
    }
}

impl NPUAccelerator {
    pub async fn new(config: Arc<SystemConfig>) -> Result<Self> {
        let capabilities = AcceleratorCapabilities {
            accelerator_type: AcceleratorType::NPU,
            max_concurrent_tasks: 8,
            memory_bandwidth_gbps: 102.4,
            compute_units: 4,
            supported_precisions: vec![Precision::FP32, Precision::FP16, Precision::BF16, Precision::INT8],
            specialized_ops: vec![
                "transformer".to_string(),
                "attention".to_string(),
                "layer_norm".to_string(),
                "embedding".to_string(),
                "softmax".to_string(),
            ],
        };
        
        // Initialize ONNX Runtime for NPU
        let ort_session = Arc::new(RwLock::new(None));
        
        Ok(Self {
            capabilities,
            utilization: Arc::new(ArcSwap::from_pointee(0.0)),
            active_tasks: Arc::new(DashMap::new()),
            config,
            ort_session,
        })
    }
}

impl Accelerator for NPUAccelerator {
    fn accelerator_type(&self) -> AcceleratorType {
        AcceleratorType::NPU
    }
    
    fn utilization(&self) -> f32 {
        **self.utilization.load()
    }
    
    fn is_available(&self) -> bool {
        self.active_tasks.len() < self.capabilities.max_concurrent_tasks
    }
    
    async fn execute_task(&self, task: AcceleratorTask) -> Result<TaskResult> {
        let task_id = task.id;
        let start_time = Instant::now();
        
        self.active_tasks.insert(task_id, start_time);
        
        // Update utilization
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        // Simulate NPU processing
        // In a real implementation, this would use ONNX Runtime with NPU provider
        let processing_time = match task.task_type {
            TaskType::LanguageModeling => Duration::from_millis(100),
            TaskType::FeatureExtraction => Duration::from_millis(40),
            _ => Duration::from_millis(60),
        };
        
        tokio::time::sleep(processing_time).await;
        
        // Clean up
        self.active_tasks.remove(&task_id);
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        let mut metadata = serde_json::Map::new();
        metadata.insert("task_type".to_string(), serde_json::Value::String(format!("{:?}", task.task_type)));
        metadata.insert("precision".to_string(), serde_json::Value::String(format!("{:?}", task.model_config.precision)));
        
        Ok(TaskResult {
            task_id,
            output_data: vec![0u8; 2048], // Placeholder output
            execution_time: start_time.elapsed(),
            accelerator_type: AcceleratorType::NPU,
            metadata: serde_json::Value::Object(metadata),
        })
    }
    
    fn capabilities(&self) -> &AcceleratorCapabilities {
        &self.capabilities
    }
    
    async fn health_check(&self) -> Result<bool> {
        // Perform NPU-specific health checks
        Ok(true)
    }
}

impl CPUAccelerator {
    pub fn new() -> Self {
        let capabilities = AcceleratorCapabilities {
            accelerator_type: AcceleratorType::CPU,
            max_concurrent_tasks: num_cpus::get(),
            memory_bandwidth_gbps: 50.0,
            compute_units: num_cpus::get(),
            supported_precisions: vec![Precision::FP32, Precision::FP16, Precision::INT16, Precision::INT8],
            specialized_ops: vec!["general_compute".to_string()],
        };
        
        Self {
            capabilities,
            utilization: Arc::new(ArcSwap::from_pointee(0.0)),
            active_tasks: Arc::new(DashMap::new()),
        }
    }
}

impl Accelerator for CPUAccelerator {
    fn accelerator_type(&self) -> AcceleratorType {
        AcceleratorType::CPU
    }
    
    fn utilization(&self) -> f32 {
        **self.utilization.load()
    }
    
    fn is_available(&self) -> bool {
        self.active_tasks.len() < self.capabilities.max_concurrent_tasks
    }
    
    async fn execute_task(&self, task: AcceleratorTask) -> Result<TaskResult> {
        let task_id = task.id;
        let start_time = Instant::now();
        
        self.active_tasks.insert(task_id, start_time);
        
        // Update utilization
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        // CPU processing (slower but more flexible)
        let processing_time = match task.task_type {
            TaskType::AudioProcessing => Duration::from_millis(50),
            TaskType::SpeechRecognition => Duration::from_millis(200),
            TaskType::LanguageModeling => Duration::from_millis(300),
            TaskType::VoiceBiometrics => Duration::from_millis(100),
            TaskType::NoiseReduction => Duration::from_millis(75),
            TaskType::FeatureExtraction => Duration::from_millis(80),
        };
        
        tokio::time::sleep(processing_time).await;
        
        // Clean up
        self.active_tasks.remove(&task_id);
        let utilization = self.active_tasks.len() as f32 / self.capabilities.max_concurrent_tasks as f32;
        self.utilization.store(Arc::new(utilization));
        
        let mut metadata = serde_json::Map::new();
        metadata.insert("task_type".to_string(), serde_json::Value::String(format!("{:?}", task.task_type)));
        metadata.insert("fallback".to_string(), serde_json::Value::Bool(true));
        
        Ok(TaskResult {
            task_id,
            output_data: vec![0u8; 1024],
            execution_time: start_time.elapsed(),
            accelerator_type: AcceleratorType::CPU,
            metadata: serde_json::Value::Object(metadata),
        })
    }
    
    fn capabilities(&self) -> &AcceleratorCapabilities {
        &self.capabilities
    }
    
    async fn health_check(&self) -> Result<bool> {
        Ok(true)
    }
}

impl AcceleratorTaskScheduler {
    pub fn new() -> Self {
        Self {
            pending_tasks: Arc::new(DashMap::new()),
            task_history: Arc::new(DashMap::new()),
        }
    }
    
    pub fn update_task_stats(
        &self,
        task_id: Uuid,
        task_type: &TaskType,
        accelerator_type: AcceleratorType,
        execution_time: Duration,
        success: bool,
    ) {
        let mut stats = self.task_history
            .entry(task_type.clone())
            .or_insert_with(|| TaskPerformanceStats {
                avg_execution_time: execution_time,
                preferred_accelerator: accelerator_type,
                success_rate: if success { 1.0 } else { 0.0 },
                last_updated: Instant::now(),
            });
        
        // Update statistics with exponential moving average
        let alpha = 0.1;
        stats.avg_execution_time = Duration::from_nanos(
            ((1.0 - alpha) * stats.avg_execution_time.as_nanos() as f64 + 
             alpha * execution_time.as_nanos() as f64) as u64
        );
        
        stats.success_rate = (1.0 - alpha) * stats.success_rate + alpha * if success { 1.0 } else { 0.0 };
        stats.last_updated = Instant::now();
        
        // Update preferred accelerator if this one performed better
        if execution_time < stats.avg_execution_time && success {
            stats.preferred_accelerator = accelerator_type;
        }
    }
}

impl TaskType {
    pub fn to_string(&self) -> String {
        format!("{:?}", self)
    }
}

impl std::str::FromStr for TaskType {
    type Err = anyhow::Error;
    
    fn from_str(s: &str) -> Result<Self> {
        match s {
            "AudioProcessing" => Ok(TaskType::AudioProcessing),
            "SpeechRecognition" => Ok(TaskType::SpeechRecognition),
            "LanguageModeling" => Ok(TaskType::LanguageModeling),
            "VoiceBiometrics" => Ok(TaskType::VoiceBiometrics),
            "NoiseReduction" => Ok(TaskType::NoiseReduction),
            "FeatureExtraction" => Ok(TaskType::FeatureExtraction),
            _ => Err(anyhow::anyhow!("Unknown task type: {}", s)),
        }
    }
}