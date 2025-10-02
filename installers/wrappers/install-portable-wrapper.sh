#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# CLAUDE PORTABLE WRAPPER INSTALLER v1.0
#
# Installs the portable wrapper with zero hardcoded paths
# Works on any user, any system, any installation location
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Dynamic path detection
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$SCRIPT_DIR"

# User installation paths (XDG compliant)
USER_BIN="${HOME}/.local/bin"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/claude"

print_header() {
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════════"
    echo -e "$1"
    echo -e "════════════════════════════════════════════════════════════════════════════════${RESET}"
}

log_info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

main() {
    print_header "CLAUDE PORTABLE WRAPPER INSTALLER v1.0"

    log_info "Project Root: $PROJECT_ROOT"
    log_info "User Bin: $USER_BIN"
    log_info "Config Dir: $USER_CONFIG"

    # Create directories
    mkdir -p "$USER_BIN" "$USER_CONFIG"

    # Backup existing claude if it exists
    if [[ -f "$USER_BIN/claude" ]]; then
        log_warning "Backing up existing claude to claude-backup"
        cp "$USER_BIN/claude" "$USER_BIN/claude-backup"
    fi

    # Install portable wrapper
    log_info "Installing portable wrapper..."
    cp "$PROJECT_ROOT/claude-wrapper-simple.sh" "$USER_BIN/claude"
    chmod +x "$USER_BIN/claude"

    # Create configuration
    cat > "$USER_CONFIG/portable-paths.conf" << EOF
# Claude Portable Configuration
# Generated: $(date)

# Project root (auto-detected)
CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"

# User paths
CLAUDE_USER_BIN="$USER_BIN"
CLAUDE_CONFIG_DIR="$USER_CONFIG"

# Learning system (if available)
LEARNING_CAPTURE_ENABLED=true
LEARNING_DB_PORT=5433
EOF

    log_success "Portable wrapper installed successfully!"
    echo
    log_info "Installation Summary:"
    log_info "  • Wrapper: $USER_BIN/claude"
    log_info "  • Config: $USER_CONFIG/portable-paths.conf"
    log_info "  • Project: $PROJECT_ROOT"
    echo
    log_info "Test commands:"
    log_info "  claude --status"
    log_info "  claude /task \"test portable wrapper\""
    echo
    log_info "The wrapper automatically:"
    log_info "  • Detects Claude binary location"
    log_info "  • Uses portable path resolution"
    log_info "  • Enables permission bypass for LiveCD/SSH"
    log_info "  • Integrates with learning system"
    echo
    log_success "Ready to use! No hardcoded paths anywhere."
}

main "$@"