/**
 * c_diff_engine.h - High-Performance SIMD-Accelerated Diff Engine
 * 
 * Features:
 * - Runtime CPU feature detection and dispatch
 * - AVX-512, AVX2, SSE4.2, and scalar implementations
 * - Byte-level and line-level diff capabilities
 * - Thread-safe operation
 * - Cache-optimized memory access patterns
 */

#ifndef C_DIFF_ENGINE_H
#define C_DIFF_ENGINE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * VERSION AND CONFIGURATION
 * ============================================================================ */

#define DIFF_ENGINE_VERSION_MAJOR 2
#define DIFF_ENGINE_VERSION_MINOR 0
#define DIFF_ENGINE_VERSION_PATCH 0

/* Cache line size for alignment */
#ifndef CACHE_LINE_SIZE
#define CACHE_LINE_SIZE 64
#endif

/* ============================================================================
 * CPU FEATURE DETECTION
 * ============================================================================ */

typedef struct {
    bool sse42;          /* SSE 4.2 support */
    bool avx;            /* AVX support */
    bool avx2;           /* AVX2 + FMA support */
    bool avx512f;        /* AVX-512 Foundation */
    bool avx512bw;       /* AVX-512 Byte/Word */
    bool avx512vl;       /* AVX-512 Vector Length */
    bool bmi2;           /* Bit Manipulation Instructions 2 */
    bool popcnt;         /* Population count instruction */
    uint32_t cache_l1d;  /* L1 data cache size in KB */
    uint32_t cache_l2;   /* L2 cache size in KB */
    uint32_t cache_l3;   /* L3 cache size in KB */
    char vendor[13];     /* CPU vendor string */
    char brand[49];      /* CPU brand string */
} cpu_features_t;

/* Detect CPU features (called automatically on first use) */
const cpu_features_t* diff_engine_get_cpu_features(void);

/* ============================================================================
 * DIFF RESULT STRUCTURES
 * ============================================================================ */

/* Type of difference detected */
typedef enum {
    DIFF_TYPE_NONE = 0,
    DIFF_TYPE_INSERT,
    DIFF_TYPE_DELETE,
    DIFF_TYPE_MODIFY,
    DIFF_TYPE_MOVE
} diff_type_t;

/* Single difference record */
typedef struct {
    diff_type_t type;
    size_t offset_a;     /* Offset in buffer A */
    size_t offset_b;     /* Offset in buffer B */
    size_t length;       /* Length of difference */
    uint32_t hash;       /* Hash of changed content */
} diff_record_t;

/* Complete diff result */
typedef struct {
    diff_record_t* records;   /* Array of difference records */
    size_t count;            /* Number of records */
    size_t capacity;         /* Allocated capacity */
    size_t total_diff_bytes; /* Total bytes that differ */
    double similarity;       /* Similarity score 0.0-1.0 */
    uint64_t time_ns;       /* Processing time in nanoseconds */
} diff_result_t;

/* Line-based diff structure */
typedef struct {
    size_t line_num;      /* Line number (1-based) */
    diff_type_t type;     /* Type of change */
    const char* content;  /* Line content */
    size_t length;        /* Line length */
    uint32_t hash;        /* Line hash */
} line_diff_t;

/* Line diff result */
typedef struct {
    line_diff_t* lines;      /* Array of line differences */
    size_t count;           /* Number of different lines */
    size_t lines_added;     /* Total lines added */
    size_t lines_deleted;   /* Total lines deleted */
    size_t lines_modified;  /* Total lines modified */
    size_t lines_moved;     /* Total lines moved */
} line_diff_result_t;

/* ============================================================================
 * DIFF ENGINE OPTIONS
 * ============================================================================ */

typedef struct {
    bool ignore_whitespace;     /* Ignore whitespace differences */
    bool ignore_case;          /* Case-insensitive comparison */
    bool detect_moves;         /* Detect moved blocks */
    size_t context_lines;      /* Lines of context for line diffs */
    size_t min_match_length;   /* Minimum match length for moves */
    size_t chunk_size;         /* Processing chunk size (0=auto) */
    bool use_simd;            /* Enable SIMD acceleration */
    bool force_scalar;        /* Force scalar implementation */
} diff_options_t;

/* Default options initializer */
#define DIFF_OPTIONS_DEFAULT { \
    .ignore_whitespace = false, \
    .ignore_case = false, \
    .detect_moves = false, \
    .context_lines = 3, \
    .min_match_length = 32, \
    .chunk_size = 0, \
    .use_simd = true, \
    .force_scalar = false \
}

/* ============================================================================
 * CORE DIFF FUNCTIONS
 * ============================================================================ */

/* Initialize diff engine (optional, called automatically) */
int diff_engine_init(void);

/* Shutdown diff engine and free resources */
void diff_engine_shutdown(void);

/* Byte-level diff with automatic SIMD dispatch */
int diff_bytes(
    const void* a, 
    size_t len_a,
    const void* b, 
    size_t len_b,
    diff_result_t* result,
    const diff_options_t* options
);

/* Line-based diff for text files */
int diff_lines(
    const char* text_a,
    size_t len_a,
    const char* text_b,
    size_t len_b,
    line_diff_result_t* result,
    const diff_options_t* options
);

/* Simple byte difference count (fastest, returns count only) */
size_t diff_count_bytes(
    const void* a,
    const void* b,
    size_t len
);

/* ============================================================================
 * SIMD-SPECIFIC FUNCTIONS (FOR DIRECT USE)
 * ============================================================================ */

/* AVX-512 implementation (64 bytes at a time) */
size_t simd_diff_avx512(const void* a, const void* b, size_t len);

/* AVX2 implementation (32 bytes at a time) */
size_t simd_diff_avx2(const void* a, const void* b, size_t len);

/* SSE4.2 implementation (16 bytes at a time) */
size_t simd_diff_sse42(const void* a, const void* b, size_t len);

/* Scalar implementation (fallback) */
size_t simd_diff_scalar(const void* a, const void* b, size_t len);

/* Auto-dispatch based on CPU features */
size_t simd_diff(const void* a, const void* b, size_t len);

/* ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================ */

/* Calculate similarity score between two buffers */
double diff_similarity(
    const void* a,
    size_t len_a,
    const void* b,
    size_t len_b
);

/* Free diff result structures */
void diff_result_free(diff_result_t* result);
void line_diff_result_free(line_diff_result_t* result);

/* Get human-readable diff type string */
const char* diff_type_str(diff_type_t type);

/* Format diff result as unified diff format */
char* diff_format_unified(
    const line_diff_result_t* result,
    const char* name_a,
    const char* name_b
);

/* ============================================================================
 * PERFORMANCE METRICS
 * ============================================================================ */

typedef struct {
    uint64_t bytes_processed;
    uint64_t diffs_computed;
    uint64_t simd_calls;
    uint64_t scalar_calls;
    uint64_t cache_hits;
    uint64_t cache_misses;
    double avg_throughput_mbps;
    const char* best_simd_level;
} diff_engine_stats_t;

/* Get performance statistics */
void diff_engine_get_stats(diff_engine_stats_t* stats);

/* Reset performance counters */
void diff_engine_reset_stats(void);

/* ============================================================================
 * ERROR CODES
 * ============================================================================ */

#define DIFF_SUCCESS           0
#define DIFF_ERROR_NULL_PTR   -1
#define DIFF_ERROR_ALLOC      -2
#define DIFF_ERROR_SIZE       -3
#define DIFF_ERROR_OPTIONS    -4
#define DIFF_ERROR_NOT_INIT   -5

/* Get error description */
const char* diff_error_str(int error_code);

#ifdef __cplusplus
}
#endif

#endif /* C_DIFF_ENGINE_H */