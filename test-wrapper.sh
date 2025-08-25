#!/bin/bash

echo "Testing Claude Ultimate Wrapper v13.1"
echo "======================================"
echo

# Test 1: Check if wrapper exists
if [ -f "./claude-wrapper-ultimate.sh" ]; then
    echo "✓ Wrapper script found"
else
    echo "✗ Wrapper script not found"
    exit 1
fi

# Test 2: Check if it's executable
if [ -x "./claude-wrapper-ultimate.sh" ]; then
    echo "✓ Wrapper is executable"
else
    echo "✗ Wrapper is not executable"
    chmod +x ./claude-wrapper-ultimate.sh
    echo "  Fixed: Made wrapper executable"
fi

# Test 3: Check agents directory
if [ -d "./agents" ]; then
    AGENT_COUNT=$(ls -1 ./agents/*.md 2>/dev/null | wc -l)
    echo "✓ Agents directory found with $AGENT_COUNT agents"
else
    echo "✗ Agents directory not found"
fi

# Test 4: Create symlinks
echo
echo "Creating symlinks for global access..."
mkdir -p "$HOME/.local/bin"

ln -sf "$(pwd)/claude-wrapper-ultimate.sh" "$HOME/.local/bin/claude-ultimate"
if [ -L "$HOME/.local/bin/claude-ultimate" ]; then
    echo "✓ Created symlink: claude-ultimate"
else
    echo "✗ Failed to create claude-ultimate symlink"
fi

ln -sf "$(pwd)/claude-wrapper-ultimate.sh" "$HOME/.local/bin/cu"
if [ -L "$HOME/.local/bin/cu" ]; then
    echo "✓ Created symlink: cu"
else
    echo "✗ Failed to create cu symlink"
fi

# Test 5: Check PATH
echo
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "✓ $HOME/.local/bin is in PATH"
else
    echo "⚠ $HOME/.local/bin is NOT in PATH"
    echo "  Add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo
echo "Setup complete! The wrapper will look for agents in:"
echo "  $(pwd)/agents"
echo
echo "Usage:"
echo "  claude-ultimate --help"
echo "  cu --agents"
echo "  cu --status"