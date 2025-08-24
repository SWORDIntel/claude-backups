#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v10.3 - CRASH-RESISTANT VERSION WITH VENV
# 
# Features:
# • Robust error handling to prevent crashes
# • Automatic virtual environment activation
# • Dependency checking before execution
# • Graceful fallbacks for missing components
# • Debug mode for troubleshooting
# ═══════════════════════════════════════════════════════════════════════════

# Don't exit on errors - handle them gracefully
set +e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCY CHECKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Enable debug mode if requested
if [[ "${CLAUDE_DEBUG:-false}" == "true" ]] || [[ "$1" == "--debug" ]]; then
    set -x
    DEBUG_MODE="true"
    [[ "$1" == "--debug" ]] && shift
else
    DEBUG_MODE="false"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for Python3
    if ! command_exists python3; then
        missing_deps+=("python3")
    fi
    
    # Check for required commands
    for cmd in mkdir cat echo; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        return 1
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VIRTUAL ENVIRONMENT ACTIVATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Function to activate virtual environment if it exists
activate_venv() {
    # Check for Claude virtual environment
    local venv_paths=(
        "${CLAUDE_VENV:-}"
        "$HOME/.local/share/claude/venv"
        "$HOME/Documents/claude-backups/venv"
        "$HOME/Documents/Claude/venv"
        "$HOME/.claude-venv"
    )
    
    for venv_path in "${venv_paths[@]}"; do
        if [[ -n "$venv_path" ]] && [[ -d "$venv_path" ]] && [[ -f "$venv_path/bin/activate" ]]; then
            # Found virtual environment
            if [[ "${DEBUG_MODE}" == "true" ]]; then
                echo "[DEBUG] Activating virtual environment: $venv_path"
            fi
            
            # Export VIRTUAL_ENV for child processes
            export VIRTUAL_ENV="$venv_path"
            export PATH="$venv_path/bin:$PATH"
            
            # Update Python-related environment variables
            export PYTHONPATH="$venv_path/lib/python*/site-packages:${PYTHONPATH:-}"
            
            # Unset PYTHONHOME as it can interfere with venv
            unset PYTHONHOME
            
            # Mark that we've activated a venv
            export CLAUDE_VENV_ACTIVATED="true"
            export CLAUDE_VENV_PATH="$venv_path"
            
            if [[ "${DEBUG_MODE}" == "true" ]]; then
                echo "[DEBUG] Virtual environment activated successfully"
                echo "[DEBUG] Python: $(which python3 2>/dev/null || echo 'not found')"
                echo "[DEBUG] Pip: $(which pip3 2>/dev/null || echo 'not found')"
            fi
            
            return 0
        fi
    done
    
    # No virtual environment found
    if [[ "${DEBUG_MODE}" == "true" ]]; then
        echo "[DEBUG] No virtual environment found, using system Python"
    fi
    
    export CLAUDE_VENV_ACTIVATED="false"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE PATH DISCOVERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Function to find project root
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
            # Check for project indicators
            if [[ -d "$path/agents" ]] || [[ -f "$path/CLAUDE.md" ]] || [[ -d "$path/.claude" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done
    
    # Fallback to home directory
    echo "$HOME/claude-project"
    mkdir -p "$HOME/claude-project" 2>/dev/null || true
}

# Function to find Claude binary
find_claude_binary() {
    local search_paths=(
        # User's npm global installations
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/bin/claude"
        "$HOME/.npm-global/bin/claude-code"
        
        # System npm global installations
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/local/bin/claude"
        "/usr/local/bin/claude-code"
        
        # Check PATH
        "$(which claude 2>/dev/null || true)"
        "$(which claude-code 2>/dev/null || true)"
    )
    
    # Also check npm global prefix if npm exists
    if command_exists npm; then
        local npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
        if [[ -n "$npm_prefix" ]]; then
            search_paths+=("$npm_prefix/lib/node_modules/@anthropic-ai/claude-code/cli.js")
            search_paths+=("$npm_prefix/bin/claude")
            search_paths+=("$npm_prefix/bin/claude-code")
        fi
    fi
    
    for path in "${search_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLORS (SAFE)
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
    # No color support
    readonly GREEN=''
    readonly YELLOW=''
    readonly CYAN=''
    readonly MAGENTA=''
    readonly RED=''
    readonly BOLD=''
    readonly DIM=''
    readonly NC=''
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION (SAFE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check dependencies first
if ! check_dependencies; then
    exit 1
fi

# Dynamic discovery of paths
export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude-home}"
export CLAUDE_PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(find_project_root)}"

# Setup directories based on project structure
if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
    export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
    export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
else
    export CLAUDE_AGENTS_DIR="${CLAUDE_AGENTS_DIR:-$HOME/agents}"
    export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}"
fi

# Cache directory
CACHE_DIR="${CLAUDE_CACHE_DIR:-$HOME/.cache/claude}"
mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR="/tmp/claude-cache-$$"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Files
METRICS_FILE="$CACHE_DIR/metrics.json"
PATTERNS_FILE="$CACHE_DIR/patterns.json"
HISTORY_FILE="$CACHE_DIR/history.json"
QUICK_ACCESS_FILE="$CACHE_DIR/quick_access.txt"

# Binary location
CLAUDE_BINARY="${CLAUDE_BINARY:-$(find_claude_binary || echo "")}"

# Feature flags with safe defaults
PERMISSION_BYPASS="${CLAUDE_PERMISSION_BYPASS:-false}"
ORCHESTRATION_ENABLED="${CLAUDE_ORCHESTRATION:-false}"
AUTO_SUGGEST="${CLAUDE_AUTO_SUGGEST:-false}"
LEARNING_MODE="${CLAUDE_LEARNING:-false}"
SUGGESTION_TIMEOUT="${CLAUDE_TIMEOUT:-5}"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

safe_initialize() {
    # Activate virtual environment first if available
    activate_venv
    
    # Try to create cache directory
    if [[ -w "$(dirname "$CACHE_DIR")" ]]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi
    
    # Initialize files only if we can write to cache dir
    if [[ -w "$CACHE_DIR" ]]; then
        # Initialize patterns file
        if [[ ! -f "$PATTERNS_FILE" ]]; then
            cat > "$PATTERNS_FILE" 2>/dev/null << 'EOF' || true
{
  "patterns": {
    "simple": ["fix", "update", "change"],
    "moderate": ["implement", "add", "setup"],
    "complex": ["architect", "design", "refactor"]
  }
}
EOF
        fi
        
        # Initialize other files
        [[ ! -f "$HISTORY_FILE" ]] && echo '{"tasks": []}' > "$HISTORY_FILE" 2>/dev/null || true
        [[ ! -f "$METRICS_FILE" ]] && echo '{"executions": 0}' > "$METRICS_FILE" 2>/dev/null || true
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIMPLE TASK ANALYSIS (FALLBACK)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

analyze_task_simple() {
    local task="$1"
    local task_lower=$(echo "$task" | tr '[:upper:]' '[:lower:]')
    
    # Simple keyword-based analysis
    local score=0
    
    # Check for complex keywords
    for keyword in architect design refactor optimize migrate scale; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            score=$((score + 20))
        fi
    done
    
    # Check for moderate keywords
    for keyword in implement add integrate setup configure; do
        if [[ "$task_lower" == *"$keyword"* ]]; then
            score=$((score + 10))
        fi
    done
    
    # Output simple JSON
    echo "{\"score\": $score, \"mode\": \"direct\"}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Claude Wrapper Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # System checks
    echo "System Information:"
    echo "  OS: $(uname -s 2>/dev/null || echo 'Unknown')"
    echo "  Shell: $SHELL"
    echo "  User: $USER"
    echo
    
    # Dependencies
    echo "Dependencies:"
    if command_exists python3; then
        echo -e "  Python3: ${GREEN}✓${NC} $(python3 --version 2>&1 | head -n1)"
    else
        echo -e "  Python3: ${RED}✗ Not found${NC}"
    fi
    
    if command_exists npm; then
        echo -e "  npm: ${GREEN}✓${NC} $(npm --version 2>/dev/null)"
    else
        echo -e "  npm: ${YELLOW}⚠ Not found${NC}"
    fi
    echo
    
    # Claude binary
    echo "Claude Binary:"
    if [[ -n "$CLAUDE_BINARY" ]] && [[ -f "$CLAUDE_BINARY" ]]; then
        echo -e "  Path: ${GREEN}$CLAUDE_BINARY${NC}"
    else
        echo -e "  Path: ${RED}Not found${NC}"
        echo "  Install with: npm install -g @anthropic-ai/claude-code"
    fi
    echo
    
    # Directories
    echo "Directories:"
    echo "  Project Root: $CLAUDE_PROJECT_ROOT"
    echo "  Cache Dir: $CACHE_DIR"
    [[ -d "$CACHE_DIR" ]] && echo -e "    Status: ${GREEN}✓ Writable${NC}" || echo -e "    Status: ${YELLOW}⚠ Not writable${NC}"
    echo
    
    # Feature flags
    echo "Features:"
    echo "  Permission Bypass: $PERMISSION_BYPASS"
    echo "  Orchestration: $ORCHESTRATION_ENABLED"
    echo "  Learning Mode: $LEARNING_MODE"
    echo "  Debug Mode: $DEBUG_MODE"
    echo
    
    # Virtual Environment
    echo "Virtual Environment:"
    if [[ "${CLAUDE_VENV_ACTIVATED:-false}" == "true" ]]; then
        echo -e "  Status: ${GREEN}✓ Activated${NC}"
        echo "  Path: ${CLAUDE_VENV_PATH:-unknown}"
        echo "  Python: $(which python3 2>/dev/null || echo 'not found')"
        echo "  Pip: $(which pip3 2>/dev/null || echo 'not found')"
    else
        echo -e "  Status: ${YELLOW}⚠ Not activated${NC}"
        echo "  Using system Python: $(which python3 2>/dev/null || echo 'not found')"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION (SAFE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Initialize safely
    safe_initialize
    
    # Handle special commands first
    case "${1:-}" in
        --status|status)
            show_status
            exit 0
            ;;
        --help|help|-h)
            echo -e "${CYAN}${BOLD}Claude Ultimate Wrapper v10.3${NC}"
            echo
            echo "Usage: claude [OPTIONS] [COMMAND]"
            echo
            echo "Options:"
            echo "  --status    Show system status and diagnostics"
            echo "  --help      Show this help message"
            echo "  --debug     Run in debug mode"
            echo "  --safe      Run without permission bypass"
            echo
            echo "Commands:"
            echo "  /task TEXT  Execute a task with Claude"
            echo "  Any other command is passed to Claude directly"
            echo
            echo "Environment Variables:"
            echo "  CLAUDE_BINARY          Path to Claude binary"
            echo "  CLAUDE_PROJECT_ROOT    Project root directory"
            echo "  CLAUDE_DEBUG           Enable debug mode (true/false)"
            echo "  CLAUDE_PERMISSION_BYPASS  Enable permission bypass (true/false)"
            echo
            echo "Troubleshooting:"
            echo "  Run with --debug for detailed output"
            echo "  Run --status to check system configuration"
            exit 0
            ;;
        --debug)
            # Already handled at the top
            shift
            set -- "$@"
            ;;
    esac
    
    # Check if Claude binary exists
    if [[ -z "$CLAUDE_BINARY" ]] || [[ ! -f "$CLAUDE_BINARY" ]]; then
        echo -e "${RED}Error: Claude binary not found${NC}"
        echo
        echo "Please install Claude Code first:"
        echo "  npm install -g @anthropic-ai/claude-code"
        echo
        echo "Or specify the path:"
        echo "  export CLAUDE_BINARY=/path/to/claude"
        echo
        echo "Run '$0 --status' for diagnostic information"
        exit 1
    fi
    
    # Handle task command
    if [[ "${1:-}" == "/task" ]] || [[ "${1:-}" == "task" ]]; then
        shift
        local task_text="$*"
        
        # Simple execution without complex orchestration
        if [[ "$PERMISSION_BYPASS" == "true" ]]; then
            exec "$CLAUDE_BINARY" --dangerously-skip-permissions /task "$task_text"
        else
            exec "$CLAUDE_BINARY" /task "$task_text"
        fi
    fi
    
    # Default: pass through to Claude
    if [[ "$PERMISSION_BYPASS" == "true" ]] && [[ "${1:-}" != "--safe" ]]; then
        exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
    else
        [[ "${1:-}" == "--safe" ]] && shift
        exec "$CLAUDE_BINARY" "$@"
    fi
}

# Trap errors
trap 'echo "Error occurred at line $LINENO. Run with --debug for details."' ERR

# Run main with all arguments
main "$@"