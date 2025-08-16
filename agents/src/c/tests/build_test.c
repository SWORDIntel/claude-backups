/*
 * Simple build system test for Claude Agent Communication System
 * Tests that the build system can compile with compatibility layer
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Define the structure before including compatibility layer
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

#define ENHANCED_MSG_HEADER_T_DEFINED 1
#include "compatibility_layer.h"

void test_compatibility_functions(void) {
    printf("Testing compatibility layer functions:\n");
    
    // Test NUMA functions
    printf("  numa_available(): %d\n", numa_available());
    printf("  numa_max_node(): %d\n", numa_max_node());
    printf("  numa_num_configured_nodes(): %d\n", numa_num_configured_nodes());
    
    // Test memory allocation
    void* ptr = numa_alloc_onnode(1024, 0);
    if (ptr) {
        printf("  numa_alloc_onnode(): SUCCESS\n");
        numa_free(ptr, 1024);
        printf("  numa_free(): SUCCESS\n");
    }
    
    // Test message processing stubs
    enhanced_msg_header_t msg = {
        .magic = 0x41474549,  // "AGEI"
        .msg_type = 1,
        .payload_len = 64,
        .priority = 2
    };
    
    uint8_t payload[64] = {0};
    
    printf("  Testing message processing:\n");
    process_message_pcore(&msg, payload);
    printf("    process_message_pcore(): SUCCESS\n");
    
    process_message_ecore(&msg, payload);
    printf("    process_message_ecore(): SUCCESS\n");
    
    int result = ring_buffer_read_priority(NULL, 0, &msg, payload);
    printf("    ring_buffer_read_priority(): %d (expected 0)\n", result);
    
    void* work = work_queue_steal(NULL);
    printf("    work_queue_steal(): %p (expected NULL)\n", work);
}

void test_architecture_detection(void) {
    printf("\nTesting architecture detection:\n");
    
#ifdef __x86_64__
    printf("  Architecture: x86_64\n");
#endif
    
#ifdef __AVX2__
    printf("  AVX2: enabled\n");
#else
    printf("  AVX2: disabled\n");
#endif
    
#ifdef __AVX512F__
    printf("  AVX-512: enabled\n");
#else
    printf("  AVX-512: disabled\n");
#endif
    
    printf("  NUMA support: %s\n", HAVE_NUMA ? "yes" : "no");
    printf("  io_uring support: %s\n", HAVE_LIBURING ? "yes" : "no");
}

int main(void) {
    printf("Claude Agent Communication System - Build Test\n");
    printf("==============================================\n");
    printf("Version: %s\n", VERSION);
    
    test_architecture_detection();
    test_compatibility_functions();
    
    printf("\nBuild test completed successfully!\n");
    return 0;
}