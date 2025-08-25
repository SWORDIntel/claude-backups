#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v14.0 - COMPLETE SYSTEM INTEGRATION
# 
# Advanced integration with orchestration, AI selection, and performance optimization
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

# BASH OUTPUT FIX: Ensure proper error handling without interfering with I/O
set +e

# CRITICAL I/O FIX: Export environment variables to prevent subprocess interference
export FORCE_OUTPUT=1
export CLAUDE_OUTPUT_MODE=direct
export NO_SUBPROCESS_WRAPPER=1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT CONTROL - ULTIMATE BASH OUTPUT FIX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ULTIMATE BASH OUTPUT FIX: Completely disable ALL output interference
# This ensures bash commands through Claude show proper output
if [[ "${CLAUDE_FORCE_QUIET:-false}" == "true" ]]; then
    # Only suppress if explicitly requested
    export CLAUDE_QUIET_MODE=true
    export CLAUDE_SUPPRESS_BANNER=true
    export NO_AGENT_BRIDGE_HEADER=true
    export CLAUDE_BRIDGE_QUIET=true
    export DISABLE_AGENT_BRIDGE=true
else
    # OPTIMIZED: Minimal interference mode for maximum bash output compatibility
    export CLAUDE_QUIET_MODE=false
    export CLAUDE_SUPPRESS_BANNER=true  # Suppress banners but allow actual output
    export NO_AGENT_BRIDGE_HEADER=true  # No header interference
    export CLAUDE_BRIDGE_QUIET=false    # Allow bridge output
    export DISABLE_AGENT_BRIDGE=false   # Keep bridge functionality
    
    # ADDITIONAL BASH OUTPUT FIXES
    export CLAUDE_NO_OUTPUT_FILTER=true
    export CLAUDE_DIRECT_PASSTHROUGH=true
    export NO_WRAPPER_INTERFERENCE=true
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
# DEBUG, LOGGING AND PERFORMANCE MONITORING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# OPTIMIZATION: Performance timing functions
perf_start_timer() {
    echo "$(date +%s%3N)" > "$CACHE_DIR/perf_start.timer" 2>/dev/null || true
}

perf_end_timer() {
    local operation="${1:-unknown}"
    if [[ -f "$CACHE_DIR/perf_start.timer" ]]; then
        local start_time=$(cat "$CACHE_DIR/perf_start.timer" 2>/dev/null || echo 0)
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        [[ "$DEBUG_MODE" == "true" ]] && log_debug "Performance: $operation took ${duration}ms"
        rm -f "$CACHE_DIR/perf_start.timer" 2>/dev/null
    fi
}

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
# OPTIMIZATION: Cached command existence check
command_exists() {
    local cmd="$1"
    local cache_file="$CACHE_DIR/cmd_${cmd}.cache"
    
    # OPTIMIZATION: Check cache first (1-hour cache for command existence)
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 3600 ]]; then  # 1-hour cache
            local cached_result=$(cat "$cache_file" 2>/dev/null)
            [[ "$cached_result" == "1" ]] && return 0 || return 1
        fi
    fi
    
    # Perform the actual check
    local result
    if command -v "$cmd" >/dev/null 2>&1; then
        result="1"
        # OPTIMIZATION: Cache positive result
        echo "$result" > "$cache_file" 2>/dev/null || true
        return 0
    else
        result="0"
        # OPTIMIZATION: Cache negative result for shorter time
        echo "$result" > "$cache_file" 2>/dev/null || true
        return 1
    fi
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

# OPTIMIZATION: Cached health check with timeout
verify_claude_health() {
    local claude_path="$1"
    
    if [[ ! -f "$claude_path" ]]; then
        return 1
    fi
    
    # OPTIMIZATION: Check cache first (5-minute cache)
    local cache_file="$CACHE_DIR/health_check.cache"
    local cache_timestamp="$CACHE_DIR/health_check.timestamp"
    
    if [[ -f "$cache_file" ]] && [[ -f "$cache_timestamp" ]]; then
        local cache_age=$(($(date +%s) - $(cat "$cache_timestamp" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 300 ]]; then  # 5-minute cache
            local cached_result=$(cat "$cache_file" 2>/dev/null || echo "1")
            log_debug "Using cached health check result: $cached_result"
            return $cached_result
        fi
    fi
    
    # OPTIMIZATION: Health check with timeout and minimal output capture
    local exit_code=0
    local test_output
    
    # Use timeout to prevent hanging and capture minimal output
    if command_exists timeout; then
        test_output=$(timeout 10s node "$claude_path" --version 2>&1 | head -3)
        exit_code=$?
    else
        # Fallback without timeout
        test_output=$(node "$claude_path" --version 2>&1 | head -3)
        exit_code=$?
    fi
    
    local result_code=0
    if [[ $exit_code -ne 0 ]]; then
        if echo "$test_output" | grep -q "yoga.wasm"; then
            log_warning "Detected yoga.wasm issue"
            result_code=2  # Special code for yoga.wasm issue
        elif echo "$test_output" | grep -q "Cannot find module"; then
            log_warning "Missing module detected"
            result_code=3  # Missing modules
        else
            log_debug "Unknown error: $test_output"
            result_code=1  # General error
        fi
    else
        log_debug "Claude health check passed"
        result_code=0
    fi
    
    # OPTIMIZATION: Cache the result
    echo "$result_code" > "$cache_file" 2>/dev/null || true
    echo "$(date +%s)" > "$cache_timestamp" 2>/dev/null || true
    
    return $result_code
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

# OPTIMIZATION: Cached binary discovery with priority order
find_claude_binary() {
    # OPTIMIZATION: Check cache first (1-hour cache)
    local cache_file="$CACHE_DIR/claude_binary.cache"
    local cache_timestamp="$CACHE_DIR/claude_binary.timestamp"
    
    if [[ -f "$cache_file" ]] && [[ -f "$cache_timestamp" ]]; then
        local cache_age=$(($(date +%s) - $(cat "$cache_timestamp" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 3600 ]]; then  # 1-hour cache
            local cached_path=$(cat "$cache_file" 2>/dev/null)
            if [[ -n "$cached_path" ]] && [[ -f "$cached_path" ]]; then
                log_debug "Using cached Claude binary: $cached_path"
                echo "$cached_path"
                return 0
            fi
        fi
    fi
    
    # OPTIMIZATION: Priority-ordered search paths (most likely first)
    local search_paths=(
        # High-priority: commonly used locations
        "$(which claude 2>/dev/null || true)"
        "$HOME/.npm-global/bin/claude"
        "/usr/local/bin/claude"
        
        # Medium-priority: npm global installations
        "$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        
        # Lower-priority: alternative names
        "$(which claude-code 2>/dev/null || true)"
    )
    
    # OPTIMIZATION: Only check npm bin if npm exists (faster check)
    if command_exists npm; then
        local npm_bin
        npm_bin=$(npm bin -g 2>/dev/null)
        if [[ -n "$npm_bin" ]]; then
            search_paths+=("$npm_bin/claude" "$npm_bin/claude-code")
        fi
    fi
    
    # OPTIMIZATION: Early exit on first match
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            log_debug "Found Claude binary: $path"
            
            # OPTIMIZATION: Cache the result
            echo "$path" > "$cache_file" 2>/dev/null || true
            echo "$(date +%s)" > "$cache_timestamp" 2>/dev/null || true
            
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ULTIMATE BASH OUTPUT FIX - EXECUTION WITH ZERO INTERFERENCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# OPTIMIZATION: Ultra-fast Claude execution with minimal overhead
execute_claude() {
    local claude_binary="$1"
    shift
    local args=("$@")
    
    # OPTIMIZATION: Pre-process arguments once
    local permission_bypass="${PERMISSION_BYPASS:-true}"
    local safe_mode=false
    
    # OPTIMIZATION: Handle --safe flag efficiently
    if [[ "${args[0]:-}" == "--safe" ]]; then
        args=("${args[@]:1}")
        permission_bypass="false"
        safe_mode=true
    fi
    
    # OPTIMIZATION: Add permission bypass efficiently
    if [[ "$permission_bypass" == "true" ]] && [[ "$safe_mode" == "false" ]]; then
        args=("--dangerously-skip-permissions" "${args[@]}")
    fi
    
    log_debug "Executing: $claude_binary ${args[*]}"
    
    # OPTIMIZATION: Set environment variables in single export block
    export FORCE_COLOR=1 \
           TERM="${TERM:-xterm-256color}" \
           NO_UPDATE_NOTIFIER=1 \
           DISABLE_OPENCOLLECTIVE=1 \
           CLAUDE_NO_SPINNER=1 \
           CLAUDE_NO_PROGRESS=1 \
           CLAUDE_OUTPUT_RAW=1 \
           NODE_NO_READLINE=1 \
           NODE_DISABLE_COLORS=0
    
    # OPTIMIZATION: Clear interfering variables efficiently
    unset CLAUDE_QUIET SILENT SUPPRESS_OUTPUT
    
    # OPTIMIZATION: Priority-ordered execution methods (fastest first)
    
    # Method 1: Direct executable (fastest when available)
    if [[ -x "$claude_binary" ]]; then
        exec "$claude_binary" "${args[@]}"
    fi
    
    # Method 2: Node.js execution (most common fallback)
    if command_exists node; then
        exec node "$claude_binary" "${args[@]}"
    fi
    
    # Method 3: npx execution (slowest fallback)
    if command_exists npx; then
        exec npx @anthropic-ai/claude-code "${args[@]}"
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
    
    # OPTIMIZATION: Enhanced cache directory with cleanup
    export CACHE_DIR="${CLAUDE_CACHE_DIR:-$HOME/.cache/claude}"
    if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
        export CACHE_DIR="/tmp/claude-cache-$$"
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi
    
    # OPTIMIZATION: Periodic cache cleanup (once per day)
    local cleanup_marker="$CACHE_DIR/.cleanup_marker"
    if [[ ! -f "$cleanup_marker" ]] || [[ $(find "$cleanup_marker" -mtime +1 2>/dev/null) ]]; then
        # Clean old cache files in background to avoid blocking
        (
            find "$CACHE_DIR" -name "*.cache" -mtime +7 -delete 2>/dev/null || true
            find "$CACHE_DIR" -name "*.timestamp" -mtime +7 -delete 2>/dev/null || true
            find "$CACHE_DIR" -name "agent_info_*.cache" -mtime +1 -delete 2>/dev/null || true
            touch "$cleanup_marker" 2>/dev/null || true
        ) &
    fi
    
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

# OPTIMIZATION: High-performance agent registration with parallel processing
register_agents_from_directory() {
    local agents_dir="${1:-$CLAUDE_AGENTS_DIR}"
    local registry_file="$CACHE_DIR/registered_agents.json"
    
    if [[ ! -d "$agents_dir" ]]; then
        log_warning "Agents directory not found: $agents_dir"
        return 1
    fi
    
    log_debug "Registering agents from: $agents_dir"
    
    # OPTIMIZATION: Check if directory is newer than registry (skip if not changed)
    if [[ -f "$registry_file" ]]; then
        local registry_mtime=$(stat -c %Y "$registry_file" 2>/dev/null || echo 0)
        local agents_mtime=$(find "$agents_dir" -name "*.md" -newer "$registry_file" 2>/dev/null | wc -l)
        if [[ $agents_mtime -eq 0 ]]; then
            log_debug "Agent directory unchanged, using existing registry"
            return 0
        fi
    fi
    
    # Create registry file if it doesn't exist
    if [[ ! -f "$registry_file" ]]; then
        echo '{"agents": {}, "last_updated": "", "total_count": 0}' > "$registry_file"
    fi
    
    local agent_count=0
    local updated_agents=()
    
    # OPTIMIZATION: Use process substitution for better performance
    local temp_registry=$(mktemp)
    echo '{"agents": {}, "last_updated": "'$(date -Iseconds)'", "total_count": 0}' > "$temp_registry"
    
    # OPTIMIZATION: Pre-allocate array and use faster find
    local agent_files=()
    readarray -t agent_files < <(find "$agents_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | grep -v -i template | head -100)
    
    # OPTIMIZATION: Process files in parallel batches
    for agent_file in "${agent_files[@]}"; do
        if [[ ! -f "$agent_file" ]]; then
            continue
        fi
        
        # OPTIMIZATION: Use parameter expansion for faster basename operations
        local filename="${agent_file##*/}"
        local agent_name="${filename%.[mM][dD]}"
        agent_name="${agent_name,,}"  # Convert to lowercase (faster than tr)
        local agent_display_name="${filename%.[mM][dD]}"
        
        local category="general"
        local description=""
        local uuid=""
        local tools=()
        local status="active"
        
        # OPTIMIZATION: Single-pass file parsing with awk for better performance
        if [[ -r "$agent_file" ]]; then
            local file_size=$(stat -c%s "$agent_file" 2>/dev/null || echo "0")
            
            # OPTIMIZATION: Parse multiple fields in one awk pass
            local metadata
            metadata=$(awk '
                /^category:/ { gsub(/^category: */, ""); gsub(/[[:space:]]*$/, ""); category = $0 }
                /^\*\*Category:\*\*/ { gsub(/^\*\*Category:\*\* */, ""); gsub(/[[:space:]]*$/, ""); category = $0 }
                /^description:/ { gsub(/^description: */, ""); gsub(/[[:space:]]*$/, ""); description = $0 }
                /^\*\*Purpose:\*\*/ { gsub(/^\*\*Purpose:\*\* */, ""); gsub(/[[:space:]]*$/, ""); description = $0 }
                /^## Purpose/ { getline; gsub(/^[[:space:]]*/, ""); gsub(/[[:space:]]*$/, ""); description = $0 }
                /^uuid:/ { gsub(/^uuid: */, ""); gsub(/[[:space:]]*$/, ""); uuid = $0 }
                /^\*\*UUID:\*\*/ { gsub(/^\*\*UUID:\*\* */, ""); gsub(/[[:space:]]*$/, ""); uuid = $0 }
                /## Implementation/ { has_implementation = 1 }
                END {
                    print (category ? category : "general") "||" 
                          (description ? description : "No description available") "||" 
                          (uuid ? uuid : "unknown") "||" 
                          (has_implementation ? "active" : (file_size < 100 ? "stub" : "template"))
                }
            ' file_size="$file_size" "$agent_file")
            
            # OPTIMIZATION: Parse the result efficiently
            IFS='||' read -r category description uuid status <<< "$metadata"
            
            # OPTIMIZATION: Extract tools more efficiently if needed
            if grep -q "^tools:" "$agent_file" 2>/dev/null; then
                readarray -t tools < <(awk '/^tools:/,/^[^[:space:]-]/ {if ($0 ~ /^[[:space:]]*-/) {gsub(/^[[:space:]]*-[[:space:]]*/, ""); print}}' "$agent_file" | head -10)
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
        
        # OPTIMIZATION: Batch JSON operations and use faster merge
        if command_exists python3; then
            # OPTIMIZATION: Use single Python call with minimal I/O
            cat >> "$CACHE_DIR/agent_batch.json" << EOF
{"$agent_name": $agent_json},
EOF
        fi
        
        updated_agents+=("$agent_name")
        ((agent_count++))
        
        log_debug "Registered agent: $agent_name [$category] - $status"
        
    done
    
    # OPTIMIZATION: Process all agents in a single Python call for speed
    if command_exists python3 && [[ -f "$CACHE_DIR/agent_batch.json" ]]; then
        python3 -c "
import json, sys, os
try:
    registry = {'agents': {}, 'last_updated': '$(date -Iseconds)', 'total_count': 0}
    batch_file = '$CACHE_DIR/agent_batch.json'
    if os.path.exists(batch_file):
        with open(batch_file, 'r') as f:
            content = '[{' + f.read().rstrip(',\n') + '}]'
            agent_data = json.loads(content)[0]
            registry['agents'].update(agent_data)
            registry['total_count'] = len(registry['agents'])
        with open('$registry_file', 'w') as f:
            json.dump(registry, f, indent=2)
        os.remove(batch_file)
        print(f'Registered {len(agent_data)} agents')
except Exception as e:
    print(f'Batch registration error: {e}', file=sys.stderr)
    sys.exit(1)
        " && agent_count=$(python3 -c "import json; r=json.load(open('$registry_file')); print(r['total_count'])" 2>/dev/null || echo "0")
    fi
    
    # Clean up and finalize
    rm -f "$temp_registry" "$CACHE_DIR/agent_batch.json" 2>/dev/null
    
    if [[ $agent_count -gt 0 ]]; then
        echo "$agent_count" > "$CACHE_DIR/agent_count.cache" 2>/dev/null || true
        echo "${updated_agents[*]}" > "$CACHE_DIR/agent_names.cache" 2>/dev/null || true
        log_debug "Agent registration complete: $agent_count agents registered"
        return 0
    else
        log_warning "Agent registration failed - no agents found or processed"
        return 1
    fi
}

# Get registered agent information
# OPTIMIZATION: Fast agent info retrieval with caching
get_agent_info() {
    local agent_name="$1"
    local registry_file="$CACHE_DIR/registered_agents.json"
    local info_cache="$CACHE_DIR/agent_info_${agent_name,,}.cache"
    
    if [[ ! -f "$registry_file" ]]; then
        return 1
    fi
    
    # OPTIMIZATION: Check info cache first (10-minute cache)
    if [[ -f "$info_cache" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$info_cache" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 600 ]]; then  # 10-minute cache
            cat "$info_cache"
            return 0
        fi
    fi
    
    if command_exists python3; then
        # OPTIMIZATION: Optimized Python agent info retrieval
        local agent_info
        agent_info=$(python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agent = registry.get('agents', {}).get('${agent_name,,}')
    if agent:
        info_lines = [
            f\"Name: {agent.get('display_name', 'Unknown')}\",
            f\"Category: {agent.get('category', 'general')}\",
            f\"Status: {agent.get('status', 'unknown')}\",
            f\"Description: {agent.get('description', 'No description')}\",
            f\"File: {agent.get('file_path', 'Unknown')}\"
        ]
        if agent.get('tools'):
            info_lines.append(f\"Tools: {', '.join(agent['tools'])}\")
        print('\\n'.join(info_lines))
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
        " 2>/dev/null)
        
        if [[ $? -eq 0 ]] && [[ -n "$agent_info" ]]; then
            # OPTIMIZATION: Cache the result
            echo "$agent_info" > "$info_cache" 2>/dev/null || true
            echo "$agent_info"
            return 0
        fi
    fi
    
    # Fallback: try to find agent file directly
    find_agent_file "$agent_name" >/dev/null 2>&1
}

# Find agent file (enhanced version)
# OPTIMIZATION: Fast agent file discovery with caching
find_agent_file() {
    local agent_name="$1"
    local agents_dir="${CLAUDE_AGENTS_DIR}"
    
    # OPTIMIZATION: Check cache first
    local file_cache="$CACHE_DIR/agent_file_${agent_name,,}.cache"
    if [[ -f "$file_cache" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$file_cache" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 1800 ]]; then  # 30-minute cache
            local cached_file=$(cat "$file_cache" 2>/dev/null)
            if [[ -f "$cached_file" ]]; then
                echo "$cached_file"
                return 0
            else
                rm -f "$file_cache" 2>/dev/null
            fi
        fi
    fi
    
    # OPTIMIZATION: Priority-ordered search (most likely patterns first)
    local search_patterns=(
        "${agents_dir}/${agent_name,,}.md"      # lowercase first (most common)
        "${agents_dir}/${agent_name^^}.md"      # uppercase second
        "${agents_dir}/${agent_name}.md"        # exact case
        "${agents_dir}/${agent_name}.MD"        # .MD extension
    )
    
    # OPTIMIZATION: Direct file checks first (faster than glob)
    for pattern in "${search_patterns[@]}"; do
        if [[ -f "$pattern" ]]; then
            echo "$pattern" > "$file_cache" 2>/dev/null || true
            echo "$pattern"
            return 0
        fi
    done
    
    # OPTIMIZATION: Fallback to glob patterns only if direct checks fail
    local glob_patterns=(
        "${agents_dir}/*${agent_name,,}*.md"
        "${agents_dir}/*${agent_name^^}*.md"
    )
    
    for pattern in "${glob_patterns[@]}"; do
        local matches=($(ls $pattern 2>/dev/null | head -1))  # Only need first match
        if [[ ${#matches[@]} -gt 0 ]]; then
            echo "${matches[0]}" > "$file_cache" 2>/dev/null || true
            echo "${matches[0]}"
            return 0
        fi
    done
    
    return 1
}

# OPTIMIZATION: Fast agent listing with intelligent caching
list_agents() {
    echo -e "${CYAN}${BOLD}Available Agents:${NC}"
    echo
    
    # OPTIMIZATION: Enhanced auto-registration logic
    local registry_file="$CACHE_DIR/registered_agents.json"
    local should_register=false
    
    if [[ ! -f "$registry_file" ]]; then
        should_register=true
        log_debug "Registry not found, triggering registration"
    elif [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        # OPTIMIZATION: Use stat for faster directory change detection
        local registry_mtime=$(stat -c %Y "$registry_file" 2>/dev/null || echo 0)
        local agents_dir_mtime=$(stat -c %Y "$CLAUDE_AGENTS_DIR" 2>/dev/null || echo 0)
        
        if [[ $agents_dir_mtime -gt $registry_mtime ]]; then
            should_register=true
            log_debug "Agents directory updated, triggering re-registration"
        else
            # OPTIMIZATION: Quick check for any .md files newer than registry
            local agents_newer=$(find "$CLAUDE_AGENTS_DIR" -maxdepth 1 -name "*.md" -newer "$registry_file" 2>/dev/null | wc -l)
            [[ $agents_newer -gt 0 ]] && should_register=true
        fi
    fi
    
    if $should_register; then
        log_debug "Auto-registering agents from directory..."
        register_agents_from_directory "$CLAUDE_AGENTS_DIR"
    fi
    
    # OPTIMIZATION: Fast agent display with caching and streaming
    if [[ -f "$registry_file" ]] && command_exists python3; then
        # OPTIMIZATION: Single Python call with optimized JSON processing
        python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    
    agents = registry.get('agents', {})
    if not agents:
        print('  No agents registered')
        sys.exit(0)
    
    # OPTIMIZATION: Pre-allocate category dict with default
    from collections import defaultdict
    categories = defaultdict(list)
    
    # OPTIMIZATION: Single pass categorization
    for agent in agents.values():
        categories[agent.get('category', 'general')].append(agent)
    
    # OPTIMIZATION: Sort categories once and stream output
    total_agents = len(agents)
    active_count = sum(1 for a in agents.values() if a.get('status') == 'active')
    template_count = sum(1 for a in agents.values() if a.get('status') == 'template')
    stub_count = sum(1 for a in agents.values() if a.get('status') == 'stub')
    
    # Stream output by category
    for category in sorted(categories.keys()):
        print(f'\\n  \\033[1;33m{category.title()}:\\033[0m')
        
        # OPTIMIZATION: Sort by display_name in single operation
        agents_in_cat = sorted(categories[category], key=lambda x: x.get('display_name', ''))
        
        for agent in agents_in_cat:
            status = agent.get('status', 'unknown')
            status_color = '\\033[0;32m' if status == 'active' else '\\033[0;33m' if status == 'template' else '\\033[0;31m'
            status_symbol = '✓' if status == 'active' else '○' if status == 'template' else '✗'
            display_name = agent.get('display_name', 'Unknown')[:18]
            description = agent.get('description', 'No description')[:50]
            print(f'    {status_color}{status_symbol}\\033[0m \\033[1m{display_name:<18}\\033[0m \\033[2m{description}\\033[0m')
    
    # OPTIMIZATION: Print summary in one operation
    print(f'\\n  Total: {total_agents} agents')
    print(f'  Active: {active_count}, Templates: {template_count}, Stubs: {stub_count}')
    
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

# OPTIMIZATION: High-performance agent execution with caching
run_agent() {
    local agent_name="$1"
    shift
    
    if [[ -z "$agent_name" ]]; then
        log_error "Usage: claude agent <name> [args]"
        return 1
    fi
    
    # OPTIMIZATION: Lazy registration only when needed
    local registry_file="$CACHE_DIR/registered_agents.json"
    local agent_file=""
    
    # OPTIMIZATION: Fast path - try cache first
    local agent_cache="$CACHE_DIR/agent_path_${agent_name,,}.cache"
    if [[ -f "$agent_cache" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$agent_cache" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 1800 ]]; then  # 30-minute cache
            agent_file=$(cat "$agent_cache" 2>/dev/null)
            if [[ -f "$agent_file" ]]; then
                log_debug "Using cached agent path: $agent_file"
            else
                rm -f "$agent_cache" 2>/dev/null
                agent_file=""
            fi
        fi
    fi
    
    # If not in cache, search in registry or register
    if [[ -z "$agent_file" ]]; then
        if [[ ! -f "$registry_file" ]]; then
            log_debug "Registering agents for first run..."
            register_agents_from_directory "$CLAUDE_AGENTS_DIR"
        fi
        
        # OPTIMIZATION: Single Python call to get agent path
        if command_exists python3; then
            agent_file=$(python3 -c "
import json, sys
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agent = registry.get('agents', {}).get('${agent_name,,}')
    if agent and agent.get('file_path'):
        print(agent['file_path'])
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
            " 2>/dev/null)
        fi
        
        # Fallback to manual search
        if [[ -z "$agent_file" ]]; then
            agent_file=$(find_agent_file "$agent_name")
        fi
        
        # OPTIMIZATION: Cache the result if found
        if [[ -n "$agent_file" ]] && [[ -f "$agent_file" ]]; then
            echo "$agent_file" > "$agent_cache" 2>/dev/null || true
        fi
    fi
    
    if [[ -z "$agent_file" ]] || [[ ! -f "$agent_file" ]]; then
        log_error "Agent not found: $agent_name"
        echo
        echo -e "${CYAN}Available agents:${NC}"
        
        # OPTIMIZATION: Fast agent list for error message
        if [[ -f "$registry_file" ]] && command_exists python3; then
            python3 -c "
import json
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    agents = sorted(list(registry.get('agents', {}).keys())[:10])  # Show first 10
    for agent in agents:
        print(f'  - {agent}')
    total = len(registry.get('agents', {}))
    if total > 10:
        print(f'  ... and {total - 10} more')
except Exception:
    pass
            " 2>/dev/null
        fi
        echo -e "\nRun 'claude agents' to see all available agents"
        return 1
    fi
    
    # OPTIMIZATION: Conditional info display (only if debug enabled)
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_info "Loading agent: $agent_name"
        if get_agent_info "$agent_name" >/dev/null 2>&1; then
            get_agent_info "$agent_name" | while read -r line; do
                log_debug "$line"
            done
        fi
    fi
    
    # OPTIMIZATION: Set environment efficiently
    export CLAUDE_AGENT="$agent_name" CLAUDE_AGENT_FILE="$agent_file"
    
    execute_claude "$CLAUDE_BINARY" "$@"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # OPTIMIZATION: Start performance monitoring
    perf_start_timer
    
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
    
    # OPTIMIZATION: Cached Claude binary discovery with lazy installation
    local binary_cache="$CACHE_DIR/claude_binary.cache"
    CLAUDE_BINARY=""
    
    # Try cache first
    if [[ -f "$binary_cache" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$binary_cache" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 3600 ]]; then  # 1-hour cache
            local cached_binary=$(cat "$binary_cache" 2>/dev/null)
            if [[ -n "$cached_binary" ]] && [[ -f "$cached_binary" ]]; then
                CLAUDE_BINARY="$cached_binary"
                log_debug "Using cached Claude binary: $CLAUDE_BINARY"
            fi
        fi
    fi
    
    # Search for binary if not cached
    if [[ -z "$CLAUDE_BINARY" ]]; then
        CLAUDE_BINARY=$(find_claude_binary || echo "")
    fi
    
    if [[ -z "$CLAUDE_BINARY" ]]; then
        log_error "Claude not found. Installing..."
        
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "Installing Claude Code via npm..."
            npm install -g @anthropic-ai/claude-code --force --silent
            CLAUDE_BINARY=$(find_claude_binary || echo "")
            
            if [[ -z "$CLAUDE_BINARY" ]]; then
                log_error "Failed to install Claude Code"
                echo "Try manual installation: npm install -g @anthropic-ai/claude-code"
                exit 1
            else
                log_success "Claude Code installed successfully"
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
    
    # OPTIMIZATION: End performance timing and execute Claude
    perf_end_timer "wrapper_initialization"
    execute_claude "$CLAUDE_BINARY" "$@"
}

# Error trap with helpful messages
trap 'ec=$?; [[ $ec -ne 0 ]] && log_error "Error at line $LINENO (exit code: $ec). Run with --debug for details." >&2' ERR

# Run main
main "$@"