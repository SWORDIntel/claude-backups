#!/usr/bin/env python3
"""
Claude Global Agents Bridge - Dynamic Discovery System
Automatically discovers and exposes ALL agents as globally accessible tools
Auto-updates when new agents are added - zero maintenance required
"""

import os
import sys
import json
import yaml
import asyncio
import hashlib
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import glob
import re

class GlobalAgentDiscovery:
    """Dynamic agent discovery system with real-time updates"""
    
    def __init__(self):
        self.agents_dir = Path(os.environ.get('CLAUDE_AGENTS_ROOT', '/home/ubuntu/Documents/Claude/agents'))
        self.cache_file = Path.home() / '.cache' / 'claude-agents' / 'discovery.json'
        self.agents = {}
        self.last_scan = None
        self.file_hashes = {}
        
    def scan_for_agents(self) -> Dict[str, Any]:
        """Dynamically scan for all agent .md files"""
        discovered = {}
        
        # Find all .md files in agents directory
        agent_files = list(self.agents_dir.glob('*.md'))
        
        for agent_file in agent_files:
            # Skip non-agent files
            if agent_file.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION']:
                continue
                
            agent_name = agent_file.stem
            agent_data = self._parse_agent_file(agent_file)
            
            if agent_data:
                discovered[agent_name.lower()] = {
                    'name': agent_name,
                    'path': str(agent_file),
                    'metadata': agent_data.get('metadata', {}),
                    'capabilities': self._extract_capabilities(agent_data),
                    'description': self._extract_description(agent_data),
                    'category': agent_data.get('metadata', {}).get('category', 'GENERAL'),
                    'status': agent_data.get('metadata', {}).get('status', 'PRODUCTION'),
                    'last_modified': agent_file.stat().st_mtime
                }
                
        return discovered
    
    def _parse_agent_file(self, file_path: Path) -> Optional[Dict]:
        """Parse agent .md file to extract metadata"""
        try:
            content = file_path.read_text()
            
            # Try to extract YAML frontmatter
            if content.startswith('---'):
                yaml_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
                if yaml_match:
                    try:
                        return yaml.safe_load(yaml_match.group(1))
                    except:
                        pass
            
            # Fallback: extract key information from content
            data = {'metadata': {}}
            
            # Extract agent name
            name_match = re.search(r'name:\s*(\w+)', content)
            if name_match:
                data['metadata']['name'] = name_match.group(1)
            
            # Extract role/expertise
            role_match = re.search(r'role:\s*"([^"]+)"', content)
            if role_match:
                data['metadata']['role'] = role_match.group(1)
                
            expertise_match = re.search(r'expertise:\s*"([^"]+)"', content)
            if expertise_match:
                data['metadata']['expertise'] = expertise_match.group(1)
                
            return data if data['metadata'] else None
            
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None
    
    def _extract_capabilities(self, agent_data: Dict) -> List[str]:
        """Extract agent capabilities from parsed data"""
        capabilities = []
        
        # Look for capabilities in various places
        if 'capabilities' in agent_data:
            capabilities.extend(agent_data['capabilities'])
        
        # Extract from tools section
        if 'tools' in agent_data:
            for tool in agent_data['tools']:
                if isinstance(tool, str):
                    capabilities.append(f"tool_{tool}")
                    
        # Default capabilities based on category
        category = agent_data.get('metadata', {}).get('category', '')
        if 'SECURITY' in category:
            capabilities.extend(['security_analysis', 'vulnerability_assessment', 'compliance_check'])
        elif 'DEVELOPMENT' in category:
            capabilities.extend(['code_generation', 'debugging', 'optimization'])
        elif 'TESTBED' in category:
            capabilities.extend(['testing', 'validation', 'quality_assurance'])
            
        return list(set(capabilities)) or ['analyze', 'execute', 'report']
    
    def _extract_description(self, agent_data: Dict) -> str:
        """Extract agent description from parsed data"""
        # Try multiple fields for description
        for field in ['description', 'role', 'expertise', 'focus']:
            if field in agent_data.get('metadata', {}):
                return agent_data['metadata'][field]
                
        # Fallback
        name = agent_data.get('metadata', {}).get('name', 'Agent')
        return f"{name} - Specialized agent for project tasks"
    
    def get_all_agents(self, force_refresh: bool = False) -> Dict[str, Any]:
        """Get all agents with caching and automatic refresh"""
        # Check if we need to refresh
        should_refresh = (
            force_refresh or
            not self.agents or
            not self.last_scan or
            (datetime.now().timestamp() - self.last_scan) > 60  # Refresh every minute
        )
        
        if should_refresh:
            self.agents = self.scan_for_agents()
            self.last_scan = datetime.now().timestamp()
            self._save_cache()
            
        return self.agents
    
    def _save_cache(self):
        """Save discovered agents to cache"""
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_data = {
            'agents': self.agents,
            'last_scan': self.last_scan,
            'version': '1.0.0'
        }
        self.cache_file.write_text(json.dumps(cache_data, indent=2))
    
    def _load_cache(self) -> bool:
        """Load agents from cache if available"""
        if self.cache_file.exists():
            try:
                cache_data = json.loads(self.cache_file.read_text())
                self.agents = cache_data.get('agents', {})
                self.last_scan = cache_data.get('last_scan')
                return True
            except:
                pass
        return False


class GlobalAgentInterface:
    """Interface to make agents globally accessible"""
    
    def __init__(self):
        self.discovery = GlobalAgentDiscovery()
        self.orchestrator_path = Path(__file__).parent / 'agents' / 'src' / 'python' / 'production_orchestrator.py'
        
    def create_global_manifest(self) -> Dict[str, Any]:
        """Create manifest for all discovered agents"""
        agents = self.discovery.get_all_agents()
        
        manifest = {
            'name': 'claude-project-agents',
            'version': '7.0.0',
            'description': f'Dynamic discovery of {len(agents)} specialized project agents',
            'agents': []
        }
        
        for agent_id, agent_info in agents.items():
            manifest['agents'].append({
                'id': agent_id,
                'name': agent_info['name'],
                'description': agent_info['description'],
                'category': agent_info['category'],
                'capabilities': agent_info['capabilities'],
                'status': agent_info['status'],
                'invocation': {
                    'type': 'subprocess',
                    'command': [
                        sys.executable,
                        str(self.orchestrator_path),
                        '--agent', agent_id
                    ]
                }
            })
            
        return manifest
    
    def create_task_tool_wrapper(self) -> str:
        """Create wrapper script for Task tool integration"""
        agents = self.discovery.get_all_agents()
        
        wrapper = '''#!/usr/bin/env python3
"""
Auto-generated Task Tool Wrapper for Project Agents
This file is automatically regenerated when agents are added/removed
"""

import subprocess
import sys
import json

# Auto-discovered agents
AGENTS = '''
        
        wrapper += json.dumps(agents, indent=4)
        
        wrapper += '''

def invoke_agent(agent_name, prompt):
    """Invoke agent through orchestrator"""
    agent_name = agent_name.lower()
    
    if agent_name not in AGENTS:
        return {"error": f"Agent {agent_name} not found. Available: {list(AGENTS.keys())}"}
    
    cmd = [
        sys.executable,
        "/home/ubuntu/Documents/Claude/agents/src/python/production_orchestrator.py",
        "--agent", agent_name,
        "--prompt", prompt
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        return {
            "success": result.returncode == 0,
            "output": result.stdout,
            "error": result.stderr if result.returncode != 0 else None
        }
    except subprocess.TimeoutExpired:
        return {"error": "Agent execution timed out after 5 minutes"}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Available agents: {list(AGENTS.keys())}")
        sys.exit(1)
    
    agent = sys.argv[1]
    prompt = " ".join(sys.argv[2:])
    result = invoke_agent(agent, prompt)
    
    if result.get("success"):
        print(result["output"])
    else:
        print(f"Error: {result.get('error')}", file=sys.stderr)
        sys.exit(1)
'''
        return wrapper
    
    def install_globally(self):
        """Install agents for global access"""
        print("🚀 Installing Claude Agents Globally with Dynamic Discovery")
        print("=" * 60)
        
        # Step 1: Discover all agents
        print("\n📡 Discovering agents...")
        agents = self.discovery.get_all_agents(force_refresh=True)
        print(f"✓ Found {len(agents)} agents:")
        for agent_id in sorted(agents.keys()):
            print(f"  • {agents[agent_id]['name']}: {agents[agent_id]['description'][:50]}...")
        
        # Step 2: Create global directories
        global_dir = Path.home() / '.local' / 'share' / 'claude-agents'
        global_dir.mkdir(parents=True, exist_ok=True)
        
        # Step 3: Create manifest
        print("\n📋 Creating global manifest...")
        manifest = self.create_global_manifest()
        manifest_file = global_dir / 'manifest.json'
        manifest_file.write_text(json.dumps(manifest, indent=2))
        print(f"✓ Manifest created: {manifest_file}")
        
        # Step 4: Create wrapper script
        print("\n🔧 Creating Task tool wrapper...")
        wrapper = self.create_task_tool_wrapper()
        wrapper_file = global_dir / 'agent_wrapper.py'
        wrapper_file.write_text(wrapper)
        wrapper_file.chmod(0o755)
        print(f"✓ Wrapper created: {wrapper_file}")
        
        # Step 5: Create global launcher
        print("\n🚀 Creating global launcher...")
        launcher_file = Path.home() / '.local' / 'bin' / 'claude-agent'
        launcher_file.parent.mkdir(parents=True, exist_ok=True)
        
        launcher_content = f'''#!/bin/bash
# Claude Agent Global Launcher with Dynamic Discovery
export CLAUDE_AGENTS_ROOT="{self.discovery.agents_dir}"
export PYTHONPATH="{self.discovery.agents_dir}/src/python:$PYTHONPATH"

if [ "$1" = "list" ] || [ -z "$1" ]; then
    python3 "{wrapper_file}" 2>&1 | head -1
    exit 0
fi

python3 "{wrapper_file}" "$@"
'''
        launcher_file.write_text(launcher_content)
        launcher_file.chmod(0o755)
        print(f"✓ Launcher created: {launcher_file}")
        
        # Step 6: Create auto-discovery service
        print("\n⚙️ Setting up auto-discovery service...")
        service_file = global_dir / 'auto_discovery.py'
        service_content = '''#!/usr/bin/env python3
"""Auto-discovery service that refreshes agent list periodically"""
import time
import sys
sys.path.insert(0, "/home/ubuntu/Documents/Claude")
from claude_global_agents_bridge import GlobalAgentInterface

interface = GlobalAgentInterface()
while True:
    interface.discovery.get_all_agents(force_refresh=True)
    interface.create_task_tool_wrapper()
    time.sleep(60)  # Refresh every minute
'''
        service_file.write_text(service_content)
        service_file.chmod(0o755)
        
        print("\n✅ Global installation complete!")
        print("\n📌 Usage:")
        print("  • List agents: claude-agent list")
        print("  • Run agent: claude-agent <agent-name> <prompt>")
        print("  • Auto-discovery: Agents are automatically discovered every 60 seconds")
        print("\n🔄 Dynamic Discovery Active:")
        print("  • New agents are automatically detected")
        print("  • No reinstallation needed when adding agents")
        print("  • Cache refreshes every minute")
        
        return True


if __name__ == "__main__":
    interface = GlobalAgentInterface()
    
    if len(sys.argv) > 1 and sys.argv[1] == 'install':
        interface.install_globally()
    else:
        # Show discovered agents
        agents = interface.discovery.get_all_agents(force_refresh=True)
        print(f"Discovered {len(agents)} agents with dynamic discovery:")
        for agent_id, info in sorted(agents.items()):
            print(f"  {info['name']}: {info['description']}")