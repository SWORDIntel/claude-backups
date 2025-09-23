#!/usr/bin/env python3
import asyncio
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
sys.path.append('/home/ubuntu/Documents/Claude/agents')

class QuickVoice:
    def __init__(self):
        self.agents = {
            'director': ['plan', 'strategy', 'coordinate'],
            'planner': ['timeline', 'roadmap', 'schedule'], 
            'architect': ['design', 'architecture', 'build'],
            'security': ['security', 'audit', 'vulnerability']
        }
    
    def parse_command(self, text):
        text = text.lower()
        for wake in ['claude', 'agent', 'hey claude']:
            text = text.replace(wake, '').strip()
        
        for agent, keywords in self.agents.items():
            if any(k in text for k in keywords):
                return agent.upper(), text
        return 'DIRECTOR', text
    
    async def execute(self, voice_input):
        from claude_agent_bridge import task_agent_invoke
        agent, command = self.parse_command(voice_input)
        result = await task_agent_invoke(agent, command)
        return f'{agent}: {result.get("status", "completed")}'

voice = QuickVoice()

async def demo():
    commands = [
        'Claude, plan my project deployment',
        'Ask security to audit the system', 
        'Have architect design the API'
    ]
    
    for cmd in commands:
        try:
            result = await voice.execute(cmd)
            print(f'✅ "{cmd}" → {result}')
        except Exception as e:
            print(f'❌ "{cmd}" → {e}')

asyncio.run(demo())
