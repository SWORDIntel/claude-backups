#!/bin/bash
# Simple test for portable wrapper functionality

set -euo pipefail

echo "Testing path resolver..."
source ./scripts/claude-path-resolver.sh init

echo "CLAUDE_PROJECT_ROOT: $CLAUDE_PROJECT_ROOT"
echo "CLAUDE_USER_HOME: $CLAUDE_USER_HOME"
echo "CLAUDE_CONFIG_DIR: $CLAUDE_CONFIG_DIR"

echo "Testing binary detection..."
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

detect_claude_binary() {
    local script_path="$(readlink -f "$0")"
    local binary_candidates=(
        # Environment override
        "${CLAUDE_BINARY_PATH:-}"

        # Node.js installations
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "${CLAUDE_USER_HOME:-$HOME}/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"

        # System binaries (avoid self-reference)
        "/usr/local/bin/claude"
        "/usr/bin/claude"
        "${CLAUDE_USER_BIN:-$HOME/.local/bin}/claude"
    )

    for candidate in "${binary_candidates[@]}"; do
        [[ -z "$candidate" ]] && continue
        echo "Checking: $candidate"

        # Handle Node.js entries
        if [[ "$candidate" == *.js ]]; then
            if [[ -f "$candidate" ]]; then
                echo "Found Node.js: $candidate"
                return 0
            fi
            continue
        fi

        # Handle binary entries
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            local candidate_real="$(readlink -f "$candidate" 2>/dev/null || echo "$candidate")"
            if [[ "$candidate_real" != "$script_path" ]]; then
                echo "Found binary: $candidate"
                return 0
            fi
        fi
    done

    echo "No Claude binary found"
}

detect_claude_binary

echo "Test completed successfully!"