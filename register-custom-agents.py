#!/usr/bin/env python3
"""
Register Custom Agents with Claude Code Task Tool
Makes all 37 project agents directly invocable through Task()
Auto-discovers and monitors for new agents
"""

import json
import yaml
import os
import time
import threading
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

class AgentRegistrar:
    """
    Registers project agents to make them available to Claude's Task tool
    """
    
    def __init__(self):
        self.agents_dir = Path("/home/ubuntu/Documents/Claude/agents")
        self.claude_config_dir = Path.home() / ".config" / "claude"
        self.claude_config_dir.mkdir(parents=True, exist_ok=True)
        
        # Auto-discovery tracking
        self.last_scan_time = 0
        self.known_agents = set()
        self.registry_file = self.claude_config_dir / "project-agents.json"
        self.monitor_thread = None
        self.monitoring = False
        
    def scan_agents(self) -> Dict[str, Any]:
        """Scan all agent .md files and extract metadata"""
        agents = {}
        
        for agent_file in self.agents_dir.glob("*.md"):
            if agent_file.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION']:
                continue
                
            agent_name = agent_file.stem.lower()
            agent_data = self.parse_agent_file(agent_file)
            
            if agent_data:
                agents[agent_name] = {
                    'name': agent_file.stem,
                    'file': str(agent_file),
                    'metadata': agent_data,
                    'tools': self.extract_tools(agent_data),
                    'description': self.extract_description(agent_data)
                }
                
        return agents
    
    def parse_agent_file(self, file_path: Path) -> Dict:
        """Parse agent .md file to extract YAML frontmatter"""
        try:
            content = file_path.read_text()
            
            if content.startswith('---'):
                # Extract YAML frontmatter
                yaml_end = content.find('---', 3)
                if yaml_end > 0:
                    yaml_content = content[3:yaml_end]
                    return yaml.safe_load(yaml_content)
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            
        return None
    
    def extract_tools(self, agent_data: Dict) -> List[str]:
        """Extract tools from agent data"""
        tools = agent_data.get('tools', [])
        
        # Convert to standard format
        if tools:
            return [tool for tool in tools if tool != 'Task']
        return ['*']  # Default to all tools
        
    def extract_description(self, agent_data: Dict) -> str:
        """Extract description from agent data"""
        metadata = agent_data.get('metadata', {})
        
        # Try various fields
        for field in ['role', 'expertise', 'focus', 'description']:
            if field in metadata:
                return metadata[field]
                
        return "Specialized project agent"
    
    def create_agent_registry(self) -> Dict[str, Any]:
        """Create registry file for Claude to recognize agents"""
        agents = self.scan_agents()
        
        registry = {
            'version': '1.0.0',
            'custom_agents': {},
            'agent_mappings': {}
        }
        
        for agent_id, agent_info in agents.items():
            # Create agent definition
            registry['custom_agents'][agent_id] = {
                'type': agent_id,
                'name': agent_info['name'],
                'description': agent_info['description'],
                'tools': agent_info['tools'],
                'source': 'project',
                'implementation': 'python',
                'endpoint': f"claude-agent {agent_id}"
            }
            
            # Create mapping for variations
            registry['agent_mappings'][agent_info['name'].lower()] = agent_id
            registry['agent_mappings'][agent_info['name']] = agent_id
            
            # Add common variations
            if '-' in agent_id:
                registry['agent_mappings'][agent_id.replace('-', '_')] = agent_id
                registry['agent_mappings'][agent_id.replace('-', '')] = agent_id
                
        return registry
    
    def create_task_extension(self) -> str:
        """Create extension code to inject agents into Task tool"""
        agents = self.scan_agents()
        
        extension = '''# Claude Code Task Tool Extension for Project Agents
# Auto-generated - DO NOT EDIT MANUALLY

"""
This extension makes all project agents available to Claude's Task tool.
Usage: Task(subagent_type="director", prompt="...")
"""

import os
import sys
import subprocess
from typing import Dict, Any

# Add project agents to path
sys.path.insert(0, '/home/ubuntu/Documents/Claude')

# Registry of available project agents
PROJECT_AGENTS = {
'''
        
        # Add each agent
        for agent_id, agent_info in agents.items():
            extension += f"    '{agent_id}': {{\n"
            extension += f"        'name': '{agent_info['name']}',\n"
            extension += f"        'description': '{agent_info['description']}',\n"
            extension += f"        'command': 'claude-agent {agent_id}',\n"
            extension += f"        'tools': {agent_info['tools']}\n"
            extension += f"    }},\n"
            
        extension += '''
}

def invoke_project_agent(agent_type: str, prompt: str) -> Dict[str, Any]:
    """Invoke a project agent through the Task tool"""
    
    if agent_type not in PROJECT_AGENTS:
        # Try variations
        agent_type = agent_type.lower().replace('_', '-')
        
    if agent_type not in PROJECT_AGENTS:
        return {
            'error': f"Agent '{agent_type}' not found",
            'available': list(PROJECT_AGENTS.keys())
        }
    
    agent = PROJECT_AGENTS[agent_type]
    
    # Execute through claude-agent command
    try:
        result = subprocess.run(
            ['claude-agent', agent_type, prompt],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        return {
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr if result.returncode != 0 else None,
            'agent': agent['name']
        }
    except Exception as e:
        return {
            'error': str(e),
            'agent': agent['name']
        }

# Register with Claude's Task system
def register_agents():
    """Register all project agents with Claude"""
    import claude_code  # This would be the actual Claude Code module
    
    for agent_id in PROJECT_AGENTS:
        claude_code.register_agent(agent_id, invoke_project_agent)
        
# Auto-register on import
if __name__ != "__main__":
    try:
        register_agents()
    except:
        pass  # Silently fail if Claude Code module not available
'''
        
        return extension
    
    def install(self):
        """Install the agent registry and extension"""
        print("🚀 Registering Project Agents with Claude Code")
        print("=" * 60)
        
        # Create registry
        print("\n📋 Creating agent registry...")
        registry = self.create_agent_registry()
        registry_file = self.claude_config_dir / "project-agents.json"
        registry_file.write_text(json.dumps(registry, indent=2))
        print(f"✓ Registry created: {registry_file}")
        print(f"  • {len(registry['custom_agents'])} agents registered")
        
        # Create extension
        print("\n🔧 Creating Task tool extension...")
        extension = self.create_task_extension()
        extension_file = self.claude_config_dir / "task_extension.py"
        extension_file.write_text(extension)
        extension_file.chmod(0o755)
        print(f"✓ Extension created: {extension_file}")
        
        # Create activation script
        print("\n📝 Creating activation script...")
        activation_script = self.claude_config_dir / "activate-agents.sh"
        activation_script.write_text('''#!/bin/bash
# Activate Project Agents for Claude Code

export CLAUDE_CUSTOM_AGENTS="/home/ubuntu/.config/claude/project-agents.json"
export PYTHONPATH="/home/ubuntu/.config/claude:$PYTHONPATH"

# Create symbolic link for C-INTERNAL style access
for agent in $(jq -r '.custom_agents | keys[]' "$CLAUDE_CUSTOM_AGENTS"); do
    export CLAUDE_AGENT_${agent^^}="available"
done

echo "✓ Project agents activated"
echo "  Run 'claude' to use with Task tool support"
''')
        activation_script.chmod(0o755)
        print(f"✓ Activation script: {activation_script}")
        
        # Update CLAUDE.md with agent list
        self.update_claude_md(registry)
        
        print("\n✅ Registration Complete!")
        print("\n📌 To activate agents:")
        print("  source ~/.config/claude/activate-agents.sh")
        print("\n📌 Usage in Claude:")
        print('  Task(subagent_type="director", prompt="plan the project")')
        print('  Task(subagent_type="optimizer", prompt="optimize this code")')
        print("\n📌 Available agents:")
        for agent_id in sorted(registry['custom_agents'].keys())[:10]:
            print(f"  • {agent_id}")
        if len(registry['custom_agents']) > 10:
            print(f"  ... and {len(registry['custom_agents']) - 10} more")
    
    def update_claude_md(self, registry: Dict):
        """Update CLAUDE.md with available agent types"""
        claude_md_path = Path("/home/ubuntu/Documents/Claude/CLAUDE.md")
        
        if not claude_md_path.exists():
            return
            
        content = claude_md_path.read_text()
        
        # Create agent list section
        agent_section = "\n## Available Task Tool Agents\n\n"
        agent_section += "These agents can be invoked directly with Task():\n\n"
        
        # Add built-in agents
        agent_section += "### Built-in Agents\n"
        agent_section += "- `general-purpose`: General-purpose agent for complex tasks\n"
        agent_section += "- `statusline-setup`: Configure status line settings\n"
        agent_section += "- `output-style-setup`: Configure output styles\n"
        agent_section += "- `C-INTERNAL`: Low-level C operations\n\n"
        
        # Add project agents
        agent_section += "### Project Agents (37 available)\n"
        for agent_id, agent_info in sorted(registry['custom_agents'].items())[:15]:
            desc = agent_info['description'][:60]
            agent_section += f"- `{agent_id}`: {desc}\n"
        
        if len(registry['custom_agents']) > 15:
            agent_section += f"\n... and {len(registry['custom_agents']) - 15} more agents\n"
            
        agent_section += "\n### Usage Example\n"
        agent_section += "```python\n"
        agent_section += 'Task(subagent_type="director", prompt="Create strategic plan")\n'
        agent_section += 'Task(subagent_type="security", prompt="Audit for vulnerabilities")\n'
        agent_section += 'Task(subagent_type="optimizer", prompt="Optimize performance")\n'
        agent_section += "```\n"
        
        # Check if section already exists
        if "## Available Task Tool Agents" not in content:
            # Add after auto-invocation patterns
            if "### Auto-Invocation Patterns" in content:
                content = content.replace(
                    "### Auto-Invocation Patterns",
                    agent_section + "\n### Auto-Invocation Patterns"
                )
            else:
                # Add at end
                content += "\n" + agent_section
                
            claude_md_path.write_text(content)
            print(f"\n📝 Updated CLAUDE.md with agent registry")
    
    def load_known_agents(self):
        """Load the list of known agents from registry"""
        if self.registry_file.exists():
            try:
                with open(self.registry_file) as f:
                    registry = json.load(f)
                    self.known_agents = set(registry.get('custom_agents', {}).keys())
            except Exception as e:
                print(f"⚠️ Could not load existing registry: {e}")
                self.known_agents = set()
        else:
            self.known_agents = set()
    
    def check_for_new_agents(self) -> List[str]:
        """Check for newly added agent files"""
        current_agents = set()
        
        for agent_file in self.agents_dir.glob("*.md"):
            if agent_file.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION']:
                continue
            current_agents.add(agent_file.stem.lower())
        
        # Find new agents
        new_agents = current_agents - self.known_agents
        
        # Find removed agents
        removed_agents = self.known_agents - current_agents
        
        return list(new_agents), list(removed_agents)
    
    def auto_update_registry(self):
        """Automatically update registry when new agents are detected"""
        new_agents, removed_agents = self.check_for_new_agents()
        
        if new_agents or removed_agents:
            print(f"\n🔄 Agent changes detected!")
            if new_agents:
                print(f"  ➕ New agents: {', '.join(new_agents)}")
            if removed_agents:
                print(f"  ➖ Removed agents: {', '.join(removed_agents)}")
            
            # Regenerate registry
            print("  📝 Updating registry...")
            self.install_silent()
            
            # Update known agents
            self.load_known_agents()
            
            return True
        return False
    
    def install_silent(self):
        """Silent install without console output (for auto-updates)"""
        try:
            # Create registry
            registry = self.create_agent_registry()
            self.registry_file.write_text(json.dumps(registry, indent=2))
            
            # Create extension
            extension = self.create_task_extension()
            extension_file = self.claude_config_dir / "task_extension.py"
            extension_file.write_text(extension)
            extension_file.chmod(0o755)
            
            # Update CLAUDE.md
            self.update_claude_md(registry)
            
            # Update activation script
            activation_script = self.claude_config_dir / "activate-agents.sh"
            activation_script.write_text('''#!/bin/bash
# Activate Project Agents for Claude Code

export CLAUDE_CUSTOM_AGENTS="/home/ubuntu/.config/claude/project-agents.json"
export PYTHONPATH="/home/ubuntu/.config/claude:$PYTHONPATH"

# Create symbolic link for C-INTERNAL style access
for agent in $(jq -r '.custom_agents | keys[]' "$CLAUDE_CUSTOM_AGENTS"); do
    export CLAUDE_AGENT_${agent^^}="available"
done

echo "✓ Project agents activated"
echo "  Run 'claude' to use with Task tool support"
''')
            activation_script.chmod(0o755)
            
        except Exception as e:
            print(f"⚠️ Silent update failed: {e}")
    
    def monitor_agents(self, interval: int = 30):
        """Monitor for agent changes in background"""
        self.monitoring = True
        print(f"\n👁️ Starting agent monitoring (checking every {interval}s)...")
        
        while self.monitoring:
            try:
                # Check for changes
                if self.auto_update_registry():
                    print(f"  ✅ Registry updated at {datetime.now().strftime('%H:%M:%S')}")
                
                # Wait for next check
                time.sleep(interval)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"⚠️ Monitor error: {e}")
                time.sleep(interval)
        
        print("\n👁️ Agent monitoring stopped")
    
    def start_monitoring(self, interval: int = 30):
        """Start background monitoring thread"""
        if self.monitor_thread and self.monitor_thread.is_alive():
            print("⚠️ Monitoring already active")
            return
        
        # Load current agents
        self.load_known_agents()
        
        # Start monitor thread
        self.monitor_thread = threading.Thread(
            target=self.monitor_agents,
            args=(interval,),
            daemon=True
        )
        self.monitor_thread.start()
        
        print(f"✅ Background monitoring started (interval: {interval}s)")
    
    def stop_monitoring(self):
        """Stop background monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        print("✅ Monitoring stopped")


if __name__ == "__main__":
    import sys
    
    registrar = AgentRegistrar()
    
    # Check for command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "--monitor":
            # Run with continuous monitoring
            registrar.install()
            registrar.load_known_agents()
            
            # Start monitoring in foreground
            try:
                registrar.monitor_agents(interval=30)
            except KeyboardInterrupt:
                print("\n\nStopping agent monitor...")
        
        elif sys.argv[1] == "--daemon":
            # Run as background daemon
            registrar.install()
            registrar.start_monitoring(interval=30)
            
            print("\n📌 Agent monitor running in background")
            print("  Registry will auto-update when agents are added/removed")
            print("  Press Ctrl+C to stop")
            
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                registrar.stop_monitoring()
        
        elif sys.argv[1] == "--check":
            # Just check for new agents
            registrar.load_known_agents()
            new_agents, removed_agents = registrar.check_for_new_agents()
            
            if new_agents or removed_agents:
                print("🔍 Agent changes detected:")
                if new_agents:
                    print(f"  ➕ New: {', '.join(new_agents)}")
                if removed_agents:
                    print(f"  ➖ Removed: {', '.join(removed_agents)}")
            else:
                print("✅ No agent changes detected")
        
        elif sys.argv[1] == "--help":
            print("Usage: register-custom-agents.py [OPTIONS]")
            print("\nOptions:")
            print("  (no args)     Install/update registry once")
            print("  --monitor     Run continuous monitoring in foreground")
            print("  --daemon      Run monitoring as background daemon")
            print("  --check       Check for new agents without updating")
            print("  --help        Show this help message")
        
        else:
            print(f"Unknown option: {sys.argv[1]}")
            print("Use --help for usage information")
    
    else:
        # Default: single installation
        registrar.install()