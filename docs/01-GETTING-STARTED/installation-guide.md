# Complete Installation Guide

## 📦 Installation Methods Overview

| Method | Time | Components | Best For |
|--------|------|------------|----------|
| **Quick** | 2 min | Essential | Getting started fast |
| **Full** | 5 min | Everything | Production deployment |
| **Custom** | 3-10 min | Selective | Specific needs |
| **Manual** | 1 min | Wrapper only | Minimal setup |
| **Portable** | 3 min | Self-contained | USB/portable media |

## 🚀 Method 1: Quick Installation

### What It Installs
- Claude Ultimate Wrapper v13.1
- 71 Agents registration
- Basic configuration
- PATH setup

### Commands
```bash
# Clone and quick install
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups
./claude-installer.sh --quick
```

### Post-Installation
```bash
# Reload shell
source ~/.bashrc

# Verify
claude --status
claude --agents
```

## 🎯 Method 2: Full Installation

### What It Installs
- Everything from Quick, plus:
- PostgreSQL database setup
- ML Learning System v3.1
- Tandem Orchestration System
- Virtual environment
- All dependencies
- Systemd services
- Hooks configuration

### Commands
```bash
# Full installation with all features
cd claude-backups
./claude-installer.sh --full

# Or automated (no prompts)
./claude-installer.sh --full --auto
```

### Database Setup (Included)
```bash
# Automatic PostgreSQL configuration
# Creates claude_agents database
# Enables pgvector extension
# Sets up auth tables
```

### Virtual Environment (Automatic)
```bash
# Creates at ~/.local/share/claude/venv
# Installs all Python dependencies:
# - psycopg2-binary
# - pandas
# - numpy
# - scikit-learn
# - asyncio
```

## 🔧 Method 3: Custom Installation

### Interactive Component Selection
```bash
./claude-installer.sh --custom
```

### Available Components
1. **Core Wrapper** - Claude command and agent discovery
2. **Agents** - All 71 agent definitions
3. **Database** - PostgreSQL with pgvector
4. **ML System** - Learning and analytics
5. **Orchestration** - Tandem Python/C system
6. **Hooks** - Event-based automation
7. **Services** - Systemd integration
8. **Documentation** - Local docs

### Example Custom Selection
```
Claude Installer - Custom Mode
==============================
[✓] Core Wrapper
[✓] Agents
[ ] Database
[✓] ML System
[ ] Orchestration
[✓] Hooks
[ ] Services
[✓] Documentation

Proceed with installation? (y/n): y
```

## 🔗 Method 4: Manual Symlink Installation

### Minimal Setup (Wrapper Only)
```bash
# Navigate to project
cd /home/ubuntu/Downloads/claude-backups

# Create symlink (preserves agent discovery)
ln -sf $(pwd)/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x claude-wrapper-ultimate.sh

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Why Symlinks?
- Preserves agent discovery (agents stay relative to script)
- Always uses latest version
- No copying/synchronization needed
- Updates immediately when pulling from git

## 💾 Method 5: Portable Installation

### For USB/External Drives
```bash
# Create portable directory
mkdir -p /media/usb/claude-portable
cd /media/usb/claude-portable

# Clone repository
git clone https://github.com/SWORDIntel/claude-backups.git .

# Run portable installer
./claude-portable-launch.sh
```

### Portable Features
- Self-contained environment
- No system modifications
- Includes all dependencies
- Run from any location

## 🐳 Method 6: Docker Installation

### Using Docker Compose
```bash
# Clone repository
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups

# Build and run
docker-compose up -d

# Access Claude
docker exec -it claude-agent-framework claude --status
```

### Dockerfile
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    nodejs npm python3 python3-pip postgresql-client
COPY . /opt/claude
WORKDIR /opt/claude
RUN ./claude-installer.sh --full --auto
CMD ["claude", "--status"]
```

## 🔄 Updating Installation

### Git Pull Update
```bash
cd /home/ubuntu/Downloads/claude-backups
git pull origin main

# Re-register agents if needed
claude --register-agents
```

### Reinstall Wrapper
```bash
./claude-installer.sh --update
```

## ✅ Post-Installation Verification

### 1. Check Installation
```bash
# Verify wrapper
which claude
claude --version

# Check agents
claude --agents | grep "Total: 71"

# Test execution
claude agent director "test"
```

### 2. System Status
```bash
claude --status
```

Expected output:
```
✓ Node.js installed
✓ Wrapper executable
✓ 71 agents registered
✓ Cache directory created
✓ PATH configured
```

### 3. Database Check (if installed)
```bash
# Check PostgreSQL
psql -U claude -d claude_agents -c "SELECT version();"

# Check pgvector
psql -U claude -d claude_agents -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

## 🚨 Common Installation Issues

### Issue: Command not found
```bash
# Solution
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc
```

### Issue: Permission denied
```bash
# Solution
chmod +x claude-wrapper-ultimate.sh
chmod +x claude-installer.sh
```

### Issue: Node.js not found
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Issue: PostgreSQL not found
```bash
# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

## 🔧 Advanced Installation Options

### Environment Variables
```bash
# Set before installation
export CLAUDE_INSTALL_DIR="/opt/claude"
export CLAUDE_DATA_DIR="/var/lib/claude"
export CLAUDE_LOG_DIR="/var/log/claude"

./claude-installer.sh --full
```

### Silent Installation
```bash
# No prompts, use defaults
./claude-installer.sh --full --silent

# With custom config
./claude-installer.sh --full --config install.conf
```

### Network Installation
```bash
# Install from URL
curl -sSL https://raw.githubusercontent.com/SWORDIntel/claude-backups/main/claude-installer.sh | bash
```

## 📝 Installation Configuration File

Create `install.conf`:
```ini
[Installation]
method=full
path=/opt/claude
auto_start=true

[Components]
wrapper=true
agents=true
database=true
ml_system=true
orchestration=true
hooks=true

[Database]
host=localhost
port=5432
name=claude_agents
user=claude
password=secure_password

[Features]
permission_bypass=true
auto_fix=true
debug=false
```

Use with:
```bash
./claude-installer.sh --config install.conf
```

## 🔐 Security Considerations

### Production Installation
```bash
# Secure installation for production
./claude-installer.sh --full --secure

# This enables:
# - Permission bypass disabled
# - Audit logging enabled
# - Restricted agent access
# - TLS for database
# - Secure file permissions
```

### Post-Installation Hardening
```bash
# Set restrictive permissions
chmod 700 ~/.local/bin/claude
chmod 600 ~/.cache/claude/*

# Disable debug mode
export CLAUDE_DEBUG=false
export CLAUDE_PERMISSION_BYPASS=false
```

## 📚 Next Steps

After installation:
1. [Configure your environment](../02-CONFIGURATION/environment-variables.md)
2. [Explore available agents](../03-AGENTS/complete-listing.md)
3. [Learn about hooks](../04-ADVANCED/hooks-system.md)
4. [Set up workflows](../06-WORKFLOWS/common-workflows.md)

---
*Installation Guide v1.0 | Framework v7.0*