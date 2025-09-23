#define _GNU_SOURCE
#define OPENSSL_SUPPRESS_DEPRECATED

#include "crypto_pow_architecture.h"
#include <stdio.h>

int main() {
    printf("Testing basic system initialization...\n");

    verification_system_t system;
    pow_status_t status = verification_system_init(&system, "test.log");

    if (status == POW_STATUS_SUCCESS) {
        printf("✓ System initialized successfully\n");
        verification_system_cleanup(&system);
        printf("✓ System cleaned up successfully\n");
        return 0;
    } else {
        printf("✗ System initialization failed: %s\n", pow_status_to_string(status));
        return 1;
    }
}