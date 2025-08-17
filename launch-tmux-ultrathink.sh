#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# ULTRATHINK 4-PANEL TMUX LAUNCHER
# Intelligent multi-panel development environment for Claude LiveCD builds
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly SESSION_NAME="ultrathink-dev"
readonly WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Function to log with colors
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

log "Creating 4-panel UltraThink development environment..."

# Create new session with first window
tmux new-session -d -s "$SESSION_NAME" -x 120 -y 40

# Set up 4-panel layout
info "Setting up intelligent 4-panel layout..."

# Split into 4 panes
tmux split-window -h -t "$SESSION_NAME:0"     # Split horizontally (left|right)
tmux split-window -v -t "$SESSION_NAME:0.0"   # Split left pane vertically (top-left|bottom-left)
tmux split-window -v -t "$SESSION_NAME:0.2"   # Split right pane vertically (top-right|bottom-right)

# Configure each panel with specific purposes
info "Configuring panel purposes..."

# Panel 1 (top-left): UltraThink ZFS Build
tmux send-keys -t "$SESSION_NAME:0.0" "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo '═══ PANEL 1: UltraThink ZFS Build ═══'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo 'Commands:'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo '  sudo ./livecd-gen/build-ultrathink-zfs-native.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo '  # Build with full ZFS + Proxmox integration'" Enter

# Panel 2 (bottom-left): Build Monitor
tmux send-keys -t "$SESSION_NAME:0.1" "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo '═══ PANEL 2: Build Monitor ═══'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo 'Commands:'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo '  watch -n 2 \"zfs list | grep buildpool || echo 'No buildpool'\"'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo '  # Monitor ZFS build progress'" Enter

# Panel 3 (top-right): LiveCD Management & Tools
tmux send-keys -t "$SESSION_NAME:0.2" "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo '═══ PANEL 3: LiveCD Management & Tools ═══'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo 'Commands:'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo '  ./scripts/claude-livecd-unified-with-agents.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo '  ./scripts/build-master-livecd.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo '  # LiveCD building and configuration'" Enter

# Panel 4 (bottom-right): Persistence & Boot Management
tmux send-keys -t "$SESSION_NAME:0.3" "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo '═══ PANEL 4: Persistence & Boot Management ═══'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo 'Commands:'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo '  ./persistence/setup-usb-persistence.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo '  ./persistence/integrate-zfs-boot.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo '  ./persistence/microcode-management.sh'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo '  # Boot configuration and persistence setup'" Enter

# Set panel titles
tmux select-pane -t "$SESSION_NAME:0.0" -T "UltraThink Build"
tmux select-pane -t "$SESSION_NAME:0.1" -T "Build Monitor"
tmux select-pane -t "$SESSION_NAME:0.2" -T "LiveCD Tools"
tmux select-pane -t "$SESSION_NAME:0.3" -T "Persistence"

# Enable pane titles display
tmux set-option -t "$SESSION_NAME" pane-border-status top
tmux set-option -t "$SESSION_NAME" pane-border-format "#[fg=cyan,bold]#{pane_title}#[default]"

# Set initial focus to build panel
tmux select-pane -t "$SESSION_NAME:0.0"

# Display session info
log "4-panel UltraThink environment created successfully!"
info "Session: $SESSION_NAME"
info "Layout: ┌─────────────┬─────────────┐"
info "        │ Build       │ LiveCD Tools│"
info "        ├─────────────┼─────────────┤"
info "        │ Monitor     │ Persistence │"
info "        └─────────────┴─────────────┘"

echo
echo -e "${YELLOW}TMUX CONTROLS:${NC}"
echo "  Ctrl+B + Arrow Keys    - Navigate panels"
echo "  Ctrl+B + D             - Detach session"
echo "  Ctrl+B + X             - Close current panel"
echo "  Ctrl+B + C             - New window"
echo "  Ctrl+B + ?             - Help"
echo
echo -e "${BOLD}Ready to attach to session...${NC}"
echo "Run: tmux attach-session -t $SESSION_NAME"

# Auto-attach option
if [[ "${1:-}" != "--no-attach" ]]; then
    sleep 2
    log "Auto-attaching to session..."
    tmux attach-session -t "$SESSION_NAME"
fi