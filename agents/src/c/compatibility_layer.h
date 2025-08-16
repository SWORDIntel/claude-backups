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
// enhanced_msg_header_t is now defined in ultra_fast_protocol.h with ALL fields
// No need to redefine - use the comprehensive version from ultra_fast_protocol.h

// System constants
#ifndef PAGE_SIZE
#define PAGE_SIZE 4096
#endif

// Function prototypes for missing functions
int io_uring_fallback_read(int fd, void *buf, size_t count, off_t offset);
int io_uring_fallback_write(int fd, const void *buf, size_t count, off_t offset);
int ring_buffer_read_priority(void* rb, int priority, enhanced_msg_header_t* msg, uint8_t* payload);
void process_message_pcore(enhanced_msg_header_t* msg, uint8_t* payload);
void process_message_ecore(enhanced_msg_header_t* msg, uint8_t* payload);
void* work_queue_steal(void* queue);

// Mock advanced feature stubs
static inline int streaming_pipeline_init(uint32_t partitions, const char* brokers, const char* topic) {
    (void)partitions; (void)brokers; (void)topic; return 0;
}
static inline void streaming_pipeline_shutdown(void) { }
static inline void streaming_pipeline_start(void) { }
static inline int nas_init(void) { return 0; }
static inline void nas_shutdown(void) { }
static inline void nas_get_stats(uint32_t* arch, double* fitness, uint32_t* gen) {
    if(arch) *arch = 100; 
    if(fitness) *fitness = 0.95; 
    if(gen) *gen = 10;
}
static inline int digital_twin_init(void) { return 0; }
static inline void* digital_twin_create(const char* name, int type) {
    (void)name; (void)type; return (void*)1;
}
static inline void digital_twin_shutdown(void) { }
static inline void digital_twin_get_stats(uint64_t* syncs, double* latency, uint64_t* pred, uint64_t* anom) {
    if(syncs) *syncs = 1000; 
    if(latency) *latency = 5.0; 
    if(pred) *pred = 500; 
    if(anom) *anom = 2;
}
static inline int multimodal_fusion_init(void) { return 0; }
static inline void* fusion_create_instance(int strategy) { (void)strategy; return (void*)1; }
static inline int fusion_process(void* fusion) { (void)fusion; return 0; }
static inline void multimodal_fusion_shutdown(void) { }

#endif /* COMPATIBILITY_LAYER_H */
