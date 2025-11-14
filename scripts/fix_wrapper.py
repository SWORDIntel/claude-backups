from pathlib import Path
from textwrap import dedent


def create_wrapper():
    home_dir = Path.home()
    local_bin = home_dir / ".local" / "bin"
    local_bin.mkdir(parents=True, exist_ok=True)

    wrapper_path = local_bin / "claude"
    project_root = Path(__file__).resolve().parent

    claude_config_dir = home_dir / ".claude"
    claude_config_dir.mkdir(parents=True, exist_ok=True)
    project_hint_file = claude_config_dir / "project_root"
    project_hint_file.write_text(str(project_root))

    wrapper_content = dedent(
        """\
        #!/bin/bash
        # Claude Unified Wrapper - dynamic project detection, no hardcoded links

        set -euo pipefail

        OPTIMIZER_DIR="$HOME/.claude/system"
        OPTIMIZER_MODULE="$OPTIMIZER_DIR/modules/claude_universal_optimizer.py"

        if [[ -f "$OPTIMIZER_MODULE" ]]; then
            export CLAUDE_OPTIMIZER_ENABLED=1
            export CLAUDE_OPTIMIZER_DIR="$OPTIMIZER_DIR"
        fi

        PROJECT_ROOT_HINT_FILE="$HOME/.claude/project_root"

        resolve_project_root() {
            if [[ -n "${CLAUDE_PROJECT_ROOT:-}" ]]; then
                echo "$CLAUDE_PROJECT_ROOT"
                return 0
            fi

            if [[ -f "$PROJECT_ROOT_HINT_FILE" ]]; then
                local hint
                hint=$(cat "$PROJECT_ROOT_HINT_FILE" 2>/dev/null || true)
                if [[ -n "$hint" && -d "$hint" ]]; then
                    echo "$hint"
                    return 0
                fi
            fi

            local candidates=(
                "$PWD"
                "$HOME/claude-backups"
                "$HOME/Documents/claude-backups"
                "$HOME/Downloads/claude-backups"
                "$HOME/projects/claude-backups"
                "$HOME/src/claude-backups"
                "/opt/claude-backups"
                "/usr/local/claude-backups"
            )

            local candidate=""
            for candidate in "${candidates[@]}"; do
                [[ -z "$candidate" ]] && continue
                candidate=$(realpath "$candidate" 2>/dev/null || echo "$candidate")
                if [[ -d "$candidate/scripts" && -f "$candidate/scripts/claude-unified" ]]; then
                    echo "$candidate"
                    return 0
                fi
            done

            return 1
        }

        PROJECT_ROOT="$(resolve_project_root 2>/dev/null || true)"
        if [[ -z "${PROJECT_ROOT:-}" ]]; then
            PROJECT_ROOT="$HOME/claude-backups"
        fi

        WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/claude-unified"

        if [[ -x "$WRAPPER_SCRIPT" ]]; then
            exec "$WRAPPER_SCRIPT" "$@"
        fi

        find_claude() {
            local paths=(
                "$PROJECT_ROOT/node_modules/.bin/claude"
                "$HOME/claude-backups/node_modules/.bin/claude"
                "$HOME/.npm-global/bin/claude"
                "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
                "/usr/local/bin/claude"
                "/usr/bin/claude"
            )

            local candidate=""
            for candidate in "${paths[@]}"; do
                if [[ -f "$candidate" && -x "$candidate" ]]; then
                    echo "$candidate"
                    return 0
                fi
            done

            if [[ -n "${NVM_DIR:-}" ]]; then
                for candidate in "$NVM_DIR"/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js; do
                    if [[ -f "$candidate" && -x "$candidate" ]]; then
                        echo "$candidate"
                        return 0
                    fi
                done
            fi

            return 1
        }

        if CLAUDE_BIN="$(find_claude)"; then
            exec "$CLAUDE_BIN" --dangerously-skip-permissions "$@"
        fi

        for fallback in /usr/local/bin/claude /usr/bin/claude; do
            if [[ -x "$fallback" && "$fallback" != "$0" ]]; then
                exec "$fallback" "$@"
            fi
        done

        echo "Claude command not found" >&2
        exit 1
        """
    )

    wrapper_path.write_text(wrapper_content)
    wrapper_path.chmod(0o755)
    print(f"Wrapper script created at {wrapper_path}")

    capital_wrapper = local_bin / "Claude"
    try:
        wrapper_target = wrapper_path.resolve()
        created_alias = False

        if capital_wrapper.is_symlink():
            if capital_wrapper.resolve() != wrapper_target:
                capital_wrapper.unlink()
                capital_wrapper.symlink_to(wrapper_path)
                created_alias = True
        elif capital_wrapper.exists():
            capital_wrapper.unlink()
            capital_wrapper.symlink_to(wrapper_path)
            created_alias = True
        else:
            capital_wrapper.symlink_to(wrapper_path)
            created_alias = True

        if created_alias:
            print(f"Alias created at {capital_wrapper}")
    except OSError as exc:
        print(f"Warning: failed to create 'Claude' alias: {exc}")


if __name__ == "__main__":
    create_wrapper()
