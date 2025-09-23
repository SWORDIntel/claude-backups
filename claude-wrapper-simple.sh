#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# CLAUDE SIMPLE PORTABLE WRAPPER v1.0 - MINIMAL HARDCODED PATHS
#
# Lightweight wrapper focusing on essential path portability
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# SIMPLE PATH DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Detect script directory
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"

# Project root detection
if [[ -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
    export CLAUDE_PROJECT_ROOT="$SCRIPT_DIR"
elif [[ -f "$(dirname "$SCRIPT_DIR")/CLAUDE.md" ]]; then
    export CLAUDE_PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
elif [[ -n "${CLAUDE_PROJECT_ROOT:-}" ]]; then
    export CLAUDE_PROJECT_ROOT="$CLAUDE_PROJECT_ROOT"
elif [[ -f "$HOME/claude-backups/CLAUDE.md" ]]; then
    export CLAUDE_PROJECT_ROOT="$HOME/claude-backups"
elif [[ -f "$HOME/Documents/claude-backups/CLAUDE.md" ]]; then
    export CLAUDE_PROJECT_ROOT="$HOME/Documents/claude-backups"
else
    export CLAUDE_PROJECT_ROOT="$HOME"
fi

# XDG-compliant paths
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
export CLAUDE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude"
export CLAUDE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
export CLAUDE_LOG_DIR="$CLAUDE_DATA_DIR/logs"

# Project structure paths
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
export CLAUDE_PYTHON_DIR="$CLAUDE_AGENTS_DIR/src/python"
export CLAUDE_DOCKER_DIR="$CLAUDE_PROJECT_ROOT/database/docker"

# User paths
export CLAUDE_USER_BIN="$HOME/.local/bin"

# Create essential directories
mkdir -p "$CLAUDE_CONFIG_DIR" "$CLAUDE_DATA_DIR" "$CLAUDE_CACHE_DIR" "$CLAUDE_LOG_DIR" "$CLAUDE_USER_BIN" 2>/dev/null || true

# Learning configuration
export LEARNING_CAPTURE_ENABLED="${LEARNING_CAPTURE_ENABLED:-true}"
export LEARNING_DB_PORT="${LEARNING_DB_PORT:-5433}"
export LEARNING_LOG_PATH="$CLAUDE_LOG_DIR/learning"
export LEARNING_DOCKER_COMPOSE_PATH="$CLAUDE_DOCKER_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE BINARY DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

detect_claude_binary() {
    local script_path="$(readlink -f "$0")"

    # Check environment override first
    if [[ -n "${CLAUDE_BINARY_PATH:-}" && -x "$CLAUDE_BINARY_PATH" ]]; then
        echo "$CLAUDE_BINARY_PATH"
        return 0
    fi

    # Node.js installations
    local node_paths=(
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    )

    for path in "${node_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "node $path"
            return 0
        fi
    done

    # Binary installations
    local binary_paths=(
        "/usr/local/bin/claude"
        "/usr/bin/claude"
        "$HOME/.local/bin/claude"
    )

    for path in "${binary_paths[@]}"; do
        if [[ -f "$path" && -x "$path" ]]; then
            local path_real="$(readlink -f "$path" 2>/dev/null || echo "$path")"
            if [[ "$path_real" != "$script_path" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done

    # Fallback - let the system find it
    if command -v claude >/dev/null 2>&1; then
        local found_claude="$(command -v claude)"
        local found_real="$(readlink -f "$found_claude" 2>/dev/null || echo "$found_claude")"
        if [[ "$found_real" != "$script_path" ]]; then
            echo "$found_claude"
            return 0
        fi
    fi

    # Ultimate fallback
    echo "claude"
}

CLAUDE_BINARY="$(detect_claude_binary)"

# ═══════════════════════════════════════════════════════════════════════════════
# PERMISSION BYPASS
# ═══════════════════════════════════════════════════════════════════════════════

should_bypass_permissions() {
    # Environment override
    [[ "${CLAUDE_PERMISSION_BYPASS:-}" == "false" ]] && return 1

    # Check for LiveCD/restricted environments
    if [[ -e "/lib/live/mount" || -e "/run/live" ]]; then
        return 0
    fi

    if [[ -f "/proc/cmdline" ]] && grep -q "boot=live\|live-media" /proc/cmdline 2>/dev/null; then
        return 0
    fi

    # Default to bypass
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local args=("$@")

    # Handle special commands
    case "${1:-}" in
        "--status"|"--portable-status")
            echo "Claude Simple Portable Wrapper v1.0"
            echo "Project Root: $CLAUDE_PROJECT_ROOT"
            echo "Config Dir:   $CLAUDE_CONFIG_DIR"
            echo "Data Dir:     $CLAUDE_DATA_DIR"
            echo "Binary:       $CLAUDE_BINARY"
            echo "Learning:     ${LEARNING_CAPTURE_ENABLED:-false}"
            return 0
            ;;
        "--safe")
            export CLAUDE_PERMISSION_BYPASS=false
            args=("${args[@]:1}")
            ;;
        "--help"|"-h")
            echo "Claude Simple Portable Wrapper v1.0"
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
            echo "  CLAUDE_BINARY_PATH=path           Override Claude binary"
            echo "  LEARNING_CAPTURE_ENABLED=false    Disable learning capture"
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

    # Execute Claude
    exec "${claude_cmd[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Debug mode
if [[ "${CLAUDE_DEBUG:-}" == "true" ]]; then
    echo "DEBUG: Project root: $CLAUDE_PROJECT_ROOT"
    echo "DEBUG: Claude binary: $CLAUDE_BINARY"
    echo "DEBUG: Args: $*"
fi

# Execute main function
main "$@"