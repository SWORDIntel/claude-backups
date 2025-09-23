#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# CLAUDE PATH RESOLVER v1.0 - UNIVERSAL PORTABLE PATH MANAGEMENT
#
# Provides dynamic path resolution for the entire claude-backups system
# Eliminates ALL hardcoded paths for true cross-platform portability
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CORE PATH DETECTION LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

detect_project_root() {
    local script_dir
    local potential_roots=(
        # Script-relative detection (highest priority)
        "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/.."
        "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.."

        # Environment variable override
        "${CLAUDE_PROJECT_ROOT:-}"

        # Current working directory
        "$(pwd)"

        # Common installation locations
        "$HOME/claude-backups"
        "$HOME/Downloads/claude-backups"
        "$HOME/Documents/claude-backups"
        "$HOME/projects/claude-backups"
        "$HOME/src/claude-backups"

        # System-wide locations
        "/opt/claude-backups"
        "/usr/local/claude-backups"

        # Fallback to home directory
        "$HOME"
    )

    for root in "${potential_roots[@]}"; do
        [[ -z "$root" ]] && continue
        root=$(realpath "$root" 2>/dev/null || echo "$root")

        # Validate by checking for key indicator files
        if [[ -f "$root/CLAUDE.md" ]] || [[ -f "$root/claude-enhanced-installer.py" ]] || [[ -d "$root/agents" ]]; then
            echo "$root"
            return 0
        fi
    done

    # Ultimate fallback
    echo "$HOME"
}

detect_user_home() {
    # Multiple methods to detect user home
    local homes=(
        "${HOME:-}"
        "$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f6 || echo "")"
        "$(eval echo "~$(whoami)" 2>/dev/null || echo "")"
        "/home/$(whoami)"
    )

    for home in "${homes[@]}"; do
        [[ -n "$home" && -d "$home" ]] && echo "$home" && return 0
    done

    echo "/tmp"  # Emergency fallback
}

detect_system_paths() {
    # Detect appropriate system paths based on OS and permissions
    local user_writable_bins=(
        "$HOME/.local/bin"
        "$HOME/bin"
    )

    local system_bins=(
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
    )

    # Find first writable user bin
    export CLAUDE_USER_BIN=""
    for bin in "${user_writable_bins[@]}"; do
        if [[ -d "$bin" ]] || mkdir -p "$bin" 2>/dev/null; then
            if [[ -w "$bin" ]]; then
                export CLAUDE_USER_BIN="$bin"
                break
            fi
        fi
    done

    # Find first writable system bin (if we have permissions)
    export CLAUDE_SYSTEM_BIN=""
    for bin in "${system_bins[@]}"; do
        if [[ -w "$bin" ]] 2>/dev/null; then
            export CLAUDE_SYSTEM_BIN="$bin"
            break
        fi
    done

    # Set default user bin if none found
    [[ -z "$CLAUDE_USER_BIN" ]] && export CLAUDE_USER_BIN="$HOME/.local/bin"
}

detect_config_paths() {
    # XDG Base Directory Specification compliant paths
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

    # Claude-specific paths
    export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
    export CLAUDE_DATA_DIR="$XDG_DATA_HOME/claude"
    export CLAUDE_CACHE_DIR="$XDG_CACHE_HOME/claude"
    export CLAUDE_STATE_DIR="$XDG_STATE_HOME/claude"
    export CLAUDE_LOG_DIR="${CLAUDE_STATE_DIR}/logs"
}

detect_optional_system_paths() {
    # Optional system paths that may or may not exist
    export OPENVINO_ROOT=""
    local openvino_locations=(
        "/opt/openvino"
        "/usr/local/openvino"
        "${HOME}/openvino"
        "${HOME}/.local/openvino"
    )

    for location in "${openvino_locations[@]}"; do
        if [[ -d "$location" ]]; then
            export OPENVINO_ROOT="$location"
            break
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

initialize_claude_paths() {
    # Detect core paths
    export CLAUDE_USER_HOME="$(detect_user_home)"
    export CLAUDE_PROJECT_ROOT="$(detect_project_root)"

    # Detect system paths
    detect_system_paths
    detect_config_paths
    detect_optional_system_paths

    # Project structure paths
    export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
    export CLAUDE_SCRIPTS_DIR="$CLAUDE_PROJECT_ROOT/scripts"
    export CLAUDE_TOOLS_DIR="$CLAUDE_PROJECT_ROOT/tools"
    export CLAUDE_DATABASE_DIR="$CLAUDE_PROJECT_ROOT/database"
    export CLAUDE_DOCS_DIR="$CLAUDE_PROJECT_ROOT/docs"
    export CLAUDE_HOOKS_DIR="$CLAUDE_PROJECT_ROOT/hooks"

    # Python paths
    export CLAUDE_PYTHON_DIR="$CLAUDE_AGENTS_DIR/src/python"
    export CLAUDE_PYTHON_CONFIG="$CLAUDE_PYTHON_DIR/config"

    # Docker and database paths
    export CLAUDE_DOCKER_DIR="$CLAUDE_DATABASE_DIR/docker"
    export CLAUDE_LEARNING_DIR="$CLAUDE_PROJECT_ROOT/learning"

    # Ensure critical directories exist
    mkdir -p "$CLAUDE_CONFIG_DIR" "$CLAUDE_DATA_DIR" "$CLAUDE_CACHE_DIR" \
             "$CLAUDE_STATE_DIR" "$CLAUDE_LOG_DIR" 2>/dev/null || true

    # Create convenience symlinks if they don't exist
    [[ ! -e "$CLAUDE_USER_HOME/.claude" ]] && \
        ln -sf "$CLAUDE_CONFIG_DIR" "$CLAUDE_USER_HOME/.claude" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

claude_path_status() {
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "CLAUDE PATH RESOLVER STATUS"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "User Home:          $CLAUDE_USER_HOME"
    echo "Project Root:       $CLAUDE_PROJECT_ROOT"
    echo "User Bin:           $CLAUDE_USER_BIN"
    echo "System Bin:         ${CLAUDE_SYSTEM_BIN:-<none writable>}"
    echo "Config Dir:         $CLAUDE_CONFIG_DIR"
    echo "Data Dir:           $CLAUDE_DATA_DIR"
    echo "Cache Dir:          $CLAUDE_CACHE_DIR"
    echo "Log Dir:            $CLAUDE_LOG_DIR"
    echo "Agents Dir:         $CLAUDE_AGENTS_DIR"
    echo "Python Dir:         $CLAUDE_PYTHON_DIR"
    echo "Docker Dir:         $CLAUDE_DOCKER_DIR"
    echo "OpenVINO Root:      ${OPENVINO_ROOT:-<not found>}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

export_claude_paths() {
    # Export all paths for use in other scripts
    cat << 'EOF'
# CLAUDE PATH RESOLVER EXPORTS
export CLAUDE_USER_HOME="$CLAUDE_USER_HOME"
export CLAUDE_PROJECT_ROOT="$CLAUDE_PROJECT_ROOT"
export CLAUDE_USER_BIN="$CLAUDE_USER_BIN"
export CLAUDE_SYSTEM_BIN="$CLAUDE_SYSTEM_BIN"
export CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR"
export CLAUDE_DATA_DIR="$CLAUDE_DATA_DIR"
export CLAUDE_CACHE_DIR="$CLAUDE_CACHE_DIR"
export CLAUDE_STATE_DIR="$CLAUDE_STATE_DIR"
export CLAUDE_LOG_DIR="$CLAUDE_LOG_DIR"
export CLAUDE_AGENTS_DIR="$CLAUDE_AGENTS_DIR"
export CLAUDE_SCRIPTS_DIR="$CLAUDE_SCRIPTS_DIR"
export CLAUDE_TOOLS_DIR="$CLAUDE_TOOLS_DIR"
export CLAUDE_DATABASE_DIR="$CLAUDE_DATABASE_DIR"
export CLAUDE_DOCS_DIR="$CLAUDE_DOCS_DIR"
export CLAUDE_HOOKS_DIR="$CLAUDE_HOOKS_DIR"
export CLAUDE_PYTHON_DIR="$CLAUDE_PYTHON_DIR"
export CLAUDE_PYTHON_CONFIG="$CLAUDE_PYTHON_CONFIG"
export CLAUDE_DOCKER_DIR="$CLAUDE_DOCKER_DIR"
export CLAUDE_LEARNING_DIR="$CLAUDE_LEARNING_DIR"
export OPENVINO_ROOT="$OPENVINO_ROOT"
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND LINE INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    case "${1:-init}" in
        "init")
            initialize_claude_paths
            ;;
        "status"|"show")
            initialize_claude_paths
            claude_path_status
            ;;
        "export")
            initialize_claude_paths
            export_claude_paths
            ;;
        "help"|"-h"|"--help")
            echo "Claude Path Resolver v1.0"
            echo "Usage: $0 [init|status|export|help]"
            echo ""
            echo "Commands:"
            echo "  init    - Initialize all Claude paths (default)"
            echo "  status  - Show current path configuration"
            echo "  export  - Output environment variables for sourcing"
            echo "  help    - Show this help message"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]:-}" != "${0:-}" ]]; then
    # Being sourced - initialize automatically
    initialize_claude_paths
else
    # Being executed - run main function
    main "$@"
fi