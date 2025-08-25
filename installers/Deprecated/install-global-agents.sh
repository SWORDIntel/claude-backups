#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE AGENTS GLOBAL INSTALLATION - FIXED FOR INSTALLERS/ SUBDIRECTORY
# Makes project agents globally accessible to all Claude instances
# Version: 2.0 - Handles running from installers/ or project root
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PATH DETECTION - FIXED FOR SUBDIRECTORY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Resolve symlinks and get real script location
if [ -L "${BASH_SOURCE[0]}" ]; then
    REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Determine project root based on script location
if [[ "$SCRIPT_DIR" == */installers ]]; then
    # Running from installers/ subdirectory
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo -e "${CYAN}Running from installers/ subdirectory${NC}"
else
    # Running from project root
    PROJECT_ROOT="$SCRIPT_DIR"
    echo -e "${CYAN}Running from project root${NC}"
fi

# Set paths relative to project root
readonly AGENTS_DIR="$PROJECT_ROOT/agents"
readonly MCP_SERVER_SCRIPT="$PROJECT_ROOT/claude-agents-mcp-server.py"
readonly TOOLS_DIR="$PROJECT_ROOT/tools"

# Global installation paths
readonly GLOBAL_CONFIG_DIR="$HOME/.config/claude-code"
readonly GLOBAL_AGENTS_DIR="$HOME/.local/share/claude-code/agents"
readonly LOCAL_BIN="$HOME/.local/bin"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}${CYAN}Claude Agents Global Installation v2.0${NC}"
echo "════════════════════════════════════════════════"
echo
echo "Project root: $PROJECT_ROOT"
echo "Agents directory: $AGENTS_DIR"
echo

# Verify agents directory exists
if [ ! -d "$AGENTS_DIR" ]; then
    echo -e "${RED}ERROR: Agents directory not found at $AGENTS_DIR${NC}"
    echo "Please ensure you're running from the correct location."
    exit 1
fi

# Count available agents
AGENT_COUNT=$(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l || echo 0)
echo -e "${GREEN}Found $AGENT_COUNT agents to install${NC}"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Step 1: Create global directories
echo -e "${GREEN}[1/7]${NC} Creating global directories..."
mkdir -p "$GLOBAL_CONFIG_DIR"
mkdir -p "$GLOBAL_AGENTS_DIR"
mkdir -p "$LOCAL_BIN"

# Step 2: Copy agents to global location
echo -e "${GREEN}[2/7]${NC} Installing agents globally..."
if [ -d "$AGENTS_DIR" ]; then
    # Clear existing agents (but preserve src/ if exists)
    if [ -d "$GLOBAL_AGENTS_DIR/src" ]; then
        mv "$GLOBAL_AGENTS_DIR/src" "/tmp/src_backup_$$" 2>/dev/null || true
    fi
    
    # Copy all agent files
    cp -r "$AGENTS_DIR/"* "$GLOBAL_AGENTS_DIR/" 2>/dev/null || true
    
    # Restore src if it was backed up
    if [ -d "/tmp/src_backup_$$" ]; then
        mv "/tmp/src_backup_$$" "$GLOBAL_AGENTS_DIR/src" 2>/dev/null || true
    fi
    
    echo -e "  ${GREEN}✓${NC} Copied $AGENT_COUNT agents"
else
    echo -e "  ${YELLOW}⚠${NC} No agents found to copy"
fi

# Step 3: Create global agent launcher
echo -e "${GREEN}[3/7]${NC} Creating global agent launcher..."
cat > "$LOCAL_BIN/claude-agent" << 'EOF'
#!/bin/bash
# Global Claude Agent Launcher v2.0

AGENT_NAME="$1"
shift

# Set agent directories
export CLAUDE_AGENTS_ROOT="${CLAUDE_AGENTS_ROOT:-$HOME/.local/share/claude-code/agents}"
export PYTHONPATH="$CLAUDE_AGENTS_ROOT/src/python:$PYTHONPATH"

# Colors for output
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

if [ -z "$AGENT_NAME" ]; then
    echo -e "${CYAN}Available agents:${NC}"
    echo "═══════════════════════════════"
    
    # List .md and .MD files
    find "$CLAUDE_AGENTS_ROOT" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) -type f 2>/dev/null | \
        while read -r agent_file; do
            agent_name=$(basename "$agent_file" | sed 's/\.[mM][dD]$//')
            echo -e "  ${GREEN}•${NC} $agent_name"
        done | sort
    
    echo
    echo "Usage: claude-agent <agent-name> [options]"
    echo "       claude-agent list              # List all agents"
    echo "       claude-agent status            # Show system status"
    exit 0
fi

# Special commands
case "$AGENT_NAME" in
    list)
        exec "$0"
        ;;
    status)
        echo -e "${CYAN}Claude Agent System Status${NC}"
        echo "═══════════════════════════════"
        echo "Agents root: $CLAUDE_AGENTS_ROOT"
        agent_count=$(find "$CLAUDE_AGENTS_ROOT" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        echo "Total agents: $agent_count"
        
        if [ -f "$CLAUDE_AGENTS_ROOT/src/python/production_orchestrator.py" ]; then
            echo -e "Orchestrator: ${GREEN}✓ Installed${NC}"
        else
            echo -e "Orchestrator: ${YELLOW}✗ Not found${NC}"
        fi
        exit 0
        ;;
esac

# Check if orchestrator exists
if [ -f "$CLAUDE_AGENTS_ROOT/src/python/production_orchestrator.py" ]; then
    # Launch agent through Python orchestrator
    exec python3 "$CLAUDE_AGENTS_ROOT/src/python/production_orchestrator.py" \
        --agent "$AGENT_NAME" \
        "$@"
else
    # Fallback: Just show agent info
    AGENT_FILE="$CLAUDE_AGENTS_ROOT/${AGENT_NAME}.md"
    if [ ! -f "$AGENT_FILE" ]; then
        # Try uppercase
        AGENT_FILE="$CLAUDE_AGENTS_ROOT/${AGENT_NAME^^}.MD"
    fi
    
    if [ -f "$AGENT_FILE" ]; then
        echo -e "${GREEN}Agent: $AGENT_NAME${NC}"
        echo "═══════════════════════════════"
        head -20 "$AGENT_FILE"
        echo
        echo -e "${YELLOW}Note: Python orchestrator not found. Install for full functionality.${NC}"
    else
        echo -e "${YELLOW}Agent '$AGENT_NAME' not found${NC}"
        echo "Run 'claude-agent' to see available agents"
        exit 1
    fi
fi
EOF
chmod +x "$LOCAL_BIN/claude-agent"

# Step 4: Create Claude Code integration config
echo -e "${GREEN}[4/7]${NC} Creating Claude Code integration..."
cat > "$GLOBAL_CONFIG_DIR/custom-agents.json" << EOF
{
  "custom_agents": {
    "enabled": true,
    "agents_path": "$GLOBAL_AGENTS_DIR",
    "launcher": "$LOCAL_BIN/claude-agent",
    "auto_discover": true,
    "project_root": "$PROJECT_ROOT",
    "sync_enabled": true,
    "sync_interval": 300
  }
}
EOF

# Step 5: Create environment setup
echo -e "${GREEN}[5/7]${NC} Setting up environment..."
cat > "$HOME/.claude-agents-env" << EOF
# Claude Agents Global Environment v2.0
# Generated from: $PROJECT_ROOT

# Core paths
export CLAUDE_AGENTS_ROOT="$GLOBAL_AGENTS_DIR"
export CLAUDE_AGENTS_LAUNCHER="$LOCAL_BIN/claude-agent"
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
export PATH="$LOCAL_BIN:\$PATH"

# Python path for agent modules
export PYTHONPATH="$GLOBAL_AGENTS_DIR/src/python:\$PYTHONPATH"

# Aliases for quick access
alias ca='claude-agent'
alias ca-list='claude-agent list'
alias ca-status='claude-agent status'

# Agent shortcuts (uppercase and lowercase)
alias ca-director='claude-agent director'
alias ca-security='claude-agent security'
alias ca-architect='claude-agent architect'
alias ca-testbed='claude-agent testbed'

# Quick sync from project
ca-sync() {
    echo "Syncing agents from $PROJECT_ROOT/agents..."
    if [ -d "$PROJECT_ROOT/agents" ]; then
        cp -r "$PROJECT_ROOT/agents/"* "$GLOBAL_AGENTS_DIR/" 2>/dev/null
        echo "✓ Sync complete"
    else
        echo "✗ Source directory not found"
    fi
}

# Show agent info
ca-info() {
    local agent="\${1:-}"
    if [ -z "\$agent" ]; then
        echo "Usage: ca-info <agent-name>"
        return 1
    fi
    
    local file="$GLOBAL_AGENTS_DIR/\${agent}.md"
    [ ! -f "\$file" ] && file="$GLOBAL_AGENTS_DIR/\${agent^^}.MD"
    
    if [ -f "\$file" ]; then
        less "\$file"
    else
        echo "Agent '\$agent' not found"
    fi
}
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

# Step 6: Create MCP server launcher (if server script exists)
echo -e "${GREEN}[6/7]${NC} Creating MCP server launcher..."
if [ -f "$MCP_SERVER_SCRIPT" ]; then
    cat > "$LOCAL_BIN/claude-agents-server" << EOF
#!/bin/bash
# Claude Agents MCP Server Launcher
cd "$GLOBAL_AGENTS_DIR"
export CLAUDE_AGENTS_ROOT="$GLOBAL_AGENTS_DIR"
exec python3 "$MCP_SERVER_SCRIPT"
EOF
    chmod +x "$LOCAL_BIN/claude-agents-server"
    echo -e "  ${GREEN}✓${NC} MCP server launcher created"
else
    echo -e "  ${YELLOW}⚠${NC} MCP server script not found at $MCP_SERVER_SCRIPT"
fi

# Step 7: Create systemd service (optional)
echo -e "${GREEN}[7/7]${NC} Creating systemd service..."
mkdir -p "$HOME/.config/systemd/user" 2>/dev/null || true

if [ -f "$MCP_SERVER_SCRIPT" ]; then
    cat > "$HOME/.config/systemd/user/claude-agents-mcp.service" << EOF
[Unit]
Description=Claude Agents MCP Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$GLOBAL_AGENTS_DIR
ExecStart=/usr/bin/python3 $MCP_SERVER_SCRIPT
Restart=on-failure
RestartSec=10
Environment="CLAUDE_AGENTS_ROOT=$GLOBAL_AGENTS_DIR"
Environment="CLAUDE_PROJECT_ROOT=$PROJECT_ROOT"

[Install]
WantedBy=default.target
EOF
    echo -e "  ${GREEN}✓${NC} Systemd service created"
else
    echo -e "  ${YELLOW}⚠${NC} Skipping service creation (no MCP server)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Quick verification
echo
echo -e "${BOLD}Verifying installation...${NC}"

# Check if agents were copied
INSTALLED_COUNT=$(find "$GLOBAL_AGENTS_DIR" -maxdepth 1 -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l || echo 0)
if [ "$INSTALLED_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} $INSTALLED_COUNT agents installed"
else
    echo -e "  ${YELLOW}⚠${NC} No agents found in global directory"
fi

# Check launcher
if [ -x "$LOCAL_BIN/claude-agent" ]; then
    echo -e "  ${GREEN}✓${NC} Launcher installed"
else
    echo -e "  ${RED}✗${NC} Launcher not executable"
fi

# Check environment file
if [ -f "$HOME/.claude-agents-env" ]; then
    echo -e "  ${GREEN}✓${NC} Environment file created"
else
    echo -e "  ${RED}✗${NC} Environment file missing"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo
echo -e "${BOLD}${GREEN}✓ Global Installation Complete!${NC}"
echo
echo "Your agents are now globally available:"
echo "  • Command: claude-agent <agent-name>"
echo "  • List agents: claude-agent list"
echo "  • Status: claude-agent status"
echo "  • Sync: ca-sync (after sourcing env)"

if [ -f "$MCP_SERVER_SCRIPT" ]; then
    echo "  • MCP Server: claude-agents-server"
fi

echo
echo "Installation locations:"
echo "  • Agents: $GLOBAL_AGENTS_DIR"
echo "  • Config: $GLOBAL_CONFIG_DIR/custom-agents.json"
echo "  • Launcher: $LOCAL_BIN/claude-agent"
echo
echo -e "${CYAN}To complete setup:${NC}"
echo "  1. Run: source ~/.claude-agents-env"
echo "  2. Test: claude-agent list"
echo "  3. Try: claude-agent director"
echo
echo -e "${YELLOW}Note: Full Claude Code integration requires MCP support${NC}"

# Optional: Source immediately for current session
if [ -t 0 ]; then
    echo
    echo -n "Source environment now? [Y/n]: "
    read -r response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        source "$HOME/.claude-agents-env"
        echo -e "${GREEN}✓ Environment loaded for current session${NC}"
        echo "Try: claude-agent list"
    fi
fi
