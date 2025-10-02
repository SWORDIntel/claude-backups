#!/usr/bin/env python3
"""
Automated Script to Fix All Hardcoded Paths in Python Files
Systematically fixes /home/john, /home/ubuntu, and claude-backups references
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Tuple
import argparse
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PathFixer:
    """Fixes hardcoded paths in Python files"""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.files_modified = []
        self.changes_made = []

    def find_python_files(self) -> List[Path]:
        """Find all Python files in the project"""
        python_files = []
        for pattern in ['**/*.py']:
            python_files.extend(self.project_root.glob(pattern))
        return python_files

    def fix_imports_section(self, content: str) -> str:
        """Fix the imports section to include path utilities"""
        lines = content.split('\n')

        # Find if path_utilities is already imported
        has_path_utilities = any('from path_utilities import' in line or 'import path_utilities' in line for line in lines)
        has_project_root_setup = any('project_root = Path(__file__)' in line for line in lines)

        if has_path_utilities and has_project_root_setup:
            return content  # Already properly set up

        # Find insertion point after imports
        insert_index = -1
        in_docstring = False
        docstring_quotes = None

        for i, line in enumerate(lines):
            stripped = line.strip()

            # Handle docstrings
            if stripped.startswith('"""') or stripped.startswith("'''"):
                if not in_docstring:
                    in_docstring = True
                    docstring_quotes = stripped[:3]
                elif stripped.endswith(docstring_quotes):
                    in_docstring = False
                continue
            elif in_docstring:
                continue

            # Skip shebang and encoding
            if stripped.startswith('#!') or stripped.startswith('# -*-') or stripped.startswith('# coding'):
                continue

            # Skip blank lines and comments at the top
            if not stripped or stripped.startswith('#'):
                continue

            # Check for import statements
            if (stripped.startswith('import ') or
                stripped.startswith('from ') or
                'import' in stripped):
                continue
            else:
                insert_index = i
                break

        # If no good insertion point found, insert after last import
        if insert_index == -1:
            for i in range(len(lines) - 1, -1, -1):
                if ('import ' in lines[i] or 'from ' in lines[i]) and not lines[i].strip().startswith('#'):
                    insert_index = i + 1
                    break

        if insert_index == -1:
            insert_index = 1  # Insert after first line (usually shebang)

        # Create the path utilities import section
        path_utils_section = [
            "",
            "# Add project root to Python path for imports",
            "project_root = Path(__file__).parent.parent.parent",
            "sys.path.insert(0, str(project_root))",
            "",
            "try:",
            "    from path_utilities import (",
            "        get_project_root, get_agents_dir, get_database_dir,",
            "        get_python_src_dir, get_shadowgit_paths, get_database_config",
            "    )",
            "except ImportError:",
            "    # Fallback if path_utilities not available",
            "    def get_project_root():",
            "        return Path(__file__).parent.parent.parent",
            "    def get_agents_dir():",
            "        return get_project_root() / 'agents'",
            "    def get_database_dir():",
            "        return get_project_root() / 'database'",
            "    def get_python_src_dir():",
            "        return get_agents_dir() / 'src' / 'python'",
            "    def get_shadowgit_paths():",
            "        home_dir = Path.home()",
            "        return {'root': home_dir / 'shadowgit'}",
            "    def get_database_config():",
            "        return {",
            "            'host': 'localhost', 'port': 5433,",
            "            'database': 'claude_agents_auth',",
            "            'user': 'claude_agent', 'password': 'claude_auth_pass'",
            "        }"
        ]

        # Insert the section
        lines[insert_index:insert_index] = path_utils_section
        return '\n'.join(lines)

    def fix_hardcoded_paths(self, content: str) -> Tuple[str, List[str]]:
        """Fix hardcoded paths in content"""
        changes = []
        original_content = content

        # Fix /home/john/claude-backups patterns
        patterns_john = [
            (r'"/home/john/claude-backups"', 'str(get_project_root())'),
            (r"'/home/john/claude-backups'", 'str(get_project_root())'),
            (r'"/home/john/claude-backups/', 'str(get_project_root() / "'),
            (r"'/home/john/claude-backups/", "str(get_project_root() / '"),
            (r'Path\("/home/john/claude-backups"\)', 'get_project_root()'),
            (r"Path\('/home/john/claude-backups'\)", 'get_project_root()'),
            (r'Path\("/home/john/claude-backups/([^"]+)"\)', r'get_project_root() / "\1"'),
            (r"Path\('/home/john/claude-backups/([^']+)'\)", r"get_project_root() / '\1'"),
        ]

        # Fix /home/ubuntu/claude-backups patterns
        patterns_ubuntu = [
            (r'"/home/ubuntu/claude-backups"', 'str(get_project_root())'),
            (r"'/home/ubuntu/claude-backups'", 'str(get_project_root())'),
            (r'"/home/ubuntu/claude-backups/', 'str(get_project_root() / "'),
            (r"'/home/ubuntu/claude-backups/", "str(get_project_root() / '"),
            (r'Path\("/home/ubuntu/claude-backups"\)', 'get_project_root()'),
            (r"Path\('/home/ubuntu/claude-backups'\)", 'get_project_root()'),
            (r'Path\("/home/ubuntu/claude-backups/([^"]+)"\)', r'get_project_root() / "\1"'),
            (r"Path\('/home/ubuntu/claude-backups/([^']+)'\)", r"get_project_root() / '\1'"),
        ]

        # Fix /home/ubuntu/Documents/Claude patterns
        patterns_docs = [
            (r'"/home/ubuntu/Documents/Claude"', 'str(get_project_root())'),
            (r"'/home/ubuntu/Documents/Claude'", 'str(get_project_root())'),
            (r'Path\("/home/ubuntu/Documents/Claude"\)', 'get_project_root()'),
            (r"Path\('/home/ubuntu/Documents/Claude'\)", 'get_project_root()'),
        ]

        # Fix shadowgit paths
        patterns_shadowgit = [
            (r"sys\.path\.append\('/home/john/shadowgit'\)",
             "shadowgit_paths = get_shadowgit_paths()\nif shadowgit_paths['root'].exists():\n    sys.path.append(str(shadowgit_paths['root']))"),
            (r'sys\.path\.append\("/home/john/shadowgit"\)',
             'shadowgit_paths = get_shadowgit_paths()\nif shadowgit_paths[\'root\'].exists():\n    sys.path.append(str(shadowgit_paths[\'root\']))'),
        ]

        # Apply all patterns
        all_patterns = patterns_john + patterns_ubuntu + patterns_docs + patterns_shadowgit

        for pattern, replacement in all_patterns:
            new_content, count = re.subn(pattern, replacement, content)
            if count > 0:
                changes.append(f"Replaced {count} occurrences of {pattern}")
                content = new_content

        # Fix specific database directory references
        db_patterns = [
            (r'"/home/john/claude-backups/database"', 'str(get_database_dir())'),
            (r"'/home/john/claude-backups/database'", 'str(get_database_dir())'),
            (r'"/home/ubuntu/claude-backups/database"', 'str(get_database_dir())'),
            (r"'/home/ubuntu/claude-backups/database'", 'str(get_database_dir())'),
            (r'Path\("/home/john/claude-backups/database"\)', 'get_database_dir()'),
            (r"Path\('/home/john/claude-backups/database'\)", 'get_database_dir()'),
        ]

        for pattern, replacement in db_patterns:
            new_content, count = re.subn(pattern, replacement, content)
            if count > 0:
                changes.append(f"Replaced {count} database path occurrences")
                content = new_content

        # Fix agents directory references
        agents_patterns = [
            (r'"/home/john/claude-backups/agents"', 'str(get_agents_dir())'),
            (r"'/home/john/claude-backups/agents'", 'str(get_agents_dir())'),
            (r'"/home/ubuntu/claude-backups/agents"', 'str(get_agents_dir())'),
            (r"'/home/ubuntu/claude-backups/agents'", 'str(get_agents_dir())'),
            (r'Path\("/home/john/claude-backups/agents"\)', 'get_agents_dir()'),
            (r"Path\('/home/john/claude-backups/agents'\)", 'get_agents_dir()'),
        ]

        for pattern, replacement in agents_patterns:
            new_content, count = re.subn(pattern, replacement, content)
            if count > 0:
                changes.append(f"Replaced {count} agents path occurrences")
                content = new_content

        return content, changes

    def process_file(self, file_path: Path) -> bool:
        """Process a single file"""
        try:
            # Read file
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content

            # Skip files that already have proper imports
            if 'from path_utilities import' in content:
                logger.debug(f"Skipping {file_path} - already has path_utilities")
                return False

            # Check if file has hardcoded paths
            has_hardcoded = any(pattern in content for pattern in [
                '/home/john/claude-backups',
                '/home/ubuntu/claude-backups',
                '/home/ubuntu/Documents/Claude',
                "sys.path.append('/home/john/shadowgit')"
            ])

            if not has_hardcoded:
                logger.debug(f"Skipping {file_path} - no hardcoded paths found")
                return False

            # Add necessary imports (sys and Path if not present)
            if 'import sys' not in content and 'from sys import' not in content:
                content = content.replace('import os', 'import os\nimport sys')

            if 'from pathlib import Path' not in content and 'import pathlib' not in content:
                # Find a good place to add pathlib import
                if 'from pathlib import' in content:
                    content = re.sub(r'from pathlib import ([^\n]+)',
                                   r'from pathlib import \1, Path', content)
                else:
                    content = content.replace('import os', 'import os\nfrom pathlib import Path')

            # Fix imports section
            content = self.fix_imports_section(content)

            # Fix hardcoded paths
            content, changes = self.fix_hardcoded_paths(content)

            if content != original_content:
                # Write file back
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)

                self.files_modified.append(str(file_path))
                self.changes_made.extend([f"{file_path}: {change}" for change in changes])
                logger.info(f"Fixed {file_path}")
                return True

            return False

        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
            return False

    def fix_all_files(self) -> Dict[str, int]:
        """Fix all Python files in the project"""
        python_files = self.find_python_files()

        stats = {
            'total_files': len(python_files),
            'files_modified': 0,
            'files_skipped': 0,
            'files_error': 0
        }

        for file_path in python_files:
            # Skip certain files
            if any(skip in str(file_path) for skip in [
                '__pycache__', '.git', 'venv', 'env',
                'path_utilities.py', 'fix_hardcoded_paths.py'
            ]):
                stats['files_skipped'] += 1
                continue

            try:
                if self.process_file(file_path):
                    stats['files_modified'] += 1
                else:
                    stats['files_skipped'] += 1
            except Exception as e:
                logger.error(f"Error processing {file_path}: {e}")
                stats['files_error'] += 1

        return stats


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Fix hardcoded paths in Python files')
    parser.add_argument('--project-root', type=Path,
                       default=Path(__file__).parent,
                       help='Project root directory')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be changed without making changes')
    parser.add_argument('--verbose', action='store_true',
                       help='Verbose output')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Initialize fixer
    fixer = PathFixer(args.project_root)

    print(f"🔧 Fixing hardcoded paths in: {args.project_root}")
    print("=" * 60)

    if args.dry_run:
        print("DRY RUN - No files will be modified")
        print("-" * 60)

    # Fix all files
    stats = fixer.fix_all_files()

    # Report results
    print("\n📊 Results:")
    print(f"  Total files found: {stats['total_files']}")
    print(f"  Files modified: {stats['files_modified']}")
    print(f"  Files skipped: {stats['files_skipped']}")
    print(f"  Files with errors: {stats['files_error']}")

    if fixer.files_modified:
        print(f"\n✅ Modified files:")
        for file_path in fixer.files_modified:
            print(f"  - {file_path}")

    if args.verbose and fixer.changes_made:
        print(f"\n📝 Changes made:")
        for change in fixer.changes_made[:20]:  # Show first 20 changes
            print(f"  - {change}")
        if len(fixer.changes_made) > 20:
            print(f"  ... and {len(fixer.changes_made) - 20} more changes")

    print(f"\n🎉 Path fixing complete!")


if __name__ == "__main__":
    main()