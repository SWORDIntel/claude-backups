#!/bin/bash
# Claude Python Installer Launcher
# Simple shell wrapper for the Python-based installer

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Print functions
print_header() {
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}Claude Enhanced Installer v2.0 - Python Edition${RESET}"
    echo -e "${BOLD}${CYAN}Robust installer with advanced error handling and shell compatibility${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${RESET}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_INSTALLER="$SCRIPT_DIR/claude-enhanced-installer.py"
CONFIG_MODULE="$SCRIPT_DIR/claude_installer_config.py"
SHELL_MODULE="$SCRIPT_DIR/claude_shell_integration.py"

# Check if Python installer exists
check_python_installer() {
    if [[ ! -f "$PYTHON_INSTALLER" ]]; then
        print_error "Python installer not found at: $PYTHON_INSTALLER"
        print_info "Please ensure claude-enhanced-installer.py is in the same directory as this script"
        return 1
    fi

    if [[ ! -f "$CONFIG_MODULE" ]]; then
        print_warning "Configuration module not found at: $CONFIG_MODULE"
        print_info "Some advanced features may not be available"
    fi

    if [[ ! -f "$SHELL_MODULE" ]]; then
        print_warning "Shell integration module not found at: $SHELL_MODULE"
        print_info "Shell-specific optimizations may not be available"
    fi

    return 0
}

# Check Python availability
check_python() {
    local python_cmd=""

    # Try different Python commands
    for cmd in python3 python; do
        if command -v "$cmd" >/dev/null 2>&1; then
            # Check version
            local version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            if [[ -n "$version" ]]; then
                local major=$(echo "$version" | cut -d. -f1)
                local minor=$(echo "$version" | cut -d. -f2)

                if [[ "$major" -eq 3 && "$minor" -ge 8 ]]; then
                    python_cmd="$cmd"
                    break
                fi
            fi
        fi
    done

    if [[ -z "$python_cmd" ]]; then
        print_error "Python 3.8+ not found"
        print_info "Please install Python 3.8 or higher"
        return 1
    fi

    echo "$python_cmd"
    return 0
}

# Show help
show_help() {
    echo "Claude Enhanced Installer v2.0 - Python Edition"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Installation modes:"
    echo "  --quick           Quick installation with minimal components"
    echo "  --full            Full installation with all components (default)"
    echo "  --custom          Custom installation - choose components"
    echo
    echo "Upgrade options:"
    echo "  --upgrade         Upgrade all components"
    echo "  --upgrade-module  Upgrade specific module (claude-code, python-installer, etc.)"
    echo
    echo "Options:"
    echo "  --detect-only     Only detect existing installations"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --auto, -a        Auto mode - no user prompts"
    echo "  --help, -h        Show this help message"
    echo
    echo "Python installer features:"
    echo "  • Robust error handling and recovery"
    echo "  • Cross-platform compatibility (Linux, macOS, WSL)"
    echo "  • Shell-specific optimizations (bash, zsh, fish)"
    echo "  • Recursion-proof wrapper generation"
    echo "  • Comprehensive dependency detection"
    echo "  • Advanced validation and testing"
    echo
    echo "Examples:"
    echo "  $0                    # Full installation (recommended)"
    echo "  $0 --quick           # Quick installation"
    echo "  $0 --detect-only     # Just detect existing installations"
    echo "  $0 --verbose --auto  # Verbose automatic installation"
    echo "  $0 --upgrade         # Upgrade all components"
    echo "  $0 --upgrade-module claude-code  # Upgrade only Claude Code"
    echo
}

# Main execution
main() {
    print_header

    # Parse arguments
    local args=()
    local show_help_flag=false
    local upgrade_mode=""
    local upgrade_module=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help_flag=true
                shift
                ;;
            --upgrade)
                upgrade_mode="all"
                shift
                ;;
            --upgrade-module)
                upgrade_mode="module"
                upgrade_module="$2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$show_help_flag" == "true" ]]; then
        show_help
        exit 0
    fi

    # Check prerequisites
    print_info "Checking prerequisites..."

    if ! check_python_installer; then
        exit 1
    fi

    python_cmd=$(check_python)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    print_success "Python installer found: $PYTHON_INSTALLER"
    print_success "Python command: $python_cmd"

    # Check if installer is executable
    if [[ ! -x "$PYTHON_INSTALLER" ]]; then
        print_info "Making Python installer executable..."
        chmod +x "$PYTHON_INSTALLER" 2>/dev/null || {
            print_warning "Could not make installer executable, running with python directly"
        }
    fi

    # Handle upgrade mode
    if [[ -n "$upgrade_mode" ]]; then
        print_info "Launching upgrade system..."
        UPGRADE_SCRIPT="$SCRIPT_DIR/upgrade-to-python-installer.py"

        if [[ ! -f "$UPGRADE_SCRIPT" ]]; then
            print_error "Upgrade script not found at: $UPGRADE_SCRIPT"
            exit 1
        fi

        if [[ "$upgrade_mode" == "all" ]]; then
            exec "$python_cmd" "$UPGRADE_SCRIPT" --upgrade-all "${args[@]}"
        else
            exec "$python_cmd" "$UPGRADE_SCRIPT" --upgrade "$upgrade_module" "${args[@]}"
        fi
    fi

    print_info "Launching Python installer..."
    echo

    # Launch Python installer
    if [[ -x "$PYTHON_INSTALLER" ]]; then
        # Run directly if executable
        exec "$PYTHON_INSTALLER" "${args[@]}"
    else
        # Run with Python
        exec "$python_cmd" "$PYTHON_INSTALLER" "${args[@]}"
    fi
}

# Handle interrupts gracefully
trap 'print_warning "Installation interrupted by user"; exit 130' INT TERM

# Run main function
main "$@"