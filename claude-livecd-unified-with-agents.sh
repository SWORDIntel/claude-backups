#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ALL-IN-ONE INSTALLER WITH GITHUB AGENTS
# Complete installation without external dependencies
# Version 3.1 - LiveCD optimized with DEFAULT permission bypass
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="3.1-all-in-one"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="/tmp/claude-install-$$"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# GitHub Configuration - UPDATE THIS WITH YOUR REPO
readonly GITHUB_REPO="https://github.com/SWORDIntel/claude-backups"  # CHANGE THIS
readonly GITHUB_BRANCH="main"

# Installation paths
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly AGENTS_DIR="$HOME/.local/share/claude/agents"
readonly LOCAL_NODE_DIR="$HOME/.local/node"
readonly LOCAL_NPM_PREFIX="$HOME/.local/npm-global"

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

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

show_banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___  | |     ___   __| | ___  
 | |    | |/ _` | | | |/ _` |/ _ \ | |    / _ \ / _` |/ _ \ 
 | |____| | (_| | |_| | (_| |  __/ | |___| (_) | (_| |  __/
  \_______|_\__,_|\__,_|\__,_|\___|  \_____\___/ \__,_|\___|
                                                           
    All-in-One Installer v3.1 - LiveCD Optimized Edition
           WITH DEFAULT PERMISSION BYPASS
EOF
    printf "${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT INSTALLATION FROM GITHUB
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents_from_github() {
    log "Installing agents from GitHub repository..."
    
    # Create agents directory
    mkdir -p "$AGENTS_DIR"
    mkdir -p "$WORK_DIR"
    
    # Method 1: Try local agents first
    if [ -d "$SCRIPT_DIR/agents" ]; then
        log "Found local agents directory"
        cp -r "$SCRIPT_DIR/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
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
    
    # Method 4: Create sample agents if download fails
    warn "Could not download agents from GitHub, creating sample agents..."
    create_sample_agents
    return 0
}

create_sample_agents() {
    cat > "$AGENTS_DIR/Director.md" << 'EOF'
# Director Agent
## Role
Project orchestration and task delegation

## Capabilities
- Task breakdown and assignment
- Progress monitoring
- Resource coordination
EOF

    cat > "$AGENTS_DIR/Security.md" << 'EOF'
# Security Agent
## Role
Security analysis and vulnerability assessment

## Capabilities
- Code security review
- Vulnerability scanning
- Security best practices
EOF

    cat > "$AGENTS_DIR/Testing.md" << 'EOF'
# Testing Agent
## Role
Test creation and quality assurance

## Capabilities
- Unit test generation
- Integration testing
- Test coverage analysis
EOF

    success "Created 3 sample agents"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NEOVIM STATUSLINE DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_neovim_statusline() {
    local statusline_src="$SCRIPT_DIR/statusline.lua"
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_lua_dir="$nvim_config_dir/lua"
    
    # Check if statusline.lua exists locally
    if [ ! -f "$statusline_src" ]; then
        # Try to download from GitHub
        log "Downloading statusline.lua from GitHub..."
        local statusline_url="${GITHUB_REPO}/raw/${GITHUB_BRANCH}/statusline.lua"
        
        mkdir -p "$WORK_DIR"
        if command -v wget &> /dev/null; then
            wget -q "$statusline_url" -O "$WORK_DIR/statusline.lua" 2>/dev/null || true
        elif command -v curl &> /dev/null; then
            curl -fsSL "$statusline_url" -o "$WORK_DIR/statusline.lua" 2>/dev/null || true
        fi
        
        if [ -f "$WORK_DIR/statusline.lua" ]; then
            statusline_src="$WORK_DIR/statusline.lua"
        else
            warn "statusline.lua not found"
            return 1
        fi
    fi
    
    log "Deploying Neovim statusline..."
    
    # Create directories
    mkdir -p "$nvim_lua_dir"
    mkdir -p "$AGENTS_DIR"
    
    # Copy statusline to both locations
    cp "$statusline_src" "$nvim_lua_dir/statusline.lua"
    cp "$statusline_src" "$AGENTS_DIR/statusline.lua"
    
    # Create/update init.lua
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
# ORCHESTRATION BRIDGE DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_orchestration_bridge() {
    log "Deploying orchestration bridge..."
    
    # Deploy to both common installation locations
    local bridge_locations=(
        "$HOME/.local/npm-global/bin/claude-orchestration-bridge.py"
        "$HOME/.local/bin/claude-orchestration-bridge.py"
        "$USER_BIN_DIR/claude-orchestration-bridge.py"
    )
    
    # Create the orchestration bridge script
    for location in "${bridge_locations[@]}"; do
        # Ensure directory exists
        mkdir -p "$(dirname "$location")"
        
        cat > "$location" << 'ORCHESTRATION_BRIDGE'
#!/usr/bin/env python3
"""
Claude Code Orchestration Bridge - LiveCD Integration
Seamlessly integrates Python Tandem Orchestration with Claude Code workflows
while maintaining permission bypass for LiveCD environments
"""

import asyncio
import sys
import os
import json
import time
import subprocess
from pathlib import Path

# Add the Python orchestration system to path
SCRIPT_DIR = Path(__file__).parent
AGENTS_DIR = os.environ.get('CLAUDE_AGENTS_DIR', Path.home() / '.local/share/claude/agents')
PYTHON_DIR = AGENTS_DIR / 'src' / 'python'
sys.path.insert(0, str(PYTHON_DIR))

try:
    from production_orchestrator import ProductionOrchestrator, StandardWorkflows, CommandSet, CommandStep, CommandType, ExecutionMode, Priority
    from agent_registry import get_registry
    ORCHESTRATOR_AVAILABLE = True
except ImportError:
    ORCHESTRATOR_AVAILABLE = False

class ClaudeOrchestrationBridge:
    """Bridge between Claude Code and the Tandem Orchestrator with LiveCD integration"""
    
    def __init__(self):
        self.orchestrator = None
        self.permission_bypass = os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true'
        self.claude_binary = self._find_claude_binary()
        self.pattern_triggers = {
            # Development workflow triggers
            "create": ["architect", "constructor"],
            "build": ["constructor", "testbed"],
            "test": ["testbed", "debugger"],
            "fix": ["debugger", "patcher"],
            "deploy": ["deployer", "monitor"],
            "document": ["docgen", "tui"],
            "review": ["linter", "security"],
            "optimize": ["optimizer", "monitor"],
            
            # Multi-agent workflow triggers
            "full development": "dev_cycle",
            "complete project": "dev_cycle", 
            "security audit": "security_audit",
            "documentation": "document_generation",
            "code review": ["linter", "security", "testbed"],
            
            # Agent coordination patterns
            "design and implement": ["architect", "constructor"],
            "test and fix": ["testbed", "debugger", "patcher"],
            "secure and deploy": ["security", "deployer"],
            "document and review": ["docgen", "linter"]
        }
    
    def _find_claude_binary(self):
        """Find the actual Claude binary (not wrapper)"""
        search_paths = [
            os.path.expanduser("~/.local/npm-global/bin/claude.original"),
            os.path.expanduser("~/.local/bin/claude.original"),
            "/usr/local/bin/claude.original",
            os.path.expanduser("~/.local/npm-global/bin/claude"),
            os.path.expanduser("~/.local/bin/claude"),
        ]
        
        for path in search_paths:
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
        
        # Try which command
        try:
            result = subprocess.run(['which', 'claude'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return None
    
    async def initialize(self):
        """Initialize the orchestration system"""
        if not ORCHESTRATOR_AVAILABLE:
            return False
            
        self.orchestrator = ProductionOrchestrator()
        return await self.orchestrator.initialize()
    
    def detect_workflow_intent(self, user_input):
        """Analyze user input to detect if orchestration would be beneficial"""
        user_lower = user_input.lower()
        
        # Check for workflow keywords
        detected_patterns = []
        for trigger, agents in self.pattern_triggers.items():
            if trigger in user_lower:
                detected_patterns.append((trigger, agents))
        
        # Check for multi-agent indicators
        multi_agent_indicators = [
            "and then", "after that", "also", "plus", "in addition",
            "complete", "full", "comprehensive", "entire", "whole"
        ]
        
        has_multi_agent = any(indicator in user_lower for indicator in multi_agent_indicators)
        
        return detected_patterns, has_multi_agent
    
    async def suggest_orchestration(self, user_input, detected_patterns, has_multi_agent):
        """Suggest orchestration enhancements based on detected patterns"""
        if not detected_patterns and not has_multi_agent:
            return None
        
        suggestions = []
        
        # Standard workflow suggestions
        for pattern, agents in detected_patterns:
            if isinstance(agents, str):  # Pre-built workflow
                suggestions.append({
                    "type": "workflow",
                    "name": agents,
                    "description": f"Run {pattern} workflow automatically",
                    "command": f"orchestration:{agents}"
                })
            elif isinstance(agents, list):  # Multi-agent coordination
                suggestions.append({
                    "type": "coordination",
                    "agents": agents,
                    "description": f"Coordinate {', '.join(agents)} for {pattern}",
                    "command": f"coordinate:{','.join(agents)}"
                })
        
        # Multi-agent suggestion for complex tasks
        if has_multi_agent and len(detected_patterns) > 1:
            suggestions.append({
                "type": "workflow",
                "name": "dev_cycle",
                "description": "Run complete development workflow",
                "command": "orchestration:dev_cycle"
            })
        
        return suggestions
    
    async def execute_orchestration_command(self, command):
        """Execute orchestration command and return results"""
        if not self.orchestrator:
            return {"error": "Orchestrator not initialized"}
        
        try:
            if command.startswith("orchestration:"):
                workflow_name = command.split(":", 1)[1]
                
                if workflow_name == "dev_cycle":
                    workflow = StandardWorkflows.create_development_workflow()
                elif workflow_name == "security_audit":
                    workflow = StandardWorkflows.create_security_audit_workflow()
                elif workflow_name == "document_generation":
                    workflow = StandardWorkflows.create_document_generation_workflow()
                else:
                    return {"error": f"Unknown workflow: {workflow_name}"}
                
                result = await self.orchestrator.execute_command_set(workflow)
                return result
            
            elif command.startswith("coordinate:"):
                agent_names = command.split(":", 1)[1].split(",")
                
                # Create a simple coordination workflow
                steps = []
                for i, agent in enumerate(agent_names):
                    steps.append(CommandStep(
                        id=f"step_{i}",
                        agent=agent.strip(),
                        action="coordinate",
                        payload={"context": "User requested coordination"}
                    ))
                
                workflow = CommandSet(
                    name=f"Coordination: {', '.join(agent_names)}",
                    type=CommandType.WORKFLOW,
                    steps=steps
                )
                
                result = await self.orchestrator.execute_command_set(workflow)
                return result
            
        except Exception as e:
            return {"error": str(e)}
    
    def format_suggestion_output(self, suggestions):
        """Format suggestions for display to user"""
        if not suggestions:
            return ""
        
        output = ["\n🤖 Orchestration Enhancement Available:"]
        
        for i, suggestion in enumerate(suggestions, 1):
            output.append(f"\n{i}. {suggestion['description']}")
            output.append(f"   Command: {suggestion['command']}")
        
        output.append(f"\nTo use: Select option above or continue with regular Claude")
        output.append("To disable: export CLAUDE_ORCHESTRATION=off")
        
        return "\n".join(output)

async def main():
    """Main bridge function - LiveCD integrated"""
    
    # Check if orchestration is disabled
    if os.environ.get("CLAUDE_ORCHESTRATION", "").lower() == "off":
        sys.exit(0)
    
    # Get user input from command line or stdin
    if len(sys.argv) > 1:
        user_input = " ".join(sys.argv[1:])
    else:
        user_input = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
    
    if not user_input:
        print("╔════════════════════════════════════════════════════════════╗")
        print("║    Claude Unified Orchestration Bridge (LiveCD)            ║")
        print("║    Permission Bypass + Tandem Orchestration                ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()
        print("Usage: claude-orchestrate '<your task description>'")
        print("   or: echo 'your task' | claude-orchestrate")
        print()
        print("Current Configuration:")
        print(f"  Permission Bypass: {'ENABLED' if os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true' else 'DISABLED'}")
        print(f"  Orchestration: ENABLED")
        sys.exit(1)
    
    # Initialize bridge
    bridge = ClaudeOrchestrationBridge()
    
    print("🔍 Analyzing task for orchestration opportunities...")
    if bridge.permission_bypass:
        print("🔓 Permission bypass: ENABLED (LiveCD mode)")
    
    if not await bridge.initialize():
        print("❌ Could not initialize orchestration system - using mock mode")
        # Continue with simplified orchestration
    
    # Detect patterns
    detected_patterns, has_multi_agent = bridge.detect_workflow_intent(user_input)
    
    # Generate suggestions
    suggestions = await bridge.suggest_orchestration(user_input, detected_patterns, has_multi_agent)
    
    if not suggestions:
        print("✅ No orchestration enhancement needed - proceeding with standard Claude Code")
        sys.exit(0)
    
    # Show suggestions
    print(bridge.format_suggestion_output(suggestions))
    
    # If running interactively, ask user if they want to execute
    if sys.stdin.isatty():
        print(f"\nExecute suggestion 1? [y/N]: ", end="", flush=True)
        response = input().strip().lower()
        
        if response in ['y', 'yes']:
            print(f"\n🚀 Executing: {suggestions[0]['description']}")
            if bridge.orchestrator:
                result = await bridge.execute_orchestration_command(suggestions[0]['command'])
                
                print(f"\n📊 Results:")
                print(f"Status: {result.get('status', 'unknown')}")
                print(f"Steps completed: {len(result.get('results', {}))}")
                
                if result.get('status') == 'completed':
                    print("✅ Orchestration completed successfully!")
                else:
                    print(f"⚠️  Orchestration finished with status: {result.get('status')}")
            else:
                print("⚠️  Running in mock mode - orchestration simulated")
        else:
            print("👍 Proceeding with standard Claude Code workflow")

if __name__ == "__main__":
    asyncio.run(main())
ORCHESTRATION_BRIDGE
        
        chmod +x "$location"
    done
    
    success "Orchestration bridge deployed to multiple locations"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE CODE INSTALLATION WITH DEFAULT PERMISSION BYPASS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_if_needed() {
    if command -v node &> /dev/null; then
        log "Node.js found: $(node --version)"
        return 0
    fi
    
    log "Installing Node.js locally..."
    warn "This may take a few minutes on first run..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    local node_version="v20.11.0"
    local node_arch="linux-x64"
    local node_url="https://nodejs.org/dist/${node_version}/node-${node_version}-${node_arch}.tar.gz"
    
    log "Downloading Node.js ${node_version}..."
    if command -v wget &> /dev/null; then
        wget --progress=bar:force "$node_url" -O node.tar.gz 2>&1 | grep -E 'ETA|%' || return 1
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar "$node_url" -o node.tar.gz || return 1
    else
        error "Neither wget nor curl available"
        return 1
    fi
    
    log "Extracting Node.js..."
    tar -xzf node.tar.gz
    mkdir -p "$LOCAL_NODE_DIR"
    cp -r "node-${node_version}-${node_arch}"/* "$LOCAL_NODE_DIR/"
    
    export PATH="$LOCAL_NODE_DIR/bin:$PATH"
    success "Node.js installed locally"
    return 0
}

install_claude_code() {
    log "Installing Claude Code with robust retry mechanisms..."
    
    # Create directories
    mkdir -p "$USER_BIN_DIR"
    
    # Method 1: Advanced NPM installation with retries
    if attempt_npm_installation; then return 0; fi
    
    # Method 2: Pip installation with retries
    if attempt_pip_installation; then return 0; fi
    
    # Method 3: Direct download methods
    if attempt_direct_download; then return 0; fi
    
    # Method 4: GitHub releases download
    if attempt_github_download; then return 0; fi
    
    # Method 5: Manual installation from source
    if attempt_source_installation; then return 0; fi
    
    # If all methods fail, create minimal stub (should be rare)
    log "All installation methods failed - creating minimal stub"
    create_minimal_stub
}

# Method 1: NPM with comprehensive retry logic
attempt_npm_installation() {
    if ! command -v npm &> /dev/null; then
        log "NPM not available, skipping NPM installation"
        return 1
    fi
    
    log "Attempting NPM installation with retries..."
    
    mkdir -p "$LOCAL_NPM_PREFIX"
    export NPM_CONFIG_PREFIX="$LOCAL_NPM_PREFIX"
    export PATH="$LOCAL_NPM_PREFIX/bin:$PATH"
    
    # Package names to try in order
    local packages=(
        "@anthropic-ai/claude-code"
        "claude-code" 
        "claude"
        "@anthropic/claude-code"
        "anthropic-claude"
    )
    
    # Try each package with multiple retry attempts
    for package in "${packages[@]}"; do
        log "Trying package: $package"
        
        for attempt in {1..3}; do
            log "  Attempt $attempt/3..."
            
            # Try with different npm configurations
            if npm install -g "$package" --no-audit --no-fund --prefer-offline 2>/dev/null || \
               npm install -g "$package" --no-audit --no-fund 2>/dev/null || \
               npm install -g "$package" --force 2>/dev/null || \
               npm install -g "$package" 2>/dev/null; then
                
                # Verify installation
                if [ -f "$LOCAL_NPM_PREFIX/bin/claude" ]; then
                    log "  ✓ Successfully installed $package"
                    create_unified_wrapper_npm "$LOCAL_NPM_PREFIX/bin/claude"
                    success "Claude Code installed via npm ($package)"
                    return 0
                fi
            fi
            
            # Clear npm cache and try again
            npm cache clean --force 2>/dev/null || true
            sleep 2
        done
    done
    
    # Try alternative npm registries
    log "Trying alternative npm registries..."
    for registry in "https://registry.npmjs.org/" "https://registry.yarnpkg.com/"; do
        log "  Using registry: $registry"
        if npm install -g @anthropic-ai/claude-code --registry="$registry" 2>/dev/null; then
            if [ -f "$LOCAL_NPM_PREFIX/bin/claude" ]; then
                create_unified_wrapper_npm "$LOCAL_NPM_PREFIX/bin/claude"
                success "Claude Code installed via npm (alternative registry)"
                return 0
            fi
        fi
    done
    
    log "NPM installation failed after all attempts"
    return 1
}

# Method 2: Pip with comprehensive retry logic  
attempt_pip_installation() {
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        log "Pip not available, skipping pip installation"
        return 1
    fi
    
    log "Attempting pip installation with retries..."
    
    # Pip commands to try
    local pip_commands=("pip3" "pip")
    
    # Package names to try
    local packages=(
        "claude-code"
        "anthropic"
        "claude"
        "anthropic-claude"
        "claude-ai"
    )
    
    for pip_cmd in "${pip_commands[@]}"; do
        if ! command -v "$pip_cmd" &> /dev/null; then continue; fi
        
        log "Using $pip_cmd..."
        
        for package in "${packages[@]}"; do
            log "  Trying package: $package"
            
            for attempt in {1..3}; do
                log "    Attempt $attempt/3..."
                
                # Try different pip installation methods
                if "$pip_cmd" install --user "$package" --no-cache-dir 2>/dev/null || \
                   "$pip_cmd" install --user "$package" --force-reinstall 2>/dev/null || \
                   "$pip_cmd" install --user "$package" --upgrade 2>/dev/null || \
                   "$pip_cmd" install --user "$package" 2>/dev/null; then
                    
                    # Check common installation locations
                    for location in "$HOME/.local/bin/claude" "/usr/local/bin/claude"; do
                        if [ -f "$location" ]; then
                            log "    ✓ Successfully installed $package via $pip_cmd"
                            create_unified_wrapper_pip "$location"
                            success "Claude Code installed via pip ($package)"
                            return 0
                        fi
                    done
                fi
                
                sleep 2
            done
        done
    done
    
    log "Pip installation failed after all attempts"
    return 1
}

# Method 3: Direct download from various sources
attempt_direct_download() {
    log "Attempting direct download methods..."
    
    # Create work directory
    local work_dir="$WORK_DIR/claude-download"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # URLs to try for direct download
    local download_urls=(
        "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-1.0.77.tgz"
        "https://files.pythonhosted.org/packages/source/c/claude-code/claude-code-1.0.77.tar.gz"
        "https://github.com/anthropics/claude-code/releases/download/v1.0.77/claude-code-1.0.77.tar.gz"
    )
    
    for url in "${download_urls[@]}"; do
        log "  Trying download from: $url"
        
        local filename=$(basename "$url")
        
        # Try different download methods
        if command -v curl &> /dev/null; then
            if curl -L -o "$filename" "$url" 2>/dev/null; then
                if attempt_manual_install "$filename"; then
                    success "Claude Code installed via direct download (curl)"
                    return 0
                fi
            fi
        fi
        
        if command -v wget &> /dev/null; then
            if wget -O "$filename" "$url" 2>/dev/null; then
                if attempt_manual_install "$filename"; then
                    success "Claude Code installed via direct download (wget)"
                    return 0
                fi
            fi
        fi
    done
    
    cd - > /dev/null
    log "Direct download failed"
    return 1
}

# Method 4: GitHub releases download
attempt_github_download() {
    log "Attempting GitHub releases download..."
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log "No download tools available"
        return 1
    fi
    
    local work_dir="$WORK_DIR/github-download" 
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # GitHub API to get latest release
    local api_url="https://api.github.com/repos/anthropics/claude-code/releases/latest"
    
    if command -v curl &> /dev/null; then
        local latest_info=$(curl -s "$api_url" 2>/dev/null)
        if [ -n "$latest_info" ]; then
            # Extract download URL from JSON (basic parsing)
            local download_url=$(echo "$latest_info" | grep -o '"browser_download_url":[^,]*' | head -1 | cut -d'"' -f4)
            if [ -n "$download_url" ]; then
                log "  Found release: $download_url"
                if curl -L -o "claude-latest.tar.gz" "$download_url" 2>/dev/null; then
                    if attempt_manual_install "claude-latest.tar.gz"; then
                        success "Claude Code installed via GitHub releases"
                        return 0
                    fi
                fi
            fi
        fi
    fi
    
    cd - > /dev/null
    log "GitHub download failed"
    return 1
}

# Method 5: Source installation
attempt_source_installation() {
    log "Attempting source installation..."
    
    if ! command -v git &> /dev/null; then
        log "Git not available for source installation"
        return 1
    fi
    
    local work_dir="$WORK_DIR/source-install"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Try cloning Claude Code repository
    if git clone https://github.com/anthropics/claude-code.git 2>/dev/null; then
        cd claude-code
        
        # Try different build methods
        if [ -f "package.json" ] && command -v npm &> /dev/null; then
            log "  Building from source with npm..."
            if npm install 2>/dev/null && npm run build 2>/dev/null; then
                # Look for built binary
                for binary_path in "dist/claude" "build/claude" "bin/claude" "claude"; do
                    if [ -f "$binary_path" ] && [ -x "$binary_path" ]; then
                        cp "$binary_path" "$USER_BIN_DIR/claude.original"
                        chmod +x "$USER_BIN_DIR/claude.original"
                        create_unified_wrapper_manual "$USER_BIN_DIR/claude.original"
                        success "Claude Code built from source"
                        return 0
                    fi
                done
            fi
        fi
        
        if [ -f "setup.py" ] && command -v python3 &> /dev/null; then
            log "  Building from source with Python..."
            if python3 setup.py install --user 2>/dev/null; then
                if [ -f "$HOME/.local/bin/claude" ]; then
                    create_unified_wrapper_pip "$HOME/.local/bin/claude"
                    success "Claude Code built from Python source"
                    return 0
                fi
            fi
        fi
    fi
    
    cd - > /dev/null
    log "Source installation failed"
    return 1
}

# Helper to attempt manual installation from downloaded file
attempt_manual_install() {
    local filename="$1"
    
    if [ ! -f "$filename" ]; then
        return 1
    fi
    
    # Extract and install based on file type
    if [[ "$filename" == *.tgz ]] || [[ "$filename" == *.tar.gz ]]; then
        if tar -xzf "$filename" 2>/dev/null; then
            # Look for Claude binary in extracted files
            local binary=$(find . -name "claude" -type f -executable 2>/dev/null | head -1)
            if [ -n "$binary" ]; then
                cp "$binary" "$USER_BIN_DIR/claude.original"
                chmod +x "$USER_BIN_DIR/claude.original"
                create_unified_wrapper_manual "$USER_BIN_DIR/claude.original"
                return 0
            fi
            
            # Look for package.json and try npm install
            if [ -f "package/package.json" ]; then
                cd package
                if command -v npm &> /dev/null && npm install 2>/dev/null; then
                    local built_binary=$(find . -name "claude" -type f -executable 2>/dev/null | head -1)
                    if [ -n "$built_binary" ]; then
                        cp "$built_binary" "$USER_BIN_DIR/claude.original"
                        chmod +x "$USER_BIN_DIR/claude.original"
                        create_unified_wrapper_manual "$USER_BIN_DIR/claude.original"
                        return 0
                    fi
                fi
                cd ..
            fi
        fi
    fi
    
    return 1
}

# Wrapper creation functions for different installation methods
create_unified_wrapper_npm() {
    local claude_path="$1"
    if [ ! -f "$claude_path" ]; then
        log "Claude binary not found at $claude_path"
        return 1
    fi
    
    # Move original binary
    mv "$claude_path" "${claude_path}.original"
    
    # Copy the unified wrapper content
    if [ -f "$SCRIPT_DIR/claude-unified" ]; then
        cp "$SCRIPT_DIR/claude-unified" "$claude_path"
        chmod +x "$claude_path"
        log "Unified wrapper installed at $claude_path"
        return 0
    else
        log "Warning: claude-unified template not found, creating basic wrapper"
        create_basic_wrapper "$claude_path" "${claude_path}.original"
        return 0
    fi
}

create_unified_wrapper_pip() {
    local claude_path="$1"
    if [ ! -f "$claude_path" ]; then
        log "Claude binary not found at $claude_path"
        return 1
    fi
    
    # Move original binary
    mv "$claude_path" "${claude_path}.original"
    
    # Copy the unified wrapper content
    if [ -f "$SCRIPT_DIR/claude-unified" ]; then
        cp "$SCRIPT_DIR/claude-unified" "$claude_path"
        chmod +x "$claude_path"
        log "Unified wrapper installed at $claude_path"
        return 0
    else
        log "Warning: claude-unified template not found, creating basic wrapper"
        create_basic_wrapper "$claude_path" "${claude_path}.original"
        return 0
    fi
}

create_unified_wrapper_manual() {
    local claude_path="$1"
    if [ ! -f "$claude_path" ]; then
        log "Claude binary not found at $claude_path"
        return 1
    fi
    
    # The binary is already named .original, create wrapper
    local wrapper_path="${claude_path%.original}"
    
    # Copy the unified wrapper content
    if [ -f "$SCRIPT_DIR/claude-unified" ]; then
        cp "$SCRIPT_DIR/claude-unified" "$wrapper_path"
        chmod +x "$wrapper_path"
        log "Unified wrapper installed at $wrapper_path"
        return 0
    else
        log "Warning: claude-unified template not found, creating basic wrapper"
        create_basic_wrapper "$wrapper_path" "$claude_path"
        return 0
    fi
}

# Create basic wrapper when template is not available
create_basic_wrapper() {
    local wrapper_path="$1"
    local original_path="$2"
    
    cat > "$wrapper_path" << 'BASIC_WRAPPER'
#!/bin/bash
# Basic Claude wrapper with permission bypass
set -euo pipefail

# Configuration
ORIGINAL_CLAUDE="${ORIGINAL_CLAUDE_PATH}"
PERMISSION_BYPASS_ENABLED=${CLAUDE_PERMISSION_BYPASS:-true}

# Add permission bypass by default
if [ "$PERMISSION_BYPASS_ENABLED" = "true" ] && [[ " $@ " != *" --no-skip-permissions "* ]] && [[ " $@ " != *" --safe "* ]]; then
    exec "$ORIGINAL_CLAUDE" --dangerously-skip-permissions "$@"
else
    exec "$ORIGINAL_CLAUDE" "$@"
fi
BASIC_WRAPPER
    
    # Replace placeholder with actual path
    sed -i "s|\${ORIGINAL_CLAUDE_PATH}|$original_path|g" "$wrapper_path"
    chmod +x "$wrapper_path"
    log "Basic wrapper created at $wrapper_path"
}

# Create minimal stub as absolute last resort
create_minimal_stub() {
    log "Creating minimal Claude stub as last resort..."
    cat > "$USER_BIN_DIR/claude" << 'MINIMAL_STUB'
#!/bin/bash
# Minimal Claude stub with permission bypass

# Set environment
export CLAUDE_AGENTS_DIR="$HOME/.local/share/claude/agents"
export CLAUDE_AGENTS_ROOT="$CLAUDE_AGENTS_DIR"

# Check for actual Claude binary
CLAUDE_ACTUAL=""
for loc in "$HOME/.local/npm-global/bin/claude.original" "$HOME/.local/bin/claude.original" "$(which claude-actual 2>/dev/null)"; do
    if [ -f "$loc" ] && [ -x "$loc" ] && [ "$loc" != "$0" ]; then
        CLAUDE_ACTUAL="$loc"
        break
    fi
done

if [ -n "$CLAUDE_ACTUAL" ]; then
    # Add permission bypass by default unless disabled
    if [[ " $@ " != *" --no-skip-permissions "* ]] && [[ " $@ " != *" --safe "* ]]; then
        exec "$CLAUDE_ACTUAL" --dangerously-skip-permissions "$@"
    else
        exec "$CLAUDE_ACTUAL" "$@"
    fi
else
    echo "Claude Code Stub v1.0 (LiveCD compatible)"
    echo ""
    echo "This stub automatically includes --dangerously-skip-permissions for LiveCD compatibility"
    echo "To install Claude Code: npm install -g @anthropic-ai/claude-code"
    echo ""
    
    case "$1" in
        --version)
            echo "1.0.0-stub"
            ;;
        --help)
            echo "Usage: claude [options] [command]"
            echo "Options:"
            echo "  --version                 Show version"
            echo "  --help                    Show this help"
            echo "  --no-skip-permissions     Disable permission bypass"
            ;;
        *)
            echo "Arguments: $@"
            ;;
    esac
fi
MINIMAL_STUB
    
    chmod +x "$USER_BIN_DIR/claude"
    CLAUDE_BINARY="$USER_BIN_DIR/claude"
    warn "Minimal Claude stub created - install Claude Code for full functionality"
    return 0
}

# Also create a 'claude-normal' command for running WITHOUT permission bypass
create_claude_normal_command() {
    cat > "$USER_BIN_DIR/claude-normal" << 'CLAUDE_NORMAL'
#!/bin/bash
# Claude launcher WITHOUT automatic permission bypass
exec claude --no-skip-permissions "$@"
CLAUDE_NORMAL
    chmod +x "$USER_BIN_DIR/claude-normal"
    log "Created 'claude-normal' command for non-LiveCD use"
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
    
    # Add alias for convenience
    if ! grep -q "alias claude-safe" "$shell_rc" 2>/dev/null; then
        echo "# Claude aliases for LiveCD" >> "$shell_rc"
        echo "alias claude-safe='claude --no-skip-permissions'  # Run without permission bypass" >> "$shell_rc"
    fi
    
    success "Environment configured"
    
    # Create the alternative command
    create_claude_normal_command
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_status() {
    echo
    printf "${BOLD}${CYAN}Installation Status${NC}\n"
    echo "═══════════════════════════════════════"
    
    # Claude Code
    printf "${BOLD}Claude Code:${NC} "
    if [ -n "$CLAUDE_BINARY" ] && [ -f "$CLAUDE_BINARY" ]; then
        printf "${GREEN}✓ Installed${NC} at $CLAUDE_BINARY\n"
        printf "  ${YELLOW}Permission bypass: ENABLED by default${NC}\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Agents
    printf "${BOLD}Agents:${NC} "
    if [ -d "$AGENTS_DIR" ]; then
        local agent_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l || echo 0)
        printf "${GREEN}✓ $agent_count agents${NC} in $AGENTS_DIR\n"
    else
        printf "${RED}✗ Not installed${NC}\n"
    fi
    
    # Statusline
    printf "${BOLD}Neovim Statusline:${NC} "
    if [ -f "$HOME/.config/nvim/lua/statusline.lua" ]; then
        printf "${GREEN}✓ Installed${NC}\n"
    else
        printf "${YELLOW}✗ Not installed${NC}\n"
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
    echo "  claude         - Launch WITH permission bypass (default)"
    echo "  claude-normal  - Launch WITHOUT permission bypass"
    echo "  claude-safe    - Alias for claude --no-skip-permissions"
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_installation() {
    # Create necessary directories
    mkdir -p "$HOME/Documents/Claude" 2>/dev/null || true
    mkdir -p "$WORK_DIR"
    
    show_banner
    
    log "Starting all-in-one installation..."
    warn "DEFAULT: Permission bypass will be ENABLED for LiveCD compatibility"
    echo
    
    # Step 1: Install Node.js if needed
    install_node_if_needed
    echo
    
    # Step 2: Install agents from GitHub
    install_agents_from_github
    echo
    
    # Step 2.5: Deploy orchestration bridge
    deploy_orchestration_bridge
    echo
    
    # Step 3: Install Claude Code with unified wrapper
    install_claude_code
    echo
    
    # Step 4: Deploy Neovim statusline
    deploy_neovim_statusline
    echo
    
    # Step 5: Setup environment
    setup_environment
    
    # Show final status
    show_status
    
    success "Installation complete!"
    echo
    echo "To complete setup:"
    echo "  1. Run: source ~/.bashrc"
    echo "  2. Launch Claude: claude"
    echo
    printf "${YELLOW}${BOLD}NEW:${NC} ${GREEN}Unified Orchestration System${NC} integrated!\n"
    echo "  • ${GREEN}Permission bypass${NC}: Automatic for LiveCD compatibility"
    echo "  • ${CYAN}Orchestration${NC}: Intelligent multi-agent workflow detection"
    echo "  • ${MAGENTA}Zero learning curve${NC}: Works exactly like regular Claude"
    echo
    echo "${BOLD}Usage:${NC}"
    echo "  claude /task \"create feature with tests\"  → Auto permission bypass + orchestration"
    echo "  claude --unified-status                    → Show system status"
    echo "  claude --unified-help                      → Show help"
    echo "  claude-normal                              → Regular Claude without bypass"
    echo
    echo "${BOLD}Environment Controls:${NC}"
    echo "  export CLAUDE_PERMISSION_BYPASS=false     → Disable permission bypass"
    echo "  export CLAUDE_ORCHESTRATION=false         → Disable orchestration"
    echo
    
    # Ask if user wants to launch Claude now
    echo -n "Launch Claude Code now? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -n "$CLAUDE_BINARY" ] && [ -f "$CLAUDE_BINARY" ]; then
            log "Launching Claude with permission bypass..."
            exec "$CLAUDE_BINARY"  # The wrapper already includes --dangerously-skip-permissions
        else
            warn "Claude binary not found. Run 'source ~/.bashrc' first."
        fi
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERACTIVE MENU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_menu() {
    while true; do
        clear
        show_banner
        
        echo "Choose an option:"
        echo
        printf "${GREEN}1)${NC} Quick Install - Everything automatic (with permission bypass)\n"
        printf "${CYAN}2)${NC} Install Agents Only\n"
        printf "${BLUE}3)${NC} Install Claude Code Only\n"
        printf "${MAGENTA}4)${NC} Install Statusline Only\n"
        printf "${YELLOW}5)${NC} Check Installation Status\n"
        printf "${RED}6)${NC} Exit\n"
        echo
        
        echo -n "Enter your choice [1-6]: "
        read -r choice
        
        case "$choice" in
            1) 
                run_installation
                break
                ;;
            2) 
                install_agents_from_github
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            3) 
                install_node_if_needed
                install_claude_code
                setup_environment
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            4) 
                deploy_neovim_statusline
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            5) 
                show_status
                echo
                printf "${YELLOW}Press ENTER to continue...${NC}"
                read -r
                ;;
            6) 
                printf "${GREEN}Thank you for using Claude installer!${NC}\n"
                exit 0
                ;;
            *)
                error "Invalid choice. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Handle command line arguments
case "${1:-}" in
    --auto|--quick|-q)
        run_installation
        ;;
    --menu|-m)
        main_menu
        ;;
    --help|-h)
        show_banner
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --auto, --quick, -q    Run automatic installation"
        echo "  --menu, -m             Show interactive menu"
        echo "  --help, -h             Show this help"
        echo
        echo "Without options, runs automatic installation"
        echo
        echo "PERMISSION BYPASS: ENABLED BY DEFAULT"
        echo "  claude         - Runs WITH permission bypass (default)"
        echo "  claude-normal  - Runs WITHOUT permission bypass"
        echo "  claude-safe    - Alias for --no-skip-permissions"
        echo
        echo "GitHub Repository: $GITHUB_REPO"
        echo "Agents Directory:  $AGENTS_DIR"
        echo "Install Directory: $USER_BIN_DIR"
        ;;
    *)
        # Default: run automatic installation
        run_installation
        ;;
esac

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_function_called=true
fi