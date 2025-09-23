#!/bin/bash
# Claude Artifact Downloader GUI Launcher
# ========================================
#
# Launches the comprehensive Claude Artifact Downloader GUI with proper
# environment setup and dependency checking.
#
# Usage: ./launch_artifact_downloader.sh [OPTIONS]
#
# Options:
#   --help, -h     Show this help message
#   --debug, -d    Enable debug mode
#   --version, -v  Show version information

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
GUI_SCRIPT="$SCRIPT_DIR/claude_artifact_downloader_gui.py"
PYTHON_CMD="python3"
DEBUG_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    echo "Claude Artifact Downloader GUI Launcher"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --debug, -d    Enable debug mode"
    echo "  --version, -v  Show version information"
    echo ""
    echo "Description:"
    echo "  Launches the comprehensive Claude Artifact Downloader GUI with:"
    echo "  - Tabbed interface for organized workflow"
    echo "  - Download configuration and management"
    echo "  - Progress tracking and logging"
    echo "  - File preview and validation"
    echo "  - Batch operations support"
    echo "  - Integration with PYTHON-INTERNAL and DEBUGGER agents"
    echo ""
    echo "Requirements:"
    echo "  - Python 3.7+"
    echo "  - tkinter (usually included with Python)"
    echo "  - Optional: requests, Pillow, markdown"
}

# Show version
show_version() {
    echo "Claude Artifact Downloader GUI v1.0"
    echo "Part of Claude Code Framework v8.0"
    echo "Python: $($PYTHON_CMD --version 2>&1)"
    echo "Tkinter: $(python3 -c "import tkinter; print('Available')" 2>/dev/null || echo 'Not Available')"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --debug|-d)
                DEBUG_MODE=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Check Python environment
check_python_environment() {
    log_info "Checking Python environment..."

    # Check Python version
    if ! command -v $PYTHON_CMD &> /dev/null; then
        log_error "Python 3 not found. Please install Python 3.7 or later."
        exit 1
    fi

    # Check Python version
    python_version=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Python version: $python_version"

    # Check minimum version (3.7)
    if ! $PYTHON_CMD -c "import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)"; then
        log_error "Python 3.7 or later required. Found: $python_version"
        exit 1
    fi

    # Check tkinter
    if ! $PYTHON_CMD -c "import tkinter" 2>/dev/null; then
        log_error "tkinter not available. Please install tkinter:"
        echo "  Ubuntu/Debian: sudo apt-get install python3-tk"
        echo "  CentOS/RHEL: sudo yum install tkinter"
        echo "  macOS: tkinter should be included with Python"
        exit 1
    fi

    log_success "Python environment OK"
}

# Check optional dependencies
check_optional_dependencies() {
    log_info "Checking optional dependencies..."

    local missing_deps=()

    # Check requests
    if ! $PYTHON_CMD -c "import requests" 2>/dev/null; then
        missing_deps+=("requests")
    fi

    # Check Pillow
    if ! $PYTHON_CMD -c "import PIL" 2>/dev/null; then
        missing_deps+=("Pillow")
    fi

    # Check markdown
    if ! $PYTHON_CMD -c "import markdown" 2>/dev/null; then
        missing_deps+=("markdown")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Optional dependencies missing: ${missing_deps[*]}"
        log_info "Some features may be limited. To install:"
        echo "  pip install ${missing_deps[*]}"
        echo ""

        # Ask user if they want to continue
        if [[ -t 0 ]]; then  # Check if interactive
            read -p "Continue without optional dependencies? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled by user"
                exit 0
            fi
        fi
    else
        log_success "All optional dependencies available"
    fi
}

# Verify GUI script exists
verify_gui_script() {
    log_info "Verifying GUI script..."

    if [[ ! -f "$GUI_SCRIPT" ]]; then
        log_error "GUI script not found: $GUI_SCRIPT"
        log_info "Expected location: $GUI_SCRIPT"
        log_info "Current directory: $(pwd)"
        exit 1
    fi

    if [[ ! -r "$GUI_SCRIPT" ]]; then
        log_error "GUI script not readable: $GUI_SCRIPT"
        exit 1
    fi

    log_success "GUI script found and accessible"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."

    # Set PYTHONPATH to include project directories
    export PYTHONPATH="$PROJECT_ROOT:$PROJECT_ROOT/agents/src/python:${PYTHONPATH:-}"

    # Set display for GUI
    if [[ -z "${DISPLAY:-}" ]] && [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
        export DISPLAY=":0"
        log_info "Set DISPLAY=:0 for GUI"
    fi

    # Debug mode environment
    if [[ "$DEBUG_MODE" == "true" ]]; then
        export PYTHONPATH="$PYTHONPATH"
        export CLAUDE_DEBUG="1"
        log_info "Debug mode enabled"
        log_info "PYTHONPATH: $PYTHONPATH"
        log_info "PROJECT_ROOT: $PROJECT_ROOT"
    fi

    log_success "Environment configured"
}

# Launch GUI
launch_gui() {
    log_info "Launching Claude Artifact Downloader GUI..."

    # Change to project root for relative imports
    cd "$PROJECT_ROOT"

    # Launch GUI
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_info "Command: $PYTHON_CMD $GUI_SCRIPT"
        log_info "Working directory: $(pwd)"
    fi

    # Execute GUI with proper error handling
    if ! $PYTHON_CMD "$GUI_SCRIPT"; then
        log_error "GUI failed to start"
        log_info "Check the following:"
        echo "  1. Python environment is correctly set up"
        echo "  2. Required dependencies are installed"
        echo "  3. Display server is available (for GUI)"
        echo "  4. File permissions are correct"

        if [[ "$DEBUG_MODE" == "true" ]]; then
            echo ""
            echo "Debug information:"
            echo "  Python: $($PYTHON_CMD --version)"
            echo "  Script: $GUI_SCRIPT"
            echo "  PWD: $(pwd)"
            echo "  PYTHONPATH: ${PYTHONPATH:-}"
            echo "  DISPLAY: ${DISPLAY:-}"
        fi

        exit 1
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "GUI closed successfully"
    else
        log_warning "GUI closed with exit code: $exit_code"
    fi
}

# Signal handlers
trap cleanup EXIT

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"

    log_info "Claude Artifact Downloader GUI Launcher v1.0"
    log_info "Project root: $PROJECT_ROOT"

    # Verification steps
    check_python_environment
    verify_gui_script
    check_optional_dependencies
    setup_environment

    # Launch application
    launch_gui
}

# Run main function with all arguments
main "$@"