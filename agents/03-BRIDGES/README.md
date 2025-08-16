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

## ULTRATHINK ANALYSIS - Binary System Integration

### 🔥 CRITICAL - Must Start for Binary System:
1. **`unified_bridge.py`** - MAIN bridge consolidating all functionality
2. **`agent_server.py`** - Binary protocol server (handles CAGT protocol)  
3. **`claude_agent_bridge.py`** - Configuration & socket management

### ⚡ SUPPORT - Enhance Functionality:
4. **`bridge_monitor.py`** - System monitoring (functionality in unified_bridge)
5. **`voice_system.py`** - Voice input (functionality in unified_bridge)
6. **`statusline_bridge.py`** - Status display (functionality in unified_bridge)

### ❌ DEPRECATED - Moved to deprecated/:
7. **`deprecated/agent_config_py.py`** - Duplicate of claude_agent_bridge.py
8. **`deprecated/auto_integrate.py`** - Broken imports, outdated paths
9. **`deprecated/*.duplicate`** - Backup copies (cleaned up)
10. **`deprecated/agent_bridge_main.py`** - Legacy, replaced by unified_bridge

### 🔧 UTILITY - Optional:
11. **`test_agent_communication.py`** - Testing framework
12. **`voice_quick.sh`** - Shell voice shortcuts
13. **`VOICE_INPUT_SYSTEM.py`** - Voice toggle system
14. **`quick_voice.py`** - Voice command processor

### Binary System Startup Sequence:
```bash
# 1. Start binary protocol server
python3 03-BRIDGES/agent_server.py &

# 2. Start unified bridge (connects to binary)  
python3 03-BRIDGES/unified_bridge.py &

# 3. Optional: Start monitoring
python3 03-BRIDGES/bridge_monitor.py &
```

### Performance Expectations:
- **NOT 4.2M msg/sec** (that's ridiculous over-engineering)
- **Target: ~50K-100K msg/sec** (realistic for agent coordination)
- **Latency: <10ms P99** (reasonable for agent tasks)
- **Memory: <100MB per bridge** (efficient Python implementation)

## Migration Plan
1. Update switch.sh to start critical components (unified_bridge + agent_server)
2. Remove duplicate files (agent_config_py.py, auto_integrate.py, *.duplicate)
3. Test binary system integration with realistic performance targets
4. Deprecate individual bridge files (keep for compatibility)