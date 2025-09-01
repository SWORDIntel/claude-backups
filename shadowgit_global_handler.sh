#!/bin/bash
# Claude Global Git Hook Handler - Universal Intelligence Layer
# Crash-proof implementation with extensive error handling and fallbacks

set -euo pipefail
IFS=$'\n\t'

# Global configuration
CLAUDE_GLOBAL_DIR="${HOME}/.claude-global"
CLAUDE_BACKUPS_DIR="${HOME}/claude-backups"
SHADOWGIT_DIR="${HOME}/shadowgit"
LOG_FILE="${CLAUDE_GLOBAL_DIR}/data/global-git.log"

# Get repository information
REPO_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "$REPO_PATH")"
GIT_HOOK_TYPE="${1:-unknown}"
TIMESTAMP="$(date +%s.%N)"

# Logging function
log_event() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$REPO_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Error handler with fallback
handle_error() {
    local error_code=$?
    log_event "ERROR" "Hook execution failed with code $error_code at line $1"
    # Don't block git operations on error
    exit 0
}

trap 'handle_error $LINENO' ERR

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log_event "INFO" "Git hook triggered: $GIT_HOOK_TYPE"

# 1. SHADOWGIT AVX2 INTEGRATION (with fallback)
integrate_shadowgit() {
    if [[ -f "${SHADOWGIT_DIR}/shadowgit_avx2.py" ]]; then
        log_event "INFO" "Shadowgit AVX2 processing started"
        
        # Get current commit info
        local commit_hash="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
        local branch="$(git branch --show-current 2>/dev/null || echo 'unknown')"
        
        # Run shadowgit with timeout and error handling
        timeout 5s python3 "${SHADOWGIT_DIR}/shadowgit_avx2.py" \
            --repo-path "$REPO_PATH" \
            --commit "$commit_hash" \
            --branch "$branch" \
            --hook-type "$GIT_HOOK_TYPE" \
            2>/dev/null || {
                log_event "WARN" "Shadowgit processing timeout or failed, continuing"
            }
    else
        log_event "DEBUG" "Shadowgit not available, skipping"
    fi
}

# 2. LEARNING SYSTEM INTEGRATION (PostgreSQL on port 5433)
integrate_learning_system() {
    # Check if PostgreSQL is accessible
    if nc -z localhost 5433 2>/dev/null; then
        log_event "INFO" "Learning system integration started"
        
        # Export metrics for learning system
        export CLAUDE_AGENT_NAME="GIT_GLOBAL"
        export CLAUDE_TASK_TYPE="$GIT_HOOK_TYPE"
        export CLAUDE_PROJECT_PATH="$REPO_PATH"
        export CLAUDE_START_TIME="$TIMESTAMP"
        
        # Track in learning system with timeout
        timeout 3s python3 "${CLAUDE_BACKUPS_DIR}/hooks/track_agent_performance.py" \
            --global-mode \
            --project "$REPO_NAME" \
            2>/dev/null || {
                log_event "WARN" "Learning system tracking failed, continuing"
            }
    else
        log_event "DEBUG" "PostgreSQL learning system not available on port 5433"
    fi
}

# 3. BINARY COMMUNICATIONS BRIDGE (with availability check)
integrate_binary_comms() {
    local binary_bridge="${CLAUDE_BACKUPS_DIR}/agents/binary-communications-system/agent_bridge"
    
    if [[ -x "$binary_bridge" ]]; then
        log_event "INFO" "Binary communications bridge activation"
        
        # Send event through binary bridge with timeout
        timeout 2s "$binary_bridge" \
            --event-type "git.$GIT_HOOK_TYPE" \
            --repo-path "$REPO_PATH" \
            --timestamp "$TIMESTAMP" \
            2>/dev/null || {
                log_event "WARN" "Binary bridge communication failed, continuing"
            }
    else
        log_event "DEBUG" "Binary communications bridge not available"
    fi
}

# 4. TANDEM ORCHESTRATION INTEGRATION
integrate_tandem_orchestration() {
    local orchestrator="${CLAUDE_BACKUPS_DIR}/agents/src/python/production_orchestrator.py"
    
    if [[ -f "$orchestrator" ]]; then
        log_event "INFO" "Tandem orchestration check"
        
        # Check if multi-agent workflow is needed
        if [[ "$GIT_HOOK_TYPE" == "pre-push" ]] || [[ "$GIT_HOOK_TYPE" == "post-merge" ]]; then
            timeout 5s python3 "$orchestrator" \
                --git-event "$GIT_HOOK_TYPE" \
                --project "$REPO_PATH" \
                --check-workflow \
                2>/dev/null || {
                    log_event "WARN" "Orchestration check failed, continuing"
                }
        fi
    else
        log_event "DEBUG" "Tandem orchestration not available"
    fi
}

# 5. CROSS-PROJECT PATTERN DETECTION
detect_cross_project_patterns() {
    local pattern_detector="${CLAUDE_GLOBAL_DIR}/core/cross-project-learner.py"
    
    if [[ -f "$pattern_detector" ]]; then
        log_event "INFO" "Cross-project pattern detection"
        
        timeout 3s python3 "$pattern_detector" \
            --repo "$REPO_PATH" \
            --event "$GIT_HOOK_TYPE" \
            --detect-patterns \
            2>/dev/null || {
                log_event "DEBUG" "Pattern detection skipped"
            }
    fi
}

# 6. AGENT RECOMMENDATIONS
recommend_agents() {
    # Quick agent recommendation based on file changes
    local changed_files="$(git diff --name-only HEAD~1 2>/dev/null || true)"
    
    if [[ -n "$changed_files" ]]; then
        log_event "INFO" "Analyzing changed files for agent recommendations"
        
        # Simple pattern matching for agent suggestions
        if echo "$changed_files" | grep -q "\.py$"; then
            log_event "INFO" "Python files changed - consider python-internal agent"
        fi
        if echo "$changed_files" | grep -q "\.rs$"; then
            log_event "INFO" "Rust files changed - consider rust-internal agent"
        fi
        if echo "$changed_files" | grep -q "security\|auth\|crypto"; then
            log_event "INFO" "Security-related changes - consider security agent"
        fi
    fi
}

# Main execution flow with parallel processing where possible
main() {
    log_event "INFO" "Starting global hook processing for $REPO_NAME"
    
    # Run integrations in parallel for performance
    {
        integrate_shadowgit &
        local shadowgit_pid=$!
        
        integrate_learning_system &
        local learning_pid=$!
        
        integrate_binary_comms &
        local binary_pid=$!
        
        integrate_tandem_orchestration &
        local tandem_pid=$!
        
        detect_cross_project_patterns &
        local pattern_pid=$!
        
        recommend_agents &
        local agent_pid=$!
        
        # Wait for all background processes with timeout
        for pid in $shadowgit_pid $learning_pid $binary_pid $tandem_pid $pattern_pid $agent_pid; do
            wait $pid 2>/dev/null || true
        done
    } || {
        log_event "WARN" "Some integrations failed but continuing"
    }
    
    log_event "INFO" "Global hook processing completed"
    
    # Store metrics for later analysis
    echo "$REPO_NAME,$GIT_HOOK_TYPE,$TIMESTAMP" >> "${CLAUDE_GLOBAL_DIR}/data/hook-metrics.csv" 2>/dev/null || true
}

# Execute main function
main

# Always exit successfully to not block git operations
exit 0