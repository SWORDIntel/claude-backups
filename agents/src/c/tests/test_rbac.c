/*
 * RBAC INTEGRATION TEST SUITE
 * 
 * Comprehensive test suite for Role-Based Access Control implementation
 * Tests JWT authentication, HMAC message signing, and permission enforcement
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
#include <assert.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>

// Include system headers - adapted for new test location
#include "../auth_security.h"
#include "../../binary-communications-system/ultra_fast_protocol.h"

// Agent bridge auth interface
extern void* create_agent_bridge(void);
extern int agent_bridge_set_jwt_token(void* bridge, const char* token);
extern int agent_bridge_validate_permission(void* bridge, uint32_t agent_id, const char* permission);

// Test configuration
#define TEST_AGENTS_COUNT 29
#define TEST_DURATION_SECONDS 10
#define TEST_MESSAGES_PER_AGENT 1000
#define MAX_TEST_FAILURES 10

// Test agent definitions
static const char* test_agents[TEST_AGENTS_COUNT] = {
    "APIDesigner", "Architect", "Bastion", "Constructor", "DataScience",
    "Database", "Debugger", "Deployer", "Director", "Docgen", "GNU",
    "Infrastructure", "Linter", "MLOps", "Mobile", "Monitor", "NPU",
    "Optimizer", "Oversight", "PLANNER", "Patcher", "ProjectOrchestrator",
    "PyGUI", "RESEARCHER", "Security", "SecurityChaosAgent", "TUI",
    "Testbed", "Web"
};

// Test role assignments
typedef struct {
    const char* agent_name;
    agent_role_t role;
    uint32_t permissions;
} agent_role_assignment_t;

static const agent_role_assignment_t test_role_assignments[TEST_AGENTS_COUNT] = {
    {"Director", ROLE_ADMIN, PERM_READ | PERM_WRITE | PERM_EXECUTE | PERM_ADMIN},
    {"ProjectOrchestrator", ROLE_SYSTEM, PERM_READ | PERM_WRITE | PERM_EXECUTE | PERM_SYSTEM},
    {"Security", ROLE_ADMIN, PERM_READ | PERM_WRITE | PERM_EXECUTE | PERM_ADMIN | PERM_SYSTEM},
    {"Bastion", ROLE_SYSTEM, PERM_READ | PERM_EXECUTE | PERM_SYSTEM},
    {"SecurityChaosAgent", ROLE_SYSTEM, PERM_READ | PERM_EXECUTE | PERM_SYSTEM},
    {"Monitor", ROLE_MONITOR, PERM_READ | PERM_MONITOR},
    {"Oversight", ROLE_MONITOR, PERM_READ | PERM_MONITOR},
    {"Infrastructure", ROLE_SYSTEM, PERM_READ | PERM_WRITE | PERM_EXECUTE | PERM_SYSTEM},
    {"Deployer", ROLE_SYSTEM, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Architect", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Constructor", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Patcher", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Debugger", ROLE_AGENT, PERM_READ | PERM_EXECUTE},
    {"Testbed", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Linter", ROLE_AGENT, PERM_READ | PERM_EXECUTE},
    {"Optimizer", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"APIDesigner", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Database", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Web", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Mobile", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"PyGUI", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"TUI", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"DataScience", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"MLOps", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"Docgen", ROLE_AGENT, PERM_READ | PERM_WRITE},
    {"RESEARCHER", ROLE_AGENT, PERM_READ},
    {"GNU", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"NPU", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE},
    {"PLANNER", ROLE_AGENT, PERM_READ | PERM_WRITE | PERM_EXECUTE}
};

// Test statistics
typedef struct {
    _Atomic uint64_t tokens_generated;
    _Atomic uint64_t tokens_validated;
    _Atomic uint64_t tokens_rejected;
    _Atomic uint64_t hmac_signatures_created;
    _Atomic uint64_t hmac_signatures_verified;
    _Atomic uint64_t hmac_failures;
    _Atomic uint64_t permission_checks_passed;
    _Atomic uint64_t permission_checks_failed;
    _Atomic uint64_t messages_sent;
    _Atomic uint64_t messages_received;
    uint64_t test_start_time;
    uint64_t test_end_time;
} rbac_test_stats_t;

static rbac_test_stats_t g_test_stats = {0};

// Test context
typedef struct {
    security_context_t* security_contexts[TEST_AGENTS_COUNT];
    jwt_token_t* agent_tokens[TEST_AGENTS_COUNT];
    pthread_t test_threads[TEST_AGENTS_COUNT];
    bool test_running;
    int test_failures;
    pthread_mutex_t failure_mutex;
} rbac_test_context_t;

static rbac_test_context_t g_test_ctx = {0};

// Utility functions
static uint64_t get_timestamp_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static void log_test_result(const char* test_name, bool passed, const char* details) {
    printf("[%s] %s: %s\n", passed ? "PASS" : "FAIL", test_name, details ? details : "");
    if (!passed) {
        pthread_mutex_lock(&g_test_ctx.failure_mutex);
        g_test_ctx.test_failures++;
        pthread_mutex_unlock(&g_test_ctx.failure_mutex);
    }
}

static void log_test_error(const char* test_name, const char* error_msg) {
    fprintf(stderr, "[ERROR] %s: %s\n", test_name, error_msg);
    pthread_mutex_lock(&g_test_ctx.failure_mutex);
    g_test_ctx.test_failures++;
    pthread_mutex_unlock(&g_test_ctx.failure_mutex);
}

// Test 1: JWT Token Generation and Validation
static bool test_jwt_token_operations() {
    printf("\n=== Testing JWT Token Operations ===\n");
    
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        const char* agent_name = test_agents[i];
        agent_role_t role = test_role_assignments[i].role;
        uint32_t permissions = test_role_assignments[i].permissions;
        
        security_context_t* ctx = auth_create_context(agent_name, role);
        if (!ctx) {
            log_test_error("JWT Token Generation", "Failed to create security context");
            return false;
        }
        
        g_test_ctx.security_contexts[i] = ctx;
        g_test_ctx.agent_tokens[i] = calloc(1, sizeof(jwt_token_t));
        
        // Test token generation
        auth_error_t result = jwt_generate_token(ctx, agent_name, role, permissions, 
                                               JWT_DEFAULT_EXPIRY_HOURS, 
                                               g_test_ctx.agent_tokens[i]);
        
        if (result != AUTH_SUCCESS) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Failed to generate token for %s: %d", 
                    agent_name, result);
            log_test_error("JWT Token Generation", error_msg);
            return false;
        }
        
        atomic_fetch_add(&g_test_stats.tokens_generated, 1);
        
        // Test token validation
        jwt_token_t validation_token;
        result = jwt_validate_token(ctx, g_test_ctx.agent_tokens[i]->token, &validation_token);
        
        if (result != AUTH_SUCCESS) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Failed to validate token for %s: %d", 
                    agent_name, result);
            log_test_error("JWT Token Validation", error_msg);
            return false;
        }
        
        atomic_fetch_add(&g_test_stats.tokens_validated, 1);
        
        // Verify token contents
        if (validation_token.payload.role != role) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Role mismatch for %s: expected %d, got %d", 
                    agent_name, role, validation_token.payload.role);
            log_test_error("JWT Token Validation", error_msg);
            return false;
        }
        
        if (validation_token.payload.permissions != permissions) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Permissions mismatch for %s: expected 0x%x, got 0x%x", 
                    agent_name, permissions, validation_token.payload.permissions);
            log_test_error("JWT Token Validation", error_msg);
            return false;
        }
        
        log_test_result("JWT Token Operations", true, agent_name);
    }
    
    printf("JWT Token Operations: Generated %lu tokens, validated %lu tokens\n",
           atomic_load(&g_test_stats.tokens_generated),
           atomic_load(&g_test_stats.tokens_validated));
    
    return true;
}

// Test 2: HMAC Message Signing and Verification
static bool test_hmac_operations() {
    printf("\n=== Testing HMAC Message Operations ===\n");
    
    const char* test_message = "Test message for HMAC verification";
    size_t message_len = strlen(test_message);
    
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        security_context_t* ctx = g_test_ctx.security_contexts[i];
        const char* agent_name = test_agents[i];
        
        unsigned char signature[HMAC_SIGNATURE_SIZE];
        size_t signature_len = sizeof(signature);
        
        // Test HMAC signing
        auth_error_t result = hmac_sign_message(ctx, test_message, message_len, 
                                              signature, &signature_len);
        
        if (result != AUTH_SUCCESS) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Failed to sign message for %s: %d", 
                    agent_name, result);
            log_test_error("HMAC Signing", error_msg);
            return false;
        }
        
        atomic_fetch_add(&g_test_stats.hmac_signatures_created, 1);
        
        // Test HMAC verification
        result = hmac_verify_signature(ctx, test_message, message_len, 
                                     signature, signature_len);
        
        if (result != AUTH_SUCCESS) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Failed to verify signature for %s: %d", 
                    agent_name, result);
            log_test_error("HMAC Verification", error_msg);
            return false;
        }
        
        atomic_fetch_add(&g_test_stats.hmac_signatures_verified, 1);
        
        // Test invalid signature detection
        signature[0] ^= 0xFF;  // Corrupt first byte
        result = hmac_verify_signature(ctx, test_message, message_len, 
                                     signature, signature_len);
        
        if (result == AUTH_SUCCESS) {
            char error_msg[256];
            snprintf(error_msg, sizeof(error_msg), "Failed to detect corrupted signature for %s", 
                    agent_name);
            log_test_error("HMAC Verification", error_msg);
            return false;
        }
        
        atomic_fetch_add(&g_test_stats.hmac_failures, 1);
        
        log_test_result("HMAC Operations", true, agent_name);
    }
    
    printf("HMAC Operations: Created %lu signatures, verified %lu signatures, detected %lu failures\n",
           atomic_load(&g_test_stats.hmac_signatures_created),
           atomic_load(&g_test_stats.hmac_signatures_verified),
           atomic_load(&g_test_stats.hmac_failures));
    
    return true;
}

// Test 3: RBAC Permission Enforcement
static bool test_rbac_permissions() {
    printf("\n=== Testing RBAC Permission Enforcement ===\n");
    
    const char* test_resources[] = {
        "system/config", "agent/execute", "data/read", "data/write", 
        "admin/users", "monitor/metrics", "system/shutdown"
    };
    const permission_t resource_permissions[] = {
        PERM_SYSTEM, PERM_EXECUTE, PERM_READ, PERM_WRITE,
        PERM_ADMIN, PERM_MONITOR, PERM_ADMIN | PERM_SYSTEM
    };
    const int num_resources = sizeof(test_resources) / sizeof(test_resources[0]);
    
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        security_context_t* ctx = g_test_ctx.security_contexts[i];
        const char* agent_name = test_agents[i];
        uint32_t agent_permissions = test_role_assignments[i].permissions;
        
        for (int r = 0; r < num_resources; r++) {
            auth_error_t result = rbac_check_permission(ctx, agent_name, 
                                                      test_resources[r], 
                                                      resource_permissions[r]);
            
            bool should_have_access = (agent_permissions & resource_permissions[r]) == resource_permissions[r];
            bool has_access = (result == AUTH_SUCCESS);
            
            if (should_have_access != has_access) {
                char error_msg[512];
                snprintf(error_msg, sizeof(error_msg), 
                        "Permission mismatch for %s on %s: expected %s, got %s",
                        agent_name, test_resources[r],
                        should_have_access ? "ALLOW" : "DENY",
                        has_access ? "ALLOW" : "DENY");
                log_test_error("RBAC Permission Check", error_msg);
                return false;
            }
            
            if (has_access) {
                atomic_fetch_add(&g_test_stats.permission_checks_passed, 1);
            } else {
                atomic_fetch_add(&g_test_stats.permission_checks_failed, 1);
            }
        }
        
        log_test_result("RBAC Permissions", true, agent_name);
    }
    
    printf("RBAC Permissions: %lu checks passed, %lu checks failed (as expected)\n",
           atomic_load(&g_test_stats.permission_checks_passed),
           atomic_load(&g_test_stats.permission_checks_failed));
    
    return true;
}

// Test 4: Cross-Agent Authentication
static void* agent_authentication_test_thread(void* arg) {
    int agent_id = *(int*)arg;
    const char* agent_name = test_agents[agent_id];
    security_context_t* ctx = g_test_ctx.security_contexts[agent_id];
    
    while (g_test_ctx.test_running) {
        // Test authenticating with other agents' tokens
        for (int other_agent = 0; other_agent < TEST_AGENTS_COUNT; other_agent++) {
            if (other_agent == agent_id) continue;
            
            jwt_token_t validation_token;
            auth_error_t result = jwt_validate_token(ctx, 
                                                   g_test_ctx.agent_tokens[other_agent]->token, 
                                                   &validation_token);
            
            if (result == AUTH_SUCCESS) {
                atomic_fetch_add(&g_test_stats.tokens_validated, 1);
                
                // Test cross-agent permission check
                const char* other_agent_name = test_agents[other_agent];
                result = rbac_check_permission(ctx, other_agent_name, "system/status", PERM_READ);
                
                if (result == AUTH_SUCCESS) {
                    atomic_fetch_add(&g_test_stats.permission_checks_passed, 1);
                } else {
                    atomic_fetch_add(&g_test_stats.permission_checks_failed, 1);
                }
            } else {
                atomic_fetch_add(&g_test_stats.tokens_rejected, 1);
            }
        }
        
        usleep(1000);  // 1ms delay
    }
    
    return NULL;
}

static bool test_cross_agent_authentication() {
    printf("\n=== Testing Cross-Agent Authentication ===\n");
    
    g_test_ctx.test_running = true;
    
    // Start authentication test threads
    int agent_ids[TEST_AGENTS_COUNT];
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        agent_ids[i] = i;
        pthread_create(&g_test_ctx.test_threads[i], NULL, 
                      agent_authentication_test_thread, &agent_ids[i]);
    }
    
    // Run test for specified duration
    sleep(TEST_DURATION_SECONDS);
    
    // Stop test threads
    g_test_ctx.test_running = false;
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        pthread_join(g_test_ctx.test_threads[i], NULL);
    }
    
    uint64_t total_validations = atomic_load(&g_test_stats.tokens_validated) - 
                                atomic_load(&g_test_stats.tokens_generated);
    uint64_t total_rejections = atomic_load(&g_test_stats.tokens_rejected);
    
    printf("Cross-Agent Authentication: %lu validations, %lu rejections in %d seconds\n",
           total_validations, total_rejections, TEST_DURATION_SECONDS);
    
    log_test_result("Cross-Agent Authentication", true, "Completed successfully");
    
    return true;
}

// Test 5: Security Event Logging
static bool test_security_logging() {
    printf("\n=== Testing Security Event Logging ===\n");
    
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        security_context_t* ctx = g_test_ctx.security_contexts[i];
        const char* agent_name = test_agents[i];
        
        // Test various security events
        auth_error_t result;
        
        result = audit_log_event(ctx, SEC_EVENT_LOGIN_SUCCESS, agent_name, 0x7F000001,
                               "Agent authentication successful", "Unit test");
        if (result != AUTH_SUCCESS) {
            log_test_error("Security Logging", "Failed to log login success event");
            return false;
        }
        
        result = audit_log_entry(ctx, agent_name, "AUTHENTICATE", "system", "SUCCESS",
                               "JWT token validated", 10);
        if (result != AUTH_SUCCESS) {
            log_test_error("Security Logging", "Failed to log audit entry");
            return false;
        }
        
        // Test permission denied event
        result = audit_log_event(ctx, SEC_EVENT_PERMISSION_DENIED, agent_name, 0x7F000001,
                               "Access denied for restricted resource", "Unit test");
        if (result != AUTH_SUCCESS) {
            log_test_error("Security Logging", "Failed to log permission denied event");
            return false;
        }
        
        log_test_result("Security Logging", true, agent_name);
    }
    
    // Flush logs
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        audit_flush_logs(g_test_ctx.security_contexts[i]);
    }
    
    return true;
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("RBAC INTEGRATION TEST SUITE\n");
    printf("===========================\n");
    printf("Testing %d agents for RBAC functionality\n\n", TEST_AGENTS_COUNT);
    
    // Initialize test context
    pthread_mutex_init(&g_test_ctx.failure_mutex, NULL);
    g_test_stats.test_start_time = get_timestamp_ns();
    
    // Initialize authentication system
    if (auth_init(NULL) != AUTH_SUCCESS) {
        fprintf(stderr, "Failed to initialize authentication system\n");
        return 1;
    }
    
    bool all_tests_passed = true;
    
    // Run test suite
    all_tests_passed &= test_jwt_token_operations();
    all_tests_passed &= test_hmac_operations();
    all_tests_passed &= test_rbac_permissions();
    all_tests_passed &= test_cross_agent_authentication();
    all_tests_passed &= test_security_logging();
    
    g_test_stats.test_end_time = get_timestamp_ns();
    
    // Print final results
    printf("\n=== TEST SUMMARY ===\n");
    printf("Total Agents Tested: %d\n", TEST_AGENTS_COUNT);
    printf("Test Duration: %.2f seconds\n", 
           (g_test_stats.test_end_time - g_test_stats.test_start_time) / 1e9);
    printf("Test Failures: %d\n", g_test_ctx.test_failures);
    
    printf("\nStatistics:\n");
    printf("  JWT Tokens Generated: %lu\n", atomic_load(&g_test_stats.tokens_generated));
    printf("  JWT Tokens Validated: %lu\n", atomic_load(&g_test_stats.tokens_validated));
    printf("  JWT Tokens Rejected: %lu\n", atomic_load(&g_test_stats.tokens_rejected));
    printf("  HMAC Signatures Created: %lu\n", atomic_load(&g_test_stats.hmac_signatures_created));
    printf("  HMAC Signatures Verified: %lu\n", atomic_load(&g_test_stats.hmac_signatures_verified));
    printf("  HMAC Failures Detected: %lu\n", atomic_load(&g_test_stats.hmac_failures));
    printf("  Permission Checks Passed: %lu\n", atomic_load(&g_test_stats.permission_checks_passed));
    printf("  Permission Checks Failed: %lu\n", atomic_load(&g_test_stats.permission_checks_failed));
    
    // Cleanup
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        if (g_test_ctx.agent_tokens[i]) {
            free(g_test_ctx.agent_tokens[i]);
        }
        if (g_test_ctx.security_contexts[i]) {
            auth_destroy_context(g_test_ctx.security_contexts[i]);
        }
    }
    
    auth_cleanup();
    pthread_mutex_destroy(&g_test_ctx.failure_mutex);
    
    if (all_tests_passed && g_test_ctx.test_failures == 0) {
        printf("\n[RESULT] ALL RBAC TESTS PASSED\n");
        return 0;
    } else {
        printf("\n[RESULT] RBAC TESTS FAILED (%d failures)\n", g_test_ctx.test_failures);
        return 1;
    }
}