#!/usr/bin/env python3
"""
Claude Shell Integration Module
Handles shell-specific configuration, compatibility, and wrapper generation
"""

import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union


@dataclass
class ShellProfile:
    """Represents a shell configuration profile"""

    shell_type: str
    config_file: Path
    syntax_type: str  # posix, csh, fish
    supports_functions: bool
    supports_aliases: bool
    supports_completion: bool
    path_variable: str
    export_syntax: str


class ShellIntegrationManager:
    """Manages shell integration for Claude installation"""

    SHELL_PROFILES = {
        "bash": ShellProfile(
            shell_type="bash",
            config_file=Path.home() / ".bashrc",
            syntax_type="posix",
            supports_functions=True,
            supports_aliases=True,
            supports_completion=True,
            path_variable="PATH",
            export_syntax="export",
        ),
        "zsh": ShellProfile(
            shell_type="zsh",
            config_file=Path.home() / ".zshrc",
            syntax_type="posix",
            supports_functions=True,
            supports_aliases=True,
            supports_completion=True,
            path_variable="PATH",
            export_syntax="export",
        ),
        "fish": ShellProfile(
            shell_type="fish",
            config_file=Path.home() / ".config" / "fish" / "config.fish",
            syntax_type="fish",
            supports_functions=True,
            supports_aliases=False,  # Fish uses functions instead
            supports_completion=True,
            path_variable="PATH",
            export_syntax="set -gx",
        ),
        "csh": ShellProfile(
            shell_type="csh",
            config_file=Path.home() / ".cshrc",
            syntax_type="csh",
            supports_functions=False,
            supports_aliases=True,
            supports_completion=False,
            path_variable="PATH",
            export_syntax="setenv",
        ),
        "tcsh": ShellProfile(
            shell_type="tcsh",
            config_file=Path.home() / ".tcshrc",
            syntax_type="csh",
            supports_functions=False,
            supports_aliases=True,
            supports_completion=True,
            path_variable="PATH",
            export_syntax="setenv",
        ),
    }

    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.detected_shells = self._detect_available_shells()
        self.primary_shell = self._detect_primary_shell()

    def _detect_available_shells(self) -> Dict[str, Path]:
        """Detect available shells on the system"""
        shells = {}

        # Check common shell locations
        shell_locations = {
            "bash": ["/bin/bash", "/usr/bin/bash", "/usr/local/bin/bash"],
            "zsh": ["/bin/zsh", "/usr/bin/zsh", "/usr/local/bin/zsh"],
            "fish": ["/bin/fish", "/usr/bin/fish", "/usr/local/bin/fish"],
            "csh": ["/bin/csh", "/usr/bin/csh"],
            "tcsh": ["/bin/tcsh", "/usr/bin/tcsh"],
        }

        for shell_name, locations in shell_locations.items():
            for location in locations:
                if Path(location).exists():
                    shells[shell_name] = Path(location)
                    break

        return shells

    def _detect_primary_shell(self) -> Optional[str]:
        """Detect the primary shell being used"""
        # Check SHELL environment variable
        shell_path = os.environ.get("SHELL", "")
        if shell_path:
            shell_name = Path(shell_path).name
            if shell_name in self.SHELL_PROFILES:
                return shell_name

        # Check current process
        try:
            result = subprocess.run(
                ["ps", "-p", str(os.getpid()), "-o", "comm="],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                process_name = result.stdout.strip().lstrip("-")
                if process_name in self.SHELL_PROFILES:
                    return process_name
        except:
            pass

        # Default to bash if available
        return "bash" if "bash" in self.detected_shells else None

    def create_universal_wrapper(self, claude_binary: Path, wrapper_path: Path) -> bool:
        """Create a universal wrapper that works across all shells"""
        try:
            # Create a robust POSIX-compliant wrapper
            wrapper_content = self._generate_universal_wrapper_content(claude_binary)

            wrapper_path.write_text(wrapper_content)
            wrapper_path.chmod(0o755)

            # Test the wrapper
            if self._test_wrapper_functionality(wrapper_path):
                if self.verbose:
                    print(f"✓ Universal wrapper created at {wrapper_path}")
                return True
            else:
                if self.verbose:
                    print(f"✗ Wrapper test failed for {wrapper_path}")
                return False

        except Exception as e:
            if self.verbose:
                print(f"✗ Failed to create wrapper: {e}")
            return False

    def _generate_universal_wrapper_content(self, claude_binary: Path) -> str:
        """Generate universal wrapper content that works across shells"""
        return f"""#!/bin/sh
# Claude Universal Wrapper
# Generated by Claude Enhanced Installer v2.0
# Compatible with bash, zsh, dash, and other POSIX shells

# Recursion protection
if [ "${{CLAUDE_WRAPPER_ACTIVE}}" = "true" ]; then
    echo "Error: Claude wrapper recursion detected" >&2
    exit 1
fi

# Set protection flag
CLAUDE_WRAPPER_ACTIVE=true
export CLAUDE_WRAPPER_ACTIVE

# Cleanup function for POSIX shells
cleanup() {{
    unset CLAUDE_WRAPPER_ACTIVE
}}

# Register cleanup (works in most shells)
trap cleanup EXIT INT TERM

# Claude binary path
CLAUDE_BINARY="{claude_binary}"

# Verify binary exists
if [ ! -f "$CLAUDE_BINARY" ]; then
    echo "Error: Claude binary not found at $CLAUDE_BINARY" >&2
    exit 1
fi

# Execute based on file type
case "$CLAUDE_BINARY" in
    *.js)
        # Node.js script - check for node
        if command -v node >/dev/null 2>&1; then
            exec node "$CLAUDE_BINARY" "$@"
        else
            echo "Error: node not found (required for $CLAUDE_BINARY)" >&2
            exit 1
        fi
        ;;
    *)
        # Direct binary
        if [ -x "$CLAUDE_BINARY" ]; then
            exec "$CLAUDE_BINARY" "$@"
        else
            echo "Error: $CLAUDE_BINARY is not executable" >&2
            exit 1
        fi
        ;;
esac
"""

    def _test_wrapper_functionality(self, wrapper_path: Path) -> bool:
        """Test wrapper functionality across multiple shells"""
        if not wrapper_path.exists():
            return False

        # Test with available shells
        test_shells = ["bash", "sh"]  # Start with most common
        if "zsh" in self.detected_shells:
            test_shells.append("zsh")

        for shell in test_shells:
            shell_path = shutil.which(shell)
            if shell_path:
                try:
                    # Test basic execution
                    result = subprocess.run(
                        [shell_path, str(wrapper_path), "--help"],
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )
                    if result.returncode != 0:
                        if self.verbose:
                            print(f"Wrapper test failed with {shell}: {result.stderr}")
                        return False
                except subprocess.TimeoutExpired:
                    if self.verbose:
                        print(f"Wrapper test timed out with {shell}")
                    return False
                except Exception as e:
                    if self.verbose:
                        print(f"Wrapper test error with {shell}: {e}")
                    return False

        return True

    def configure_shell_integration(
        self, local_bin_path: Path
    ) -> Tuple[bool, List[str]]:
        """Configure shell integration for all detected shells"""
        results = []
        overall_success = True

        # Configure primary shell first
        if self.primary_shell:
            success = self._configure_single_shell(self.primary_shell, local_bin_path)
            results.append(f"{self.primary_shell}: {'✓' if success else '✗'}")
            if not success:
                overall_success = False

        # Configure other detected shells
        for shell_name in self.detected_shells:
            if shell_name != self.primary_shell:
                success = self._configure_single_shell(shell_name, local_bin_path)
                results.append(f"{shell_name}: {'✓' if success else '✗'}")
                if not success:
                    overall_success = False

        return overall_success, results

    def _configure_single_shell(self, shell_name: str, local_bin_path: Path) -> bool:
        """Configure a single shell for Claude integration"""
        if shell_name not in self.SHELL_PROFILES:
            return False

        profile = self.SHELL_PROFILES[shell_name]

        try:
            # Ensure config file directory exists
            profile.config_file.parent.mkdir(parents=True, exist_ok=True)

            # Read current config
            current_content = ""
            if profile.config_file.exists():
                current_content = profile.config_file.read_text()

            # Check if already configured
            if self._is_already_configured(current_content):
                if self.verbose:
                    print(f"{shell_name} already configured")
                return True

            # Generate configuration block
            config_block = self._generate_shell_config_block(profile, local_bin_path)

            # Append configuration
            with profile.config_file.open("a") as f:
                f.write(config_block)

            if self.verbose:
                print(f"✓ {shell_name} configuration updated")
            return True

        except Exception as e:
            if self.verbose:
                print(f"✗ Failed to configure {shell_name}: {e}")
            return False

    def _is_already_configured(self, content: str) -> bool:
        """Check if shell is already configured for Claude"""
        markers = ["Claude Enhanced Installer", "/.local/bin", "CLAUDE_WRAPPER_ACTIVE"]
        return any(marker in content for marker in markers)

    def _generate_shell_config_block(
        self, profile: ShellProfile, local_bin_path: Path
    ) -> str:
        """Generate shell-specific configuration block"""
        if profile.syntax_type == "fish":
            return self._generate_fish_config(profile, local_bin_path)
        elif profile.syntax_type == "csh":
            return self._generate_csh_config(profile, local_bin_path)
        else:  # POSIX (bash, zsh)
            return self._generate_posix_config(profile, local_bin_path)

    def _generate_posix_config(
        self, profile: ShellProfile, local_bin_path: Path
    ) -> str:
        """Generate POSIX shell configuration (bash, zsh)"""
        config = f"""

# ═══════════════════════════════════════════════════════════════════
# Claude Enhanced Installer Configuration
# ═══════════════════════════════════════════════════════════════════

# Add local bin to PATH if not already present
case ":$PATH:" in
    *":{local_bin_path}:"*) ;;
    *) export PATH="{local_bin_path}:$PATH" ;;
esac

# Claude completion setup
if command -v claude >/dev/null 2>&1; then
    # Enable completion if available
    # Note: Completion scripts would be sourced here if available
    true
fi
"""

        # Add shell-specific enhancements
        if profile.shell_type == "zsh":
            config += """
# ZSH-specific Claude enhancements
if [[ -n "$ZSH_VERSION" ]]; then
    # Enable ZSH completion system if not already enabled
    autoload -Uz compinit
    compinit -C  # Skip security check for performance
fi
"""

        return config

    def _generate_fish_config(self, profile: ShellProfile, local_bin_path: Path) -> str:
        """Generate Fish shell configuration"""
        return f"""

# ═══════════════════════════════════════════════════════════════════
# Claude Enhanced Installer Configuration
# ═══════════════════════════════════════════════════════════════════

# Add local bin to PATH
if not contains "{local_bin_path}" $PATH
    set -gx PATH "{local_bin_path}" $PATH
end

# Claude completion setup
if command -v claude >/dev/null 2>&1
    # Enable completion if available
    # Note: Fish completion files would be installed separately
    true
end
"""

    def _generate_csh_config(self, profile: ShellProfile, local_bin_path: Path) -> str:
        """Generate C shell configuration"""
        return f"""

# ═══════════════════════════════════════════════════════════════════
# Claude Enhanced Installer Configuration
# ═══════════════════════════════════════════════════════════════════

# Add local bin to PATH
set path = ({local_bin_path} $path)

# Claude alias (since csh doesn't support functions well)
alias claude-help "claude --help"
"""

    def create_shell_specific_wrappers(
        self, claude_binary: Path, wrapper_dir: Path
    ) -> Dict[str, bool]:
        """Create shell-specific wrapper scripts"""
        results = {}

        for shell_name in self.detected_shells:
            if shell_name in self.SHELL_PROFILES:
                wrapper_path = wrapper_dir / f"claude-{shell_name}"
                success = self._create_shell_specific_wrapper(
                    shell_name, claude_binary, wrapper_path
                )
                results[shell_name] = success

        return results

    def _create_shell_specific_wrapper(
        self, shell_name: str, claude_binary: Path, wrapper_path: Path
    ) -> bool:
        """Create a wrapper optimized for a specific shell"""
        try:
            profile = self.SHELL_PROFILES[shell_name]

            if profile.syntax_type == "fish":
                content = self._generate_fish_wrapper(claude_binary)
            elif profile.syntax_type == "csh":
                content = self._generate_csh_wrapper(claude_binary)
            else:  # POSIX
                content = self._generate_posix_wrapper(claude_binary, shell_name)

            wrapper_path.write_text(content)
            wrapper_path.chmod(0o755)

            return True

        except Exception as e:
            if self.verbose:
                print(f"Failed to create {shell_name} wrapper: {e}")
            return False

    def _generate_posix_wrapper(self, claude_binary: Path, shell_name: str) -> str:
        """Generate POSIX shell wrapper (bash/zsh specific optimizations)"""
        shebang = f"#!/bin/{shell_name}"

        wrapper = f"""{shebang}
# Claude {shell_name.upper()} Wrapper
# Optimized for {shell_name} with enhanced error handling

# Recursion protection with {shell_name} specific checks
if [[ "${{CLAUDE_WRAPPER_ACTIVE}}" == "true" ]]; then
    echo "Error: Claude wrapper recursion detected" >&2
    exit 1
fi

export CLAUDE_WRAPPER_ACTIVE=true

# Cleanup function
cleanup() {{
    unset CLAUDE_WRAPPER_ACTIVE
}}

# Register cleanup
trap cleanup EXIT INT TERM"""

        if shell_name == "zsh":
            wrapper += """

# ZSH specific optimizations
setopt NO_UNSET  # Prevent undefined variable errors
setopt ERR_EXIT  # Exit on command failure"""

        wrapper += f"""

# Claude binary path
CLAUDE_BINARY="{claude_binary}"

# Enhanced binary verification
if [[ ! -f "$CLAUDE_BINARY" ]]; then
    echo "Error: Claude binary not found at $CLAUDE_BINARY" >&2
    exit 1
fi

if [[ ! -r "$CLAUDE_BINARY" ]]; then
    echo "Error: Cannot read Claude binary at $CLAUDE_BINARY" >&2
    exit 1
fi

# Execute based on file type with enhanced error handling
case "$CLAUDE_BINARY" in
    *.js)
        if command -v node >/dev/null 2>&1; then
            exec node "$CLAUDE_BINARY" "$@"
        else
            echo "Error: node not found (required for JavaScript Claude binary)" >&2
            exit 1
        fi
        ;;
    *)
        if [[ -x "$CLAUDE_BINARY" ]]; then
            exec "$CLAUDE_BINARY" "$@"
        else
            echo "Error: Claude binary is not executable" >&2
            echo "Try: chmod +x $CLAUDE_BINARY" >&2
            exit 1
        fi
        ;;
esac
"""
        return wrapper

    def _generate_fish_wrapper(self, claude_binary: Path) -> str:
        """Generate Fish shell wrapper"""
        return f"""#!/usr/bin/env fish
# Claude Fish Wrapper
# Fish-specific implementation with proper error handling

# Recursion protection
if test "$CLAUDE_WRAPPER_ACTIVE" = "true"
    echo "Error: Claude wrapper recursion detected" >&2
    exit 1
end

set -gx CLAUDE_WRAPPER_ACTIVE true

# Cleanup function
function cleanup --on-process-exit
    set -e CLAUDE_WRAPPER_ACTIVE
end

# Claude binary path
set CLAUDE_BINARY "{claude_binary}"

# Verify binary exists
if not test -f "$CLAUDE_BINARY"
    echo "Error: Claude binary not found at $CLAUDE_BINARY" >&2
    exit 1
end

# Execute based on file type
switch "$CLAUDE_BINARY"
    case "*.js"
        if command -v node >/dev/null 2>&1
            exec node "$CLAUDE_BINARY" $argv
        else
            echo "Error: node not found (required for JavaScript Claude binary)" >&2
            exit 1
        end
    case "*"
        if test -x "$CLAUDE_BINARY"
            exec "$CLAUDE_BINARY" $argv
        else
            echo "Error: Claude binary is not executable" >&2
            exit 1
        end
end
"""

    def _generate_csh_wrapper(self, claude_binary: Path) -> str:
        """Generate C shell wrapper"""
        return f"""#!/bin/csh
# Claude C Shell Wrapper
# Basic implementation for csh/tcsh compatibility

# Simple recursion check (csh limitations)
if ($?CLAUDE_WRAPPER_ACTIVE) then
    echo "Error: Claude wrapper recursion detected"
    exit 1
endif

setenv CLAUDE_WRAPPER_ACTIVE true

# Claude binary path
set CLAUDE_BINARY = "{claude_binary}"

# Basic verification
if (! -f "$CLAUDE_BINARY") then
    echo "Error: Claude binary not found at $CLAUDE_BINARY"
    exit 1
endif

# Execute (simplified for csh)
if ("$CLAUDE_BINARY" =~ *.js) then
    if (`which node` != "") then
        exec node "$CLAUDE_BINARY" $*
    else
        echo "Error: node not found"
        exit 1
    endif
else
    if (-x "$CLAUDE_BINARY") then
        exec "$CLAUDE_BINARY" $*
    else
        echo "Error: Claude binary is not executable"
        exit 1
    endif
endif
"""

    def get_shell_info(self) -> Dict[str, any]:
        """Get comprehensive shell information"""
        return {
            "detected_shells": {
                name: str(path) for name, path in self.detected_shells.items()
            },
            "primary_shell": self.primary_shell,
            "shell_configs": {
                name: {
                    "config_file": str(profile.config_file),
                    "exists": profile.config_file.exists(),
                    "writable": os.access(profile.config_file.parent, os.W_OK),
                }
                for name, profile in self.SHELL_PROFILES.items()
                if name in self.detected_shells
            },
            "environment": {
                "SHELL": os.environ.get("SHELL", ""),
                "PATH": os.environ.get("PATH", "").split(":"),
                "current_process": self._get_current_process_info(),
            },
        }

    def _get_current_process_info(self) -> Dict[str, str]:
        """Get current process information"""
        try:
            result = subprocess.run(
                ["ps", "-p", str(os.getpid()), "-o", "pid,ppid,comm,args"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split("\\n")
                if len(lines) > 1:
                    return {"ps_output": lines[1]}
        except:
            pass

        return {"ps_output": "unknown"}


if __name__ == "__main__":
    # Example usage and testing
    manager = ShellIntegrationManager(verbose=True)

    print("Shell Information:")
    import pprint

    pprint.pprint(manager.get_shell_info())

    print(f"\\nPrimary shell: {manager.primary_shell}")
    print(f"Detected shells: {list(manager.detected_shells.keys())}")
