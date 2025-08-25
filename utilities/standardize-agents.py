#!/usr/bin/env python3
"""
Standardize all agent files to UPPERCASE naming
"""

import os
from pathlib import Path

def main():
    print("🔧 Standardizing all agent files to UPPERCASE...")
    
    agents_dir = Path("agents")
    if not agents_dir.exists():
        print("❌ agents/ directory not found")
        return False
    
    # Find all .md files
    agent_files = list(agents_dir.glob("*.md"))
    print(f"📁 Found {len(agent_files)} .md files in agents/")
    
    renames_needed = []
    already_uppercase = []
    exclude_files = {'README.md', 'TEMPLATE.md', 'WHERE_I_AM.md'}
    
    for agent_file in agent_files:
        if agent_file.name in exclude_files:
            print(f"⏭️ Skipping: {agent_file.name}")
            continue
            
        current_name = agent_file.stem
        uppercase_name = current_name.upper()
        
        if current_name != uppercase_name:
            new_file = agent_file.parent / f"{uppercase_name}.md"
            renames_needed.append((agent_file, new_file))
            print(f"🔄 Need to rename: {agent_file.name} -> {new_file.name}")
        else:
            already_uppercase.append(agent_file.name)
            print(f"✅ Already uppercase: {agent_file.name}")
    
    print(f"\n📊 Summary:")
    print(f"  • Already uppercase: {len(already_uppercase)}")
    print(f"  • Need renaming: {len(renames_needed)}")
    
    if renames_needed:
        print(f"\n🔧 Performing renames...")
        for old_file, new_file in renames_needed:
            try:
                old_file.rename(new_file)
                print(f"  ✅ {old_file.name} -> {new_file.name}")
            except Exception as e:
                print(f"  ❌ Failed to rename {old_file.name}: {e}")
    
    # Update all_md_agents.txt to uppercase
    all_agents_file = Path("all_md_agents.txt")
    if all_agents_file.exists():
        print(f"\n📝 Updating all_md_agents.txt to uppercase...")
        lines = all_agents_file.read_text().strip().split('\n')
        uppercase_lines = [line.upper() for line in lines]
        all_agents_file.write_text('\n'.join(uppercase_lines) + '\n')
        print(f"  ✅ Updated {len(lines)} agent names to uppercase")
    
    print(f"\n✅ Standardization complete!")
    return True

if __name__ == "__main__":
    main()