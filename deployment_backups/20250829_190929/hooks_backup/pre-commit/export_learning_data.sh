#!/bin/bash
# Export learning data before commit

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/Claude")"
LEARNING_SYNC="$PROJECT_ROOT/database/scripts/learning_sync.sh"

if [ -f "$LEARNING_SYNC" ]; then
    echo "📤 Exporting learning data..."
    "$LEARNING_SYNC" export >/dev/null 2>&1
    
    # Add the exported files to the commit
    git add "$PROJECT_ROOT/database/learning_data/" 2>/dev/null
fi

exit 0
