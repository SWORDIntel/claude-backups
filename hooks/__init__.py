"""
Hooks Module - Compatibility Layer
====================================

Provides backward compatibility for relocated modules during repository reorganization.
This module ensures existing imports continue to work while we transition to the new structure.

New Structure:
- hooks/crypto-pow/     - Cryptographic proof-of-work system
- hooks/shadowgit/      - Neural-accelerated git monitoring
"""

import sys
import warnings
from pathlib import Path

# Get hooks directory
HOOKS_DIR = Path(__file__).parent
PROJECT_ROOT = HOOKS_DIR.parent

# Add new module locations to sys.path for imports
SHADOWGIT_PYTHON = HOOKS_DIR / "shadowgit" / "python"
CRYPTO_POW_DIR = HOOKS_DIR / "crypto-pow"

if SHADOWGIT_PYTHON.exists():
    if str(SHADOWGIT_PYTHON) not in sys.path:
        sys.path.insert(0, str(SHADOWGIT_PYTHON))

if CRYPTO_POW_DIR.exists():
    if str(CRYPTO_POW_DIR) not in sys.path:
        sys.path.insert(0, str(CRYPTO_POW_DIR))


# Deprecation warning helper
def _warn_deprecated_import(old_module: str, new_module: str):
    """Warn about deprecated import paths."""
    warnings.warn(
        f"Importing '{old_module}' from old location is deprecated. "
        f"Please update to: from {new_module}",
        DeprecationWarning,
        stacklevel=4,
    )


# Re-export relocated modules for compatibility (lazy loading)
__all__ = [
    "get_shadowgit_root",
    "get_crypto_pow_root",
]


def get_shadowgit_root() -> Path:
    """Get shadowgit module root directory."""
    return (
        SHADOWGIT_PYTHON.parent
        if SHADOWGIT_PYTHON.exists()
        else PROJECT_ROOT / "shadowgit"
    )


def get_crypto_pow_root() -> Path:
    """Get crypto POW module root directory."""
    return CRYPTO_POW_DIR if CRYPTO_POW_DIR.exists() else PROJECT_ROOT / "crypto"
