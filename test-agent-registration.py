#!/usr/bin/env python3
"""
Test script to register agents with proper case handling
"""

import sys
from pathlib import Path
sys.path.append('./tools')

from register_custom_agents import GlobalAgentCoordinator

def main():
    print("🔧 Testing agent registration with case-sensitive fixes...")
    
    coordinator = GlobalAgentCoordinator()
    
    # Check paths
    print(f"📁 Agents directory: {coordinator.agents_dir}")
    print(f"📁 Project root: {coordinator.project_root}")
    
    # Scan for agents
    print("\n📡 Scanning for agents...")
    agents = coordinator.scan_for_agents()
    
    print(f"\n✅ Found {len(agents)} agents:")
    for name, info in sorted(agents.items()):
        print(f"  • {name} -> {info['file']}")
    
    # Check for DOCGEN specifically
    if 'DOCGEN' in agents:
        print(f"\n✅ DOCGEN found: {agents['DOCGEN']['file']}")
    if 'docgen' in agents:
        print(f"✅ docgen found: {agents['docgen']['file']}")
    
    print(f"\n🎯 Agent keys available: {list(agents.keys())}")
    
    return True

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()