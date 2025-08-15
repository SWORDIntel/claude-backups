# Agent Bridge System

## Overview
The bridges in this directory connect Claude Code to the agent system and binary protocol.

## Main Files

### Core Bridge (USE THIS)
- **`unified_bridge.py`** - Main consolidated bridge with all functionality
  - Binary protocol connection
  - Agent invocation (`task_agent_invoke`)
  - Status line management
  - Voice system integration
  - Monitoring and metrics

### Legacy/Support Files
- **`agent_bridge_main.py`** - Original main bridge (kept for compatibility)
- **`claude_agent_bridge.py`** - Configuration and connection helpers
- **`statusline_bridge.py`** - Status line management (functionality now in unified_bridge)
- **`voice_system.py`** - Voice input system (functionality now in unified_bridge)
- **`bridge_monitor.py`** - Monitoring system (functionality now in unified_bridge)
- **`agent_server.py`** - Binary protocol server
- **`test_agent_communication.py`** - Testing utilities

### Deprecated/To Remove
- **`agent_config_py.py`** - Duplicate of claude_agent_bridge.py (REMOVE)
- **`auto_integrate.py`** - Broken imports, outdated (REMOVE)

## Usage

### From Python/Claude Code:
```python
from unified_bridge import task_agent_invoke, get_statusline, list_available_agents

# Invoke an agent
result = task_agent_invoke("Director", "Plan the next steps")

# Get status
status = get_statusline().get_status_line()

# List agents
agents = list_available_agents()
```

### From Shell:
```bash
# Test the system
python3 /home/ubuntu/Documents/Claude/agents/03-BRIDGES/unified_bridge.py

# Get status
python3 -c "from unified_bridge import get_bridge; print(get_bridge().get_status())"
```

## Configuration
All paths are configured in `unified_bridge.Config` class:
- Runtime: `/06-BUILD-RUNTIME/runtime/`
- Build: `/06-BUILD-RUNTIME/build/`
- Config: `/05-CONFIG/`
- Agent definitions: `/01-AGENTS-DEFINITIONS/ACTIVE/`

## Features
1. **Binary Bridge Connection** - Connects to C binary protocol when available
2. **Agent Invocation** - Routes tasks to agents via binary or Python
3. **Status Line** - Real-time status display with metrics
4. **Voice System** - Voice command processing (when enabled)
5. **Monitoring** - System health and performance metrics
6. **Fallback Logic** - Works even if binary protocol is offline

## Migration Plan
1. Update all imports to use `unified_bridge`
2. Remove duplicate files (agent_config_py.py, auto_integrate.py)
3. Eventually deprecate individual bridge files
4. Keep agent_server.py for binary protocol server