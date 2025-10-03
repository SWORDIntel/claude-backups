#!/usr/bin/env bash
################################################################################
# Transaction-Based State Management Module
# Version: 1.0.0
# Provides atomic state tracking with rollback capability
################################################################################

set -euo pipefail

# State file location
readonly STATE_FILE="${STATE_FILE:-$HOME/.claude-install-state.json}"
readonly STATE_VERSION="1.0"

# Initialize state management
state_init() {
    local state_dir
    state_dir=$(dirname "$STATE_FILE")
    mkdir -p "$state_dir" 2>/dev/null || return 1

    if [[ ! -f "$STATE_FILE" ]]; then
        echo "{\"version\":\"$STATE_VERSION\",\"created\":\"$(date -Iseconds)\"}" > "$STATE_FILE"
    fi

    return 0
}

# Save state value
state_save() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$STATE_FILE" ]]; then
        state_init
    fi

    # Simple key=value append (can use jq for JSON if available)
    if command -v jq &>/dev/null; then
        local temp
        temp=$(mktemp)
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$STATE_FILE" > "$temp" && mv "$temp" "$STATE_FILE"
    else
        # Fallback to simple key=value format
        echo "${key}=${value}" >> "$STATE_FILE"
    fi

    return 0
}

# Get state value
state_get() {
    local key="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE"
    else
        grep "^${key}=" "$STATE_FILE" | cut -d= -f2- | tail -1
    fi
}

# Lock state file
state_lock() {
    local lock_name="$1"
    local lock_file="${STATE_FILE}.${lock_name}.lock"

    if ! mkdir "$lock_file" 2>/dev/null; then
        return 1
    fi

    echo $$ > "$lock_file/pid"
    return 0
}

# Unlock state file
state_unlock() {
    local lock_name="$1"
    local lock_file="${STATE_FILE}.${lock_name}.lock"

    rm -rf "$lock_file" 2>/dev/null
}

# Cleanup on exit
state_cleanup_on_exit() {
    # Remove all locks for this PID
    find "$(dirname "$STATE_FILE")" -name "*.lock" -type d 2>/dev/null | while read -r lock; do
        if [[ -f "$lock/pid" ]] && [[ "$(cat "$lock/pid")" == "$$" ]]; then
            rm -rf "$lock"
        fi
    done
}
