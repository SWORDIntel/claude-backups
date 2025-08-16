/*
 * ULTRA FAST PROTOCOL HEADER
 * 
 * High-performance inter-agent communication protocol optimized for
 * Intel Meteor Lake architecture with hardware acceleration support
 * 
 * Author: Agent Communication System
 * Version: 1.0 Production
 */

#ifndef ULTRA_FAST_PROTOCOL_H
#define ULTRA_FAST_PROTOCOL_H

#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>

// Protocol constants
#define PROTOCOL_MAGIC 0x41474E54  // "AGNT"
#define PROTOCOL_VERSION 1
#define MAX_PAYLOAD_SIZE 65536
#define MAX_TARGETS 16
#define MAX_PREDICTION_PATH 4

// Message types
typedef enum {
    MSG_TYPE_PING = 1,
    MSG_TYPE_PONG = 2,
    MSG_TYPE_REQUEST = 3,
    MSG_TYPE_RESPONSE = 4,
    MSG_TYPE_NOTIFICATION = 5,
    MSG_TYPE_BROADCAST = 6,
    MSG_TYPE_COORDINATION = 7,
    MSG_TYPE_EMERGENCY = 8,
    MSG_TYPE_HEARTBEAT = 9,
    MSG_TYPE_SHUTDOWN = 10
} message_type_t;

// Message flags
#define MSG_FLAG_COMPRESSED     0x01
#define MSG_FLAG_ENCRYPTED      0x02
#define MSG_FLAG_PRIORITY_HIGH  0x04
#define MSG_FLAG_REQUIRES_ACK   0x08
#define MSG_FLAG_STREAMING      0x10
#define MSG_FLAG_MULTICAST      0x20
#define MSG_FLAG_AI_ENHANCED    0x40
#define MSG_FLAG_GPU_ACCELERATED 0x80

// Message header is defined in compatibility_layer.h

// Agent capability descriptor
typedef struct {
    uint32_t agent_id;
    uint32_t agent_type;
    char name[64];
    char capabilities[256];
    uint32_t load_factor;
    bool available;
    uint64_t last_seen_ns;
} agent_capability_desc_t;

// Communication endpoint
typedef struct {
    char host[64];
    uint16_t port;
    uint32_t protocol_flags;
    float latency_ms;
    uint32_t bandwidth_mbps;
} communication_endpoint_t;

// Function declarations for protocol operations
static inline void init_message_header(enhanced_msg_header_t* header, 
                                      uint32_t msg_type, 
                                      uint32_t source_agent,
                                      uint32_t target_agent) {
    header->magic = PROTOCOL_MAGIC;
    header->msg_type = msg_type;
    header->source_agent = source_agent;
    header->target_agents[0] = target_agent;
    header->target_count = 1;
    header->timestamp = 0; // Will be set by sender
    header->sequence = 0;  // Will be set by sender
    header->payload_len = 0;
    header->flags = 0;
    header->priority = 3; // Normal priority
    header->crc32 = 0;
    header->ai_confidence = 1.0f;
    header->anomaly_score = 0.0f;
    header->gpu_batch_id = 0;
}

// CRC32 calculation (simple implementation)
static inline uint32_t calculate_crc32(const void* data, size_t len) {
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
static inline bool validate_message_header(const enhanced_msg_header_t* header) {
    return (header->magic == PROTOCOL_MAGIC &&
            header->target_count > 0 &&
            header->target_count <= MAX_TARGETS &&
            header->payload_len <= MAX_PAYLOAD_SIZE);
}

#endif // ULTRA_FAST_PROTOCOL_H