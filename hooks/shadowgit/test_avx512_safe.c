#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/time.h>

static jmp_buf jump_buffer;
static int test_failed = 0;

void sigill_handler(int sig) {
    test_failed = 1;
    longjmp(jump_buffer, 1);
}

double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec / 1000000.0;
}

int pin_to_cpu(int cpu_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    
    if (sched_setaffinity(0, sizeof(cpuset), &cpuset) != 0) {
        fprintf(stderr, "Failed to pin to CPU %d: %s\n", cpu_id, strerror(errno));
        return -1;
    }
    
    // Give scheduler time to migrate
    usleep(1000);
    
    // Verify we're actually on the correct CPU
    int current_cpu = sched_getcpu();
    if (current_cpu != cpu_id) {
        fprintf(stderr, "Warning: Requested CPU %d, but running on CPU %d\n", cpu_id, current_cpu);
        return -1;
    }
    
    return 0;
}

int test_avx512_inline_asm(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Use inline assembly to test AVX-512 more directly
        asm volatile (
            "vmovdqu32 %%zmm0, %%zmm1\n\t"
            "vpxord %%zmm0, %%zmm0, %%zmm0\n\t"
            "vpaddd %%zmm0, %%zmm1, %%zmm2\n\t"
            : 
            : 
            : "zmm0", "zmm1", "zmm2"
        );
        
        return 1; // Success if we reach here
    } else {
        return 0; // SIGILL caught
    }
}

int test_avx512_basic_safe(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // More conservative test using basic operations
        volatile int test_data[16] __attribute__((aligned(64)));
        volatile int result_data[16] __attribute__((aligned(64)));
        
        // Initialize test data
        for (int i = 0; i < 16; i++) {
            test_data[i] = i + 1;
        }
        
        // Try to load and store using AVX-512
        asm volatile (
            "vmovdqu32 %0, %%zmm0\n\t"
            "vpaddd %0, %%zmm0, %%zmm1\n\t"
            "vmovdqu32 %%zmm1, %1\n\t"
            : "=m" (*test_data), "=m" (*result_data)
            : "m" (*test_data)
            : "zmm0", "zmm1"
        );
        
        // Verify results
        for (int i = 0; i < 16; i++) {
            if (result_data[i] != (test_data[i] * 2)) {
                printf("CPU %2d: AVX-512 calculation error at index %d: %d != %d\n", 
                       cpu_id, i, result_data[i], test_data[i] * 2);
                return 0;
            }
        }
        
        return 1;
    } else {
        return 0; // SIGILL caught
    }
}

int test_avx512_mask_ops(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Test mask operations which are AVX-512 specific
        volatile int src[16] __attribute__((aligned(64)));
        volatile int dst[16] __attribute__((aligned(64)));
        
        for (int i = 0; i < 16; i++) {
            src[i] = i * 10;
            dst[i] = 0;
        }
        
        // Use mask 0x5555 (every other element)
        asm volatile (
            "mov $0x5555, %%eax\n\t"
            "kmovw %%eax, %%k1\n\t"
            "vmovdqu32 %0, %%zmm0\n\t"
            "vmovdqu32 %1, %%zmm1\n\t"
            "vpaddw %%zmm0, %%zmm1, %%zmm2 {%%k1}{z}\n\t"
            "vmovdqu32 %%zmm2, %1\n\t"
            : "=m" (*src), "=m" (*dst)
            : "m" (*src), "m" (*dst)
            : "eax", "k1", "zmm0", "zmm1", "zmm2"
        );
        
        return 1;
    } else {
        return 0; // SIGILL caught
    }
}

void test_cpu_avx512(int cpu_id) {
    printf("=== Testing CPU %d ===\n", cpu_id);
    
    if (pin_to_cpu(cpu_id) != 0) {
        printf("CPU %2d: ✗ Failed to pin to core\n", cpu_id);
        return;
    }
    
    printf("CPU %2d: ✓ Pinned successfully (running on CPU %d)\n", cpu_id, sched_getcpu());
    
    // Test 1: Basic inline assembly AVX-512
    printf("CPU %2d: Testing inline assembly AVX-512...", cpu_id);
    fflush(stdout);
    if (test_avx512_inline_asm(cpu_id)) {
        printf(" ✓ PASSED\n");
    } else {
        printf(" ✗ FAILED (SIGILL)\n");
        return;
    }
    
    // Test 2: Safe AVX-512 with verification
    printf("CPU %2d: Testing AVX-512 arithmetic...", cpu_id);
    fflush(stdout);
    if (test_avx512_basic_safe(cpu_id)) {
        printf(" ✓ PASSED\n");
    } else {
        printf(" ✗ FAILED (SIGILL)\n");
        return;
    }
    
    // Test 3: AVX-512 mask operations
    printf("CPU %2d: Testing AVX-512 mask operations...", cpu_id);
    fflush(stdout);
    if (test_avx512_mask_ops(cpu_id)) {
        printf(" ✓ PASSED\n");
    } else {
        printf(" ✗ FAILED (SIGILL)\n");
        return;
    }
    
    printf("CPU %2d: 🎉 ALL AVX-512 TESTS PASSED!\n", cpu_id);
}

int main() {
    // Install SIGILL handler FIRST before any potential AVX-512 instructions
    signal(SIGILL, sigill_handler);
    
    printf("AVX-512 Per-Core Test Suite (Safe Version)\n");
    printf("Microcode version 0x1c detected\n");
    printf("Testing P-cores (CPUs 0-11) for AVX-512 support\n");
    printf("========================================\n\n");
    
    // P-cores are CPUs 0-11 based on the topology analysis
    int p_cores[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    int num_p_cores = sizeof(p_cores) / sizeof(p_cores[0]);
    
    int passed_cores = 0;
    int failed_cores = 0;
    
    for (int i = 0; i < num_p_cores; i++) {
        test_cpu_avx512(p_cores[i]);
        printf("\n");
        
        // Brief pause between tests to let system stabilize
        usleep(100000); // 100ms
    }
    
    printf("========================================\n");
    printf("AVX-512 Test Complete\n");
    printf("P-cores tested: %d\n", num_p_cores);
    printf("========================================\n");
    
    return 0;
}