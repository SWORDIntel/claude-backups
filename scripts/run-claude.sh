#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# PORTABLE CLAUDE RUNNER FOR LIVECD - FIXED VERSION
# Self-contained launcher that works from any directory
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Check multiple possible Claude locations
CLAUDE_SEARCH_PATHS=(
    "${SCRIPT_DIR}/claude"
    "${SCRIPT_DIR}/claude-actual"
    "${SCRIPT_DIR}/.local/bin/claude"
    "${SCRIPT_DIR}/.local/bin/claude.original"
    "$HOME/.local/bin/claude"
    "$HOME/.local/bin/claude.original"
    "$HOME/.local/npm-global/bin/claude"
    "$(which claude 2>/dev/null || echo '')"
)

# Function to find Claude binary
find_claude_binary() {
    for path in "${CLAUDE_SEARCH_PATHS[@]}"; do
        if [ -n "$path" ] && [ -f "$path" ] && [ -x "$path" ]; then
            # Make sure it's not this script itself
            if [ "$(realpath "$path" 2>/dev/null)" != "$(realpath "$0" 2>/dev/null)" ]; then
                echo "$path"
                return 0
            fi
        fi
    done
    return 1
}

# Function to install Claude if missing
install_claude_minimal() {
    echo -e "${YELLOW}Claude not found. Installing...${NC}"
    
    local INSTALL_DIR="${SCRIPT_DIR}/.local"
    mkdir -p "$INSTALL_DIR/bin"
    
    # Check for the full installer
    if [ -f "${SCRIPT_DIR}/paste.txt" ]; then
        echo -e "${CYAN}Running full installer...${NC}"
        bash "${SCRIPT_DIR}/paste.txt" --auto-mode --local --force
    elif [ -f "${SCRIPT_DIR}/install-claude.sh" ]; then
        echo -e "${CYAN}Running installer...${NC}"
        bash "${SCRIPT_DIR}/install-claude.sh" --auto-mode --local
    else
        echo -e "${YELLOW}No installer found. Creating minimal stub...${NC}"
        
        # Create a minimal Python stub
        cat > "$INSTALL_DIR/bin/claude" << 'EOF'
#!/usr/bin/env python3
import sys
import os

print("Claude Code Stub - LiveCD Edition")
print("Arguments:", sys.argv[1:])
print("\nThis is a placeholder. Install the official Claude Code:")
print("  npm install -g @anthropic-ai/claude-code")
print("  or")
print("  pip install claude-code")
EOF
        chmod +x "$INSTALL_DIR/bin/claude"
        CLAUDE_BIN="$INSTALL_DIR/bin/claude"
    fi
}

# Main execution
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}     CLAUDE PORTABLE ENVIRONMENT (LiveCD Mode)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# Find Claude binary
CLAUDE_BIN=$(find_claude_binary || echo "")

if [ -z "$CLAUDE_BIN" ]; then
    echo -e "${RED}✗ Claude binary not found${NC}"
    echo
    echo -n "Would you like to install Claude now? (Y/n): "
    read -r response
    
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        install_claude_minimal
        CLAUDE_BIN=$(find_claude_binary || echo "")
    fi
    
    if [ -z "$CLAUDE_BIN" ]; then
        echo -e "${RED}ERROR: Could not install Claude${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Claude found:${NC} $CLAUDE_BIN"

# Set up environment
export PATH="${SCRIPT_DIR}:${SCRIPT_DIR}/gh-cli:${SCRIPT_DIR}/.local/bin:${PATH}"

# GitHub CLI config
if [ -d "${SCRIPT_DIR}/gh-cli" ]; then
    export GH_CONFIG_DIR="${SCRIPT_DIR}/.config/gh"
    echo -e "${GREEN}✓ GitHub CLI:${NC} ${SCRIPT_DIR}/gh-cli/gh"
fi

# Claude home directory (portable)
export CLAUDE_HOME="${SCRIPT_DIR}/.claude-home"
export CLAUDE_CONFIG_DIR="${CLAUDE_HOME}/.config/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Detect and link agents
AGENTS_LOCATIONS=(
    "${SCRIPT_DIR}/agents"
    "${SCRIPT_DIR}/.local/share/claude/agents"
    "$HOME/.local/share/claude/agents"
    "$HOME/Documents/Claude/agents"
)

AGENTS_DIR=""
for loc in "${AGENTS_LOCATIONS[@]}"; do
    if [ -d "$loc" ]; then
        AGENTS_DIR="$loc"
        break
    fi
done

if [ -n "$AGENTS_DIR" ]; then
    # Link agents to config directory
    ln -sf "$AGENTS_DIR" "$CLAUDE_CONFIG_DIR/agents" 2>/dev/null
    export CLAUDE_AGENTS_DIR="$AGENTS_DIR"
    
    # Count agents
    AGENT_COUNT=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
    echo -e "${GREEN}✓ Agents:${NC} $AGENT_COUNT configurations at $AGENTS_DIR"
else
    echo -e "${YELLOW}⚠ No agents directory found${NC}"
fi

echo
echo -e "${CYAN}Environment configured for LiveCD:${NC}"
echo "  • Claude runs with --dangerously-skip-permissions"
echo "  • All data stored in: ${SCRIPT_DIR}"
echo "  • No system modifications required"
echo "  • Portable - runs from any location"
echo

# Check if we have arguments to pass
if [ $# -gt 0 ]; then
    echo -e "${GREEN}➜ Starting Claude with arguments: $@${NC}"
else
    echo -e "${GREEN}➜ Starting Claude in interactive mode${NC}"
fi

echo -e "${CYAN}Running: $CLAUDE_BIN --dangerously-skip-permissions $@${NC}"
echo

# Execute Claude with permission bypass for LiveCD
exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"