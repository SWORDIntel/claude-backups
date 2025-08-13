/* Auto-generated compatibility implementation */
#include "compatibility_layer.h"
#include <stdio.h>
#include <string.h>

/* io_uring fallback implementations using regular I/O */
int io_uring_fallback_read(int fd, void *buf, size_t count, off_t offset) {
    if (lseek(fd, offset, SEEK_SET) == -1) return -1;
    return read(fd, buf, count);
}

int io_uring_fallback_write(int fd, const void *buf, size_t count, off_t offset) {
    if (lseek(fd, offset, SEEK_SET) == -1) return -1;
    return write(fd, buf, count);
}

/* Missing function stubs for ring buffer operations */
int ring_buffer_read_priority(void* rb, int priority, enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)rb; (void)priority; (void)msg; (void)payload;
    return 0; // No messages available
}

void process_message_pcore(enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)msg; (void)payload;
    // Stub implementation - would process message on P-core
}

void process_message_ecore(enhanced_msg_header_t* msg, uint8_t* payload) {
    (void)msg; (void)payload;
    // Stub implementation - would process message on E-core
}

void* work_queue_steal(void* queue) {
    (void)queue;
    return NULL; // No work to steal
}
