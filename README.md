# Claude Code LiveCD Unified Installer

**Complete Claude Code installation suite with three powerful installers for LiveCD environments**

## 🚀 Quick Start - Choose Your Method

### Method 1: Portable Installation (Best for LiveCD)
```bash
# Everything in one self-contained directory - no system dependencies
./claude-portable-launch.sh
```

### Method 2: Quick System Installation
```bash
# Smart installer with CPU optimization detection
./claude-quick-launch-agents.sh
```

### Method 3: Direct Installation
```bash
# Main installer with full control
./claude-livecd-unified-with-agents.sh --auto-mode
```

All methods install Claude Code v1.0.77 with agents, statusline, and auto-permission bypass.

## ✨ Features

- ✅ **Claude Code v1.0.77** - Official @anthropic-ai/claude-code package
- ✅ **Three Installation Methods** - Portable, Quick, or Direct
- ✅ **Zero Dependencies** - Auto-installs npm, node, nano, and more
- ✅ **Portable Mode** - Everything in one directory (~300MB)
- ✅ **LiveCD Optimized** - Works on non-persistent systems  
- ✅ **Auto Permission Bypass** - No prompts for LiveCD usage
- ✅ **28 Production Agents** - Full v7.0 agent system with local detection
- ✅ **God-tier Statusline** - For Neovim, Vim, Nano, and Shell
- ✅ **Nano Default Editor** - User-friendly with syntax highlighting
- ✅ **AVX-512 Cloaking Detection** - Detects when microcode disables AVX-512
- ✅ **Intel Core Ultra Optimized** - AVX512/AVX2 SIMD acceleration
- ✅ **P-Core/E-Core Aware** - Optimized for Intel hybrid CPUs
- ✅ **First Launch Helper** - Guided setup with /config and /terminal-setup

## 📦 What Gets Installed

### 1. **Claude Code** with three commands:
   - `claude` - Auto permission bypass (LiveCD default)
   - `claude-normal` - Standard mode with prompts
   - `claude-first-launch` - Guided first-time setup

### 2. **Claude Agents** (28 production agents):
   - Automatically detected from local `agents/` folder
   - Falls back to GitHub repository if not found locally
   - Communication protocols compiled with CPU optimizations
   - Full v7.0 framework with Task tool coordination

### 3. **Enhanced Editor Experience**:
   - **Nano** - Default editor with:
     - Syntax highlighting for all languages
     - Custom Claude agent syntax highlighting
     - User-friendly keybindings (Ctrl+S save, Ctrl+Q quit)
     - Line numbers and mouse support
   - **Statusline** - Shows git branch, project type, file changes
   - **Shell Prompt** - Enhanced with project and git information

### 4. **Dependencies** (automatic):
   - Node.js and npm (latest LTS)
   - GitHub CLI
   - Nano editor
   - Build tools (gcc, make, etc.)
   - Optional: Neovim, jq, ripgrep, fd-find

## 💻 System Requirements

- **OS**: Ubuntu LiveCD 24.04+ (or any Debian-based)
- **CPU**: x86_64 (Intel Core Ultra optimized)
- **RAM**: 2GB minimum
- **Network**: Internet connection for downloads
- **Disk**: 150MB free space

## 🛠️ Installation Options

### Option 1: Portable Installation (Recommended for LiveCD)
```bash
chmod +x claude-portable-launch.sh
./claude-portable-launch.sh
```
- ✅ Everything in `claude-portable/` directory
- ✅ No sudo required
- ✅ Includes local Node.js
- ✅ ~300MB total size
- ✅ Can be copied to USB/other systems

### Option 2: Quick System Install
```bash
chmod +x claude-quick-launch-agents.sh
./claude-quick-launch-agents.sh
```
- ✅ Smart CPU detection
- ✅ Auto-finds and runs main installer
- ✅ Fixes Dell repo warnings
- ✅ Uses system directories

### Option 3: Direct Installation
```bash
chmod +x claude-livecd-unified-with-agents.sh

# Auto mode (no prompts)
./claude-livecd-unified-with-agents.sh --auto-mode

# Skip agents (Claude Code only)
./claude-livecd-unified-with-agents.sh --skip-agents

# Dry run to test
./claude-livecd-unified-with-agents.sh --dry-run

# Force installation
./claude-livecd-unified-with-agents.sh --force
```

## 🎯 First Launch

After installation, run the first-launch helper:

```bash
claude-first-launch
```

This will:
1. Run `/config` to configure Claude Code
2. Run `/terminal-setup` to detect agents
3. Launch Claude Code normally

Or manually:
```bash
claude /config          # Configure Claude Code
claude /terminal-setup  # Setup terminal with agents
claude                  # Start Claude Code
```

## 📁 Directory Structure

```
/home/ubuntu/Documents/Claude/
├── claude-portable-launch.sh             # Portable installer (NEW)
├── claude-livecd-unified-with-agents.sh  # Main installer
├── claude-quick-launch-agents.sh         # Quick launcher
├── agents/                               # 28 production agents
├── scripts/
│   ├── statusline.lua                   # Neovim statusline
│   └── statusline.md                    # Documentation
├── CLAUDE.md                            # Project context
└── claude-portable/                     # Created by portable installer
    ├── node/                            # Local Node.js
    ├── claude-code/                     # Claude Code installation
    ├── agents/                          # Copied agents
    ├── bin/                             # Wrapper scripts
    └── launch-claude.sh                 # Launch script
```

## ⚡ Performance Notes

### CPU Optimizations
- **AVX-512**: Detected via runtime test (not just cpuinfo)
- **Microcode Detection**: Versions >0x20 indicate AVX-512 is cloaked/disabled
- **AVX2**: Automatic fallback when AVX-512 unavailable
- **P-Core Affinity**: Automatically detected for Intel hybrid CPUs
- **Compilation**: Uses detected features for optimal performance

### LiveCD Optimizations
- Uses home directory (avoids `/tmp` noexec)
- All changes lost on reboot
- Credentials embedded for convenience

## 🔧 Troubleshooting

### Permission Denied
```bash
chmod +x claude-quick-launch-agents.sh
chmod +x claude-livecd-unified-with-agents.sh
```

### AVX-512 Illegal Instruction
Your microcode has disabled AVX-512. The installer automatically falls back to AVX2.

### Network Issues
Check your internet connection. The installer needs to download from GitHub and npm.

### Agents Not Found
Ensure the `agents/` folder is in the same directory as the installer scripts.

### Nano Not Working
The installer will automatically install nano if not present. For manual install:
```bash
sudo apt-get install nano
```

## 🔒 Security Note

This installer includes hardcoded credentials for LiveCD convenience. For production use:
1. Replace GitHub token in scripts
2. Use your own API keys
3. Review security settings in CLAUDE.md

## 📚 Documentation

- **[CLAUDE.md](CLAUDE.md)** - Project context and agent documentation
- **[scripts/statusline.md](scripts/statusline.md)** - Statusline configuration
- **[agents/docs/](agents/docs/)** - Agent framework documentation

## 🏷️ Version

**Current Version**: 6.0.0-portable  
**Release Date**: 2025-08-13  
**Claude Code Version**: 1.0.77  
**Platform**: Intel Core Ultra 7 155H (Meteor Lake)

## 📝 License

This project is part of the Claude Code ecosystem. See repository for license details.

---

**For detailed documentation, see [CLAUDE.md](CLAUDE.md)**