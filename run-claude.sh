#!/bin/bash
# Portable Claude runner for LiveCD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_BIN="${SCRIPT_DIR}/claude"

# Set up environment
export PATH="${SCRIPT_DIR}:${SCRIPT_DIR}/gh-cli:${PATH}"
export GH_CONFIG_DIR="${SCRIPT_DIR}/.config/gh"

# Create Claude config directory
export CLAUDE_HOME="${SCRIPT_DIR}/.claude-home"
export CLAUDE_CONFIG_DIR="${CLAUDE_HOME}/.config/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Link agents
ln -sf "${SCRIPT_DIR}/agents" "$CLAUDE_CONFIG_DIR/agents" 2>/dev/null

# Create alias for claude with permission skip
alias claude="${CLAUDE_BIN} --dangerously-skip-permissions"

echo "═══════════════════════════════════════════════════════════"
echo "     CLAUDE PORTABLE ENVIRONMENT (LiveCD Mode)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Claude CLI: ${CLAUDE_BIN}"
echo "Agents directory: ${SCRIPT_DIR}/agents"
echo "GitHub CLI: ${SCRIPT_DIR}/gh-cli/gh"
echo ""
echo "Environment configured for LiveCD:"
echo "  - Claude runs with --dangerously-skip-permissions"
echo "  - All data stored in: ${SCRIPT_DIR}"
echo "  - No system modifications"
echo ""

# Check if Claude binary exists
if [ -x "$CLAUDE_BIN" ]; then
    echo "Starting Claude in LiveCD mode..."
    echo "Running: claude --dangerously-skip-permissions $@"
    echo ""
    exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"
else
    echo "ERROR: Claude binary not found at $CLAUDE_BIN"
    echo "Starting shell with environment configured..."
    echo "You can manually run: ./claude --dangerously-skip-permission-check"
    exec bash
fi
