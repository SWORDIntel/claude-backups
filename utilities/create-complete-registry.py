#!/usr/bin/env python3
"""
Create clean agent registry with only UPPERCASE agents from actual files
"""

import json
from pathlib import Path
import os

def main():
    # Get actual agent files from the agents directory
    agents_dir = Path("agents")
    if not agents_dir.exists():
        print("❌ agents/ directory not found")
        return
        
    # Find all .md files, exclude non-agent files
    exclude_patterns = ['README', 'Template', 'WHERE_I_AM', 'Agents Readme', 'TEMPLATE']
    
    agent_files = []
    for md_file in agents_dir.glob("*.md"):
        if not any(pattern in md_file.name for pattern in exclude_patterns):
            agent_name = md_file.stem  # filename without .md
            # Only include UPPERCASE agents
            if agent_name.isupper():
                agent_files.append(agent_name)
    
    print(f"📁 Found {len(agent_files)} valid UPPERCASE agent files")
    
    agents = {}
    
    # Process only the actual UPPERCASE agent files found
    for agent_name in sorted(agent_files):
        filename = f"{agent_name}.md"
        file_path = f"agents/{filename}"
        category = determine_category(agent_name)
        description = create_description(agent_name, category)
        
        # Create single agent entry - NO DUPLICATES
        agent_info = {
            "name": agent_name,
            "display_name": agent_name,
            "file_path": file_path,
            "original_filename": filename,
            "category": category,
            "status": "active",
            "description": description,
            "tools": ["Task"]
        }
        
        # Store only UPPERCASE version - NO case variations
        agents[agent_name] = agent_info
        
    # Create clean registry
    registry = {
        "agents": agents,
        "metadata": {
            "version": "9.0.0",
            "total_agents": len(agent_files),
            "generated": "2025-01-14",
            "description": "Clean agent registry with only UPPERCASE agents"
        }
    }
    
    # Save registry to config directory (not cache)
    registry_file = Path("config/registered_agents.json")
    registry_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print(f"✅ Clean registry created!")
    print(f"  • Total agents: {len(agent_files)}")
    print(f"  • Registry file: {registry_file}")
    print(f"  • No duplicates, UPPERCASE only")
    
    # Show sample agents
    print(f"\n📋 Sample agents registered:")
    for i, agent in enumerate(sorted(agents.keys())[:10], 1):
        print(f"  {i:2d}. {agent}")
    
    if len(agents) > 10:
        print(f"  ... and {len(agents) - 10} more")

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
    """Determine category from UPPERCASE agent name"""
    name_lower = agent_name.lower()
    
    # Security category
    if any(word in name_lower for word in ['security', 'audit', 'crypto', 'quantum', 'defense', 'ghost', 'psyops', 'bastion', 'apt41', 'bgp', 'chaos', 'prompt']):
        return 'security'
    
    # Command & Control
    elif any(word in name_lower for word in ['director', 'orchestrator', 'planner', 'cso', 'oversight']):
        return 'command'
    
    # Development
    elif any(word in name_lower for word in ['architect', 'constructor', 'debugger', 'linter', 'testbed', 'patcher', 'agentsmith']):
        return 'development'
    
    # Infrastructure
    elif any(word in name_lower for word in ['infrastructure', 'deployer', 'monitor', 'packager', 'docker', 'proxmox', 'ddwrt', 'cisco']):
        return 'infrastructure'
    
    # Languages (INTERNAL agents)
    elif 'internal' in name_lower or any(word in name_lower for word in ['python', 'java', 'rust', 'typescript', 'kotlin', 'assembly', 'cpp', 'carbon', 'zig', 'dart', 'php', 'sql', 'matlab', 'julia']):
        return 'languages'
    
    # Platforms
    elif any(word in name_lower for word in ['web', 'mobile', 'android', 'gui', 'tui', 'pygui']):
        return 'platforms'
    
    # Data & ML
    elif any(word in name_lower for word in ['datascience', 'mlops', 'database', 'researcher']):
        return 'data'
        
    # Hardware
    elif any(word in name_lower for word in ['npu', 'gna', 'leadengineer', 'hardware', 'optimizer']):
        return 'hardware'
    
    else:
        return 'specialized'

def create_description(agent_name, category):
    """Create description for UPPERCASE agent"""
    name_lower = agent_name.lower()
    
    # Specific descriptions for key agents
    descriptions = {
        'DOCGEN': 'Documentation generation specialist',
        'DIRECTOR': 'Strategic command and control',
        'SECURITY': 'Comprehensive security analysis',
        'ARCHITECT': 'System design and architecture',
        'DEBUGGER': 'Debug and troubleshooting specialist',
        'MONITOR': 'System monitoring and observability',
        'DEPLOYER': 'Deployment and release management',
        'PYTHON-INTERNAL': 'Python development specialist',
        'WEB': 'Web development and frameworks',
        'DATABASE': 'Database design and optimization',
        'PROJECTORCHESTRATOR': 'Tactical coordination nexus'
    }
    
    if agent_name in descriptions:
        return descriptions[agent_name]
    else:
        return f"{agent_name} specialist"

if __name__ == "__main__":
    main()