/* Auto-generated compatibility layer */
#ifndef COMPATIBILITY_LAYER_H
#define COMPATIBILITY_LAYER_H

#include <stdlib.h>
#include <unistd.h>
#include <sched.h>

/* NUMA compatibility stubs */
#define numa_available() -1
#define numa_max_node() 0
#define numa_num_configured_nodes() 1
#define numa_node_of_cpu(cpu) 0
#define numa_alloc_onnode(size, node) malloc(size)
#define numa_free(ptr, size) free(ptr)
#define numa_alloc_interleaved(size) malloc(size)

/* io_uring compatibility stubs */
struct io_uring { int dummy; };
struct io_uring_sqe { int dummy; };
struct io_uring_cqe { int dummy; };
#define io_uring_queue_init(entries, ring, flags) -1
#define io_uring_queue_exit(ring) do {} while(0)
#define io_uring_get_sqe(ring) NULL
#define io_uring_prep_read(sqe, fd, buf, len, offset) do {} while(0)
#define io_uring_prep_write(sqe, fd, buf, len, offset) do {} while(0)
#define io_uring_sqe_set_data(sqe, data) do {} while(0)
#define io_uring_submit(ring) -1
#define io_uring_wait_cqe(ring, cqe_ptr) -1
#define io_uring_cqe_seen(ring, cqe) do {} while(0)

// Forward declarations for missing protocol structures
#include <stdint.h>
// Always define the structure for compatibility
#ifndef ENHANCED_MSG_HEADER_T_DEFINED
typedef struct {
    uint32_t magic;
    uint32_t msg_type;
    uint32_t source_agent;
    uint32_t target_agents[16];
    uint32_t target_count;
    uint64_t timestamp;
    uint64_t sequence;
    uint32_t payload_len;
    uint32_t flags;
    uint32_t priority;
    uint32_t crc32;
    float ai_confidence;
    float anomaly_score;
    uint16_t predicted_path[4];
    uint64_t feature_hash;
    uint8_t gpu_batch_id;
    uint8_t padding2[31];
} enhanced_msg_header_t;
#endif /* ENHANCED_MSG_HEADER_T_DEFINED */

// Function prototypes for missing functions
int io_uring_fallback_read(int fd, void *buf, size_t count, off_t offset);
int io_uring_fallback_write(int fd, const void *buf, size_t count, off_t offset);
int ring_buffer_read_priority(void* rb, int priority, enhanced_msg_header_t* msg, uint8_t* payload);
void process_message_pcore(enhanced_msg_header_t* msg, uint8_t* payload);
void process_message_ecore(enhanced_msg_header_t* msg, uint8_t* payload);
void* work_queue_steal(void* queue);

#endif /* COMPATIBILITY_LAYER_H */
