#!/usr/bin/env python3
"""
Fix malformed YAML frontmatter in agent .md files.
Adds closing --- after the comment block to make valid YAML.

The problem:
---
# COMMENT BLOCK
metadata:
  ...

The fix:
---
# COMMENT BLOCK
---
metadata:
  ...
"""

import os
import re
import glob

def fix_agent_file(filepath):
    """Fix the YAML frontmatter in a single agent file."""
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Check if file starts with --- and has comment block
    if not content.startswith('---'):
        print(f"⏭️  {filepath}: No frontmatter found, skipping")
        return False
    
    # Pattern to match: --- followed by comment block, then metadata
    # We need to insert --- between comment block and metadata
    pattern = r'^(---\n)(#+.*?\n#+.*?\n)(metadata:)'
    
    # Check if already fixed (has closing ---)
    if re.search(r'^---\n#+.*?\n#+.*?\n---\nmetadata:', content, re.MULTILINE | re.DOTALL):
        print(f"✅ {filepath}: Already fixed")
        return False
    
    # Fix the frontmatter by adding --- after comment block
    fixed_content = re.sub(
        pattern,
        r'\1\2---\n\3',
        content,
        count=1,
        flags=re.MULTILINE | re.DOTALL
    )
    
    if fixed_content != content:
        # Backup original
        backup_path = filepath + '.backup'
        if not os.path.exists(backup_path):
            with open(backup_path, 'w') as f:
                f.write(content)
        
        # Write fixed content
        with open(filepath, 'w') as f:
            f.write(fixed_content)
        
        print(f"✨ {filepath}: Fixed! (backup saved as {backup_path})")
        return True
    else:
        print(f"⚠️  {filepath}: Pattern not matched, manual review needed")
        return False

def main():
    """Fix all agent .md files in the current directory."""
    
    print("🔧 Fixing YAML Frontmatter in Agent Files")
    print("=" * 50)
    
    # Change to agents directory
    agents_dir = "/home/ubuntu/Documents/Claude/agents"
    os.chdir(agents_dir)
    
    # Find all agent .md files (exclude README, Template, etc.)
    agent_files = [
        'Director.md', 'ProjectOrchestrator.md', 'Architect.md', 'Security.md',
        'Constructor.md', 'Testbed.md', 'Optimizer.md', 'Debugger.md', 
        'Deployer.md', 'Monitor.md', 'Database.md', 'MLOps.md', 'Patcher.md',
        'Linter.md', 'Docgen.md', 'Infrastructure.md', 'APIDesigner.md',
        'Web.md', 'Mobile.md', 'PyGUI.md', 'TUI.md', 'DataScience.md',
        'c-internal.md', 'python-internal.md', 'SecurityChaosAgent.md',
        'Bastion.md', 'Oversight.md', 'RESEARCHER.md', 'GNU.md', 'NPU.md',
        'PLANNER.md'
    ]
    
    fixed_count = 0
    for filename in agent_files:
        if os.path.exists(filename):
            if fix_agent_file(filename):
                fixed_count += 1
        else:
            print(f"❌ {filename}: File not found")
    
    # Also update files in ~/.claude/agents/
    print("\n🔄 Updating ~/.claude/agents/ copies...")
    claude_agents_dir = os.path.expanduser("~/.claude/agents/")
    if os.path.exists(claude_agents_dir):
        for filename in agent_files:
            src = os.path.join(agents_dir, filename)
            dst = os.path.join(claude_agents_dir, filename)
            if os.path.exists(src) and os.path.exists(dst):
                with open(src, 'r') as f:
                    content = f.read()
                with open(dst, 'w') as f:
                    f.write(content)
                print(f"📋 Copied {filename} to ~/.claude/agents/")
    
    print("\n" + "=" * 50)
    print(f"✅ Complete! Fixed {fixed_count} files")
    print("\nTo verify the fix, check any agent file:")
    print("  head -n 10 Director.md")
    print("\nTo restore backups if needed:")
    print("  for f in *.md.backup; do mv $f ${f%.backup}; done")

if __name__ == "__main__":
    main()