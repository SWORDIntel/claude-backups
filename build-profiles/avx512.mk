# Intel AVX-512 Compiler Profile
# Optimized for Intel Ice Lake, Tiger Lake, and Sapphire Rapids processors
#
# Architecture: Intel processors with full AVX-512 support
# SIMD Support: AVX-512F, AVX-512DQ, AVX-512BW, AVX-512VL, AVX2, FMA3, AES-NI
# Use Cases: High-performance computing, data center, scientific computing

CPU_ARCH = avx512

# Base optimization level
PROD_FLAGS = -O2

# Architecture-specific tuning
PROD_FLAGS += -march=native -mtune=native

# AVX-512 Foundation and Extensions
PROD_FLAGS += -mavx512f       # AVX-512 Foundation (base)
PROD_FLAGS += -mavx512dq      # AVX-512 Doubleword and Quadword
PROD_FLAGS += -mavx512bw      # AVX-512 Byte and Word
PROD_FLAGS += -mavx512vl      # AVX-512 Vector Length (128/256-bit)
PROD_FLAGS += -mavx512cd      # AVX-512 Conflict Detection

# Backward compatible SIMD
PROD_FLAGS += -mavx2          # AVX2 (fallback path)
PROD_FLAGS += -mfma           # FMA3
PROD_FLAGS += -maes           # AES-NI

# Link-Time Optimization
PROD_FLAGS += -flto=thin

# Loop and function optimizations
PROD_FLAGS += -funroll-loops
PROD_FLAGS += -finline-functions

# Code generation optimizations
PROD_FLAGS += -fomit-frame-pointer
PROD_FLAGS += -fno-semantic-interposition

# Export for visibility
export AVX512_FLAGS = $(PROD_FLAGS)
