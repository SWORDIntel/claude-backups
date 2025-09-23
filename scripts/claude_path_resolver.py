#!/usr/bin/env python3
"""
CLAUDE PATH RESOLVER v1.0 - UNIVERSAL PORTABLE PATH MANAGEMENT

Provides dynamic path resolution for the entire claude-backups system
Eliminates ALL hardcoded paths for true cross-platform portability
"""

import os
import sys
import pwd
import pathlib
from pathlib import Path
from typing import Optional, List, Dict


class ClaudePathResolver:
    """Centralized path resolution for claude-backups system"""

    def __init__(self):
        self.paths = {}
        self._initialize_paths()

    def _initialize_paths(self):
        """Initialize all Claude paths dynamically"""
        # Core paths
        self.paths['user_home'] = self._detect_user_home()
        self.paths['project_root'] = self._detect_project_root()

        # System paths
        self._detect_system_paths()
        self._detect_config_paths()
        self._detect_optional_system_paths()

        # Project structure paths
        self._setup_project_paths()

        # Ensure critical directories exist
        self._ensure_directories()

    def _detect_user_home(self) -> Path:
        """Detect user home directory using multiple methods"""
        methods = [
            lambda: Path(os.environ.get('HOME', '')),
            lambda: Path(pwd.getpwuid(os.getuid()).pw_dir),
            lambda: Path.home(),
            lambda: Path(f'/home/{os.getenv("USER", os.getenv("USERNAME", ""))}')
        ]

        for method in methods:
            try:
                home = method()
                if home.exists() and home.is_dir():
                    return home
            except (KeyError, OSError, AttributeError):
                continue

        # Emergency fallback
        return Path('/tmp')

    def _detect_project_root(self) -> Path:
        """Detect project root using multiple strategies"""
        # Get script directory for relative detection
        script_path = Path(__file__).resolve()
        script_dir = script_path.parent

        potential_roots = [
            # Script-relative detection (highest priority)
            script_dir.parent,
            script_dir.parent.parent,

            # Environment variable override
            Path(os.environ.get('CLAUDE_PROJECT_ROOT', '')),

            # Current working directory
            Path.cwd(),

            # Common installation locations
            self.paths['user_home'] / 'claude-backups',
            self.paths['user_home'] / 'Downloads' / 'claude-backups',
            self.paths['user_home'] / 'Documents' / 'claude-backups',
            self.paths['user_home'] / 'projects' / 'claude-backups',
            self.paths['user_home'] / 'src' / 'claude-backups',

            # System-wide locations
            Path('/opt/claude-backups'),
            Path('/usr/local/claude-backups'),
        ]

        for root in potential_roots:
            if not root or not isinstance(root, Path):
                continue

            try:
                root = root.resolve()
                # Validate by checking for key indicator files
                indicators = ['CLAUDE.md', 'claude-enhanced-installer.py', 'agents']
                if any((root / indicator).exists() for indicator in indicators):
                    return root
            except (OSError, AttributeError):
                continue

        # Ultimate fallback
        return self.paths['user_home']

    def _detect_system_paths(self):
        """Detect appropriate system paths based on OS and permissions"""
        user_writable_bins = [
            self.paths['user_home'] / '.local' / 'bin',
            self.paths['user_home'] / 'bin',
        ]

        system_bins = [
            Path('/usr/local/bin'),
            Path('/usr/bin'),
            Path('/bin'),
        ]

        # Find first writable user bin
        self.paths['user_bin'] = None
        for bin_path in user_writable_bins:
            try:
                bin_path.mkdir(parents=True, exist_ok=True)
                if os.access(bin_path, os.W_OK):
                    self.paths['user_bin'] = bin_path
                    break
            except (OSError, PermissionError):
                continue

        # Set default user bin if none found
        if not self.paths['user_bin']:
            self.paths['user_bin'] = self.paths['user_home'] / '.local' / 'bin'

        # Find first writable system bin (if we have permissions)
        self.paths['system_bin'] = None
        for bin_path in system_bins:
            try:
                if os.access(bin_path, os.W_OK):
                    self.paths['system_bin'] = bin_path
                    break
            except (OSError, PermissionError):
                continue

    def _detect_config_paths(self):
        """Setup XDG Base Directory Specification compliant paths"""
        # XDG paths
        xdg_config = Path(os.environ.get('XDG_CONFIG_HOME', self.paths['user_home'] / '.config'))
        xdg_data = Path(os.environ.get('XDG_DATA_HOME', self.paths['user_home'] / '.local' / 'share'))
        xdg_cache = Path(os.environ.get('XDG_CACHE_HOME', self.paths['user_home'] / '.cache'))
        xdg_state = Path(os.environ.get('XDG_STATE_HOME', self.paths['user_home'] / '.local' / 'state'))

        # Claude-specific paths
        self.paths['config_dir'] = xdg_config / 'claude'
        self.paths['data_dir'] = xdg_data / 'claude'
        self.paths['cache_dir'] = xdg_cache / 'claude'
        self.paths['state_dir'] = xdg_state / 'claude'
        self.paths['log_dir'] = self.paths['state_dir'] / 'logs'

    def _detect_optional_system_paths(self):
        """Detect optional system paths that may or may not exist"""
        # OpenVINO detection
        openvino_locations = [
            Path('/opt/openvino'),
            Path('/usr/local/openvino'),
            self.paths['user_home'] / 'openvino',
            self.paths['user_home'] / '.local' / 'openvino',
        ]

        self.paths['openvino_root'] = None
        for location in openvino_locations:
            if location.exists() and location.is_dir():
                self.paths['openvino_root'] = location
                break

    def _setup_project_paths(self):
        """Setup project structure paths"""
        project_root = self.paths['project_root']

        self.paths['agents_dir'] = project_root / 'agents'
        self.paths['scripts_dir'] = project_root / 'scripts'
        self.paths['tools_dir'] = project_root / 'tools'
        self.paths['database_dir'] = project_root / 'database'
        self.paths['docs_dir'] = project_root / 'docs'
        self.paths['hooks_dir'] = project_root / 'hooks'

        # Python-specific paths
        self.paths['python_dir'] = self.paths['agents_dir'] / 'src' / 'python'
        self.paths['python_config'] = self.paths['python_dir'] / 'config'

        # Docker and database paths
        self.paths['docker_dir'] = self.paths['database_dir'] / 'docker'
        self.paths['learning_dir'] = project_root / 'learning'

    def _ensure_directories(self):
        """Ensure critical directories exist"""
        critical_dirs = [
            'config_dir', 'data_dir', 'cache_dir', 'state_dir', 'log_dir', 'user_bin'
        ]

        for dir_key in critical_dirs:
            if dir_key in self.paths and self.paths[dir_key]:
                try:
                    self.paths[dir_key].mkdir(parents=True, exist_ok=True)
                except (OSError, PermissionError):
                    pass  # Continue if we can't create the directory

        # Create convenience symlink
        claude_link = self.paths['user_home'] / '.claude'
        if not claude_link.exists():
            try:
                claude_link.symlink_to(self.paths['config_dir'])
            except (OSError, PermissionError):
                pass

    def get_path(self, key: str) -> Optional[Path]:
        """Get a specific path by key"""
        return self.paths.get(key)

    def get_all_paths(self) -> Dict[str, Path]:
        """Get all resolved paths"""
        return self.paths.copy()

    def export_env_vars(self) -> Dict[str, str]:
        """Export paths as environment variables"""
        env_vars = {}
        path_mapping = {
            'CLAUDE_USER_HOME': 'user_home',
            'CLAUDE_PROJECT_ROOT': 'project_root',
            'CLAUDE_USER_BIN': 'user_bin',
            'CLAUDE_SYSTEM_BIN': 'system_bin',
            'CLAUDE_CONFIG_DIR': 'config_dir',
            'CLAUDE_DATA_DIR': 'data_dir',
            'CLAUDE_CACHE_DIR': 'cache_dir',
            'CLAUDE_STATE_DIR': 'state_dir',
            'CLAUDE_LOG_DIR': 'log_dir',
            'CLAUDE_AGENTS_DIR': 'agents_dir',
            'CLAUDE_SCRIPTS_DIR': 'scripts_dir',
            'CLAUDE_TOOLS_DIR': 'tools_dir',
            'CLAUDE_DATABASE_DIR': 'database_dir',
            'CLAUDE_DOCS_DIR': 'docs_dir',
            'CLAUDE_HOOKS_DIR': 'hooks_dir',
            'CLAUDE_PYTHON_DIR': 'python_dir',
            'CLAUDE_PYTHON_CONFIG': 'python_config',
            'CLAUDE_DOCKER_DIR': 'docker_dir',
            'CLAUDE_LEARNING_DIR': 'learning_dir',
            'OPENVINO_ROOT': 'openvino_root',
        }

        for env_var, path_key in path_mapping.items():
            path_value = self.paths.get(path_key)
            if path_value:
                env_vars[env_var] = str(path_value)

        return env_vars

    def apply_to_environment(self):
        """Apply all paths to current environment"""
        env_vars = self.export_env_vars()
        for var, value in env_vars.items():
            os.environ[var] = value

    def status_report(self) -> str:
        """Generate a status report of all paths"""
        lines = [
            "═" * 79,
            "CLAUDE PATH RESOLVER STATUS",
            "═" * 79,
        ]

        important_paths = [
            ('User Home', 'user_home'),
            ('Project Root', 'project_root'),
            ('User Bin', 'user_bin'),
            ('System Bin', 'system_bin'),
            ('Config Dir', 'config_dir'),
            ('Data Dir', 'data_dir'),
            ('Cache Dir', 'cache_dir'),
            ('Log Dir', 'log_dir'),
            ('Agents Dir', 'agents_dir'),
            ('Python Dir', 'python_dir'),
            ('Docker Dir', 'docker_dir'),
            ('OpenVINO Root', 'openvino_root'),
        ]

        for label, key in important_paths:
            value = self.paths.get(key)
            if value:
                lines.append(f"{label:<15}: {value}")
            else:
                lines.append(f"{label:<15}: <not found>")

        lines.append("═" * 79)
        return "\n".join(lines)


# Global instance for easy access
_resolver = None

def get_resolver() -> ClaudePathResolver:
    """Get the global path resolver instance"""
    global _resolver
    if _resolver is None:
        _resolver = ClaudePathResolver()
    return _resolver

def get_path(key: str) -> Optional[Path]:
    """Convenience function to get a path"""
    return get_resolver().get_path(key)

def apply_to_environment():
    """Convenience function to apply paths to environment"""
    get_resolver().apply_to_environment()

def status_report() -> str:
    """Convenience function to get status report"""
    return get_resolver().status_report()


if __name__ == '__main__':
    # Command line interface
    import argparse

    parser = argparse.ArgumentParser(description='Claude Path Resolver v1.0')
    parser.add_argument('command', nargs='?', default='status',
                       choices=['status', 'export', 'env', 'test'],
                       help='Command to execute')

    args = parser.parse_args()

    resolver = get_resolver()

    if args.command == 'status':
        print(resolver.status_report())
    elif args.command == 'export':
        env_vars = resolver.export_env_vars()
        for var, value in env_vars.items():
            print(f'export {var}="{value}"')
    elif args.command == 'env':
        resolver.apply_to_environment()
        print("Environment variables applied to current process")
    elif args.command == 'test':
        # Test all paths
        resolver.apply_to_environment()
        print("Testing path resolution...")
        print(resolver.status_report())

        # Test some path access
        print("\nTesting path access:")
        test_paths = ['project_root', 'user_home', 'config_dir', 'python_dir']
        for path_key in test_paths:
            path = resolver.get_path(path_key)
            exists = path.exists() if path else False
            print(f"  {path_key}: {path} ({'exists' if exists else 'missing'})")