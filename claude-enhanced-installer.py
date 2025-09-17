#!/usr/bin/env python3
"""
Claude Enhanced Installer v2.0
Python-based installer system with robust error handling and cross-platform support
"""

import argparse
import json
import os
import pathlib
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import re
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union


class InstallationMode(Enum):
    QUICK = "quick"
    FULL = "full"
    CUSTOM = "custom"


class ShellType(Enum):
    BASH = "bash"
    ZSH = "zsh"
    FISH = "fish"
    CSH = "csh"
    TCSH = "tcsh"
    DASH = "dash"
    UNKNOWN = "unknown"


@dataclass
class ClaudeInstallation:
    """Represents a detected Claude installation"""
    binary_path: Path
    version: Optional[str]
    installation_type: str  # npm, pip, system, manual
    working: bool
    details: Dict[str, any]


class EnvironmentType(Enum):
    HEADLESS = "headless"
    KDE = "kde"
    GNOME = "gnome"
    XFCE = "xfce"
    WAYLAND = "wayland"
    X11 = "x11"
    UNKNOWN_GUI = "unknown_gui"

@dataclass
class SystemInfo:
    """System information for installation decisions"""
    platform: str
    architecture: str
    shell: ShellType
    shell_config_files: List[Path]
    python_version: str
    node_version: Optional[str]
    npm_available: bool
    pip_available: bool
    has_sudo: bool
    home_dir: Path
    user_name: str
    environment_type: EnvironmentType
    display_server: Optional[str]
    desktop_session: Optional[str]
    has_systemd: bool


class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    MAGENTA = '\033[0;35m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'


class ClaudeEnhancedInstaller:
    """Enhanced Python-based Claude installer with robust error handling"""

    def __init__(self, verbose: bool = False, auto_mode: bool = False):
        self.verbose = verbose
        self.auto_mode = auto_mode
        self.project_root = self._detect_project_root()
        self.system_info = self._gather_system_info()
        self.installation_log = []
        self.current_step = 0
        self.total_steps = 0

        # Installation paths
        self.local_bin = self.system_info.home_dir / ".local" / "bin"
        self.config_dir = self.system_info.home_dir / ".config" / "claude"
        self.venv_dir = self.system_info.home_dir / ".local" / "share" / "claude" / "venv"
        self.log_dir = self.system_info.home_dir / ".local" / "share" / "claude" / "logs"

        # Create necessary directories
        for directory in [self.local_bin, self.config_dir, self.log_dir]:
            directory.mkdir(parents=True, exist_ok=True)

    def _detect_project_root(self) -> Path:
        """Detect the Claude project root directory using dynamic resolution"""
        # Check script directory first (where installer is located)
        script_dir = Path(__file__).parent.resolve()
        if (script_dir / "agents").exists() and (script_dir / "CLAUDE.md").exists():
            return script_dir

        # Check current working directory
        current = Path.cwd().resolve()
        if (current / "agents").exists() and (current / "CLAUDE.md").exists():
            return current

        # Check environment variable if set
        if "CLAUDE_PROJECT_ROOT" in os.environ:
            env_root = Path(os.environ["CLAUDE_PROJECT_ROOT"]).resolve()
            if env_root.exists() and (env_root / "agents").exists():
                return env_root

        # Search common locations dynamically (avoid hardcoded paths)
        home_dir = Path.home()
        search_patterns = [
            "*/claude-backups",
            "*/Claude",
            "*/Documents/Claude",
            "*/Downloads/claude-backups",
            "claude-backups",
            "Claude"
        ]

        for pattern in search_patterns:
            for location in home_dir.glob(pattern):
                if location.is_dir() and (location / "agents").exists() and (location / "CLAUDE.md").exists():
                    return location.resolve()

        # Try to find based on git repository
        try:
            git_result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                cwd=current,
                capture_output=True,
                text=True,
                timeout=5
            )
            if git_result.returncode == 0:
                git_root = Path(git_result.stdout.strip()).resolve()
                if (git_root / "agents").exists() and (git_root / "CLAUDE.md").exists():
                    return git_root
        except:
            pass

        # Default to current directory if nothing found
        return current

    def _gather_system_info(self) -> SystemInfo:
        """Gather comprehensive system information"""
        shell_type, shell_configs = self._detect_shell()
        env_type, display_server, desktop_session = self._detect_environment()

        return SystemInfo(
            platform=platform.system().lower(),
            architecture=platform.machine(),
            shell=shell_type,
            shell_config_files=shell_configs,
            python_version=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            node_version=self._get_node_version(),
            npm_available=shutil.which("npm") is not None,
            pip_available=shutil.which("pip") is not None or shutil.which("pip3") is not None,
            has_sudo=self._check_sudo_available(),
            home_dir=Path.home(),
            user_name=os.environ.get("USER", "unknown"),
            environment_type=env_type,
            display_server=display_server,
            desktop_session=desktop_session,
            has_systemd=self._check_systemd_available()
        )

    def _show_progress(self, message: str, step: Optional[int] = None) -> None:
        """Show progress with step counter and progress bar"""
        if step is not None:
            self.current_step = step
        else:
            self.current_step += 1

        if self.total_steps > 0:
            progress = int((self.current_step / self.total_steps) * 50)
            bar = "█" * progress + "░" * (50 - progress)
            percentage = int((self.current_step / self.total_steps) * 100)
            print(f"\r{Colors.CYAN}[{bar}] {percentage:3d}% {Colors.RESET}{message}", end="", flush=True)
            if self.current_step >= self.total_steps:
                print()  # New line when complete
        else:
            print(f"{Colors.CYAN}⚙ {Colors.RESET}{message}")

    def _set_total_steps(self, total: int) -> None:
        """Set total number of steps for progress tracking"""
        self.total_steps = total
        self.current_step = 0

    def _detect_shell(self) -> Tuple[ShellType, List[Path]]:
        """Detect current shell and configuration files"""
        shell_path = os.environ.get("SHELL", "")

        # Detect shell type
        if "zsh" in shell_path:
            shell_type = ShellType.ZSH
            configs = [
                Path.home() / ".zshrc",
                Path.home() / ".zprofile",
                Path.home() / ".profile"
            ]
        elif "bash" in shell_path:
            shell_type = ShellType.BASH
            configs = [
                Path.home() / ".bashrc",
                Path.home() / ".bash_profile",
                Path.home() / ".profile"
            ]
        elif "fish" in shell_path:
            shell_type = ShellType.FISH
            configs = [
                Path.home() / ".config" / "fish" / "config.fish",
                Path.home() / ".profile"
            ]
        elif "csh" in shell_path:
            shell_type = ShellType.CSH
            configs = [Path.home() / ".cshrc"]
        elif "tcsh" in shell_path:
            shell_type = ShellType.TCSH
            configs = [Path.home() / ".tcshrc", Path.home() / ".cshrc"]
        else:
            # Try to detect from process
            try:
                result = subprocess.run(["ps", "-p", str(os.getpid()), "-o", "comm="],
                                      capture_output=True, text=True, timeout=5)
                process_name = result.stdout.strip().lstrip("-")

                if "zsh" in process_name:
                    shell_type = ShellType.ZSH
                    configs = [Path.home() / ".zshrc", Path.home() / ".zprofile", Path.home() / ".profile"]
                elif "bash" in process_name:
                    shell_type = ShellType.BASH
                    configs = [Path.home() / ".bashrc", Path.home() / ".bash_profile", Path.home() / ".profile"]
                else:
                    shell_type = ShellType.BASH  # Default fallback
                    configs = [Path.home() / ".bashrc", Path.home() / ".profile"]
            except:
                shell_type = ShellType.BASH  # Safe fallback
                configs = [Path.home() / ".bashrc", Path.home() / ".profile"]

        # Filter to existing files
        existing_configs = [config for config in configs if config.exists()]
        if not existing_configs and shell_type in [ShellType.ZSH, ShellType.BASH]:
            # Create default config file if none exist
            default_config = configs[0]
            default_config.touch()
            existing_configs = [default_config]

        return shell_type, existing_configs

    def _get_node_version(self) -> Optional[str]:
        """Get Node.js version if available"""
        try:
            result = subprocess.run(["node", "--version"], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return result.stdout.strip().lstrip("v")
        except:
            pass
        return None

    def _check_sudo_available(self) -> bool:
        """Check if sudo is available and functional"""
        if os.geteuid() == 0:
            return True

        try:
            result = subprocess.run(["sudo", "-n", "true"], capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False

    def _check_systemd_available(self) -> bool:
        """Check if systemd is available"""
        try:
            result = subprocess.run(["systemctl", "--version"], capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False

    def _detect_environment(self) -> Tuple[EnvironmentType, Optional[str], Optional[str]]:
        """Detect the current environment type (headless/KDE/GNOME/etc)"""

        # Check environment variables for display servers
        display = os.environ.get("DISPLAY")
        wayland_display = os.environ.get("WAYLAND_DISPLAY")
        xdg_session_type = os.environ.get("XDG_SESSION_TYPE", "").lower()
        desktop_session = os.environ.get("DESKTOP_SESSION", "").lower()
        xdg_current_desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
        gdmsession = os.environ.get("GDMSESSION", "").lower()

        # Determine display server
        display_server = None
        if wayland_display:
            display_server = "wayland"
        elif display:
            display_server = "x11"
        elif xdg_session_type in ["wayland", "x11"]:
            display_server = xdg_session_type

        # If no display server detected, likely headless
        if not display_server and not display and not wayland_display:
            # Double-check with additional methods
            if self._is_headless_environment():
                return EnvironmentType.HEADLESS, None, None

        # Detect desktop environment
        desktop_indicators = {
            EnvironmentType.KDE: ["kde", "plasma", "kwin", "kwallet"],
            EnvironmentType.GNOME: ["gnome", "ubuntu", "pop", "gdm"],
            EnvironmentType.XFCE: ["xfce", "xubuntu"],
        }

        # Check desktop session and current desktop
        session_info = f"{desktop_session} {xdg_current_desktop} {gdmsession}".lower()

        for env_type, indicators in desktop_indicators.items():
            if any(indicator in session_info for indicator in indicators):
                if display_server == "wayland":
                    return EnvironmentType.WAYLAND, display_server, desktop_session
                else:
                    return env_type, display_server, desktop_session

        # Check for running desktop processes
        desktop_processes = {
            EnvironmentType.KDE: ["plasmashell", "kwin", "kdeconnectd"],
            EnvironmentType.GNOME: ["gnome-shell", "gnome-session", "gsd-power"],
            EnvironmentType.XFCE: ["xfce4-session", "xfwm4", "xfce4-panel"],
        }

        for env_type, processes in desktop_processes.items():
            if self._check_processes_running(processes):
                return env_type, display_server, desktop_session

        # If we have a display server but couldn't identify desktop
        if display_server:
            if display_server == "wayland":
                return EnvironmentType.WAYLAND, display_server, desktop_session
            else:
                return EnvironmentType.X11, display_server, desktop_session

        # Default to headless if nothing else detected
        return EnvironmentType.HEADLESS, None, None

    def _is_headless_environment(self) -> bool:
        """Additional checks to confirm headless environment"""
        # Check if we're in a container
        if Path("/.dockerenv").exists():
            return True

        # Check for SSH connection
        if os.environ.get("SSH_CLIENT") or os.environ.get("SSH_TTY"):
            return True

        # Check if running on known cloud/VPS platforms
        cloud_indicators = [
            "/sys/devices/virtual/dmi/id/sys_vendor",
            "/sys/devices/virtual/dmi/id/product_name"
        ]

        for indicator_path in cloud_indicators:
            try:
                content = Path(indicator_path).read_text().strip().lower()
                if any(cloud in content for cloud in ["amazon", "google", "microsoft", "digitalocean", "linode", "vultr"]):
                    return True
            except:
                pass

        # Check if no graphics drivers are loaded
        try:
            result = subprocess.run(["lsmod"], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                gpu_modules = ["nvidia", "amdgpu", "radeon", "i915", "nouveau"]
                if not any(module in result.stdout for module in gpu_modules):
                    return True
        except:
            pass

        return False

    def _check_processes_running(self, process_names: List[str]) -> bool:
        """Check if any of the given processes are running"""
        try:
            result = subprocess.run(["pgrep", "-f", "|".join(process_names)],
                                  capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False

    def _run_command(self, cmd: List[str], shell: bool = False, check: bool = True,
                    timeout: int = 60, cwd: Optional[Path] = None) -> subprocess.CompletedProcess:
        """Run a command with comprehensive error handling"""
        if self.verbose:
            self._print_info(f"Running: {' '.join(cmd) if not shell else cmd[0]}")

        try:
            if shell and isinstance(cmd, list):
                cmd = ' '.join(shlex.quote(str(arg)) for arg in cmd)

            result = subprocess.run(
                cmd,
                shell=shell,
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=cwd,
                env={**os.environ, "PYTHONUNBUFFERED": "1"}
            )

            if self.verbose and result.stdout:
                self._print_dim(f"stdout: {result.stdout}")
            if self.verbose and result.stderr:
                self._print_dim(f"stderr: {result.stderr}")

            if check and result.returncode != 0:
                raise subprocess.CalledProcessError(result.returncode, cmd, result.stdout, result.stderr)

            return result

        except subprocess.TimeoutExpired:
            self._print_error(f"Command timed out after {timeout}s: {cmd}")
            raise
        except subprocess.CalledProcessError as e:
            self._print_error(f"Command failed with code {e.returncode}: {cmd}")
            if e.stderr:
                self._print_error(f"Error output: {e.stderr}")
            raise

    def detect_claude_installations(self) -> List[ClaudeInstallation]:
        """Detect all Claude installations on the system"""
        installations = []

        # Check npm global installation
        npm_installation = self._check_npm_claude()
        if npm_installation:
            installations.append(npm_installation)

        # Check pip installation
        pip_installation = self._check_pip_claude()
        if pip_installation:
            installations.append(pip_installation)

        # Check system PATH
        system_installation = self._check_system_claude()
        if system_installation:
            installations.append(system_installation)

        # Check manual installations
        manual_installations = self._check_manual_claude()
        installations.extend(manual_installations)

        return installations

    def _check_npm_claude(self) -> Optional[ClaudeInstallation]:
        """Check for npm-installed Claude"""
        try:
            # Check if npm package is installed globally
            result = self._run_command(["npm", "list", "-g", "@anthropic-ai/claude-code"], check=False)
            if result.returncode == 0:
                # Find the actual binary
                npm_prefix_result = self._run_command(["npm", "config", "get", "prefix"], check=False)
                if npm_prefix_result.returncode == 0:
                    npm_prefix = Path(npm_prefix_result.stdout.strip())
                    possible_paths = [
                        npm_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js",
                        npm_prefix / "bin" / "claude",
                        npm_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "bin" / "claude"
                    ]

                    for path in possible_paths:
                        if path.exists():
                            version = self._get_claude_version(path)
                            return ClaudeInstallation(
                                binary_path=path,
                                version=version,
                                installation_type="npm",
                                working=self._test_claude_binary(path),
                                details={"npm_prefix": str(npm_prefix)}
                            )
        except:
            pass
        return None

    def _check_pip_claude(self) -> Optional[ClaudeInstallation]:
        """Check for pip-installed Claude"""
        try:
            # Check if pip package is installed
            pip_cmd = "pip3" if shutil.which("pip3") else "pip"
            result = self._run_command([pip_cmd, "show", "claude-code"], check=False)
            if result.returncode == 0:
                # Try to find the binary
                possible_commands = ["claude", "claude-code"]
                for cmd in possible_commands:
                    claude_path = shutil.which(cmd)
                    if claude_path:
                        version = self._get_claude_version(Path(claude_path))
                        return ClaudeInstallation(
                            binary_path=Path(claude_path),
                            version=version,
                            installation_type="pip",
                            working=self._test_claude_binary(Path(claude_path)),
                            details={"pip_package": "claude-code"}
                        )
        except:
            pass
        return None

    def _check_system_claude(self) -> Optional[ClaudeInstallation]:
        """Check for system-installed Claude"""
        claude_path = shutil.which("claude")
        if claude_path:
            path = Path(claude_path)
            # Skip if this is npm or already detected
            if "node_modules" not in str(path):
                version = self._get_claude_version(path)
                return ClaudeInstallation(
                    binary_path=path,
                    version=version,
                    installation_type="system",
                    working=self._test_claude_binary(path),
                    details={"system_path": str(path)}
                )
        return None

    def _check_manual_claude(self) -> List[ClaudeInstallation]:
        """Check for manual Claude installations"""
        installations = []

        # Common manual installation locations
        search_paths = [
            self.system_info.home_dir / ".local" / "bin",
            self.system_info.home_dir / "bin",
            Path("/usr/local/bin"),
            self.project_root,
        ]

        for search_path in search_paths:
            if search_path.exists():
                for binary_name in ["claude", "claude-code", "claude.js", "cli.js"]:
                    potential_path = search_path / binary_name
                    if potential_path.exists() and potential_path.is_file():
                        # Avoid duplicates
                        if not any(inst.binary_path == potential_path for inst in installations):
                            version = self._get_claude_version(potential_path)
                            installations.append(ClaudeInstallation(
                                binary_path=potential_path,
                                version=version,
                                installation_type="manual",
                                working=self._test_claude_binary(potential_path),
                                details={"search_path": str(search_path)}
                            ))

        return installations

    def _get_claude_version(self, binary_path: Path) -> Optional[str]:
        """Get Claude version from binary"""
        try:
            if binary_path.suffix == ".js":
                result = self._run_command(["node", str(binary_path), "--version"], check=False, timeout=10)
            else:
                result = self._run_command([str(binary_path), "--version"], check=False, timeout=10)

            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        return None

    def _test_claude_binary(self, binary_path: Path) -> bool:
        """Test if Claude binary is working"""
        try:
            if binary_path.suffix == ".js":
                result = self._run_command(["node", str(binary_path), "--help"], check=False, timeout=10)
            else:
                result = self._run_command([str(binary_path), "--help"], check=False, timeout=10)

            return result.returncode == 0
        except:
            return False

    def _find_npm_claude_alternative(self) -> Optional[Path]:
        """Alternative method to find npm-installed Claude binary after successful npm install"""
        try:
            # Method 1: Check common npm global locations more thoroughly
            possible_locations = []

            # Try to get npm root and prefix
            try:
                npm_root_result = self._run_command(["npm", "root", "-g"], check=False, timeout=10)
                if npm_root_result.returncode == 0:
                    npm_root = Path(npm_root_result.stdout.strip())
                    possible_locations.extend([
                        npm_root / "@anthropic-ai" / "claude-code" / "cli.js",
                        npm_root / "@anthropic-ai" / "claude-code" / "bin" / "claude",
                        npm_root.parent / "bin" / "claude"
                    ])
            except:
                pass

            # Try npm prefix method
            try:
                npm_prefix_result = self._run_command(["npm", "config", "get", "prefix"], check=False, timeout=10)
                if npm_prefix_result.returncode == 0:
                    npm_prefix = Path(npm_prefix_result.stdout.strip())
                    possible_locations.extend([
                        npm_prefix / "bin" / "claude",
                        npm_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js",
                        npm_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "bin" / "claude"
                    ])
            except:
                pass

            # Method 2: Check user npm global prefix
            npm_global_prefix = self.system_info.home_dir / ".npm-global"
            if npm_global_prefix.exists():
                possible_locations.extend([
                    npm_global_prefix / "bin" / "claude",
                    npm_global_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js",
                    npm_global_prefix / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "bin" / "claude"
                ])

            # Method 3: Search PATH for claude binary and verify it's npm-installed
            claude_in_path = shutil.which("claude")
            if claude_in_path:
                claude_path = Path(claude_in_path)
                # Check if it's likely an npm installation
                if "node_modules" in str(claude_path) or "npm" in str(claude_path):
                    if self._test_claude_binary(claude_path):
                        possible_locations.append(claude_path)

            # Method 4: Check if binary was just installed and needs PATH refresh
            # Update PATH to include common npm bin directories
            current_path = os.environ.get("PATH", "")
            npm_bin_dirs = [
                str(self.system_info.home_dir / ".npm-global" / "bin"),
                "/usr/local/bin",
                str(Path("/usr/local/lib/node_modules/.bin")),
            ]

            for bin_dir in npm_bin_dirs:
                if bin_dir not in current_path:
                    os.environ["PATH"] = f"{bin_dir}:{current_path}"

            # Re-check which command after PATH update
            claude_in_path = shutil.which("claude")
            if claude_in_path:
                claude_path = Path(claude_in_path)
                possible_locations.append(claude_path)

            # Test all possible locations
            for location in possible_locations:
                if location and location.exists():
                    if self._test_claude_binary(location):
                        self._print_info(f"Found working npm binary at: {location}")
                        return location

            # Method 5: Last resort - check recently modified files in npm directories
            try:
                # Check for recently created claude executables
                import time
                current_time = time.time()
                recent_threshold = current_time - 300  # 5 minutes ago

                search_dirs = [
                    Path("/usr/local/bin"),
                    self.system_info.home_dir / ".npm-global" / "bin",
                    Path("/usr/local/lib/node_modules"),
                ]

                for search_dir in search_dirs:
                    if search_dir.exists():
                        for file_path in search_dir.rglob("claude*"):
                            if (file_path.is_file() and
                                file_path.stat().st_mtime > recent_threshold and
                                self._test_claude_binary(file_path)):
                                self._print_info(f"Found recently created npm binary: {file_path}")
                                return file_path
            except:
                pass

        except Exception as e:
            self._print_warning(f"Alternative npm detection failed: {e}")

        return None

    def install_claude_npm(self) -> bool:
        """Install Claude via npm with comprehensive fallbacks"""
        self._print_section("Installing Claude via npm")

        if not self.system_info.npm_available:
            self._print_error("npm is not available. Please install Node.js first.")
            return False

        try:
            # Configure npm prefix
            npm_prefix = self.system_info.home_dir / ".npm-global"
            npm_prefix.mkdir(exist_ok=True)

            self._run_command(["npm", "config", "set", "prefix", str(npm_prefix)])

            # Update PATH for this session
            npm_bin = npm_prefix / "bin"
            current_path = os.environ.get("PATH", "")
            if str(npm_bin) not in current_path:
                os.environ["PATH"] = f"{npm_bin}:{current_path}"

            # Install package with multiple fallback strategies
            install_strategies = [
                ["npm", "install", "-g", "@anthropic-ai/claude-code"],
                ["npm", "install", "-g", "@anthropic-ai/claude-code", "--force"],
                ["npm", "install", "-g", "@anthropic-ai/claude-code", "--legacy-peer-deps"]
            ]

            if self.system_info.has_sudo:
                install_strategies.insert(1, ["sudo", "npm", "install", "-g", "@anthropic-ai/claude-code"])

            for strategy in install_strategies:
                try:
                    self._print_info(f"Trying: {' '.join(strategy)}")
                    self._run_command(strategy, timeout=300)
                    self._print_success("npm installation successful")
                    return True
                except subprocess.CalledProcessError as e:
                    self._print_warning(f"Strategy failed: {e}")
                    continue

            self._print_error("All npm installation strategies failed")
            return False

        except Exception as e:
            self._print_error(f"npm installation failed: {e}")
            return False

    def install_claude_pip(self) -> bool:
        """Install Claude via pip with PEP 668 and pipx support"""
        self._print_section("Installing Claude via pip")

        if not self.system_info.pip_available:
            self._print_error("pip is not available")
            return False

        try:
            pip_cmd = "pip3" if shutil.which("pip3") else "pip"

            # Check for PEP 668 externally managed environment
            try:
                test_result = self._run_command([pip_cmd, "install", "--dry-run", "setuptools"], check=False, timeout=30)
                if "externally-managed-environment" in test_result.stderr:
                    self._print_info("Detected PEP 668 externally managed environment (Debian 12+)")
                    return self._install_claude_pipx_venv()
            except:
                pass

            # Traditional pip installation strategies
            install_strategies = [
                [pip_cmd, "install", "--user", "claude-code"],
                [pip_cmd, "install", "--user", "claude-code", "--break-system-packages"],
                [pip_cmd, "install", "claude-code"]
            ]

            if self.system_info.has_sudo:
                install_strategies.extend([
                    ["sudo", pip_cmd, "install", "claude-code"],
                    ["sudo", pip_cmd, "install", "claude-code", "--break-system-packages"]
                ])

            for strategy in install_strategies:
                try:
                    self._print_info(f"Trying: {' '.join(strategy)}")
                    self._run_command(strategy, timeout=300)
                    self._print_success("pip installation successful")
                    return True
                except subprocess.CalledProcessError as e:
                    if "externally-managed-environment" in (e.stderr or ""):
                        self._print_warning("PEP 668 detected, falling back to pipx/venv")
                        return self._install_claude_pipx_venv()
                    continue

            self._print_error("All pip installation strategies failed")
            return False

        except Exception as e:
            self._print_error(f"pip installation failed: {e}")
            return False

    def _install_claude_pipx_venv(self) -> bool:
        """Install Claude using pipx or virtual environment (PEP 668 compatible)"""
        self._print_info("Installing Claude with PEP 668 compatibility")

        # Try pipx first (recommended for Debian)
        if self._install_claude_pipx():
            return True

        # Fall back to manual venv
        return self._install_claude_manual_venv()

    def _install_claude_pipx(self) -> bool:
        """Install Claude using pipx"""
        try:
            # Check if pipx is available
            if not shutil.which("pipx"):
                self._print_info("pipx not found, installing...")

                # Install pipx using system package manager
                install_pipx_strategies = [
                    ["sudo", "apt", "install", "-y", "pipx"],
                    ["sudo", "apt-get", "install", "-y", "pipx"],
                    [shutil.which("pip3") or "pip3", "install", "--user", "pipx", "--break-system-packages"]
                ]

                for strategy in install_pipx_strategies:
                    try:
                        self._print_info(f"Installing pipx: {' '.join(strategy)}")
                        self._run_command(strategy, timeout=300)

                        # Ensure pipx is in PATH
                        pipx_bin = Path.home() / ".local" / "bin" / "pipx"
                        if pipx_bin.exists():
                            # Add to current PATH for this session
                            current_path = os.environ.get("PATH", "")
                            local_bin = str(Path.home() / ".local" / "bin")
                            if local_bin not in current_path:
                                os.environ["PATH"] = f"{local_bin}:{current_path}"
                            break
                    except subprocess.CalledProcessError:
                        continue
                else:
                    self._print_warning("Failed to install pipx")
                    return False

            # Install Claude using pipx
            pipx_cmd = shutil.which("pipx") or str(Path.home() / ".local" / "bin" / "pipx")

            try:
                self._print_info(f"Installing Claude via pipx: {pipx_cmd}")
                self._run_command([pipx_cmd, "install", "claude-code"], timeout=300)

                # Ensure pipx binaries are in PATH
                pipx_bin_dir = Path.home() / ".local" / "bin"
                current_path = os.environ.get("PATH", "")
                if str(pipx_bin_dir) not in current_path:
                    os.environ["PATH"] = f"{pipx_bin_dir}:{current_path}"

                self._print_success("Claude installed via pipx")
                return True

            except subprocess.CalledProcessError as e:
                self._print_warning(f"pipx installation failed: {e}")
                return False

        except Exception as e:
            self._print_warning(f"pipx installation error: {e}")
            return False

    def _install_claude_manual_venv(self) -> bool:
        """Install Claude in a manual virtual environment"""
        try:
            self._print_info("Creating virtual environment for Claude")

            # Ensure python3-venv is installed
            try:
                self._run_command(["sudo", "apt", "install", "-y", "python3-venv", "python3-full"], timeout=120)
            except subprocess.CalledProcessError:
                try:
                    self._run_command(["sudo", "apt-get", "install", "-y", "python3-venv", "python3-full"], timeout=120)
                except subprocess.CalledProcessError:
                    self._print_warning("Could not install python3-venv")

            # Create venv directory
            if self.venv_dir.exists():
                shutil.rmtree(self.venv_dir)

            self.venv_dir.mkdir(parents=True, exist_ok=True)

            # Create virtual environment
            self._print_info(f"Creating venv at {self.venv_dir}")
            self._run_command(["python3", "-m", "venv", str(self.venv_dir)], timeout=120)

            # Install Claude in venv
            venv_pip = self.venv_dir / "bin" / "pip"
            venv_python = self.venv_dir / "bin" / "python"

            self._print_info("Installing Claude in virtual environment")
            self._run_command([str(venv_pip), "install", "--upgrade", "pip"], timeout=120)
            self._run_command([str(venv_pip), "install", "claude-code"], timeout=300)

            # Create wrapper script that uses venv
            self._create_venv_wrapper()

            self._print_success("Claude installed in virtual environment")
            return True

        except Exception as e:
            self._print_error(f"Virtual environment installation failed: {e}")
            return False

    def _create_venv_wrapper(self) -> bool:
        """Create wrapper script for venv-installed Claude"""
        try:
            wrapper_path = self.local_bin / "claude"
            venv_claude = self.venv_dir / "bin" / "claude"

            if not venv_claude.exists():
                # Look for claude-code
                venv_claude = self.venv_dir / "bin" / "claude-code"
                if not venv_claude.exists():
                    self._print_error("Claude binary not found in venv")
                    return False

            wrapper_content = f'''#!/bin/bash
# Claude Virtual Environment Wrapper
# Auto-generated by Claude Enhanced Installer for PEP 668 compatibility

# Activate virtual environment and execute Claude
source "{self.venv_dir}/bin/activate"
exec "{venv_claude}" "$@"
'''

            wrapper_path.write_text(wrapper_content)
            wrapper_path.chmod(0o755)

            self._print_success(f"Virtual environment wrapper created at {wrapper_path}")
            return True

        except Exception as e:
            self._print_error(f"Failed to create venv wrapper: {e}")
            return False

    def create_wrapper_script(self, claude_binary: Path) -> bool:
        """Create enhanced wrapper script with auto permission bypass and orchestration"""
        self._print_section("Creating enhanced wrapper script")

        try:
            wrapper_path = self.local_bin / "claude"

            # Always create the enhanced wrapper with full functionality
            wrapper_content = self._generate_enhanced_wrapper(claude_binary)

            # Write wrapper script
            wrapper_path.write_text(wrapper_content)
            wrapper_path.chmod(0o755)

            # Test wrapper
            if self._test_enhanced_wrapper(wrapper_path):
                self._print_success(f"Enhanced wrapper created at {wrapper_path}")
                self._print_info("Features: Auto permission bypass, orchestration, agent access")
                return True
            else:
                self._print_error("Enhanced wrapper test failed")
                return False

        except Exception as e:
            self._print_error(f"Failed to create enhanced wrapper: {e}")
            return False

    def _generate_bash_wrapper(self, claude_binary: Path) -> str:
        """Generate bash wrapper script"""
        return f'''#!/bin/bash
# Claude Enhanced Wrapper - Auto-generated by Claude Enhanced Installer
# Prevents recursion issues and provides robust execution

# Detect if we're being called recursively
if [[ "${{CLAUDE_WRAPPER_ACTIVE}}" == "true" ]]; then
    echo "Error: Claude wrapper recursion detected" >&2
    exit 1
fi

# Set recursion protection
export CLAUDE_WRAPPER_ACTIVE=true

# Cleanup function
cleanup() {{
    unset CLAUDE_WRAPPER_ACTIVE
}}
trap cleanup EXIT

# Real Claude binary path
CLAUDE_BINARY="{claude_binary}"

# Verify binary exists
if [[ ! -f "$CLAUDE_BINARY" ]]; then
    echo "Error: Claude binary not found at $CLAUDE_BINARY" >&2
    exit 1
fi

# Execute with proper permissions and error handling
if [[ "$CLAUDE_BINARY" == *.js ]]; then
    # Node.js script
    exec node "$CLAUDE_BINARY" "$@"
else
    # Direct binary
    exec "$CLAUDE_BINARY" "$@"
fi
'''

    def _generate_zsh_wrapper(self, claude_binary: Path) -> str:
        """Generate zsh-compatible wrapper script"""
        return f'''#!/bin/zsh
# Claude Enhanced Wrapper - Auto-generated by Claude Enhanced Installer
# ZSH-compatible version with recursion protection

# Detect if we're being called recursively
if [[ "${{CLAUDE_WRAPPER_ACTIVE}}" == "true" ]]; then
    print "Error: Claude wrapper recursion detected" >&2
    exit 1
fi

# Set recursion protection
export CLAUDE_WRAPPER_ACTIVE=true

# Cleanup function
cleanup() {{
    unset CLAUDE_WRAPPER_ACTIVE
}}

# Register cleanup
trap cleanup EXIT

# Real Claude binary path
CLAUDE_BINARY="{claude_binary}"

# Verify binary exists
if [[ ! -f "$CLAUDE_BINARY" ]]; then
    print "Error: Claude binary not found at $CLAUDE_BINARY" >&2
    exit 1
fi

# Execute with proper permissions and error handling
if [[ "$CLAUDE_BINARY" == *.js ]]; then
    # Node.js script
    exec node "$CLAUDE_BINARY" "$@"
else
    # Direct binary
    exec "$CLAUDE_BINARY" "$@"
fi
'''

    def _generate_enhanced_wrapper(self, claude_binary: Path) -> str:
        """Generate enhanced wrapper with auto permission bypass and orchestration"""
        return f'''#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Master System with Auto Permission Bypass
# Enhanced wrapper with intelligent orchestration and automatic updates
# Auto-generated by Claude Enhanced Installer v2.0
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Dynamic path detection
detect_project_root() {{
    # Check environment variable first
    if [[ -n "${{CLAUDE_PROJECT_ROOT:-}}" ]] && [[ -d "$CLAUDE_PROJECT_ROOT/agents" ]]; then
        echo "$CLAUDE_PROJECT_ROOT"
        return 0
    fi

    # Check agents symlink location
    if [[ -L "$HOME/.local/share/claude/agents" ]]; then
        local agents_target
        agents_target=$(readlink -f "$HOME/.local/share/claude/agents")
        if [[ -n "$agents_target" ]]; then
            echo "$(dirname "$agents_target")"
            return 0
        fi
    fi

    # Check common locations
    local locations=(
        "$(dirname "$(readlink -f "$0")")"
        "$PWD"
        "$HOME/claude-backups"
        "$HOME/Documents/Claude"
        "$HOME/Downloads/claude-backups"
    )

    for location in "${{locations[@]}}"; do
        if [[ -d "$location/agents" ]] && [[ -f "$location/CLAUDE.md" ]]; then
            echo "$location"
            return 0
        fi
    done

    # Default fallback
    echo "$PWD"
}}

# Dynamic configuration
PROJECT_ROOT=$(detect_project_root)
CLAUDE_BINARY="{claude_binary}"
ORCHESTRATOR_PATH="$PROJECT_ROOT/agents/src/python/production_orchestrator.py"
CACHE_DIR="$HOME/.cache/claude"
AGENTS_BRIDGE="$HOME/.local/bin/claude-agent"
LEARNING_CLI="$HOME/.local/bin/claude-learning"

# Feature flags - can be disabled via environment variables
CLAUDE_PERMISSION_BYPASS="${{CLAUDE_PERMISSION_BYPASS:-true}}"
PICMCS_ENABLED="${{PICMCS_ENABLED:-false}}"
LEARNING_ML_ENABLED="${{LEARNING_ML_ENABLED:-false}}"
LEARNING_DOCKER_AUTO_START="${{LEARNING_DOCKER_AUTO_START:-true}}"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
CYAN='\\033[0;36m'
BOLD='\\033[1m'
RESET='\\033[0m'

# Logging function
log() {{
    echo -e "${{CYAN}}[Claude Master]${{RESET}} $1"
}}

# Status display
show_status() {{
    echo -e "${{BOLD}}${{CYAN}}Claude Master System Status:${{RESET}}"
    echo -e "  ${{GREEN}}✓${{RESET}} Claude Binary: $CLAUDE_BINARY"
    echo -e "  ${{GREEN}}✓${{RESET}} Permission Bypass: $([[ "$CLAUDE_PERMISSION_BYPASS" == "true" ]] && echo "Enabled" || echo "Disabled")"

    # Check orchestrator
    if [[ -f "$ORCHESTRATOR_PATH" ]]; then
        echo -e "  ${{GREEN}}✓${{RESET}} Orchestrator: Available"
    else
        echo -e "  ${{YELLOW}}⚠${{RESET}} Orchestrator: Not found"
    fi

    # Check agents bridge
    if [[ -f "$AGENTS_BRIDGE" ]]; then
        echo -e "  ${{GREEN}}✓${{RESET}} Agents Bridge: Available"
    else
        echo -e "  ${{YELLOW}}⚠${{RESET}} Agents Bridge: Not installed"
    fi

    # Check learning system
    if [[ -f "$LEARNING_CLI" ]]; then
        echo -e "  ${{GREEN}}✓${{RESET}} Learning System: Available"
    else
        echo -e "  ${{YELLOW}}⚠${{RESET}} Learning System: Not installed"
    fi

    # Check Docker
    if command -v docker >/dev/null && docker ps | grep claude-postgres >/dev/null 2>&1; then
        echo -e "  ${{GREEN}}✓${{RESET}} Database: Running (PostgreSQL)"
    else
        echo -e "  ${{YELLOW}}⚠${{RESET}} Database: Not running"
    fi
}}

# Auto permission bypass check
should_bypass_permissions() {{
    # Always bypass if explicitly enabled
    [[ "$CLAUDE_PERMISSION_BYPASS" == "true" ]] && return 0

    # Check for headless/server environment
    if [[ -n "${{SSH_CLIENT:-}}" ]] || [[ -n "${{SSH_TTY:-}}" ]] || [[ -f "/.dockerenv" ]]; then
        return 0
    fi

    # Default to no bypass for desktop environments
    return 1
}}

# Help display
show_help() {{
    cat << 'EOF'
Claude Master System with Auto Permission Bypass
================================================
Commands:
  claude [args]           - Run Claude (with auto permission bypass)
  claude --safe [args]    - Run Claude without permission bypass
  claude --status         - Show status
  claude --list-agents    - List agents
  claude --orchestrator   - Launch Python orchestrator UI

Environment:
  CLAUDE_PERMISSION_BYPASS=false  - Disable auto permission bypass
  PICMCS_ENABLED=false           - Disable PICMCS v3.0 context optimization
  LEARNING_ML_ENABLED=false      - Disable machine learning features
  LEARNING_DOCKER_AUTO_START=true - Enable automatic Docker container startup
EOF
}}

# Main command handling
main() {{
    # Handle special commands
    case "${{1:-}}" in
        "--status")
            show_status
            return 0
            ;;
        "--list-agents")
            if [[ -f "$AGENTS_BRIDGE" ]]; then
                "$AGENTS_BRIDGE" list
            else
                echo -e "${{YELLOW}}⚠${{RESET}} Agents bridge not installed. Run: python3 claude-enhanced-installer.py --mode=full"
            fi
            return 0
            ;;
        "--orchestrator")
            if [[ -f "$ORCHESTRATOR_PATH" ]]; then
                log "Launching Python orchestrator UI..."
                cd "$(dirname "$ORCHESTRATOR_PATH")"
                python3 "$ORCHESTRATOR_PATH" "${{@:2}}"
            else
                echo -e "${{RED}}✗${{RESET}} Orchestrator not found. Install with: python3 claude-enhanced-installer.py --mode=full"
                return 1
            fi
            return $?
            ;;
        "--help"|"-h")
            show_help
            return 0
            ;;
        "--safe")
            # Run without permission bypass
            shift
            log "Running in safe mode (no permission bypass)"
            exec "$CLAUDE_BINARY" "$@"
            ;;
    esac

    # Verify Claude binary exists
    if [[ ! -f "$CLAUDE_BINARY" ]]; then
        echo -e "${{RED}}✗${{RESET}} Claude binary not found at $CLAUDE_BINARY"
        echo "Install Claude with: npm install -g @anthropic-ai/claude-code"
        return 1
    fi

    # Build command with auto permission bypass
    local claude_args=()

    # Add permission bypass if enabled
    if should_bypass_permissions; then
        claude_args+=("--dangerously-skip-permissions")
        log "Auto permission bypass enabled ({self.system_info.environment_type.value} environment detected)"
    fi

    # Add original arguments
    claude_args+=("$@")

    # Execute Claude with enhanced features
    exec "$CLAUDE_BINARY" "${{claude_args[@]}}"
}}

# Run main function with all arguments
main "$@"
'''

    def _test_enhanced_wrapper(self, wrapper_path: Path) -> bool:
        """Test enhanced wrapper script functionality"""
        try:
            # Test status command
            result = self._run_command([str(wrapper_path), "--status"], check=False, timeout=10)
            if result.returncode != 0:
                return False

            # Test help command
            result = self._run_command([str(wrapper_path), "--help"], check=False, timeout=10)
            return result.returncode == 0
        except:
            return False

    def _test_wrapper(self, wrapper_path: Path) -> bool:
        """Test wrapper script functionality"""
        try:
            result = self._run_command([str(wrapper_path), "--help"], check=False, timeout=10)
            return result.returncode == 0
        except:
            return False

    def update_shell_config(self) -> bool:
        """Update shell configuration files for PATH and completion"""
        self._print_section("Updating shell configuration")

        try:
            # Ensure .local/bin is in PATH
            path_export = f'export PATH="$HOME/.local/bin:$PATH"'

            # Shell-specific configuration
            if self.system_info.shell == ShellType.ZSH:
                return self._update_zsh_config(path_export)
            elif self.system_info.shell == ShellType.BASH:
                return self._update_bash_config(path_export)
            elif self.system_info.shell == ShellType.FISH:
                return self._update_fish_config()
            else:
                # Generic approach for other shells
                return self._update_generic_config(path_export)

        except Exception as e:
            self._print_error(f"Failed to update shell configuration: {e}")
            return False

    def _update_zsh_config(self, path_export: str) -> bool:
        """Update zsh configuration"""
        try:
            zshrc = Path.home() / ".zshrc"

            # Read current content
            current_content = ""
            if zshrc.exists():
                current_content = zshrc.read_text()

            # Check if already configured
            if "/.local/bin:" in current_content and "Claude Enhanced Installer" in current_content:
                self._print_info("ZSH already configured")
                return True

            # Add configuration
            config_block = f'''
# Added by Claude Enhanced Installer
{path_export}

# Claude completion (if available)
if command -v claude >/dev/null 2>&1; then
    # Try to enable completion
    true
fi
'''

            # Append configuration
            with zshrc.open("a") as f:
                f.write(config_block)

            self._print_success("ZSH configuration updated")
            return True

        except Exception as e:
            self._print_error(f"Failed to update ZSH config: {e}")
            return False

    def _update_bash_config(self, path_export: str) -> bool:
        """Update bash configuration"""
        try:
            bashrc = Path.home() / ".bashrc"

            # Create .bashrc if it doesn't exist
            if not bashrc.exists():
                bashrc.touch()

            current_content = bashrc.read_text()

            # Check if already configured
            if "/.local/bin:" in current_content and "Claude Enhanced Installer" in current_content:
                self._print_info("Bash already configured")
                return True

            # Add configuration
            config_block = f'''
# Added by Claude Enhanced Installer
{path_export}

# Claude completion (if available)
if command -v claude >/dev/null 2>&1; then
    # Try to enable completion
    true
fi
'''

            # Append configuration
            with bashrc.open("a") as f:
                f.write(config_block)

            self._print_success("Bash configuration updated")
            return True

        except Exception as e:
            self._print_error(f"Failed to update Bash config: {e}")
            return False

    def _update_fish_config(self) -> bool:
        """Update fish shell configuration"""
        try:
            fish_config_dir = Path.home() / ".config" / "fish"
            fish_config_dir.mkdir(parents=True, exist_ok=True)

            config_fish = fish_config_dir / "config.fish"

            current_content = ""
            if config_fish.exists():
                current_content = config_fish.read_text()

            # Check if already configured
            if "/.local/bin" in current_content and "Claude Enhanced Installer" in current_content:
                self._print_info("Fish already configured")
                return True

            # Add configuration for fish
            config_block = '''
# Added by Claude Enhanced Installer
set -gx PATH $HOME/.local/bin $PATH

# Claude completion (if available)
if command -v claude >/dev/null 2>&1
    # Try to enable completion
    true
end
'''

            # Append configuration
            with config_fish.open("a") as f:
                f.write(config_block)

            self._print_success("Fish configuration updated")
            return True

        except Exception as e:
            self._print_error(f"Failed to update Fish config: {e}")
            return False

    def _update_generic_config(self, path_export: str) -> bool:
        """Update configuration for unknown/other shells"""
        try:
            profile = Path.home() / ".profile"

            current_content = ""
            if profile.exists():
                current_content = profile.read_text()

            # Check if already configured
            if "/.local/bin:" in current_content and "Claude Enhanced Installer" in current_content:
                self._print_info("Profile already configured")
                return True

            # Add configuration
            config_block = f'''
# Added by Claude Enhanced Installer
{path_export}
'''

            # Append configuration
            with profile.open("a") as f:
                f.write(config_block)

            self._print_success("Profile configuration updated")
            return True

        except Exception as e:
            self._print_error(f"Failed to update profile config: {e}")
            return False

    def install_agents_system(self) -> bool:
        """Install the agent system using symlinks to preserve live updates"""
        self._print_section("Installing agent system")

        try:
            agents_source = self.project_root / "agents"
            if not agents_source.exists():
                self._print_warning(f"Agents source directory not found: {agents_source}")
                return False

            # Create symlink targets
            claude_share_agents = self.system_info.home_dir / ".local" / "share" / "claude" / "agents"
            home_agents = self.system_info.home_dir / "agents"

            # Ensure parent directories exist
            claude_share_agents.parent.mkdir(parents=True, exist_ok=True)

            # Remove existing symlinks/directories if they exist
            for target in [claude_share_agents, home_agents]:
                if target.exists() or target.is_symlink():
                    if target.is_symlink():
                        target.unlink()
                        self._print_info(f"Removed existing symlink: {target}")
                    elif target.is_dir():
                        shutil.rmtree(target)
                        self._print_info(f"Removed existing directory: {target}")

            # Create primary symlink (~/.local/share/claude/agents -> project/agents)
            claude_share_agents.symlink_to(agents_source.resolve())
            self._print_success(f"Created symlink: {claude_share_agents} -> {agents_source}")

            # Create convenience symlink (~/agents -> ~/.local/share/claude/agents)
            home_agents.symlink_to(claude_share_agents)
            self._print_success(f"Created convenience symlink: {home_agents} -> {claude_share_agents}")

            # Verify symlinks work
            if claude_share_agents.exists() and home_agents.exists():
                agent_count = len(list(claude_share_agents.glob("*.md")))
                self._print_success(f"Agent system installed with {agent_count} agents available")
                self._print_info(f"Live updates: Changes to {agents_source} will be immediately available")
                return True
            else:
                self._print_error("Symlink verification failed")
                return False

        except Exception as e:
            self._print_error(f"Failed to install agent system: {e}")
            return False

    def install_picmcs_system(self) -> bool:
        """Install PICMCS v3.0 context chopping system"""
        self._print_section("Installing PICMCS v3.0 system")

        try:
            picmcs_source = self.project_root / "agents" / "src" / "python"
            if not picmcs_source.exists():
                self._print_warning("PICMCS source directory not found")
                return False

            picmcs_target = self.system_info.home_dir / ".local" / "share" / "claude" / "picmcs"
            picmcs_target.mkdir(parents=True, exist_ok=True)

            # Copy PICMCS files
            picmcs_files = [
                "intelligent_context_chopper.py",
                "demo_adaptive_chopper.py",
                "test_hardware_fallback.py"
            ]

            for filename in picmcs_files:
                source_file = picmcs_source / filename
                if source_file.exists():
                    target_file = picmcs_target / filename
                    shutil.copy2(source_file, target_file)
                    target_file.chmod(0o755)

            self._print_success("PICMCS v3.0 system installed")
            return True

        except Exception as e:
            self._print_error(f"Failed to install PICMCS system: {e}")
            return False

    def create_launch_script(self) -> bool:
        """Create convenient launch script with dynamic path resolution"""
        self._print_section("Creating launch script")

        try:
            launch_script = self.local_bin / "claude-enhanced"

            script_content = '''#!/bin/bash
# Claude Enhanced Launcher
# Provides enhanced functionality and error handling with dynamic path resolution

# Dynamic project root detection
detect_project_root() {
    # Check agents symlink location first
    if [[ -L "$HOME/.local/share/claude/agents" ]]; then
        local agents_target
        agents_target=$(readlink -f "$HOME/.local/share/claude/agents")
        if [[ -n "$agents_target" ]]; then
            echo "$(dirname "$agents_target")"
            return 0
        fi
    fi

    # Check common locations
    local locations=(
        "$HOME/claude-backups"
        "$HOME/Documents/Claude"
        "$HOME/Downloads/claude-backups"
        "$PWD"
    )

    for location in "${locations[@]}"; do
        if [[ -d "$location/agents" ]] && [[ -f "$location/CLAUDE.md" ]]; then
            echo "$location"
            return 0
        fi
    done

    # Default fallback
    echo "$PWD"
}

# Set up environment with dynamic paths
export CLAUDE_ENHANCED=true
export CLAUDE_PROJECT_ROOT=$(detect_project_root)

# Launch Claude with enhanced features
exec claude "$@"
'''

            launch_script.write_text(script_content)
            launch_script.chmod(0o755)

            self._print_success(f"Launch script created at {launch_script}")
            return True

        except Exception as e:
            self._print_error(f"Failed to create launch script: {e}")
            return False

    def install_docker_database(self) -> bool:
        """Install Docker-based PostgreSQL database with pgvector"""
        self._print_section("Installing Docker database system")

        try:
            # Check if Docker is available
            if not shutil.which("docker"):
                self._print_info("Installing Docker and environment-specific packages...")

                # Get environment-specific packages
                env_packages = self._get_environment_specific_packages()
                docker_packages = ["docker.io", "docker-compose"]
                all_packages = list(set(env_packages + docker_packages))  # Remove duplicates

                self._print_info(f"📦 Installing packages for {self.system_info.environment_type.value} environment: {', '.join(all_packages)}")

                # Install Docker and environment packages using system package manager
                package_list = " ".join(all_packages)
                docker_install_strategies = [
                    ["sudo", "apt", "update", "&&", "sudo", "apt", "install", "-y"] + all_packages,
                    ["sudo", "apt-get", "update", "&&", "sudo", "apt-get", "install", "-y"] + all_packages,
                    ["curl", "-fsSL", "https://get.docker.com", "-o", "get-docker.sh", "&&", "sudo", "sh", "get-docker.sh"]
                ]

                for strategy in docker_install_strategies:
                    try:
                        if "&&" in strategy:
                            # Handle compound commands
                            parts = []
                            current_cmd = []
                            for item in strategy:
                                if item == "&&":
                                    if current_cmd:
                                        parts.append(current_cmd)
                                        current_cmd = []
                                else:
                                    current_cmd.append(item)
                            if current_cmd:
                                parts.append(current_cmd)

                            # Execute each part
                            for cmd_part in parts:
                                self._run_command(cmd_part, timeout=300)
                        else:
                            self._run_command(strategy, timeout=300)
                        break
                    except subprocess.CalledProcessError:
                        continue
                else:
                    self._print_warning("Could not install Docker, skipping database setup")
                    return False

            # Add user to docker group if not already
            try:
                self._run_command(["sudo", "usermod", "-aG", "docker", self.system_info.user_name], timeout=30)
                self._print_info("Added user to docker group (may require logout/login)")
            except subprocess.CalledProcessError:
                self._print_warning("Could not add user to docker group")

            # Create database directory structure
            db_dir = self.project_root / "database"
            docker_dir = db_dir / "docker"
            docker_dir.mkdir(parents=True, exist_ok=True)

            # Create docker-compose.yml for PostgreSQL with pgvector
            compose_content = """version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:0.7.0-pg16
    container_name: claude-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: claude_agents_auth
      POSTGRES_USER: claude_agent
      POSTGRES_PASSWORD: claude_secure_2024
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"
    ports:
      - "5433:5432"
    volumes:
      - claude_postgres_data:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U claude_agent -d claude_agents_auth"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  claude_postgres_data:
    driver: local
"""

            compose_file = docker_dir / "docker-compose.yml"
            compose_file.write_text(compose_content)

            # Create SQL initialization script
            sql_dir = docker_dir / "sql"
            sql_dir.mkdir(exist_ok=True)

            init_sql = """-- Claude Enhanced Learning System Database Schema
-- PostgreSQL 16+ with pgvector extension

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enhanced learning schema
CREATE SCHEMA IF NOT EXISTS enhanced_learning;

-- Agent performance metrics table
CREATE TABLE IF NOT EXISTS enhanced_learning.agent_metrics (
    id BIGSERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    task_embedding VECTOR(512),
    context_size INTEGER,
    tokens_used INTEGER
);

-- Learning analytics table
CREATE TABLE IF NOT EXISTS enhanced_learning.learning_analytics (
    id BIGSERIAL PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(10,4),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_metrics_name_time ON enhanced_learning.agent_metrics(agent_name, timestamp);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_embedding ON enhanced_learning.agent_metrics USING ivfflat (task_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_learning_analytics_category ON enhanced_learning.learning_analytics(category, timestamp);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA enhanced_learning TO claude_agent;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA enhanced_learning TO claude_agent;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA enhanced_learning TO claude_agent;
"""

            init_file = sql_dir / "01-init-learning.sql"
            init_file.write_text(init_sql)

            # Check for existing container and handle reinstall
            existing_container = False
            try:
                result = self._run_command(["docker", "ps", "-a", "--filter", "name=claude-postgres", "--format", "{{.Names}}"],
                                         check=False, timeout=10)
                if "claude-postgres" in result.stdout:
                    existing_container = True
                    self._print_info("Existing claude-postgres container detected - handling reinstall...")

                    # Stop and remove existing container
                    self._run_command(["docker", "stop", "claude-postgres"], check=False, timeout=30)
                    self._run_command(["docker", "rm", "claude-postgres"], check=False, timeout=30)
                    self._print_info("Removed existing container for clean reinstall")
            except:
                pass

            # Start database service
            self._print_info("Starting PostgreSQL database...")
            self._run_command(["docker-compose", "-f", str(compose_file), "up", "-d"],
                            cwd=docker_dir, timeout=120)

            # Wait for database to be ready
            self._print_info("Waiting for database to be ready...")
            for i in range(30):  # 30 second timeout
                try:
                    result = self._run_command([
                        "docker", "exec", "claude-postgres",
                        "pg_isready", "-U", "claude_agent", "-d", "claude_agents_auth"
                    ], check=False, timeout=5)

                    if result.returncode == 0:
                        self._print_success("Database is ready")
                        break

                    time.sleep(1)
                except:
                    time.sleep(1)
            else:
                self._print_warning("Database readiness check timed out")

            self._print_success("Docker database system installed")
            return True

        except Exception as e:
            self._print_error(f"Failed to install Docker database: {e}")
            return False

    def install_global_agents_bridge(self) -> bool:
        """Install global agents bridge for 60+ agent ecosystem"""
        self._print_section("Installing global agents bridge")

        try:
            # Create bridge directory
            bridge_dir = self.system_info.home_dir / ".local" / "share" / "claude" / "bridge"
            bridge_dir.mkdir(parents=True, exist_ok=True)

            # Create agent registry
            registry_content = {
                "version": "10.0",
                "agents": {},
                "last_updated": time.time(),
                "total_agents": 0
            }

            # Discover agents from source
            agents_source = self.project_root / "agents"
            if agents_source.exists():
                for agent_file in agents_source.glob("*.md"):
                    if agent_file.name != "Template.md":
                        agent_name = agent_file.stem.lower().replace("-", "_")
                        registry_content["agents"][agent_name] = {
                            "file": str(agent_file),
                            "name": agent_file.stem,
                            "status": "active"
                        }

            registry_content["total_agents"] = len(registry_content["agents"])

            # Write registry
            registry_file = bridge_dir / "agents_registry.json"
            registry_file.write_text(json.dumps(registry_content, indent=2))

            # Create claude-agent command
            agent_script = self.local_bin / "claude-agent"
            agent_content = f'''#!/bin/bash
# Claude Agents Bridge - Global agent access
# Provides command-line access to 60+ specialized agents

BRIDGE_DIR="{bridge_dir}"
REGISTRY_FILE="$BRIDGE_DIR/agents_registry.json"

# Show help
show_help() {{
    cat << 'EOF'
Claude Agents Bridge v10.0
Command-line access to 60+ specialized agents

Usage:
  claude-agent list                    # List all agents
  claude-agent status                  # Show system status
  claude-agent <agent-name> <prompt>   # Invoke agent

Examples:
  claude-agent director "Create strategic plan"
  claude-agent security "Audit system vulnerabilities"
  claude-agent optimizer "Improve performance"

Available Agents:
  Command & Control: director, projectorchestrator
  Security: security, bastion, cryptoexpert, quantumguard
  Development: architect, constructor, debugger, testbed
  Languages: c-internal, python-internal, rust-internal
  And 50+ more specialized agents...
EOF
}}

# List agents
list_agents() {{
    if [[ -f "$REGISTRY_FILE" ]]; then
        python3 -c "
import json
with open('$REGISTRY_FILE') as f:
    data = json.load(f)
print(f'📊 Total Agents: {{data[\"total_agents\"]}}')
print('\\n🤖 Available Agents:')
for name, info in sorted(data['agents'].items()):
    print(f'  {{name:20}} - {{info[\"name\"]}}')
"
    else
        echo "❌ Agent registry not found"
        exit 1
    fi
}}

# Show status
show_status() {{
    echo "Claude Agents Bridge v10.0 Status:"
    echo "  Registry: $REGISTRY_FILE"
    if [[ -f "$REGISTRY_FILE" ]]; then
        echo "  Status: ✅ Operational"
        AGENT_COUNT=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['total_agents'])")
        echo "  Agents: $AGENT_COUNT available"
    else
        echo "  Status: ❌ Registry not found"
    fi
}}

# Main command handling
case "$1" in
    "list"|"ls")
        list_agents
        ;;
    "status"|"stat")
        show_status
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        # Agent invocation
        AGENT_NAME="$1"
        shift
        PROMPT="$*"

        if [[ -z "$AGENT_NAME" ]] || [[ -z "$PROMPT" ]]; then
            echo "❌ Usage: claude-agent <agent-name> <prompt>"
            exit 1
        fi

        echo "🤖 Invoking agent: $AGENT_NAME"
        echo "📝 Prompt: $PROMPT"
        echo "⚠️  Note: Direct agent invocation requires Claude Code Task tool integration"
        echo "💡 For now, this provides agent discovery and registry management"
        ;;
esac
'''

            agent_script.write_text(agent_content)
            agent_script.chmod(0o755)

            self._print_success("Global agents bridge installed")
            return True

        except Exception as e:
            self._print_error(f"Failed to install global agents bridge: {e}")
            return False

    def setup_learning_system(self) -> bool:
        """Setup ML-powered learning and analytics system"""
        self._print_section("Setting up learning system")

        try:
            # Create learning directory
            learning_dir = self.system_info.home_dir / ".local" / "share" / "claude" / "learning"
            learning_dir.mkdir(parents=True, exist_ok=True)

            # Install learning dependencies in venv if available
            if self.venv_dir.exists():
                venv_pip = self.venv_dir / "bin" / "pip"
                learning_packages = [
                    "numpy", "scikit-learn", "psycopg2-binary",
                    "pandas", "asyncpg", "sqlalchemy"
                ]

                for package in learning_packages:
                    try:
                        self._print_info(f"Installing {package}...")
                        self._run_command([str(venv_pip), "install", package], timeout=120)
                    except subprocess.CalledProcessError:
                        self._print_warning(f"Could not install {package}")

            # Create learning configuration
            learning_config = {
                "version": "3.1",
                "database": {
                    "host": "localhost",
                    "port": 5433,
                    "database": "claude_agents_auth",
                    "user": "claude_agent",
                    "password": "claude_secure_2024"
                },
                "ml_features": {
                    "agent_selection": True,
                    "performance_prediction": True,
                    "adaptive_strategies": True,
                    "vector_embeddings": True
                },
                "docker_integration": {
                    "enabled": True,
                    "auto_start": True,
                    "container_name": "claude-postgres"
                }
            }

            config_file = learning_dir / "config.json"
            config_file.write_text(json.dumps(learning_config, indent=2))

            # Create learning CLI script
            learning_cli = self.local_bin / "claude-learning"
            cli_content = f'''#!/bin/bash
# Claude Learning System CLI
# ML-powered performance analytics and optimization

LEARNING_DIR="{learning_dir}"
CONFIG_FILE="$LEARNING_DIR/config.json"

show_help() {{
    cat << 'EOF'
Claude Learning System v3.1
ML-powered performance analytics and optimization

Usage:
  claude-learning status      # Show system status
  claude-learning dashboard   # View performance dashboard
  claude-learning export     # Export learning data
  claude-learning analyze    # Run performance analysis

Features:
  • ML-powered agent selection
  • Performance prediction and optimization
  • Vector embeddings for task similarity
  • Real-time analytics dashboard
EOF
}}

check_database() {{
    if docker ps | grep claude-postgres >/dev/null; then
        echo "✅ Database: Running"
        return 0
    else
        echo "❌ Database: Not running"
        return 1
    fi
}}

show_status() {{
    echo "Claude Learning System Status:"
    echo "  Config: $CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  Configuration: ✅ Found"
    else
        echo "  Configuration: ❌ Missing"
    fi

    check_database

    if command -v docker >/dev/null; then
        echo "  Docker: ✅ Available"
    else
        echo "  Docker: ❌ Not available"
    fi
}}

case "$1" in
    "status")
        show_status
        ;;
    "dashboard")
        echo "📊 Opening learning dashboard..."
        echo "💡 Access via: http://localhost:5433 (when implemented)"
        ;;
    "export")
        echo "📤 Exporting learning data..."
        echo "💡 Data export functionality (when implemented)"
        ;;
    "analyze")
        echo "🔍 Running performance analysis..."
        echo "💡 Analysis functionality (when implemented)"
        ;;
    *)
        show_help
        ;;
esac
'''

            learning_cli.write_text(cli_content)
            learning_cli.chmod(0o755)

            self._print_success("Learning system setup complete")
            return True

        except Exception as e:
            self._print_error(f"Failed to setup learning system: {e}")
            return False

    def check_for_claude_updates(self) -> Optional[str]:
        """Check for available Claude Code updates"""
        try:
            # Get current version
            current_version = self._get_current_claude_version()
            if not current_version:
                return None

            # Get latest version from npm
            latest_version = self._get_latest_claude_version()
            if not latest_version:
                return None

            # Compare versions
            if self._is_newer_version(latest_version, current_version):
                return latest_version

            return None

        except Exception as e:
            self._print_warning(f"Failed to check for updates: {e}")
            return None

    def _get_current_claude_version(self) -> Optional[str]:
        """Get currently installed Claude Code version"""
        try:
            # Try npm list first
            result = self._run_command(["npm", "list", "-g", "@anthropic-ai/claude-code"], check=False)
            if result.returncode == 0:
                # Extract version from npm output
                version_match = re.search(r'@anthropic-ai/claude-code@(\d+\.\d+\.\d+)', result.stdout)
                if version_match:
                    return version_match.group(1)

            # Try direct binary version
            claude_binary = self._find_claude_binary()
            if claude_binary:
                result = self._run_command([str(claude_binary), "--version"], check=False, timeout=10)
                if result.returncode == 0:
                    # Extract version from output
                    version_match = re.search(r'(\d+\.\d+\.\d+)', result.stdout)
                    if version_match:
                        return version_match.group(1)

        except Exception:
            pass
        return None

    def _get_latest_claude_version(self) -> Optional[str]:
        """Get latest available Claude Code version from npm"""
        try:
            result = self._run_command(["npm", "view", "@anthropic-ai/claude-code", "version"], check=False, timeout=30)
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return None

    def _is_newer_version(self, latest: str, current: str) -> bool:
        """Compare version strings to determine if latest is newer"""
        try:
            latest_parts = [int(x) for x in latest.split('.')]
            current_parts = [int(x) for x in current.split('.')]

            # Pad to same length
            max_len = max(len(latest_parts), len(current_parts))
            latest_parts.extend([0] * (max_len - len(latest_parts)))
            current_parts.extend([0] * (max_len - len(current_parts)))

            return latest_parts > current_parts
        except Exception:
            return False

    def _find_claude_binary(self) -> Optional[Path]:
        """Find Claude binary location"""
        # Check common locations
        locations = [
            Path("/usr/local/bin/claude"),
            Path(self.system_info.home_dir / ".local/bin/claude"),
            Path(self.system_info.home_dir / ".npm-global/bin/claude")
        ]

        for location in locations:
            if location.exists():
                return location

        # Try which command
        claude_path = shutil.which("claude")
        if claude_path:
            return Path(claude_path)

        return None

    def auto_update_claude(self) -> bool:
        """Perform automatic Claude Code update"""
        self._print_section("Performing Claude Code auto-update")

        try:
            latest_version = self.check_for_claude_updates()
            if not latest_version:
                self._print_info("Claude Code is up to date")
                return True

            current_version = self._get_current_claude_version()
            self._print_info(f"Update available: {current_version} → {latest_version}")

            # Perform update using the same installation strategies
            if self.system_info.npm_available:
                try:
                    self._print_info("Updating Claude via npm...")
                    self._run_command(["npm", "update", "-g", "@anthropic-ai/claude-code"], timeout=300)
                    self._print_success("Claude Code updated successfully")
                    return True
                except subprocess.CalledProcessError:
                    # Try sudo npm update
                    if self.system_info.has_sudo:
                        try:
                            self._run_command(["sudo", "npm", "update", "-g", "@anthropic-ai/claude-code"], timeout=300)
                            self._print_success("Claude Code updated successfully (with sudo)")
                            return True
                        except subprocess.CalledProcessError:
                            pass

            # Fall back to reinstallation
            self._print_info("Falling back to reinstallation...")
            return self.install_claude_npm()

        except Exception as e:
            self._print_error(f"Auto-update failed: {e}")
            return False

    def setup_update_scheduler(self) -> bool:
        """Setup automatic update checking via cron"""
        self._print_section("Setting up update scheduler")

        try:
            # Create update checker script
            update_script = self.local_bin / "claude-update-checker"
            script_content = f'''#!/bin/bash
# Claude Code Update Checker
# Automatically checks for updates and notifies user

CLAUDE_INSTALLER="{Path(__file__).resolve()}"
LOG_FILE="$HOME/.local/share/claude/logs/update-check.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Check for updates
echo "$(date): Checking for Claude Code updates..." >> "$LOG_FILE"

# Run update check
if python3 "$CLAUDE_INSTALLER" --check-updates >> "$LOG_FILE" 2>&1; then
    echo "$(date): Update check completed successfully" >> "$LOG_FILE"
else
    echo "$(date): Update check failed" >> "$LOG_FILE"
fi
'''

            update_script.write_text(script_content)
            update_script.chmod(0o755)

            # Add to cron (weekly check on Monday 8 AM)
            try:
                # Get current crontab
                result = self._run_command(["crontab", "-l"], check=False)
                current_cron = result.stdout if result.returncode == 0 else ""

                # Check if update job already exists
                if "claude-update-checker" not in current_cron:
                    # Add update check job
                    new_cron_line = f"0 8 * * 1 {update_script} >/dev/null 2>&1"
                    updated_cron = current_cron + "\n" + new_cron_line

                    # Install new crontab
                    process = subprocess.Popen(["crontab", "-"], stdin=subprocess.PIPE, text=True)
                    process.communicate(input=updated_cron)

                    if process.returncode == 0:
                        self._print_success("Update scheduler installed (weekly checks)")
                    else:
                        self._print_warning("Could not install cron job")
                else:
                    self._print_info("Update scheduler already installed")

            except subprocess.CalledProcessError:
                self._print_warning("Could not setup cron job (crontab not available)")

            self._print_success("Update checker script created")
            return True

        except Exception as e:
            self._print_error(f"Failed to setup update scheduler: {e}")
            return False

    def run_installation(self, mode: InstallationMode = InstallationMode.FULL) -> bool:
        """Run the complete installation process"""
        self._print_header()

        # Adapt installation based on detected environment
        adapted_mode = self._adapt_installation_for_environment(mode)
        if adapted_mode != mode:
            self._print_info(f"📋 Installation mode adapted: {mode.value} → {adapted_mode.value}")
            mode = adapted_mode

        success_count = 0
        total_steps = 0

        # Step 1: Detect existing installations
        self._print_section("Detecting existing Claude installations")
        existing_installations = self.detect_claude_installations()

        if existing_installations:
            self._print_info("Found existing installations:")
            for install in existing_installations:
                status = "✓ Working" if install.working else "✗ Not working"
                self._print_info(f"  {install.installation_type}: {install.binary_path} ({status})")

            # Use existing working installation if available
            working_installations = [inst for inst in existing_installations if inst.working]
            if working_installations and not self.auto_mode:
                if self._prompt_yes_no("Use existing working installation?"):
                    claude_binary = working_installations[0].binary_path
                else:
                    claude_binary = None
            elif working_installations:
                claude_binary = working_installations[0].binary_path
                self._print_info(f"Using existing installation: {claude_binary}")
            else:
                claude_binary = None
        else:
            claude_binary = None

        total_steps += 1
        if claude_binary or existing_installations:
            success_count += 1

        # Step 2: Install Claude if needed
        if not claude_binary:
            self._print_section("Installing Claude")

            npm_install_succeeded = False
            pip_install_succeeded = False

            # Try npm first
            if self.system_info.npm_available:
                self._print_info("Attempting npm installation...")
                if self.install_claude_npm():
                    npm_install_succeeded = True
                    self._print_success("npm installation completed successfully")

                    # Find the installed binary - try multiple detection methods
                    npm_installation = self._check_npm_claude()
                    if npm_installation and npm_installation.working:
                        claude_binary = npm_installation.binary_path
                        success_count += 1
                        self._print_success(f"npm installation verified: {claude_binary}")
                    else:
                        # npm installation succeeded but binary detection failed - try harder
                        self._print_warning("npm installation succeeded but binary not detected via standard method")

                        # Try alternative detection methods
                        npm_binary = self._find_npm_claude_alternative()
                        if npm_binary:
                            claude_binary = npm_binary
                            success_count += 1
                            self._print_success(f"npm installation found via alternative method: {claude_binary}")
                        else:
                            self._print_warning("Could not locate npm-installed binary - this may require manual verification")
                else:
                    self._print_warning("npm installation failed")

            # Only try pip if npm completely failed OR binary was not found
            if not claude_binary and not npm_install_succeeded and self.system_info.pip_available:
                self._print_info("Attempting pip installation...")
                if self.install_claude_pip():
                    pip_install_succeeded = True
                    self._print_success("pip installation completed successfully")

                    pip_installation = self._check_pip_claude()
                    if pip_installation and pip_installation.working:
                        claude_binary = pip_installation.binary_path
                        success_count += 1
                        self._print_success(f"pip installation verified: {claude_binary}")
                    else:
                        self._print_warning("pip installation succeeded but binary not detected")
                else:
                    self._print_warning("pip installation failed")

            total_steps += 1

        if not claude_binary:
            self._print_error("Failed to install or find working Claude binary")
            return False

        # Step 3: Create wrapper script
        total_steps += 1
        if self.create_wrapper_script(claude_binary):
            success_count += 1

        # Step 4: Update shell configuration
        total_steps += 1
        if self.update_shell_config():
            success_count += 1

        # Step 5: Install agents (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.install_agents_system():
                success_count += 1

        # Step 6: Install PICMCS v3.0 (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.install_picmcs_system():
                success_count += 1

        # Step 7: Install Docker database (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.install_docker_database():
                success_count += 1

        # Step 8: Install global agents bridge (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.install_global_agents_bridge():
                success_count += 1

        # Step 9: Setup learning system (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.setup_learning_system():
                success_count += 1

        # Step 10: Setup update scheduler (if in full mode)
        if mode == InstallationMode.FULL:
            total_steps += 1
            if self.setup_update_scheduler():
                success_count += 1

        # Step 11: Create launch script
        total_steps += 1
        if self.create_launch_script():
            success_count += 1

        # Report results
        self._print_section("Installation Results")
        self._print_info(f"Completed {success_count}/{total_steps} steps successfully")

        if success_count == total_steps:
            self._print_success("Installation completed successfully!")
            self._print_info("Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc)")
            self._print_info("Then test with: claude --help")
            return True
        else:
            self._print_warning("Installation completed with some issues")
            return False

    def _prompt_yes_no(self, question: str) -> bool:
        """Prompt user for yes/no answer"""
        if self.auto_mode:
            return True

        while True:
            try:
                answer = input(f"{question} [y/N]: ").strip().lower()
                if answer in ['y', 'yes']:
                    return True
                elif answer in ['n', 'no', '']:
                    return False
                else:
                    print("Please answer 'y' or 'n'")
            except KeyboardInterrupt:
                print("\nAborted by user")
                sys.exit(1)

    # Output formatting methods
    def _print_header(self):
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}Claude Enhanced Installer v2.0{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}Python-based installer with robust error handling{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.RESET}")
        print()

        # System info
        print(f"{Colors.BOLD}System Information:{Colors.RESET}")
        print(f"  Platform: {self.system_info.platform} ({self.system_info.architecture})")
        print(f"  Environment: {self._format_environment_info()}")
        print(f"  Shell: {self.system_info.shell.value}")
        print(f"  Python: {self.system_info.python_version}")
        print(f"  Node.js: {self.system_info.node_version or 'Not available'}")
        print(f"  npm: {'Available' if self.system_info.npm_available else 'Not available'}")
        print(f"  pip: {'Available' if self.system_info.pip_available else 'Not available'}")
        print(f"  Systemd: {'Available' if self.system_info.has_systemd else 'Not available'}")
        print(f"  Project root: {self.project_root}")
        print()

    def _print_section(self, title: str):
        print(f"{Colors.BOLD}{Colors.BLUE}{'─'*50}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.BLUE}{title}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.BLUE}{'─'*50}{Colors.RESET}")

    def _print_success(self, message: str):
        print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")

    def _print_error(self, message: str):
        print(f"{Colors.RED}✗ {message}{Colors.RESET}")

    def _print_warning(self, message: str):
        print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")

    def _print_info(self, message: str):
        print(f"{Colors.CYAN}ℹ {message}{Colors.RESET}")

    def _print_dim(self, message: str):
        print(f"{Colors.DIM}{message}{Colors.RESET}")

    def _format_environment_info(self) -> str:
        """Format environment information for display"""
        env_type = self.system_info.environment_type

        # Environment type with appropriate emoji
        env_icons = {
            EnvironmentType.HEADLESS: "🖥️  Headless Server",
            EnvironmentType.KDE: "🎨 KDE Plasma",
            EnvironmentType.GNOME: "🐧 GNOME Desktop",
            EnvironmentType.XFCE: "🖱️  XFCE Desktop",
            EnvironmentType.WAYLAND: "🌊 Wayland",
            EnvironmentType.X11: "🪟 X11",
            EnvironmentType.UNKNOWN_GUI: "❓ Unknown GUI"
        }

        env_display = env_icons.get(env_type, env_type.value.title())

        # Add display server info if available
        if self.system_info.display_server:
            env_display += f" ({self.system_info.display_server})"

        # Add session info if available
        if self.system_info.desktop_session and self.system_info.desktop_session != "unknown":
            env_display += f" [{self.system_info.desktop_session}]"

        return env_display

    def _adapt_installation_for_environment(self, mode: InstallationMode) -> InstallationMode:
        """Adapt installation mode based on detected environment"""
        env_type = self.system_info.environment_type

        # Environment-specific adaptations
        if env_type == EnvironmentType.HEADLESS:
            self._print_info("🖥️  Headless environment detected - optimizing for server deployment")
            # Force full mode for headless to ensure all server components
            if mode == InstallationMode.QUICK:
                self._print_info("📦 Upgrading to full installation for headless server optimization")
                return InstallationMode.FULL

        elif env_type in [EnvironmentType.KDE, EnvironmentType.GNOME, EnvironmentType.XFCE]:
            self._print_info(f"🎨 Desktop environment detected ({env_type.value.upper()}) - enabling GUI optimizations")

        elif env_type in [EnvironmentType.WAYLAND, EnvironmentType.X11]:
            self._print_info(f"🪟 Display server detected ({self.system_info.display_server}) - configuring graphics support")

        return mode

    def _get_environment_specific_packages(self) -> List[str]:
        """Get environment-specific package recommendations"""
        env_type = self.system_info.environment_type
        packages = []

        if env_type == EnvironmentType.HEADLESS:
            # Headless server packages
            packages.extend([
                "docker.io", "docker-compose",
                "python3-venv", "python3-full",
                "curl", "wget", "git",
                "postgresql-client"  # For database connectivity
            ])

        elif env_type in [EnvironmentType.KDE, EnvironmentType.GNOME, EnvironmentType.XFCE]:
            # Desktop environment packages
            packages.extend([
                "python3-venv", "python3-full",
                "git", "curl", "wget"
            ])

            # Environment-specific packages
            if env_type == EnvironmentType.KDE:
                packages.extend(["kde-baseapps", "konsole"])
            elif env_type == EnvironmentType.GNOME:
                packages.extend(["gnome-terminal", "nautilus"])
            elif env_type == EnvironmentType.XFCE:
                packages.extend(["xfce4-terminal", "thunar"])

        return packages


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Claude Enhanced Installer v2.0 - Python-based installer with robust error handling"
    )

    parser.add_argument(
        "--mode",
        choices=["quick", "full", "custom"],
        default="full",
        help="Installation mode (default: full)"
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    parser.add_argument(
        "--auto", "-a",
        action="store_true",
        help="Auto mode - no user prompts"
    )

    parser.add_argument(
        "--detect-only",
        action="store_true",
        help="Only detect existing installations, don't install"
    )

    parser.add_argument(
        "--check-updates",
        action="store_true",
        help="Check for available Claude Code updates"
    )

    parser.add_argument(
        "--auto-update",
        action="store_true",
        help="Perform automatic Claude Code update"
    )

    args = parser.parse_args()

    # Create installer instance
    installer = ClaudeEnhancedInstaller(
        verbose=args.verbose,
        auto_mode=args.auto
    )

    try:
        if args.detect_only:
            # Just detect and report
            installer._print_header()
            installations = installer.detect_claude_installations()

            if installations:
                print(f"{Colors.BOLD}Found {len(installations)} Claude installation(s):{Colors.RESET}")
                for i, install in enumerate(installations, 1):
                    status = "✓ Working" if install.working else "✗ Not working"
                    print(f"  {i}. {install.installation_type}: {install.binary_path}")
                    print(f"     Version: {install.version or 'Unknown'}")
                    print(f"     Status: {status}")
                    if install.details:
                        for key, value in install.details.items():
                            print(f"     {key}: {value}")
                    print()
            else:
                print(f"{Colors.YELLOW}No Claude installations found{Colors.RESET}")

            return

        if args.check_updates:
            # Check for updates only
            installer._print_header()
            latest_version = installer.check_for_claude_updates()
            current_version = installer._get_current_claude_version()

            print(f"{Colors.BOLD}Claude Code Update Check:{Colors.RESET}")
            print(f"  Current Version: {current_version or 'Unknown'}")

            if latest_version:
                print(f"  Latest Version: {latest_version}")
                print(f"  {Colors.GREEN}✓ Update available!{Colors.RESET}")
                print(f"\nTo update run: python3 {sys.argv[0]} --auto-update")
            else:
                print(f"  {Colors.GREEN}✓ Up to date{Colors.RESET}")

            return

        if args.auto_update:
            # Perform auto-update
            installer._print_header()
            success = installer.auto_update_claude()
            sys.exit(0 if success else 1)

        # Run installation
        mode = InstallationMode(args.mode)
        success = installer.run_installation(mode)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Installation aborted by user{Colors.RESET}")
        sys.exit(1)
    except Exception as e:
        print(f"{Colors.RED}Installation failed with error: {e}{Colors.RESET}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()