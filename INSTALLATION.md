# Claude Code Installation Guide

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups
```

### 2. Install (New Python-Based System)
```bash
# Quick installation
./install

# Advanced installation
./claude-python-installer.sh --full

# Custom installation
./claude-python-installer.sh --custom
```

### 3. Upgrade Existing Installation
```bash
# Upgrade all components
./claude-python-installer.sh --upgrade

# Upgrade specific module
python3 upgrade-to-python-installer.py --upgrade claude-code
```

### 4. Uninstall
```bash
./uninstall
```

## 📋 System Requirements

- **Python 3.8+** (required for installer)
- **Node.js 18+** (for Claude Code)
- **npm or pip** (for package management)
- **Docker** (optional, for learning system)
- **10 GB disk space** (for full installation)

## 🔧 Prerequisites Setup

### Node.js & npm
```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node

# Windows (WSL)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Docker (Optional)
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker

# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Or use our fix script
./fix-docker-permissions
```

### Python Dependencies
```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip python3-venv

# macOS
brew install python3

# Windows (WSL)
sudo apt install python3 python3-pip python3-venv
```

## 🛠️ Installation Methods

### Method 1: Quick Install (Recommended)
```bash
./install
```
- Uses Python-based installer
- Handles all dependencies
- Cross-platform compatible
- Includes error recovery

### Method 2: Advanced Install
```bash
./claude-python-installer.sh --full --verbose
```
- Full system installation
- All components included
- Detailed progress output
- Learning system setup

### Method 3: Custom Install
```bash
./claude-python-installer.sh --custom
```
- Choose specific components
- Minimal installation option
- Skip optional features
- Advanced configuration

### Method 4: Detection Only
```bash
./claude-python-installer.sh --detect-only
```
- Check existing installations
- No modifications made
- System analysis
- Compatibility check

## 🏗️ What Gets Installed

| Component | Description | Storage |
|-----------|-------------|---------|
| **Claude Code** | Main AI assistant binary | ~/.local/bin/claude |
| **Wrapper System** | Enhanced wrapper with features | ~/.local/bin/claude |
| **Agent Framework** | 84 specialized agents | ~/agents/ |
| **Learning System** | ML performance analytics | Docker containers |
| **OpenVINO Runtime** | AI acceleration | /opt/openvino/ |
| **Configuration** | Settings and preferences | ~/.config/claude/ |

## 🔍 Troubleshooting

### Docker Permission Issues
```bash
# Error: permission denied while trying to connect to Docker daemon
./fix-docker-permissions

# Manual fix
sudo usermod -aG docker $USER
newgrp docker
```

### Node.js/npm Issues
```bash
# Check versions
node --version  # Should be 18+
npm --version   # Should be 8+

# Reset npm prefix
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
```

### Python Issues
```bash
# Check Python version
python3 --version  # Should be 3.8+

# Install missing packages
pip3 install --user asyncpg psutil pathlib
```

### Wrapper Not Working
```bash
# Check wrapper status
claude --status

# Reinstall wrapper
./claude-python-installer.sh --upgrade wrapper-system

# Reset to original
./uninstall
./install
```

## 📚 Advanced Configuration

### Environment Variables
```bash
# Disable permission bypass
export CLAUDE_PERMISSION_BYPASS=false

# Disable learning system
export LEARNING_CAPTURE_ENABLED=false

# Custom project root
export CLAUDE_PROJECT_ROOT=/path/to/project
```

### Shell Integration
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_HOME="$HOME/.claude-home"

# Enable autocompletion (if available)
source ~/.local/share/claude/completion.bash
```

### Docker Configuration
```bash
# Check Docker status
docker ps | grep claude

# Start learning system
cd database && docker-compose up -d

# View logs
docker logs claude-postgres
```

## 🔄 Migration from Old Installer

### From Shell Installer v10.0
```bash
# Automatic migration
./upgrade-to-python-installer.py --auto

# Manual migration
./claude-python-installer.sh --upgrade-all
```

### Backup Current Installation
```bash
# Create backup before migration
cp -r ~/.local/bin/claude ~/.local/bin/claude.backup
cp -r ~/.config/claude ~/.config/claude.backup
```

### Verify Migration
```bash
# Test new system
claude --status
claude /task "hello test"

# Check agent access
claude agents
claude agent director "test"
```

## 🆘 Getting Help

### Documentation
- `./claude-python-installer.sh --help` - Installer help
- `claude --help` - Claude command help
- `docs/` - Complete documentation

### Support Commands
```bash
# System status
claude --status

# List agents
claude agents

# Test installation
./claude-python-installer.sh --detect-only

# Check logs
tail -f ~/.claude-home/learning_logs/executions.jsonl
```

### Common Issues
1. **Permission denied**: Use `./fix-docker-permissions`
2. **Command not found**: Check PATH and reinstall
3. **Python errors**: Update Python to 3.8+
4. **Network issues**: Check firewall and proxy settings
5. **Disk space**: Ensure 10GB available

---

**Note**: The old shell installer (`claude-installer.sh`) has been deprecated. Use the new Python-based installer for better reliability and cross-platform support.