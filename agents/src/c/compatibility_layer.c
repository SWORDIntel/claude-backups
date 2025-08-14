// Compatibility layer implementation
#include "compatibility_layer.h"

int io_uring_fallback_read(int fd, void *buf, size_t count, off_t offset) {
    lseek(fd, offset, SEEK_SET);
    return read(fd, buf, count);
}

int io_uring_fallback_write(int fd, const void *buf, size_t count, off_t offset) {
    lseek(fd, offset, SEEK_SET);
    return write(fd, buf, count);
}

// Stub implementations for missing functions
int ring_buffer_read_priority(void* rb, int priority, enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)rb; (void)priority; (void)msg; (void)payload; return -1;
}

void process_message_pcore(enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)msg; (void)payload;
}

void process_message_ecore(enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)msg; (void)payload;
}

void* work_queue_steal(void* queue) {
    (void)queue; return NULL;
}
