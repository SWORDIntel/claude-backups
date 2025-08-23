#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Master Installer v8.0 - Professional Edition
# Clean, robust, and fully automated installation
# ═══════════════════════════════════════════════════════════════════════════

# Disable strict mode for force installation
set +e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION & SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Fix color output issues
export TERM=xterm-256color

# Define colors using printf for better compatibility
print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_blue() { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_magenta() { printf "\033[0;35m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }
print_dim() { printf "\033[2m%s\033[0m\n" "$1"; }

# Status indicators
SUCCESS="✓"
ERROR="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"

# Detect project root
if [[ -d "./agents" ]] && [[ -f "./CLAUDE.md" ]]; then
    PROJECT_ROOT="$(pwd)"
elif [[ -d "$HOME/Documents/Claude/agents" ]]; then
    PROJECT_ROOT="$HOME/Documents/Claude"
else
    PROJECT_ROOT="$(pwd)"
fi

# Define all paths
HOME_DIR="$HOME"
LOCAL_BIN="$HOME_DIR/.local/bin"
NPM_PREFIX="$HOME_DIR/.npm-global"
CLAUDE_HOME="$HOME_DIR/.claude-home"
AGENTS_SOURCE="$PROJECT_ROOT/agents"
AGENTS_TARGET="$HOME_DIR/agents"
CONFIG_DIR="$HOME_DIR/.config/claude"
HOOKS_SOURCE="$PROJECT_ROOT/hooks"
STATUSLINE_SOURCE="$PROJECT_ROOT/statusline.lua"
LOG_DIR="$HOME_DIR/.local/share/claude/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Claude directory structure (for self-contained mode)
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Installation counters
TOTAL_STEPS=13
CURRENT_STEP=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR" 2>/dev/null

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
    echo "$1"
}

# Progress bar
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' ']'
    printf "] %3d%% " "$percent"
}

# Print header
print_header() {
    clear
    echo ""
    print_cyan "╔═══════════════════════════════════════════════════════════════╗"
    print_cyan "║           Claude Master Installer v8.0                       ║"
    print_cyan "║           Professional Agent Framework Setup                 ║"
    print_cyan "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    print_dim "Project: $PROJECT_ROOT"
    print_dim "Target: $HOME_DIR"
    echo ""
}

# Print section
print_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_bold "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Status messages
success() {
    print_green "$SUCCESS $1"
    log "SUCCESS: $1"
}

error() {
    print_red "$ERROR $1"
    log "ERROR: $1"
}

warning() {
    print_yellow "$WARNING $1"
    log "WARNING: $1"
}

info() {
    print_cyan "$INFO $1"
    log "INFO: $1"
}

# Force directory creation
force_mkdir() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir" 2>/dev/null
    sudo chown -R "$USER:$USER" "$dir" 2>/dev/null
}

# Force copy with permissions
force_copy() {
    local src="$1"
    local dst="$2"
    
    # Create destination directory
    force_mkdir "$(dirname "$dst")"
    
    # Try multiple copy methods
    cp -rf "$src" "$dst" 2>/dev/null || \
    sudo cp -rf "$src" "$dst" 2>/dev/null || \
    rsync -a "$src" "$dst" 2>/dev/null || \
    tar cf - -C "$(dirname "$src")" "$(basename "$src")" | tar xf - -C "$(dirname "$dst")" 2>/dev/null
    
    # Fix permissions
    sudo chown -R "$USER:$USER" "$dst" 2>/dev/null
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Node.js
    printf "  %-20s" "Node.js..."
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node -v)
        print_green "$SUCCESS ($NODE_VERSION)"
    else
        print_red "$ERROR Not installed"
        warning "    Installing Node.js is recommended"
    fi
    
    # npm
    printf "  %-20s" "npm..."
    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm -v)
        print_green "$SUCCESS (v$NPM_VERSION)"
    else
        print_red "$ERROR Not installed"
    fi
    
    # Disk space
    printf "  %-20s" "Disk space..."
    AVAILABLE=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE -gt 100000 ]]; then
        print_green "$SUCCESS ($(numfmt --to=iec $((AVAILABLE * 1024))))"
    else
        print_yellow "$WARNING Low space"
    fi
    
    show_progress
}

# 2. Install NPM package
install_npm_package() {
    print_section "Installing Claude NPM Package"
    
    # Configure npm
    info "Configuring npm prefix..."
    force_mkdir "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX" 2>/dev/null
    export PATH="$NPM_PREFIX/bin:$PATH"
    
    # Check if installed
    if npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "@anthropic-ai/claude-code"; then
        success "Package already installed"
    else
        info "Installing @anthropic-ai/claude-code..."
        npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        sudo npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        npm install -g @anthropic-ai/claude-code --force 2>/dev/null
    fi
    
    # Find CLI path
    CLAUDE_CLI_PATH="$NPM_PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    if [[ -f "$CLAUDE_CLI_PATH" ]]; then
        success "CLI found at: $CLAUDE_CLI_PATH"
        CLAUDE_BINARY="$CLAUDE_CLI_PATH"
    else
        # Search for it
        CLAUDE_CLI_PATH=$(find "$NPM_PREFIX" -name "cli.js" -path "*claude-code*" 2>/dev/null | head -1)
        CLAUDE_BINARY="${CLAUDE_CLI_PATH:-$NPM_PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli.js}"
    fi
    
    show_progress
}

# 3. Install agents
install_agents() {
    print_section "Installing Agent System"
    
    # Create target directory
    force_mkdir "$AGENTS_TARGET"
    
    if [[ ! -d "$AGENTS_SOURCE" ]]; then
        warning "No agents source found at: $AGENTS_SOURCE"
        info "Skipping agent installation - directory will be ready for manual setup"
    else
        info "Updating agent files from $AGENTS_SOURCE..."
        
        # Count source agents (only .md files in root of agents directory)
        SOURCE_COUNT=$(find "$AGENTS_SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        info "Found $SOURCE_COUNT agent files"
        
        if [[ $SOURCE_COUNT -gt 0 ]]; then
            # Force copy all .md/.MD files from the root agents directory (overwrite existing)
            find "$AGENTS_SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) -exec cp -f {} "$AGENTS_TARGET/" \; 2>/dev/null
            
            # Fix permissions
            sudo chown -R "$USER:$USER" "$AGENTS_TARGET" 2>/dev/null
            
            # Verify
            INSTALLED_COUNT=$(find "$AGENTS_TARGET" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
            if [[ $INSTALLED_COUNT -gt 0 ]]; then
                success "Installed/Updated $INSTALLED_COUNT agents (overwrote existing)"
            else
                warning "Failed to copy agents"
            fi
        else
            info "No agent files found in root of source directory"
        fi
    fi
    
    show_progress
}

# 4. Install hooks
install_hooks() {
    print_section "Installing Hooks"
    
    if [[ -d "$HOOKS_SOURCE" ]]; then
        force_mkdir "$CONFIG_DIR/hooks"
        cp -r "$HOOKS_SOURCE"/* "$CONFIG_DIR/hooks/" 2>/dev/null
        chmod -R +x "$CONFIG_DIR/hooks" 2>/dev/null
        
        HOOK_COUNT=$(find "$CONFIG_DIR/hooks" -type f 2>/dev/null | wc -l)
        success "Installed $HOOK_COUNT hooks"
    else
        warning "No hooks found"
    fi
    
    show_progress
}

# 5. Install statusline
install_statusline() {
    print_section "Installing Statusline"
    
    if [[ -f "$STATUSLINE_SOURCE" ]]; then
        force_mkdir "$HOME/.config/nvim/lua"
        cp "$STATUSLINE_SOURCE" "$HOME/.config/nvim/lua/claude-statusline.lua" 2>/dev/null
        
        if ! grep -q "claude-statusline" "$HOME/.config/nvim/init.lua" 2>/dev/null; then
            echo "require('claude-statusline')" >> "$HOME/.config/nvim/init.lua"
        fi
        
        success "Statusline installed"
    else
        warning "No statusline found"
    fi
    
    show_progress
}

# 6. Setup .claude directory structure
setup_claude_directory() {
    print_section "Setting up .claude Directory Structure"
    
    info "Creating self-contained .claude directory..."
    
    # Create .claude directory
    force_mkdir "$CLAUDE_DIR"
    
    # Create symlinks for all major directories
    for dir in agents config hooks database docs scripts tools orchestration installers bin; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            # Remove existing symlink or directory in .claude
            rm -rf "$CLAUDE_DIR/$dir" 2>/dev/null
            # Create symlink (relative path for portability)
            ln -sf "../$dir" "$CLAUDE_DIR/$dir"
            success "Linked .claude/$dir -> ../$dir"
        fi
    done
    
    # Create settings file if it doesn't exist
    if [[ ! -f "$CLAUDE_DIR/settings.local.json" ]]; then
        cat > "$CLAUDE_DIR/settings.local.json" << 'EOF'
{
  "claude_project_root": "auto",
  "self_contained": true,
  "use_symlinks": true,
  "directories": {
    "agents": "./agents",
    "config": "./config",
    "hooks": "./hooks",
    "database": "./database",
    "docs": "./docs",
    "scripts": "./scripts",
    "tools": "./tools",
    "orchestration": "./orchestration"
  }
}
EOF
        success "Created .claude/settings.local.json"
    fi
    
    success ".claude directory structure created with symlinks"
    show_progress
}

# 6.5. Setup precision orchestration style
setup_precision_style() {
    print_section "Setting up Precision Orchestration Style"
    
    if [[ -f "$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh" ]]; then
        info "Running precision orchestration style setup..."
        bash "$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh" --reinstall 2>&1 | while read line; do
            echo "  $line"
        done
        success "Precision orchestration style configured"
    else
        warning "Precision orchestration setup script not found"
    fi
    
    show_progress
}

# 6.6. Setup tandem orchestration
setup_tandem_orchestration() {
    print_section "Setting up Tandem Orchestration"
    
    if [[ -f "$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh" ]]; then
        info "Running tandem orchestration setup..."
        bash "$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh" 2>&1 | while read line; do
            echo "  $line"
        done
        success "Tandem orchestration configured"
    else
        warning "Tandem orchestration setup script not found"
    fi
    
    show_progress
}

# 6.7. Validate agent files
validate_agents() {
    print_section "Validating Agent Files"
    
    # Check if validation script exists
    if [[ -f "$PROJECT_ROOT/scripts/validate_all_agents.py" ]]; then
        info "Validating agent YAML frontmatter..."
        
        # Run validation
        local validation_output=$(python3 "$PROJECT_ROOT/scripts/validate_all_agents.py" 2>&1)
        local exit_code=$?
        
        # Show output with indentation
        echo "$validation_output" | while read line; do
            if [[ "$line" == *"✅"* ]]; then
                # Don't show all valid agents to reduce clutter
                continue
            elif [[ "$line" == *"❌"* ]]; then
                # Show invalid agents as warnings
                warning "  $line"
            elif [[ "$line" == *"Summary:"* ]]; then
                # Show summary
                echo "  $line"
            elif [[ "$line" == *"All agent files are valid"* ]]; then
                success "  $line"
            fi
        done
        
        # Extract summary
        local summary=$(echo "$validation_output" | grep "Summary:" || echo "")
        if [[ -n "$summary" ]]; then
            # Parse valid and invalid counts
            local valid_count=$(echo "$summary" | grep -o "[0-9]* valid" | grep -o "[0-9]*")
            local invalid_count=$(echo "$summary" | grep -o "[0-9]* invalid" | grep -o "[0-9]*")
            
            if [[ "$invalid_count" == "0" ]]; then
                success "All $valid_count agent files validated successfully"
            else
                warning "$invalid_count agent files have validation issues"
                info "Agent files with issues will still work but may not be discoverable by Task tool"
            fi
        fi
    else
        warning "Agent validation script not found"
        info "Skipping validation - agents will work but should be validated"
    fi
    
    show_progress
}

# 7. Create wrapper
create_wrapper() {
    print_section "Creating Enhanced Claude Wrapper"
    
    force_mkdir "$LOCAL_BIN"
    
    # Check for ultimate wrapper first, then enhanced wrapper
    if [[ -f "$PROJECT_ROOT/claude-wrapper-ultimate.sh" ]]; then
        # Use the ultimate wrapper from project
        cp "$PROJECT_ROOT/claude-wrapper-ultimate.sh" "$LOCAL_BIN/claude"
        chmod +x "$LOCAL_BIN/claude"
        
        # Replace placeholders
        sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$LOCAL_BIN/claude"
        sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_BINARY|g" "$LOCAL_BIN/claude"
        
        success "Ultimate wrapper installed with AI intelligence features"
        info "  • Pattern learning system active"
        info "  • Quick access shortcuts configured"
        info "  • Confidence scoring enabled"
        show_progress
        return
    elif [[ -f "$PROJECT_ROOT/claude-wrapper-enhanced.sh" ]]; then
        # Fall back to enhanced wrapper
        cp "$PROJECT_ROOT/claude-wrapper-enhanced.sh" "$LOCAL_BIN/claude"
        chmod +x "$LOCAL_BIN/claude"
        
        # Replace placeholders
        sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$LOCAL_BIN/claude"
        sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_BINARY|g" "$LOCAL_BIN/claude"
        
        success "Enhanced wrapper installed with intelligence features"
        show_progress
        return
    fi
    
    cat > "$LOCAL_BIN/claude" << 'WRAPPER'
#!/bin/bash
# Claude Master Wrapper v8.0 with Auto Permission Bypass

# Configuration
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"

# Check if running from project with .claude directory
if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
    export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
    export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
    export CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
else
    export CLAUDE_AGENTS_DIR="$HOME/agents"
    export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
    export CLAUDE_HOOKS_DIR="$HOME/.config/claude/hooks"
fi

# Binary location
CLAUDE_BINARY="BINARY_PLACEHOLDER"

# Find binary if needed
if [[ ! -f "$CLAUDE_BINARY" ]]; then
    for path in \
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
        "$HOME/.npm-global/bin/claude" \
        "/usr/local/bin/claude"; do
        if [[ -f "$path" ]]; then
            CLAUDE_BINARY="$path"
            break
        fi
    done
fi

# Permission bypass can be disabled with environment variable
PERMISSION_BYPASS="${CLAUDE_PERMISSION_BYPASS:-true}"

# Commands
case "$1" in
    --status|status)
        echo "Claude System Status"
        echo "===================="
        echo "Binary: $CLAUDE_BINARY"
        echo "Agents: $CLAUDE_AGENTS_DIR"
        echo "Project: $CLAUDE_PROJECT_ROOT"
        echo "Permission Bypass: $PERMISSION_BYPASS"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            COUNT=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
            echo "Agent Count: $COUNT"
        fi
        ;;
        
    --list-agents|agents)
        echo "Available Agents"
        echo "================"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            find "$CLAUDE_AGENTS_DIR" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | while read -r agent; do
                name=$(basename "$agent" | sed 's/\.[mM][dD]$//')
                printf "  • %s\n" "$name"
            done | sort
        else
            echo "No agents directory found"
        fi
        ;;
        
    --agent|agent)
        shift
        AGENT_NAME="$1"
        shift
        
        if [[ -z "$AGENT_NAME" ]]; then
            echo "Usage: claude agent <name> [args]"
            exit 1
        fi
        
        # Find agent file
        AGENT_FILE=""
        for pattern in \
            "$CLAUDE_AGENTS_DIR/${AGENT_NAME}.md" \
            "$CLAUDE_AGENTS_DIR/${AGENT_NAME}.MD" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_NAME}.md" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_NAME}.MD"; do
            for file in $pattern; do
                if [[ -f "$file" ]]; then
                    AGENT_FILE="$file"
                    break 2
                fi
            done
        done
        
        if [[ -z "$AGENT_FILE" ]]; then
            echo "Agent not found: $AGENT_NAME"
            exit 1
        fi
        
        echo "Loading agent: $AGENT_NAME"
        export CLAUDE_AGENT="$AGENT_NAME"
        export CLAUDE_AGENT_FILE="$AGENT_FILE"
        
        # Add permission bypass if enabled
        if [[ "$PERMISSION_BYPASS" == "true" ]]; then
            exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        else
            exec "$CLAUDE_BINARY" "$@"
        fi
        ;;
        
    --safe)
        # Run without permission bypass
        shift
        exec "$CLAUDE_BINARY" "$@"
        ;;
        
    --help|-h)
        echo "Claude Master System with Auto Permission Bypass"
        echo "================================================"
        echo "Commands:"
        echo "  claude [args]           - Run Claude (with auto permission bypass)"
        echo "  claude --safe [args]    - Run Claude without permission bypass"
        echo "  claude --status         - Show status"
        echo "  claude --list-agents    - List agents"
        echo "  claude agent <n> [args] - Run agent"
        echo ""
        echo "Environment:"
        echo "  CLAUDE_PERMISSION_BYPASS=false  - Disable auto permission bypass"
        echo ""
        echo "Quick functions:"
        echo "  coder, director, architect, security"
        ;;
        
    *)
        # Default: run with permission bypass if enabled
        if [[ "$PERMISSION_BYPASS" == "true" ]]; then
            exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        else
            exec "$CLAUDE_BINARY" "$@"
        fi
        ;;
esac
WRAPPER
    
    # Replace placeholders
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$LOCAL_BIN/claude"
    sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_BINARY|g" "$LOCAL_BIN/claude"
    
    chmod +x "$LOCAL_BIN/claude"
    success "Wrapper created"
    
    show_progress
}

# 7. Setup sync
setup_sync() {
    print_section "Setting Up Auto-Sync"
    
    cat > "$LOCAL_BIN/sync-agents.sh" << 'SYNC'
#!/bin/bash
SOURCE="SOURCE_PLACEHOLDER"
TARGET="$HOME/agents"

if [[ -d "$SOURCE" ]] && [[ "$SOURCE" != "$TARGET" ]]; then
    # Force sync .md/.MD files from root directory (overwrite existing)
    find "$SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) -exec cp -f {} "$TARGET/" \; 2>/dev/null
fi
SYNC
    
    sed -i "s|SOURCE_PLACEHOLDER|$AGENTS_SOURCE|g" "$LOCAL_BIN/sync-agents.sh"
    chmod +x "$LOCAL_BIN/sync-agents.sh"
    
    # Add to cron
    (crontab -l 2>/dev/null | grep -v "sync-agents"; 
     echo "*/5 * * * * $LOCAL_BIN/sync-agents.sh >/dev/null 2>&1") | crontab - 2>/dev/null
    
    success "Auto-sync configured"
    show_progress
}

# 8. Setup environment
setup_environment() {
    print_section "Configuring Environment"
    
    SHELL_RC="$HOME/.bashrc"
    [[ -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.zshrc"
    
    # Remove old config
    sed -i '/# Claude Master System/,/# End Claude System/d' "$SHELL_RC" 2>/dev/null
    
    # Add new config
    cat >> "$SHELL_RC" << 'ENV'

# Claude Master System
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_AGENTS_DIR="$HOME/agents"

# Auto permission bypass (set to false to disable)
export CLAUDE_PERMISSION_BYPASS=true

# Aliases
alias claude-status='claude --status'
alias claude-agents='claude --list-agents'
alias claude-safe='claude --safe'  # Run without permission bypass
alias ca='claude agent'

# Quick functions
coder() { claude agent coder "$@"; }
director() { claude agent director "$@"; }
architect() { claude agent architect "$@"; }
security() { claude agent security "$@"; }

# End Claude System
ENV
    
    success "Environment configured"
    show_progress
}

# 9. Run tests
run_tests() {
    print_section "Running Tests"
    
    TESTS_PASSED=0
    TESTS_TOTAL=5
    
    # Test 1: NPM package
    printf "  %-30s" "NPM package..."
    if npm list -g @anthropic-ai/claude-code &>/dev/null; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 2: Wrapper
    printf "  %-30s" "Wrapper executable..."
    if [[ -x "$LOCAL_BIN/claude" ]]; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 3: Agents
    printf "  %-30s" "Agents installed..."
    AGENT_COUNT=$(find "$AGENTS_TARGET" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
    if [[ $AGENT_COUNT -gt 0 ]]; then
        print_green "$SUCCESS ($AGENT_COUNT agents)"
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 4: Environment
    printf "  %-30s" "Environment setup..."
    if grep -q "Claude Master System" "$HOME/.bashrc" 2>/dev/null; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_yellow "$WARNING"
    fi
    
    # Test 5: PATH
    printf "  %-30s" "PATH configured..."
    if [[ "$PATH" == *"$LOCAL_BIN"* ]]; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_yellow "$WARNING"
    fi
    
    echo ""
    success "Tests: $TESTS_PASSED/$TESTS_TOTAL passed"
    show_progress
}

# 10. Show summary
show_summary() {
    echo ""
    echo ""
    print_green "╔═══════════════════════════════════════════════════════════════╗"
    print_green "║              Installation Complete! ✨                       ║"
    print_green "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    AGENT_COUNT=$(find "$AGENTS_TARGET" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
    
    print_bold "Installed Components:"
    echo "  • Claude NPM Package"
    echo "  • Enhanced Wrapper with Auto Permission Bypass"
    echo "  • $AGENT_COUNT Agents"
    echo "  • Auto-sync (5 minutes)"
    echo ""
    
    print_bold "Available Commands:"
    printf "  %-30s %s\n" "claude" "Run Claude (auto permission bypass)"
    printf "  %-30s %s\n" "claude --safe" "Run Claude without permission bypass"
    printf "  %-30s %s\n" "claude --status" "Show status"
    printf "  %-30s %s\n" "claude --list-agents" "List agents"
    printf "  %-30s %s\n" "claude agent <name>" "Run specific agent"
    echo ""
    
    print_bold "Quick Functions:"
    echo "  coder, director, architect, security"
    echo ""
    
    print_yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_yellow "                    Next Steps"
    print_yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Reload your shell:"
    print_cyan "     source ~/.bashrc"
    echo ""
    echo "  2. Test the system:"
    print_cyan "     claude --status"
    echo ""
    
    if [[ $AGENT_COUNT -eq 0 ]]; then
        echo "  3. Add agents (optional):"
        print_cyan "     # Copy existing agents if available:"
        print_cyan "     cp -r /path/to/agents/*.md $AGENTS_TARGET/"
        print_cyan "     # Or create your own agent files in: $AGENTS_TARGET/"
    else
        print_cyan "     claude --list-agents"
    fi
    
    echo ""
    print_dim "Log file: $LOG_FILE"
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    print_header
    
    # Get sudo if needed
    if [[ "$EUID" -ne 0 ]]; then
        print_yellow "This installer may need sudo access for some operations."
        sudo -v 2>/dev/null || true
    fi
    
    # Run installation steps
    check_prerequisites
    install_npm_package
    install_agents
    install_hooks
    install_statusline
    setup_claude_directory
    setup_precision_style
    setup_tandem_orchestration
    create_wrapper
    setup_sync
    setup_environment
    run_tests
    validate_agents
    
    # Reset progress for completion
    CURRENT_STEP=$TOTAL_STEPS
    show_progress
    echo ""
    
    # Show summary
    show_summary
}

# Run the installer
main "$@"
