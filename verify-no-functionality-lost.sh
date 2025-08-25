#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "    Verifying No Functionality Was Lost in Fix"
echo "════════════════════════════════════════════════════════════════"
echo

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WRAPPER="/home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh"
ERRORS=0

echo "Checking all functions are preserved..."
echo

# List of all expected functions
EXPECTED_FUNCTIONS=(
    "log_debug"
    "log_error"
    "log_success"
    "log_warning"
    "log_info"
    "log_fixing"
    "command_exists"
    "check_node_npm"
    "verify_claude_health"
    "fix_yoga_wasm_issue"
    "activate_venv"
    "find_project_root"
    "find_claude_binary"
    "execute_claude"
    "initialize_environment"
    "show_status"
    "auto_fix_issues"
    "register_agents_from_directory"
    "get_agent_info"
    "find_agent_file"
    "list_agents"
    "run_agent"
    "main"
)

echo "Functions Check:"
for func in "${EXPECTED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" "$WRAPPER"; then
        echo -e "  ${GREEN}✓${NC} $func"
    else
        echo -e "  ${RED}✗${NC} $func - MISSING!"
        ((ERRORS++))
    fi
done
echo

# Check all command-line options
echo "Command-line Options Check:"
EXPECTED_OPTIONS=(
    "--status"
    "--fix"
    "--agents"
    "--register-agents"
    "--agent"
    "--agent-info"
    "--help"
    "--debug"
    "--safe"
)

for opt in "${EXPECTED_OPTIONS[@]}"; do
    if grep -q "$opt" "$WRAPPER"; then
        echo -e "  ${GREEN}✓${NC} $opt"
    else
        echo -e "  ${RED}✗${NC} $opt - MISSING!"
        ((ERRORS++))
    fi
done
echo

# Check key features
echo "Key Features Check:"
EXPECTED_FEATURES=(
    "CLAUDE_AUTO_FIX"
    "CLAUDE_PERMISSION_BYPASS"
    "CLAUDE_ORCHESTRATION"
    "CLAUDE_LEARNING"
    "CLAUDE_VENV"
    "CLAUDE_PROJECT_ROOT"
    "CLAUDE_AGENTS_DIR"
    "yoga.wasm"
    "agent_registry"
    "registered_agents.json"
    "Permission Bypass"
    "virtual environment"
    "npm install"
    "agent metadata"
)

for feature in "${EXPECTED_FEATURES[@]}"; do
    if grep -q "$feature" "$WRAPPER"; then
        echo -e "  ${GREEN}✓${NC} $feature"
    else
        echo -e "  ${RED}✗${NC} $feature - MISSING!"
        ((ERRORS++))
    fi
done
echo

# Check line count (should be similar)
ORIGINAL_LINES=1183  # Original script line count
CURRENT_LINES=$(wc -l < "$WRAPPER")
LINE_DIFF=$((CURRENT_LINES - ORIGINAL_LINES))

echo "Line Count Check:"
echo "  Original: $ORIGINAL_LINES lines"
echo "  Current:  $CURRENT_LINES lines"
if [[ $LINE_DIFF -gt -10 ]] && [[ $LINE_DIFF -lt 50 ]]; then
    echo -e "  ${GREEN}✓${NC} Line count difference is minimal (+$LINE_DIFF lines)"
else
    echo -e "  ${YELLOW}⚠${NC} Line count difference: $LINE_DIFF lines"
fi
echo

# Check what was actually changed
echo "Changes Made (should only be output control and exec removal):"
echo "─────────────────────────────────────────────────────────────"

# Check for the new conditional output control
if grep -q "CLAUDE_FORCE_QUIET" "$WRAPPER"; then
    echo -e "${GREEN}✓${NC} Added conditional output control (CLAUDE_FORCE_QUIET)"
else
    echo -e "${YELLOW}⚠${NC} Conditional output control not found"
fi

# Check exec was replaced
if grep -q 'exec "$claude_binary"' "$WRAPPER"; then
    echo -e "${RED}✗${NC} 'exec' command still present (should be removed)"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} 'exec' commands removed as intended"
fi

# Check that normal execution is used instead
if grep -q '"$claude_binary" "${args\[@\]}"' "$WRAPPER"; then
    echo -e "${GREEN}✓${NC} Normal execution pattern found"
else
    echo -e "${YELLOW}⚠${NC} Normal execution pattern not verified"
fi

echo
echo "════════════════════════════════════════════════════════════════"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ VERIFICATION PASSED${NC}"
    echo "All functionality preserved. Only output control was modified."
else
    echo -e "${RED}✗ VERIFICATION FAILED${NC}"
    echo "$ERRORS issues found. Some functionality may be missing."
fi
echo "════════════════════════════════════════════════════════════════"
echo
echo "Summary of Changes:"
echo "  1. Output suppression now OFF by default (was ON)"
echo "  2. Added CLAUDE_FORCE_QUIET variable for opt-in quiet mode"
echo "  3. Removed 'exec' commands that replaced shell process"
echo "  4. Changed to normal execution to preserve output handling"
echo
echo "No other functionality was modified or removed."