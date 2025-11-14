/*
 * Shadowgit Diff Engine with Multi-Level Fallback
 * ================================================
 * Team Delta - High-performance file diffing with graceful degradation
 *
 * This file provides hardware-accelerated diff implementation with
 * automatic CPU capability detection and fallback support:
 *
 * Acceleration Modes (auto-selected based on CPU capabilities):
 * 1. AVX-512: 512-bit SIMD - 1.86B lines/sec (Meteor Lake P-cores)
 * 2. AVX2:    256-bit SIMD - 930M lines/sec (widely available)
 * 3. SSE4.2:  128-bit SIMD - 400M lines/sec (legacy CPUs)
 * 4. Scalar:  No SIMD      - 50M lines/sec (guaranteed available)
 *
 * The engine automatically detects CPU capabilities at runtime and
 * selects the best available acceleration mode. If AVX-512 is present
 * but disabled by microcode, it gracefully falls back to AVX2.
 */

#ifndef SHADOWGIT_AVX2_DIFF_H
#define SHADOWGIT_AVX2_DIFF_H

#include <stdint.h>
#include <stdbool.h>
#include "cpu_feature_detection.h"

// Conditional SIMD headers (compile-time safety)
#if defined(__SSE4_2__)
#include <nmmintrin.h>
#endif

#if defined(__AVX2__)
#include <immintrin.h>
#endif

#if defined(__AVX512F__)
#include <immintrin.h>
#endif

// Performance constants
#define BUFFER_SIZE (1024 * 1024) // 1MB buffer for file I/O
#define VECTOR_SIZE 32            // 256-bit AVX2 vectors (32 bytes)
#define UNROLL_FACTOR 8           // Loop unrolling factor for main processing loop

// Result structure for diff operations
typedef struct {
    uint64_t total_lines_old;
    uint64_t total_lines_new;
    uint64_t modified_lines;
    uint64_t processing_time_ns;
    uint64_t bytes_read;
    const char* error_message;
} diff_result_t;

// Main context for diff engine (renamed for clarity)
typedef struct {
    char* file_buffer1;
    char* file_buffer2;
    uint64_t timestamp_start;
    uint64_t timestamp_end;
    acceleration_mode_t accel_mode;  // Active acceleration mode
    bool force_mode;                  // If true, don't auto-select mode
} avx2_context_t;  // Keep name for API compatibility

// Public API functions
#ifdef __cplusplus
extern "C" {
#endif

/*
 * @brief Creates and initializes a new AVX2 diff context.
 * @return A pointer to the new context, or NULL on failure.
 */
avx2_context_t* create_avx2_context(void);

/*
 * @brief Destroys and cleans up an AVX2 diff context.
 * @param ctx The context to destroy.
 */
void destroy_avx2_context(avx2_context_t* ctx);

/*
 * @brief Performs a high-performance diff between two files with auto-acceleration.
 *        Automatically selects best available SIMD mode (AVX-512, AVX2, SSE4.2, or scalar).
 * @param file1_path Path to the first file.
 * @param file2_path Path to the second file.
 * @param result Pointer to a diff_result_t struct to store the results.
 * @return 0 on success, -1 on error.
 */
int shadowgit_avx2_diff(const char* file1_path, const char* file2_path, diff_result_t* result);

/*
 * @brief Performs diff with explicit acceleration mode selection.
 * @param file1_path Path to the first file.
 * @param file2_path Path to the second file.
 * @param result Pointer to a diff_result_t struct to store the results.
 * @param mode Explicit acceleration mode (or use get_best_acceleration_mode() for auto).
 * @return 0 on success, -1 on error.
 */
int shadowgit_diff_with_mode(const char* file1_path, const char* file2_path, diff_result_t* result, acceleration_mode_t mode);

/*
 * @brief Gets the current timestamp in nanoseconds for performance measurement.
 * @return The current timestamp.
 */
uint64_t get_timestamp_ns(void);

#ifdef __cplusplus
}
#endif

#endif // SHADOWGIT_AVX2_DIFF_H