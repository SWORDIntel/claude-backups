#!/bin/bash
# Simple Universal Documentation Browser Launcher
# Launches the browser without complex venv management

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSER_SCRIPT="$SCRIPT_DIR/docs/universal_docs_browser_enhanced.py"

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Banner
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Universal Documentation Browser                        ║${NC}"
echo -e "${CYAN}║        Enhanced with PDF Extraction (Simple Launcher)          ║${NC}"
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║  🌐 Adapts to any documentation structure                      ║${NC}"
echo -e "${CYAN}║  📄 PDF text extraction with pdfplumber (if installed)         ║${NC}"
echo -e "${CYAN}║  🔍 Advanced search across all file types                      ║${NC}"
echo -e "${CYAN}║  👥 Auto-generated role-based quick access                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if browser exists
if [[ ! -f "$BROWSER_SCRIPT" ]]; then
    error "Browser script not found: $BROWSER_SCRIPT"
    exit 1
fi

# Check Python and tkinter
if ! command -v python3 &> /dev/null; then
    error "Python 3 not found. Please install Python 3."
    exit 1
fi

if ! python3 -c "import tkinter" 2>/dev/null; then
    error "tkinter not available. Install with: sudo apt install python3-tk"
    exit 1
fi

# Check PDF support
if python3 -c "import pdfplumber" 2>/dev/null; then
    log "✓ PDF extraction available (pdfplumber)"
else
    log "⚠ PDF extraction not available. Install with: pip install pdfplumber"
fi

# Determine target directory
TARGET_DIR="$1"
if [[ -z "$TARGET_DIR" ]]; then
    # Auto-detect
    candidates=(
        "$SCRIPT_DIR/docs"
        "$CLAUDE_PROJECT_ROOT/docs"
        "$HOME/Documents/ARTICBASTION/docs"  
        "$HOME/Documents/livecd-gen/docs"
        "$(pwd)/docs"
        "$(pwd)"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            doc_count=$(find "$candidate" -maxdepth 2 -name "*.md" -o -name "*.txt" -o -name "*.pdf" 2>/dev/null | wc -l)
            if [[ $doc_count -gt 0 ]]; then
                TARGET_DIR="$candidate"
                log "Auto-detected: $TARGET_DIR ($doc_count files)"
                break
            fi
        fi
    done
    
    if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$(pwd)"
        log "Using current directory: $TARGET_DIR"
    fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    error "Directory not found: $TARGET_DIR"
    exit 1
fi

log "Launching Universal Documentation Browser..."
log "Target: $TARGET_DIR"

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [directory]"
    echo
    echo "Launch Universal Documentation Browser"
    echo
    echo "Examples:"
    echo "  $0                                              # Auto-detect docs"
    echo "  $0 $HOME/Documents/ARTICBASTION/docs    # Complex structure"
    echo "  $0 $HOME/Documents/livecd-gen/docs      # Another structure"
    echo "  $0 /path/to/any/docs                           # Any docs folder"
    exit 0
fi

# Launch browser
cd "$(dirname "$BROWSER_SCRIPT")"
if python3 "$(basename "$BROWSER_SCRIPT")" "$TARGET_DIR"; then
    success "Browser closed normally"
else
    exit_code=$?
    if [[ $exit_code -eq 130 ]]; then
        log "Browser interrupted by user"
    else
        error "Browser exited with code $exit_code"
        echo "Try: sudo apt install python3-tk"
        echo "Or:  pip install pdfplumber"
    fi
fi