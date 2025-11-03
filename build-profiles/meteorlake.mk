# Intel Meteor Lake Compiler Profile
# Optimized for Intel Core Ultra 7 165H and similar Meteor Lake processors
#
# Architecture: Intel Meteor Lake (Raptor Cove P-cores + Crestmont E-cores)
# SIMD Support: AVX2, AVX-VNNI, FMA3, AES-NI, SSE4.2
# Notable: AVX-512 support is now available on P-cores for Meteor Lake
PROD_FLAGS += -mavx512f         # AVX-512 Foundation
PROD_FLAGS += -mavx512vl        # AVX-512 Vector Length Extensions
PROD_FLAGS += -mavx512bw        # AVX-512 Byte and Word Instructions
PROD_FLAGS += -mavx512dq        # AVX-512 Doubleword and Quadword Instructions
PROD_FLAGS += -mavx512cd        # AVX-512 Conflict Detection Instructions
