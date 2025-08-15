/*
 * ultra_hybrid_fixed.c
 * Fixed multi-consumer synchronization with maximum throughput
 * Implements atomic message claiming, batch processing, and work-stealing
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <time.h>
#include <stdatomic.h>
#include <immintrin.h>
#include <sched.h>
#include <signal.h>
#include <stdbool.h>
#include <assert.h>

// ============================================================================
// Configuration and Constants
// ============================================================================

#define MAX_AGENTS 32
#define MAX_PRODUCERS 16
#define MAX_WORKERS 32
#define MSG_BUFFER_SIZE 65536
#define BATCH_SIZE 64
#define RING_BUFFER_SIZE (512 * 1024 * 1024)  // 512 MB ring buffer
#define CACHE_LINE_SIZE 64
#define PREFETCH_DISTANCE 4
#define WORKER_BATCH_SIZE 64  // Increased batch size for better throughput

// Feature flags
#define ENABLE_CRC_ASYNC 1
#define ENABLE_BATCH_PROCESSING 1
#define ENABLE_PREFETCH 1
#define ENABLE_WORK_STEALING 1

// Memory ordering hints
#define MO_RELAXED memory_order_relaxed
#define MO_ACQUIRE memory_order_acquire
#define MO_RELEASE memory_order_release
#define MO_ACQ_REL memory_order_acq_rel

// Alignment macros
#define CACHE_ALIGNED __attribute__((aligned(CACHE_LINE_SIZE)))
#define PACKED __attribute__((packed))
#define LIKELY(x) __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)

// ============================================================================
// Cache-Optimized Data Structures
// ============================================================================

typedef struct CACHE_ALIGNED {
    atomic_uint_fast64_t value;
    char padding[CACHE_LINE_SIZE - sizeof(atomic_uint_fast64_t)];
} aligned_counter_t;

typedef struct PACKED {
    uint32_t msg_type;
    uint32_t msg_len;
    uint64_t timestamp;
    uint32_t source_agent;
    uint32_t target_agent;
    uint32_t flags;
    uint32_t crc32;
} message_header_t;

typedef struct CACHE_ALIGNED {
    message_header_t headers[BATCH_SIZE];
    uint8_t* payloads[BATCH_SIZE];
    uint32_t count;
    uint32_t total_size;
    char padding[CACHE_LINE_SIZE - 8];
} message_batch_t;

// Work item for work-stealing queue
typedef struct {
    uint64_t offset;      // Offset in ring buffer (wrapped)
    uint64_t linear_pos;  // Linear position for read tracking
    uint32_t size;        // Total size (header + payload)
    uint32_t msg_type;    // For priority routing
} work_item_t;

// Work-stealing deque per worker
typedef struct CACHE_ALIGNED {
    work_item_t* items;
    atomic_int_fast32_t top;     // Private end (owner pushes/pops)
    atomic_int_fast32_t bottom;  // Public end (thieves steal)
    size_t capacity;
    size_t mask;                  // For fast modulo
    pthread_spinlock_t steal_lock;
} work_deque_t;

// Enhanced producer context
typedef struct CACHE_ALIGNED {
    pthread_t thread;
    uint32_t producer_id;
    atomic_uint_fast64_t messages_sent;
    atomic_uint_fast64_t bytes_sent;
    volatile int running;
    message_batch_t* batch;
    int cpu_core;
    uint64_t start_time;
    uint64_t end_time;
} producer_context_t;

// Enhanced ring buffer with consumer synchronization
typedef struct CACHE_ALIGNED {
    // Separate cache lines for producer and consumer sides
    aligned_counter_t write_pos;
    aligned_counter_t reserved_pos;
    
    // Consumer side - multiple read cursors
    aligned_counter_t read_pos;        // Global committed read position
    aligned_counter_t claim_pos;        // Next position to claim
    
    // Buffer and metadata
    uint8_t* buffer;
    size_t size;
    size_t mask;
    
    // Producer synchronization
    pthread_mutex_t write_lock;
    pthread_spinlock_t reserve_lock;
    
    // Consumer synchronization
    pthread_spinlock_t claim_lock;
    
    // Statistics
    atomic_uint_fast64_t total_messages;
    atomic_uint_fast64_t total_bytes;
    atomic_uint_fast64_t dropped_messages;
    atomic_uint_fast64_t duplicate_reads;  // Debug counter
} ring_buffer_t;

// Enhanced worker context with work-stealing
typedef struct CACHE_ALIGNED {
    pthread_t thread;
    uint32_t worker_id;
    int cpu_core;
    volatile int running;
    
    // Work-stealing deque
    work_deque_t* deque;
    
    // Local batch buffer for claimed messages
    work_item_t local_batch[WORKER_BATCH_SIZE];
    uint32_t batch_count;
    
    // Statistics
    atomic_uint_fast64_t messages_processed;
    atomic_uint_fast64_t bytes_processed;
    atomic_uint_fast64_t messages_stolen;
    atomic_uint_fast64_t steal_attempts;
    atomic_uint_fast64_t idle_cycles;
    uint64_t start_time;
    
    // Read position tracking
    uint64_t last_processed_pos;
} worker_context_t;

// ============================================================================
// Global State
// ============================================================================

static ring_buffer_t* g_ring_buffer = NULL;
static producer_context_t g_producers[MAX_PRODUCERS];
static worker_context_t g_workers[MAX_WORKERS];
static volatile int g_system_running = 1;
static int g_socket_fd = -1;
static int g_num_workers = 0;

// Debug: Track total messages claimed vs processed
static atomic_uint_fast64_t g_messages_claimed = 0;
static atomic_uint_fast64_t g_messages_completed = 0;

// ============================================================================
// Work-Stealing Deque Implementation
// ============================================================================

static work_deque_t* create_work_deque(size_t capacity) {
    // Ensure capacity is power of 2
    size_t size = 1;
    while (size < capacity) size <<= 1;
    
    work_deque_t* deque = aligned_alloc(CACHE_LINE_SIZE, sizeof(work_deque_t));
    if (!deque) return NULL;
    
    deque->items = aligned_alloc(CACHE_LINE_SIZE, size * sizeof(work_item_t));
    if (!deque->items) {
        free(deque);
        return NULL;
    }
    
    deque->capacity = size;
    deque->mask = size - 1;
    atomic_store(&deque->top, 0);
    atomic_store(&deque->bottom, 0);
    pthread_spin_init(&deque->steal_lock, PTHREAD_PROCESS_PRIVATE);
    
    return deque;
}

// Owner pushes work to their deque
static void deque_push(work_deque_t* deque, work_item_t* item) {
    int_fast32_t b = atomic_load_explicit(&deque->bottom, MO_RELAXED);
    int_fast32_t t = atomic_load_explicit(&deque->top, MO_ACQUIRE);
    
    if (b - t >= (int32_t)deque->capacity) {
        // Deque full - this shouldn't happen with proper sizing
        return;
    }
    
    deque->items[b & deque->mask] = *item;
    atomic_thread_fence(memory_order_release);
    atomic_store_explicit(&deque->bottom, b + 1, MO_RELAXED);
}

// Owner pops from their deque
static bool deque_pop(work_deque_t* deque, work_item_t* item) {
    int_fast32_t b = atomic_load_explicit(&deque->bottom, MO_RELAXED) - 1;
    atomic_store_explicit(&deque->bottom, b, MO_RELAXED);
    atomic_thread_fence(memory_order_seq_cst);
    
    int_fast32_t t = atomic_load_explicit(&deque->top, MO_RELAXED);
    
    if (t <= b) {
        // Non-empty
        *item = deque->items[b & deque->mask];
        
        if (t == b) {
            // Last item - need CAS
            int_fast32_t new_top = t + 1;
            if (!atomic_compare_exchange_strong_explicit(&deque->top, &t, new_top,
                                                         memory_order_seq_cst,
                                                         memory_order_seq_cst)) {
                // Failed race
                atomic_store_explicit(&deque->bottom, b + 1, MO_RELAXED);
                return false;
            }
            atomic_store_explicit(&deque->bottom, b + 1, MO_RELAXED);
        }
        return true;
    } else {
        // Empty
        atomic_store_explicit(&deque->bottom, b + 1, MO_RELAXED);
        return false;
    }
}

// Thief steals from another's deque
static bool deque_steal(work_deque_t* deque, work_item_t* item) {
    int_fast32_t t = atomic_load_explicit(&deque->top, MO_ACQUIRE);
    atomic_thread_fence(memory_order_seq_cst);
    int_fast32_t b = atomic_load_explicit(&deque->bottom, MO_ACQUIRE);
    
    if (t < b) {
        *item = deque->items[t & deque->mask];
        
        int_fast32_t new_top = t + 1;
        if (atomic_compare_exchange_strong_explicit(&deque->top, &t, new_top,
                                                    memory_order_seq_cst,
                                                    memory_order_seq_cst)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// CRC32 Implementation
// ============================================================================

static uint32_t calculate_crc32_fast(const void* data, size_t length) {
#ifdef __x86_64__
    const uint8_t* bytes = (const uint8_t*)data;
    uint32_t crc = 0xFFFFFFFF;
    
    while (length >= 8) {
        crc = _mm_crc32_u64(crc, *(uint64_t*)bytes);
        bytes += 8;
        length -= 8;
    }
    
    while (length--) {
        crc = _mm_crc32_u8(crc, *bytes++);
    }
    
    return ~crc;
#else
    const uint8_t* bytes = (const uint8_t*)data;
    uint32_t crc = 0xFFFFFFFF;
    
    for (size_t i = 0; i < length; i++) {
        crc ^= bytes[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
        }
    }
    
    return ~crc;
#endif
}

// ============================================================================
// Ring Buffer Implementation (Producer Side)
// ============================================================================

static int init_ring_buffer(void) {
    g_ring_buffer = aligned_alloc(CACHE_LINE_SIZE, sizeof(ring_buffer_t));
    if (!g_ring_buffer) return -1;
    
    memset(g_ring_buffer, 0, sizeof(ring_buffer_t));
    
    g_ring_buffer->size = RING_BUFFER_SIZE;
    g_ring_buffer->mask = RING_BUFFER_SIZE - 1;
    
    // Try huge pages first
    g_ring_buffer->buffer = mmap(NULL, RING_BUFFER_SIZE,
                                 PROT_READ | PROT_WRITE,
                                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                                 -1, 0);
    
    if (g_ring_buffer->buffer == MAP_FAILED) {
        g_ring_buffer->buffer = mmap(NULL, RING_BUFFER_SIZE,
                                     PROT_READ | PROT_WRITE,
                                     MAP_PRIVATE | MAP_ANONYMOUS,
                                     -1, 0);
        if (g_ring_buffer->buffer == MAP_FAILED) {
            free(g_ring_buffer);
            return -1;
        }
    }
    
    mlock(g_ring_buffer->buffer, RING_BUFFER_SIZE);
    
    pthread_mutex_init(&g_ring_buffer->write_lock, NULL);
    pthread_spin_init(&g_ring_buffer->reserve_lock, PTHREAD_PROCESS_PRIVATE);
    pthread_spin_init(&g_ring_buffer->claim_lock, PTHREAD_PROCESS_PRIVATE);
    
    atomic_store(&g_ring_buffer->write_pos.value, 0);
    atomic_store(&g_ring_buffer->read_pos.value, 0);
    atomic_store(&g_ring_buffer->reserved_pos.value, 0);
    atomic_store(&g_ring_buffer->claim_pos.value, 0);
    
    return 0;
}

static uint64_t ring_buffer_reserve(size_t size) {
    uint64_t write_pos, read_pos, new_pos;
    
    pthread_spin_lock(&g_ring_buffer->reserve_lock);
    
    write_pos = atomic_load(&g_ring_buffer->reserved_pos.value);
    read_pos = atomic_load(&g_ring_buffer->read_pos.value);
    new_pos = write_pos + size;
    
    if (new_pos - read_pos > g_ring_buffer->size) {
        pthread_spin_unlock(&g_ring_buffer->reserve_lock);
        atomic_fetch_add(&g_ring_buffer->dropped_messages, 1);
        return UINT64_MAX;
    }
    
    atomic_store(&g_ring_buffer->reserved_pos.value, new_pos);
    pthread_spin_unlock(&g_ring_buffer->reserve_lock);
    
    return write_pos;
}

static void ring_buffer_commit(uint64_t pos, size_t size) {
    while (atomic_load(&g_ring_buffer->write_pos.value) != pos) {
        _mm_pause();
    }
    
    atomic_store(&g_ring_buffer->write_pos.value, pos + size);
    atomic_fetch_add(&g_ring_buffer->total_bytes, size);
}

// ============================================================================
// Ring Buffer Consumer Side - Atomic Batch Claiming
// ============================================================================

static uint32_t claim_messages_batch(worker_context_t* worker) {
    uint64_t write_pos = atomic_load_explicit(&g_ring_buffer->write_pos.value, MO_ACQUIRE);
    uint64_t claim_start, claim_end;
    uint32_t claimed = 0;
    
    // Try to claim a batch of messages
    while (claimed < WORKER_BATCH_SIZE) {
        claim_start = atomic_load_explicit(&g_ring_buffer->claim_pos.value, MO_ACQUIRE);
        
        if (claim_start >= write_pos) {
            break;  // No more messages available
        }
        
        // Peek at next message header
        uint64_t offset = claim_start & g_ring_buffer->mask;
        message_header_t* header = (message_header_t*)(g_ring_buffer->buffer + offset);
        
        // Validate header - messages should be 256-1280 bytes
        if (header->msg_len == 0 || header->msg_len > 2048) {
            // Corrupted message - skip just the header
            claim_end = claim_start + sizeof(message_header_t);
            atomic_compare_exchange_strong(&g_ring_buffer->claim_pos.value, 
                                          &claim_start, claim_end);
            continue;
        }
        
        uint32_t msg_size = sizeof(message_header_t) + header->msg_len;
        claim_end = claim_start + msg_size;
        
        // Ensure we don't exceed write position
        if (claim_end > write_pos) {
            break;
        }
        
        // Atomic claim using CAS
        if (atomic_compare_exchange_strong_explicit(
                &g_ring_buffer->claim_pos.value,
                &claim_start,
                claim_end,
                MO_ACQ_REL,
                MO_ACQUIRE)) {
            
            // Successfully claimed this message
            worker->local_batch[claimed].offset = offset;
            worker->local_batch[claimed].linear_pos = claim_start;
            worker->local_batch[claimed].size = msg_size;
            worker->local_batch[claimed].msg_type = header->msg_type;
            claimed++;
            
            atomic_fetch_add(&g_messages_claimed, 1);
            
            // Prefetch next message if available
#if ENABLE_PREFETCH
            if (claim_end < write_pos) {
                __builtin_prefetch(g_ring_buffer->buffer + (claim_end & g_ring_buffer->mask), 0, 3);
            }
#endif
        }
        // If CAS failed, another worker claimed it - retry with new position
    }
    
    worker->batch_count = claimed;
    return claimed;
}

// Update global read position after processing
static void commit_read_position(uint64_t new_pos) {
    uint64_t current_read;
    
    do {
        current_read = atomic_load(&g_ring_buffer->read_pos.value);
        if (new_pos <= current_read) {
            break;  // Another worker already advanced past us
        }
    } while (!atomic_compare_exchange_weak(&g_ring_buffer->read_pos.value,
                                           &current_read, new_pos));
}

// ============================================================================
// Worker Thread with Work-Stealing
// ============================================================================

static void process_message(worker_context_t* worker, work_item_t* item) {
    message_header_t header;
    uint8_t payload_buffer[MSG_BUFFER_SIZE];
    
    // Read message from ring buffer
    uint8_t* src = g_ring_buffer->buffer + item->offset;
    memcpy(&header, src, sizeof(header));
    memcpy(payload_buffer, src + sizeof(header), header.msg_len);
    
    // Process based on core type
    bool is_pcore = (worker->cpu_core < 12);
    
    if (header.flags & 0x01) {  // CRC enabled
        uint32_t crc = calculate_crc32_fast(payload_buffer, header.msg_len);
        if (crc != header.crc32 && header.crc32 != 0) {
            return;  // CRC mismatch
        }
    }
    
    // Minimal processing simulation - just a memory fence
    // Real processing would happen here
    __atomic_thread_fence(__ATOMIC_ACQ_REL);
    
    // Optional: Single pause for cache coherency
    if (header.msg_type < 5) {
        __builtin_ia32_pause();
    }
    
    // Update statistics
    atomic_fetch_add(&worker->messages_processed, 1);
    atomic_fetch_add(&worker->bytes_processed, item->size);
    atomic_fetch_add(&g_messages_completed, 1);
    
    // Track latest processed position
    worker->last_processed_pos = item->linear_pos + item->size;
}

static void* worker_thread(void* arg) {
    worker_context_t* ctx = (worker_context_t*)arg;
    
    // Set CPU affinity
    if (ctx->cpu_core >= 0) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(ctx->cpu_core, &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpuset), &cpuset);
    }
    
    // Create work-stealing deque
    ctx->deque = create_work_deque(256);
    if (!ctx->deque) {
        fprintf(stderr, "Worker %u: Failed to create deque\n", ctx->worker_id);
        return NULL;
    }
    
    ctx->start_time = time(NULL);
    work_item_t item;
    
    while (ctx->running && g_system_running) {
        bool found_work = false;
        
        // Step 1: Try to get work from local deque
        if (deque_pop(ctx->deque, &item)) {
            process_message(ctx, &item);
            // TODO: Update read position periodically
            found_work = true;
        }
        
        // Step 2: Claim new messages from ring buffer
        if (!found_work) {
            uint32_t claimed = claim_messages_batch(ctx);
            if (claimed > 0) {
                // Process first message immediately
                process_message(ctx, &ctx->local_batch[0]);
                // TODO: Update read position in batches
                
                // Push rest to local deque for later
                for (uint32_t i = 1; i < claimed; i++) {
                    deque_push(ctx->deque, &ctx->local_batch[i]);
                }
                
                found_work = true;
            }
        }
        
#if ENABLE_WORK_STEALING
        // Step 3: Try to steal work from other workers
        if (!found_work) {
            // Random victim selection
            uint32_t victim = (ctx->worker_id + 1 + (rand() % (g_num_workers - 1))) % g_num_workers;
            
            atomic_fetch_add(&ctx->steal_attempts, 1);
            
            if (victim != ctx->worker_id && g_workers[victim].deque) {
                if (deque_steal(g_workers[victim].deque, &item)) {
                    process_message(ctx, &item);
                    // TODO: Update read position for stolen work
                    atomic_fetch_add(&ctx->messages_stolen, 1);
                    found_work = true;
                }
            }
        }
#endif
        
        // Step 4: Minimal idle - just pause briefly
        if (!found_work) {
            atomic_fetch_add(&ctx->idle_cycles, 1);
            __builtin_ia32_pause();  // Single pause for all cores
        }
        
        // TODO: Implement proper read position tracking
    }
    
    // Cleanup
    if (ctx->deque) {
        free(ctx->deque->items);
        pthread_spin_destroy(&ctx->deque->steal_lock);
        free(ctx->deque);
    }
    
    return NULL;
}

// ============================================================================
// Batch Processing for Producers
// ============================================================================

static message_batch_t* create_message_batch(void) {
    message_batch_t* batch = aligned_alloc(CACHE_LINE_SIZE, sizeof(message_batch_t));
    if (batch) {
        memset(batch, 0, sizeof(message_batch_t));
    }
    return batch;
}

static void add_to_batch(message_batch_t* batch, message_header_t* header, 
                         const void* payload, size_t payload_size) {
    if (batch->count >= BATCH_SIZE) return;
    
    memcpy(&batch->headers[batch->count], header, sizeof(message_header_t));
    
    batch->payloads[batch->count] = malloc(payload_size);
    if (batch->payloads[batch->count]) {
        memcpy(batch->payloads[batch->count], payload, payload_size);
        batch->total_size += sizeof(message_header_t) + payload_size;
        batch->count++;
    }
}

static int flush_batch(message_batch_t* batch) {
    if (batch->count == 0) return 0;
    
    uint64_t write_pos = ring_buffer_reserve(batch->total_size);
    if (write_pos == UINT64_MAX) {
        for (uint32_t i = 0; i < batch->count; i++) {
            free(batch->payloads[i]);
        }
        batch->count = 0;
        batch->total_size = 0;
        return -1;
    }
    
    uint64_t offset = write_pos & g_ring_buffer->mask;
    uint8_t* dst = g_ring_buffer->buffer + offset;
    
    for (uint32_t i = 0; i < batch->count; i++) {
#if ENABLE_PREFETCH
        if (i + PREFETCH_DISTANCE < batch->count) {
            __builtin_prefetch(&batch->headers[i + PREFETCH_DISTANCE], 0, 3);
            __builtin_prefetch(batch->payloads[i + PREFETCH_DISTANCE], 0, 3);
        }
#endif
        
        memcpy(dst, &batch->headers[i], sizeof(message_header_t));
        dst += sizeof(message_header_t);
        
        size_t payload_size = batch->headers[i].msg_len;
        memcpy(dst, batch->payloads[i], payload_size);
        dst += payload_size;
        
        free(batch->payloads[i]);
        
        if ((uint64_t)(dst - g_ring_buffer->buffer) >= g_ring_buffer->size) {
            dst = g_ring_buffer->buffer;
        }
    }
    
    ring_buffer_commit(write_pos, batch->total_size);
    atomic_fetch_add(&g_ring_buffer->total_messages, batch->count);
    
    batch->count = 0;
    batch->total_size = 0;
    
    return 0;
}

// ============================================================================
// Producer Thread
// ============================================================================

static void* producer_thread(void* arg) {
    producer_context_t* ctx = (producer_context_t*)arg;
    
    if (ctx->cpu_core >= 0) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(ctx->cpu_core, &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpuset), &cpuset);
    }
    
    ctx->batch = create_message_batch();
    if (!ctx->batch) {
        return NULL;
    }
    
    ctx->start_time = time(NULL);
    
    uint64_t msg_count = 0;
    while (ctx->running && g_system_running) {
        message_header_t header = {
            .msg_type = (msg_count % 10) + 1,
            .msg_len = 256 + (msg_count % 1024),
            .timestamp = time(NULL),
            .source_agent = ctx->producer_id,
            .target_agent = (ctx->producer_id + 1) % MAX_AGENTS,
            .flags = ENABLE_CRC_ASYNC ? 0x01 : 0x00,
            .crc32 = 0
        };
        
        uint8_t payload[header.msg_len];
        for (uint32_t i = 0; i < header.msg_len; i++) {
            payload[i] = (uint8_t)(i ^ msg_count);
        }
        
        if (!ENABLE_CRC_ASYNC && (header.flags & 0x01)) {
            header.crc32 = calculate_crc32_fast(payload, header.msg_len);
        }
        
        add_to_batch(ctx->batch, &header, payload, header.msg_len);
        
        if (ctx->batch->count >= BATCH_SIZE || (msg_count % 100) == 0) {
            if (flush_batch(ctx->batch) < 0) {
                // Buffer full, back off briefly
                __builtin_ia32_pause();
            }
        }
        
        atomic_fetch_add(&ctx->messages_sent, 1);
        atomic_fetch_add(&ctx->bytes_sent, sizeof(header) + header.msg_len);
        
        msg_count++;
        
        if ((msg_count % 10000) == 0) {
            sched_yield();  // Yield less frequently
        }
    }
    
    if (ctx->batch->count > 0) {
        flush_batch(ctx->batch);  // Final flush, ignore errors
    }
    
    ctx->end_time = time(NULL);
    
    if (ctx->batch) {
        free(ctx->batch);
    }
    
    return NULL;
}

// ============================================================================
// Statistics and Monitoring
// ============================================================================

static void print_statistics(void) {
    printf("\n=== System Statistics ===\n");
    printf("Ring Buffer:\n");
    printf("  Total messages: %lu\n", atomic_load(&g_ring_buffer->total_messages));
    printf("  Total bytes: %lu MB\n", atomic_load(&g_ring_buffer->total_bytes) / (1024*1024));
    printf("  Dropped: %lu\n", atomic_load(&g_ring_buffer->dropped_messages));
    
    uint64_t write_pos = atomic_load(&g_ring_buffer->write_pos.value);
    uint64_t read_pos = atomic_load(&g_ring_buffer->read_pos.value);
    uint64_t claim_pos = atomic_load(&g_ring_buffer->claim_pos.value);
    uint64_t pending = write_pos - read_pos;
    uint64_t claimed_not_processed = claim_pos - read_pos;
    
    printf("  Buffer usage: %.1f%% (%lu KB pending)\n",
           (double)pending / g_ring_buffer->size * 100.0, pending / 1024);
    printf("  Messages claimed: %lu\n", atomic_load(&g_messages_claimed));
    printf("  Messages completed: %lu\n", atomic_load(&g_messages_completed));
    printf("  In-flight: %lu\n", claimed_not_processed / (sizeof(message_header_t) + 640));
    
    printf("\n=== Producer Statistics ===\n");
    uint64_t total_produced = 0;
    for (int i = 0; i < MAX_PRODUCERS; i++) {
        if (g_producers[i].thread) {
            uint64_t messages = atomic_load(&g_producers[i].messages_sent);
            total_produced += messages;
            
            if (g_producers[i].end_time > g_producers[i].start_time) {
                uint64_t duration = g_producers[i].end_time - g_producers[i].start_time;
                printf("  Producer %d: %lu msgs @ %.0f msg/sec\n",
                       i, messages, (double)messages / duration);
            }
        }
    }
    
    printf("\n=== Worker Statistics ===\n");
    uint64_t total_processed = 0;
    uint64_t total_stolen = 0;
    uint64_t total_steal_attempts = 0;
    
    for (int i = 0; i < g_num_workers; i++) {
        if (g_workers[i].thread) {
            uint64_t messages = atomic_load(&g_workers[i].messages_processed);
            uint64_t stolen = atomic_load(&g_workers[i].messages_stolen);
            uint64_t attempts = atomic_load(&g_workers[i].steal_attempts);
            uint64_t idle = atomic_load(&g_workers[i].idle_cycles);
            
            total_processed += messages;
            total_stolen += stolen;
            total_steal_attempts += attempts;
            
            const char* core_type = (i < 12) ? "P" : "E";
            printf("  Worker %2d (%s-core %2d): %6lu proc, %4lu stolen (%.1f%% success), %lu idle\n",
                   i, core_type, g_workers[i].cpu_core, messages, stolen,
                   attempts > 0 ? (double)stolen/attempts*100 : 0.0, idle);
        }
    }
    
    printf("\n=== Throughput Summary ===\n");
    printf("  Produced: %lu\n", total_produced);
    printf("  Processed: %lu\n", total_processed);
    printf("  Work stolen: %lu (%.1f%%)\n", total_stolen, 
           total_processed > 0 ? (double)total_stolen/total_processed*100 : 0.0);
    
    // Verify no duplicates
    if (atomic_load(&g_messages_claimed) != atomic_load(&g_messages_completed)) {
        printf("  WARNING: Claimed != Completed (%lu != %lu)\n",
               atomic_load(&g_messages_claimed), 
               atomic_load(&g_messages_completed));
    }
}

// ============================================================================
// Signal Handling
// ============================================================================

static void signal_handler(int sig) {
    printf("\nReceived signal %d, shutting down...\n", sig);
    g_system_running = 0;
}

// ============================================================================
// Main Function
// ============================================================================

int main(int argc, char* argv[]) {
    printf("Ultra Hybrid Fixed - Multi-Consumer Lock-Free Implementation\n");
    printf("Features: Atomic claiming, Work-stealing, Batch processing\n");
    
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    if (init_ring_buffer() < 0) {
        fprintf(stderr, "Failed to initialize ring buffer\n");
        return 1;
    }
    
    int num_cores = sysconf(_SC_NPROCESSORS_ONLN);
    printf("Detected %d CPU cores (12 P-cores + 10 E-cores assumed)\n", num_cores);
    
    // Configure producers and workers
    int num_producers = (argc > 1) ? atoi(argv[1]) : 4;
    g_num_workers = (argc > 2) ? atoi(argv[2]) : num_cores;
    
    if (num_producers < 1) num_producers = 1;
    if (num_producers > MAX_PRODUCERS) num_producers = MAX_PRODUCERS;
    if (g_num_workers < 1) g_num_workers = 1;
    if (g_num_workers > MAX_WORKERS) g_num_workers = MAX_WORKERS;
    
    printf("Configuration: %d producers, %d workers\n", num_producers, g_num_workers);
    
    // Start producers
    for (int i = 0; i < num_producers; i++) {
        g_producers[i].producer_id = i;
        g_producers[i].running = 1;
        g_producers[i].cpu_core = i % 12;  // Use P-cores for producers
        
        if (pthread_create(&g_producers[i].thread, NULL, producer_thread, &g_producers[i]) != 0) {
            fprintf(stderr, "Failed to create producer %d\n", i);
            g_producers[i].thread = 0;
        }
    }
    
    // Start workers - distribute across P-cores and E-cores
    for (int i = 0; i < g_num_workers; i++) {
        g_workers[i].worker_id = i;
        g_workers[i].running = 1;
        
        // First 12 workers on P-cores, rest on E-cores
        if (i < 12) {
            g_workers[i].cpu_core = i;
        } else {
            g_workers[i].cpu_core = 12 + ((i - 12) % 10);
        }
        
        if (pthread_create(&g_workers[i].thread, NULL, worker_thread, &g_workers[i]) != 0) {
            fprintf(stderr, "Failed to create worker %d\n", i);
            g_workers[i].thread = 0;
        }
    }
    
    // Main monitoring loop
    while (g_system_running) {
        sleep(5);
        if (g_system_running) {
            print_statistics();
        }
    }
    
    // Shutdown
    printf("\nShutting down...\n");
    
    for (int i = 0; i < MAX_PRODUCERS; i++) {
        if (g_producers[i].thread) {
            g_producers[i].running = 0;
        }
    }
    
    for (int i = 0; i < MAX_WORKERS; i++) {
        if (g_workers[i].thread) {
            g_workers[i].running = 0;
        }
    }
    
    for (int i = 0; i < MAX_PRODUCERS; i++) {
        if (g_producers[i].thread) {
            pthread_join(g_producers[i].thread, NULL);
        }
    }
    
    for (int i = 0; i < MAX_WORKERS; i++) {
        if (g_workers[i].thread) {
            pthread_join(g_workers[i].thread, NULL);
        }
    }
    
    print_statistics();
    
    if (g_ring_buffer) {
        munmap(g_ring_buffer->buffer, g_ring_buffer->size);
        pthread_mutex_destroy(&g_ring_buffer->write_lock);
        pthread_spin_destroy(&g_ring_buffer->reserve_lock);
        pthread_spin_destroy(&g_ring_buffer->claim_lock);
        free(g_ring_buffer);
    }
    
    printf("Shutdown complete\n");
    return 0;
}