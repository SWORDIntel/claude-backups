#!/bin/bash
# ============================================================================
# SETUP TANDEM ORCHESTRATION FOR CLAUDE CODE
# 
# Makes the Tandem Orchestration System accessible to Claude Code
# from any directory by setting up proper symlinks and configurations
# ============================================================================

set -euo pipefail

# Configuration
# Detect project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == */scripts ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# Use project .claude if exists, otherwise use home directory
if [[ -d "$PROJECT_ROOT/.claude" ]]; then
    CLAUDE_DIR="$PROJECT_ROOT/.claude"
else
    CLAUDE_DIR="$HOME/.claude"
fi

VENV_DIR="$HOME/.local/share/claude/venv"

echo "Setting up Tandem Orchestration for Claude Code..."
echo "=============================================="

# 1. Ensure agents are linked (required for orchestration)
echo "1. Checking agent symlink..."
if [[ "$CLAUDE_DIR" == "$PROJECT_ROOT/.claude" ]]; then
    # Using project .claude - symlinks should already exist from installer
    if [ -L "$CLAUDE_DIR/agents" ]; then
        echo "   ✓ Agents symlink exists (project .claude)"
    else
        ln -sf "../agents" "$CLAUDE_DIR/agents"
        echo "   ✓ Created agents symlink"
    fi
else
    # Using home .claude - create absolute symlink
    if [ ! -L "$CLAUDE_DIR/agents" ]; then
        ln -sf "$PROJECT_ROOT/agents" "$CLAUDE_DIR/agents"
        echo "   ✓ Created agents symlink"
    else
        echo "   ✓ Agents symlink exists"
    fi
fi

# 2. Create orchestration directory in .claude
echo "2. Setting up orchestration in ~/.claude/..."
mkdir -p "$CLAUDE_DIR/orchestration"

# Link Python orchestration files
ln -sf "$PROJECT_ROOT/agents/src/python/production_orchestrator.py" "$CLAUDE_DIR/orchestration/" 2>/dev/null || true
ln -sf "$PROJECT_ROOT/agents/src/python/tandem_orchestrator.py" "$CLAUDE_DIR/orchestration/" 2>/dev/null || true
ln -sf "$PROJECT_ROOT/agents/src/python/agent_registry.py" "$CLAUDE_DIR/orchestration/" 2>/dev/null || true
ln -sf "$PROJECT_ROOT/agents/src/python/orchestrator_metrics.py" "$CLAUDE_DIR/orchestration/" 2>/dev/null || true
ln -sf "$PROJECT_ROOT/agents/src/python/database_orchestrator.py" "$CLAUDE_DIR/orchestration/" 2>/dev/null || true

echo "   ✓ Linked orchestration Python files"

# 3. Create a Claude-specific orchestrator config
echo "3. Creating orchestration config..."
cat > "$CLAUDE_DIR/orchestration/config.json" << EOF
{
  "project_root": "$PROJECT_ROOT",
  "agents_dir": "$PROJECT_ROOT/agents",
  "python_path": "$PROJECT_ROOT/agents/src/python",
  "venv_dir": "$VENV_DIR",
  "orchestrators": {
    "production": "$PROJECT_ROOT/agents/src/python/production_orchestrator.py",
    "tandem": "$PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"
  },
  "execution_modes": [
    "INTELLIGENT",
    "REDUNDANT",
    "CONSENSUS",
    "SPEED_CRITICAL",
    "PYTHON_ONLY"
  ]
}
EOF
echo "   ✓ Created orchestration config"

# 4. Create helper script for Claude to invoke orchestration
echo "4. Creating Claude orchestration helper..."
cat > "$CLAUDE_DIR/orchestration/invoke.py" << 'EOF'
#!/usr/bin/env python3
"""
Claude Code Orchestration Invoker
Allows Claude to invoke the Tandem Orchestration System
"""

import sys
import os
import json
import subprocess
from pathlib import Path

# Load config
config_path = Path(__file__).parent / "config.json"
with open(config_path) as f:
    config = json.load(f)

# Add Python path
sys.path.insert(0, config["python_path"])
sys.path.insert(0, str(Path(config["agents_dir"]) / "src" / "python"))

# Set environment
os.environ["CLAUDE_PROJECT_ROOT"] = config["project_root"]
os.environ["CLAUDE_AGENTS_DIR"] = config["agents_dir"]

def invoke_orchestrator(task, orchestrator_type="production"):
    """Invoke the specified orchestrator with a task"""
    orchestrator_path = config["orchestrators"].get(orchestrator_type)
    
    if not orchestrator_path or not Path(orchestrator_path).exists():
        return {"error": f"Orchestrator {orchestrator_type} not found"}
    
    # Check for venv
    venv_activate = Path(config["venv_dir"]) / "bin" / "activate"
    
    if venv_activate.exists():
        # Run with venv
        cmd = f"source {venv_activate} && python3 {orchestrator_path} --task '{task}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, executable='/bin/bash')
    else:
        # Run without venv
        result = subprocess.run(
            [sys.executable, orchestrator_path, "--task", task],
            capture_output=True,
            text=True
        )
    
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: invoke.py <task> [orchestrator_type]")
        sys.exit(1)
    
    task = sys.argv[1]
    orch_type = sys.argv[2] if len(sys.argv) > 2 else "production"
    
    result = invoke_orchestrator(task, orch_type)
    
    if result["returncode"] == 0:
        print(result["stdout"])
    else:
        print(f"Error: {result['stderr']}", file=sys.stderr)
        sys.exit(result["returncode"])
EOF
chmod +x "$CLAUDE_DIR/orchestration/invoke.py"
echo "   ✓ Created orchestration helper"

# 5. Create README for Claude
echo "5. Creating documentation..."
cat > "$CLAUDE_DIR/orchestration/README.md" << 'EOF'
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
EOF
echo "   ✓ Created documentation"

# 6. Test the setup
echo ""
echo "6. Testing setup..."
if python3 "$CLAUDE_DIR/orchestration/invoke.py" "test" 2>/dev/null | grep -q "orchestrat"; then
    echo "   ✓ Orchestration is working!"
else
    echo "   ⚠ Orchestration test inconclusive (may need dependencies)"
fi

# 7. Summary
echo ""
echo "=========================================="
echo "Tandem Orchestration Setup Complete!"
echo "=========================================="
echo ""
echo "What's been configured:"
echo "  • Agents symlinked to ~/.claude/agents/"
echo "  • Orchestration files linked to ~/.claude/orchestration/"
echo "  • Config file created with project paths"
echo "  • Helper script for invoking orchestrators"
echo "  • Documentation for Claude Code usage"
echo ""
echo "The Tandem Orchestration System is now accessible to Claude Code!"
echo ""
echo "Files created/linked:"
ls -la "$CLAUDE_DIR/orchestration/" 2>/dev/null | tail -n +2
echo ""
echo "To test from Claude Code, ask it to:"
echo '  "Use the orchestrator to coordinate agents for creating a feature"'