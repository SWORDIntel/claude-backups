/*
 * CPU Feature Detection and Fallback System
 * ==========================================
 * Unified CPU capability detection with graceful degradation
 * for AVX-512, AVX2, SSE4.2, and scalar fallbacks
 *
 * Author: Claude Agent Framework v7.0
 * Target: Intel Meteor Lake (Core Ultra 7 165H) and compatible
 */

#ifndef CPU_FEATURE_DETECTION_H
#define CPU_FEATURE_DETECTION_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// CPU feature flags
typedef enum {
    CPU_FEATURE_NONE    = 0,
    CPU_FEATURE_SSE42   = 1 << 0,
    CPU_FEATURE_AVX     = 1 << 1,
    CPU_FEATURE_AVX2    = 1 << 2,
    CPU_FEATURE_AVX512F = 1 << 3,
    CPU_FEATURE_AVX512BW = 1 << 4,
    CPU_FEATURE_AVX512VL = 1 << 5,
    CPU_FEATURE_POPCNT  = 1 << 6,
    CPU_FEATURE_FMA     = 1 << 7,
    CPU_FEATURE_BMI2    = 1 << 8,
} cpu_feature_flags_t;

// Acceleration mode (ordered from fastest to slowest)
typedef enum {
    ACCEL_MODE_AVX512   = 0,  // Fastest: 512-bit SIMD
    ACCEL_MODE_AVX2     = 1,  // Fast: 256-bit SIMD
    ACCEL_MODE_SSE42    = 2,  // Moderate: 128-bit SIMD
    ACCEL_MODE_SCALAR   = 3,  // Slowest: No SIMD (guaranteed available)
} acceleration_mode_t;

// CPU capability structure
typedef struct {
    // Feature flags
    uint32_t features;

    // CPU identification
    char vendor[13];        // "GenuineIntel", "AuthenticAMD", etc.
    char brand[49];         // Full CPU brand string

    // Cache sizes (in bytes)
    uint32_t l1_cache;
    uint32_t l2_cache;
    uint32_t l3_cache;

    // Core counts
    uint32_t physical_cores;
    uint32_t logical_cores;

    // Best acceleration mode available
    acceleration_mode_t best_mode;

    // Human-readable mode string
    const char* mode_string;

    // Detection success flag
    bool detection_successful;
} cpu_capabilities_t;

/**
 * Detect CPU capabilities using CPUID instruction
 * Returns: Populated cpu_capabilities_t structure
 *
 * This function is safe to call on any x86-64 platform.
 * If CPUID fails, it will return scalar mode as fallback.
 */
cpu_capabilities_t detect_cpu_capabilities(void);

/**
 * Check if a specific feature is available
 * Returns: true if feature is supported, false otherwise
 */
bool has_cpu_feature(cpu_feature_flags_t feature);

/**
 * Get the best acceleration mode for current CPU
 * Returns: Best available acceleration mode (guaranteed valid)
 */
acceleration_mode_t get_best_acceleration_mode(void);

/**
 * Get human-readable string for acceleration mode
 * Returns: String like "AVX-512", "AVX2", "SSE4.2", or "Scalar"
 */
const char* get_acceleration_mode_string(acceleration_mode_t mode);

/**
 * Print detailed CPU information to stdout
 * Useful for debugging and system verification
 */
void print_cpu_info(void);

/**
 * Check if AVX-512 is truly usable (some CPUs have it but disabled by microcode)
 * Returns: true if AVX-512 can be safely used, false if it should be avoided
 *
 * Note: Intel disabled AVX-512 on some Alder Lake+ CPUs via microcode updates
 * This function performs a runtime check instead of just checking CPUID
 */
bool is_avx512_usable(void);

/**
 * Initialize global CPU capabilities (call once at program start)
 * Returns: 0 on success, -1 on failure
 */
int init_cpu_detection(void);

/**
 * Get cached CPU capabilities (fast, after init_cpu_detection)
 * Returns: Pointer to global capabilities structure
 */
const cpu_capabilities_t* get_cpu_capabilities(void);

#ifdef __cplusplus
}
#endif

#endif /* CPU_FEATURE_DETECTION_H */
