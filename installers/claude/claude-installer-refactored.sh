#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Streamlined Installer v11.0 - Hook System Integration Edition
# Refactored for efficiency with integrated TUI monitoring and hook system
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORE CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Terminal colors and formatting
export TERM=xterm-256color
print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_blue() { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_magenta() { printf "\033[0;35m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }

# Status symbols
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly ARROW="→"
readonly PROGRESS="⟳"

# Installation modes
readonly MODE_MINIMAL="minimal"
readonly MODE_STANDARD="standard" 
readonly MODE_FULL="full"
readonly MODE_DEVELOPER="developer"

# Global state
INSTALLATION_MODE="$MODE_STANDARD"
ENABLE_TUI="true"
ENABLE_HOOKS="true"
ENABLE_MONITORING="true"
DRY_RUN="false"
VERBOSE="false"
FORCE="false"

# Path configuration
detect_project_root() {
    local current_dir="$(pwd)"
    if [[ -d "./agents" ]] && [[ -f "./CLAUDE.md" ]]; then
        echo "$current_dir"
    elif [[ -d "$HOME/Documents/Claude/agents" ]]; then
        echo "$HOME/Documents/Claude"
    elif [[ -d "$(dirname "$0")/agents" ]]; then
        echo "$(dirname "$0")"
    else
        echo "$current_dir"
    fi
}

readonly PROJECT_ROOT="$(detect_project_root)"
readonly HOME_DIR="$HOME"
readonly LOCAL_BIN="$HOME_DIR/.local/bin"
readonly CLAUDE_HOME="$HOME_DIR/.claude"
readonly CONFIG_DIR="$HOME_DIR/.config/claude"
readonly CACHE_DIR="$HOME_DIR/.cache/claude"
readonly LOG_DIR="$HOME_DIR/.local/share/claude/logs"
readonly HOOKS_SOURCE="$PROJECT_ROOT/hooks"
readonly HOOKS_TARGET="$CONFIG_DIR/hooks"

# Create essential directories
for dir in "$LOCAL_BIN" "$CLAUDE_HOME" "$CONFIG_DIR" "$CACHE_DIR" "$LOG_DIR" "$HOOKS_TARGET"; do
    mkdir -p "$dir" 2>/dev/null || true
done

# Logging setup
readonly LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUI DASHBOARD SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Python TUI Dashboard Implementation (embedded)
create_tui_dashboard() {
    cat > "$CACHE_DIR/tui_dashboard.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Installer TUI Dashboard
Real-time monitoring of installation progress with hook system integration
"""

import curses
import json
import time
import threading
from pathlib import Path
from typing import Dict, List, Optional

class ClaudeInstallerTUI:
    def __init__(self):
        self.status_file = Path.home() / '.cache/claude/installer_status.json'
        self.hook_status_file = Path.home() / '.cache/claude/hook_status.json' 
        self.running = True
        self.status_data = {}
        self.hook_data = {}
        
    def init_curses(self):
        self.stdscr = curses.initscr()
        curses.noecho()
        curses.cbreak()
        curses.curs_set(0)
        self.stdscr.nodelay(True)
        
        # Colors
        curses.start_color()
        curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)   # Success
        curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)     # Error
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # Warning
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)    # Info
        curses.init_pair(5, curses.COLOR_MAGENTA, curses.COLOR_BLACK) # Progress
        
    def cleanup_curses(self):
        curses.nocbreak()
        curses.echo()
        curses.curs_set(1)
        curses.endwin()
        
    def load_status(self):
        """Load status from JSON files"""
        try:
            if self.status_file.exists():
                with open(self.status_file) as f:
                    self.status_data = json.load(f)
        except:
            pass
            
        try:
            if self.hook_status_file.exists():
                with open(self.hook_status_file) as f:
                    self.hook_data = json.load(f)
        except:
            pass
    
    def draw_header(self):
        """Draw the header section"""
        self.stdscr.addstr(0, 0, "╭─────────────────────────────────────────────────────────────────────╮", curses.color_pair(4))
        self.stdscr.addstr(1, 0, "│", curses.color_pair(4))
        self.stdscr.addstr(1, 1, " Claude Streamlined Installer v11.0 - Real-Time Dashboard", curses.A_BOLD)
        self.stdscr.addstr(1, 69, "│", curses.color_pair(4))
        self.stdscr.addstr(2, 0, "╰─────────────────────────────────────────────────────────────────────╯", curses.color_pair(4))
        
    def draw_progress(self, y_offset: int):
        """Draw installation progress"""
        progress = self.status_data.get('progress', {})
        current = progress.get('current', 0)
        total = progress.get('total', 10)
        percentage = int((current / total) * 100) if total > 0 else 0
        
        self.stdscr.addstr(y_offset, 0, f"Overall Progress: {current}/{total} ({percentage}%)", curses.A_BOLD)
        
        # Progress bar
        bar_width = 50
        filled = int((current / total) * bar_width) if total > 0 else 0
        bar = "█" * filled + "░" * (bar_width - filled)
        self.stdscr.addstr(y_offset + 1, 0, f"[{bar}]", curses.color_pair(5))
        
        return y_offset + 3
        
    def draw_components(self, y_offset: int):
        """Draw component status"""
        self.stdscr.addstr(y_offset, 0, "Component Status:", curses.A_BOLD)
        y_offset += 1
        
        components = self.status_data.get('components', {})
        for name, status in components.items():
            color = curses.color_pair(1) if status == 'completed' else \
                   curses.color_pair(2) if status == 'failed' else \
                   curses.color_pair(3) if status == 'running' else \
                   curses.color_pair(4)
            
            symbol = "✓" if status == 'completed' else \
                    "✗" if status == 'failed' else \
                    "⟳" if status == 'running' else "○"
            
            self.stdscr.addstr(y_offset, 2, f"{symbol} {name}: {status}", color)
            y_offset += 1
            
        return y_offset + 1
        
    def draw_hooks(self, y_offset: int):
        """Draw hook system status"""
        self.stdscr.addstr(y_offset, 0, "Hook System Status:", curses.A_BOLD)
        y_offset += 1
        
        hook_status = self.hook_data.get('status', 'inactive')
        active_hooks = self.hook_data.get('active_hooks', [])
        performance = self.hook_data.get('performance', {})
        
        # Main status
        color = curses.color_pair(1) if hook_status == 'active' else curses.color_pair(2)
        self.stdscr.addstr(y_offset, 2, f"Status: {hook_status}", color)
        y_offset += 1
        
        # Active hooks
        self.stdscr.addstr(y_offset, 2, f"Active Hooks: {len(active_hooks)}")
        y_offset += 1
        
        for hook in active_hooks[:5]:  # Show first 5
            self.stdscr.addstr(y_offset, 4, f"• {hook}", curses.color_pair(4))
            y_offset += 1
            
        # Performance metrics
        if performance:
            throughput = performance.get('throughput', 0)
            latency = performance.get('avg_latency', 0)
            self.stdscr.addstr(y_offset, 2, f"Throughput: {throughput:.1f} ops/sec", curses.color_pair(4))
            y_offset += 1
            self.stdscr.addstr(y_offset, 2, f"Avg Latency: {latency:.2f}ms", curses.color_pair(4))
            y_offset += 1
            
        return y_offset + 1
    
    def draw_logs(self, y_offset: int):
        """Draw recent log entries"""
        logs = self.status_data.get('recent_logs', [])
        if not logs:
            return y_offset
            
        self.stdscr.addstr(y_offset, 0, "Recent Activity:", curses.A_BOLD)
        y_offset += 1
        
        for log in logs[-10:]:  # Show last 10 entries
            level = log.get('level', 'INFO')
            message = log.get('message', '')
            timestamp = log.get('timestamp', '')
            
            color = curses.color_pair(1) if level == 'SUCCESS' else \
                   curses.color_pair(2) if level == 'ERROR' else \
                   curses.color_pair(3) if level == 'WARNING' else \
                   curses.color_pair(4)
            
            self.stdscr.addstr(y_offset, 2, f"[{timestamp}] {level}: {message}"[:65], color)
            y_offset += 1
            
        return y_offset
        
    def run(self):
        """Main dashboard loop"""
        self.init_curses()
        
        try:
            while self.running:
                self.stdscr.clear()
                self.load_status()
                
                y = 0
                y = self.draw_header()
                y = self.draw_progress(y + 1)
                y = self.draw_components(y)
                y = self.draw_hooks(y)
                y = self.draw_logs(y)
                
                self.stdscr.addstr(curses.LINES - 2, 0, "Press 'q' to quit dashboard", curses.A_DIM)
                self.stdscr.refresh()
                
                # Check for quit
                key = self.stdscr.getch()
                if key == ord('q'):
                    break
                    
                time.sleep(0.5)  # Update every 500ms
                
        finally:
            self.cleanup_curses()

if __name__ == "__main__":
    dashboard = ClaudeInstallerTUI()
    dashboard.run()
EOF
    
    chmod +x "$CACHE_DIR/tui_dashboard.py"
}

# Status management functions
update_status() {
    local component="$1"
    local status="$2"
    local message="${3:-}"
    
    local status_file="$CACHE_DIR/installer_status.json"
    local timestamp=$(date -Iseconds)
    
    # Create or update status file
    if [[ -f "$status_file" ]]; then
        local temp_file=$(mktemp)
        jq --arg comp "$component" --arg stat "$status" --arg msg "$message" --arg ts "$timestamp" \
           '.components[$comp] = $stat | 
            .recent_logs += [{level: ($stat | ascii_upcase), message: $msg, timestamp: $ts}] |
            .recent_logs = (.recent_logs | if length > 20 then .[10:] else . end)' \
           "$status_file" > "$temp_file" && mv "$temp_file" "$status_file"
    else
        jq -n --arg comp "$component" --arg stat "$status" --arg msg "$message" --arg ts "$timestamp" \
           '{progress: {current: 0, total: 10}, 
             components: {($comp): $stat},
             recent_logs: [{level: ($stat | ascii_upcase), message: $msg, timestamp: $ts}]}' \
           > "$status_file"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_cyan "$INFO [$component] $status: $message"
    fi
}

update_progress() {
    local current="$1"
    local total="$2"
    
    local status_file="$CACHE_DIR/installer_status.json"
    if [[ -f "$status_file" ]]; then
        local temp_file=$(mktemp)
        jq --argjson current "$current" --argjson total "$total" \
           '.progress.current = $current | .progress.total = $total' \
           "$status_file" > "$temp_file" && mv "$temp_file" "$status_file"
    fi
}

start_tui_dashboard() {
    if [[ "$ENABLE_TUI" == "true" ]] && command -v python3 >/dev/null 2>&1; then
        create_tui_dashboard
        
        # Start dashboard in background
        python3 "$CACHE_DIR/tui_dashboard.py" &
        local tui_pid=$!
        echo "$tui_pid" > "$CACHE_DIR/tui_pid"
        
        print_green "$SUCCESS TUI Dashboard started (PID: $tui_pid)"
        sleep 2  # Give dashboard time to initialize
    fi
}

stop_tui_dashboard() {
    if [[ -f "$CACHE_DIR/tui_pid" ]]; then
        local tui_pid=$(cat "$CACHE_DIR/tui_pid")
        kill "$tui_pid" 2>/dev/null || true
        rm -f "$CACHE_DIR/tui_pid"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HOOK SYSTEM INTEGRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_hook_system() {
    update_status "hook_system" "running" "Installing unified hook system"
    
    if [[ ! -d "$HOOKS_SOURCE" ]]; then
        print_red "$ERROR Hook source directory not found: $HOOKS_SOURCE"
        return 1
    fi
    
    # Copy hook system files
    print_cyan "$ARROW Copying hook system files..."
    cp -r "$HOOKS_SOURCE"/* "$HOOKS_TARGET/" 2>/dev/null || {
        print_red "$ERROR Failed to copy hook files"
        return 1
    }
    
    # Make hook scripts executable
    find "$HOOKS_TARGET" -name "*.py" -o -name "*.sh" | xargs chmod +x
    
    # Install Python dependencies for hook system
    local requirements_file="$HOOKS_TARGET/requirements-test.txt"
    if [[ -f "$requirements_file" ]]; then
        print_cyan "$ARROW Installing hook system Python dependencies..."
        python3 -m pip install --user -r "$requirements_file" >/dev/null 2>&1 || {
            print_yellow "$WARNING Some Python dependencies may not have installed properly"
        }
    fi
    
    # Initialize hook system configuration
    local hook_config="$CONFIG_DIR/hook_config.json"
    cat > "$hook_config" << EOF
{
    "version": "3.1",
    "enabled": true,
    "project_root": "$PROJECT_ROOT",
    "agents_dir": "$PROJECT_ROOT/agents",
    "config_dir": "$CONFIG_DIR",
    "cache_dir": "$CACHE_DIR",
    "features": {
        "fuzzy_matching": true,
        "semantic_matching": true,
        "natural_invocation": true,
        "shadowgit": false,
        "learning": true
    },
    "performance": {
        "max_parallel_agents": null,
        "confidence_threshold": 0.7,
        "cache_ttl_seconds": 3600
    }
}
EOF
    
    # Test hook system
    print_cyan "$ARROW Testing hook system initialization..."
    if python3 "$HOOKS_TARGET/claude_unified_hook_system_v2.py" --test-config 2>/dev/null; then
        update_status "hook_system" "completed" "Hook system installed and tested successfully"
        print_green "$SUCCESS Hook system installation completed"
        
        # Update hook status file for TUI
        local hook_status="$CACHE_DIR/hook_status.json"
        jq -n '{
            status: "active",
            active_hooks: ["fuzzy_matching", "semantic_matching", "natural_invocation"],
            performance: {throughput: 0, avg_latency: 0},
            config_path: "'"$hook_config"'"
        }' > "$hook_status"
        
        return 0
    else
        update_status "hook_system" "failed" "Hook system test failed"
        print_red "$ERROR Hook system test failed"
        return 1
    fi
}

test_hook_system() {
    print_cyan "$ARROW Running comprehensive hook system tests..."
    
    local test_script="$HOOKS_TARGET/test_hook_system.py"
    if [[ -f "$test_script" ]]; then
        if python3 "$test_script" --verbose 2>&1 | tee "$LOG_DIR/hook_test.log"; then
            print_green "$SUCCESS Hook system tests passed"
            
            # Extract performance metrics from test output
            local throughput=$(grep -o "throughput: [0-9.]*" "$LOG_DIR/hook_test.log" | cut -d' ' -f2 || echo "0")
            local latency=$(grep -o "avg_latency: [0-9.]*" "$LOG_DIR/hook_test.log" | cut -d' ' -f2 || echo "0")
            
            # Update hook status with performance data
            local hook_status="$CACHE_DIR/hook_status.json"
            jq --argjson throughput "$throughput" --argjson latency "$latency" \
               '.performance.throughput = $throughput | .performance.avg_latency = $latency' \
               "$hook_status" > "${hook_status}.tmp" && mv "${hook_status}.tmp" "$hook_status"
               
            print_green "$SUCCESS Performance: ${throughput} ops/sec, ${latency}ms latency"
            return 0
        else
            print_red "$ERROR Hook system tests failed - check $LOG_DIR/hook_test.log"
            return 1
        fi
    else
        print_yellow "$WARNING Hook test script not found, skipping tests"
        return 0
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STREAMLINED INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_system_requirements() {
    update_status "requirements" "running" "Checking system requirements"
    
    local missing=()
    
    # Essential commands
    for cmd in python3 curl git jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_red "$ERROR Missing required commands: ${missing[*]}"
        print_cyan "$INFO Please install: sudo apt-get install ${missing[*]} # or equivalent"
        update_status "requirements" "failed" "Missing: ${missing[*]}"
        return 1
    fi
    
    # Check Python version
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [[ $(echo "$python_version >= 3.8" | bc 2>/dev/null || echo "1") -eq 0 ]]; then
        print_red "$ERROR Python 3.8+ required, found $python_version"
        return 1
    fi
    
    update_status "requirements" "completed" "All requirements satisfied"
    return 0
}

install_node_and_claude() {
    update_status "claude_core" "running" "Installing Node.js and Claude Code"
    
    # Check if Node.js is already installed
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        print_green "$SUCCESS Node.js already installed: $(node --version)"
    else
        print_cyan "$ARROW Installing Node.js via package manager..."
        
        # Try distro package manager first
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y nodejs npm >/dev/null 2>&1 || {
                print_yellow "$WARNING System package installation failed, trying alternative..."
            }
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y nodejs npm >/dev/null 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm nodejs npm >/dev/null 2>&1
        fi
        
        # Verify installation
        if ! command -v node >/dev/null 2>&1; then
            print_red "$ERROR Node.js installation failed"
            update_status "claude_core" "failed" "Node.js installation failed"
            return 1
        fi
    fi
    
    # Install Claude Code
    print_cyan "$ARROW Installing @anthropic-ai/claude-code..."
    
    # Create npm prefix directory
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
    
    # Install Claude Code
    if npm install -g @anthropic-ai/claude-code 2>/dev/null || \
       "$HOME/.npm-global/bin/npm" install -g @anthropic-ai/claude-code 2>/dev/null; then
        print_green "$SUCCESS Claude Code installed successfully"
    else
        print_red "$ERROR Claude Code installation failed"
        update_status "claude_core" "failed" "Claude Code npm install failed"
        return 1
    fi
    
    # Create claude command symlink
    local claude_bin=$(find "$HOME/.npm-global" -name "cli.js" -path "*claude-code*" 2>/dev/null | head -1)
    if [[ -f "$claude_bin" ]]; then
        ln -sf "$claude_bin" "$LOCAL_BIN/claude" 2>/dev/null || {
            print_yellow "$WARNING Could not create claude symlink in $LOCAL_BIN"
        }
    fi
    
    update_status "claude_core" "completed" "Claude Code installed and configured"
    return 0
}

install_agents_system() {
    update_status "agents" "running" "Installing agent ecosystem"
    
    local agents_source="$PROJECT_ROOT/agents"
    local agents_target="$HOME/agents"
    
    if [[ ! -d "$agents_source" ]]; then
        print_red "$ERROR Agents directory not found: $agents_source"
        update_status "agents" "failed" "Agents source directory not found"
        return 1
    fi
    
    print_cyan "$ARROW Copying agent files..."
    
    # Create target directory and copy agents
    mkdir -p "$agents_target"
    cp -r "$agents_source"/* "$agents_target/" 2>/dev/null || {
        print_red "$ERROR Failed to copy agent files"
        return 1
    }
    
    # Count agents for reporting
    local agent_count=$(find "$agents_target" -name "*.md" -not -name "Template.md" -not -name "TEMPLATE.md" | wc -l)
    
    print_green "$SUCCESS $agent_count agents installed to $agents_target"
    update_status "agents" "completed" "$agent_count agents installed"
    return 0
}

install_monitoring_system() {
    if [[ "$ENABLE_MONITORING" != "true" ]]; then
        return 0
    fi
    
    update_status "monitoring" "running" "Setting up monitoring system"
    
    # Install monitoring dependencies
    print_cyan "$ARROW Installing monitoring dependencies..."
    python3 -m pip install --user psutil >/dev/null 2>&1 || {
        print_yellow "$WARNING Could not install psutil for monitoring"
    }
    
    # Setup monitoring script
    local monitoring_script="$HOOKS_TARGET/monitoring_setup.py"
    if [[ -f "$monitoring_script" ]]; then
        print_cyan "$ARROW Initializing monitoring system..."
        python3 "$monitoring_script" --init >/dev/null 2>&1 || {
            print_yellow "$WARNING Monitoring initialization had issues"
        }
        print_green "$SUCCESS Monitoring system configured"
    fi
    
    update_status "monitoring" "completed" "Monitoring system ready"
    return 0
}

create_launcher_scripts() {
    update_status "launchers" "running" "Creating launcher scripts"
    
    # Main claude launcher with hook integration
    cat > "$LOCAL_BIN/claude-enhanced" << 'EOF'
#!/bin/bash
# Claude Enhanced Launcher with Hook System Integration

CLAUDE_CONFIG_DIR="$HOME/.config/claude"
CLAUDE_HOOKS_DIR="$CLAUDE_CONFIG_DIR/hooks"

# Initialize hook system if available
if [[ -f "$CLAUDE_HOOKS_DIR/claude_unified_hook_system_v2.py" ]]; then
    export CLAUDE_HOOKS_ENABLED="true"
    export CLAUDE_HOOKS_DIR="$CLAUDE_HOOKS_DIR"
fi

# Execute claude with hook system integration
if [[ -x "$HOME/.npm-global/bin/claude" ]]; then
    exec "$HOME/.npm-global/bin/claude" "$@"
elif [[ -x "$HOME/.local/bin/claude" ]]; then
    exec "$HOME/.local/bin/claude" "$@"
else
    echo "Error: Claude binary not found" >&2
    exit 1
fi
EOF
    
    chmod +x "$LOCAL_BIN/claude-enhanced"
    
    # Hook system direct launcher
    if [[ -f "$HOOKS_TARGET/claude_unified_hook_system_v2.py" ]]; then
        cat > "$LOCAL_BIN/claude-hooks" << EOF
#!/bin/bash
# Direct Hook System Launcher
exec python3 "$HOOKS_TARGET/claude_unified_hook_system_v2.py" "\$@"
EOF
        chmod +x "$LOCAL_BIN/claude-hooks"
    fi
    
    update_status "launchers" "completed" "Launcher scripts created"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION ORCHESTRATOR
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_usage() {
    cat << EOF
Claude Streamlined Installer v11.0 - Hook System Integration Edition

Usage: $0 [OPTIONS] [MODE]

Installation Modes:
  minimal     Install only Claude Code core
  standard    Install Claude Code + agents + basic hooks (default)
  full        Install everything including monitoring and TUI
  developer   Full installation with development tools and verbose output

Options:
  --dry-run          Show what would be installed without doing it
  --verbose          Show detailed installation progress
  --force            Force installation even if components exist
  --no-tui           Disable TUI dashboard
  --no-hooks         Skip hook system installation
  --no-monitoring    Skip monitoring system setup
  --help             Show this help message

Examples:
  $0                          # Standard installation
  $0 full --verbose           # Full installation with verbose output
  $0 developer --dry-run      # Preview developer installation
  $0 minimal --no-tui         # Minimal installation without TUI

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                VERBOSE="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --no-tui)
                ENABLE_TUI="false"
                shift
                ;;
            --no-hooks)
                ENABLE_HOOKS="false"
                shift
                ;;
            --no-monitoring)
                ENABLE_MONITORING="false"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            minimal|standard|full|developer)
                INSTALLATION_MODE="$1"
                shift
                ;;
            *)
                print_red "$ERROR Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Enable verbose for developer mode
    if [[ "$INSTALLATION_MODE" == "developer" ]]; then
        VERBOSE="true"
    fi
}

run_installation() {
    local start_time=$(date +%s)
    local total_steps=0
    local current_step=0
    
    # Determine steps based on mode
    case "$INSTALLATION_MODE" in
        minimal)
            total_steps=4
            ;;
        standard)
            total_steps=6
            ;;
        full|developer)
            total_steps=8
            ;;
    esac
    
    update_progress 0 "$total_steps"
    
    print_bold "╭─────────────────────────────────────────────────────────────────────╮"
    print_bold "│ Claude Streamlined Installer v11.0 - Hook System Integration      │"
    print_bold "│ Mode: $INSTALLATION_MODE | TUI: $ENABLE_TUI | Hooks: $ENABLE_HOOKS                      │"
    print_bold "╰─────────────────────────────────────────────────────────────────────╯"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_yellow "$WARNING DRY RUN MODE - No actual installation will occur"
    fi
    
    # Start TUI dashboard
    if [[ "$ENABLE_TUI" == "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        start_tui_dashboard
    fi
    
    # Installation steps
    if [[ "$DRY_RUN" != "true" ]]; then
        # Step 1: System requirements
        ((current_step++))
        update_progress "$current_step" "$total_steps"
        check_system_requirements || exit 1
        
        # Step 2: Core Claude installation
        ((current_step++))
        update_progress "$current_step" "$total_steps"
        install_node_and_claude || exit 1
        
        # Step 3: Agents (standard+)
        if [[ "$INSTALLATION_MODE" != "minimal" ]]; then
            ((current_step++))
            update_progress "$current_step" "$total_steps"
            install_agents_system || exit 1
        fi
        
        # Step 4: Hook system (standard+)
        if [[ "$INSTALLATION_MODE" != "minimal" ]] && [[ "$ENABLE_HOOKS" == "true" ]]; then
            ((current_step++))
            update_progress "$current_step" "$total_steps"
            install_hook_system || exit 1
        fi
        
        # Step 5: Hook system testing (full+)
        if [[ "$INSTALLATION_MODE" == "full" || "$INSTALLATION_MODE" == "developer" ]] && [[ "$ENABLE_HOOKS" == "true" ]]; then
            ((current_step++))
            update_progress "$current_step" "$total_steps"
            test_hook_system || print_yellow "$WARNING Hook system tests had issues"
        fi
        
        # Step 6: Monitoring (full+)
        if [[ "$INSTALLATION_MODE" == "full" || "$INSTALLATION_MODE" == "developer" ]]; then
            ((current_step++))
            update_progress "$current_step" "$total_steps"
            install_monitoring_system || exit 1
        fi
        
        # Step 7: Launchers
        ((current_step++))
        update_progress "$current_step" "$total_steps"
        create_launcher_scripts || exit 1
        
        # Final step
        ((current_step++))
        update_progress "$current_step" "$total_steps"
        update_status "installation" "completed" "Installation finished successfully"
    else
        print_cyan "$INFO DRY RUN: Would install $INSTALLATION_MODE mode with $total_steps steps"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Installation summary
    print_bold ""
    print_bold "╭─────────────────────────────────────────────────────────────────────╮"
    print_bold "│                    INSTALLATION COMPLETE                           │"
    print_bold "╰─────────────────────────────────────────────────────────────────────╯"
    print_green "$SUCCESS Installation completed in ${duration}s"
    print_green "$SUCCESS Mode: $INSTALLATION_MODE"
    print_green "$SUCCESS Components installed:"
    
    case "$INSTALLATION_MODE" in
        minimal)
            print_cyan "  • Claude Code core"
            print_cyan "  • Basic launcher scripts"
            ;;
        standard)
            print_cyan "  • Claude Code core"
            print_cyan "  • Agent ecosystem (74+ agents)"
            print_cyan "  • Unified hook system v3.1"
            print_cyan "  • Enhanced launcher scripts"
            ;;
        full|developer)
            print_cyan "  • Claude Code core"
            print_cyan "  • Agent ecosystem (74+ agents)"
            print_cyan "  • Unified hook system v3.1 with testing"
            print_cyan "  • Real-time monitoring system"
            print_cyan "  • TUI dashboard"
            print_cyan "  • Enhanced launcher scripts"
            ;;
    esac
    
    if [[ "$ENABLE_HOOKS" == "true" ]] && [[ "$INSTALLATION_MODE" != "minimal" ]]; then
        print_bold ""
        print_green "$SUCCESS Hook System Features:"
        print_cyan "  • Fuzzy agent matching"
        print_cyan "  • Semantic task analysis"
        print_cyan "  • Natural language invocation"
        print_cyan "  • Performance monitoring"
        print_cyan "  • Security hardening"
        
        if [[ -f "$CACHE_DIR/hook_status.json" ]]; then
            local hook_data=$(cat "$CACHE_DIR/hook_status.json" 2>/dev/null || echo "{}")
            local throughput=$(echo "$hook_data" | jq -r '.performance.throughput // 0')
            local latency=$(echo "$hook_data" | jq -r '.performance.avg_latency // 0')
            if [[ "$throughput" != "0" ]]; then
                print_cyan "  • Performance: ${throughput} ops/sec, ${latency}ms latency"
            fi
        fi
    fi
    
    print_bold ""
    print_green "$SUCCESS Next Steps:"
    print_cyan "  1. Add $LOCAL_BIN to your PATH if not already present"
    print_cyan "  2. Run: source ~/.bashrc  # or restart terminal"
    if [[ "$INSTALLATION_MODE" != "minimal" ]]; then
        print_cyan "  3. Test: claude-enhanced --help"
        if [[ "$ENABLE_HOOKS" == "true" ]]; then
            print_cyan "  4. Test hooks: claude-hooks --status"
        fi
    else
        print_cyan "  3. Test: claude --help"
    fi
    
    # Stop TUI dashboard
    if [[ "$ENABLE_TUI" == "true" ]]; then
        sleep 3  # Give user time to see results
        stop_tui_dashboard
    fi
    
    print_bold ""
    print_green "$SUCCESS Installation log saved to: $LOG_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Trap cleanup
    trap 'stop_tui_dashboard; exit 1' INT TERM
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Run installation
    run_installation
}

# Execute main function with all arguments
main "$@"