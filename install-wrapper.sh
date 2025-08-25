#!/bin/bash

# Installation script for Claude Ultimate Wrapper v13.1

echo "Installing Claude Ultimate Wrapper v13.1..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_PATH="$SCRIPT_DIR/claude-wrapper-ultimate.sh"

# Ensure the wrapper is executable
chmod +x "$WRAPPER_PATH"

# Create symlinks in user's local bin
mkdir -p "$HOME/.local/bin"

# Create main symlink
ln -sf "$WRAPPER_PATH" "$HOME/.local/bin/claude-ultimate"
echo "✓ Created symlink: claude-ultimate"

# Create short alias
ln -sf "$WRAPPER_PATH" "$HOME/.local/bin/cu"
echo "✓ Created short alias: cu"

# Check if .local/bin is in PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo ""
    echo "⚠️  Note: $HOME/.local/bin is not in your PATH"
    echo "Add this line to your ~/.bashrc or ~/.profile:"
    echo '    export PATH="$HOME/.local/bin:$PATH"'
    echo ""
fi

# Test the installation
echo ""
echo "Testing installation..."
echo "Project root will be: $SCRIPT_DIR"
echo "Agents directory: $SCRIPT_DIR/agents"

# Count agents
AGENT_COUNT=$(find "$SCRIPT_DIR/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
echo "Found $AGENT_COUNT agent files"

echo ""
echo "Installation complete! You can now use:"
echo "  claude-ultimate --help    # Full command"
echo "  cu --help                 # Short alias"
echo "  cu --agents               # List all agents"
echo "  cu --status               # Check system status"
echo ""
echo "The wrapper will automatically find agents in:"
echo "  $SCRIPT_DIR/agents"