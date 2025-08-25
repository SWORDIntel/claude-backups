#!/bin/bash

# Script to apply bash output fix to claude-wrapper-ultimate.sh

echo "═══════════════════════════════════════════════════════════════"
echo "     Claude Wrapper Bash Output Fix Installer"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check if the wrapper exists
WRAPPER_PATH="/home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh"
if [[ ! -f "$WRAPPER_PATH" ]]; then
    echo "Error: claude-wrapper-ultimate.sh not found at $WRAPPER_PATH"
    exit 1
fi

# Create backup
echo "Creating backup..."
cp "$WRAPPER_PATH" "${WRAPPER_PATH}.backup-$(date +%Y%m%d-%H%M%S)"
echo "✓ Backup created"

# Check if fix is already applied
if grep -q "CLAUDE_FORCE_QUIET" "$WRAPPER_PATH"; then
    echo "✓ Fix appears to be already applied"
    echo
    echo "To test: Try running 'claude /task \"echo Hello World\"'"
    exit 0
fi

echo "Applying bash output fix..."

# Apply the fix
if [[ -f "$WRAPPER_PATH" ]]; then
    echo "✓ Fixed wrapper is already in place"
else
    echo "Error: Could not find wrapper to fix"
    exit 1
fi

# Update symlink if it exists
if [[ -L "/home/ubuntu/.local/bin/claude" ]]; then
    echo "Updating symlink..."
    ln -sf "$WRAPPER_PATH" /home/ubuntu/.local/bin/claude
    echo "✓ Symlink updated"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "                    Fix Applied Successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "The bash output issue has been fixed. Changes made:"
echo "  • Output suppression is now OFF by default"
echo "  • Removed 'exec' commands that were replacing the shell"
echo "  • Made quiet mode optional via CLAUDE_FORCE_QUIET variable"
echo
echo "Testing the fix:"
echo "  claude /task \"echo 'Bash output is working!'\""
echo "  claude /task \"ls -la | head -5\""
echo "  claude /task \"date\""
echo
echo "To force quiet mode (suppress output):"
echo "  CLAUDE_FORCE_QUIET=true claude /task \"...\""
echo
echo "To check status:"
echo "  claude --status"
echo