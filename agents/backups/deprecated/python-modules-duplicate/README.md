# Python Modules - Deprecated Duplicate

**Date Deprecated**: 2025-08-16  
**Reason**: Duplicate of `src/python/` - consolidated into unified structure  
**Status**: DEPRECATED - DO NOT USE

## Background

This directory contained duplicate Python files that were also present in `src/python/`. As part of the Python bridge unification project, all functionality has been consolidated into `src/python/` as the single source of truth.

## Files Moved

- `ENHANCED_AGENT_INTEGRATION.py` → `src/python/ENHANCED_AGENT_INTEGRATION.py`
- `ENHANCED_AGENT_INTEGRATION.py.optimizer_backup` → (backup, not needed)
- `async_io_optimizer.py` → `src/python/async_io_optimizer.py`
- `intelligent_cache.py` → `src/python/intelligent_cache.py`
- `meteor_lake_parallel.py` → `src/python/meteor_lake_parallel.py`
- `optimized_algorithms.py` → `src/python/optimized_algorithms.py`

## Migration

**Old Path**: `/home/ubuntu/Documents/Claude/agents/python-modules/`  
**New Path**: `/home/ubuntu/Documents/Claude/agents/src/python/`

All imports and references have been updated to use the new unified structure.

## Cleanup

This directory can be safely deleted once you confirm no external scripts reference these old paths.

**Use `src/python/` instead!**