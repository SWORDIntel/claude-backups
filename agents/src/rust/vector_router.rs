//! Vector-based Semantic Message Router
//! 
//! High-performance vector database for semantic message routing in the
//! Claude Agent Communication System. Provides:
//! - Real-time vector similarity search
//! - Semantic message clustering
//! - Adaptive routing based on content similarity
//! - Edge AI capabilities for distributed intelligence
//! - Integration with NPU/GNA hardware acceleration
//!
//! Author: ML-OPS Agent
//! Version: 1.0 Production

use anyhow::{Context, Result};
use arc_swap::ArcSwap;
use dashmap::DashMap;
use ndarray::{Array1, Array2, Axis};
use parking_lot::{RwLock, Mutex};
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::{BinaryHeap, HashMap, VecDeque};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::{mpsc, oneshot, Semaphore};
use tracing::{debug, error, info, instrument, warn};
use uuid::Uuid;

// Hardware acceleration support
#[cfg(feature = "npu-acceleration")]
use openvino::{Core, CompiledModel, InferRequest, Tensor, ElementType, Shape};

#[cfg(feature = "simd")]
use std::arch::x86_64::*;

// ============================================================================
// CORE TYPES AND CONSTANTS
// ============================================================================

/// Maximum vector dimensions supported
const MAX_VECTOR_DIMENSIONS: usize = 1024;

/// Default vector dimensions for message embeddings
const DEFAULT_VECTOR_DIM: usize = 512;

/// Maximum number of stored vectors
const MAX_VECTOR_CAPACITY: usize = 1_000_000;

/// Similarity search result limit
const MAX_SEARCH_RESULTS: usize = 100;

/// Cache size for frequent queries
const SIMILARITY_CACHE_SIZE: usize = 10_000;

/// Batch size for hardware-accelerated operations
const HW_ACCEL_BATCH_SIZE: usize = 64;

/// Vector quantization levels for compression
const QUANTIZATION_LEVELS: usize = 256;

/// Clustering update interval
const CLUSTER_UPDATE_INTERVAL: Duration = Duration::from_secs(60);

/// Vector database performance metrics
#[derive(Debug, Clone, Default)]
pub struct VectorMetrics {
    pub total_vectors: AtomicUsize,
    pub total_searches: AtomicU64,
    pub cache_hits: AtomicU64,
    pub cache_misses: AtomicU64,
    pub avg_search_latency_ns: AtomicU64,
    pub hw_accel_queries: AtomicU64,
    pub clustering_operations: AtomicU64,
    pub memory_usage_bytes: AtomicUsize,
}

/// Similarity search configuration
#[derive(Debug, Clone)]
pub struct SearchConfig {
    pub similarity_threshold: f32,
    pub max_results: usize,
    pub use_hardware_acceleration: bool,
    pub enable_clustering: bool,
    pub quantization_enabled: bool,
}

impl Default for SearchConfig {
    fn default() -> Self {
        Self {
            similarity_threshold: 0.7,
            max_results: 20,
            use_hardware_acceleration: true,
            enable_clustering: true,
            quantization_enabled: false,
        }
    }
}

/// Message vector representation
#[derive(Debug, Clone)]
pub struct MessageVector {
    pub id: Uuid,
    pub agent_id: u32,
    pub message_type: u32,
    pub timestamp: SystemTime,
    pub vector: Array1<f32>,
    pub metadata: HashMap<String, String>,
    pub cluster_id: Option<usize>,
    pub routing_history: Vec<u32>, // Previous successful targets
}

/// Similarity search result
#[derive(Debug, Clone)]
pub struct SimilarityResult {
    pub vector_id: Uuid,
    pub agent_id: u32,
    pub similarity_score: f32,
    pub cluster_id: Option<usize>,
    pub suggested_targets: Vec<u32>,
    pub confidence: f32,
}

/// Vector cluster for semantic grouping
#[derive(Debug, Clone)]
pub struct VectorCluster {
    pub id: usize,
    pub centroid: Array1<f32>,
    pub member_count: usize,
    pub last_updated: SystemTime,
    pub routing_preferences: HashMap<u32, f32>, // Target -> preference score
    pub performance_stats: ClusterPerformanceStats,
}

#[derive(Debug, Clone, Default)]
pub struct ClusterPerformanceStats {
    pub successful_routes: u64,
    pub failed_routes: u64,
    pub avg_latency_ms: f32,
    pub last_performance_update: SystemTime,
}

/// Hardware acceleration context
#[cfg(feature = "npu-acceleration")]
pub struct HardwareAccelerator {
    core: Core,
    model: CompiledModel,
    batch_size: usize,
    input_shape: Shape,
    output_shape: Shape,
}

/// Quantized vector for memory efficiency
#[derive(Debug, Clone)]
pub struct QuantizedVector {
    pub quantized_data: Vec<u8>,
    pub scale: f32,
    pub offset: f32,
    pub original_norm: f32,
}

/// Vector database index for fast similarity search
pub struct VectorIndex {
    // Core storage
    vectors: Arc<RwLock<HashMap<Uuid, MessageVector>>>,
    clusters: Arc<RwLock<HashMap<usize, VectorCluster>>>,
    
    // Performance optimization structures
    similarity_cache: Arc<DashMap<u64, Vec<SimilarityResult>>>,
    quantized_vectors: Arc<RwLock<HashMap<Uuid, QuantizedVector>>>,
    
    // Hardware acceleration
    #[cfg(feature = "npu-acceleration")]
    hw_accelerator: Arc<Mutex<Option<HardwareAccelerator>>>,
    
    // Configuration and metrics
    config: Arc<ArcSwap<SearchConfig>>,
    metrics: Arc<VectorMetrics>,
    
    // Async processing
    background_tasks: Arc<Semaphore>,
    clustering_tx: mpsc::UnboundedSender<ClusteringTask>,
    
    // Index metadata
    next_cluster_id: AtomicUsize,
    dimensions: usize,
}

/// Background clustering task
#[derive(Debug)]
enum ClusteringTask {
    AddVector(Uuid),
    UpdateClusters,
    RecomputeCentroids,
    CleanupStaleVectors,
}

/// Vector database implementation
pub struct VectorDatabase {
    index: VectorIndex,
    _clustering_handle: tokio::task::JoinHandle<()>,
}

// ============================================================================
// SIMD ACCELERATED OPERATIONS
// ============================================================================

/// SIMD-accelerated dot product for x86-64 with AVX2
#[cfg(all(feature = "simd", target_arch = "x86_64"))]
fn simd_dot_product(a: &[f32], b: &[f32]) -> f32 {
    assert_eq!(a.len(), b.len());
    let len = a.len();
    
    unsafe {
        let mut sum = _mm256_setzero_ps();
        let chunks = len / 8;
        
        for i in 0..chunks {
            let offset = i * 8;
            let va = _mm256_loadu_ps(a.as_ptr().add(offset));
            let vb = _mm256_loadu_ps(b.as_ptr().add(offset));
            let mul = _mm256_mul_ps(va, vb);
            sum = _mm256_add_ps(sum, mul);
        }
        
        // Horizontal add to get final sum
        let hi = _mm256_extractf128_ps(sum, 1);
        let lo = _mm256_castps256_ps128(sum);
        let sum128 = _mm_add_ps(hi, lo);
        let sum64 = _mm_add_ps(sum128, _mm_movehl_ps(sum128, sum128));
        let sum32 = _mm_add_ss(sum64, _mm_shuffle_ps(sum64, sum64, 1));
        
        let mut result = _mm_cvtss_f32(sum32);
        
        // Handle remainder elements
        for i in (chunks * 8)..len {
            result += a[i] * b[i];
        }
        
        result
    }
}

/// Fallback dot product for non-SIMD platforms
#[cfg(not(all(feature = "simd", target_arch = "x86_64")))]
fn simd_dot_product(a: &[f32], b: &[f32]) -> f32 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

/// SIMD-accelerated cosine similarity
pub fn fast_cosine_similarity(a: &Array1<f32>, b: &Array1<f32>) -> f32 {
    let dot = simd_dot_product(a.as_slice().unwrap(), b.as_slice().unwrap());
    let norm_a = a.dot(a).sqrt();
    let norm_b = b.dot(b).sqrt();
    
    if norm_a == 0.0 || norm_b == 0.0 {
        0.0
    } else {
        dot / (norm_a * norm_b)
    }
}

/// Batch cosine similarity computation
pub fn batch_cosine_similarity(
    query: &Array1<f32>,
    vectors: &[Array1<f32>],
) -> Vec<f32> {
    vectors
        .par_iter()
        .map(|v| fast_cosine_similarity(query, v))
        .collect()
}

// ============================================================================
// VECTOR QUANTIZATION
// ============================================================================

impl QuantizedVector {
    /// Create quantized vector from f32 array
    pub fn from_vector(vector: &Array1<f32>) -> Self {
        let data = vector.as_slice().unwrap();
        let min_val = data.iter().fold(f32::INFINITY, |a, &b| a.min(b));
        let max_val = data.iter().fold(f32::NEG_INFINITY, |a, &b| a.max(b));
        
        let scale = (max_val - min_val) / (QUANTIZATION_LEVELS as f32 - 1.0);
        let offset = min_val;
        let original_norm = vector.dot(vector).sqrt();
        
        let quantized_data: Vec<u8> = data
            .iter()
            .map(|&x| {
                let normalized = (x - offset) / scale;
                (normalized.round().clamp(0.0, (QUANTIZATION_LEVELS - 1) as f32)) as u8
            })
            .collect();
        
        Self {
            quantized_data,
            scale,
            offset,
            original_norm,
        }
    }
    
    /// Reconstruct approximate f32 vector
    pub fn to_vector(&self) -> Array1<f32> {
        let data: Vec<f32> = self
            .quantized_data
            .iter()
            .map(|&q| (q as f32) * self.scale + self.offset)
            .collect();
        
        Array1::from_vec(data)
    }
    
    /// Fast approximate similarity using quantized data
    pub fn fast_similarity(&self, other: &QuantizedVector) -> f32 {
        if self.quantized_data.len() != other.quantized_data.len() {
            return 0.0;
        }
        
        // Use integer arithmetic for speed
        let dot_product: i32 = self
            .quantized_data
            .iter()
            .zip(other.quantized_data.iter())
            .map(|(&a, &b)| (a as i32) * (b as i32))
            .sum();
        
        // Approximate normalization
        let norm_product = self.original_norm * other.original_norm;
        if norm_product == 0.0 {
            0.0
        } else {
            // Scale back to approximate cosine similarity
            (dot_product as f32) * self.scale * other.scale / norm_product
        }
    }
}

// ============================================================================
// HARDWARE ACCELERATION
// ============================================================================

#[cfg(feature = "npu-acceleration")]
impl HardwareAccelerator {
    pub async fn new(model_path: &str, batch_size: usize) -> Result<Self> {
        let core = Core::new()?;
        let model = core.read_model_from_file(model_path)?;
        let compiled_model = core.compile_model(&model, "NPU")?;
        
        // Assume model takes vectors and outputs similarity scores
        let input_shape = Shape::new(&[batch_size as i64, DEFAULT_VECTOR_DIM as i64]);
        let output_shape = Shape::new(&[batch_size as i64, batch_size as i64]);
        
        Ok(Self {
            core,
            model: compiled_model,
            batch_size,
            input_shape,
            output_shape,
        })
    }
    
    pub async fn batch_similarity(
        &mut self,
        query_batch: &[Array1<f32>],
        candidate_batch: &[Array1<f32>],
    ) -> Result<Array2<f32>> {
        let batch_size = query_batch.len();
        if batch_size > self.batch_size {
            return Err(anyhow::anyhow!("Batch size exceeds hardware limit"));
        }
        
        // Prepare input tensor
        let mut input_data = Vec::with_capacity(batch_size * DEFAULT_VECTOR_DIM);
        for vector in query_batch {
            input_data.extend_from_slice(vector.as_slice().unwrap());
        }
        
        let input_tensor = Tensor::new(ElementType::F32, &self.input_shape)?;
        input_tensor.set_data(&input_data)?;
        
        // Create inference request
        let mut infer_request = self.model.create_infer_request()?;
        infer_request.set_input_tensor(&input_tensor)?;
        
        // Run inference
        infer_request.infer()?;
        
        // Get output
        let output_tensor = infer_request.get_output_tensor()?;
        let output_data: Vec<f32> = output_tensor.get_data()?;
        
        // Reshape to similarity matrix
        let similarity_matrix = Array2::from_shape_vec(
            (batch_size, batch_size),
            output_data,
        )?;
        
        Ok(similarity_matrix)
    }
}

// ============================================================================
// CLUSTERING IMPLEMENTATION
// ============================================================================

impl VectorCluster {
    pub fn new(id: usize, initial_vector: &Array1<f32>) -> Self {
        Self {
            id,
            centroid: initial_vector.clone(),
            member_count: 1,
            last_updated: SystemTime::now(),
            routing_preferences: HashMap::new(),
            performance_stats: ClusterPerformanceStats::default(),
        }
    }
    
    pub fn add_vector(&mut self, vector: &Array1<f32>, weight: f32) {
        let alpha = weight / (self.member_count as f32 + weight);
        self.centroid = (1.0 - alpha) * &self.centroid + alpha * vector;
        self.member_count += 1;
        self.last_updated = SystemTime::now();
    }
    
    pub fn update_routing_preference(&mut self, target: u32, success: bool, latency_ms: f32) {
        let current_pref = self.routing_preferences.get(&target).copied().unwrap_or(0.5);
        
        // Update preference based on success/failure and latency
        let latency_factor = (100.0 - latency_ms.min(100.0)) / 100.0; // Better latency = higher score
        let success_factor = if success { 1.0 } else { 0.0 };
        
        let new_pref = 0.9 * current_pref + 0.1 * (0.7 * success_factor + 0.3 * latency_factor);
        self.routing_preferences.insert(target, new_pref);
        
        // Update performance stats
        if success {
            self.performance_stats.successful_routes += 1;
        } else {
            self.performance_stats.failed_routes += 1;
        }
        
        let total_routes = self.performance_stats.successful_routes + self.performance_stats.failed_routes;
        if total_routes > 0 {
            self.performance_stats.avg_latency_ms = 
                (self.performance_stats.avg_latency_ms * (total_routes - 1) as f32 + latency_ms) / total_routes as f32;
        }
        
        self.performance_stats.last_performance_update = SystemTime::now();
    }
    
    pub fn get_best_targets(&self, count: usize) -> Vec<(u32, f32)> {
        let mut targets: Vec<_> = self.routing_preferences.iter()
            .map(|(&target, &score)| (target, score))
            .collect();
        
        targets.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        targets.truncate(count);
        targets
    }
}

// ============================================================================
// VECTOR INDEX IMPLEMENTATION
// ============================================================================

impl VectorIndex {
    pub fn new(dimensions: usize, config: SearchConfig) -> Self {
        let (clustering_tx, clustering_rx) = mpsc::unbounded_channel();
        
        let index = Self {
            vectors: Arc::new(RwLock::new(HashMap::new())),
            clusters: Arc::new(RwLock::new(HashMap::new())),
            similarity_cache: Arc::new(DashMap::new()),
            quantized_vectors: Arc::new(RwLock::new(HashMap::new())),
            
            #[cfg(feature = "npu-acceleration")]
            hw_accelerator: Arc::new(Mutex::new(None)),
            
            config: Arc::new(ArcSwap::new(Arc::new(config))),
            metrics: Arc::new(VectorMetrics::default()),
            background_tasks: Arc::new(Semaphore::new(10)),
            clustering_tx,
            next_cluster_id: AtomicUsize::new(0),
            dimensions,
        };
        
        // Start background clustering task
        let clustering_handle = Self::start_clustering_worker(
            clustering_rx,
            Arc::clone(&index.vectors),
            Arc::clone(&index.clusters),
            Arc::clone(&index.metrics),
        );
        
        index
    }
    
    #[instrument(skip(self, vector))]
    pub async fn add_vector(&self, mut message_vector: MessageVector) -> Result<()> {
        if message_vector.vector.len() != self.dimensions {
            return Err(anyhow::anyhow!(
                "Vector dimension mismatch: expected {}, got {}",
                self.dimensions,
                message_vector.vector.len()
            ));
        }
        
        let vector_id = message_vector.id;
        
        // Find best cluster or create new one
        let cluster_id = self.find_best_cluster(&message_vector.vector).await;
        message_vector.cluster_id = cluster_id;
        
        // Store vector
        {
            let mut vectors = self.vectors.write();
            vectors.insert(vector_id, message_vector);
            
            self.metrics.total_vectors.store(vectors.len(), Ordering::Relaxed);
            self.metrics.memory_usage_bytes.fetch_add(
                self.dimensions * std::mem::size_of::<f32>(),
                Ordering::Relaxed,
            );
        }
        
        // Create quantized version if enabled
        let config = self.config.load();
        if config.quantization_enabled {
            let vector = &self.vectors.read().get(&vector_id).unwrap().vector;
            let quantized = QuantizedVector::from_vector(vector);
            self.quantized_vectors.write().insert(vector_id, quantized);
        }
        
        // Schedule clustering update
        let _ = self.clustering_tx.send(ClusteringTask::AddVector(vector_id));
        
        info!("Added vector {} to cluster {:?}", vector_id, cluster_id);
        Ok(())
    }
    
    #[instrument(skip(self, query_vector))]
    pub async fn search_similar(
        &self,
        query_vector: &Array1<f32>,
        config: Option<SearchConfig>,
    ) -> Result<Vec<SimilarityResult>> {
        let search_config = config.as_ref().unwrap_or(&*self.config.load());
        let search_start = Instant::now();
        
        self.metrics.total_searches.fetch_add(1, Ordering::Relaxed);
        
        // Check cache first
        let query_hash = self.hash_vector(query_vector);
        if let Some(cached_results) = self.similarity_cache.get(&query_hash) {
            self.metrics.cache_hits.fetch_add(1, Ordering::Relaxed);
            return Ok(cached_results.clone());
        }
        
        self.metrics.cache_misses.fetch_add(1, Ordering::Relaxed);
        
        let mut results = if search_config.use_hardware_acceleration {
            self.hw_accelerated_search(query_vector, search_config).await?
        } else {
            self.cpu_search(query_vector, search_config).await?
        };
        
        // Sort by similarity score
        results.sort_by(|a, b| b.similarity_score.partial_cmp(&a.similarity_score).unwrap());
        results.truncate(search_config.max_results);
        
        // Update metrics
        let search_duration = search_start.elapsed().as_nanos() as u64;
        let current_avg = self.metrics.avg_search_latency_ns.load(Ordering::Relaxed);
        let new_avg = (current_avg + search_duration) / 2;
        self.metrics.avg_search_latency_ns.store(new_avg, Ordering::Relaxed);
        
        // Cache results
        if self.similarity_cache.len() < SIMILARITY_CACHE_SIZE {
            self.similarity_cache.insert(query_hash, results.clone());
        }
        
        debug!("Search completed: {} results in {:?}", results.len(), search_start.elapsed());
        Ok(results)
    }
    
    async fn cpu_search(
        &self,
        query_vector: &Array1<f32>,
        config: &SearchConfig,
    ) -> Result<Vec<SimilarityResult>> {
        let vectors = self.vectors.read();
        let clusters = self.clusters.read();
        
        // If clustering is enabled, search within relevant clusters first
        let candidate_vectors: Vec<_> = if config.enable_clustering && !clusters.is_empty() {
            // Find most similar clusters
            let mut cluster_similarities: Vec<_> = clusters
                .values()
                .map(|cluster| {
                    let similarity = fast_cosine_similarity(query_vector, &cluster.centroid);
                    (cluster.id, similarity)
                })
                .collect();
            
            cluster_similarities.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
            
            // Get vectors from top clusters
            let top_clusters: std::collections::HashSet<_> = cluster_similarities
                .iter()
                .take(3) // Search top 3 clusters
                .map(|(id, _)| *id)
                .collect();
            
            vectors
                .values()
                .filter(|v| v.cluster_id.map_or(true, |id| top_clusters.contains(&id)))
                .collect()
        } else {
            vectors.values().collect()
        };
        
        // Parallel similarity computation
        let similarities: Vec<_> = candidate_vectors
            .par_iter()
            .map(|vector| {
                let similarity = if config.quantization_enabled {
                    // Use quantized similarity for speed
                    if let Some(quantized) = self.quantized_vectors.read().get(&vector.id) {
                        let query_quantized = QuantizedVector::from_vector(query_vector);
                        quantized.fast_similarity(&query_quantized)
                    } else {
                        fast_cosine_similarity(query_vector, &vector.vector)
                    }
                } else {
                    fast_cosine_similarity(query_vector, &vector.vector)
                };
                
                (vector, similarity)
            })
            .filter(|(_, similarity)| *similarity >= config.similarity_threshold)
            .collect();
        
        // Convert to results
        let results: Vec<_> = similarities
            .into_iter()
            .map(|(vector, similarity)| {
                let suggested_targets = if let Some(cluster_id) = vector.cluster_id {
                    if let Some(cluster) = clusters.get(&cluster_id) {
                        cluster.get_best_targets(3).into_iter().map(|(target, _)| target).collect()
                    } else {
                        vector.routing_history.clone()
                    }
                } else {
                    vector.routing_history.clone()
                };
                
                SimilarityResult {
                    vector_id: vector.id,
                    agent_id: vector.agent_id,
                    similarity_score: similarity,
                    cluster_id: vector.cluster_id,
                    suggested_targets,
                    confidence: similarity, // Simplified confidence
                }
            })
            .collect();
        
        Ok(results)
    }
    
    #[cfg(feature = "npu-acceleration")]
    async fn hw_accelerated_search(
        &self,
        query_vector: &Array1<f32>,
        config: &SearchConfig,
    ) -> Result<Vec<SimilarityResult>> {
        self.metrics.hw_accel_queries.fetch_add(1, Ordering::Relaxed);
        
        let mut hw_accel = self.hw_accelerator.lock();
        if let Some(ref mut accelerator) = *hw_accel {
            // Batch process with hardware acceleration
            let vectors = self.vectors.read();
            let vector_list: Vec<_> = vectors.values().collect();
            
            let mut results = Vec::new();
            
            // Process in batches
            for chunk in vector_list.chunks(HW_ACCEL_BATCH_SIZE) {
                let query_batch = vec![query_vector.clone(); chunk.len()];
                let candidate_batch: Vec<_> = chunk.iter().map(|v| v.vector.clone()).collect();
                
                let similarity_matrix = accelerator
                    .batch_similarity(&query_batch, &candidate_batch)
                    .await?;
                
                // Extract diagonal (query vs each candidate)
                for (i, vector) in chunk.iter().enumerate() {
                    let similarity = similarity_matrix[(0, i)];
                    
                    if similarity >= config.similarity_threshold {
                        results.push(SimilarityResult {
                            vector_id: vector.id,
                            agent_id: vector.agent_id,
                            similarity_score: similarity,
                            cluster_id: vector.cluster_id,
                            suggested_targets: vector.routing_history.clone(),
                            confidence: similarity,
                        });
                    }
                }
            }
            
            Ok(results)
        } else {
            // Fallback to CPU if hardware not available
            self.cpu_search(query_vector, config).await
        }
    }
    
    #[cfg(not(feature = "npu-acceleration"))]
    async fn hw_accelerated_search(
        &self,
        query_vector: &Array1<f32>,
        config: &SearchConfig,
    ) -> Result<Vec<SimilarityResult>> {
        // Fallback to CPU search
        self.cpu_search(query_vector, config).await
    }
    
    async fn find_best_cluster(&self, vector: &Array1<f32>) -> Option<usize> {
        let clusters = self.clusters.read();
        
        if clusters.is_empty() {
            return None;
        }
        
        let mut best_cluster = None;
        let mut best_similarity = 0.0;
        
        for cluster in clusters.values() {
            let similarity = fast_cosine_similarity(vector, &cluster.centroid);
            if similarity > best_similarity {
                best_similarity = similarity;
                best_cluster = Some(cluster.id);
            }
        }
        
        // Only assign to cluster if similarity is high enough
        if best_similarity > 0.8 {
            best_cluster
        } else {
            None
        }
    }
    
    fn hash_vector(&self, vector: &Array1<f32>) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        
        // Hash first few dimensions for cache key
        for &val in vector.as_slice().unwrap().iter().take(16) {
            (val * 1000.0) as i32.hash(&mut hasher);
        }
        
        hasher.finish()
    }
    
    fn start_clustering_worker(
        mut rx: mpsc::UnboundedReceiver<ClusteringTask>,
        vectors: Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        clusters: Arc<RwLock<HashMap<usize, VectorCluster>>>,
        metrics: Arc<VectorMetrics>,
    ) -> tokio::task::JoinHandle<()> {
        tokio::spawn(async move {
            let mut update_timer = tokio::time::interval(CLUSTER_UPDATE_INTERVAL);
            
            loop {
                tokio::select! {
                    task = rx.recv() => {
                        match task {
                            Some(ClusteringTask::AddVector(vector_id)) => {
                                Self::handle_add_vector_to_cluster(vector_id, &vectors, &clusters).await;
                            },
                            Some(ClusteringTask::UpdateClusters) => {
                                Self::update_all_clusters(&vectors, &clusters, &metrics).await;
                            },
                            Some(ClusteringTask::RecomputeCentroids) => {
                                Self::recompute_centroids(&vectors, &clusters).await;
                            },
                            Some(ClusteringTask::CleanupStaleVectors) => {
                                Self::cleanup_stale_vectors(&vectors, &clusters).await;
                            },
                            None => break,
                        }
                    }
                    _ = update_timer.tick() => {
                        Self::update_all_clusters(&vectors, &clusters, &metrics).await;
                    }
                }
            }
        })
    }
    
    async fn handle_add_vector_to_cluster(
        vector_id: Uuid,
        vectors: &Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>,
    ) {
        let vector = {
            let vectors_guard = vectors.read();
            vectors_guard.get(&vector_id).cloned()
        };
        
        if let Some(vector) = vector {
            if let Some(cluster_id) = vector.cluster_id {
                let mut clusters_guard = clusters.write();
                if let Some(cluster) = clusters_guard.get_mut(&cluster_id) {
                    cluster.add_vector(&vector.vector, 1.0);
                }
            } else {
                // Create new cluster
                let new_cluster_id = clusters.read().len();
                let new_cluster = VectorCluster::new(new_cluster_id, &vector.vector);
                
                clusters.write().insert(new_cluster_id, new_cluster);
                
                // Update vector with cluster assignment
                vectors.write().get_mut(&vector_id).unwrap().cluster_id = Some(new_cluster_id);
            }
        }
    }
    
    async fn update_all_clusters(
        vectors: &Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>,
        metrics: &Arc<VectorMetrics>,
    ) {
        let start_time = Instant::now();
        
        // Recompute cluster centroids
        Self::recompute_centroids(vectors, clusters).await;
        
        // Reassign vectors to better clusters if needed
        Self::reassign_vectors(vectors, clusters).await;
        
        // Clean up empty clusters
        Self::cleanup_empty_clusters(clusters).await;
        
        metrics.clustering_operations.fetch_add(1, Ordering::Relaxed);
        
        debug!("Cluster update completed in {:?}", start_time.elapsed());
    }
    
    async fn recompute_centroids(
        vectors: &Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>,
    ) {
        let vectors_guard = vectors.read();
        let mut clusters_guard = clusters.write();
        
        // Reset centroids
        for cluster in clusters_guard.values_mut() {
            cluster.centroid.fill(0.0);
            cluster.member_count = 0;
        }
        
        // Accumulate vectors for each cluster
        for vector in vectors_guard.values() {
            if let Some(cluster_id) = vector.cluster_id {
                if let Some(cluster) = clusters_guard.get_mut(&cluster_id) {
                    cluster.centroid = &cluster.centroid + &vector.vector;
                    cluster.member_count += 1;
                }
            }
        }
        
        // Normalize centroids
        for cluster in clusters_guard.values_mut() {
            if cluster.member_count > 0 {
                cluster.centroid /= cluster.member_count as f32;
                cluster.last_updated = SystemTime::now();
            }
        }
    }
    
    async fn reassign_vectors(
        vectors: &Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>,
    ) {
        // This is a simplified K-means-style reassignment
        let mut reassignments = Vec::new();
        
        {
            let vectors_guard = vectors.read();
            let clusters_guard = clusters.read();
            
            for (vector_id, vector) in vectors_guard.iter() {
                let mut best_cluster = vector.cluster_id;
                let mut best_similarity = 0.0;
                
                for cluster in clusters_guard.values() {
                    let similarity = fast_cosine_similarity(&vector.vector, &cluster.centroid);
                    if similarity > best_similarity {
                        best_similarity = similarity;
                        best_cluster = Some(cluster.id);
                    }
                }
                
                if best_cluster != vector.cluster_id && best_similarity > 0.8 {
                    reassignments.push((*vector_id, best_cluster));
                }
            }
        }
        
        // Apply reassignments
        if !reassignments.is_empty() {
            let mut vectors_guard = vectors.write();
            for (vector_id, new_cluster_id) in reassignments {
                if let Some(vector) = vectors_guard.get_mut(&vector_id) {
                    vector.cluster_id = new_cluster_id;
                }
            }
        }
    }
    
    async fn cleanup_empty_clusters(clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>) {
        let mut clusters_guard = clusters.write();
        clusters_guard.retain(|_, cluster| cluster.member_count > 0);
    }
    
    async fn cleanup_stale_vectors(
        vectors: &Arc<RwLock<HashMap<Uuid, MessageVector>>>,
        _clusters: &Arc<RwLock<HashMap<usize, VectorCluster>>>,
    ) {
        let cutoff_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .checked_sub(Duration::from_secs(86400)) // 24 hours
            .map(|d| UNIX_EPOCH + d)
            .unwrap_or(UNIX_EPOCH);
        
        let mut vectors_guard = vectors.write();
        vectors_guard.retain(|_, vector| vector.timestamp > cutoff_time);
    }
}

// ============================================================================
// VECTOR DATABASE PUBLIC API
// ============================================================================

impl VectorDatabase {
    /// Create a new vector database
    pub fn new(dimensions: usize, config: SearchConfig) -> Self {
        let index = VectorIndex::new(dimensions, config);
        
        // Start clustering worker
        let clustering_handle = tokio::spawn(async {
            // This is handled in VectorIndex::start_clustering_worker
        });
        
        Self {
            index,
            _clustering_handle: clustering_handle,
        }
    }
    
    /// Initialize hardware acceleration
    #[cfg(feature = "npu-acceleration")]
    pub async fn init_hardware_acceleration(&self, model_path: &str) -> Result<()> {
        let accelerator = HardwareAccelerator::new(model_path, HW_ACCEL_BATCH_SIZE).await?;
        *self.index.hw_accelerator.lock() = Some(accelerator);
        
        info!("Hardware acceleration initialized with NPU");
        Ok(())
    }
    
    /// Add a message vector to the database
    pub async fn add_message_vector(&self, vector: MessageVector) -> Result<()> {
        self.index.add_vector(vector).await
    }
    
    /// Search for similar message vectors
    pub async fn find_similar_messages(
        &self,
        query_vector: &Array1<f32>,
        config: Option<SearchConfig>,
    ) -> Result<Vec<SimilarityResult>> {
        self.index.search_similar(query_vector, config).await
    }
    
    /// Update routing performance for a cluster
    pub async fn update_routing_performance(
        &self,
        cluster_id: usize,
        target: u32,
        success: bool,
        latency_ms: f32,
    ) -> Result<()> {
        let mut clusters = self.index.clusters.write();
        if let Some(cluster) = clusters.get_mut(&cluster_id) {
            cluster.update_routing_preference(target, success, latency_ms);
        }
        Ok(())
    }
    
    /// Get routing suggestions for a message vector
    pub async fn get_routing_suggestions(
        &self,
        query_vector: &Array1<f32>,
        max_suggestions: usize,
    ) -> Result<Vec<(u32, f32)>> {
        let similar_results = self.find_similar_messages(query_vector, None).await?;
        
        let mut target_scores: HashMap<u32, f32> = HashMap::new();
        let mut target_counts: HashMap<u32, usize> = HashMap::new();
        
        // Aggregate suggestions from similar messages
        for result in similar_results.iter().take(10) {
            for target in &result.suggested_targets {
                let score = result.similarity_score * result.confidence;
                *target_scores.entry(*target).or_insert(0.0) += score;
                *target_counts.entry(*target).or_insert(0) += 1;
            }
        }
        
        // Calculate average scores and sort
        let mut suggestions: Vec<_> = target_scores
            .into_iter()
            .map(|(target, total_score)| {
                let count = target_counts[&target] as f32;
                (target, total_score / count)
            })
            .collect();
        
        suggestions.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        suggestions.truncate(max_suggestions);
        
        Ok(suggestions)
    }
    
    /// Get database statistics
    pub fn get_metrics(&self) -> VectorMetrics {
        VectorMetrics {
            total_vectors: AtomicUsize::new(self.index.metrics.total_vectors.load(Ordering::Relaxed)),
            total_searches: AtomicU64::new(self.index.metrics.total_searches.load(Ordering::Relaxed)),
            cache_hits: AtomicU64::new(self.index.metrics.cache_hits.load(Ordering::Relaxed)),
            cache_misses: AtomicU64::new(self.index.metrics.cache_misses.load(Ordering::Relaxed)),
            avg_search_latency_ns: AtomicU64::new(self.index.metrics.avg_search_latency_ns.load(Ordering::Relaxed)),
            hw_accel_queries: AtomicU64::new(self.index.metrics.hw_accel_queries.load(Ordering::Relaxed)),
            clustering_operations: AtomicU64::new(self.index.metrics.clustering_operations.load(Ordering::Relaxed)),
            memory_usage_bytes: AtomicUsize::new(self.index.metrics.memory_usage_bytes.load(Ordering::Relaxed)),
        }
    }
    
    /// Update search configuration
    pub fn update_config(&self, new_config: SearchConfig) {
        self.index.config.store(Arc::new(new_config));
    }
    
    /// Clear similarity cache
    pub fn clear_cache(&self) {
        self.index.similarity_cache.clear();
    }
    
    /// Get cluster information
    pub async fn get_cluster_info(&self, cluster_id: usize) -> Option<VectorCluster> {
        self.index.clusters.read().get(&cluster_id).cloned()
    }
    
    /// Trigger manual clustering update
    pub async fn update_clustering(&self) -> Result<()> {
        self.index.clustering_tx.send(ClusteringTask::UpdateClusters)?;
        Ok(())
    }
}

// ============================================================================
// C FFI INTERFACE
// ============================================================================

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int, c_uint};

/// C-compatible vector database handle
#[repr(C)]
pub struct CVectorDatabase {
    db: Box<VectorDatabase>,
}

/// C-compatible search result
#[repr(C)]
pub struct CSearchResult {
    agent_id: c_uint,
    similarity_score: c_float,
    suggested_target: c_uint,
    confidence: c_float,
}

#[no_mangle]
pub unsafe extern "C" fn vector_db_create(dimensions: c_int) -> *mut CVectorDatabase {
    let config = SearchConfig::default();
    let db = VectorDatabase::new(dimensions as usize, config);
    
    Box::into_raw(Box::new(CVectorDatabase {
        db: Box::new(db),
    }))
}

#[no_mangle]
pub unsafe extern "C" fn vector_db_destroy(db: *mut CVectorDatabase) {
    if !db.is_null() {
        let _ = Box::from_raw(db);
    }
}

#[no_mangle]
pub unsafe extern "C" fn vector_db_add_vector(
    db: *mut CVectorDatabase,
    agent_id: c_uint,
    message_type: c_uint,
    vector_data: *const c_float,
    dimensions: c_int,
) -> c_int {
    if db.is_null() || vector_data.is_null() {
        return -1;
    }
    
    let db_ref = &mut *db;
    let vector_slice = std::slice::from_raw_parts(vector_data, dimensions as usize);
    let vector = Array1::from_vec(vector_slice.to_vec());
    
    let message_vector = MessageVector {
        id: Uuid::new_v4(),
        agent_id,
        message_type,
        timestamp: SystemTime::now(),
        vector,
        metadata: HashMap::new(),
        cluster_id: None,
        routing_history: Vec::new(),
    };
    
    // Use tokio runtime for async operation
    let rt = tokio::runtime::Handle::current();
    match rt.block_on(db_ref.db.add_message_vector(message_vector)) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn vector_db_search(
    db: *mut CVectorDatabase,
    query_vector: *const c_float,
    dimensions: c_int,
    max_results: c_int,
    results: *mut CSearchResult,
) -> c_int {
    if db.is_null() || query_vector.is_null() || results.is_null() {
        return -1;
    }
    
    let db_ref = &mut *db;
    let query_slice = std::slice::from_raw_parts(query_vector, dimensions as usize);
    let query = Array1::from_vec(query_slice.to_vec());
    
    let rt = tokio::runtime::Handle::current();
    match rt.block_on(db_ref.db.find_similar_messages(&query, None)) {
        Ok(search_results) => {
            let count = search_results.len().min(max_results as usize);
            let results_slice = std::slice::from_raw_parts_mut(results, count);
            
            for (i, result) in search_results.iter().take(count).enumerate() {
                results_slice[i] = CSearchResult {
                    agent_id: result.agent_id,
                    similarity_score: result.similarity_score,
                    suggested_target: result.suggested_targets.first().copied().unwrap_or(0),
                    confidence: result.confidence,
                };
            }
            
            count as c_int
        }
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn vector_db_get_routing_suggestions(
    db: *mut CVectorDatabase,
    query_vector: *const c_float,
    dimensions: c_int,
    max_suggestions: c_int,
    targets: *mut c_uint,
    scores: *mut c_float,
) -> c_int {
    if db.is_null() || query_vector.is_null() || targets.is_null() || scores.is_null() {
        return -1;
    }
    
    let db_ref = &mut *db;
    let query_slice = std::slice::from_raw_parts(query_vector, dimensions as usize);
    let query = Array1::from_vec(query_slice.to_vec());
    
    let rt = tokio::runtime::Handle::current();
    match rt.block_on(db_ref.db.get_routing_suggestions(&query, max_suggestions as usize)) {
        Ok(suggestions) => {
            let count = suggestions.len();
            let targets_slice = std::slice::from_raw_parts_mut(targets, count);
            let scores_slice = std::slice::from_raw_parts_mut(scores, count);
            
            for (i, (target, score)) in suggestions.iter().enumerate() {
                targets_slice[i] = *target;
                scores_slice[i] = *score;
            }
            
            count as c_int
        }
        Err(_) => -1,
    }
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use ndarray::Array;
    
    #[tokio::test]
    async fn test_vector_database_creation() {
        let config = SearchConfig::default();
        let db = VectorDatabase::new(512, config);
        
        let metrics = db.get_metrics();
        assert_eq!(metrics.total_vectors.load(Ordering::Relaxed), 0);
    }
    
    #[tokio::test]
    async fn test_add_and_search_vectors() {
        let config = SearchConfig::default();
        let db = VectorDatabase::new(4, config);
        
        // Add test vectors
        let vector1 = MessageVector {
            id: Uuid::new_v4(),
            agent_id: 1,
            message_type: 10,
            timestamp: SystemTime::now(),
            vector: Array1::from_vec(vec![1.0, 0.0, 0.0, 0.0]),
            metadata: HashMap::new(),
            cluster_id: None,
            routing_history: vec![100, 101],
        };
        
        let vector2 = MessageVector {
            id: Uuid::new_v4(),
            agent_id: 2,
            message_type: 20,
            timestamp: SystemTime::now(),
            vector: Array1::from_vec(vec![0.9, 0.1, 0.0, 0.0]), // Similar to vector1
            metadata: HashMap::new(),
            cluster_id: None,
            routing_history: vec![102, 103],
        };
        
        db.add_message_vector(vector1).await.unwrap();
        db.add_message_vector(vector2).await.unwrap();
        
        // Search for similar vectors
        let query = Array1::from_vec(vec![1.0, 0.0, 0.0, 0.0]);
        let results = db.find_similar_messages(&query, None).await.unwrap();
        
        assert!(results.len() >= 1);
        assert!(results[0].similarity_score > 0.8);
    }
    
    #[test]
    fn test_simd_dot_product() {
        let a = vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
        let b = vec![8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0];
        
        let result = simd_dot_product(&a, &b);
        let expected: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        
        assert!((result - expected).abs() < 1e-6);
    }
    
    #[test]
    fn test_quantized_vector() {
        let original = Array1::from_vec(vec![1.0, -0.5, 0.8, -0.2, 0.0]);
        let quantized = QuantizedVector::from_vector(&original);
        let reconstructed = quantized.to_vector();
        
        // Should be approximately equal (within quantization error)
        for (orig, recon) in original.iter().zip(reconstructed.iter()) {
            assert!((orig - recon).abs() < 0.1);
        }
    }
    
    #[tokio::test]
    async fn test_clustering() {
        let config = SearchConfig {
            enable_clustering: true,
            ..Default::default()
        };
        let db = VectorDatabase::new(3, config);
        
        // Add vectors that should form clusters
        let vectors = vec![
            Array1::from_vec(vec![1.0, 0.0, 0.0]),  // Cluster 1
            Array1::from_vec(vec![0.9, 0.1, 0.0]),  // Cluster 1
            Array1::from_vec(vec![0.0, 1.0, 0.0]),  // Cluster 2
            Array1::from_vec(vec![0.0, 0.9, 0.1]),  // Cluster 2
        ];
        
        for (i, vector) in vectors.into_iter().enumerate() {
            let message_vector = MessageVector {
                id: Uuid::new_v4(),
                agent_id: i as u32,
                message_type: 1,
                timestamp: SystemTime::now(),
                vector,
                metadata: HashMap::new(),
                cluster_id: None,
                routing_history: vec![i as u32 * 10],
            };
            
            db.add_message_vector(message_vector).await.unwrap();
        }
        
        // Wait for clustering to complete
        tokio::time::sleep(Duration::from_millis(100)).await;
        db.update_clustering().await.unwrap();
        
        // Check that clusters were formed
        let query = Array1::from_vec(vec![1.0, 0.0, 0.0]);
        let results = db.find_similar_messages(&query, None).await.unwrap();
        
        assert!(!results.is_empty());
        // Similar vectors should have cluster assignments
        assert!(results.iter().any(|r| r.cluster_id.is_some()));
    }
}