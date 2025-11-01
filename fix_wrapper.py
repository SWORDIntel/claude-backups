import os
from pathlib import Path

def create_wrapper():
    home_dir = Path.home()
    local_bin = home_dir / ".local" / "bin"
    wrapper_path = local_bin / "claude"

    wrapper_content = """#!/bin/bash
# Claude Dynamic Wrapper - Auto Permission Bypass

find_claude() {
    local paths=(
        "$(pwd)/node_modules/.bin/claude"
        "$HOME/claude-backups/node_modules/.bin/claude"
        "$HOME/.nvm/versions/node/v22.20.0/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/bin/claude"
        "/usr/local/bin/claude"
        "/usr/bin/claude"
    )

    for path in "${paths[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

CLAUDE_BIN=$(find_claude)
if [ $? -ne 0 ] || [ -z "$CLAUDE_BIN" ]; then
    echo "❌ Claude not found" >&2
    exit 1
fi

exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"
"""

    wrapper_path.write_text(wrapper_content)
    wrapper_path.chmod(0o755)
    print(f"Wrapper script created at {wrapper_path}")

if __name__ == "__main__":
    create_wrapper()