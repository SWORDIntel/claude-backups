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
        """Detect the Claude project root directory"""
        current = Path.cwd()

        # Check current directory first
        if (current / "agents").exists() and (current / "CLAUDE.md").exists():
            return current

        # Check common locations
        common_locations = [
            Path.home() / "Documents" / "Claude",
            Path.home() / "claude-backups",
            Path.home() / "Downloads" / "claude-backups"
        ]

        for location in common_locations:
            if location.exists() and (location / "agents").exists():
                return location

        # Default to current directory
        return current

    def _gather_system_info(self) -> SystemInfo:
        """Gather comprehensive system information"""
        shell_type, shell_configs = self._detect_shell()

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
            user_name=os.environ.get("USER", "unknown")
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
        """Install Claude via pip (if available)"""
        self._print_section("Installing Claude via pip")

        if not self.system_info.pip_available:
            self._print_error("pip is not available")
            return False

        try:
            pip_cmd = "pip3" if shutil.which("pip3") else "pip"

            # Try user installation first, then global
            install_strategies = [
                [pip_cmd, "install", "--user", "claude-code"],
                [pip_cmd, "install", "claude-code"]
            ]

            if self.system_info.has_sudo:
                install_strategies.append(["sudo", pip_cmd, "install", "claude-code"])

            for strategy in install_strategies:
                try:
                    self._print_info(f"Trying: {' '.join(strategy)}")
                    self._run_command(strategy, timeout=300)
                    self._print_success("pip installation successful")
                    return True
                except subprocess.CalledProcessError:
                    continue

            self._print_error("All pip installation strategies failed")
            return False

        except Exception as e:
            self._print_error(f"pip installation failed: {e}")
            return False

    def create_wrapper_script(self, claude_binary: Path) -> bool:
        """Create robust wrapper script avoiding recursion issues"""
        self._print_section("Creating wrapper script")

        try:
            wrapper_path = self.local_bin / "claude"

            # Generate wrapper script based on shell type
            if self.system_info.shell == ShellType.ZSH:
                wrapper_content = self._generate_zsh_wrapper(claude_binary)
            else:
                wrapper_content = self._generate_bash_wrapper(claude_binary)

            # Write wrapper script
            wrapper_path.write_text(wrapper_content)
            wrapper_path.chmod(0o755)

            # Test wrapper
            if self._test_wrapper(wrapper_path):
                self._print_success(f"Wrapper created at {wrapper_path}")
                return True
            else:
                self._print_error("Wrapper test failed")
                return False

        except Exception as e:
            self._print_error(f"Failed to create wrapper: {e}")
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
        """Install the agent system"""
        self._print_section("Installing agent system")

        try:
            agents_source = self.project_root / "agents"
            agents_target = self.system_info.home_dir / "agents"

            if not agents_source.exists():
                self._print_warning(f"Agents source directory not found: {agents_source}")
                return False

            # Create target directory
            agents_target.mkdir(exist_ok=True)

            # Copy agent files
            for agent_file in agents_source.glob("*.md"):
                if agent_file.name != "Template.md":  # Skip template
                    target_file = agents_target / agent_file.name
                    shutil.copy2(agent_file, target_file)

            # Copy source directories if they exist
            for source_dir in ["src", "docs", "tools"]:
                source_path = agents_source / source_dir
                target_path = agents_target / source_dir

                if source_path.exists():
                    if target_path.exists():
                        shutil.rmtree(target_path)
                    shutil.copytree(source_path, target_path)

            self._print_success(f"Agent system installed to {agents_target}")
            return True

        except Exception as e:
            self._print_error(f"Failed to install agent system: {e}")
            return False

    def create_launch_script(self) -> bool:
        """Create convenient launch script"""
        self._print_section("Creating launch script")

        try:
            launch_script = self.local_bin / "claude-enhanced"

            script_content = f'''#!/bin/bash
# Claude Enhanced Launcher
# Provides enhanced functionality and error handling

# Set up environment
export CLAUDE_ENHANCED=true
export CLAUDE_PROJECT_ROOT="{self.project_root}"

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

    def run_installation(self, mode: InstallationMode = InstallationMode.FULL) -> bool:
        """Run the complete installation process"""
        self._print_header()

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

            # Try npm first, then pip
            if self.system_info.npm_available:
                if self.install_claude_npm():
                    # Find the installed binary
                    npm_installation = self._check_npm_claude()
                    if npm_installation and npm_installation.working:
                        claude_binary = npm_installation.binary_path
                        success_count += 1

            if not claude_binary and self.system_info.pip_available:
                if self.install_claude_pip():
                    pip_installation = self._check_pip_claude()
                    if pip_installation and pip_installation.working:
                        claude_binary = pip_installation.binary_path
                        success_count += 1

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

        # Step 7: Create launch script
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
        print(f"  Shell: {self.system_info.shell.value}")
        print(f"  Python: {self.system_info.python_version}")
        print(f"  Node.js: {self.system_info.node_version or 'Not available'}")
        print(f"  npm: {'Available' if self.system_info.npm_available else 'Not available'}")
        print(f"  pip: {'Available' if self.system_info.pip_available else 'Not available'}")
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