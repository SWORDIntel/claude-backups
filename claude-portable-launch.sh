#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE PORTABLE LAUNCHER FOR LIVECD
# Self-contained installation in single directory
# Version 3.0.0 - Ultra-portable with local everything
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get the directory where this script is located - EVERYTHING goes here
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PORTABLE_DIR="$SCRIPT_DIR/claude-portable"
readonly WORK_DIR="$PORTABLE_DIR/.tmp-$$"
readonly LOG_FILE="$PORTABLE_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Subdirectories for portable installation
readonly NODE_DIR="$PORTABLE_DIR/node"
readonly CLAUDE_DIR="$PORTABLE_DIR/claude-code"
readonly AGENTS_DIR="$PORTABLE_DIR/agents"
readonly BIN_DIR="$PORTABLE_DIR/bin"
readonly CONFIG_DIR="$PORTABLE_DIR/config"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { echo -e "${GREEN}[PORTABLE]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${GREEN}[PORTABLE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

cleanup() {
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETUP PORTABLE DIRECTORY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_portable_dir() {
    log "Setting up portable directory structure..."
    
    # Create all necessary directories
    mkdir -p "$PORTABLE_DIR"
    mkdir -p "$NODE_DIR"
    mkdir -p "$CLAUDE_DIR"
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$WORK_DIR"
    
    # Copy agents if they exist locally
    if [ -d "$SCRIPT_DIR/agents" ]; then
        info "Copying local agents..."
        cp -r "$SCRIPT_DIR/agents"/* "$AGENTS_DIR/" 2>/dev/null || true
        success "Agents copied to portable directory"
    elif [ -d "/home/ubuntu/Documents/Claude/agents" ]; then
        info "Copying agents from Documents..."
        cp -r "/home/ubuntu/Documents/Claude/agents"/* "$AGENTS_DIR/" 2>/dev/null || true
        success "Agents copied to portable directory"
    fi
    
    # Copy scripts if they exist
    if [ -d "$SCRIPT_DIR/scripts" ]; then
        cp -r "$SCRIPT_DIR/scripts" "$PORTABLE_DIR/" 2>/dev/null || true
    fi
    
    success "Portable directory structure created"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALL NODE.JS LOCALLY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_portable() {
    if [ -f "$NODE_DIR/bin/node" ] && [ -f "$NODE_DIR/bin/npm" ]; then
        info "Node.js already installed in portable directory"
        export PATH="$NODE_DIR/bin:$PATH"
        return 0
    fi
    
    log "Installing Node.js to portable directory..."
    
    local NODE_VERSION="v20.11.0"
    local NODE_ARCH="linux-x64"
    local NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.xz"
    
    cd "$WORK_DIR"
    
    info "Downloading Node.js ${NODE_VERSION}..."
    if wget -q "$NODE_URL" -O node.tar.xz || curl -fsSL "$NODE_URL" -o node.tar.xz; then
        tar -xf node.tar.xz
        
        # Move to portable directory
        cp -r "node-${NODE_VERSION}-${NODE_ARCH}"/* "$NODE_DIR/"
        
        # Make binaries executable
        chmod +x "$NODE_DIR/bin/node"
        chmod +x "$NODE_DIR/bin/npm"
        chmod +x "$NODE_DIR/bin/npx"
        
        # Set PATH for this session
        export PATH="$NODE_DIR/bin:$PATH"
        
        success "Node.js installed: $(node --version)"
        success "npm installed: $(npm --version)"
    else
        error "Failed to download Node.js"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALL CLAUDE CODE LOCALLY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_claude_portable() {
    log "Installing Claude Code to portable directory..."
    
    # Ensure npm is in PATH
    export PATH="$NODE_DIR/bin:$PATH"
    
    # Set npm prefix to our portable directory
    export NPM_CONFIG_PREFIX="$CLAUDE_DIR"
    
    # Install Claude Code
    info "Installing @anthropic-ai/claude-code..."
    if npm install -g @anthropic-ai/claude-code 2>&1 | tee -a "$LOG_FILE"; then
        success "Claude Code installed successfully"
        
        # Find the installed binary
        local claude_bin="$CLAUDE_DIR/bin/claude"
        if [ -f "$claude_bin" ]; then
            # Create wrapper in our bin directory
            cat > "$BIN_DIR/claude" <<EOF
#!/bin/bash
# Claude Code portable wrapper

# Set up portable environment
export PATH="$NODE_DIR/bin:\$PATH"
export NPM_CONFIG_PREFIX="$CLAUDE_DIR"
export CLAUDE_AGENTS_DIR="$AGENTS_DIR"

# Execute Claude with permission bypass for LiveCD
exec "$claude_bin" --dangerously-skip-permissions "\$@"
EOF
            chmod +x "$BIN_DIR/claude"
            success "Claude wrapper created"
        else
            warn "Claude binary not found at expected location"
        fi
    else
        warn "Failed to install Claude Code via npm"
        create_claude_fallback
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CREATE FALLBACK CLAUDE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_claude_fallback() {
    warn "Creating fallback Claude launcher..."
    
    cat > "$BIN_DIR/claude" <<'EOF'
#!/bin/bash
echo "Claude Code - Portable Edition"
echo "Note: Official Claude Code installation failed"
echo ""
echo "To install manually:"
echo "  export PATH=$NODE_DIR/bin:\$PATH"
echo "  npm install -g @anthropic-ai/claude-code"
echo ""
echo "Agents directory: $AGENTS_DIR"
echo "Found $(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l) agent configurations"
EOF
    chmod +x "$BIN_DIR/claude"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPILE AGENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

compile_agents() {
    log "Compiling agent binaries..."
    
    if [ ! -d "$AGENTS_DIR" ] || [ -z "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]; then
        warn "No agents found to compile"
        return 0
    fi
    
    cd "$AGENTS_DIR"
    
    # Check for C compiler
    if ! command -v gcc &> /dev/null; then
        warn "gcc not found - skipping C compilation"
        return 0
    fi
    
    # Detect CPU features for optimization
    local CFLAGS="-O2 -pthread"
    if grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
        CFLAGS="$CFLAGS -mavx2"
        info "AVX2 optimizations enabled"
    fi
    
    # Compile C files if they exist
    local c_files=($(find . -name "*.c" -type f 2>/dev/null | head -10))
    
    if [ ${#c_files[@]} -gt 0 ]; then
        mkdir -p build
        
        for src in "${c_files[@]}"; do
            local name=$(basename "$src" .c)
            info "Compiling $name..."
            
            if gcc $CFLAGS -o "build/$name" "$src" -lm -lpthread 2>/dev/null; then
                chmod +x "build/$name"
                success "Compiled: $name"
            else
                warn "Failed to compile: $name"
            fi
        done
    fi
    
    cd - > /dev/null
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CREATE LAUNCH SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_launch_script() {
    log "Creating portable launch script..."
    
    local launcher="$PORTABLE_DIR/launch-claude.sh"
    
    cat > "$launcher" <<EOF
#!/bin/bash
# Claude Code Portable Launcher
# Auto-generated on $(date)

# Set up portable environment
export PATH="$NODE_DIR/bin:$BIN_DIR:\$PATH"
export NPM_CONFIG_PREFIX="$CLAUDE_DIR"
export CLAUDE_AGENTS_DIR="$AGENTS_DIR"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\${GREEN}═══════════════════════════════════════════════════════════\${NC}"
echo -e "\${GREEN}    Claude Code Portable Edition\${NC}"
echo -e "\${GREEN}═══════════════════════════════════════════════════════════\${NC}"
echo
echo -e "\${CYAN}Installation Directory:\${NC} $PORTABLE_DIR"
echo -e "\${CYAN}Node.js Version:\${NC} \$(node --version 2>/dev/null || echo 'Not found')"
echo -e "\${CYAN}Claude Version:\${NC} \$(claude --version 2>/dev/null || echo 'Not found')"
echo -e "\${CYAN}Agents:\${NC} \$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l) configurations"
echo

# Check if this is first run
if [ ! -f "$CONFIG_DIR/.configured" ]; then
    echo "First run detected. Launching configuration..."
    echo
    "$BIN_DIR/claude" /config
    touch "$CONFIG_DIR/.configured"
    echo
    echo "Configuration complete. Launching Claude Code..."
    echo
fi

# Launch Claude
exec "$BIN_DIR/claude" "\$@"
EOF
    
    chmod +x "$launcher"
    
    # Create desktop shortcut if Desktop exists
    if [ -d "$HOME/Desktop" ]; then
        cat > "$HOME/Desktop/claude-portable.desktop" <<EOF
[Desktop Entry]
Name=Claude Code Portable
Comment=Launch Claude Code Portable Edition
Exec=$launcher
Icon=terminal
Terminal=true
Type=Application
Categories=Development;
EOF
        chmod +x "$HOME/Desktop/claude-portable.desktop" 2>/dev/null || true
    fi
    
    success "Launch script created: $launcher"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}    Claude Code Portable Installer for LiveCD${NC}"
    echo -e "${BOLD}${CYAN}    Everything in one directory: $PORTABLE_DIR${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Step 1: Setup portable directory
    setup_portable_dir
    
    # Step 2: Install Node.js locally
    install_node_portable
    
    # Step 3: Install Claude Code
    install_claude_portable
    
    # Step 4: Compile agents
    compile_agents
    
    # Step 5: Create launch script
    create_launch_script
    
    # Summary
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}    Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${CYAN}Portable directory:${NC} $PORTABLE_DIR"
    echo -e "${CYAN}Size:${NC} $(du -sh "$PORTABLE_DIR" 2>/dev/null | cut -f1)"
    echo
    echo -e "${YELLOW}To launch Claude:${NC}"
    echo -e "  ${BOLD}$PORTABLE_DIR/launch-claude.sh${NC}"
    echo
    echo -e "${YELLOW}Or add to PATH:${NC}"
    echo -e "  export PATH=\"$BIN_DIR:\$PATH\""
    echo -e "  claude"
    echo
    
    # Ask if user wants to launch now
    echo -n "Launch Claude Code now? (Y/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]] || [ -z "$response" ]; then
        echo
        exec "$PORTABLE_DIR/launch-claude.sh"
    fi
}

# Run main
main "$@"