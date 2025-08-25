#!/usr/bin/env python3
"""
Claude Global Agents Bridge v11.0 - Fully Dynamic Agent Registration
Automatically discovers ALL agents and creates comprehensive case-insensitive registry
No hardcoded paths, agents, or metadata - completely dynamic discovery
"""

import os
import sys
import json
import yaml
import time
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import glob
import re

# ==============================================================================
# DYNAMIC PATH DISCOVERY - NO HARDCODED PATHS
# ==============================================================================

def find_project_root() -> Path:
    """Dynamically find project root by searching for key markers"""
    current = Path(__file__).resolve().parent
    
    # Search upward for project markers
    for _ in range(10):  # Max 10 levels up
        markers = [
            current / 'agents',
            current / 'README.md', 
            current / '.git',
            current / 'CLAUDE.md'
        ]
        
        # If we find agents directory, this is likely the root
        if (current / 'agents').exists() and (current / 'agents').is_dir():
            return current
            
        # Or if we find multiple markers
        if sum(1 for marker in markers if marker.exists()) >= 2:
            return current
            
        parent = current.parent
        if parent == current:  # Reached filesystem root
            break
        current = parent
    
    # Fallback to current working directory
    return Path.cwd()

def find_agents_directory() -> Path:
    """Dynamically locate agents directory"""
    # Try environment variable first
    if os.environ.get('CLAUDE_AGENTS_ROOT'):
        agents_dir = Path(os.environ['CLAUDE_AGENTS_ROOT'])
        if agents_dir.exists() and agents_dir.is_dir():
            return agents_dir
    
    # Search from project root
    project_root = find_project_root()
    
    # Common locations to check (dynamically)
    possible_locations = [
        project_root / 'agents',
        project_root / 'claude-backups' / 'agents',
        Path.cwd() / 'agents',
    ]
    
    for location in possible_locations:
        if location.exists() and location.is_dir():
            return location
    
    # If nothing found, create default
    default_location = project_root / 'agents'
    print(f"⚠️  Agents directory not found, using: {default_location}")
    return default_location

# ==============================================================================
# DYNAMIC AGENT DISCOVERY - NO HARDCODED AGENT LISTS
# ==============================================================================

class DynamicAgentRegistry:
    """Fully dynamic agent registry with automatic discovery and alias generation"""
    
    def __init__(self):
        self.agents_dir = find_agents_directory()
        self.project_root = find_project_root()
        
        # Output to config directory (with fallback)
        self.config_dir = self.project_root / 'config'
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.registry_file = self.config_dir / 'registered_agents.json'
        
        # Create symlink to cache location for backwards compatibility
        self.cache_dir = Path.home() / '.cache' / 'claude'
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.cache_registry_file = self.cache_dir / 'registered_agents.json'
        
        # Exclusion patterns (configurable)
        self.exclude_patterns = {
            'README', 'Template', 'TEMPLATE', 'WHERE_I_AM', 
            'Agents Readme', 'STATUSLINE_INTEGRATION'
        }
    
    def discover_all_agents(self) -> Dict[str, Any]:
        """Dynamically discover all .md agent files"""
        agents = {}
        
        if not self.agents_dir.exists():
            print(f"❌ Agents directory not found: {self.agents_dir}")
            return agents
        
        print(f"🔍 Scanning for agents in: {self.agents_dir}")
        
        # Find all .md files recursively in agents directory
        agent_files = list(self.agents_dir.glob("*.md"))
        
        print(f"📁 Found {len(agent_files)} .md files")
        
        for agent_file in agent_files:
            # Skip excluded files
            if agent_file.stem in self.exclude_patterns:
                print(f"⏭️  Skipping: {agent_file.name}")
                continue
                
            agent_info = self._create_agent_info(agent_file)
            if agent_info:
                # Create multiple aliases for each agent
                aliases = self._generate_aliases(agent_file.stem)
                
                for alias in aliases:
                    agents[alias] = agent_info
                    
                print(f"✅ Registered: {agent_file.stem} ({len(aliases)} aliases)")
        
        return agents
    
    def _create_agent_info(self, agent_file: Path) -> Dict[str, Any]:
        """Create agent info from file analysis"""
        try:
            # Parse agent file for metadata
            metadata = self._parse_agent_metadata(agent_file)
            
            # Determine display name
            display_name = self._generate_display_name(agent_file.stem)
            
            # Auto-categorize based on filename patterns
            category = self._auto_categorize(agent_file.stem)
            
            # Generate description
            description = self._generate_description(agent_file.stem, category, metadata)
            
            # Extract tools (default to Task if not specified)
            tools = self._extract_tools_from_metadata(metadata)
            
            return {
                'name': display_name,
                'display_name': display_name,
                'file_path': str(agent_file.relative_to(self.project_root)),
                'original_filename': agent_file.name,
                'category': category,
                'status': 'active',
                'description': description,
                'tools': tools,
                'metadata': metadata,
                'aliases': self._generate_aliases(agent_file.stem)
            }
        except Exception as e:
            print(f"⚠️  Error processing {agent_file.name}: {e}")
            return None
    
    def _parse_agent_metadata(self, agent_file: Path) -> Dict:
        """Parse YAML frontmatter or extract metadata from file"""
        try:
            content = agent_file.read_text(encoding='utf-8', errors='ignore')
            
            # Try to parse YAML frontmatter
            if content.startswith('---'):
                yaml_end = content.find('---', 3)
                if yaml_end > 0:
                    yaml_content = content[3:yaml_end]
                    return yaml.safe_load(yaml_content) or {}
            
            # If no YAML, extract basic info from content
            return self._extract_metadata_from_content(content)
            
        except Exception as e:
            print(f"  ⚠️ Could not parse metadata from {agent_file.name}: {e}")
            return {}
    
    def _extract_metadata_from_content(self, content: str) -> Dict:
        """Extract metadata from file content when no YAML frontmatter exists"""
        metadata = {}
        
        # Look for common patterns
        lines = content.split('\n')[:20]  # Check first 20 lines
        
        for line in lines:
            line = line.strip()
            
            # Extract title/role information
            if line.startswith('#') and not metadata.get('role'):
                title = line.lstrip('# ').strip()
                if title and title not in ['Agent', 'Template']:
                    metadata['role'] = title
            
            # Look for description patterns
            elif any(keyword in line.lower() for keyword in ['specialist', 'expert', 'manager', 'developer']):
                if not metadata.get('description'):
                    metadata['description'] = line.strip()
        
        return metadata
    
    def _generate_display_name(self, file_stem: str) -> str:
        """Generate proper display name from filename"""
        # Handle different naming patterns
        if '-' in file_stem:
            # Convert kebab-case to PascalCase: "apt41-defense-agent" -> "Apt41DefenseAgent"
            parts = file_stem.split('-')
            return ''.join(part.capitalize() for part in parts)
        elif '_' in file_stem:
            # Convert snake_case to PascalCase: "cognitive_defense_agent" -> "CognitiveDefenseAgent" 
            parts = file_stem.split('_')
            return ''.join(part.capitalize() for part in parts)
        else:
            # Already in correct format or single word
            return file_stem.upper()
    
    def _generate_aliases(self, file_stem: str) -> List[str]:
        """Generate all possible aliases for an agent"""
        aliases = set()
        
        # Original filename stem
        aliases.add(file_stem)
        
        # Uppercase version
        aliases.add(file_stem.upper())
        
        # Lowercase version
        aliases.add(file_stem.lower())
        
        # Title case version
        aliases.add(file_stem.title())
        
        # Display name versions
        display_name = self._generate_display_name(file_stem)
        aliases.add(display_name)
        aliases.add(display_name.lower())
        aliases.add(display_name.upper())
        
        # Handle special patterns
        if '-' in file_stem:
            # Remove hyphens: "apt41-defense-agent" -> "apt41defenseagent"
            no_hyphens = file_stem.replace('-', '')
            aliases.add(no_hyphens)
            aliases.add(no_hyphens.upper())
            aliases.add(no_hyphens.lower())
            
            # CamelCase: "apt41-defense-agent" -> "apt41DefenseAgent"
            camel_case = ''.join(part.capitalize() if i > 0 else part for i, part in enumerate(file_stem.split('-')))
            aliases.add(camel_case)
            
        if '_' in file_stem:
            # Remove underscores: "cognitive_defense_agent" -> "cognitivedefenseagent"
            no_underscores = file_stem.replace('_', '')
            aliases.add(no_underscores)
            aliases.add(no_underscores.upper())
            aliases.add(no_underscores.lower())
        
        return list(aliases)
    
    def _auto_categorize(self, file_stem: str) -> str:
        """Automatically categorize agent based on filename patterns"""
        name_lower = file_stem.lower()
        
        # Security category
        security_keywords = ['security', 'audit', 'crypto', 'quantum', 'defense', 'ghost', 'psyops', 'bastion', 'apt41', 'redteam', 'cognitiv']
        if any(keyword in name_lower for keyword in security_keywords):
            return 'security'
        
        # Command & Control
        command_keywords = ['director', 'orchestrator', 'planner', 'cso', 'manager']
        if any(keyword in name_lower for keyword in command_keywords):
            return 'command'
        
        # Development
        dev_keywords = ['architect', 'constructor', 'debugger', 'linter', 'testbed', 'patcher', 'docgen']
        if any(keyword in name_lower for keyword in dev_keywords):
            return 'development'
        
        # Infrastructure
        infra_keywords = ['infrastructure', 'deployer', 'monitor', 'packager', 'docker', 'proxmox']
        if any(keyword in name_lower for keyword in infra_keywords):
            return 'infrastructure'
        
        # Languages
        lang_keywords = ['python', 'java', 'rust', 'internal', 'typescript', 'kotlin', 'assembly', 'cpp', 'carbon', 'zig', 'go']
        if any(keyword in name_lower for keyword in lang_keywords):
            return 'languages'
        
        # Platforms
        platform_keywords = ['web', 'mobile', 'android', 'gui', 'tui']
        if any(keyword in name_lower for keyword in platform_keywords):
            return 'platforms'
        
        # Network
        network_keywords = ['bgp', 'cisco', 'iot', 'ddwrt', 'network']
        if any(keyword in name_lower for keyword in network_keywords):
            return 'network'
        
        # Data & ML
        data_keywords = ['datascience', 'mlops', 'sql', 'database', 'data']
        if any(keyword in name_lower for keyword in data_keywords):
            return 'data'
            
        # Hardware
        hardware_keywords = ['npu', 'gna', 'leadengineer', 'hardware']
        if any(keyword in name_lower for keyword in hardware_keywords):
            return 'hardware'
        
        return 'specialized'
    
    def _generate_description(self, file_stem: str, category: str, metadata: Dict) -> str:
        """Generate description from multiple sources"""
        # Try metadata first
        for field in ['description', 'role', 'expertise', 'focus']:
            if field in metadata and metadata[field]:
                return str(metadata[field])
        
        # Generate from filename and category
        display_name = self._generate_display_name(file_stem)
        
        category_descriptions = {
            'security': 'specialist',
            'command': 'coordinator', 
            'development': 'specialist',
            'infrastructure': 'manager',
            'languages': 'developer',
            'platforms': 'specialist',
            'network': 'specialist',
            'data': 'specialist',
            'hardware': 'specialist',
            'specialized': 'agent'
        }
        
        suffix = category_descriptions.get(category, 'agent')
        return f"{display_name} {suffix}"
    
    def _extract_tools_from_metadata(self, metadata: Dict) -> List[str]:
        """Extract tools from metadata or default to Task"""
        if 'tools' in metadata:
            tools = metadata['tools']
            if isinstance(tools, list):
                return [tool for tool in tools if tool != 'Task'] + ['Task']
            elif isinstance(tools, str):
                return [tools] if tools != 'Task' else ['Task']
        
        return ['Task']  # Default
    
    def create_registry(self) -> Dict[str, Any]:
        """Create complete agent registry"""
        print("🚀 Dynamic Agent Registration v11.0")
        print("=" * 60)
        
        # Discover all agents
        agents = self.discover_all_agents()
        
        if not agents:
            print("❌ No agents discovered!")
            return {}
        
        # Calculate statistics
        unique_agents = len(set(info['name'] for info in agents.values()))
        
        registry = {
            'agents': agents,
            'version': '11.0',
            'total_agents': unique_agents,
            'total_aliases': len(agents),
            'discovery_timestamp': datetime.now().isoformat(),
            'agents_directory': str(self.agents_dir),
            'project_root': str(self.project_root),
            'auto_generated': True,
            'description': 'Fully dynamic agent registry with automatic discovery and alias generation'
        }
        
        # Save registry to config directory
        registry_json = json.dumps(registry, indent=2)
        self.registry_file.write_text(registry_json)
        
        # Create symlink to cache location for backwards compatibility
        try:
            if self.cache_registry_file.exists() or self.cache_registry_file.is_symlink():
                self.cache_registry_file.unlink()
            self.cache_registry_file.symlink_to(self.registry_file.resolve())
        except Exception as e:
            # Fallback: copy instead of symlink if symlink fails
            self.cache_registry_file.write_text(registry_json)
        
        print(f"\n✅ Registry created successfully!")
        print(f"  📁 Agents directory: {self.agents_dir}")
        print(f"  📊 Unique agents: {unique_agents}")
        print(f"  🏷️  Total aliases: {len(agents)}")
        print(f"  💾 Registry file: {self.registry_file}")
        print(f"  🔗 Symlinked to: {self.cache_registry_file}")
        
        return registry
    
    def test_key_agents(self, registry: Dict[str, Any]):
        """Test that key agents can be found with different case variations"""
        agents = registry.get('agents', {})
        
        # Test common agent variations
        test_cases = [
            'DOCGEN', 'docgen', 'Docgen',
            'DIRECTOR', 'director', 'Director',
            'SECURITY', 'security', 'Security',
            'apt41-defense-agent', 'APT41DefenseAgent', 'Apt41DefenseAgent'
        ]
        
        print(f"\n🧪 Testing agent lookups:")
        found = 0
        for test_case in test_cases:
            if test_case in agents:
                original_file = agents[test_case]['original_filename']
                print(f"  ✅ {test_case} -> {original_file}")
                found += 1
            else:
                print(f"  ❌ {test_case} not found")
        
        print(f"\n📈 Test Results: {found}/{len(test_cases)} lookups successful")

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

def main():
    """Main execution function"""
    registry = DynamicAgentRegistry()
    
    try:
        # Create registry
        result = registry.create_registry()
        
        # Test key lookups
        registry.test_key_agents(result)
        
        return True
        
    except Exception as e:
        print(f"❌ Error during registration: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)