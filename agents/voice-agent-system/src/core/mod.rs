//! Core system components for the Voice Agent System

pub mod accelerator;
pub mod messaging;
pub mod orchestrator;
pub mod scheduler;
pub mod fault_tolerance;

pub use orchestrator::VoiceOrchestrator;
pub use messaging::{MessageBus, AgentMessage, MessagePriority};
pub use accelerator::{AcceleratorManager, AcceleratorType};
pub use scheduler::{AgentScheduler, SchedulingPolicy};
pub use fault_tolerance::{FaultTolerance, RecoveryStrategy};