#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ALL-IN-ONE INSTALLER WITH GITHUB AGENTS
# Complete installation without external dependencies
# Version 3.1 - LiveCD optimized with DEFAULT permission bypass
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="3.1-all-in-one"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="/tmp/claude-install-$$"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# GitHub Configuration - UPDATE THIS WITH YOUR REPO
readonly GITHUB_REPO="https://github.com/SWORDIntel/claude-backups"  # CHANGE THIS
readonly GITHUB_BRANCH="main"

# Installation paths
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly AGENTS_DIR="$HOME/.local/share/claude/agents"
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
                                                           
    All-in-One Installer v3.1 - LiveCD Optimized Edition
           WITH DEFAULT PERMISSION BYPASS
EOF
    printf "${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT INSTALLATION FROM GITHUB
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents_from_github() {
    log "Installing agents from GitHub repository..."
    
    # Create agents directory
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$WORK_DIR"
    
    # Method 1: Try local agents first
    if [ -d "$SCRIPT_DIR/agents" ]; then
        log "Found local agents directory"
        cp -r "$SCRIPT_DIR/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        if [ "$agent_count" -gt 0 ]; then
            success "Installed $agent_count agents from local directory"
            return 0
        fi
    fi
    
    cd "$WORK_DIR"
    
    # Method 2: Git clone (if git available)
    if command -v git &> /dev/null; then
        log "Cloning agents from GitHub..."
        if git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO" repo 2>/dev/null; then
            cd repo
            git sparse-checkout set agents 2>/dev/null || true
            
            if [ -d "agents" ]; then
                cp -r agents/* "$AGENTS_DIR/" 2>/dev/null || true
                local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
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
            local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
            success "Downloaded $agent_count agents from GitHub archive"
            return 0
        fi
    fi
    
    # Method 4: Create sample agents if download fails
    warn "Could not download agents from GitHub, creating sample agents..."
    create_sample_agents
    return 0
}

create_sample_agents() {
    cat > "$AGENTS_DIR/Director.md" << 'EOF'
# Director Agent
## Role
Project orchestration and task delegation

## Capabilities
- Task breakdown and assignment
- Progress monitoring
- Resource coordination
EOF

    cat > "$AGENTS_DIR/Security.md" << 'EOF'
# Security Agent
## Role
Security analysis and vulnerability assessment

## Capabilities
- Code security review
- Vulnerability scanning
- Security best practices
EOF

    cat > "$AGENTS_DIR/Testing.md" << 'EOF'
# Testing Agent
## Role
Test creation and quality assurance

## Capabilities
- Unit test generation
- Integration testing
- Test coverage analysis
EOF

    success "Created 3 sample agents"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NEOVIM STATUSLINE DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_neovim_statusline() {
    local statusline_src="$SCRIPT_DIR/statusline.lua"
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_lua_dir="$nvim_config_dir/lua"
    
    # Check if statusline.lua exists locally
    if [ ! -f "$statusline_src" ]; then
        # Try to download from GitHub
        log "Downloading statusline.lua from GitHub..."
        local statusline_url="${GITHUB_REPO}/raw/${GITHUB_BRANCH}/statusline.lua"
        
        mkdir -p "$WORK_DIR"
        if command -v wget &> /dev/null; then
            wget -q "$statusline_url" -O "$WORK_DIR/statusline.lua" 2>/dev/null || true
        elif command -v curl &> /dev/null; then
            curl -fsSL "$statusline_url" -o "$WORK_DIR/statusline.lua" 2>/dev/null || true
        fi
        
        if [ -f "$WORK_DIR/statusline.lua" ]; then
            statusline_src="$WORK_DIR/statusline.lua"
        else
            warn "statusline.lua not found"
            return 1
        fi
    fi
    
    log "Deploying Neovim statusline..."
    
    # Create directories
    mkdir -p "$nvim_lua_dir"
    mkdir -p "$AGENTS_DIR"
    
    # Copy statusline to both locations
    cp "$statusline_src" "$nvim_lua_dir/statusline.lua"
    cp "$statusline_src" "$AGENTS_DIR/statusline.lua"
    
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
# CLAUDE CODE INSTALLATION WITH DEFAULT PERMISSION BYPASS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_if_needed() {
    if command -v node &> /dev/null; then
        log "Node.js found: $(node --version)"
        return 0
    fi
    
    log "Installing Node.js locally..."
    warn "This may take a few minutes on first run..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    local node_version="v20.11.0"
    local node_arch="linux-x64"
    local node_url="https://nodejs.org/dist/${node_version}/node-${node_version}-${node_arch}.tar.gz"
    
    log "Downloading Node.js ${node_version}..."
    if command -v wget &> /dev/null; then
        wget --progress=bar:force "$node_url" -O node.tar.gz 2>&1 | grep -E 'ETA|%' || return 1
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar "$node_url" -o node.tar.gz || return 1
    else
        error "Neither wget nor curl available"
        return 1
    fi
    
    log "Extracting Node.js..."
    tar -xzf node.tar.gz
    mkdir -p "$LOCAL_NODE_DIR"
    cp -r "node-${node_version}-${node_arch}"/* "$LOCAL_NODE_DIR/"
    
    export PATH="$LOCAL_NODE_DIR/bin:$PATH"
    success "Node.js installed locally"
    return 0
}

install_claude_code() {
    log "Installing Claude Code..."
    
    # Create directories
    mkdir -p "$USER_BIN_DIR"
    
    # Try npm installation first
    if command -v npm &> /dev/null; then
        log "Attempting npm installation..."
        
        mkdir -p "$LOCAL_NPM_PREFIX"
        export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
        export PATH="$LOCAL_NPM_PREFIX/bin:$PATH"
        
        # Try different package names
        npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        npm install -g claude-code 2>/dev/null || \
        npm install -g claude 2>/dev/null || true
        
        # Check if installed and create wrapper
        if [ -f "$LOCAL_NPM_PREFIX/bin/claude" ]; then
            # Move original binary
            mv "$LOCAL_NPM_PREFIX/bin/claude" "$LOCAL_NPM_PREFIX/bin/claude.original"
            
            # Create wrapper that always adds --dangerously-skip-permissions
            cat > "$LOCAL_NPM_PREFIX/bin/claude" << 'CLAUDE_WRAPPER'
#!/bin/bash
# Claude wrapper with automatic permission bypass for LiveCD
exec "$HOME/.local/npm-global/bin/claude.original" --dangerously-skip-permissions "$@"
CLAUDE_WRAPPER
            chmod +x "$LOCAL_NPM_PREFIX/bin/claude"
            CLAUDE_BINARY="$LOCAL_NPM_PREFIX/bin/claude"
            success "Claude Code installed via npm with permission bypass"
            return 0
        fi
    fi
    
    # Try pip installation
    if command -v pip3 &> /dev/null; then
        log "Attempting pip installation..."
        pip3 install --user claude-code 2>/dev/null || \
        pip3 install --user anthropic 2>/dev/null || true
        
        # Check if installed and create wrapper
        if [ -f "$HOME/.local/bin/claude" ]; then
            # Move original binary
            mv "$HOME/.local/bin/claude" "$HOME/.local/bin/claude.original"
            
            # Create wrapper
            cat > "$HOME/.local/bin/claude" << 'CLAUDE_WRAPPER'
#!/bin/bash
# Claude wrapper with automatic permission bypass for LiveCD
exec "$HOME/.local/bin/claude.original" --dangerously-skip-permissions "$@"
CLAUDE_WRAPPER
            chmod +x "$HOME/.local/bin/claude"
            CLAUDE_BINARY="$HOME/.local/bin/claude"
            success "Claude Code installed via pip with permission bypass"
            return 0
        fi
    fi
    
    # Create functional stub as fallback WITH PERMISSION BYPASS BY DEFAULT
    log "Creating Claude Code launcher with default permission bypass..."
    cat > "$USER_BIN_DIR/claude" << 'CLAUDE_STUB'
#!/bin/bash
# Claude Code Launcher with DEFAULT Permission Bypass

# Set environment
export CLAUDE_AGENTS_DIR="$HOME/.local/share/claude/agents"
export CLAUDE_AGENTS_ROOT="$CLAUDE_AGENTS_DIR"

# Check for actual Claude binary
CLAUDE_ACTUAL=""
for loc in "$HOME/.local/npm-global/bin/claude.original" "$HOME/.local/bin/claude.original" "$(which claude-actual 2>/dev/null)"; do
    if [ -f "$loc" ] && [ -x "$loc" ] && [ "$loc" != "$0" ]; then
        CLAUDE_ACTUAL="$loc"
        break
    fi
done

if [ -n "$CLAUDE_ACTUAL" ]; then
    # ALWAYS add --dangerously-skip-permissions unless explicitly disabled
    if [[ " $@ " == *" --no-skip-permissions "* ]]; then
        # Remove our custom flag and run without permission skip
        args="${@//--no-skip-permissions/}"
        exec "$CLAUDE_ACTUAL" $args
    else
        # DEFAULT: Always add permission bypass
        exec "$CLAUDE_ACTUAL" --dangerously-skip-permissions "$@"
    fi
else
    echo "Claude Code v1.0 (LiveCD Stub with Auto Permission Bypass)"
    echo ""
    echo "This launcher automatically includes --dangerously-skip-permissions"
    echo "To disable: use --no-skip-permissions flag"
    echo ""
    echo "To install the official Claude Code, run:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Arguments received: $@"
    
    # Basic command handling
    case "$1" in
        --version)
            echo "1.0.0-livecd-stub"
            ;;
        --help)
            echo "Usage: claude [options] [command]"
            echo "Options:"
            echo "  --version                      Show version"
            echo "  --help                         Show this help"
            echo "  --no-skip-permissions          Disable automatic permission bypass"
            echo ""
            echo "NOTE: Permission bypass (--dangerously-skip-permissions) is"
            echo "      applied BY DEFAULT for LiveCD compatibility"
            ;;
        *)
            echo ""
            echo "Agents directory: $CLAUDE_AGENTS_DIR"
            local agent_count=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
            echo "Agents available: $agent_count"
            echo ""
            echo "Permission bypass: ENABLED (default for LiveCD)"
            ;;
    esac
fi
CLAUDE_STUB
    
    chmod +x "$USER_BIN_DIR/claude"
    CLAUDE_BINARY="$USER_BIN_DIR/claude"
    success "Claude launcher created with DEFAULT permission bypass"
    return 0
}

# Also create a 'claude-normal' command for running WITHOUT permission bypass
create_claude_normal_command() {
    cat > "$USER_BIN_DIR/claude-normal" << 'CLAUDE_NORMAL'
#!/bin/bash
# Claude launcher WITHOUT automatic permission bypass
exec claude --no-skip-permissions "$@"
CLAUDE_NORMAL
    chmod +x "$USER_BIN_DIR/claude-normal"
    log "Created 'claude-normal' command for non-LiveCD use"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_environment() {
    log "Setting up environment..."
    
    # Export variables for current session
    export CLAUDE_AGENTS_DIR="$AGENTS_DIR"
    export CLAUDE_AGENTS_ROOT="$AGENTS_DIR"
    export PATH="$USER_BIN_DIR:$LOCAL_NODE_DIR/bin:$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Update shell configuration
    local shell_rc="$HOME/.bashrc"
    [ -n "${ZSH_VERSION:-}" ] && shell_rc="$HOME/.zshrc"
    
    # Add PATH
    if ! grep -q "$USER_BIN_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$shell_rc"
    fi
    
    if [ -d "$LOCAL_NODE_DIR" ] && ! grep -q "$LOCAL_NODE_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$LOCAL_NODE_DIR/bin:\$PATH\"" >> "$shell_rc"
    fi
    
    if [ -d "$LOCAL_NPM_PREFIX" ] && ! grep -q "$LOCAL_NPM_PREFIX" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$LOCAL_NPM_PREFIX/bin:\$PATH\"" >> "$shell_rc"
    fi
    
    # Add agent environment variables
    if ! grep -q "CLAUDE_AGENTS_DIR" "$shell_rc" 2>/dev/null; then
        echo "export CLAUDE_AGENTS_DIR=\"$AGENTS_DIR\"" >> "$shell_rc"
        echo "export CLAUDE_AGENTS_ROOT=\"$AGENTS_DIR\"" >> "$shell_rc"
    fi
    
    # Add alias for convenience
    if ! grep -q "alias claude-safe" "$shell_rc" 2>/dev/null; then
        echo "# Claude aliases for LiveCD" >> "$shell_rc"
        echo "alias claude-safe='claude --no-skip-permissions'  # Run without permission bypass" >> "$shell_rc"
    fi
    
    success "Environment configured"
    
    # Create the alternative command
    create_claude_normal_command
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
    if [ -n "$CLAUDE_BINARY" ] && [ -f "$CLAUDE_BINARY" ]; then
        printf "${GREEN}✓ Installed${NC} at $CLAUDE_BINARY\n"
        printf "  ${YELLOW}Permission bypass: ENABLED by default${NC}\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Agents
    printf "${BOLD}Agents:${NC} "
    if [ -d "$AGENTS_DIR" ]; then
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        printf "${GREEN}✓ $agent_count agents${NC} in $AGENTS_DIR\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
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
    printf "${BOLD}${CYAN}Commands:${NC}\n"
    echo "  claude         - Launch WITH permission bypass (default)"
    echo "  claude-normal  - Launch WITHOUT permission bypass"
    echo "  claude-safe    - Alias for claude --no-skip-permissions"
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_installation() {
    # Create necessary directories
    mkdir -p "$HOME/Documents/Claude" 2>/dev/null || true
    mkdir -p "$WORK_DIR"
    
    show_banner
    
    log "Starting all-in-one installation..."
    warn "DEFAULT: Permission bypass will be ENABLED for LiveCD compatibility"
    echo
    
    # Step 1: Install Node.js if needed
    install_node_if_needed
    echo
    
    # Step 2: Install agents from GitHub
    install_agents_from_github
    echo
    
    # Step 3: Install Claude Code with permission bypass wrapper
    install_claude_code
    echo
    
    # Step 4: Deploy Neovim statusline
    deploy_neovim_statusline
    echo
    
    # Step 5: Setup environment
    setup_environment
    
    # Show final status
    show_status
    
    success "Installation complete!"
    echo
    echo "To complete setup:"
    echo "  1. Run: source ~/.bashrc"
    echo "  2. Launch Claude: claude"
    echo
    printf "${YELLOW}${BOLD}IMPORTANT:${NC} Permission bypass is ${GREEN}ENABLED BY DEFAULT${NC}\n"
    echo "  - Use 'claude' for LiveCD (with permission bypass)"
    echo "  - Use 'claude-normal' or 'claude-safe' for regular use"
    echo
    
    # Ask if user wants to launch Claude now
    echo -n "Launch Claude Code now? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -n "$CLAUDE_BINARY" ] && [ -f "$CLAUDE_BINARY" ]; then
            log "Launching Claude with permission bypass..."
            exec "$CLAUDE_BINARY"  # The wrapper already includes --dangerously-skip-permissions
        else
            warn "Claude binary not found. Run 'source ~/.bashrc' first."
        fi
    fi
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
        printf "${GREEN}1)${NC} Quick Install - Everything automatic (with permission bypass)\n"
        printf "${CYAN}2)${NC} Install Agents Only\n"
        printf "${BLUE}3)${NC} Install Claude Code Only\n"
        printf "${MAGENTA}4)${NC} Install Statusline Only\n"
        printf "${YELLOW}5)${NC} Check Installation Status\n"
        printf "${RED}6)${NC} Exit\n"
        echo
        
        echo -n "Enter your choice [1-6]: "
        read -r choice
        
        case "$choice" in
            1) 
                run_installation
                break
                ;;
            2) 
                install_agents_from_github
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            3) 
                install_node_if_needed
                install_claude_code
                setup_environment
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            4) 
                deploy_neovim_statusline
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
                printf "${GREEN}Thank you for using Claude installer!${NC}\n"
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
        run_installation
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
        echo "Without options, runs automatic installation"
        echo
        echo "PERMISSION BYPASS: ENABLED BY DEFAULT"
        echo "  claude         - Runs WITH permission bypass (default)"
        echo "  claude-normal  - Runs WITHOUT permission bypass"
        echo "  claude-safe    - Alias for --no-skip-permissions"
        echo
        echo "GitHub Repository: $GITHUB_REPO"
        echo "Agents Directory:  $AGENTS_DIR"
        echo "Install Directory: $USER_BIN_DIR"
        ;;
    *)
        # Default: run automatic installation
        run_installation
        ;;
esac