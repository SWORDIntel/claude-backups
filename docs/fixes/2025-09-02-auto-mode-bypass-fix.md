# AUTO_MODE Bypass Bug Fix

**Date**: 2025-09-02  
**Issue**: Installer getting stuck in infinite loop despite AUTO_MODE=true  
**Status**: ✅ RESOLVED  

## Problem Description

The claude-installer.sh was getting stuck in an infinite loop when run with `AUTO_MODE=true ./claude-installer.sh`, specifically in the `choose_database_deployment()` function. The installer would still prompt for deployment method selection despite AUTO_MODE being enabled.

## Root Cause Analysis

The bug was in the `parse_arguments()` function. When AUTO_MODE was set as an environment variable (e.g., `AUTO_MODE=true ./script.sh`), the function would:

1. Initialize `AUTO_MODE=false` (line 4056)  
2. Only set `AUTO_MODE=true` if the `--auto` command flag was passed
3. Ignore the environment variable entirely

This meant `AUTO_MODE=true ./claude-installer.sh` would not work, only `./claude-installer.sh --auto` would work.

## Solution Implemented

### 1. Environment Variable Recognition Fix
**File**: `claude-installer.sh`  
**Line**: 4057  

**Before**:
```bash
AUTO_MODE=false
```

**After**:
```bash
# Check environment variable first, then default to false
AUTO_MODE="${AUTO_MODE:-false}"
```

This change uses bash parameter expansion to check if AUTO_MODE is already set as an environment variable before defaulting to false.

### 2. Enhanced Debugging
**File**: `claude-installer.sh`  
**Line**: 1575  

Added debug message to clearly show when AUTO_MODE is detected:
```bash
if [[ "$AUTO_MODE" == "true" ]]; then
    info "Auto-mode detected: AUTO_MODE=$AUTO_MODE"
    # ... rest of function
```

### 3. Infinite Loop Prevention
**File**: `claude-installer.sh`  
**Lines**: 1606-1654  

Added multiple safety mechanisms to prevent infinite loops in interactive mode:

#### Timeout Mechanism
```bash
# Timeout mechanism to prevent infinite loops
if ! read -r -t 30 choice; then
    warning "Input timeout. Defaulting to Docker deployment."
    export DATABASE_DEPLOYMENT_METHOD="docker"
    return 0
fi
```

#### Attempt Counter with Fallback
```bash
local attempt_count=0
local max_attempts=5

# Inside the loop:
((attempt_count++))
warning "Invalid choice. Please select 1, 2, or 3."

# Safety mechanism: default to Docker after multiple failed attempts
if [[ $attempt_count -ge $max_attempts ]]; then
    warning "Too many invalid attempts. Defaulting to Docker deployment."
    if [[ "$DOCKER_AVAILABLE" == "true" ]] && [[ "$COMPOSE_AVAILABLE" == "true" ]]; then
        export DATABASE_DEPLOYMENT_METHOD="docker"
    else
        export DATABASE_DEPLOYMENT_METHOD="native"
    fi
    return 0
fi
```

## Testing Results

Comprehensive testing confirmed all fixes work correctly:

✅ **Environment Variable**: `AUTO_MODE=true ./claude-installer.sh` now works  
✅ **Command Flag**: `./claude-installer.sh --auto` continues to work  
✅ **Default Behavior**: Interactive mode when no AUTO_MODE specified  
✅ **Timeout Protection**: 30-second timeout prevents hanging  
✅ **Attempt Limit**: 5 failed attempts trigger automatic fallback  

## Impact

- **Resolves Critical Bug**: Eliminates infinite loop in automated installations
- **Maintains Compatibility**: All existing usage patterns continue to work
- **Enhances Reliability**: Multiple fallback mechanisms prevent hanging
- **Improves User Experience**: Clear debug messages show AUTO_MODE status

## Usage Examples

Both of these now work correctly:

```bash
# Environment variable method (now fixed)
AUTO_MODE=true ./claude-installer.sh

# Command flag method (always worked)
./claude-installer.sh --auto
```

## Files Modified

1. `claude-installer.sh` - Main installer script
   - Fixed environment variable recognition
   - Added debugging messages  
   - Implemented infinite loop protection
2. `docs/fixes/2025-09-02-auto-mode-bypass-fix.md` - This documentation

## Verification Commands

```bash
# Test environment variable method
AUTO_MODE=true ./claude-installer.sh --dry-run

# Test command flag method  
./claude-installer.sh --auto --dry-run

# Test interactive mode (should not hang)
./claude-installer.sh --dry-run
```

---

**Status**: Production ready - deployed and tested  
**Breaking Changes**: None  
**Backward Compatibility**: 100% maintained