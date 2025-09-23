#!/usr/bin/env python3
"""
Fix remaining claude-backups project name references
"""

import os
import re
import sys
from pathlib import Path

def fix_claude_backups_references():
    """Fix remaining claude-backups hardcoded references"""
    project_root = Path(__file__).parent

    # Files that still have claude-backups references
    files_to_fix = [
        "agents/src/python/claude_agents/bridges/claude_orchestration_bridge.py",
        "agents/src/python/claude_agents/implementations/specialized/production_orchestrator.py",
        "agents/src/python/production_orchestrator.py",
        "agents/src/python/dynamic_think_mode_selector.py",
        "agents/src/python/claude_code_think_hooks.py"
    ]

    # Patterns to fix
    patterns = [
        (r'Path\.home\(\) / "Documents" / "claude-backups"', 'get_project_root()'),
        (r'Path\.home\(\) / "Downloads" / "claude-backups"', 'get_project_root()'),
        (r'Path\.home\(\) / "claude-backups"', 'get_project_root()'),
        (r'"claude-backups"', '"' + project_root.name + '"'),
        (r"'claude-backups'", "'" + project_root.name + "'"),
        (r'claude-backups', project_root.name)
    ]

    files_modified = []

    for file_path in files_to_fix:
        full_path = project_root / file_path
        if not full_path.exists():
            print(f"File not found: {full_path}")
            continue

        try:
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content

            # Apply patterns
            for pattern, replacement in patterns:
                content = re.sub(pattern, replacement, content)

            if content != original_content:
                with open(full_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                files_modified.append(str(full_path))
                print(f"Fixed: {full_path}")

        except Exception as e:
            print(f"Error processing {full_path}: {e}")

    print(f"\n✅ Fixed {len(files_modified)} files")
    return files_modified

if __name__ == "__main__":
    fix_claude_backups_references()