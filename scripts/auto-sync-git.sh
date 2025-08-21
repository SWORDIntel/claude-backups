#!/bin/bash

# Auto Git Sync for Claude Agent Framework
# Automatically commits and pushes agent changes to GitHub repository

# Configuration
REPO_DIR="/home/ubuntu/Documents/Claude"
LOG_FILE="$REPO_DIR/logs/git-sync.log"
LOCK_FILE="/tmp/git-sync.lock"
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
    log_message "Git sync already in progress, exiting"
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
log_message "====== Starting Git sync process ======"
rotate_log

# Change to repository directory
cd "$REPO_DIR" || {
    log_message "ERROR: Could not change to repository directory"
    exit 1
}

# Fetch latest changes from remote
log_message "Fetching latest from remote..."
git fetch origin "$BRANCH" >> "$LOG_FILE" 2>&1

# Check if there are any changes to commit
if git diff --quiet && git diff --staged --quiet; then
    # No local changes, check for remote updates
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log_message "Pulling remote changes..."
        git pull origin "$BRANCH" >> "$LOG_FILE" 2>&1
        log_message "Remote changes pulled successfully"
    else
        log_message "No changes to sync (repository is up to date)"
    fi
else
    # There are local changes to commit
    log_message "Found local changes, preparing to commit..."
    
    # Add all agent-related changes
    git add agents/*.md agents/*.MD agents/*.py agents/src/ >> "$LOG_FILE" 2>&1
    
    # Also add any database, docs, or script changes
    git add database/ docs/ scripts/ >> "$LOG_FILE" 2>&1
    
    # Check what files are staged
    STAGED_FILES=$(git diff --cached --name-only)
    MODIFIED_COUNT=$(echo "$STAGED_FILES" | grep -v '^$' | wc -l)
    
    if [ "$MODIFIED_COUNT" -gt 0 ]; then
        # Determine the type of changes for better commit messages
        AGENT_CHANGES=$(echo "$STAGED_FILES" | grep -c "agents/.*\.md" || true)
        PY_CHANGES=$(echo "$STAGED_FILES" | grep -c "\.py$" || true)
        DB_CHANGES=$(echo "$STAGED_FILES" | grep -c "database/" || true)
        
        # Build descriptive commit message
        COMMIT_MSG="sync: Auto-sync"
        
        if [ "$AGENT_CHANGES" -gt 0 ]; then
            COMMIT_MSG="$COMMIT_MSG agent updates ($AGENT_CHANGES agents)"
        fi
        
        if [ "$PY_CHANGES" -gt 0 ]; then
            if [ "$AGENT_CHANGES" -gt 0 ]; then
                COMMIT_MSG="$COMMIT_MSG and Python implementations"
            else
                COMMIT_MSG="$COMMIT_MSG Python implementations"
            fi
        fi
        
        if [ "$DB_CHANGES" -gt 0 ]; then
            COMMIT_MSG="$COMMIT_MSG + database updates"
        fi
        
        COMMIT_MSG="$COMMIT_MSG - $(date '+%Y-%m-%d %H:%M')"
        
        # Log what we're about to commit
        log_message "Staging $MODIFIED_COUNT files for commit"
        echo "$STAGED_FILES" | head -10 >> "$LOG_FILE"
        
        # Commit changes
        git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "Successfully committed $MODIFIED_COUNT files"
            
            # Push to remote
            log_message "Pushing to remote repository..."
            git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                log_message "✓ Successfully pushed changes to GitHub"
            else
                log_message "⚠ Push failed, attempting pull --rebase..."
                # Try to pull and rebase, then push again
                git pull --rebase origin "$BRANCH" >> "$LOG_FILE" 2>&1
                
                if [ $? -eq 0 ]; then
                    git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
                    if [ $? -eq 0 ]; then
                        log_message "✓ Successfully pushed after rebase"
                    else
                        log_message "✗ Push failed after rebase - manual intervention required"
                    fi
                else
                    log_message "✗ Rebase failed - manual intervention required"
                fi
            fi
        else
            log_message "ERROR: Commit failed"
        fi
    else
        log_message "No staged changes to commit"
    fi
fi

# Get current status for logging
CURRENT_BRANCH=$(git branch --show-current)
COMMIT_COUNT=$(git rev-list --count HEAD)
LAST_COMMIT=$(git log -1 --pretty=format:"%h - %s" 2>/dev/null)

log_message "Current branch: $CURRENT_BRANCH"
log_message "Total commits: $COMMIT_COUNT"
log_message "Last commit: $LAST_COMMIT"
log_message "====== Git sync process completed ======

"