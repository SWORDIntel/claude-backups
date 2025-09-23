#define _GNU_SOURCE
#define OPENSSL_SUPPRESS_DEPRECATED

#include "crypto_pow_architecture.h"
#include <stdio.h>

int main() {
    printf("Testing memory manager only...\n");

    secure_memory_manager_t memory_mgr;
    pow_status_t status = secure_memory_init(&memory_mgr);

    if (status == POW_STATUS_SUCCESS) {
        printf("✓ Memory manager initialized\n");
        secure_memory_cleanup(&memory_mgr);
        printf("✓ Memory manager cleaned up\n");
        return 0;
    } else {
        printf("✗ Memory manager failed\n");
        return 1;
    }
}