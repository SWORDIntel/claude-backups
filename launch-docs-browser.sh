#!/bin/bash
# Documentation Browser Launcher with Virtual Environment Management
# Claude Agent Framework v7.0 - Comprehensive Documentation Browser

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DOCS_DIR="$PROJECT_ROOT/docs"
VENV_DIR="$PROJECT_ROOT/venv"
BROWSER_SCRIPT="$DOCS_DIR/universal_docs_browser_enhanced.py"

# Logging function
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

# Banner
show_banner() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Claude Agent Framework v7.0                        ║${NC}"
    echo -e "${BLUE}║              Documentation Browser Launcher                      ║${NC}"
    echo -e "${BLUE}║                                                                  ║${NC}"
    echo -e "${BLUE}║  🗂️  47 documentation files across 8 organized categories      ║${NC}"
    echo -e "${BLUE}║  🔍  Advanced search and role-based quick access               ║${NC}"
    echo -e "${BLUE}║  🖥️  Professional PyGUI interface with external integration    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        error "Python 3 not found. Please install Python 3.6 or higher."
        echo "  Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv"
        echo "  RHEL/CentOS: sudo yum install python3 python3-pip"
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
    
    # Check project structure
    if [[ ! -d "$DOCS_DIR" ]]; then
        error "Documentation directory not found: $DOCS_DIR"
        exit 1
    fi
    
    if [[ ! -f "$BROWSER_SCRIPT" ]]; then
        error "Documentation browser script not found: $BROWSER_SCRIPT"
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
    
    # Core dependencies for the documentation browser
    local deps=(
        "tkinter"  # GUI framework (usually built-in)
        "pathlib"  # Path handling (built-in in Python 3.4+)
    )
    
    # Optional dependencies for enhanced functionality
    local optional_deps=(
        "Pillow>=8.0.0"     # Enhanced image support
        "markdown>=3.0.0"   # Markdown processing
        "pygments>=2.0.0"   # Syntax highlighting
    )
    
    # Upgrade pip first
    log "Upgrading pip..."
    python3 -m pip install --upgrade pip
    
    # Install core dependencies (most are built-in)
    log "Checking core dependencies..."
    for dep in "${deps[@]}"; do
        if [[ "$dep" == "tkinter" || "$dep" == "pathlib" ]]; then
            # These are built-in, just test import
            if python3 -c "import $dep" 2>/dev/null; then
                success "$dep available (built-in)"
            else
                warning "$dep not available - may need system package"
            fi
        else
            log "Installing $dep..."
            pip3 install "$dep"
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
        "$DOCS_DIR/requirements.txt"
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
    log "Verifying documentation browser functionality..."
    
    # Test import capabilities
    if ! python3 -c "
import sys
import os
import tkinter
import pathlib
from pathlib import Path
print('✓ Core imports successful')

# Test docs directory access
docs_path = Path('$DOCS_DIR')
if not docs_path.exists():
    print('✗ Docs directory not found')
    sys.exit(1)

# Count documentation files
md_files = list(docs_path.rglob('*.md'))
pdf_files = list(docs_path.rglob('*.pdf'))
total_files = len(md_files) + len(pdf_files)
print(f'✓ Found {total_files} documentation files ({len(md_files)} .md, {len(pdf_files)} .pdf)')

# Test categories
categories = ['guides', 'reference', 'architecture', 'implementation', 'features', 'fixes', 'troubleshooting', 'legacy']
found_categories = 0
for cat in categories:
    cat_path = docs_path / cat
    if cat_path.exists():
        found_categories += 1
print(f'✓ Found {found_categories}/{len(categories)} documentation categories')

print('✓ Documentation browser verification successful')
" 2>/dev/null; then
        error "Documentation browser verification failed"
        exit 1
    fi
    
    success "Documentation browser verified and ready"
}

# Launch the browser
launch_browser() {
    log "Launching Claude Agent Framework Documentation Browser..."
    
    # Change to docs directory for optimal functionality
    cd "$DOCS_DIR"
    log "Working directory: $(pwd)"
    
    # Display launch information
    echo
    log "Documentation Statistics:"
    log "  📁 Categories: 8 (guides, reference, architecture, implementation, features, fixes, troubleshooting, legacy)"
    log "  📄 Total Files: 47 documentation files"
    log "  🔍 Search: Real-time content and filename search"
    log "  👥 Quick Access: Role-based document sets (New Users, Developers, System Administrators, Researchers)"
    log "  🖥️  Interface: Professional PyGUI with external editor integration"
    echo
    
    log "Starting documentation browser..."
    
    # Launch with error handling
    if python3 "$BROWSER_SCRIPT"; then
        success "Documentation browser closed normally"
    else
        local exit_code=$?
        if [[ $exit_code -eq 130 ]]; then
            log "Documentation browser interrupted by user (Ctrl+C)"
        else
            error "Documentation browser exited with error code: $exit_code"
            echo
            echo "Troubleshooting steps:"
            echo "1. Check that X11 forwarding is enabled if using SSH"
            echo "2. Verify GUI environment is available: echo \$DISPLAY"
            echo "3. Test tkinter: python3 -c 'import tkinter; tkinter.Tk()'"
            echo "4. Check file permissions: ls -la $BROWSER_SCRIPT"
        fi
    fi
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

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Launch the Claude Agent Framework Documentation Browser with virtual environment support"
    echo
    echo "OPTIONS:"
    echo "  -h, --help         Show this help message"
    echo "  --setup-only       Only setup virtual environment and dependencies, don't launch browser"
    echo "  --skip-deps        Skip dependency installation (use existing environment)"
    echo "  --verify-only      Only verify setup, don't launch browser"
    echo "  --clean            Clean virtual environment and reinstall"
    echo "  --status           Show system and environment status"
    echo
    echo "EXAMPLES:"
    echo "  $0                 # Full setup and launch"
    echo "  $0 --setup-only    # Setup environment only"
    echo "  $0 --skip-deps     # Launch with existing environment"
    echo "  $0 --status        # Show status information"
    echo
}

# Status function
show_status() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}        Claude Agent Framework Documentation Browser Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # System information
    echo -e "${GREEN}System Information:${NC}"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Shell: $SHELL"
    echo "  User: $(whoami)"
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
    
    # Documentation structure
    echo -e "${GREEN}Documentation Structure:${NC}"
    if [[ -d "$DOCS_DIR" ]]; then
        echo "  Docs Directory: $DOCS_DIR ✓"
        local md_count pdf_count
        md_count=$(find "$DOCS_DIR" -name "*.md" 2>/dev/null | wc -l)
        pdf_count=$(find "$DOCS_DIR" -name "*.pdf" 2>/dev/null | wc -l)
        echo "  Markdown Files: $md_count"
        echo "  PDF Files: $pdf_count"
        echo "  Total Files: $((md_count + pdf_count))"
        
        # Category breakdown
        local categories=(guides reference architecture implementation features fixes troubleshooting legacy)
        echo "  Categories:"
        for cat in "${categories[@]}"; do
            if [[ -d "$DOCS_DIR/$cat" ]]; then
                local cat_count
                cat_count=$(find "$DOCS_DIR/$cat" -name "*.md" -o -name "*.pdf" 2>/dev/null | wc -l)
                echo "    $cat: $cat_count files ✓"
            else
                echo "    $cat: Not found ✗"
            fi
        done
    else
        echo "  Docs Directory: Not found ✗"
    fi
    echo
    
    # Browser script
    echo -e "${GREEN}Browser Application:${NC}"
    if [[ -f "$BROWSER_SCRIPT" ]]; then
        echo "  Script: $BROWSER_SCRIPT ✓"
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
}

# Main function
main() {
    # Parse command line arguments
    local setup_only=false
    local skip_deps=false
    local verify_only=false
    local clean_env=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --clean)
                clean_env=true
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Show banner
    show_banner
    
    # Clean environment if requested
    if [[ "$clean_env" == "true" ]]; then
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
    if [[ "$skip_deps" == "false" ]]; then
        install_dependencies
    else
        log "Skipping dependency installation as requested"
    fi
    
    # Verify browser functionality
    verify_browser
    
    # Exit early if setup/verify only
    if [[ "$setup_only" == "true" ]]; then
        success "Setup completed successfully. Use '$0' to launch the browser."
        exit 0
    fi
    
    if [[ "$verify_only" == "true" ]]; then
        success "Verification completed successfully."
        exit 0
    fi
    
    # Launch the browser
    launch_browser
}

# Run main function with all arguments
main "$@"