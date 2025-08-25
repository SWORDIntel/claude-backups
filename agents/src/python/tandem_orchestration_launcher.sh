#!/bin/bash
# Minimal Tandem Orchestrator Launcher
export CLAUDE_AGENTS_ROOT="${HOME}/Documents/claude-backups/agents"
export PYTHONPATH="${CLAUDE_AGENTS_ROOT}/src/python:${PYTHONPATH}"

echo "Starting Tandem Orchestration System..."
cd "${CLAUDE_AGENTS_ROOT}/src/python"

python3 -c "
import asyncio
from production_orchestrator import ProductionOrchestrator

async def start():
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    print(f'✓ System online with {len(orchestrator.list_available_agents())} agents')

asyncio.run(start())
"
