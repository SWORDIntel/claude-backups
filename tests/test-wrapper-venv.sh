#!/bin/bash
# Test script for Claude wrapper virtual environment activation

echo "═══════════════════════════════════════════════════════════════"
echo "     Claude Wrapper Virtual Environment Test"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Test wrapper status
echo "Testing wrapper status command..."
echo "────────────────────────────"
/home/ubuntu/Documents/claude-backups/claude-wrapper-ultimate.sh --status

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Test Environment Variables:"
echo "────────────────────────────"
echo "CLAUDE_VENV: ${CLAUDE_VENV:-not set}"
echo "VIRTUAL_ENV: ${VIRTUAL_ENV:-not set}"
echo "CLAUDE_VENV_ACTIVATED: ${CLAUDE_VENV_ACTIVATED:-not set}"
echo "CLAUDE_VENV_PATH: ${CLAUDE_VENV_PATH:-not set}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Python Environment:"
echo "────────────────────────────"
echo "Python3: $(which python3 2>/dev/null || echo 'not found')"
echo "Pip3: $(which pip3 2>/dev/null || echo 'not found')"
echo "Python version: $(python3 --version 2>/dev/null || echo 'not available')"

# Check if venv directory exists
VENV_DIR="$HOME/.local/share/claude/venv"
echo ""
echo "Virtual Environment Directory Check:"
echo "────────────────────────────"
if [[ -d "$VENV_DIR" ]]; then
    printf "${GREEN}✓${NC} Virtual environment directory exists: %s\n" "$VENV_DIR"
    if [[ -f "$VENV_DIR/bin/activate" ]]; then
        printf "${GREEN}✓${NC} Activation script found\n"
    else
        printf "${RED}✗${NC} Activation script not found\n"
    fi
    if [[ -f "$VENV_DIR/bin/python3" ]]; then
        printf "${GREEN}✓${NC} Python binary found in venv\n"
    else
        printf "${RED}✗${NC} Python binary not found in venv\n"
    fi
else
    printf "${YELLOW}⚠${NC} Virtual environment not found at: %s\n" "$VENV_DIR"
    echo "  Run the installer first to create the virtual environment:"
    echo "  ./claude-installer.sh"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Debug Mode Test (shows venv activation):"
echo "────────────────────────────"
echo "Running wrapper in debug mode..."
CLAUDE_DEBUG=true /home/ubuntu/Documents/claude-backups/claude-wrapper-ultimate.sh --help 2>&1 | grep -E "\[DEBUG\].*venv|Virtual environment" | head -10

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Summary:"
echo "────────────────────────────"
if [[ -d "$VENV_DIR" ]]; then
    printf "${GREEN}✓${NC} Virtual environment directory exists\n"
    echo "  The wrapper should automatically activate it when run"
else
    printf "${YELLOW}⚠${NC} Virtual environment not yet created\n"
    echo "  Run ./claude-installer.sh to set up the virtual environment"
fi

echo ""
echo "To manually test venv activation in the wrapper:"
echo "  CLAUDE_DEBUG=true ./claude-wrapper-ultimate.sh --status"
echo ""
echo "The wrapper will automatically activate the venv if it exists at:"
echo "  - \$CLAUDE_VENV (if set)"
echo "  - \$HOME/.local/share/claude/venv"
echo "  - \$HOME/Documents/claude-backups/venv"
echo "  - \$HOME/Documents/Claude/venv"
echo "  - \$HOME/.claude-venv"