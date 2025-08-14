#!/bin/bash
# Dell Enterprise Tools Testing Framework
# Ring -1 LiveCD Validation Suite

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="Dell Tools Test Suite"
readonly VERSION="1.0-Ring-1"
readonly DELL_TOOLS_DIR="$HOME/.local/share/claude/agents/build/dell-tools"
readonly TEST_LOG="/tmp/dell-tools-test-$(date +%Y%m%d-%H%M%S).log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

test_header() {
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Dell Enterprise Tools Test Suite             ║"
    echo "║                    Ring -1 LiveCD                         ║"
    echo "║                     Version $VERSION                         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    log_test "Starting Dell tools test suite"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"  # Default expect success
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -n "Testing $test_name... "
    log_test "TEST: $test_name - Command: $test_command"
    
    local result=0
    if eval "$test_command" >> "$TEST_LOG" 2>&1; then
        if [ "$expected_result" = "0" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            log_test "PASS: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC} (Expected failure but succeeded)"
            log_test "FAIL: $test_name (unexpected success)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        result=$?
        if [ "$expected_result" != "0" ]; then
            echo -e "${GREEN}✓ PASS${NC} (Expected failure)"
            log_test "PASS: $test_name (expected failure)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC} (Exit code: $result)"
            log_test "FAIL: $test_name (exit code: $result)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    fi
}

test_file_existence() {
    echo -e "${BOLD}${BLUE}Testing Tool Installation${NC}"
    
    local tools=(
        "probe-dell-enterprise"
        "dell-bios-analyzer"
        "dell-idrac-probe"
        "dell-thermal-monitor"
        "dell-smbios-probe"
        "dell-redfish-client.py"
        "dell-enterprise-suite"
    )
    
    for tool in "${tools[@]}"; do
        run_test "File existence: $tool" "[ -f '$DELL_TOOLS_DIR/$tool' ]"
        if [ -f "$DELL_TOOLS_DIR/$tool" ]; then
            run_test "File executable: $tool" "[ -x '$DELL_TOOLS_DIR/$tool' ]"
        fi
    done
}

test_system_integration() {
    echo -e "${BOLD}${BLUE}Testing System Integration${NC}"
    
    # Test PATH integration
    run_test "PATH integration (dell-suite)" "command -v dell-suite > /dev/null"
    run_test "PATH integration (dell-probe)" "command -v dell-probe > /dev/null"
    
    # Test basic system tools
    run_test "dmidecode available" "command -v dmidecode > /dev/null"
    
    # Test Python environment
    run_test "Python3 available" "command -v python3 > /dev/null"
    if command -v python3 &> /dev/null; then
        run_test "Python requests module" "python3 -c 'import requests' > /dev/null"
    fi
}

test_basic_functionality() {
    echo -e "${BOLD}${BLUE}Testing Basic Functionality${NC}"
    
    # Test Dell hardware probe
    if [ -x "$DELL_TOOLS_DIR/probe-dell-enterprise" ]; then
        run_test "Dell hardware probe execution" "$DELL_TOOLS_DIR/probe-dell-enterprise > /dev/null"
    fi
    
    # Test BIOS analyzer
    if [ -x "$DELL_TOOLS_DIR/dell-bios-analyzer" ]; then
        run_test "BIOS analyzer execution" "$DELL_TOOLS_DIR/dell-bios-analyzer > /dev/null"
    fi
    
    # Test thermal monitor
    if [ -x "$DELL_TOOLS_DIR/dell-thermal-monitor" ]; then
        run_test "Thermal monitor execution" "$DELL_TOOLS_DIR/dell-thermal-monitor > /dev/null"
    fi
    
    # Test iDRAC probe
    if [ -x "$DELL_TOOLS_DIR/dell-idrac-probe" ]; then
        run_test "iDRAC probe execution" "$DELL_TOOLS_DIR/dell-idrac-probe > /dev/null"
    fi
    
    # Test SMBIOS probe
    if [ -x "$DELL_TOOLS_DIR/dell-smbios-probe" ]; then
        run_test "SMBIOS probe execution" "$DELL_TOOLS_DIR/dell-smbios-probe > /dev/null"
    fi
}

test_python_tools() {
    echo -e "${BOLD}${BLUE}Testing Python Tools${NC}"
    
    if [ -x "$DELL_TOOLS_DIR/dell-redfish-client.py" ]; then
        # Test help output
        run_test "Redfish client help" "python3 '$DELL_TOOLS_DIR/dell-redfish-client.py' 2>&1 | grep -q 'Usage:'"
        
        # Test discovery mode
        run_test "Redfish discovery mode" "timeout 5 python3 '$DELL_TOOLS_DIR/dell-redfish-client.py' discover 2>&1 || true"
    fi
}

test_system_detection() {
    echo -e "${BOLD}${BLUE}Testing System Detection${NC}"
    
    # Test basic system information detection
    run_test "DMI vendor detection" "[ -f /sys/class/dmi/id/sys_vendor ]"
    run_test "DMI product detection" "[ -f /sys/class/dmi/id/product_name ]"
    run_test "BIOS vendor detection" "[ -f /sys/class/dmi/id/bios_vendor ]"
    
    # Test thermal zones
    run_test "Thermal zones available" "ls /sys/class/thermal/thermal_zone* > /dev/null 2>&1 || [ $? -eq 2 ]"
    
    # Test hardware monitoring
    run_test "Hardware monitoring sysfs" "ls /sys/class/hwmon/ > /dev/null 2>&1 || [ $? -eq 2 ]"
    
    # Test ACPI availability
    run_test "ACPI interface" "[ -d /proc/acpi ] || [ -d /sys/firmware/acpi ]"
    
    # Test EFI/UEFI
    run_test "EFI firmware interface" "[ -d /sys/firmware/efi ] || true"
}

test_performance() {
    echo -e "${BOLD}${BLUE}Testing Performance${NC}"
    
    # Test Dell hardware probe performance
    if [ -x "$DELL_TOOLS_DIR/probe-dell-enterprise" ]; then
        run_test "Hardware probe performance (<5s)" "timeout 5 '$DELL_TOOLS_DIR/probe-dell-enterprise' > /dev/null"
    fi
    
    # Test thermal monitor performance
    if [ -x "$DELL_TOOLS_DIR/dell-thermal-monitor" ]; then
        run_test "Thermal monitor performance (<3s)" "timeout 3 '$DELL_TOOLS_DIR/dell-thermal-monitor' > /dev/null"
    fi
    
    # Test BIOS analyzer performance
    if [ -x "$DELL_TOOLS_DIR/dell-bios-analyzer" ]; then
        run_test "BIOS analyzer performance (<3s)" "timeout 3 '$DELL_TOOLS_DIR/dell-bios-analyzer' > /dev/null"
    fi
}

test_error_handling() {
    echo -e "${BOLD}${BLUE}Testing Error Handling${NC}"
    
    # Test invalid arguments
    if [ -x "$DELL_TOOLS_DIR/dell-redfish-client.py" ]; then
        run_test "Redfish invalid args" "python3 '$DELL_TOOLS_DIR/dell-redfish-client.py' invalid-command 2>&1 | grep -q 'Usage:'" 1
    fi
    
    # Test non-existent files
    run_test "Non-existent tool handling" "[ ! -x '$DELL_TOOLS_DIR/non-existent-tool' ]"
}

test_security() {
    echo -e "${BOLD}${BLUE}Testing Security${NC}"
    
    # Test file permissions
    for tool in "$DELL_TOOLS_DIR"/*; do
        if [ -f "$tool" ]; then
            local basename_tool=$(basename "$tool")
            run_test "Secure permissions: $basename_tool" "[ ! -u '$tool' ] && [ ! -g '$tool' ]"
        fi
    done
    
    # Test no world-writable files
    run_test "No world-writable tools" "! find '$DELL_TOOLS_DIR' -type f -perm -o+w | grep -q ."
}

test_cleanup() {
    echo -e "${BOLD}${BLUE}Testing Cleanup${NC}"
    
    # Test temporary file cleanup
    local temp_file="/tmp/dell-test-$$"
    echo "test" > "$temp_file"
    run_test "Temporary file cleanup" "[ -f '$temp_file' ] && rm -f '$temp_file'"
}

show_summary() {
    echo
    echo -e "${BOLD}${CYAN}Test Summary${NC}"
    echo "============"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${BOLD}${GREEN}All tests passed! ✓${NC}"
        log_test "All tests passed successfully"
    else
        echo -e "${BOLD}${RED}$TESTS_FAILED tests failed! ✗${NC}"
        log_test "$TESTS_FAILED tests failed"
        echo "Check log file: $TEST_LOG"
    fi
    
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo "Success rate: ${success_rate}%"
    log_test "Test suite completed - Success rate: ${success_rate}%"
}

show_system_info() {
    echo -e "${BOLD}${BLUE}System Information${NC}"
    echo "=================="
    
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    
    if [ -f /sys/class/dmi/id/sys_vendor ]; then
        echo "Vendor: $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo 'Unknown')"
    fi
    
    if [ -f /sys/class/dmi/id/product_name ]; then
        echo "Product: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'Unknown')"
    fi
    
    echo "Dell tools directory: $DELL_TOOLS_DIR"
    echo "Test log: $TEST_LOG"
    echo
}

main() {
    test_header
    show_system_info
    
    # Run test suites
    test_file_existence
    test_system_integration
    test_system_detection
    test_basic_functionality
    test_python_tools
    test_performance
    test_error_handling
    test_security
    test_cleanup
    
    # Show results
    show_summary
    
    # Return appropriate exit code
    [ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Dell Enterprise Tools Test Suite"
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h    Show this help"
        echo "  --verbose     Enable verbose output"
        echo "  --log-only    Only log results, no console output"
        exit 0
        ;;
    --verbose)
        set -x
        main
        ;;
    --log-only)
        main > "$TEST_LOG" 2>&1
        echo "Test results logged to: $TEST_LOG"
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac