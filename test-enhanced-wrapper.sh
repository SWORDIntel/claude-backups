#!/bin/bash
# Test Enhanced Claude Wrapper Auto Permission Bypass
set -euo pipefail

echo "🧪 Testing Enhanced Claude Wrapper Auto Permission Bypass..."
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

WRAPPER="/home/john/.local/bin/claude-enhanced"

test_scenario() {
    local name="$1"
    local setup="$2"
    local expected="$3"

    echo -e "${CYAN}Testing: $name${NC}"

    # Setup environment
    eval "$setup"

    # Test status
    status_output=$($WRAPPER --status 2>/dev/null | grep "Permission Bypass")
    echo "  Status: $status_output"

    # Test task execution (capture stderr for bypass message)
    task_output=$($WRAPPER /task "test" 2>&1 | head -1)
    echo "  Task output: $task_output"

    # Check if expected pattern is found
    if echo "$task_output" | grep -q "$expected"; then
        echo -e "  Result: ${GREEN}✅ PASS${NC}"
    else
        echo -e "  Result: ${RED}❌ FAIL${NC} (expected: $expected)"
    fi
    echo

    # Cleanup environment
    unset SSH_CLIENT SSH_TTY CLAUDE_PERMISSION_BYPASS DISPLAY WAYLAND_DISPLAY
}

echo "=== Auto Permission Bypass Tests ==="
echo

# Test 1: Default environment
test_scenario "Default Environment" \
    "" \
    "default mode"

# Test 2: SSH environment
test_scenario "SSH Environment" \
    "export SSH_CLIENT='192.168.1.100'" \
    "SSH environment detected"

# Test 3: SSH TTY environment
test_scenario "SSH TTY Environment" \
    "export SSH_TTY='/dev/pts/0'" \
    "SSH environment detected"

# Test 4: Headless environment
test_scenario "Headless Environment" \
    "unset DISPLAY WAYLAND_DISPLAY" \
    "headless environment detected"

# Test 5: Explicitly disabled
test_scenario "Explicitly Disabled" \
    "export CLAUDE_PERMISSION_BYPASS=false" \
    "No bypass message expected"

echo "=== Test Summary ==="
echo -e "${GREEN}✅ All environment detection scenarios tested${NC}"
echo
echo "Manual tests:"
echo "  1. sudo $WRAPPER /task \"test\" # Should show bypass message"
echo "  2. CLAUDE_PERMISSION_BYPASS=false $WRAPPER /task \"test\" # Should NOT show bypass"
echo "  3. SSH_CLIENT=test $WRAPPER /task \"test\" # Should show SSH detection"
echo
echo "To install system-wide: sudo /home/john/claude-backups/install-enhanced-wrapper.sh"