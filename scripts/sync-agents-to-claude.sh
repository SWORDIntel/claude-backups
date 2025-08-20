#!/bin/bash
# ============================================================================
# SYNC AGENTS TO CLAUDE CODE DISCOVERY LOCATION
# 
# This script ensures agents are available to Claude Code's Task tool
# by syncing them to ~/.claude/agents/
# ============================================================================

set -euo pipefail

# Configuration
SOURCE_DIR="/home/siducer/Documents/Claude/agents"
TARGET_DIR="$HOME/.claude/agents"
LOG_FILE="$HOME/.claude/agent-sync.log"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Start sync
log_message "Starting agent sync from $SOURCE_DIR to $TARGET_DIR"

# Check if source exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_message "ERROR: Source directory $SOURCE_DIR not found"
    exit 1
fi

# Create ~/.claude if it doesn't exist
mkdir -p "$HOME/.claude"

# Check if target is a symlink
if [ -L "$TARGET_DIR" ]; then
    # Symlink exists, verify it points to the right place
    link_target=$(readlink -f "$TARGET_DIR")
    if [ "$link_target" = "$(readlink -f "$SOURCE_DIR")" ]; then
        log_message "Symlink already correct: $TARGET_DIR -> $SOURCE_DIR"
        exit 0
    else
        log_message "Removing incorrect symlink: $TARGET_DIR -> $link_target"
        rm "$TARGET_DIR"
    fi
fi

# If target exists but is not a symlink, back it up
if [ -e "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
    backup_dir="$HOME/.claude/agents.backup.$(date +%Y%m%d-%H%M%S)"
    log_message "Backing up existing agents to $backup_dir"
    mv "$TARGET_DIR" "$backup_dir"
fi

# Create symlink
ln -sf "$SOURCE_DIR" "$TARGET_DIR"
log_message "Created symlink: $TARGET_DIR -> $SOURCE_DIR"

# Count agents
agent_count=$(find "$SOURCE_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)
log_message "SUCCESS: $agent_count agents now available to Claude Code"

# Keep log file size manageable (keep last 1000 lines)
if [ -f "$LOG_FILE" ]; then
    tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi