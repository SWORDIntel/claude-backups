# Tandem Orchestration System - Global Access Setup

## Overview
The Tandem Orchestration System is now fully configured for global access from Claude Code, regardless of which directory you launch from.

## What Was Set Up

### 1. Orchestration Files in ~/.claude/orchestration/
The following files are now accessible to Claude Code:

```
~/.claude/orchestration/
├── production_orchestrator.py -> /home/.../agents/src/python/production_orchestrator.py
├── tandem_orchestrator.py -> /home/.../agents/src/python/tandem_orchestrator.py
├── agent_registry.py -> /home/.../agents/src/python/agent_registry.py
├── orchestrator_metrics.py -> /home/.../agents/src/python/orchestrator_metrics.py
├── database_orchestrator.py -> /home/.../agents/src/python/database_orchestrator.py
├── config.json (configuration file)
├── invoke.py (helper script)
└── README.md (documentation)
```

### 2. Configuration File
Created `~/.claude/orchestration/config.json` with:
- Project root path
- Agents directory location
- Python paths for imports
- Virtual environment location
- Available orchestrators
- Execution modes

### 3. Helper Script
`~/.claude/orchestration/invoke.py` allows Claude to:
- Invoke orchestrators with tasks
- Manage Python paths automatically
- Activate virtual environment if available
- Return structured results

### 4. Automatic Sync
The cron job now also maintains orchestration links:
```bash
*/5 * * * * sync-claude-agents-enhanced.sh
```

## How Claude Code Can Use Orchestration

### Method 1: Via Task Tool (Recommended)
When Claude detects a complex multi-agent task, it can use:
```python
Task(
    subagent_type="general-purpose",
    prompt="Coordinate agents using orchestrator for: creating authentication with tests and security review"
)
```

### Method 2: Direct Python Invocation
```python
import subprocess
import json

# Invoke production orchestrator
result = subprocess.run([
    "python3",
    os.path.expanduser("~/.claude/orchestration/invoke.py"),
    "create user authentication system with comprehensive tests",
    "production"  # or "tandem"
], capture_output=True, text=True)

# Process result
if result.returncode == 0:
    print("Orchestration successful:", result.stdout)
else:
    print("Error:", result.stderr)
```

### Method 3: Via Shell Command
```bash
# From Claude's bash tool
python3 ~/.claude/orchestration/invoke.py "coordinate agents for API development" production
```

## Execution Modes Available

The Tandem Orchestration System supports 5 execution modes:

1. **INTELLIGENT** - Python orchestrates, leverages best capabilities
2. **REDUNDANT** - Multiple agents execute for critical reliability
3. **CONSENSUS** - Multiple agents must agree on outcomes
4. **SPEED_CRITICAL** - Optimized for maximum performance
5. **PYTHON_ONLY** - Pure Python for complex logic and libraries

## Available Orchestrators

### 1. Production Orchestrator
- **Path**: `~/.claude/orchestration/production_orchestrator.py`
- **Purpose**: Main production-ready orchestration engine
- **Features**: Full agent coordination, workflow management, error handling

### 2. Tandem Orchestrator
- **Path**: `~/.claude/orchestration/tandem_orchestrator.py`
- **Purpose**: Advanced tandem operations with dual-layer execution
- **Features**: Python/C coordination, hardware optimization

### 3. Database Orchestrator
- **Path**: `~/.claude/orchestration/database_orchestrator.py`
- **Purpose**: Database-specific orchestration
- **Features**: PostgreSQL 17 optimization, query coordination

## Agent Registry

The `agent_registry.py` provides:
- Automatic discovery of all 47 agents
- Health monitoring and capability mapping
- Dynamic agent allocation based on availability
- YAML frontmatter parsing for agent metadata

## Testing the Setup

### From Terminal:
```bash
# Test orchestrator invocation
python3 ~/.claude/orchestration/invoke.py "test orchestration" production

# Check orchestration files
ls -la ~/.claude/orchestration/

# View configuration
cat ~/.claude/orchestration/config.json

# Check if orchestrator command works globally
orchestrator
```

### From Claude Code:
Ask Claude to:
1. "Use the orchestrator to coordinate multiple agents for creating a feature"
2. "Show me available orchestration modes"
3. "Invoke the tandem orchestrator for a complex task"

## Workflow Examples

### Example 1: Feature Development
```
Task: "Create user authentication with tests and documentation"
Orchestrator coordinates:
  → ARCHITECT: Design system
  → CONSTRUCTOR: Build implementation
  → TESTBED: Create tests
  → SECURITY: Security review
  → DOCGEN: Generate documentation
```

### Example 2: Bug Fix Pipeline
```
Task: "Debug and fix performance issue in API"
Orchestrator coordinates:
  → DEBUGGER: Analyze issue
  → OPTIMIZER: Identify bottlenecks
  → PATCHER: Apply fixes
  → TESTBED: Validate fixes
  → MONITOR: Verify performance
```

### Example 3: Deployment Workflow
```
Task: "Deploy application with monitoring"
Orchestrator coordinates:
  → INFRASTRUCTURE: Prepare environment
  → DEPLOYER: Execute deployment
  → MONITOR: Set up monitoring
  → SECURITY: Security validation
```

## Troubleshooting

### If orchestration doesn't work:

1. **Check symlinks**:
   ```bash
   ls -la ~/.claude/orchestration/*.py
   ```

2. **Verify configuration**:
   ```bash
   python3 -c "import json; print(json.load(open('$HOME/.claude/orchestration/config.json')))"
   ```

3. **Test invoke script**:
   ```bash
   python3 ~/.claude/orchestration/invoke.py "test" production
   ```

4. **Check Python path**:
   ```bash
   python3 -c "import sys; print('\n'.join(sys.path))"
   ```

5. **Run setup again**:
   ```bash
   /home/siducer/Documents/Claude/scripts/setup-tandem-for-claude.sh
   ```

## Files Created

1. **Setup Script**: `/home/siducer/Documents/Claude/scripts/setup-tandem-for-claude.sh`
2. **Config File**: `~/.claude/orchestration/config.json`
3. **Helper Script**: `~/.claude/orchestration/invoke.py`
4. **Symlinks**: All orchestrator Python files linked
5. **Documentation**: `~/.claude/orchestration/README.md`

## Summary

✅ **Tandem Orchestration is now globally accessible!**

The system provides:
- Full orchestration capabilities from any directory
- Access to all 47 agents for coordination
- 5 execution modes for different requirements
- Automatic synchronization every 5 minutes
- Helper scripts for easy invocation

Claude Code can now coordinate complex multi-agent workflows using the Tandem Orchestration System, regardless of where it's launched from!