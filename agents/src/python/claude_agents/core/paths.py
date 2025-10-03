"""
Centralized path resolution for Claude agent system
Provides XDG-compliant directory structure and auto-detection
"""

import os
from pathlib import Path


class ClaudePaths:
    """Centralized path resolution for all Claude modules"""

    def __init__(self):
        # Auto-detect project root
        self.project_root = Path(os.environ.get(
            'CLAUDE_PROJECT_ROOT',
            Path(__file__).parent.parent.parent.parent.parent
        ))

        self.agents_root = Path(os.environ.get(
            'CLAUDE_AGENTS_ROOT',
            self.project_root / 'agents'
        ))

        # XDG-compliant data directories
        xdg_data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
        self.data_home = Path(os.environ.get('CLAUDE_DATA_HOME', xdg_data / 'claude'))

        xdg_config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
        self.config_home = Path(os.environ.get('CLAUDE_CONFIG_HOME', xdg_config / 'claude'))

        xdg_state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
        self.state_home = Path(os.environ.get('CLAUDE_STATE_HOME', xdg_state / 'claude'))

        xdg_cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache'))
        self.cache_home = Path(os.environ.get('CLAUDE_CACHE_HOME', xdg_cache / 'claude'))

        # Ensure directories exist
        for dir_path in [self.data_home, self.config_home, self.state_home, self.cache_home]:
            dir_path.mkdir(parents=True, exist_ok=True)

    # Security executor paths
    @property
    def ghidra_scripts(self):
        path = self.data_home / 'ghidra-workspace/scripts'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def analysis_workspace(self):
        path = self.data_home / 'ghidra-workspace'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def hostile_samples(self):
        path = self.data_home / 'hostile-samples'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def quarantine(self):
        path = self.data_home / 'quarantine'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def reports(self):
        path = self.data_home / 'analysis-reports'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def yara_rules(self):
        path = self.config_home / 'yara-rules'
        path.mkdir(parents=True, exist_ok=True)
        return path

    # Module paths
    @property
    def npu_bridge(self):
        return self.agents_root / 'src/rust/npu_coordination_bridge'

    @property
    def shadowgit(self):
        # Try multiple locations
        locations = [
            self.project_root / 'hooks/shadowgit',
            self.project_root / 'tests/shadowgit',
        ]
        for loc in locations:
            if loc.exists():
                return loc
        return self.project_root / 'tests/shadowgit'

    @property
    def git_tests(self):
        return self.project_root / 'tests/shadowgit'

    @property
    def venv_path(self):
        path = self.data_home / 'datascience'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def c_toolchain(self):
        path = self.data_home / 'c-toolchain'
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def obsidian_vault(self):
        return Path.home() / 'Documents/Obsidian/DataScience'


# Global instance
paths = ClaudePaths()
