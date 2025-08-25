# Bash Output Fix for claude-wrapper-ultimate.sh

## Problem Identified

The `claude-wrapper-ultimate.sh` script was causing a complete lack of bash output when using the `claude` command due to two main issues:

### 1. Aggressive Output Suppression (Lines 25-30)
```bash
# Original problematic code:
export CLAUDE_QUIET_MODE=true
export CLAUDE_SUPPRESS_BANNER=true
export NO_AGENT_BRIDGE_HEADER=true
export CLAUDE_BRIDGE_QUIET=true
export DISABLE_AGENT_BRIDGE=true
```

These environment variables were globally suppressing ALL output from claude and child processes, including bash command output.

### 2. Use of `exec` Command (Lines 346, 350, 355)
```bash
# Original problematic code:
exec "$claude_binary" "${args[@]}" 2>&1
exec node "$claude_binary" "${args[@]}" 2>&1
exec npx @anthropic-ai/claude-code "${args[@]}" 2>&1
```

The `exec` command replaces the current shell process entirely, which can interfere with output handling and prevent proper output capture.

## Solution Applied

### Fix 1: Made Output Control Configurable
```bash
# Fixed code:
if [[ "${CLAUDE_FORCE_QUIET:-false}" == "true" ]]; then
    # Only suppress if explicitly requested
    export CLAUDE_QUIET_MODE=true
    export CLAUDE_SUPPRESS_BANNER=true
    export NO_AGENT_BRIDGE_HEADER=true
    export CLAUDE_BRIDGE_QUIET=true
    export DISABLE_AGENT_BRIDGE=true
else
    # Default: Allow normal output
    export CLAUDE_QUIET_MODE=false
    export CLAUDE_SUPPRESS_BANNER=false
    export NO_AGENT_BRIDGE_HEADER=true  # Keep this to reduce verbosity
    export CLAUDE_BRIDGE_QUIET=false
    export DISABLE_AGENT_BRIDGE=false
fi
```

**Key Changes:**
- Output suppression is now OFF by default
- Users can explicitly enable quiet mode with `CLAUDE_FORCE_QUIET=true`
- Maintains header suppression to reduce verbosity while allowing actual output

### Fix 2: Removed `exec` Commands
```bash
# Fixed code:
# Method 1: Try direct execution
if [[ -x "$claude_binary" ]]; then
    "$claude_binary" "${args[@]}"
    return $?
fi

# Method 2: Try with node
if command_exists node; then
    node "$claude_binary" "${args[@]}"
    return $?
fi

# Method 3: Try with npx
if command_exists npx; then
    npx @anthropic-ai/claude-code "${args[@]}"
    return $?
fi
```

**Key Changes:**
- Removed `exec` which was replacing the shell process
- Normal execution preserves output handling
- Added explicit `return $?` to propagate exit codes
- Removed `2>&1` redirection to allow stderr to remain separate

## Usage

### Normal Usage (Output Enabled)
```bash
# Default behavior - bash output will work
claude /task "run some bash commands"
```

### Force Quiet Mode (If Needed)
```bash
# Explicitly suppress output if desired
CLAUDE_FORCE_QUIET=true claude /task "run quietly"

# Or export for session
export CLAUDE_FORCE_QUIET=true
```

### Check Current Mode
```bash
# View current output control status
claude --status
```

## Files Modified

1. **claude-wrapper-ultimate.sh** - Applied fixes directly
2. **claude-wrapper-fixed.sh** - Complete fixed version for reference
3. **fix-bash-output.patch** - Patch file showing exact changes
4. **test-bash-output.sh** - Test script to verify the fix

## Testing

After applying the fix, bash commands executed through claude should produce visible output:

```bash
# This should now show output
claude /task "ls -la"
claude /task "echo 'Hello World'"
claude /task "date"
```

## Rollback

If you need to revert to the original behavior:
```bash
# Set environment variable to force quiet mode
export CLAUDE_FORCE_QUIET=true
```

Or restore the original script from backup if needed.