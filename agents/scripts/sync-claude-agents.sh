#!/bin/bash
# Auto-sync project agents with Claude Code
# Called by git hooks and installers

cd "/home/ubuntu/Documents/Claude/agents"

echo "Syncing project agents with Claude Code..."

# Run the integration installer
python3 "/home/ubuntu/Documents/Claude/agents/agents/src/python/install_claude_integration.py" --quiet

# Update agent registry
python3 -c "
import sys
sys.path.insert(0, '/home/ubuntu/Documents/Claude/agents/agents/src/python')
from claude_code_integration import create_claude_config
create_claude_config()
print('✓ Agent registry updated')
"

echo "✓ Claude Code agent sync complete"
