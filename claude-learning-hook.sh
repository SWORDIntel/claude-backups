#!/bin/bash

# Claude Learning Hook - Tracks every Claude Code execution
# This script wraps Claude to automatically collect learning data

set -e

# Configuration
LEARNING_COLLECTOR="/home/john/claude-backups/agents/src/python/claude_execution_tracker.py"
CLAUDE_BINARY="${CLAUDE_BINARY:-claude}"
DOCKER_CHECK_INTERVAL=5
MAX_DOCKER_WAIT=30

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to ensure Docker PostgreSQL is running
ensure_postgres_running() {
    local waited=0
    
    # Check if PostgreSQL container is running
    if ! docker ps | grep -q "claude-postgres"; then
        echo -e "${YELLOW}Starting PostgreSQL for learning system...${NC}" >&2
        cd /home/john/claude-backups/database/docker
        docker-compose up -d postgres >/dev/null 2>&1
        
        # Wait for PostgreSQL to be ready
        while [ $waited -lt $MAX_DOCKER_WAIT ]; do
            if docker exec claude-postgres pg_isready -U claude_agent >/dev/null 2>&1; then
                echo -e "${GREEN}Learning system ready!${NC}" >&2
                break
            fi
            sleep 1
            waited=$((waited + 1))
        done
    fi
}

# Function to track execution start
track_execution_start() {
    local task_description="$1"
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local task_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    
    # Export for use in track_execution_end
    export CLAUDE_TASK_ID="$task_id"
    export CLAUDE_START_TIME="$start_time"
    export CLAUDE_TASK_DESC="$task_description"
    
    # Start tracking in background
    if [ -f "$LEARNING_COLLECTOR" ]; then
        python3 "$LEARNING_COLLECTOR" start \
            --task-id "$task_id" \
            --task "$task_description" \
            --agent "claude-code" \
            --start-time "$start_time" \
            2>/dev/null &
        export CLAUDE_TRACKER_PID=$!
    fi
}

# Function to track execution end
track_execution_end() {
    local exit_code=$1
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    if [ -n "$CLAUDE_TASK_ID" ] && [ -f "$LEARNING_COLLECTOR" ]; then
        # Calculate duration
        local start_epoch=$(date -d "$CLAUDE_START_TIME" +%s 2>/dev/null || echo 0)
        local end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo 0)
        local duration=$((end_epoch - start_epoch))
        
        # Track completion
        python3 "$LEARNING_COLLECTOR" complete \
            --task-id "$CLAUDE_TASK_ID" \
            --success $([ $exit_code -eq 0 ] && echo "true" || echo "false") \
            --exit-code $exit_code \
            --duration $duration \
            --end-time "$end_time" \
            2>/dev/null &
        
        # Kill start tracker if still running
        if [ -n "$CLAUDE_TRACKER_PID" ]; then
            kill $CLAUDE_TRACKER_PID 2>/dev/null || true
        fi
    fi
}

# Main execution
main() {
    # Ensure learning system is running
    ensure_postgres_running
    
    # Extract task description from arguments
    local task_description=""
    local has_task=false
    
    for arg in "$@"; do
        if [ "$has_task" = true ]; then
            task_description="$arg"
            break
        fi
        if [[ "$arg" == "/task" ]] || [[ "$arg" == "--task" ]]; then
            has_task=true
        fi
    done
    
    # If no task found, try to extract from other patterns
    if [ -z "$task_description" ]; then
        # Check for direct command
        if [ $# -gt 0 ]; then
            task_description="$*"
        else
            task_description="Interactive Claude session"
        fi
    fi
    
    # Track execution start
    track_execution_start "$task_description"
    
    # Run Claude with all arguments
    exec $CLAUDE_BINARY "$@"
    
    # Note: exec replaces this process, so the following won't run
    # We need to use a trap instead
}

# Set up trap to track execution end
trap 'track_execution_end $?' EXIT

# Run main
main "$@"