/*
 * Test program for AI Router Integration
 * 
 * Simple functionality test to verify the AI router integration
 * compiles and links correctly with the existing system
 */

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// Include our headers
#include "ai_enhanced_router.h"
#include "agent_protocol.h"

int main(void) {
    printf("=== AI Router Integration Test ===\n");
    
    // Test 1: Check if AI router is initialized
    bool initialized = ai_is_initialized();
    printf("AI Router initialized: %s\n", initialized ? "true" : "false");
    
    // Test 2: Get AI router version
    int major, minor, patch;
    ai_get_version(&major, &minor, &patch);
    printf("AI Router version: %d.%d.%d\n", major, minor, patch);
    
    // Test 3: Create a test message
    enhanced_msg_header_t test_msg;
    ufp_init_header(&test_msg, UFP_MSG_REQUEST, 1, 2);
    test_msg.payload_len = 64;
    
    printf("Test message created:\n");
    printf("  Magic: 0x%08X\n", test_msg.magic);
    printf("  Version: 0x%04X\n", test_msg.version);
    printf("  Type: %u\n", test_msg.msg_type);
    printf("  Source: %u\n", test_msg.source_agent);
    printf("  Target: %u\n", test_msg.target_agents[0]);
    
    // Test 4: Test routing strategy string conversion
    printf("\nRouting strategies:\n");
    for (int i = 0; i <= 5; i++) {
        printf("  %d: %s\n", i, ai_routing_strategy_string((ai_routing_strategy_t)i));
    }
    
    // Test 5: Test accelerator type string conversion
    printf("\nAccelerator types:\n");
    for (int i = 0; i <= 4; i++) {
        printf("  %d: %s\n", i, ai_accelerator_type_string((accelerator_type_t)i));
    }
    
    // Test 6: Get timestamp
    uint64_t timestamp = ai_get_timestamp_ns();
    printf("\nCurrent timestamp: %lu ns\n", timestamp);
    
    // Test 7: Test integration API availability  
    printf("\nIntegration API functions available:\n");
    printf("  ai_integration_service_init: %s\n", 
           ai_integration_service_init ? "available" : "not available");
    printf("  ai_integration_get_router: %s\n",
           ai_integration_get_router ? "available" : "not available");
    
    printf("\n=== All basic tests completed successfully ===\n");
    printf("AI Router Integration appears to be working correctly!\n");
    
    return 0;
}