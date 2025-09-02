#!/usr/bin/env python3
"""
Create Claude Code compatible agent registry with only UPPERCASE agents from actual files
"""

import json
import yaml
from pathlib import Path
import os
import re

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
        
        # Parse YAML frontmatter from actual agent file
        agent_metadata = parse_agent_metadata(agents_dir / filename)
        
        # Ensure agent_metadata is a dict
        if not isinstance(agent_metadata, dict):
            agent_metadata = {}
        
        # Create Claude Code compatible agent entry
        agent_info = {
            "name": agent_name,
            "display_name": agent_name,
            "file_path": file_path,
            "original_filename": filename,
            "category": agent_metadata.get("category", "specialized").lower(),
            "status": "active",
            "description": agent_metadata.get("description", f"{agent_name} specialist"),
            "tools": flatten_tools(agent_metadata.get("tools", {"required": ["Task"]})),
            "metadata": agent_metadata  # Full metadata for Claude Code compatibility
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

def parse_agent_metadata(file_path):
    """Parse YAML frontmatter from agent file for Claude Code compatibility"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Extract YAML frontmatter
        if content.startswith('---'):
            try:
                # Find the end of YAML - either second --- or first # (markdown start)
                yaml_end = content.find('---', 3)
                if yaml_end == -1:
                    # No closing ---, look for first markdown header
                    lines = content.split('\n')
                    yaml_lines = []
                    in_yaml = True
                    
                    for i, line in enumerate(lines[1:], 1):  # Skip first ---
                        if line.strip().startswith('#') and not line.strip().startswith('# '):
                            # Found markdown header, end of YAML
                            break
                        elif line.strip() == '---':
                            # Found proper YAML end
                            break
                        else:
                            yaml_lines.append(line)
                    
                    yaml_content = '\n'.join(yaml_lines)
                else:
                    yaml_content = content[3:yaml_end].strip()
                    
                metadata = yaml.safe_load(yaml_content)
                
                # Handle None return from yaml.safe_load
                if metadata is None:
                    print(f"⚠️ Empty YAML metadata in {file_path}")
                    return {}
                
                # Extract metadata section if nested
                if isinstance(metadata, dict) and 'metadata' in metadata:
                    return metadata['metadata']
                else:
                    return metadata if metadata else {}
                    
            except yaml.YAMLError as e:
                print(f"⚠️ YAML parsing error in {file_path}: {e}")
                return {}
        else:
            print(f"⚠️ No YAML frontmatter found in {file_path}")
            return {}
            
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        return {}
    except Exception as e:
        print(f"❌ Error reading {file_path}: {e}")
        return {}

def flatten_tools(tools_config):
    """Flatten tools configuration for Claude Code Task tool compatibility"""
    if not tools_config:
        return ["Task"]
    
    flattened = []
    
    def extract_tools_recursive(obj):
        """Recursively extract tools from nested structures"""
        if isinstance(obj, list):
            for item in obj:
                if isinstance(item, str):
                    flattened.append(item)
                else:
                    extract_tools_recursive(item)
        elif isinstance(obj, dict):
            for key, value in obj.items():
                extract_tools_recursive(value)
        elif isinstance(obj, str):
            flattened.append(obj)
    
    # Handle different YAML structures
    if isinstance(tools_config, dict):
        # Look for tools in various expected locations
        if 'tools' in tools_config:
            extract_tools_recursive(tools_config['tools'])
        else:
            # Extract from any nested structure
            extract_tools_recursive(tools_config)
    elif isinstance(tools_config, list):
        # Already a flat list
        flattened = tools_config
    else:
        # Convert single tool to list
        if isinstance(tools_config, str):
            flattened = [tools_config]
        else:
            flattened = ["Task"]
    
    # Ensure Task tool is always included for Claude Code compatibility
    if "Task" not in flattened:
        flattened.insert(0, "Task")
    
    # Remove duplicates while preserving order
    seen = set()
    result = []
    for tool in flattened:
        if isinstance(tool, str) and tool not in seen:
            seen.add(tool)
            result.append(tool)
    
    return result if result else ["Task"]

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