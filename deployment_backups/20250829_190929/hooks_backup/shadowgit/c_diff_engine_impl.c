/**
 * c_diff_engine.c - High-Performance SIMD-Accelerated Diff Engine Implementation
 * 
 * Compile with:
 * gcc -O3 -march=native -mavx512f -mavx512bw -mavx2 -msse4.2 -mbmi2 -mpopcnt \
 *     -shared -fPIC -o c_diff_engine.so c_diff_engine.c
 */

#include "c_diff_engine.h"
#include <immintrin.h>
#include <cpuid.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <ctype.h>

#ifdef _MSC_VER
#include <intrin.h>
#define __builtin_popcount __popcnt
#define __builtin_popcountll __popcnt64
#endif

/* ============================================================================
 * GLOBAL STATE
 * ============================================================================ */

static cpu_features_t g_cpu_features = {0};
static bool g_features_detected = false;
static diff_engine_stats_t g_stats = {0};

/* Function pointer for runtime dispatch */
static size_t (*g_simd_diff_func)(const void*, const void*, size_t) = NULL;

/* ============================================================================
 * CPU FEATURE DETECTION
 * ============================================================================ */

static void detect_cpu_features(void) {
    if (g_features_detected) return;
    
    uint32_t eax, ebx, ecx, edx;
    uint32_t max_level;
    
#ifdef _MSC_VER
    int cpuinfo[4];
    __cpuid(cpuinfo, 0);
    max_level = cpuinfo[0];
#else
    max_level = __get_cpuid_max(0, NULL);
#endif
    
    /* Get vendor string */
#ifdef _MSC_VER
    __cpuid(cpuinfo, 0);
    memcpy(g_cpu_features.vendor, &cpuinfo[1], 4);
    memcpy(g_cpu_features.vendor + 4, &cpuinfo[3], 4);
    memcpy(g_cpu_features.vendor + 8, &cpuinfo[2], 4);
#else
    __cpuid(0, eax, ebx, ecx, edx);
    memcpy(g_cpu_features.vendor, &ebx, 4);
    memcpy(g_cpu_features.vendor + 4, &edx, 4);
    memcpy(g_cpu_features.vendor + 8, &ecx, 4);
#endif
    g_cpu_features.vendor[12] = '\0';
    
    /* Basic features */
    if (max_level >= 1) {
#ifdef _MSC_VER
        __cpuid(cpuinfo, 1);
        ecx = cpuinfo[2];
        edx = cpuinfo[3];
#else
        __cpuid(1, eax, ebx, ecx, edx);
#endif
        g_cpu_features.sse42 = (ecx >> 20) & 1;
        g_cpu_features.popcnt = (ecx >> 23) & 1;
        g_cpu_features.avx = (ecx >> 28) & 1;
    }
    
    /* Extended features */
    if (max_level >= 7) {
#ifdef _MSC_VER
        __cpuidex(cpuinfo, 7, 0);
        ebx = cpuinfo[1];
        ecx = cpuinfo[2];
#else
        __cpuid_count(7, 0, eax, ebx, ecx, edx);
#endif
        g_cpu_features.avx2 = (ebx >> 5) & 1;
        g_cpu_features.bmi2 = (ebx >> 8) & 1;
        g_cpu_features.avx512f = (ebx >> 16) & 1;
        g_cpu_features.avx512bw = (ebx >> 30) & 1;
        g_cpu_features.avx512vl = (ecx >> 1) & 1;
    }
    
    /* Cache sizes (Intel specific) */
    if (strncmp(g_cpu_features.vendor, "GenuineIntel", 12) == 0) {
        if (max_level >= 4) {
            for (int i = 0; i < 4; i++) {
#ifdef _MSC_VER
                __cpuidex(cpuinfo, 4, i);
                eax = cpuinfo[0];
                ebx = cpuinfo[1];
                ecx = cpuinfo[2];
#else
                __cpuid_count(4, i, eax, ebx, ecx, edx);
#endif
                int cache_type = eax & 0x1F;
                if (cache_type == 0) break;
                
                int cache_level = (eax >> 5) & 0x7;
                int line_size = (ebx & 0xFFF) + 1;
                int partitions = ((ebx >> 12) & 0x3FF) + 1;
                int ways = ((ebx >> 22) & 0x3FF) + 1;
                int sets = ecx + 1;
                
                uint32_t cache_size = (ways * partitions * line_size * sets) / 1024;
                
                if (cache_type == 1) { /* Data cache */
                    if (cache_level == 1) g_cpu_features.cache_l1d = cache_size;
                    else if (cache_level == 2) g_cpu_features.cache_l2 = cache_size;
                    else if (cache_level == 3) g_cpu_features.cache_l3 = cache_size;
                }
            }
        }
    }
    
    /* Select best SIMD function */
    if (g_cpu_features.avx512f && g_cpu_features.avx512bw) {
        g_simd_diff_func = simd_diff_avx512;
        g_stats.best_simd_level = "AVX-512";
    } else if (g_cpu_features.avx2) {
        g_simd_diff_func = simd_diff_avx2;
        g_stats.best_simd_level = "AVX2";
    } else if (g_cpu_features.sse42) {
        g_simd_diff_func = simd_diff_sse42;
        g_stats.best_simd_level = "SSE4.2";
    } else {
        g_simd_diff_func = simd_diff_scalar;
        g_stats.best_simd_level = "Scalar";
    }
    
    g_features_detected = true;
}

const cpu_features_t* diff_engine_get_cpu_features(void) {
    detect_cpu_features();
    return &g_cpu_features;
}

/* ============================================================================
 * SIMD IMPLEMENTATIONS
 * ============================================================================ */

/* AVX-512 implementation */
size_t simd_diff_avx512(const void* a, const void* b, size_t len) {
#ifdef __AVX512F__
    const uint8_t* pa = (const uint8_t*)a;
    const uint8_t* pb = (const uint8_t*)b;
    size_t diff_count = 0;
    size_t i = 0;
    
    /* Process 64 bytes at a time */
    for (; i + 64 <= len; i += 64) {
        __m512i va = _mm512_loadu_si512((__m512i*)(pa + i));
        __m512i vb = _mm512_loadu_si512((__m512i*)(pb + i));
        __mmask64 mask = _mm512_cmpneq_epi8_mask(va, vb);
        diff_count += __builtin_popcountll(mask);
    }
    
    /* Handle remainder with AVX2 if available */
    if (i + 32 <= len) {
        __m256i va = _mm256_loadu_si256((__m256i*)(pa + i));
        __m256i vb = _mm256_loadu_si256((__m256i*)(pb + i));
        __m256i vcmp = _mm256_cmpeq_epi8(va, vb);
        uint32_t mask = _mm256_movemask_epi8(vcmp);
        diff_count += __builtin_popcount(~mask);
        i += 32;
    }
    
    /* Handle remaining bytes */
    for (; i < len; i++) {
        if (pa[i] != pb[i]) diff_count++;
    }
    
    g_stats.simd_calls++;
    return diff_count;
#else
    return simd_diff_avx2(a, b, len);
#endif
}

/* AVX2 implementation */
size_t simd_diff_avx2(const void* a, const void* b, size_t len) {
#ifdef __AVX2__
    const uint8_t* pa = (const uint8_t*)a;
    const uint8_t* pb = (const uint8_t*)b;
    size_t diff_count = 0;
    size_t i = 0;
    
    /* Process 32 bytes at a time */
    for (; i + 32 <= len; i += 32) {
        __m256i va = _mm256_loadu_si256((__m256i*)(pa + i));
        __m256i vb = _mm256_loadu_si256((__m256i*)(pb + i));
        __m256i vcmp = _mm256_cmpeq_epi8(va, vb);
        uint32_t mask = _mm256_movemask_epi8(vcmp);
        diff_count += __builtin_popcount(~mask);
    }
    
    /* Handle remainder with SSE if available */
    if (i + 16 <= len) {
        __m128i va = _mm_loadu_si128((__m128i*)(pa + i));
        __m128i vb = _mm_loadu_si128((__m128i*)(pb + i));
        __m128i vcmp = _mm_cmpeq_epi8(va, vb);
        uint16_t mask = _mm_movemask_epi8(vcmp);
        diff_count += __builtin_popcount(~mask & 0xFFFF);
        i += 16;
    }
    
    /* Handle remaining bytes */
    for (; i < len; i++) {
        if (pa[i] != pb[i]) diff_count++;
    }
    
    g_stats.simd_calls++;
    return diff_count;
#else
    return simd_diff_sse42(a, b, len);
#endif
}

/* SSE4.2 implementation */
size_t simd_diff_sse42(const void* a, const void* b, size_t len) {
#ifdef __SSE4_2__
    const uint8_t* pa = (const uint8_t*)a;
    const uint8_t* pb = (const uint8_t*)b;
    size_t diff_count = 0;
    size_t i = 0;
    
    /* Process 16 bytes at a time */
    for (; i + 16 <= len; i += 16) {
        __m128i va = _mm_loadu_si128((__m128i*)(pa + i));
        __m128i vb = _mm_loadu_si128((__m128i*)(pb + i));
        __m128i vcmp = _mm_cmpeq_epi8(va, vb);
        uint16_t mask = _mm_movemask_epi8(vcmp);
        diff_count += __builtin_popcount(~mask & 0xFFFF);
    }
    
    /* Handle remaining bytes */
    for (; i < len; i++) {
        if (pa[i] != pb[i]) diff_count++;
    }
    
    g_stats.simd_calls++;
    return diff_count;
#else
    return simd_diff_scalar(a, b, len);
#endif
}

/* Scalar implementation (fallback) */
size_t simd_diff_scalar(const void* a, const void* b, size_t len) {
    const uint8_t* pa = (const uint8_t*)a;
    const uint8_t* pb = (const uint8_t*)b;
    size_t diff_count = 0;
    
    /* Unroll loop for better performance */
    size_t i = 0;
    for (; i + 8 <= len; i += 8) {
        diff_count += (pa[i] != pb[i]);
        diff_count += (pa[i+1] != pb[i+1]);
        diff_count += (pa[i+2] != pb[i+2]);
        diff_count += (pa[i+3] != pb[i+3]);
        diff_count += (pa[i+4] != pb[i+4]);
        diff_count += (pa[i+5] != pb[i+5]);
        diff_count += (pa[i+6] != pb[i+6]);
        diff_count += (pa[i+7] != pb[i+7]);
    }
    
    /* Handle remainder */
    for (; i < len; i++) {
        if (pa[i] != pb[i]) diff_count++;
    }
    
    g_stats.scalar_calls++;
    return diff_count;
}

/* Auto-dispatch implementation */
size_t simd_diff(const void* a, const void* b, size_t len) {
    detect_cpu_features();
    return g_simd_diff_func(a, b, len);
}

/* ============================================================================
 * CORE DIFF FUNCTIONS
 * ============================================================================ */

/* Simple byte difference count */
size_t diff_count_bytes(const void* a, const void* b, size_t len) {
    if (!a || !b) return len;
    
    detect_cpu_features();
    
    size_t count = g_simd_diff_func(a, b, len);
    
    g_stats.bytes_processed += len;
    g_stats.diffs_computed++;
    
    return count;
}

/* Initialize diff engine */
int diff_engine_init(void) {
    detect_cpu_features();
    memset(&g_stats, 0, sizeof(g_stats));
    g_stats.best_simd_level = g_cpu_features.avx512f ? "AVX-512" :
                              g_cpu_features.avx2 ? "AVX2" :
                              g_cpu_features.sse42 ? "SSE4.2" : "Scalar";
    return DIFF_SUCCESS;
}

/* Shutdown diff engine */
void diff_engine_shutdown(void) {
    /* Currently no cleanup needed */
}

/* Detailed byte-level diff */
int diff_bytes(const void* a, size_t len_a, const void* b, size_t len_b,
               diff_result_t* result, const diff_options_t* options) {
    if (!a || !b || !result) return DIFF_ERROR_NULL_PTR;
    
    detect_cpu_features();
    
    /* Initialize result */
    memset(result, 0, sizeof(*result));
    
    /* Start timing */
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    /* Simple implementation for now - just count differences */
    size_t min_len = len_a < len_b ? len_a : len_b;
    size_t max_len = len_a > len_b ? len_a : len_b;
    
    /* Count byte differences in common length */
    size_t diff_count = 0;
    if (!options || !options->force_scalar) {
        diff_count = g_simd_diff_func(a, b, min_len);
    } else {
        diff_count = simd_diff_scalar(a, b, min_len);
    }
    
    /* Add difference for length mismatch */
    diff_count += (max_len - min_len);
    
    /* Calculate similarity */
    result->total_diff_bytes = diff_count;
    result->similarity = 1.0 - ((double)diff_count / max_len);
    
    /* End timing */
    clock_gettime(CLOCK_MONOTONIC, &end);
    result->time_ns = (end.tv_sec - start.tv_sec) * 1000000000ULL +
                     (end.tv_nsec - start.tv_nsec);
    
    /* Update stats */
    g_stats.bytes_processed += max_len;
    g_stats.diffs_computed++;
    
    return DIFF_SUCCESS;
}

/* Line-based diff for text files */
int diff_lines(const char* text_a, size_t len_a, const char* text_b, size_t len_b,
               line_diff_result_t* result, const diff_options_t* options) {
    if (!text_a || !text_b || !result) return DIFF_ERROR_NULL_PTR;
    
    /* Initialize result */
    memset(result, 0, sizeof(*result));
    
    /* Count lines in each text */
    size_t lines_a = 1, lines_b = 1;
    for (size_t i = 0; i < len_a; i++) {
        if (text_a[i] == '\n') lines_a++;
    }
    for (size_t i = 0; i < len_b; i++) {
        if (text_b[i] == '\n') lines_b++;
    }
    
    /* Allocate line arrays */
    const char** lines_arr_a = calloc(lines_a, sizeof(char*));
    const char** lines_arr_b = calloc(lines_b, sizeof(char*));
    size_t* lens_a = calloc(lines_a, sizeof(size_t));
    size_t* lens_b = calloc(lines_b, sizeof(size_t));
    
    if (!lines_arr_a || !lines_arr_b || !lens_a || !lens_b) {
        free(lines_arr_a);
        free(lines_arr_b);
        free(lens_a);
        free(lens_b);
        return DIFF_ERROR_ALLOC;
    }
    
    /* Split text into lines */
    size_t line_idx = 0;
    const char* line_start = text_a;
    for (size_t i = 0; i <= len_a; i++) {
        if (i == len_a || text_a[i] == '\n') {
            lines_arr_a[line_idx] = line_start;
            lens_a[line_idx] = (text_a + i) - line_start;
            line_idx++;
            if (i < len_a) line_start = text_a + i + 1;
        }
    }
    
    line_idx = 0;
    line_start = text_b;
    for (size_t i = 0; i <= len_b; i++) {
        if (i == len_b || text_b[i] == '\n') {
            lines_arr_b[line_idx] = line_start;
            lens_b[line_idx] = (text_b + i) - line_start;
            line_idx++;
            if (i < len_b) line_start = text_b + i + 1;
        }
    }
    
    /* Simple line diff - compare line by line */
    size_t min_lines = lines_a < lines_b ? lines_a : lines_b;
    size_t diff_lines = 0;
    
    for (size_t i = 0; i < min_lines; i++) {
        if (lens_a[i] != lens_b[i] ||
            memcmp(lines_arr_a[i], lines_arr_b[i], lens_a[i]) != 0) {
            diff_lines++;
            result->lines_modified++;
        }
    }
    
    /* Count added/deleted lines */
    if (lines_b > lines_a) {
        result->lines_added = lines_b - lines_a;
    } else if (lines_a > lines_b) {
        result->lines_deleted = lines_a - lines_b;
    }
    
    result->count = diff_lines + result->lines_added + result->lines_deleted;
    
    /* Cleanup */
    free(lines_arr_a);
    free(lines_arr_b);
    free(lens_a);
    free(lens_b);
    
    return DIFF_SUCCESS;
}

/* ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================ */

/* Calculate similarity score */
double diff_similarity(const void* a, size_t len_a, const void* b, size_t len_b) {
    if (!a || !b) return 0.0;
    
    size_t min_len = len_a < len_b ? len_a : len_b;
    size_t max_len = len_a > len_b ? len_a : len_b;
    
    if (max_len == 0) return 1.0;
    
    size_t diff_count = diff_count_bytes(a, b, min_len);
    diff_count += (max_len - min_len);
    
    return 1.0 - ((double)diff_count / max_len);
}

/* Free diff result */
void diff_result_free(diff_result_t* result) {
    if (result && result->records) {
        free(result->records);
        result->records = NULL;
        result->count = 0;
        result->capacity = 0;
    }
}

/* Free line diff result */
void line_diff_result_free(line_diff_result_t* result) {
    if (result && result->lines) {
        free(result->lines);
        result->lines = NULL;
        result->count = 0;
    }
}

/* Get diff type string */
const char* diff_type_str(diff_type_t type) {
    switch (type) {
        case DIFF_TYPE_NONE: return "none";
        case DIFF_TYPE_INSERT: return "insert";
        case DIFF_TYPE_DELETE: return "delete";
        case DIFF_TYPE_MODIFY: return "modify";
        case DIFF_TYPE_MOVE: return "move";
        default: return "unknown";
    }
}

/* Get error description */
const char* diff_error_str(int error_code) {
    switch (error_code) {
        case DIFF_SUCCESS: return "Success";
        case DIFF_ERROR_NULL_PTR: return "Null pointer";
        case DIFF_ERROR_ALLOC: return "Memory allocation failed";
        case DIFF_ERROR_SIZE: return "Invalid size";
        case DIFF_ERROR_OPTIONS: return "Invalid options";
        case DIFF_ERROR_NOT_INIT: return "Engine not initialized";
        default: return "Unknown error";
    }
}

/* ============================================================================
 * PERFORMANCE METRICS
 * ============================================================================ */

/* Get performance statistics */
void diff_engine_get_stats(diff_engine_stats_t* stats) {
    if (!stats) return;
    
    *stats = g_stats;
    
    /* Calculate throughput */
    if (g_stats.diffs_computed > 0) {
        stats->avg_throughput_mbps = 
            (double)g_stats.bytes_processed / (1024.0 * 1024.0);
    }
}

/* Reset performance counters */
void diff_engine_reset_stats(void) {
    uint64_t bytes = g_stats.bytes_processed;
    const char* level = g_stats.best_simd_level;
    memset(&g_stats, 0, sizeof(g_stats));
    g_stats.bytes_processed = bytes;
    g_stats.best_simd_level = level;
}