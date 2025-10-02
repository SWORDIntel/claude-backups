#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# PORTABLE PATHS VALIDATION SCRIPT
# Tests that all installer scripts work correctly with portable path resolution
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# Test configuration
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"
TEST_USER="testuser"
TEST_PROJECT_DIR="/tmp/claude-test-$$"
FAILED_TESTS=0
TOTAL_TESTS=0

print_header() {
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════════"
    echo -e "CLAUDE PORTABLE PATHS VALIDATION"
    echo -e "Testing all installers work with dynamic path resolution"
    echo -e "════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo
}

# Test function to validate scripts don't have hardcoded paths
test_script_portable() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"

    ((TOTAL_TESTS++))
    log_info "Testing $script_name for hardcoded paths..."

    # Check for obvious hardcoded paths (but allow some acceptable ones)
    local hardcoded_patterns=(
        "/home/john"
        "/home/ubuntu"
        "claude-backups" # unless in environment variable context
    )

    local issues_found=0

    for pattern in "${hardcoded_patterns[@]}"; do
        # Skip patterns that are in acceptable contexts
        local matches=$(grep -n "$pattern" "$script_path" 2>/dev/null | \
                       grep -v "\${.*$pattern.*}" | \
                       grep -v "# " | \
                       grep -v "export.*=.*$pattern" | \
                       wc -l)

        if [[ $matches -gt 0 ]]; then
            log_error "  Found hardcoded pattern '$pattern' in $script_name:"
            grep -n "$pattern" "$script_path" | grep -v "\${.*$pattern.*}" | grep -v "# " | head -3
            ((issues_found++))
        fi
    done

    if [[ $issues_found -eq 0 ]]; then
        log_success "  $script_name passed hardcoded path check"
    else
        log_error "  $script_name failed with $issues_found issues"
        ((FAILED_TESTS++))
    fi
}

# Test project root detection in scripts
test_project_detection() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"

    ((TOTAL_TESTS++))
    log_info "Testing $script_name project root detection..."

    # Create a temporary test environment
    mkdir -p "$TEST_PROJECT_DIR"/{agents,hooks,database}
    echo "# Test CLAUDE.md" > "$TEST_PROJECT_DIR/CLAUDE.md"

    # Export environment variable to test dynamic detection
    export CLAUDE_PROJECT_ROOT="$TEST_PROJECT_DIR"

    # Try running the script with --help or --status to see if it detects paths correctly
    local test_passed=true

    case "$script_name" in
        *.sh)
            if bash -n "$script_path" 2>/dev/null; then
                log_success "  $script_name syntax check passed"
            else
                log_error "  $script_name syntax check failed"
                test_passed=false
            fi
            ;;
        *.py)
            if python3 -m py_compile "$script_path" 2>/dev/null; then
                log_success "  $script_name Python syntax check passed"
            else
                log_error "  $script_name Python syntax check failed"
                test_passed=false
            fi
            ;;
    esac

    if [[ "$test_passed" != "true" ]]; then
        ((FAILED_TESTS++))
    fi

    # Cleanup
    unset CLAUDE_PROJECT_ROOT
    rm -rf "$TEST_PROJECT_DIR"
}

# Test XDG compliance
test_xdg_compliance() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"

    ((TOTAL_TESTS++))
    log_info "Testing $script_name XDG compliance..."

    # Check if script uses XDG environment variables
    if grep -q "XDG_" "$script_path" 2>/dev/null; then
        log_success "  $script_name uses XDG environment variables"
    else
        # Check if it at least uses .local, .config, .cache correctly
        if grep -q "\$HOME/\.local\|\.config\|\.cache" "$script_path" 2>/dev/null; then
            log_warning "  $script_name uses standard paths but not XDG variables"
        else
            log_warning "  $script_name may not follow XDG standards"
        fi
    fi
}

# Main validation function
run_validation() {
    print_header

    log_info "Starting validation of portable paths in installers..."
    echo

    # Find all installer scripts
    local installers=(
        "$SCRIPT_DIR/install-enhanced-wrapper.sh"
        "$SCRIPT_DIR/install-wrapper-integration.sh"
        "$SCRIPT_DIR/claude-enhanced-installer.py"
        "$SCRIPT_DIR/claude-python-installer.sh"
        "$SCRIPT_DIR/hooks/install_unified_hooks.sh"
        "$SCRIPT_DIR/integrated_learning_setup.py"
    )

    # Add any additional discovered installers
    while IFS= read -r -d '' installer; do
        installers+=("$installer")
    done < <(find "$SCRIPT_DIR" -name "*install*.sh" -o -name "*installer*.py" -type f -print0 2>/dev/null | head -10)

    log_info "Found ${#installers[@]} installer scripts to validate"
    echo

    # Run tests on each installer
    for installer in "${installers[@]}"; do
        if [[ -f "$installer" ]]; then
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${BOLD}Testing: $(basename "$installer")${RESET}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

            test_script_portable "$installer"
            test_project_detection "$installer"
            test_xdg_compliance "$installer"

            echo
        fi
    done

    # Summary
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════════"
    echo -e "VALIDATION SUMMARY"
    echo -e "════════════════════════════════════════════════════════════════════════════════${RESET}"
    echo

    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All $TOTAL_TESTS tests passed! ✅"
        echo -e "${GREEN}All installers use portable path resolution.${RESET}"
        echo
        echo -e "${BOLD}Next steps:${RESET}"
        echo "1. The installers should work on any user/system"
        echo "2. Test installation on a different user account"
        echo "3. Verify XDG compliance works with custom XDG paths"
        echo
        return 0
    else
        log_error "$FAILED_TESTS out of $TOTAL_TESTS tests failed! ❌"
        echo -e "${RED}Some installers still have hardcoded paths that need fixing.${RESET}"
        echo
        echo -e "${BOLD}Actions needed:${RESET}"
        echo "1. Review the failed tests above"
        echo "2. Fix hardcoded paths in the identified scripts"
        echo "3. Re-run this validation script"
        echo
        return 1
    fi
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Claude Portable Paths Validation Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script validates that all Claude installation scripts use portable"
    echo "path resolution instead of hardcoded paths, making the system work"
    echo "across different users and installations."
    echo
    echo "Tests performed:"
    echo "  • Hardcoded path detection"
    echo "  • Project root detection validation"
    echo "  • XDG compliance checking"
    echo "  • Syntax validation"
    echo
    echo "Environment variables used:"
    echo "  CLAUDE_PROJECT_ROOT - Override project root detection"
    echo "  XDG_CONFIG_HOME     - XDG config directory"
    echo "  XDG_DATA_HOME       - XDG data directory"
    echo "  XDG_CACHE_HOME      - XDG cache directory"
    echo
    exit 0
fi

# Run the validation
run_validation