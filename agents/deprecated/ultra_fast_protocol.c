/*
 * ULTRA-FAST BINARY PROTOCOL FOR AGENT COMMUNICATION
 * High-performance C implementation with zero-copy, SIMD, and lock-free operations
 * Achieves sub-microsecond latency and millions of messages per second
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <errno.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <immintrin.h>  // SIMD intrinsics
#include <stdatomic.h>

// Protocol constants
#define MAGIC_BYTES 0x4147  // 'AG' for Agent
#define PROTOCOL_VERSION 3
#define MAX_AGENTS 65535
#define MAX_PAYLOAD_SIZE (16 * 1024 * 1024)  // 16MB
#define CACHE_LINE_SIZE 64
#define SIMD_ALIGNMENT 32
#define RING_BUFFER_SIZE (64 * 1024 * 1024)  // 64MB

// Message types (compact encoding)
typedef enum {
    MSG_REQUEST = 0x01,
    MSG_RESPONSE = 0x02,
    MSG_BROADCAST = 0x03,
    MSG_HEARTBEAT = 0x04,
    MSG_ACK = 0x05,
    MSG_ERROR = 0x06,
    MSG_VETO = 0x07,
    MSG_TASK = 0x08,
    MSG_RESULT = 0x09,
    MSG_STATE_SYNC = 0x0A,
    MSG_RESOURCE_REQ = 0x0B,
    MSG_RESOURCE_RESP = 0x0C,
    MSG_DISCOVERY = 0x0D,
    MSG_SHUTDOWN = 0x0E,
    MSG_EMERGENCY = 0x0F
} message_type_t;

// Priority levels
typedef enum {
    PRIORITY_CRITICAL = 0x00,
    PRIORITY_HIGH = 0x01,
    PRIORITY_MEDIUM = 0x02,
    PRIORITY_LOW = 0x03,
    PRIORITY_BACKGROUND = 0x04
} priority_t;

// Compression types
typedef enum {
    COMPRESS_NONE = 0x00,
    COMPRESS_LZ4 = 0x01,
    COMPRESS_ZSTD = 0x02,
    COMPRESS_SNAPPY = 0x03
} compression_t;

// Aligned for cache line and SIMD
typedef struct __attribute__((aligned(CACHE_LINE_SIZE))) {
    uint16_t magic;
    uint8_t version;
    uint8_t flags;
    uint16_t msg_type;
    uint8_t priority;
    uint8_t reserved1;
    uint32_t msg_id;
    uint32_t timestamp;
    uint16_t source_agent;
    uint8_t target_count;
    uint8_t reserved2;
    uint32_t payload_len;
    uint32_t checksum;
} message_header_t;

// Agent ID mapping structure
typedef struct {
    char name[64];
    uint16_t id;
} agent_mapping_t;

// Lock-free ring buffer for ultra-fast IPC
typedef struct __attribute__((aligned(CACHE_LINE_SIZE))) {
    _Atomic uint64_t write_pos;
    char padding1[CACHE_LINE_SIZE - sizeof(uint64_t)];
    
    _Atomic uint64_t read_pos;
    char padding2[CACHE_LINE_SIZE - sizeof(uint64_t)];
    
    _Atomic uint64_t cached_write_pos;
    char padding3[CACHE_LINE_SIZE - sizeof(uint64_t)];
    
    _Atomic uint64_t cached_read_pos;
    char padding4[CACHE_LINE_SIZE - sizeof(uint64_t)];
    
    uint32_t size;
    uint32_t mask;
    uint8_t* buffer;
} ring_buffer_t;

// Message pool for zero allocation
typedef struct {
    void* pool;
    size_t pool_size;
    size_t chunk_size;
    _Atomic uint32_t free_list;
    uint32_t* next_free;
} message_pool_t;

// Global agent registry
static agent_mapping_t agent_registry[MAX_AGENTS];
static _Atomic uint16_t next_agent_id = 1;
static pthread_rwlock_t registry_lock = PTHREAD_RWLOCK_INITIALIZER;

// Performance counters
static _Atomic uint64_t messages_sent = 0;
static _Atomic uint64_t messages_received = 0;
static _Atomic uint64_t bytes_sent = 0;
static _Atomic uint64_t bytes_received = 0;

// Initialize core agents
static void init_agent_registry(void) {
    const char* core_agents[] = {
        "DIRECTOR", "PROJECT_ORCHESTRATOR", "ARCHITECT", "SECURITY",
        "CONSTRUCTOR", "TESTBED", "OPTIMIZER", "DEBUGGER", "DEPLOYER",
        "MONITOR", "DATABASE", "ML_OPS", "PATCHER", "LINTER", "DOCGEN",
        "PACKAGER", "API_DESIGNER", "WEB", "MOBILE", "PYGUI",
        "C_INTERNAL", "PYTHON_INTERNAL", "SECURITY-CHAOS", NULL
    };
    
    pthread_rwlock_wrlock(&registry_lock);
    for (int i = 0; core_agents[i] != NULL; i++) {
        strncpy(agent_registry[i].name, core_agents[i], 63);
        agent_registry[i].id = i + 1;
    }
    next_agent_id = 24;  // After core agents
    pthread_rwlock_unlock(&registry_lock);
}

// Register agent and get ID
static uint16_t register_agent(const char* name) {
    pthread_rwlock_rdlock(&registry_lock);
    
    // Check if already registered
    for (int i = 0; i < next_agent_id; i++) {
        if (strcmp(agent_registry[i].name, name) == 0) {
            uint16_t id = agent_registry[i].id;
            pthread_rwlock_unlock(&registry_lock);
            return id;
        }
    }
    pthread_rwlock_unlock(&registry_lock);
    
    // Register new agent
    pthread_rwlock_wrlock(&registry_lock);
    uint16_t id = atomic_fetch_add(&next_agent_id, 1);
    strncpy(agent_registry[id - 1].name, name, 63);
    agent_registry[id - 1].id = id;
    pthread_rwlock_unlock(&registry_lock);
    
    return id;
}

// Get agent name from ID
static const char* get_agent_name(uint16_t id) {
    if (id == 0 || id >= next_agent_id) return "UNKNOWN";
    return agent_registry[id - 1].name;
}

// SIMD-optimized CRC32C checksum using SSE4.2
static inline uint32_t crc32c_sse42(const uint8_t* data, size_t len) {
    uint32_t crc = 0xFFFFFFFF;
    
    #ifdef __SSE4_2__
    // Process 8 bytes at a time using hardware CRC32 instruction
    size_t i = 0;
    for (; i + 8 <= len; i += 8) {
        crc = _mm_crc32_u64(crc, *(uint64_t*)(data + i));
    }
    
    // Process remaining bytes
    for (; i < len; i++) {
        crc = _mm_crc32_u8(crc, data[i]);
    }
    #else
    // Fallback to software CRC32
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int k = 0; k < 8; k++) {
            crc = (crc >> 1) ^ (0x82F63B78 & (-(crc & 1)));
        }
    }
    #endif
    
    return ~crc;
}

// SIMD-optimized memory copy
static inline void simd_memcpy(void* dst, const void* src, size_t size) {
    #ifdef __AVX2__
    __m256i* d = (__m256i*)dst;
    const __m256i* s = (const __m256i*)src;
    size_t chunks = size / 32;
    
    for (size_t i = 0; i < chunks; i++) {
        _mm256_stream_si256(d + i, _mm256_load_si256(s + i));
    }
    
    // Copy remaining bytes
    size_t remaining = size % 32;
    if (remaining > 0) {
        memcpy((uint8_t*)dst + chunks * 32, (const uint8_t*)src + chunks * 32, remaining);
    }
    
    _mm_sfence();  // Ensure streaming stores are visible
    #else
    memcpy(dst, src, size);
    #endif
}

// Create lock-free ring buffer
static ring_buffer_t* create_ring_buffer(size_t size) {
    // Ensure size is power of 2
    size_t actual_size = 1;
    while (actual_size < size) actual_size <<= 1;
    
    ring_buffer_t* rb = aligned_alloc(CACHE_LINE_SIZE, sizeof(ring_buffer_t));
    if (!rb) return NULL;
    
    // Allocate buffer with huge pages for better performance
    rb->buffer = mmap(NULL, actual_size, 
                     PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                     -1, 0);
    
    if (rb->buffer == MAP_FAILED) {
        // Fallback to regular pages
        rb->buffer = mmap(NULL, actual_size,
                         PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS,
                         -1, 0);
        if (rb->buffer == MAP_FAILED) {
            free(rb);
            return NULL;
        }
    }
    
    rb->size = actual_size;
    rb->mask = actual_size - 1;
    atomic_store(&rb->write_pos, 0);
    atomic_store(&rb->read_pos, 0);
    atomic_store(&rb->cached_write_pos, 0);
    atomic_store(&rb->cached_read_pos, 0);
    
    return rb;
}

// Lock-free ring buffer write
static bool ring_buffer_write(ring_buffer_t* rb, const void* data, size_t len) {
    if (len > rb->size / 4) return false;  // Don't allow huge messages
    
    uint64_t write_pos = atomic_load_explicit(&rb->write_pos, memory_order_relaxed);
    uint64_t read_pos = atomic_load_explicit(&rb->cached_read_pos, memory_order_acquire);
    
    // Check if we need to update cached read position
    if (write_pos + len > read_pos + rb->size) {
        read_pos = atomic_load_explicit(&rb->read_pos, memory_order_acquire);
        atomic_store_explicit(&rb->cached_read_pos, read_pos, memory_order_relaxed);
        
        if (write_pos + len > read_pos + rb->size) {
            return false;  // Buffer full
        }
    }
    
    // Write size header
    uint32_t msg_size = (uint32_t)len;
    uint64_t write_idx = write_pos & rb->mask;
    
    // Handle wrap-around for header
    if (write_idx + sizeof(uint32_t) > rb->size) {
        size_t part1 = rb->size - write_idx;
        memcpy(rb->buffer + write_idx, &msg_size, part1);
        memcpy(rb->buffer, ((uint8_t*)&msg_size) + part1, sizeof(uint32_t) - part1);
        write_idx = sizeof(uint32_t) - part1;
    } else {
        memcpy(rb->buffer + write_idx, &msg_size, sizeof(uint32_t));
        write_idx += sizeof(uint32_t);
    }
    
    // Write data using SIMD copy
    if (write_idx + len > rb->size) {
        size_t part1 = rb->size - write_idx;
        simd_memcpy(rb->buffer + write_idx, data, part1);
        simd_memcpy(rb->buffer, (const uint8_t*)data + part1, len - part1);
    } else {
        simd_memcpy(rb->buffer + write_idx, data, len);
    }
    
    // Update write position
    atomic_store_explicit(&rb->write_pos, write_pos + sizeof(uint32_t) + len, memory_order_release);
    
    atomic_fetch_add(&messages_sent, 1);
    atomic_fetch_add(&bytes_sent, len);
    
    return true;
}

// Lock-free ring buffer read
static size_t ring_buffer_read(ring_buffer_t* rb, void* data, size_t max_len) {
    uint64_t read_pos = atomic_load_explicit(&rb->read_pos, memory_order_relaxed);
    uint64_t write_pos = atomic_load_explicit(&rb->cached_write_pos, memory_order_acquire);
    
    // Check if we need to update cached write position
    if (read_pos >= write_pos) {
        write_pos = atomic_load_explicit(&rb->write_pos, memory_order_acquire);
        atomic_store_explicit(&rb->cached_write_pos, write_pos, memory_order_relaxed);
        
        if (read_pos >= write_pos) {
            return 0;  // Buffer empty
        }
    }
    
    // Read size header
    uint32_t msg_size;
    uint64_t read_idx = read_pos & rb->mask;
    
    if (read_idx + sizeof(uint32_t) > rb->size) {
        size_t part1 = rb->size - read_idx;
        memcpy(&msg_size, rb->buffer + read_idx, part1);
        memcpy(((uint8_t*)&msg_size) + part1, rb->buffer, sizeof(uint32_t) - part1);
        read_idx = sizeof(uint32_t) - part1;
    } else {
        memcpy(&msg_size, rb->buffer + read_idx, sizeof(uint32_t));
        read_idx += sizeof(uint32_t);
    }
    
    if (msg_size > max_len) return 0;  // Message too large for buffer
    
    // Read data
    if (read_idx + msg_size > rb->size) {
        size_t part1 = rb->size - read_idx;
        simd_memcpy(data, rb->buffer + read_idx, part1);
        simd_memcpy((uint8_t*)data + part1, rb->buffer, msg_size - part1);
    } else {
        simd_memcpy(data, rb->buffer + read_idx, msg_size);
    }
    
    // Update read position
    atomic_store_explicit(&rb->read_pos, read_pos + sizeof(uint32_t) + msg_size, memory_order_release);
    
    atomic_fetch_add(&messages_received, 1);
    atomic_fetch_add(&bytes_received, msg_size);
    
    return msg_size;
}

// Pack message into binary format
static size_t pack_message(uint8_t* buffer, size_t buffer_size,
                           message_type_t msg_type,
                           const char* source,
                           const char** targets, uint8_t target_count,
                           const void* payload, size_t payload_len,
                           priority_t priority) {
    
    if (sizeof(message_header_t) + target_count * 2 + payload_len > buffer_size) {
        return 0;  // Buffer too small
    }
    
    message_header_t* header = (message_header_t*)buffer;
    
    // Fill header
    header->magic = MAGIC_BYTES;
    header->version = PROTOCOL_VERSION;
    header->flags = 0;
    header->msg_type = msg_type;
    header->priority = priority;
    header->reserved1 = 0;
    
    // Generate message ID
    static _Atomic uint32_t msg_counter = 0;
    header->msg_id = atomic_fetch_add(&msg_counter, 1);
    
    // Timestamp (milliseconds since epoch)
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    header->timestamp = ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
    
    // Agent IDs
    header->source_agent = register_agent(source);
    header->target_count = target_count;
    header->reserved2 = 0;
    header->payload_len = payload_len;
    
    // Pack target agent IDs
    uint16_t* target_ids = (uint16_t*)(buffer + sizeof(message_header_t));
    for (uint8_t i = 0; i < target_count; i++) {
        target_ids[i] = register_agent(targets[i]);
    }
    
    // Copy payload using SIMD
    uint8_t* payload_ptr = buffer + sizeof(message_header_t) + target_count * sizeof(uint16_t);
    simd_memcpy(payload_ptr, payload, payload_len);
    
    // Calculate checksum
    size_t msg_size = sizeof(message_header_t) + target_count * sizeof(uint16_t) + payload_len;
    header->checksum = crc32c_sse42(buffer, msg_size - sizeof(uint32_t));
    
    return msg_size;
}

// Unpack message from binary format
static bool unpack_message(const uint8_t* buffer, size_t buffer_size,
                           message_type_t* msg_type,
                           char* source, size_t source_size,
                           char** targets, uint8_t* target_count,
                           void* payload, size_t* payload_len,
                           priority_t* priority) {
    
    if (buffer_size < sizeof(message_header_t)) return false;
    
    const message_header_t* header = (const message_header_t*)buffer;
    
    // Verify magic and version
    if (header->magic != MAGIC_BYTES || header->version != PROTOCOL_VERSION) {
        return false;
    }
    
    // Verify size
    size_t expected_size = sizeof(message_header_t) + 
                          header->target_count * sizeof(uint16_t) + 
                          header->payload_len;
    if (buffer_size < expected_size) return false;
    
    // Verify checksum
    uint32_t calculated_checksum = crc32c_sse42(buffer, expected_size - sizeof(uint32_t));
    if (calculated_checksum != header->checksum) {
        return false;
    }
    
    // Extract fields
    *msg_type = (message_type_t)header->msg_type;
    *priority = (priority_t)header->priority;
    *target_count = header->target_count;
    *payload_len = header->payload_len;
    
    // Get source agent name
    strncpy(source, get_agent_name(header->source_agent), source_size - 1);
    
    // Get target agent names
    const uint16_t* target_ids = (const uint16_t*)(buffer + sizeof(message_header_t));
    for (uint8_t i = 0; i < header->target_count; i++) {
        if (targets[i]) {
            strcpy(targets[i], get_agent_name(target_ids[i]));
        }
    }
    
    // Copy payload
    const uint8_t* payload_ptr = buffer + sizeof(message_header_t) + 
                                 header->target_count * sizeof(uint16_t);
    simd_memcpy(payload, payload_ptr, header->payload_len);
    
    return true;
}

// Message pool for zero allocation
static message_pool_t* create_message_pool(size_t chunk_size, size_t chunk_count) {
    message_pool_t* pool = malloc(sizeof(message_pool_t));
    if (!pool) return NULL;
    
    pool->chunk_size = chunk_size;
    pool->pool_size = chunk_size * chunk_count;
    
    // Allocate aligned memory for pool
    pool->pool = aligned_alloc(CACHE_LINE_SIZE, pool->pool_size);
    if (!pool->pool) {
        free(pool);
        return NULL;
    }
    
    // Initialize free list
    pool->next_free = malloc(chunk_count * sizeof(uint32_t));
    if (!pool->next_free) {
        free(pool->pool);
        free(pool);
        return NULL;
    }
    
    for (size_t i = 0; i < chunk_count - 1; i++) {
        pool->next_free[i] = i + 1;
    }
    pool->next_free[chunk_count - 1] = UINT32_MAX;
    
    atomic_store(&pool->free_list, 0);
    
    return pool;
}

// Allocate message from pool (lock-free)
static void* pool_alloc(message_pool_t* pool) {
    uint32_t index;
    uint32_t next;
    
    do {
        index = atomic_load(&pool->free_list);
        if (index == UINT32_MAX) return NULL;  // Pool exhausted
        next = pool->next_free[index];
    } while (!atomic_compare_exchange_weak(&pool->free_list, &index, next));
    
    return (uint8_t*)pool->pool + index * pool->chunk_size;
}

// Return message to pool (lock-free)
static void pool_free(message_pool_t* pool, void* ptr) {
    uint32_t index = ((uint8_t*)ptr - (uint8_t*)pool->pool) / pool->chunk_size;
    uint32_t head;
    
    do {
        head = atomic_load(&pool->free_list);
        pool->next_free[index] = head;
    } while (!atomic_compare_exchange_weak(&pool->free_list, &head, index));
}

// Benchmark functions
static void benchmark_serialization(int iterations) {
    printf("\n=== Serialization Benchmark ===\n");
    
    uint8_t buffer[4096];
    const char* targets[] = {"MONITOR", "SECURITY", "DEBUGGER"};
    char payload[1024];
    memset(payload, 'X', sizeof(payload));
    
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    for (int i = 0; i < iterations; i++) {
        size_t packed_size = pack_message(
            buffer, sizeof(buffer),
            MSG_REQUEST, "SECURITY-CHAOS",
            targets, 3,
            payload, sizeof(payload),
            PRIORITY_HIGH
        );
        
        // Unpack to verify
        message_type_t msg_type;
        char source[64];
        char* target_buffers[3];
        char t1[64], t2[64], t3[64];
        target_buffers[0] = t1;
        target_buffers[1] = t2;
        target_buffers[2] = t3;
        uint8_t target_count;
        char unpacked_payload[1024];
        size_t payload_len;
        priority_t priority;
        
        unpack_message(buffer, packed_size,
                      &msg_type, source, sizeof(source),
                      target_buffers, &target_count,
                      unpacked_payload, &payload_len,
                      &priority);
    }
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double elapsed = (end.tv_sec - start.tv_sec) + 
                    (end.tv_nsec - start.tv_nsec) / 1e9;
    
    printf("Iterations: %d\n", iterations);
    printf("Time: %.3f seconds\n", elapsed);
    printf("Messages/sec: %.0f\n", iterations / elapsed);
    printf("Throughput: %.1f MB/s\n", 
           (iterations * sizeof(payload)) / elapsed / (1024 * 1024));
}

static void benchmark_ring_buffer(int iterations) {
    printf("\n=== Ring Buffer Benchmark ===\n");
    
    ring_buffer_t* rb = create_ring_buffer(RING_BUFFER_SIZE);
    if (!rb) {
        printf("Failed to create ring buffer\n");
        return;
    }
    
    char write_data[1024];
    char read_data[1024];
    memset(write_data, 'Y', sizeof(write_data));
    
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    // Writer thread
    pthread_t writer_thread;
    pthread_create(&writer_thread, NULL, (void*)({
        void* writer_func(void* arg) {
            for (int i = 0; i < iterations; i++) {
                while (!ring_buffer_write(rb, write_data, sizeof(write_data))) {
                    __builtin_ia32_pause();  // CPU pause instruction
                }
            }
            return NULL;
        }
        writer_func;
    }), NULL);
    
    // Reader (main thread)
    int messages_read = 0;
    while (messages_read < iterations) {
        if (ring_buffer_read(rb, read_data, sizeof(read_data)) > 0) {
            messages_read++;
        } else {
            __builtin_ia32_pause();
        }
    }
    
    pthread_join(writer_thread, NULL);
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double elapsed = (end.tv_sec - start.tv_sec) + 
                    (end.tv_nsec - start.tv_nsec) / 1e9;
    
    printf("Iterations: %d\n", iterations);
    printf("Time: %.3f seconds\n", elapsed);
    printf("Messages/sec: %.0f\n", iterations / elapsed);
    printf("Throughput: %.1f MB/s\n", 
           (iterations * sizeof(write_data)) / elapsed / (1024 * 1024));
    printf("Latency: %.1f ns/msg\n", elapsed * 1e9 / iterations);
    
    munmap(rb->buffer, rb->size);
    free(rb);
}

static void benchmark_message_pool(int iterations) {
    printf("\n=== Message Pool Benchmark ===\n");
    
    message_pool_t* pool = create_message_pool(2048, 1000);
    if (!pool) {
        printf("Failed to create message pool\n");
        return;
    }
    
    void* messages[1000];
    
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    for (int iter = 0; iter < iterations; iter++) {
        // Allocate batch
        for (int i = 0; i < 100; i++) {
            messages[i] = pool_alloc(pool);
            if (messages[i]) {
                memset(messages[i], iter & 0xFF, 256);  // Some work
            }
        }
        
        // Free batch
        for (int i = 0; i < 100; i++) {
            if (messages[i]) {
                pool_free(pool, messages[i]);
            }
        }
    }
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double elapsed = (end.tv_sec - start.tv_sec) + 
                    (end.tv_nsec - start.tv_nsec) / 1e9;
    
    printf("Iterations: %d\n", iterations);
    printf("Allocations: %d\n", iterations * 100);
    printf("Time: %.3f seconds\n", elapsed);
    printf("Alloc+Free/sec: %.0f\n", (iterations * 100 * 2) / elapsed);
    
    free(pool->next_free);
    free(pool->pool);
    free(pool);
}

// Print performance statistics
static void print_statistics(void) {
    printf("\n=== Performance Statistics ===\n");
    printf("Messages sent: %lu\n", atomic_load(&messages_sent));
    printf("Messages received: %lu\n", atomic_load(&messages_received));
    printf("Bytes sent: %lu\n", atomic_load(&bytes_sent));
    printf("Bytes received: %lu\n", atomic_load(&bytes_received));
    
    uint64_t total_bytes = atomic_load(&bytes_sent) + atomic_load(&bytes_received);
    printf("Total throughput: %.1f MB\n", total_bytes / (1024.0 * 1024.0));
}

int main(int argc, char* argv[]) {
    printf("ULTRA-FAST BINARY PROTOCOL - C Implementation\n");
    printf("==============================================\n");
    printf("Cache line size: %d bytes\n", CACHE_LINE_SIZE);
    printf("SIMD alignment: %d bytes\n", SIMD_ALIGNMENT);
    printf("Header size: %zu bytes\n", sizeof(message_header_t));
    
    #ifdef __AVX2__
    printf("AVX2: Enabled\n");
    #endif
    #ifdef __SSE4_2__
    printf("SSE4.2: Enabled\n");
    #endif
    
    // Initialize agent registry
    init_agent_registry();
    
    // Run benchmarks
    int iterations = (argc > 1) ? atoi(argv[1]) : 100000;
    
    benchmark_serialization(iterations);
    benchmark_ring_buffer(iterations);
    benchmark_message_pool(iterations / 10);
    
    print_statistics();
    
    return 0;
}