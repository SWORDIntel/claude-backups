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
#include <sys/ucontext.h>

static jmp_buf jump_buffer;
static int test_failed = 0;
static void* fault_address = NULL;
static int fault_code = 0;

void sigill_handler(int sig, siginfo_t *si, void *unused) {
    fault_address = si->si_addr;
    fault_code = si->si_code;
    test_failed = 1;
    longjmp(jump_buffer, 1);
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

void check_cpuid_avx512(int cpu_id) {
    unsigned int eax, ebx, ecx, edx;
    
    // Check CPUID leaf 7, subleaf 0 for AVX-512 features
    asm volatile ("cpuid"
                  : "=a" (eax), "=b" (ebx), "=c" (ecx), "=d" (edx)
                  : "a" (7), "c" (0));
    
    printf("CPU %2d: CPUID(7,0): EBX=0x%08x ECX=0x%08x EDX=0x%08x\n", cpu_id, ebx, ecx, edx);
    
    // Check specific AVX-512 bits
    if (ebx & (1 << 16)) printf("CPU %2d: AVX512F (Foundation) supported\n", cpu_id);
    if (ebx & (1 << 17)) printf("CPU %2d: AVX512DQ supported\n", cpu_id);
    if (ebx & (1 << 21)) printf("CPU %2d: AVX512IFMA supported\n", cpu_id);
    if (ebx & (1 << 26)) printf("CPU %2d: AVX512PF supported\n", cpu_id);
    if (ebx & (1 << 27)) printf("CPU %2d: AVX512ER supported\n", cpu_id);
    if (ebx & (1 << 28)) printf("CPU %2d: AVX512CD supported\n", cpu_id);
    if (ebx & (1 << 30)) printf("CPU %2d: AVX512BW supported\n", cpu_id);
    if (ebx & (1 << 31)) printf("CPU %2d: AVX512VL supported\n", cpu_id);
    
    if (ecx & (1 << 1)) printf("CPU %2d: AVX512VBMI supported\n", cpu_id);
    if (ecx & (1 << 11)) printf("CPU %2d: AVX512VNNI supported\n", cpu_id);
    
    // Check XCR0 to see what's enabled by OS
    unsigned int xcr0_low, xcr0_high;
    asm volatile ("xgetbv" : "=a" (xcr0_low), "=d" (xcr0_high) : "c" (0));
    printf("CPU %2d: XCR0=0x%08x%08x\n", cpu_id, xcr0_high, xcr0_low);
    
    if (xcr0_low & (1 << 7)) printf("CPU %2d: OS supports AVX-512 upper ZMM\n", cpu_id);
    if (xcr0_low & (1 << 6)) printf("CPU %2d: OS supports AVX-512 ZMM_Hi256\n", cpu_id);
    if (xcr0_low & (1 << 5)) printf("CPU %2d: OS supports AVX-512 opmask\n", cpu_id);
}

int test_avx512_simple(int cpu_id) {
    test_failed = 0;
    fault_address = NULL;
    fault_code = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Try the simplest possible AVX-512 instruction
        asm volatile (
            "vpxord %%zmm0, %%zmm0, %%zmm0\n\t"
            :
            :
            : "zmm0"
        );
        
        return 1; // Success
    } else {
        printf("CPU %2d: SIGILL at address %p, code %d\n", cpu_id, fault_address, fault_code);
        return 0; // SIGILL caught
    }
}

int test_ymm_registers(int cpu_id) {
    test_failed = 0;
    
    if (setjmp(jump_buffer) == 0) {
        // Try AVX2 (YMM) instructions first
        asm volatile (
            "vpxor %%ymm0, %%ymm0, %%ymm0\n\t"
            :
            :
            : "ymm0"
        );
        
        return 1; // Success
    } else {
        return 0; // SIGILL caught
    }
}

void test_cpu_comprehensive(int cpu_id) {
    printf("=== Comprehensive Test CPU %d ===\n", cpu_id);
    
    if (pin_to_cpu(cpu_id) != 0) {
        printf("CPU %2d: ✗ Failed to pin to core\n", cpu_id);
        return;
    }
    
    printf("CPU %2d: ✓ Pinned successfully (running on CPU %d)\n", cpu_id, sched_getcpu());
    
    // Check CPUID information
    check_cpuid_avx512(cpu_id);
    
    // Test AVX2 first
    printf("CPU %2d: Testing AVX2 (YMM) registers...", cpu_id);
    fflush(stdout);
    if (test_ymm_registers(cpu_id)) {
        printf(" ✓ PASSED\n");
    } else {
        printf(" ✗ FAILED (SIGILL) - Basic AVX2 not working\n");
        return;
    }
    
    // Test AVX-512
    printf("CPU %2d: Testing AVX-512 (ZMM) registers...", cpu_id);
    fflush(stdout);
    if (test_avx512_simple(cpu_id)) {
        printf(" ✓ PASSED - AVX-512 IS WORKING!\n");
    } else {
        printf(" ✗ FAILED (SIGILL) - AVX-512 blocked\n");
    }
}

int main() {
    // Install enhanced SIGILL handler
    struct sigaction sa;
    sa.sa_sigaction = sigill_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGILL, &sa, NULL);
    
    printf("AVX-512 Detailed Analysis Test\n");
    printf("Microcode version 0x1c - Comprehensive testing\n");
    printf("========================================\n\n");
    
    // Test just first few P-cores for detailed analysis
    int p_cores[] = {0, 1, 2, 8}; // Mix of different physical cores
    int num_cores = sizeof(p_cores) / sizeof(p_cores[0]);
    
    for (int i = 0; i < num_cores; i++) {
        test_cpu_comprehensive(p_cores[i]);
        printf("\n");
        usleep(100000); // 100ms pause
    }
    
    printf("========================================\n");
    printf("Analysis complete. Key findings:\n");
    printf("1. Microcode 0x1c should restore AVX-512 on P-cores\n");
    printf("2. Check CPUID output for feature availability\n");
    printf("3. Check XCR0 for OS support\n");
    printf("4. SIGILL indicates hardware or OS blocking\n");
    printf("========================================\n");
    
    return 0;
}