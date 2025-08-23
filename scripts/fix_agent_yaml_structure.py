#!/usr/bin/env python3
"""Fix YAML structure in agent files - ensure frontmatter ends before section headers"""

import re
from pathlib import Path

def fix_agent_yaml_structure(filepath):
    """Fix YAML structure by ensuring frontmatter ends before hash sections"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Check if file starts with frontmatter
    if not content.startswith('---'):
        print(f"  ⚠️  {filepath.name}: No frontmatter found")
        return False
    
    # Find the first hash section
    hash_section_pattern = r'\n#{10,}\n# .+\n#{10,}'
    match = re.search(hash_section_pattern, content)
    
    if not match:
        # No hash sections found, check if there's already a closing ---
        if content.count('---') >= 2:
            print(f"  ✅ {filepath.name}: Already properly structured")
            return True
        else:
            print(f"  ⚠️  {filepath.name}: No hash sections found")
            return False
    
    # Get position of first hash section
    hash_start = match.start()
    
    # Find the frontmatter content (everything before the hash section)
    frontmatter_end = content[:hash_start].rfind('\n')
    if frontmatter_end == -1:
        frontmatter_end = hash_start
    
    # Check if there's already a closing --- before the hash section
    frontmatter_content = content[:frontmatter_end]
    if frontmatter_content.count('---') >= 2:
        print(f"  ✅ {filepath.name}: Already has closing delimiter")
        return True
    
    # Find the last valid YAML field before the hash section
    # Look for lines that are valid YAML (indented or field: value)
    lines = frontmatter_content.split('\n')
    last_yaml_line = -1
    
    for i in range(len(lines) - 1, 0, -1):
        line = lines[i].strip()
        # Skip empty lines
        if not line:
            continue
        # Check if it's a comment line
        if line.startswith('#'):
            continue
        # This looks like YAML content
        if ':' in line or line.startswith('-') or line.startswith(' '):
            last_yaml_line = i
            break
    
    if last_yaml_line == -1:
        print(f"  ⚠️  {filepath.name}: Could not find valid YAML content")
        return False
    
    # Reconstruct the file
    new_lines = lines[:last_yaml_line + 1]
    new_lines.append('---')
    new_lines.append('')
    
    # Add the rest of the content (hash sections and beyond)
    remaining_content = content[hash_start:]
    
    new_content = '\n'.join(new_lines) + remaining_content
    
    # Write back
    with open(filepath, 'w') as f:
        f.write(new_content)
    
    print(f"  ✅ {filepath.name}: Fixed - added closing delimiter before hash sections")
    return True

def main():
    agents_dir = Path('/home/ubuntu/Documents/Claude/agents')
    
    # Get all agent .md files
    agent_files = []
    for file in agents_dir.glob('*.md'):
        if file.name in ['WHERE_I_AM.md', 'Template.md', 'TEMPLATE.md']:
            continue
        if not file.stem.isupper() and file.stem not in ['C-INTERNAL', 'PYTHON-INTERNAL']:
            continue
        agent_files.append(file)
    
    agent_files.sort()
    
    print(f"Fixing YAML structure in {len(agent_files)} agent files...\n")
    
    success_count = 0
    for agent_file in agent_files:
        print(f"Processing {agent_file.name}...")
        if fix_agent_yaml_structure(agent_file):
            success_count += 1
    
    print(f"\n✨ Fixed {success_count}/{len(agent_files)} agent files")

if __name__ == '__main__':
    main()