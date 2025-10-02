#!/bin/bash
# Docker Learning Integration Validation Script
# Comprehensive testing and validation of the learning system

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${CYAN}Test $TESTS_TOTAL: $test_name${RESET}"

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to run a test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${CYAN}Test $TESTS_TOTAL: $test_name${RESET}"

    local output
    if output=$(eval "$test_command" 2>&1); then
        echo -e "${GREEN}✅ PASS${RESET}"
        if [[ -n "$output" ]]; then
            echo -e "${BLUE}   Output: $output${RESET}"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${RESET}"
        if [[ -n "$output" ]]; then
            echo -e "${RED}   Error: $output${RESET}"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo -e "${BOLD}${CYAN}Docker Learning Integration Validation${RESET}"
echo "========================================"
echo

# Test 1: Configuration files exist
echo -e "${BOLD}Configuration Tests${RESET}"
run_test "Learning config exists" "test -f $HOME/.config/claude/learning_config.json"
run_test "Environment config exists" "test -f $HOME/.config/claude/.env"
run_test "Startup script exists" "test -x $HOME/.config/claude/start_learning_system.sh"
run_test "Systemd service exists" "test -f $HOME/.config/systemd/user/claude-learning.service"
run_test "Shell integration exists" "test -f $HOME/.config/claude/shell_integration.sh"

echo

# Test 2: Docker system tests
echo -e "${BOLD}Docker System Tests${RESET}"
run_test "Docker command available" "command -v docker"
run_test "Docker daemon running" "systemctl is-active --quiet docker"

# Check Docker permissions
if run_test "Docker permissions" "docker ps"; then
    echo -e "${GREEN}   Docker access working without sudo${RESET}"
else
    echo -e "${YELLOW}   Docker permissions need fixing. Run: sudo usermod -aG docker \$USER${RESET}"
fi

echo

# Test 3: Environment configuration
echo -e "${BOLD}Environment Configuration Tests${RESET}"
if [[ -f "$HOME/.config/claude/.env" ]]; then
    source "$HOME/.config/claude/.env"

    run_test_with_output "LEARNING_DOCKER_AUTO_START set" "echo \${LEARNING_DOCKER_AUTO_START:-not_set}"
    run_test_with_output "LEARNING_SYSTEM_ENABLED set" "echo \${LEARNING_SYSTEM_ENABLED:-not_set}"
    run_test_with_output "NPU_ACCELERATION_ENABLED set" "echo \${NPU_ACCELERATION_ENABLED:-not_set}"
fi

echo

# Test 4: Project structure tests
echo -e "${BOLD}Project Structure Tests${RESET}"

# Find project root
PROJECT_ROOT=""
for possible_root in \
    "$HOME/claude-backups" \
    "$HOME/Documents/Claude" \
    "$(pwd)"; do

    if [[ -f "$possible_root/database/docker/docker-compose.yml" ]]; then
        PROJECT_ROOT="$possible_root"
        break
    fi
done

if [[ -n "$PROJECT_ROOT" ]]; then
    echo -e "${GREEN}✅ Project root found: $PROJECT_ROOT${RESET}"

    run_test "Docker compose file exists" "test -f $PROJECT_ROOT/database/docker/docker-compose.yml"
    run_test "NPU orchestrator exists" "test -f $PROJECT_ROOT/agents/src/python/npu_optimized_final.py"
    run_test "NPU installer exists" "test -f $PROJECT_ROOT/npu_installer_integration.py"
    run_test "Database directory exists" "test -d $PROJECT_ROOT/database"
else
    echo -e "${RED}❌ Project root not found${RESET}"
    TESTS_TOTAL=$((TESTS_TOTAL + 4))
    TESTS_FAILED=$((TESTS_FAILED + 4))
fi

echo

# Test 5: Systemd service tests
echo -e "${BOLD}Systemd Service Tests${RESET}"
run_test "Systemd user daemon running" "systemctl --user is-active --quiet"
run_test "Claude learning service enabled" "systemctl --user is-enabled --quiet claude-learning.service"

echo

# Test 6: NPU integration tests
echo -e "${BOLD}NPU Integration Tests${RESET}"
run_test "NPU launcher exists" "test -x $HOME/.local/bin/claude-npu"
run_test "NPU test script exists" "test -x $HOME/.local/bin/claude-npu-test"

# Test NPU virtual environment
if [[ -n "$PROJECT_ROOT" ]]; then
    NPU_VENV="$PROJECT_ROOT/agents/src/python/.venv"
    if [[ -d "$NPU_VENV" ]]; then
        run_test "NPU virtual environment exists" "test -f $NPU_VENV/bin/python"
        run_test_with_output "OpenVINO in NPU venv" "$NPU_VENV/bin/python -c 'import openvino; print(openvino.__version__)'"
    else
        echo -e "${YELLOW}⚠️  NPU virtual environment not found at $NPU_VENV${RESET}"
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        TESTS_FAILED=$((TESTS_FAILED + 2))
    fi
fi

echo

# Test 7: Integration functionality
echo -e "${BOLD}Integration Functionality Tests${RESET}"

# Test if we can start the learning system (dry run)
if [[ -n "$PROJECT_ROOT" ]] && docker ps >/dev/null 2>&1; then
    echo -e "${CYAN}Test: Learning system startup (dry run)${RESET}"

    # Check if containers are already running
    if docker ps | grep -q claude-postgres; then
        echo -e "${GREEN}✅ Learning database already running${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  Learning database not running - try starting with:${RESET}"
        echo -e "${CYAN}   $HOME/.config/claude/start_learning_system.sh${RESET}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

# Test shell integration
if [[ -f "$HOME/.config/claude/shell_integration.sh" ]]; then
    run_test "Shell integration loadable" "source $HOME/.config/claude/shell_integration.sh"
fi

echo

# Summary
echo -e "${BOLD}Validation Summary${RESET}"
echo "=================="
echo -e "Total tests: ${BOLD}$TESTS_TOTAL${RESET}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${RESET}"
echo -e "Failed: ${RED}$TESTS_FAILED${RESET}"

SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
echo -e "Success rate: ${BOLD}$SUCCESS_RATE%${RESET}"

echo

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}🎉 All tests passed! Docker learning integration is fully configured.${RESET}"
    echo
    echo -e "${CYAN}Quick commands:${RESET}"
    echo "  • Start learning system: claude-learning-start"
    echo "  • Check system status: claude-learning-status"
    echo "  • View system health: claude-learning-health"
    echo "  • Connect to database: claude-learning-connect"
    echo "  • Test NPU system: claude-npu-test"
    echo "  • Launch NPU orchestrator: claude-npu"
elif [[ $SUCCESS_RATE -ge 80 ]]; then
    echo -e "${BOLD}${YELLOW}⚠️  Most tests passed ($SUCCESS_RATE%), but some issues need attention.${RESET}"
    echo
    echo -e "${CYAN}Common fixes:${RESET}"
    echo "  • Docker permissions: sudo usermod -aG docker \$USER && newgrp docker"
    echo "  • Start learning system: $HOME/.config/claude/start_learning_system.sh"
    echo "  • Add shell integration: echo 'source $HOME/.config/claude/shell_integration.sh' >> ~/.bashrc"
else
    echo -e "${BOLD}${RED}❌ Significant issues detected ($SUCCESS_RATE% success rate).${RESET}"
    echo
    echo -e "${CYAN}Recommended actions:${RESET}"
    echo "  1. Fix Docker permissions first"
    echo "  2. Re-run configuration script"
    echo "  3. Check project structure"
    echo "  4. Validate all configuration files"
fi

echo
echo -e "${CYAN}For detailed troubleshooting, check:${RESET}"
echo "  • Docker logs: docker logs claude-postgres"
echo "  • Systemd service: systemctl --user status claude-learning.service"
echo "  • Configuration: cat $HOME/.config/claude/learning_config.json"

exit $TESTS_FAILED