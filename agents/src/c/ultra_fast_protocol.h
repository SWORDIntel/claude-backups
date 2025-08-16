/*
 * ULTRA FAST PROTOCOL HEADER
 * 
 * High-performance inter-agent communication protocol optimized for
 * Intel Meteor Lake architecture with hardware acceleration support
 * 
 * Author: Agent Communication System v7.0
 * Version: 7.0.0 Production
 */

#ifndef ULTRA_FAST_PROTOCOL_H
#define ULTRA_FAST_PROTOCOL_H

#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// PROTOCOL CONSTANTS
// ============================================================================

#define UFP_PROTOCOL_MAGIC 0x41474E54  // "AGNT"
#define UFP_PROTOCOL_VERSION 0x0700    // v7.0
#define UFP_MAX_PAYLOAD_SIZE 65536
#define UFP_MAX_TARGETS 16
#define UFP_MAX_AGENT_NAME 64
#define UFP_MAX_PREDICTION_PATH 4
#define UFP_CACHE_LINE_SIZE 64

// ============================================================================
// MESSAGE TYPES
// ============================================================================

typedef enum {
    UFP_MSG_PING = 1,
    UFP_MSG_PONG = 2,
    UFP_MSG_REQUEST = 3,
    UFP_MSG_RESPONSE = 4,
    UFP_MSG_NOTIFICATION = 5,
    UFP_MSG_BROADCAST = 6,
    UFP_MSG_COORDINATION = 7,
    UFP_MSG_EMERGENCY = 8,
    UFP_MSG_HEARTBEAT = 9,
    UFP_MSG_SHUTDOWN = 10,
    UFP_MSG_ACK = 11,
    UFP_MSG_NACK = 12,
    UFP_MSG_DATA = 13,
    UFP_MSG_CONTROL = 14,
    UFP_MSG_TASK = 15,
    UFP_MSG_RESULT = 16
} ufp_message_type_t;

// ============================================================================
// MESSAGE FLAGS
// ============================================================================

#define UFP_FLAG_COMPRESSED      0x0001
#define UFP_FLAG_ENCRYPTED       0x0002
#define UFP_FLAG_PRIORITY_HIGH   0x0004
#define UFP_FLAG_REQUIRES_ACK    0x0008
#define UFP_FLAG_STREAMING       0x0010
#define UFP_FLAG_MULTICAST       0x0020
#define UFP_FLAG_AI_ENHANCED     0x0040
#define UFP_FLAG_GPU_ACCELERATED 0x0080
#define UFP_FLAG_P_CORE_ONLY     0x0100
#define UFP_FLAG_E_CORE_ONLY     0x0200
#define UFP_FLAG_AVX512_OPTIMIZED 0x0400
#define UFP_FLAG_THERMAL_THROTTLED 0x0800

// ============================================================================
// AGENT TYPES
// ============================================================================

typedef enum {
    AGENT_TYPE_UNKNOWN = 0,
    AGENT_TYPE_C_INTERNAL,
    AGENT_TYPE_PYTHON_INTERNAL,
    AGENT_TYPE_INFRASTRUCTURE,
    AGENT_TYPE_RESEARCHER,
    AGENT_TYPE_TESTBED,
    AGENT_TYPE_PATCHER,
    AGENT_TYPE_DEPLOYER,
    AGENT_TYPE_DIRECTOR,
    AGENT_TYPE_SECURITY,
    AGENT_TYPE_MONITOR,
    AGENT_TYPE_DATABASE,
    AGENT_TYPE_API_DESIGNER,
    AGENT_TYPE_WEB,
    AGENT_TYPE_ML_OPS,
    AGENT_TYPE_OPTIMIZER,
    AGENT_TYPE_BASTION,
    AGENT_TYPE_NPU,
    AGENT_TYPE_PLANNER,
    AGENT_TYPE_COORDINATOR
} agent_type_t;

// ============================================================================
// AGENT STATES
// ============================================================================

typedef enum {
    AGENT_STATE_INACTIVE = 0,
    AGENT_STATE_INITIALIZING,
    AGENT_STATE_IDLE,
    AGENT_STATE_ACTIVE,
    AGENT_STATE_BUSY,
    AGENT_STATE_ERROR,
    AGENT_STATE_THERMAL_PAUSE,
    AGENT_STATE_SHUTTING_DOWN
} agent_state_t;

// ============================================================================
// MESSAGE STRUCTURES
// ============================================================================

// Enhanced message header with cache line alignment
typedef struct __attribute__((aligned(UFP_CACHE_LINE_SIZE))) {
    // First cache line (64 bytes)
    uint32_t magic;                    // 4 bytes - Protocol magic
    uint16_t version;                  // 2 bytes - Protocol version
    uint16_t flags;                    // 2 bytes - Message flags
    uint32_t msg_type;                 // 4 bytes - Message type
    uint32_t priority;                 // 4 bytes - Priority level (0-7)
    uint64_t timestamp;                // 8 bytes - Nanosecond timestamp
    uint64_t sequence;                 // 8 bytes - Sequence number
    uint32_t source_agent;             // 4 bytes - Source agent ID
    uint32_t target_count;             // 4 bytes - Number of targets
    uint32_t target_agents[4];         // 16 bytes - First 4 targets
    uint32_t payload_len;              // 4 bytes - Payload length
    uint32_t crc32;                    // 4 bytes - CRC32 checksum
    
    // Second cache line (64 bytes) - Extended fields
    uint32_t target_agents_ext[12];    // 48 bytes - Additional targets
    float ai_confidence;               // 4 bytes - AI prediction confidence
    float anomaly_score;               // 4 bytes - Anomaly detection score
    uint32_t gpu_batch_id;             // 4 bytes - GPU batch identifier
    uint32_t reserved;                 // 4 bytes - Reserved for alignment
    
    // Performance metrics
    uint64_t processing_start_ns;      // 8 bytes
    uint64_t processing_end_ns;        // 8 bytes
    uint32_t retry_count;              // 4 bytes
    uint32_t hop_count;                // 4 bytes
    
    // AI Router Extensions (preserving compatibility_layer.h fields)
    uint16_t predicted_path[4];        // 8 bytes - AI routing prediction path
    uint64_t feature_hash;             // 8 bytes - Message feature hash for ML
    uint32_t target_agent;             // 4 bytes - Primary target (compatibility)
    uint32_t correlation_id;           // 4 bytes - Message correlation ID
    uint8_t ttl;                       // 1 byte - Time to live
    uint32_t msg_id;                   // 4 bytes - Unique message identifier
    uint8_t padding_ai[11];            // 11 bytes - Padding for alignment
} enhanced_msg_header_t;

// UFP Message structure
typedef struct {
    char source[UFP_MAX_AGENT_NAME];
    char targets[UFP_MAX_TARGETS][UFP_MAX_AGENT_NAME];
    uint32_t target_count;
    ufp_message_type_t msg_type;
    uint32_t priority;
    uint16_t flags;
    char payload[UFP_MAX_PAYLOAD_SIZE];
    uint32_t payload_size;
} ufp_message_t;

// Agent capability descriptor
typedef struct {
    uint32_t agent_id;
    agent_type_t agent_type;
    char name[UFP_MAX_AGENT_NAME];
    char capabilities[256];
    uint32_t load_factor;
    bool available;
    uint64_t last_seen_ns;
    
    // Hardware capabilities
    bool has_avx512;
    bool has_avx2;
    uint32_t p_cores;
    uint32_t e_cores;
    uint64_t memory_mb;
    
    // Performance metrics
    double avg_response_time_ms;
    double success_rate;
    uint64_t messages_processed;
} agent_capability_desc_t;

// Communication endpoint
typedef struct {
    char host[64];
    uint16_t port;
    uint32_t protocol_flags;
    float latency_ms;
    uint32_t bandwidth_mbps;
    bool is_secure;
    bool is_local;
} communication_endpoint_t;

// ============================================================================
// CONTEXT STRUCTURES
// ============================================================================

// UFP Context for agent communication
typedef struct ufp_context {
    char agent_name[UFP_MAX_AGENT_NAME];
    uint32_t agent_id;
    agent_type_t agent_type;
    
    // Communication channels
    void* ring_buffer_in;
    void* ring_buffer_out;
    
    // Threading
    pthread_t receiver_thread;
    pthread_t sender_thread;
    pthread_mutex_t send_mutex;
    pthread_mutex_t recv_mutex;
    
    // Statistics
    atomic_uint_fast64_t messages_sent;
    atomic_uint_fast64_t messages_received;
    atomic_uint_fast64_t bytes_sent;
    atomic_uint_fast64_t bytes_received;
    
    // Configuration
    bool use_compression;
    bool use_encryption;
    uint32_t max_retries;
    uint32_t timeout_ms;
    
    // State
    atomic_bool running;
    agent_state_t state;
} ufp_context_t;

// ============================================================================
// PROTOCOL OPERATIONS
// ============================================================================

// Context management
ufp_context_t* ufp_create_context(const char* agent_name);
void ufp_destroy_context(ufp_context_t* context);

// Message operations
ufp_message_t* ufp_message_create(void);
void ufp_message_destroy(ufp_message_t* msg);
void ufp_message_clear(ufp_message_t* msg);

// Communication operations
int ufp_send(ufp_context_t* context, ufp_message_t* msg);
int ufp_receive(ufp_context_t* context, ufp_message_t* msg, uint32_t timeout_ms);
int ufp_broadcast(ufp_context_t* context, ufp_message_t* msg);

// Agent discovery and registration
int agent_register(const char* name, agent_type_t type, void* capabilities, size_t cap_size);
int agent_unregister(const char* name);
int agent_discover(agent_capability_desc_t* agents, uint32_t* count);

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Initialize message header
static inline void ufp_init_header(enhanced_msg_header_t* header, 
                                   uint32_t msg_type, 
                                   uint32_t source_agent,
                                   uint32_t target_agent) {
    header->magic = UFP_PROTOCOL_MAGIC;
    header->version = UFP_PROTOCOL_VERSION;
    header->msg_type = msg_type;
    header->source_agent = source_agent;
    header->target_agents[0] = target_agent;
    header->target_count = 1;
    header->timestamp = 0;  // Will be set by sender
    header->sequence = 0;   // Will be set by sender
    header->payload_len = 0;
    header->flags = 0;
    header->priority = 3;   // Normal priority
    header->crc32 = 0;
    header->ai_confidence = 1.0f;
    header->anomaly_score = 0.0f;
    header->gpu_batch_id = 0;
    header->processing_start_ns = 0;
    header->processing_end_ns = 0;
    header->retry_count = 0;
    header->hop_count = 0;
}

// CRC32 calculation
static inline uint32_t ufp_calculate_crc32(const void* data, size_t len) {
    const uint8_t* bytes = (const uint8_t*)data;
    uint32_t crc = 0xFFFFFFFF;
    
    for (size_t i = 0; i < len; i++) {
        crc ^= bytes[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
        }
    }
    
    return ~crc;
}

// Message validation
static inline bool ufp_validate_header(const enhanced_msg_header_t* header) {
    return (header->magic == UFP_PROTOCOL_MAGIC &&
            header->version == UFP_PROTOCOL_VERSION &&
            header->target_count > 0 &&
            header->target_count <= UFP_MAX_TARGETS &&
            header->payload_len <= UFP_MAX_PAYLOAD_SIZE);
}

// Get current timestamp in nanoseconds
static inline uint64_t ufp_get_timestamp_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000UL + (uint64_t)ts.tv_nsec;
}

// Set message timestamp
static inline void ufp_set_timestamp(enhanced_msg_header_t* header) {
    header->timestamp = ufp_get_timestamp_ns();
}

// Calculate message latency
static inline double ufp_calculate_latency_ms(const enhanced_msg_header_t* header) {
    uint64_t now = ufp_get_timestamp_ns();
    return (now - header->timestamp) / 1000000.0;
}

// Priority helpers
static inline bool ufp_is_high_priority(const enhanced_msg_header_t* header) {
    return (header->flags & UFP_FLAG_PRIORITY_HIGH) || (header->priority <= 1);
}

static inline bool ufp_requires_ack(const enhanced_msg_header_t* header) {
    return (header->flags & UFP_FLAG_REQUIRES_ACK);
}

// ============================================================================
// RETURN CODES
// ============================================================================

typedef enum {
    UFP_SUCCESS = 0,
    UFP_ERROR_INVALID_PARAM = -1,
    UFP_ERROR_NO_MEMORY = -2,
    UFP_ERROR_TIMEOUT = -3,
    UFP_ERROR_NOT_FOUND = -4,
    UFP_ERROR_BUSY = -5,
    UFP_ERROR_DISCONNECTED = -6,
    UFP_ERROR_PROTOCOL = -7,
    UFP_ERROR_CRC = -8,
    UFP_ERROR_THERMAL = -9,
    UFP_ERROR_QUEUE_FULL = -10
} ufp_error_t;

// Error string helper
static inline const char* ufp_error_string(int error) {
    switch (error) {
        case UFP_SUCCESS: return "Success";
        case UFP_ERROR_INVALID_PARAM: return "Invalid parameter";
        case UFP_ERROR_NO_MEMORY: return "Out of memory";
        case UFP_ERROR_TIMEOUT: return "Operation timed out";
        case UFP_ERROR_NOT_FOUND: return "Not found";
        case UFP_ERROR_BUSY: return "Resource busy";
        case UFP_ERROR_DISCONNECTED: return "Disconnected";
        case UFP_ERROR_PROTOCOL: return "Protocol error";
        case UFP_ERROR_CRC: return "CRC error";
        case UFP_ERROR_THERMAL: return "Thermal throttling";
        case UFP_ERROR_QUEUE_FULL: return "Queue full";
        default: return "Unknown error";
    }
}

#ifdef __cplusplus
}
#endif

#endif // ULTRA_FAST_PROTOCOL_H