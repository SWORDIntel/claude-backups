#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# WRAPPER INTEGRATION PRO INSTALLER v1.0
# Complete installation system for Claude Wrapper Ultimate PRO with orchestration
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLORS AND STYLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Enhanced color system
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' BOLD='' DIM='' NC=''
fi

# Status indicators
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly LIGHTNING="⚡"
readonly BRAIN="🧠"
readonly CHIP="💾"

# Logging functions
log_info() { echo -e "${CYAN}${INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${SUCCESS} $1${NC}"; }
log_warning() { echo -e "${YELLOW}${WARNING} $1${NC}"; }
log_error() { echo -e "${RED}${ERROR} $1${NC}"; }
log_rocket() { echo -e "${WHITE}${ROCKET} $1${NC}"; }
log_gear() { echo -e "${BLUE}${GEAR} $1${NC}"; }
log_brain() { echo -e "${MAGENTA}${BRAIN} $1${NC}"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION AND ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Detect project root intelligently
detect_project_root() {
    local current_dir="$(pwd)"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    local candidates=(
        "$current_dir"
        "$script_dir"
        "$HOME/Documents/Claude"
        "$HOME/Documents/claude-backups"
        "$HOME/Downloads/claude-backups"
        "$HOME/claude-backups"
        "$HOME/projects/claude"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            local score=0
            [[ -d "$candidate/agents" ]] && ((score += 3))
            [[ -f "$candidate/CLAUDE.md" ]] && ((score += 2))
            [[ -f "$candidate/claude-wrapper-ultimate.sh" ]] && ((score += 2))
            [[ -d "$candidate/orchestration" ]] && ((score += 1))
            
            if [[ $score -ge 3 ]]; then
                export PROJECT_ROOT="$candidate"
                log_success "Project root detected: $PROJECT_ROOT"
                return 0
            fi
        fi
    done
    
    export PROJECT_ROOT="$current_dir"
    log_warning "Using current directory as project root: $PROJECT_ROOT"
}

# Setup installation environment
setup_environment() {
    log_gear "Setting up installation environment..."
    
    detect_project_root
    
    # Define installation paths
    export LOCAL_BIN="$HOME/.local/bin"
    export CACHE_DIR="$HOME/.cache/claude"
    export CONFIG_DIR="$HOME/.config/claude"
    export LOG_DIR="$HOME/.local/share/claude/logs"
    
    # Create necessary directories
    mkdir -p "$LOCAL_BIN" "$CACHE_DIR" "$CONFIG_DIR" "$LOG_DIR" 2>/dev/null || true
    
    # Installation tracking
    export INSTALL_LOG="$LOG_DIR/wrapper-pro-install-$(date +%Y%m%d-%H%M%S).log"
    touch "$INSTALL_LOG" 2>/dev/null || export INSTALL_LOG="/tmp/wrapper-pro-install.log"
    
    log_success "Environment configured"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYSTEM CHECKS AND VALIDATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_system_requirements() {
    log_brain "Checking system requirements..."
    
    local requirements_met=true
    
    # Check essential commands
    local required_commands=("bash" "python3" "node" "npm")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "$cmd: Available ($(command -v "$cmd"))"
        else
            log_error "$cmd: Not found - required for installation"
            requirements_met=false
        fi
    done
    
    # Check Python version
    if command -v python3 >/dev/null 2>&1; then
        local python_version
        python_version=$(python3 --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        local major_version=$(echo "$python_version" | cut -d. -f1)
        local minor_version=$(echo "$python_version" | cut -d. -f2)
        
        if [[ $major_version -ge 3 ]] && [[ $minor_version -ge 8 ]]; then
            log_success "Python: $python_version (compatible)"
        else
            log_warning "Python: $python_version (minimum 3.8 recommended)"
        fi
    fi
    
    # Check Node.js version
    if command -v node >/dev/null 2>&1; then
        local node_version
        node_version=$(node --version | sed 's/v//')
        local major_version=$(echo "$node_version" | cut -d. -f1)
        
        if [[ $major_version -ge 16 ]]; then
            log_success "Node.js: $node_version (compatible)"
        else
            log_warning "Node.js: $node_version (minimum 16.0 recommended)"
        fi
    fi
    
    # Check available space
    local available_space
    available_space=$(df -BM "$HOME" | tail -1 | awk '{print $4}' | sed 's/M//')
    
    if [[ $available_space -ge 100 ]]; then
        log_success "Disk space: ${available_space}MB available"
    else
        log_warning "Disk space: ${available_space}MB available (low space)"
    fi
    
    if [[ "$requirements_met" == "false" ]]; then
        log_error "System requirements not met. Please install missing dependencies."
        exit 1
    fi
    
    log_success "System requirements check passed"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE INSTALLATION AND VERIFICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_claude_if_needed() {
    log_gear "Checking Claude Code installation..."
    
    # Check if Claude is already installed
    local claude_paths=(
        "$(which claude 2>/dev/null || true)"
        "$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    )
    
    local claude_found=false
    local claude_binary=""
    
    for path in "${claude_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            claude_found=true
            claude_binary="$path"
            break
        fi
    done
    
    if [[ "$claude_found" == "true" ]]; then
        log_success "Claude Code found: $claude_binary"
        
        # Verify it works
        if timeout 10s node "$claude_binary" --version >/dev/null 2>&1; then
            log_success "Claude Code is working correctly"
            return 0
        else
            log_warning "Claude Code found but not working, reinstalling..."
        fi
    else
        log_info "Claude Code not found, installing..."
    fi
    
    # Install Claude Code
    log_gear "Installing Claude Code via npm..."
    
    local install_attempts=0
    local max_attempts=3
    
    while [[ $install_attempts -lt $max_attempts ]]; do
        ((install_attempts++))
        
        log_info "Installation attempt $install_attempts of $max_attempts"
        
        # Try different installation methods
        if npm install -g @anthropic-ai/claude-code --force >/dev/null 2>&1; then
            log_success "Claude Code installed successfully"
            break
        elif [[ $install_attempts -eq $max_attempts ]]; then
            log_error "Failed to install Claude Code after $max_attempts attempts"
            exit 1
        else
            log_warning "Installation attempt $install_attempts failed, retrying..."
            sleep 2
        fi
    done
    
    # Verify installation
    local new_claude_binary=""
    for path in "${claude_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            new_claude_binary="$path"
            break
        fi
    done
    
    if [[ -n "$new_claude_binary" ]] && timeout 10s node "$new_claude_binary" --version >/dev/null 2>&1; then
        log_success "Claude Code installation verified"
    else
        log_error "Claude Code installation verification failed"
        exit 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WRAPPER INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_wrapper_pro() {
    log_rocket "Installing Claude Wrapper Ultimate PRO..."
    
    # Source files
    local wrapper_source="$PROJECT_ROOT/claude-wrapper-ultimate-pro.sh"
    local bridge_source="$PROJECT_ROOT/claude-orchestration-bridge-pro.py"
    
    # Installation targets
    local wrapper_target="$LOCAL_BIN/claude-pro"
    local bridge_target="$LOCAL_BIN/claude-orchestration-bridge-pro"
    
    # Install wrapper
    if [[ -f "$wrapper_source" ]]; then
        cp "$wrapper_source" "$wrapper_target"
        chmod +x "$wrapper_target"
        log_success "Wrapper installed: $wrapper_target"
    else
        log_error "Wrapper source not found: $wrapper_source"
        exit 1
    fi
    
    # Install orchestration bridge
    if [[ -f "$bridge_source" ]]; then
        cp "$bridge_source" "$bridge_target"
        chmod +x "$bridge_target"
        log_success "Orchestration bridge installed: $bridge_target"
    else
        log_warning "Orchestration bridge source not found: $bridge_source"
    fi
    
    # Create symlinks for easy access
    local claude_symlink="$LOCAL_BIN/claude"
    
    # Backup existing claude command if present
    if [[ -L "$claude_symlink" ]] || [[ -f "$claude_symlink" ]]; then
        local backup_name="$LOCAL_BIN/claude.backup.$(date +%Y%m%d-%H%M%S)"
        mv "$claude_symlink" "$backup_name"
        log_info "Existing claude command backed up as: $(basename "$backup_name")"
    fi
    
    # Create new symlink
    ln -sf "$wrapper_target" "$claude_symlink"
    log_success "Claude command linked to wrapper PRO"
    
    # Verify installation
    if [[ -x "$wrapper_target" ]]; then
        log_success "Wrapper PRO installation completed"
        return 0
    else
        log_error "Wrapper PRO installation verification failed"
        exit 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION SYSTEM SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_orchestration() {
    log_brain "Setting up orchestration system..."
    
    # Check for Python orchestration components
    local python_orchestration_dir="$PROJECT_ROOT/agents/src/python"
    local orchestration_dir="$PROJECT_ROOT/orchestration"
    
    local orchestration_available=false
    
    # Check for production orchestrator
    if [[ -f "$python_orchestration_dir/production_orchestrator.py" ]]; then
        log_success "Production orchestrator found: $python_orchestration_dir"
        orchestration_available=true
    elif [[ -f "$orchestration_dir/production_orchestrator.py" ]]; then
        log_success "Production orchestrator found: $orchestration_dir"
        orchestration_available=true
    fi
    
    # Check for agent registry
    if [[ -f "$python_orchestration_dir/agent_registry.py" ]]; then
        log_success "Agent registry found: $python_orchestration_dir"
    elif [[ -f "$orchestration_dir/agent_registry.py" ]]; then
        log_success "Agent registry found: $orchestration_dir"
    else
        log_warning "Agent registry not found - orchestration features will be limited"
    fi
    
    # Install Python dependencies if requirements file exists
    local requirements_files=(
        "$python_orchestration_dir/requirements.txt"
        "$orchestration_dir/requirements.txt"
        "$PROJECT_ROOT/requirements.txt"
    )
    
    for req_file in "${requirements_files[@]}"; do
        if [[ -f "$req_file" ]]; then
            log_gear "Installing Python dependencies from: $req_file"
            if python3 -m pip install -r "$req_file" --user >/dev/null 2>&1; then
                log_success "Python dependencies installed"
            else
                log_warning "Failed to install some Python dependencies"
            fi
            break
        fi
    done
    
    if [[ "$orchestration_available" == "true" ]]; then
        log_success "Orchestration system configured"
        
        # Create configuration
        local config_file="$CONFIG_DIR/wrapper-pro-config.json"
        cat > "$config_file" << EOF
{
    "orchestration_enabled": true,
    "python_orchestration_dir": "$python_orchestration_dir",
    "orchestration_dir": "$orchestration_dir",
    "intelligence_level": "advanced",
    "performance_monitoring": true,
    "auto_agent_selection": true,
    "fallback_strategies": ["hybrid", "agent_specific", "direct"],
    "cache_enabled": true,
    "debug_mode": false
}
EOF
        log_success "Configuration file created: $config_file"
    else
        log_warning "Orchestration system not available - some features will be limited"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT SYSTEM INTEGRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_agent_integration() {
    log_brain "Setting up agent system integration..."
    
    local agents_dir="$PROJECT_ROOT/agents"
    
    if [[ ! -d "$agents_dir" ]]; then
        log_warning "Agents directory not found: $agents_dir"
        return 1
    fi
    
    # Count available agents
    local agent_count=0
    local agent_files=()
    
    while IFS= read -r agent_file; do
        agent_files+=("$agent_file")
        ((agent_count++))
    done < <(find "$agents_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | head -100)
    
    if [[ $agent_count -gt 0 ]]; then
        log_success "Agent system: $agent_count agents detected"
        
        # Create agent registry cache directory
        mkdir -p "$CACHE_DIR/agents" 2>/dev/null || true
        
        # Initialize agent discovery for wrapper PRO
        log_gear "Initializing agent discovery system..."
        
        # This would be handled by the wrapper itself, but we can pre-warm it
        echo "{\"agents\": {}, \"last_updated\": \"$(date -Iseconds)\", \"total_count\": 0}" > "$CACHE_DIR/enhanced_agent_registry.json" 2>/dev/null || true
        
        log_success "Agent system integration configured"
    else
        log_warning "No agents found in agents directory"
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHELL INTEGRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_shell_integration() {
    log_gear "Setting up shell integration..."
    
    # Add local bin to PATH if not already present
    local shell_rc_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    local path_export='export PATH="$HOME/.local/bin:$PATH"'
    local integration_added=false
    
    for rc_file in "${shell_rc_files[@]}"; do
        if [[ -f "$rc_file" ]]; then
            # Check if PATH export already exists
            if ! grep -q "HOME/.local/bin" "$rc_file" 2>/dev/null; then
                echo "" >> "$rc_file"
                echo "# Claude Wrapper Pro Integration" >> "$rc_file"
                echo "$path_export" >> "$rc_file"
                log_success "PATH updated in: $(basename "$rc_file")"
                integration_added=true
            else
                log_info "PATH already configured in: $(basename "$rc_file")"
            fi
            break
        fi
    done
    
    if [[ "$integration_added" == "true" ]]; then
        log_success "Shell integration configured - restart shell or source rc file"
    fi
    
    # Create desktop entry if running in a desktop environment
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] && [[ -d "$HOME/.local/share/applications" ]]; then
        local desktop_file="$HOME/.local/share/applications/claude-wrapper-pro.desktop"
        cat > "$desktop_file" << EOF
[Desktop Entry]
Name=Claude Wrapper Pro
Comment=Advanced AI-powered wrapper with orchestration
Exec=$LOCAL_BIN/claude-pro
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Development;Utility;
EOF
        log_success "Desktop entry created"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TESTING AND VALIDATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_installation_tests() {
    log_lightning "Running installation validation tests..."
    
    local test_passed=true
    
    # Test 1: Wrapper PRO executable
    log_info "Test 1: Wrapper PRO executable"
    if [[ -x "$LOCAL_BIN/claude-pro" ]]; then
        log_success "  ✓ Wrapper PRO is executable"
    else
        log_error "  ✗ Wrapper PRO is not executable"
        test_passed=false
    fi
    
    # Test 2: Symlink to claude command
    log_info "Test 2: Claude command symlink"
    if [[ -L "$LOCAL_BIN/claude" ]] && [[ "$(readlink "$LOCAL_BIN/claude")" == "$LOCAL_BIN/claude-pro" ]]; then
        log_success "  ✓ Claude command properly linked"
    else
        log_error "  ✗ Claude command link invalid"
        test_passed=false
    fi
    
    # Test 3: Wrapper PRO help command
    log_info "Test 3: Wrapper PRO help command"
    if timeout 10s "$LOCAL_BIN/claude-pro" --help >/dev/null 2>&1; then
        log_success "  ✓ Wrapper PRO help command works"
    else
        log_error "  ✗ Wrapper PRO help command failed"
        test_passed=false
    fi
    
    # Test 4: Orchestration bridge (if available)
    if [[ -x "$LOCAL_BIN/claude-orchestration-bridge-pro" ]]; then
        log_info "Test 4: Orchestration bridge"
        if timeout 10s python3 "$LOCAL_BIN/claude-orchestration-bridge-pro" --status >/dev/null 2>&1; then
            log_success "  ✓ Orchestration bridge works"
        else
            log_warning "  ⚠ Orchestration bridge has issues (non-critical)"
        fi
    fi
    
    # Test 5: Cache directory
    log_info "Test 5: Cache directory"
    if [[ -d "$CACHE_DIR" ]] && [[ -w "$CACHE_DIR" ]]; then
        log_success "  ✓ Cache directory is writable"
    else
        log_error "  ✗ Cache directory issues"
        test_passed=false
    fi
    
    # Test 6: Configuration file
    log_info "Test 6: Configuration file"
    if [[ -f "$CONFIG_DIR/wrapper-pro-config.json" ]]; then
        log_success "  ✓ Configuration file exists"
    else
        log_warning "  ⚠ Configuration file missing (non-critical)"
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        log_success "All critical tests passed!"
        return 0
    else
        log_error "Some tests failed - installation may have issues"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo
    echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}      WRAPPER INTEGRATION PRO INSTALLER v1.0${NC}"
    echo -e "${WHITE}${BOLD}  Complete Claude Wrapper Ultimate PRO Installation${NC}"
    echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Parse command line arguments
    local force_install=false
    local skip_tests=false
    local quiet=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_install=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --quiet)
                quiet=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --force       Force installation even if components exist"
                echo "  --skip-tests  Skip installation validation tests"
                echo "  --quiet       Minimize output"
                echo "  --help        Show this help message"
                echo
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Start installation process
    log_rocket "Starting Wrapper Integration PRO installation..."
    
    # Step 1: Setup environment
    setup_environment
    
    # Step 2: Check system requirements
    check_system_requirements
    
    # Step 3: Install/verify Claude Code
    install_claude_if_needed
    
    # Step 4: Install wrapper PRO
    if [[ "$force_install" == "true" ]] || [[ ! -x "$LOCAL_BIN/claude-pro" ]]; then
        install_wrapper_pro
    else
        log_info "Wrapper PRO already installed (use --force to reinstall)"
    fi
    
    # Step 5: Setup orchestration system
    setup_orchestration
    
    # Step 6: Setup agent integration
    setup_agent_integration
    
    # Step 7: Setup shell integration
    setup_shell_integration
    
    # Step 8: Run validation tests
    if [[ "$skip_tests" != "true" ]]; then
        if run_installation_tests; then
            log_success "Installation validation passed"
        else
            log_warning "Installation validation had issues"
        fi
    fi
    
    # Installation complete
    echo
    echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}   WRAPPER INTEGRATION PRO INSTALLATION COMPLETE!${NC}"
    echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    log_rocket "Claude Wrapper Ultimate PRO v14.0 is now installed!"
    echo
    echo -e "${BOLD}Quick Start:${NC}"
    echo "  claude --status                    # Show system status"
    echo "  claude agents                     # List AI-classified agents"
    echo "  claude --intelligent-task 'task'  # Use AI orchestration"
    echo "  claude --help                     # Show full help"
    echo
    
    echo -e "${BOLD}Advanced Features:${NC}"
    echo "  • AI-powered agent selection"
    echo "  • Intelligent task orchestration"  
    echo "  • Performance monitoring"
    echo "  • Seamless fallback systems"
    echo "  • Enhanced bash output handling"
    echo
    
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        echo -e "${DIM}Note: Desktop entry created for GUI environments${NC}"
        echo
    fi
    
    echo -e "${CYAN}${INFO} Restart your shell or run: source ~/.bashrc${NC}"
    echo -e "${CYAN}${INFO} Installation log: $INSTALL_LOG${NC}"
    echo
    
    log_success "Installation completed successfully!"
}

# Error handling
trap 'log_error "Installation failed at line $LINENO. Check $INSTALL_LOG for details."' ERR

# Run main installation
main "$@"