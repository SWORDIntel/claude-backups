"""
ShadowGit Python Package

High-performance Git analysis with NPU/AVX2 acceleration.

Modules:
- integration_hub: Python-C bridge and coordination
- phase3_unified: Core Git intelligence engine
- shadowgit_avx2: NPU/AVX2 optimized operations
- neural_accelerator: ML acceleration utilities
- performance_integration: Metrics and monitoring
"""

from .integration_hub import *
from .phase3_unified import Phase3Unified
from .shadowgit_avx2 import ShadowGitAVX2

__all__ = [
    "Phase3Unified",
    "ShadowGitAVX2",
]
