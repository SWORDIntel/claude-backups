#!/bin/bash
# Agent Registry Auto-Updater
# Runs every 5 minutes to keep agent registry up to date
# No hardcoded paths - dynamically finds script location

# Find the script directory (works with symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Find project root by looking for key markers
PROJECT_ROOT=""
CURRENT_DIR="$SCRIPT_DIR"
for i in {1..10}; do
    if [[ -d "$CURRENT_DIR/agents" && (-f "$CURRENT_DIR/README.md" || -f "$CURRENT_DIR/CLAUDE.md") ]]; then
        PROJECT_ROOT="$CURRENT_DIR"
        break
    fi
    PARENT_DIR="$(dirname "$CURRENT_DIR")"
    if [[ "$PARENT_DIR" == "$CURRENT_DIR" ]]; then
        break
    fi
    CURRENT_DIR="$PARENT_DIR"
done

# Fallback to script directory parent if not found
if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Set environment variable for the registration script
export CLAUDE_AGENTS_ROOT="$PROJECT_ROOT/agents"

# Run the registration script (suppress output for cron)
REGISTER_SCRIPT="$PROJECT_ROOT/tools/register-custom-agents.py"

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/logs" 2>/dev/null || true

if [[ -f "$REGISTER_SCRIPT" ]]; then
    # Change to project directory before running
    cd "$PROJECT_ROOT" || exit 1
    
    python3 "$REGISTER_SCRIPT" > /dev/null 2>&1
    EXIT_CODE=$?
    
    # Only log if there's an error
    if [[ $EXIT_CODE -ne 0 ]]; then
        echo "$(date): Agent registration failed with exit code $EXIT_CODE" >> "$PROJECT_ROOT/logs/agent-registry.log" 2>/dev/null || true
    fi
else
    echo "$(date): Registration script not found at $REGISTER_SCRIPT" >> "$PROJECT_ROOT/logs/agent-registry.log" 2>/dev/null || true
fi