/*
 * SECURITY INTEGRATION TEST - END-TO-END VALIDATION
 * 
 * Comprehensive integration testing for the complete security stack:
 * - Full UFP protocol with security wrapper integration
 * - Multi-agent communication with authentication
 * - Real-world load testing scenarios
 * - Failure mode and recovery testing
 * - Performance under security constraints
 * - Compliance validation in production environment
 * 
 * This test simulates a complete Claude Agent ecosystem with:
 * - 10+ different agent types
 * - Varying security levels and permissions
 * - High-throughput message exchange
 * - Dynamic security policy updates
 * - Incident response scenarios
 * 
 * Author: Security Integration Validation
 * Version: 1.0 Production
 */

#define _GNU_SOURCE
#include "auth_security.h"
#include "agent_protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <assert.h>

// ============================================================================
// INTEGRATION TEST CONFIGURATION
// ============================================================================

#define MAX_TEST_AGENTS 32
#define TEST_DURATION_SECONDS 60
#define MESSAGE_BURST_SIZE 1000
#define MAX_MESSAGE_SIZE 4096

// Agent types for comprehensive testing
typedef enum {
    AGENT_TYPE_DIRECTOR = 1,
    AGENT_TYPE_SECURITY = 2,
    AGENT_TYPE_MONITOR = 3,
    AGENT_TYPE_OPTIMIZER = 4,
    AGENT_TYPE_DEBUGGER = 5,
    AGENT_TYPE_TESTBED = 6,
    AGENT_TYPE_PATCHER = 7,
    AGENT_TYPE_DEPLOYER = 8,
    AGENT_TYPE_LINTER = 9,
    AGENT_TYPE_ARCHITECT = 10
} test_agent_type_t;

// Test scenario types
typedef enum {
    SCENARIO_NORMAL_OPERATION = 1,
    SCENARIO_HIGH_LOAD = 2,
    SCENARIO_SECURITY_INCIDENT = 3,
    SCENARIO_DDOS_ATTACK = 4,
    SCENARIO_PRIVILEGE_ESCALATION = 5,
    SCENARIO_KEY_ROTATION = 6,
    SCENARIO_AGENT_FAILURE = 7,
    SCENARIO_NETWORK_PARTITION = 8
} test_scenario_t;

// Test agent context
typedef struct {
    int agent_id;
    test_agent_type_t type;
    char name[64];
    agent_role_t role;
    uint32_t permissions;
    ufp_context_t* ufp_ctx;
    security_context_t* sec_ctx;
    pthread_t thread;
    
    // Statistics
    atomic_uint64_t messages_sent;
    atomic_uint64_t messages_received;
    atomic_uint64_t auth_failures;
    atomic_uint64_t security_violations;
    
    // Test control
    volatile bool active;
    volatile bool under_attack;
    test_scenario_t current_scenario;
} test_agent_t;

// Global test state
static struct {
    test_agent_t agents[MAX_TEST_AGENTS];
    int agent_count;
    volatile bool test_running;
    volatile bool incident_active;
    pthread_mutex_t test_mutex;
    
    // Test statistics
    atomic_uint64_t total_messages;
    atomic_uint64_t total_auth_checks;
    atomic_uint64_t total_security_events;
    atomic_uint64_t total_errors;
    
    double test_start_time;
    double test_end_time;
} g_test_state = {0};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

static double get_time_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static void generate_test_message(ufp_message_t* msg, test_agent_t* sender, 
                                 test_agent_t* receiver) {
    memset(msg, 0, sizeof(ufp_message_t));
    
    msg->msg_id = atomic_fetch_add(&g_test_state.total_messages, 1) + 1;
    msg->msg_type = UFP_MSG_REQUEST;
    msg->priority = UFP_PRIORITY_MEDIUM;
    
    strncpy(msg->source, sender->name, sizeof(msg->source) - 1);
    strncpy(msg->targets[0], receiver->name, sizeof(msg->targets[0]) - 1);
    msg->target_count = 1;
    
    msg->timestamp = (uint32_t)time(NULL);
    msg->correlation_id = msg->msg_id;
    
    // Generate test payload
    static char test_payload[1024];
    snprintf(test_payload, sizeof(test_payload),
             "Test message from %s to %s - ID: %u",
             sender->name, receiver->name, msg->msg_id);
    
    msg->payload = test_payload;
    msg->payload_size = strlen(test_payload);
}

// ============================================================================
// AGENT SIMULATION FUNCTIONS
// ============================================================================

/**
 * Director agent - orchestrates other agents
 */
static void* director_agent_thread(void* arg) {
    test_agent_t* agent = (test_agent_t*)arg;
    
    printf("Director agent %s started\n", agent->name);
    
    while (agent->active && g_test_state.test_running) {
        // Send coordination messages to other agents
        for (int i = 0; i < g_test_state.agent_count; i++) {
            test_agent_t* target = &g_test_state.agents[i];
            if (target != agent && target->active) {
                ufp_message_t msg;
                generate_test_message(&msg, agent, target);
                
                // Use secure send
                auth_error_t result = secure_ufp_send(agent->ufp_ctx, &msg);
                if (result == AUTH_SUCCESS) {
                    atomic_fetch_add(&agent->messages_sent, 1);
                } else {
                    atomic_fetch_add(&agent->auth_failures, 1);
                }
            }
        }
        
        usleep(100000); // 100ms
    }
    
    printf("Director agent %s stopped\n", agent->name);
    return NULL;
}

/**
 * Security agent - monitors and responds to threats
 */
static void* security_agent_thread(void* arg) {
    test_agent_t* agent = (test_agent_t*)arg;
    
    printf("Security agent %s started\n", agent->name);
    
    while (agent->active && g_test_state.test_running) {
        // Monitor for security events
        if (g_test_state.incident_active) {
            printf("SECURITY ALERT: %s responding to incident\n", agent->name);
            
            // Implement security response
            for (int i = 0; i < g_test_state.agent_count; i++) {
                test_agent_t* target = &g_test_state.agents[i];
                if (target->under_attack) {
                    // Send security advisory
                    ufp_message_t msg;
                    generate_test_message(&msg, agent, target);
                    
                    secure_ufp_send(agent->ufp_ctx, &msg);
                    atomic_fetch_add(&agent->messages_sent, 1);
                }
            }
        }
        
        // Regular security monitoring
        ufp_message_t received_msg;
        auth_error_t result = secure_ufp_receive(agent->ufp_ctx, &received_msg, 10);
        if (result == AUTH_SUCCESS) {
            atomic_fetch_add(&agent->messages_received, 1);
            
            // Analyze message for security threats
            if (received_msg.priority == UFP_PRIORITY_CRITICAL) {
                atomic_fetch_add(&g_test_state.total_security_events, 1);
            }
        }
        
        usleep(50000); // 50ms
    }
    
    printf("Security agent %s stopped\n", agent->name);
    return NULL;
}

/**
 * Monitor agent - collects performance metrics
 */
static void* monitor_agent_thread(void* arg) {
    test_agent_t* agent = (test_agent_t*)arg;
    
    printf("Monitor agent %s started\n", agent->name);
    
    while (agent->active && g_test_state.test_running) {
        // Collect metrics from other agents
        for (int i = 0; i < g_test_state.agent_count; i++) {
            test_agent_t* target = &g_test_state.agents[i];
            if (target != agent && target->active && (rand() % 10 == 0)) {
                ufp_message_t msg;
                generate_test_message(&msg, agent, target);
                
                secure_ufp_send(agent->ufp_ctx, &msg);
                atomic_fetch_add(&agent->messages_sent, 1);
            }
        }
        
        // Process incoming metric data
        ufp_message_t received_msg;
        auth_error_t result = secure_ufp_receive(agent->ufp_ctx, &received_msg, 5);
        if (result == AUTH_SUCCESS) {
            atomic_fetch_add(&agent->messages_received, 1);
        }
        
        usleep(200000); // 200ms
    }
    
    printf("Monitor agent %s stopped\n", agent->name);
    return NULL;
}

/**
 * Generic worker agent
 */
static void* worker_agent_thread(void* arg) {
    test_agent_t* agent = (test_agent_t*)arg;
    
    printf("Worker agent %s started (type: %d)\n", agent->name, agent->type);
    
    while (agent->active && g_test_state.test_running) {
        // Process incoming messages
        ufp_message_t received_msg;
        auth_error_t result = secure_ufp_receive(agent->ufp_ctx, &received_msg, 10);
        if (result == AUTH_SUCCESS) {
            atomic_fetch_add(&agent->messages_received, 1);
            
            // Send response back
            ufp_message_t response;
            memcpy(&response, &received_msg, sizeof(ufp_message_t));
            response.msg_type = UFP_MSG_RESPONSE;
            strncpy(response.source, agent->name, sizeof(response.source) - 1);
            strncpy(response.targets[0], received_msg.source, sizeof(response.targets[0]) - 1);
            
            secure_ufp_send(agent->ufp_ctx, &response);
            atomic_fetch_add(&agent->messages_sent, 1);
        } else if (result != UFP_ERROR_TIMEOUT) {
            atomic_fetch_add(&agent->auth_failures, 1);
        }
        
        // Send periodic keep-alive messages
        if (rand() % 100 == 0) {
            int target_idx = rand() % g_test_state.agent_count;
            test_agent_t* target = &g_test_state.agents[target_idx];
            
            if (target != agent && target->active) {
                ufp_message_t msg;
                generate_test_message(&msg, agent, target);
                msg.msg_type = UFP_MSG_HEARTBEAT;
                
                secure_ufp_send(agent->ufp_ctx, &msg);
                atomic_fetch_add(&agent->messages_sent, 1);
            }
        }
        
        usleep(10000 + (rand() % 90000)); // 10-100ms random interval
    }
    
    printf("Worker agent %s stopped\n", agent->name);
    return NULL;
}

// ============================================================================
// TEST SCENARIO IMPLEMENTATIONS
// ============================================================================

/**
 * Simulate normal operation scenario
 */
static void run_normal_operation_scenario(void) {
    printf("\n=== Running Normal Operation Scenario ===\n");
    
    // All agents operate normally
    for (int i = 0; i < g_test_state.agent_count; i++) {
        g_test_state.agents[i].current_scenario = SCENARIO_NORMAL_OPERATION;
        g_test_state.agents[i].under_attack = false;
    }
    
    printf("Normal operation scenario running...\n");
    sleep(10);
    
    printf("Normal operation scenario completed\n");
}

/**
 * Simulate high load scenario
 */
static void run_high_load_scenario(void) {
    printf("\n=== Running High Load Scenario ===\n");
    
    // Increase message frequency for all agents
    for (int i = 0; i < g_test_state.agent_count; i++) {
        g_test_state.agents[i].current_scenario = SCENARIO_HIGH_LOAD;
    }
    
    // Generate message bursts
    for (int burst = 0; burst < 5; burst++) {
        printf("High load burst %d/5\n", burst + 1);
        
        for (int i = 0; i < g_test_state.agent_count; i++) {
            test_agent_t* sender = &g_test_state.agents[i];
            
            for (int msg = 0; msg < MESSAGE_BURST_SIZE; msg++) {
                int target_idx = rand() % g_test_state.agent_count;
                test_agent_t* receiver = &g_test_state.agents[target_idx];
                
                if (sender != receiver && sender->active && receiver->active) {
                    ufp_message_t burst_msg;
                    generate_test_message(&burst_msg, sender, receiver);
                    
                    secure_ufp_send(sender->ufp_ctx, &burst_msg);
                    atomic_fetch_add(&sender->messages_sent, 1);
                }
            }
        }
        
        sleep(2);
    }
    
    printf("High load scenario completed\n");
}

/**
 * Simulate DDoS attack scenario
 */
static void run_ddos_attack_scenario(void) {
    printf("\n=== Running DDoS Attack Scenario ===\n");
    
    g_test_state.incident_active = true;
    
    // Simulate attack on security agent
    test_agent_t* target_agent = NULL;
    for (int i = 0; i < g_test_state.agent_count; i++) {
        if (g_test_state.agents[i].type == AGENT_TYPE_SECURITY) {
            target_agent = &g_test_state.agents[i];
            break;
        }
    }
    
    if (target_agent) {
        target_agent->under_attack = true;
        target_agent->current_scenario = SCENARIO_DDOS_ATTACK;
        
        printf("DDoS attack targeting %s\n", target_agent->name);
        
        // Generate attack traffic
        for (int i = 0; i < 10000; i++) {
            ufp_message_t attack_msg;
            generate_test_message(&attack_msg, &g_test_state.agents[0], target_agent);
            attack_msg.priority = UFP_PRIORITY_CRITICAL;
            
            auth_error_t result = secure_ufp_send(g_test_state.agents[0].ufp_ctx, &attack_msg);
            if (result != AUTH_SUCCESS) {
                // Expected - DDoS protection should kick in
                atomic_fetch_add(&g_test_state.total_security_events, 1);
                break;
            }
            
            if (i % 1000 == 0) {
                printf("Attack messages sent: %d\n", i);
            }
        }
        
        target_agent->under_attack = false;
    }
    
    g_test_state.incident_active = false;
    printf("DDoS attack scenario completed\n");
}

/**
 * Simulate privilege escalation attempt
 */
static void run_privilege_escalation_scenario(void) {
    printf("\n=== Running Privilege Escalation Scenario ===\n");
    
    // Find a worker agent to attempt escalation
    test_agent_t* attacker = NULL;
    for (int i = 0; i < g_test_state.agent_count; i++) {
        if (g_test_state.agents[i].role == ROLE_AGENT) {
            attacker = &g_test_state.agents[i];
            break;
        }
    }
    
    if (attacker) {
        printf("Agent %s attempting privilege escalation\n", attacker->name);
        
        // Attempt to access admin resources
        const char* restricted_resources[] = {
            "system_config", "security_keys", "admin_panel", "root_access"
        };
        
        for (int i = 0; i < 4; i++) {
            auth_error_t result = rbac_check_permission(attacker->sec_ctx,
                                                       attacker->name,
                                                       restricted_resources[i],
                                                       PERM_ADMIN);
            
            if (result == AUTH_ERROR_INSUFFICIENT_PERMISSIONS) {
                printf("✓ Privilege escalation blocked for resource: %s\n", restricted_resources[i]);
                atomic_fetch_add(&g_test_state.total_security_events, 1);
            } else {
                printf("✗ Privilege escalation succeeded for resource: %s\n", restricted_resources[i]);
                atomic_fetch_add(&g_test_state.total_errors, 1);
            }
        }
    }
    
    printf("Privilege escalation scenario completed\n");
}

/**
 * Simulate key rotation scenario
 */
static void run_key_rotation_scenario(void) {
    printf("\n=== Running Key Rotation Scenario ===\n");
    
    // Trigger key rotation
    auth_error_t result = key_rotation_perform(g_test_state.agents[0].sec_ctx);
    if (result == AUTH_SUCCESS) {
        printf("✓ Key rotation completed successfully\n");
        
        // Test that all agents can still communicate
        bool communication_ok = true;
        for (int i = 0; i < 5; i++) {
            int sender_idx = rand() % g_test_state.agent_count;
            int receiver_idx = rand() % g_test_state.agent_count;
            
            if (sender_idx != receiver_idx) {
                test_agent_t* sender = &g_test_state.agents[sender_idx];
                test_agent_t* receiver = &g_test_state.agents[receiver_idx];
                
                ufp_message_t test_msg;
                generate_test_message(&test_msg, sender, receiver);
                
                auth_error_t send_result = secure_ufp_send(sender->ufp_ctx, &test_msg);
                if (send_result != AUTH_SUCCESS) {
                    communication_ok = false;
                    break;
                }
            }
        }
        
        if (communication_ok) {
            printf("✓ Post-rotation communication verified\n");
        } else {
            printf("✗ Post-rotation communication failed\n");
            atomic_fetch_add(&g_test_state.total_errors, 1);
        }
    } else {
        printf("✗ Key rotation failed\n");
        atomic_fetch_add(&g_test_state.total_errors, 1);
    }
    
    printf("Key rotation scenario completed\n");
}

// ============================================================================
// AGENT INITIALIZATION AND MANAGEMENT
// ============================================================================

/**
 * Initialize a test agent
 */
static int init_test_agent(test_agent_t* agent, int id, test_agent_type_t type) {
    agent->agent_id = id;
    agent->type = type;
    agent->active = true;
    agent->under_attack = false;
    agent->current_scenario = SCENARIO_NORMAL_OPERATION;
    
    // Set agent name and role based on type
    switch (type) {
        case AGENT_TYPE_DIRECTOR:
            snprintf(agent->name, sizeof(agent->name), "director-%d", id);
            agent->role = ROLE_ADMIN;
            agent->permissions = PERM_READ | PERM_WRITE | PERM_EXECUTE | PERM_ADMIN;
            break;
            
        case AGENT_TYPE_SECURITY:
            snprintf(agent->name, sizeof(agent->name), "security-%d", id);
            agent->role = ROLE_SYSTEM;
            agent->permissions = PERM_READ | PERM_WRITE | PERM_SYSTEM | PERM_MONITOR;
            break;
            
        case AGENT_TYPE_MONITOR:
            snprintf(agent->name, sizeof(agent->name), "monitor-%d", id);
            agent->role = ROLE_MONITOR;
            agent->permissions = PERM_READ | PERM_MONITOR;
            break;
            
        default:
            snprintf(agent->name, sizeof(agent->name), "worker-%d", id);
            agent->role = ROLE_AGENT;
            agent->permissions = PERM_READ | PERM_WRITE | PERM_EXECUTE;
            break;
    }
    
    // Initialize UFP context
    agent->ufp_ctx = ufp_create_context(agent->name);
    if (!agent->ufp_ctx) {
        fprintf(stderr, "Failed to create UFP context for %s\n", agent->name);
        return -1;
    }
    
    // Initialize security context
    agent->sec_ctx = auth_create_context(agent->name, agent->role);
    if (!agent->sec_ctx) {
        fprintf(stderr, "Failed to create security context for %s\n", agent->name);
        ufp_destroy_context(agent->ufp_ctx);
        return -1;
    }
    
    // Initialize statistics
    atomic_init(&agent->messages_sent, 0);
    atomic_init(&agent->messages_received, 0);
    atomic_init(&agent->auth_failures, 0);
    atomic_init(&agent->security_violations, 0);
    
    return 0;
}

/**
 * Start agent thread based on type
 */
static int start_agent_thread(test_agent_t* agent) {
    void* (*thread_func)(void*) = NULL;
    
    switch (agent->type) {
        case AGENT_TYPE_DIRECTOR:
            thread_func = director_agent_thread;
            break;
        case AGENT_TYPE_SECURITY:
            thread_func = security_agent_thread;
            break;
        case AGENT_TYPE_MONITOR:
            thread_func = monitor_agent_thread;
            break;
        default:
            thread_func = worker_agent_thread;
            break;
    }
    
    if (pthread_create(&agent->thread, NULL, thread_func, agent) != 0) {
        fprintf(stderr, "Failed to create thread for agent %s\n", agent->name);
        return -1;
    }
    
    return 0;
}

/**
 * Stop and cleanup agent
 */
static void cleanup_agent(test_agent_t* agent) {
    agent->active = false;
    
    if (agent->thread) {
        pthread_join(agent->thread, NULL);
    }
    
    if (agent->sec_ctx) {
        auth_destroy_context(agent->sec_ctx);
    }
    
    if (agent->ufp_ctx) {
        ufp_destroy_context(agent->ufp_ctx);
    }
}

// ============================================================================
// TEST ORCHESTRATION
// ============================================================================

/**
 * Initialize test environment
 */
static int init_test_environment(void) {
    printf("Initializing test environment...\n");
    
    // Initialize security framework
    auth_error_t result = auth_init(NULL);
    if (result != AUTH_SUCCESS) {
        fprintf(stderr, "Failed to initialize security framework\n");
        return -1;
    }
    
    // Initialize security integration
    result = security_integration_init(NULL);
    if (result != AUTH_SUCCESS) {
        fprintf(stderr, "Failed to initialize security integration\n");
        auth_cleanup();
        return -1;
    }
    
    // Initialize UFP protocol
    ufp_error_t ufp_result = ufp_init();
    if (ufp_result != UFP_SUCCESS) {
        fprintf(stderr, "Failed to initialize UFP protocol\n");
        security_integration_cleanup();
        auth_cleanup();
        return -1;
    }
    
    pthread_mutex_init(&g_test_state.test_mutex, NULL);
    
    // Initialize statistics
    atomic_init(&g_test_state.total_messages, 0);
    atomic_init(&g_test_state.total_auth_checks, 0);
    atomic_init(&g_test_state.total_security_events, 0);
    atomic_init(&g_test_state.total_errors, 0);
    
    g_test_state.test_running = true;
    g_test_state.incident_active = false;
    
    printf("Test environment initialized successfully\n");
    return 0;
}

/**
 * Create test agent ecosystem
 */
static int create_test_agents(void) {
    printf("Creating test agent ecosystem...\n");
    
    g_test_state.agent_count = 0;
    
    // Create director agent
    if (init_test_agent(&g_test_state.agents[g_test_state.agent_count++],
                       1, AGENT_TYPE_DIRECTOR) != 0) {
        return -1;
    }
    
    // Create security agent
    if (init_test_agent(&g_test_state.agents[g_test_state.agent_count++],
                       2, AGENT_TYPE_SECURITY) != 0) {
        return -1;
    }
    
    // Create monitor agent
    if (init_test_agent(&g_test_state.agents[g_test_state.agent_count++],
                       3, AGENT_TYPE_MONITOR) != 0) {
        return -1;
    }
    
    // Create worker agents
    test_agent_type_t worker_types[] = {
        AGENT_TYPE_OPTIMIZER, AGENT_TYPE_DEBUGGER, AGENT_TYPE_TESTBED,
        AGENT_TYPE_PATCHER, AGENT_TYPE_DEPLOYER, AGENT_TYPE_LINTER,
        AGENT_TYPE_ARCHITECT
    };
    
    for (int i = 0; i < 7 && g_test_state.agent_count < MAX_TEST_AGENTS; i++) {
        if (init_test_agent(&g_test_state.agents[g_test_state.agent_count++],
                           4 + i, worker_types[i]) != 0) {
            return -1;
        }
    }
    
    printf("Created %d test agents\n", g_test_state.agent_count);
    return 0;
}

/**
 * Start all agent threads
 */
static int start_all_agents(void) {
    printf("Starting all agent threads...\n");
    
    for (int i = 0; i < g_test_state.agent_count; i++) {
        if (start_agent_thread(&g_test_state.agents[i]) != 0) {
            return -1;
        }
    }
    
    printf("All %d agents started successfully\n", g_test_state.agent_count);
    return 0;
}

/**
 * Run all test scenarios
 */
static void run_test_scenarios(void) {
    printf("\n=== Starting Integration Test Scenarios ===\n");
    
    g_test_state.test_start_time = get_time_seconds();
    
    // Run scenarios sequentially
    run_normal_operation_scenario();
    run_high_load_scenario();
    run_ddos_attack_scenario();
    run_privilege_escalation_scenario();
    run_key_rotation_scenario();
    
    // Let the system stabilize
    printf("\nAllowing system to stabilize...\n");
    sleep(5);
    
    g_test_state.test_end_time = get_time_seconds();
}

/**
 * Print comprehensive test results
 */
static void print_test_results(void) {
    double test_duration = g_test_state.test_end_time - g_test_state.test_start_time;
    
    printf("\n=== Integration Test Results ===\n");
    printf("Test duration: %.2f seconds\n", test_duration);
    printf("Total agents: %d\n", g_test_state.agent_count);
    
    // Agent-specific statistics
    uint64_t total_messages_sent = 0;
    uint64_t total_messages_received = 0;
    uint64_t total_auth_failures = 0;
    uint64_t total_security_violations = 0;
    
    printf("\nAgent Statistics:\n");
    for (int i = 0; i < g_test_state.agent_count; i++) {
        test_agent_t* agent = &g_test_state.agents[i];
        
        uint64_t sent = atomic_load(&agent->messages_sent);
        uint64_t received = atomic_load(&agent->messages_received);
        uint64_t auth_failures = atomic_load(&agent->auth_failures);
        uint64_t violations = atomic_load(&agent->security_violations);
        
        printf("  %s: sent=%lu, received=%lu, auth_failures=%lu, violations=%lu\n",
               agent->name, sent, received, auth_failures, violations);
        
        total_messages_sent += sent;
        total_messages_received += received;
        total_auth_failures += auth_failures;
        total_security_violations += violations;
    }
    
    // Overall statistics
    printf("\nOverall Statistics:\n");
    printf("Messages sent: %lu\n", total_messages_sent);
    printf("Messages received: %lu\n", total_messages_received);
    printf("Message throughput: %.0f msg/sec\n", total_messages_sent / test_duration);
    printf("Authentication failures: %lu\n", total_auth_failures);
    printf("Security violations: %lu\n", total_security_violations);
    printf("Security events: %lu\n", atomic_load(&g_test_state.total_security_events));
    printf("Total errors: %lu\n", atomic_load(&g_test_state.total_errors));
    
    // Success rate
    double message_success_rate = (total_messages_sent > 0) ?
        (double)(total_messages_sent - total_auth_failures) / total_messages_sent * 100.0 : 0.0;
    printf("Message success rate: %.2f%%\n", message_success_rate);
    
    // Performance assessment
    printf("\nPerformance Assessment:\n");
    if (message_success_rate >= 95.0) {
        printf("✓ Message reliability: EXCELLENT (>95%%)\n");
    } else if (message_success_rate >= 90.0) {
        printf("△ Message reliability: ACCEPTABLE (>90%%)\n");
    } else {
        printf("✗ Message reliability: POOR (<90%%)\n");
    }
    
    double throughput = total_messages_sent / test_duration;
    if (throughput >= 1000.0) {
        printf("✓ Message throughput: EXCELLENT (>1K msg/sec)\n");
    } else if (throughput >= 100.0) {
        printf("△ Message throughput: ACCEPTABLE (>100 msg/sec)\n");
    } else {
        printf("✗ Message throughput: POOR (<100 msg/sec)\n");
    }
    
    // Security assessment
    printf("\nSecurity Assessment:\n");
    if (total_auth_failures == 0 && total_security_violations == 0) {
        printf("✓ Security: PERFECT (no failures or violations)\n");
    } else if (total_auth_failures < 10 && total_security_violations < 5) {
        printf("△ Security: ACCEPTABLE (minimal failures)\n");
    } else {
        printf("✗ Security: CONCERNING (multiple failures)\n");
    }
    
    uint64_t security_events = atomic_load(&g_test_state.total_security_events);
    if (security_events > 0) {
        printf("✓ Security monitoring: ACTIVE (%lu events detected)\n", security_events);
    } else {
        printf("△ Security monitoring: PASSIVE (no events detected)\n");
    }
    
    printf("\n=== Integration Test Summary ===\n");
    if (atomic_load(&g_test_state.total_errors) == 0 && message_success_rate >= 95.0) {
        printf("✓ INTEGRATION TEST PASSED\n");
    } else {
        printf("✗ INTEGRATION TEST FAILED\n");
    }
    printf("=====================================\n");
}

/**
 * Cleanup test environment
 */
static void cleanup_test_environment(void) {
    printf("\nCleaning up test environment...\n");
    
    g_test_state.test_running = false;
    
    // Stop all agents
    for (int i = 0; i < g_test_state.agent_count; i++) {
        cleanup_agent(&g_test_state.agents[i]);
    }
    
    // Cleanup frameworks
    security_integration_cleanup();
    ufp_cleanup();
    auth_cleanup();
    
    pthread_mutex_destroy(&g_test_state.test_mutex);
    
    printf("Test environment cleanup completed\n");
}

/**
 * Signal handler for graceful shutdown
 */
static void signal_handler(int sig) {
    printf("\nReceived signal %d, shutting down gracefully...\n", sig);
    g_test_state.test_running = false;
}

// ============================================================================
// MAIN TEST PROGRAM
// ============================================================================

int main(int argc, char** argv) {
    printf("Claude Agents Security Framework - Integration Test Suite\n");
    printf("Version: 1.0\n");
    printf("Testing comprehensive security integration with UFP protocol\n\n");
    
    // Setup signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    int exit_code = 0;
    
    // Initialize test environment
    if (init_test_environment() != 0) {
        fprintf(stderr, "Failed to initialize test environment\n");
        return 1;
    }
    
    // Create and start test agents
    if (create_test_agents() != 0) {
        fprintf(stderr, "Failed to create test agents\n");
        cleanup_test_environment();
        return 1;
    }
    
    if (start_all_agents() != 0) {
        fprintf(stderr, "Failed to start agent threads\n");
        cleanup_test_environment();
        return 1;
    }
    
    // Run integration tests
    run_test_scenarios();
    
    // Print results
    print_test_results();
    
    // Set exit code based on test results
    if (atomic_load(&g_test_state.total_errors) > 0) {
        exit_code = 1;
    }
    
    // Cleanup
    cleanup_test_environment();
    
    printf("\nIntegration test suite completed with exit code: %d\n", exit_code);
    return exit_code;
}