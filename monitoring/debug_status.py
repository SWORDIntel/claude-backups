#!/usr/bin/env python3
"""
Debug version of Claude Terminal Status Monitor
Prints status to console to verify tracking is working
"""

import json
import subprocess
import psutil
from pathlib import Path
from datetime import datetime

def check_agent_status():
    """Check status of all agents and modules"""
    agents_online = 0

    # Check agent registry
    registry_path = Path.home() / ".cache/claude/registered_agents.json"
    if registry_path.exists():
        try:
            with open(registry_path) as f:
                registry = json.load(f)
                if 'agents' in registry:
                    agents_online = len(registry['agents'])
        except Exception as e:
            print(f"Error reading agent registry: {e}")

    return agents_online

def check_modules():
    """Check all modules"""
    modules = {}

    # PostgreSQL
    try:
        result = subprocess.run(['pg_isready', '-p', '5433'], capture_output=True, timeout=2)
        modules['PostgreSQL'] = result.returncode == 0
    except:
        modules['PostgreSQL'] = False

    # OpenVINO
    try:
        import openvino
        modules['OpenVINO'] = True
    except ImportError:
        modules['OpenVINO'] = False

    # Shadowgit
    shadowgit_path = Path('/home/john/claude-backups/hooks/shadowgit')
    modules['Shadowgit'] = shadowgit_path.exists() and (shadowgit_path / 'python').exists()

    # Agent Systems
    modules['Agent Systems'] = (Path.home() / ".local/share/claude/agents").exists()

    # Orchestration
    modules['Orchestration'] = Path("/home/john/claude-backups/orchestration").exists()

    # Integration
    modules['Integration'] = Path("/home/john/claude-backups/integration").exists()

    # C Agent Engine
    modules['C Agent Engine'] = Path("/home/john/claude-backups/agents/src/c").exists()

    # NPU
    modules['NPU'] = Path('/dev/accel/accel0').exists()

    return modules

def check_hardware():
    """Check hardware status"""
    try:
        # CPU temperature
        temps = psutil.sensors_temperatures()
        cpu_temp = 0
        if 'coretemp' in temps:
            cpu_temp = max([t.current for t in temps['coretemp']])
        elif temps:
            first_sensor = list(temps.values())[0]
            cpu_temp = max([t.current for t in first_sensor])

        # Memory usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent

        return cpu_temp, memory_percent
    except:
        return 0, 0

if __name__ == "__main__":
    print("=== Claude Agent Framework Status Debug ===")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    # Check agents
    agents_online = check_agent_status()
    print(f"Agents Online: {agents_online}/466")

    # Check modules
    modules = check_modules()
    modules_online = sum(1 for status in modules.values() if status)
    print(f"Modules Online: {modules_online}/{len(modules)}")

    print("\nModule Details:")
    for name, status in modules.items():
        status_text = "●" if status else "✗"
        print(f"  {name}: {status_text}")

    # Check hardware
    cpu_temp, memory_usage = check_hardware()
    print(f"\nHardware:")
    print(f"  CPU Temp: {cpu_temp:.1f}°C")
    print(f"  Memory Usage: {memory_usage:.1f}%")

    print("\n=== End Debug ===")