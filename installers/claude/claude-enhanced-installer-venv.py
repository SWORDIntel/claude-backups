#!/usr/bin/env python3
"""
Claude Enhanced Installer with Virtual Environment Support v3.0
Handles PEP 668 externally-managed environments with proper venv setup
Integrates with PYTHON-INTERNAL, DIRECTOR, and PROJECTORCHESTRATOR agents
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import venv
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union


# Color codes for terminal output
class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

    @staticmethod
    def disable():
        Colors.BLUE = ''
        Colors.GREEN = ''
        Colors.YELLOW = ''
        Colors.RED = ''
        Colors.MAGENTA = ''
        Colors.CYAN = ''
        Colors.WHITE = ''
        Colors.BOLD = ''
        Colors.RESET = ''

def print_banner():
    """Print installation banner"""
    print("=" * 70)
    print(f"{Colors.BOLD}Claude Enhanced Installer with Virtual Environment v3.0{Colors.RESET}")
    print(f"Python venv-based installer with PEP 668 compliance")
    print(f"Integrated with Agent Orchestration System")
    print("=" * 70)
    print()

def print_header(text: str):
    """Print section header"""
    print(f"\n{Colors.CYAN}{'─' * 50}{Colors.RESET}")
    print(f"{Colors.BOLD}{text}{Colors.RESET}")
    print(f"{Colors.CYAN}{'─' * 50}{Colors.RESET}")

def print_info(text: str):
    """Print info message"""
    print(f"{Colors.BLUE}ℹ{Colors.RESET} {text}")

def print_success(text: str):
    """Print success message"""
    print(f"{Colors.GREEN}✓{Colors.RESET} {text}")

def print_warning(text: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠{Colors.RESET} {text}")

def print_error(text: str):
    """Print error message"""
    print(f"{Colors.RED}✗{Colors.RESET} {text}")

class ClaudeVenvInstaller:
    """Enhanced Claude installer with virtual environment support"""

    def __init__(self, args=None):
        self.args = args or argparse.Namespace()
        self.system_info = self.detect_system()
        self.venv_path = Path.home() / ".claude-venv"
        self.claude_binary = None
        self.venv_created = False
        self.project_root = Path.cwd()
        self.agent_count = 0
        self.python_files_count = 0

    def detect_system(self) -> Dict[str, Any]:
        """Detect system information"""
        info = {
            'platform': platform.system().lower(),
            'arch': platform.machine().lower(),
            'python_version': '.'.join(map(str, sys.version_info[:3])),
            'shell': os.environ.get('SHELL', 'unknown'),
            'has_npm': shutil.which('npm') is not None,
            'has_pip': shutil.which('pip3') is not None or shutil.which('pip') is not None,
            'has_nodejs': shutil.which('node') is not None,
            'has_sudo': shutil.which('sudo') is not None,
            'is_pep668': self.check_pep668_environment(),
            'home_dir': Path.home(),
            'project_root': Path.cwd()
        }

        # Get Node.js version if available
        if info['has_nodejs']:
            try:
                result = subprocess.run(['node', '--version'],
                                      capture_output=True, text=True, timeout=5)
                info['node_version'] = result.stdout.strip().lstrip('v')
            except:
                info['node_version'] = 'unknown'

        return info

    def check_pep668_environment(self) -> bool:
        """Check if system has PEP 668 externally-managed environment"""
        try:
            # Try to detect PEP 668 by checking for EXTERNALLY-MANAGED file
            python_version = '.'.join(map(str, sys.version_info[:2]))
            externally_managed_paths = [
                Path(f'/usr/lib/python{python_version}/EXTERNALLY-MANAGED'),
                Path('/usr/lib/python3.11/EXTERNALLY-MANAGED'),
                Path('/usr/lib/python3.10/EXTERNALLY-MANAGED'),
                Path('/usr/lib/python3.9/EXTERNALLY-MANAGED'),
                Path('/usr/lib/python3.12/EXTERNALLY-MANAGED'),
            ]

            for path in externally_managed_paths:
                if path.exists():
                    return True

            # Also check by trying a pip install command
            result = subprocess.run(
                ['pip3', 'install', '--dry-run', 'pip'],
                capture_output=True, text=True, timeout=5
            )
            return 'externally-managed-environment' in result.stderr
        except:
            return False

    def print_system_info(self):
        """Print system information"""
        print(f"{Colors.BOLD}System Information:{Colors.RESET}")
        print(f"  Platform: {self.system_info['platform']} ({self.system_info['arch']})")
        print(f"  Shell: {os.path.basename(self.system_info['shell'])}")
        print(f"  Python: {self.system_info['python_version']}")

        if self.system_info['has_nodejs']:
            print(f"  Node.js: {self.system_info['node_version']}")

        print(f"  npm: {'Available' if self.system_info['has_npm'] else 'Not found'}")
        print(f"  pip: {'Available' if self.system_info['has_pip'] else 'Not found'}")
        print(f"  PEP 668: {'Yes (venv required)' if self.system_info['is_pep668'] else 'No'}")
        print(f"  Virtual env: {self.venv_path}")
        print(f"  Project root: {self.project_root}")
        print()

    def create_virtual_environment(self) -> bool:
        """Create and setup virtual environment"""
        print_header("Setting up Python virtual environment")

        try:
            # Check if venv already exists
            if self.venv_path.exists() and not getattr(self.args, 'recreate_venv', False):
                print_info(f"Virtual environment already exists at {self.venv_path}")

                # Verify it's valid
                pip_path = self.venv_path / "bin" / "pip"
                if not pip_path.exists():
                    print_warning("Existing venv appears corrupted, recreating...")
                    shutil.rmtree(self.venv_path)
                else:
                    self.venv_created = True
                    print_success("Using existing virtual environment")
                    return True

            # Remove old venv if recreating
            if self.venv_path.exists() and getattr(self.args, 'recreate_venv', False):
                print_info("Removing existing virtual environment...")
                shutil.rmtree(self.venv_path)

            # Create new virtual environment
            print_info(f"Creating virtual environment at {self.venv_path}")
            venv.create(self.venv_path, with_pip=True, clear=True, symlinks=True)

            # Verify creation
            pip_path = self.venv_path / "bin" / "pip"
            if not pip_path.exists():
                print_error("Failed to create virtual environment")
                return False

            # Upgrade pip in the venv
            print_info("Upgrading pip in virtual environment...")
            result = subprocess.run(
                [str(pip_path), "install", "--upgrade", "pip", "setuptools", "wheel"],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode != 0:
                print_warning("Failed to upgrade pip, continuing anyway...")

            self.venv_created = True
            print_success("Virtual environment created successfully")
            return True

        except Exception as e:
            print_error(f"Failed to create virtual environment: {e}")
            return False

    def install_claude_npm_global(self) -> bool:
        """Install Claude via npm globally"""
        if not self.system_info['has_npm']:
            print_warning("npm not available")
            return False

        print_header("Installing Claude Code via npm")

        # Try different npm installation approaches
        commands = [
            ['npm', 'install', '-g', '@anthropic-ai/claude-code'],
            ['sudo', 'npm', 'install', '-g', '@anthropic-ai/claude-code']
        ]

        for cmd in commands:
            try:
                # Skip sudo if not available
                if cmd[0] == 'sudo' and not self.system_info['has_sudo']:
                    continue

                print_info(f"Trying: {' '.join(cmd)}")
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=120
                )

                if result.returncode == 0:
                    print_success("npm installation successful")

                    # Find the installed binary
                    for name in ['claude', 'claude-code']:
                        binary = shutil.which(name)
                        if binary:
                            self.claude_binary = Path(binary)
                            print_success(f"Found Claude binary: {binary}")
                            return True
                else:
                    # Check if it's a permissions issue
                    if 'EACCES' in result.stderr:
                        print_warning(f"Permission denied, trying with sudo...")
                    else:
                        print_warning(f"Installation failed: {result.stderr[:200]}")

            except subprocess.TimeoutExpired:
                print_warning("Installation timed out")
            except Exception as e:
                print_warning(f"Installation error: {e}")

        return False

    def create_wrapper_script(self) -> bool:
        """Create wrapper script for Claude"""
        if not self.claude_binary:
            print_warning("No Claude binary found to wrap")
            return False

        print_header("Creating wrapper scripts")

        # Ensure .local/bin exists
        local_bin = Path.home() / ".local" / "bin"
        local_bin.mkdir(parents=True, exist_ok=True)

        wrapper_path = local_bin / "claude"

        # Create wrapper content
        if self.venv_created:
            # Include venv activation
            wrapper_content = f"""#!/bin/bash
# Claude wrapper script with automatic venv activation
# Generated by claude-enhanced-installer-venv.py

# Activate virtual environment if needed
if [ -z "$VIRTUAL_ENV" ] || [ "$VIRTUAL_ENV" != "{self.venv_path}" ]; then
    source "{self.venv_path}/bin/activate" 2>/dev/null
fi

# Execute Claude with all arguments
exec "{self.claude_binary}" "$@"
"""
        else:
            # Simple wrapper without venv
            wrapper_content = f"""#!/bin/bash
# Claude wrapper script
# Generated by claude-enhanced-installer-venv.py

# Execute Claude with all arguments
exec "{self.claude_binary}" "$@"
"""

        try:
            wrapper_path.write_text(wrapper_content)
            wrapper_path.chmod(0o755)
            print_success(f"Created wrapper script: {wrapper_path}")

            # Create symlinks for alternative names
            for name in ['claude-code', 'claude-cli']:
                link_path = local_bin / name
                if link_path.exists() or link_path.is_symlink():
                    link_path.unlink()
                link_path.symlink_to(wrapper_path)
                print_success(f"Created symlink: {link_path} -> claude")

            return True

        except Exception as e:
            print_error(f"Failed to create wrapper: {e}")
            return False

    def install_agent_system(self) -> bool:
        """Install the agent orchestration system"""
        print_header("Installing Agent Orchestration System")

        agents_dir = self.project_root / "agents"
        if not agents_dir.exists():
            print_warning("agents/ directory not found in project root")
            return False

        # Count agents
        agent_files = list(agents_dir.glob("*.md"))
        self.agent_count = len(agent_files)
        print_info(f"Found {self.agent_count} agents including:")

        # Show key agents
        key_agents = ['DIRECTOR.md', 'PROJECTORCHESTRATOR.md', 'PYTHON-INTERNAL.md']
        for agent in key_agents:
            if (agents_dir / agent).exists():
                print_success(f"  ✓ {agent}")

        # Install Python orchestration files
        python_src = agents_dir / "src" / "python"
        if python_src.exists():
            python_files = list(python_src.glob("*.py"))
            self.python_files_count = len(python_files)
            print_info(f"Found {self.python_files_count} Python orchestration files")

            # Install requirements if they exist and venv is created
            requirements_files = [
                python_src / "requirements.txt",
                self.project_root / "requirements.txt",
                agents_dir / "requirements.txt"
            ]

            if self.venv_created:
                pip_path = self.venv_path / "bin" / "pip"

                for req_file in requirements_files:
                    if req_file.exists():
                        print_info(f"Installing dependencies from {req_file.name}...")
                        try:
                            result = subprocess.run(
                                [str(pip_path), "install", "-r", str(req_file)],
                                capture_output=True, text=True, timeout=120
                            )
                            if result.returncode == 0:
                                print_success(f"Dependencies installed from {req_file.name}")
                            else:
                                print_warning(f"Some dependencies failed: {result.stderr[:200]}")
                        except Exception as e:
                            print_warning(f"Failed to install dependencies: {e}")

        # Copy CLAUDE.md if it exists
        claude_md = self.project_root / "CLAUDE.md"
        if claude_md.exists():
            target = Path.home() / ".claude" / "CLAUDE.md"
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(claude_md, target)
            print_success("Copied CLAUDE.md configuration")

        print_success(f"Agent system ready ({self.agent_count} agents, {self.python_files_count} Python files)")
        return True

    def update_shell_config(self) -> bool:
        """Update shell configuration"""
        print_header("Updating shell configuration")

        shell = os.path.basename(self.system_info['shell'])

        # Determine config files to update
        config_files = []
        if 'bash' in shell:
            config_files = [Path.home() / '.bashrc']
        elif 'zsh' in shell:
            config_files = [Path.home() / '.zshrc']
        elif 'fish' in shell:
            config_files = [Path.home() / '.config' / 'fish' / 'config.fish']
        else:
            config_files = [Path.home() / '.profile']

        updated = False
        for config_path in config_files:
            if not config_path.exists():
                continue

            try:
                content = config_path.read_text()

                # Check if already configured
                if 'CLAUDE_VENV_PATH' in content or '/.local/bin' in content:
                    print_info(f"{config_path.name} already configured")
                    continue

                # Add configuration
                addon = f"""

# Claude Enhanced Configuration (added {datetime.now().strftime('%Y-%m-%d')})
export CLAUDE_VENV_PATH="{self.venv_path}"
export CLAUDE_PROJECT_ROOT="{self.project_root}"
export PATH="$HOME/.local/bin:$PATH"

# Quick alias to activate Claude venv
alias claude-activate="source {self.venv_path}/bin/activate"
"""

                config_path.write_text(content + addon)
                print_success(f"Updated {config_path.name}")
                updated = True

            except Exception as e:
                print_warning(f"Failed to update {config_path.name}: {e}")

        return updated

    def test_installation(self) -> bool:
        """Test the Claude installation"""
        print_header("Testing installation")

        test_commands = [
            Path.home() / ".local" / "bin" / "claude",
            self.claude_binary
        ]

        for cmd in test_commands:
            if cmd and cmd.exists():
                try:
                    result = subprocess.run(
                        [str(cmd), "--version"],
                        capture_output=True, text=True, timeout=10
                    )
                    if result.returncode == 0 or "claude" in result.stdout.lower():
                        print_success(f"Claude is working: {cmd}")
                        return True
                except Exception as e:
                    print_warning(f"Test failed for {cmd}: {e}")

        return False

    def print_summary(self):
        """Print installation summary"""
        print("\n" + "=" * 70)
        print(f"{Colors.BOLD}Installation Summary{Colors.RESET}")
        print("=" * 70)

        if self.claude_binary:
            print(f"{Colors.GREEN}✓ Installation successful!{Colors.RESET}\n")
            print(f"Claude binary: {self.claude_binary}")

            if self.venv_created:
                print(f"Virtual environment: {self.venv_path}")

            print(f"Wrapper script: {Path.home() / '.local' / 'bin' / 'claude'}")

            if self.agent_count > 0:
                print(f"\nAgent System:")
                print(f"  Agents: {self.agent_count}")
                print(f"  Python files: {self.python_files_count}")
                print(f"  Key agents: DIRECTOR, PROJECTORCHESTRATOR, PYTHON-INTERNAL")

            print(f"\n{Colors.BOLD}Next steps:{Colors.RESET}")
            print("1. Restart your terminal or run:")
            print(f"   {Colors.CYAN}source ~/.bashrc{Colors.RESET}")
            print("\n2. Test Claude:")
            print(f"   {Colors.CYAN}claude --version{Colors.RESET}")

            if self.venv_created:
                print("\n3. The virtual environment activates automatically when using claude")
                print("   Or manually activate with:")
                print(f"   {Colors.CYAN}claude-activate{Colors.RESET}")
        else:
            print(f"{Colors.RED}✗ Installation incomplete{Colors.RESET}\n")
            print("Claude was not fully installed. Please try:")
            print("\n1. Ensure Node.js and npm are installed:")
            print(f"   {Colors.CYAN}sudo apt-get update && sudo apt-get install nodejs npm{Colors.RESET}")
            print("\n2. Run the installer again:")
            print(f"   {Colors.CYAN}python3 claude-enhanced-installer-venv.py{Colors.RESET}")

        print("=" * 70)

    def run(self) -> bool:
        """Run the complete installation process"""
        print_banner()
        self.print_system_info()

        success = False

        # Handle PEP 668 environment
        if self.system_info['is_pep668']:
            print_info("PEP 668 environment detected - virtual environment will be created")
            if not self.create_virtual_environment():
                print_error("Failed to create virtual environment")
                # Continue with npm installation anyway

        # Try npm installation
        if self.install_claude_npm_global():
            success = True
        else:
            print_warning("npm installation failed")

            # Create venv if not already created
            if not self.venv_created:
                print_info("Attempting virtual environment setup as fallback...")
                self.create_virtual_environment()

        # Create wrapper if we have a binary
        if self.claude_binary:
            self.create_wrapper_script()
            success = True

        # Install agent system
        self.install_agent_system()

        # Update shell config
        self.update_shell_config()

        # Test installation
        if success:
            self.test_installation()

        # Print summary
        self.print_summary()

        return success

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Claude Enhanced Installer with Virtual Environment Support"
    )
    parser.add_argument('--force', action='store_true',
                       help='Force reinstallation')
    parser.add_argument('--recreate-venv', action='store_true',
                       help='Recreate virtual environment')
    parser.add_argument('--no-color', action='store_true',
                       help='Disable colored output')
    parser.add_argument('--skip-npm', action='store_true',
                       help='Skip npm installation')

    args = parser.parse_args()

    if args.no_color:
        Colors.disable()

    installer = ClaudeVenvInstaller(args)

    try:
        success = installer.run()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\nInstallation cancelled")
        sys.exit(130)
    except Exception as e:
        print_error(f"Installation error: {e}")
        import traceback
        if '--debug' in sys.argv:
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()