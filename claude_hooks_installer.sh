#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE HOOKS SYSTEM - COMPLETE INSTALLER v1.0
# 
# This script sets up the complete hooks integration between Claude Code
# and your Python agent system.
# 
# Usage: ./install_claude_hooks_system.sh
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SOURCE_DIR="$PROJECT_ROOT/hooks"
CLAUDE_HOME="$HOME/.claude"
CLAUDE_HOOKS_DIR="$CLAUDE_HOME/hooks"
CLAUDE_CONFIG_FILE="$CLAUDE_HOOKS_DIR/config.json"

# Required directories
REQUIRED_DIRS=(
    "$CLAUDE_HOME"
    "$CLAUDE_HOOKS_DIR"
    "$CLAUDE_HOOKS_DIR/pre-task"
    "$CLAUDE_HOOKS_DIR/post-edit"
    "$CLAUDE_HOOKS_DIR/post-task"
    "$PROJECT_ROOT/.agent_cache"
    "$PROJECT_ROOT/reports"
    "$PROJECT_ROOT/generated_code"
)

# Log functions
log() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
warn() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
success() { printf "${GREEN}✅${NC} %s\n" "$1"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: CREATE DIRECTORY STRUCTURE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_directories() {
    log "Creating directory structure..."
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "  Created: $dir"
        else
            log "  Exists: $dir"
        fi
    done
    
    success "Directory structure ready"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: CREATE CONFIG.JSON
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_config_json() {
    log "Creating Claude hooks configuration..."
    
    cat > "$CLAUDE_CONFIG_FILE" << 'EOF'
{
  "version": "1.0.0",
  "hooks": {
    "pre-task": {
      "enabled": true,
      "scripts": [
        {
          "name": "Validation & Setup",
          "path": "~/.claude/hooks/pre-task/validate_and_setup.sh",
          "timeout": 10,
          "required": true,
          "on_failure": "abort"
        }
      ]
    },
    "post-edit": {
      "enabled": true,
      "scripts": [
        {
          "name": "Process Changes",
          "path": "~/.claude/hooks/post-edit/process_changes.sh",
          "timeout": 30,
          "required": false,
          "on_failure": "continue"
        }
      ]
    },
    "post-task": {
      "enabled": true,
      "scripts": [
        {
          "name": "Cleanup & Report",
          "path": "~/.claude/hooks/post-task/cleanup_and_report.sh",
          "timeout": 15,
          "required": false,
          "on_failure": "log"
        }
      ]
    }
  },
  "global": {
    "log_file": "~/.claude/hooks/hooks.log",
    "debug": true,
    "parallel_execution": false
  }
}
EOF
    
    success "Created config.json at $CLAUDE_CONFIG_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: CREATE HOOK SCRIPTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_hook_scripts() {
    log "Creating hook scripts..."
    
    # Pre-task hook
    cat > "$CLAUDE_HOOKS_DIR/pre-task/validate_and_setup.sh" << EOF
#!/bin/bash
# Pre-task hook for Claude Code

# Get the current task context from environment or args
TASK_CONTEXT="\${CLAUDE_TASK_CONTEXT:-\$1}"

# Call Python hook bridge
python3 "$HOOKS_SOURCE_DIR/claude_hooks_bridge.py" \\
  --phase pre-task \\
  --context "\$TASK_CONTEXT"

# Check validation result
if [ \$? -ne 0 ]; then
  echo "❌ Pre-task validation failed"
  exit 1
fi

echo "✅ Pre-task hooks completed"
EOF
    chmod +x "$CLAUDE_HOOKS_DIR/pre-task/validate_and_setup.sh"
    log "  Created pre-task hook"
    
    # Post-edit hook
    cat > "$CLAUDE_HOOKS_DIR/post-edit/process_changes.sh" << EOF
#!/bin/bash
# Post-edit hook for Claude Code

# Get edited files from Claude Code
EDITED_FILES="\${CLAUDE_EDITED_FILES:-\$1}"

# Create context with file information
CONTEXT_FILE="/tmp/claude_edit_context_\$\$.json"
cat > "\$CONTEXT_FILE" << EOJSON
{
  "edited_files": "\$EDITED_FILES",
  "timestamp": "\$(date -Iseconds)",
  "agent": "\${CLAUDE_CURRENT_AGENT:-unknown}",
  "task_id": "\${CLAUDE_TASK_ID:-\$\$}"
}
EOJSON

# Call Python hook bridge
python3 "$HOOKS_SOURCE_DIR/claude_hooks_bridge.py" \\
  --phase post-edit \\
  --context "\$CONTEXT_FILE"

echo "✅ Post-edit hooks completed"

# Cleanup
rm -f "\$CONTEXT_FILE"
EOF
    chmod +x "$CLAUDE_HOOKS_DIR/post-edit/process_changes.sh"
    log "  Created post-edit hook"
    
    # Post-task hook
    cat > "$CLAUDE_HOOKS_DIR/post-task/cleanup_and_report.sh" << EOF
#!/bin/bash
# Post-task hook for Claude Code

# Gather task completion data
TASK_RESULT="\${CLAUDE_TASK_RESULT:-completed}"

# Create completion context
CONTEXT_FILE="/tmp/claude_task_context_\$\$.json"
cat > "\$CONTEXT_FILE" << EOJSON
{
  "task_result": "\$TASK_RESULT",
  "completion_time": "\$(date -Iseconds)",
  "agent": "\${CLAUDE_CURRENT_AGENT:-unknown}",
  "task_id": "\${CLAUDE_TASK_ID:-\$\$}",
  "duration": "\${CLAUDE_TASK_DURATION:-unknown}"
}
EOJSON

# Call Python hook bridge
python3 "$HOOKS_SOURCE_DIR/claude_hooks_bridge.py" \\
  --phase post-task \\
  --context "\$CONTEXT_FILE"

echo "✅ Post-task hooks completed"

# Cleanup
rm -f "\$CONTEXT_FILE"
EOF
    chmod +x "$CLAUDE_HOOKS_DIR/post-task/cleanup_and_report.sh"
    log "  Created post-task hook"
    
    success "Hook scripts created and made executable"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: CREATE CLAUDE HOOKS REGISTRY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_claude_registry() {
    log "Creating Claude hooks registry..."
    
    # Create registry for Claude Code discovery
    cat > "$CLAUDE_HOME/hook_registry.json" << EOF
{
  "hook_provider": "claude-agent-framework",
  "version": "7.0.0",
  "project_root": "$PROJECT_ROOT",
  "hooks_source": "$HOOKS_SOURCE_DIR",
  "hooks": {
    "/hooks/pre-task": {
      "handler": "$CLAUDE_HOOKS_DIR/pre-task/validate_and_setup.sh",
      "description": "Validate and prepare task execution"
    },
    "/hooks/post-edit": {
      "handler": "$CLAUDE_HOOKS_DIR/post-edit/process_changes.sh",
      "description": "Process code changes and extract artifacts"
    },
    "/hooks/post-task": {
      "handler": "$CLAUDE_HOOKS_DIR/post-task/cleanup_and_report.sh",
      "description": "Cleanup and generate reports"
    }
  }
}
EOF
    
    # Create .claude-hooks file for Claude Code
    cat > "$HOME/.claude-hooks" << EOF
{
  "version": "1.0",
  "provider": "claude-agent-framework",
  "hooks": {
    "pre-task": "$CLAUDE_HOOKS_DIR/pre-task/validate_and_setup.sh pre-task",
    "post-edit": "$CLAUDE_HOOKS_DIR/post-edit/process_changes.sh post-edit",
    "post-task": "$CLAUDE_HOOKS_DIR/post-task/cleanup_and_report.sh post-task"
  }
}
EOF
    
    success "Created Claude hooks registry files"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: INSTALL PYTHON DEPENDENCIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_dependencies() {
    log "Installing Python dependencies..."
    
    # Check if pip is available
    if command -v pip3 &> /dev/null; then
        pip3 install --user pyyaml psutil rich 2>/dev/null || {
            warn "Some Python packages failed to install, but continuing..."
        }
    else
        warn "pip3 not found - skipping Python dependency installation"
    fi
    
    success "Dependencies check completed"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: VERIFY PYTHON HOOK FILES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

verify_python_hooks() {
    log "Verifying Python hook files..."
    
    local required_files=(
        "claude_hooks_bridge.py"
        "claude_hook_manager.py"
        "claude_code_hook_adapter.py"
        "agent_hooks.py"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ -f "$HOOKS_SOURCE_DIR/$file" ]; then
            log "  ✓ Found: $file"
        else
            warn "  ✗ Missing: $file"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        warn "Some Python hook files are missing in $HOOKS_SOURCE_DIR"
        warn "Please ensure all hook Python files are created"
    else
        success "All Python hook files verified"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: CREATE TEST SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_test_script() {
    log "Creating test script..."
    
    cat > "$PROJECT_ROOT/test_claude_hooks.sh" << 'EOF'
#!/bin/bash
# Test Claude Hooks Integration

echo "🧪 Testing Claude Hooks System"
echo "=============================="
echo

# Test pre-task hook
echo "Testing pre-task hook..."
~/.claude/hooks/pre-task/validate_and_setup.sh '{"task": "test", "agent": "test"}'
echo

# Test post-edit hook
echo "Testing post-edit hook..."
export CLAUDE_EDITED_FILES="/tmp/test.py"
echo "print('test')" > /tmp/test.py
~/.claude/hooks/post-edit/process_changes.sh
echo

# Test post-task hook
echo "Testing post-task hook..."
export CLAUDE_TASK_RESULT="success"
~/.claude/hooks/post-task/cleanup_and_report.sh
echo

echo "✅ All hooks tested!"
EOF
    
    chmod +x "$PROJECT_ROOT/test_claude_hooks.sh"
    success "Created test script: test_claude_hooks.sh"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 8: CREATE MANAGEMENT SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_management_script() {
    log "Creating management script..."
    
    cat > "$PROJECT_ROOT/manage_claude_hooks.sh" << 'EOF'
#!/bin/bash
# Claude Hooks Management Script

case "$1" in
    enable)
        echo "Enabling Claude hooks..."
        jq '.hooks."pre-task".enabled = true | .hooks."post-edit".enabled = true | .hooks."post-task".enabled = true' \
            ~/.claude/hooks/config.json > /tmp/config.json && \
            mv /tmp/config.json ~/.claude/hooks/config.json
        echo "✅ Hooks enabled"
        ;;
    
    disable)
        echo "Disabling Claude hooks..."
        jq '.hooks."pre-task".enabled = false | .hooks."post-edit".enabled = false | .hooks."post-task".enabled = false' \
            ~/.claude/hooks/config.json > /tmp/config.json && \
            mv /tmp/config.json ~/.claude/hooks/config.json
        echo "✅ Hooks disabled"
        ;;
    
    status)
        echo "Claude Hooks Status:"
        echo "===================="
        if [ -f ~/.claude/hooks/config.json ]; then
            jq -r '.hooks | to_entries[] | "\(.key): \(if .value.enabled then "✅ Enabled" else "❌ Disabled" end)"' \
                ~/.claude/hooks/config.json
        else
            echo "❌ Config file not found"
        fi
        ;;
    
    test)
        ./test_claude_hooks.sh
        ;;
    
    *)
        echo "Usage: $0 {enable|disable|status|test}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$PROJECT_ROOT/manage_claude_hooks.sh"
    success "Created management script: manage_claude_hooks.sh"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FLOW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}    CLAUDE HOOKS SYSTEM INSTALLER v1.0                ${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo
    
    log "Starting installation from: $PROJECT_ROOT"
    log "Installing to: $CLAUDE_HOME"
    echo
    
    # Run installation steps
    create_directories
    echo
    
    create_config_json
    echo
    
    create_hook_scripts
    echo
    
    create_claude_registry
    echo
    
    install_dependencies
    echo
    
    verify_python_hooks
    echo
    
    create_test_script
    echo
    
    create_management_script
    echo
    
    # Final summary
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}    INSTALLATION COMPLETE!                            ${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo
    echo "📍 Installation Summary:"
    echo "  • Config: $CLAUDE_CONFIG_FILE"
    echo "  • Hooks: $CLAUDE_HOOKS_DIR"
    echo "  • Registry: $CLAUDE_HOME/hook_registry.json"
    echo "  • Python hooks: $HOOKS_SOURCE_DIR"
    echo
    echo "🎯 Quick Commands:"
    echo "  • Test hooks:    ./test_claude_hooks.sh"
    echo "  • Manage hooks:  ./manage_claude_hooks.sh {enable|disable|status|test}"
    echo "  • View config:   cat ~/.claude/hooks/config.json"
    echo
    echo "📝 Usage in Claude Code:"
    echo "  • /hooks enable  - Enable all hooks"
    echo "  • /hooks disable - Disable all hooks"
    echo "  • /hooks list    - List registered hooks"
    echo "  • /hooks test    - Test hook execution"
    echo
    echo -e "${GREEN}The hooks will automatically trigger during task execution!${NC}"
    echo
}

# Run main installation
main "$@"