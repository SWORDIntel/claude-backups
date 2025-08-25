#!/bin/bash

# Simple test of agent registration functionality

echo "Testing agent registration functionality..."

# Set up environment
CLAUDE_AGENTS_DIR="./agents"
CACHE_DIR="/tmp/claude-test-cache-$$"
mkdir -p "$CACHE_DIR"

# Function to register agents
register_agents() {
    local agents_dir="$1"
    local registry_file="$CACHE_DIR/registered_agents.json"
    
    echo "Registering agents from: $agents_dir"
    
    if [[ ! -d "$agents_dir" ]]; then
        echo "ERROR: Agents directory not found: $agents_dir"
        return 1
    fi
    
    local count=0
    echo '{"agents": {}}' > "$registry_file"
    
    while IFS= read -r agent_file; do
        local agent_name=$(basename "$agent_file" | sed 's/\.md$//')
        echo "  Found agent: $agent_name"
        ((count++))
    done < <(find "$agents_dir" -maxdepth 1 -type f -name "*.md" 2>/dev/null | head -10)
    
    echo "Total agents found: $count"
    return 0
}

# Run the test
register_agents "$CLAUDE_AGENTS_DIR"

# Cleanup
rm -rf "$CACHE_DIR"

echo "Test complete."