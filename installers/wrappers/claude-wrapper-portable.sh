#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# CLAUDE PORTABLE WRAPPER v1.0 - ZERO HARDCODED PATHS
#
# Universal wrapper that works on ANY system, ANY user, ANY installation location
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZE PORTABLE PATH RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Source path resolver - try multiple locations
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"
PATH_RESOLVER_LOCATIONS=(
    "$SCRIPT_DIR/claude-path-resolver.sh"
    "$SCRIPT_DIR/scripts/claude-path-resolver.sh"
    "$(dirname "$SCRIPT_DIR")/scripts/claude-path-resolver.sh"
    "./scripts/claude-path-resolver.sh"
    "./claude-path-resolver.sh"
)

for resolver in "${PATH_RESOLVER_LOCATIONS[@]}"; do
    if [[ -f "$resolver" ]]; then
        source "$resolver" init
        break
    fi
done

# Fallback path resolution if resolver not found
if [[ -z "${CLAUDE_PROJECT_ROOT:-}" ]]; then
    echo "Warning: Path resolver not found, using basic fallback detection"

    # Basic fallback detection
    if [[ -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
        export CLAUDE_PROJECT_ROOT="$SCRIPT_DIR"
    elif [[ -f "$(dirname "$SCRIPT_DIR")/CLAUDE.md" ]]; then
        export CLAUDE_PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    else
        export CLAUDE_PROJECT_ROOT="$HOME"
    fi

    export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
    export CLAUDE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude"
    export CLAUDE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
    export CLAUDE_LOG_DIR="$CLAUDE_DATA_DIR/logs"
    export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
    export CLAUDE_PYTHON_DIR="$CLAUDE_AGENTS_DIR/src/python"
    export CLAUDE_DOCKER_DIR="$CLAUDE_PROJECT_ROOT/database/docker"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION WITH PORTABLE PATHS
# ═══════════════════════════════════════════════════════════════════════════════

# Learning System Integration v3.1
export LEARNING_CAPTURE_ENABLED="${LEARNING_CAPTURE_ENABLED:-true}"
export LEARNING_DB_PORT="${LEARNING_DB_PORT:-5433}"
export LEARNING_LOG_PATH="$CLAUDE_LOG_DIR/learning"

# PICMCS v3.0 Context Optimization Integration
export PICMCS_ENABLED="${PICMCS_ENABLED:-true}"
export PICMCS_AUTO_CHOPPING="${PICMCS_AUTO_CHOPPING:-true}"
export PICMCS_HARDWARE_ADAPTIVE="${PICMCS_HARDWARE_ADAPTIVE:-true}"
export PICMCS_PYTHON_PATH="$CLAUDE_PYTHON_DIR"

# Full Self-Learning Integration v3.1
export LEARNING_ML_ENABLED="${LEARNING_ML_ENABLED:-true}"
export LEARNING_AGENT_SELECTION="${LEARNING_AGENT_SELECTION:-true}"
export LEARNING_SUCCESS_PREDICTION="${LEARNING_SUCCESS_PREDICTION:-true}"
export LEARNING_ADAPTIVE_STRATEGIES="${LEARNING_ADAPTIVE_STRATEGIES:-true}"

# Docker Learning System Integration
export LEARNING_DOCKER_ENABLED="${LEARNING_DOCKER_ENABLED:-true}"
export LEARNING_DOCKER_AUTO_START="${LEARNING_DOCKER_AUTO_START:-false}"
export LEARNING_DOCKER_COMPOSE_PATH="$CLAUDE_DOCKER_DIR"

# Ensure learning directories exist
mkdir -p "$LEARNING_LOG_PATH" "$CLAUDE_CONFIG_DIR" "$CLAUDE_DATA_DIR" "$CLAUDE_CACHE_DIR" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# DYNAMIC CLAUDE BINARY DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

detect_claude_binary() {
    local script_path="$(readlink -f "$0")"
    local binary_candidates=(
        # Environment override
        "${CLAUDE_BINARY_PATH:-}"

        # Node.js installations
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "${CLAUDE_USER_HOME:-$HOME}/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "${CLAUDE_USER_HOME:-$HOME}/.local/lib/node_modules/@anthropic-ai/claude-code/cli.js"

        # System binaries (avoid self-reference)
        "/usr/local/bin/claude"
        "/usr/bin/claude"
        "${CLAUDE_USER_BIN:-$HOME/.local/bin}/claude"

        # PIP installations
        "${CLAUDE_USER_HOME:-$HOME}/.local/bin/claude"

        # Fallback to PATH search
        "$(command -v claude 2>/dev/null || echo "")"
    )

    for candidate in "${binary_candidates[@]}"; do
        [[ -z "$candidate" ]] && continue

        # Handle Node.js entries
        if [[ "$candidate" == *.js ]]; then
            if [[ -f "$candidate" ]]; then
                echo "node $candidate"
                return 0
            fi
            continue
        fi

        # Handle binary entries
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            # Avoid self-reference
            local candidate_real="$(readlink -f "$candidate" 2>/dev/null || echo "$candidate")"
            if [[ "$candidate_real" != "$script_path" ]]; then
                echo "$candidate"
                return 0
            fi
        fi
    done

    # Ultimate fallback - try node.js
    if command -v node >/dev/null 2>&1; then
        echo "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    else
        echo "claude"  # Let the system handle it
    fi
}

CLAUDE_BINARY="$(detect_claude_binary)"

# ═══════════════════════════════════════════════════════════════════════════════
# LEARNING CAPTURE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

capture_execution() {
    [[ "$LEARNING_CAPTURE_ENABLED" != "true" ]] && return 0

    local start_time=$(date +%s.%N)
    local session_id=$(uuidgen 2>/dev/null || echo "$(date +%s)-$$")
    local prompt_hash=""
    local agent_used="${CLAUDE_AGENT:-direct}"

    # Extract prompt hash if available
    for arg in "$@"; do
        if [[ "$arg" == /task* ]] || [[ "$arg" == task* ]]; then
            prompt_hash=$(echo "$arg" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            break
        fi
    done

    # Log execution attempt
    local log_entry="{\"timestamp\":\"$(date -Iseconds)\",\"session_id\":\"$session_id\",\"agent\":\"$agent_used\",\"prompt_hash\":\"$prompt_hash\",\"start_time\":$start_time}"
    echo "$log_entry" >> "$LEARNING_LOG_PATH/executions.jsonl" 2>/dev/null || true

    # Execute and capture result
    local exit_code=0
    "$@" || exit_code=$?

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    # Log completion
    local completion_entry="{\"session_id\":\"$session_id\",\"end_time\":$end_time,\"duration\":$duration,\"exit_code\":$exit_code}"
    echo "$completion_entry" >> "$LEARNING_LOG_PATH/completions.jsonl" 2>/dev/null || true

    return $exit_code
}

# ═══════════════════════════════════════════════════════════════════════════════
# PERMISSION BYPASS SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

should_bypass_permissions() {
    # Check environment override
    if [[ "${CLAUDE_PERMISSION_BYPASS:-}" == "false" ]]; then
        return 1
    fi

    # Check for LiveCD indicators
    local livecd_indicators=(
        "/lib/live/mount"
        "/run/live"
        "/proc/cmdline"
    )

    for indicator in "${livecd_indicators[@]}"; do
        if [[ -e "$indicator" ]]; then
            if [[ "$indicator" == "/proc/cmdline" ]]; then
                if grep -q "boot=live\|live-media" "$indicator" 2>/dev/null; then
                    return 0
                fi
            else
                return 0
            fi
        fi
    done

    # Check for restricted environments
    if [[ ! -w "/tmp" ]] || [[ ! -w "$HOME" ]]; then
        return 0
    fi

    # Default to bypass unless explicitly disabled
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# ORCHESTRATION DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

detect_orchestration_need() {
    local args="$*"

    # Keywords that suggest multi-agent orchestration
    local orchestration_keywords=(
        "create.*with.*test"
        "build.*and.*deploy"
        "security.*audit"
        "performance.*optimi"
        "multi-step"
        "workflow"
        "coordinate"
        "parallel"
        "concurrent"
    )

    for keyword in "${orchestration_keywords[@]}"; do
        if echo "$args" | grep -qi "$keyword"; then
            return 0
        fi
    done

    return 1
}

suggest_orchestration() {
    local timeout=5
    echo "🤖 Multi-step task detected. Use orchestration for better coordination?"
    echo "   Press ENTER for orchestration, any other key for direct execution..."

    if read -t $timeout -n 1; then
        echo
        if [[ -z "$REPLY" ]]; then
            return 0  # Use orchestration
        fi
    else
        echo " (timeout)"
    fi

    return 1  # Use direct execution
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local args=("$@")

    # Handle special commands
    case "${1:-}" in
        "--status"|"--portable-status")
            echo "Claude Portable Wrapper v1.0"
            echo "Project Root: $CLAUDE_PROJECT_ROOT"
            echo "Config Dir:   $CLAUDE_CONFIG_DIR"
            echo "Data Dir:     $CLAUDE_DATA_DIR"
            echo "Binary:       $CLAUDE_BINARY"
            echo "Learning:     ${LEARNING_CAPTURE_ENABLED:-false}"
            echo "Orchestration Available: $(test -f "$CLAUDE_PYTHON_DIR/production_orchestrator.py" && echo "Yes" || echo "No")"
            return 0
            ;;
        "--safe")
            export CLAUDE_PERMISSION_BYPASS=false
            args=("${args[@]:1}")  # Remove --safe from args
            ;;
        "--help"|"-h")
            echo "Claude Portable Wrapper v1.0 - Zero Hardcoded Paths"
            echo ""
            echo "Usage: $0 [options] [claude-args...]"
            echo ""
            echo "Options:"
            echo "  --safe              Disable permission bypass"
            echo "  --status            Show wrapper status"
            echo "  --help              Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  CLAUDE_PERMISSION_BYPASS=false    Disable permission bypass"
            echo "  CLAUDE_ORCHESTRATION=false        Disable orchestration suggestions"
            echo "  LEARNING_CAPTURE_ENABLED=false    Disable learning capture"
            echo ""
            echo "All other arguments are passed to Claude."
            return 0
            ;;
    esac

    # Prepare Claude command
    local claude_cmd=($CLAUDE_BINARY)

    # Add permission bypass if needed
    if should_bypass_permissions; then
        claude_cmd+=(--dangerously-skip-permissions)
    fi

    # Add user arguments
    claude_cmd+=("${args[@]}")

    # Check for orchestration suggestion
    if [[ "${CLAUDE_ORCHESTRATION:-true}" != "false" ]] && detect_orchestration_need "$*"; then
        if suggest_orchestration; then
            # Try to use orchestration if available
            local orchestrator="$CLAUDE_PYTHON_DIR/production_orchestrator.py"
            if [[ -f "$orchestrator" ]]; then
                echo "🚀 Launching orchestrated execution..."
                capture_execution python3 "$orchestrator" "${args[@]}"
                return $?
            fi
        fi
    fi

    # Execute Claude with learning capture
    capture_execution "${claude_cmd[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Debug mode
if [[ "${CLAUDE_DEBUG:-}" == "true" ]]; then
    echo "DEBUG: Script dir: $SCRIPT_DIR"
    echo "DEBUG: Project root: $CLAUDE_PROJECT_ROOT"
    echo "DEBUG: Claude binary: $CLAUDE_BINARY"
    echo "DEBUG: Args: $*"
fi

# Execute main function
main "$@"