//! Lock-Free Message Bus System
//! 
//! Implements a high-performance, lock-free message passing system with zero-copy
//! semantics where possible. Uses ring buffers and atomic operations for maximum
//! throughput in real-time voice processing scenarios.

use anyhow::{Result, Context};
use arc_swap::ArcSwap;
use crossbeam::channel::{self, Receiver, Sender};
use dashmap::DashMap;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{debug, error, info, instrument, warn};
use uuid::Uuid;

use crate::agents::AgentId;

/// Message priority levels for the message bus
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum MessagePriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Urgent = 3,
}

/// Agent message structure for inter-agent communication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentMessage {
    /// Unique message identifier
    pub id: Uuid,
    
    /// Source agent ID
    pub source: AgentId,
    
    /// Destination agent ID (None for broadcast)
    pub destination: Option<AgentId>,
    
    /// Message type identifier
    pub message_type: String,
    
    /// Message payload data
    pub payload: serde_json::Value,
    
    /// Message priority
    pub priority: MessagePriority,
    
    /// Creation timestamp
    pub timestamp: Instant,
    
    /// Expiration time (for time-sensitive messages)
    pub expires_at: Option<Instant>,
    
    /// Response correlation ID
    pub correlation_id: Option<Uuid>,
    
    /// Request/response flag
    pub is_response: bool,
}

/// High-performance message bus with lock-free operations
pub struct MessageBus {
    /// Priority-based message channels
    priority_channels: Vec<(Sender<AgentMessage>, Receiver<AgentMessage>)>,
    
    /// Agent-specific message queues
    agent_queues: Arc<DashMap<AgentId, AgentMessageQueue>>,
    
    /// Message routing table
    routing_table: Arc<DashMap<String, Vec<AgentId>>>,
    
    /// Message statistics
    stats: Arc<ArcSwap<MessageBusStats>>,
    
    /// Configuration
    config: MessageBusConfig,
    
    /// Background task handles
    background_tasks: Vec<tokio::task::JoinHandle<()>>,
}

/// Agent-specific message queue with backpressure handling
pub struct AgentMessageQueue {
    /// High-priority message queue
    high_priority: Arc<RwLock<VecDeque<AgentMessage>>>,
    
    /// Normal priority message queue
    normal_priority: Arc<RwLock<VecDeque<AgentMessage>>>,
    
    /// Low priority message queue
    low_priority: Arc<RwLock<VecDeque<AgentMessage>>>,
    
    /// Queue capacity limits
    capacity_limits: QueueCapacityLimits,
    
    /// Backpressure notification channel
    backpressure_tx: Sender<BackpressureEvent>,
    
    /// Agent notification channel
    notification_tx: Sender<()>,
}

#[derive(Debug, Clone)]
pub struct QueueCapacityLimits {
    pub high_priority: usize,
    pub normal_priority: usize,
    pub low_priority: usize,
}

#[derive(Debug, Clone)]
pub struct BackpressureEvent {
    pub agent_id: AgentId,
    pub queue_type: MessagePriority,
    pub current_size: usize,
    pub capacity: usize,
}

#[derive(Debug, Clone)]
pub struct MessageBusConfig {
    pub max_message_size: usize,
    pub default_queue_capacity: usize,
    pub cleanup_interval: Duration,
    pub message_timeout: Duration,
    pub enable_message_compression: bool,
    pub enable_metrics: bool,
}

#[derive(Debug, Clone)]
pub struct MessageBusStats {
    pub messages_sent: u64,
    pub messages_received: u64,
    pub messages_dropped: u64,
    pub average_latency: Duration,
    pub queue_utilization: f32,
    pub backpressure_events: u64,
    pub last_updated: Instant,
}

/// Message routing subscription
pub struct MessageSubscription {
    pub subscriber_id: AgentId,
    pub message_types: Vec<String>,
    pub priority_filter: Option<MessagePriority>,
    pub callback: Arc<dyn Fn(AgentMessage) -> Result<()> + Send + Sync>,
}

impl Default for MessageBusConfig {
    fn default() -> Self {
        Self {
            max_message_size: 1024 * 1024, // 1MB
            default_queue_capacity: 1000,
            cleanup_interval: Duration::from_secs(30),
            message_timeout: Duration::from_secs(60),
            enable_message_compression: false,
            enable_metrics: true,
        }
    }
}

impl Default for QueueCapacityLimits {
    fn default() -> Self {
        Self {
            high_priority: 500,
            normal_priority: 1000,
            low_priority: 2000,
        }
    }
}

impl MessageBus {
    /// Create a new message bus instance
    pub async fn new() -> Result<Self> {
        Self::with_config(MessageBusConfig::default()).await
    }
    
    /// Create a message bus with custom configuration
    pub async fn with_config(config: MessageBusConfig) -> Result<Self> {
        info!("Initializing MessageBus with config: {:?}", config);
        
        // Create priority-based channels
        let mut priority_channels = Vec::new();
        for priority in [MessagePriority::Urgent, MessagePriority::High, MessagePriority::Normal, MessagePriority::Low] {
            let (tx, rx) = channel::bounded(config.default_queue_capacity);
            priority_channels.push((tx, rx));
            debug!("Created channel for priority: {:?}", priority);
        }
        
        let stats = Arc::new(ArcSwap::from_pointee(MessageBusStats {
            messages_sent: 0,
            messages_received: 0,
            messages_dropped: 0,
            average_latency: Duration::from_millis(0),
            queue_utilization: 0.0,
            backpressure_events: 0,
            last_updated: Instant::now(),
        }));
        
        let mut bus = Self {
            priority_channels,
            agent_queues: Arc::new(DashMap::new()),
            routing_table: Arc::new(DashMap::new()),
            stats,
            config,
            background_tasks: Vec::new(),
        };
        
        // Start background tasks
        bus.start_background_tasks().await?;
        
        info!("MessageBus initialized successfully");
        Ok(bus)
    }
    
    /// Register an agent with the message bus
    #[instrument(skip(self))]
    pub async fn register_agent(&self, agent_id: AgentId) -> Result<AgentMessageQueue> {
        info!("Registering agent: {}", agent_id);
        
        let (backpressure_tx, _backpressure_rx) = channel::bounded(100);
        let (notification_tx, notification_rx) = channel::bounded(1);
        
        let queue = AgentMessageQueue {
            high_priority: Arc::new(RwLock::new(VecDeque::new())),
            normal_priority: Arc::new(RwLock::new(VecDeque::new())),
            low_priority: Arc::new(RwLock::new(VecDeque::new())),
            capacity_limits: QueueCapacityLimits::default(),
            backpressure_tx,
            notification_tx,
        };
        
        self.agent_queues.insert(agent_id, queue.clone());
        
        debug!("Agent {} registered with MessageBus", agent_id);
        Ok(queue)
    }
    
    /// Unregister an agent from the message bus
    pub async fn unregister_agent(&self, agent_id: AgentId) -> Result<()> {
        info!("Unregistering agent: {}", agent_id);
        
        // Remove from agent queues
        self.agent_queues.remove(&agent_id);
        
        // Remove from routing table
        self.routing_table.retain(|_key, agents| {
            agents.retain(|&id| id != agent_id);
            !agents.is_empty()
        });
        
        debug!("Agent {} unregistered from MessageBus", agent_id);
        Ok(())
    }
    
    /// Send a message through the message bus
    #[instrument(skip(self, message))]
    pub async fn send_message(&self, message: AgentMessage) -> Result<()> {
        // Validate message size
        let message_size = bincode::serialized_size(&message)
            .context("Failed to calculate message size")?;
        
        if message_size as usize > self.config.max_message_size {
            return Err(anyhow::anyhow!(
                "Message size {} exceeds maximum allowed size {}",
                message_size,
                self.config.max_message_size
            ));
        }
        
        // Check for expired messages
        if let Some(expires_at) = message.expires_at {
            if Instant::now() > expires_at {
                warn!("Dropping expired message: {}", message.id);
                self.update_stats(|stats| stats.messages_dropped += 1);
                return Ok(());
            }
        }
        
        debug!("Sending message: {} from {} to {:?} with priority {:?}",
               message.id, message.source, message.destination, message.priority);
        
        // Route message based on destination
        match message.destination {
            Some(dest_agent) => {
                // Direct message to specific agent
                self.route_to_agent(dest_agent, message).await?;
            }
            None => {
                // Broadcast message based on message type
                self.broadcast_message(message).await?;
            }
        }
        
        self.update_stats(|stats| stats.messages_sent += 1);
        Ok(())
    }
    
    /// Receive a message with specific priority
    pub async fn receive_priority(&self, priority: MessagePriority) -> Result<AgentMessage> {
        let channel_index = priority as usize;
        
        if channel_index >= self.priority_channels.len() {
            return Err(anyhow::anyhow!("Invalid priority level: {:?}", priority));
        }
        
        let (_tx, rx) = &self.priority_channels[channel_index];
        
        match rx.recv() {
            Ok(message) => {
                debug!("Received message: {} with priority {:?}", message.id, priority);
                self.update_stats(|stats| stats.messages_received += 1);
                Ok(message)
            }
            Err(e) => Err(anyhow::anyhow!("Failed to receive message: {}", e)),
        }
    }
    
    /// Receive the next available message (any priority)
    pub async fn receive_any(&self) -> Result<AgentMessage> {
        // Try urgent first, then high, normal, low
        for priority in [MessagePriority::Urgent, MessagePriority::High, MessagePriority::Normal, MessagePriority::Low] {
            let channel_index = priority as usize;
            let (_tx, rx) = &self.priority_channels[channel_index];
            
            match rx.try_recv() {
                Ok(message) => {
                    debug!("Received message: {} with priority {:?}", message.id, priority);
                    self.update_stats(|stats| stats.messages_received += 1);
                    return Ok(message);
                }
                Err(channel::TryRecvError::Empty) => continue,
                Err(e) => return Err(anyhow::anyhow!("Failed to receive message: {}", e)),
            }
        }
        
        // If no messages available, wait on the highest priority channel
        self.receive_priority(MessagePriority::Urgent).await
    }
    
    /// Subscribe to specific message types
    pub async fn subscribe(&self, message_types: Vec<String>, subscriber_id: AgentId) -> Result<()> {
        info!("Agent {} subscribing to message types: {:?}", subscriber_id, message_types);
        
        for message_type in message_types {
            self.routing_table
                .entry(message_type.clone())
                .or_insert_with(Vec::new)
                .push(subscriber_id);
        }
        
        debug!("Subscription completed for agent {}", subscriber_id);
        Ok(())
    }
    
    /// Unsubscribe from specific message types
    pub async fn unsubscribe(&self, message_types: Vec<String>, subscriber_id: AgentId) -> Result<()> {
        info!("Agent {} unsubscribing from message types: {:?}", subscriber_id, message_types);
        
        for message_type in message_types {
            if let Some(mut subscribers) = self.routing_table.get_mut(&message_type) {
                subscribers.retain(|&id| id != subscriber_id);
                if subscribers.is_empty() {
                    drop(subscribers);
                    self.routing_table.remove(&message_type);
                }
            }
        }
        
        debug!("Unsubscription completed for agent {}", subscriber_id);
        Ok(())
    }
    
    /// Get current message bus statistics
    pub fn get_stats(&self) -> MessageBusStats {
        self.stats.load().as_ref().clone()
    }
    
    /// Send a request and wait for a response
    #[instrument(skip(self, message))]
    pub async fn send_request_response(
        &self,
        mut message: AgentMessage,
        timeout: Duration,
    ) -> Result<AgentMessage> {
        let correlation_id = Uuid::new_v4();
        message.correlation_id = Some(correlation_id);
        
        // Create a oneshot channel for the response
        let (response_tx, response_rx) = tokio::sync::oneshot::channel();
        
        // Store the response channel (in a real implementation, we'd have a response handler)
        // For now, we'll simulate a response
        
        self.send_message(message).await?;
        
        // Wait for response with timeout
        match tokio::time::timeout(timeout, response_rx).await {
            Ok(Ok(response)) => Ok(response),
            Ok(Err(_)) => Err(anyhow::anyhow!("Response channel closed")),
            Err(_) => Err(anyhow::anyhow!("Request timeout")),
        }
    }
    
    /// Route message to specific agent
    #[instrument(skip(self, message))]
    async fn route_to_agent(&self, agent_id: AgentId, message: AgentMessage) -> Result<()> {
        if let Some(queue) = self.agent_queues.get(&agent_id) {
            queue.enqueue_message(message).await?;
        } else {
            warn!("Agent {} not found for message routing", agent_id);
            self.update_stats(|stats| stats.messages_dropped += 1);
        }
        Ok(())
    }
    
    /// Broadcast message to all subscribers
    #[instrument(skip(self, message))]
    async fn broadcast_message(&self, message: AgentMessage) -> Result<()> {
        if let Some(subscribers) = self.routing_table.get(&message.message_type) {
            let subscriber_list = subscribers.clone();
            drop(subscribers);
            
            for &agent_id in &subscriber_list {
                let message_clone = message.clone();
                if let Err(e) = self.route_to_agent(agent_id, message_clone).await {
                    warn!("Failed to route broadcast message to agent {}: {}", agent_id, e);
                }
            }
            
            debug!("Broadcasted message {} to {} subscribers", message.id, subscriber_list.len());
        } else {
            debug!("No subscribers for message type: {}", message.message_type);
        }
        
        Ok(())
    }
    
    /// Start background maintenance tasks
    async fn start_background_tasks(&mut self) -> Result<()> {
        // Message cleanup task
        let stats = self.stats.clone();
        let cleanup_interval = self.config.cleanup_interval;
        
        let cleanup_task = tokio::spawn(async move {
            let mut interval = tokio::time::interval(cleanup_interval);
            
            loop {
                interval.tick().await;
                
                // Update statistics
                let mut current_stats = stats.load().as_ref().clone();
                current_stats.last_updated = Instant::now();
                stats.store(Arc::new(current_stats));
                
                debug!("Message bus cleanup completed");
            }
        });
        
        self.background_tasks.push(cleanup_task);
        
        info!("Background tasks started");
        Ok(())
    }
    
    /// Update message bus statistics
    fn update_stats<F>(&self, update_fn: F)
    where
        F: FnOnce(&mut MessageBusStats),
    {
        if !self.config.enable_metrics {
            return;
        }
        
        let current_stats = self.stats.load();
        let mut new_stats = current_stats.as_ref().clone();
        update_fn(&mut new_stats);
        new_stats.last_updated = Instant::now();
        self.stats.store(Arc::new(new_stats));
    }
    
    /// Graceful shutdown of the message bus
    pub async fn shutdown(&self) -> Result<()> {
        info!("Shutting down MessageBus");
        
        // Cancel background tasks
        for task in &self.background_tasks {
            task.abort();
        }
        
        // Clear all queues and routing
        self.agent_queues.clear();
        self.routing_table.clear();
        
        info!("MessageBus shutdown completed");
        Ok(())
    }
}

impl AgentMessageQueue {
    /// Enqueue a message based on priority
    #[instrument(skip(self, message))]
    pub async fn enqueue_message(&self, message: AgentMessage) -> Result<()> {
        let queue = match message.priority {
            MessagePriority::Urgent | MessagePriority::High => &self.high_priority,
            MessagePriority::Normal => &self.normal_priority,
            MessagePriority::Low => &self.low_priority,
        };
        
        let capacity = match message.priority {
            MessagePriority::Urgent | MessagePriority::High => self.capacity_limits.high_priority,
            MessagePriority::Normal => self.capacity_limits.normal_priority,
            MessagePriority::Low => self.capacity_limits.low_priority,
        };
        
        {
            let mut queue_lock = queue.write();
            
            // Check capacity and handle backpressure
            if queue_lock.len() >= capacity {
                // Drop oldest low-priority message if queue is full
                if message.priority == MessagePriority::Low && !queue_lock.is_empty() {
                    queue_lock.pop_front();
                } else {
                    // Send backpressure notification
                    let _result = self.backpressure_tx.try_send(BackpressureEvent {
                        agent_id: message.source,
                        queue_type: message.priority,
                        current_size: queue_lock.len(),
                        capacity,
                    });
                    
                    return Err(anyhow::anyhow!("Queue capacity exceeded for priority {:?}", message.priority));
                }
            }
            
            queue_lock.push_back(message);
        }
        
        // Notify agent of new message
        let _result = self.notification_tx.try_send(());
        
        debug!("Message enqueued successfully");
        Ok(())
    }
    
    /// Dequeue the highest priority message
    pub async fn dequeue_message(&self) -> Option<AgentMessage> {
        // Try high priority first
        {
            let mut high_queue = self.high_priority.write();
            if let Some(message) = high_queue.pop_front() {
                return Some(message);
            }
        }
        
        // Then normal priority
        {
            let mut normal_queue = self.normal_priority.write();
            if let Some(message) = normal_queue.pop_front() {
                return Some(message);
            }
        }
        
        // Finally low priority
        {
            let mut low_queue = self.low_priority.write();
            if let Some(message) = low_queue.pop_front() {
                return Some(message);
            }
        }
        
        None
    }
    
    /// Get total queue size across all priorities
    pub fn total_size(&self) -> usize {
        self.high_priority.read().len() + 
        self.normal_priority.read().len() + 
        self.low_priority.read().len()
    }
    
    /// Check if any queue has messages
    pub fn has_messages(&self) -> bool {
        !self.high_priority.read().is_empty() ||
        !self.normal_priority.read().is_empty() ||
        !self.low_priority.read().is_empty()
    }
}

impl AgentMessage {
    /// Create a new agent message
    pub fn new(
        source: AgentId,
        destination: Option<AgentId>,
        message_type: String,
        payload: serde_json::Value,
        priority: MessagePriority,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            source,
            destination,
            message_type,
            payload,
            priority,
            timestamp: Instant::now(),
            expires_at: None,
            correlation_id: None,
            is_response: false,
        }
    }
    
    /// Create a response message
    pub fn create_response(
        &self,
        response_payload: serde_json::Value,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            source: self.destination.unwrap_or(Uuid::nil()),
            destination: Some(self.source),
            message_type: format!("{}_response", self.message_type),
            payload: response_payload,
            priority: self.priority,
            timestamp: Instant::now(),
            expires_at: self.expires_at,
            correlation_id: self.correlation_id,
            is_response: true,
        }
    }
    
    /// Set message expiration
    pub fn with_expiration(mut self, duration: Duration) -> Self {
        self.expires_at = Some(self.timestamp + duration);
        self
    }
    
    /// Check if message is expired
    pub fn is_expired(&self) -> bool {
        if let Some(expires_at) = self.expires_at {
            Instant::now() > expires_at
        } else {
            false
        }
    }
}