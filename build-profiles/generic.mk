# Generic Compiler Profile (Maximum Compatibility)
#
# Fallback profile for:
#   - Unknown/unsupported CPUs
#   - Cross-compilation targets
#   - Maximum portability requirements
#   - Older processors (pre-AVX2)
#
# SIMD Support: SSE4.2 only (widely supported since ~2008)
# Trade-off: Sacrifices performance for maximum compatibility

CPU_ARCH = generic

# Conservative optimization level
PROD_FLAGS = -O2

# Generic x86-64 baseline (no native optimizations)
# Using -march=x86-64-v2 for modern baseline (SSE4.2, SSSE3, CMPXCHG16B)
PROD_FLAGS += -march=x86-64-v2 -mtune=generic

# Explicitly enable only SSE4.2 (widely supported)
PROD_FLAGS += -msse4.2

# Explicitly disable advanced SIMD (for portability)
PROD_FLAGS += -mno-avx
PROD_FLAGS += -mno-avx2
PROD_FLAGS += -mno-avx512f

# Link-Time Optimization (compatible with most compilers)
PROD_FLAGS += -flto

# Conservative loop optimizations
PROD_FLAGS += -funroll-loops

# Basic code generation optimizations
PROD_FLAGS += -fomit-frame-pointer

# Ensure portable code generation
PROD_FLAGS += -fno-semantic-interposition

# Warning: This profile prioritizes compatibility over performance
# Expected performance: 40-60% of native-optimized builds

# Export for visibility
export GENERIC_FLAGS = $(PROD_FLAGS)
