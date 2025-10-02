# Deprecated Shadowgit Python Files

The following files have syntax errors and are **not currently used** in the reorganized codebase.
They appear to be incomplete development files from earlier phases.

## Files Marked as Deprecated

### 1. accelerator.py
- **Status**: Incomplete / Has syntax error at line 67
- **Size**: 813 lines
- **Error**: `sys.path.insert` missing closing paren
- **Usage**: NOT imported anywhere in current codebase
- **Recommendation**: Fix or remove. Functionality replaced by:
  - `shadowgit_avx2.py` (NEW - working)
  - `neural_accelerator.py` (working)
  - `phase3_unified.py` (working)

### 2. legacy_accelerator.py
- **Status**: Duplicate of accelerator.py with same syntax error
- **Size**: 824 lines
- **Error**: Same as accelerator.py (line 65)
- **Usage**: NOT imported anywhere
- **Recommendation**: Delete (duplicate of broken file)

## Impact Analysis

**Current Import Usage:**
```bash
$ grep -r "from.*accelerator import" . --include="*.py"
# Result: ZERO imports (only neural_accelerator is used)
```

**Working Alternatives:**
- ✅ `shadowgit_avx2.py` - NEW unified AVX2 module (348 lines, working)
- ✅ `neural_accelerator.py` - Neural acceleration (working)
- ✅ `phase3_unified.py` - Phase 3 system (working)

## Recommendation

Since these files are:
1. Not imported anywhere in the codebase
2. Have syntax errors (incomplete)
3. Functionality is covered by other working modules

**Action**: Mark as deprecated stubs or move to archive/

**If needed in future**: Fix syntax errors and complete implementation, but current system works without them.

---

**Date**: October 2, 2025
**Status**: Safe to ignore - no impact on production functionality
