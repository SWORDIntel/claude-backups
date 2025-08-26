#!/bin/bash
# Universal Documentation Browser Launcher with Virtual Environment Management
# Modular documentation browser that adapts to any documentation structure

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
VENV_DIR="$PROJECT_ROOT/venv"
BROWSER_SCRIPT="$PROJECT_ROOT/docs/universal_docs_browser_enhanced.py"

# Default target directory
TARGET_DIR=""

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Enhanced banner
show_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Universal Documentation Browser Launcher               ║${NC}"
    echo -e "${CYAN}║                   Enhanced with PDF Extraction                  ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  🌐  Adapts to any documentation structure                     ║${NC}"
    echo -e "${CYAN}║  📄  PDF text extraction with pdfplumber                       ║${NC}"
    echo -e "${CYAN}║  🔍  Advanced search across all file types                     ║${NC}"
    echo -e "${CYAN}║  👥  Auto-generated role-based quick access                    ║${NC}"
    echo -e "${CYAN}║  🖥️   Professional PyGUI with caching support                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Parse command line arguments first
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --setup-only)
                SETUP_ONLY=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --clean)
                CLEAN_ENV=true
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --test-all)
                test_all_structures
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # This should be a directory path
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS] [DIRECTORY]"
    echo
    echo "Launch the Universal Documentation Browser with virtual environment support"
    echo
    echo "ARGUMENTS:"
    echo "  DIRECTORY              Documentation directory to browse (optional)"
    echo "                        If not specified, will auto-detect from common locations"
    echo
    echo "OPTIONS:"
    echo "  -h, --help            Show this help message"
    echo "  --setup-only          Only setup virtual environment and dependencies"
    echo "  --skip-deps           Skip dependency installation (use existing environment)"
    echo "  --verify-only         Only verify setup, don't launch browser"
    echo "  --clean               Clean virtual environment and reinstall"
    echo "  --status              Show system and environment status"
    echo "  --test-all            Test browser with multiple documentation structures"
    echo
    echo "EXAMPLES:"
    echo "  $0                                                    # Auto-detect and launch"
    echo "  $0 /path/to/docs                                     # Launch with specific directory"
    echo "  $0 /home/ubuntu/Documents/ARTICBASTION/docs          # Test complex structure"
    echo "  $0 /home/ubuntu/Documents/livecd-gen/docs            # Test another structure"
    echo "  $0 --setup-only                                      # Setup environment only"
    echo "  $0 --status                                          # Show status information"
    echo "  $0 --test-all                                        # Test all available structures"
    echo
    echo "SUPPORTED STRUCTURES:"
    echo "  • Claude Agent Framework (guides, reference, architecture, etc.)"
    echo "  • ARTICBASTION (api, security, technical, roadmaps, etc.)"
    echo "  • LiveCD Generator (architecture, development, guides, etc.)"
    echo "  • Any documentation folder with .md, .pdf, .txt, .html files"
    echo
}

# Test all available documentation structures
test_all_structures() {
    show_banner
    log "Testing Universal Documentation Browser with multiple structures..."
    echo
    
    # Test directories
    test_dirs=(
        "/home/ubuntu/Documents/claude-backups/docs"
        "/home/ubuntu/Documents/ARTICBASTION/docs" 
        "/home/ubuntu/Documents/livecd-gen/docs"
    )
    
    for test_dir in "${test_dirs[@]}"; do
        if [[ -d "$test_dir" ]]; then
            info "Testing structure: $test_dir"
            
            # Analyze structure without launching GUI
            if python3 "$BROWSER_SCRIPT" "$test_dir" --analyze-only 2>/dev/null; then
                success "✓ Structure analysis successful: $(basename $(dirname $test_dir))/$(basename $test_dir)"
            else
                warning "✗ Structure analysis failed: $test_dir"
            fi
        else
            warning "Directory not found: $test_dir"
        fi
    done
    
    echo
    log "Structure testing complete. Use '$0 [directory]' to launch browser."
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        error "Python 3 not found. Please install Python 3.6 or higher."
        echo "  Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv python3-tk"
        echo "  RHEL/CentOS: sudo yum install python3 python3-pip python3-tkinter"
        exit 1
    fi
    
    local python_version
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log "Python version: $python_version"
    
    # Check minimum Python version (3.6+)
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 6) else 1)" 2>/dev/null; then
        error "Python 3.6+ required. Found: $python_version"
        exit 1
    fi
    
    # Check tkinter availability
    if ! python3 -c "import tkinter" 2>/dev/null; then
        error "tkinter not available. Please install python3-tk:"
        echo "  Ubuntu/Debian: sudo apt install python3-tk"
        echo "  RHEL/CentOS: sudo yum install tkinter" 
        echo "  macOS: tkinter should be included with Python"
        exit 1
    fi
    
    # Check browser script
    if [[ ! -f "$BROWSER_SCRIPT" ]]; then
        error "Universal documentation browser script not found: $BROWSER_SCRIPT"
        exit 1
    fi
    
    success "System requirements verified"
}

# Setup virtual environment
setup_venv() {
    log "Setting up virtual environment..."
    
    if [[ ! -d "$VENV_DIR" ]]; then
        log "Creating virtual environment at: $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    else
        log "Virtual environment found at: $VENV_DIR"
    fi
    
    # Activate virtual environment
    log "Activating virtual environment..."
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    
    # Verify activation
    if [[ "${VIRTUAL_ENV:-}" != "$VENV_DIR" ]]; then
        error "Failed to activate virtual environment"
        exit 1
    fi
    
    log "Virtual environment activated: $VIRTUAL_ENV"
    log "Python executable: $(which python3)"
    log "Pip executable: $(which pip3)"
    
    success "Virtual environment ready"
}

# Install/update dependencies
install_dependencies() {
    log "Installing/updating Python dependencies..."
    
    # Critical dependencies
    local critical_deps=(
        "pdfplumber>=0.7.0"  # PDF text extraction - CRITICAL for enhanced functionality
    )
    
    # Optional dependencies for enhanced functionality
    local optional_deps=(
        "Pillow>=8.0.0"      # Enhanced image support
        "markdown>=3.0.0"    # Markdown processing (future feature)
        "pygments>=2.0.0"    # Syntax highlighting (future feature)
        "rich>=10.0.0"       # Enhanced terminal output (future feature)
    )
    
    # Upgrade pip first
    log "Upgrading pip..."
    python3 -m pip install --upgrade pip
    
    # Install critical dependencies
    log "Installing critical dependencies..."
    for dep in "${critical_deps[@]}"; do
        log "Installing $dep..."
        if pip3 install "$dep"; then
            success "$dep installed successfully"
        else
            warning "$dep installation failed - PDF extraction may not work"
        fi
    done
    
    # Install optional dependencies (best effort)
    log "Installing optional dependencies for enhanced functionality..."
    for dep in "${optional_deps[@]}"; do
        log "Installing $dep (optional)..."
        if pip3 install "$dep" 2>/dev/null; then
            success "$dep installed"
        else
            warning "$dep installation failed (optional - continuing)"
        fi
    done
    
    # Install project-specific requirements if they exist
    local requirements_files=(
        "$PROJECT_ROOT/requirements.txt"
        "$PROJECT_ROOT/docs/requirements.txt"
    )
    
    for req_file in "${requirements_files[@]}"; do
        if [[ -f "$req_file" ]]; then
            log "Installing requirements from: $req_file"
            pip3 install -r "$req_file" || warning "Some requirements failed to install"
        fi
    done
    
    success "Dependencies installation completed"
}

# Verify browser functionality
verify_browser() {
    log "Verifying universal documentation browser functionality..."
    
    # Test import capabilities and directory detection
    if ! python3 -c "
import sys
import os
import tkinter
import pathlib
from pathlib import Path

# Test critical imports
try:
    import pdfplumber
    print('✓ PDF extraction available (pdfplumber)')
except ImportError:
    print('⚠ PDF extraction not available - install pdfplumber for full functionality')

try:
    from PIL import Image, ImageTk
    print('✓ Enhanced image support available (Pillow)')
except ImportError:
    print('⚠ Enhanced image support not available (optional)')

print('✓ Core imports successful')

# Test browser script exists and is readable
browser_script = Path('$BROWSER_SCRIPT')
if not browser_script.exists():
    print('✗ Browser script not found')
    sys.exit(1)

print(f'✓ Browser script found: {browser_script.name}')
print('✓ Universal documentation browser verification successful')
" 2>/dev/null; then
        error "Universal documentation browser verification failed"
        exit 1
    fi
    
    success "Universal documentation browser verified and ready"
}

# Detect documentation directory
detect_docs_directory() {
    local candidates=()
    
    if [[ -n "$TARGET_DIR" ]]; then
        # User specified directory
        if [[ -d "$TARGET_DIR" ]]; then
            echo "$TARGET_DIR"
            return 0
        else
            error "Specified directory not found: $TARGET_DIR"
            exit 1
        fi
    fi
    
    # Auto-detect candidates
    candidates=(
        "$PROJECT_ROOT/docs"
        "/home/ubuntu/Documents/claude-backups/docs"
        "/home/ubuntu/Documents/ARTICBASTION/docs"
        "/home/ubuntu/Documents/livecd-gen/docs"
        "$(pwd)/docs"
        "$(pwd)/doc"
        "$(pwd)/documentation"
        "$(pwd)"
    )
    
    log "Auto-detecting documentation directory..."
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            # Check if it contains documentation files
            local doc_count
            doc_count=$(find "$candidate" -maxdepth 2 -name "*.md" -o -name "*.txt" -o -name "*.rst" -o -name "*.pdf" -o -name "*.html" 2>/dev/null | wc -l)
            if [[ $doc_count -gt 0 ]]; then
                log "Found documentation directory with $doc_count files: $candidate"
                echo "$candidate"
                return 0
            fi
        fi
    done
    
    # Fallback to current directory
    warning "No documentation directory auto-detected, using current directory"
    echo "$(pwd)"
}

# Launch the browser
launch_browser() {
    local docs_dir
    docs_dir=$(detect_docs_directory)
    
    log "Launching Universal Documentation Browser..."
    log "Target directory: $docs_dir"
    
    # Change to the directory containing the browser script for relative imports
    cd "$(dirname "$BROWSER_SCRIPT")"
    
    # Display launch information
    echo
    log "Universal Documentation Browser Features:"
    log "  🌐 Automatically adapts to any documentation structure"
    log "  📁 Detects categories: guides, api, architecture, security, technical, etc."
    log "  📄 File support: .md, .pdf, .txt, .rst, .html, .docx, .odt"
    log "  🔍 Advanced search with PDF content indexing"
    log "  👥 Auto-generated role-based quick access"
    log "  🖥️  Professional GUI with caching and external integration"
    log "  ⚡ Single-file implementation with PDF extraction"
    echo
    
    if [[ "$docs_dir" != "$(pwd)" ]]; then
        log "Launching with directory argument: $docs_dir"
        if python3 "$(basename "$BROWSER_SCRIPT")" "$docs_dir"; then
            success "Universal documentation browser closed normally"
        else
            handle_browser_exit $?
        fi
    else
        log "Launching with auto-detection from current directory"
        if python3 "$(basename "$BROWSER_SCRIPT")"; then
            success "Universal documentation browser closed normally"
        else
            handle_browser_exit $?
        fi
    fi
}

# Handle browser exit codes
handle_browser_exit() {
    local exit_code=$1
    if [[ $exit_code -eq 130 ]]; then
        log "Universal documentation browser interrupted by user (Ctrl+C)"
    else
        error "Universal documentation browser exited with error code: $exit_code"
        echo
        echo "Troubleshooting steps:"
        echo "1. Check that X11 forwarding is enabled if using SSH: ssh -X user@host"
        echo "2. Verify GUI environment is available: echo \$DISPLAY"
        echo "3. Test tkinter: python3 -c 'import tkinter; tkinter.Tk().destroy()'"
        echo "4. Install PDF support: pip install pdfplumber"
        echo "5. Check file permissions: ls -la $BROWSER_SCRIPT"
        echo "6. Try with specific directory: $0 /path/to/docs"
        echo "7. Check system status: $0 --status"
    fi
}

# Status function with enhanced information
show_status() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}      Universal Documentation Browser System Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # System information
    echo -e "${GREEN}System Information:${NC}"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Shell: $SHELL"
    echo "  User: $(whoami)"
    echo "  Working Directory: $(pwd)"
    echo
    
    # Python information
    echo -e "${GREEN}Python Environment:${NC}"
    echo "  Python Version: $(python3 --version 2>/dev/null || echo 'Not found')"
    echo "  Python Path: $(which python3 2>/dev/null || echo 'Not found')"
    echo "  Pip Path: $(which pip3 2>/dev/null || echo 'Not found')"
    if python3 -c "import tkinter" 2>/dev/null; then
        echo "  Tkinter: ✓ Available"
    else
        echo "  Tkinter: ✗ Not available"
    fi
    echo
    
    # Enhanced dependencies
    echo -e "${GREEN}Enhanced Dependencies:${NC}"
    if python3 -c "import pdfplumber" 2>/dev/null; then
        echo "  PDF Extraction (pdfplumber): ✓ Available"
    else
        echo "  PDF Extraction (pdfplumber): ✗ Not available - install with: pip install pdfplumber"
    fi
    
    if python3 -c "from PIL import Image" 2>/dev/null; then
        echo "  Image Support (Pillow): ✓ Available" 
    else
        echo "  Image Support (Pillow): ✗ Not available (optional)"
    fi
    echo
    
    # Virtual environment
    echo -e "${GREEN}Virtual Environment:${NC}"
    if [[ -d "$VENV_DIR" ]]; then
        echo "  Location: $VENV_DIR ✓"
        if [[ -n "${VIRTUAL_ENV:-}" ]]; then
            echo "  Status: Active ($VIRTUAL_ENV)"
        else
            echo "  Status: Inactive"
        fi
    else
        echo "  Status: Not created"
    fi
    echo
    
    # Browser application
    echo -e "${GREEN}Browser Application:${NC}"
    if [[ -f "$BROWSER_SCRIPT" ]]; then
        echo "  Script: $(basename $BROWSER_SCRIPT) ✓"
        echo "  Path: $BROWSER_SCRIPT"
        echo "  Size: $(stat -f%z "$BROWSER_SCRIPT" 2>/dev/null || stat -c%s "$BROWSER_SCRIPT") bytes"
        if [[ -x "$BROWSER_SCRIPT" ]]; then
            echo "  Permissions: Executable ✓"
        else
            echo "  Permissions: Not executable (will use python3)"
        fi
    else
        echo "  Script: Not found ✗"
    fi
    echo
    
    # Available documentation directories  
    echo -e "${GREEN}Available Documentation Directories:${NC}"
    local test_dirs=(
        "$PROJECT_ROOT/docs"
        "/home/ubuntu/Documents/claude-backups/docs"
        "/home/ubuntu/Documents/ARTICBASTION/docs"
        "/home/ubuntu/Documents/livecd-gen/docs"
    )
    
    for test_dir in "${test_dirs[@]}"; do
        if [[ -d "$test_dir" ]]; then
            local file_count
            file_count=$(find "$test_dir" -name "*.md" -o -name "*.pdf" -o -name "*.txt" -o -name "*.html" 2>/dev/null | wc -l)
            local pdf_count
            pdf_count=$(find "$test_dir" -name "*.pdf" 2>/dev/null | wc -l)
            echo "  $(basename $(dirname $test_dir))/$(basename $test_dir): $file_count files ($pdf_count PDFs) ✓"
        else
            echo "  $test_dir: Not found ✗"
        fi
    done
    echo
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    # Deactivate virtual environment if active
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        log "Deactivating virtual environment"
        deactivate 2>/dev/null || true
    fi
}

# Main function
main() {
    # Initialize variables with defaults
    local setup_only=false
    local skip_deps=false
    local verify_only=false
    local clean_env=false
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Parse arguments (this will handle --help, --status, etc.)
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # Clean environment if requested
    if [[ "${clean_env:-false}" == "true" ]]; then
        log "Cleaning virtual environment..."
        if [[ -d "$VENV_DIR" ]]; then
            rm -rf "$VENV_DIR"
            success "Virtual environment cleaned"
        fi
    fi
    
    # Check system requirements
    check_requirements
    
    # Setup virtual environment
    setup_venv
    
    # Install dependencies unless skipped
    if [[ "${skip_deps:-false}" == "false" ]]; then
        install_dependencies
    else
        log "Skipping dependency installation as requested"
    fi
    
    # Verify browser functionality
    verify_browser
    
    # Exit early if setup/verify only
    if [[ "${setup_only:-false}" == "true" ]]; then
        success "Setup completed successfully. Use '$0 [directory]' to launch the browser."
        exit 0
    fi
    
    if [[ "${verify_only:-false}" == "true" ]]; then
        success "Verification completed successfully."
        exit 0
    fi
    
    # Launch the browser
    launch_browser
}

# Run main function with all arguments
main "$@"