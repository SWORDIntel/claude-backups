#!/bin/bash

# Agent Sync Script for Claude Framework v7.0
# Automatically commits and pushes agent changes to GitHub

# Configuration
REPO_DIR="/home/ubuntu/Documents/Claude"
LOG_FILE="$REPO_DIR/logs/agent-sync.log"
LOCK_FILE="/tmp/agent-sync.lock"
BRANCH="main"
MAX_LOG_SIZE=10485760  # 10MB

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to rotate log if too large
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            log_message "Log rotated"
        fi
    fi
}

# Check for lock file to prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    log_message "Sync already in progress, exiting"
    exit 0
fi

# Create lock file
touch "$LOCK_FILE"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Start sync process
log_message "Starting agent sync process"
rotate_log

# Change to repository directory
cd "$REPO_DIR" || {
    log_message "ERROR: Could not change to repository directory"
    exit 1
}

# Fetch latest changes from remote
git fetch origin "$BRANCH" >> "$LOG_FILE" 2>&1

# Check if there are any changes to commit
if git diff --quiet && git diff --staged --quiet; then
    # No local changes, check for remote updates
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log_message "Pulling remote changes"
        git pull origin "$BRANCH" >> "$LOG_FILE" 2>&1
    else
        log_message "No changes to sync"
    fi
else
    # There are local changes to commit
    log_message "Found local changes, preparing to commit"
    
    # Add all agent-related changes
    git add agents/*.md agents/*.py agents/src/ >> "$LOG_FILE" 2>&1
    
    # Generate commit message
    MODIFIED_COUNT=$(git diff --cached --name-only | wc -l)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    
    if [ "$MODIFIED_COUNT" -gt 0 ]; then
        # Create descriptive commit message
        COMMIT_MSG="sync: Auto-sync agent updates ($MODIFIED_COUNT files) - $TIMESTAMP"
        
        # Commit changes
        git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "Committed $MODIFIED_COUNT files"
            
            # Push to remote
            git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                log_message "Successfully pushed changes to remote"
            else
                log_message "ERROR: Failed to push changes"
                # Try to pull and merge, then push again
                git pull --rebase origin "$BRANCH" >> "$LOG_FILE" 2>&1
                git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
            fi
        else
            log_message "ERROR: Commit failed"
        fi
    else
        log_message "No staged changes to commit"
    fi
fi

# Clean up any untracked files in deprecated directories
find "$REPO_DIR/agents/deprecated" -type f -name "*.tmp" -delete 2>/dev/null

log_message "Agent sync process completed"