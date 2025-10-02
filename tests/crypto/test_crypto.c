#define _GNU_SOURCE
#define OPENSSL_SUPPRESS_DEPRECATED

#include "crypto_pow_architecture.h"
#include <stdio.h>

int main() {
    printf("Testing crypto context only...\n");

    crypto_context_t crypto_ctx;
    memset(&crypto_ctx, 0, sizeof(crypto_context_t));

    // Just initialize OpenSSL without generating keys
    if (!RAND_poll()) {
        printf("✗ OpenSSL initialization failed\n");
        return 1;
    }

    printf("✓ OpenSSL initialized\n");
    printf("✓ Crypto context test complete\n");
    return 0;
}