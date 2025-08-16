#!/bin/bash
# Verify all agents are properly integrated

echo "Verifying agent integration..."

# Check for communication section in all agent files
for agent in *.md; do
    if [[ "$agent" != "WHERE_I_AM.md" && "$agent" != "Template.md" ]]; then
        if grep -q "COMMUNICATION SYSTEM INTEGRATION" "$agent"; then
            echo "✓ $agent - integrated"
        else
            echo "✗ $agent - NOT integrated"
        fi
    fi
done

# Check for C implementations
echo ""
echo "Checking C implementations..."
for agent in *.md; do
    if [[ "$agent" != "WHERE_I_AM.md" && "$agent" != "Template.md" ]]; then
        agent_name=$(basename "$agent" .md | tr '[:upper:]' '[:lower:]')
        if [ -f "src/c/${agent_name}_agent.c" ]; then
            echo "✓ ${agent_name}_agent.c exists"
        else
            echo "✗ ${agent_name}_agent.c missing"
        fi
    fi
done
