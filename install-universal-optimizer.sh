#!/bin/bash
# Universal Optimizer Installation Script (Simplified for Phase 1)
# Creates system-wide infrastructure for Claude optimization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SYSTEM_DIR="$HOME/.claude/system"

echo "Installing Claude Universal Optimizer Infrastructure..."

# Create directory structure
mkdir -p "$CLAUDE_SYSTEM_DIR"/{modules,config,logs,cache,db}

# Copy optimizer if it exists
if [[ -f "$SCRIPT_DIR/claude_universal_optimizer.py" ]]; then
    cp "$SCRIPT_DIR/claude_universal_optimizer.py" "$CLAUDE_SYSTEM_DIR/modules/"
    echo "✓ Optimizer module installed"
fi

# Copy Python modules if they exist
if [[ -d "$SCRIPT_DIR/agents/src/python" ]]; then
    for module in intelligent_context_chopper.py token_optimizer.py permission_fallback_system.py; do
        if [[ -f "$SCRIPT_DIR/agents/src/python/$module" ]]; then
            cp "$SCRIPT_DIR/agents/src/python/$module" "$CLAUDE_SYSTEM_DIR/modules/" 2>/dev/null || true
        fi
    done
    echo "✓ Python modules copied"
fi

# Create basic config
cat > "$CLAUDE_SYSTEM_DIR/config/optimizer.conf" << 'EOF'
[general]
enabled = true
log_level = INFO

[optimization]
auto_optimize = true
cache_enabled = true
max_cache_size = 1G
EOF

echo "✓ Configuration created"

# Create wrapper script
WRAPPER_SCRIPT="$HOME/.local/bin/claude"
mkdir -p "$HOME/.local/bin"

cat > "$WRAPPER_SCRIPT" << 'EOF'
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
EOF

chmod +x "$WRAPPER_SCRIPT"
echo "✓ Wrapper installed at $WRAPPER_SCRIPT"

echo ""
echo "Installation complete!"
echo "System directory: $CLAUDE_SYSTEM_DIR"
echo "Add $HOME/.local/bin to your PATH if not already present"