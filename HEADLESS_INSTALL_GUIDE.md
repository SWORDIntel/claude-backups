# Claude Enhanced Installer - Headless Debian Installation Guide

## 🚀 Quick Installation

For headless Debian 12+ systems with PEP 668 restrictions:

```bash
# Method 1: Use the enhanced installer (recommended)
cd claude-backups
python3 claude-enhanced-installer.py --mode=full --auto

# Method 2: Force pipx installation if pip fails
python3 claude-enhanced-installer.py --mode=full --auto --verbose
```

## 🔧 Manual PEP 668 Resolution

If you encounter PEP 668 externally managed environment errors:

```bash
# Install pipx (Debian-recommended approach)
sudo apt update
sudo apt install -y pipx python3-venv python3-full

# Install Claude via pipx
pipx install claude-code

# Ensure pipx binaries are in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 🛠️ Manual Virtual Environment Method

If pipx fails, use manual virtual environment:

```bash
# Create virtual environment
python3 -m venv ~/.local/share/claude/venv

# Activate and install
source ~/.local/share/claude/venv/bin/activate
pip install claude-code

# Create wrapper script
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude << 'EOF'
#!/bin/bash
source ~/.local/share/claude/venv/bin/activate
exec claude "$@"
EOF
chmod +x ~/.local/bin/claude
```

## 🧪 Test Installation

```bash
# Test Claude availability
which claude
claude --version
claude --help

# Run headless compatibility test
python3 test-headless-install.py
```

## ⚠️ Troubleshooting

### PEP 668 Error Messages
If you see:
```
error: externally-managed-environment
× This environment is externally managed
```

**Solution**: The enhanced installer automatically handles this by using pipx or virtual environments.

### npm Permission Errors
If you see:
```
npm ERR! code EACCES
npm ERR! syscall rename
```

**Solution**: The installer will try sudo npm installation automatically, or fall back to pip/pipx methods.

### Missing Dependencies
```bash
# Install common missing packages
sudo apt install -y nodejs npm python3-pip python3-venv python3-full pipx
```

### PATH Issues
```bash
# Ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 🎯 What the Enhanced Installer Does

1. **Detects PEP 668** - Automatically identifies externally managed Python environments
2. **Uses pipx** - Installs via system package manager when available
3. **Creates virtual environments** - Falls back to manual venv creation
4. **Handles permissions** - Uses sudo when necessary for npm/system packages
5. **Creates proper wrappers** - Ensures Claude is accessible from PATH
6. **Validates installation** - Tests functionality before completing

## 📊 System Requirements

- **Debian 11+** or Ubuntu 20.04+
- **Python 3.8+** with venv support
- **Node.js 16+** and npm (optional, for npm installation method)
- **sudo access** (for system package installation)
- **Internet connection** (for package downloads)

## 🎉 Success Indicators

After successful installation:
```bash
$ claude --version
1.0.113 (Claude Code)

$ claude --help
Usage: claude [options] [command] [prompt]
...
```

The enhanced installer resolves all known headless Debian compatibility issues and provides multiple fallback installation methods.