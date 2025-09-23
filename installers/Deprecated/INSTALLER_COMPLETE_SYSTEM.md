# Claude Master Installer v10.0 - Complete System

## Overview

The installer now installs **EVERYTHING** by default - no `--full` flag needed. Just run `./claude-installer.sh` and get the complete system automatically.

## What Gets Installed (Automatically)

### 1. Claude Code
- NPM package installation (with fallback methods)
- Enhanced wrapper with auto permission bypass
- Complete environment setup

### 2. All 42 Agents
- Copies agents to `~/agents/`
- Sets up auto-sync every 5 minutes
- Validates YAML frontmatter for Task tool

### 3. PostgreSQL Database System
- Local PostgreSQL instance on port 5433
- Self-contained in `database/data/postgresql/`
- Auth database with `claude_auth` user
- Automatic initialization and startup

### 4. Agent Learning System
- Machine learning models for agent optimization
- PostgreSQL-backed persistent storage
- Learning data syncs with GitHub
- CLI interface (`claude-learning`)

### 5. Tandem Orchestration
- Python-based orchestration system
- Agent registry with automatic discovery
- Multiple execution modes
- Performance monitoring

### 6. Hooks Integration
- Pre-commit: Auto-export learning data
- Post-task: Record executions
- Integration with existing hooks system
- Git hooks for automatic sync

### 7. Production Environment
- 100+ Python packages
- Virtual environment setup
- Requirements installation
- Complete dependency management

## Installation Process

```bash
# Just run the installer - it does everything!
cd $HOME/Documents/Claude
./installers/claude-installer.sh
```

The installer will:
1. ✅ Show what's being installed (no prompts needed)
2. ✅ Install Claude via npm/pip/direct methods
3. ✅ Copy and validate all agents
4. ✅ Initialize PostgreSQL database
5. ✅ Set up learning system with ML
6. ✅ Configure orchestration
7. ✅ Install hooks
8. ✅ Create all launchers and wrappers
9. ✅ Set up environment
10. ✅ Run validation tests

## Available Commands After Installation

```bash
# Main Claude command
claude                          # Run with auto permission bypass
claude --safe                   # Run without permission bypass
claude --status                 # Show system status
claude --list-agents           # List all agents
claude --orchestrator          # Launch orchestrator UI

# Learning system
claude-learning status         # Check learning status
claude-learning cli dashboard  # View learning dashboard
claude-learning cli analyze    # Analyze patterns

# Database
database/start_local_postgres.sh   # Start database
database/stop_local_postgres.sh    # Stop database
database/scripts/learning_sync.sh export  # Export learning data
database/scripts/learning_sync.sh import  # Import learning data

# Agent shortcuts
coder          # Quick access to coder agent
director       # Quick access to director agent
architect      # Quick access to architect agent
security       # Quick access to security agent
```

## Key Features

### Self-Contained Database
- Runs entirely from repository
- No external PostgreSQL required
- Port 5433 to avoid conflicts
- Automatic startup/shutdown

### Learning Data Persistence
- Exports to `database/learning_data/`
- Syncs with GitHub automatically
- Imports on new installations
- Continuous improvement across clones

### Complete Automation
- No user interaction required
- Smart fallbacks for all operations
- Handles all error cases
- Works on fresh systems

## Configuration

All configuration is automatic, but can be customized:

### Database
- Host: localhost
- Port: 5433
- Database: claude_auth
- User: claude_auth
- Password: claude_auth_pass

### Environment Variables
```bash
export CLAUDE_PERMISSION_BYPASS=false  # Disable auto bypass
export POSTGRES_PORT=5433              # Database port
export POSTGRES_DB=claude_auth         # Database name
```

## Troubleshooting

### If Installation Fails
```bash
# Check what's missing
./installers/test_installer.sh

# View installation log
cat ~/.local/share/claude/logs/install-*.log
```

### Database Issues
```bash
# Reset database
database/initialize_complete_system.sh reset
database/initialize_complete_system.sh setup

# Check database status
database/initialize_complete_system.sh status
```

### Learning System Issues
```bash
# Reinstall learning system
cd agents/src/python
python3 setup_learning_system.py

# Check learning status
claude-learning status
```

## What Changed in v10.0

1. **No More Options**: Everything installs by default
2. **Database Integration**: PostgreSQL system included
3. **Learning System**: ML-powered agent optimization
4. **GitHub Sync**: Automatic learning data preservation
5. **Complete Hooks**: Full automation support
6. **Better Progress**: Clear feedback during installation
7. **Comprehensive Testing**: Validates all components

## Summary

The installer is now truly "zero-configuration" - just run it and get a complete, production-ready Claude agent system with database, learning, orchestration, and full automation. Everything is self-contained within the repository and syncs with GitHub for persistence across installations.