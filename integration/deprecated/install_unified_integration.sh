#!/bin/bash
"""
UNIFIED CLAUDE CODE INTEGRATION INSTALLER
Multi-Agent Coordination: DIRECTOR, PROJECTORCHESTRATOR, ARCHITECT, CONSTRUCTOR

Installs the unified integration system that bypasses Claude Code Task tool limitations
through multi-layer integration approach combining all existing components.
"""

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dynamic project root detection
find_project_root() {
    local current="$(pwd)"
    local markers=(".claude" "agents" "CLAUDE.md" ".git" "claude-wrapper-ultimate.sh")
    
    while [[ "$current" != "/" ]]; do
        for marker in "${markers[@]}"; do
            if [[ -e "$current/$marker" ]]; then
                echo "$current"
                return 0
            fi
        done
        current="$(dirname "$current")"
    done
    
    echo "$(pwd)"
}

PROJECT_ROOT="$(find_project_root)"
INTEGRATION_FILE="$PROJECT_ROOT/claude_unified_integration.py"

print_header() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}         UNIFIED CLAUDE CODE INTEGRATION INSTALLER${NC}"
    echo -e "${BLUE}      Multi-Agent System Bypass for Task Tool Limitations${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_dependencies() {
    print_step "Checking dependencies..."
    
    local missing=()
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    # Check required Python modules
    if ! python3 -c "import json, pathlib, asyncio" 2>/dev/null; then
        print_warning "Some Python standard library modules may not be available"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    print_success "All dependencies available"
}

setup_directories() {
    print_step "Setting up directories..."
    
    local directories=(
        "$HOME/.config/claude"
        "$HOME/.claude/hooks"
        "$HOME/.cache/claude-agents"
        "$PROJECT_ROOT/config"
        "$PROJECT_ROOT/logs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_info "Created directory: $dir"
        fi
    done
    
    print_success "Directories setup complete"
}

install_integration_system() {
    print_step "Installing unified integration system..."
    
    if [[ ! -f "$INTEGRATION_FILE" ]]; then
        print_error "Integration file not found: $INTEGRATION_FILE"
        return 1
    fi
    
    # Make integration file executable
    chmod +x "$INTEGRATION_FILE"
    
    # Create symlink in user bin
    local user_bin="$HOME/.local/bin"
    if [[ ! -d "$user_bin" ]]; then
        mkdir -p "$user_bin"
    fi
    
    local symlink_path="$user_bin/claude-unified-integration"
    if [[ -L "$symlink_path" ]]; then
        rm "$symlink_path"
    fi
    
    ln -sf "$INTEGRATION_FILE" "$symlink_path"
    print_info "Created symlink: $symlink_path -> $INTEGRATION_FILE"
    
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$user_bin:"* ]]; then
        print_info "Add this to your ~/.bashrc or ~/.zshrc:"
        print_info "export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    print_success "Integration system installed"
}

setup_claude_code_hooks() {
    print_step "Setting up Claude Code hooks..."
    
    # Run the integration setup
    if python3 "$INTEGRATION_FILE" --setup; then
        print_success "Claude Code hooks configured"
    else
        print_warning "Hook setup completed with warnings"
    fi
}

create_configuration() {
    print_step "Creating configuration files..."
    
    local config_dir="$HOME/.config/claude"
    
    # Create unified integration config
    cat > "$config_dir/unified-integration.json" << 'EOF'
{
  "version": "1.0.0",
  "integration_layers": {
    "environment": true,
    "hooks": true,
    "command": true,
    "bridge": true,
    "orchestration": true
  },
  "agent_invocation": {
    "default_method": "auto",
    "timeout": 300,
    "retry_attempts": 2
  },
  "logging": {
    "level": "INFO",
    "file": "~/.cache/claude-agents/integration.log"
  }
}
EOF
    
    print_info "Created configuration: $config_dir/unified-integration.json"
    
    print_success "Configuration files created"
}

test_integration() {
    print_step "Testing unified integration..."
    
    # Test system status
    if python3 "$INTEGRATION_FILE" --status > /dev/null 2>&1; then
        print_success "Integration system operational"
    else
        print_error "Integration system test failed"
        return 1
    fi
    
    # Test agent listing
    local agent_count
    agent_count=$(python3 "$INTEGRATION_FILE" --list 2>/dev/null | grep -c "^  -" || echo "0")
    
    if [[ "$agent_count" -gt 0 ]]; then
        print_success "Found $agent_count agents in registry"
    else
        print_warning "No agents found in registry"
    fi
    
    print_success "Integration testing completed"
}

create_wrapper_script() {
    print_step "Creating Claude Code wrapper script..."
    
    local wrapper_script="$PROJECT_ROOT/claude-with-agents"
    
    cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# Claude Code with Unified Agent Integration
# This wrapper enables agent access within Claude Code sessions

# Set integration environment
export CLAUDE_UNIFIED_INTEGRATION="active"
export CLAUDE_AGENTS_AVAILABLE="true"

# Find project root dynamically
find_project_root() {
    local current="$(pwd)"
    local markers=(".claude" "agents" "CLAUDE.md" ".git")
    
    while [[ "$current" != "/" ]]; do
        for marker in "${markers[@]}"; do
            if [[ -e "$current/$marker" ]]; then
                echo "$current"
                return 0
            fi
        done
        current="$(dirname "$current")"
    done
    
    echo "$(pwd)"
}

PROJECT_ROOT="$(find_project_root)"
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
export CLAUDE_AGENTS_ROOT="$PROJECT_ROOT/agents"

# Initialize integration if available
if [[ -f "$PROJECT_ROOT/claude_unified_integration.py" ]]; then
    python3 "$PROJECT_ROOT/claude_unified_integration.py" --setup 2>/dev/null || true
fi

# Execute Claude with agent environment
if command -v claude &> /dev/null; then
    exec claude "$@"
else
    echo "Claude command not found. Please install Claude Code first."
    exit 1
fi
EOF
    
    chmod +x "$wrapper_script"
    print_info "Created wrapper script: $wrapper_script"
    
    # Create alias suggestion
    print_info "Optional: Add this alias to your shell configuration:"
    print_info "alias claude-agents='$wrapper_script'"
    
    print_success "Wrapper script created"
}

print_final_instructions() {
    echo
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}                  INSTALLATION COMPLETE!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo
    echo -e "${BLUE}Unified Claude Code Integration System is now installed.${NC}"
    echo
    echo -e "${YELLOW}Available Commands:${NC}"
    echo "  claude-unified-integration --status    # Show system status"
    echo "  claude-unified-integration --list      # List all agents"
    echo "  claude-unified-integration --info AGENT # Show agent details"
    echo "  claude-unified-integration --invoke AGENT PROMPT # Invoke agent"
    echo
    echo -e "${YELLOW}Integration Features:${NC}"
    echo "  ✓ Environment detection and capability injection"
    echo "  ✓ Hook-based integration (pre/post task actions)"
    echo "  ✓ Command interception and agent routing"
    echo "  ✓ Unified agent bridge (76 agents available)"
    echo "  ✓ Production orchestrator integration"
    echo
    echo -e "${YELLOW}Claude Code Integration:${NC}"
    echo "  • Hooks are automatically setup for Claude Code"
    echo "  • Agents will be suggested based on task patterns"
    echo "  • Use '$PROJECT_ROOT/claude-with-agents' for enhanced Claude"
    echo
    echo -e "${YELLOW}Testing:${NC}"
    echo "  claude-unified-integration --status"
    echo
    print_success "Ready to use unified agent integration!"
}

main() {
    print_header
    
    print_info "Project root: $PROJECT_ROOT"
    print_info "Integration file: $INTEGRATION_FILE"
    echo
    
    check_dependencies || exit 1
    setup_directories || exit 1
    install_integration_system || exit 1
    setup_claude_code_hooks || exit 1
    create_configuration || exit 1
    create_wrapper_script || exit 1
    test_integration || exit 1
    
    print_final_instructions
}

# Execute main function
main "$@"