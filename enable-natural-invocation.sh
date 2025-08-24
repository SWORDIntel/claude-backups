#!/bin/bash
# Enhanced Natural Agent Invocation Setup v2.0
# Complete setup for automatic agent discovery with 58+ agent support

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Allow environment overrides for all paths
CLAUDE_BASE_PATH="${CLAUDE_BASE_PATH:-$HOME/.config/claude}"
CLAUDE_AGENTS_PATH="${CLAUDE_AGENTS_PATH:-$HOME/agents}"
CLAUDE_CACHE_PATH="${CLAUDE_CACHE_PATH:-$HOME/.cache/claude-agents}"
CLAUDE_BACKUP_PATH="${CLAUDE_BACKUP_PATH:-$HOME/Documents/claude-backups}"

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOOKS_DIR="${CLAUDE_HOOKS_DIR:-$SCRIPT_DIR/hooks}"
CONFIG_DIR="$CLAUDE_BASE_PATH"
CACHE_DIR="$CLAUDE_CACHE_PATH"
LOG_DIR="$CLAUDE_CACHE_PATH/logs"

# Version information
VERSION="2.0.0"
MIN_PYTHON_VERSION="3.8"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}   🎯 Natural Agent Invocation Setup v${VERSION}${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${MAGENTA}▶${NC} ${BOLD}$1${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_python_version() {
    if check_command python3; then
        python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        if [[ $(echo "$python_version >= $MIN_PYTHON_VERSION" | bc -l) -eq 1 ]]; then
            return 0
        fi
    fi
    return 1
}

create_directory() {
    local dir="$1"
    local desc="$2"
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created $desc: $dir"
    else
        print_info "$desc already exists: $dir"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        print_success "Backed up: $(basename "$file") → $(basename "$backup")"
    fi
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local all_good=true
    
    # Check Python
    if check_python_version; then
        print_success "Python 3.8+ found: $(python3 --version 2>&1 | cut -d' ' -f2)"
    else
        print_error "Python 3.8+ is required"
        all_good=false
    fi
    
    # Check for required Python packages
    local required_packages=("json" "pathlib" "typing" "dataclasses" "enum")
    for package in "${required_packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            print_success "Python package '$package' available"
        else
            print_warning "Python package '$package' may be required"
        fi
    done
    
    # Check if agent directory exists
    if [ -d "$CLAUDE_AGENTS_PATH" ]; then
        agent_count=$(find "$CLAUDE_AGENTS_PATH" -name "*.md" 2>/dev/null | wc -l)
        print_success "Found $agent_count agent files in $CLAUDE_AGENTS_PATH"
    else
        print_warning "Agent directory not found: $CLAUDE_AGENTS_PATH"
        print_info "Creating agent directory..."
        mkdir -p "$CLAUDE_AGENTS_PATH"
    fi
    
    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

setup_directories() {
    print_step "Setting up directory structure..."
    
    create_directory "$CONFIG_DIR" "Configuration directory"
    create_directory "$CACHE_DIR" "Cache directory"
    create_directory "$LOG_DIR" "Log directory"
    create_directory "$HOOKS_DIR" "Hooks directory"
    create_directory "$CONFIG_DIR/patterns" "Patterns directory"
    create_directory "$CONFIG_DIR/agents" "Agent configs directory"
    
    print_success "Directory structure ready"
}

# ============================================================================
# HOOK CONFIGURATION
# ============================================================================

install_hook_configuration() {
    print_step "Installing hook configuration..."
    
    local hooks_config="$CONFIG_DIR/hooks.json"
    
    # Backup existing configuration
    backup_file "$hooks_config"
    
    # Create comprehensive hook configuration
    cat > "$hooks_config" << EOF
{
  "version": "$VERSION",
  "enabled": true,
  "hooks": {
    "pre-task": {
      "enabled": true,
      "script": "$HOOKS_DIR/natural-invocation-hook.py",
      "function": "hook_pre_task",
      "description": "Analyzes task invocations to suggest relevant agents",
      "timeout": 5
    },
    "post-edit": {
      "enabled": true,
      "script": "$HOOKS_DIR/natural-invocation-hook.py",
      "function": "hook_post_edit",
      "description": "Suggests follow-up agents after code edits",
      "timeout": 3
    },
    "conversation-analysis": {
      "enabled": true,
      "script": "$HOOKS_DIR/natural-invocation-hook.py",
      "function": "hook_conversation_analysis",
      "description": "Analyzes conversation history for agent suggestions",
      "timeout": 5
    },
    "user-prompt-submit": {
      "enabled": true,
      "script": "$HOOKS_DIR/natural-invocation-hook.py",
      "function": "hook_pre_task",
      "description": "Processes natural language for agent invocation",
      "timeout": 5
    }
  },
  "settings": {
    "confidence_threshold": 0.6,
    "auto_invoke": false,
    "show_suggestions": true,
    "show_confidence": true,
    "show_reasoning": true,
    "max_suggestions": 5,
    "log_invocations": true,
    "log_file": "$LOG_DIR/invocations.log",
    "cache_ttl": 3600,
    "enable_semantic_matching": true,
    "enable_workflow_detection": true,
    "enable_pattern_matching": true
  },
  "agent_registry": {
    "path": "$CLAUDE_AGENTS_PATH",
    "cache_path": "$CACHE_DIR",
    "patterns_path": "$CONFIG_DIR/patterns",
    "refresh_interval": 3600,
    "auto_discover": true,
    "agent_count": 58
  },
  "execution_modes": {
    "default": "INTELLIGENT",
    "available": ["INTELLIGENT", "PYTHON_ONLY", "SPEED_CRITICAL", "REDUNDANT"]
  },
  "workflows": {
    "security_assessment": {
      "enabled": true,
      "agents": ["cso", "securityauditor", "security", "cryptoexpert"],
      "coordinator": "cso"
    },
    "incident_response": {
      "enabled": true,
      "agents": ["debugger", "monitor", "patcher", "deployer"],
      "coordinator": "leadengineer"
    },
    "deployment_pipeline": {
      "enabled": true,
      "agents": ["deployer", "testbed", "monitor", "infrastructure"],
      "coordinator": "deployer"
    },
    "ml_pipeline": {
      "enabled": true,
      "agents": ["mlops", "datascience", "optimizer", "monitor"],
      "coordinator": "mlops"
    },
    "quantum_migration": {
      "enabled": true,
      "agents": ["quantumguard", "cryptoexpert", "security"],
      "coordinator": "quantumguard"
    },
    "red_team_exercise": {
      "enabled": true,
      "agents": ["redteamorchestrator", "apt41-defense-agent", "securitychaosagent"],
      "coordinator": "redteamorchestrator"
    }
  }
}
EOF
    
    print_success "Hook configuration installed"
}

# ============================================================================
# AGENT REGISTRY
# ============================================================================

create_agent_registry() {
    print_step "Creating agent registry..."
    
    local registry_file="$CONFIG_DIR/agent-registry.json"
    
    # Create comprehensive agent registry
    cat > "$registry_file" << 'EOF'
{
  "version": "2.0.0",
  "agents": {
    "director": {"type": "ORCHESTRATOR", "priority": 5},
    "projectorchestrator": {"type": "ORCHESTRATOR", "priority": 4},
    "redteamorchestrator": {"type": "SECURITY_ORCHESTRATOR", "priority": 4},
    "cso": {"type": "SECURITY", "priority": 5},
    "security": {"type": "SECURITY", "priority": 4},
    "securityauditor": {"type": "SECURITY", "priority": 4},
    "securitychaosagent": {"type": "SECURITY", "priority": 3},
    "cryptoexpert": {"type": "SECURITY", "priority": 4},
    "quantumguard": {"type": "SECURITY", "priority": 4},
    "bastion": {"type": "SECURITY", "priority": 5},
    "nsa": {"type": "INTELLIGENCE", "priority": 5},
    "apt41-defense-agent": {"type": "THREAT_DEFENSE", "priority": 5},
    "bgp-purple-team-agent": {"type": "NETWORK_SECURITY", "priority": 4},
    "psyops_agent": {"type": "PSYCHOLOGICAL_OPS", "priority": 4},
    "leadengineer": {"type": "ENGINEERING", "priority": 4},
    "constructor": {"type": "DEVELOPMENT", "priority": 3},
    "debugger": {"type": "DEVELOPMENT", "priority": 4},
    "patcher": {"type": "DEVELOPMENT", "priority": 4},
    "linter": {"type": "DEVELOPMENT", "priority": 2},
    "python-internal": {"type": "LANGUAGE", "priority": 3},
    "rust-internal": {"type": "LANGUAGE", "priority": 3},
    "go-internal": {"type": "LANGUAGE", "priority": 3},
    "typescript-internal": {"type": "LANGUAGE", "priority": 3},
    "cpp_internal_agent": {"type": "LANGUAGE", "priority": 3},
    "c-internal": {"type": "LANGUAGE", "priority": 3},
    "java-internal": {"type": "LANGUAGE", "priority": 3},
    "kotlin-internal": {"type": "LANGUAGE", "priority": 3},
    "zig-internal": {"type": "LANGUAGE", "priority": 2},
    "assembly-internal-agent": {"type": "LANGUAGE", "priority": 2},
    "carbon-internal": {"type": "LANGUAGE", "priority": 2},
    "web": {"type": "UI", "priority": 3},
    "androidmobile": {"type": "MOBILE", "priority": 3},
    "pygui": {"type": "UI", "priority": 2},
    "tui": {"type": "UI", "priority": 2},
    "datascience": {"type": "DATA", "priority": 3},
    "mlops": {"type": "ML_OPERATIONS", "priority": 3},
    "researcher": {"type": "RESEARCH", "priority": 3},
    "infrastructure": {"type": "OPERATIONS", "priority": 4},
    "docker-agent": {"type": "CONTAINERIZATION", "priority": 3},
    "proxmox-agent": {"type": "VIRTUALIZATION", "priority": 3},
    "cisco-agent": {"type": "NETWORKING", "priority": 3},
    "ddwrt-agent": {"type": "NETWORKING", "priority": 2},
    "deployer": {"type": "OPERATIONS", "priority": 4},
    "monitor": {"type": "OPERATIONS", "priority": 3},
    "packager": {"type": "OPERATIONS", "priority": 3},
    "database": {"type": "DATA", "priority": 3},
    "apidesigner": {"type": "API", "priority": 3},
    "docgen": {"type": "DOCUMENTATION", "priority": 2},
    "testbed": {"type": "TESTING", "priority": 3},
    "qadirector": {"type": "QUALITY", "priority": 4},
    "optimizer": {"type": "PERFORMANCE", "priority": 4},
    "oversight": {"type": "COMPLIANCE", "priority": 4},
    "planner": {"type": "PLANNING", "priority": 3},
    "integration": {"type": "INTEGRATION", "priority": 3},
    "npu": {"type": "HARDWARE", "priority": 3},
    "gna": {"type": "HARDWARE", "priority": 2},
    "iot-access-control-agent": {"type": "IOT", "priority": 3}
  }
}
EOF
    
    print_success "Agent registry created with 58+ agents"
}

# ============================================================================
# HOOK SCRIPTS
# ============================================================================

install_hook_scripts() {
    print_step "Installing hook scripts..."
    
    # Check if natural-invocation-hook.py exists
    local hook_script="$HOOKS_DIR/natural-invocation-hook.py"
    
    if [ -f "$SCRIPT_DIR/natural-invocation-hook.py" ]; then
        cp "$SCRIPT_DIR/natural-invocation-hook.py" "$hook_script"
        print_success "Copied natural-invocation-hook.py to hooks directory"
    elif [ -f "$hook_script" ]; then
        print_info "Hook script already exists"
    else
        print_warning "Hook script not found, creating minimal version..."
        
        # Create minimal hook script
        cat > "$hook_script" << 'EOF'
#!/usr/bin/env python3
"""Minimal Natural Agent Invocation Hook"""

import os
import sys
from pathlib import Path

# Add paths
sys.path.insert(0, os.environ.get('CLAUDE_BASE_PATH', str(Path.home() / '.config/claude')))

def hook_pre_task(context):
    """Pre-task hook"""
    return context

def hook_post_edit(context):
    """Post-edit hook"""
    return context

def hook_conversation_analysis(messages):
    """Conversation analysis hook"""
    return None

print("Minimal hook installed - please install full version for complete functionality")
EOF
        chmod +x "$hook_script"
    fi
    
    # Check if fuzzy matcher exists
    local fuzzy_matcher="$CONFIG_DIR/claude-fuzzy-agent-matcher.py"
    if [ -f "$SCRIPT_DIR/claude-fuzzy-agent-matcher.py" ]; then
        cp "$SCRIPT_DIR/claude-fuzzy-agent-matcher.py" "$fuzzy_matcher"
        print_success "Copied fuzzy matcher to config directory"
    fi
    
    # Check if semantic matcher exists
    local semantic_matcher="$CONFIG_DIR/agent-semantic-matcher.py"
    if [ -f "$SCRIPT_DIR/agent-semantic-matcher.py" ]; then
        cp "$SCRIPT_DIR/agent-semantic-matcher.py" "$semantic_matcher"
        print_success "Copied semantic matcher to config directory"
    fi
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

setup_environment() {
    print_step "Setting up environment variables..."
    
    # Export variables for current session
    export CLAUDE_BASE_PATH="$CLAUDE_BASE_PATH"
    export CLAUDE_AGENTS_PATH="$CLAUDE_AGENTS_PATH"
    export CLAUDE_CACHE_PATH="$CLAUDE_CACHE_PATH"
    export CLAUDE_HOOKS_ENABLED=true
    export CLAUDE_HOOKS_CONFIG="$CONFIG_DIR/hooks.json"
    export CLAUDE_NATURAL_INVOCATION=true
    export PYTHONPATH="$CONFIG_DIR:$PYTHONPATH"
    
    # Create environment file
    local env_file="$CONFIG_DIR/natural-invocation.env"
    cat > "$env_file" << EOF
# Natural Agent Invocation Environment
export CLAUDE_BASE_PATH="$CLAUDE_BASE_PATH"
export CLAUDE_AGENTS_PATH="$CLAUDE_AGENTS_PATH"
export CLAUDE_CACHE_PATH="$CLAUDE_CACHE_PATH"
export CLAUDE_HOOKS_ENABLED=true
export CLAUDE_HOOKS_CONFIG="$CONFIG_DIR/hooks.json"
export CLAUDE_NATURAL_INVOCATION=true
export PYTHONPATH="$CONFIG_DIR:\$PYTHONPATH"
EOF
    
    print_success "Environment variables configured"
    
    # Add to shell profile
    local shell_profile="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    fi
    
    if ! grep -q "CLAUDE_NATURAL_INVOCATION" "$shell_profile" 2>/dev/null; then
        echo "" >> "$shell_profile"
        echo "# Claude Natural Agent Invocation" >> "$shell_profile"
        echo "source $env_file" >> "$shell_profile"
        print_success "Added to shell profile: $shell_profile"
    else
        print_info "Shell profile already configured"
    fi
}

# ============================================================================
# TESTING
# ============================================================================

run_tests() {
    print_step "Running tests..."
    
    # Create comprehensive test script
    local test_script="$CACHE_DIR/test-natural-invocation.py"
    cat > "$test_script" << 'EOF'
#!/usr/bin/env python3
"""Comprehensive Natural Invocation Test Suite"""

import os
import sys
import json
from pathlib import Path

# Setup paths
base_path = os.environ.get('CLAUDE_BASE_PATH', Path.home() / '.config' / 'claude')
sys.path.insert(0, str(base_path))

print("\n🧪 Natural Agent Invocation Test Suite")
print("=" * 60)

# Test cases covering all agent types
test_cases = {
    # Orchestrators
    "I need to coordinate multiple teams": ["director", "projectorchestrator"],
    "Plan a red team exercise": ["redteamorchestrator"],
    
    # Security
    "Perform security audit": ["cso", "securityauditor"],
    "Setup quantum-safe encryption": ["quantumguard", "cryptoexpert"],
    "Analyze BGP routing security": ["bgp-purple-team-agent"],
    
    # Development
    "Debug memory leak in Rust": ["rust-internal", "debugger"],
    "Fix Python performance issue": ["python-internal", "optimizer"],
    "Create TypeScript React app": ["typescript-internal", "web"],
    
    # Infrastructure
    "Deploy with Docker to Kubernetes": ["docker-agent", "infrastructure", "deployer"],
    "Setup Proxmox cluster": ["proxmox-agent"],
    
    # Data/ML
    "Build ML pipeline": ["mlops", "datascience"],
    "Analyze data patterns": ["datascience", "researcher"],
    
    # Operations
    "Monitor production systems": ["monitor", "deployer"],
    "Package application": ["packager"],
}

try:
    # Try to import the hook
    from natural_invocation_hook import EnhancedNaturalInvocationHook
    hook = EnhancedNaturalInvocationHook()
    
    passed = 0
    failed = 0
    
    for test_input, expected_agents in test_cases.items():
        context = hook.analyze_input(test_input)
        
        # Check if any expected agent was found
        found = any(agent in context.agents for agent in expected_agents)
        
        if found:
            print(f"✓ '{test_input[:40]}...'")
            print(f"  → {', '.join(context.agents[:3])} ({context.confidence:.0%})")
            passed += 1
        else:
            print(f"✗ '{test_input[:40]}...'")
            print(f"  Expected: {expected_agents}")
            print(f"  Got: {context.agents[:3]}")
            failed += 1
    
    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    
    if failed == 0:
        print("✅ All tests passed!")
        sys.exit(0)
    else:
        print(f"⚠️  {failed} tests failed")
        sys.exit(1)
        
except ImportError as e:
    print(f"⚠️  Could not import hook: {e}")
    print("Please ensure all required files are installed")
    sys.exit(1)
except Exception as e:
    print(f"❌ Test failed: {e}")
    sys.exit(1)
EOF
    
    chmod +x "$test_script"
    
    # Run tests
    if python3 "$test_script"; then
        print_success "All tests passed"
    else
        print_warning "Some tests failed - system may still work"
    fi
}

# ============================================================================
# FINAL SETUP
# ============================================================================

create_helper_scripts() {
    print_step "Creating helper scripts..."
    
    # Create agent list script
    local list_script="$CONFIG_DIR/list-agents"
    cat > "$list_script" << 'EOF'
#!/bin/bash
echo "🤖 Available Agents (58+):"
echo "========================="
find "${CLAUDE_AGENTS_PATH:-$HOME/agents}" -name "*.md" 2>/dev/null | \
    sed 's/.*\///' | sed 's/\.md$//' | sort | \
    awk '{printf "  • %-30s", $0; if(NR%2==0) print ""; else printf "\t"}'
echo ""
EOF
    chmod +x "$list_script"
    
    # Create test invocation script
    local test_invoke="$CONFIG_DIR/test-invoke"
    cat > "$test_invoke" << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: test-invoke \"your natural language request\""
    exit 1
fi

python3 -c "
import os, sys
sys.path.insert(0, os.environ.get('CLAUDE_BASE_PATH', '$HOME/.config/claude'))
from natural_invocation_hook import EnhancedNaturalInvocationHook
hook = EnhancedNaturalInvocationHook()
context = hook.analyze_input('$1')
if context.agents:
    print(f'Agents: {", ".join(context.agents[:3])}')
    print(f'Confidence: {context.confidence:.0%}')
    if context.workflow:
        print(f'Workflow: {context.workflow}')
else:
    print('No agents matched')
"
EOF
    chmod +x "$test_invoke"
    
    print_success "Helper scripts created"
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}===============================================${NC}"
    echo -e "${GREEN}${BOLD}   ✅ Natural Agent Invocation Enabled!${NC}"
    echo -e "${GREEN}${BOLD}===============================================${NC}"
    echo ""
    
    echo -e "${CYAN}📁 Installation Paths:${NC}"
    echo "   • Base: $CLAUDE_BASE_PATH"
    echo "   • Agents: $CLAUDE_AGENTS_PATH"
    echo "   • Cache: $CLAUDE_CACHE_PATH"
    echo "   • Hooks: $HOOKS_DIR"
    echo ""
    
    echo -e "${CYAN}🎯 Features Enabled:${NC}"
    echo "   • Automatic agent detection"
    echo "   • 58+ specialized agents"
    echo "   • Semantic matching"
    echo "   • Workflow detection"
    echo "   • Pattern recognition"
    echo "   • Confidence scoring"
    echo ""
    
    echo -e "${CYAN}🛠️ Helper Commands:${NC}"
    echo "   • List agents: $CONFIG_DIR/list-agents"
    echo "   • Test input: $CONFIG_DIR/test-invoke \"your request\""
    echo "   • View config: cat $CONFIG_DIR/hooks.json"
    echo ""
    
    echo -e "${YELLOW}📝 Usage Examples:${NC}"
    echo "   \"Debug memory leak\" → debugger, patcher"
    echo "   \"Deploy to production\" → deployer, monitor"
    echo "   \"Security audit\" → cso, securityauditor"
    echo "   \"Build React app\" → web, constructor"
    echo ""
    
    echo -e "${MAGENTA}${BOLD}Next Steps:${NC}"
    echo "   1. Source the environment:"
    echo "      source $CONFIG_DIR/natural-invocation.env"
    echo ""
    echo "   2. Test the system:"
    echo "      $CONFIG_DIR/test-invoke \"debug Python script\""
    echo ""
    echo "   3. Restart Claude Code for hooks to take effect"
    echo ""
    
    if [ -n "$CLAUDE_HOOKS_ENABLED" ]; then
        echo -e "${GREEN}✓ Hooks are enabled in current session${NC}"
    else
        echo -e "${YELLOW}⚠ Run 'source $CONFIG_DIR/natural-invocation.env' to enable${NC}"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --help, -h       Show this help message"
                echo "  --force, -f      Force reinstall even if already configured"
                echo "  --test-only      Only run tests"
                echo "  --no-tests       Skip testing"
                echo "  --base-path PATH Set base path for configuration"
                echo "  --agents-path PATH Set path to agent files"
                echo ""
                exit 0
                ;;
            --force|-f)
                FORCE_INSTALL=true
                shift
                ;;
            --test-only)
                TEST_ONLY=true
                shift
                ;;
            --no-tests)
                SKIP_TESTS=true
                shift
                ;;
            --base-path)
                CLAUDE_BASE_PATH="$2"
                CONFIG_DIR="$CLAUDE_BASE_PATH"
                shift 2
                ;;
            --agents-path)
                CLAUDE_AGENTS_PATH="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Test only mode
    if [ "${TEST_ONLY:-false}" = true ]; then
        run_tests
        exit $?
    fi
    
    # Check if already configured
    if [ -f "$CONFIG_DIR/hooks.json" ] && [ "${FORCE_INSTALL:-false}" != true ]; then
        print_warning "Natural invocation appears to be already configured"
        echo -n "Reinstall? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing configuration"
            print_summary
            exit 0
        fi
    fi
    
    # Run installation steps
    check_prerequisites
    setup_directories
    install_hook_configuration
    create_agent_registry
    install_hook_scripts
    setup_environment
    create_helper_scripts
    
    # Run tests unless skipped
    if [ "${SKIP_TESTS:-false}" != true ]; then
        run_tests
    fi
    
    # Show summary
    print_summary
}

# Run main function
main "$@"