#!/usr/bin/env python3
"""
Fix agent registration to properly handle mixed case agent files
"""

import json
from pathlib import Path

def main():
    print("🔧 Fixing agent registration...")
    
    agents_dir = Path("agents")
    cache_dir = Path.home() / '.cache' / 'claude'
    cache_dir.mkdir(parents=True, exist_ok=True)
    registry_file = cache_dir / 'registered_agents.json'
    
    # Get all .md files from agents directory
    agent_files = list(agents_dir.glob("*.md"))
    exclude_files = {'README.md', 'TEMPLATE.md', 'Template.md', 'WHERE_I_AM.md', 'Agents Readme.txt'}
    
    agents = {}
    
    print(f"📁 Scanning {len(agent_files)} files...")
    
    for agent_file in agent_files:
        if agent_file.name in exclude_files:
            continue
            
        # Extract clean agent name
        file_stem = agent_file.stem
        
        # Handle different naming patterns
        if file_stem.endswith('-agent'):
            # For files like "apt41-defense-agent.md" -> "APT41DefenseOrchestrator"
            clean_name = file_stem.replace('-agent', '').replace('-', ' ').title().replace(' ', '')
        elif '-' in file_stem:
            # For files like "bgp-purple-team-agent.md" -> "BGPPurpleTeam"
            clean_name = ''.join(word.capitalize() for word in file_stem.split('-'))
        else:
            # For files like "DOCGEN.md" -> "DOCGEN" (keep as-is)
            clean_name = file_stem
        
        # Create agent entry
        agent_info = {
            'name': clean_name,
            'display_name': clean_name,
            'file_path': str(agent_file),
            'original_filename': agent_file.name,
            'category': determine_category(clean_name),
            'status': 'active',
            'description': f"{clean_name} specialized agent",
            'tools': ['Task']
        }
        
        # Store with multiple aliases for compatibility
        agents[clean_name] = agent_info
        agents[clean_name.lower()] = agent_info
        agents[file_stem] = agent_info  # Original filename stem
        if file_stem != clean_name:
            agents[file_stem.lower()] = agent_info
        
        print(f"  ✅ Registered: {clean_name} ({agent_file.name})")
    
    # Create registry structure
    registry = {
        'agents': agents,
        'version': '2.0',
        'total_agents': len(set(info['name'] for info in agents.values())),
        'updated': '2025-08-25'
    }
    
    # Save registry
    registry_file.write_text(json.dumps(registry, indent=2))
    
    # Count unique agents (not aliases)
    unique_agents = len(set(info['name'] for info in agents.values()))
    print(f"\n✅ Registration complete!")
    print(f"  • Unique agents: {unique_agents}")
    print(f"  • Total aliases: {len(agents)}")
    print(f"  • Registry saved to: {registry_file}")
    
    # Test specific agents
    test_agents = ['DOCGEN', 'docgen', 'Docgen', 'DIRECTOR', 'director', 'SECURITY', 'security']
    print(f"\n🧪 Testing key agents:")
    for test_name in test_agents:
        if test_name in agents:
            original_file = agents[test_name]['original_filename']
            print(f"  ✅ {test_name} -> {original_file}")
        else:
            print(f"  ❌ {test_name} not found")

def determine_category(agent_name):
    """Determine category from agent name"""
    name_lower = agent_name.lower()
    
    if any(word in name_lower for word in ['security', 'audit', 'crypto', 'quantum', 'defense']):
        return 'security'
    elif any(word in name_lower for word in ['director', 'orchestrator', 'planner']):
        return 'command'
    elif any(word in name_lower for word in ['architect', 'constructor', 'debugger', 'linter']):
        return 'development'
    elif any(word in name_lower for word in ['infrastructure', 'deployer', 'monitor']):
        return 'infrastructure'
    elif any(word in name_lower for word in ['web', 'mobile', 'gui', 'tui']):
        return 'platforms'
    elif any(word in name_lower for word in ['python', 'java', 'rust', 'internal']):
        return 'languages'
    else:
        return 'specialized'

if __name__ == "__main__":
    main()