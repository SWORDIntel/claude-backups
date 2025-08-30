#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <unistd.h>
#include <signal.h>
#include <setjmp.h>

static jmp_buf jbuf;

void sigill_handler(int sig) {
    longjmp(jbuf, 1);
}

int test_avx512() {
    // Simple AVX-512 instruction test
    asm volatile(
        "vpxord %%zmm0, %%zmm0, %%zmm0\n"
        ::: "zmm0"
    );
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <cpu_number>\n", argv[0]);
        return 1;
    }
    
    int cpu = atoi(argv[1]);
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu, &cpuset);
    
    if (sched_setaffinity(0, sizeof(cpuset), &cpuset) != 0) {
        printf("CPU%d: Failed to set affinity\n", cpu);
        return 1;
    }
    
    signal(SIGILL, sigill_handler);
    
    if (setjmp(jbuf) == 0) {
        test_avx512();
        printf("CPU%d: AVX-512 SUPPORTED (P-core)\n", cpu);
        return 0;
    } else {
        printf("CPU%d: No AVX-512 (E-core)\n", cpu);
        return 1;
    }
}