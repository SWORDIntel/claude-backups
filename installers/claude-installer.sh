#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ULTIMATE UNIFIED INSTALLER
# Complete installation solution with all features combined
# Version 4.0 - The One True Installer
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly SCRIPT_VERSION="4.0-ultimate"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the actual project root (parent of installers directory)
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly WORK_DIR="/tmp/claude-install-$$"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# GitHub Configuration
readonly GITHUB_REPO="https://github.com/SWORDIntel/claude-backups"
readonly GITHUB_BRANCH="main"
readonly GITHUB_TOKEN=""  # Optional: Add token for private repos

# Installation paths
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly AGENTS_DIR="$HOME/.local/share/claude/agents"
readonly LOCAL_NODE_DIR="$HOME/.local/node"
readonly LOCAL_NPM_PREFIX="$HOME/.local/npm-global"
readonly CONFIG_DIR="$HOME/.config/claude"

# Installation modes
readonly MODE_QUICK="quick"          # Fast installation, minimal prompts
readonly MODE_FULL="full"            # Complete with all features
readonly MODE_PORTABLE="portable"    # Self-contained installation
readonly MODE_CUSTOM="custom"        # User-selected components

# Feature flags
INSTALL_AGENTS=${INSTALL_AGENTS:-true}
INSTALL_ORCHESTRATION=${INSTALL_ORCHESTRATION:-true}
INSTALL_STATUSLINE=${INSTALL_STATUSLINE:-true}
INSTALL_NODE=${INSTALL_NODE:-auto}
PERMISSION_BYPASS=${PERMISSION_BYPASS:-true}
AUTO_MODE=${AUTO_MODE:-false}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Global variable to store found Claude binary
CLAUDE_BINARY=""
INSTALLATION_MODE=""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { 
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() { 
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

success() { 
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
    echo "[SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

debug() {
    if [ "$VERBOSE" = true ]; then
        printf "${CYAN}[DEBUG]${NC} %s\n" "$1"
        echo "[DEBUG] $1" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

check_requirements() {
    local missing=()
    
    # Check for required commands
    for cmd in curl tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        error "Please install them first"
        return 1
    fi
    
    # Check disk space (need at least 500MB)
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 500000 ]; then
        warn "Low disk space. At least 500MB recommended"
    fi
    
    return 0
}

show_banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___  | |     ___   __| | ___ 
 | |    | |/ _` | | | |/ _` |/ _ \ | |    / _ \ / _` |/ _ \
 | |____| | (_| | |_| | (_| |  __/ | |___| (_) | (_| |  __/
  \_______|_\__,_|\__,_|\__,_|\___|  \_____\___/ \__,_|\___|
                                                           
        Ultimate Unified Installer v4.0 - The One True Installer
EOF
    printf "${NC}\n"
    printf "${GREEN}Features:${NC} Agents | Orchestration | Statusline | Permission Bypass\n"
    printf "${BLUE}Modes:${NC} Quick | Full | Portable | Custom\n\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MODE DETECTION AND SELECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_installation_mode() {
    # Auto-detect best mode based on environment
    
    # Check if running from LiveCD
    if [ -f /cdrom/.disk/info ] || [ -f /run/live/medium/.disk/info ]; then
        log "LiveCD environment detected"
        INSTALLATION_MODE="$MODE_PORTABLE"
        PERMISSION_BYPASS=true
        return 0
    fi
    
    # Check if we have sudo access
    if sudo -n true 2>/dev/null; then
        INSTALLATION_MODE="$MODE_FULL"
    else
        INSTALLATION_MODE="$MODE_QUICK"
    fi
    
    # Check available features
    if [ -d "$SCRIPT_DIR/agents" ]; then
        debug "Local agents directory found"
    fi
    
    if [ -f "$PROJECT_ROOT/orchestration/claude-unified" ]; then
        debug "Unified wrapper template found"
    fi
    
    if [ -f "$PROJECT_ROOT/config/statusline.lua" ]; then
        debug "Statusline configuration found"
    fi
}

select_installation_mode() {
    if [ "$AUTO_MODE" = true ]; then
        detect_installation_mode
        log "Auto-selected mode: $INSTALLATION_MODE"
        return 0
    fi
    
    echo "Select installation mode:"
    echo
    printf "${GREEN}1)${NC} Quick Install - Fast, minimal prompts (recommended)\n"
    printf "${CYAN}2)${NC} Full Install - All features with orchestration\n"
    printf "${MAGENTA}3)${NC} Portable Install - Self-contained, no system changes\n"
    printf "${YELLOW}4)${NC} Custom Install - Choose components\n"
    printf "${RED}5)${NC} Exit\n"
    echo
    
    echo -n "Enter your choice [1-5]: "
    read -r choice
    
    case "$choice" in
        1) INSTALLATION_MODE="$MODE_QUICK" ;;
        2) INSTALLATION_MODE="$MODE_FULL" ;;
        3) INSTALLATION_MODE="$MODE_PORTABLE" ;;
        4) INSTALLATION_MODE="$MODE_CUSTOM" ;;
        5) exit 0 ;;
        *) 
            warn "Invalid choice, using Quick Install"
            INSTALLATION_MODE="$MODE_QUICK"
            ;;
    esac
}

configure_custom_installation() {
    echo "Select components to install:"
    echo
    
    echo -n "Install Claude Agents? [Y/n]: "
    read -r response
    [[ "$response" =~ ^[Nn]$ ]] && INSTALL_AGENTS=false
    
    echo -n "Install Orchestration System? [Y/n]: "
    read -r response
    [[ "$response" =~ ^[Nn]$ ]] && INSTALL_ORCHESTRATION=false
    
    echo -n "Install Neovim Statusline? [Y/n]: "
    read -r response
    [[ "$response" =~ ^[Nn]$ ]] && INSTALL_STATUSLINE=false
    
    echo -n "Enable Permission Bypass (LiveCD)? [Y/n]: "
    read -r response
    [[ "$response" =~ ^[Nn]$ ]] && PERMISSION_BYPASS=false
    
    echo
    log "Custom configuration set"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping agent installation"
        return 0
    fi
    
    log "Installing Claude agents..."
    
    # Create agents directory
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$WORK_DIR"
    
    # Method 1: Try local agents first
    if [ -d "$PROJECT_ROOT/agents" ]; then
        log "Found local agents directory"
        cp -r "$PROJECT_ROOT/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        if [ "$agent_count" -gt 0 ]; then
            success "Installed $agent_count agents from local directory"
            return 0
        fi
    fi
    
    cd "$WORK_DIR"
    
    # Method 2: Git clone (if git available)
    if command -v git &> /dev/null; then
        log "Cloning agents from GitHub..."
        if git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO" repo 2>/dev/null; then
            cd repo
            git sparse-checkout set agents 2>/dev/null || true
            
            if [ -d "agents" ]; then
                cp -r agents/* "$AGENTS_DIR/" 2>/dev/null || true
                local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
                success "Downloaded $agent_count agents from GitHub"
                return 0
            fi
        fi
    fi
    
    # Method 3: Download as archive
    log "Downloading repository archive..."
    local archive_url="${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.tar.gz"
    
    if command -v wget &> /dev/null; then
        wget -q "$archive_url" -O repo.tar.gz 2>/dev/null || true
    elif command -v curl &> /dev/null; then
        curl -fsSL "$archive_url" -o repo.tar.gz 2>/dev/null || true
    fi
    
    if [ -f "repo.tar.gz" ]; then
        tar -xzf repo.tar.gz 2>/dev/null || true
        local repo_dir=$(find . -maxdepth 1 -type d -name "*claude*" 2>/dev/null | head -1)
        
        if [ -n "$repo_dir" ] && [ -d "$repo_dir/agents" ]; then
            cp -r "$repo_dir/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
            local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
            success "Downloaded $agent_count agents from GitHub archive"
            return 0
        fi
    fi
    
    # Method 4: Create minimal sample agents
    warn "Could not download agents from GitHub, creating sample agents..."
    create_sample_agents
    return 0
}

create_sample_agents() {
    cat > "$AGENTS_DIR/Director.md" << 'EOF'
---
uuid: director-001
name: Director
role: Strategic Command and Control
tools:
  - Task
proactive_triggers:
  - multi_step_project
  - strategic_planning
---

# Director Agent
Strategic project orchestration and task delegation
EOF

    cat > "$AGENTS_DIR/Security.md" << 'EOF'
---
uuid: security-001
name: Security
role: Security Analysis
tools:
  - Task
proactive_triggers:
  - security_concern
  - vulnerability_detected
---

# Security Agent
Security analysis and vulnerability assessment
EOF

    cat > "$AGENTS_DIR/Testbed.md" << 'EOF'
---
uuid: testbed-001
name: Testbed
role: Testing and QA
tools:
  - Task
proactive_triggers:
  - new_code
  - test_needed
---

# Testbed Agent
Test creation and quality assurance
EOF

    success "Created 3 sample agents"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION SYSTEM DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_orchestration_bridge() {
    if [ "$INSTALL_ORCHESTRATION" != true ]; then
        debug "Skipping orchestration deployment"
        return 0
    fi
    
    log "Deploying orchestration bridge..."
    
    for location in "$SCRIPT_DIR" "$HOME/.local/bin" "$USER_BIN_DIR"; do
        mkdir -p "$location" 2>/dev/null || true
        
        cat > "$location/claude-orchestration-bridge.py" << 'ORCHESTRATION_BRIDGE'
#!/usr/bin/env python3
"""
Claude Orchestration Bridge - Enhanced with Permission Bypass
Bridges Claude Code with the Python Tandem Orchestration System
"""

import os
import sys
import json
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class OrchestrationBridge:
    def __init__(self):
        self.agents_dir = Path(os.environ.get('CLAUDE_AGENTS_DIR', 
                                             Path.home() / '.local' / 'share' / 'claude' / 'agents'))
        self.orchestrator_path = self.agents_dir / 'src' / 'python' / 'production_orchestrator.py'
        self.claude_binary = self.find_claude_binary()
        self.permission_bypass = os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true'
        
    def find_claude_binary(self) -> Optional[str]:
        """Find the actual Claude binary"""
        search_paths = [
            Path.home() / '.local' / 'npm-global' / 'bin' / 'claude.original',
            Path.home() / '.local' / 'bin' / 'claude.original',
            Path('/usr/local/bin/claude.original'),
        ]
        
        for path in search_paths:
            if path.exists() and path.is_file():
                return str(path)
        
        # Try to find via which
        try:
            result = subprocess.run(['which', 'claude.original'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return os.environ.get('CLAUDE_BINARY')
    
    def analyze_task(self, task_text: str) -> Dict:
        """Analyze task for orchestration opportunities"""
        patterns = {
            'multi_agent': [
                r'create.*and.*test',
                r'build.*deploy',
                r'design.*implement',
                r'complete.*project',
                r'full.*development',
            ],
            'agents_needed': []
        }
        
        # Detect patterns
        for pattern in patterns['multi_agent']:
            if re.search(pattern, task_text, re.IGNORECASE):
                return self.suggest_workflow(task_text)
        
        return {'orchestrate': False}
    
    def suggest_workflow(self, task_text: str) -> Dict:
        """Suggest appropriate workflow based on task"""
        workflows = {
            'development': ['architect', 'constructor', 'testbed', 'linter'],
            'security': ['security', 'securitychaosagent', 'patcher'],
            'documentation': ['docgen', 'tui'],
            'deployment': ['infrastructure', 'deployer', 'monitor'],
        }
        
        # Simple keyword matching for workflow selection
        task_lower = task_text.lower()
        
        if any(word in task_lower for word in ['create', 'build', 'develop']):
            return {
                'orchestrate': True,
                'workflow': 'development',
                'agents': workflows['development']
            }
        elif any(word in task_lower for word in ['security', 'audit', 'vulnerability']):
            return {
                'orchestrate': True,
                'workflow': 'security',
                'agents': workflows['security']
            }
        
        return {'orchestrate': False}
    
    def run_with_orchestration(self, args: List[str]) -> int:
        """Execute task with orchestration"""
        if self.orchestrator_path.exists():
            print("🚀 Launching Tandem Orchestrator...")
            
            # Pass task to orchestrator
            env = os.environ.copy()
            env['CLAUDE_TASK'] = ' '.join(args)
            
            result = subprocess.run(
                [sys.executable, str(self.orchestrator_path), '--task'] + args,
                env=env
            )
            return result.returncode
        else:
            print("⚠️  Orchestrator not found, falling back to direct Claude")
            return self.run_direct_claude(args)
    
    def run_direct_claude(self, args: List[str]) -> int:
        """Run Claude directly with permission bypass if enabled"""
        if not self.claude_binary:
            print("❌ Claude Code not found!")
            return 1
        
        cmd = [self.claude_binary]
        
        # Add permission bypass if enabled
        if self.permission_bypass and '--dangerously-skip-permissions' not in args:
            cmd.append('--dangerously-skip-permissions')
        
        cmd.extend(args)
        
        result = subprocess.run(cmd)
        return result.returncode
    
    def main(self, args: List[str]) -> int:
        """Main entry point"""
        if not args or '--help' in args:
            print("Claude Orchestration Bridge")
            print("Usage: claude-orchestration-bridge.py [task description]")
            print("\nAnalyzes tasks and suggests orchestration when beneficial")
            return 0
        
        # Analyze the task
        task_text = ' '.join(args)
        analysis = self.analyze_task(task_text)
        
        if analysis.get('orchestrate', False):
            print(f"🔍 Orchestration opportunity detected!")
            print(f"   Workflow: {analysis.get('workflow', 'custom')}")
            print(f"   Agents: {', '.join(analysis.get('agents', []))}")
            
            # For now, return the analysis
            # In production, this would launch the orchestrator
            return self.run_with_orchestration(args)
        else:
            return self.run_direct_claude(args)

if __name__ == '__main__':
    bridge = OrchestrationBridge()
    sys.exit(bridge.main(sys.argv[1:]))
ORCHESTRATION_BRIDGE
        
        chmod +x "$location/claude-orchestration-bridge.py" 2>/dev/null || true
        
        if [ -f "$location/claude-orchestration-bridge.py" ]; then
            success "Orchestration bridge deployed to $location"
            return 0
        fi
    done
    
    warn "Could not deploy orchestration bridge"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODE.JS INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_if_needed() {
    if [ "$INSTALL_NODE" = "false" ]; then
        debug "Skipping Node.js installation"
        return 0
    fi
    
    if command -v node &> /dev/null; then
        log "Node.js found: $(node --version)"
        return 0
    fi
    
    if [ "$INSTALL_NODE" = "auto" ]; then
        log "Node.js not found, installing locally..."
    else
        warn "Node.js not found and installation disabled"
        return 1
    fi
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    local node_version="v20.11.0"
    local node_arch="linux-x64"
    
    # Detect architecture
    case "$(uname -m)" in
        arm64|aarch64) node_arch="linux-arm64" ;;
        x86_64) node_arch="linux-x64" ;;
        *) warn "Unknown architecture: $(uname -m)" ;;
    esac
    
    local node_url="https://nodejs.org/dist/${node_version}/node-${node_version}-${node_arch}.tar.gz"
    
    log "Downloading Node.js ${node_version}..."
    if command -v wget &> /dev/null; then
        wget -q "$node_url" -O node.tar.gz || return 1
    elif command -v curl &> /dev/null; then
        curl -fsSL "$node_url" -o node.tar.gz || return 1
    else
        error "Neither wget nor curl available"
        return 1
    fi
    
    tar -xzf node.tar.gz
    mkdir -p "$LOCAL_NODE_DIR"
    cp -r "node-${node_version}-${node_arch}"/* "$LOCAL_NODE_DIR/"
    
    export PATH="$LOCAL_NODE_DIR/bin:$PATH"
    success "Node.js installed locally"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE CODE INSTALLATION WITH ROBUST RETRY MECHANISMS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_claude_code() {
    log "Installing Claude Code with robust retry mechanisms..."
    
    # Create directories
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Try installation methods in order
    if attempt_npm_installation; then 
        create_wrapper
        return 0
    fi
    
    if attempt_pip_installation; then 
        create_wrapper
        return 0
    fi
    
    if attempt_direct_download; then 
        create_wrapper
        return 0
    fi
    
    if attempt_github_download; then 
        create_wrapper
        return 0
    fi
    
    if attempt_source_installation; then 
        create_wrapper
        return 0
    fi
    
    # Last resort: create minimal stub
    log "All installation methods failed - creating minimal stub"
    create_minimal_stub
}

# Method 1: NPM with comprehensive retry logic
attempt_npm_installation() {
    if ! command -v npm &> /dev/null; then
        debug "NPM not available"
        return 1
    fi
    
    log "Attempting NPM installation with retries..."
    
    mkdir -p "$LOCAL_NPM_PREFIX"
    export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
    export PATH="$LOCAL_NPM_PREFIX/bin:$PATH"
    
    local packages=(
        "@anthropic-ai/claude-code"
        "claude-code" 
        "claude"
        "@anthropic/claude-code"
        "anthropic-claude"
    )
    
    for package in "${packages[@]}"; do
        debug "Trying package: $package"
        
        for attempt in {1..3}; do
            debug "  Attempt $attempt/3..."
            
            if npm install -g "$package" --no-audit --no-fund --prefer-offline 2>/dev/null || \
               npm install -g "$package" --no-audit --no-fund 2>/dev/null || \
               npm install -g "$package" 2>/dev/null; then
                
                if [ -f "$LOCAL_NPM_PREFIX/bin/claude" ]; then
                    mv "$LOCAL_NPM_PREFIX/bin/claude" "$LOCAL_NPM_PREFIX/bin/claude.original"
                    CLAUDE_BINARY="$LOCAL_NPM_PREFIX/bin/claude"
                    success "Claude Code installed via npm ($package)"
                    return 0
                fi
            fi
            
            npm cache clean --force 2>/dev/null || true
            sleep 2
        done
    done
    
    debug "NPM installation failed"
    return 1
}

# Method 2: Pip installation
attempt_pip_installation() {
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        debug "Pip not available"
        return 1
    fi
    
    log "Attempting pip installation with retries..."
    
    local pip_commands=("pip3" "pip")
    local packages=(
        "claude-code"
        "anthropic"
        "claude"
        "anthropic-claude"
        "claude-ai"
    )
    
    for pip_cmd in "${pip_commands[@]}"; do
        if ! command -v "$pip_cmd" &> /dev/null; then continue; fi
        
        debug "Using $pip_cmd..."
        
        for package in "${packages[@]}"; do
            debug "  Trying package: $package"
            
            for attempt in {1..3}; do
                debug "    Attempt $attempt/3..."
                
                if "$pip_cmd" install --user "$package" --no-cache-dir 2>/dev/null || \
                   "$pip_cmd" install --user "$package" --force-reinstall 2>/dev/null || \
                   "$pip_cmd" install --user "$package" 2>/dev/null; then
                    
                    for location in "$HOME/.local/bin/claude" "/usr/local/bin/claude"; do
                        if [ -f "$location" ] && [ -x "$location" ]; then
                            mv "$location" "${location}.original"
                            CLAUDE_BINARY="$location"
                            success "Claude Code installed via pip ($package)"
                            return 0
                        fi
                    done
                fi
                
                sleep 2
            done
        done
    done
    
    debug "Pip installation failed"
    return 1
}

# Additional installation methods follow same pattern...
attempt_direct_download() {
    debug "Attempting direct download installation"
    
    local attempt_count=0
    local max_attempts=3
    
    while [ $attempt_count -lt $max_attempts ]; do
        attempt_count=$((attempt_count + 1))
        log "Direct download attempt $attempt_count/$max_attempts"
        
        # Try different download methods
        local download_urls=(
            "https://github.com/anthropics/claude-code/releases/latest/download/claude-linux-x64"
            "https://api.github.com/repos/anthropics/claude-code/releases/latest"
        )
        
        for url in "${download_urls[@]}"; do
            debug "Trying download from: $url"
            
            local temp_file="$WORK_DIR/claude-download"
            
            # Try wget first
            if command -v wget &> /dev/null; then
                if wget -q --timeout=30 "$url" -O "$temp_file" 2>/dev/null; then
                    if [ -s "$temp_file" ]; then
                        debug "Downloaded via wget"
                        chmod +x "$temp_file"
                        
                        # Test if it's a valid binary
                        if "$temp_file" --version &>/dev/null; then
                            mkdir -p "$USER_BIN_DIR"
                            cp "$temp_file" "$USER_BIN_DIR/claude"
                            CLAUDE_BINARY="$USER_BIN_DIR/claude"
                            success "Claude Code installed via direct download"
                            return 0
                        fi
                    fi
                fi
            fi
            
            # Try curl
            if command -v curl &> /dev/null; then
                if curl -fsSL --max-time 30 "$url" -o "$temp_file" 2>/dev/null; then
                    if [ -s "$temp_file" ]; then
                        debug "Downloaded via curl"
                        chmod +x "$temp_file"
                        
                        # Test if it's a valid binary
                        if "$temp_file" --version &>/dev/null; then
                            mkdir -p "$USER_BIN_DIR"
                            cp "$temp_file" "$USER_BIN_DIR/claude"
                            CLAUDE_BINARY="$USER_BIN_DIR/claude"
                            success "Claude Code installed via direct download"
                            return 0
                        fi
                    fi
                fi
            fi
        done
        
        sleep 2
    done
    
    debug "Direct download failed after $max_attempts attempts"
    return 1
}

attempt_github_download() {
    debug "Attempting GitHub API download"
    
    local attempt_count=0
    local max_attempts=3
    
    while [ $attempt_count -lt $max_attempts ]; do
        attempt_count=$((attempt_count + 1))
        log "GitHub download attempt $attempt_count/$max_attempts"
        
        # Get latest release info
        local api_url="https://api.github.com/repos/anthropics/claude-code/releases/latest"
        local release_info="$WORK_DIR/release.json"
        
        if command -v curl &> /dev/null; then
            if curl -fsSL --max-time 30 "$api_url" -o "$release_info" 2>/dev/null; then
                # Parse JSON to get download URL (basic parsing)
                local download_url=$(grep -o '"browser_download_url":"[^"]*linux[^"]*"' "$release_info" 2>/dev/null | cut -d'"' -f4 | head -1)
                
                if [ -n "$download_url" ]; then
                    debug "Found download URL: $download_url"
                    
                    local temp_file="$WORK_DIR/claude-github"
                    if curl -fsSL --max-time 60 "$download_url" -o "$temp_file" 2>/dev/null; then
                        chmod +x "$temp_file"
                        
                        if "$temp_file" --version &>/dev/null; then
                            mkdir -p "$USER_BIN_DIR"
                            cp "$temp_file" "$USER_BIN_DIR/claude"
                            CLAUDE_BINARY="$USER_BIN_DIR/claude"
                            success "Claude Code installed via GitHub API"
                            return 0
                        fi
                    fi
                fi
            fi
        fi
        
        sleep 2
    done
    
    debug "GitHub download failed after $max_attempts attempts"
    return 1
}

attempt_source_installation() {
    debug "Attempting source installation"
    
    if ! command -v git &> /dev/null; then
        debug "Git not available for source installation"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        debug "npm not available for source installation"
        return 1
    fi
    
    local attempt_count=0
    local max_attempts=2
    
    while [ $attempt_count -lt $max_attempts ]; do
        attempt_count=$((attempt_count + 1))
        log "Source installation attempt $attempt_count/$max_attempts"
        
        local source_dir="$WORK_DIR/claude-source"
        rm -rf "$source_dir" 2>/dev/null || true
        
        # Try different repositories
        local repos=(
            "https://github.com/anthropics/claude-code.git"
            "https://github.com/anthropic-ai/claude-code.git"
        )
        
        for repo in "${repos[@]}"; do
            debug "Cloning from: $repo"
            
            if git clone --depth 1 "$repo" "$source_dir" 2>/dev/null; then
                cd "$source_dir"
                
                # Try to build
                if [ -f package.json ]; then
                    debug "Installing dependencies..."
                    if npm install --no-audit --no-fund 2>/dev/null; then
                        debug "Building..."
                        if npm run build 2>/dev/null; then
                            # Look for built binary
                            local built_binary=""
                            for potential in bin/claude build/claude dist/claude claude; do
                                if [ -f "$potential" ] && [ -x "$potential" ]; then
                                    built_binary="$potential"
                                    break
                                fi
                            done
                            
                            if [ -n "$built_binary" ] && "$built_binary" --version &>/dev/null; then
                                mkdir -p "$USER_BIN_DIR"
                                cp "$built_binary" "$USER_BIN_DIR/claude"
                                CLAUDE_BINARY="$USER_BIN_DIR/claude"
                                success "Claude Code built from source"
                                return 0
                            fi
                        fi
                    fi
                fi
                
                cd "$WORK_DIR"
            fi
        done
        
        sleep 3
    done
    
    debug "Source installation failed after $max_attempts attempts"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WRAPPER CREATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_wrapper() {
    if [ -z "$CLAUDE_BINARY" ]; then
        warn "Claude binary not set, cannot create wrapper"
        return 1
    fi
    
    local wrapper_path="$CLAUDE_BINARY"
    local original_path="${CLAUDE_BINARY}.original"
    
    if [ ! -f "$original_path" ]; then
        warn "Original binary not found at $original_path"
        return 1
    fi
    
    # Determine wrapper type based on features
    if [ "$INSTALL_ORCHESTRATION" = true ] && [ -f "$PROJECT_ROOT/orchestration/claude-unified" ]; then
        log "Creating unified wrapper with orchestration..."
        cp "$PROJECT_ROOT/orchestration/claude-unified" "$wrapper_path"
    elif [ "$PERMISSION_BYPASS" = true ]; then
        log "Creating permission bypass wrapper..."
        create_permission_bypass_wrapper "$wrapper_path" "$original_path"
    else
        log "Creating basic wrapper..."
        create_basic_wrapper "$wrapper_path" "$original_path"
    fi
    
    chmod +x "$wrapper_path"
    success "Wrapper created at $wrapper_path"
    return 0
}

create_permission_bypass_wrapper() {
    local wrapper_path="$1"
    local original_path="$2"
    
    cat > "$wrapper_path" << EOF
#!/bin/bash
# Claude Permission Bypass Wrapper
set -euo pipefail

ORIGINAL_CLAUDE="$original_path"
PERMISSION_BYPASS_ENABLED=\${CLAUDE_PERMISSION_BYPASS:-true}

export CLAUDE_AGENTS_DIR="\$HOME/.local/share/claude/agents"
export CLAUDE_AGENTS_ROOT="\$CLAUDE_AGENTS_DIR"

if [ "\$PERMISSION_BYPASS_ENABLED" = "true" ] && [[ " \$@ " != *" --no-skip-permissions "* ]] && [[ " \$@ " != *" --safe "* ]] && [[ " \$@ " != *" --dangerously-skip-permissions "* ]]; then
    exec "\$ORIGINAL_CLAUDE" --dangerously-skip-permissions "\$@"
else
    args=()
    for arg in "\$@"; do
        if [ "\$arg" != "--no-skip-permissions" ] && [ "\$arg" != "--safe" ]; then
            args+=("\$arg")
        fi
    done
    exec "\$ORIGINAL_CLAUDE" "\${args[@]}"
fi
EOF
}

create_basic_wrapper() {
    local wrapper_path="$1"
    local original_path="$2"
    
    cat > "$wrapper_path" << EOF
#!/bin/bash
# Claude Basic Wrapper
set -euo pipefail

export CLAUDE_AGENTS_DIR="\$HOME/.local/share/claude/agents"
export CLAUDE_AGENTS_ROOT="\$CLAUDE_AGENTS_DIR"

exec "$original_path" "\$@"
EOF
}

create_minimal_stub() {
    log "Creating minimal Claude stub..."
    cat > "$USER_BIN_DIR/claude" << 'MINIMAL_STUB'
#!/bin/bash
# Minimal Claude Stub

export CLAUDE_AGENTS_DIR="$HOME/.local/share/claude/agents"
export CLAUDE_AGENTS_ROOT="$CLAUDE_AGENTS_DIR"
PERMISSION_BYPASS_ENABLED=${CLAUDE_PERMISSION_BYPASS:-true}

CLAUDE_ACTUAL=""
for loc in "$HOME/.local/npm-global/bin/claude.original" "$HOME/.local/bin/claude.original"; do
    if [ -f "$loc" ] && [ -x "$loc" ] && [ "$loc" != "$0" ]; then
        CLAUDE_ACTUAL="$loc"
        break
    fi
done

if [ -n "$CLAUDE_ACTUAL" ]; then
    if [ "$PERMISSION_BYPASS_ENABLED" = "true" ] && [[ " $@ " != *" --no-skip-permissions "* ]]; then
        exec "$CLAUDE_ACTUAL" --dangerously-skip-permissions "$@"
    else
        exec "$CLAUDE_ACTUAL" "$@"
    fi
else
    echo "Claude Code Ultimate Installer Stub v1.0"
    echo "To install: npm install -g @anthropic-ai/claude-code"
    echo ""
    case "$1" in
        --version) echo "1.0.0-stub" ;;
        --help) echo "Usage: claude [options] [command]" ;;
        *) echo "Arguments: $@" ;;
    esac
fi
MINIMAL_STUB
    
    chmod +x "$USER_BIN_DIR/claude"
    CLAUDE_BINARY="$USER_BIN_DIR/claude"
    warn "Minimal stub created - install Claude Code for full functionality"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUSLINE DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_neovim_statusline() {
    if [ "$INSTALL_STATUSLINE" != true ]; then
        debug "Skipping statusline installation"
        return 0
    fi
    
    local statusline_src="$PROJECT_ROOT/config/statusline.lua"
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_lua_dir="$nvim_config_dir/lua"
    
    if [ ! -f "$statusline_src" ]; then
        debug "statusline.lua not found locally"
        return 1
    fi
    
    log "Deploying Neovim statusline..."
    
    mkdir -p "$nvim_lua_dir"
    mkdir -p "$AGENTS_DIR"
    
    cp "$statusline_src" "$nvim_lua_dir/statusline.lua"
    cp "$statusline_src" "$AGENTS_DIR/statusline.lua"
    
    if [ ! -f "$nvim_config_dir/init.lua" ]; then
        cat > "$nvim_config_dir/init.lua" << 'NVIM_INIT'
-- Claude Agent Framework Statusline
vim.env.CLAUDE_AGENTS_ROOT = vim.env.CLAUDE_AGENTS_ROOT or vim.fn.expand("~/.local/share/claude/agents")
package.path = package.path .. ";" .. vim.env.CLAUDE_AGENTS_ROOT .. "/?.lua"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
NVIM_INIT
        success "Created Neovim config with statusline"
    else
        if ! grep -q "statusline.setup()" "$nvim_config_dir/init.lua" 2>/dev/null; then
            cat >> "$nvim_config_dir/init.lua" << 'NVIM_APPEND'

-- Claude Agent Framework Statusline
vim.env.CLAUDE_AGENTS_ROOT = vim.env.CLAUDE_AGENTS_ROOT or vim.fn.expand("~/.local/share/claude/agents")
package.path = package.path .. ";" .. vim.env.CLAUDE_AGENTS_ROOT .. "/?.lua"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
NVIM_APPEND
            success "Updated Neovim config"
        fi
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT SYNC SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_agent_sync() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping agent sync setup (agents not installed)"
        return 0
    fi
    
    log "Setting up agent synchronization..."
    
    # Define paths
    local sync_script="$HOME/sync-agents.sh"
    local source_dir="$SCRIPT_DIR/agents"
    local target_dir="$HOME/agents"
    local log_file="$HOME/agent-sync.log"
    
    # Create sync script
    cat > "$sync_script" << 'EOF'
#!/bin/bash

# Agent synchronization script
# Syncs agents from Documents/Claude/agents to ~/agents every 5 minutes

SOURCE="/home/ubuntu/Documents/Claude/agents"
TARGET="/home/ubuntu/agents"
LOGFILE="/home/ubuntu/agent-sync.log"

# Create timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" >> "$LOGFILE"
}

# Check if source exists
if [ ! -d "$SOURCE" ]; then
    log_message "ERROR: Source directory $SOURCE does not exist"
    exit 1
fi

# Remove existing symlink or directory
if [ -L "$TARGET" ] || [ -d "$TARGET" ]; then
    rm -rf "$TARGET"
    log_message "Removed existing target: $TARGET"
fi

# Create target directory
mkdir -p "$TARGET"

# Sync with rsync for efficiency
if rsync -av --delete "$SOURCE/" "$TARGET/" >> "$LOGFILE" 2>&1; then
    log_message "SUCCESS: Agents synced successfully"
    
    # Count synced files
    MD_COUNT=$(find "$TARGET" -name "*.md" -type f | wc -l)
    log_message "INFO: Synced $MD_COUNT agent definition files"
else
    log_message "ERROR: Sync failed"
    exit 1
fi

# Keep log file manageable (last 1000 lines)
if [ -f "$LOGFILE" ]; then
    tail -n 1000 "$LOGFILE" > "${LOGFILE}.tmp" && mv "${LOGFILE}.tmp" "$LOGFILE"
fi
EOF
    
    # Make sync script executable
    chmod +x "$sync_script"
    
    # Test the sync script once
    if [ -d "$source_dir" ]; then
        log "Running initial agent sync..."
        if "$sync_script"; then
            success "Initial agent sync completed"
        else
            warn "Initial sync failed, but cron job will retry"
        fi
    fi
    
    # Set up cron job
    local cron_line="*/5 * * * * $sync_script >/dev/null 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$sync_script"; then
        debug "Agent sync cron job already exists"
    else
        # Add cron job
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        if [ $? -eq 0 ]; then
            success "Agent sync cron job installed (runs every 5 minutes)"
        else
            warn "Failed to install cron job - you may need to set it up manually"
        fi
    fi
    
    # Create status check command
    cat > "$HOME/.local/bin/claude-sync-status" << 'EOF'
#!/bin/bash
echo "Agent Sync Status:"
echo "=================="
if [ -f "/home/ubuntu/agent-sync.log" ]; then
    echo "Last sync entries:"
    tail -5 /home/ubuntu/agent-sync.log
    echo
    echo "Agent count: $(find ~/agents -name "*.md" -maxdepth 1 2>/dev/null | wc -l) files"
else
    echo "No sync log found"
fi
EOF
    chmod +x "$HOME/.local/bin/claude-sync-status"
    
    log "Created claude-sync-status command for monitoring"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GLOBAL AGENT SYSTEM INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_global_agent_system() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping global agent system (agents not installed)"
        return 0
    fi
    
    log "Installing global agent discovery system..."
    
    # Check for installation scripts
    if [ -f "$SCRIPT_DIR/install-global-agents.sh" ]; then
        debug "Using install-global-agents.sh"
        bash "$SCRIPT_DIR/install-global-agents.sh"
        success "Global agent system installed via script"
    elif [ -f "$PROJECT_ROOT/tools/claude-global-agents-bridge.py" ]; then
        debug "Using claude-global-agents-bridge.py"
        python3 "$PROJECT_ROOT/tools/claude-global-agents-bridge.py" install
        success "Global agent system installed via Python bridge"
    else
        warn "Global agent system scripts not found - skipping"
        return 1
    fi
    
    # Verify installation
    if [ -f "$HOME/.local/share/claude-agents/manifest.json" ]; then
        local agent_count=$(grep -c '"id"' "$HOME/.local/share/claude-agents/manifest.json" 2>/dev/null || echo "0")
        success "Global agent system active with $agent_count agents"
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE.MD GLOBAL SYNC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_claude_md_sync() {
    log "Setting up CLAUDE.md global synchronization..."
    
    # Define paths
    local claude_md_source="$PROJECT_ROOT/CLAUDE.md"
    local claude_md_target="$HOME/.claude/CLAUDE.md"
    local claude_config_dir="$HOME/.claude"
    local sync_script="$HOME/sync-claude-md.sh"
    
    # Create config directory
    mkdir -p "$claude_config_dir"
    
    # Create sync script for CLAUDE.md
    cat > "$sync_script" << 'EOF'
#!/bin/bash
# CLAUDE.md Global Sync Script
set -euo pipefail

SOURCE="/home/ubuntu/Documents/Claude/CLAUDE.md"
TARGET="$HOME/.claude/CLAUDE.md"
LOGFILE="$HOME/claude-md-sync.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# Create target directory if needed
mkdir -p "$(dirname "$TARGET")"

# Check if source exists
if [ ! -f "$SOURCE" ]; then
    log_message "ERROR: Source CLAUDE.md not found at $SOURCE"
    exit 1
fi

# Sync CLAUDE.md
if cp "$SOURCE" "$TARGET" 2>> "$LOGFILE"; then
    log_message "SUCCESS: CLAUDE.md synced to $TARGET"
    
    # Also sync to other common locations
    for dir in "$HOME/.config/claude" "$HOME/.local/share/claude"; do
        if [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null; then
            cp "$SOURCE" "$dir/CLAUDE.md" 2>> "$LOGFILE" || true
        fi
    done
else
    log_message "ERROR: Failed to sync CLAUDE.md"
    exit 1
fi
EOF
    
    chmod +x "$sync_script"
    
    # Initial sync
    bash "$sync_script"
    
    # Add to cron (every 5 minutes, offset by 2 minutes from agent sync)
    local cron_line="*/5 * * * * sleep 120 && $sync_script >/dev/null 2>&1"
    
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -qF "$sync_script"; then
        (crontab -l 2>/dev/null || echo ""; echo "$cron_line") | crontab -
        success "CLAUDE.md cron sync added (runs every 5 minutes)"
    else
        log "CLAUDE.md cron sync already exists"
    fi
    
    # Create status command
    local status_script="$USER_BIN_DIR/claude-md-status"
    cat > "$status_script" << 'EOF'
#!/bin/bash
echo "📋 CLAUDE.md Sync Status"
echo "━━━━━━━━━━━━━━━━━━━━━"
echo "Source: /home/ubuntu/Documents/Claude/CLAUDE.md"
echo "Targets:"
for target in "$HOME/.claude/CLAUDE.md" "$HOME/.config/claude/CLAUDE.md" "$HOME/.local/share/claude/CLAUDE.md"; do
    if [ -f "$target" ]; then
        echo "  ✓ $target ($(ls -lh "$target" | awk '{print $5}'))"
    else
        echo "  ✗ $target (not found)"
    fi
done
echo
echo "Last sync log entries:"
tail -5 "$HOME/claude-md-sync.log" 2>/dev/null || echo "  No log entries yet"
echo
echo "Cron job:"
crontab -l 2>/dev/null | grep "claude-md" || echo "  Not found"
EOF
    
    chmod +x "$status_script"
    
    success "CLAUDE.md global sync configured"
    log "  • Source: $claude_md_source"
    log "  • Synced to: ~/.claude/, ~/.config/claude/, ~/.local/share/claude/"
    log "  • Status: claude-md-status"
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUZZY MATCHING SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_agent_registration() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping agent registration (agents not installed)"
        return 0
    fi
    
    log "Setting up agent registration with auto-discovery..."
    
    # Install the registration script
    if [ -f "$PROJECT_ROOT/tools/register-custom-agents.py" ]; then
        cp "$PROJECT_ROOT/tools/register-custom-agents.py" "$USER_BIN_DIR/register-custom-agents"
        chmod +x "$USER_BIN_DIR/register-custom-agents"
        
        # Run initial registration
        log "Registering all project agents..."
        python3 "$USER_BIN_DIR/register-custom-agents"
        
        # Setup auto-discovery monitoring
        if command -v systemctl &> /dev/null; then
            log "Setting up systemd monitoring service..."
            
            # Copy service file to user systemd directory
            mkdir -p ~/.config/systemd/user/
            if [ -f "$PROJECT_ROOT/config/claude-agent-monitor.service" ]; then
                cp "$PROJECT_ROOT/config/claude-agent-monitor.service" ~/.config/systemd/user/
                
                # Enable and start the service
                systemctl --user daemon-reload
                systemctl --user enable claude-agent-monitor.service 2>/dev/null || true
                systemctl --user start claude-agent-monitor.service 2>/dev/null || true
                
                if systemctl --user is-active claude-agent-monitor.service &> /dev/null; then
                    success "Auto-discovery monitor active"
                    debug "New agents will be automatically registered"
                else
                    warn "Monitor service not started (manual start may be required)"
                fi
            else
                warn "Service file not found - using cron fallback"
            fi
        fi
        
        # Fallback: Add to cron if systemd not available
        if ! systemctl --user is-active claude-agent-monitor.service &> /dev/null 2>&1; then
            log "Setting up cron-based auto-discovery..."
            (crontab -l 2>/dev/null | grep -v "register-custom-agents" ; \
             echo "*/5 * * * * /usr/bin/python3 $USER_BIN_DIR/register-custom-agents --check && /usr/bin/python3 $USER_BIN_DIR/register-custom-agents >/dev/null 2>&1") | crontab -
            success "Cron job added for agent auto-discovery"
        fi
        
        # Create convenience commands
        cat > "$USER_BIN_DIR/claude-agent-register" << 'EOF'
#!/bin/bash
# Manual agent registration
/usr/bin/python3 ~/.local/bin/register-custom-agents "$@"
EOF
        chmod +x "$USER_BIN_DIR/claude-agent-register"
        
        cat > "$USER_BIN_DIR/claude-agent-monitor" << 'EOF'
#!/bin/bash
# Check agent monitor status
if systemctl --user is-active claude-agent-monitor.service &> /dev/null; then
    echo "✅ Agent monitor is active"
    systemctl --user status claude-agent-monitor.service --no-pager
else
    echo "❌ Agent monitor is not running"
    echo "Start with: systemctl --user start claude-agent-monitor.service"
fi
EOF
        chmod +x "$USER_BIN_DIR/claude-agent-monitor"
        
        success "Agent registration system installed with auto-discovery"
        echo "  • Registry: ~/.config/claude/project-agents.json"
        echo "  • Monitor status: claude-agent-monitor"
        echo "  • Manual register: claude-agent-register"
        echo "  • Auto-discovery: Enabled (checks every 30s)"
        
    else
        warn "Registration script not found - skipping"
        return 1
    fi
}

install_fuzzy_matching() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping fuzzy matching (agents not installed)"
        return 0
    fi
    
    log "Installing ML-style fuzzy matching system..."
    
    # Define target directories
    local lib_dir="$HOME/.local/lib/claude-agents"
    local bin_dir="$USER_BIN_DIR"
    local config_dir="$HOME/.config/claude"
    
    # Create directories
    mkdir -p "$lib_dir" "$config_dir"
    
    # Install semantic matcher library
    if [ -f "$PROJECT_ROOT/tools/agent-semantic-matcher.py" ]; then
        cp "$PROJECT_ROOT/tools/agent-semantic-matcher.py" "$lib_dir/agent_semantic_matcher.py"
        debug "Installed semantic matcher to $lib_dir"
    else
        warn "Semantic matcher not found - using basic matching only"
        return 1
    fi
    
    # Install fuzzy matcher integration
    if [ -f "$PROJECT_ROOT/tools/claude-fuzzy-agent-matcher.py" ]; then
        cp "$PROJECT_ROOT/tools/claude-fuzzy-agent-matcher.py" "$lib_dir/claude_fuzzy_agent_matcher.py"
        debug "Installed fuzzy matcher integration"
    fi
    
    # Copy pattern configuration
    if [ -f "$PROJECT_ROOT/config/agent-invocation-patterns.yaml" ]; then
        cp "$PROJECT_ROOT/config/agent-invocation-patterns.yaml" "$config_dir/agent-invocation-patterns.yaml"
        debug "Installed invocation patterns to $config_dir"
    fi
    
    # Create fuzzy-match command for testing
    cat > "$bin_dir/claude-fuzzy-match" << 'EOF'
#!/usr/bin/env python3
"""Test fuzzy matching for Claude agent invocation"""
import sys
sys.path.insert(0, '/home/ubuntu/.local/lib/claude-agents')
from agent_semantic_matcher import EnhancedAgentMatcher

if __name__ == "__main__":
    matcher = EnhancedAgentMatcher()
    
    if len(sys.argv) > 1:
        user_input = ' '.join(sys.argv[1:])
    else:
        user_input = input("Enter request: ")
        
    results = matcher.match(user_input)
    command = matcher.get_invocation_command(user_input)
    
    print(f"\n🎯 Top Agents: {', '.join([a for a, _ in list(results['semantic_agents'].items())[:3]])}")
    print(f"📊 Confidence: {results['confidence']:.2f}")
    
    if command:
        print(f"💡 Command: {command}")
EOF
    chmod +x "$bin_dir/claude-fuzzy-match"
    
    # Create Python import helper for Claude
    cat > "$lib_dir/__init__.py" << 'EOF'
"""Claude Agent Fuzzy Matching Library"""
from .agent_semantic_matcher import SemanticAgentMatcher, EnhancedAgentMatcher
from .claude_fuzzy_agent_matcher import ClaudeFuzzyMatcher, fuzzy_match_agents, get_agent_command

__all__ = [
    'SemanticAgentMatcher',
    'EnhancedAgentMatcher', 
    'ClaudeFuzzyMatcher',
    'fuzzy_match_agents',
    'get_agent_command'
]
EOF
    
    # Add to Python path in bashrc
    if ! grep -q "PYTHONPATH.*claude-agents" "$HOME/.bashrc" 2>/dev/null; then
        echo "export PYTHONPATH=\"\$HOME/.local/lib/claude-agents:\$PYTHONPATH\"" >> "$HOME/.bashrc"
        debug "Added fuzzy matching library to PYTHONPATH"
    fi
    
    success "Fuzzy matching system installed"
    log "  • Semantic matcher: $lib_dir/agent_semantic_matcher.py"
    log "  • Pattern config: $config_dir/agent-invocation-patterns.yaml"
    log "  • Test command: claude-fuzzy-match"
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_environment() {
    log "Setting up environment..."
    
    # Export variables for current session
    export CLAUDE_AGENTS_DIR="$AGENTS_DIR"
    export CLAUDE_AGENTS_ROOT="$AGENTS_DIR"
    export PATH="$USER_BIN_DIR:$LOCAL_NODE_DIR/bin:$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Update shell configuration
    local shell_rc="$HOME/.bashrc"
    [ -n "${ZSH_VERSION:-}" ] && shell_rc="$HOME/.zshrc"
    
    # Add PATH
    if ! grep -q "$USER_BIN_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$shell_rc"
    fi
    
    if [ -d "$LOCAL_NODE_DIR" ] && ! grep -q "$LOCAL_NODE_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$LOCAL_NODE_DIR/bin:\$PATH\"" >> "$shell_rc"
    fi
    
    if [ -d "$LOCAL_NPM_PREFIX" ] && ! grep -q "$LOCAL_NPM_PREFIX" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$LOCAL_NPM_PREFIX/bin:\$PATH\"" >> "$shell_rc"
    fi
    
    # Add agent environment variables
    if ! grep -q "CLAUDE_AGENTS_DIR" "$shell_rc" 2>/dev/null; then
        echo "export CLAUDE_AGENTS_DIR=\"$AGENTS_DIR\"" >> "$shell_rc"
        echo "export CLAUDE_AGENTS_ROOT=\"$AGENTS_DIR\"" >> "$shell_rc"
    fi
    
    # Add aliases
    if ! grep -q "alias claude-safe" "$shell_rc" 2>/dev/null; then
        echo "# Claude aliases" >> "$shell_rc"
        echo "alias claude-safe='claude --no-skip-permissions'" >> "$shell_rc"
        echo "alias claude-normal='claude --no-skip-permissions'" >> "$shell_rc"
    fi
    
    success "Environment configured"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS AND REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo
    printf "${BOLD}${CYAN}Installation Status${NC}\n"
    echo "═══════════════════════════════════════"
    
    # Claude Code
    printf "${BOLD}Claude Code:${NC} "
    if [ -n "$CLAUDE_BINARY" ] && [ -f "$CLAUDE_BINARY" ]; then
        printf "${GREEN}✓ Installed${NC} at $CLAUDE_BINARY\n"
        if [ "$PERMISSION_BYPASS" = true ]; then
            printf "  ${YELLOW}Permission bypass: ENABLED${NC}\n"
        fi
        if [ "$INSTALL_ORCHESTRATION" = true ]; then
            printf "  ${CYAN}Orchestration: ENABLED${NC}\n"
        fi
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Agents
    printf "${BOLD}Agents:${NC} "
    if [ -d "$AGENTS_DIR" ]; then
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        printf "${GREEN}✓ $agent_count agents${NC} in $AGENTS_DIR\n"
        
        # Check sync status
        if [ -f "$HOME/sync-agents.sh" ]; then
            printf "  ${CYAN}Sync: ENABLED${NC} (every 5 minutes to ~/agents)\n"
            if crontab -l 2>/dev/null | grep -q "sync-agents.sh"; then
                printf "  ${GREEN}Cron job: ACTIVE${NC}\n"
            else
                printf "  ${YELLOW}Cron job: NOT FOUND${NC}\n"
            fi
        else
            printf "  ${YELLOW}Sync: NOT CONFIGURED${NC}\n"
        fi
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Orchestration
    printf "${BOLD}Orchestration:${NC} "
    if [ -f "$PROJECT_ROOT/orchestration/claude-orchestration-bridge.py" ] || [ -f "$USER_BIN_DIR/claude-orchestration-bridge.py" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
    else
        printf "${YELLOW}✗ Not installed${NC}\n"
    fi
    
    # Statusline
    printf "${BOLD}Neovim Statusline:${NC} "
    if [ -f "$HOME/.config/nvim/lua/statusline.lua" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
    else
        printf "${YELLOW}✗ Not installed${NC}\n"
    fi
    
    # Fuzzy Matching
    printf "${BOLD}Fuzzy Matching:${NC} "
    if [ -f "$HOME/.local/lib/claude-agents/agent_semantic_matcher.py" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
        printf "  ${CYAN}ML-style semantic matching: ENABLED${NC}\n"
        if [ -f "$USER_BIN_DIR/claude-fuzzy-match" ]; then
            printf "  ${GREEN}Test command: claude-fuzzy-match${NC}\n"
        fi
    else
        printf "${GRAY}Not configured${NC}\n"
    fi
    
    # Node.js
    printf "${BOLD}Node.js:${NC} "
    if command -v node &> /dev/null; then
        printf "${GREEN}✓ $(node --version)${NC}\n"
    else
        printf "${YELLOW}✗ Not found${NC}\n"
    fi
    
    echo
    printf "${BOLD}${CYAN}Commands:${NC}\n"
    echo "  claude         - Launch Claude Code"
    if [ "$PERMISSION_BYPASS" = true ]; then
        echo "  claude-safe    - Launch without permission bypass"
        echo "  claude-normal  - Same as claude-safe"
    fi
    echo
    printf "${BOLD}${CYAN}Paths:${NC}\n"
    echo "  Agents:     $AGENTS_DIR"
    echo "  Config:     $CONFIG_DIR"
    echo "  Binaries:   $USER_BIN_DIR"
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FLOW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_installation() {
    # Create necessary directories
    mkdir -p "$HOME/Documents/Claude" 2>/dev/null || true
    mkdir -p "$WORK_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Configure based on mode
    case "$INSTALLATION_MODE" in
        "$MODE_QUICK")
            INSTALL_AGENTS=true
            INSTALL_ORCHESTRATION=false
            INSTALL_STATUSLINE=false
            PERMISSION_BYPASS=true
            ;;
        "$MODE_FULL")
            INSTALL_AGENTS=true
            INSTALL_ORCHESTRATION=true
            INSTALL_STATUSLINE=true
            PERMISSION_BYPASS=true
            ;;
        "$MODE_PORTABLE")
            INSTALL_AGENTS=true
            INSTALL_ORCHESTRATION=true
            INSTALL_STATUSLINE=false
            PERMISSION_BYPASS=true
            ;;
        "$MODE_CUSTOM")
            configure_custom_installation
            ;;
    esac
    
    log "Starting installation (Mode: $INSTALLATION_MODE)..."
    
    # Step 1: Install Node.js if needed
    install_node_if_needed
    echo
    
    # Step 2: Install agents
    install_agents
    echo
    
    # Step 3: Deploy orchestration bridge
    deploy_orchestration_bridge
    echo
    
    # Step 4: Install Claude Code
    install_claude_code
    echo
    
    # Step 5: Deploy statusline
    deploy_neovim_statusline
    echo
    
    # Step 6: Setup environment
    setup_environment
    
    # Step 7: Setup agent synchronization
    setup_agent_sync
    
    # Step 8: Install global agent system
    install_global_agent_system
    
    # Step 9: Setup CLAUDE.md global sync
    setup_claude_md_sync
    
    # Step 10: Install fuzzy matching system
    install_fuzzy_matching
    
    # Step 11: Setup agent registration with auto-discovery
    setup_agent_registration
    
    # Show final status
    show_status
    
    success "Installation complete!"
    echo
    echo "To complete setup:"
    echo "  1. Run: source ~/.bashrc"
    echo "  2. Launch Claude: claude"
    echo "  3. Check agent sync: claude-sync-status"
    echo "  4. Check CLAUDE.md sync: claude-md-status"
    echo "  5. List global agents: claude-agent list"
    echo "  6. Test fuzzy matching: claude-fuzzy-match 'optimize database'"
    echo
    
    if [ "$INSTALL_ORCHESTRATION" = true ]; then
        printf "${CYAN}${BOLD}Orchestration System:${NC} Integrated\n"
        echo "  • Multi-agent workflow detection"
        echo "  • Automatic task routing"
        echo "  • Python Tandem Orchestrator support"
        echo
    fi
    
    if [ "$PERMISSION_BYPASS" = true ]; then
        printf "${YELLOW}${BOLD}Permission Bypass:${NC} Enabled by default\n"
        echo "  • Use 'claude-safe' to disable"
        echo "  • Perfect for LiveCD environments"
        echo
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick|-q)
                INSTALLATION_MODE="$MODE_QUICK"
                AUTO_MODE=true
                ;;
            --full|-f)
                INSTALLATION_MODE="$MODE_FULL"
                AUTO_MODE=true
                ;;
            --portable|-p)
                INSTALLATION_MODE="$MODE_PORTABLE"
                AUTO_MODE=true
                ;;
            --custom|-c)
                INSTALLATION_MODE="$MODE_CUSTOM"
                AUTO_MODE=false
                ;;
            --auto|-a)
                AUTO_MODE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --no-agents)
                INSTALL_AGENTS=false
                ;;
            --no-orchestration)
                INSTALL_ORCHESTRATION=false
                ;;
            --no-statusline)
                INSTALL_STATUSLINE=false
                ;;
            --no-permission-bypass)
                PERMISSION_BYPASS=false
                ;;
            --help|-h)
                show_banner
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --quick, -q          Quick installation (minimal)"
                echo "  --full, -f           Full installation (all features)"
                echo "  --portable, -p       Portable installation"
                echo "  --custom, -c         Custom component selection"
                echo "  --auto, -a           Automatic mode (no prompts)"
                echo "  --dry-run            Test without making changes"
                echo "  --verbose, -v        Verbose output"
                echo "  --no-agents          Skip agent installation"
                echo "  --no-orchestration   Skip orchestration system"
                echo "  --no-statusline      Skip statusline installation"
                echo "  --no-permission-bypass  Disable permission bypass"
                echo "  --help, -h           Show this help"
                echo
                echo "Examples:"
                echo "  $0 --quick           # Quick install with defaults"
                echo "  $0 --full --auto     # Full install, no prompts"
                echo "  $0 --custom          # Choose components"
                echo
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                ;;
        esac
        shift
    done
    
    # Show banner
    show_banner
    
    # Check requirements
    if ! check_requirements; then
        error "Requirements check failed"
        exit 1
    fi
    
    # Select installation mode if not set
    if [ -z "$INSTALLATION_MODE" ]; then
        if [ "$AUTO_MODE" = true ]; then
            detect_installation_mode
        else
            select_installation_mode
        fi
    fi
    
    # Run installation
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN MODE - No changes will be made"
        log "Would install with mode: $INSTALLATION_MODE"
        log "  Agents: $INSTALL_AGENTS"
        log "  Orchestration: $INSTALL_ORCHESTRATION"
        log "  Statusline: $INSTALL_STATUSLINE"
        log "  Permission Bypass: $PERMISSION_BYPASS"
    else
        run_installation
    fi
}

# Run main function
main "$@"