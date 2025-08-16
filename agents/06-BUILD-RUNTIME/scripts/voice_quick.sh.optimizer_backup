#!/bin/bash
# Quick voice command
if [ $# -eq 0 ]; then
    echo "Usage: voice 'your command'"
    echo "Example: voice 'plan my project'"
    exit 1
fi

python3 -c "
import asyncio
import sys
sys.path.append('/home/ubuntu/Documents/Claude/agents')
from claude_agent_bridge import task_agent_invoke

async def quick_voice():
    command = '$1'
    # Simple agent detection
    if 'plan' in command or 'strategy' in command:
        agent = 'DIRECTOR'
    elif 'security' in command or 'audit' in command:
        agent = 'SECURITY'
    elif 'design' in command or 'architecture' in command:
        agent = 'ARCHITECT'
    else:
        agent = 'DIRECTOR'
    
    print(f'🎤 Routing to {agent}: {command}')
    try:
        result = await task_agent_invoke(agent, command)
        print(f'✅ {agent} completed: {result.get("status", "success")}')
    except Exception as e:
        print(f'❌ Error: {e}')

asyncio.run(quick_voice())
"
