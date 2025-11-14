#!/usr/bin/env python3
"""Manual test of registration system"""

import os
import sys
from pathlib import Path

# Add the tools directory to path
sys.path.insert(0, str(Path(__file__).parent / "tools"))

# Import and test the registration system
try:
    from register_custom_agents import DynamicAgentRegistry

    print("🧪 Testing agent registration manually...")

    registry = DynamicAgentRegistry()
    print(f"Project root: {registry.project_root}")
    print(f"Agents dir: {registry.agents_dir}")
    print(f"Config dir: {registry.config_dir}")

    # Test registration
    result = registry.create_registry()
    print(f"Registration result: {len(result)} items")

    # Test lookups
    registry.test_key_agents(result)

except Exception as e:
    print(f"Error: {e}")
    import traceback

    traceback.print_exc()
