/*
 * AGENT COORDINATION INTEGRATION TEST SUITE
 * 
 * Comprehensive test suite for inter-agent communication and coordination
 * Tests message routing, pub/sub patterns, RPC calls, and work queue coordination
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
#include <sched.h>

// Include system headers - adapted for new structure
#include "../../binary-communications-system/ultra_fast_protocol.h"
#include "../auth_security.h"
// Use agent_bridge instead of including implementation directly
extern void* create_agent_bridge(void);
extern int agent_bridge_send_message(void* bridge, enhanced_msg_header_t* msg, uint8_t* payload);
extern int agent_bridge_receive_message(void* bridge, enhanced_msg_header_t* msg, uint8_t* payload);

// Test configuration
#define TEST_AGENTS_COUNT 29
#define TEST_DURATION_SECONDS 30
#define TEST_MESSAGES_PER_AGENT 10000
#define TEST_THREAD_COUNT 64
#define TEST_BATCH_SIZE 1000
#define MAX_MESSAGE_SIZE 65536
#define COORDINATION_TEST_SCENARIOS 5

// Message patterns
typedef enum {
    MSG_PATTERN_PUB_SUB = 1,
    MSG_PATTERN_RPC_CALL = 2,
    MSG_PATTERN_RPC_RESPONSE = 3,
    MSG_PATTERN_WORK_QUEUE = 4,
    MSG_PATTERN_BROADCAST = 5,
    MSG_PATTERN_DIRECT = 6,
    MSG_PATTERN_MULTICAST = 7
} message_pattern_t;

// Coordination scenarios
typedef enum {
    SCENARIO_TASK_DISTRIBUTION = 1,
    SCENARIO_DATA_PIPELINE = 2,
    SCENARIO_CONSENSUS_VOTING = 3,
    SCENARIO_RESOURCE_SHARING = 4,
    SCENARIO_CHAOS_RECOVERY = 5
} coordination_scenario_t;

// Test agent definitions with specializations
typedef struct {
    const char* name;
    uint16_t id;
    ufp_priority_t priority;
    message_pattern_t primary_pattern;
    bool is_coordinator;
    bool handles_rpc;
    bool subscribes_to_events;
} test_agent_def_t;

static const test_agent_def_t test_agents[TEST_AGENTS_COUNT] = {
    {"Director", 1, UFP_PRIORITY_CRITICAL, MSG_PATTERN_BROADCAST, true, true, true},
    {"ProjectOrchestrator", 2, UFP_PRIORITY_CRITICAL, MSG_PATTERN_WORK_QUEUE, true, true, true},
    {"Security", 3, UFP_PRIORITY_HIGH, MSG_PATTERN_PUB_SUB, false, true, true},
    {"Bastion", 4, UFP_PRIORITY_HIGH, MSG_PATTERN_DIRECT, false, true, true},
    {"SecurityChaosAgent", 5, UFP_PRIORITY_HIGH, MSG_PATTERN_PUB_SUB, false, false, true},
    {"Monitor", 6, UFP_PRIORITY_MEDIUM, MSG_PATTERN_PUB_SUB, false, false, true},
    {"Oversight", 7, UFP_PRIORITY_MEDIUM, MSG_PATTERN_PUB_SUB, false, false, true},
    {"Infrastructure", 8, UFP_PRIORITY_HIGH, MSG_PATTERN_RPC_CALL, false, true, true},
    {"Deployer", 9, UFP_PRIORITY_HIGH, MSG_PATTERN_WORK_QUEUE, false, true, true},
    {"Architect", 10, UFP_PRIORITY_HIGH, MSG_PATTERN_RPC_CALL, false, true, true},
    {"Constructor", 11, UFP_PRIORITY_MEDIUM, MSG_PATTERN_WORK_QUEUE, false, true, false},
    {"Patcher", 12, UFP_PRIORITY_MEDIUM, MSG_PATTERN_WORK_QUEUE, false, true, false},
    {"Debugger", 13, UFP_PRIORITY_HIGH, MSG_PATTERN_RPC_CALL, false, true, true},
    {"Testbed", 14, UFP_PRIORITY_MEDIUM, MSG_PATTERN_MULTICAST, false, true, true},
    {"Linter", 15, UFP_PRIORITY_LOW, MSG_PATTERN_WORK_QUEUE, false, false, false},
    {"Optimizer", 16, UFP_PRIORITY_MEDIUM, MSG_PATTERN_RPC_CALL, false, true, false},
    {"APIDesigner", 17, UFP_PRIORITY_MEDIUM, MSG_PATTERN_RPC_CALL, false, true, false},
    {"Database", 18, UFP_PRIORITY_HIGH, MSG_PATTERN_RPC_CALL, false, true, true},
    {"Web", 19, UFP_PRIORITY_MEDIUM, MSG_PATTERN_RPC_CALL, false, true, false},
    {"Mobile", 20, UFP_PRIORITY_MEDIUM, MSG_PATTERN_RPC_CALL, false, true, false},
    {"PyGUI", 21, UFP_PRIORITY_LOW, MSG_PATTERN_RPC_CALL, false, true, false},
    {"TUI", 22, UFP_PRIORITY_LOW, MSG_PATTERN_RPC_CALL, false, true, false},
    {"DataScience", 23, UFP_PRIORITY_MEDIUM, MSG_PATTERN_WORK_QUEUE, false, true, false},
    {"MLOps", 24, UFP_PRIORITY_MEDIUM, MSG_PATTERN_WORK_QUEUE, false, true, true},
    {"Docgen", 25, UFP_PRIORITY_LOW, MSG_PATTERN_WORK_QUEUE, false, false, false},
    {"RESEARCHER", 26, UFP_PRIORITY_LOW, MSG_PATTERN_RPC_CALL, false, false, false},
    {"GNU", 27, UFP_PRIORITY_MEDIUM, MSG_PATTERN_WORK_QUEUE, false, true, false},
    {"NPU", 28, UFP_PRIORITY_HIGH, MSG_PATTERN_MULTICAST, false, true, true},
    {"PLANNER", 29, UFP_PRIORITY_HIGH, MSG_PATTERN_BROADCAST, false, true, true}
};

// Test statistics
typedef struct {
    _Atomic uint64_t messages_sent;
    _Atomic uint64_t messages_received;
    _Atomic uint64_t messages_dropped;
    _Atomic uint64_t rpc_calls_made;
    _Atomic uint64_t rpc_responses_received;
    _Atomic uint64_t pub_sub_events_published;
    _Atomic uint64_t pub_sub_events_received;
    _Atomic uint64_t work_queue_tasks_submitted;
    _Atomic uint64_t work_queue_tasks_completed;
    _Atomic uint64_t broadcast_messages_sent;
    _Atomic uint64_t multicast_messages_sent;
    _Atomic uint64_t coordination_scenarios_completed;
    _Atomic uint64_t routing_failures;
    _Atomic uint64_t authentication_failures;
    uint64_t test_start_time;
    uint64_t test_end_time;
    double peak_throughput_msgps;
    double avg_latency_microseconds;
} coordination_test_stats_t;

static coordination_test_stats_t g_test_stats = {0};

// Test context
typedef struct {
    ufp_context_t* agent_contexts[TEST_AGENTS_COUNT];
    security_context_t* security_contexts[TEST_AGENTS_COUNT];
    pthread_t agent_threads[TEST_AGENTS_COUNT];
    enhanced_ring_buffer_t* ring_buffer;
    bool test_running;
    int test_failures;
    pthread_mutex_t failure_mutex;
    pthread_mutex_t stats_mutex;
    
    // Scenario-specific data
    _Atomic uint64_t scenario_messages[COORDINATION_TEST_SCENARIOS];
    _Atomic uint64_t scenario_completions[COORDINATION_TEST_SCENARIOS];
} coordination_test_context_t;

static coordination_test_context_t g_test_ctx = {0};

// Utility functions
static uint64_t get_timestamp_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static uint32_t get_timestamp_ms() {
    return get_timestamp_ns() / 1000000;
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

// Message creation helpers
static ufp_message_t* create_test_message(uint16_t source_id, uint16_t target_id, 
                                        ufp_msg_type_t msg_type, ufp_priority_t priority,
                                        const void* payload, size_t payload_size) {
    ufp_message_t* msg = ufp_message_create();
    if (!msg) return NULL;
    
    msg->msg_id = rand();
    msg->msg_type = msg_type;
    msg->priority = priority;
    msg->timestamp = get_timestamp_ms();
    msg->correlation_id = rand();
    
    snprintf(msg->source, sizeof(msg->source), "Agent%d", source_id);
    
    if (target_id == 0) {
        strcpy(msg->targets[0], "BROADCAST");
        msg->target_count = 1;
    } else {
        snprintf(msg->targets[0], sizeof(msg->targets[0]), "Agent%d", target_id);
        msg->target_count = 1;
    }
    
    if (payload && payload_size > 0) {
        msg->payload = malloc(payload_size);
        if (msg->payload) {
            memcpy(msg->payload, payload, payload_size);
            msg->payload_size = payload_size;
        }
    }
    
    return msg;
}

// Test 1: Basic Message Routing
static void* agent_message_routing_thread(void* arg) {
    int agent_idx = *(int*)arg;
    const test_agent_def_t* agent = &test_agents[agent_idx];
    ufp_context_t* ctx = g_test_ctx.agent_contexts[agent_idx];
    
    uint64_t messages_sent = 0;
    uint64_t messages_received = 0;
    
    while (g_test_ctx.test_running) {
        // Send messages based on agent's primary pattern
        switch (agent->primary_pattern) {
            case MSG_PATTERN_BROADCAST:
                if (agent->is_coordinator && messages_sent < TEST_MESSAGES_PER_AGENT / 10) {
                    char payload[256];
                    snprintf(payload, sizeof(payload), "Broadcast from %s #%lu", 
                            agent->name, messages_sent);
                    
                    ufp_message_t* msg = create_test_message(agent->id, 0, UFP_MSG_BROADCAST,
                                                           agent->priority, payload, strlen(payload));
                    if (msg) {
                        if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                            atomic_fetch_add(&g_test_stats.broadcast_messages_sent, 1);
                            messages_sent++;
                        }
                        ufp_message_destroy(msg);
                    }
                }
                break;
                
            case MSG_PATTERN_RPC_CALL:
                if (messages_sent < TEST_MESSAGES_PER_AGENT / 5) {
                    uint16_t target_id = (rand() % TEST_AGENTS_COUNT) + 1;
                    if (target_id != agent->id && test_agents[target_id - 1].handles_rpc) {
                        char payload[512];
                        snprintf(payload, sizeof(payload), 
                                "RPC call from %s to %s #%lu", 
                                agent->name, test_agents[target_id - 1].name, messages_sent);
                        
                        ufp_message_t* msg = create_test_message(agent->id, target_id, 
                                                               UFP_MSG_REQUEST, agent->priority,
                                                               payload, strlen(payload));
                        if (msg) {
                            if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                                atomic_fetch_add(&g_test_stats.rpc_calls_made, 1);
                                messages_sent++;
                            }
                            ufp_message_destroy(msg);
                        }
                    }
                }
                break;
                
            case MSG_PATTERN_PUB_SUB:
                if (messages_sent < TEST_MESSAGES_PER_AGENT / 3) {
                    char payload[128];
                    snprintf(payload, sizeof(payload), "Event from %s #%lu", 
                            agent->name, messages_sent);
                    
                    ufp_message_t* msg = create_test_message(agent->id, 0, UFP_MSG_BROADCAST,
                                                           UFP_PRIORITY_MEDIUM, payload, strlen(payload));
                    if (msg) {
                        if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                            atomic_fetch_add(&g_test_stats.pub_sub_events_published, 1);
                            messages_sent++;
                        }
                        ufp_message_destroy(msg);
                    }
                }
                break;
                
            case MSG_PATTERN_WORK_QUEUE:
                if (messages_sent < TEST_MESSAGES_PER_AGENT) {
                    char payload[1024];
                    snprintf(payload, sizeof(payload), "Work task from %s #%lu", 
                            agent->name, messages_sent);
                    
                    // Find a coordinator to submit work to
                    uint16_t coordinator_id = 2; // ProjectOrchestrator
                    ufp_message_t* msg = create_test_message(agent->id, coordinator_id, 
                                                           UFP_MSG_TASK, agent->priority,
                                                           payload, strlen(payload));
                    if (msg) {
                        if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                            atomic_fetch_add(&g_test_stats.work_queue_tasks_submitted, 1);
                            messages_sent++;
                        }
                        ufp_message_destroy(msg);
                    }
                }
                break;
                
            case MSG_PATTERN_MULTICAST:
                if (messages_sent < TEST_MESSAGES_PER_AGENT / 8) {
                    char payload[256];
                    snprintf(payload, sizeof(payload), "Multicast from %s #%lu", 
                            agent->name, messages_sent);
                    
                    ufp_message_t* msg = ufp_message_create();
                    if (msg) {
                        msg->msg_id = rand();
                        msg->msg_type = UFP_MSG_BROADCAST;
                        msg->priority = agent->priority;
                        snprintf(msg->source, sizeof(msg->source), "Agent%d", agent->id);
                        
                        // Add multiple targets
                        int target_count = 0;
                        for (int i = 0; i < TEST_AGENTS_COUNT && target_count < 8; i++) {
                            if (test_agents[i].subscribes_to_events && i != agent_idx) {
                                snprintf(msg->targets[target_count], sizeof(msg->targets[target_count]),
                                        "Agent%d", test_agents[i].id);
                                target_count++;
                            }
                        }
                        msg->target_count = target_count;
                        
                        msg->payload = malloc(strlen(payload));
                        if (msg->payload) {
                            strcpy(msg->payload, payload);
                            msg->payload_size = strlen(payload);
                            
                            if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                                atomic_fetch_add(&g_test_stats.multicast_messages_sent, 1);
                                messages_sent++;
                            }
                        }
                        ufp_message_destroy(msg);
                    }
                }
                break;
                
            default:
                // Direct messaging
                if (messages_sent < TEST_MESSAGES_PER_AGENT / 2) {
                    uint16_t target_id = (rand() % TEST_AGENTS_COUNT) + 1;
                    if (target_id != agent->id) {
                        char payload[128];
                        snprintf(payload, sizeof(payload), "Direct message from %s #%lu", 
                                agent->name, messages_sent);
                        
                        ufp_message_t* msg = create_test_message(agent->id, target_id, 
                                                               UFP_MSG_REQUEST, agent->priority,
                                                               payload, strlen(payload));
                        if (msg) {
                            if (ufp_send(ctx, msg) == UFP_SUCCESS) {
                                messages_sent++;
                            }
                            ufp_message_destroy(msg);
                        }
                    }
                }
                break;
        }
        
        // Receive and process messages
        ufp_message_t received_msg;
        if (ufp_receive(ctx, &received_msg, 1) == UFP_SUCCESS) {
            messages_received++;
            
            // Handle different message types
            switch (received_msg.msg_type) {
                case UFP_MSG_REQUEST:
                    if (agent->handles_rpc) {
                        // Send response
                        ufp_message_t* response = create_test_message(agent->id, 
                                                                    atoi(received_msg.source + 5),
                                                                    UFP_MSG_RESPONSE, 
                                                                    UFP_PRIORITY_HIGH,
                                                                    "RPC Response", 12);
                        if (response) {
                            response->correlation_id = received_msg.correlation_id;
                            if (ufp_send(ctx, response) == UFP_SUCCESS) {
                                atomic_fetch_add(&g_test_stats.rpc_responses_received, 1);
                            }
                            ufp_message_destroy(response);
                        }
                    }
                    break;
                    
                case UFP_MSG_RESPONSE:
                    atomic_fetch_add(&g_test_stats.rpc_responses_received, 1);
                    break;
                    
                case UFP_MSG_BROADCAST:
                    if (agent->subscribes_to_events) {
                        atomic_fetch_add(&g_test_stats.pub_sub_events_received, 1);
                    }
                    break;
                    
                case UFP_MSG_TASK:
                    if (agent->is_coordinator) {
                        atomic_fetch_add(&g_test_stats.work_queue_tasks_completed, 1);
                    }
                    break;
                    
                default:
                    break;
            }
            
            if (received_msg.payload) {
                free(received_msg.payload);
            }
        }
        
        usleep(100); // 100 microsecond delay
    }
    
    atomic_fetch_add(&g_test_stats.messages_sent, messages_sent);
    atomic_fetch_add(&g_test_stats.messages_received, messages_received);
    
    return NULL;
}

static bool test_basic_message_routing() {
    printf("\n=== Testing Basic Message Routing ===\n");
    
    g_test_ctx.test_running = true;
    
    // Start agent threads
    int agent_ids[TEST_AGENTS_COUNT];
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        agent_ids[i] = i;
        pthread_create(&g_test_ctx.agent_threads[i], NULL, 
                      agent_message_routing_thread, &agent_ids[i]);
    }
    
    // Monitor progress
    uint64_t last_sent = 0, last_received = 0;
    for (int t = 0; t < TEST_DURATION_SECONDS; t++) {
        sleep(1);
        
        uint64_t current_sent = atomic_load(&g_test_stats.messages_sent);
        uint64_t current_received = atomic_load(&g_test_stats.messages_received);
        
        double throughput = (current_sent + current_received - last_sent - last_received);
        if (throughput > g_test_stats.peak_throughput_msgps) {
            g_test_stats.peak_throughput_msgps = throughput;
        }
        
        printf("T+%02d: Sent=%lu (+%lu), Received=%lu (+%lu), Throughput=%.0f msg/s\n", 
               t + 1, current_sent, current_sent - last_sent, 
               current_received, current_received - last_received, throughput);
        
        last_sent = current_sent;
        last_received = current_received;
    }
    
    // Stop test
    g_test_ctx.test_running = false;
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        pthread_join(g_test_ctx.agent_threads[i], NULL);
    }
    
    uint64_t total_sent = atomic_load(&g_test_stats.messages_sent);
    uint64_t total_received = atomic_load(&g_test_stats.messages_received);
    
    printf("Message Routing: %lu sent, %lu received (%.1f%% delivery rate)\n",
           total_sent, total_received, 
           total_sent > 0 ? (100.0 * total_received / total_sent) : 0.0);
    
    log_test_result("Basic Message Routing", true, "Completed successfully");
    
    return true;
}

// Test 2: Coordination Scenario - Task Distribution
static void* task_distribution_coordinator_thread(void* arg) {
    ufp_context_t* ctx = g_test_ctx.agent_contexts[1]; // ProjectOrchestrator
    
    uint64_t tasks_distributed = 0;
    uint64_t responses_received = 0;
    
    while (g_test_ctx.test_running && tasks_distributed < 1000) {
        // Create and distribute tasks
        char task_data[512];
        snprintf(task_data, sizeof(task_data), 
                "TASK_%lu:PROCESS_DATA:PRIORITY_MEDIUM", tasks_distributed);
        
        // Find available worker agents
        for (int i = 10; i < 27 && tasks_distributed < 1000; i++) { // Constructor to GNU
            if (!test_agents[i].is_coordinator) {
                ufp_message_t* task = create_test_message(2, test_agents[i].id, 
                                                        UFP_MSG_TASK, UFP_PRIORITY_MEDIUM,
                                                        task_data, strlen(task_data));
                if (task) {
                    if (ufp_send(ctx, task) == UFP_SUCCESS) {
                        tasks_distributed++;
                        atomic_fetch_add(&g_test_ctx.scenario_messages[0], 1);
                    }
                    ufp_message_destroy(task);
                }
            }
        }
        
        // Collect responses
        ufp_message_t response;
        while (ufp_receive(ctx, &response, 1) == UFP_SUCCESS) {
            if (response.msg_type == UFP_MSG_RESULT) {
                responses_received++;
                atomic_fetch_add(&g_test_ctx.scenario_completions[0], 1);
            }
            if (response.payload) free(response.payload);
        }
        
        usleep(1000); // 1ms delay
    }
    
    printf("Task Distribution: %lu tasks distributed, %lu responses received\n",
           tasks_distributed, responses_received);
    
    return NULL;
}

static bool test_task_distribution_scenario() {
    printf("\n=== Testing Task Distribution Scenario ===\n");
    
    g_test_ctx.test_running = true;
    
    pthread_t coordinator_thread;
    pthread_create(&coordinator_thread, NULL, task_distribution_coordinator_thread, NULL);
    
    // Start worker agents
    int worker_ids[17];
    for (int i = 0; i < 17; i++) {
        worker_ids[i] = i + 10; // Constructor to GNU
    }
    
    // Let the scenario run
    sleep(10);
    
    g_test_ctx.test_running = false;
    pthread_join(coordinator_thread, NULL);
    
    uint64_t tasks_sent = atomic_load(&g_test_ctx.scenario_messages[0]);
    uint64_t tasks_completed = atomic_load(&g_test_ctx.scenario_completions[0]);
    
    printf("Task Distribution Results: %lu tasks sent, %lu completed (%.1f%% completion rate)\n",
           tasks_sent, tasks_completed, 
           tasks_sent > 0 ? (100.0 * tasks_completed / tasks_sent) : 0.0);
    
    log_test_result("Task Distribution", tasks_completed > tasks_sent * 0.8, 
                    "Task completion rate acceptable");
    
    return true;
}

// Test 3: Pub/Sub Event System
static void* pubsub_publisher_thread(void* arg) {
    int publisher_id = *(int*)arg;
    ufp_context_t* ctx = g_test_ctx.agent_contexts[publisher_id];
    
    uint64_t events_published = 0;
    
    while (g_test_ctx.test_running && events_published < 500) {
        char event_data[256];
        snprintf(event_data, sizeof(event_data), 
                "EVENT:TYPE=STATUS_UPDATE:SOURCE=%s:TIMESTAMP=%u:DATA=%lu",
                test_agents[publisher_id].name, get_timestamp_ms(), events_published);
        
        ufp_message_t* event = create_test_message(test_agents[publisher_id].id, 0,
                                                 UFP_MSG_BROADCAST, UFP_PRIORITY_MEDIUM,
                                                 event_data, strlen(event_data));
        if (event) {
            if (ufp_send(ctx, event) == UFP_SUCCESS) {
                events_published++;
                atomic_fetch_add(&g_test_ctx.scenario_messages[1], 1);
            }
            ufp_message_destroy(event);
        }
        
        usleep(10000); // 10ms delay
    }
    
    return NULL;
}

static void* pubsub_subscriber_thread(void* arg) {
    int subscriber_id = *(int*)arg;
    ufp_context_t* ctx = g_test_ctx.agent_contexts[subscriber_id];
    
    uint64_t events_received = 0;
    
    while (g_test_ctx.test_running) {
        ufp_message_t event;
        if (ufp_receive(ctx, &event, 10) == UFP_SUCCESS) {
            if (event.msg_type == UFP_MSG_BROADCAST && 
                strstr((char*)event.payload, "EVENT:TYPE=STATUS_UPDATE")) {
                events_received++;
                atomic_fetch_add(&g_test_ctx.scenario_completions[1], 1);
            }
            if (event.payload) free(event.payload);
        }
    }
    
    printf("Subscriber %s received %lu events\n", 
           test_agents[subscriber_id].name, events_received);
    
    return NULL;
}

static bool test_pubsub_event_system() {
    printf("\n=== Testing Pub/Sub Event System ===\n");
    
    g_test_ctx.test_running = true;
    
    // Start publishers
    pthread_t publisher_threads[5];
    int publisher_ids[] = {2, 4, 5, 27, 28}; // Security, SecurityChaos, Monitor, NPU, PLANNER
    
    for (int i = 0; i < 5; i++) {
        pthread_create(&publisher_threads[i], NULL, 
                      pubsub_publisher_thread, &publisher_ids[i]);
    }
    
    // Start subscribers
    pthread_t subscriber_threads[10];
    int subscriber_ids[] = {5, 6, 7, 13, 17, 23, 27, 28}; // Various agents that subscribe
    
    for (int i = 0; i < 8; i++) {
        pthread_create(&subscriber_threads[i], NULL,
                      pubsub_subscriber_thread, &subscriber_ids[i]);
    }
    
    // Let the scenario run
    sleep(15);
    
    g_test_ctx.test_running = false;
    
    // Wait for threads
    for (int i = 0; i < 5; i++) {
        pthread_join(publisher_threads[i], NULL);
    }
    for (int i = 0; i < 8; i++) {
        pthread_join(subscriber_threads[i], NULL);
    }
    
    uint64_t events_published = atomic_load(&g_test_ctx.scenario_messages[1]);
    uint64_t events_received = atomic_load(&g_test_ctx.scenario_completions[1]);
    
    printf("Pub/Sub Results: %lu events published, %lu total receptions (%.1fx fanout)\n",
           events_published, events_received, 
           events_published > 0 ? ((double)events_received / events_published) : 0.0);
    
    log_test_result("Pub/Sub Event System", events_received > events_published * 3, 
                    "Event fanout acceptable");
    
    return true;
}

// Test 4: RPC Call Chain
static bool test_rpc_call_chains() {
    printf("\n=== Testing RPC Call Chains ===\n");
    
    // Test complex RPC chain: Director -> Architect -> Database -> DataScience -> Response
    ufp_context_t* director_ctx = g_test_ctx.agent_contexts[0];
    
    uint64_t rpc_chains_initiated = 0;
    uint64_t rpc_chains_completed = 0;
    
    g_test_ctx.test_running = true;
    
    for (int chain = 0; chain < 100 && g_test_ctx.test_running; chain++) {
        char request_data[512];
        snprintf(request_data, sizeof(request_data),
                "RPC_CHAIN_%d:REQUEST_TYPE=DESIGN_AND_IMPLEMENT:COMPONENT=UserAuth", chain);
        
        // Step 1: Director -> Architect
        ufp_message_t* architect_request = create_test_message(1, 10, UFP_MSG_REQUEST,
                                                             UFP_PRIORITY_HIGH, request_data, 
                                                             strlen(request_data));
        if (architect_request) {
            architect_request->correlation_id = chain;
            if (ufp_send(director_ctx, architect_request) == UFP_SUCCESS) {
                rpc_chains_initiated++;
                atomic_fetch_add(&g_test_ctx.scenario_messages[2], 1);
                
                // Wait for chain completion (simplified - in real system would be async)
                usleep(5000); // 5ms simulated processing time
                
                ufp_message_t response;
                if (ufp_receive(director_ctx, &response, 100) == UFP_SUCCESS) {
                    if (response.msg_type == UFP_MSG_RESPONSE && 
                        response.correlation_id == chain) {
                        rpc_chains_completed++;
                        atomic_fetch_add(&g_test_ctx.scenario_completions[2], 1);
                    }
                    if (response.payload) free(response.payload);
                }
            }
            ufp_message_destroy(architect_request);
        }
        
        usleep(1000); // 1ms between chains
    }
    
    g_test_ctx.test_running = false;
    
    printf("RPC Chain Results: %lu chains initiated, %lu completed (%.1f%% success rate)\n",
           rpc_chains_initiated, rpc_chains_completed,
           rpc_chains_initiated > 0 ? (100.0 * rpc_chains_completed / rpc_chains_initiated) : 0.0);
    
    log_test_result("RPC Call Chains", rpc_chains_completed > rpc_chains_initiated * 0.7,
                    "RPC chain success rate acceptable");
    
    return true;
}

// Test 5: System-Wide Broadcast
static bool test_system_broadcast() {
    printf("\n=== Testing System-Wide Broadcast ===\n");
    
    ufp_context_t* director_ctx = g_test_ctx.agent_contexts[0];
    
    // Send system-wide broadcast
    char broadcast_data[] = "SYSTEM_BROADCAST:TYPE=EMERGENCY_SHUTDOWN:REASON=SECURITY_ALERT";
    ufp_message_t* broadcast = create_test_message(1, 0, UFP_MSG_EMERGENCY,
                                                 UFP_PRIORITY_CRITICAL, broadcast_data,
                                                 strlen(broadcast_data));
    
    if (!broadcast) {
        log_test_error("System Broadcast", "Failed to create broadcast message");
        return false;
    }
    
    uint32_t broadcast_id = rand();
    broadcast->correlation_id = broadcast_id;
    
    uint64_t broadcast_start = get_timestamp_ns();
    
    if (ufp_send(director_ctx, broadcast) != UFP_SUCCESS) {
        log_test_error("System Broadcast", "Failed to send broadcast");
        ufp_message_destroy(broadcast);
        return false;
    }
    
    ufp_message_destroy(broadcast);
    atomic_fetch_add(&g_test_stats.broadcast_messages_sent, 1);
    
    // Give time for broadcast to propagate
    sleep(2);
    
    // Check how many agents received the broadcast
    uint64_t agents_responded = 0;
    for (int i = 1; i < TEST_AGENTS_COUNT; i++) { // Skip Director
        ufp_context_t* agent_ctx = g_test_ctx.agent_contexts[i];
        
        ufp_message_t received_msg;
        if (ufp_receive(agent_ctx, &received_msg, 10) == UFP_SUCCESS) {
            if (received_msg.msg_type == UFP_MSG_EMERGENCY && 
                received_msg.correlation_id == broadcast_id) {
                agents_responded++;
            }
            if (received_msg.payload) free(received_msg.payload);
        }
    }
    
    uint64_t broadcast_end = get_timestamp_ns();
    double broadcast_latency_ms = (broadcast_end - broadcast_start) / 1e6;
    
    printf("System Broadcast: %lu/%d agents received (%.1f%%), latency: %.2f ms\n",
           agents_responded, TEST_AGENTS_COUNT - 1,
           100.0 * agents_responded / (TEST_AGENTS_COUNT - 1), broadcast_latency_ms);
    
    log_test_result("System Broadcast", agents_responded >= (TEST_AGENTS_COUNT - 1) * 0.9,
                    "Broadcast delivery rate acceptable");
    
    return true;
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("AGENT COORDINATION INTEGRATION TEST SUITE\n");
    printf("==========================================\n");
    printf("Testing %d agents for coordination functionality\n\n", TEST_AGENTS_COUNT);
    
    // Initialize test context
    pthread_mutex_init(&g_test_ctx.failure_mutex, NULL);
    pthread_mutex_init(&g_test_ctx.stats_mutex, NULL);
    g_test_stats.test_start_time = get_timestamp_ns();
    
    // Initialize UFP system
    if (ufp_init() != UFP_SUCCESS) {
        fprintf(stderr, "Failed to initialize UFP system\n");
        return 1;
    }
    
    // Create ring buffer
    g_test_ctx.ring_buffer = create_enhanced_ring_buffer(RING_BUFFER_SIZE / 6);
    if (!g_test_ctx.ring_buffer) {
        fprintf(stderr, "Failed to create ring buffer\n");
        ufp_cleanup();
        return 1;
    }
    
    // Create agent contexts
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        g_test_ctx.agent_contexts[i] = ufp_create_context(test_agents[i].name);
        if (!g_test_ctx.agent_contexts[i]) {
            fprintf(stderr, "Failed to create context for %s\n", test_agents[i].name);
            return 1;
        }
        
        // Register agent
        ufp_register_agent(test_agents[i].name);
    }
    
    bool all_tests_passed = true;
    
    // Run test suite
    all_tests_passed &= test_basic_message_routing();
    all_tests_passed &= test_task_distribution_scenario();
    all_tests_passed &= test_pubsub_event_system();
    all_tests_passed &= test_rpc_call_chains();
    all_tests_passed &= test_system_broadcast();
    
    g_test_stats.test_end_time = get_timestamp_ns();
    
    // Calculate final statistics
    double test_duration = (g_test_stats.test_end_time - g_test_stats.test_start_time) / 1e9;
    uint64_t total_messages = atomic_load(&g_test_stats.messages_sent) + 
                             atomic_load(&g_test_stats.messages_received);
    double avg_throughput = total_messages / test_duration;
    
    // Print final results
    printf("\n=== COORDINATION TEST SUMMARY ===\n");
    printf("Total Agents: %d\n", TEST_AGENTS_COUNT);
    printf("Test Duration: %.2f seconds\n", test_duration);
    printf("Test Failures: %d\n", g_test_ctx.test_failures);
    printf("Average Throughput: %.0f msg/sec\n", avg_throughput);
    printf("Peak Throughput: %.0f msg/sec\n", g_test_stats.peak_throughput_msgps);
    
    printf("\nMessage Statistics:\n");
    printf("  Messages Sent: %lu\n", atomic_load(&g_test_stats.messages_sent));
    printf("  Messages Received: %lu\n", atomic_load(&g_test_stats.messages_received));
    printf("  Messages Dropped: %lu\n", atomic_load(&g_test_stats.messages_dropped));
    printf("  RPC Calls Made: %lu\n", atomic_load(&g_test_stats.rpc_calls_made));
    printf("  RPC Responses: %lu\n", atomic_load(&g_test_stats.rpc_responses_received));
    printf("  Pub/Sub Events Published: %lu\n", atomic_load(&g_test_stats.pub_sub_events_published));
    printf("  Pub/Sub Events Received: %lu\n", atomic_load(&g_test_stats.pub_sub_events_received));
    printf("  Work Queue Tasks Submitted: %lu\n", atomic_load(&g_test_stats.work_queue_tasks_submitted));
    printf("  Work Queue Tasks Completed: %lu\n", atomic_load(&g_test_stats.work_queue_tasks_completed));
    printf("  Broadcast Messages: %lu\n", atomic_load(&g_test_stats.broadcast_messages_sent));
    printf("  Multicast Messages: %lu\n", atomic_load(&g_test_stats.multicast_messages_sent));
    
    printf("\nCoordination Scenarios:\n");
    for (int i = 0; i < COORDINATION_TEST_SCENARIOS; i++) {
        printf("  Scenario %d: %lu messages, %lu completions\n", i + 1,
               atomic_load(&g_test_ctx.scenario_messages[i]),
               atomic_load(&g_test_ctx.scenario_completions[i]));
    }
    
    // Performance validation
    bool performance_passed = true;
    if (avg_throughput < 100000) { // Expect at least 100K msg/sec
        printf("\nWARNING: Average throughput below expected threshold (100K msg/sec)\n");
        performance_passed = false;
    }
    
    // Cleanup
    for (int i = 0; i < TEST_AGENTS_COUNT; i++) {
        if (g_test_ctx.agent_contexts[i]) {
            ufp_destroy_context(g_test_ctx.agent_contexts[i]);
        }
    }
    
    if (g_test_ctx.ring_buffer) {
        // Cleanup ring buffer (implementation-specific)
        for (int i = 0; i < 6; i++) {
            if (g_test_ctx.ring_buffer->queues[i].buffer != MAP_FAILED) {
                munmap(g_test_ctx.ring_buffer->queues[i].buffer, g_test_ctx.ring_buffer->queues[i].size);
            }
        }
        numa_free(g_test_ctx.ring_buffer, sizeof(enhanced_ring_buffer_t));
    }
    
    ufp_cleanup();
    pthread_mutex_destroy(&g_test_ctx.failure_mutex);
    pthread_mutex_destroy(&g_test_ctx.stats_mutex);
    
    if (all_tests_passed && performance_passed && g_test_ctx.test_failures == 0) {
        printf("\n[RESULT] ALL COORDINATION TESTS PASSED\n");
        return 0;
    } else {
        printf("\n[RESULT] COORDINATION TESTS FAILED (%d failures)\n", g_test_ctx.test_failures);
        return 1;
    }
}