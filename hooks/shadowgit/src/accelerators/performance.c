/*
 * Performance Accelerator - io_uring + Thermal Management
 * Optimized for Intel Meteor Lake with real-time monitoring
 */

#include <liburing.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <sys/sysinfo.h>

#define IO_QUEUE_DEPTH 256
#define THERMAL_THRESHOLD_C 95
#define PERFORMANCE_SAMPLES 1000
#define MAX_CONCURRENT_FILES 64

typedef struct {
    struct io_uring ring;
    int thermal_state;
    double current_temp;
    uint64_t operations_completed;
    uint64_t bytes_processed;
    double avg_latency_ms;
    pthread_mutex_t stats_lock;
} perf_accelerator_t;

typedef struct {
    int fd;
    char* buffer;
    size_t size;
    off_t offset;
    struct timespec start_time;
} io_operation_t;

static perf_accelerator_t g_accelerator = {0};

// Thermal monitoring for Intel Meteor Lake
static double read_cpu_temperature() {
    FILE* temp_file = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!temp_file) return 0.0;
    
    int temp_millidegrees;
    fscanf(temp_file, "%d", &temp_millidegrees);
    fclose(temp_file);
    
    return temp_millidegrees / 1000.0;
}

static int thermal_throttling_required() {
    g_accelerator.current_temp = read_cpu_temperature();
    return g_accelerator.current_temp > THERMAL_THRESHOLD_C;
}

// io_uring initialization optimized for git operations
int perf_accelerator_init() {
    pthread_mutex_init(&g_accelerator.stats_lock, NULL);
    
    struct io_uring_params params = {0};
    params.flags = IORING_SETUP_SQPOLL | IORING_SETUP_SQ_AFF;
    params.sq_thread_cpu = 0; // Pin to P-core 0
    params.sq_thread_idle = 1000; // 1 second idle before sleep
    
    int ret = io_uring_queue_init_params(IO_QUEUE_DEPTH, &g_accelerator.ring, &params);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init failed: %s\n", strerror(-ret));
        return ret;
    }
    
    return 0;
}

// Async file read with performance tracking
int perf_read_file_async(const char* filepath, char** buffer, size_t* size) {
    struct timespec start_time;
    clock_gettime(CLOCK_MONOTONIC, &start_time);
    
    // Check thermal state
    if (thermal_throttling_required()) {
        usleep(10000); // 10ms delay for cooling
    }
    
    int fd = open(filepath, O_RDONLY);
    if (fd < 0) return -1;
    
    struct stat st;
    fstat(fd, &st);
    *size = st.st_size;
    *buffer = aligned_alloc(4096, (*size + 4095) & ~4095); // 4K aligned
    
    struct io_uring_sqe* sqe = io_uring_get_sqe(&g_accelerator.ring);
    if (!sqe) {
        close(fd);
        free(*buffer);
        return -1;
    }
    
    io_operation_t* op = malloc(sizeof(io_operation_t));
    op->fd = fd;
    op->buffer = *buffer;
    op->size = *size;
    op->offset = 0;
    op->start_time = start_time;
    
    io_uring_prep_read(sqe, fd, *buffer, *size, 0);
    io_uring_sqe_set_data(sqe, op);
    
    io_uring_submit(&g_accelerator.ring);
    
    struct io_uring_cqe* cqe;
    int ret = io_uring_wait_cqe(&g_accelerator.ring, &cqe);
    if (ret < 0) {
        close(fd);
        free(*buffer);
        free(op);
        return ret;
    }
    
    io_operation_t* completed_op = (io_operation_t*)cqe->user_data;
    int result = cqe->res;
    
    // Update performance statistics
    struct timespec end_time;
    clock_gettime(CLOCK_MONOTONIC, &end_time);
    double latency = (end_time.tv_sec - completed_op->start_time.tv_sec) * 1000.0 +
                    (end_time.tv_nsec - completed_op->start_time.tv_nsec) / 1000000.0;
    
    pthread_mutex_lock(&g_accelerator.stats_lock);
    g_accelerator.operations_completed++;
    g_accelerator.bytes_processed += *size;
    g_accelerator.avg_latency_ms = (g_accelerator.avg_latency_ms * 0.95) + (latency * 0.05);
    pthread_mutex_unlock(&g_accelerator.stats_lock);
    
    io_uring_cqe_seen(&g_accelerator.ring, cqe);
    close(completed_op->fd);
    free(completed_op);
    
    return result < 0 ? result : 0;
}

// Batch file processing with io_uring
int perf_process_files_batch(char** filepaths, int num_files, 
                           void (*process_func)(const char*, const char*, size_t)) {
    if (num_files > MAX_CONCURRENT_FILES) {
        return -1;
    }
    
    io_operation_t operations[MAX_CONCURRENT_FILES];
    struct io_uring_sqe* sqes[MAX_CONCURRENT_FILES];
    
    // Submit all read operations
    for (int i = 0; i < num_files; i++) {
        int fd = open(filepaths[i], O_RDONLY);
        if (fd < 0) continue;
        
        struct stat st;
        fstat(fd, &st);
        
        operations[i].fd = fd;
        operations[i].size = st.st_size;
        operations[i].buffer = aligned_alloc(4096, (st.st_size + 4095) & ~4095);
        operations[i].offset = 0;
        clock_gettime(CLOCK_MONOTONIC, &operations[i].start_time);
        
        sqes[i] = io_uring_get_sqe(&g_accelerator.ring);
        if (sqes[i]) {
            io_uring_prep_read(sqes[i], fd, operations[i].buffer, operations[i].size, 0);
            io_uring_sqe_set_data(sqes[i], &operations[i]);
        }
    }
    
    io_uring_submit(&g_accelerator.ring);
    
    // Wait for completions and process
    int completed = 0;
    while (completed < num_files) {
        struct io_uring_cqe* cqe;
        int ret = io_uring_wait_cqe(&g_accelerator.ring, &cqe);
        if (ret < 0) break;
        
        io_operation_t* op = (io_operation_t*)cqe->user_data;
        if (cqe->res > 0 && process_func) {
            process_func(filepaths[completed], op->buffer, op->size);
        }
        
        io_uring_cqe_seen(&g_accelerator.ring, cqe);
        close(op->fd);
        free(op->buffer);
        completed++;
    }
    
    return completed;
}

// Real-time performance monitoring
typedef struct {
    double throughput_mbps;
    double operations_per_sec;
    double avg_latency_ms;
    double cpu_temp_c;
    int thermal_throttled;
} perf_stats_t;

void perf_get_stats(perf_stats_t* stats) {
    pthread_mutex_lock(&g_accelerator.stats_lock);
    
    stats->avg_latency_ms = g_accelerator.avg_latency_ms;
    stats->operations_per_sec = g_accelerator.operations_completed / 
                               (time(NULL) - g_accelerator.operations_completed);
    stats->throughput_mbps = (g_accelerator.bytes_processed / (1024.0 * 1024.0)) /
                            (time(NULL) - g_accelerator.operations_completed);
    
    pthread_mutex_unlock(&g_accelerator.stats_lock);
    
    stats->cpu_temp_c = read_cpu_temperature();
    stats->thermal_throttled = thermal_throttling_required();
}

// Adaptive performance scaling
void perf_adaptive_scaling() {
    perf_stats_t stats;
    perf_get_stats(&stats);
    
    if (stats.thermal_throttled) {
        // Reduce queue depth and add delays
        struct io_uring_params params = {0};
        io_uring_queue_exit(&g_accelerator.ring);
        io_uring_queue_init_params(IO_QUEUE_DEPTH / 2, &g_accelerator.ring, &params);
        
        usleep(50000); // 50ms cooling period
    } else if (stats.cpu_temp_c < THERMAL_THRESHOLD_C - 10) {
        // Increase performance if well below threshold
        struct io_uring_params params = {0};
        params.flags = IORING_SETUP_SQPOLL | IORING_SETUP_SQ_AFF;
        params.sq_thread_cpu = 0;
        
        io_uring_queue_exit(&g_accelerator.ring);
        io_uring_queue_init_params(IO_QUEUE_DEPTH, &g_accelerator.ring, &params);
    }
}

// Cleanup
void perf_accelerator_cleanup() {
    io_uring_queue_exit(&g_accelerator.ring);
    pthread_mutex_destroy(&g_accelerator.stats_lock);
}

// Performance benchmark
double perf_benchmark_io_throughput(int num_files, size_t file_size) {
    char** test_files = malloc(num_files * sizeof(char*));
    
    // Create test files
    for (int i = 0; i < num_files; i++) {
        test_files[i] = malloc(256);
        snprintf(test_files[i], 256, "/tmp/perf_test_%d.tmp", i);
        
        int fd = open(test_files[i], O_CREAT | O_WRONLY, 0644);
        char* dummy_data = malloc(file_size);
        memset(dummy_data, 'A' + (i % 26), file_size);
        write(fd, dummy_data, file_size);
        close(fd);
        free(dummy_data);
    }
    
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    perf_process_files_batch(test_files, num_files, NULL);
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    double total_mb = (num_files * file_size) / (1024.0 * 1024.0);
    
    // Cleanup test files
    for (int i = 0; i < num_files; i++) {
        unlink(test_files[i]);
        free(test_files[i]);
    }
    free(test_files);
    
    return total_mb / elapsed; // MB/s throughput
}