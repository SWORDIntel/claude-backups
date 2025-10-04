# Generic AVX2 Compiler Profile
# Optimized for modern Intel and AMD processors with AVX2 support
#
# Compatible with:
#   - Intel: Haswell, Broadwell, Skylake, Kaby Lake, Coffee Lake,
#            Comet Lake, Ice Lake, Tiger Lake, Alder Lake, Raptor Lake
#   - AMD: Zen, Zen+, Zen 2, Zen 3, Zen 4
# SIMD Support: AVX2, FMA3, AES-NI, SSE4.2

CPU_ARCH = avx2

# Base optimization level
PROD_FLAGS = -O2

# Architecture-specific tuning
# -march=native may include AVX-512 on capable CPUs
# We explicitly disable AVX-512 for this profile
PROD_FLAGS += -march=native -mtune=native

# Explicitly enable AVX2 (baseline for this profile)
PROD_FLAGS += -mavx2          # AVX2 256-bit SIMD
PROD_FLAGS += -mfma           # Fused Multiply-Add (FMA3)
PROD_FLAGS += -maes           # AES-NI hardware acceleration
PROD_FLAGS += -msse4.2        # SSE 4.2

# Explicitly disable AVX-512 (for compatibility)
PROD_FLAGS += -mno-avx512f

# Link-Time Optimization
PROD_FLAGS += -flto=thin

# Loop and function optimizations
PROD_FLAGS += -funroll-loops
PROD_FLAGS += -finline-functions

# Code generation optimizations
PROD_FLAGS += -fomit-frame-pointer
PROD_FLAGS += -fno-semantic-interposition

# Export for visibility
export AVX2_FLAGS = $(PROD_FLAGS)
