#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE QUICK LAUNCHER - FIXED FOR INSTALLERS/ SUBDIRECTORY
# Complete installation with proper path detection and agent discovery
# Version 3.1 - Subdirectory-aware with agent sync
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

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
    echo "Running from installers/ subdirectory"
else
    # Running from project root
    PROJECT_ROOT="$SCRIPT_DIR"
    echo "Running from project root"
fi

# Configuration
readonly SCRIPT_VERSION="3.1-subdirectory-aware"
readonly WORK_DIR="/tmp/claude-install-$$"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# Set paths relative to project root
readonly SOURCE_AGENTS_DIR="$PROJECT_ROOT/agents"
readonly STATUSLINE_SRC="$PROJECT_ROOT/statusline.lua"
readonly UNIFIED_WRAPPER="$PROJECT_ROOT/claude-unified"
readonly ORCHESTRATION_BRIDGE="$PROJECT_ROOT/claude-orchestration-bridge.py"

# GitHub Configuration (fallback if local not found)
readonly GITHUB_REPO="https://github.com/SWORDIntel/claude-backups"
readonly GITHUB_BRANCH="main"

# Installation paths
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly AGENTS_DIR="$HOME/.local/share/claude/agents"
readonly CLAUDE_HOME_AGENTS="$HOME/agents"  # Where Task tool looks
readonly LOCAL_NODE_DIR="$HOME/.local/node"
readonly LOCAL_NPM_PREFIX="$HOME/.local/npm-global"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Global variable to store found Claude binary
CLAUDE_BINARY=""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { 
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() { 
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

success() { 
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
    echo "[SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

show_banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___  | |     ___   __| | ___  
 | |    | |/ _` | | | |/ _` |/ _ \ | |    / _ \ / _` |/ _ \ 
 | |____| | (_| | |_| | (_| |  __/ | |___| (_) | (_| |  __/
  \_______|_\__,_|\__,_|\__,_|\___|  \_____\___/ \__,_|\___|
                                                           
         Quick Launcher v3.1 - Smart Path Detection Edition
EOF
    printf "${NC}\n"
    printf "${GREEN}Project Root:${NC} $PROJECT_ROOT\n"
    printf "${GREEN}Agents Source:${NC} $SOURCE_AGENTS_DIR\n\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DETECT AND RUN MAIN INSTALLER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

find_and_run_main_installer() {
    log "Looking for main installer..."
    
    # Possible locations for the main installer
    local installer_paths=(
        "$PROJECT_ROOT/installers/claude-installer.sh"
        "$PROJECT_ROOT/claude-installer.sh"
        "$SCRIPT_DIR/claude-installer.sh"
        "$PROJECT_ROOT/installers/claude-livecd-unified-with-agents.sh"
        "$PROJECT_ROOT/claude-livecd-unified-with-agents.sh"
    )
    
    for installer in "${installer_paths[@]}"; do
        if [ -f "$installer" ] && [ -x "$installer" ]; then
            success "Found main installer: $installer"
            echo "Launching main installer..."
            exec "$installer" "$@"
            exit $?
        elif [ -f "$installer" ]; then
            success "Found main installer (making executable): $installer"
            chmod +x "$installer"
            exec "$installer" "$@"
            exit $?
        fi
    done
    
    warn "Main installer not found, continuing with quick installation..."
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT INSTALLATION WITH PROPER PATH DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents_with_discovery() {
    log "Installing agents with Task tool discovery..."
    
    # Create necessary directories
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$CLAUDE_HOME_AGENTS"
    mkdir -p "$WORK_DIR"
    
    # Method 1: Try local agents from project root
    if [ -d "$SOURCE_AGENTS_DIR" ]; then
        log "Found agents at: $SOURCE_AGENTS_DIR"
        
        # Count agents before copying
        local source_count=$(find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        log "Found $source_count agents in source directory"
        
        # Copy to standard agent directory
        cp -r "$SOURCE_AGENTS_DIR/"* "$AGENTS_DIR/" 2>/dev/null || true
        
        # CRITICAL: Copy to ~/agents for Task tool discovery
        rm -rf "$CLAUDE_HOME_AGENTS" 2>/dev/null || true
        cp -r "$SOURCE_AGENTS_DIR" "$CLAUDE_HOME_AGENTS"
        
        local agent_count=$(find "$CLAUDE_HOME_AGENTS" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        
        if [ "$agent_count" -gt 0 ]; then
            success "Installed $agent_count agents"
            echo "Agents installed to:"
            echo "  • Standard: $AGENTS_DIR"
            echo "  • Task discovery: $CLAUDE_HOME_AGENTS"
            
            # List first few agents
            echo "Discovered agents:"
            find "$CLAUDE_HOME_AGENTS" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | head -5 | while read -r agent; do
                echo "  • $(basename "$agent" | sed 's/\.[mM][dD]$//')"
            done
            
            return 0
        fi
    else
        warn "Local agents directory not found at $SOURCE_AGENTS_DIR"
    fi
    
    # Method 2: Download from GitHub
    cd "$WORK_DIR"
    log "Attempting to download agents from GitHub..."
    
    # Try git clone first
    if command -v git &> /dev/null; then
        if git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO" repo 2>/dev/null; then
            cd repo
            git sparse-checkout set agents 2>/dev/null || true
            
            if [ -d "agents" ]; then
                cp -r agents/* "$AGENTS_DIR/" 2>/dev/null || true
                cp -r agents "$CLAUDE_HOME_AGENTS" 2>/dev/null || true
                local agent_count=$(find "$CLAUDE_HOME_AGENTS" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l || echo 0)
                success "Downloaded $agent_count agents from GitHub"
                return 0
            fi
        fi
    fi
    
    # Method 3: Download as archive
    log "Downloading repository archive..."
    local archive_url="${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"
    
    if command -v wget &> /dev/null; then
        wget -q "$archive_url" -O repo.tar.gz 2>/dev/null || true
    elif command -v curl &> /dev/null; then
        curl -fsSL "$archive_url" -o repo.tar.gz 2>/dev/null || true
    fi
    
    if [ -f "repo.tar.gz" ]; then
        tar -xzf repo.tar.gz 2>/dev/null || true
        local repo_dir=$(find . -maxdepth 1 -type d -name "*claude*" 2>/dev/null | head -1)
        
        if [ -n "$repo_dir" ] && [ -d "$repo_dir/agents" ]; then
            cp -r "$repo_dir/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
            cp -r "$repo_dir/agents" "$CLAUDE_HOME_AGENTS" 2>/dev/null || true
            local agent_count=$(find "$CLAUDE_HOME_AGENTS" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l || echo 0)
            success "Downloaded $agent_count agents from GitHub archive"
            return 0
        fi
    fi
    
    # Method 4: Create sample agents
    warn "Could not download agents, creating samples..."
    create_sample_agents
}

create_sample_agents() {
    for dir in "$AGENTS_DIR" "$CLAUDE_HOME_AGENTS"; do
        mkdir -p "$dir"
        
        cat > "$dir/DIRECTOR.md" << 'EOF'
---
uuid: director-001
name: Director
role: Strategic Command and Control
tools:
  - Task
---

# Director Agent
Project orchestration and task delegation
EOF

        cat > "$dir/SECURITY.md" << 'EOF'
---
uuid: security-001
name: Security
role: Security Analysis
tools:
  - Task
---

# Security Agent
Security analysis and vulnerability assessment
EOF

        cat > "$dir/TESTBED.md" << 'EOF'
---
uuid: testbed-001
name: Testbed
role: Testing and QA
tools:
  - Task
---

# Testing Agent
Test creation and quality assurance
EOF
    done
    
    success "Created 3 sample agents in both locations"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT SYNC WITH PROPER PATHS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_agent_sync() {
    log "Setting up 5-minute agent synchronization..."
    
    # Create sync script with correct paths
    local sync_script="$USER_BIN_DIR/sync-claude-agents.sh"
    mkdir -p "$USER_BIN_DIR"
    
    cat > "$sync_script" << SYNC_SCRIPT
#!/bin/bash
# Claude Agent Sync - Updates every 5 minutes

SOURCE="$SOURCE_AGENTS_DIR"  # Using detected project root
TARGET="$CLAUDE_HOME_AGENTS"
BACKUP="$AGENTS_DIR"
LOG="\$HOME/.local/share/claude/agent-sync.log"

mkdir -p "\$(dirname "\$LOG")"
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')

if [ ! -d "\$SOURCE" ]; then
    echo "[\$TIMESTAMP] ERROR: Source not found at \$SOURCE" >> "\$LOG"
    exit 1
fi

# Check if changed
if [ -f "\$HOME/.agent-sync-marker" ]; then
    if [ "\$SOURCE" -ot "\$HOME/.agent-sync-marker" ]; then
        exit 0
    fi
fi

echo "[\$TIMESTAMP] Syncing from \$SOURCE to \$TARGET" >> "\$LOG"

# Sync to Task tool location
rm -rf "\$TARGET.old" 2>/dev/null
[ -d "\$TARGET" ] && mv "\$TARGET" "\$TARGET.old"
cp -r "\$SOURCE" "\$TARGET"

# Also sync to backup location
cp -r "\$SOURCE/"* "\$BACKUP/" 2>/dev/null || true

COUNT=\$(find "\$TARGET" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
echo "[\$TIMESTAMP] Synced \$COUNT agents" >> "\$LOG"

touch "\$HOME/.agent-sync-marker"
tail -n 100 "\$LOG" > "\${LOG}.tmp" && mv "\${LOG}.tmp" "\$LOG"
SYNC_SCRIPT
    
    chmod +x "$sync_script"
    
    # Run initial sync
    "$sync_script" 2>/dev/null || true
    
    # Setup cron job
    (crontab -l 2>/dev/null | grep -v "$sync_script"; echo "*/5 * * * * $sync_script >/dev/null 2>&1") | crontab -
    
    success "Agent sync cron job configured (every 5 minutes)"
    
    # Create status command
    cat > "$USER_BIN_DIR/claude-agent-status" << 'STATUS_SCRIPT'
#!/bin/bash
echo "═══════════════════════════════════════════════════"
echo "           Claude Agent System Status"
echo "═══════════════════════════════════════════════════"
echo
echo "Agent Locations:"
echo "  • Task Discovery: ~/agents"
echo "  • Standard: ~/.local/share/claude/agents"
echo
echo "Agent Counts:"
echo "  • ~/agents: $(find ~/agents -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l) agents"
echo "  • Standard: $(find ~/.local/share/claude/agents -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l) agents"
echo
echo "Cron Job:"
if crontab -l 2>/dev/null | grep -q "sync-claude-agents"; then
    echo "  ✅ Active (runs every 5 minutes)"
else
    echo "  ❌ Not found"
fi
echo
if [ -f "$HOME/.local/share/claude/agent-sync.log" ]; then
    echo "Last sync activity:"
    tail -3 "$HOME/.local/share/claude/agent-sync.log"
fi
STATUS_SCRIPT
    chmod +x "$USER_BIN_DIR/claude-agent-status"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NEOVIM STATUSLINE DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_neovim_statusline() {
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_lua_dir="$nvim_config_dir/lua"
    
    # Check if statusline.lua exists in project root
    if [ ! -f "$STATUSLINE_SRC" ]; then
        warn "statusline.lua not found at $STATUSLINE_SRC"
        
        # Try to download from GitHub
        log "Attempting to download statusline.lua from GitHub..."
        local statusline_url="${GITHUB_REPO}/raw/${GITHUB_BRANCH}/statusline.lua"
        
        mkdir -p "$WORK_DIR"
        if command -v wget &> /dev/null; then
            wget -q "$statusline_url" -O "$WORK_DIR/statusline.lua" 2>/dev/null || true
        elif command -v curl &> /dev/null; then
            curl -fsSL "$statusline_url" -o "$WORK_DIR/statusline.lua" 2>/dev/null || true
        fi
        
        if [ -f "$WORK_DIR/statusline.lua" ]; then
            STATUSLINE_SRC="$WORK_DIR/statusline.lua"
        else
            warn "Could not obtain statusline.lua"
            return 1
        fi
    fi
    
    log "Deploying Neovim statusline..."
    
    # Create directories
    mkdir -p "$nvim_lua_dir"
    mkdir -p "$AGENTS_DIR"
    
    # Copy statusline
    cp "$STATUSLINE_SRC" "$nvim_lua_dir/statusline.lua"
    cp "$STATUSLINE_SRC" "$AGENTS_DIR/statusline.lua"
    
    # Create/update init.lua
    if [ ! -f "$nvim_config_dir/init.lua" ]; then
        cat > "$nvim_config_dir/init.lua" << 'NVIM_INIT'
-- Claude Agent Framework Statusline
vim.env.CLAUDE_AGENTS_ROOT = vim.env.CLAUDE_AGENTS_ROOT or vim.fn.expand("~/.local/share/claude/agents")
package.path = package.path .. ";" .. vim.env.CLAUDE_AGENTS_ROOT .. "/?.lua"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
NVIM_INIT
        success "Created Neovim config with statusline"
    else
        if ! grep -q "statusline.setup()" "$nvim_config_dir/init.lua" 2>/dev/null; then
            cat >> "$nvim_config_dir/init.lua" << 'NVIM_APPEND'

-- Claude Agent Framework Statusline
vim.env.CLAUDE_AGENTS_ROOT = vim.env.CLAUDE_AGENTS_ROOT or vim.fn.expand("~/.local/share/claude/agents")
package.path = package.path .. ";" .. vim.env.CLAUDE_AGENTS_ROOT .. "/?.lua"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
NVIM_APPEND
            success "Updated Neovim config"
        fi
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODE.JS INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_if_needed() {
    if command -v node &> /dev/null; then
        log "Node.js found: $(node --version)"
        return 0
    fi
    
    log "Installing Node.js locally..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    local node_version="v20.11.0"
    local node_arch="linux-x64"
    
    case "$(uname -m)" in
        arm64|aarch64) node_arch="linux-arm64" ;;
    esac
    
    local node_url="https://nodejs.org/dist/${node_version}/node-${node_version}-${node_arch}.tar.gz"
    
    if command -v wget &> /dev/null; then
        wget -q "$node_url" -O node.tar.gz || return 1
    elif command -v curl &> /dev/null; then
        curl -fsSL "$node_url" -o node.tar.gz || return 1
    fi
    
    tar -xzf node.tar.gz
    mkdir -p "$LOCAL_NODE_DIR"
    cp -r "node-${node_version}-${node_arch}"/* "$LOCAL_NODE_DIR/"
    
    export PATH="$LOCAL_NODE_DIR/bin:$PATH"
    success "Node.js installed locally"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE CODE INSTALLATION (simplified for quick launch)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_claude_code() {
    log "Installing Claude Code..."
    
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$LOCAL_NPM_PREFIX"
    
    export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
    export PATH="$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Try npm installation
    if command -v npm &> /dev/null; then
        log "Installing Claude Code via npm..."
        
        if npm install -g @anthropic-ai/claude-code --no-audit --no-fund 2>/dev/null; then
            if [ -f "$LOCAL_NPM_PREFIX/bin/claude" ]; then
                mv "$LOCAL_NPM_PREFIX/bin/claude" "$LOCAL_NPM_PREFIX/bin/claude.original"
                CLAUDE_BINARY="$LOCAL_NPM_PREFIX/bin/claude.original"
                success "Claude Code installed via npm"
                
                # Create wrapper (check for unified wrapper first)
                if [ -f "$UNIFIED_WRAPPER" ]; then
                    log "Using unified wrapper"
                    cp "$UNIFIED_WRAPPER" "$USER_BIN_DIR/claude"
                    chmod +x "$USER_BIN_DIR/claude"
                else
                    create_permission_bypass_wrapper
                fi
                
                return 0
            fi
        fi
    fi
    
    # Create stub if installation failed
    create_minimal_stub
    return 0
}

create_permission_bypass_wrapper() {
    log "Creating permission bypass wrapper..."
    cat > "$USER_BIN_DIR/claude" << EOF
#!/bin/bash
# Claude LiveCD Wrapper
export CLAUDE_AGENTS_DIR="$CLAUDE_HOME_AGENTS"
export CLAUDE_AGENTS_ROOT="$CLAUDE_HOME_AGENTS"

ORIGINAL="$CLAUDE_BINARY"
if [ -f "\$ORIGINAL" ]; then
    if [[ " \$@ " != *" --no-skip-permissions "* ]]; then
        exec "\$ORIGINAL" --dangerously-skip-permissions "\$@"
    else
        exec "\$ORIGINAL" "\$@"
    fi
else
    echo "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
fi
EOF
    chmod +x "$USER_BIN_DIR/claude"
    success "Wrapper created"
}

create_minimal_stub() {
    log "Creating minimal stub..."
    cat > "$USER_BIN_DIR/claude" << 'STUB'
#!/bin/bash
echo "Claude Code - Installation Required"
echo "Run: npm install -g @anthropic-ai/claude-code"
echo "Agents directory: ~/agents"
STUB
    chmod +x "$USER_BIN_DIR/claude"
    CLAUDE_BINARY="$USER_BIN_DIR/claude"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_environment() {
    log "Setting up environment..."
    
    # Export variables for current session
    export CLAUDE_AGENTS_DIR="$CLAUDE_HOME_AGENTS"
    export CLAUDE_AGENTS_ROOT="$CLAUDE_HOME_AGENTS"
    export PATH="$USER_BIN_DIR:$LOCAL_NODE_DIR/bin:$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Update bashrc
    local shell_rc="$HOME/.bashrc"
    
    # Add PATH
    if ! grep -q "$USER_BIN_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$shell_rc"
    fi
    
    # Add agent environment variables
    if ! grep -q "CLAUDE_AGENTS_DIR" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << 'BASHRC_ENV'

# Claude Agent Framework
export CLAUDE_AGENTS_DIR="$HOME/agents"
export CLAUDE_AGENTS_ROOT="$HOME/agents"
export CLAUDE_PERMISSION_BYPASS=true

# Aliases
alias claude-safe='claude --no-skip-permissions'
alias ca-status='claude-agent-status'
alias ca-list='claude-list-agents'

# List agents function
claude-list-agents() {
    echo "Available agents in ~/agents:"
    find ~/agents -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) -type f 2>/dev/null | \
        while read -r agent; do
            echo "  • $(basename "$agent" | sed 's/\.[mM][dD]$//')"
        done | sort
}
BASHRC_ENV
    fi
    
    success "Environment configured"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo
    printf "${BOLD}${CYAN}Installation Status${NC}\n"
    echo "═══════════════════════════════════════"
    
    # Claude Code
    printf "${BOLD}Claude Code:${NC} "
    if [ -f "$USER_BIN_DIR/claude" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Agents
    printf "${BOLD}Agents:${NC} "
    if [ -d "$CLAUDE_HOME_AGENTS" ]; then
        local agent_count=$(find "$CLAUDE_HOME_AGENTS" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l || echo 0)
        printf "${GREEN}✓ $agent_count agents${NC} in ~/agents\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Cron sync
    printf "${BOLD}Agent Sync:${NC} "
    if crontab -l 2>/dev/null | grep -q "sync-claude-agents"; then
        printf "${GREEN}✓ Active${NC} (every 5 minutes)\n"
    else
        printf "${YELLOW}✗ Not configured${NC}\n"
    fi
    
    # Statusline
    printf "${BOLD}Neovim Statusline:${NC} "
    if [ -f "$HOME/.config/nvim/lua/statusline.lua" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
    else
        printf "${YELLOW}✗ Not installed${NC}\n"
    fi
    
    # Node.js
    printf "${BOLD}Node.js:${NC} "
    if command -v node &> /dev/null; then
        printf "${GREEN}✓ $(node --version)${NC}\n"
    else
        printf "${YELLOW}✗ Not found${NC}\n"
    fi
    
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_quick_installation() {
    show_banner
    
    # First, try to find and run the main installer
    if find_and_run_main_installer "$@"; then
        exit 0
    fi
    
    # If main installer not found, continue with quick installation
    log "Starting quick installation..."
    echo
    
    # Create necessary directories
    mkdir -p "$HOME/Documents/Claude" 2>/dev/null || true
    mkdir -p "$WORK_DIR"
    
    # Step 1: Install Node.js if needed
    echo -n "Installing Node.js... "
    if install_node_if_needed &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Step 2: Install agents with proper discovery
    echo -n "Installing agents... "
    if install_agents_with_discovery &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Step 3: Setup agent sync
    echo -n "Setting up agent sync... "
    if setup_agent_sync &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Step 4: Install Claude Code
    echo -n "Installing Claude Code... "
    if install_claude_code &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Step 5: Deploy Neovim statusline
    echo -n "Installing statusline... "
    if deploy_neovim_statusline &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Step 6: Setup environment
    echo -n "Configuring environment... "
    if setup_environment &>/dev/null; then
        echo "✅"
    else
        echo "⚠️"
    fi
    
    # Show final status
    show_status
    
    success "Quick installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Run: source ~/.bashrc"
    echo "  2. Check: claude-agent-status"
    echo "  3. Launch: claude"
    echo
    echo "For LiveCD: claude is configured with auto permission bypass"
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERACTIVE MENU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_menu() {
    while true; do
        clear
        show_banner
        
        echo "Choose an option:"
        echo
        printf "${GREEN}1)${NC} Quick Install - Everything automatic\n"
        printf "${CYAN}2)${NC} Find & Run Main Installer\n"
        printf "${BLUE}3)${NC} Install Agents Only\n"
        printf "${MAGENTA}4)${NC} Install Claude Code Only\n"
        printf "${YELLOW}5)${NC} Check Installation Status\n"
        printf "${RED}6)${NC} Exit\n"
        echo
        
        echo -n "Enter your choice [1-6]: "
        read -r choice
        
        case "$choice" in
            1) 
                run_quick_installation
                break
                ;;
            2)
                if find_and_run_main_installer; then
                    exit 0
                else
                    echo "Main installer not found"
                    echo "Press ENTER to continue..."
                    read -r
                fi
                ;;
            3) 
                install_agents_with_discovery
                setup_agent_sync
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            4) 
                install_node_if_needed
                install_claude_code
                setup_environment
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            5) 
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            6) 
                printf "${GREEN}Thank you for using Claude quick launcher!${NC}\n"
                exit 0
                ;;
            *)
                error "Invalid choice. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Handle command line arguments
case "${1:-}" in
    --auto|--quick|-q)
        run_quick_installation
        ;;
    --menu|-m)
        main_menu
        ;;
    --help|-h)
        show_banner
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --auto, --quick, -q    Run automatic installation"
        echo "  --menu, -m             Show interactive menu"
        echo "  --help, -h             Show this help"
        echo
        echo "This script will:"
        echo "  1. Try to find and run the main installer"
        echo "  2. If not found, run quick installation"
        echo
        echo "Project Root: $PROJECT_ROOT"
        echo "Agents Source: $SOURCE_AGENTS_DIR"
        echo "Install Directory: $USER_BIN_DIR"
        ;;
    *)
        # Default: run automatic installation
        run_quick_installation
        ;;
esac
