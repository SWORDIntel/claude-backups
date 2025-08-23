# Tandem Orchestration System for Claude Code

This directory contains the Tandem Orchestration System configured for Claude Code.

## Available Orchestrators

1. **Production Orchestrator** - Main orchestration engine
2. **Tandem Orchestrator** - Advanced tandem operations
3. **Database Orchestrator** - Database-specific orchestration

## Usage in Claude Code

### Via Task Tool:
```python
Task(subagent_type="general-purpose", prompt="Use orchestrator to coordinate multiple agents for: <task>")
```

### Via Python:
```python
import subprocess
result = subprocess.run([
    "python3", 
    "~/.claude/orchestration/invoke.py",
    "create authentication system with tests"
], capture_output=True, text=True)
```

## Execution Modes

- **INTELLIGENT**: Python orchestrates, leverages best of both layers
- **REDUNDANT**: Both layers execute for critical reliability
- **CONSENSUS**: Both layers must agree on outcomes
- **SPEED_CRITICAL**: C layer only for maximum performance
- **PYTHON_ONLY**: Pure Python for complex logic and library access

## Configuration

See `config.json` for paths and settings.
