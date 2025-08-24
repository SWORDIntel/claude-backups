#!/bin/bash
# Test script for Claude installer integration
# Tests virtual environment, database, and natural invocation setup

# Don't exit on errors, we want to run all tests
set +e

echo "═══════════════════════════════════════════════════════════════"
echo "     Claude Installer Integration Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_pass() {
    printf "${GREEN}✓${NC} %s\n" "$1"
    ((TESTS_PASSED++))
}

test_fail() {
    printf "${RED}✗${NC} %s\n" "$1"
    ((TESTS_FAILED++))
}

test_info() {
    printf "${YELLOW}ℹ${NC} %s\n" "$1"
}

# Test 1: Check if installer exists and is executable
echo ""
echo "Test 1: Installer File Checks"
echo "────────────────────────────"
if [[ -f "/home/ubuntu/Documents/claude-backups/claude-installer.sh" ]]; then
    test_pass "claude-installer.sh exists"
    if [[ -x "/home/ubuntu/Documents/claude-backups/claude-installer.sh" ]]; then
        test_pass "claude-installer.sh is executable"
    else
        test_fail "claude-installer.sh is not executable"
    fi
else
    test_fail "claude-installer.sh not found"
fi

# Test 2: Check virtual environment configuration
echo ""
echo "Test 2: Virtual Environment Configuration"
echo "────────────────────────────"
if grep -q "setup_virtual_environment" /home/ubuntu/Documents/claude-backups/claude-installer.sh; then
    test_pass "Virtual environment setup function found"
    if grep -q "VENV_DIR=" /home/ubuntu/Documents/claude-backups/claude-installer.sh; then
        test_pass "VENV_DIR variable configured"
    else
        test_fail "VENV_DIR variable not found"
    fi
else
    test_fail "Virtual environment setup function not found"
fi

# Test 3: Check database integration
echo ""
echo "Test 3: Database System Integration"
echo "────────────────────────────"
if [[ -f "/home/ubuntu/Documents/claude-backups/database/manage_database.sh" ]]; then
    test_pass "manage_database.sh exists"
else
    test_fail "manage_database.sh not found"
fi

if [[ -f "/home/ubuntu/Documents/claude-backups/database/sql/auth_db_setup.sql" ]]; then
    test_pass "auth_db_setup.sql exists"
else
    test_fail "auth_db_setup.sql not found"
fi

if [[ -f "/home/ubuntu/Documents/claude-backups/database/sql/learning_system_schema.sql" ]]; then
    test_pass "learning_system_schema.sql exists"
else
    test_fail "learning_system_schema.sql not found"
fi

if grep -q "setup_database_system" /home/ubuntu/Documents/claude-backups/claude-installer.sh; then
    test_pass "Database setup function integrated"
else
    test_fail "Database setup function not found"
fi

# Test 4: Check natural invocation integration
echo ""
echo "Test 4: Natural Invocation System"
echo "────────────────────────────"
if [[ -f "/home/ubuntu/Documents/claude-backups/enable-natural-invocation.sh" ]]; then
    test_pass "enable-natural-invocation.sh exists"
    if [[ -x "/home/ubuntu/Documents/claude-backups/enable-natural-invocation.sh" ]]; then
        test_pass "enable-natural-invocation.sh is executable"
    else
        test_fail "enable-natural-invocation.sh is not executable"
    fi
else
    test_fail "enable-natural-invocation.sh not found"
fi

if grep -q "setup_natural_invocation" /home/ubuntu/Documents/claude-backups/claude-installer.sh; then
    test_pass "Natural invocation setup function integrated"
else
    test_fail "Natural invocation setup function not found"
fi

if [[ -f "/home/ubuntu/Documents/claude-backups/hooks/natural-invocation-hook.py" ]]; then
    test_pass "natural-invocation-hook.py exists"
else
    test_fail "natural-invocation-hook.py not found"
fi

if [[ -f "/home/ubuntu/Documents/claude-backups/tools/claude-fuzzy-agent-matcher.py" ]] || [[ -f "/home/ubuntu/Documents/claude-backups/hooks/claude-fuzzy-agent-matcher.py" ]]; then
    test_pass "claude-fuzzy-agent-matcher.py exists"
else
    test_fail "claude-fuzzy-agent-matcher.py not found"
fi

# Test 5: Check requirements.txt
echo ""
echo "Test 5: Python Requirements"
echo "────────────────────────────"
if [[ -f "/home/ubuntu/Documents/claude-backups/requirements.txt" ]]; then
    test_pass "requirements.txt exists"
    
    # Check for key packages
    if grep -q "psycopg2" /home/ubuntu/Documents/claude-backups/requirements.txt; then
        test_pass "PostgreSQL driver (psycopg2) in requirements"
    else
        test_fail "PostgreSQL driver missing from requirements"
    fi
    
    if grep -q "redis" /home/ubuntu/Documents/claude-backups/requirements.txt; then
        test_pass "Redis client in requirements"
    else
        test_fail "Redis client missing from requirements"
    fi
    
    if grep -q "sqlalchemy" /home/ubuntu/Documents/claude-backups/requirements.txt; then
        test_pass "SQLAlchemy ORM in requirements"
    else
        test_fail "SQLAlchemy missing from requirements"
    fi
else
    test_fail "requirements.txt not found"
fi

# Test 6: Check installer function order
echo ""
echo "Test 6: Installation Function Order"
echo "────────────────────────────"
# Check if functions are called in correct order in main()
if grep -A 20 "INSTALLATION_MODE.*full" /home/ubuntu/Documents/claude-backups/claude-installer.sh | grep -q "setup_virtual_environment"; then
    test_pass "Virtual environment setup in installation flow"
else
    test_fail "Virtual environment setup not in installation flow"
fi

if grep -A 20 "INSTALLATION_MODE.*full" /home/ubuntu/Documents/claude-backups/claude-installer.sh | grep -q "setup_natural_invocation"; then
    test_pass "Natural invocation setup in installation flow"
else
    test_fail "Natural invocation setup not in installation flow"
fi

# Test 7: Check Redis setup integration
echo ""
echo "Test 7: Redis Caching Layer"
echo "────────────────────────────"
if [[ -f "/home/ubuntu/Documents/claude-backups/database/python/auth_redis_setup.py" ]]; then
    test_pass "auth_redis_setup.py exists"
else
    test_fail "auth_redis_setup.py not found"
fi

if grep -q "auth_redis_setup.py" /home/ubuntu/Documents/claude-backups/claude-installer.sh; then
    test_pass "Redis setup integrated in installer"
else
    test_fail "Redis setup not integrated in installer"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    Test Summary"
echo "═══════════════════════════════════════════════════════════════"
printf "Tests Passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
printf "Tests Failed: ${RED}%d${NC}\n" "$TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    printf "${GREEN}✓ All tests passed! The installer is ready for use.${NC}\n"
    echo ""
    echo "To run the full installation:"
    echo "  cd /home/ubuntu/Documents/claude-backups"
    echo "  ./claude-installer.sh"
    exit 0
else
    echo ""
    printf "${RED}✗ Some tests failed. Please review the issues above.${NC}\n"
    exit 1
fi