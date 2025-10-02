#!/bin/bash
# Claude Virtual Environment Installer Launcher
# Comprehensive installer with PEP 668 compliance and virtual environment management

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
    echo -e "${BOLD}${CYAN}Claude Enhanced Installer v3.0 - Virtual Environment Edition${RESET}"
    echo -e "${BOLD}${CYAN}PEP 668 compliant installer with virtual environment management${RESET}"
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
PYTHON_INSTALLER="$SCRIPT_DIR/claude-enhanced-installer-venv.py"

# Check if Python installer exists
check_python_installer() {
    if [[ ! -f "$PYTHON_INSTALLER" ]]; then
        print_error "Python installer not found at: $PYTHON_INSTALLER"
        print_info "Please ensure claude-enhanced-installer-venv.py is in the same directory as this script"
        return 1
    fi

    return 0
}

# Check Python availability and version
check_python() {
    local python_cmd=""
    local min_major=3
    local min_minor=8

    # Try different Python commands
    for cmd in python3 python; do
        if command -v "$cmd" >/dev/null 2>&1; then
            # Check version
            local version_output=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
            if [[ -n "$version_output" ]]; then
                local major=$(echo "$version_output" | cut -d. -f1)
                local minor=$(echo "$version_output" | cut -d. -f2)

                if [[ "$major" -eq $min_major && "$minor" -ge $min_minor ]]; then
                    python_cmd="$cmd"
                    print_success "Found Python $version_output at $(which $cmd)" >&2
                    break
                elif [[ "$major" -gt $min_major ]]; then
                    python_cmd="$cmd"
                    print_success "Found Python $version_output at $(which $cmd)" >&2
                    break
                else
                    print_warning "Python $version_output found but requires $min_major.$min_minor+" >&2
                fi
            fi
        fi
    done

    if [[ -z "$python_cmd" ]]; then
        print_error "Python $min_major.$min_minor+ not found" >&2
        print_info "Please install Python $min_major.$min_minor or higher" >&2
        print_info "On Debian/Ubuntu: sudo apt install python3 python3-venv python3-pip" >&2
        print_info "On CentOS/RHEL: sudo yum install python3 python3-venv python3-pip" >&2
        print_info "On macOS: brew install python3" >&2
        return 1
    fi

    echo "$python_cmd"
    return 0
}

# Check for externally managed environment (PEP 668)
check_pep668() {
    local python_cmd="$1"

    print_info "Checking for PEP 668 externally-managed environment..."

    local pip_output=$("$python_cmd" -m pip install --dry-run requests 2>&1 || true)

    if echo "$pip_output" | grep -q "externally-managed-environment"; then
        print_warning "Detected PEP 668 externally-managed environment"
        print_info "This installer will use virtual environments to comply with PEP 668"
        return 0
    else
        print_info "System allows direct pip installation (non-PEP 668)"
        return 1
    fi
}

# Check virtual environment support
check_venv_support() {
    local python_cmd="$1"

    print_info "Checking virtual environment support..."

    if "$python_cmd" -c "import venv" >/dev/null 2>&1; then
        print_success "Virtual environment module available"
        return 0
    else
        print_error "Virtual environment module not available"
        print_info "On Debian/Ubuntu: sudo apt install python3-venv"
        print_info "On CentOS/RHEL: sudo yum install python3-venv"
        return 1
    fi
}

# Show help
show_help() {
    echo "Claude Enhanced Installer v3.0 - Virtual Environment Edition"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Installation modes:"
    echo "  --quick           Quick installation with minimal components"
    echo "  --full            Full installation with all components (default)"
    echo "  --custom          Custom installation - choose components"
    echo
    echo "Virtual environment options:"
    echo "  --recreate-venv   Force recreation of virtual environment"
    echo "  --venv-path PATH  Custom virtual environment path"
    echo
    echo "Options:"
    echo "  --detect-only     Only detect existing installations"
    echo "  --verbose, -v     Enable verbose output"
    echo "  --auto, -a        Auto mode - no user prompts"
    echo "  --help, -h        Show this help message"
    echo
    echo "Key features:"
    echo "  • PEP 668 compliant (handles externally-managed environments)"
    echo "  • Virtual environment management"
    echo "  • Python-INTERNAL agent support"
    echo "  • Agent orchestration system integration"
    echo "  • PICMCS v3.0 hardware-adaptive context chopping"
    echo "  • Cross-platform compatibility (Linux, macOS, WSL)"
    echo "  • Shell-specific optimizations (bash, zsh, fish)"
    echo "  • Comprehensive dependency management"
    echo
    echo "Virtual environment benefits:"
    echo "  • Isolated Python dependencies"
    echo "  • No system package conflicts"
    echo "  • Easy upgrade and maintenance"
    echo "  • Compliant with modern Python standards"
    echo
    echo "Examples:"
    echo "  $0                      # Full installation (recommended)"
    echo "  $0 --quick             # Quick installation"
    echo "  $0 --detect-only       # Just detect existing installations"
    echo "  $0 --verbose --auto    # Verbose automatic installation"
    echo "  $0 --recreate-venv     # Force virtual environment recreation"
    echo
}

# Main execution
main() {
    print_header

    # Parse arguments
    local args=()
    local show_help_flag=false
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help_flag=true
                shift
                ;;
            --check-only)
                check_only=true
                shift
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

    # Check virtual environment support
    if ! check_venv_support "$python_cmd"; then
        exit 1
    fi

    # Check PEP 668 status
    is_pep668=false
    if check_pep668 "$python_cmd"; then
        is_pep668=true
    fi

    print_success "Python installer found: $PYTHON_INSTALLER"
    print_success "Python command: $python_cmd"

    if [[ "$check_only" == "true" ]]; then
        print_info "Prerequisites check completed successfully"
        if [[ "$is_pep668" == "true" ]]; then
            print_info "System has PEP 668 externally-managed environment (virtual environment required)"
        else
            print_info "System allows direct pip installation"
        fi
        exit 0
    fi

    # Check if installer is executable
    if [[ ! -x "$PYTHON_INSTALLER" ]]; then
        print_info "Making Python installer executable..."
        chmod +x "$PYTHON_INSTALLER" 2>/dev/null || {
            print_warning "Could not make installer executable, running with python directly"
        }
    fi

    print_info "Launching Python virtual environment installer..."
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