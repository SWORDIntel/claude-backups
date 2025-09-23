#!/usr/bin/env python3
"""Validate YAML frontmatter in all agent files"""

import yaml
from pathlib import Path

def validate_agent(filepath):
    """Validate a single agent file"""

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
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Check structure
        if not content.startswith('---'):
            return False, "No frontmatter"
        
        parts = content.split('---', 2)
        if len(parts) < 3:
            return False, "Missing closing ---"
        
        # Parse YAML
        frontmatter = parts[1]
        data = yaml.safe_load(frontmatter)
        
        if not data or 'metadata' not in data:
            return False, "No metadata"
        
        # Check required fields
        metadata = data['metadata']
        required = ['name', 'version', 'uuid', 'category', 'priority', 'status', 'description']
        missing = [f for f in required if f not in metadata]
        
        if missing:
            return False, f"Missing: {', '.join(missing)}"
        
        return True, "Valid"
        
    except yaml.YAMLError as e:
        # Get just the first line of error
        error_msg = str(e).split('\n')[0]
        return False, f"YAML error: {error_msg}"
    except Exception as e:
        return False, str(e)

def main():
    agents_dir = Path('/home/ubuntu/Documents/Claude/agents')
    
    agent_files = []
    for file in agents_dir.glob('*.md'):
        if file.name in ['WHERE_I_AM.md', 'Template.md', 'TEMPLATE.md']:
            continue
        if not file.stem.isupper() and file.stem not in ['C-INTERNAL', 'PYTHON-INTERNAL']:
            continue
        agent_files.append(file)
    
    agent_files.sort()
    
    valid = 0
    invalid = 0
    
    print("Validating agent files:\n")
    
    for agent_file in agent_files:
        is_valid, message = validate_agent(agent_file)
        
        if is_valid:
            print(f"✅ {agent_file.name}: {message}")
            valid += 1
        else:
            print(f"❌ {agent_file.name}: {message}")
            invalid += 1
    
    print(f"\n📊 Summary: {valid} valid, {invalid} invalid")
    
    if invalid == 0:
        print("✨ All agent files are valid!")

if __name__ == '__main__':
    main()