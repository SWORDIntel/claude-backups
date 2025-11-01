#!/bin/bash
# Claude Universal Optimizer Wrapper

OPTIMIZER_DIR="$HOME/.claude/system"
OPTIMIZER_MODULE="$OPTIMIZER_DIR/modules/claude_universal_optimizer.py"

if [[ -f "$OPTIMIZER_MODULE" ]]; then
    export CLAUDE_OPTIMIZER_ENABLED=1
    export CLAUDE_OPTIMIZER_DIR="$OPTIMIZER_DIR"
fi

# Find and execute original claude
for path in /usr/local/bin/claude /usr/bin/claude; do
    if [[ -x "$path" && "$path" != "$0" ]]; then
        exec "$path" "$@"
    fi
done

echo "Claude command not found" >&2
exit 1
