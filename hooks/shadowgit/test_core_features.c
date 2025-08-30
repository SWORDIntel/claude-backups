#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <unistd.h>
#include <cpuid.h>

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
    
    // Get CPU info
    unsigned int eax, ebx, ecx, edx;
    char vendor[13] = {0};
    
    // Get vendor
    __cpuid(0, eax, ebx, ecx, edx);
    *((unsigned int *)&vendor[0]) = ebx;
    *((unsigned int *)&vendor[4]) = edx;
    *((unsigned int *)&vendor[8]) = ecx;
    
    // Get base frequency from CPUID
    unsigned int base_freq = 0;
    if (__get_cpuid_max(0x16, NULL) >= 0x16) {
        __cpuid(0x16, eax, ebx, ecx, edx);
        base_freq = eax;
    }
    
    // Check AVX2 support
    __cpuid_count(7, 0, eax, ebx, ecx, edx);
    int has_avx2 = (ebx >> 5) & 1;
    int has_avx512f = (ebx >> 16) & 1;
    
    // Get cache info
    __cpuid(0x4, eax, ebx, ecx, edx);
    int cache_level = (eax >> 5) & 0x7;
    
    printf("CPU%02d: Base=%4dMHz AVX2=%d AVX512F=%d Cache_L=%d", 
           cpu, base_freq, has_avx2, has_avx512f, cache_level);
    
    // Determine core type based on frequency
    if (base_freq >= 1400) {
        printf(" [P-CORE]\n");
    } else if (base_freq >= 900) {
        printf(" [E-CORE]\n");
    } else {
        printf(" [LP-E-CORE]\n");
    }
    
    return 0;
}