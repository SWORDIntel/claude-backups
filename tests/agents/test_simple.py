#!/usr/bin/env python3
"""
Simple test of core functionality
"""
import sys

# Add project root to Python path for imports
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from path_utilities import (
        get_project_root, get_agents_dir, get_database_dir,
        get_python_src_dir, get_shadowgit_paths, get_database_config
    )
except ImportError:
    # Fallback if path_utilities not available
    def get_project_root():
        return Path(__file__).parent.parent.parent
    def get_agents_dir():
        return get_project_root() / 'agents'
    def get_database_dir():
        return get_project_root() / 'database'
    def get_python_src_dir():
        return get_agents_dir() / 'src' / 'python'
    def get_shadowgit_paths():
        home_dir = Path.home()
        return {'root': home_dir / 'shadowgit'}
    def get_database_config():
        return {
            'host': 'localhost', 'port': 5433,
            'database': 'claude_agents_auth',
            'user': 'claude_agent', 'password': 'claude_auth_pass'
        }
sys.path.insert(0, '.')

# Test minimal imports first
try:
    import asyncio
    import json
    from pathlib import Path
    print("✅ Basic imports successful")
except Exception as e:
    print(f"❌ Basic imports failed: {e}")
    exit(1)

# Test agent file parsing
try:
    import yaml
    agents_dir = Path("/home/ubuntu/Documents/Claude/agents")
    agent_files = list(agents_dir.glob("*.md"))
    excluded = {"Template.md", "README.md", "STATUSLINE_INTEGRATION.md"}
    valid_agents = [f for f in agent_files if f.name not in excluded]
    
    print(f"✅ Found {len(valid_agents)} agent files")
    print(f"📋 Sample agents: {[f.stem for f in valid_agents[:5]]}")
    
    # Test parsing one agent
    if valid_agents:
        sample_agent = valid_agents[0]
        with open(sample_agent, 'r') as f:
            content = f.read()
        
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                frontmatter = yaml.safe_load(parts[1])
                print(f"✅ Successfully parsed agent: {sample_agent.stem}")
                print(f"🔍 Has communication config: {'communication' in frontmatter}")
            else:
                print(f"⚠️ Agent {sample_agent.stem} has incomplete YAML frontmatter")
        else:
            print(f"⚠️ Agent {sample_agent.stem} has no YAML frontmatter")
    
except Exception as e:
    print(f"❌ Agent parsing failed: {e}")
    import traceback
    traceback.print_exc()
    exit(1)

# Test the core classes without full initialization
try:
    print("\n🧪 Testing core orchestrator classes...")
    
    # Import minimal required components
    from ENHANCED_AGENT_INTEGRATION import Priority, AgentStatus
    from production_orchestrator import ExecutionMode, CommandSet, CommandStep, CommandType
    print("✅ Imported basic enums and classes")
    
    # Create a simple command set
    test_command = CommandSet(
        name="Test Command",
        type=CommandType.WORKFLOW,
        mode=ExecutionMode.PYTHON_ONLY,
        priority=Priority.MEDIUM,
        steps=[
            CommandStep(
                action="test",
                agent="Director",
                payload={"test": True}
            )
        ]
    )
    
    print("✅ Created command set successfully")
    print(f"📋 Command has {len(test_command.steps)} step(s)")
    
    # Test DAG conversion
    dag = test_command.to_dag()
    print(f"✅ Generated DAG with {len(dag['nodes'])} nodes and {len(dag['edges'])} edges")
    
except Exception as e:
    print(f"❌ Core classes test failed: {e}")
    import traceback
    traceback.print_exc()
    exit(1)

print("\n🎉 All basic tests passed! Core Constructor implementation is functional.")
print("💡 The orchestration system can be used with proper initialization.")