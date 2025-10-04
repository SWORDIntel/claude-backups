# Intel Meteor Lake Compiler Profile
# Optimized for Intel Core Ultra 7 165H and similar Meteor Lake processors
#
# Architecture: Intel Meteor Lake (Raptor Cove P-cores + Crestmont E-cores)
# SIMD Support: AVX2, AVX-VNNI, FMA3, AES-NI, SSE4.2
# Notable: NO AVX-512 support (removed from Meteor Lake architecture)

CPU_ARCH = meteorlake

# Base optimization level (-O2 for production stability)
# -O2 provides excellent performance without aggressive optimizations that can cause issues
PROD_FLAGS = -O2

# Architecture-specific tuning
# -march=native: Use all instructions available on build machine
# -mtune=native: Optimize instruction scheduling for build machine
PROD_FLAGS += -march=native -mtune=native

# SIMD Extensions (explicitly enabled for Meteor Lake)
PROD_FLAGS += -mavx2          # AVX2 256-bit SIMD
PROD_FLAGS += -mfma           # Fused Multiply-Add (FMA3)
PROD_FLAGS += -mavx-vnni      # AVX-VNNI for AI/ML workloads
PROD_FLAGS += -maes           # AES-NI hardware acceleration
PROD_FLAGS += -msse4.2        # SSE 4.2 (baseline)

# Link-Time Optimization
# -flto=thin: Fast incremental LTO (LLVM/Clang compatible)
PROD_FLAGS += -flto=thin

# Loop and function optimizations
PROD_FLAGS += -funroll-loops       # Unroll loops for better performance
PROD_FLAGS += -finline-functions   # Aggressive function inlining

# Code generation optimizations
PROD_FLAGS += -fomit-frame-pointer # Remove frame pointer (more registers)

# Intel-specific optimizations
PROD_FLAGS += -fno-semantic-interposition  # Better optimization across DSOs

# NOT INCLUDED (reasons documented):
# -ffast-math          : Can break IEEE 754 compliance and cause precision issues
# -mavx512f            : Not supported on Meteor Lake
# -O3                  : Can cause code bloat and cache issues
# -funroll-all-loops   : Can cause excessive code size

# Export for visibility
export METEORLAKE_FLAGS = $(PROD_FLAGS)
