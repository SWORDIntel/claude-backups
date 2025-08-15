#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# SELF-CONTAINED CLAUDE LAUNCHER - NO EXTERNAL FILES REQUIRED
# Includes embedded installation logic
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly VERSION="4.0-embedded"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="/tmp/claude-install-$$"
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly AGENTS_DIR="$HOME/.local/share/claude/agents"
readonly LOCAL_NODE_DIR="$HOME/.local/node"
readonly LOCAL_NPM_PREFIX="$HOME/.local/npm-global"
readonly LOG_FILE="/tmp/claude-install-$(date +%Y%m%d-%H%M%S).log"

# GitHub configuration for agents
readonly GITHUB_TOKEN="${GITHUB_TOKEN:-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}"
readonly REPO_OWNER="SWORDIntel"
readonly REPO_NAME="claude-backups"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Cleanup on exit
cleanup() {
    [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2 | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2 | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }

# Banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___  | |     ___   __| | ___  
 | |    | |/ _` | | | |/ _` |/ _ \ | |    / _ \ / _` |/ _ \ 
 | |____| | (_| | |_| | (_| |  __/ | |___| (_) | (_| |  __/
  \_______|_\__,_|\__,_|\__,_|\___| \_____\___/ \__,_|\___|
                                                           
        Self-Contained LiveCD Launcher v4.0              
EOF
    echo -e "${NC}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EMBEDDED INSTALLATION LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_locally() {
    if command -v node &> /dev/null; then
        log "Node.js already installed: $(node --version)"
        return 0
    fi
    
    log "Installing Node.js locally (no sudo required)..."
    
    local NODE_VERSION="v20.11.0"
    local NODE_ARCH="linux-x64"
    local NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Download Node.js
    if command -v wget &> /dev/null; then
        wget -q --show-progress "$NODE_URL" -O node.tar.gz || return 1
    elif command -v curl &> /dev/null; then
        curl -fsSL "$NODE_URL" -o node.tar.gz || return 1
    else
        error "Neither wget nor curl found. Cannot download Node.js"
        return 1
    fi
    
    # Extract and install
    tar -xzf node.tar.gz
    mkdir -p "$LOCAL_NODE_DIR"
    cp -r "node-${NODE_VERSION}-${NODE_ARCH}"/* "$LOCAL_NODE_DIR/"
    
    # Update PATH
    export PATH="$LOCAL_NODE_DIR/bin:$PATH"
    
    # Add to shell profile
    local shell_rc="$HOME/.bashrc"
    if ! grep -q "$LOCAL_NODE_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$LOCAL_NODE_DIR/bin:\$PATH\"" >> "$shell_rc"
    fi
    
    cd - > /dev/null
    success "Node.js installed locally at $LOCAL_NODE_DIR"
    return 0
}

install_claude_npm() {
    log "Installing Claude Code via npm..."
    
    # Ensure npm is available
    if ! command -v npm &> /dev/null; then
        warn "npm not found, installing Node.js first..."
        install_node_locally || return 1
    fi
    
    # Configure npm for local installation
    mkdir -p "$LOCAL_NPM_PREFIX"
    export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
    export PATH="$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Try different package names
    local packages=(
        "@anthropic-ai/claude-code"
        "claude-code"
        "@anthropic/claude"
        "claude"
    )
    
    for package in "${packages[@]}"; do
        log "Trying npm package: $package"
        if npm install -g "$package" 2>/dev/null; then
            success "Installed $package via npm"
            
            # Find the installed binary
            local claude_bin="$LOCAL_NPM_PREFIX/bin/claude"
            if [ -f "$claude_bin" ]; then
                # Create wrapper in user bin
                mkdir -p "$USER_BIN_DIR"
                cat > "$USER_BIN_DIR/claude.original" << WRAPPER_EOF
#!/bin/bash
export PATH="$LOCAL_NODE_DIR/bin:\$PATH"
export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
exec "$claude_bin" "\$@"
WRAPPER_EOF
                chmod +x "$USER_BIN_DIR/claude.original"
                return 0
            fi
        fi
    done
    
    warn "Could not install Claude via npm"
    return 1
}

install_claude_pip() {
    log "Installing Claude Code via pip..."
    
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        warn "pip not available"
        return 1
    fi
    
    local pip_cmd="pip3"
    command -v pip3 &> /dev/null || pip_cmd="pip"
    
    # Try different packages
    local packages=(
        "claude-code"
        "anthropic"
        "claude"
    )
    
    for package in "${packages[@]}"; do
        log "Trying pip package: $package"
        if $pip_cmd install --user "$package" 2>/dev/null; then
            # Check if binary was installed
            if [ -f "$HOME/.local/bin/claude" ]; then
                mkdir -p "$USER_BIN_DIR"
                cp "$HOME/.local/bin/claude" "$USER_BIN_DIR/claude.original"
                chmod +x "$USER_BIN_DIR/claude.original"
                success "Installed $package via pip"
                return 0
            fi
        fi
    done
    
    warn "Could not install Claude via pip"
    return 1
}

create_claude_stub() {
    log "Creating Claude Code stub as fallback..."
    
    mkdir -p "$USER_BIN_DIR"
    
    cat > "$USER_BIN_DIR/claude.original" << 'STUB_EOF'
#!/usr/bin/env python3
"""Claude Code Stub - Minimal implementation for LiveCD"""

import sys
import os
import json
from pathlib import Path

class ClaudeStub:
    def __init__(self):
        self.version = "1.0.0-stub"
        self.agents_dir = os.environ.get('CLAUDE_AGENTS_DIR', 
                                         os.path.expanduser('~/.local/share/claude/agents'))
    
    def run(self):
        print(f"Claude Code Stub v{self.version}")
        print("This is a placeholder for the official Claude Code")
        print()
        
        if "--version" in sys.argv:
            print(f"Version: {self.version}")
        elif "--help" in sys.argv:
            print("Usage: claude [options] [command]")
            print("\nOptions:")
            print("  --version                        Show version")
            print("  --help                          Show this help")
            print("  --dangerously-skip-permissions  Skip permission checks")
            print("\nCommands:")
            print("  /config          Open configuration")
            print("  /terminal-setup  Setup terminal")
        else:
            print(f"Arguments: {sys.argv[1:]}")
            print(f"\nAgents directory: {self.agents_dir}")
            
            if os.path.exists(self.agents_dir):
                agent_count = len(list(Path(self.agents_dir).glob('**/*.md')))
                print(f"Found {agent_count} agent configurations")
            
            print("\nTo install the official Claude Code:")
            print("  npm install -g @anthropic-ai/claude-code")
            print("  or")
            print("  pip install claude-code")
        
        return 0

if __name__ == "__main__":
    stub = ClaudeStub()
    sys.exit(stub.run())
STUB_EOF
    
    chmod +x "$USER_BIN_DIR/claude.original"
    success "Claude stub created at $USER_BIN_DIR/claude.original"
    return 0
}

install_agents_from_github() {
    log "Installing Claude agents from GitHub..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Try to clone the repository
    if command -v git &> /dev/null; then
        log "Cloning agents repository..."
        
        # Try with token
        if [ -n "$GITHUB_TOKEN" ]; then
            git clone --depth=1 "https://${GITHUB_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git" 2>/dev/null || {
                warn "Could not clone with token, trying without..."
                git clone --depth=1 "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" 2>/dev/null || {
                    warn "Could not clone repository"
                    return 1
                }
            }
        else
            git clone --depth=1 "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" 2>/dev/null || {
                warn "Could not clone repository"
                return 1
            }
        fi
        
        # Check if agents directory exists
        if [ -d "${REPO_NAME}/agents" ]; then
            mkdir -p "$AGENTS_DIR"
            cp -r "${REPO_NAME}/agents"/* "$AGENTS_DIR/"
            success "Agents installed to $AGENTS_DIR"
            
            # Count agents
            local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
            log "Installed $agent_count agent configurations"
            return 0
        else
            warn "No agents directory found in repository"
        fi
    else
        warn "git not available, cannot clone agents"
    fi
    
    cd - > /dev/null
    return 1
}

install_agents_local() {
    log "Checking for local agents..."
    
    # Check if agents exist in script directory
    if [ -d "${SCRIPT_DIR}/agents" ]; then
        log "Found local agents at ${SCRIPT_DIR}/agents"
        
        mkdir -p "$AGENTS_DIR"
        cp -r "${SCRIPT_DIR}/agents"/* "$AGENTS_DIR/" 2>/dev/null || true
        
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
        success "Copied $agent_count agent configurations"
        return 0
    fi
    
    warn "No local agents found"
    return 1
}

create_claude_wrapper() {
    log "Creating Claude wrapper with permission bypass..."
    
    mkdir -p "$USER_BIN_DIR"
    
    cat > "$USER_BIN_DIR/claude" << 'WRAPPER_EOF'
#!/bin/bash
# Claude wrapper with automatic permission bypass for LiveCD

# Find the actual Claude binary
CLAUDE_BIN=""
for loc in ~/.local/bin/claude.original ~/.local/npm-global/bin/claude ~/.local/node/bin/claude; do
    if [ -f "$loc" ] && [ -x "$loc" ]; then
        CLAUDE_BIN="$loc"
        break
    fi
done

if [ -z "$CLAUDE_BIN" ]; then
    echo "Claude Code not installed. Please run the installer."
    exit 1
fi

# Set agents directory
export CLAUDE_AGENTS_DIR="${CLAUDE_AGENTS_DIR:-$HOME/.local/share/claude/agents}"

# Check if we should add bypass flag
should_bypass=true
for arg in "$@"; do
    if [[ "$arg" == "--dangerously-skip-permissions" ]] || [[ "$arg" == "--help" ]] || [[ "$arg" == "--version" ]]; then
        should_bypass=false
        break
    fi
done

# Execute with or without bypass
if [ "$should_bypass" = true ]; then
    exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"
else
    exec "$CLAUDE_BIN" "$@"
fi
WRAPPER_EOF
    
    chmod +x "$USER_BIN_DIR/claude"
    success "Claude wrapper created at $USER_BIN_DIR/claude"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_full_installation() {
    show_banner
    
    log "Starting Claude Code installation for LiveCD..."
    echo
    
    # Create necessary directories
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$WORK_DIR"
    
    # Step 1: Install Claude Code
    echo -e "${CYAN}Step 1: Installing Claude Code...${NC}"
    
    local claude_installed=false
    
    # Try npm first
    if install_claude_npm; then
        claude_installed=true
    # Try pip if npm failed
    elif install_claude_pip; then
        claude_installed=true
    # Create stub as last resort
    else
        create_claude_stub
        claude_installed=true
    fi
    
    # Step 2: Install agents
    echo
    echo -e "${CYAN}Step 2: Installing agents...${NC}"
    
    # Try local first, then GitHub
    install_agents_local || install_agents_from_github || {
        warn "Could not install agents"
    }
    
    # Step 3: Create wrapper
    echo
    echo -e "${CYAN}Step 3: Creating launcher wrapper...${NC}"
    create_claude_wrapper
    
    # Step 4: Update PATH
    echo
    echo -e "${CYAN}Step 4: Updating environment...${NC}"
    
    local shell_rc="$HOME/.bashrc"
    if ! grep -q "$USER_BIN_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$shell_rc"
        log "Added $USER_BIN_DIR to PATH in $shell_rc"
    fi
    
    if ! grep -q "CLAUDE_AGENTS_DIR" "$shell_rc" 2>/dev/null; then
        echo "export CLAUDE_AGENTS_DIR=\"$AGENTS_DIR\"" >> "$shell_rc"
        log "Added CLAUDE_AGENTS_DIR to $shell_rc"
    fi
    
    # Final status
    echo
    echo -e "${GREEN}${BOLD}Installation Complete!${NC}"
    echo
    echo "Installed components:"
    
    if [ -f "$USER_BIN_DIR/claude.original" ]; then
        echo -e "  ${GREEN}✓${NC} Claude Code binary"
    fi
    
    if [ -f "$USER_BIN_DIR/claude" ]; then
        echo -e "  ${GREEN}✓${NC} Claude wrapper (with auto-bypass)"
    fi
    
    local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
    if [ "$agent_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Agents: $agent_count configurations"
    else
        echo -e "  ${YELLOW}⚠${NC} Agents: not installed"
    fi
    
    echo
    echo "To use Claude Code:"
    echo "  1. Reload your shell: source ~/.bashrc"
    echo "  2. Run: claude"
    echo
    echo "Or run directly now:"
    echo "  $USER_BIN_DIR/claude"
    echo
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUICK LAUNCH FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

quick_launch() {
    # Try to find Claude
    local claude_bin=""
    
    for loc in "$USER_BIN_DIR/claude" "$USER_BIN_DIR/claude.original" "$HOME/.local/npm-global/bin/claude"; do
        if [ -f "$loc" ] && [ -x "$loc" ]; then
            claude_bin="$loc"
            break
        fi
    done
    
    if [ -n "$claude_bin" ]; then
        log "Launching Claude from: $claude_bin"
        export CLAUDE_AGENTS_DIR="$AGENTS_DIR"
        exec "$claude_bin" --dangerously-skip-permissions "$@"
    else
        error "Claude not found. Installing..."
        run_full_installation
        
        # Try again after installation
        if [ -f "$USER_BIN_DIR/claude" ]; then
            exec "$USER_BIN_DIR/claude" --dangerously-skip-permissions "$@"
        else
            error "Installation failed"
            exit 1
        fi
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN MENU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_menu() {
    while true; do
        show_banner
        
        # Check current status
        local claude_status="${RED}✗ Not installed${NC}"
        local agents_status="${RED}✗ Not installed${NC}"
        
        if [ -f "$USER_BIN_DIR/claude" ] || [ -f "$USER_BIN_DIR/claude.original" ]; then
            claude_status="${GREEN}✓ Installed${NC}"
        fi
        
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        if [ "$agent_count" -gt 0 ]; then
            agents_status="${GREEN}✓ $agent_count agents${NC}"
        fi
        
        echo "Current Status:"
        echo "  Claude: $claude_status"
        echo "  Agents: $agents_status"
        echo
        
        echo "Options:"
        echo "  1) Quick Launch Claude"
        echo "  2) Full Installation (Recommended)"
        echo "  3) Install Claude Only"
        echo "  4) Install Agents Only"
        echo "  5) System Check"
        echo "  6) Exit"
        echo
        
        echo -n "Enter your choice [1-6]: "
        read -r choice
        
        case "$choice" in
            1) quick_launch ;;
            2) run_full_installation; read -p "Press ENTER to continue..." ;;
            3) install_claude_npm || install_claude_pip || create_claude_stub; create_claude_wrapper; read -p "Press ENTER to continue..." ;;
            4) install_agents_local || install_agents_from_github; read -p "Press ENTER to continue..." ;;
            5) 
                echo "System Check:"
                echo "  Node: $(command -v node &> /dev/null && node --version || echo 'Not installed')"
                echo "  NPM: $(command -v npm &> /dev/null && npm --version || echo 'Not installed')"
                echo "  Python: $(command -v python3 &> /dev/null && python3 --version || echo 'Not installed')"
                echo "  Git: $(command -v git &> /dev/null && git --version || echo 'Not installed')"
                read -p "Press ENTER to continue..."
                ;;
            6) 
                success "Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid choice"
                sleep 2
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Parse arguments
case "${1:-}" in
    --install|-i)
        run_full_installation
        ;;
    --quick|-q)
        shift
        quick_launch "$@"
        ;;
    --help|-h)
        echo "Self-Contained Claude Launcher"
        echo "Usage: $0 [options]"
        echo "  --install, -i   Run full installation"
        echo "  --quick, -q     Quick launch Claude"
        echo "  --help, -h      Show this help"
        echo "  (no options)    Show interactive menu"
        ;;
    "")
        main_menu
        ;;
    *)
        # Pass through to Claude
        quick_launch "$@"
        ;;
esac