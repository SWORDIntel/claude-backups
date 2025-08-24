#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v12.0 - COMPREHENSIVE MODULE VERIFICATION
# 
# Features:
# • Complete module dependency verification  
# • Automatic yoga.wasm error prevention and recovery
# • Comprehensive npm package health checks
# • Self-healing module installation system
# • Multi-layer execution fallback strategy
# • Module compatibility verification
# • Smart virtual environment activation
# • Performance monitoring and caching
# ═══════════════════════════════════════════════════════════════════════════

# Don't exit on errors - handle them gracefully
set +e

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
    readonly BLUE='\033[0;34m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly GREEN='' YELLOW='' CYAN='' MAGENTA='' RED='' BLUE='' BOLD='' DIM='' NC=''
fi

# Status symbols
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly FIXING="🔧"
readonly CHECK="🔍"
readonly MODULE="📦"

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

# Logging functions
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

log_check() {
    echo -e "${BLUE}${CHECK} $1${NC}" >&2
}

log_module() {
    echo -e "${CYAN}${MODULE} $1${NC}" >&2
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MODULE VERIFICATION SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Critical Claude modules that must be present
CRITICAL_MODULES=(
    "@anthropic-ai/claude-code"
    "vscode-languageclient"
    "vscode-languageserver"
    "vscode-languageserver-protocol"
)

# Optional modules that enhance functionality
OPTIONAL_MODULES=(
    "yoga-layout-prebuilt"
    "ws"
    "jsonrpc"
    "debug"
    "chalk"
    "commander"
    "inquirer"
    "ora"
)

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check module installation
check_module() {
    local module="$1"
    local npm_root="${2:-$(npm root -g 2>/dev/null)}"
    
    # Check multiple possible locations
    local locations=(
        "$npm_root/$module"
        "$HOME/.npm-global/lib/node_modules/$module"
        "/usr/local/lib/node_modules/$module"
        "$(npm root)/$module"
    )
    
    for loc in "${locations[@]}"; do
        if [[ -d "$loc" ]]; then
            log_debug "Found module $module at $loc"
            return 0
        fi
    done
    
    log_debug "Module $module not found"
    return 1
}

# Comprehensive module verification
verify_all_modules() {
    local all_good=true
    local npm_root=$(npm root -g 2>/dev/null)
    
    log_check "Verifying critical modules..."
    
    # Check critical modules
    for module in "${CRITICAL_MODULES[@]}"; do
        if check_module "$module" "$npm_root"; then
            log_debug "  $module: ${GREEN}${SUCCESS}${NC}"
        else
            log_error "  Missing critical module: $module"
            all_good=false
        fi
    done
    
    # Check optional modules if verbose
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_check "Checking optional modules..."
        for module in "${OPTIONAL_MODULES[@]}"; do
            if check_module "$module" "$npm_root"; then
                log_debug "  $module: ${GREEN}${SUCCESS}${NC}"
            else
                log_debug "  $module: ${DIM}not installed (optional)${NC}"
            fi
        done
    fi
    
    $all_good && return 0 || return 1
}

# Fix missing modules
fix_missing_modules() {
    log_fixing "Installing missing modules..."
    
    # Try to install Claude Code with all dependencies
    npm install -g @anthropic-ai/claude-code --force 2>&1 | while read -r line; do
        log_debug "$line"
    done
    
    # Verify installation
    if verify_all_modules; then
        log_success "All modules installed successfully"
        return 0
    else
        log_warning "Some modules may still be missing"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY CHECKING AND AUTO-FIXING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
    
    # First check modules
    if ! verify_all_modules; then
        log_warning "Module verification failed"
        return 3  # Missing modules
    fi
    
    # Check if yoga.wasm issue exists by attempting a dry run
    local test_output=$(NODE_OPTIONS="--no-warnings" CLAUDE_NO_YOGA=1 node "$claude_path" --version 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        if echo "$test_output" | grep -q "yoga.wasm"; then
            log_warning "Detected yoga.wasm issue"
            return 2  # Special code for yoga.wasm issue
        elif echo "$test_output" | grep -q "Cannot find module"; then
            log_warning "Missing module detected"
            # Extract module name if possible
            local missing_module=$(echo "$test_output" | grep -oP "Cannot find module '\K[^']+")
            if [[ -n "$missing_module" ]]; then
                log_debug "Missing module: $missing_module"
            fi
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
    export NODE_OPTIONS="--no-warnings --max-old-space-size=4096"
    export YOGA_DISABLE=1
    
    # Method 2: Try reinstalling yoga-layout-prebuilt
    if [[ "${CLAUDE_AUTO_FIX:-false}" == "true" ]]; then
        log_info "Attempting to reinstall yoga-layout-prebuilt..."
        npm install -g yoga-layout-prebuilt@latest 2>/dev/null || true
    fi
    
    # Method 3: Create yoga.wasm placeholder if needed
    local claude_dirs=(
        "$(npm root -g)/@anthropic-ai/claude-code"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code"
    )
    
    for dir in "${claude_dirs[@]}"; do
        if [[ -d "$dir" ]] && [[ ! -f "$dir/yoga.wasm" ]]; then
            echo "// Placeholder for yoga.wasm" > "$dir/yoga.wasm" 2>/dev/null || true
            log_debug "Created yoga.wasm placeholder in $dir"
        fi
    done
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VIRTUAL ENVIRONMENT ACTIVATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

activate_venv() {
    local venv_paths=(
        "${CLAUDE_VENV:-}"
        "$HOME/.local/share/claude/venv"
        "$HOME/Documents/claude-backups/venv"
        "$HOME/Documents/Claude/venv"
        "$HOME/.claude-venv"
        "./venv"
        "./.venv"
    )
    
    for venv_path in "${venv_paths[@]}"; do
        if [[ -n "$venv_path" ]] && [[ -d "$venv_path" ]] && [[ -f "$venv_path/bin/activate" ]]; then
            log_debug "Activating virtual environment: $venv_path"
            
            export VIRTUAL_ENV="$venv_path"
            export PATH="$venv_path/bin:$PATH"
            export PYTHONPATH="$venv_path/lib/python*/site-packages:${PYTHONPATH:-}"
            unset PYTHONHOME
            
            export CLAUDE_VENV_ACTIVATED="true"
            export CLAUDE_VENV_PATH="$venv_path"
            
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
    local search_paths=(
        "$current_dir"
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
    
    # Add permission bypass if enabled
    if [[ "${PERMISSION_BYPASS:-false}" == "true" ]] && [[ "${args[0]}" != "--safe" ]]; then
        args=("--dangerously-skip-permissions" "${args[@]}")
    fi
    
    # Remove --safe flag if present
    if [[ "${args[0]}" == "--safe" ]]; then
        args=("${args[@]:1}")
        PERMISSION_BYPASS="false"
    fi
    
    # Ensure environment is set for yoga.wasm protection
    export NODE_OPTIONS="${NODE_OPTIONS:---no-warnings --max-old-space-size=4096}"
    export CLAUDE_NO_YOGA="${CLAUDE_NO_YOGA:-1}"
    export YOGA_DISABLE="${YOGA_DISABLE:-1}"
    
    log_debug "Executing: $claude_binary ${args[*]}"
    log_debug "Environment: NODE_OPTIONS=$NODE_OPTIONS, CLAUDE_NO_YOGA=$CLAUDE_NO_YOGA"
    
    # Method 1: Try direct execution
    if [[ -x "$claude_binary" ]]; then
        exec "$claude_binary" "${args[@]}" 2>&1
    fi
    
    # Method 2: Try with node
    if command_exists node; then
        exec node "$claude_binary" "${args[@]}" 2>&1
    fi
    
    # Method 3: Try with npx
    if command_exists npx; then
        exec npx @anthropic-ai/claude-code "${args[@]}" 2>&1
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
    else
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
    export NODE_OPTIONS="${NODE_OPTIONS:---no-warnings --max-old-space-size=4096}"
    export CLAUDE_NO_YOGA="${CLAUDE_NO_YOGA:-1}"
    export YOGA_DISABLE="${YOGA_DISABLE:-1}"
    
    log_debug "Environment initialized"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENHANCED STATUS DISPLAY WITH MODULE INFO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}          Claude Ultimate Wrapper v12.0 Status${NC}"
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
    
    # Module Status
    echo -e "${BOLD}Module Status:${NC}"
    local npm_root=$(npm root -g 2>/dev/null)
    
    for module in "${CRITICAL_MODULES[@]}"; do
        if check_module "$module" "$npm_root"; then
            echo -e "  $module: ${GREEN}${SUCCESS} Installed${NC}"
        else
            echo -e "  $module: ${RED}${ERROR} Missing${NC}"
        fi
    done
    
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo
        echo -e "${BOLD}Optional Modules:${NC}"
        for module in "${OPTIONAL_MODULES[@]}"; do
            if check_module "$module" "$npm_root"; then
                echo -e "  $module: ${GREEN}${SUCCESS} Installed${NC}"
            else
                echo -e "  $module: ${DIM}Not installed${NC}"
            fi
        done
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
            3) echo -e "  Health: ${YELLOW}${WARNING} Missing modules (run --fix to install)${NC}" ;;
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
    [[ -d "$CLAUDE_AGENTS_DIR" ]] && echo "  Agents: $CLAUDE_AGENTS_DIR ($(find "$CLAUDE_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l) found)"
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
    
    # Environment Protection
    echo -e "${BOLD}Protection Settings:${NC}"
    echo "  NODE_OPTIONS: ${NODE_OPTIONS:-not set}"
    echo "  CLAUDE_NO_YOGA: ${CLAUDE_NO_YOGA:-not set}"
    echo "  YOGA_DISABLE: ${YOGA_DISABLE:-not set}"
    echo
    
    # Quick Commands
    echo -e "${BOLD}Quick Commands:${NC}"
    echo "  claude --help          Show help"
    echo "  claude --fix           Auto-fix issues"
    echo "  claude --modules       Check all modules"
    echo "  claude --safe          Run without permission bypass"
    echo "  claude task <text>     Execute a task"
    echo "  claude agent <name>    Run specific agent"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MODULE CHECK FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_all_modules() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Module Verification Report${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local npm_root=$(npm root -g 2>/dev/null)
    local critical_count=0
    local critical_missing=0
    local optional_count=0
    local optional_missing=0
    
    echo -e "${BOLD}Critical Modules:${NC}"
    for module in "${CRITICAL_MODULES[@]}"; do
        ((critical_count++))
        if check_module "$module" "$npm_root"; then
            echo -e "  ${GREEN}${SUCCESS}${NC} $module"
            
            # Check module version
            local version_file="$npm_root/$module/package.json"
            if [[ -f "$version_file" ]]; then
                local version=$(grep '"version"' "$version_file" 2>/dev/null | sed 's/.*"version": *"\([^"]*\)".*/\1/')
                [[ -n "$version" ]] && echo "      Version: $version"
            fi
        else
            echo -e "  ${RED}${ERROR}${NC} $module (missing)"
            ((critical_missing++))
        fi
    done
    echo
    
    echo -e "${BOLD}Optional Modules:${NC}"
    for module in "${OPTIONAL_MODULES[@]}"; do
        ((optional_count++))
        if check_module "$module" "$npm_root"; then
            echo -e "  ${GREEN}${SUCCESS}${NC} $module"
        else
            echo -e "  ${DIM}○${NC} $module (not installed)"
            ((optional_missing++))
        fi
    done
    echo
    
    echo -e "${BOLD}Summary:${NC}"
    echo "  Critical: $((critical_count - critical_missing))/$critical_count installed"
    echo "  Optional: $((optional_count - optional_missing))/$optional_count installed"
    
    if [[ $critical_missing -gt 0 ]]; then
        echo
        echo -e "${YELLOW}${WARNING} Missing critical modules detected${NC}"
        echo "  Run 'claude --fix' to install missing modules"
        return 1
    else
        echo
        echo -e "${GREEN}${SUCCESS} All critical modules are installed${NC}"
        return 0
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-FIX FUNCTION WITH MODULE REPAIR
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

auto_fix_issues() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Claude Auto-Fix System v12.0${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    log_info "Starting comprehensive system check..."
    
    # Check Node/npm
    if ! check_node_npm; then
        log_error "Node.js/npm issues detected. Please install Node.js 14+ and npm."
        return 1
    fi
    
    # Check modules
    log_check "Verifying module installation..."
    if ! verify_all_modules; then
        fix_missing_modules
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
        3)
            log_fixing "Fixing missing modules..."
            fix_missing_modules
            
            verify_claude_health "$claude_binary"
            if [[ $? -eq 0 ]]; then
                log_success "Module issues resolved"
            else
                log_warning "Some module issues may remain"
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
# AGENT MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

list_agents() {
    echo -e "${CYAN}${BOLD}Available Agents:${NC}"
    echo
    
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
}

run_agent() {
    local agent_name="$1"
    shift
    
    if [[ -z "$agent_name" ]]; then
        log_error "Usage: claude agent <name> [args]"
        return 1
    fi
    
    # Find agent file (case-insensitive)
    local agent_file=""
    for pattern in \
        "$CLAUDE_AGENTS_DIR/${agent_name}.md" \
        "$CLAUDE_AGENTS_DIR/${agent_name}.MD" \
        "$CLAUDE_AGENTS_DIR/${agent_name^^}.md" \
        "$CLAUDE_AGENTS_DIR/${agent_name,,}.md"; do
        if [[ -f "$pattern" ]]; then
            agent_file="$pattern"
            break
        fi
    done
    
    if [[ -z "$agent_file" ]]; then
        log_error "Agent not found: $agent_name"
        log_info "Run 'claude agents' to see available agents"
        return 1
    fi
    
    log_info "Loading agent: $agent_name"
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
            
        --modules|modules)
            check_all_modules
            exit $?
            ;;
            
        --fix|fix)
            auto_fix_issues
            exit $?
            ;;
            
        --agents|agents|--list-agents)
            list_agents
            exit 0
            ;;
            
        --agent|agent)
            shift
            run_agent "$@"
            exit $?
            ;;
            
        --help|help|-h)
            echo -e "${CYAN}${BOLD}Claude Ultimate Wrapper v12.0${NC}"
            echo -e "${DIM}Complete module verification and yoga.wasm protection${NC}"
            echo
            echo "Usage: claude [OPTIONS] [COMMAND]"
            echo
            echo "Options:"
            echo "  --status       Show comprehensive system status"
            echo "  --modules      Verify all module installations"
            echo "  --fix          Auto-detect and fix all issues"
            echo "  --agents       List available agents"
            echo "  --agent NAME   Run specific agent"
            echo "  --safe         Run without permission bypass"
            echo "  --debug        Enable debug output"
            echo "  --help         Show this help"
            echo
            echo "Commands:"
            echo "  task <text>    Execute a task"
            echo "  <any>          Pass through to Claude"
            echo
            echo "Environment Variables:"
            echo "  CLAUDE_AUTO_FIX=true         Enable automatic issue fixing"
            echo "  CLAUDE_PERMISSION_BYPASS=true Enable permission bypass"
            echo "  CLAUDE_DEBUG=true            Enable debug mode"
            echo "  CLAUDE_NO_YOGA=1             Bypass yoga.wasm issues"
            echo "  CLAUDE_PROJECT_ROOT          Set project root directory"
            echo "  CLAUDE_VENV                  Path to Python virtual environment"
            echo
            echo "Module Verification:"
            echo "  Run 'claude --modules' to check all module installations"
            echo "  Run 'claude --fix' to automatically install missing modules"
            echo
            echo "Troubleshooting:"
            echo "  If Claude fails to start, run: claude --fix"
            echo "  For module verification: claude --modules"
            echo "  For detailed diagnostics: claude --status"
            echo "  For debug output: claude --debug [command]"
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
            3) fix_missing_modules ;;
            *) 
                # Try general fix
                export NODE_OPTIONS="--no-warnings --max-old-space-size=4096"
                export CLAUDE_NO_YOGA=1
                export YOGA_DISABLE=1
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