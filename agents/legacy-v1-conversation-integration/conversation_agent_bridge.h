/*
 * Conversation-Agent Bridge Header
 * Ultra-High Performance C API for Claude Integration
 */

#ifndef CONVERSATION_AGENT_BRIDGE_H
#define CONVERSATION_AGENT_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// API Version
#define CONVERSATION_BRIDGE_VERSION_MAJOR 1
#define CONVERSATION_BRIDGE_VERSION_MINOR 0
#define CONVERSATION_BRIDGE_VERSION_PATCH 0

// Return codes
#define CONV_BRIDGE_SUCCESS 0
#define CONV_BRIDGE_ERROR -1
#define CONV_BRIDGE_QUEUE_FULL -2
#define CONV_BRIDGE_NOT_FOUND -3
#define CONV_BRIDGE_INVALID_STATE -4

// Conversation states (exported enum)
typedef enum {
    CONV_STATE_ACTIVE = 0,
    CONV_STATE_THINKING = 1,
    CONV_STATE_AGENT_WORKING = 2,
    CONV_STATE_STREAMING = 3,
    CONV_STATE_COMPLETE = 4,
    CONV_STATE_ERROR = 5
} conversation_state_t;

// Performance statistics structure
typedef struct {
    uint64_t total_messages_processed;
    uint64_t total_agent_invocations;
    uint64_t average_response_time_ns;
    uint32_t peak_concurrent_conversations;
    uint32_t active_conversations;
    uint64_t uptime_seconds;
} performance_stats_t;

// Stream chunk structure
typedef struct {
    char* content;
    size_t content_len;
    char* source_type;  // "conversation", "agent", "system"
    char* source_id;
    char* chunk_type;   // "text", "code", "data", "metadata"
    int is_partial;
    uint64_t timestamp_ns;
    void* metadata;     // JSON metadata as string
} stream_chunk_t;

/**
 * Initialize the conversation-agent bridge system
 * Must be called before any other functions
 * 
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int conversation_bridge_init(void);

/**
 * Process a user message through the integrated system
 * 
 * @param conversation_id Unique conversation identifier
 * @param user_id User identifier
 * @param message User message content
 * @param message_len Length of message in bytes
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int process_user_message(const char* conversation_id, 
                        const char* user_id,
                        const char* message, 
                        size_t message_len);

/**
 * Get current conversation state
 * 
 * @param conversation_id Conversation identifier
 * @return conversation_state_t value, or -1 on error
 */
int get_conversation_state(const char* conversation_id);

/**
 * Set conversation integration mode
 * 
 * @param conversation_id Conversation identifier
 * @param mode Integration mode (0=transparent, 1=collaborative, 2=interactive, 3=diagnostic)
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int set_integration_mode(const char* conversation_id, int mode);

/**
 * Get next stream chunk for a conversation
 * Non-blocking call that returns immediately
 * 
 * @param conversation_id Conversation identifier
 * @param chunk Output structure for stream chunk
 * @return CONV_BRIDGE_SUCCESS if chunk available, CONV_BRIDGE_NOT_FOUND if no chunks
 */
int get_stream_chunk(const char* conversation_id, stream_chunk_t* chunk);

/**
 * Free stream chunk resources
 * Must be called after processing each chunk
 * 
 * @param chunk Stream chunk to free
 */
void free_stream_chunk(stream_chunk_t* chunk);

/**
 * Inject agent capability into ongoing conversation
 * 
 * @param conversation_id Conversation identifier
 * @param capability_name Name of capability to inject
 * @param parameters JSON string of parameters
 * @param result_buffer Buffer to store result (JSON)
 * @param buffer_size Size of result buffer
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int inject_agent_capability(const char* conversation_id,
                           const char* capability_name,
                           const char* parameters,
                           char* result_buffer,
                           size_t buffer_size);

/**
 * Update shared context between conversation and agents
 * 
 * @param conversation_id Conversation identifier
 * @param context_updates JSON string of context updates
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int update_shared_context(const char* conversation_id, 
                         const char* context_updates);

/**
 * Get performance statistics
 * 
 * @param stats Output structure for performance statistics
 */
void get_performance_stats(performance_stats_t* stats);

/**
 * Get detailed conversation metrics
 * 
 * @param conversation_id Conversation identifier
 * @param metrics_buffer Buffer to store metrics (JSON)
 * @param buffer_size Size of metrics buffer
 * @return CONV_BRIDGE_SUCCESS on success, error code otherwise
 */
int get_conversation_metrics(const char* conversation_id,
                            char* metrics_buffer,
                            size_t buffer_size);

/**
 * Force cleanup of inactive conversations
 * Useful for memory management in long-running processes
 * 
 * @param max_inactive_seconds Maximum seconds of inactivity before cleanup
 * @return Number of conversations cleaned up
 */
int cleanup_inactive_conversations(int max_inactive_seconds);

/**
 * Enable/disable diagnostic mode for debugging
 * 
 * @param enable 1 to enable, 0 to disable
 * @param log_level Log level (0=error, 1=warn, 2=info, 3=debug, 4=trace)
 * @return CONV_BRIDGE_SUCCESS on success
 */
int set_diagnostic_mode(int enable, int log_level);

/**
 * Get system resource usage
 * 
 * @param cpu_usage_percent Current CPU usage percentage
 * @param memory_usage_mb Current memory usage in MB
 * @param thread_count Active thread count
 * @return CONV_BRIDGE_SUCCESS on success
 */
int get_resource_usage(float* cpu_usage_percent, 
                      uint64_t* memory_usage_mb,
                      uint32_t* thread_count);

/**
 * Shutdown the conversation-agent bridge system
 * Gracefully stops all threads and frees resources
 */
void conversation_bridge_shutdown(void);

// Callback function types for event handling
typedef void (*message_callback_t)(const char* conversation_id, 
                                  const char* message, 
                                  void* user_data);

typedef void (*state_change_callback_t)(const char* conversation_id, 
                                       int old_state, 
                                       int new_state, 
                                       void* user_data);

typedef void (*agent_event_callback_t)(const char* conversation_id,
                                      const char* agent_id,
                                      const char* event_type,
                                      const char* event_data,
                                      void* user_data);

/**
 * Register callbacks for real-time events
 * 
 * @param msg_callback Callback for message events (can be NULL)
 * @param state_callback Callback for state changes (can be NULL)
 * @param agent_callback Callback for agent events (can be NULL)
 * @param user_data User data passed to callbacks
 * @return CONV_BRIDGE_SUCCESS on success
 */
int register_event_callbacks(message_callback_t msg_callback,
                            state_change_callback_t state_callback,
                            agent_event_callback_t agent_callback,
                            void* user_data);

/**
 * Unregister event callbacks
 */
void unregister_event_callbacks(void);

#ifdef __cplusplus
}
#endif

#endif // CONVERSATION_AGENT_BRIDGE_H