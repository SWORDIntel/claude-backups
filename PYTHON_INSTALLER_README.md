# Claude Enhanced Installer v2.0 - Python Edition

A robust, Python-based installer system for Claude Code that addresses shell compatibility issues, provides comprehensive error handling, and avoids the recursion problems found in complex shell scripts.

## Overview

The enhanced installer system consists of several Python modules that work together to provide a comprehensive, reliable installation experience:

- **`claude-enhanced-installer.py`** - Main installer with detection and installation logic
- **`claude_installer_config.py`** - Configuration management and validation
- **`claude_shell_integration.py`** - Shell-specific compatibility and wrapper generation
- **`claude-python-installer.sh`** - Simple shell launcher

## Key Features

### 🔧 Robust Installation
- **Multiple Installation Methods**: npm, pip, system packages, manual detection
- **Comprehensive Fallbacks**: 75+ installation strategies with automatic fallback
- **Cross-Platform Support**: Linux, macOS, Windows WSL
- **Dependency Detection**: Automatic detection and validation of requirements

### 🐚 Shell Compatibility
- **Universal Wrappers**: POSIX-compliant wrappers that work across all shells
- **Shell-Specific Optimizations**: Custom wrappers for bash, zsh, fish, csh/tcsh
- **Recursion Prevention**: Built-in protection against wrapper recursion issues
- **Configuration Management**: Automatic PATH and completion setup

### 🛡️ Error Handling
- **Comprehensive Validation**: System requirements, paths, dependencies
- **Recovery Mechanisms**: Backup and restore functionality
- **Detailed Logging**: Verbose output and error reporting
- **Graceful Degradation**: Works even when some components fail

### ⚡ Performance
- **Fast Detection**: Efficient binary detection across multiple locations
- **Minimal Dependencies**: Uses only Python standard library
- **Optimized Execution**: Shell-specific optimizations for best performance

## Quick Start

### Basic Installation (Recommended)
```bash
# Full installation with all components
./claude-python-installer.sh

# Or run Python installer directly
./claude-enhanced-installer.py
```

### Quick Installation
```bash
# Minimal installation
./claude-python-installer.sh --quick

# With Python installer
./claude-enhanced-installer.py --mode quick
```

### Detection Only
```bash
# Just detect existing installations
./claude-python-installer.sh --detect-only

# With verbose output
./claude-enhanced-installer.py --detect-only --verbose
```

## Installation Modes

### Full Mode (Default)
Installs all components:
- Claude binary (via npm or pip)
- Agent system
- Shell integration
- Wrapper scripts
- Configuration files

### Quick Mode
Installs minimal components:
- Claude binary only
- Basic wrapper script
- Essential PATH configuration

### Custom Mode
Interactive selection of components to install.

## Command Line Options

### Shell Launcher (`claude-python-installer.sh`)
```bash
./claude-python-installer.sh [OPTIONS]

Options:
  --quick           Quick installation with minimal components
  --full            Full installation with all components (default)
  --custom          Custom installation - choose components
  --detect-only     Only detect existing installations
  --verbose, -v     Enable verbose output
  --auto, -a        Auto mode - no user prompts
  --help, -h        Show help message
```

### Python Installer (`claude-enhanced-installer.py`)
```bash
./claude-enhanced-installer.py [OPTIONS]

Options:
  --mode {quick,full,custom}    Installation mode (default: full)
  --verbose, -v                 Enable verbose output
  --auto, -a                   Auto mode - no user prompts
  --detect-only                Only detect existing installations
```

## System Requirements

### Minimum Requirements
- **Python**: 3.8 or higher
- **Operating System**: Linux, macOS, or Windows WSL
- **Disk Space**: 1GB free space
- **Internet**: Active internet connection

### Recommended Requirements
- **Node.js**: 16+ (for npm installation)
- **Git**: For full agent system installation
- **Shell**: bash, zsh, fish, or compatible POSIX shell

## Architecture

### Detection System
The installer automatically detects existing Claude installations:

1. **npm Global Packages**: Searches npm global installations
2. **pip Packages**: Checks for pip-installed Claude packages
3. **System PATH**: Looks for system-installed binaries
4. **Manual Installations**: Searches common manual installation locations

### Wrapper Generation
Creates robust wrapper scripts that:

- **Prevent Recursion**: Built-in protection against infinite loops
- **Shell Compatibility**: Works across bash, zsh, fish, and other shells
- **Error Handling**: Comprehensive error checking and reporting
- **Binary Detection**: Automatically handles Node.js scripts vs direct binaries

### Shell Integration
Automatically configures:

- **PATH Updates**: Adds `~/.local/bin` to PATH in all shells
- **Completion Setup**: Enables completion when available
- **Environment Variables**: Sets necessary environment variables
- **Configuration Files**: Updates `.bashrc`, `.zshrc`, etc.

## Configuration

### Configuration File
The installer creates a configuration file at:
```
~/.config/claude/installer_config.json
```

### Environment Variables
- `CLAUDE_WRAPPER_ACTIVE`: Recursion protection flag
- `CLAUDE_ENHANCED`: Indicates enhanced installation
- `CLAUDE_PROJECT_ROOT`: Project root directory

### Installation State
State tracking is maintained at:
```
~/.config/claude/installation_state.json
```

## Troubleshooting

### Common Issues

#### "Python 3.8+ not found"
```bash
# Install Python 3.8+ using your system package manager
# Ubuntu/Debian:
sudo apt update && sudo apt install python3 python3-pip

# macOS:
brew install python3

# Or use pyenv for version management
```

#### "npm installation failed"
```bash
# Install Node.js first
# Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS:
brew install node

# Then retry installation
```

#### "Wrapper recursion detected"
The enhanced installer includes built-in recursion protection. If you see this error:

1. Check for conflicting wrapper scripts
2. Ensure only one Claude wrapper is in PATH
3. Run with `--force-reinstall` to recreate wrappers

#### "Shell configuration failed"
```bash
# Manually source the configuration
source ~/.bashrc  # for bash
source ~/.zshrc   # for zsh

# Or restart your shell
exec $SHELL
```

### Verbose Debugging
For detailed troubleshooting information:
```bash
./claude-enhanced-installer.py --verbose --detect-only
```

### Recovery
If installation fails, you can recover using:
```bash
# The installer automatically creates backups
ls ~/.config/claude/backups/

# Use the configuration module for recovery
python3 claude_installer_config.py
```

## Advanced Usage

### Custom Installation Paths
```python
# Edit configuration before installation
from claude_installer_config import InstallationConfig

config = InstallationConfig()
config.custom_install_path = "/custom/path"
config.custom_config_path = "/custom/config"
config.save_to_file(Path.home() / ".config/claude/installer_config.json")
```

### Shell-Specific Wrappers
```bash
# Create shell-specific wrappers for optimization
python3 -c "
from claude_shell_integration import ShellIntegrationManager
from pathlib import Path

manager = ShellIntegrationManager(verbose=True)
claude_binary = Path('/path/to/claude')
wrapper_dir = Path.home() / '.local/bin'

results = manager.create_shell_specific_wrappers(claude_binary, wrapper_dir)
print('Wrapper creation results:', results)
"
```

### Validation Only
```python
# Run comprehensive validation
from claude_installer_config import ClaudeEnvironmentValidator, create_default_config

config = create_default_config()
validator = ClaudeEnvironmentValidator(config)

print("System Requirements:", validator.validate_system_requirements())
print("Paths:", validator.validate_installation_paths())
print("Dependencies:", validator.validate_dependencies())
```

## Comparison with Shell Installer

| Feature | Python Installer | Shell Installer |
|---------|------------------|------------------|
| Recursion Protection | ✅ Built-in | ⚠️ Complex logic |
| Shell Compatibility | ✅ Universal | ⚠️ Shell-specific issues |
| Error Handling | ✅ Comprehensive | ⚠️ Limited |
| Cross-Platform | ✅ Excellent | ⚠️ Platform-dependent |
| Maintainability | ✅ Modular Python | ⚠️ Complex shell scripts |
| Performance | ✅ Fast detection | ⚠️ Multiple subprocess calls |
| Recovery | ✅ Built-in backup/restore | ❌ Manual |
| Validation | ✅ Comprehensive checks | ⚠️ Basic |

## Development

### Adding New Features
The modular design makes it easy to extend:

1. **Detection Logic**: Add new detection methods in `detect_claude_installations()`
2. **Installation Methods**: Add new installation strategies in installation methods
3. **Shell Support**: Add new shells in `claude_shell_integration.py`
4. **Validation**: Add new checks in `claude_installer_config.py`

### Testing
```bash
# Run with detection only for testing
./claude-enhanced-installer.py --detect-only --verbose

# Test shell integration
python3 claude_shell_integration.py

# Test configuration system
python3 claude_installer_config.py
```

## Files Created

After successful installation, you'll find:

```
~/.local/bin/claude              # Universal wrapper script
~/.local/bin/claude-enhanced     # Enhanced launcher
~/.config/claude/                # Configuration directory
  ├── installer_config.json     # Installation configuration
  ├── installation_state.json   # Current state
  └── backups/                  # Automatic backups
~/.local/share/claude/          # Data directory
  ├── logs/                     # Installation logs
  └── venv/                     # Virtual environment (if created)
~/agents/                       # Agent system (if installed)
```

## Support

For issues with the Python installer:

1. **Check Logs**: Look in `~/.local/share/claude/logs/`
2. **Run Detection**: Use `--detect-only --verbose` for diagnosis
3. **Check Configuration**: Verify `~/.config/claude/installer_config.json`
4. **Manual Recovery**: Use backup files in `~/.config/claude/backups/`

## License

This enhanced installer is part of the Claude Code project and follows the same licensing terms as the main project.

---

*Generated by Claude Enhanced Installer v2.0*