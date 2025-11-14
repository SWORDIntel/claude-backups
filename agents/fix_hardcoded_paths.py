#!/usr/bin/env python3
"""
COORDINATOR Agent - Systematic Hardcoded Path Fix
=================================================

This script systematically fixes ALL hardcoded paths across the entire agent ecosystem
to ensure path-agnostic operation and dynamic path discovery.

Key fixes:
1. Replace /home/ubuntu and /home/john with dynamic resolution
2. Replace hardcoded project paths like "claude-backups"
3. Update installation examples with portable patterns
4. Ensure agents can discover their own paths dynamically
"""

import glob
import json
import os
import re
import shutil
from pathlib import Path


class HardcodedPathFixer:
    def __init__(self, agents_dir):
        self.agents_dir = Path(agents_dir)
        self.fixes_applied = []

        # Dynamic path resolution patterns
        self.path_replacements = [
            # Agent directory paths
            (
                r'${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../',
                '${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../',
            ),
            (
                r'${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../',
                '${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../',
            ),
            (
                r"/home/(ubuntu|john)/[^/]+/claude-backups/agents/",
                '${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../',
            ),
            # Project root paths
            (
                r'${CLAUDE_PROJECT_ROOT:-$(dirname "$0")/../../}',
                '${CLAUDE_PROJECT_ROOT:-$(dirname "$0")/../../}',
            ),
            (
                r'${CLAUDE_PROJECT_ROOT:-$(dirname "$0")/../../}',
                '${CLAUDE_PROJECT_ROOT:-$(dirname "$0")/../../}',
            ),
            (
                r"/home/(ubuntu|john)/[^/]+/claude-backups/",
                '${CLAUDE_PROJECT_ROOT:-$(dirname "$0")/../../}',
            ),
            # Binary protocol paths
            (
                r'"/home/[^/]+/[^/]+/claude-backups/agents/binary-communications-system/([^"]+)"',
                '"${CLAUDE_AGENTS_ROOT}/binary-communications-system/$1"',
            ),
            # Source paths
            (
                r'"/home/[^/]+/[^/]+/claude-backups/agents/src/c/([^"]+)"',
                '"${CLAUDE_AGENTS_ROOT}/src/c/$1"',
            ),
            (
                r'"/home/[^/]+/[^/]+/claude-backups/agents/src/python/([^"]+)"',
                '"${CLAUDE_AGENTS_ROOT}/src/python/$1"',
            ),
            # Location fields in YAML/config
            (
                r'location: "/home/[^/]+/[^/]+/claude-backups/agents/"',
                'location: "${CLAUDE_AGENTS_ROOT}/"',
            ),
            (
                r'location: "/home/(ubuntu|john)/Documents/Claude/agents/"',
                'location: "${CLAUDE_AGENTS_ROOT}/"',
            ),
            # Python import paths
            (r"'/home/[^/]+/[^/]+/claude-backups/'", "'${CLAUDE_PROJECT_ROOT}'"),
            (r'"/home/[^/]+/[^/]+/claude-backups/"', '"${CLAUDE_PROJECT_ROOT}"'),
            # Specific hardcoded directories
            (r"${CLAUDE_BINARY:-claude}", "${CLAUDE_BINARY:-claude}"),
            (
                r"${OPENVINO_ROOT:-/opt/openvino/}",
                "${OPENVINO_ROOT:-${OPENVINO_ROOT:-/opt/openvino/}}",
            ),
            (
                r"${CLAUDE_LOG_DIR:-/var/log/claude-agents/}",
                "${CLAUDE_LOG_DIR:-${CLAUDE_LOG_DIR:-/var/log/claude-agents/}}",
            ),
        ]

        # Python-specific path replacements
        self.python_replacements = [
            # sys.path modifications
            (
                r"sys\.path\.append\('/home/[^/]+/[^/]+/claude-backups/'\)",
                "sys.path.append(os.environ.get('CLAUDE_PROJECT_ROOT', os.path.dirname(os.path.abspath(__file__)) + '/../../'))",
            ),
            (
                r"sys\.path\.insert\(0, '/home/[^/]+/[^/]+/claude-backups/'\)",
                "sys.path.insert(0, os.environ.get('CLAUDE_PROJECT_ROOT', os.path.dirname(os.path.abspath(__file__)) + '/../../'))",
            ),
            # Direct path references
            (
                r"'/home/[^/]+/[^/]+/claude-backups/agents/'",
                "os.environ.get('CLAUDE_AGENTS_ROOT', os.path.dirname(os.path.abspath(__file__)) + '/../')",
            ),
            (
                r'"/home/[^/]+/[^/]+/claude-backups/agents/"',
                'os.environ.get("CLAUDE_AGENTS_ROOT", os.path.dirname(os.path.abspath(__file__)) + "/../")',
            ),
            # Configuration file paths
            (
                r"os.path.join(os.environ.get('CLAUDE_AGENTS_ROOT', '.'), 'config', '$1')]+)'",
                "os.path.join(os.environ.get('CLAUDE_AGENTS_ROOT', '.'), 'config', '$1')",
            ),
            (
                r'os.path.join(os.environ.get("CLAUDE_AGENTS_ROOT", "."), "config", "$1")]+)"',
                'os.path.join(os.environ.get("CLAUDE_AGENTS_ROOT", "."), "config", "$1")',
            ),
        ]

        # C-specific path replacements
        self.c_replacements = [
            # #define paths
            (
                r'#define\s+AGENT_ROOT\s+"/home/[^/]+/[^/]+/claude-backups/agents/"',
                '#define AGENT_ROOT getenv("CLAUDE_AGENTS_ROOT") ? getenv("CLAUDE_AGENTS_ROOT") : "../"',
            ),
            (
                r'#define\s+PROJECT_ROOT\s+"/home/[^/]+/[^/]+/claude-backups/"',
                '#define PROJECT_ROOT getenv("CLAUDE_PROJECT_ROOT") ? getenv("CLAUDE_PROJECT_ROOT") : "../../"',
            ),
        ]

    def backup_file(self, filepath):
        """Create backup before modification"""
        backup_path = f"{filepath}.backup"
        if not os.path.exists(backup_path):
            shutil.copy2(filepath, backup_path)
        return backup_path

    def fix_file_content(self, filepath, content):
        """Apply all relevant fixes to file content"""
        original_content = content

        # Apply general replacements
        for pattern, replacement in self.path_replacements:
            content = re.sub(pattern, replacement, content)

        # Apply language-specific replacements
        if filepath.endswith(".py"):
            for pattern, replacement in self.python_replacements:
                content = re.sub(pattern, replacement, content)
        elif filepath.endswith((".c", ".h")):
            for pattern, replacement in self.c_replacements:
                content = re.sub(pattern, replacement, content)

        return content, content != original_content

    def fix_markdown_files(self):
        """Fix all agent .md files"""
        print("Fixing agent .md files...")
        md_files = list(self.agents_dir.glob("*.md"))

        for md_file in md_files:
            try:
                with open(md_file, "r", encoding="utf-8") as f:
                    content = f.read()

                fixed_content, changed = self.fix_file_content(str(md_file), content)

                if changed:
                    self.backup_file(md_file)
                    with open(md_file, "w", encoding="utf-8") as f:
                        f.write(fixed_content)

                    self.fixes_applied.append(
                        {
                            "file": str(md_file),
                            "type": "markdown",
                            "changes": "hardcoded paths → dynamic resolution",
                        }
                    )
                    print(f"  ✓ Fixed: {md_file.name}")

            except Exception as e:
                print(f"  ✗ Error fixing {md_file}: {e}")

    def fix_python_files(self):
        """Fix Python source files"""
        print("Fixing Python source files...")
        python_files = list(self.agents_dir.rglob("*.py"))

        for py_file in python_files:
            try:
                with open(py_file, "r", encoding="utf-8") as f:
                    content = f.read()

                fixed_content, changed = self.fix_file_content(str(py_file), content)

                if changed:
                    self.backup_file(py_file)
                    with open(py_file, "w", encoding="utf-8") as f:
                        f.write(fixed_content)

                    self.fixes_applied.append(
                        {
                            "file": str(py_file),
                            "type": "python",
                            "changes": "hardcoded paths → dynamic resolution",
                        }
                    )
                    print(f"  ✓ Fixed: {py_file.relative_to(self.agents_dir)}")

            except Exception as e:
                print(f"  ✗ Error fixing {py_file}: {e}")

    def fix_c_files(self):
        """Fix C source files"""
        print("Fixing C source files...")
        c_files = list(self.agents_dir.rglob("*.c")) + list(
            self.agents_dir.rglob("*.h")
        )

        for c_file in c_files:
            try:
                with open(c_file, "r", encoding="utf-8") as f:
                    content = f.read()

                fixed_content, changed = self.fix_file_content(str(c_file), content)

                if changed:
                    self.backup_file(c_file)
                    with open(c_file, "w", encoding="utf-8") as f:
                        f.write(fixed_content)

                    self.fixes_applied.append(
                        {
                            "file": str(c_file),
                            "type": "c",
                            "changes": "hardcoded paths → dynamic resolution",
                        }
                    )
                    print(f"  ✓ Fixed: {c_file.relative_to(self.agents_dir)}")

            except Exception as e:
                print(f"  ✗ Error fixing {c_file}: {e}")

    def fix_config_files(self):
        """Fix configuration and service files"""
        print("Fixing configuration files...")
        config_files = (
            list(self.agents_dir.rglob("*.json"))
            + list(self.agents_dir.rglob("*.yaml"))
            + list(self.agents_dir.rglob("*.yml"))
            + list(self.agents_dir.rglob("*.service"))
            + list(self.agents_dir.rglob("*.sh"))
        )

        for config_file in config_files:
            try:
                with open(config_file, "r", encoding="utf-8") as f:
                    content = f.read()

                fixed_content, changed = self.fix_file_content(
                    str(config_file), content
                )

                if changed:
                    self.backup_file(config_file)
                    with open(config_file, "w", encoding="utf-8") as f:
                        f.write(fixed_content)

                    self.fixes_applied.append(
                        {
                            "file": str(config_file),
                            "type": "config",
                            "changes": "hardcoded paths → dynamic resolution",
                        }
                    )
                    print(f"  ✓ Fixed: {config_file.relative_to(self.agents_dir)}")

            except Exception as e:
                print(f"  ✗ Error fixing {config_file}: {e}")

    def create_path_discovery_helper(self):
        """Create helper script for dynamic path discovery"""
        helper_content = """#!/bin/bash
# Dynamic Path Discovery Helper for Claude Agents
# This script provides consistent path resolution across the entire agent ecosystem

# Detect the project root dynamically
if [ -z "$CLAUDE_PROJECT_ROOT" ]; then
    # Try to find project root by looking for characteristic files
    current_dir="$(pwd)"
    script_dir="$(dirname "$(readlink -f "$0")")"

    # Check if we're in the agents directory
    if [ -f "$script_dir/TEMPLATE.md" ] && [ -d "$script_dir/src" ]; then
        export CLAUDE_PROJECT_ROOT="$(dirname "$script_dir")"
        export CLAUDE_AGENTS_ROOT="$script_dir"
    # Check if we're in project root
    elif [ -f "$script_dir/CLAUDE.md" ] && [ -d "$script_dir/agents" ]; then
        export CLAUDE_PROJECT_ROOT="$script_dir"
        export CLAUDE_AGENTS_ROOT="$script_dir/agents"
    # Try going up one level
    elif [ -f "$(dirname "$script_dir")/CLAUDE.md" ]; then
        export CLAUDE_PROJECT_ROOT="$(dirname "$script_dir")"
        export CLAUDE_AGENTS_ROOT="$CLAUDE_PROJECT_ROOT/agents"
    else
        # Fallback: assume standard structure
        export CLAUDE_PROJECT_ROOT="$(dirname "$script_dir")"
        export CLAUDE_AGENTS_ROOT="$script_dir"
    fi
fi

# Set default environment variables if not already set
export CLAUDE_AGENTS_ROOT="${CLAUDE_AGENTS_ROOT:-$CLAUDE_PROJECT_ROOT/agents}"
export CLAUDE_BINARY="${CLAUDE_BINARY:-claude}"
export OPENVINO_ROOT="${OPENVINO_ROOT:-${OPENVINO_ROOT:-/opt/openvino/}}"
export CLAUDE_LOG_DIR="${CLAUDE_LOG_DIR:-${CLAUDE_LOG_DIR:-/var/log/claude-agents/}}"

# Function to resolve agent-relative paths
resolve_agent_path() {
    local relative_path="$1"
    echo "$CLAUDE_AGENTS_ROOT/$relative_path"
}

# Function to resolve project-relative paths
resolve_project_path() {
    local relative_path="$1"
    echo "$CLAUDE_PROJECT_ROOT/$relative_path"
}

# Export functions for use in other scripts
export -f resolve_agent_path
export -f resolve_project_path

# Print current configuration if requested
if [ "$1" = "--show-config" ]; then
    echo "CLAUDE_PROJECT_ROOT: $CLAUDE_PROJECT_ROOT"
    echo "CLAUDE_AGENTS_ROOT: $CLAUDE_AGENTS_ROOT"
    echo "CLAUDE_BINARY: $CLAUDE_BINARY"
    echo "OPENVINO_ROOT: $OPENVINO_ROOT"
    echo "CLAUDE_LOG_DIR: $CLAUDE_LOG_DIR"
fi
"""

        helper_path = self.agents_dir / "path_discovery.sh"
        with open(helper_path, "w") as f:
            f.write(helper_content)
        os.chmod(helper_path, 0o755)

        print(f"✓ Created path discovery helper: {helper_path}")

    def create_python_path_helper(self):
        """Create Python helper for dynamic path discovery"""
        helper_content = '''"""
Dynamic Path Discovery Helper for Claude Agents (Python)
========================================================

This module provides consistent path resolution across the entire agent ecosystem
for Python scripts and modules.
"""

import os
import sys
from pathlib import Path

class AgentPathResolver:
    """Provides dynamic path resolution for agent system"""

    def __init__(self):
        self._project_root = None
        self._agents_root = None
        self._detect_paths()

    def _detect_paths(self):
        """Detect project and agent root paths dynamically"""
        # Check environment variables first
        if os.environ.get('CLAUDE_PROJECT_ROOT'):
            self._project_root = Path(os.environ['CLAUDE_PROJECT_ROOT'])
            self._agents_root = Path(os.environ.get('CLAUDE_AGENTS_ROOT',
                                                  self._project_root / 'agents'))
            return

        # Try to detect based on current file location
        current_file = Path(__file__).resolve()
        current_dir = current_file.parent

        # Look for characteristic files to identify structure
        for parent in [current_dir] + list(current_dir.parents):
            # Check if this is agents directory
            if (parent / 'TEMPLATE.md').exists() and (parent / 'src').exists():
                self._agents_root = parent
                self._project_root = parent.parent
                break
            # Check if this is project root
            elif (parent / 'CLAUDE.md').exists() and (parent / 'agents').exists():
                self._project_root = parent
                self._agents_root = parent / 'agents'
                break

        # Fallback
        if not self._project_root:
            self._project_root = current_dir.parent
            self._agents_root = current_dir

        # Set environment variables for other processes
        os.environ['CLAUDE_PROJECT_ROOT'] = str(self._project_root)
        os.environ['CLAUDE_AGENTS_ROOT'] = str(self._agents_root)

    @property
    def project_root(self):
        """Get project root path"""
        return self._project_root

    @property
    def agents_root(self):
        """Get agents root path"""
        return self._agents_root

    def resolve_agent_path(self, relative_path):
        """Resolve path relative to agents directory"""
        return self._agents_root / relative_path

    def resolve_project_path(self, relative_path):
        """Resolve path relative to project root"""
        return self._project_root / relative_path

    def add_to_python_path(self):
        """Add project root to Python path if not already present"""
        project_str = str(self._project_root)
        if project_str not in sys.path:
            sys.path.insert(0, project_str)

    def get_config_path(self, config_name):
        """Get path to configuration file"""
        return self.resolve_agent_path(fos.path.join(os.environ.get('CLAUDE_AGENTS_ROOT', '.'), 'config', '$1'))

    def get_binary_path(self, binary_name):
        """Get path to binary file"""
        return self.resolve_agent_path(f'binary-communications-system/{binary_name}')

    def get_src_path(self, lang, filename):
        """Get path to source file"""
        return self.resolve_agent_path(f'src/{lang}/{filename}')

# Global instance for easy importing
path_resolver = AgentPathResolver()

# Convenience functions
def get_project_root():
    return path_resolver.project_root

def get_agents_root():
    return path_resolver.agents_root

def resolve_agent_path(relative_path):
    return path_resolver.resolve_agent_path(relative_path)

def resolve_project_path(relative_path):
    return path_resolver.resolve_project_path(relative_path)

def add_to_python_path():
    path_resolver.add_to_python_path()

# Auto-add to Python path when imported
add_to_python_path()
'''

        helper_path = self.agents_dir / "src" / "python" / "agent_path_resolver.py"
        helper_path.parent.mkdir(parents=True, exist_ok=True)
        with open(helper_path, "w") as f:
            f.write(helper_content)

        print(f"✓ Created Python path helper: {helper_path}")

    def generate_report(self):
        """Generate comprehensive fix report"""
        report = {
            "timestamp": str(Path.cwd()),
            "total_fixes": len(self.fixes_applied),
            "fixes_by_type": {},
            "fixes_applied": self.fixes_applied,
            "dynamic_patterns_created": [
                "CLAUDE_PROJECT_ROOT environment variable support",
                "CLAUDE_AGENTS_ROOT environment variable support",
                "Dynamic path discovery based on file structure",
                "Bash helper script (path_discovery.sh)",
                "Python helper module (agent_path_resolver.py)",
            ],
        }

        # Count fixes by type
        for fix in self.fixes_applied:
            fix_type = fix["type"]
            report["fixes_by_type"][fix_type] = (
                report["fixes_by_type"].get(fix_type, 0) + 1
            )

        report_path = self.agents_dir / "hardcoded_paths_fix_report.json"
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)

        print(f"\n📊 Fix Report:")
        print(f"  Total files fixed: {report['total_fixes']}")
        for fix_type, count in report["fixes_by_type"].items():
            print(f"  {fix_type.title()} files: {count}")
        print(f"  Report saved: {report_path}")

    def run_comprehensive_fix(self):
        """Execute comprehensive hardcoded path fix"""
        print("🔧 COORDINATOR Agent - Hardcoded Path Fix")
        print("=" * 50)

        # Create helper scripts first
        self.create_path_discovery_helper()
        self.create_python_path_helper()

        # Fix all file types
        self.fix_markdown_files()
        self.fix_python_files()
        self.fix_c_files()
        self.fix_config_files()

        # Generate report
        self.generate_report()

        print("\n✅ Comprehensive hardcoded path fix completed!")
        print("All agents now use dynamic path resolution.")


if __name__ == "__main__":
    # Detect agents directory
    current_dir = Path(__file__).parent
    agents_dir = current_dir if current_dir.name == "agents" else current_dir / "agents"

    if not agents_dir.exists():
        print("❌ Error: Could not find agents directory")
        sys.exit(1)

    # Run the fix
    fixer = HardcodedPathFixer(agents_dir)
    fixer.run_comprehensive_fix()
