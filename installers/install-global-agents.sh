#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE AGENTS GLOBAL INSTALLATION
# Makes project agents globally accessible to all Claude instances
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AGENTS_DIR="$SCRIPT_DIR/agents"
readonly GLOBAL_CONFIG_DIR="$HOME/.config/claude-code"
readonly GLOBAL_AGENTS_DIR="$HOME/.local/share/claude-code/agents"
readonly SYSTEM_BIN="/usr/local/bin"

echo -e "${BOLD}${CYAN}Claude Agents Global Installation${NC}"
echo "════════════════════════════════════════════════"

# Step 1: Create global directories
echo -e "${GREEN}[1/6]${NC} Creating global directories..."
mkdir -p "$GLOBAL_CONFIG_DIR"
mkdir -p "$GLOBAL_AGENTS_DIR"
mkdir -p "$HOME/.local/bin"

# Step 2: Copy agents to global location
echo -e "${GREEN}[2/6]${NC} Installing agents globally..."
cp -r "$AGENTS_DIR"/* "$GLOBAL_AGENTS_DIR/"

# Step 3: Create global agent launcher
echo -e "${GREEN}[3/6]${NC} Creating global agent launcher..."
cat > "$HOME/.local/bin/claude-agent" << 'EOF'
#!/bin/bash
# Global Claude Agent Launcher

AGENT_NAME="$1"
shift

export CLAUDE_AGENTS_ROOT="$HOME/.local/share/claude-code/agents"
export PYTHONPATH="$CLAUDE_AGENTS_ROOT/src/python:$PYTHONPATH"

if [ -z "$AGENT_NAME" ]; then
    echo "Available agents:"
    find "$CLAUDE_AGENTS_ROOT" -name "*.md" -maxdepth 1 -exec basename {} .md \; | sort
    exit 0
fi

# Launch agent through Python orchestrator
python3 "$CLAUDE_AGENTS_ROOT/src/python/production_orchestrator.py" \
    --agent "$AGENT_NAME" \
    "$@"
EOF
chmod +x "$HOME/.local/bin/claude-agent"

# Step 4: Create Claude Code integration
echo -e "${GREEN}[4/6]${NC} Creating Claude Code integration..."
cat > "$GLOBAL_CONFIG_DIR/custom-agents.json" << EOF
{
  "custom_agents": {
    "enabled": true,
    "agents_path": "$GLOBAL_AGENTS_DIR",
    "launcher": "$HOME/.local/bin/claude-agent",
    "auto_discover": true
  }
}
EOF

# Step 5: Create environment setup
echo -e "${GREEN}[5/6]${NC} Setting up environment..."
cat > "$HOME/.claude-agents-env" << EOF
# Claude Agents Global Environment
export CLAUDE_AGENTS_ROOT="$GLOBAL_AGENTS_DIR"
export CLAUDE_AGENTS_LAUNCHER="$HOME/.local/bin/claude-agent"
export PATH="$HOME/.local/bin:\$PATH"

# Python path for agent modules
export PYTHONPATH="$GLOBAL_AGENTS_DIR/src/python:\$PYTHONPATH"

# Aliases for quick access
alias ca='claude-agent'
alias ca-list='claude-agent'
alias ca-director='claude-agent director'
alias ca-orchestrator='claude-agent projectorchestrator'
alias ca-security='claude-agent security'
EOF

# Add to shell RC files
for rc_file in ~/.bashrc ~/.zshrc; do
    if [ -f "$rc_file" ]; then
        if ! grep -q ".claude-agents-env" "$rc_file"; then
            echo "" >> "$rc_file"
            echo "# Claude Agents Global" >> "$rc_file"
            echo "[ -f ~/.claude-agents-env ] && source ~/.claude-agents-env" >> "$rc_file"
        fi
    fi
done

# Step 6: Create systemd service for MCP server (optional)
echo -e "${GREEN}[6/6]${NC} Creating MCP server service..."
cat > "$HOME/.config/systemd/user/claude-agents-mcp.service" << EOF
[Unit]
Description=Claude Agents MCP Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$GLOBAL_AGENTS_DIR
ExecStart=/usr/bin/python3 $SCRIPT_DIR/claude-agents-mcp-server.py
Restart=on-failure
RestartSec=10
Environment="CLAUDE_AGENTS_ROOT=$GLOBAL_AGENTS_DIR"

[Install]
WantedBy=default.target
EOF

# Create quick launcher for MCP server
cat > "$HOME/.local/bin/claude-agents-server" << 'EOF'
#!/bin/bash
cd "$HOME/.local/share/claude-code/agents"
python3 /home/ubuntu/Documents/Claude/claude-agents-mcp-server.py
EOF
chmod +x "$HOME/.local/bin/claude-agents-server"

echo
echo -e "${BOLD}${GREEN}✓ Installation Complete!${NC}"
echo
echo "Your agents are now globally available:"
echo "  • Command: claude-agent <agent-name>"
echo "  • List agents: claude-agent"
echo "  • MCP Server: claude-agents-server"
echo
echo "To complete setup:"
echo "  1. Run: source ~/.claude-agents-env"
echo "  2. Test: claude-agent director help"
echo
echo "For Claude Code integration:"
echo "  • Config: ~/.config/claude-code/custom-agents.json"
echo "  • Agents: ~/.local/share/claude-code/agents/"
echo
echo -e "${YELLOW}Note: Full Claude Code integration requires MCP support or custom extension${NC}"