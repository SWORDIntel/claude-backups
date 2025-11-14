/*
 * CPU Feature Detection and Fallback System - Implementation
 * ===========================================================
 * Provides runtime CPU capability detection with graceful fallback
 *
 * This implementation uses CPUID on x86-64 and provides safe
 * fallback to scalar operations if SIMD instructions are unavailable.
 */

#include "cpu_feature_detection.h"
#include <stdio.h>
#include <string.h>
#include <cpuid.h>
#include <signal.h>
#include <setjmp.h>

// Global CPU capabilities (initialized once)
static cpu_capabilities_t g_cpu_caps = {0};
static bool g_caps_initialized = false;

// For AVX-512 runtime testing
static sigjmp_buf avx512_test_jmpbuf;
static volatile bool avx512_test_caught_signal = false;

/**
 * Signal handler for AVX-512 capability testing
 * Catches SIGILL if AVX-512 instruction fails
 */
static void avx512_sigill_handler(int sig) {
    (void)sig;
    avx512_test_caught_signal = true;
    siglongjmp(avx512_test_jmpbuf, 1);
}

/**
 * Execute CPUID instruction safely
 */
static inline void cpuid(uint32_t leaf, uint32_t subleaf, uint32_t* eax, uint32_t* ebx, uint32_t* ecx, uint32_t* edx) {
    __cpuid_count(leaf, subleaf, *eax, *ebx, *ecx, *edx);
}

/**
 * Detect CPU vendor string
 */
static void detect_vendor(cpu_capabilities_t* caps) {
    uint32_t eax, ebx, ecx, edx;
    cpuid(0, 0, &eax, &ebx, &ecx, &edx);

    memcpy(caps->vendor, &ebx, 4);
    memcpy(caps->vendor + 4, &edx, 4);
    memcpy(caps->vendor + 8, &ecx, 4);
    caps->vendor[12] = '\0';
}

/**
 * Detect CPU brand string
 */
static void detect_brand(cpu_capabilities_t* caps) {
    uint32_t brand[12];

    for (int i = 0; i < 3; i++) {
        cpuid(0x80000002 + i, 0, &brand[i*4], &brand[i*4+1], &brand[i*4+2], &brand[i*4+3]);
    }

    memcpy(caps->brand, brand, 48);
    caps->brand[48] = '\0';
}

/**
 * Detect CPU features using CPUID
 */
static void detect_features(cpu_capabilities_t* caps) {
    uint32_t eax, ebx, ecx, edx;

    // Check basic features (leaf 1)
    cpuid(1, 0, &eax, &ebx, &ecx, &edx);

    if (ecx & (1 << 20)) caps->features |= CPU_FEATURE_SSE42;
    if (ecx & (1 << 28)) caps->features |= CPU_FEATURE_AVX;
    if (ecx & (1 << 12)) caps->features |= CPU_FEATURE_FMA;
    if (ecx & (1 << 23)) caps->features |= CPU_FEATURE_POPCNT;

    // Check extended features (leaf 7, subleaf 0)
    cpuid(7, 0, &eax, &ebx, &ecx, &edx);

    if (ebx & (1 << 5))  caps->features |= CPU_FEATURE_AVX2;
    if (ebx & (1 << 8))  caps->features |= CPU_FEATURE_BMI2;
    if (ebx & (1 << 16)) caps->features |= CPU_FEATURE_AVX512F;
    if (ebx & (1 << 30)) caps->features |= CPU_FEATURE_AVX512BW;
    if (ebx & (1 << 31)) caps->features |= CPU_FEATURE_AVX512VL;
}

/**
 * Detect cache sizes
 */
static void detect_cache_sizes(cpu_capabilities_t* caps) {
    uint32_t eax, ebx, ecx, edx;

    // Intel cache descriptors (leaf 4)
    for (int i = 0; i < 10; i++) {
        cpuid(4, i, &eax, &ebx, &ecx, &edx);

        uint32_t cache_type = eax & 0x1F;
        if (cache_type == 0) break; // No more caches

        uint32_t cache_level = (eax >> 5) & 0x7;
        uint32_t ways = ((ebx >> 22) & 0x3FF) + 1;
        uint32_t partitions = ((ebx >> 12) & 0x3FF) + 1;
        uint32_t line_size = (ebx & 0xFFF) + 1;
        uint32_t sets = ecx + 1;

        uint32_t cache_size = ways * partitions * line_size * sets;

        if (cache_level == 1) caps->l1_cache = cache_size;
        else if (cache_level == 2) caps->l2_cache = cache_size;
        else if (cache_level == 3) caps->l3_cache = cache_size;
    }
}

/**
 * Detect core counts
 */
static void detect_core_counts(cpu_capabilities_t* caps) {
    uint32_t eax, ebx, ecx, edx;

    // Logical processors (leaf 1)
    cpuid(1, 0, &eax, &ebx, &ecx, &edx);
    caps->logical_cores = (ebx >> 16) & 0xFF;

    // Physical cores (leaf 4, subleaf 0)
    cpuid(4, 0, &eax, &ebx, &ecx, &edx);
    caps->physical_cores = ((eax >> 26) & 0x3F) + 1;
}

/**
 * Determine best acceleration mode based on detected features
 */
static void determine_best_mode(cpu_capabilities_t* caps) {
    // Check from fastest to slowest
    if ((caps->features & CPU_FEATURE_AVX512F) &&
        (caps->features & CPU_FEATURE_AVX512BW) &&
        is_avx512_usable()) {
        caps->best_mode = ACCEL_MODE_AVX512;
        caps->mode_string = "AVX-512";
    } else if (caps->features & CPU_FEATURE_AVX2) {
        caps->best_mode = ACCEL_MODE_AVX2;
        caps->mode_string = "AVX2";
    } else if (caps->features & CPU_FEATURE_SSE42) {
        caps->best_mode = ACCEL_MODE_SSE42;
        caps->mode_string = "SSE4.2";
    } else {
        caps->best_mode = ACCEL_MODE_SCALAR;
        caps->mode_string = "Scalar (no SIMD)";
    }
}

/**
 * Test if AVX-512 is actually usable (not just present)
 * Some Intel CPUs have AVX-512 disabled by microcode
 */
bool is_avx512_usable(void) {
    // If CPUID doesn't report AVX-512, definitely not usable
    if (!(g_cpu_caps.features & CPU_FEATURE_AVX512F)) {
        return false;
    }

    // Try executing a simple AVX-512 instruction
    struct sigaction old_action, new_action;
    avx512_test_caught_signal = false;

    new_action.sa_handler = avx512_sigill_handler;
    sigemptyset(&new_action.sa_mask);
    new_action.sa_flags = 0;

    sigaction(SIGILL, &new_action, &old_action);

    if (sigsetjmp(avx512_test_jmpbuf, 1) == 0) {
        // Try a simple AVX-512 operation
        __asm__ __volatile__(
            "vpxorq %%zmm0, %%zmm0, %%zmm0\n\t"
            ::: "zmm0"
        );
    }

    sigaction(SIGILL, &old_action, NULL);

    return !avx512_test_caught_signal;
}

/**
 * Main CPU detection function
 */
cpu_capabilities_t detect_cpu_capabilities(void) {
    cpu_capabilities_t caps = {0};

    detect_vendor(&caps);
    detect_brand(&caps);
    detect_features(&caps);
    detect_cache_sizes(&caps);
    detect_core_counts(&caps);
    determine_best_mode(&caps);

    caps.detection_successful = true;

    return caps;
}

/**
 * Check if specific feature is available
 */
bool has_cpu_feature(cpu_feature_flags_t feature) {
    if (!g_caps_initialized) {
        init_cpu_detection();
    }
    return (g_cpu_caps.features & feature) != 0;
}

/**
 * Get best acceleration mode
 */
acceleration_mode_t get_best_acceleration_mode(void) {
    if (!g_caps_initialized) {
        init_cpu_detection();
    }
    return g_cpu_caps.best_mode;
}

/**
 * Get acceleration mode string
 */
const char* get_acceleration_mode_string(acceleration_mode_t mode) {
    switch (mode) {
        case ACCEL_MODE_AVX512: return "AVX-512";
        case ACCEL_MODE_AVX2:   return "AVX2";
        case ACCEL_MODE_SSE42:  return "SSE4.2";
        case ACCEL_MODE_SCALAR: return "Scalar";
        default:                return "Unknown";
    }
}

/**
 * Print detailed CPU information
 */
void print_cpu_info(void) {
    if (!g_caps_initialized) {
        init_cpu_detection();
    }

    const cpu_capabilities_t* caps = &g_cpu_caps;

    printf("=== CPU Information ===\n");
    printf("Vendor:     %s\n", caps->vendor);
    printf("Brand:      %s\n", caps->brand);
    printf("Cores:      %u physical, %u logical\n", caps->physical_cores, caps->logical_cores);
    printf("\nCache Sizes:\n");
    printf("  L1: %u KB\n", caps->l1_cache / 1024);
    printf("  L2: %u KB\n", caps->l2_cache / 1024);
    printf("  L3: %u KB\n", caps->l3_cache / 1024);
    printf("\nFeatures:\n");
    printf("  SSE4.2:    %s\n", (caps->features & CPU_FEATURE_SSE42) ? "Yes" : "No");
    printf("  AVX:       %s\n", (caps->features & CPU_FEATURE_AVX) ? "Yes" : "No");
    printf("  AVX2:      %s\n", (caps->features & CPU_FEATURE_AVX2) ? "Yes" : "No");
    printf("  AVX-512F:  %s\n", (caps->features & CPU_FEATURE_AVX512F) ? "Yes" : "No");
    printf("  AVX-512BW: %s\n", (caps->features & CPU_FEATURE_AVX512BW) ? "Yes" : "No");
    printf("  AVX-512VL: %s\n", (caps->features & CPU_FEATURE_AVX512VL) ? "Yes" : "No");
    printf("  FMA:       %s\n", (caps->features & CPU_FEATURE_FMA) ? "Yes" : "No");
    printf("  POPCNT:    %s\n", (caps->features & CPU_FEATURE_POPCNT) ? "Yes" : "No");
    printf("  BMI2:      %s\n", (caps->features & CPU_FEATURE_BMI2) ? "Yes" : "No");
    printf("\nBest Acceleration Mode: %s\n", caps->mode_string);

    if ((caps->features & CPU_FEATURE_AVX512F) && !is_avx512_usable()) {
        printf("\n⚠️  WARNING: AVX-512 detected but NOT usable (likely disabled by microcode)\n");
        printf("    Using AVX2 fallback instead.\n");
    }
}

/**
 * Initialize CPU detection (call once at startup)
 */
int init_cpu_detection(void) {
    if (g_caps_initialized) {
        return 0; // Already initialized
    }

    g_cpu_caps = detect_cpu_capabilities();
    g_caps_initialized = true;

    return g_cpu_caps.detection_successful ? 0 : -1;
}

/**
 * Get cached CPU capabilities
 */
const cpu_capabilities_t* get_cpu_capabilities(void) {
    if (!g_caps_initialized) {
        init_cpu_detection();
    }
    return &g_cpu_caps;
}
