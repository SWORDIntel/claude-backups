#!/usr/bin/env python3
"""
Create complete agent registry with all 70 agents
"""

import json
from pathlib import Path

def main():
    # All agents from the provided list
    agent_list = [
        "androidmobile", "apidesigner", "architect", "apt41-defense-agent",
        "apt41-redteam-agent", "assembly-internal-agent", "bastion", "bgp-blue-team",
        "bgp-purple-team-agent", "bgp-red-team", "c-internal", "carbon-internal-agent",
        "cisco-agent", "claudecode-promptinjector", "cognitive_defense_agent",
        "constructor", "cpp_internal_agent", "cryptoexpert", "cso", "database",
        "datascience", "ddwrt-agent", "debugger", "deployer", "director",
        "docker-agent", "docgen", "ghost_protocol_agent", "gna", "go-internal-agent",
        "infrastructure", "intergration", "iot-access-control-agent",
        "java-internal-agent", "kotlin-internal-agent", "leadengineer", "linter",
        "mlops", "monitor", "npu", "nsa", "optimizer", "oversight", "packager",
        "patcher", "planner", "projectorchestrator", "prompt-defender",
        "prompt-injector", "proxmox-agent", "psyops_agent", "pygui",
        "python-internal", "qadirector", "quantumguard", "redteamorchestrator",
        "researcher", "rust-internal-agent", "security", "securityauditor",
        "securitychaosagent", "sql-internal-agent", "template", "testbed",
        "tui", "typescript-internal-agent", "web", "wrapper-liberation",
        "wrapper-liberation-pro", "zig-internal-agent"
    ]
    
    agents = {}
    
    for agent_name in agent_list:
        if agent_name == "template":  # Skip template
            continue
            
        # Determine file format - UPPERCASE or lowercase with extensions
        if "-" in agent_name or "_" in agent_name:
            # Lowercase files like "apt41-defense-agent.md"
            filename = f"{agent_name}.md"
            display_name = format_display_name(agent_name)
        else:
            # UPPERCASE files like "DOCGEN.md"  
            filename = f"{agent_name.upper()}.md"
            display_name = agent_name.upper()
        
        file_path = f"agents/{filename}"
        category = determine_category(agent_name)
        description = create_description(agent_name, category)
        
        # Create agent info
        agent_info = {
            "name": display_name,
            "display_name": display_name,
            "file_path": file_path,
            "original_filename": filename,
            "category": category,
            "status": "active",
            "description": description,
            "tools": ["Task"]
        }
        
        # Store with multiple case variations for maximum compatibility
        agents[display_name] = agent_info  # DOCGEN
        agents[display_name.lower()] = agent_info  # docgen
        agents[agent_name] = agent_info  # original format
        if agent_name != display_name.lower():
            agents[agent_name.lower()] = agent_info
        # Title case
        agents[display_name.title()] = agent_info  # Docgen
        
    # Create registry
    registry = {
        "agents": agents,
        "version": "3.0",
        "total_agents": len(agent_list) - 1,  # -1 for template
        "total_aliases": len(agents),
        "updated": "2025-08-25",
        "description": "Complete agent registry with case-insensitive lookup"
    }
    
    # Ensure cache directory exists
    cache_dir = Path.home() / '.cache' / 'claude'
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    # Save registry
    registry_file = cache_dir / 'registered_agents.json'
    registry_file.write_text(json.dumps(registry, indent=2))
    
    print(f"✅ Complete registry created!")
    print(f"  • Unique agents: {len(agent_list) - 1}")
    print(f"  • Total aliases: {len(agents)}")
    print(f"  • Registry file: {registry_file}")
    
    # Test key agents
    test_cases = [
        'DOCGEN', 'docgen', 'Docgen',
        'DIRECTOR', 'director', 'Director',
        'SECURITY', 'security', 'Security',
        'apt41-defense-agent', 'APT41DefenseAgent'
    ]
    
    print(f"\n🧪 Testing key lookups:")
    for test in test_cases:
        if test in agents:
            print(f"  ✅ {test} -> {agents[test]['original_filename']}")
        else:
            print(f"  ❌ {test} not found")

def format_display_name(agent_name):
    """Format agent name for display"""
    if "-" in agent_name:
        # apt41-defense-agent -> APT41DefenseAgent
        parts = agent_name.split("-")
        return "".join(part.capitalize() for part in parts)
    elif "_" in agent_name:
        # cognitive_defense_agent -> CognitiveDefenseAgent
        parts = agent_name.split("_")
        return "".join(part.capitalize() for part in parts)
    else:
        return agent_name.upper()

def determine_category(agent_name):
    """Determine category from agent name"""
    name_lower = agent_name.lower()
    
    # Security category
    if any(word in name_lower for word in ['security', 'audit', 'crypto', 'quantum', 'defense', 'ghost', 'psyops', 'bastion']):
        return 'security'
    
    # Command & Control
    elif any(word in name_lower for word in ['director', 'orchestrator', 'planner', 'cso']):
        return 'command'
    
    # Development
    elif any(word in name_lower for word in ['architect', 'constructor', 'debugger', 'linter', 'testbed', 'patcher']):
        return 'development'
    
    # Infrastructure
    elif any(word in name_lower for word in ['infrastructure', 'deployer', 'monitor', 'packager', 'docker', 'proxmox']):
        return 'infrastructure'
    
    # Languages
    elif any(word in name_lower for word in ['python', 'java', 'rust', 'internal', 'typescript', 'kotlin', 'assembly', 'cpp', 'carbon', 'zig']):
        return 'languages'
    
    # Platforms
    elif any(word in name_lower for word in ['web', 'mobile', 'android', 'gui', 'tui']):
        return 'platforms'
    
    # Network
    elif any(word in name_lower for word in ['bgp', 'cisco', 'iot', 'ddwrt']):
        return 'network'
    
    # Data & ML
    elif any(word in name_lower for word in ['datascience', 'mlops', 'sql', 'database']):
        return 'data'
        
    # Hardware
    elif any(word in name_lower for word in ['npu', 'gna', 'leadengineer']):
        return 'hardware'
    
    else:
        return 'specialized'

def create_description(agent_name, category):
    """Create description for agent"""
    descriptions = {
        'docgen': 'Documentation generation specialist',
        'director': 'Strategic command and control',
        'security': 'Comprehensive security analysis',
        'architect': 'System design and architecture',
        'debugger': 'Debug and troubleshooting specialist',
        'monitor': 'System monitoring and observability',
        'deployer': 'Deployment and release management',
        'python-internal': 'Python development specialist',
        'web': 'Web development and frameworks',
        'database': 'Database design and optimization'
    }
    
    if agent_name in descriptions:
        return descriptions[agent_name]
    else:
        return f"{format_display_name(agent_name)} specialized agent"

if __name__ == "__main__":
    main()