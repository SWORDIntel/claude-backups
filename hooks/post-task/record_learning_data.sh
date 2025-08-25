#!/bin/bash
# Record task execution for learning system

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/Claude")"
TASK_TYPE="${CLAUDE_TASK_TYPE:-general}"
AGENTS_USED="${CLAUDE_AGENTS_USED:-unknown}"
SUCCESS="${CLAUDE_TASK_SUCCESS:-true}"

# Record in learning system if available
if [ -f "$PROJECT_ROOT/agents/src/python/learning_cli.py" ]; then
    export POSTGRES_DB=claude_auth
    export POSTGRES_USER=claude_auth
    export POSTGRES_PASSWORD=claude_auth_pass
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5433
    
    # Start database if needed
    "$PROJECT_ROOT/database/start_local_postgres.sh" >/dev/null 2>&1
    
    # Record execution (if CLI supports it)
    python3 "$PROJECT_ROOT/agents/src/python/learning_cli.py" record \
        --task-type "$TASK_TYPE" \
        --agents "$AGENTS_USED" \
        --success "$SUCCESS" 2>/dev/null || true
fi

exit 0
