#!/usr/bin/env python3
"""
Claude Installer Configuration Module
Handles advanced configuration, validation, and integration scenarios
"""

import json
import os
import platform
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class InstallationConfig:
    """Configuration for Claude installation"""

    # Installation preferences
    preferred_method: str = "npm"  # npm, pip, system, manual
    use_system_packages: bool = False
    create_virtual_env: bool = True
    install_agents: bool = True
    install_database: bool = True
    install_learning_system: bool = True

    # Path configurations
    custom_install_path: Optional[str] = None
    custom_config_path: Optional[str] = None
    custom_agents_path: Optional[str] = None

    # Shell and environment
    shell_integration: bool = True
    completion_setup: bool = True
    add_to_path: bool = True

    # Advanced options
    force_reinstall: bool = False
    skip_validation: bool = False
    enable_debug_logging: bool = False

    # Platform-specific settings
    zsh_compatibility_mode: bool = False
    use_homebrew_on_mac: bool = True
    use_snap_on_linux: bool = False

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization"""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "InstallationConfig":
        """Create from dictionary"""
        return cls(**data)

    def save_to_file(self, path: Path) -> None:
        """Save configuration to file"""
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w") as f:
            json.dump(self.to_dict(), f, indent=2)

    @classmethod
    def load_from_file(cls, path: Path) -> "InstallationConfig":
        """Load configuration from file"""
        if not path.exists():
            return cls()  # Return default config

        try:
            with path.open("r") as f:
                data = json.load(f)
            return cls.from_dict(data)
        except (json.JSONDecodeError, TypeError):
            return cls()  # Return default config on error


class ClaudeEnvironmentValidator:
    """Validates and prepares the environment for Claude installation"""

    def __init__(self, config: InstallationConfig):
        self.config = config
        self.validation_results = {}

    def validate_system_requirements(self) -> Tuple[bool, List[str]]:
        """Validate system requirements for Claude installation"""
        issues = []
        system_ok = True

        # Check Python version
        python_version = sys.version_info
        if python_version < (3, 8):
            issues.append(
                f"Python 3.8+ required, found {python_version.major}.{python_version.minor}"
            )
            system_ok = False

        # Check available disk space
        try:
            disk_usage = os.statvfs(Path.home())
            free_space_gb = (disk_usage.f_frsize * disk_usage.f_bavail) / (1024**3)
            if free_space_gb < 1.0:  # Require at least 1GB free
                issues.append(
                    f"Insufficient disk space: {free_space_gb:.1f}GB available, 1GB required"
                )
                system_ok = False
        except:
            issues.append("Could not check disk space")

        # Check internet connectivity
        if not self._check_internet_connectivity():
            issues.append("No internet connectivity detected")
            system_ok = False

        # Platform-specific checks
        platform_issues = self._validate_platform_specific()
        issues.extend(platform_issues)
        if platform_issues:
            system_ok = False

        self.validation_results["system_requirements"] = {
            "passed": system_ok,
            "issues": issues,
        }

        return system_ok, issues

    def _check_internet_connectivity(self) -> bool:
        """Check if internet connectivity is available"""
        test_hosts = [
            "8.8.8.8",  # Google DNS
            "1.1.1.1",  # Cloudflare DNS
        ]

        for host in test_hosts:
            try:
                subprocess.run(
                    ["ping", "-c", "1", "-W", "3", host], capture_output=True, timeout=5
                )
                return True
            except:
                continue

        return False

    def _validate_platform_specific(self) -> List[str]:
        """Platform-specific validation"""
        issues = []
        system = platform.system().lower()

        if system == "darwin":  # macOS
            issues.extend(self._validate_macos())
        elif system == "linux":
            issues.extend(self._validate_linux())
        elif system == "windows":
            issues.extend(self._validate_windows())

        return issues

    def _validate_macos(self) -> List[str]:
        """macOS-specific validation"""
        issues = []

        # Check for Xcode command line tools
        try:
            subprocess.run(
                ["xcode-select", "--print-path"], capture_output=True, check=True
            )
        except:
            issues.append("Xcode command line tools not installed")

        # Check Homebrew if configured to use it
        if self.config.use_homebrew_on_mac:
            if not self._command_exists("brew"):
                issues.append("Homebrew not installed but configured to use it")

        return issues

    def _validate_linux(self) -> List[str]:
        """Linux-specific validation"""
        issues = []

        # Check for essential build tools
        essential_tools = ["gcc", "g++", "make"]
        missing_tools = [
            tool for tool in essential_tools if not self._command_exists(tool)
        ]

        if missing_tools:
            issues.append(f"Missing build tools: {', '.join(missing_tools)}")

        # Check package manager
        package_managers = ["apt", "yum", "dnf", "pacman", "zypper"]
        if not any(self._command_exists(pm) for pm in package_managers):
            issues.append("No supported package manager found")

        return issues

    def _validate_windows(self) -> List[str]:
        """Windows-specific validation (WSL support)"""
        issues = []

        # Check if running under WSL
        try:
            with open("/proc/version", "r") as f:
                if "microsoft" not in f.read().lower():
                    issues.append("Windows installation requires WSL")
        except:
            # Probably not WSL
            issues.append("Windows installation requires WSL")

        return issues

    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH"""
        try:
            subprocess.run(["which", command], capture_output=True, check=True)
            return True
        except:
            return False

    def validate_installation_paths(self) -> Tuple[bool, List[str]]:
        """Validate installation paths and permissions"""
        issues = []
        paths_ok = True

        # Check target directories
        target_dirs = [
            Path.home() / ".local" / "bin",
            Path.home() / ".config" / "claude",
            Path.home() / ".local" / "share" / "claude",
        ]

        if self.config.custom_install_path:
            target_dirs.append(Path(self.config.custom_install_path))

        for directory in target_dirs:
            try:
                directory.mkdir(parents=True, exist_ok=True)
                # Test write permission
                test_file = directory / ".test_write"
                test_file.touch()
                test_file.unlink()
            except PermissionError:
                issues.append(f"No write permission for {directory}")
                paths_ok = False
            except Exception as e:
                issues.append(f"Cannot access {directory}: {e}")
                paths_ok = False

        self.validation_results["installation_paths"] = {
            "passed": paths_ok,
            "issues": issues,
        }

        return paths_ok, issues

    def validate_dependencies(self) -> Tuple[bool, List[str]]:
        """Validate required dependencies"""
        issues = []
        deps_ok = True

        # Check Node.js if npm installation preferred
        if self.config.preferred_method == "npm":
            if not self._command_exists("node"):
                issues.append("Node.js not found (required for npm installation)")
                deps_ok = False
            else:
                # Check Node.js version
                try:
                    result = subprocess.run(
                        ["node", "--version"], capture_output=True, text=True
                    )
                    version_str = result.stdout.strip().lstrip("v")
                    major_version = int(version_str.split(".")[0])
                    if major_version < 16:
                        issues.append(f"Node.js 16+ required, found {version_str}")
                        deps_ok = False
                except:
                    issues.append("Could not determine Node.js version")
                    deps_ok = False

            if not self._command_exists("npm"):
                issues.append("npm not found (required for npm installation)")
                deps_ok = False

        # Check pip if pip installation preferred
        if self.config.preferred_method == "pip":
            if not (self._command_exists("pip") or self._command_exists("pip3")):
                issues.append("pip not found (required for pip installation)")
                deps_ok = False

        # Check Git (generally required)
        if not self._command_exists("git"):
            issues.append("git not found (required for full installation)")
            deps_ok = False

        # Check Docker if database installation requested
        if self.config.install_database:
            if not self._command_exists("docker"):
                issues.append("docker not found (required for database installation)")
                deps_ok = False

        self.validation_results["dependencies"] = {"passed": deps_ok, "issues": issues}

        return deps_ok, issues

    def prepare_environment(self) -> bool:
        """Prepare the environment for installation"""
        try:
            # Create necessary directories
            dirs_to_create = [
                Path.home() / ".local" / "bin",
                Path.home() / ".config" / "claude",
                Path.home() / ".local" / "share" / "claude" / "logs",
                Path.home() / ".local" / "share" / "claude" / "venv",
            ]

            for directory in dirs_to_create:
                directory.mkdir(parents=True, exist_ok=True)

            # Set up configuration file
            config_file = Path.home() / ".config" / "claude" / "installer_config.json"
            self.config.save_to_file(config_file)

            return True

        except Exception:
            return False

    def get_validation_report(self) -> Dict[str, Any]:
        """Get complete validation report"""
        return {
            "validation_results": self.validation_results,
            "system_info": {
                "platform": platform.system(),
                "architecture": platform.machine(),
                "python_version": sys.version,
                "home_directory": str(Path.home()),
                "current_directory": str(Path.cwd()),
            },
            "configuration": self.config.to_dict(),
        }


class ClaudeInstallationManager:
    """Manages Claude installation state and provides recovery mechanisms"""

    def __init__(self, config_dir: Optional[Path] = None):
        self.config_dir = config_dir or (Path.home() / ".config" / "claude")
        self.config_dir.mkdir(parents=True, exist_ok=True)

        self.state_file = self.config_dir / "installation_state.json"
        self.backup_dir = self.config_dir / "backups"
        self.backup_dir.mkdir(exist_ok=True)

    def save_installation_state(self, state: Dict[str, Any]) -> None:
        """Save current installation state"""
        state["timestamp"] = time.time()
        state["version"] = "2.0"

        with self.state_file.open("w") as f:
            json.dump(state, f, indent=2)

    def load_installation_state(self) -> Optional[Dict[str, Any]]:
        """Load installation state"""
        if not self.state_file.exists():
            return None

        try:
            with self.state_file.open("r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None

    def create_backup(self, name: str) -> Path:
        """Create backup of current configuration"""
        import time

        timestamp = int(time.time())
        backup_path = self.backup_dir / f"{name}_{timestamp}"
        backup_path.mkdir(exist_ok=True)

        # Backup important files
        files_to_backup = [
            Path.home() / ".bashrc",
            Path.home() / ".zshrc",
            Path.home() / ".profile",
            self.config_dir / "installer_config.json",
            self.state_file,
        ]

        for file_path in files_to_backup:
            if file_path.exists():
                backup_file = backup_path / file_path.name
                try:
                    import shutil

                    shutil.copy2(file_path, backup_file)
                except:
                    pass  # Continue with other files

        return backup_path

    def restore_from_backup(self, backup_path: Path) -> bool:
        """Restore configuration from backup"""
        try:
            if not backup_path.exists():
                return False

            # Restore files
            for backup_file in backup_path.iterdir():
                if backup_file.is_file():
                    if backup_file.name in [".bashrc", ".zshrc", ".profile"]:
                        target = Path.home() / backup_file.name
                    else:
                        target = self.config_dir / backup_file.name

                    import shutil

                    shutil.copy2(backup_file, target)

            return True

        except Exception:
            return False

    def cleanup_failed_installation(self) -> None:
        """Clean up after failed installation"""
        # Remove potentially broken wrapper scripts
        wrapper_paths = [
            Path.home() / ".local" / "bin" / "claude",
            Path.home() / ".local" / "bin" / "claude-enhanced",
        ]

        for wrapper_path in wrapper_paths:
            if wrapper_path.exists():
                try:
                    wrapper_path.unlink()
                except:
                    pass

        # Clear installation state
        if self.state_file.exists():
            try:
                self.state_file.unlink()
            except:
                pass


def create_default_config() -> InstallationConfig:
    """Create default configuration based on system detection"""
    config = InstallationConfig()

    # Detect system preferences
    system = platform.system().lower()

    if system == "darwin":  # macOS
        config.use_homebrew_on_mac = True
        config.preferred_method = "npm"  # Homebrew typically has good Node.js
    elif system == "linux":
        # Check for common package managers
        if subprocess.run(["which", "snap"], capture_output=True).returncode == 0:
            config.use_snap_on_linux = True

        # Prefer npm if Node.js is available
        if subprocess.run(["which", "node"], capture_output=True).returncode == 0:
            config.preferred_method = "npm"
        else:
            config.preferred_method = "pip"

    # Check for ZSH
    shell = os.environ.get("SHELL", "")
    if "zsh" in shell:
        config.zsh_compatibility_mode = True

    return config


if __name__ == "__main__":
    # Example usage and testing
    config = create_default_config()
    validator = ClaudeEnvironmentValidator(config)

    print("System Requirements:", validator.validate_system_requirements())
    print("Installation Paths:", validator.validate_installation_paths())
    print("Dependencies:", validator.validate_dependencies())

    print("\nValidation Report:")
    import pprint

    pprint.pprint(validator.get_validation_report())
