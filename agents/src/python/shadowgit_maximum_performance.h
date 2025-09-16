/**
 * shadowgit_maximum_performance.h - Ultra-High Performance Git Processing Engine
 * =================================================================================
 * C-INTERNAL Agent Implementation
 * Target: 15+ BILLION lines/sec throughput
 *
 * Features:
 * - NPU-accelerated hash engine using OpenVINO C++ API
 * - Enhanced AVX2 vectorization beyond 930M lines/sec baseline
 * - Multi-threaded coordination across Intel Core Ultra 7 165H (22 cores)
 * - Zero-copy memory management for maximum efficiency
 * - Thermal-aware performance scaling
 * - Work-stealing queues for optimal core utilization
 * - NUMA-aware memory allocation for large repositories
 * - Real-time performance monitoring with thermal management
 */

#ifndef SHADOWGIT_MAXIMUM_PERFORMANCE_H
#define SHADOWGIT_MAXIMUM_PERFORMANCE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <time.h>
#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * VERSION AND PERFORMANCE TARGETS
 * ============================================================================ */

#define SHADOWGIT_MAX_PERF_VERSION_MAJOR 1
#define SHADOWGIT_MAX_PERF_VERSION_MINOR 0
#define SHADOWGIT_MAX_PERF_VERSION_PATCH 0

// Performance targets
#define TARGET_LINES_PER_SEC_NPU       8000000000ULL  // 8 billion lines/sec (NPU layer)
#define TARGET_LINES_PER_SEC_AVX2      2000000000ULL  // 2 billion lines/sec (enhanced AVX2)
#define TARGET_LINES_PER_SEC_MULTICORE 3000000000ULL  // 3x scaling improvement
#define TARGET_LINES_PER_SEC_TOTAL    15000000000ULL  // 15+ billion lines/sec total

// Hardware configuration for Intel Core Ultra 7 165H
#define INTEL_P_CORES 6        // Performance cores: 0,2,4,6,8,10
#define INTEL_E_CORES 8        // Efficiency cores: 12-19
#define INTEL_LP_E_CORES 2     // Low-power E-cores: 20-21
#define TOTAL_CORES 22         // Total available cores

/* ============================================================================
 * HARDWARE ACCELERATION CAPABILITIES
 * ============================================================================ */

typedef struct {
    // CPU features
    bool avx512f;              // AVX-512 Foundation
    bool avx512bw;             // AVX-512 Byte/Word
    bool avx512vl;             // AVX-512 Vector Length
    bool avx2;                 // AVX2 support
    bool fma;                  // Fused Multiply-Add
    bool bmi2;                 // Bit Manipulation Instructions 2
    bool popcnt;               // Population count

    // NPU capabilities
    bool npu_available;        // Intel AI Boost NPU (11 TOPS)
    uint32_t npu_tops;         // TOPS capability

    // Memory hierarchy
    uint32_t l1d_cache_kb;     // L1 data cache size
    uint32_t l2_cache_kb;      // L2 cache size
    uint32_t l3_cache_kb;      // L3 cache size
    uint64_t total_memory_gb;  // Total system memory

    // Thermal management
    uint32_t max_temp_celsius; // Maximum safe temperature
    uint32_t current_temp;     // Current temperature

    // Core configuration
    int p_core_ids[INTEL_P_CORES];     // P-core IDs
    int e_core_ids[INTEL_E_CORES];     // E-core IDs
    int lp_e_core_ids[INTEL_LP_E_CORES]; // LP E-core IDs
} hardware_capabilities_t;

/* ============================================================================
 * NPU ACCELERATION STRUCTURES
 * ============================================================================ */

typedef struct {
    void* openvino_core;       // OpenVINO Core instance
    void* npu_device;          // NPU device handle
    void* compiled_model;      // Compiled NPU model
    void* infer_request;       // Inference request handle

    // NPU memory buffers
    void* input_tensor;        // Input tensor for hash operations
    void* output_tensor;       // Output tensor for results
    size_t tensor_size;        // Tensor size in bytes

    // Performance tracking
    uint64_t npu_operations;   // Total NPU operations
    uint64_t npu_bytes;        // Total bytes processed by NPU
    double npu_utilization;    // NPU utilization percentage
} npu_engine_t;

/* ============================================================================
 * WORK-STEALING QUEUE STRUCTURES
 * ============================================================================ */

typedef enum {
    TASK_TYPE_DIFF = 1,
    TASK_TYPE_HASH,
    TASK_TYPE_BATCH_PROCESS,
    TASK_TYPE_NPU_ACCELERATED
} task_type_t;

typedef struct {
    task_type_t type;
    char task_id[64];

    // File processing data
    const char* file_path_a;
    const char* file_path_b;
    void* data_a;
    void* data_b;
    size_t size_a;
    size_t size_b;

    // Processing options
    bool use_npu;
    bool use_avx512;
    bool use_avx2;
    int priority;

    // Results
    uint64_t lines_processed;
    uint64_t hash_result;
    double processing_time_ns;
    int assigned_core;
    bool completed;
    char error_msg[256];
} performance_task_t;

typedef struct {
    performance_task_t* tasks;
    size_t capacity;
    volatile size_t head;
    volatile size_t tail;
    pthread_mutex_t mutex;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
} work_stealing_queue_t;

/* ============================================================================
 * PERFORMANCE MONITORING STRUCTURES
 * ============================================================================ */

typedef struct {
    // Throughput metrics
    uint64_t total_lines_processed;
    uint64_t total_bytes_processed;
    uint64_t total_operations;

    // Performance breakdown
    uint64_t npu_operations;
    uint64_t avx512_operations;
    uint64_t avx2_operations;
    uint64_t scalar_operations;

    // Timing metrics
    double total_processing_time_ns;
    double avg_lines_per_second;
    double peak_lines_per_second;
    double current_lines_per_second;

    // Hardware utilization
    double p_core_utilization[INTEL_P_CORES];
    double e_core_utilization[INTEL_E_CORES];
    double npu_utilization;
    double memory_bandwidth_gbps;

    // Thermal metrics
    uint32_t max_temp_reached;
    uint32_t current_temp;
    bool thermal_throttling;

    // Efficiency metrics
    double performance_per_watt;
    double speedup_vs_baseline;
    double target_achievement_percent;
} performance_metrics_t;

/* ============================================================================
 * MAIN ENGINE CONTEXT
 * ============================================================================ */

typedef struct {
    // Hardware capabilities
    hardware_capabilities_t hw_caps;

    // NPU engine
    npu_engine_t* npu;

    // Work distribution
    work_stealing_queue_t* work_queues;
    size_t num_queues;

    // Worker threads
    pthread_t* worker_threads;
    int num_workers;
    volatile bool shutdown;

    // Performance monitoring
    performance_metrics_t metrics;
    pthread_mutex_t metrics_mutex;

    // Thermal management
    pthread_t thermal_monitor_thread;
    volatile bool thermal_shutdown;

    // Memory management
    void* memory_pool;
    size_t memory_pool_size;
    pthread_mutex_t memory_mutex;

    // NUMA awareness
    int numa_nodes;
    void* numa_memory[4];  // Up to 4 NUMA nodes
    size_t numa_sizes[4];

} shadowgit_max_perf_context_t;

/* ============================================================================
 * CORE API FUNCTIONS
 * ============================================================================ */

/**
 * Initialize the maximum performance engine
 * Returns 0 on success, negative on error
 */
int shadowgit_max_perf_init(void);

/**
 * Shutdown and cleanup the engine
 */
void shadowgit_max_perf_shutdown(void);

/**
 * Get the global context (for direct access)
 */
shadowgit_max_perf_context_t* shadowgit_max_perf_get_context(void);

/* ============================================================================
 * NPU ACCELERATION FUNCTIONS
 * ============================================================================ */

/**
 * Initialize NPU engine with OpenVINO
 * Returns 0 on success, negative on error
 */
int npu_engine_init(npu_engine_t** engine);

/**
 * Submit hash computation to NPU
 * Returns 0 on success, negative on error
 */
int npu_submit_hash_operation(
    npu_engine_t* engine,
    const void* data,
    size_t size,
    uint64_t* hash_result
);

/**
 * Submit batch processing to NPU
 * Returns 0 on success, negative on error
 */
int npu_submit_batch_process(
    npu_engine_t* engine,
    const void** data_array,
    const size_t* sizes,
    size_t count,
    uint64_t* results
);

/**
 * Cleanup NPU engine
 */
void npu_engine_destroy(npu_engine_t* engine);

/* ============================================================================
 * ENHANCED AVX2 FUNCTIONS
 * ============================================================================ */

/**
 * Enhanced AVX2 diff processing (beyond 930M lines/sec baseline)
 * Returns number of differences found
 */
size_t avx2_enhanced_diff(
    const void* data_a,
    const void* data_b,
    size_t size,
    uint64_t* line_count
);

/**
 * Enhanced AVX2 hash computation with FMA optimization
 * Returns computed hash
 */
uint64_t avx2_enhanced_hash(
    const void* data,
    size_t size
);

/**
 * Enhanced AVX2 batch processing
 * Returns number of items processed
 */
size_t avx2_enhanced_batch_process(
    const void** data_array,
    const size_t* sizes,
    size_t count,
    uint64_t* results
);

/* ============================================================================
 * WORK-STEALING QUEUE FUNCTIONS
 * ============================================================================ */

/**
 * Create work-stealing queue
 * Returns queue pointer on success, NULL on error
 */
work_stealing_queue_t* work_queue_create(size_t capacity);

/**
 * Push task to queue (producer)
 * Returns 0 on success, negative on error
 */
int work_queue_push(work_stealing_queue_t* queue, const performance_task_t* task);

/**
 * Pop task from queue (consumer)
 * Returns 0 on success, negative if empty
 */
int work_queue_pop(work_stealing_queue_t* queue, performance_task_t* task);

/**
 * Steal task from another queue
 * Returns 0 on success, negative if empty
 */
int work_queue_steal(work_stealing_queue_t* queue, performance_task_t* task);

/**
 * Destroy work-stealing queue
 */
void work_queue_destroy(work_stealing_queue_t* queue);

/* ============================================================================
 * PERFORMANCE COORDINATION FUNCTIONS
 * ============================================================================ */

/**
 * Submit high-priority task for immediate processing
 * Returns task ID on success, negative on error
 */
int submit_priority_task(
    const char* file_a,
    const char* file_b,
    bool use_npu,
    int priority
);

/**
 * Submit batch of tasks for parallel processing
 * Returns number of tasks submitted
 */
int submit_batch_tasks(
    const char** files_a,
    const char** files_b,
    size_t count,
    bool use_npu
);

/**
 * Wait for task completion
 * Returns 0 when complete, negative on timeout
 */
int wait_for_task_completion(const char* task_id, double timeout_seconds);

/**
 * Get current performance metrics
 */
performance_metrics_t get_performance_metrics(void);

/* ============================================================================
 * THERMAL MANAGEMENT FUNCTIONS
 * ============================================================================ */

/**
 * Start thermal monitoring thread
 * Returns 0 on success, negative on error
 */
int thermal_monitor_start(void);

/**
 * Stop thermal monitoring
 */
void thermal_monitor_stop(void);

/**
 * Get current thermal state
 * Returns temperature in Celsius
 */
uint32_t get_current_temperature(void);

/**
 * Check if thermal throttling is active
 * Returns true if throttling
 */
bool is_thermal_throttling(void);

/* ============================================================================
 * MEMORY MANAGEMENT FUNCTIONS
 * ============================================================================ */

/**
 * Allocate NUMA-aware memory
 * Returns pointer on success, NULL on error
 */
void* numa_alloc_memory(size_t size, int numa_node);

/**
 * Free NUMA-aware memory
 */
void numa_free_memory(void* ptr, size_t size);

/**
 * Get optimal NUMA node for current thread
 * Returns NUMA node ID
 */
int get_optimal_numa_node(void);

/* ============================================================================
 * CORE AFFINITY FUNCTIONS
 * ============================================================================ */

/**
 * Set thread affinity to specific P-core
 * Returns 0 on success, negative on error
 */
int set_thread_to_p_core(int core_id);

/**
 * Set thread affinity to specific E-core
 * Returns 0 on success, negative on error
 */
int set_thread_to_e_core(int core_id);

/**
 * Get next available P-core
 * Returns core ID
 */
int get_next_p_core(void);

/**
 * Get next available E-core
 * Returns core ID
 */
int get_next_e_core(void);

/* ============================================================================
 * PERFORMANCE TESTING FUNCTIONS
 * ============================================================================ */

/**
 * Run comprehensive performance benchmark
 * Returns 0 on success, negative on error
 */
int run_performance_benchmark(
    const char* test_data_path,
    size_t num_iterations,
    bool use_npu
);

/**
 * Test NPU acceleration specifically
 * Returns achieved lines/sec
 */
uint64_t test_npu_acceleration(
    const void* test_data,
    size_t size,
    size_t iterations
);

/**
 * Test enhanced AVX2 performance
 * Returns achieved lines/sec
 */
uint64_t test_avx2_enhanced_performance(
    const void* test_data,
    size_t size,
    size_t iterations
);

/**
 * Test multi-core scaling
 * Returns scaling factor
 */
double test_multicore_scaling(
    const void* test_data,
    size_t size,
    size_t num_threads
);

/* ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================ */

/**
 * Get high-precision timestamp
 * Returns nanoseconds since epoch
 */
uint64_t get_high_precision_timestamp(void);

/**
 * Calculate lines per second
 * Returns lines/sec rate
 */
double calculate_lines_per_second(
    uint64_t lines_processed,
    uint64_t time_ns
);

/**
 * Print detailed performance report
 */
void print_performance_report(const performance_metrics_t* metrics);

/**
 * Export performance data to JSON
 * Returns JSON string (caller must free)
 */
char* export_performance_json(const performance_metrics_t* metrics);

/* ============================================================================
 * ERROR CODES
 * ============================================================================ */

#define SHADOWGIT_MAX_PERF_SUCCESS           0
#define SHADOWGIT_MAX_PERF_ERROR_NULL_PTR   -1
#define SHADOWGIT_MAX_PERF_ERROR_ALLOC      -2
#define SHADOWGIT_MAX_PERF_ERROR_INIT       -3
#define SHADOWGIT_MAX_PERF_ERROR_NPU        -4
#define SHADOWGIT_MAX_PERF_ERROR_THERMAL    -5
#define SHADOWGIT_MAX_PERF_ERROR_NUMA       -6
#define SHADOWGIT_MAX_PERF_ERROR_AFFINITY   -7
#define SHADOWGIT_MAX_PERF_ERROR_TIMEOUT    -8

/**
 * Get error description string
 */
const char* shadowgit_max_perf_error_str(int error_code);

#ifdef __cplusplus
}
#endif

#endif /* SHADOWGIT_MAXIMUM_PERFORMANCE_H */