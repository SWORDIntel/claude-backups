#!/usr/bin/env python3
"""
Claude Code Orchestration Invoker
Allows Claude to invoke the Tandem Orchestration System
"""

import json
import os
import subprocess
import sys
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
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, executable="/bin/bash"
        )
    else:
        # Run without venv
        result = subprocess.run(
            [sys.executable, orchestrator_path, "--task", task],
            capture_output=True,
            text=True,
        )

    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode,
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
