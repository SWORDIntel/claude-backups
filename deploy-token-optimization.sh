#!/bin/bash
# Token Optimization System - Portable Repository, System-wide Installation
# Usage: ./deploy-token-optimization.sh

set -e

# Get script location (works with symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Installation paths
USER_CLAUDE_DIR="$HOME/.claude"
SYSTEM_DIR="$USER_CLAUDE_DIR/system"
MODULES_DIR="$SYSTEM_DIR/modules"
CONFIG_DIR="$SYSTEM_DIR/config"
TESTS_DIR="$SYSTEM_DIR/tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[DEPLOY]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v python3 &> /dev/null; then
        error "Python3 is required but not installed"
        exit 1
    fi
    
    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
        error "Python 3.8+ is required"
        exit 1
    fi
    
    log "Dependencies check passed"
}

# Create directory structure
create_directories() {
    log "Creating system directories..."
    
    mkdir -p "$USER_CLAUDE_DIR"
    mkdir -p "$MODULES_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$TESTS_DIR"
    mkdir -p "$USER_CLAUDE_DIR/logs"
    mkdir -p "$USER_CLAUDE_DIR/cache"
    
    log "Directory structure created at $USER_CLAUDE_DIR"
}

# Deploy modules
deploy_modules() {
    log "Deploying optimization modules..."
    
    # Copy modules from repository
    if [[ -d "$REPO_ROOT/system/modules" ]]; then
        cp -r "$REPO_ROOT/system/modules/"* "$MODULES_DIR/" 2>/dev/null || true
    fi
    
    # Copy Python modules from agents/src/python if they exist
    if [[ -d "$REPO_ROOT/agents/src/python" ]]; then
        for module in token_optimizer.py trie_keyword_matcher.py multilevel_cache_system.py permission_fallback_system.py unified_async_optimization_pipeline.py; do
            if [[ -f "$REPO_ROOT/agents/src/python/$module" ]]; then
                cp "$REPO_ROOT/agents/src/python/$module" "$MODULES_DIR/" 2>/dev/null || true
            fi
        done
    fi
    
    log "Modules deployed to $MODULES_DIR"
}

# Deploy configuration
deploy_config() {
    log "Deploying configuration templates..."
    
    # Copy config templates
    if [[ -d "$REPO_ROOT/system/config" ]]; then
        cp -r "$REPO_ROOT/system/config/"* "$CONFIG_DIR/" 2>/dev/null || true
    fi
    
    # Create default config if none exists
    if [[ ! -f "$CONFIG_DIR/token_optimizer.conf" ]]; then
        cat > "$CONFIG_DIR/token_optimizer.conf" << 'CONFIG'
# Token Optimization Configuration
[optimization]
enabled=true
max_tokens=4000
compression_level=high
preserve_context=true

[caching]
enabled=true
cache_size=1000
ttl_seconds=3600

[logging]
level=INFO
file=$HOME/.claude/logs/token_optimizer.log

[performance]
parallel_processing=true
max_workers=4
batch_size=100
CONFIG
    fi
    
    log "Configuration deployed to $CONFIG_DIR"
}

# Deploy tests
deploy_tests() {
    log "Deploying test suite..."
    
    if [[ -d "$REPO_ROOT/system/tests" ]]; then
        cp -r "$REPO_ROOT/system/tests/"* "$TESTS_DIR/" 2>/dev/null || true
    fi
    
    log "Tests deployed to $TESTS_DIR"
}

# Create system-wide wrapper
create_system_wrapper() {
    log "Creating system-wide Claude wrapper..."
    
    # Check if we can write to /usr/local/bin
    if [[ -w "/usr/local/bin" ]] || sudo -n true 2>/dev/null; then
        WRAPPER_PATH="/usr/local/bin/claude-optimized"
        USE_SUDO="sudo"
    else
        WRAPPER_PATH="$HOME/.local/bin/claude-optimized"
        USE_SUDO=""
        mkdir -p "$HOME/.local/bin"
    fi
    
    cat > "/tmp/claude-optimized" << 'WRAPPER'
#!/bin/bash
# Claude Token Optimization Wrapper - System-wide Installation

# Find user's Claude system directory
USER_CLAUDE_DIR="$HOME/.claude"
SYSTEM_DIR="$USER_CLAUDE_DIR/system"

# Fallback to repository location
if [[ ! -d "$SYSTEM_DIR" ]]; then
    # Try to find repository
    POSSIBLE_REPOS=(
        "$HOME/claude-backups"
        "$HOME/Documents/claude-backups"
        "$HOME/code/claude-backups"
        "$(pwd)"
    )
    
    for repo in "${POSSIBLE_REPOS[@]}"; do
        if [[ -d "$repo/system" ]]; then
            SYSTEM_DIR="$repo/system"
            break
        fi
    done
fi

# Export system paths
export CLAUDE_SYSTEM_DIR="$SYSTEM_DIR"
export CLAUDE_MODULES_DIR="$SYSTEM_DIR/modules"
export CLAUDE_CONFIG_DIR="$SYSTEM_DIR/config"

# Find original claude binary
CLAUDE_BINARY=""
for path in /usr/local/bin/claude $HOME/.local/bin/claude $(which claude 2>/dev/null); do
    if [[ -x "$path" && "$path" != "$0" ]]; then
        CLAUDE_BINARY="$path"
        break
    fi
done

if [[ -z "$CLAUDE_BINARY" ]]; then
    echo "Error: Claude binary not found" >&2
    exit 1
fi

# Load optimization if available
if [[ -f "$CLAUDE_MODULES_DIR/claude_universal_optimizer.py" ]]; then
    python3 "$CLAUDE_MODULES_DIR/claude_universal_optimizer.py" --pre-process "$@"
    exec "$CLAUDE_BINARY" "$@"
else
    exec "$CLAUDE_BINARY" "$@"
fi
WRAPPER
    
    # Install wrapper
    if [[ -n "$USE_SUDO" ]]; then
        sudo cp "/tmp/claude-optimized" "$WRAPPER_PATH"
        sudo chmod +x "$WRAPPER_PATH"
    else
        cp "/tmp/claude-optimized" "$WRAPPER_PATH"
        chmod +x "$WRAPPER_PATH"
    fi
    
    rm "/tmp/claude-optimized"
    
    log "System wrapper installed at $WRAPPER_PATH"
    
    # Add to PATH if needed
    if [[ "$WRAPPER_PATH" == "$HOME/.local/bin/claude-optimized" ]]; then
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            warn "Add $HOME/.local/bin to your PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
}

# Create development symlinks
create_dev_symlinks() {
    log "Creating development symlinks..."
    
    # Link back to repository for development
    ln -sf "$REPO_ROOT" "$USER_CLAUDE_DIR/repo" 2>/dev/null || true
    
    # Create convenient symlinks
    if [[ -d "$REPO_ROOT/agents" ]]; then
        ln -sf "$REPO_ROOT/agents" "$USER_CLAUDE_DIR/agents" 2>/dev/null || true
    fi
    
    log "Development symlinks created"
}

# Run tests
run_tests() {
    if [[ "$1" == "--skip-tests" ]]; then
        warn "Skipping tests as requested"
        return
    fi
    
    log "Running installation tests..."
    
    # Test Python imports
    if python3 -c "
import sys
sys.path.insert(0, '$MODULES_DIR')
try:
    import configparser
    print('✓ Configuration parsing available')
except ImportError:
    print('✗ Configuration parsing failed')
    
try:
    import json
    print('✓ JSON processing available')
except ImportError:
    print('✗ JSON processing failed')
" 2>/dev/null; then
        log "Python environment tests passed"
    else
        warn "Some Python tests failed - optimization may be limited"
    fi
    
    # Test directory structure
    if [[ -d "$MODULES_DIR" && -d "$CONFIG_DIR" ]]; then
        log "Directory structure tests passed"
    else
        error "Directory structure tests failed"
        exit 1
    fi
}

# Show installation summary
show_summary() {
    log "Installation Summary:"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "System Directory: $USER_CLAUDE_DIR/system"
    info "Modules: $MODULES_DIR"
    info "Config: $CONFIG_DIR"
    info "Tests: $TESTS_DIR"
    info "Repository Link: $USER_CLAUDE_DIR/repo"
    
    if command -v claude-optimized &> /dev/null; then
        info "Wrapper: $(which claude-optimized)"
        info ""
        info "Usage: claude-optimized [options] /task \"your task\""
    else
        warn "Wrapper not in PATH - you may need to update your PATH"
    fi
    
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main installation function
main() {
    log "Starting Token Optimization System deployment..."
    log "Repository: $REPO_ROOT"
    log "Target: $USER_CLAUDE_DIR"
    
    check_dependencies
    create_directories
    deploy_modules
    deploy_config
    deploy_tests
    create_system_wrapper
    create_dev_symlinks
    run_tests "$@"
    show_summary
    
    log "Deployment complete! 🚀"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Token Optimization System Deployment"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --skip-tests    Skip installation tests"
        echo "  --help, -h      Show this help"
        echo ""
        echo "This script installs the token optimization system"
        echo "from the portable repository to ~/.claude/system/"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac