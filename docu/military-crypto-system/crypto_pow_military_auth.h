/*
 * Military Token Authorization System Header
 * Dell Latitude 5450 MIL-SPEC Integration
 */

#ifndef CRYPTO_POW_MILITARY_AUTH_H
#define CRYPTO_POW_MILITARY_AUTH_H

#include <stdint.h>
#include <stddef.h>

// Military token IDs from LAT5150DRVMIL specifications
#define MILITARY_TOKEN_PRIMARY_AUTH    0x049e  // UNCLASSIFIED
#define MILITARY_TOKEN_SECONDARY_VAL   0x049f  // CONFIDENTIAL
#define MILITARY_TOKEN_HARDWARE_ACT    0x04a0  // CONFIDENTIAL
#define MILITARY_TOKEN_ADVANCED_SEC    0x04a1  // SECRET
#define MILITARY_TOKEN_SYSTEM_INTEG    0x04a2  // SECRET
#define MILITARY_TOKEN_MILITARY_VAL    0x04a3  // TOP_SECRET

// Security clearance levels
typedef enum {
    CLEARANCE_UNCLASSIFIED = 1,
    CLEARANCE_CONFIDENTIAL = 2,
    CLEARANCE_SECRET = 3,
    CLEARANCE_TOP_SECRET = 4
} security_clearance_t;

// Authorization results
typedef enum {
    AUTH_DENIED = 0,
    AUTH_GRANTED = 1,
    AUTH_PARTIAL = 2,
    AUTH_REQUIRES_ELEVATION = 3
} auth_result_t;

// Authorization context structure
typedef struct {
    uint32_t session_id;
    security_clearance_t current_clearance;
    uint64_t timestamp;
    uint32_t operation_flags;
    char audit_trail[256];
} military_auth_context_t;

// Function prototypes
auth_result_t authorize_military_operation(const char* operation, security_clearance_t required_clearance);
int get_military_auth_status(military_auth_context_t* context);
int military_auth_crypto_operation(const char* crypto_operation, const void* data, size_t data_len);
void display_military_token_status(void);

#endif // CRYPTO_POW_MILITARY_AUTH_H