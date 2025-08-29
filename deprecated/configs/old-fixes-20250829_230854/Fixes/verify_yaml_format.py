#!/usr/bin/env python3
"""
Verify YAML frontmatter format in all agent files.
Checks that all agent .md files have proper YAML frontmatter.
"""

import os
import glob

def check_agent_file(filepath):
    """Check if an agent file has proper YAML frontmatter."""
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    if len(lines) < 5:
        return False, "File too short"
    
    # Check for proper YAML frontmatter structure
    if not lines[0].strip() == '---':
        return False, f"Missing opening --- (first line: {lines[0][:30].strip()})"
    
    # Look for closing --- within first 10 lines (after comments)
    found_closing = False
    for i in range(1, min(10, len(lines))):
        if lines[i].strip() == '---':
            found_closing = True
            break
    
    if not found_closing:
        return False, "Missing closing --- after header comment"
    
    return True, "Valid YAML frontmatter"

def main():
    os.chdir('/home/ubuntu/Documents/Claude/agents')
    
    # List of known agent files
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
    
    print("=" * 60)
    print("YAML Frontmatter Verification Report")
    print("=" * 60)
    print()
    
    valid_count = 0
    invalid_count = 0
    missing_count = 0
    
    print("Checking agent files:")
    print("-" * 40)
    
    for filename in agent_files:
        if os.path.exists(filename):
            is_valid, message = check_agent_file(filename)
            if is_valid:
                print(f"✅ {filename:<30} - {message}")
                valid_count += 1
            else:
                print(f"❌ {filename:<30} - {message}")
                invalid_count += 1
        else:
            print(f"⚠️  {filename:<30} - File not found")
            missing_count += 1
    
    print()
    print("=" * 60)
    print("Summary:")
    print(f"  ✅ Valid:    {valid_count} files")
    print(f"  ❌ Invalid:  {invalid_count} files")
    print(f"  ⚠️  Missing:  {missing_count} files")
    print(f"  Total:       {valid_count + invalid_count + missing_count} files")
    print("=" * 60)
    
    if invalid_count > 0:
        print("\n⚠️  Some files need manual fixing!")
        print("Run the fix_yaml_frontmatter.py script or edit manually.")
    else:
        print("\n✨ All agent files have valid YAML frontmatter!")

if __name__ == "__main__":
    main()