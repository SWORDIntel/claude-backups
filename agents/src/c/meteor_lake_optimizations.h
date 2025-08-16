#ifndef METEOR_LAKE_OPTIMIZATIONS_H
#define METEOR_LAKE_OPTIMIZATIONS_H

#include <immintrin.h>
#include <cpuid.h>
#include <sched.h>
#include <numa.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

// ═══════════════════════════════════════════════════════════════
// METEOR LAKE CPU IDENTIFICATION
// ═══════════════════════════════════════════════════════════════

#define METEOR_LAKE_FAMILY 6
#define METEOR_LAKE_MODEL 0xAA     // Intel Core Ultra (Meteor Lake)
#define METEOR_LAKE_SIGNATURE 0x000A06A4  // From project docs

// Core topology - Dell Latitude 5450 MIL-SPEC configuration
typedef enum {
    CORE_TYPE_P = 0,        // Performance cores (hyperthreaded)
    CORE_TYPE_E = 1,        // Efficiency cores 
    CORE_TYPE_LP_E = 2,     // Low Power E-cores
    CORE_TYPE_INVALID = -1
} meteor_lake_core_type_t;

// Verified core topology from project documentation
static const int METEOR_LAKE_P_CORES[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};  // 12 logical cores
static const int METEOR_LAKE_E_CORES[] = {12, 13, 14, 15, 16, 17, 18, 19};       // 8 standard E-cores  
static const int METEOR_LAKE_LP_E_CORES[] = {20, 21};                             // 2 low-power E-cores

#define P_CORE_COUNT 12
#define E_CORE_COUNT 8
#define LP_E_CORE_COUNT 2
#define TOTAL_CORE_COUNT 22

// Ultra performance cores (fastest P-cores from MSR analysis)
static const int METEOR_LAKE_ULTRA_CORES[] = {11, 14, 15, 16};
#define ULTRA_CORE_COUNT 4

// ═══════════════════════════════════════════════════════════════
// MSR DEFINITIONS FOR PERFORMANCE CONTROL
// ═══════════════════════════════════════════════════════════════

// Performance MSRs
#define IA32_PERF_CTL           0x199
#define IA32_MISC_ENABLE        0x1A0
#define IA32_THERM_STATUS       0x19C
#define IA32_TEMPERATURE_TARGET 0x1A2
#define IA32_TURBO_RATIO_LIMIT  0x1AD
#define IA32_TURBO_RATIO_LIMIT1 0x1AE

// Power management MSRs
#define MSR_PKG_POWER_LIMIT     0x610
#define MSR_PP0_POWER_LIMIT     0x638
#define MSR_PP1_POWER_LIMIT     0x640
#define MSR_RAPL_POWER_UNIT     0x606

// HWP (Hardware P-State) MSRs
#define IA32_HWP_REQUEST        0x774
#define IA32_HWP_STATUS         0x777
#define IA32_HWP_CAPABILITIES   0x771

// Mystery MSRs discovered in project
#define MSR_UNKNOWN_C80         0xC80  // Read-only, bit 30 set
#define MSR_UNKNOWN_C82         0xC82  // Writable, bit 0 only
#define MSR_UNKNOWN_C85         0xC85  // Writable, bit 0 only
#define MSR_UNKNOWN_E2F         0xE2F  // Writable, unknown function

// Performance targets
#define TURBO_RATIO_5GHZ        0x32   // 50 * 100MHz = 5.0GHz
#define TURBO_RATIO_38GHZ       0x26   // 38 * 100MHz = 3.8GHz
#define THERMAL_TARGET_MAX      0x6E   // 110°C (from project docs)
#define THERMAL_TARGET_SAFE     0x55   // 85°C throttle point

// ═══════════════════════════════════════════════════════════════
// FEATURE DETECTION
// ═══════════════════════════════════════════════════════════════

// Detect Meteor Lake CPU
static inline bool is_meteor_lake_cpu(void) {
    unsigned int eax, ebx, ecx, edx;
    __cpuid(1, eax, ebx, ecx, edx);
    
    unsigned int family = ((eax >> 8) & 0xF) + ((eax >> 20) & 0xFF);
    unsigned int model = ((eax >> 4) & 0xF) + ((eax >> 12) & 0xF0);
    
    return (family == METEOR_LAKE_FAMILY && model == METEOR_LAKE_MODEL);
}

// AVX-512 support check (P-cores only)
static inline bool has_avx512_support(void) {
    unsigned int eax, ebx, ecx, edx;
    
    // Check CPUID leaf 7, subleaf 0
    __cpuid_count(7, 0, eax, ebx, ecx, edx);
    
    // Check AVX-512 Foundation, DQ, CD, BW, VL bits
    bool avx512f = (ebx & (1 << 16)) != 0;   // AVX-512 Foundation
    bool avx512dq = (ebx & (1 << 17)) != 0;  // AVX-512 DQ
    bool avx512cd = (ebx & (1 << 28)) != 0;  // AVX-512 CD
    bool avx512bw = (ebx & (1 << 30)) != 0;  // AVX-512 BW
    bool avx512vl = (ebx & (1 << 31)) != 0;  // AVX-512 VL
    
    return avx512f && avx512dq && avx512cd && avx512bw && avx512vl;
}

// NPU detection for Meteor Lake
static inline bool has_meteor_lake_npu(void) {
    // Check for Intel VSC device (NPU interface)
    return access("/dev/intel_vsc", F_OK) == 0;
}

// TME (Total Memory Encryption) detection
static inline bool has_tme_enabled(void) {
    unsigned int eax, ebx, ecx, edx;
    
    // Check CPUID leaf 7, subleaf 0
    __cpuid_count(7, 0, eax, ebx, ecx, edx);
    
    // TME capability bit
    return (ecx & (1 << 13)) != 0;
}

// ═══════════════════════════════════════════════════════════════
// MSR ACCESS FUNCTIONS
// ═══════════════════════════════════════════════════════════════

static inline int rdmsr_safe(unsigned int msr, uint64_t *value) {
    int fd;
    char msr_file[32];
    
    snprintf(msr_file, sizeof(msr_file), "/dev/cpu/0/msr");
    fd = open(msr_file, O_RDONLY);
    if (fd < 0) return -1;
    
    if (pread(fd, value, sizeof(*value), msr) != sizeof(*value)) {
        close(fd);
        return -1;
    }
    
    close(fd);
    return 0;
}

static inline int wrmsr_safe(unsigned int msr, uint64_t value) {
    int fd;
    char msr_file[32];
    
    snprintf(msr_file, sizeof(msr_file), "/dev/cpu/0/msr");
    fd = open(msr_file, O_WRONLY);
    if (fd < 0) return -1;
    
    if (pwrite(fd, &value, sizeof(value), msr) != sizeof(value)) {
        close(fd);
        return -1;
    }
    
    close(fd);
    return 0;
}

// ═══════════════════════════════════════════════════════════════
// CORE TYPE DETECTION
// ═══════════════════════════════════════════════════════════════

static inline meteor_lake_core_type_t get_current_core_type(void) {
    int cpu = sched_getcpu();
    
    if (cpu < 0) return CORE_TYPE_INVALID;
    
    if (cpu < 12) return CORE_TYPE_P;
    if (cpu < 20) return CORE_TYPE_E;
    if (cpu < 22) return CORE_TYPE_LP_E;
    
    return CORE_TYPE_INVALID;
}

static inline bool is_running_on_p_core(void) {
    return get_current_core_type() == CORE_TYPE_P;
}

// ═══════════════════════════════════════════════════════════════
// THREAD AFFINITY MANAGEMENT
// ═══════════════════════════════════════════════════════════════

// Set affinity to specific core type
static inline int set_core_type_affinity(meteor_lake_core_type_t core_type) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    
    switch (core_type) {
        case CORE_TYPE_P:
            for (int i = 0; i < P_CORE_COUNT; i++) {
                CPU_SET(METEOR_LAKE_P_CORES[i], &cpuset);
            }
            break;
            
        case CORE_TYPE_E:
            for (int i = 0; i < E_CORE_COUNT; i++) {
                CPU_SET(METEOR_LAKE_E_CORES[i], &cpuset);
            }
            break;
            
        case CORE_TYPE_LP_E:
            for (int i = 0; i < LP_E_CORE_COUNT; i++) {
                CPU_SET(METEOR_LAKE_LP_E_CORES[i], &cpuset);
            }
            break;
            
        default:
            return -1;
    }
    
    return sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
}

// Set affinity to ultra performance cores
static inline int set_ultra_core_affinity(void) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    
    for (int i = 0; i < ULTRA_CORE_COUNT; i++) {
        CPU_SET(METEOR_LAKE_ULTRA_CORES[i], &cpuset);
    }
    
    return sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
}

// ═══════════════════════════════════════════════════════════════
// PERFORMANCE OPTIMIZATION
// ═══════════════════════════════════════════════════════════════

// Force 5GHz turbo on ultra cores (requires root)
static inline int force_5ghz_turbo(void) {
    uint64_t hwp_request = 0x00003232;  // Min=50, Max=50 (5GHz)
    
    for (int i = 0; i < ULTRA_CORE_COUNT; i++) {
        char msr_file[32];
        snprintf(msr_file, sizeof(msr_file), "/dev/cpu/%d/msr", 
                 METEOR_LAKE_ULTRA_CORES[i]);
        
        int fd = open(msr_file, O_WRONLY);
        if (fd < 0) return -1;
        
        if (pwrite(fd, &hwp_request, sizeof(hwp_request), IA32_HWP_REQUEST) 
            != sizeof(hwp_request)) {
            close(fd);
            return -1;
        }
        close(fd);
    }
    
    return 0;
}

// Remove power limits for maximum performance
static inline int remove_power_limits(void) {
    uint64_t max_power = 0x00FFFFFF00FFFFFF;  // Unlimited power
    
    if (wrmsr_safe(MSR_PKG_POWER_LIMIT, max_power) < 0) return -1;
    if (wrmsr_safe(MSR_PP0_POWER_LIMIT, 0xFFFFFF) < 0) return -1;
    if (wrmsr_safe(MSR_PP1_POWER_LIMIT, 0xFFFFFF) < 0) return -1;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════
// THERMAL MONITORING
// ═══════════════════════════════════════════════════════════════

static inline int get_package_temperature(void) {
    uint64_t therm_status;
    
    if (rdmsr_safe(IA32_THERM_STATUS, &therm_status) < 0) {
        return -1;
    }
    
    // Extract digital readout (bits 22:16)
    int digital_readout = (therm_status >> 16) & 0x7F;
    
    // Get TjMax
    uint64_t temp_target;
    if (rdmsr_safe(IA32_TEMPERATURE_TARGET, &temp_target) < 0) {
        return -1;
    }
    
    int tjmax = (temp_target >> 16) & 0xFF;
    
    // Calculate actual temperature
    return tjmax - digital_readout;
}

// Check if thermal throttling is active
static inline bool is_thermal_throttling(void) {
    uint64_t therm_status;
    
    if (rdmsr_safe(IA32_THERM_STATUS, &therm_status) < 0) {
        return false;
    }
    
    // Check thermal status and log bits
    return (therm_status & 0x3) != 0;
}

// ═══════════════════════════════════════════════════════════════
// MEMORY OPTIMIZATION
// ═══════════════════════════════════════════════════════════════

// Optimized memory allocation for Meteor Lake
static inline void* meteor_lake_aligned_alloc(size_t size, bool high_perf) {
    size_t alignment = 64;  // Cache line size
    
    if (high_perf && size >= 4096) {
        alignment = 2097152;  // 2MB huge page alignment
    }
    
    // Round size up to alignment
    size = (size + alignment - 1) & ~(alignment - 1);
    
    void* ptr = NULL;
    
    if (numa_available() >= 0) {
        // Allocate on node 0 for P-cores
        ptr = numa_alloc_onnode(size, 0);
    } else {
        // Fallback to aligned allocation
        if (posix_memalign(&ptr, alignment, size) != 0) {
            return NULL;
        }
    }
    
    // Prefault pages for lower latency
    if (ptr && high_perf) {
        memset(ptr, 0, size);
    }
    
    return ptr;
}

// ═══════════════════════════════════════════════════════════════
// SIMD DISPATCH
// ═══════════════════════════════════════════════════════════════

// Memory copy with core-aware SIMD dispatch
static inline void meteor_lake_memcpy(void* dst, const void* src, size_t size) {
    if (!dst || !src || size == 0) return;
    
    // Use AVX-512 on P-cores for large copies
    if (is_running_on_p_core() && has_avx512_support() && size >= 512) {
        const char* s = (const char*)src;
        char* d = (char*)dst;
        
        // Process 64-byte chunks with AVX-512
        while (size >= 64) {
            __m512i data = _mm512_loadu_si512((const __m512i*)s);
            _mm512_storeu_si512((__m512i*)d, data);
            s += 64;
            d += 64;
            size -= 64;
        }
        
        // Handle remainder
        if (size > 0) {
            memcpy(d, s, size);
        }
    } 
    // Use AVX2 on E-cores or smaller copies
    else if (size >= 32) {
        const char* s = (const char*)src;
        char* d = (char*)dst;
        
        // Process 32-byte chunks with AVX2
        while (size >= 32) {
            __m256i data = _mm256_loadu_si256((const __m256i*)s);
            _mm256_storeu_si256((__m256i*)d, data);
            s += 32;
            d += 32;
            size -= 32;
        }
        
        // Handle remainder
        if (size > 0) {
            memcpy(d, s, size);
        }
    }
    // Standard memcpy for small copies
    else {
        memcpy(dst, src, size);
    }
}

// ═══════════════════════════════════════════════════════════════
// SPINLOCK OPTIMIZED FOR METEOR LAKE
// ═══════════════════════════════════════════════════════════════

typedef struct {
    volatile int lock;
    char padding[60];  // Avoid false sharing (64-byte cache line)
} __attribute__((aligned(64))) meteor_lake_spinlock_t;

static inline void meteor_lake_spinlock_init(meteor_lake_spinlock_t* lock) {
    lock->lock = 0;
}

static inline void meteor_lake_spinlock_lock(meteor_lake_spinlock_t* lock) {
    while (__atomic_exchange_n(&lock->lock, 1, __ATOMIC_ACQUIRE)) {
        // Hybrid-aware pause
        if (is_running_on_p_core()) {
            __builtin_ia32_pause();
            __builtin_ia32_pause();  // Double pause on P-cores
        } else {
            __builtin_ia32_pause();
        }
    }
}

static inline int meteor_lake_spinlock_trylock(meteor_lake_spinlock_t* lock) {
    return __atomic_exchange_n(&lock->lock, 1, __ATOMIC_ACQUIRE) == 0;
}

static inline void meteor_lake_spinlock_unlock(meteor_lake_spinlock_t* lock) {
    __atomic_store_n(&lock->lock, 0, __ATOMIC_RELEASE);
}

// ═══════════════════════════════════════════════════════════════
// COMPILER FLAGS GENERATION
// ═══════════════════════════════════════════════════════════════

// Get optimal compiler flags for current core type
static inline const char* get_meteor_lake_cflags(meteor_lake_core_type_t core_type) {
    switch (core_type) {
        case CORE_TYPE_P:
            // P-cores with AVX-512 support
            return "-march=alderlake -mtune=alderlake "
                   "-mavx512f -mavx512dq -mavx512cd -mavx512bw -mavx512vl "
                   "-mprefer-vector-width=512 -O3 -flto";
                   
        case CORE_TYPE_E:
        case CORE_TYPE_LP_E:
            // E-cores with AVX2 only
            return "-march=alderlake -mtune=alderlake -mno-avx512f "
                   "-mavx2 -mfma -mbmi -mbmi2 -mlzcnt -mpopcnt "
                   "-mprefer-vector-width=256 -O2";
                   
        default:
            // Safe fallback
            return "-march=x86-64-v3 -O2";
    }
}

// ═══════════════════════════════════════════════════════════════
// NPU INTEGRATION (EXPERIMENTAL)
// ═══════════════════════════════════════════════════════════════

typedef struct {
    void* handle;
    bool available;
    int device_fd;
} meteor_lake_npu_context_t;

// Initialize NPU context
static inline meteor_lake_npu_context_t* meteor_lake_npu_init(void) {
    meteor_lake_npu_context_t* ctx = calloc(1, sizeof(meteor_lake_npu_context_t));
    if (!ctx) return NULL;
    
    // Check for NPU device
    ctx->device_fd = open("/dev/intel_vsc", O_RDWR);
    ctx->available = (ctx->device_fd >= 0);
    
    return ctx;
}

// Cleanup NPU context
static inline void meteor_lake_npu_cleanup(meteor_lake_npu_context_t* ctx) {
    if (!ctx) return;
    
    if (ctx->device_fd >= 0) {
        close(ctx->device_fd);
    }
    
    free(ctx);
}

// ═══════════════════════════════════════════════════════════════
// PERFORMANCE PROFILING
// ═══════════════════════════════════════════════════════════════

// Get current CPU frequency in MHz
static inline int get_cpu_frequency_mhz(int cpu) {
    char path[256];
    snprintf(path, sizeof(path), 
             "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq", cpu);
    
    FILE* f = fopen(path, "r");
    if (!f) return -1;
    
    int freq_khz;
    if (fscanf(f, "%d", &freq_khz) != 1) {
        fclose(f);
        return -1;
    }
    
    fclose(f);
    return freq_khz / 1000;  // Convert to MHz
}

// Performance monitoring structure
typedef struct {
    uint64_t cycles_start;
    uint64_t cycles_end;
    int temperature_start;
    int temperature_end;
    bool throttled;
} meteor_lake_perf_t;

// Start performance monitoring
static inline void meteor_lake_perf_start(meteor_lake_perf_t* perf) {
    perf->cycles_start = __rdtsc();
    perf->temperature_start = get_package_temperature();
    perf->throttled = false;
}

// End performance monitoring
static inline void meteor_lake_perf_end(meteor_lake_perf_t* perf) {
    perf->cycles_end = __rdtsc();
    perf->temperature_end = get_package_temperature();
    perf->throttled = is_thermal_throttling();
}

// Get elapsed cycles
static inline uint64_t meteor_lake_perf_cycles(const meteor_lake_perf_t* perf) {
    return perf->cycles_end - perf->cycles_start;
}

#endif // METEOR_LAKE_OPTIMIZATIONS_H