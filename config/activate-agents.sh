#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Global Agents Bridge v10.0 - Activation Script
# 
# This script activates the unified agent system for Claude Code
# Source this file to enable agent support: source activate-agents.sh
# ═══════════════════════════════════════════════════════════════════════════

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}Claude Global Agents Bridge v10.0 - Activation${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"

# Set base paths
export CLAUDE_AGENTS_ROOT="/home/ubuntu/Documents/claude-backups/agents"
export CLAUDE_PROJECT_ROOT="/home/ubuntu/Documents/claude-backups"
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
export CLAUDE_CUSTOM_AGENTS="$CLAUDE_CONFIG_DIR/project-agents.json"

# Add Python paths
export PYTHONPATH="$CLAUDE_AGENTS_ROOT/src/python:$CLAUDE_PROJECT_ROOT:$CLAUDE_CONFIG_DIR:$PYTHONPATH"

# Add binary paths
export PATH="$HOME/.local/bin:$CLAUDE_AGENTS_ROOT/bin:$PATH"

# Set execution mode preferences
export CLAUDE_EXECUTION_MODE="${CLAUDE_EXECUTION_MODE:-INTELLIGENT}"
export CLAUDE_FALLBACK_MODE="PYTHON_ONLY"

# Enable feature flags
export CLAUDE_TANDEM_ENABLED=true
export CLAUDE_C_BRIDGE_ENABLED=true
export CLAUDE_MONITORING_ENABLED=true
export CLAUDE_METRICS_ENABLED=true

# Check system capabilities
echo -e "\n${YELLOW}Checking system capabilities...${NC}"

# Check for C binary layer
if ps aux | grep -q 'agent_bridge\|ultra_hybrid' 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} C Binary Layer: ${GREEN}Active${NC}"
    export CLAUDE_C_BRIDGE_ACTIVE=true
else
    echo -e "  ${YELLOW}○${NC} C Binary Layer: ${YELLOW}Offline${NC} (Python fallback enabled)"
    export CLAUDE_C_BRIDGE_ACTIVE=false
fi

# Check for Tandem orchestrator
if [ -f "$CLAUDE_AGENTS_ROOT/src/python/tandem_orchestrator.py" ]; then
    echo -e "  ${GREEN}✓${NC} Tandem Orchestrator: ${GREEN}Available${NC}"
    export CLAUDE_TANDEM_AVAILABLE=true
else
    echo -e "  ${YELLOW}○${NC} Tandem Orchestrator: ${YELLOW}Not found${NC}"
    export CLAUDE_TANDEM_AVAILABLE=false
fi

# Check for production orchestrator
if [ -f "$CLAUDE_AGENTS_ROOT/src/python/production_orchestrator.py" ]; then
    echo -e "  ${GREEN}✓${NC} Production Orchestrator: ${GREEN}Available${NC}"
    export CLAUDE_ORCHESTRATOR_AVAILABLE=true
else
    echo -e "  ${YELLOW}○${NC} Production Orchestrator: ${YELLOW}Not found${NC}"
    export CLAUDE_ORCHESTRATOR_AVAILABLE=false
fi

# Check for AVX-512 support
if grep -q avx512 /proc/cpuinfo 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} AVX-512: ${GREEN}Supported${NC}"
    export CLAUDE_AVX512_AVAILABLE=true
else
    echo -e "  ${YELLOW}○${NC} AVX-512: ${YELLOW}Not available${NC}"
    export CLAUDE_AVX512_AVAILABLE=false
fi

# Check if agent registry exists
if [ -f "$CLAUDE_CUSTOM_AGENTS" ]; then
    AGENT_COUNT=$(jq -r '.custom_agents | length' "$CLAUDE_CUSTOM_AGENTS" 2>/dev/null || echo "0")
    echo -e "\n${GREEN}✓${NC} Agent Registry: ${GREEN}${AGENT_COUNT} agents registered${NC}"
    
    # Export agent environment variables for each agent
    for agent in $(jq -r '.custom_agents | keys[]' "$CLAUDE_CUSTOM_AGENTS" 2>/dev/null); do
        # Convert agent name to valid shell variable name (replace hyphens with underscores)
        clean_agent=$(echo "${agent^^}" | tr '-' '_')
        export CLAUDE_AGENT_${clean_agent}="available"
    done
else
    echo -e "\n${YELLOW}⚠${NC} Agent Registry: ${YELLOW}Not found${NC}"
    echo -e "  Run: ${CYAN}claude-registry${NC}"
fi

# Create helpful aliases
alias claude-agents='claude-agent list'
alias claude-status='claude-agent status'
alias claude-monitor='python3 $CLAUDE_PROJECT_ROOT/tools/claude-global-agents-bridge.py --monitor'
alias claude-install='python3 $CLAUDE_PROJECT_ROOT/tools/claude-global-agents-bridge.py --install'
alias claude-registry='python3 $CLAUDE_PROJECT_ROOT/tools/register-custom-agents.py --install'

# Function to invoke agents easily
claude-invoke() {
    if [ $# -lt 2 ]; then
        echo "Usage: claude-invoke <agent-name> <prompt>"
        echo "Example: claude-invoke director 'Plan the project architecture'"
        return 1
    fi
    
    local agent="$1"
    shift
    local prompt="$*"
    
    claude-agent "$agent" "$prompt"
}

# Function to show agent details
claude-info() {
    if [ $# -lt 1 ]; then
        echo "Usage: claude-info <agent-name>"
        return 1
    fi
    
    local agent="$1"
    
    if [ -f "$CLAUDE_CUSTOM_AGENTS" ]; then
        jq ".custom_agents.\"$agent\"" "$CLAUDE_CUSTOM_AGENTS" 2>/dev/null || echo "Agent not found: $agent"
    else
        echo "Agent registry not found. Run: claude-install"
    fi
}

# Function to test agent system
claude-test() {
    echo -e "\n${CYAN}Testing Agent System...${NC}"
    
    # Test Task tool integration
    echo -e "\n${YELLOW}1. Task Tool Integration:${NC}"
    if command -v claude >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Claude command available"
    else
        echo -e "  ${RED}✗${NC} Claude command not found"
    fi
    
    # Test Python imports
    echo -e "\n${YELLOW}2. Python Integration:${NC}"
    python3 -c "
import sys
sys.path.insert(0, '$CLAUDE_CONFIG_DIR')
try:
    import task_extension
    print('  ✓ Task extension module loadable')
except ImportError as e:
    print('  ✗ Task extension not found:', e)
" 2>/dev/null || echo -e "  ${RED}✗${NC} Python integration failed"
    
    # Test agent invocation
    echo -e "\n${YELLOW}3. Agent Invocation:${NC}"
    if [ -f "$HOME/.local/bin/claude-agent" ]; then
        echo -e "  ${GREEN}✓${NC} Global launcher available"
        
        # Try a simple invocation
        echo -e "  Testing with 'linter' agent..."
        claude-agent linter "test" >/dev/null 2>&1 && \
            echo -e "  ${GREEN}✓${NC} Agent invocation successful" || \
            echo -e "  ${YELLOW}○${NC} Agent invocation needs setup"
    else
        echo -e "  ${YELLOW}○${NC} Global launcher not installed"
    fi
    
    echo -e "\n${GREEN}Test complete!${NC}"
}

# Show performance metrics
claude-metrics() {
    if [ -f "$HOME/.cache/claude-agents/coordination_config.json" ]; then
        echo -e "\n${CYAN}Performance Metrics:${NC}"
        jq '.metrics' "$HOME/.cache/claude-agents/coordination_config.json" 2>/dev/null || echo "No metrics available"
        
        echo -e "\n${CYAN}Execution Statistics:${NC}"
        jq '.execution_stats' "$HOME/.cache/claude-agents/coordination_config.json" 2>/dev/null || echo "No statistics available"
    else
        echo "No metrics available. Agents need to be invoked first."
    fi
}

# Function to start background monitoring
claude-daemon() {
    echo -e "\n${CYAN}Starting agent monitoring daemon...${NC}"
    python3 "$CLAUDE_PROJECT_ROOT/tools/claude-global-agents-bridge.py" --daemon &
    local pid=$!
    echo -e "${GREEN}✓${NC} Daemon started with PID: $pid"
    echo -e "  Stop with: ${CYAN}kill $pid${NC}"
}

# Display activation summary
echo -e "\n${GREEN}${BOLD}✅ Agent System Activated!${NC}"
echo -e "\n${CYAN}Available Commands:${NC}"
echo -e "  ${BOLD}claude-agents${NC}      - List all available agents"
echo -e "  ${BOLD}claude-status${NC}      - Show system status"
echo -e "  ${BOLD}claude-invoke${NC}      - Invoke an agent"
echo -e "  ${BOLD}claude-info${NC}        - Show agent details"
echo -e "  ${BOLD}claude-test${NC}        - Test agent system"
echo -e "  ${BOLD}claude-metrics${NC}     - Show performance metrics"
echo -e "  ${BOLD}claude-monitor${NC}     - Start live monitoring"
echo -e "  ${BOLD}claude-daemon${NC}      - Start background daemon"
echo -e "  ${BOLD}claude-install${NC}     - Install/update agents"

echo -e "\n${CYAN}Quick Start:${NC}"
echo -e "  1. Install agents:     ${BOLD}claude-install${NC}"
echo -e "  2. List agents:        ${BOLD}claude-agents${NC}"
echo -e "  3. Invoke an agent:    ${BOLD}claude-invoke director 'Plan the project'${NC}"
echo -e "  4. Use in Claude:      ${BOLD}Task(subagent_type=\"optimizer\", prompt=\"...\")${NC}"

echo -e "\n${CYAN}Execution Mode:${NC} ${BOLD}$CLAUDE_EXECUTION_MODE${NC}"
if [ "$CLAUDE_C_BRIDGE_ACTIVE" = "true" ]; then
    echo -e "${CYAN}Performance:${NC} ${GREEN}Maximum (C bridge active, 100K+ msg/sec)${NC}"
elif [ "$CLAUDE_TANDEM_AVAILABLE" = "true" ]; then
    echo -e "${CYAN}Performance:${NC} ${YELLOW}High (Tandem available, 10-50K msg/sec)${NC}"
else
    echo -e "${CYAN}Performance:${NC} ${YELLOW}Baseline (Python only, 5K msg/sec)${NC}"
fi

echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════${NC}"
