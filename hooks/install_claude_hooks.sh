#!/bin/bash
# Create: install_claude_hooks.sh

set -e

CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Installing Claude Code hooks integration..."

# Create hooks directory structure
mkdir -p "$CLAUDE_HOOKS_DIR"/{pre-task,post-edit,post-task}

# Create pre-task hook
cat > "$CLAUDE_HOOKS_DIR/pre-task/validate_and_setup.sh" << 'EOF'
#!/bin/bash
# Pre-task hook for Claude Code

# Get the current task context from environment or args
TASK_CONTEXT="${CLAUDE_TASK_CONTEXT:-$1}"

# Call Python hook bridge
python3 /home/ubuntu/Documents/Claude/agents/claude_hooks_bridge.py \
  --phase pre-task \
  --context "$TASK_CONTEXT"

# Check validation result
if [ $? -ne 0 ]; then
  echo "❌ Pre-task validation failed"
  exit 1
fi

echo "✅ Pre-task hooks completed"
EOF

# Create post-edit hook
cat > "$CLAUDE_HOOKS_DIR/post-edit/process_changes.sh" << 'EOF'
#!/bin/bash
# Post-edit hook for Claude Code

# Get edited files from Claude Code
EDITED_FILES="${CLAUDE_EDITED_FILES:-$1}"

# Create context with file information
CONTEXT_FILE="/tmp/claude_edit_context_$$.json"
cat > "$CONTEXT_FILE" << EOJSON
{
  "edited_files": "$EDITED_FILES",
  "timestamp": "$(date -Iseconds)",
  "agent": "${CLAUDE_CURRENT_AGENT:-unknown}",
  "task_id": "${CLAUDE_TASK_ID:-$$}"
}
EOJSON

# Call Python hook bridge
python3 /home/ubuntu/Documents/Claude/agents/claude_hooks_bridge.py \
  --phase post-edit \
  --context "$CONTEXT_FILE"

echo "✅ Post-edit hooks completed"

# Cleanup
rm -f "$CONTEXT_FILE"
EOF

# Create post-task hook
cat > "$CLAUDE_HOOKS_DIR/post-task/cleanup_and_report.sh" << 'EOF'
#!/bin/bash
# Post-task hook for Claude Code

# Gather task completion data
TASK_RESULT="${CLAUDE_TASK_RESULT:-completed}"

# Create completion context
CONTEXT_FILE="/tmp/claude_task_context_$$.json"
cat > "$CONTEXT_FILE" << EOJSON
{
  "task_result": "$TASK_RESULT",
  "completion_time": "$(date -Iseconds)",
  "agent": "${CLAUDE_CURRENT_AGENT:-unknown}",
  "task_id": "${CLAUDE_TASK_ID:-$$}",
  "duration": "${CLAUDE_TASK_DURATION:-unknown}"
}
EOJSON

# Call Python hook bridge
python3 /home/ubuntu/Documents/Claude/agents/claude_hooks_bridge.py \
  --phase post-task \
  --context "$CONTEXT_FILE"

echo "✅ Post-task hooks completed"

# Cleanup
rm -f "$CONTEXT_FILE"
EOF

# Make all hooks executable
chmod +x "$CLAUDE_HOOKS_DIR"/*/**.sh

echo "✅ Claude hooks installed successfully"
echo "📍 Location: $CLAUDE_HOOKS_DIR"
