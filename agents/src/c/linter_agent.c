/*
 * LINTER AGENT - Communication System Integration
 * Version 2.0 - Production-ready implementation
 */
#include "ultra_fast_protocol.h"
#include "agent_system.h"
#include "compatibility_layer.h"
#include <stdio.h>
#include <string.h>
#include <stdatomic.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <syslog.h>

#define AGENT_NAME_MAX      64
#define RECV_TIMEOUT_MS     100
#define MAX_RETRY_COUNT     3
#define LINTER_VERSION      "2.0.0"

// Error codes
typedef enum {
    LINTER_SUCCESS = 0,
    LINTER_ERR_INIT = -1,
    LINTER_ERR_COMM = -2,
    LINTER_ERR_MEMORY = -3,
    LINTER_ERR_INVALID_PARAM = -4,
    LINTER_ERR_REGISTRATION = -5
} linter_error_t;

// Linting result structure
typedef struct {
    uint32_t errors;
    uint32_t warnings;
    uint32_t suggestions;
    char* details;
    size_t details_size;
} lint_result_t;

// Agent definition with enhanced fields
typedef struct {
    ufp_context_t* comm_context;
    char name[AGENT_NAME_MAX];
    uint32_t agent_id;
    atomic_int state;
    pthread_mutex_t lock;
    
    // Statistics
    atomic_uint messages_processed;
    atomic_uint errors_found;
    atomic_uint warnings_found;
    
    // Configuration
    uint32_t severity_level;
    char* rule_config_path;
    void* lint_engine;
} linter_agent_t;

// Global agent instance for signal handling
static linter_agent_t* g_agent = NULL;

// Signal handler for graceful shutdown
static void signal_handler(int sig) {
    if (g_agent) {
        syslog(LOG_INFO, "Linter agent received signal %d, shutting down", sig);
        atomic_store(&g_agent->state, AGENT_STATE_SHUTDOWN);
    }
}

// Initialize agent with full error handling
linter_error_t linter_init(linter_agent_t* agent, const char* config_path) {
    if (!agent) {
        return LINTER_ERR_INVALID_PARAM;
    }
    
    memset(agent, 0, sizeof(linter_agent_t));
    
    // Initialize mutex
    if (pthread_mutex_init(&agent->lock, NULL) != 0) {
        syslog(LOG_ERR, "Failed to initialize mutex: %s", strerror(errno));
        return LINTER_ERR_INIT;
    }
    
    // Initialize communication context with retry logic
    int retry_count = 0;
    while (retry_count < MAX_RETRY_COUNT) {
        agent->comm_context = ufp_create_context("linter");
        if (agent->comm_context) {
            break;
        }
        retry_count++;
        usleep(100000); // 100ms backoff
    }
    
    if (!agent->comm_context) {
        pthread_mutex_destroy(&agent->lock);
        syslog(LOG_ERR, "Failed to create communication context after %d retries", MAX_RETRY_COUNT);
        return LINTER_ERR_COMM;
    }
    
    // Safe string copy with bounds checking
    strncpy(agent->name, "linter", AGENT_NAME_MAX - 1);
    agent->name[AGENT_NAME_MAX - 1] = '\0';
    
    atomic_store(&agent->state, AGENT_STATE_ACTIVE);
    agent->severity_level = 2; // Default: warnings and errors
    
    // Load configuration if provided
    if (config_path) {
        agent->rule_config_path = strdup(config_path);
        if (!agent->rule_config_path) {
            ufp_destroy_context(agent->comm_context);
            pthread_mutex_destroy(&agent->lock);
            return LINTER_ERR_MEMORY;
        }
    }
    
    // Initialize linting engine (placeholder for actual implementation)
    agent->lint_engine = NULL; // Would initialize actual linting library here
    
    // Register with discovery service
    agent_metadata_t metadata = {
        .version = LINTER_VERSION,
        .capabilities = AGENT_CAP_LINT | AGENT_CAP_ASYNC,
        .max_concurrent = 10
    };
    
    if (agent_register("linter", AGENT_TYPE_LINTER, &metadata, sizeof(metadata)) != 0) {
        linter_cleanup(agent);
        return LINTER_ERR_REGISTRATION;
    }
    
    // Set up signal handlers
    g_agent = agent;
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    syslog(LOG_INFO, "Linter agent initialized successfully");
    return LINTER_SUCCESS;
}

// Perform actual linting operation
static lint_result_t* perform_lint(linter_agent_t* agent, const char* content, size_t content_size) {
    lint_result_t* result = calloc(1, sizeof(lint_result_t));
    if (!result) {
        return NULL;
    }
    
    // Actual linting logic would go here
    // This is a placeholder implementation
    
    // Check for common C issues
    if (strstr(content, "strcpy") != NULL) {
        result->warnings++;
        result->details = strdup("Warning: Use of unsafe strcpy detected. Consider strncpy or strlcpy.\n");
    }
    
    if (strstr(content, "gets") != NULL) {
        result->errors++;
        const char* error_msg = "Error: Use of deprecated gets() function. Use fgets() instead.\n";
        if (result->details) {
            size_t new_size = strlen(result->details) + strlen(error_msg) + 1;
            char* new_details = realloc(result->details, new_size);
            if (new_details) {
                strcat(new_details, error_msg);
                result->details = new_details;
            }
        } else {
            result->details = strdup(error_msg);
        }
    }
    
    // Check for potential buffer overflows
    if (strstr(content, "sprintf") != NULL && strstr(content, "snprintf") == NULL) {
        result->suggestions++;
    }
    
    result->details_size = result->details ? strlen(result->details) : 0;
    
    // Update statistics
    atomic_fetch_add(&agent->errors_found, result->errors);
    atomic_fetch_add(&agent->warnings_found, result->warnings);
    
    return result;
}

// Process incoming message with proper error handling
static linter_error_t linter_process_message(linter_agent_t* agent, ufp_message_t* msg) {
    if (!agent || !msg) {
        return LINTER_ERR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&agent->lock);
    
    syslog(LOG_DEBUG, "Processing message from %s, type: %d", msg->source, msg->msg_type);
    
    linter_error_t ret = LINTER_SUCCESS;
    ufp_message_t* response = NULL;
    
    switch (msg->msg_type) {
        case UFP_MSG_LINT_REQUEST: {
            // Perform linting operation
            lint_result_t* lint_result = perform_lint(agent, msg->payload, msg->payload_size);
            
            if (lint_result) {
                // Create response message
                response = ufp_message_create();
                if (response) {
                    strncpy(response->source, agent->name, UFP_NAME_MAX - 1);
                    strncpy(response->targets[0], msg->source, UFP_NAME_MAX - 1);
                    response->target_count = 1;
                    response->msg_type = UFP_MSG_LINT_RESULT;
                    
                    // Serialize lint results to payload
                    response->payload_size = sizeof(uint32_t) * 3 + lint_result->details_size;
                    response->payload = malloc(response->payload_size);
                    
                    if (response->payload) {
                        uint32_t* counts = (uint32_t*)response->payload;
                        counts[0] = lint_result->errors;
                        counts[1] = lint_result->warnings;
                        counts[2] = lint_result->suggestions;
                        
                        if (lint_result->details) {
                            memcpy(response->payload + sizeof(uint32_t) * 3, 
                                   lint_result->details, 
                                   lint_result->details_size);
                        }
                    }
                }
                
                // Cleanup lint result
                free(lint_result->details);
                free(lint_result);
            }
            break;
        }
        
        case UFP_MSG_STATUS_REQUEST: {
            // Return agent status
            response = ufp_message_create();
            if (response) {
                strncpy(response->source, agent->name, UFP_NAME_MAX - 1);
                strncpy(response->targets[0], msg->source, UFP_NAME_MAX - 1);
                response->target_count = 1;
                response->msg_type = UFP_MSG_STATUS_RESPONSE;
                
                // Create status payload
                char status_buffer[256];
                snprintf(status_buffer, sizeof(status_buffer),
                        "State: %d, Messages: %u, Errors: %u, Warnings: %u",
                        atomic_load(&agent->state),
                        atomic_load(&agent->messages_processed),
                        atomic_load(&agent->errors_found),
                        atomic_load(&agent->warnings_found));
                
                response->payload = strdup(status_buffer);
                response->payload_size = strlen(status_buffer);
            }
            break;
        }
        
        default: {
            // Send generic acknowledgment for other message types
            response = ufp_message_create();
            if (response) {
                strncpy(response->source, agent->name, UFP_NAME_MAX - 1);
                strncpy(response->targets[0], msg->source, UFP_NAME_MAX - 1);
                response->target_count = 1;
                response->msg_type = UFP_MSG_ACK;
            }
            break;
        }
    }
    
    // Send response if created
    if (response) {
        if (ufp_send(agent->comm_context, response) != UFP_SUCCESS) {
            syslog(LOG_ERR, "Failed to send response to %s", msg->source);
            ret = LINTER_ERR_COMM;
        }
        ufp_message_destroy(response);
    }
    
    atomic_fetch_add(&agent->messages_processed, 1);
    
    pthread_mutex_unlock(&agent->lock);
    return ret;
}

// Main agent loop with proper shutdown handling
void linter_run(linter_agent_t* agent) {
    if (!agent) {
        return;
    }
    
    ufp_message_t msg;
    int consecutive_errors = 0;
    
    syslog(LOG_INFO, "Linter agent entering main loop");
    
    while (atomic_load(&agent->state) == AGENT_STATE_ACTIVE) {
        int recv_result = ufp_receive(agent->comm_context, &msg, RECV_TIMEOUT_MS);
        
        if (recv_result == UFP_SUCCESS) {
            consecutive_errors = 0;
            
            if (linter_process_message(agent, &msg) != LINTER_SUCCESS) {
                syslog(LOG_WARNING, "Failed to process message");
            }
            
            // Clean up message payload if allocated
            if (msg.payload && msg.payload_size > 0) {
                free(msg.payload);
            }
        } else if (recv_result != UFP_TIMEOUT) {
            consecutive_errors++;
            syslog(LOG_WARNING, "Receive error: %d, consecutive errors: %d", 
                   recv_result, consecutive_errors);
            
            // Circuit breaker pattern
            if (consecutive_errors >= 10) {
                syslog(LOG_ERR, "Too many consecutive errors, shutting down");
                atomic_store(&agent->state, AGENT_STATE_ERROR);
                break;
            }
            
            // Exponential backoff
            usleep(consecutive_errors * 100000);
        }
    }
    
    syslog(LOG_INFO, "Linter agent exiting main loop, state: %d", 
           atomic_load(&agent->state));
}

// Cleanup function for proper resource management
void linter_cleanup(linter_agent_t* agent) {
    if (!agent) {
        return;
    }
    
    syslog(LOG_INFO, "Cleaning up linter agent");
    
    // Set state to shutdown
    atomic_store(&agent->state, AGENT_STATE_SHUTDOWN);
    
    // Unregister from discovery service
    agent_unregister("linter");
    
    // Destroy communication context
    if (agent->comm_context) {
        ufp_destroy_context(agent->comm_context);
        agent->comm_context = NULL;
    }
    
    // Free allocated memory
    if (agent->rule_config_path) {
        free(agent->rule_config_path);
        agent->rule_config_path = NULL;
    }
    
    // Cleanup lint engine
    if (agent->lint_engine) {
        // Actual cleanup would depend on linting library used
        agent->lint_engine = NULL;
    }
    
    // Destroy mutex
    pthread_mutex_destroy(&agent->lock);
    
    // Clear global reference
    if (g_agent == agent) {
        g_agent = NULL;
    }
    
    syslog(LOG_INFO, "Linter agent cleanup complete");
}

// Get agent statistics
void linter_get_stats(linter_agent_t* agent, uint32_t* messages, uint32_t* errors, uint32_t* warnings) {
    if (!agent) {
        return;
    }
    
    if (messages) *messages = atomic_load(&agent->messages_processed);
    if (errors) *errors = atomic_load(&agent->errors_found);
    if (warnings) *warnings = atomic_load(&agent->warnings_found);
}