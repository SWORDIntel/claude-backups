#!/bin/bash

# Verification script that writes output to a file
OUTPUT_FILE="installation-report.txt"

{
    echo "Claude Ultimate Wrapper v13.1 Installation Report"
    echo "================================================="
    echo "Date: $(date)"
    echo
    
    echo "1. Wrapper Script Status:"
    if [ -f "./claude-wrapper-ultimate.sh" ]; then
        echo "   ✓ Wrapper found: $(pwd)/claude-wrapper-ultimate.sh"
        echo "   Size: $(stat -c%s ./claude-wrapper-ultimate.sh 2>/dev/null || stat -f%z ./claude-wrapper-ultimate.sh 2>/dev/null) bytes"
        [ -x "./claude-wrapper-ultimate.sh" ] && echo "   ✓ Executable" || echo "   ✗ Not executable"
    else
        echo "   ✗ Wrapper not found"
    fi
    echo
    
    echo "2. Agents Directory:"
    if [ -d "./agents" ]; then
        AGENT_COUNT=$(ls -1 ./agents/*.md 2>/dev/null | wc -l)
        echo "   ✓ Found: $(pwd)/agents"
        echo "   ✓ Agent files: $AGENT_COUNT"
        echo "   Sample agents:"
        ls -1 ./agents/*.md 2>/dev/null | head -5 | while read agent; do
            echo "     - $(basename $agent)"
        done
    else
        echo "   ✗ Agents directory not found"
    fi
    echo
    
    echo "3. Symlinks:"
    WRAPPER_FULL="$(pwd)/claude-wrapper-ultimate.sh"
    
    # Create symlinks
    mkdir -p "$HOME/.local/bin"
    ln -sf "$WRAPPER_FULL" "$HOME/.local/bin/claude-ultimate" 2>/dev/null
    ln -sf "$WRAPPER_FULL" "$HOME/.local/bin/cu" 2>/dev/null
    
    [ -L "$HOME/.local/bin/claude-ultimate" ] && echo "   ✓ claude-ultimate symlink created" || echo "   ✗ Failed to create claude-ultimate"
    [ -L "$HOME/.local/bin/cu" ] && echo "   ✓ cu symlink created" || echo "   ✗ Failed to create cu"
    echo
    
    echo "4. PATH Configuration:"
    if echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo "   ✓ $HOME/.local/bin is in PATH"
    else
        echo "   ⚠ $HOME/.local/bin is NOT in PATH"
        echo "   To fix, add to ~/.bashrc:"
        echo '   export PATH="$HOME/.local/bin:$PATH"'
    fi
    echo
    
    echo "5. Commands Available:"
    echo "   claude-ultimate --help     # Show help"
    echo "   claude-ultimate --agents   # List agents"
    echo "   claude-ultimate --status   # System status"
    echo "   cu --agents               # Short alias"
    echo
    
    echo "Installation complete!"
    
} > "$OUTPUT_FILE" 2>&1

echo "Report written to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"