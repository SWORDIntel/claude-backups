/*
 * Shadowgit AVX2 Diff Engine - Implementation
 * ===========================================
 * Team Delta - High-performance file diffing with AVX2
 *
 * This implementation uses AVX2 intrinsics to rapidly compare
 * file contents, counting differences and line numbers.
 *
 * Key Optimizations:
 * - Memory-mapped I/O for zero-copy file access.
 * - 256-bit AVX2 vectors for parallel comparison.
 * - Loop unrolling to maximize instruction-level parallelism.
 * - POPCNT instruction for fast counting of differing bits.
 * - Optimized newline counting.
 */

#define _ISOC11_SOURCE
#include "shadowgit_avx2_diff.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <immintrin.h>

// Helper to get timestamp
uint64_t get_timestamp_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000 + (uint64_t)ts.tv_nsec;
}

// Context management
avx2_context_t* create_avx2_context(void) {
    avx2_context_t* ctx = (avx2_context_t*)malloc(sizeof(avx2_context_t));
    if (!ctx) return NULL;

    // Use aligned memory for better performance
    ctx->file_buffer1 = (char*)aligned_alloc(VECTOR_SIZE, BUFFER_SIZE);
    ctx->file_buffer2 = (char*)aligned_alloc(VECTOR_SIZE, BUFFER_SIZE);

    if (!ctx->file_buffer1 || !ctx->file_buffer2) {
        free(ctx->file_buffer1);
        free(ctx->file_buffer2);
        free(ctx);
        return NULL;
    }
    return ctx;
}

void destroy_avx2_context(avx2_context_t* ctx) {
    if (ctx) {
        free(ctx->file_buffer1);
        free(ctx->file_buffer2);
        free(ctx);
    }
}

// Core newline counting function using AVX2
static inline uint64_t count_newlines_avx2(const char* buffer, size_t size) {
    uint64_t count = 0;
    const __m256i newline = _mm256_set1_epi8('\n');
    size_t i = 0;

    for (; i + VECTOR_SIZE <= size; i += VECTOR_SIZE) {
        __m256i chunk = _mm256_loadu_si256((const __m256i*)(buffer + i));
        __m256i result = _mm256_cmpeq_epi8(chunk, newline);
        uint32_t mask = _mm256_movemask_epi8(result);
        count += _mm_popcnt_u32(mask);
    }

    // Handle remaining bytes
    for (; i < size; ++i) {
        if (buffer[i] == '\n') {
            count++;
        }
    }
    return count;
}

// Main diff function
int shadowgit_avx2_diff(const char* file1_path, const char* file2_path, diff_result_t* result) {
    if (!file1_path || !file2_path || !result) {
        if (result) result->error_message = "Invalid arguments";
        return -1;
    }

    uint64_t start_time = get_timestamp_ns();

    // Initialize result struct
    memset(result, 0, sizeof(diff_result_t));

    int fd1 = open(file1_path, O_RDONLY);
    if (fd1 == -1) {
        result->error_message = "Failed to open file 1";
        return -1;
    }

    int fd2 = open(file2_path, O_RDONLY);
    if (fd2 == -1) {
        close(fd1);
        result->error_message = "Failed to open file 2";
        return -1;
    }

    struct stat stat1, stat2;
    if (fstat(fd1, &stat1) == -1 || fstat(fd2, &stat2) == -1) {
        close(fd1);
        close(fd2);
        result->error_message = "Failed to get file stats";
        return -1;
    }

    size_t size1 = stat1.st_size;
    size_t size2 = stat2.st_size;
    result->bytes_read = size1 + size2;

    char* map1 = (char*)mmap(NULL, size1, PROT_READ, MAP_PRIVATE, fd1, 0);
    char* map2 = (char*)mmap(NULL, size2, PROT_READ, MAP_PRIVATE, fd2, 0);

    if (map1 == MAP_FAILED || map2 == MAP_FAILED) {
        if (map1 != MAP_FAILED) munmap(map1, size1);
        if (map2 != MAP_FAILED) munmap(map2, size2);
        close(fd1);
        close(fd2);
        result->error_message = "Memory mapping failed";
        return -1;
    }

    // Count lines in both files
    result->total_lines_old = count_newlines_avx2(map1, size1);
    result->total_lines_new = count_newlines_avx2(map2, size2);

    // Compare file contents
    size_t common_size = (size1 < size2) ? size1 : size2;
    uint64_t modified_lines = 0;
    size_t i = 0;

    for (; i + (VECTOR_SIZE * UNROLL_FACTOR) <= common_size; i += (VECTOR_SIZE * UNROLL_FACTOR)) {
        __m256i diff = _mm256_setzero_si256();

        #pragma GCC unroll 8
        for (int j = 0; j < UNROLL_FACTOR; ++j) {
            __m256i chunk1 = _mm256_loadu_si256((const __m256i*)(map1 + i + j * VECTOR_SIZE));
            __m256i chunk2 = _mm256_loadu_si256((const __m256i*)(map2 + i + j * VECTOR_SIZE));
            diff = _mm256_or_si256(diff, _mm256_xor_si256(chunk1, chunk2));
        }

        if (_mm256_testz_si256(diff, diff) == 0) {
             // If there's a difference, we'd do more granular line-by-line analysis.
             // For this high-speed version, we'll just count this chunk as modified.
             // A more complex implementation would identify the exact lines.
             // Here, we simplify by estimating modified lines based on diffs.
             modified_lines++; // Simplified for this example
        }
    }

    // Handle remaining bytes
    for (; i < common_size; i++) {
        if (map1[i] != map2[i]) {
            // This is a simplified approach. A real diff would find the
            // start and end of the differing lines.
            modified_lines++;
            break; // Exit after first difference for performance.
        }
    }

    // Account for size difference
    if (size1 != size2) {
        modified_lines += (result->total_lines_old > result->total_lines_new)
                        ? (result->total_lines_old - result->total_lines_new)
                        : (result->total_lines_new - result->total_lines_old);
    }

    result->modified_lines = modified_lines;

    // Cleanup
    munmap(map1, size1);
    munmap(map2, size2);
    close(fd1);
    close(fd2);

    result->processing_time_ns = get_timestamp_ns() - start_time;
    return 0;
}