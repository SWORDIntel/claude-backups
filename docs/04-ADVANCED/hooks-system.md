# Claude Hooks System Documentation

## 🪝 Overview

The Claude Hooks System allows users to configure shell commands that execute automatically in response to events like tool calls. Hooks provide powerful automation and customization capabilities for the Claude Agent Framework.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Tool Call   │────▶│ Hook Trigger │────▶│   Execute    │
│   (Event)    │     │   Matching   │     │   Command    │
└──────────────┘     └──────────────┘     └──────────────┘
                             │
                             ▼
                     ┌──────────────┐
                     │ Hook Config  │
                     │   ~/.claude  │
                     └──────────────┘
```

## Hook Types

### 1. Pre-Execution Hooks
Execute before a tool/agent runs:
```bash
# ~/.claude/hooks/pre-execution
#!/bin/bash
echo "About to execute: $CLAUDE_TOOL_NAME with args: $CLAUDE_TOOL_ARGS"
logger -t claude "Pre-execution: $CLAUDE_TOOL_NAME"
```

### 2. Post-Execution Hooks
Execute after a tool/agent completes:
```bash
# ~/.claude/hooks/post-execution
#!/bin/bash
echo "Completed: $CLAUDE_TOOL_NAME with exit code: $CLAUDE_EXIT_CODE"
if [ $CLAUDE_EXIT_CODE -ne 0 ]; then
    notify-send "Claude Error" "Tool $CLAUDE_TOOL_NAME failed"
fi
```

### 3. Tool-Specific Hooks
Execute for specific tools only:
```bash
# ~/.claude/hooks/tool-write
#!/bin/bash
# Triggered only for Write tool
echo "File written: $CLAUDE_FILE_PATH"
git add "$CLAUDE_FILE_PATH"
git commit -m "Auto-commit: Modified $CLAUDE_FILE_PATH"
```

### 4. Agent-Specific Hooks
Execute for specific agents:
```bash
# ~/.claude/hooks/agent-security
#!/bin/bash
# Triggered when security agent runs
echo "Security scan initiated at $(date)"
echo "$CLAUDE_AGENT_ARGS" >> ~/.claude/security-audit.log
```

### 5. Error Hooks
Execute on errors:
```bash
# ~/.claude/hooks/on-error
#!/bin/bash
echo "Error occurred: $CLAUDE_ERROR_MESSAGE"
echo "Tool: $CLAUDE_TOOL_NAME"
echo "Time: $(date)" >> ~/.claude/error.log
```

### 6. User Prompt Submit Hook
Execute when user submits a prompt:
```bash
# ~/.claude/hooks/user-prompt-submit
#!/bin/bash
echo "User prompt: $CLAUDE_USER_PROMPT"
# Log all prompts for audit
echo "$(date): $CLAUDE_USER_PROMPT" >> ~/.claude/prompt-history.log
```

## Configuration

### 1. Hook Directory Structure
```
~/.claude/
├── hooks/
│   ├── pre-execution
│   ├── post-execution
│   ├── on-error
│   ├── user-prompt-submit
│   ├── tool-write
│   ├── tool-read
│   ├── tool-edit
│   ├── tool-bash
│   ├── agent-security
│   ├── agent-director
│   └── agent-*
├── hooks.conf
└── hooks.log
```

### 2. Hooks Configuration File
Create `~/.claude/hooks.conf`:
```ini
[Global]
enabled = true
log_level = info
timeout = 30

[PreExecution]
enabled = true
script = ~/.claude/hooks/pre-execution
async = false

[PostExecution]
enabled = true
script = ~/.claude/hooks/post-execution
async = true

[ToolHooks]
write = ~/.claude/hooks/tool-write
read = ~/.claude/hooks/tool-read
edit = ~/.claude/hooks/tool-edit
bash = ~/.claude/hooks/tool-bash

[AgentHooks]
security = ~/.claude/hooks/agent-security
director = ~/.claude/hooks/agent-director
optimizer = ~/.claude/hooks/agent-optimizer

[ErrorHandling]
on_error = ~/.claude/hooks/on-error
on_timeout = ~/.claude/hooks/on-timeout
retry_count = 3
```

### 3. Environment Variables in Hooks

Hooks receive these environment variables:

```bash
# Tool Information
CLAUDE_TOOL_NAME        # Name of the tool being executed
CLAUDE_TOOL_ARGS        # Arguments passed to the tool
CLAUDE_TOOL_ID          # Unique execution ID

# Agent Information  
CLAUDE_AGENT_NAME       # Name of the agent (if applicable)
CLAUDE_AGENT_ARGS       # Agent arguments
CLAUDE_AGENT_CATEGORY   # Agent category

# File Operations
CLAUDE_FILE_PATH        # Path of file being operated on
CLAUDE_FILE_CONTENT     # Content (for write operations)
CLAUDE_FILE_OLD_CONTENT # Previous content (for edit)

# Execution Context
CLAUDE_USER_PROMPT      # Original user prompt
CLAUDE_WORKING_DIR      # Current working directory
CLAUDE_SESSION_ID       # Current session ID
CLAUDE_TIMESTAMP        # Execution timestamp

# Results
CLAUDE_EXIT_CODE        # Exit code of tool/agent
CLAUDE_OUTPUT           # Output from execution
CLAUDE_ERROR_MESSAGE    # Error message (if any)
```

## Examples

### Example 1: Git Auto-Commit Hook
```bash
#!/bin/bash
# ~/.claude/hooks/tool-write
# Auto-commit files modified by Claude

if [[ "$CLAUDE_TOOL_NAME" == "Write" ]] || [[ "$CLAUDE_TOOL_NAME" == "Edit" ]]; then
    FILE="$CLAUDE_FILE_PATH"
    
    # Check if file is in a git repository
    if git -C "$(dirname "$FILE")" rev-parse --git-dir > /dev/null 2>&1; then
        git -C "$(dirname "$FILE")" add "$FILE"
        git -C "$(dirname "$FILE")" commit -m "Claude: Modified $(basename "$FILE")" || true
        echo "Auto-committed: $FILE"
    fi
fi
```

### Example 2: Security Audit Hook
```bash
#!/bin/bash
# ~/.claude/hooks/agent-security
# Log all security agent activities

LOG_FILE="$HOME/.claude/security-audit.log"
echo "=== Security Scan: $(date) ===" >> "$LOG_FILE"
echo "Agent: $CLAUDE_AGENT_NAME" >> "$LOG_FILE"
echo "Arguments: $CLAUDE_AGENT_ARGS" >> "$LOG_FILE"
echo "User: $USER" >> "$LOG_FILE"
echo "Directory: $CLAUDE_WORKING_DIR" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

# Send notification
notify-send "Security Scan" "Running security analysis..."
```

### Example 3: Performance Monitoring Hook
```bash
#!/bin/bash
# ~/.claude/hooks/pre-execution
# Monitor performance of operations

START_TIME=$(date +%s%N)
echo "$START_TIME" > /tmp/claude-start-time-$CLAUDE_TOOL_ID

# Log to metrics file
echo "$(date),START,$CLAUDE_TOOL_NAME,$CLAUDE_TOOL_ID" >> ~/.claude/metrics.csv
```

```bash
#!/bin/bash
# ~/.claude/hooks/post-execution
# Calculate execution time

if [ -f /tmp/claude-start-time-$CLAUDE_TOOL_ID ]; then
    START_TIME=$(cat /tmp/claude-start-time-$CLAUDE_TOOL_ID)
    END_TIME=$(date +%s%N)
    DURATION=$((($END_TIME - $START_TIME) / 1000000)) # Convert to milliseconds
    
    echo "$(date),END,$CLAUDE_TOOL_NAME,$CLAUDE_TOOL_ID,$DURATION,$CLAUDE_EXIT_CODE" >> ~/.claude/metrics.csv
    rm /tmp/claude-start-time-$CLAUDE_TOOL_ID
    
    # Alert if operation took too long
    if [ $DURATION -gt 5000 ]; then
        echo "Warning: $CLAUDE_TOOL_NAME took ${DURATION}ms"
    fi
fi
```

### Example 4: Backup Hook
```bash
#!/bin/bash
# ~/.claude/hooks/tool-edit
# Backup files before editing

if [[ "$CLAUDE_TOOL_NAME" == "Edit" ]]; then
    BACKUP_DIR="$HOME/.claude/backups/$(date +%Y%m%d)"
    mkdir -p "$BACKUP_DIR"
    
    FILE="$CLAUDE_FILE_PATH"
    BACKUP="$BACKUP_DIR/$(basename "$FILE").$(date +%H%M%S).bak"
    
    cp "$FILE" "$BACKUP"
    echo "Backed up to: $BACKUP"
fi
```

### Example 5: Notification Hook
```bash
#!/bin/bash
# ~/.claude/hooks/on-error
# Send notifications on errors

ERROR_MSG="$CLAUDE_ERROR_MESSAGE"
TOOL="$CLAUDE_TOOL_NAME"

# Desktop notification
notify-send -u critical "Claude Error" "$TOOL failed: $ERROR_MSG"

# Log to system journal
logger -t claude-error "Tool $TOOL failed: $ERROR_MSG"

# Send email (if configured)
if [ -n "$CLAUDE_ERROR_EMAIL" ]; then
    echo "Error in $TOOL: $ERROR_MSG" | mail -s "Claude Error" "$CLAUDE_ERROR_EMAIL"
fi
```

## Advanced Features

### 1. Conditional Hooks
```bash
#!/bin/bash
# Execute only for specific conditions

# Only for Python files
if [[ "$CLAUDE_FILE_PATH" == *.py ]]; then
    pylint "$CLAUDE_FILE_PATH"
fi

# Only for specific directories
if [[ "$CLAUDE_WORKING_DIR" == */production/* ]]; then
    echo "WARNING: Operating in production directory!"
    read -p "Continue? (y/n): " -n 1 -r
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi
```

### 2. Chained Hooks
```bash
#!/bin/bash
# ~/.claude/hooks/chain-controller

# Execute multiple hooks in sequence
~/.claude/hooks/pre-validation
[ $? -ne 0 ] && exit 1

~/.claude/hooks/pre-backup
[ $? -ne 0 ] && exit 1

~/.claude/hooks/pre-execution-main
```

### 3. Async Hooks
```bash
#!/bin/bash
# Run hook in background

{
    # Long-running operation
    sleep 5
    curl -X POST https://api.example.com/claude-webhook \
        -H "Content-Type: application/json" \
        -d "{\"tool\":\"$CLAUDE_TOOL_NAME\",\"status\":\"completed\"}"
} &

# Don't wait for completion
exit 0
```

### 4. Hook Templates
```bash
#!/bin/bash
# ~/.claude/hooks/template

# Source common functions
source ~/.claude/hooks/common.sh

# Standard logging
log_operation() {
    echo "[$(date)] $1" >> ~/.claude/hooks.log
}

# Main hook logic
main() {
    log_operation "Hook triggered: $CLAUDE_TOOL_NAME"
    
    case "$CLAUDE_TOOL_NAME" in
        Write|Edit)
            handle_file_operation
            ;;
        Bash)
            handle_command_execution
            ;;
        *)
            handle_generic
            ;;
    esac
}

main "$@"
```

## Blocking and Non-Blocking Hooks

### Blocking Hooks
Can prevent operations:
```bash
#!/bin/bash
# ~/.claude/hooks/pre-execution

# Block dangerous operations
if [[ "$CLAUDE_TOOL_NAME" == "Bash" ]] && [[ "$CLAUDE_TOOL_ARGS" == *"rm -rf"* ]]; then
    echo "BLOCKED: Dangerous command detected"
    exit 1  # Non-zero exit blocks execution
fi

exit 0  # Allow execution
```

### Non-Blocking Hooks
Run alongside operations:
```bash
#!/bin/bash
# ~/.claude/hooks/post-execution

# Log without blocking
{
    echo "$(date): $CLAUDE_TOOL_NAME completed" >> ~/.claude/activity.log
} &

exit 0
```

## Hook Management

### Enable/Disable Hooks
```bash
# Disable all hooks temporarily
export CLAUDE_HOOKS_ENABLED=false

# Disable specific hook
chmod -x ~/.claude/hooks/pre-execution

# Re-enable
chmod +x ~/.claude/hooks/pre-execution
export CLAUDE_HOOKS_ENABLED=true
```

### Test Hooks
```bash
#!/bin/bash
# Test hook execution

# Set test environment
export CLAUDE_TOOL_NAME="Test"
export CLAUDE_TOOL_ARGS="test arguments"
export CLAUDE_FILE_PATH="/tmp/test.txt"

# Execute hook
~/.claude/hooks/pre-execution

# Check result
echo "Hook exit code: $?"
```

### Debug Hooks
```bash
#!/bin/bash
# Enable debug output in hooks

set -x  # Enable debug
exec 2>> ~/.claude/hooks-debug.log  # Redirect stderr to log

echo "Debug: Tool=$CLAUDE_TOOL_NAME"
echo "Debug: Args=$CLAUDE_TOOL_ARGS"
# ... rest of hook logic
```

## Security Considerations

### 1. Validate Input
```bash
# Sanitize file paths
FILE=$(realpath "$CLAUDE_FILE_PATH" 2>/dev/null)
if [[ ! "$FILE" =~ ^/home/$USER/ ]]; then
    echo "Security: Operating outside user home denied"
    exit 1
fi
```

### 2. Restrict Permissions
```bash
# Set secure permissions
chmod 700 ~/.claude/hooks/
chmod 600 ~/.claude/hooks/*
```

### 3. Audit Logging
```bash
# Log all hook executions
echo "$(date)|$USER|$CLAUDE_TOOL_NAME|$CLAUDE_TOOL_ARGS" >> /var/log/claude-hooks.log
```

## Troubleshooting

### Hook Not Executing
```bash
# Check permissions
ls -la ~/.claude/hooks/

# Check if enabled
echo $CLAUDE_HOOKS_ENABLED

# Test manually
CLAUDE_TOOL_NAME=test ~/.claude/hooks/pre-execution
```

### Hook Timing Out
```bash
# Add timeout to hook
#!/bin/bash
timeout 10 your-long-running-command || exit 1
```

### Debug Hook Issues
```bash
# Enable verbose logging
export CLAUDE_HOOK_DEBUG=true

# Check hook logs
tail -f ~/.claude/hooks.log
tail -f ~/.claude/hooks-debug.log
```

## Best Practices

1. **Keep hooks fast** - Long-running hooks slow down operations
2. **Handle errors gracefully** - Don't break Claude's operation
3. **Log important events** - Maintain audit trail
4. **Test thoroughly** - Verify hooks work as expected
5. **Use async for long operations** - Don't block Claude
6. **Validate input** - Sanitize all variables
7. **Document your hooks** - Add comments explaining purpose

---
*Hooks System Documentation v1.0 | Framework v7.0*