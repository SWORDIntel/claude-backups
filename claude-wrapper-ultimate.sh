#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v13.1 - ENHANCED WITH AUTOMATIC AGENT REGISTRATION
# 
# Features:
# • Automatic yoga.wasm error detection and recovery
# • Self-healing npm package management
# • Multiple execution fallback methods
# • Robust error handling to prevent crashes
# • Automatic virtual environment activation
# • Smart dependency checking and auto-fixing
# • Performance monitoring and caching
# • Banner suppression for clean output
# • Correct agent system status reporting
# • Automatic agent discovery and registration from agents/ directory
# • Intelligent agent metadata extraction (category, description, tools, UUID)
# • Agent status tracking (active/template/stub)
# • Enhanced agent search and execution
# • JSON-based agent registry with caching
# ═══════════════════════════════════════════════════════════════════════════

# Don't exit on errors - handle them gracefully
set +e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT CONTROL - CONFIGURABLE (FIXED FOR BASH OUTPUT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Allow user to control output suppression via environment variable
# Default to NOT suppressing output to fix bash output issues
if [[ "${CLAUDE_FORCE_QUIET:-false}" == "true" ]]; then
    # Only suppress if explicitly requested
    export CLAUDE_QUIET_MODE=true
    export CLAUDE_SUPPRESS_BANNER=true
    export NO_AGENT_BRIDGE_HEADER=true
    export CLAUDE_BRIDGE_QUIET=true
    export DISABLE_AGENT_BRIDGE=true
else
    # Default: Allow normal output
    export CLAUDE_QUIET_MODE=false
    export CLAUDE_SUPPRESS_BANNER=false
    # Still suppress verbose headers but allow actual output
    export NO_AGENT_BRIDGE_HEADER=true
    export CLAUDE_BRIDGE_QUIET=false
    export DISABLE_AGENT_BRIDGE=false
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLORS AND SYMBOLS (SAFE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if terminal supports colors
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly RED='\033[0;31m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly GREEN='' YELLOW='' CYAN='' MAGENTA='' RED='' BOLD='' DIM='' NC=''
fi

# Status symbols
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly FIXING="🔧"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEBUG AND LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Enable debug mode if requested
DEBUG_MODE="${CLAUDE_DEBUG:-false}"
if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE="true"
    shift
    set -x
fi

# Logging function
log_debug() {
    [[ "$DEBUG_MODE" == "true" ]] && echo -e "${DIM}[DEBUG] $1${NC}" >&2
}

log_error() {
    echo -e "${RED}${ERROR} $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}" >&2
}

log_info() {
    echo -e "${CYAN}${INFO} $1${NC}" >&2
}

log_fixing() {
    echo -e "${MAGENTA}${FIXING} $1${NC}" >&2
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY CHECKING AND AUTO-FIXING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Node.js and npm
check_node_npm() {
    local has_issues=false
    
    if ! command_exists node; then
        log_error "Node.js is not installed"
        has_issues=true
    else
        local node_version=$(node --version 2>/dev/null | sed 's/v//')
        log_debug "Node.js version: $node_version"
        
        # Check if version is sufficient (>= 14.0.0)
        local major_version=$(echo "$node_version" | cut -d. -f1)
        if [[ "$major_version" -lt 14 ]]; then
            log_warning "Node.js version is old ($node_version). Consider upgrading to 14+"
        fi
    fi
    
    if ! command_exists npm; then
        log_error "npm is not installed"
        has_issues=true
    else
        log_debug "npm version: $(npm --version 2>/dev/null)"
    fi
    
    return $([ "$has_issues" = true ] && echo 1 || echo 0)
}

# Function to verify Claude installation health
verify_claude_health() {
    local claude_path="$1"
    
    if [[ ! -f "$claude_path" ]]; then
        return 1
    fi
    
    # Check if yoga.wasm issue exists by attempting a dry run
    local test_output=$(node "$claude_path" --version 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        if echo "$test_output" | grep -q "yoga.wasm"; then
            log_warning "Detected yoga.wasm issue"
            return 2  # Special code for yoga.wasm issue
        elif echo "$test_output" | grep -q "Cannot find module"; then
            log_warning "Missing module detected"
            return 3  # Missing modules
        else
            log_debug "Unknown error: $test_output"
            return 1  # General error
        fi
    fi
    
    log_debug "Claude health check passed"
    return 0
}

# Function to fix yoga.wasm issue
fix_yoga_wasm_issue() {
    log_fixing "Attempting to fix yoga.wasm issue..."
    
    # Method 1: Set environment variable to bypass yoga
    export CLAUDE_NO_YOGA=1
    export NODE_OPTIONS="--no-warnings"
    
    # Method 2: Try reinstalling if user confirms
    if [[ "${CLAUDE_AUTO_FIX:-false}" == "true" ]]; then
        log_info "Auto-fix enabled. Reinstalling Claude Code..."
        
        # Save current directory
        local current_dir=$(pwd)
        
        # Uninstall and reinstall
        npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1
        npm cache clean --force >/dev/null 2>&1
        npm install -g @anthropic-ai/claude-code --force >/dev/null 2>&1
        
        # Return to original directory
        cd "$current_dir"
        
        if [[ $? -eq 0 ]]; then
            log_success "Claude Code reinstalled successfully"
            return 0
        else
            log_warning "Reinstall failed, using workaround mode"
        fi
    fi
    
    # Method 3: Create yoga.wasm placeholder if needed
    local claude_dir=""
    for dir in \
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code" \
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code" \
        "$(npm root -g)/@anthropic-ai/claude-code"; do
        if [[ -d "$dir" ]]; then
            claude_dir="$dir"
            break
        fi
    done
    
    if [[ -n "$claude_dir" ]] && [[ ! -f "$claude_dir/yoga.wasm" ]]; then
        echo "// Placeholder" > "$claude_dir/yoga.wasm" 2>/dev/null || true
        log_debug "Created yoga.wasm placeholder"
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VIRTUAL ENVIRONMENT ACTIVATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

activate_venv() {
    local venv_paths=(
        "${CLAUDE_VENV:-}"
        "./venv"
        "./.venv"
        "../venv"
        "../.venv"
    )
    
    for venv_path in "${venv_paths[@]}"; do
        if [[ -n "$venv_path" ]] && [[ -d "$venv_path" ]] && [[ -f "$venv_path/bin/activate" ]]; then
            log_debug "Activating virtual environment: $venv_path"
            
            # Use realpath to get absolute path for exports
            local abs_venv_path="$(realpath "$venv_path" 2>/dev/null || echo "$venv_path")"
            
            export VIRTUAL_ENV="$abs_venv_path"
            export PATH="$abs_venv_path/bin:$PATH"
            export PYTHONPATH="$abs_venv_path/lib/python*/site-packages:${PYTHONPATH:-}"
            unset PYTHONHOME
            
            export CLAUDE_VENV_ACTIVATED="true"
            export CLAUDE_VENV_PATH="$abs_venv_path"
            
            return 0
        fi
    done
    
    export CLAUDE_VENV_ACTIVATED="false"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTELLIGENT PATH DISCOVERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

find_project_root() {
    local current_dir="$(pwd 2>/dev/null || echo "$HOME")"
    
    # First check if script is being run from within a project directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
    
    local search_paths=(
        "$current_dir"
        "$script_dir"
        "${CLAUDE_PROJECT_ROOT:-}"
        "$HOME/Documents/Claude"
        "$HOME/Documents/claude-backups"
        "$HOME/claude-backups"
        "$HOME/projects/claude"
        "$HOME/workspace/claude"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -d "$path" ]]; then
            if [[ -d "$path/agents" ]] || [[ -f "$path/CLAUDE.md" ]] || [[ -d "$path/.claude" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done
    
    # If no project found, use current directory if it has agents
    if [[ -d "$current_dir/agents" ]]; then
        echo "$current_dir"
        return 0
    fi
    
    echo "$HOME/claude-project"
    mkdir -p "$HOME/claude-project" 2>/dev/null || true
}

find_claude_binary() {
    local search_paths=(
        # Check npm global installations
        "$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/bin/claude"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/local/bin/claude"
        
        # Check PATH
        "$(which claude 2>/dev/null || true)"
        "$(which claude-code 2>/dev/null || true)"
    )
    
    # Also check npm bin if npm exists
    if command_exists npm; then
        local npm_bin=$(npm bin -g 2>/dev/null)
        if [[ -n "$npm_bin" ]]; then
            search_paths+=("$npm_bin/claude")
            search_paths+=("$npm_bin/claude-code")
        fi
    fi
    
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            log_debug "Found Claude binary: $path"
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SMART EXECUTION WITH FALLBACKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

execute_claude() {
    local claude_binary="$1"
    shift
    local args=("$@")
    
    # Add permission bypass if enabled (default to true)
    if [[ "${PERMISSION_BYPASS:-true}" == "true" ]] && [[ "${args[0]}" != "--safe" ]]; then
        args=("--dangerously-skip-permissions" "${args[@]}")
    fi
    
    # Remove --safe flag if present
    if [[ "${args[0]}" == "--safe" ]]; then
        args=("${args[@]:1}")
        PERMISSION_BYPASS="false"
    fi
    
    log_debug "Executing: $claude_binary ${args[*]}"
    
    # FIXED: Don't use exec which replaces the shell process
    # Instead, run normally to preserve output handling
    
    # Method 1: Try direct execution
    if [[ -x "$claude_binary" ]]; then
        "$claude_binary" "${args[@]}"
        return $?
    fi
    
    # Method 2: Try with node
    if command_exists node; then
        node "$claude_binary" "${args[@]}"
        return $?
    fi
    
    # Method 3: Try with npx
    if command_exists npx; then
        npx @anthropic-ai/claude-code "${args[@]}"
        return $?
    fi
    
    log_error "All execution methods failed"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION AND INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

initialize_environment() {
    # Activate virtual environment if available
    activate_venv
    
    # Set up environment variables
    export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude-home}"
    export CLAUDE_PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(find_project_root)}"
    
    # Setup directories
    if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
        export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
        export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
        export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
    elif [[ -d "$CLAUDE_PROJECT_ROOT/agents" ]]; then
        # If agents directory exists in project root, use it
        export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
        export CLAUDE_CONFIG_DIR="$CLAUDE_PROJECT_ROOT/config"
    elif [[ -d "./agents" ]]; then
        # If agents directory exists relative to current directory
        export CLAUDE_AGENTS_DIR="$(realpath ./agents 2>/dev/null || pwd)/agents"
        export CLAUDE_CONFIG_DIR="$(realpath ./config 2>/dev/null || pwd)/config"
    else
        # Final fallback
        export CLAUDE_AGENTS_DIR="${CLAUDE_AGENTS_DIR:-$HOME/agents}"
        export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}"
    fi
    
    # Cache directory
    export CACHE_DIR="${CLAUDE_CACHE_DIR:-$HOME/.cache/claude}"
    mkdir -p "$CACHE_DIR" 2>/dev/null || export CACHE_DIR="/tmp/claude-cache-$$"
    
    # Feature flags
    export PERMISSION_BYPASS="${CLAUDE_PERMISSION_BYPASS:-true}"
    export AUTO_FIX="${CLAUDE_AUTO_FIX:-true}"
    export ORCHESTRATION_ENABLED="${CLAUDE_ORCHESTRATION:-true}"
    export LEARNING_MODE="${CLAUDE_LEARNING:-true}"
    
    # Set Node options for better compatibility
    export NODE_OPTIONS="${NODE_OPTIONS:---no-warnings}"
    export CLAUDE_NO_YOGA="${CLAUDE_NO_YOGA:-1}"
    
    log_debug "Environment initialized"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENHANCED STATUS DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}          Claude Ultimate Wrapper v13.1 Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # System Info
    echo -e "${BOLD}System:${NC}"
    echo "  OS: $(uname -s 2>/dev/null || echo 'Unknown')"
    echo "  User: $USER"
    echo "  Shell: ${SHELL##*/}"
    echo
    
    # Node.js and npm
    echo -e "${BOLD}Node Environment:${NC}"
    if command_exists node; then
        echo -e "  Node.js: ${GREEN}${SUCCESS}${NC} $(node --version)"
    else
        echo -e "  Node.js: ${RED}${ERROR} Not installed${NC}"
    fi
    
    if command_exists npm; then
        echo -e "  npm: ${GREEN}${SUCCESS}${NC} v$(npm --version)"
        echo "  Global prefix: $(npm config get prefix 2>/dev/null)"
    else
        echo -e "  npm: ${RED}${ERROR} Not installed${NC}"
    fi
    echo
    
    # Claude Binary
    echo -e "${BOLD}Claude Installation:${NC}"
    local claude_binary=$(find_claude_binary || echo "")
    if [[ -n "$claude_binary" ]]; then
        echo -e "  Binary: ${GREEN}${SUCCESS}${NC} $claude_binary"
        
        # Health check
        verify_claude_health "$claude_binary"
        local health_status=$?
        case $health_status in
            0) echo -e "  Health: ${GREEN}${SUCCESS} Operational${NC}" ;;
            2) echo -e "  Health: ${YELLOW}${WARNING} yoga.wasm issue detected (auto-fix available)${NC}" ;;
            3) echo -e "  Health: ${YELLOW}${WARNING} Missing modules${NC}" ;;
            *) echo -e "  Health: ${RED}${ERROR} Issues detected${NC}" ;;
        esac
    else
        echo -e "  Binary: ${RED}${ERROR} Not found${NC}"
        echo "  Install: npm install -g @anthropic-ai/claude-code"
    fi
    echo
    
    # Virtual Environment
    echo -e "${BOLD}Python Environment:${NC}"
    if [[ "${CLAUDE_VENV_ACTIVATED:-false}" == "true" ]]; then
        echo -e "  Venv: ${GREEN}${SUCCESS} Active${NC}"
        echo "  Path: ${CLAUDE_VENV_PATH}"
        echo "  Python: $(which python3 2>/dev/null || echo 'not found')"
    else
        echo -e "  Venv: ${DIM}Not active${NC}"
        echo "  Python: $(which python3 2>/dev/null || echo 'system default')"
    fi
    echo
    
    # Directories
    echo -e "${BOLD}Directories:${NC}"
    echo "  Project: $CLAUDE_PROJECT_ROOT"
    if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        local total_agents=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
        echo "  Agents: $CLAUDE_AGENTS_DIR ($total_agents found)"
    else
        echo -e "  Agents: ${RED}${ERROR} Not found${NC}"
    fi
    echo "  Cache: $CACHE_DIR"
    
    # Agent Registry Status
    local registry_file="$CACHE_DIR/registered_agents.json"
    if [[ -f "$registry_file" ]]; then
        local registered_count=0
        local active_count=0
        local template_count=0
        local stub_count=0
        
        if command_exists python3; then
            eval "$(python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agents = registry.get('agents', {})
    print(f'registered_count={len(agents)}')
    print(f'active_count={sum(1 for a in agents.values() if a.get(\"status\") == \"active\")}')
    print(f'template_count={sum(1 for a in agents.values() if a.get(\"status\") == \"template\")}')
    print(f'stub_count={sum(1 for a in agents.values() if a.get(\"status\") == \"stub\")}')
except Exception:
    print('registered_count=0')
" 2>/dev/null)"
        fi
        
        echo "  Registry: $registered_count registered"
        [[ $active_count -gt 0 ]] && echo "    Active: $active_count"
        [[ $template_count -gt 0 ]] && echo "    Templates: $template_count"
        [[ $stub_count -gt 0 ]] && echo "    Stubs: $stub_count"
    else
        echo -e "  Registry: ${DIM}Not created (run 'claude agents' to register)${NC}"
    fi
    echo
    
    # Agent System (check actual status)
    echo -e "${BOLD}Agent System:${NC}"
    if [[ -f "$HOME/Documents/claude-backups/agents/src/python/production_orchestrator.py" ]]; then
        echo -e "  Production Orchestrator: ${GREEN}${SUCCESS} Available${NC}"
    else
        echo -e "  Production Orchestrator: ${YELLOW}${WARNING} Not found${NC}"
    fi
    
    # C Binary Layer is typically not active due to microcode restrictions
    echo -e "  C Binary Layer: ${YELLOW}${WARNING} Not active${NC}"
    echo -e "  Note: Using Python fallback mode"
    echo
    
    # Features
    echo -e "${BOLD}Features:${NC}"
    [[ "$PERMISSION_BYPASS" == "true" ]] && echo -e "  Permission Bypass: ${GREEN}Enabled${NC}" || echo -e "  Permission Bypass: ${DIM}Disabled${NC}"
    [[ "$AUTO_FIX" == "true" ]] && echo -e "  Auto-Fix: ${GREEN}Enabled${NC}" || echo -e "  Auto-Fix: ${DIM}Disabled${NC}"
    [[ "$ORCHESTRATION_ENABLED" == "true" ]] && echo -e "  Orchestration: ${GREEN}Enabled${NC}" || echo -e "  Orchestration: ${DIM}Disabled${NC}"
    [[ "$LEARNING_MODE" == "true" ]] && echo -e "  Learning Mode: ${GREEN}Enabled${NC}" || echo -e "  Learning Mode: ${DIM}Disabled${NC}"
    [[ "$DEBUG_MODE" == "true" ]] && echo -e "  Debug Mode: ${GREEN}Active${NC}" || echo -e "  Debug Mode: ${DIM}Inactive${NC}"
    echo -e "  Banner Suppression: ${GREEN}Enabled${NC}"
    echo
    
    # Quick Commands
    echo -e "${BOLD}Quick Commands:${NC}"
    echo "  claude --help          Show help"
    echo "  claude --fix           Auto-fix issues"
    echo "  claude --safe          Run without permission bypass"
    echo "  claude task <text>     Execute a task"
    echo "  claude agent <name>    Run specific agent"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-FIX FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

auto_fix_issues() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Claude Auto-Fix System${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    log_info "Checking for issues..."
    
    # Check Node/npm
    if ! check_node_npm; then
        log_error "Node.js/npm issues detected. Please install Node.js 14+ and npm."
        return 1
    fi
    
    # Find and check Claude binary
    local claude_binary=$(find_claude_binary || echo "")
    if [[ -z "$claude_binary" ]]; then
        log_fixing "Claude not found. Installing..."
        npm install -g @anthropic-ai/claude-code --force
        
        claude_binary=$(find_claude_binary || echo "")
        if [[ -n "$claude_binary" ]]; then
            log_success "Claude installed successfully"
        else
            log_error "Failed to install Claude"
            return 1
        fi
    fi
    
    # Check health
    verify_claude_health "$claude_binary"
    local health_status=$?
    
    case $health_status in
        0)
            log_success "Claude is healthy - no issues found"
            ;;
        2)
            log_fixing "Fixing yoga.wasm issue..."
            fix_yoga_wasm_issue
            
            # Verify fix
            verify_claude_health "$claude_binary"
            if [[ $? -eq 0 ]]; then
                log_success "yoga.wasm issue fixed"
            else
                log_warning "yoga.wasm workaround applied"
            fi
            ;;
        *)
            log_fixing "Attempting general fixes..."
            npm cache clean --force >/dev/null 2>&1
            npm install -g @anthropic-ai/claude-code --force >/dev/null 2>&1
            
            verify_claude_health "$claude_binary"
            if [[ $? -eq 0 ]]; then
                log_success "Issues resolved"
            else
                log_warning "Some issues remain - using workaround mode"
            fi
            ;;
    esac
    
    echo
    log_info "Auto-fix complete. Run 'claude --status' to verify."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT MANAGEMENT WITH AUTOMATIC REGISTRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Agent registry cache
AGENT_REGISTRY_CACHE="$CACHE_DIR/agent_registry.cache"
AGENT_REGISTRY_TIMESTAMP="$CACHE_DIR/agent_registry.timestamp"

# Automatic agent registration from agents/ directory
register_agents_from_directory() {
    local agents_dir="${1:-$CLAUDE_AGENTS_DIR}"
    local registry_file="$CACHE_DIR/registered_agents.json"
    
    if [[ ! -d "$agents_dir" ]]; then
        log_warning "Agents directory not found: $agents_dir"
        return 1
    fi
    
    log_debug "Registering agents from: $agents_dir"
    
    # Create registry file if it doesn't exist
    if [[ ! -f "$registry_file" ]]; then
        echo '{"agents": {}, "last_updated": "", "total_count": 0}' > "$registry_file"
    fi
    
    local agent_count=0
    local updated_agents=()
    
    # Initialize registry JSON
    local temp_registry=$(mktemp)
    echo '{"agents": {}, "last_updated": "'$(date -Iseconds)'", "total_count": 0}' > "$temp_registry"
    
    while IFS= read -r agent_file; do
        if [[ ! -f "$agent_file" ]]; then
            continue
        fi
        
        local agent_name=$(basename "$agent_file" | sed 's/\.[mM][dD]$//' | tr '[:upper:]' '[:lower:]')
        local agent_display_name=$(basename "$agent_file" | sed 's/\.[mM][dD]$//')
        local category="general"
        local description=""
        local uuid=""
        local tools=()
        local status="active"
        
        # Extract metadata from agent file
        if [[ -r "$agent_file" ]]; then
            # Try to extract category from frontmatter or content
            if grep -q "^category:" "$agent_file" 2>/dev/null; then
                category=$(grep "^category:" "$agent_file" | head -1 | sed 's/category: *//; s/[[:space:]]*$//')
            elif grep -qE "^\*\*Category:\*\*" "$agent_file" 2>/dev/null; then
                category=$(grep -E "^\*\*Category:\*\*" "$agent_file" | head -1 | sed 's/^\*\*Category:\*\* *//; s/[[:space:]]*$//')
            fi
            
            # Extract description
            if grep -q "^description:" "$agent_file" 2>/dev/null; then
                description=$(grep "^description:" "$agent_file" | head -1 | sed 's/description: *//; s/[[:space:]]*$//')
            elif grep -qE "^\*\*Purpose:\*\*" "$agent_file" 2>/dev/null; then
                description=$(grep -E "^\*\*Purpose:\*\*" "$agent_file" | head -1 | sed 's/^\*\*Purpose:\*\* *//; s/[[:space:]]*$//')
            elif grep -q "^## Purpose" "$agent_file" 2>/dev/null; then
                description=$(awk '/^## Purpose/{getline; print; exit}' "$agent_file" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            fi
            
            # Extract UUID
            if grep -q "^uuid:" "$agent_file" 2>/dev/null; then
                uuid=$(grep "^uuid:" "$agent_file" | head -1 | sed 's/uuid: *//; s/[[:space:]]*$//')
            elif grep -qE "^\*\*UUID:\*\*" "$agent_file" 2>/dev/null; then
                uuid=$(grep -E "^\*\*UUID:\*\*" "$agent_file" | head -1 | sed 's/^\*\*UUID:\*\* *//; s/[[:space:]]*$//')
            fi
            
            # Extract tools array (simplified - look for tools: section)
            if grep -q "^tools:" "$agent_file" 2>/dev/null; then
                # Extract tools array items (basic implementation)
                while IFS= read -r tool_line; do
                    if [[ "$tool_line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ ]]; then
                        tools+=("${BASH_REMATCH[1]}")
                    fi
                done < <(awk '/^tools:/,/^[^[:space:]-]/ {if ($0 ~ /^[[:space:]]*-/) print $0}' "$agent_file" | head -10)
            fi
            
            # Determine status based on file completeness
            local file_size=$(stat -f%z "$agent_file" 2>/dev/null || stat -c%s "$agent_file" 2>/dev/null || echo "0")
            if [[ $file_size -lt 100 ]]; then
                status="stub"
            elif ! grep -q "## Implementation" "$agent_file" 2>/dev/null; then
                status="template"
            else
                status="active"
            fi
        fi
        
        # Build JSON entry for this agent
        local tools_json=""
        if [[ ${#tools[@]} -gt 0 ]]; then
            tools_json=$(printf '"%s",' "${tools[@]}")
            tools_json="[${tools_json%,}]"
        else
            tools_json="[]"
        fi
        
        # Add agent to temporary registry
        local agent_json='{
            "name": "'$agent_name'",
            "display_name": "'$agent_display_name'",
            "file_path": "'$agent_file'",
            "category": "'${category:-general}'",
            "description": "'${description:-No description available}'",
            "uuid": "'${uuid:-unknown}'",
            "tools": '$tools_json',
            "status": "'$status'",
            "last_modified": "'$(date -r "$agent_file" -Iseconds 2>/dev/null || date -Iseconds)'"
        }'
        
        # Use python or node to properly merge JSON (fallback to simple method)
        if command_exists python3; then
            python3 -c "
import json, sys
try:
    with open('$temp_registry', 'r') as f: registry = json.load(f)
    registry['agents']['$agent_name'] = $agent_json
    registry['total_count'] = len(registry['agents'])
    with open('$temp_registry', 'w') as f: json.dump(registry, f, indent=2)
except Exception as e:
    print(f'JSON merge error: {e}', file=sys.stderr)
            " 2>/dev/null || log_debug "Python JSON merge failed for agent: $agent_name"
        fi
        
        updated_agents+=("$agent_name")
        ((agent_count++))
        
        log_debug "Registered agent: $agent_name [$category] - $status"
        
    done < <(find "$agents_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | grep -v -i template | head -100)
    
    # Move temporary registry to final location
    if [[ -s "$temp_registry" ]]; then
        mv "$temp_registry" "$registry_file"
        echo "$agent_count" > "$CACHE_DIR/agent_count.cache"
        echo "${updated_agents[*]}" > "$CACHE_DIR/agent_names.cache"
        log_debug "Agent registration complete: $agent_count agents registered"
        return 0
    else
        rm -f "$temp_registry" 2>/dev/null
        log_warning "Agent registration failed - no agents found or processed"
        return 1
    fi
}

# Get registered agent information
get_agent_info() {
    local agent_name="$1"
    local registry_file="$CACHE_DIR/registered_agents.json"
    
    if [[ ! -f "$registry_file" ]]; then
        return 1
    fi
    
    if command_exists python3; then
        python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agent = registry['agents'].get('${agent_name,,}')
    if agent:
        print(f\"Name: {agent['display_name']}\")
        print(f\"Category: {agent['category']}\")
        print(f\"Status: {agent['status']}\")
        print(f\"Description: {agent['description']}\")
        print(f\"File: {agent['file_path']}\")
        if agent['tools']:
            print(f\"Tools: {', '.join(agent['tools'])}\")
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
        " 2>/dev/null
    else
        # Fallback: try to find agent file directly
        find_agent_file "$agent_name" >/dev/null 2>&1
    fi
}

# Find agent file (enhanced version)
find_agent_file() {
    local agent_name="$1"
    local agents_dir="${CLAUDE_AGENTS_DIR}"
    
    # Try multiple name variations and locations
    local search_patterns=(
        "${agents_dir}/${agent_name}.md"
        "${agents_dir}/${agent_name}.MD"
        "${agents_dir}/${agent_name^^}.md"
        "${agents_dir}/${agent_name,,}.md"
        "${agents_dir}/*${agent_name,,}*.md"
        "${agents_dir}/*${agent_name^^}*.md"
    )
    
    for pattern in "${search_patterns[@]}"; do
        local matches=($(ls $pattern 2>/dev/null | head -5))
        if [[ ${#matches[@]} -gt 0 ]]; then
            echo "${matches[0]}"
            return 0
        fi
    done
    
    return 1
}

list_agents() {
    echo -e "${CYAN}${BOLD}Available Agents:${NC}"
    echo
    
    # Auto-register agents if not already done or if directory is newer
    local registry_file="$CACHE_DIR/registered_agents.json"
    local should_register=false
    
    if [[ ! -f "$registry_file" ]]; then
        should_register=true
    elif [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        # Check if agents directory is newer than registry
        local agents_newer=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" -newer "$registry_file" 2>/dev/null | wc -l)
        [[ $agents_newer -gt 0 ]] && should_register=true
    fi
    
    if $should_register; then
        log_debug "Auto-registering agents from directory..."
        register_agents_from_directory "$CLAUDE_AGENTS_DIR"
    fi
    
    # Display registered agents
    if [[ -f "$registry_file" ]] && command_exists python3; then
        python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    
    agents = registry.get('agents', {})
    if not agents:
        print('  No agents registered')
        sys.exit(0)
    
    # Group by category
    categories = {}
    for name, agent in agents.items():
        cat = agent.get('category', 'general')
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(agent)
    
    # Display by category
    for category in sorted(categories.keys()):
        print(f'\\n  \\033[1;33m{category.title()}:\\033[0m')
        agents_in_cat = sorted(categories[category], key=lambda x: x['display_name'])
        for agent in agents_in_cat:
            status_color = '\\033[0;32m' if agent['status'] == 'active' else '\\033[0;33m' if agent['status'] == 'template' else '\\033[0;31m'
            status_symbol = '✓' if agent['status'] == 'active' else '○' if agent['status'] == 'template' else '✗'
            print(f'    {status_color}{status_symbol}\\033[0m \\033[1m{agent[\"display_name\"]:<18}\\033[0m \\033[2m{agent[\"description\"][:50]}\\033[0m')
    
    print(f'\\n  Total: {len(agents)} agents')
    print(f'  Active: {sum(1 for a in agents.values() if a[\"status\"] == \"active\")}')
    print(f'  Templates: {sum(1 for a in agents.values() if a[\"status\"] == \"template\")}')
    print(f'  Stubs: {sum(1 for a in agents.values() if a[\"status\"] == \"stub\")}')
    
except Exception as e:
    print(f'Error reading agent registry: {e}', file=sys.stderr)
    sys.exit(1)
        "
    else
        # Fallback: simple directory listing
        if [[ ! -d "$CLAUDE_AGENTS_DIR" ]]; then
            log_warning "Agents directory not found: $CLAUDE_AGENTS_DIR"
            return 1
        fi
        
        local count=0
        while IFS= read -r agent_file; do
            local agent_name=$(basename "$agent_file" | sed 's/\.[mM][dD]$//')
            local category="general"
            
            # Try to extract category from frontmatter
            if grep -q "^category:" "$agent_file" 2>/dev/null; then
                category=$(grep "^category:" "$agent_file" | head -1 | sed 's/category: *//')
            fi
            
            printf "  %-20s ${DIM}[%s]${NC}\n" "$agent_name" "$category"
            ((count++))
        done < <(find "$CLAUDE_AGENTS_DIR" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | sort)
        
        echo
        echo "Total: $count agents"
    fi
}

run_agent() {
    local agent_name="$1"
    shift
    
    if [[ -z "$agent_name" ]]; then
        log_error "Usage: claude agent <name> [args]"
        return 1
    fi
    
    # Ensure agents are registered
    local registry_file="$CACHE_DIR/registered_agents.json"
    if [[ ! -f "$registry_file" ]]; then
        log_debug "Registering agents for first run..."
        register_agents_from_directory "$CLAUDE_AGENTS_DIR"
    fi
    
    # Try to get agent info from registry first
    local agent_file=""
    if get_agent_info "$agent_name" >/dev/null 2>&1; then
        # Get file path from registry
        if command_exists python3; then
            agent_file=$(python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agent = registry['agents'].get('${agent_name,,}')
    if agent:
        print(agent['file_path'])
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
            " 2>/dev/null)
        fi
    fi
    
    # Fallback to manual search
    if [[ -z "$agent_file" ]]; then
        agent_file=$(find_agent_file "$agent_name")
    fi
    
    if [[ -z "$agent_file" ]] || [[ ! -f "$agent_file" ]]; then
        log_error "Agent not found: $agent_name"
        echo
        echo -e "${CYAN}Available agents:${NC}"
        if [[ -f "$registry_file" ]] && command_exists python3; then
            python3 -c "
import json
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agents = list(registry.get('agents', {}).keys())[:10]  # Show first 10
    for agent in sorted(agents):
        print(f'  - {agent}')
    if len(registry.get('agents', {})) > 10:
        print(f'  ... and {len(registry.get(\"agents\", {})) - 10} more')
except Exception:
    pass
            " 2>/dev/null
        fi
        echo -e "\nRun 'claude agents' to see all available agents"
        return 1
    fi
    
    # Display agent info if available
    log_info "Loading agent: $agent_name"
    if get_agent_info "$agent_name" >/dev/null 2>&1; then
        get_agent_info "$agent_name" | while read -r line; do
            log_debug "$line"
        done
    fi
    
    export CLAUDE_AGENT="$agent_name"
    export CLAUDE_AGENT_FILE="$agent_file"
    
    execute_claude "$CLAUDE_BINARY" "$@"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Initialize environment
    initialize_environment
    
    # Handle special commands
    case "${1:-}" in
        --status|status)
            show_status
            exit 0
            ;;
            
        --fix|fix)
            auto_fix_issues
            exit $?
            ;;
            
        --agents|agents|--list-agents)
            list_agents
            exit 0
            ;;
            
        --register-agents|register-agents)
            echo -e "${CYAN}${BOLD}Registering agents from directory...${NC}"
            if register_agents_from_directory "$CLAUDE_AGENTS_DIR"; then
                log_success "Agents registered successfully"
                echo
                list_agents
            else
                log_error "Failed to register agents"
                exit 1
            fi
            exit 0
            ;;
            
        --agent|agent)
            shift
            run_agent "$@"
            exit $?
            ;;
            
        --agent-info)
            shift
            local agent_name="$1"
            if [[ -z "$agent_name" ]]; then
                log_error "Usage: claude --agent-info <name>"
                exit 1
            fi
            
            echo -e "${CYAN}${BOLD}Agent Information: $agent_name${NC}"
            echo
            if get_agent_info "$agent_name"; then
                exit 0
            else
                log_error "Agent not found: $agent_name"
                echo -e "\nRun 'claude agents' to see available agents"
                exit 1
            fi
            ;;
            
        --help|help|-h)
            echo -e "${CYAN}${BOLD}Claude Ultimate Wrapper v13.1${NC}"
            echo -e "${DIM}Enhanced with automatic agent registration and management${NC}"
            echo
            echo "Usage: claude [OPTIONS] [COMMAND]"
            echo
            echo "Options:"
            echo "  --status           Show comprehensive system status"
            echo "  --fix              Auto-detect and fix issues"
            echo "  --agents           List available agents with categories"
            echo "  --register-agents  Manually register agents from agents/ directory"
            echo "  --agent NAME       Run specific agent"
            echo "  --agent-info NAME  Show detailed information about an agent"
            echo "  --safe             Run without permission bypass"
            echo "  --debug            Enable debug output"
            echo "  --help             Show this help"
            echo
            echo "Commands:"
            echo "  task <text>        Execute a task"
            echo "  agent <name>       Shortcut for --agent"
            echo "  <any>              Pass through to Claude"
            echo
            echo "Agent Management:"
            echo "  • Agents are automatically discovered from agents/ directory"
            echo "  • Registry is cached and updated when directory changes"
            echo "  • Supports metadata extraction (category, description, tools)"
            echo "  • Status tracking (active/template/stub)"
            echo
            echo "Environment Variables:"
            echo "  CLAUDE_AUTO_FIX=true         Enable automatic issue fixing"
            echo "  CLAUDE_PERMISSION_BYPASS=true Enable permission bypass"
            echo "  CLAUDE_DEBUG=true            Enable debug mode"
            echo "  CLAUDE_PROJECT_ROOT          Set project root directory"
            echo "  CLAUDE_AGENTS_DIR            Path to agents directory"
            echo "  CLAUDE_VENV                  Path to Python virtual environment"
            echo
            echo "Examples:"
            echo "  claude agents                List all available agents"
            echo "  claude agent director        Run the director agent"
            echo "  claude --agent-info security Show security agent details"
            echo "  claude --register-agents     Refresh agent registry"
            echo
            echo "Troubleshooting:"
            echo "  If Claude fails to start, run: claude --fix"
            echo "  For detailed diagnostics: claude --status"
            echo "  For debug output: claude --debug [command]"
            echo "  If agents not found: claude --register-agents"
            exit 0
            ;;
            
        --debug)
            # Already handled at top, just shift and continue
            shift
            ;;
    esac
    
    # Find Claude binary
    CLAUDE_BINARY=$(find_claude_binary || echo "")
    
    if [[ -z "$CLAUDE_BINARY" ]]; then
        log_error "Claude not found. Installing..."
        
        if [[ "$AUTO_FIX" == "true" ]]; then
            npm install -g @anthropic-ai/claude-code --force
            CLAUDE_BINARY=$(find_claude_binary || echo "")
            
            if [[ -z "$CLAUDE_BINARY" ]]; then
                log_error "Failed to install Claude Code"
                echo "Try manual installation: npm install -g @anthropic-ai/claude-code"
                exit 1
            fi
        else
            echo "Install with: npm install -g @anthropic-ai/claude-code"
            echo "Or enable auto-fix: export CLAUDE_AUTO_FIX=true"
            exit 1
        fi
    fi
    
    # Health check
    verify_claude_health "$CLAUDE_BINARY"
    local health_status=$?
    
    if [[ $health_status -ne 0 ]] && [[ "$AUTO_FIX" == "true" ]]; then
        log_info "Applying automatic fixes..."
        
        case $health_status in
            2) fix_yoga_wasm_issue ;;
            *) 
                # Try general fix
                export NODE_OPTIONS="--no-warnings"
                export CLAUDE_NO_YOGA=1
                ;;
        esac
    fi
    
    # Execute Claude
    execute_claude "$CLAUDE_BINARY" "$@"
}

# Error trap with helpful messages
trap 'ec=$?; [[ $ec -ne 0 ]] && log_error "Error at line $LINENO (exit code: $ec). Run with --debug for details." >&2' ERR

# Run main
main "$@"