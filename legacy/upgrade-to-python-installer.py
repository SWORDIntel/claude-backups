#!/usr/bin/env python3
"""
Claude Enhanced Upgrade System v1.0
Comprehensive upgrade system for all Claude modules and components
Handles Claude Code, Python components, wrappers, agents, learning system, and OpenVINO
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from enum import Enum
from dataclasses import dataclass


class UpgradeModule(Enum):
    """Available modules for upgrade"""
    CLAUDE_CODE = "claude-code"
    PYTHON_INSTALLER = "python-installer"
    WRAPPER_SYSTEM = "wrapper-system"
    AGENT_DEFINITIONS = "agent-definitions"
    LEARNING_SYSTEM = "learning-system"
    OPENVINO_RUNTIME = "openvino-runtime"
    DATABASE_SCHEMA = "database-schema"
    ALL = "all"


@dataclass
class ComponentInfo:
    """Information about an installed component"""
    name: str
    current_version: Optional[str]
    latest_version: Optional[str]
    path: Optional[Path]
    is_installed: bool
    needs_upgrade: bool
    upgrade_method: str


class ClaudeUpgradeSystem:
    """Comprehensive upgrade system for Claude installation"""

    def __init__(self, verbose: bool = False, dry_run: bool = False):
        self.verbose = verbose
        self.dry_run = dry_run
        self.project_root = self._detect_project_root()
        self.backup_dir = Path.home() / ".config" / "claude" / "upgrade_backup"
        self.upgrade_log = []

        # Version information
        self.current_versions = {}
        self.available_versions = {}

        # Initialize directories
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    def _detect_project_root(self) -> Path:
        """Detect project root directory"""
        current = Path.cwd()
        if (current / "agents").exists() and (current / "CLAUDE.md").exists():
            return current

        # Check for common locations
        common_locations = [
            Path.home() / "Documents" / "Claude",
            Path.home() / "claude-backups",
            Path.home() / "Downloads" / "claude-backups"
        ]

        for location in common_locations:
            if location.exists() and (location / "agents").exists():
                return location

        return current

    def _log_action(self, action: str, status: str = "INFO", details: str = ""):
        """Log upgrade actions"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {status}: {action}"
        if details:
            log_entry += f" - {details}"

        self.upgrade_log.append(log_entry)
        if self.verbose:
            print(log_entry)

    def _run_command(self, cmd: List[str], capture_output: bool = True, timeout: int = 300) -> Tuple[bool, str, str]:
        """Run command with error handling"""
        try:
            self._log_action(f"Running: {' '.join(cmd)}")

            if self.dry_run:
                self._log_action("DRY RUN: Command would be executed", "DRY_RUN")
                return True, "dry-run-output", ""

            result = subprocess.run(
                cmd,
                capture_output=capture_output,
                text=True,
                timeout=timeout,
                cwd=self.project_root
            )

            success = result.returncode == 0
            return success, result.stdout, result.stderr

        except subprocess.TimeoutExpired:
            self._log_action(f"Command timed out after {timeout}s", "ERROR")
            return False, "", "Command timed out"
        except Exception as e:
            self._log_action(f"Command failed: {e}", "ERROR")
            return False, "", str(e)

    def _print_info(self, message: str):
        print(f"ℹ {message}")

    def _print_success(self, message: str):
        print(f"✓ {message}")

    def _print_warning(self, message: str):
        print(f"⚠ {message}")

    def _print_error(self, message: str):
        print(f"✗ {message}")

    def detect_current_versions(self) -> Dict[str, ComponentInfo]:
        """Detect current versions of all components"""
        components = {}

        # Claude Code
        claude_path = shutil.which("claude")
        if claude_path:
            success, stdout, stderr = self._run_command(["claude", "--version"])
            version = None
            if success and "Claude Code" in stdout:
                # Extract version from output
                version_match = re.search(r'v?(\d+\.\d+\.\d+)', stdout)
                if version_match:
                    version = version_match.group(1)

            components["claude-code"] = ComponentInfo(
                name="Claude Code",
                current_version=version,
                latest_version=None,  # Will be fetched later
                path=Path(claude_path) if claude_path else None,
                is_installed=bool(claude_path),
                needs_upgrade=False,  # Will be determined later
                upgrade_method="npm"
            )

        # Python Installer
        python_installer = self.project_root / "claude-enhanced-installer.py"
        components["python-installer"] = ComponentInfo(
            name="Python Installer",
            current_version="2.0" if python_installer.exists() else None,
            latest_version="2.0",
            path=python_installer if python_installer.exists() else None,
            is_installed=python_installer.exists(),
            needs_upgrade=False,
            upgrade_method="git"
        )

        # Wrapper System
        wrapper_path = Path.home() / ".local" / "bin" / "claude"
        wrapper_version = None
        if wrapper_path.exists():
            try:
                content = wrapper_path.read_text()
                if "Enhanced Installer v2.0" in content:
                    wrapper_version = "2.0"
                elif "claude-wrapper-ultimate" in content:
                    wrapper_version = "13.1"
            except:
                pass

        components["wrapper-system"] = ComponentInfo(
            name="Wrapper System",
            current_version=wrapper_version,
            latest_version="2.0",
            path=wrapper_path if wrapper_path.exists() else None,
            is_installed=wrapper_path.exists(),
            needs_upgrade=wrapper_version != "2.0",
            upgrade_method="python-installer"
        )

        # Agent Definitions
        agents_dir = self.project_root / "agents"
        agent_count = 0
        if agents_dir.exists():
            agent_count = len(list(agents_dir.glob("*.md"))) - 1  # Exclude Template.md

        components["agent-definitions"] = ComponentInfo(
            name="Agent Definitions",
            current_version=f"{agent_count} agents",
            latest_version="89 agents",
            path=agents_dir if agents_dir.exists() else None,
            is_installed=agents_dir.exists(),
            needs_upgrade=agent_count < 89,
            upgrade_method="git"
        )

        # Learning System
        learning_system = self.project_root / "integrated_learning_setup.py"
        components["learning-system"] = ComponentInfo(
            name="Learning System",
            current_version="5.0" if learning_system.exists() else None,
            latest_version="5.0",
            path=learning_system if learning_system.exists() else None,
            is_installed=learning_system.exists(),
            needs_upgrade=False,
            upgrade_method="git"
        )

        # OpenVINO Runtime
        openvino_path = Path("/opt/openvino")
        openvino_version = None
        if openvino_path.exists():
            try:
                # Try to get version from setupvars.sh
                setupvars = openvino_path / "setupvars.sh"
                if setupvars.exists():
                    content = setupvars.read_text()
                    version_match = re.search(r'2025\.(\d+\.\d+)', content)
                    if version_match:
                        openvino_version = f"2025.{version_match.group(1)}"
            except:
                openvino_version = "installed"

        components["openvino-runtime"] = ComponentInfo(
            name="OpenVINO Runtime",
            current_version=openvino_version,
            latest_version="2025.4.0",
            path=openvino_path if openvino_path.exists() else None,
            is_installed=openvino_path.exists(),
            needs_upgrade=openvino_version != "2025.4.0",
            upgrade_method="manual"
        )

        # Database Schema
        db_schema = self.project_root / "database" / "sql" / "auth_db_setup.sql"
        components["database-schema"] = ComponentInfo(
            name="Database Schema",
            current_version="PostgreSQL 16/17" if db_schema.exists() else None,
            latest_version="PostgreSQL 16/17",
            path=db_schema if db_schema.exists() else None,
            is_installed=db_schema.exists(),
            needs_upgrade=False,
            upgrade_method="git"
        )

        self.current_versions = components
        return components

    def create_backup(self, components: List[str] = None) -> bool:
        """Create comprehensive backup of current installation"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = self.backup_dir / f"backup_{timestamp}"
            backup_path.mkdir(parents=True, exist_ok=True)

            self._log_action(f"Creating backup at {backup_path}")

            # Backup wrapper scripts
            wrapper_paths = [
                Path.home() / ".local" / "bin" / "claude",
                Path.home() / ".local" / "bin" / "claude-enhanced"
            ]

            for wrapper_path in wrapper_paths:
                if wrapper_path.exists():
                    backup_file = backup_path / wrapper_path.name
                    shutil.copy2(wrapper_path, backup_file)
                    self._log_action(f"Backed up {wrapper_path}")

            # Backup config files
            config_dirs = [
                Path.home() / ".config" / "claude",
                Path.home() / ".claude"
            ]

            for config_dir in config_dirs:
                if config_dir.exists():
                    backup_config = backup_path / config_dir.name
                    shutil.copytree(config_dir, backup_config, dirs_exist_ok=True)
                    self._log_action(f"Backed up {config_dir}")

            # Backup shell configs
            shell_configs = [".bashrc", ".zshrc", ".profile"]
            for config_name in shell_configs:
                config_path = Path.home() / config_name
                if config_path.exists():
                    backup_file = backup_path / config_name
                    shutil.copy2(config_path, backup_file)

            # Save component versions
            versions_file = backup_path / "component_versions.json"
            with open(versions_file, 'w') as f:
                json.dump({
                    name: {
                        "current_version": comp.current_version,
                        "path": str(comp.path) if comp.path else None,
                        "is_installed": comp.is_installed
                    }
                    for name, comp in self.current_versions.items()
                }, f, indent=2)

            self._log_action("Backup completed successfully", "SUCCESS")
            return True

        except Exception as e:
            self._log_action(f"Backup failed: {e}", "ERROR")
            return False

    def upgrade_claude_code(self) -> bool:
        """Upgrade Claude Code via npm"""
        self._log_action("Upgrading Claude Code")

        # Try different upgrade methods
        upgrade_methods = [
            ["npm", "update", "-g", "@anthropic-ai/claude-code"],
            ["npm", "install", "-g", "@anthropic-ai/claude-code@latest"],
            ["pip", "install", "--upgrade", "claude-code"]
        ]

        for method in upgrade_methods:
            self._log_action(f"Trying upgrade method: {' '.join(method)}")
            success, stdout, stderr = self._run_command(method)

            if success:
                self._log_action("Claude Code upgraded successfully", "SUCCESS")
                return True
            else:
                self._log_action(f"Method failed: {stderr}", "WARNING")

        self._log_action("All upgrade methods failed", "ERROR")
        return False

    def upgrade_python_installer(self) -> bool:
        """Upgrade Python installer components via git"""
        self._log_action("Upgrading Python installer components")

        try:
            # Pull latest changes
            success, stdout, stderr = self._run_command(["git", "pull", "origin", "main"])

            if not success:
                self._log_action(f"Git pull failed: {stderr}", "ERROR")
                return False

            # Check if Python installer files are present
            required_files = [
                "claude-enhanced-installer.py",
                "claude-python-installer.sh",
                "claude_installer_config.py",
                "claude_shell_integration.py"
            ]

            missing_files = []
            for file in required_files:
                if not (self.project_root / file).exists():
                    missing_files.append(file)

            if missing_files:
                self._log_action(f"Missing installer files: {missing_files}", "WARNING")

            self._log_action("Python installer components upgraded", "SUCCESS")
            return True

        except Exception as e:
            self._log_action(f"Python installer upgrade failed: {e}", "ERROR")
            return False

    def upgrade_wrapper_system(self) -> bool:
        """Upgrade wrapper system by running the Python installer"""
        self._log_action("Upgrading wrapper system")

        try:
            python_installer = self.project_root / "claude-enhanced-installer.py"

            if not python_installer.exists():
                self._log_action("Python installer not found", "ERROR")
                return False

            # Run installer in wrapper-only mode
            cmd = [sys.executable, str(python_installer), "--mode", "wrapper-only", "--auto"]
            if self.verbose:
                cmd.append("--verbose")

            success, stdout, stderr = self._run_command(cmd, timeout=600)

            if success:
                self._log_action("Wrapper system upgraded successfully", "SUCCESS")
                return True
            else:
                self._log_action(f"Wrapper upgrade failed: {stderr}", "ERROR")
                return False

        except Exception as e:
            self._log_action(f"Wrapper system upgrade failed: {e}", "ERROR")
            return False

    def upgrade_agent_definitions(self) -> bool:
        """Upgrade agent definitions via git"""
        self._log_action("Upgrading agent definitions")

        try:
            # Pull latest agent definitions
            success, stdout, stderr = self._run_command(["git", "pull", "origin", "main"])

            if not success:
                self._log_action(f"Git pull failed: {stderr}", "ERROR")
                return False

            # Count agents after upgrade
            agents_dir = self.project_root / "agents"
            if agents_dir.exists():
                agent_count = len(list(agents_dir.glob("*.md"))) - 1  # Exclude Template.md
                self._log_action(f"Agent definitions updated: {agent_count} agents available", "SUCCESS")
            else:
                self._log_action("Agents directory not found", "ERROR")
                return False

            return True

        except Exception as e:
            self._log_action(f"Agent definitions upgrade failed: {e}", "ERROR")
            return False

    def upgrade_learning_system(self) -> bool:
        """Upgrade learning system"""
        self._log_action("Upgrading learning system")

        try:
            # Pull latest learning system
            success, stdout, stderr = self._run_command(["git", "pull", "origin", "main"])

            if not success:
                self._log_action(f"Git pull failed: {stderr}", "ERROR")
                return False

            # Run learning system setup if available
            learning_setup = self.project_root / "integrated_learning_setup.py"
            if learning_setup.exists():
                cmd = [sys.executable, str(learning_setup), "--upgrade"]
                success, stdout, stderr = self._run_command(cmd, timeout=600)

                if success:
                    self._log_action("Learning system upgraded successfully", "SUCCESS")
                else:
                    self._log_action(f"Learning system setup failed: {stderr}", "WARNING")

            return True

        except Exception as e:
            self._log_action(f"Learning system upgrade failed: {e}", "ERROR")
            return False

    def upgrade_openvino_runtime(self) -> bool:
        """Upgrade OpenVINO runtime"""
        self._log_action("Upgrading OpenVINO runtime")

        self._log_action("OpenVINO upgrades require manual intervention", "WARNING")
        self._log_action("Please run the OpenVINO deployment script manually:", "INFO")
        self._log_action("sudo /opt/openvino/deploy-ai-enhanced-system.sh", "INFO")

        return True

    def upgrade_database_schema(self) -> bool:
        """Upgrade database schema"""
        self._log_action("Upgrading database schema")

        try:
            # Pull latest schema
            success, stdout, stderr = self._run_command(["git", "pull", "origin", "main"])

            if not success:
                self._log_action(f"Git pull failed: {stderr}", "ERROR")
                return False

            # Check for database migration scripts
            db_dir = self.project_root / "database"
            if db_dir.exists():
                migration_script = db_dir / "migrate_schema.sh"
                if migration_script.exists():
                    cmd = ["bash", str(migration_script)]
                    success, stdout, stderr = self._run_command(cmd, timeout=300)

                    if success:
                        self._log_action("Database schema migrated successfully", "SUCCESS")
                    else:
                        self._log_action(f"Schema migration failed: {stderr}", "WARNING")

            return True

        except Exception as e:
            self._log_action(f"Database schema upgrade failed: {e}", "ERROR")
            return False

    def upgrade_component(self, component_name: str) -> bool:
        """Upgrade a specific component"""
        upgrade_methods = {
            "claude-code": self.upgrade_claude_code,
            "python-installer": self.upgrade_python_installer,
            "wrapper-system": self.upgrade_wrapper_system,
            "agent-definitions": self.upgrade_agent_definitions,
            "learning-system": self.upgrade_learning_system,
            "openvino-runtime": self.upgrade_openvino_runtime,
            "database-schema": self.upgrade_database_schema
        }

        if component_name not in upgrade_methods:
            self._log_action(f"Unknown component: {component_name}", "ERROR")
            return False

        return upgrade_methods[component_name]()

    def run_full_upgrade(self, modules: List[str] = None, skip_backup: bool = False) -> bool:
        """Run complete upgrade process"""
        self._print_info("Claude Enhanced Upgrade System v1.0")
        self._print_info("=" * 50)

        # Step 1: Detect current versions
        self._print_info("Analyzing current installation...")
        components = self.detect_current_versions()

        print("\nCurrent Installation Status:")
        print("-" * 40)
        for name, comp in components.items():
            status = "✓ INSTALLED" if comp.is_installed else "✗ NOT INSTALLED"
            upgrade_status = " (NEEDS UPGRADE)" if comp.needs_upgrade else ""
            print(f"{comp.name}: {status}{upgrade_status}")
            if comp.current_version:
                print(f"  Current: {comp.current_version}")
            if comp.latest_version:
                print(f"  Latest:  {comp.latest_version}")
            print()

        # Determine which modules to upgrade
        if modules is None or "all" in modules:
            modules_to_upgrade = [name for name, comp in components.items()
                                 if comp.is_installed and comp.needs_upgrade]
            if not modules_to_upgrade:
                modules_to_upgrade = list(components.keys())
        else:
            modules_to_upgrade = [m for m in modules if m in components]

        if not modules_to_upgrade:
            self._print_info("No modules need upgrading")
            return True

        self._print_info(f"Modules to upgrade: {', '.join(modules_to_upgrade)}")

        # Step 2: Create backup
        if not skip_backup:
            self._print_info("Creating backup...")
            if not self.create_backup():
                if not self.dry_run:
                    response = input("Backup failed. Continue anyway? [y/N]: ")
                    if response.lower() != 'y':
                        return False

        # Step 3: Upgrade components
        upgrade_results = {}
        for module in modules_to_upgrade:
            self._print_info(f"Upgrading {module}...")
            result = self.upgrade_component(module)
            upgrade_results[module] = result

            if result:
                self._print_success(f"{module} upgraded successfully")
            else:
                self._print_error(f"{module} upgrade failed")

        # Step 4: Verify installation
        self._print_info("Verifying upgrades...")
        verification_results = {}

        # Test Claude command
        try:
            success, stdout, stderr = self._run_command(["claude", "--version"], timeout=10)
            verification_results["claude_command"] = success
            if success:
                self._print_success(f"Claude command working: {stdout.strip()[:50]}...")
            else:
                self._print_warning("Claude command verification failed")
        except:
            verification_results["claude_command"] = False
            self._print_warning("Could not verify Claude command")

        # Summary
        print("\nUpgrade Summary:")
        print("=" * 30)
        successful_upgrades = sum(1 for result in upgrade_results.values() if result)
        total_upgrades = len(upgrade_results)

        print(f"Successful upgrades: {successful_upgrades}/{total_upgrades}")

        for module, result in upgrade_results.items():
            status = "✓ SUCCESS" if result else "✗ FAILED"
            print(f"  {module}: {status}")

        print(f"\nUpgrade log saved with {len(self.upgrade_log)} entries")

        # Save upgrade log
        log_file = self.backup_dir / f"upgrade_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(log_file, 'w') as f:
            f.write('\n'.join(self.upgrade_log))
        print(f"Detailed log: {log_file}")

        print("\nRecommended next steps:")
        print("1. Restart your shell: source ~/.bashrc (or ~/.zshrc)")
        print("2. Test Claude: claude --help")
        print("3. Run Python installer if needed: ./claude-enhanced-installer.py")

        return successful_upgrades == total_upgrades

    def analyze_current_installation(self) -> dict:
        """Analyze the current installation state (legacy compatibility)"""
        components = self.detect_current_versions()

        # Convert to legacy format for compatibility
        analysis = {
            "shell_installer_found": (self.project_root / "claude-installer.sh").exists(),
            "python_installer_found": (self.project_root / "claude-enhanced-installer.py").exists(),
            "claude_binary_found": components.get("claude-code", {}).is_installed if "claude-code" in components else False,
            "wrapper_scripts": [],
            "config_files": [],
            "shell_configs_modified": []
        }

        # Check for wrapper scripts
        wrapper_locations = [
            Path.home() / ".local" / "bin" / "claude",
            Path.home() / ".local" / "bin" / "claude-enhanced",
            Path("/usr/local/bin/claude")
        ]

        for wrapper in wrapper_locations:
            if wrapper.exists():
                analysis["wrapper_scripts"].append(str(wrapper))

        # Check for config files
        config_locations = [
            Path.home() / ".config" / "claude",
            Path.home() / ".claude-home"
        ]

        for config in config_locations:
            if config.exists():
                analysis["config_files"].append(str(config))

        # Check for modified shell configs
        shell_configs = [
            Path.home() / ".bashrc",
            Path.home() / ".zshrc",
            Path.home() / ".profile"
        ]

        for config in shell_configs:
            if config.exists():
                try:
                    content = config.read_text()
                    if "claude" in content.lower() or ".local/bin" in content:
                        analysis["shell_configs_modified"].append(str(config))
                except:
                    pass

        return analysis


# Legacy InstallerUpgrader class for backward compatibility
class InstallerUpgrader(ClaudeUpgradeSystem):
    """Legacy class for backward compatibility"""

    def run_upgrade(self, mode: str = "full", auto: bool = False) -> bool:
        """Legacy upgrade method - redirects to new system"""
        return self.run_full_upgrade(modules=["python-installer", "wrapper-system"], skip_backup=False)


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Claude Enhanced Upgrade System v1.0",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Available modules:
  claude-code       - Claude Code binary (@anthropic-ai/claude-code)
  python-installer  - Python installer components
  wrapper-system    - Wrapper scripts and shell integration
  agent-definitions - Agent definition files
  learning-system   - ML learning system and database
  openvino-runtime  - OpenVINO AI runtime (manual intervention required)
  database-schema   - PostgreSQL database schema
  all               - All available modules

Examples:
  %(prog)s --upgrade-all                    # Upgrade everything
  %(prog)s --upgrade claude-code            # Upgrade only Claude Code
  %(prog)s --upgrade wrapper-system --dry-run  # Test wrapper upgrade
  %(prog)s --analyze-only                   # Show current versions
  %(prog)s --legacy --mode full             # Use legacy upgrade method
        """
    )

    # Main upgrade options
    upgrade_group = parser.add_mutually_exclusive_group(required=True)
    upgrade_group.add_argument(
        "--upgrade",
        metavar="MODULE",
        nargs="+",
        choices=["claude-code", "python-installer", "wrapper-system",
                "agent-definitions", "learning-system", "openvino-runtime",
                "database-schema", "all"],
        help="Upgrade specific modules"
    )
    upgrade_group.add_argument(
        "--upgrade-all",
        action="store_true",
        help="Upgrade all modules"
    )
    upgrade_group.add_argument(
        "--analyze-only",
        action="store_true",
        help="Only analyze current installation, don't upgrade"
    )
    upgrade_group.add_argument(
        "--legacy",
        action="store_true",
        help="Use legacy upgrade method (Python installer migration)"
    )

    # Options
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without executing"
    )
    parser.add_argument(
        "--skip-backup",
        action="store_true",
        help="Skip backup creation"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    # Legacy options
    parser.add_argument(
        "--mode",
        choices=["quick", "full", "custom"],
        default="full",
        help="Installation mode for legacy Python installer"
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Run in automatic mode (legacy)"
    )

    args = parser.parse_args()

    # Initialize upgrade system
    if args.legacy:
        upgrader = InstallerUpgrader(verbose=args.verbose)
    else:
        upgrader = ClaudeUpgradeSystem(verbose=args.verbose, dry_run=args.dry_run)

    # Handle different modes
    try:
        if args.analyze_only:
            print("Current Installation Analysis")
            print("=" * 40)

            if args.legacy:
                analysis = upgrader.analyze_current_installation()
                for key, value in analysis.items():
                    print(f"{key}: {value}")
            else:
                components = upgrader.detect_current_versions()
                for name, comp in components.items():
                    status = "✓ INSTALLED" if comp.is_installed else "✗ NOT INSTALLED"
                    upgrade_status = " (NEEDS UPGRADE)" if comp.needs_upgrade else ""
                    print(f"{comp.name}: {status}{upgrade_status}")
                    if comp.current_version:
                        print(f"  Current: {comp.current_version}")
                    if comp.latest_version:
                        print(f"  Latest:  {comp.latest_version}")
                    print()
            return

        elif args.legacy:
            success = upgrader.run_upgrade(args.mode, args.auto)
        elif args.upgrade_all:
            success = upgrader.run_full_upgrade(modules=["all"], skip_backup=args.skip_backup)
        else:
            success = upgrader.run_full_upgrade(modules=args.upgrade, skip_backup=args.skip_backup)

        sys.exit(0 if success else 1)

    except KeyboardInterrupt:
        print("\nUpgrade interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Upgrade failed: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()