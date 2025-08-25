#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# WRAPPER INTEGRATION INSTALLER v2.0
# Professional wrapper installation system for Claude with orchestration
# Integrated with main claude-installer.sh as modular component
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

# Detect project root intelligently with caller integration
detect_project_root() {
    # Check if called from main installer with environment variables
    if [[ -n "$CALLER_PROJECT_ROOT" ]] && [[ -d "$CALLER_PROJECT_ROOT" ]]; then
        export PROJECT_ROOT="$CALLER_PROJECT_ROOT"
        log_success "Project root from caller: $PROJECT_ROOT"
        return 0
    fi
    
    local current_dir="$(pwd)"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    local candidates=(
        "$current_dir"
        "$script_dir/.."  # Parent directory (main project root from installers/)
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

# Setup installation environment with caller integration
setup_environment() {
    log_gear "Setting up wrapper integration environment..."
    
    detect_project_root
    
    # Use caller's configuration if available
    if [[ -n "$CALLER_LOCAL_BIN" ]]; then
        export LOCAL_BIN="$CALLER_LOCAL_BIN"
        log_info "Using caller's LOCAL_BIN: $LOCAL_BIN"
    else
        export LOCAL_BIN="$HOME/.local/bin"
    fi
    
    # Use caller's log file if available
    if [[ -n "$CALLER_LOG_FILE" ]]; then
        export LOG_FILE="$CALLER_LOG_FILE"
        log_info "Using caller's log file: $LOG_FILE"
    else
        export LOG_DIR="$HOME/.local/share/claude/logs"
        mkdir -p "$LOG_DIR" 2>/dev/null || true
        export LOG_FILE="$LOG_DIR/wrapper-integration-$(date +%Y%m%d-%H%M%S).log"
        touch "$LOG_FILE" 2>/dev/null || export LOG_FILE="/tmp/wrapper-integration.log"
    fi
    
    # Define installation paths
    export CACHE_DIR="$HOME/.cache/claude"
    export CONFIG_DIR="$HOME/.config/claude"
    
    # Create necessary directories
    mkdir -p "$LOCAL_BIN" "$CACHE_DIR" "$CONFIG_DIR" 2>/dev/null || true
    
    log_success "Environment configured"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WRAPPER INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_wrapper_system() {
    log_rocket "Installing Claude Wrapper Integration System..."
    
    # Check for claude-wrapper-ultimate.sh first (highest priority)
    local wrapper_source="$PROJECT_ROOT/claude-wrapper-ultimate.sh"
    local wrapper_target="$LOCAL_BIN/claude"
    
    if [[ -f "$wrapper_source" ]]; then
        # Use symlink for ultimate wrapper to preserve agent discovery
        ln -sf "$wrapper_source" "$wrapper_target"
        chmod +x "$wrapper_source"
        
        log_success "Ultimate wrapper installed (symlinked)"
        log_info "  • Advanced AI intelligence features active"
        log_info "  • Automatic agent discovery from $PROJECT_ROOT/agents"
        log_info "  • Permission bypass enabled for enhanced functionality"
        log_info "  • Pattern learning system active"
        return 0
    fi
    
    # Check for orchestration bridge integration
    local bridge_source="$PROJECT_ROOT/claude-orchestration-bridge.py"
    if [[ -f "$bridge_source" ]]; then
        local bridge_target="$LOCAL_BIN/claude-orchestration-bridge"
        cp "$bridge_source" "$bridge_target"
        chmod +x "$bridge_target"
        log_success "Orchestration bridge installed: $bridge_target"
    fi
    
    # If no existing wrapper, create a professional wrapper
    if [[ ! -f "$wrapper_target" ]]; then
        create_professional_wrapper "$wrapper_target"
    fi
    
    return 0
}

# Create professional wrapper if no existing wrapper found
create_professional_wrapper() {
    local wrapper_target="$1"
    
    log_gear "Creating professional Claude wrapper..."
    
    cat > "$wrapper_target" << 'EOF'
#!/bin/bash
# Professional Claude Wrapper v2.0 - Wrapper Integration System
# Created by modular installer integration

# Configuration
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"
export LOCAL_BIN="$HOME/.local/bin"

# Detect Claude binary
CLAUDE_BINARY=""
for path in \
    "$(which claude 2>/dev/null || true)" \
    "$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js" \
    "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
    "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"; do
    if [[ -n "$path" ]] && [[ -f "$path" ]]; then
        CLAUDE_BINARY="$path"
        break
    fi
done

# Agents directory
if [[ -d "$CLAUDE_PROJECT_ROOT/agents" ]]; then
    export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
else
    export CLAUDE_AGENTS_DIR="$HOME/agents"
fi

# Enhanced commands
case "$1" in
    --status|status)
        echo "Claude Professional System Status"
        echo "================================="
        echo "Binary: $CLAUDE_BINARY"
        echo "Agents: $CLAUDE_AGENTS_DIR"
        echo "Project: $CLAUDE_PROJECT_ROOT"
        echo "Wrapper: Professional v2.0"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            COUNT=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
            echo "Agent Count: $COUNT"
        fi
        
        # Check orchestration
        if [[ -f "$LOCAL_BIN/claude-orchestration-bridge" ]]; then
            echo "Orchestration: Available"
        fi
        ;;
        
    --agents|agents)
        echo "Available Agents (Professional Discovery)"
        echo "======================================="
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            find "$CLAUDE_AGENTS_DIR" -type f -name "*.md" 2>/dev/null | while read -r agent; do
                name=$(basename "$agent" .md)
                # Extract description from YAML frontmatter if available
                desc=$(grep -m1 "^description:" "$agent" 2>/dev/null | sed 's/description: *//') 
                printf "  %-20s %s\n" "$name" "${desc:-Professional AI agent}"
            done | sort
        else
            echo "No agents directory found"
        fi
        ;;
        
    --orchestrate|orchestrate)
        # Launch orchestration system if available
        if [[ -f "$LOCAL_BIN/claude-orchestration-bridge" ]]; then
            exec python3 "$LOCAL_BIN/claude-orchestration-bridge" "$@"
        else
            echo "Orchestration system not installed"
            exit 1
        fi
        ;;
        
    --help|-h)
        echo "Claude Professional Wrapper System v2.0"
        echo "======================================="
        echo "Commands:"
        echo "  claude [args]           - Run Claude with enhanced features"
        echo "  claude --status         - Show detailed system status"
        echo "  claude --agents         - List agents with descriptions"
        echo "  claude --orchestrate    - Launch orchestration system"
        echo "  claude --help           - Show this help"
        echo ""
        echo "Features:"
        echo "  • Professional wrapper integration"
        echo "  • Automatic permission bypass"
        echo "  • Agent discovery system"
        echo "  • Orchestration capabilities"
        ;;
        
    *)
        # Default: Run Claude with permission bypass
        if [[ -n "$CLAUDE_BINARY" ]]; then
            exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        else
            echo "Claude binary not found. Please install Claude Code first."
            exit 1
        fi
        ;;
esac
EOF

    # Replace placeholder
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$wrapper_target"
    chmod +x "$wrapper_target"
    
    log_success "Professional wrapper created: $wrapper_target"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION INTEGRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_orchestration_integration() {
    log_brain "Setting up orchestration integration..."
    
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
    
    if [[ "$orchestration_available" == "true" ]]; then
        # Create configuration for wrapper integration
        local config_file="$CONFIG_DIR/wrapper-integration.json"
        cat > "$config_file" << EOF
{
    "integration_version": "2.0",
    "orchestration_enabled": true,
    "python_orchestration_dir": "$python_orchestration_dir",
    "orchestration_dir": "$orchestration_dir",
    "wrapper_features": {
        "permission_bypass": true,
        "agent_discovery": true,
        "orchestration_bridge": true,
        "professional_commands": true
    },
    "installation_source": "modular_installer"
}
EOF
        log_success "Orchestration integration configured: $config_file"
        return 0
    else
        log_info "Orchestration components not found - wrapper will work without orchestration"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION AND TESTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validate_installation() {
    log_lightning "Validating wrapper integration installation..."
    
    local validation_passed=true
    
    # Test 1: Claude command exists and is executable
    if [[ -x "$LOCAL_BIN/claude" ]]; then
        log_success "  ✓ Claude wrapper is executable"
    else
        log_error "  ✗ Claude wrapper not executable"
        validation_passed=false
    fi
    
    # Test 2: Claude wrapper responds to --help
    if timeout 10s "$LOCAL_BIN/claude" --help >/dev/null 2>&1; then
        log_success "  ✓ Claude wrapper responds to commands"
    else
        log_error "  ✗ Claude wrapper not responding"
        validation_passed=false
    fi
    
    # Test 3: Project root detection
    if [[ -d "$PROJECT_ROOT/agents" ]]; then
        log_success "  ✓ Agent directory accessible"
    else
        log_warning "  ⚠ Agent directory not found (non-critical)"
    fi
    
    # Test 4: Configuration file
    if [[ -f "$CONFIG_DIR/wrapper-integration.json" ]]; then
        log_success "  ✓ Integration configuration exists"
    else
        log_info "  ℹ No orchestration configuration (wrapper will work without it)"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Wrapper integration validation passed"
        return 0
    else
        log_error "Wrapper integration validation failed"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Parse command line arguments
    local quiet=false
    local force_install=false
    local skip_validation=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quiet)
                quiet=true
                shift
                ;;
            --force)
                force_install=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --help|-h)
                echo "Wrapper Integration Installer v2.0"
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --quiet           Minimize output"
                echo "  --force           Force installation"
                echo "  --skip-validation Skip validation tests"
                echo "  --help            Show this help"
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Header (unless quiet)
    if [[ "$quiet" != "true" ]]; then
        echo
        echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}${BOLD}      WRAPPER INTEGRATION INSTALLER v2.0${NC}"
        echo -e "${WHITE}${BOLD}  Professional Claude Wrapper System Integration${NC}"
        echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo
    fi
    
    # Installation process
    log_rocket "Starting wrapper integration installation..."
    
    # Step 1: Setup environment
    setup_environment
    
    # Step 2: Install wrapper system
    install_wrapper_system
    
    # Step 3: Setup orchestration integration
    setup_orchestration_integration
    
    # Step 4: Validate installation
    if [[ "$skip_validation" != "true" ]]; then
        if ! validate_installation; then
            log_error "Installation validation failed"
            exit 1
        fi
    fi
    
    # Success message
    if [[ "$quiet" != "true" ]]; then
        echo
        echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}   WRAPPER INTEGRATION INSTALLATION COMPLETE!${NC}"
        echo -e "${WHITE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo
        
        log_rocket "Professional Claude wrapper system is now active!"
        echo
        echo -e "${BOLD}Quick Start:${NC}"
        echo "  claude --status     # Show system status"
        echo "  claude --agents     # List available agents"
        echo "  claude --help       # Show wrapper help"
        echo
    fi
    
    log_success "Wrapper integration completed successfully!"
    return 0
}

# Error handling
trap 'log_error "Installation failed at line $LINENO"' ERR

# Run main installation if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi