#!/usr/bin/env python3
"""Add closing --- to YAML frontmatter before hash sections"""

import re
from pathlib import Path

def fix_yaml_closing(filepath):
    """Add closing --- before first hash section if missing"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Check if file starts with frontmatter
    if not content.startswith('---'):
        return False, "No frontmatter"
    
    # Find first hash section
    hash_match = re.search(r'\n#{10,}\n', content)
    if not hash_match:
        # Check if already has closing ---
        if content.count('---') >= 2:
            return True, "Already has closing"
        return False, "No hash section found"
    
    hash_pos = hash_match.start()
    
    # Check if there's already a closing --- before the hash section
    before_hash = content[:hash_pos]
    if before_hash.count('---') >= 2:
        return True, "Already has closing"
    
    # Find the best place to insert closing ---
    # Look for the last YAML line before the hash section
    lines = before_hash.split('\n')
    
    # Find last non-empty, non-comment line
    insert_pos = -1
    for i in range(len(lines) - 1, 0, -1):
        line = lines[i].strip()
        if line and not line.startswith('#'):
            insert_pos = i + 1
            break
    
    if insert_pos == -1:
        return False, "Could not find insertion point"
    
    # Insert the closing ---
    lines.insert(insert_pos, '---')
    if insert_pos < len(lines) and lines[insert_pos + 1].strip() != '':
        lines.insert(insert_pos + 1, '')
    
    # Reconstruct content
    new_before = '\n'.join(lines)
    new_content = new_before + content[hash_pos:]
    
    # Write back
    with open(filepath, 'w') as f:
        f.write(new_content)
    
    return True, "Fixed"

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
    
    print(f"Fixing {len(agent_files)} agent files...\n")
    
    for agent_file in agent_files:
        success, message = fix_yaml_closing(agent_file)
        status = "✅" if success else "❌"
        print(f"{status} {agent_file.name}: {message}")
    
    print("\n✨ Done!")

if __name__ == '__main__':
    main()