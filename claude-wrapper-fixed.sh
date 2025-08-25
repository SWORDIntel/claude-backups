#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v13.2 - FIXED BASH OUTPUT
# 
# Changes from v13.1:
# • Removed aggressive output suppression
# • Made quiet mode optional via environment variable
# • Fixed exec output handling
# • Preserved all other functionality
# ═══════════════════════════════════════════════════════════════════════════

# Don't exit on errors - handle them gracefully
set +e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT CONTROL - CONFIGURABLE (FIXED)
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
# SMART EXECUTION WITH FALLBACKS (FIXED OUTPUT HANDLING)
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
    echo -e "${CYAN}${BOLD}          Claude Ultimate Wrapper v13.2 Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # System Info
    echo -e "${BOLD}System:${NC}"
    echo "  OS: $(uname -s 2>/dev/null || echo 'Unknown')"
    echo "  User: $USER"
    echo "  Shell: ${SHELL##*/}"
    echo
    
    # Output Control Status
    echo -e "${BOLD}Output Control:${NC}"
    if [[ "${CLAUDE_FORCE_QUIET:-false}" == "true" ]]; then
        echo -e "  Mode: ${YELLOW}${WARNING} Quiet Mode Forced${NC}"
        echo "  To enable output: unset CLAUDE_FORCE_QUIET"
    else
        echo -e "  Mode: ${GREEN}${SUCCESS} Normal Output Enabled${NC}"
        echo "  Bash output: Working"
    fi
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
    echo
    
    # Features
    echo -e "${BOLD}Features:${NC}"
    [[ "$PERMISSION_BYPASS" == "true" ]] && echo -e "  Permission Bypass: ${GREEN}Enabled${NC}" || echo -e "  Permission Bypass: ${DIM}Disabled${NC}"
    [[ "$AUTO_FIX" == "true" ]] && echo -e "  Auto-Fix: ${GREEN}Enabled${NC}" || echo -e "  Auto-Fix: ${DIM}Disabled${NC}"
    [[ "$ORCHESTRATION_ENABLED" == "true" ]] && echo -e "  Orchestration: ${GREEN}Enabled${NC}" || echo -e "  Orchestration: ${DIM}Disabled${NC}"
    [[ "$LEARNING_MODE" == "true" ]] && echo -e "  Learning Mode: ${GREEN}Enabled${NC}" || echo -e "  Learning Mode: ${DIM}Disabled${NC}"
    [[ "$DEBUG_MODE" == "true" ]] && echo -e "  Debug Mode: ${GREEN}Active${NC}" || echo -e "  Debug Mode: ${DIM}Inactive${NC}"
    echo
    
    # Quick Commands
    echo -e "${BOLD}Quick Commands:${NC}"
    echo "  claude --help          Show help"
    echo "  claude --fix           Auto-fix issues"
    echo "  claude --safe          Run without permission bypass"
    echo "  claude --quiet         Force quiet mode (suppress output)"
    echo "  claude task <text>     Execute a task"
    echo "  claude agent <name>    Run specific agent"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION (Rest remains the same, omitted for brevity)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# [Include all the rest of the functions from the original script here...]
# auto_fix_issues, register_agents_from_directory, get_agent_info, 
# find_agent_file, list_agents, run_agent, main

# Note: The main function and other functions remain the same
# Only the output control and execute_claude functions were modified

# Copy the rest of the original script from line 555 onwards...