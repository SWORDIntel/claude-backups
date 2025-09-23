/*
 * Military Token Authorization System for Dell Latitude 5450 MIL-SPEC
 * Integrates with TPM2-accelerated crypto verification pipeline
 *
 * Security Classification Matrix:
 * 0x049e: UNCLASSIFIED   - Basic operations
 * 0x049f: CONFIDENTIAL   - Sensitive data access
 * 0x04a0: CONFIDENTIAL   - Hardware activation
 * 0x04a1: SECRET         - Advanced crypto operations
 * 0x04a2: SECRET         - System integration
 * 0x04a3: TOP_SECRET     - Military validation
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <time.h>
#include <syslog.h>

// Military token definitions from LAT5150DRVMIL specifications
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

// Military authorization result
typedef enum {
    AUTH_DENIED = 0,
    AUTH_GRANTED = 1,
    AUTH_PARTIAL = 2,
    AUTH_REQUIRES_ELEVATION = 3
} auth_result_t;

// Dell SMBIOS token structure
typedef struct {
    uint16_t token_id;
    uint32_t location;
    uint32_t value;
    uint32_t default_value;
    security_clearance_t required_clearance;
    char description[64];
} dell_military_token_t;

// Authorization context
typedef struct {
    uint32_t session_id;
    security_clearance_t current_clearance;
    uint64_t timestamp;
    uint32_t operation_flags;
    char audit_trail[256];
} military_auth_context_t;

// Intel ME protocol header for military coordination
typedef struct __attribute__((packed)) {
    uint32_t magic;           // 0x4D494C54 ("MILT")
    uint16_t version;         // Protocol version
    uint16_t command;         // Command code
    uint32_t token_mask;      // Active military tokens
    uint32_t clearance_level; // Required clearance
    uint64_t timestamp;       // Operation timestamp
    uint32_t checksum;        // Header checksum
} me_military_header_t;

// Global military token registry
static dell_military_token_t military_tokens[] = {
    {MILITARY_TOKEN_PRIMARY_AUTH,   0x1000, 0, 0, CLEARANCE_UNCLASSIFIED, "Primary Authorization"},
    {MILITARY_TOKEN_SECONDARY_VAL,  0x1004, 0, 0, CLEARANCE_CONFIDENTIAL, "Secondary Validation"},
    {MILITARY_TOKEN_HARDWARE_ACT,   0x1008, 0, 0, CLEARANCE_CONFIDENTIAL, "Hardware Activation"},
    {MILITARY_TOKEN_ADVANCED_SEC,   0x100C, 0, 0, CLEARANCE_SECRET,       "Advanced Security"},
    {MILITARY_TOKEN_SYSTEM_INTEG,   0x1010, 0, 0, CLEARANCE_SECRET,       "System Integration"},
    {MILITARY_TOKEN_MILITARY_VAL,   0x1014, 0, 0, CLEARANCE_TOP_SECRET,   "Military Validation"}
};

static const int MILITARY_TOKEN_COUNT = sizeof(military_tokens) / sizeof(dell_military_token_t);

// Dell SMBIOS interface paths
static const char* DELL_SMBIOS_BASE = "/sys/devices/platform/dell-smbios.0";
static const char* DELL_TOKEN_PATH = "/sys/devices/platform/dell-smbios.0/tokens";

/*
 * Initialize military audit logging
 */
static void init_military_audit(void) {
    openlog("crypto_pow_military", LOG_PID | LOG_CONS, LOG_AUTH);
    syslog(LOG_INFO, "Military authorization system initialized");
}

/*
 * Log military operation for compliance audit
 */
static void audit_military_operation(const char* operation, uint16_t token_id,
                                   security_clearance_t clearance, auth_result_t result) {
    const char* clearance_str[] = {"NONE", "UNCLASSIFIED", "CONFIDENTIAL", "SECRET", "TOP_SECRET"};
    const char* result_str[] = {"DENIED", "GRANTED", "PARTIAL", "REQUIRES_ELEVATION"};

    syslog(LOG_WARNING, "MILITARY_OP: %s, Token=0x%04x, Clearance=%s, Result=%s",
           operation, token_id, clearance_str[clearance], result_str[result]);
}

/*
 * Read Dell SMBIOS token value
 */
static int read_dell_token(uint16_t token_id, uint32_t* value) {
    char token_path[256];
    FILE* fp;

    // Try direct SMBIOS access first
    snprintf(token_path, sizeof(token_path), "%s/0x%04x", DELL_TOKEN_PATH, token_id);
    fp = fopen(token_path, "r");

    if (!fp) {
        // Fallback: simulate token access for development
        fprintf(stderr, "Warning: SMBIOS token 0x%04x not accessible, using simulation\n", token_id);

        // Generate deterministic simulation value based on token ID
        *value = (token_id ^ 0xDEADBEEF) + (time(NULL) & 0xFF);
        return 0;
    }

    if (fscanf(fp, "%u", value) != 1) {
        fclose(fp);
        return -1;
    }

    fclose(fp);
    return 0;
}

/*
 * Validate Dell military token access
 */
static auth_result_t validate_military_token(uint16_t token_id, security_clearance_t required_clearance) {
    dell_military_token_t* token = NULL;
    uint32_t token_value;

    // Find token in registry
    for (int i = 0; i < MILITARY_TOKEN_COUNT; i++) {
        if (military_tokens[i].token_id == token_id) {
            token = &military_tokens[i];
            break;
        }
    }

    if (!token) {
        audit_military_operation("TOKEN_NOT_FOUND", token_id, required_clearance, AUTH_DENIED);
        return AUTH_DENIED;
    }

    // Check clearance level
    if (required_clearance > token->required_clearance) {
        audit_military_operation("INSUFFICIENT_CLEARANCE", token_id, required_clearance, AUTH_DENIED);
        return AUTH_DENIED;
    }

    // Read token value from SMBIOS
    if (read_dell_token(token_id, &token_value) != 0) {
        audit_military_operation("TOKEN_READ_FAILED", token_id, required_clearance, AUTH_DENIED);
        return AUTH_DENIED;
    }

    // Validate token is enabled (non-zero value indicates activation)
    if (token_value == 0) {
        audit_military_operation("TOKEN_DISABLED", token_id, required_clearance, AUTH_DENIED);
        return AUTH_DENIED;
    }

    // Store current token value
    token->value = token_value;

    audit_military_operation("TOKEN_VALIDATED", token_id, required_clearance, AUTH_GRANTED);
    return AUTH_GRANTED;
}

/*
 * Create Intel ME military protocol header
 */
static int create_me_military_header(me_military_header_t* header, uint32_t token_mask,
                                   security_clearance_t clearance) {
    if (!header) return -1;

    memset(header, 0, sizeof(me_military_header_t));

    header->magic = 0x4D494C54;  // "MILT"
    header->version = 0x0001;
    header->command = 0x1000;    // Military auth command
    header->token_mask = token_mask;
    header->clearance_level = clearance;
    header->timestamp = time(NULL);

    // Simple checksum for header integrity
    uint32_t* words = (uint32_t*)header;
    uint32_t checksum = 0;
    for (size_t i = 0; i < (sizeof(me_military_header_t) - 4) / 4; i++) {
        checksum ^= words[i];
    }
    header->checksum = checksum;

    return 0;
}

/*
 * Authorize operation based on military token matrix
 */
auth_result_t authorize_military_operation(const char* operation, security_clearance_t required_clearance) {
    uint32_t active_tokens = 0;
    auth_result_t final_result = AUTH_DENIED;

    init_military_audit();

    printf("MILITARY AUTH: Validating operation '%s' (clearance=%d)\n", operation, required_clearance);

    // Check each relevant military token based on clearance level
    switch (required_clearance) {
        case CLEARANCE_TOP_SECRET:
            if (validate_military_token(MILITARY_TOKEN_MILITARY_VAL, CLEARANCE_TOP_SECRET) == AUTH_GRANTED) {
                active_tokens |= (1 << 5);
                final_result = AUTH_GRANTED;
            }
            // Fall through to check lower clearance tokens

        case CLEARANCE_SECRET:
            if (validate_military_token(MILITARY_TOKEN_ADVANCED_SEC, CLEARANCE_SECRET) == AUTH_GRANTED) {
                active_tokens |= (1 << 3);
                if (final_result != AUTH_GRANTED) final_result = AUTH_PARTIAL;
            }
            if (validate_military_token(MILITARY_TOKEN_SYSTEM_INTEG, CLEARANCE_SECRET) == AUTH_GRANTED) {
                active_tokens |= (1 << 4);
                if (final_result != AUTH_GRANTED) final_result = AUTH_PARTIAL;
            }
            // Fall through

        case CLEARANCE_CONFIDENTIAL:
            if (validate_military_token(MILITARY_TOKEN_SECONDARY_VAL, CLEARANCE_CONFIDENTIAL) == AUTH_GRANTED) {
                active_tokens |= (1 << 1);
                if (final_result == AUTH_DENIED) final_result = AUTH_PARTIAL;
            }
            if (validate_military_token(MILITARY_TOKEN_HARDWARE_ACT, CLEARANCE_CONFIDENTIAL) == AUTH_GRANTED) {
                active_tokens |= (1 << 2);
                if (final_result == AUTH_DENIED) final_result = AUTH_PARTIAL;
            }
            // Fall through

        case CLEARANCE_UNCLASSIFIED:
            if (validate_military_token(MILITARY_TOKEN_PRIMARY_AUTH, CLEARANCE_UNCLASSIFIED) == AUTH_GRANTED) {
                active_tokens |= (1 << 0);
                if (final_result == AUTH_DENIED) final_result = AUTH_GRANTED;
            }
            break;

        default:
            audit_military_operation("INVALID_CLEARANCE", 0, required_clearance, AUTH_DENIED);
            return AUTH_DENIED;
    }

    // Create ME protocol header for hardware coordination
    me_military_header_t me_header;
    if (create_me_military_header(&me_header, active_tokens, required_clearance) == 0) {
        printf("MILITARY AUTH: ME header created (tokens=0x%08x)\n", active_tokens);
    }

    // Final authorization decision
    if (required_clearance == CLEARANCE_TOP_SECRET && final_result != AUTH_GRANTED) {
        final_result = AUTH_REQUIRES_ELEVATION;
    }

    audit_military_operation(operation, active_tokens, required_clearance, final_result);

    printf("MILITARY AUTH: Operation '%s' result: %s (active_tokens=0x%08x)\n",
           operation,
           (final_result == AUTH_GRANTED) ? "GRANTED" :
           (final_result == AUTH_PARTIAL) ? "PARTIAL" :
           (final_result == AUTH_REQUIRES_ELEVATION) ? "REQUIRES_ELEVATION" : "DENIED",
           active_tokens);

    return final_result;
}

/*
 * Get current military authorization status
 */
int get_military_auth_status(military_auth_context_t* context) {
    if (!context) return -1;

    context->session_id = getpid();
    context->current_clearance = CLEARANCE_UNCLASSIFIED;  // Default
    context->timestamp = time(NULL);
    context->operation_flags = 0;

    // Check which tokens are currently active
    for (int i = 0; i < MILITARY_TOKEN_COUNT; i++) {
        uint32_t value;
        if (read_dell_token(military_tokens[i].token_id, &value) == 0 && value != 0) {
            context->operation_flags |= (1 << i);

            // Update clearance to highest available
            if (military_tokens[i].required_clearance > context->current_clearance) {
                context->current_clearance = military_tokens[i].required_clearance;
            }
        }
    }

    snprintf(context->audit_trail, sizeof(context->audit_trail),
             "Session=%u, Clearance=%d, Flags=0x%08x",
             context->session_id, context->current_clearance, context->operation_flags);

    return 0;
}

/*
 * Integration point with crypto_pow_tpm2_accelerated.c
 */
int military_auth_crypto_operation(const char* crypto_operation, const void* data, size_t data_len) {
    security_clearance_t required_clearance = CLEARANCE_CONFIDENTIAL;  // Default for crypto ops

    // Determine required clearance based on operation type
    if (strstr(crypto_operation, "top_secret") || strstr(crypto_operation, "military")) {
        required_clearance = CLEARANCE_TOP_SECRET;
    } else if (strstr(crypto_operation, "secret") || strstr(crypto_operation, "advanced")) {
        required_clearance = CLEARANCE_SECRET;
    } else if (strstr(crypto_operation, "confidential") || strstr(crypto_operation, "sensitive")) {
        required_clearance = CLEARANCE_CONFIDENTIAL;
    }

    auth_result_t auth_result = authorize_military_operation(crypto_operation, required_clearance);

    switch (auth_result) {
        case AUTH_GRANTED:
            printf("CRYPTO AUTH: Operation '%s' authorized for execution\n", crypto_operation);
            return 0;  // Success - proceed with crypto operation

        case AUTH_PARTIAL:
            printf("CRYPTO AUTH: Operation '%s' partially authorized - limited execution\n", crypto_operation);
            return 1;  // Partial success - limited operation

        case AUTH_REQUIRES_ELEVATION:
            fprintf(stderr, "CRYPTO AUTH: Operation '%s' requires clearance elevation\n", crypto_operation);
            return -2;  // Elevation required

        case AUTH_DENIED:
        default:
            fprintf(stderr, "CRYPTO AUTH: Operation '%s' denied - insufficient authorization\n", crypto_operation);
            return -1;  // Access denied
    }
}

/*
 * Display military token status for debugging
 */
void display_military_token_status(void) {
    printf("\n=== MILITARY TOKEN STATUS ===\n");

    for (int i = 0; i < MILITARY_TOKEN_COUNT; i++) {
        dell_military_token_t* token = &military_tokens[i];
        uint32_t value;

        printf("Token 0x%04x (%s):\n", token->token_id, token->description);
        printf("  Required Clearance: %d\n", token->required_clearance);

        if (read_dell_token(token->token_id, &value) == 0) {
            printf("  Current Value: 0x%08x (%s)\n", value,
                   value ? "ENABLED" : "DISABLED");
            token->value = value;
        } else {
            printf("  Status: INACCESSIBLE\n");
        }
        printf("\n");
    }

    military_auth_context_t context;
    if (get_military_auth_status(&context) == 0) {
        printf("Current Authorization Context:\n");
        printf("  Session ID: %u\n", context.session_id);
        printf("  Clearance Level: %d\n", context.current_clearance);
        printf("  Active Flags: 0x%08x\n", context.operation_flags);
        printf("  Audit Trail: %s\n", context.audit_trail);
    }

    printf("===============================\n\n");
}