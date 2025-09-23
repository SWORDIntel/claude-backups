#!/usr/bin/env python3
"""
Claude Agent Framework Path Utilities
Provides dynamic path resolution to eliminate hardcoded paths across the system
"""

import os
import sys
from pathlib import Path
from typing import Optional, Dict, List, Union
import logging

logger = logging.getLogger(__name__)


class PathResolver:
    """Dynamic path resolution for Claude Agent Framework"""

    def __init__(self, project_name: Optional[str] = None):
        self.project_name = project_name or self._detect_project_name()
        self._cache = {}
        self._project_root = None

    def _detect_project_name(self) -> str:
        """Detect project name from current environment"""
        # Try environment variable first
        project_name = os.environ.get('CLAUDE_PROJECT_NAME')
        if project_name:
            return project_name

        # Try to detect from current working directory
        cwd = Path.cwd()
        for part in cwd.parts:
            if 'claude' in part.lower():
                return part

        # Try to detect from script location
        script_path = Path(__file__)
        for parent in script_path.parents:
            if parent.name and 'claude' in parent.name.lower():
                return parent.name

        # Default fallback
        return 'claude-backups'

    def get_project_root(self) -> Path:
        """Get the project root directory"""
        if self._project_root is not None:
            return self._project_root

        # Check environment variable first
        env_root = os.environ.get('CLAUDE_PROJECT_ROOT')
        if env_root:
            self._project_root = Path(env_root)
            return self._project_root

        # Check common environment variables
        for env_var in ['CLAUDE_AGENTS_ROOT', 'CLAUDE_HOME']:
            env_path = os.environ.get(env_var)
            if env_path:
                env_path = Path(env_path)
                if env_path.name == 'agents':
                    self._project_root = env_path.parent
                else:
                    self._project_root = env_path
                return self._project_root

        # Try to find from current script location
        script_path = Path(__file__).resolve()
        for parent in [script_path.parent] + list(script_path.parents):
            # Look for marker files that indicate project root
            # CLAUDE.md is the strongest indicator
            if (parent / 'CLAUDE.md').exists() and (parent / 'agents').exists():
                self._project_root = parent
                return self._project_root

            # Also check for agents directory with multiple markers
            marker_files = ['README.md', '.git', 'database', 'tools', 'config']
            marker_count = sum(1 for marker in marker_files if (parent / marker).exists())

            if (parent / 'agents').exists() and marker_count >= 2:
                self._project_root = parent
                return self._project_root

        # Try current working directory and its parents
        cwd = Path.cwd()
        for parent in [cwd] + list(cwd.parents):
            if (parent / 'agents').exists() and (parent / 'CLAUDE.md').exists():
                self._project_root = parent
                return self._project_root

        # Try common installation locations
        home_dir = Path.home()
        common_locations = [
            home_dir / 'Documents' / 'Claude',
            home_dir / 'claude-backups',
            home_dir / 'Downloads' / 'claude-backups',
            home_dir / 'Desktop' / 'claude-backups',
            Path('/opt/claude'),
            Path('/usr/local/claude')
        ]

        for location in common_locations:
            if location.exists() and (location / 'agents').exists():
                self._project_root = location
                return self._project_root

        # If still not found, use the directory containing this script
        self._project_root = script_path.parent
        logger.warning(f"Could not detect project root, using: {self._project_root}")
        return self._project_root

    def get_user_home(self) -> Path:
        """Get current user's home directory"""
        return Path.home()

    def get_agents_dir(self) -> Path:
        """Get agents directory"""
        return self.get_project_root() / 'agents'

    def get_database_dir(self) -> Path:
        """Get database directory"""
        return self.get_project_root() / 'database'

    def get_config_dir(self) -> Path:
        """Get config directory"""
        return self.get_project_root() / 'config'

    def get_tools_dir(self) -> Path:
        """Get tools directory"""
        return self.get_project_root() / 'tools'

    def get_scripts_dir(self) -> Path:
        """Get scripts directory"""
        return self.get_project_root() / 'scripts'

    def get_docs_dir(self) -> Path:
        """Get docs directory"""
        return self.get_project_root() / 'docs'

    def get_python_src_dir(self) -> Path:
        """Get Python source directory"""
        return self.get_agents_dir() / 'src' / 'python'

    def get_c_src_dir(self) -> Path:
        """Get C source directory"""
        return self.get_agents_dir() / 'src' / 'c'

    def get_orchestration_dir(self) -> Path:
        """Get orchestration directory"""
        return self.get_project_root() / 'orchestration'

    def resolve_relative_path(self, relative_path: Union[str, Path]) -> Path:
        """Resolve a relative path from project root"""
        return self.get_project_root() / relative_path

    def get_env_path(self, env_var: str, default_relative: Union[str, Path]) -> Path:
        """Get path from environment variable or default relative to project root"""
        env_value = os.environ.get(env_var)
        if env_value:
            return Path(env_value)
        return self.resolve_relative_path(default_relative)

    def ensure_path_exists(self, path: Path, create_if_missing: bool = False) -> bool:
        """Ensure path exists, optionally create if missing"""
        if path.exists():
            return True

        if create_if_missing:
            try:
                path.mkdir(parents=True, exist_ok=True)
                return True
            except Exception as e:
                logger.error(f"Failed to create path {path}: {e}")
                return False

        return False

    def get_database_config(self) -> Dict[str, Union[str, int]]:
        """Get database configuration with environment variable support"""
        return {
            'host': os.environ.get('DB_HOST', 'localhost'),
            'port': int(os.environ.get('DB_PORT', 5433)),
            'database': os.environ.get('DB_NAME', 'claude_agents_auth'),
            'user': os.environ.get('DB_USER', 'claude_agent'),
            'password': os.environ.get('DB_PASSWORD', 'claude_auth_pass')
        }

    def get_shadowgit_paths(self) -> Dict[str, Path]:
        """Get Shadowgit related paths"""
        shadowgit_root = Path(os.environ.get('SHADOWGIT_ROOT',
                                           self.get_user_home() / 'shadowgit'))

        return {
            'root': shadowgit_root,
            'python_module': shadowgit_root / 'shadowgit_avx2.py',
            'c_src': shadowgit_root / 'c_src_avx2',
            'binary': shadowgit_root / 'c_src_avx2' / 'shadowgit_avx2'
        }

    def add_python_paths(self) -> None:
        """Add common Python paths to sys.path"""
        paths_to_add = [
            str(self.get_project_root()),
            str(self.get_python_src_dir()),
            str(self.get_agents_dir()),
            str(self.get_tools_dir())
        ]

        # Add Shadowgit path if available
        shadowgit_paths = self.get_shadowgit_paths()
        if shadowgit_paths['root'].exists():
            paths_to_add.append(str(shadowgit_paths['root']))

        for path in paths_to_add:
            if path not in sys.path:
                sys.path.insert(0, path)

    def get_temp_dir(self) -> Path:
        """Get temporary directory for the project"""
        temp_base = Path(os.environ.get('TMPDIR', '/tmp'))
        project_temp = temp_base / f'claude-{os.getuid()}'
        self.ensure_path_exists(project_temp, create_if_missing=True)
        return project_temp

    def validate_installation(self) -> Dict[str, bool]:
        """Validate the installation by checking key paths"""
        project_root = self.get_project_root()

        checks = {
            'project_root_exists': project_root.exists(),
            'agents_dir_exists': self.get_agents_dir().exists(),
            'database_dir_exists': self.get_database_dir().exists(),
            'python_src_exists': self.get_python_src_dir().exists(),
            'claude_md_exists': (project_root / 'CLAUDE.md').exists(),
            'config_dir_exists': self.get_config_dir().exists()
        }

        return checks


# Global instance for convenience
path_resolver = PathResolver()

# Convenience functions
def get_project_root() -> Path:
    """Get project root directory"""
    return path_resolver.get_project_root()

def get_agents_dir() -> Path:
    """Get agents directory"""
    return path_resolver.get_agents_dir()

def get_database_dir() -> Path:
    """Get database directory"""
    return path_resolver.get_database_dir()

def get_python_src_dir() -> Path:
    """Get Python source directory"""
    return path_resolver.get_python_src_dir()

def add_python_paths() -> None:
    """Add common Python paths to sys.path"""
    path_resolver.add_python_paths()

def get_database_config() -> Dict[str, Union[str, int]]:
    """Get database configuration"""
    return path_resolver.get_database_config()

def resolve_path(relative_path: Union[str, Path]) -> Path:
    """Resolve relative path from project root"""
    return path_resolver.resolve_relative_path(relative_path)

def get_shadowgit_paths() -> Dict[str, Path]:
    """Get Shadowgit paths"""
    return path_resolver.get_shadowgit_paths()


if __name__ == "__main__":
    # Test the path resolver
    print("Claude Agent Framework Path Resolver Test")
    print("=" * 50)

    resolver = PathResolver()

    print(f"Project Root: {resolver.get_project_root()}")
    print(f"Agents Dir: {resolver.get_agents_dir()}")
    print(f"Database Dir: {resolver.get_database_dir()}")
    print(f"Python Src: {resolver.get_python_src_dir()}")
    print(f"Config Dir: {resolver.get_config_dir()}")
    print(f"Tools Dir: {resolver.get_tools_dir()}")

    print("\nDatabase Configuration:")
    db_config = resolver.get_database_config()
    for key, value in db_config.items():
        if key == 'password':
            value = '*' * len(str(value))
        print(f"  {key}: {value}")

    print("\nShadowgit Paths:")
    shadowgit_paths = resolver.get_shadowgit_paths()
    for key, path in shadowgit_paths.items():
        print(f"  {key}: {path}")

    print("\nInstallation Validation:")
    validation = resolver.validate_installation()
    for check, passed in validation.items():
        status = "✓" if passed else "✗"
        print(f"  {status} {check}: {passed}")