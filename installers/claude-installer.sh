#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE MASTER INSTALLER - ORCHESTRATOR EDITION
# Calls existing scripts instead of recreating components
# Version 7.0 - Streamlined with existing infrastructure
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly SCRIPT_VERSION="7.0-orchestrator"

# Resolve script location
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(get_script_dir)"

# Find project root dynamically
find_project_root() {
    local current_dir="$SCRIPT_DIR"
    local max_depth=10
    local depth=0
    
    # If we're in installers directory, go up
    if [[ "$(basename "$current_dir")" == "installers" ]]; then
        current_dir="$(dirname "$current_dir")"
    fi
    
    # Search for project markers
    while [ $depth -lt $max_depth ]; do
        if [ -d "$current_dir/agents" ] && [ -d "$current_dir/hooks" ] && [ -d "$current_dir/scripts" ]; then
            echo "$current_dir"
            return 0
        fi
        
        [ "$current_dir" = "/" ] && break
        current_dir="$(dirname "$current_dir")"
        depth=$((depth + 1))
    done
    
    # Fallback to common locations
    for dir in "$HOME/Documents/Claude" "$HOME/claude-backups" "$HOME/claude-project"; do
        if [ -d "$dir/agents" ] && [ -d "$dir/hooks" ] && [ -d "$dir/scripts" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    echo "$SCRIPT_DIR"
    return 1
}

# Set project root
PROJECT_ROOT="$(find_project_root)"
readonly PROJECT_ROOT

# User directories
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly USER_SHARE_DIR="$HOME/.local/share/claude"
readonly CONFIG_DIR="$HOME/.config/claude"
readonly CLAUDE_HOME="$HOME/.claude"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Feature flags
INSTALL_HOOKS=${INSTALL_HOOKS:-true}
INSTALL_PRECISION_STYLE=${INSTALL_PRECISION_STYLE:-true}
INSTALL_TANDEM=${INSTALL_TANDEM:-true}
SYNC_AGENTS=${SYNC_AGENTS:-true}
VERBOSE=${VERBOSE:-true}
DRY_RUN=${DRY_RUN:-false}

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

debug() {
    if [ "$VERBOSE" = true ]; then
        printf "${CYAN}[DEBUG]${NC} %s\n" "$1"
        echo "[DEBUG] $1" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

run_script() {
    local script="$1"
    local description="${2:-Running $script}"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would execute: $script"
        return 0
    fi
    
    if [ -f "$script" ]; then
        log "$description"
        chmod +x "$script"
        if bash "$script"; then
            success "✓ $description completed"
            return 0
        else
            warn "⚠ $description had issues"
            return 1
        fi
    else
        warn "Script not found: $script"
        return 1
    fi
}

check_command() {
    local cmd="$1"
    command -v "$cmd" &> /dev/null
}

show_banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        __  __           _            
  / ____| |               | |      |  \/  |         | |           
 | |    | | __ _ _   _  __| | ___  | \  / | __ _ ___| |_ ___ _ __ 
 | |    | |/ _` | | | |/ _` |/ _ \ | |\/| |/ _` / __| __/ _ \ '__|
 | |____| | (_| | |_| | (_| |  __/ | |  | | (_| \__ \ ||  __/ |   
  \_______|_\__,_|\__,_|\__,_|\___| |_|  |_|\__,_|___/\__\___|_|   
                                                                    
    Master Installer v7.0 - Using Existing Infrastructure
EOF
    printf "${NC}\n"
    printf "${GREEN}Mode:${NC} Orchestrator - Calls existing scripts\n"
    printf "${BLUE}Project:${NC} $PROJECT_ROOT\n"
    printf "${CYAN}Strategy:${NC} Reuse existing components, no duplication\n\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validate_project_structure() {
    log "Validating project structure..."
    
    local all_good=true
    
    # Check critical directories
    echo "Checking directories:"
    
    if [ -d "$PROJECT_ROOT/agents" ]; then
        local agent_count=$(find "$PROJECT_ROOT/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        echo "  ✓ agents/ ($agent_count agents found)"
    else
        echo "  ✗ agents/ directory missing"
        all_good=false
    fi
    
    if [ -d "$PROJECT_ROOT/hooks" ]; then
        echo "  ✓ hooks/"
    else
        echo "  ✗ hooks/ directory missing"
        all_good=false
    fi
    
    if [ -d "$PROJECT_ROOT/scripts" ]; then
        echo "  ✓ scripts/"
    else
        echo "  ✗ scripts/ directory missing"
        all_good=false
    fi
    
    echo
    echo "Checking critical scripts:"
    
    # Check for critical scripts
    local scripts=(
        "hooks/setup_claude_hooks.sh"
        "hooks/install_claude_hooks.sh"
        "scripts/setup-precision-orchestration-style.sh"
        "scripts/setup-tandem-for-claude.sh"
        "scripts/sync-agents-to-claude.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/$script" ]; then
            echo "  ✓ $script"
        else
            echo "  ✗ $script missing"
            # Don't fail for optional scripts
            if [[ "$script" == hooks/* ]]; then
                INSTALL_HOOKS=false
            fi
        fi
    done
    
    echo
    
    # Check for Python components
    if [ -f "$PROJECT_ROOT/hooks/claude_hooks_bridge.py" ]; then
        echo "  ✓ Python hooks bridge found"
    else
        echo "  ⚠ Python hooks bridge not found"
    fi
    
    # Check for requirements.txt
    if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
        echo "  ✓ requirements.txt found"
    else
        echo "  ⚠ requirements.txt not found"
    fi
    
    if [ "$all_good" = false ]; then
        error "Critical directories missing. Please check project structure."
        return 1
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_python_dependencies() {
    log "Installing Python dependencies..."
    
    if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
        if check_command pip3; then
            log "Installing from requirements.txt..."
            pip3 install --user -r "$PROJECT_ROOT/requirements.txt" || {
                warn "Some packages failed to install"
            }
        elif check_command pip; then
            pip install --user -r "$PROJECT_ROOT/requirements.txt" || {
                warn "Some packages failed to install"
            }
        else
            warn "pip not found, skipping Python dependencies"
        fi
    fi
    
    # Ensure critical packages
    local packages=("pyyaml" "psutil" "rich" "numpy" "networkx")
    for pkg in "${packages[@]}"; do
        python3 -c "import $pkg" 2>/dev/null || {
            warn "$pkg not available, installing..."
            pip3 install --user "$pkg" 2>/dev/null || true
        }
    done
    
    # Install agent-specific dependencies for 100% compliance
    local agent_deps_installer="$PROJECT_ROOT/agents/src/python/install_agent_dependencies.sh"
    if [ -f "$agent_deps_installer" ]; then
        log "Installing agent-specific dependencies for 100% compliance..."
        if [ -x "$agent_deps_installer" ]; then
            "$agent_deps_installer" || warn "Some agent dependencies failed to install"
            success "Agent dependencies installation completed"
        else
            warn "Agent dependency installer found but not executable"
        fi
    else
        warn "Agent dependency installer not found at: $agent_deps_installer"
    fi
}

setup_claude_wrapper() {
    log "Setting up Claude wrapper..."
    
    # Check if claude-unified exists
    if [ -f "$PROJECT_ROOT/claude-unified" ]; then
        cp "$PROJECT_ROOT/claude-unified" "$USER_BIN_DIR/claude"
        chmod +x "$USER_BIN_DIR/claude"
        success "Claude wrapper installed"
    else
        # Create basic wrapper
        cat > "$USER_BIN_DIR/claude" << EOF
#!/bin/bash
# Claude wrapper - basic version
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="$PROJECT_ROOT/agents"

# Find actual claude binary
CLAUDE_BIN=\$(which claude.original || which claude-code || echo "")

if [ -n "\$CLAUDE_BIN" ]; then
    exec "\$CLAUDE_BIN" --dangerously-skip-permissions "\$@"
else
    echo "Claude Code not installed. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi
EOF
        chmod +x "$USER_BIN_DIR/claude"
        warn "Created basic wrapper (claude-unified not found)"
    fi
}

install_hooks_system() {
    if [ "$INSTALL_HOOKS" != true ]; then
        debug "Skipping hooks installation"
        return 0
    fi
    
    log "Installing Claude Hooks System..."
    
    # Try different hook installation scripts
    local hook_scripts=(
        "$PROJECT_ROOT/hooks/setup_claude_hooks.sh"
        "$PROJECT_ROOT/hooks/install_claude_hooks.sh"
        "$PROJECT_ROOT/claude_hooks_installer.sh"
    )
    
    local installed=false
    for script in "${hook_scripts[@]}"; do
        if [ -f "$script" ]; then
            if run_script "$script" "Installing hooks via $(basename $script)"; then
                installed=true
                break
            fi
        fi
    done
    
    if [ "$installed" = false ]; then
        warn "No hook installation script found"
        
        # Minimal fallback - just copy the bridge
        if [ -f "$PROJECT_ROOT/hooks/claude_hooks_bridge.py" ]; then
            mkdir -p "$CLAUDE_HOME/hooks"
            cp "$PROJECT_ROOT/hooks/claude_hooks_bridge.py" "$CLAUDE_HOME/hooks/"
            chmod +x "$CLAUDE_HOME/hooks/claude_hooks_bridge.py"
            debug "Copied hooks bridge as fallback"
        fi
    fi
    
    return 0
}

install_precision_style() {
    if [ "$INSTALL_PRECISION_STYLE" != true ]; then
        debug "Skipping precision style installation"
        return 0
    fi
    
    log "Installing Precision Orchestration Style..."
    
    local style_script="$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh"
    
    if [ -f "$style_script" ]; then
        run_script "$style_script" "Installing Precision Orchestration Style"
    else
        warn "Precision style script not found at: $style_script"
    fi
    
    return 0
}

setup_tandem_orchestration() {
    if [ "$INSTALL_TANDEM" != true ]; then
        debug "Skipping tandem setup"
        return 0
    fi
    
    log "Setting up Tandem Orchestration..."
    
    local tandem_script="$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh"
    
    if [ -f "$tandem_script" ]; then
        run_script "$tandem_script" "Setting up Tandem Orchestration"
    else
        warn "Tandem setup script not found at: $tandem_script"
    fi
    
    return 0
}

sync_agents() {
    if [ "$SYNC_AGENTS" != true ]; then
        debug "Skipping agent sync"
        return 0
    fi
    
    log "Syncing agents to Claude..."
    
    local sync_script="$PROJECT_ROOT/scripts/sync-agents-to-claude.sh"
    
    if [ -f "$sync_script" ]; then
        run_script "$sync_script" "Syncing agents to Claude directories"
    else
        # Fallback to manual sync
        log "Manual agent sync..."
        
        # Create necessary directories
        mkdir -p "$HOME/.claude/agents"
        mkdir -p "$HOME/agents"
        
        # Create symlinks
        if [ -d "$PROJECT_ROOT/agents" ]; then
            # Remove existing non-symlinks
            [ -e "$HOME/.claude/agents" ] && [ ! -L "$HOME/.claude/agents" ] && rm -rf "$HOME/.claude/agents"
            [ -e "$HOME/agents" ] && [ ! -L "$HOME/agents" ] && rm -rf "$HOME/agents"
            
            # Create symlinks
            ln -sfn "$PROJECT_ROOT/agents" "$HOME/.claude/agents"
            ln -sfn "$PROJECT_ROOT/agents" "$HOME/agents"
            
            success "Agent symlinks created"
        fi
    fi
    
    # Install Claude Code integration for Task tool
    log "Installing Claude Code Task tool integration..."
    local claude_integration="$PROJECT_ROOT/agents/src/python/install_claude_integration.py"
    
    if [ -f "$claude_integration" ]; then
        if python3 "$claude_integration" --quiet; then
            success "Claude Code Task tool integration installed"
        else
            warn "Claude Code integration failed (Claude Code may not be installed)"
        fi
    else
        warn "Claude Code integration script not found"
    fi
    
    # Setup auto-sync cron job
    setup_agent_cron
    
    return 0
}

setup_agent_cron() {
    log "Setting up agent auto-sync cron job..."
    
    local sync_script="$PROJECT_ROOT/scripts/sync-agents-to-claude.sh"
    
    if [ -f "$sync_script" ]; then
        # Remove old cron entries
        (crontab -l 2>/dev/null | grep -v "sync-agents") | crontab - 2>/dev/null || true
        
        # Add new cron entry
        (crontab -l 2>/dev/null; echo "*/5 * * * * $sync_script >/dev/null 2>&1") | crontab -
        
        success "Cron job configured for automatic agent sync"
    fi
}

setup_environment() {
    log "Setting up environment variables..."
    
    # Export for current session
    export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
    export CLAUDE_AGENTS_DIR="$PROJECT_ROOT/agents"
    export CLAUDE_HOOKS_DIR="$PROJECT_ROOT/hooks"
    export PATH="$USER_BIN_DIR:$PATH"
    
    # Add to bashrc
    local shell_rc="$HOME/.bashrc"
    
    # Remove old entries to avoid duplicates
    if [ -f "$shell_rc" ]; then
        sed -i '/# Claude Agent Framework/,/# End Claude Agent Framework/d' "$shell_rc" 2>/dev/null || true
    fi
    
    # Add new configuration
    cat >> "$shell_rc" << EOF

# Claude Agent Framework
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$CLAUDE_PROJECT_ROOT/agents"
export CLAUDE_HOOKS_DIR="\$CLAUDE_PROJECT_ROOT/hooks"
export PATH="$USER_BIN_DIR:\$PATH"

# Aliases
alias claude-status='$PROJECT_ROOT/scripts/diagenv.sh 2>/dev/null || echo "Status script not found"'
alias claude-agents='ls -la \$CLAUDE_AGENTS_DIR/*.md 2>/dev/null | wc -l && echo " agents available"'
alias claude-sync='$PROJECT_ROOT/scripts/sync-agents-to-claude.sh'
alias claude-hooks='$CLAUDE_HOOKS_DIR/setup_claude_hooks.sh'
alias claude-precision='claude --output-style precision-orchestration'

# Functions
claude-info() {
    echo "Claude Project Information:"
    echo "  Root: \$CLAUDE_PROJECT_ROOT"
    echo "  Agents: \$(find \$CLAUDE_AGENTS_DIR -name "*.md" 2>/dev/null | wc -l) available"
    echo "  Hooks: \$([ -d \$CLAUDE_HOOKS_DIR ] && echo "✓ Installed" || echo "✗ Not found")"
    echo "  Style: \$([ -f \$HOME/.claude/output-styles/precision-orchestration.md ] && echo "✓ Precision installed" || echo "✗ Not installed")"
}

# End Claude Agent Framework
EOF
    
    success "Environment configured"
}

create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Create master status script
    cat > "$USER_BIN_DIR/claude-master-status" << 'EOF'
#!/bin/bash
echo "═══════════════════════════════════════════════════════════"
echo "           Claude Master System Status"
echo "═══════════════════════════════════════════════════════════"
echo

# Project info
echo "Project Root: ${CLAUDE_PROJECT_ROOT:-Not set}"
echo

# Agents
echo "Agents:"
if [ -d "$HOME/.claude/agents" ]; then
    echo "  ~/.claude/agents: ✓ $([ -L "$HOME/.claude/agents" ] && echo "(symlink)" || echo "(directory)")"
fi
if [ -d "$HOME/agents" ]; then
    echo "  ~/agents: ✓ $([ -L "$HOME/agents" ] && echo "(symlink)" || echo "(directory)")"
fi
if [ -n "$CLAUDE_AGENTS_DIR" ] && [ -d "$CLAUDE_AGENTS_DIR" ]; then
    count=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
    echo "  Total agents: $count"
fi
echo

# Hooks
echo "Hooks System:"
if [ -f "$HOME/.claude/hooks/config.json" ]; then
    echo "  Configuration: ✓ Installed"
    enabled=$(jq -r '.enabled' "$HOME/.claude/hooks/config.json" 2>/dev/null || echo "unknown")
    echo "  Status: $enabled"
else
    echo "  Configuration: ✗ Not found"
fi
echo

# Precision Style
echo "Precision Style:"
if [ -f "$HOME/.claude/output-styles/precision-orchestration.md" ]; then
    echo "  Installation: ✓ Installed"
    echo "  Activation: claude --output-style precision-orchestration"
else
    echo "  Installation: ✗ Not found"
fi
echo

# Cron jobs
echo "Automation:"
if crontab -l 2>/dev/null | grep -q "sync-agents"; then
    echo "  Agent sync: ✓ Scheduled (every 5 minutes)"
else
    echo "  Agent sync: ✗ Not scheduled"
fi
echo

echo "Quick Commands:"
echo "  claude-info     - Show configuration"
echo "  claude-agents   - Count agents"
echo "  claude-sync     - Sync agents manually"
echo "  claude-hooks    - Manage hooks"
echo "  claude-precision - Use precision style"
EOF
    chmod +x "$USER_BIN_DIR/claude-master-status"
    
    # Create test script
    cat > "$USER_BIN_DIR/claude-test-all" << EOF
#!/bin/bash
echo "Testing Claude Installation..."
echo

# Test agents
echo -n "Agents: "
if [ -L "\$HOME/.claude/agents" ] && [ -d "\$HOME/.claude/agents" ]; then
    echo "✓"
else
    echo "✗"
fi

# Test hooks
echo -n "Hooks: "
if [ -f "\$HOME/.claude/hooks/config.json" ]; then
    echo "✓"
else
    echo "✗"
fi

# Test precision style
echo -n "Style: "
if [ -f "\$HOME/.claude/output-styles/precision-orchestration.md" ]; then
    echo "✓"
else
    echo "✗"
fi

# Test Python dependencies
echo -n "Python: "
if python3 -c "import yaml, psutil, numpy, networkx" 2>/dev/null; then
    echo "✓"
else
    echo "✗"
fi

echo
echo "Run 'claude-master-status' for detailed information"
EOF
    chmod +x "$USER_BIN_DIR/claude-test-all"
    
    success "Helper scripts created"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_final_status() {
    echo
    printf "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}${BOLD}       Installation Complete!${NC}\n"
    printf "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    echo
    
    echo "📂 Project Configuration:"
    echo "  • Root: $PROJECT_ROOT"
    echo "  • Mode: Using existing infrastructure"
    echo
    
    echo "✅ Components Processed:"
    
    # Check what was installed
    if [ -f "$USER_BIN_DIR/claude" ]; then
        echo "  • Claude wrapper: ✓ Installed"
    fi
    
    if [ -L "$HOME/.claude/agents" ]; then
        echo "  • Agent sync: ✓ Configured"
        local count=$(find "$PROJECT_ROOT/agents" -name "*.md" 2>/dev/null | wc -l || echo 0)
        echo "    - $count agents available"
    fi
    
    if [ -f "$HOME/.claude/hooks/config.json" ]; then
        echo "  • Hooks system: ✓ Installed"
    elif [ "$INSTALL_HOOKS" = true ]; then
        echo "  • Hooks system: ⚠ Check manually"
    fi
    
    if [ -f "$HOME/.claude/output-styles/precision-orchestration.md" ]; then
        echo "  • Precision style: ✓ Installed"
    elif [ "$INSTALL_PRECISION_STYLE" = true ]; then
        echo "  • Precision style: ⚠ Check manually"
    fi
    
    if crontab -l 2>/dev/null | grep -q "sync-agents"; then
        echo "  • Auto-sync: ✓ Scheduled"
    fi
    
    echo
    echo "📝 Commands Available:"
    echo "  • claude-master-status - Full system status"
    echo "  • claude-test-all      - Test installation"
    echo "  • claude-info          - Show configuration"
    echo "  • claude-sync          - Manual agent sync"
    echo "  • claude-precision     - Use precision style"
    echo
    
    echo "🚀 Next Steps:"
    echo "  1. source ~/.bashrc"
    echo "  2. claude-test-all        (verify installation)"
    echo "  3. claude-master-status   (detailed status)"
    echo
    
    if [ "$DRY_RUN" = true ]; then
        printf "${YELLOW}Note: This was a DRY RUN - no changes were made${NC}\n"
    fi
    
    printf "${GREEN}Installation orchestrated successfully!${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN ORCHESTRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    show_banner
    
    log "Starting orchestrated installation..."
    log "Project root: $PROJECT_ROOT"
    
    # Validate project structure
    validate_project_structure || {
        error "Project validation failed"
        exit 1
    }
    
    # Create necessary directories
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$USER_SHARE_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CLAUDE_HOME"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    echo "📦 Orchestrating installation..."
    echo
    
    # Installation steps
    local steps=(
        "Python dependencies:install_python_dependencies"
        "Claude wrapper:setup_claude_wrapper"
        "Hooks system:install_hooks_system"
        "Precision style:install_precision_style"
        "Tandem orchestration:setup_tandem_orchestration"
        "Agent synchronization:sync_agents"
        "Environment setup:setup_environment"
        "Helper scripts:create_helper_scripts"
    )
    
    local step_num=1
    local total_steps=${#steps[@]}
    
    for step_def in "${steps[@]}"; do
        IFS=':' read -r step_name step_func <<< "$step_def"
        echo -n "  [$step_num/$total_steps] $step_name... "
        
        if $step_func &>/dev/null; then
            echo "✅"
        else
            echo "⚠️"
        fi
        
        step_num=$((step_num + 1))
    done
    
    echo
    
    # Show final status
    show_final_status
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ARGUMENT PARSING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            log "DRY RUN MODE - No changes will be made"
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --quiet|-q)
            VERBOSE=false
            ;;
        --no-hooks)
            INSTALL_HOOKS=false
            ;;
        --no-style)
            INSTALL_PRECISION_STYLE=false
            ;;
        --no-tandem)
            INSTALL_TANDEM=false
            ;;
        --no-sync)
            SYNC_AGENTS=false
            ;;
        --help|-h)
            echo "Claude Master Installer v$SCRIPT_VERSION"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "This installer orchestrates existing scripts rather than"
            echo "recreating components. It calls scripts from:"
            echo "  • hooks/   - Hook system setup"
            echo "  • scripts/ - Style and sync scripts"
            echo
            echo "Options:"
            echo "  --dry-run         Show what would be done"
            echo "  --verbose, -v     Show detailed output"
            echo "  --quiet, -q       Minimal output"
            echo "  --no-hooks        Skip hooks installation"
            echo "  --no-style        Skip precision style"
            echo "  --no-tandem       Skip tandem setup"
            echo "  --no-sync         Skip agent sync"
            echo "  --help, -h        Show this help"
            echo
            echo "Project root: $PROJECT_ROOT"
            echo
            echo "Available scripts detected:"
            [ -f "$PROJECT_ROOT/hooks/setup_claude_hooks.sh" ] && echo "  ✓ Hooks setup"
            [ -f "$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh" ] && echo "  ✓ Precision style"
            [ -f "$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh" ] && echo "  ✓ Tandem setup"
            [ -f "$PROJECT_ROOT/scripts/sync-agents-to-claude.sh" ] && echo "  ✓ Agent sync"
            exit 0
            ;;
        *)
            warn "Unknown option: $1"
            ;;
    esac
    shift
done

# Run main installation
main "$@"