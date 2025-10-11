/*
 * Shadowgit AVX2 Diff Engine
 * ===========================
 * Team Delta - High-performance file diffing with AVX2
 *
 * This file is part of the Shadowgit integration project.
 * It provides a hardware-accelerated diff implementation
 * using AVX2 intrinsics for modern x86-64 CPUs.
 *
 * Target: 930 million lines/sec on Intel Meteor Lake
 */

#ifndef SHADOWGIT_AVX2_DIFF_H
#define SHADOWGIT_AVX2_DIFF_H

#include <stdint.h>
#include <immintrin.h>

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

// Main context for AVX2 diff engine
typedef struct {
    char* file_buffer1;
    char* file_buffer2;
    uint64_t timestamp_start;
    uint64_t timestamp_end;
} avx2_context_t;

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
 * @brief Performs a high-performance diff between two files using AVX2.
 * @param file1_path Path to the first file.
 * @param file2_path Path to the second file.
 * @param result Pointer to a diff_result_t struct to store the results.
 * @return 0 on success, -1 on error.
 */
int shadowgit_avx2_diff(const char* file1_path, const char* file2_path, diff_result_t* result);

/*
 * @brief Gets the current timestamp in nanoseconds for performance measurement.
 * @return The current timestamp.
 */
uint64_t get_timestamp_ns(void);

#ifdef __cplusplus
}
#endif

#endif // SHADOWGIT_AVX2_DIFF_H