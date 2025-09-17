#!/bin/bash
# Claude Agents Bridge - Global agent access
# Provides command-line access to 60+ specialized agents

BRIDGE_DIR="/home/john/.local/share/claude/bridge"
REGISTRY_FILE="$BRIDGE_DIR/agents_registry.json"

# Show help
show_help() {
    cat << 'EOF'
Claude Agents Bridge v10.0
Command-line access to 60+ specialized agents

Usage:
  claude-agent list                    # List all agents
  claude-agent status                  # Show system status
  claude-agent <agent-name> <prompt>   # Invoke agent

Examples:
  claude-agent director "Create strategic plan"
  claude-agent security "Audit system vulnerabilities"
  claude-agent optimizer "Improve performance"

Available Agents:
  Command & Control: director, projectorchestrator
  Security: security, bastion, cryptoexpert, quantumguard
  Development: architect, constructor, debugger, testbed
  Languages: c-internal, python-internal, rust-internal
  And 50+ more specialized agents...
EOF
}

# List agents
list_agents() {
    if [[ -f "$REGISTRY_FILE" ]]; then
        python3 -c "
import json
with open('$REGISTRY_FILE') as f:
    data = json.load(f)
print(f'📊 Total Agents: {data["total_agents"]}')
print('\n🤖 Available Agents:')
for name, info in sorted(data['agents'].items()):
    print(f'  {name:20} - {info["name"]}')
"
    else
        echo "❌ Agent registry not found"
        exit 1
    fi
}

# Show status
show_status() {
    echo "Claude Agents Bridge v10.0 Status:"
    echo "  Registry: $REGISTRY_FILE"
    if [[ -f "$REGISTRY_FILE" ]]; then
        echo "  Status: ✅ Operational"
        AGENT_COUNT=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['total_agents'])")
        echo "  Agents: $AGENT_COUNT available"
    else
        echo "  Status: ❌ Registry not found"
    fi
}

# Main command handling
case "$1" in
    "list"|"ls")
        list_agents
        ;;
    "status"|"stat")
        show_status
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        # Agent invocation
        AGENT_NAME="$1"
        shift
        PROMPT="$*"

        if [[ -z "$AGENT_NAME" ]] || [[ -z "$PROMPT" ]]; then
            echo "❌ Usage: claude-agent <agent-name> <prompt>"
            exit 1
        fi

        echo "🤖 Invoking agent: $AGENT_NAME"
        echo "📝 Prompt: $PROMPT"
        echo "⚠️  Note: Direct agent invocation requires Claude Code Task tool integration"
        echo "💡 For now, this provides agent discovery and registry management"
        ;;
esac
