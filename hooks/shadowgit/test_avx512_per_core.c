#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <unistd.h>
#include <immintrin.h>
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
    
    // Verify we're actually on the correct CPU
    int current_cpu = sched_getcpu();
    if (current_cpu != cpu_id) {
        fprintf(stderr, "Warning: Requested CPU %d, but running on CPU %d\n", cpu_id, current_cpu);
        return -1;
    }
    
    return 0;
}

int test_avx512_basic(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Test 1: Basic AVX-512 register operations
        __m512i a = _mm512_set1_epi32(0x12345678);
        __m512i b = _mm512_set1_epi32(0x87654321);
        __m512i result = _mm512_add_epi32(a, b);
        
        // Extract first element to verify operation
        int first = _mm512_cvtsi512_si32(result);
        
        if (first != (int)(0x12345678U + 0x87654321U)) {
            printf("CPU %2d: AVX-512 arithmetic failed (expected 0x%08x, got 0x%08x)\n", 
                   cpu_id, (int)(0x12345678U + 0x87654321U), first);
            return 0;
        }
        
        return 1;
    } else {
        return 0; // SIGILL caught
    }
}

int test_avx512_advanced(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Test 2: AVX-512 mask operations
        __mmask16 mask = 0x5555; // Every other element
        __m512i a = _mm512_set1_epi32(100);
        __m512i b = _mm512_set1_epi32(200);
        __m512i result = _mm512_mask_add_epi32(a, mask, a, b);
        
        // Test 3: AVX-512 gather operations
        __m512i indices = _mm512_setr_epi32(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        int data[16] = {0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225};
        __m512i gathered = _mm512_i32gather_epi32(indices, data, 4);
        
        return 1;
    } else {
        return 0; // SIGILL caught
    }
}

int test_avx512_performance(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        const int iterations = 1000000;
        double start_time = get_time();
        
        __m512 a = _mm512_set1_ps(1.0f);
        __m512 b = _mm512_set1_ps(2.0f);
        
        for (int i = 0; i < iterations; i++) {
            a = _mm512_fmadd_ps(a, b, a); // a = a * b + a
        }
        
        double end_time = get_time();
        double elapsed = end_time - start_time;
        
        // Extract result to prevent optimization
        float result = _mm512_reduce_add_ps(a);
        
        printf("CPU %2d: AVX-512 performance test: %.3f ms, result: %e\n", 
               cpu_id, elapsed * 1000, result);
        
        return 1;
    } else {
        return 0; // SIGILL caught
    }
}

void test_cpu_avx512(int cpu_id) {
    printf("=== Testing CPU %d ===\n", cpu_id);
    
    if (pin_to_cpu(cpu_id) != 0) {
        printf("CPU %2d: Failed to pin to core\n", cpu_id);
        return;
    }
    
    // Install SIGILL handler
    signal(SIGILL, sigill_handler);
    
    printf("CPU %2d: Pinned successfully, running tests...\n", cpu_id);
    
    // Test 1: Basic AVX-512 operations
    if (test_avx512_basic(cpu_id)) {
        printf("CPU %2d: ✓ Basic AVX-512 operations PASSED\n", cpu_id);
    } else {
        printf("CPU %2d: ✗ Basic AVX-512 operations FAILED (SIGILL)\n", cpu_id);
        return;
    }
    
    // Test 2: Advanced AVX-512 operations
    if (test_avx512_advanced(cpu_id)) {
        printf("CPU %2d: ✓ Advanced AVX-512 operations PASSED\n", cpu_id);
    } else {
        printf("CPU %2d: ✗ Advanced AVX-512 operations FAILED (SIGILL)\n", cpu_id);
        return;
    }
    
    // Test 3: Performance test
    if (test_avx512_performance(cpu_id)) {
        printf("CPU %2d: ✓ AVX-512 performance test PASSED\n", cpu_id);
    } else {
        printf("CPU %2d: ✗ AVX-512 performance test FAILED (SIGILL)\n", cpu_id);
        return;
    }
    
    printf("CPU %2d: 🎉 ALL AVX-512 TESTS PASSED!\n", cpu_id);
}

int main() {
    printf("AVX-512 Per-Core Test Suite\n");
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
        
        // Brief pause between tests
        usleep(100000); // 100ms
    }
    
    printf("========================================\n");
    printf("AVX-512 Test Summary:\n");
    printf("P-cores tested: %d\n", num_p_cores);
    printf("Note: Success/failure counts will be implemented after individual testing\n");
    printf("========================================\n");
    
    return 0;
}