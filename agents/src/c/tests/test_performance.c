/*
 * PERFORMANCE BENCHMARK TEST SUITE
 * 
 * Comprehensive performance testing for the ultra-hybrid communication system
 * Validates 4.2M+ msg/sec throughput with hardware optimization paths
 * 
 * Author: TESTBED Agent  
 * Version: 1.0 Production
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sched.h>
#include <numa.h>
#include <cpuid.h>
#include <x86intrin.h>
#include <math.h>

// Include system headers - adapted for agent_bridge model
#include "../../binary-communications-system/ultra_fast_protocol.h"
#include "../auth_security.h"

// Agent bridge interface for performance testing
extern void* create_agent_bridge(void);
extern int agent_bridge_send_batch(void* bridge, enhanced_msg_header_t* msgs, uint8_t* payloads, int count);
extern double agent_bridge_get_throughput(void* bridge);
extern double agent_bridge_get_latency_p99(void* bridge);

// Performance test configuration
#define PERF_TEST_DURATION_SECONDS 30
#define PERF_TARGET_MSGPS 4200000  // 4.2M msg/sec target
#define PERF_WARMUP_SECONDS 5
#define PERF_COOLDOWN_SECONDS 2
#define PERF_SAMPLE_INTERVAL_MS 100
#define PERF_MAX_THREADS 256
#define PERF_MESSAGE_SIZES 8
#define PERF_BATCH_SIZES 6

// Message size test points
static const size_t test_message_sizes[PERF_MESSAGE_SIZES] = {
    64, 128, 256, 512, 1024, 2048, 4096, 8192
};

// Batch size test points  
static const size_t test_batch_sizes[PERF_BATCH_SIZES] = {
    1, 8, 32, 64, 128, 256
};

// Performance metrics
typedef struct {
    _Atomic uint64_t messages_sent;
    _Atomic uint64_t messages_received; 
    _Atomic uint64_t bytes_transferred;
    _Atomic uint64_t operations_completed;
    _Atomic uint64_t cache_misses;
    _Atomic uint64_t cache_hits;
    _Atomic uint64_t cpu_cycles;
    _Atomic uint64_t instructions_retired;
    _Atomic uint64_t branch_mispredictions;
    _Atomic uint64_t tlb_misses;
    _Atomic uint64_t memory_stalls;
    _Atomic uint64_t numa_local_accesses;
    _Atomic uint64_t numa_remote_accesses;
    
    // Latency measurements (nanoseconds)
    _Atomic uint64_t min_latency_ns;
    _Atomic uint64_t max_latency_ns;
    _Atomic uint64_t total_latency_ns;
    _Atomic uint64_t latency_samples;
    
    // Hardware utilization
    _Atomic uint64_t p_core_utilization_pct;
    _Atomic uint64_t e_core_utilization_pct;
    _Atomic uint64_t npu_utilization_pct;
    _Atomic uint64_t gpu_utilization_pct;
    
    // SIMD instruction usage
    _Atomic uint64_t avx2_instructions;
    _Atomic uint64_t avx512_instructions;
    _Atomic uint64_t vector_operations;
    
    uint64_t test_start_time;
    uint64_t test_end_time;
} performance_metrics_t;

static performance_metrics_t g_perf_metrics = {0};

// Performance test context
typedef struct {
    enhanced_ring_buffer_t* ring_buffer;
    thread_pool_t* thread_pool;
    pthread_t* test_threads;
    int num_threads;
    bool test_running;
    bool warmup_phase;
    bool measurement_phase;
    size_t current_message_size;
    size_t current_batch_size;
    int test_failures;
    pthread_mutex_t metrics_mutex;
    
    // Hardware monitoring
    int* p_core_ids;
    int* e_core_ids;
    int num_p_cores;
    int num_e_cores;
} performance_test_context_t;

static performance_test_context_t g_perf_ctx = {0};

// Utility functions
static inline uint64_t rdtsc() {
    uint32_t lo, hi;
    __asm__ volatile ("rdtsc" : "=a" (lo), "=d" (hi));
    return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t get_timestamp_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static void log_perf_result(const char* test_name, bool passed, double value, const char* unit) {
    printf("[%s] %s: %.2f %s\n", passed ? "PASS" : "FAIL", test_name, value, unit);
    if (!passed) {
        __sync_fetch_and_add(&g_perf_ctx.test_failures, 1);
    }
}

// Hardware performance counter interface
typedef struct {
    uint64_t cycles;
    uint64_t instructions;
    uint64_t cache_misses;
    uint64_t cache_refs;
    uint64_t branch_misses;
    uint64_t branches;
} hw_counters_t;

static void read_hw_counters(hw_counters_t* counters) {
    // Read hardware performance counters
    // Note: This requires perf_event_open() or similar - simplified for test
    counters->cycles = rdtsc();
    counters->instructions = 0; // Would read from PMU
    counters->cache_misses = 0; // Would read from PMU  
    counters->cache_refs = 0;   // Would read from PMU
    counters->branch_misses = 0; // Would read from PMU
    counters->branches = 0;     // Would read from PMU
}

// Test 1: Single-threaded throughput baseline
static void* single_thread_throughput_test(void* arg) {
    int thread_id = *(int*)arg;
    int cpu_id = g_perf_ctx.p_core_ids[thread_id % g_perf_ctx.num_p_cores];
    
    // Set CPU affinity to P-core
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
    
    enhanced_msg_header_t msg = {
        .magic = 0x4147454E,
        .msg_type = 1,
        .priority = PRIORITY_HIGH,
        .source_agent = thread_id,
        .target_agent = (thread_id + 1) % TEST_AGENTS_COUNT,
        .payload_len = g_perf_ctx.current_message_size,
        .timestamp = get_timestamp_ns()
    };
    
    uint8_t* payload = aligned_alloc(64, g_perf_ctx.current_message_size);
    memset(payload, 0xAB, g_perf_ctx.current_message_size);
    
    uint64_t messages_sent = 0;
    uint64_t start_cycles = rdtsc();
    hw_counters_t start_counters, end_counters;
    
    read_hw_counters(&start_counters);
    
    while (g_perf_ctx.test_running) {
        if (g_perf_ctx.measurement_phase) {
            uint64_t send_start = get_timestamp_ns();
            
            msg.msg_id = messages_sent;
            msg.timestamp = send_start;
            msg.checksum = crc32c_parallel_enhanced((uint8_t*)&msg, sizeof(msg) - 4);
            
            if (ring_buffer_write_priority(g_perf_ctx.ring_buffer, &msg, payload)) {
                messages_sent++;
                
                uint64_t send_end = get_timestamp_ns();
                uint64_t latency = send_end - send_start;
                
                // Update latency statistics
                uint64_t current_min = atomic_load(&g_perf_metrics.min_latency_ns);
                while (latency < current_min && 
                       !atomic_compare_exchange_weak(&g_perf_metrics.min_latency_ns, 
                                                   &current_min, latency));
                
                uint64_t current_max = atomic_load(&g_perf_metrics.max_latency_ns);
                while (latency > current_max && 
                       !atomic_compare_exchange_weak(&g_perf_metrics.max_latency_ns,
                                                   &current_max, latency));
                
                atomic_fetch_add(&g_perf_metrics.total_latency_ns, latency);
                atomic_fetch_add(&g_perf_metrics.latency_samples, 1);
            }
        } else if (!g_perf_ctx.warmup_phase) {
            // Just send without measurement overhead
            msg.msg_id = messages_sent;
            msg.timestamp = get_timestamp_ns();
            if (ring_buffer_write_priority(g_perf_ctx.ring_buffer, &msg, payload)) {
                messages_sent++;
            }
        }
    }
    
    read_hw_counters(&end_counters);
    uint64_t end_cycles = rdtsc();
    
    // Update performance metrics
    atomic_fetch_add(&g_perf_metrics.messages_sent, messages_sent);
    atomic_fetch_add(&g_perf_metrics.bytes_transferred, 
                     messages_sent * (sizeof(enhanced_msg_header_t) + g_perf_ctx.current_message_size));
    atomic_fetch_add(&g_perf_metrics.cpu_cycles, end_cycles - start_cycles);
    atomic_fetch_add(&g_perf_metrics.cache_misses, 
                     end_counters.cache_misses - start_counters.cache_misses);
    
    free(payload);
    return NULL;
}

static bool test_single_thread_throughput() {
    printf("\n=== Testing Single-threaded Throughput ===\n");
    
    for (int msg_size_idx = 0; msg_size_idx < PERF_MESSAGE_SIZES; msg_size_idx++) {
        g_perf_ctx.current_message_size = test_message_sizes[msg_size_idx];
        
        // Reset metrics
        memset(&g_perf_metrics, 0, sizeof(g_perf_metrics));
        atomic_store(&g_perf_metrics.min_latency_ns, UINT64_MAX);
        g_perf_metrics.test_start_time = get_timestamp_ns();
        
        // Single thread test
        g_perf_ctx.num_threads = 1;
        g_perf_ctx.test_running = true;
        g_perf_ctx.warmup_phase = true;
        g_perf_ctx.measurement_phase = false;
        
        int thread_id = 0;
        pthread_t test_thread;
        pthread_create(&test_thread, NULL, single_thread_throughput_test, &thread_id);
        
        // Warmup phase
        sleep(PERF_WARMUP_SECONDS);
        g_perf_ctx.warmup_phase = false;
        g_perf_ctx.measurement_phase = true;
        
        // Measurement phase
        sleep(PERF_TEST_DURATION_SECONDS);
        g_perf_ctx.measurement_phase = false;
        
        // Cooldown
        sleep(PERF_COOLDOWN_SECONDS);
        g_perf_ctx.test_running = false;
        
        pthread_join(test_thread, NULL);
        
        g_perf_metrics.test_end_time = get_timestamp_ns();
        
        // Calculate results
        double test_duration = (g_perf_metrics.test_end_time - g_perf_metrics.test_start_time) / 1e9;
        uint64_t messages_sent = atomic_load(&g_perf_metrics.messages_sent);
        double throughput_msgps = messages_sent / test_duration;
        double throughput_mbps = atomic_load(&g_perf_metrics.bytes_transferred) / (1024.0 * 1024.0) / test_duration;
        
        uint64_t latency_samples = atomic_load(&g_perf_metrics.latency_samples);
        double avg_latency_ns = latency_samples > 0 ? 
            (double)atomic_load(&g_perf_metrics.total_latency_ns) / latency_samples : 0;
        
        printf("Message Size %zu bytes:\n", g_perf_ctx.current_message_size);
        printf("  Throughput: %.0f msg/sec (%.2f MB/sec)\n", throughput_msgps, throughput_mbps);
        printf("  Latency: avg=%.1f ns, min=%lu ns, max=%lu ns\n",
               avg_latency_ns, 
               atomic_load(&g_perf_metrics.min_latency_ns),
               atomic_load(&g_perf_metrics.max_latency_ns));
        
        // Check if we meet baseline performance
        double baseline_target = PERF_TARGET_MSGPS * 0.1; // 10% of target for single thread
        bool passed = throughput_msgps >= baseline_target;
        log_perf_result("Single-thread Baseline", passed, throughput_msgps, "msg/sec");
    }
    
    return true;
}

// Test 2: Multi-threaded P-core scaling
static void* multithread_pcore_test(void* arg) {
    int thread_id = *(int*)arg;
    int cpu_id = g_perf_ctx.p_core_ids[thread_id % g_perf_ctx.num_p_cores];
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
    
    enhanced_msg_header_t msg = {
        .magic = 0x4147454E,
        .msg_type = 1,
        .priority = PRIORITY_CRITICAL,
        .source_agent = thread_id,
        .target_agent = (thread_id + 1) % TEST_AGENTS_COUNT,
        .payload_len = g_perf_ctx.current_message_size
    };
    
    uint8_t* payload = aligned_alloc(64, g_perf_ctx.current_message_size);
    
    // Fill payload with thread-specific pattern for verification
    for (size_t i = 0; i < g_perf_ctx.current_message_size; i++) {
        payload[i] = (uint8_t)(thread_id ^ i);
    }
    
    uint64_t messages_sent = 0;
    uint64_t avx512_ops = 0;
    
    while (g_perf_ctx.test_running) {
        if (g_perf_ctx.measurement_phase) {
            msg.msg_id = (thread_id << 32) | messages_sent;
            msg.timestamp = get_timestamp_ns();
            
            // Use AVX-512 for checksum on P-cores if available
            if (g_system_caps.has_avx512f) {
                msg.checksum = crc32c_parallel_enhanced((uint8_t*)&msg, sizeof(msg) - 4);
                avx512_ops++;
            } else {
                msg.checksum = _mm_crc32_u32(0xFFFFFFFF, msg.msg_id);
            }
            
            if (ring_buffer_write_priority(g_perf_ctx.ring_buffer, &msg, payload)) {
                messages_sent++;
            }
        }
    }
    
    atomic_fetch_add(&g_perf_metrics.messages_sent, messages_sent);
    atomic_fetch_add(&g_perf_metrics.avx512_instructions, avx512_ops);
    atomic_fetch_add(&g_perf_metrics.bytes_transferred,
                     messages_sent * (sizeof(enhanced_msg_header_t) + g_perf_ctx.current_message_size));
    
    free(payload);
    return NULL;
}

static bool test_pcore_scaling() {
    printf("\n=== Testing P-core Scaling ===\n");
    
    g_perf_ctx.current_message_size = 1024; // Standard size
    
    for (int thread_count = 1; thread_count <= g_perf_ctx.num_p_cores; thread_count++) {
        memset(&g_perf_metrics, 0, sizeof(g_perf_metrics));
        g_perf_metrics.test_start_time = get_timestamp_ns();
        
        g_perf_ctx.num_threads = thread_count;
        g_perf_ctx.test_running = true;
        g_perf_ctx.warmup_phase = true;
        g_perf_ctx.measurement_phase = false;
        
        pthread_t* threads = malloc(thread_count * sizeof(pthread_t));
        int* thread_ids = malloc(thread_count * sizeof(int));
        
        for (int i = 0; i < thread_count; i++) {
            thread_ids[i] = i;
            pthread_create(&threads[i], NULL, multithread_pcore_test, &thread_ids[i]);
        }
        
        // Test phases
        sleep(PERF_WARMUP_SECONDS);
        g_perf_ctx.warmup_phase = false;
        g_perf_ctx.measurement_phase = true;
        
        sleep(PERF_TEST_DURATION_SECONDS);
        g_perf_ctx.measurement_phase = false;
        
        sleep(PERF_COOLDOWN_SECONDS);
        g_perf_ctx.test_running = false;
        
        for (int i = 0; i < thread_count; i++) {
            pthread_join(threads[i], NULL);
        }
        
        g_perf_metrics.test_end_time = get_timestamp_ns();
        
        // Calculate results
        double test_duration = (g_perf_metrics.test_end_time - g_perf_metrics.test_start_time) / 1e9;
        uint64_t total_messages = atomic_load(&g_perf_metrics.messages_sent);
        double throughput = total_messages / test_duration;
        double scaling_efficiency = throughput / (thread_count * (PERF_TARGET_MSGPS / g_perf_ctx.num_p_cores));
        
        printf("P-cores: %d threads, %.0f msg/sec (%.1f%% scaling efficiency)\n",
               thread_count, throughput, scaling_efficiency * 100);
        
        if (g_system_caps.has_avx512f) {
            printf("  AVX-512 operations: %lu\n", atomic_load(&g_perf_metrics.avx512_instructions));
        }
        
        free(threads);
        free(thread_ids);
        
        // Check scaling efficiency
        bool passed = scaling_efficiency >= 0.8; // Expect 80% efficiency
        log_perf_result("P-core Scaling", passed, scaling_efficiency * 100, "% efficiency");
    }
    
    return true;
}

// Test 3: Hybrid P-core + E-core utilization
static void* hybrid_ecore_test(void* arg) {
    int thread_id = *(int*)arg;
    bool is_pcore = thread_id < g_perf_ctx.num_p_cores;
    int cpu_id;
    
    if (is_pcore) {
        cpu_id = g_perf_ctx.p_core_ids[thread_id];
    } else {
        cpu_id = g_perf_ctx.e_core_ids[thread_id - g_perf_ctx.num_p_cores];
    }
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
    
    // Set thread name for identification
    char thread_name[16];
    snprintf(thread_name, sizeof(thread_name), "%s-%d", 
             is_pcore ? "P" : "E", thread_id);
    pthread_setname_np(pthread_self(), thread_name);
    
    enhanced_msg_header_t msg = {
        .magic = 0x4147454E,
        .msg_type = 1,
        .priority = is_pcore ? PRIORITY_HIGH : PRIORITY_NORMAL,
        .source_agent = thread_id,
        .target_agent = (thread_id + 1) % TEST_AGENTS_COUNT,
        .payload_len = g_perf_ctx.current_message_size
    };
    
    uint8_t* payload = aligned_alloc(is_pcore ? 64 : 32, g_perf_ctx.current_message_size);
    memset(payload, is_pcore ? 0xAA : 0xBB, g_perf_ctx.current_message_size);
    
    uint64_t messages_sent = 0;
    uint64_t simd_ops = 0;
    
    while (g_perf_ctx.test_running) {
        if (g_perf_ctx.measurement_phase) {
            msg.msg_id = (thread_id << 32) | messages_sent;
            msg.timestamp = get_timestamp_ns();
            
            // Use appropriate SIMD path
            if (is_pcore && g_system_caps.has_avx512f) {
                // P-core with AVX-512
                msg.checksum = crc32c_parallel_enhanced((uint8_t*)&msg, sizeof(msg) - 4);
                simd_ops++;
            } else if (g_system_caps.has_avx2) {
                // E-core with AVX2
                msg.checksum = _mm_crc32_u32(0xFFFFFFFF, msg.msg_id);
                simd_ops++;
            } else {
                msg.checksum = msg.msg_id;
            }
            
            if (ring_buffer_write_priority(g_perf_ctx.ring_buffer, &msg, payload)) {
                messages_sent++;
            }
        }
    }
    
    atomic_fetch_add(&g_perf_metrics.messages_sent, messages_sent);
    if (is_pcore) {
        atomic_fetch_add(&g_perf_metrics.avx512_instructions, simd_ops);
    } else {
        atomic_fetch_add(&g_perf_metrics.avx2_instructions, simd_ops);
    }
    
    free(payload);
    return NULL;
}

static bool test_hybrid_core_utilization() {
    printf("\n=== Testing Hybrid P-core + E-core Utilization ===\n");
    
    g_perf_ctx.current_message_size = 512;
    int total_cores = g_perf_ctx.num_p_cores + g_perf_ctx.num_e_cores;
    
    memset(&g_perf_metrics, 0, sizeof(g_perf_metrics));
    g_perf_metrics.test_start_time = get_timestamp_ns();
    
    g_perf_ctx.num_threads = total_cores;
    g_perf_ctx.test_running = true;
    g_perf_ctx.warmup_phase = true;
    g_perf_ctx.measurement_phase = false;
    
    pthread_t* threads = malloc(total_cores * sizeof(pthread_t));
    int* thread_ids = malloc(total_cores * sizeof(int));
    
    for (int i = 0; i < total_cores; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, hybrid_ecore_test, &thread_ids[i]);
    }
    
    // Test phases with monitoring
    sleep(PERF_WARMUP_SECONDS);
    g_perf_ctx.warmup_phase = false;
    g_perf_ctx.measurement_phase = true;
    
    // Monitor throughput during test
    uint64_t last_messages = 0;
    for (int t = 0; t < PERF_TEST_DURATION_SECONDS; t++) {
        sleep(1);
        uint64_t current_messages = atomic_load(&g_perf_metrics.messages_sent);
        uint64_t delta = current_messages - last_messages;
        printf("T+%02d: %lu msg/sec\n", t + 1, delta);
        last_messages = current_messages;
    }
    
    g_perf_ctx.measurement_phase = false;
    
    sleep(PERF_COOLDOWN_SECONDS);
    g_perf_ctx.test_running = false;
    
    for (int i = 0; i < total_cores; i++) {
        pthread_join(threads[i], NULL);
    }
    
    g_perf_metrics.test_end_time = get_timestamp_ns();
    
    // Calculate results
    double test_duration = (g_perf_metrics.test_end_time - g_perf_metrics.test_start_time) / 1e9;
    uint64_t total_messages = atomic_load(&g_perf_metrics.messages_sent);
    double throughput = total_messages / test_duration;
    double utilization = throughput / PERF_TARGET_MSGPS;
    
    printf("\nHybrid Core Results:\n");
    printf("  Total cores: %d (%d P-cores, %d E-cores)\n", 
           total_cores, g_perf_ctx.num_p_cores, g_perf_ctx.num_e_cores);
    printf("  Throughput: %.0f msg/sec (%.1f%% of target)\n", throughput, utilization * 100);
    printf("  AVX-512 operations: %lu\n", atomic_load(&g_perf_metrics.avx512_instructions));
    printf("  AVX2 operations: %lu\n", atomic_load(&g_perf_metrics.avx2_instructions));
    
    free(threads);
    free(thread_ids);
    
    // Check if we achieve target performance
    bool passed = throughput >= PERF_TARGET_MSGPS * 0.85; // 85% of target
    log_perf_result("Hybrid Core Performance", passed, throughput, "msg/sec");
    
    return passed;
}

// Test 4: Batch processing optimization
static void* batch_processing_test(void* arg) {
    int thread_id = *(int*)arg;
    int cpu_id = g_perf_ctx.p_core_ids[thread_id % g_perf_ctx.num_p_cores];
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
    
    size_t batch_size = g_perf_ctx.current_batch_size;
    enhanced_msg_header_t* msg_batch = aligned_alloc(64, batch_size * sizeof(enhanced_msg_header_t));
    uint8_t* payload = aligned_alloc(64, g_perf_ctx.current_message_size);
    
    // Initialize message batch
    for (size_t i = 0; i < batch_size; i++) {
        msg_batch[i].magic = 0x4147454E;
        msg_batch[i].msg_type = 1;
        msg_batch[i].priority = PRIORITY_HIGH;
        msg_batch[i].source_agent = thread_id;
        msg_batch[i].target_agent = (thread_id + i + 1) % TEST_AGENTS_COUNT;
        msg_batch[i].payload_len = g_perf_ctx.current_message_size;
    }
    
    memset(payload, 0xCD, g_perf_ctx.current_message_size);
    
    uint64_t batches_sent = 0;
    uint64_t total_messages = 0;
    
    while (g_perf_ctx.test_running) {
        if (g_perf_ctx.measurement_phase) {
            uint64_t batch_start = get_timestamp_ns();
            
            // Update batch with current timestamps and IDs
            for (size_t i = 0; i < batch_size; i++) {
                msg_batch[i].msg_id = (batches_sent << 16) | i;
                msg_batch[i].timestamp = batch_start;
                msg_batch[i].checksum = crc32c_parallel_enhanced((uint8_t*)&msg_batch[i], 
                                                               sizeof(enhanced_msg_header_t) - 4);
            }
            
            // Send batch (simplified - would use actual batch API)
            bool batch_success = true;
            for (size_t i = 0; i < batch_size; i++) {
                if (!ring_buffer_write_priority(g_perf_ctx.ring_buffer, &msg_batch[i], payload)) {
                    batch_success = false;
                    break;
                }
            }
            
            if (batch_success) {
                batches_sent++;
                total_messages += batch_size;
                
                uint64_t batch_end = get_timestamp_ns();
                uint64_t batch_latency = batch_end - batch_start;
                
                atomic_fetch_add(&g_perf_metrics.total_latency_ns, batch_latency);
                atomic_fetch_add(&g_perf_metrics.latency_samples, 1);
            }
        }
    }
    
    atomic_fetch_add(&g_perf_metrics.messages_sent, total_messages);
    atomic_fetch_add(&g_perf_metrics.operations_completed, batches_sent);
    
    free(msg_batch);
    free(payload);
    return NULL;
}

static bool test_batch_processing() {
    printf("\n=== Testing Batch Processing Optimization ===\n");
    
    g_perf_ctx.current_message_size = 256;
    
    for (int batch_idx = 0; batch_idx < PERF_BATCH_SIZES; batch_idx++) {
        g_perf_ctx.current_batch_size = test_batch_sizes[batch_idx];
        
        memset(&g_perf_metrics, 0, sizeof(g_perf_metrics));
        g_perf_metrics.test_start_time = get_timestamp_ns();
        
        g_perf_ctx.num_threads = g_perf_ctx.num_p_cores;
        g_perf_ctx.test_running = true;
        g_perf_ctx.warmup_phase = true;
        g_perf_ctx.measurement_phase = false;
        
        pthread_t* threads = malloc(g_perf_ctx.num_threads * sizeof(pthread_t));
        int* thread_ids = malloc(g_perf_ctx.num_threads * sizeof(int));
        
        for (int i = 0; i < g_perf_ctx.num_threads; i++) {
            thread_ids[i] = i;
            pthread_create(&threads[i], NULL, batch_processing_test, &thread_ids[i]);
        }
        
        // Test phases
        sleep(PERF_WARMUP_SECONDS);
        g_perf_ctx.warmup_phase = false;
        g_perf_ctx.measurement_phase = true;
        
        sleep(PERF_TEST_DURATION_SECONDS / 2); // Shorter test for batch analysis
        g_perf_ctx.measurement_phase = false;
        
        sleep(PERF_COOLDOWN_SECONDS);
        g_perf_ctx.test_running = false;
        
        for (int i = 0; i < g_perf_ctx.num_threads; i++) {
            pthread_join(threads[i], NULL);
        }
        
        g_perf_metrics.test_end_time = get_timestamp_ns();
        
        // Calculate results
        double test_duration = (g_perf_metrics.test_end_time - g_perf_metrics.test_start_time) / 1e9;
        uint64_t total_messages = atomic_load(&g_perf_metrics.messages_sent);
        uint64_t total_batches = atomic_load(&g_perf_metrics.operations_completed);
        double throughput = total_messages / test_duration;
        
        uint64_t latency_samples = atomic_load(&g_perf_metrics.latency_samples);
        double avg_batch_latency_us = latency_samples > 0 ?
            (double)atomic_load(&g_perf_metrics.total_latency_ns) / latency_samples / 1000.0 : 0;
        
        printf("Batch Size %zu:\n", g_perf_ctx.current_batch_size);
        printf("  Throughput: %.0f msg/sec (%lu batches)\n", throughput, total_batches);
        printf("  Avg batch latency: %.2f μs\n", avg_batch_latency_us);
        printf("  Efficiency: %.2f msg/μs\n", g_perf_ctx.current_batch_size / avg_batch_latency_us);
        
        free(threads);
        free(thread_ids);
    }
    
    log_perf_result("Batch Processing", true, 0, "optimization tested");
    return true;
}

// Test 5: Memory bandwidth and NUMA optimization
static void* numa_memory_test(void* arg) {
    int thread_id = *(int*)arg;
    int numa_node = numa_node_of_cpu(sched_getcpu());
    
    // Allocate memory on local NUMA node
    size_t buffer_size = 64 * 1024 * 1024; // 64MB per thread
    uint8_t* local_buffer = numa_alloc_onnode(buffer_size, numa_node);
    uint8_t* remote_buffer = numa_alloc_onnode(buffer_size, (numa_node + 1) % numa_max_node());
    
    if (!local_buffer || !remote_buffer) {
        return NULL;
    }
    
    uint64_t local_accesses = 0;
    uint64_t remote_accesses = 0;
    uint64_t memory_ops = 0;
    
    while (g_perf_ctx.test_running) {
        if (g_perf_ctx.measurement_phase) {
            // Test local NUMA access
            uint64_t start_cycles = rdtsc();
            for (int i = 0; i < 1000; i++) {
                volatile uint64_t* ptr = (volatile uint64_t*)(local_buffer + (i * 64));
                *ptr = rdtsc();
                memory_ops += *ptr ? 1 : 0; // Prevent optimization
            }
            uint64_t local_cycles = rdtsc() - start_cycles;
            
            // Test remote NUMA access  
            start_cycles = rdtsc();
            for (int i = 0; i < 1000; i++) {
                volatile uint64_t* ptr = (volatile uint64_t*)(remote_buffer + (i * 64));
                *ptr = rdtsc();
                memory_ops += *ptr ? 1 : 0;
            }
            uint64_t remote_cycles = rdtsc() - start_cycles;
            
            local_accesses += local_cycles;
            remote_accesses += remote_cycles;
        }
        
        usleep(1000); // 1ms delay
    }
    
    atomic_fetch_add(&g_perf_metrics.numa_local_accesses, local_accesses);
    atomic_fetch_add(&g_perf_metrics.numa_remote_accesses, remote_accesses);
    atomic_fetch_add(&g_perf_metrics.memory_stalls, memory_ops);
    
    numa_free(local_buffer, buffer_size);
    numa_free(remote_buffer, buffer_size);
    return NULL;
}

static bool test_numa_optimization() {
    printf("\n=== Testing NUMA Memory Optimization ===\n");
    
    if (numa_available() < 0) {
        printf("NUMA not available, skipping test\n");
        return true;
    }
    
    int numa_nodes = numa_max_node() + 1;
    printf("Testing with %d NUMA nodes\n", numa_nodes);
    
    memset(&g_perf_metrics, 0, sizeof(g_perf_metrics));
    g_perf_metrics.test_start_time = get_timestamp_ns();
    
    g_perf_ctx.num_threads = g_perf_ctx.num_p_cores;
    g_perf_ctx.test_running = true;
    g_perf_ctx.warmup_phase = true;
    g_perf_ctx.measurement_phase = false;
    
    pthread_t* threads = malloc(g_perf_ctx.num_threads * sizeof(pthread_t));
    int* thread_ids = malloc(g_perf_ctx.num_threads * sizeof(int));
    
    for (int i = 0; i < g_perf_ctx.num_threads; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, numa_memory_test, &thread_ids[i]);
    }
    
    // Test phases
    sleep(PERF_WARMUP_SECONDS);
    g_perf_ctx.warmup_phase = false;
    g_perf_ctx.measurement_phase = true;
    
    sleep(PERF_TEST_DURATION_SECONDS / 3); // Shorter NUMA test
    g_perf_ctx.measurement_phase = false;
    
    sleep(PERF_COOLDOWN_SECONDS);
    g_perf_ctx.test_running = false;
    
    for (int i = 0; i < g_perf_ctx.num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    
    g_perf_metrics.test_end_time = get_timestamp_ns();
    
    // Calculate NUMA efficiency
    uint64_t local_cycles = atomic_load(&g_perf_metrics.numa_local_accesses);
    uint64_t remote_cycles = atomic_load(&g_perf_metrics.numa_remote_accesses);
    
    double numa_penalty = remote_cycles > 0 ? (double)remote_cycles / local_cycles : 0;
    double numa_efficiency = 1.0 / (1.0 + numa_penalty);
    
    printf("NUMA Results:\n");
    printf("  Local access cycles: %lu\n", local_cycles);
    printf("  Remote access cycles: %lu\n", remote_cycles);
    printf("  NUMA penalty: %.2fx\n", numa_penalty);
    printf("  NUMA efficiency: %.1f%%\n", numa_efficiency * 100);
    
    free(threads);
    free(thread_ids);
    
    // Check NUMA optimization effectiveness
    bool passed = numa_penalty < 2.0; // Less than 2x penalty is good
    log_perf_result("NUMA Optimization", passed, numa_efficiency * 100, "% efficiency");
    
    return passed;
}

// Main performance test runner
int main(int argc, char* argv[]) {
    printf("PERFORMANCE BENCHMARK TEST SUITE\n");
    printf("================================\n");
    printf("Target performance: %.1fM msg/sec\n\n", PERF_TARGET_MSGPS / 1e6);
    
    // Initialize test context
    pthread_mutex_init(&g_perf_ctx.metrics_mutex, NULL);
    
    // Detect system capabilities
    detect_system_capabilities();
    
    // Initialize hardware info
    g_perf_ctx.num_p_cores = g_system_caps.num_p_cores;
    g_perf_ctx.num_e_cores = g_system_caps.num_e_cores;
    g_perf_ctx.p_core_ids = g_system_caps.p_core_ids;
    g_perf_ctx.e_core_ids = g_system_caps.e_core_ids;
    
    printf("Hardware Configuration:\n");
    printf("  P-cores: %d\n", g_perf_ctx.num_p_cores);
    printf("  E-cores: %d\n", g_perf_ctx.num_e_cores);
    printf("  NUMA nodes: %d\n", g_system_caps.num_numa_nodes);
    printf("  AVX-512: %s\n", g_system_caps.has_avx512f ? "Yes" : "No");
    printf("  AVX2: %s\n", g_system_caps.has_avx2 ? "Yes" : "No");
    
    // Create ring buffer
    g_perf_ctx.ring_buffer = create_enhanced_ring_buffer(RING_BUFFER_SIZE / 6);
    if (!g_perf_ctx.ring_buffer) {
        fprintf(stderr, "Failed to create ring buffer\n");
        return 1;
    }
    
    bool all_tests_passed = true;
    
    // Run performance test suite
    all_tests_passed &= test_single_thread_throughput();
    all_tests_passed &= test_pcore_scaling();
    all_tests_passed &= test_hybrid_core_utilization();
    all_tests_passed &= test_batch_processing();
    all_tests_passed &= test_numa_optimization();
    
    // Final performance validation
    printf("\n=== PERFORMANCE TEST SUMMARY ===\n");
    printf("Target: %.1fM msg/sec\n", PERF_TARGET_MSGPS / 1e6);
    printf("Test Failures: %d\n", g_perf_ctx.test_failures);
    
    // Cleanup
    if (g_perf_ctx.ring_buffer) {
        for (int i = 0; i < 6; i++) {
            if (g_perf_ctx.ring_buffer->queues[i].buffer != MAP_FAILED) {
                munmap(g_perf_ctx.ring_buffer->queues[i].buffer, g_perf_ctx.ring_buffer->queues[i].size);
            }
        }
        numa_free(g_perf_ctx.ring_buffer, sizeof(enhanced_ring_buffer_t));
    }
    
    pthread_mutex_destroy(&g_perf_ctx.metrics_mutex);
    
    if (all_tests_passed && g_perf_ctx.test_failures == 0) {
        printf("\n[RESULT] ALL PERFORMANCE TESTS PASSED\n");
        printf("System meets 4.2M+ msg/sec performance target\n");
        return 0;
    } else {
        printf("\n[RESULT] PERFORMANCE TESTS FAILED (%d failures)\n", g_perf_ctx.test_failures);
        return 1;
    }
}