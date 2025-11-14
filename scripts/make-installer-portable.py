#!/usr/bin/env python3
"""
Claude Installer Portability Enhancement Tool v1.0

Updates the claude-enhanced-installer.py to use dynamic path resolution
instead of hardcoded paths and project-specific patterns.
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple


class InstallerPortabilityEnhancer:
    """Enhances installer with portable path resolution"""

    def __init__(self, installer_path: Path):
        self.installer_path = installer_path
        self.backup_path = installer_path.with_suffix(".py.backup")
        self.changes_made = []

    def create_backup(self):
        """Create backup of original installer"""
        if not self.backup_path.exists():
            with open(self.installer_path, "r") as src, open(
                self.backup_path, "w"
            ) as dst:
                dst.write(src.read())
            print(f"Created backup: {self.backup_path}")

    def read_installer(self) -> str:
        """Read the installer content"""
        with open(self.installer_path, "r") as f:
            return f.read()

    def write_installer(self, content: str):
        """Write the updated installer content"""
        with open(self.installer_path, "w") as f:
            f.write(content)

    def enhance_project_detection(self, content: str) -> str:
        """Enhance project root detection to be more portable"""

        # Find the _detect_project_root method
        detect_method_pattern = (
            r"(def _detect_project_root\(self\) -> Path:.*?)(return current)"
        )

        new_detection_logic = '''def _detect_project_root(self) -> Path:
        """Detect the Claude project root directory using dynamic resolution"""
        # Import path resolver if available
        try:
            script_dir = Path(__file__).parent.resolve()
            path_resolver_locations = [
                script_dir / "scripts" / "claude_path_resolver.py",
                script_dir / "claude_path_resolver.py",
                script_dir.parent / "scripts" / "claude_path_resolver.py"
            ]

            for resolver_path in path_resolver_locations:
                if resolver_path.exists():
                    sys.path.insert(0, str(resolver_path.parent))
                    try:
                        from claude_path_resolver import get_path
                        project_root = get_path('project_root')
                        if project_root and project_root.exists():
                            return project_root
                    except ImportError:
                        pass
        except Exception:
            pass

        # Fallback to original detection logic
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
            "*/claude-*",
            "*/Claude",
            "*/Documents/Claude*",
            "*/Downloads/claude-*",
            "claude-*",
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

        # Default to current directory if nothing found'''

        if re.search(detect_method_pattern, content, re.DOTALL):
            content = re.sub(
                detect_method_pattern,
                new_detection_logic + r"\n        return current",
                content,
                flags=re.DOTALL,
            )
            self.changes_made.append(
                "Enhanced _detect_project_root method for better portability"
            )

        return content

    def remove_hardcoded_patterns(self, content: str) -> str:
        """Remove hardcoded project-specific patterns"""

        # Replace hardcoded project names with dynamic pattern
        patterns_to_replace = [
            (r'"claude-backups"', '"${project_name}"'),
            (r"'claude-backups'", "'${project_name}'"),
            (r"/claude-backups/", "/${project_name}/"),
            (r"claude-backups/", "${project_name}/"),
        ]

        # Add dynamic project name detection
        if '"*/claude-backups"' in content:
            content = content.replace('"*/claude-backups"', '"*/claude-*"')
            content = content.replace(
                '"*/Downloads/claude-backups"', '"*/Downloads/claude-*"'
            )
            content = content.replace('"claude-backups"', '"claude-*"')
            self.changes_made.append(
                "Replaced hardcoded 'claude-backups' with dynamic patterns"
            )

        # Replace hardcoded paths in search patterns
        hardcoded_search_replacements = [
            ("$HOME/claude-backups", "${project_root}"),
            ("$HOME/Downloads/claude-backups", "${project_root}"),
            ("$HOME/Documents/claude-backups", "${project_root}"),
        ]

        for old, new in hardcoded_search_replacements:
            if old in content:
                content = content.replace(old, new)
                self.changes_made.append(f"Replaced {old} with {new}")

        return content

    def enhance_path_configuration(self, content: str) -> str:
        """Enhance path configuration to use XDG base directories"""

        # Add XDG compliance to path setup
        xdg_enhancement = '''
        # Enhanced XDG-compliant path configuration
        xdg_config = Path(os.environ.get('XDG_CONFIG_HOME', self.system_info.home_dir / '.config'))
        xdg_data = Path(os.environ.get('XDG_DATA_HOME', self.system_info.home_dir / '.local' / 'share'))
        xdg_cache = Path(os.environ.get('XDG_CACHE_HOME', self.system_info.home_dir / '.cache'))

        # Installation paths with XDG compliance
        self.local_bin = self.system_info.home_dir / ".local" / "bin"
        self.config_dir = xdg_config / "claude"
        self.data_dir = xdg_data / "claude"
        self.cache_dir = xdg_cache / "claude"
        self.venv_dir = self.data_dir / "venv"
        self.log_dir = self.data_dir / "logs"'''

        # Find the existing path configuration section
        path_config_pattern = r"(# Installation paths.*?self\.log_dir = .*?logs.*?)"

        if re.search(path_config_pattern, content, re.DOTALL):
            content = re.sub(
                path_config_pattern, xdg_enhancement, content, flags=re.DOTALL
            )
            self.changes_made.append("Enhanced path configuration with XDG compliance")

        return content

    def add_path_resolver_integration(self, content: str) -> str:
        """Add path resolver integration to the installer"""

        # Check if path resolver integration already exists
        if "claude_path_resolver" in content:
            return content

        # Add import for path resolver at the top
        imports_pattern = r"(from typing import.*?\n)"

        path_resolver_import = """from typing import Dict, List, Optional, Tuple, Union

# Claude Path Resolver Integration
try:
    from scripts.claude_path_resolver import get_resolver, apply_to_environment
    PATH_RESOLVER_AVAILABLE = True
except ImportError:
    PATH_RESOLVER_AVAILABLE = False

"""

        content = re.sub(
            imports_pattern, path_resolver_import, content, flags=re.DOTALL
        )

        # Add path resolver initialization to __init__
        init_pattern = r"(def __init__\(self.*?\n)(.*?)(self\.project_root = self\._detect_project_root\(\))"

        if re.search(init_pattern, content, re.DOTALL):
            path_resolver_init = r"\1\2# Apply path resolver if available\n        if PATH_RESOLVER_AVAILABLE:\n            apply_to_environment()\n        \n        \3"
            content = re.sub(init_pattern, path_resolver_init, content, flags=re.DOTALL)
            self.changes_made.append("Added path resolver integration to __init__")

        return content

    def enhance_system_path_detection(self, content: str) -> str:
        """Enhance system path detection to be more robust"""

        # Find binary detection patterns and make them more portable
        binary_patterns = [
            (r"/usr/local/bin", "${system_bin_dir}"),
            (r"/usr/bin", "${fallback_bin_dir}"),
        ]

        for old_pattern, new_pattern in binary_patterns:
            content = content.replace(
                f'"{old_pattern}"', f'"${{CLAUDE_SYSTEM_BIN:-{old_pattern}}}"'
            )
            content = content.replace(
                f"'{old_pattern}'", f'"${{CLAUDE_SYSTEM_BIN:-{old_pattern}}}"'
            )

        # Add dynamic system path detection method
        if "_detect_system_paths" not in content:
            system_path_method = '''
    def _detect_system_paths(self) -> Tuple[Path, Optional[Path]]:
        """Detect appropriate system installation paths"""
        # User-writable paths
        user_bins = [
            self.system_info.home_dir / ".local" / "bin",
            self.system_info.home_dir / "bin"
        ]

        # System paths (if writable)
        system_bins = [
            Path("/usr/local/bin"),
            Path("/usr/bin"),
            Path("/bin")
        ]

        # Find first writable user path
        user_bin = None
        for bin_path in user_bins:
            bin_path.mkdir(parents=True, exist_ok=True)
            if os.access(bin_path, os.W_OK):
                user_bin = bin_path
                break

        if not user_bin:
            user_bin = user_bins[0]  # Default fallback

        # Find first writable system path
        system_bin = None
        for bin_path in system_bins:
            if bin_path.exists() and os.access(bin_path, os.W_OK):
                system_bin = bin_path
                break

        return user_bin, system_bin
'''
            # Insert the method before the main class ends
            class_end_pattern = r"(\n\nclass .*?:|\n\n\nclass .*?:|\n\ndef )"
            if re.search(class_end_pattern, content):
                content = re.sub(
                    class_end_pattern, system_path_method + r"\1", content, count=1
                )
                self.changes_made.append("Added _detect_system_paths method")

        return content

    def run_enhancement(self) -> bool:
        """Run the complete enhancement process"""
        print("Starting Claude Installer Portability Enhancement...")

        # Create backup
        self.create_backup()

        # Read current content
        content = self.read_installer()

        # Apply enhancements
        content = self.enhance_project_detection(content)
        content = self.remove_hardcoded_patterns(content)
        content = self.enhance_path_configuration(content)
        content = self.add_path_resolver_integration(content)
        content = self.enhance_system_path_detection(content)

        # Write enhanced content
        self.write_installer(content)

        # Report changes
        if self.changes_made:
            print(f"\nEnhancement completed! Changes made:")
            for change in self.changes_made:
                print(f"  ✓ {change}")
            print(f"\nBackup saved to: {self.backup_path}")
            return True
        else:
            print("No changes were necessary - installer already appears portable")
            return False


def main():
    """Main execution function"""
    if len(sys.argv) > 1:
        installer_path = Path(sys.argv[1])
    else:
        # Default to the installer in the same directory or parent
        script_dir = Path(__file__).parent
        installer_candidates = [
            script_dir.parent / "claude-enhanced-installer.py",
            script_dir / "claude-enhanced-installer.py",
            Path("claude-enhanced-installer.py"),
        ]

        installer_path = None
        for candidate in installer_candidates:
            if candidate.exists():
                installer_path = candidate
                break

        if not installer_path:
            print("Error: Could not find claude-enhanced-installer.py")
            print("Usage: python3 make-installer-portable.py [path_to_installer]")
            sys.exit(1)

    if not installer_path.exists():
        print(f"Error: Installer not found at {installer_path}")
        sys.exit(1)

    enhancer = InstallerPortabilityEnhancer(installer_path)
    success = enhancer.run_enhancement()

    if success:
        print(f"\n🚀 Installer enhanced for portability!")
        print(f"📁 Enhanced installer: {installer_path}")
        print("\nNext steps:")
        print("1. Test the enhanced installer")
        print("2. Verify it works on different systems/users")
        print("3. Update documentation as needed")
    else:
        print("\n✅ Installer was already portable")


if __name__ == "__main__":
    main()
