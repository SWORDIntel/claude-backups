# Claude Upgrade System - Quick Reference

**Version**: 1.0 | **Date**: 2025-09-15

## 🚀 Quick Commands

### **Check What Needs Upgrading**
```bash
python3 upgrade-to-python-installer.py --analyze-only
```

### **Upgrade Everything**
```bash
python3 upgrade-to-python-installer.py --upgrade-all
```

### **Upgrade Specific Module**
```bash
python3 upgrade-to-python-installer.py --upgrade claude-code
```

### **Test Upgrade (No Changes)**
```bash
python3 upgrade-to-python-installer.py --upgrade-all --dry-run
```

### **Via Shell Wrapper**
```bash
./claude-python-installer.sh --upgrade
./claude-python-installer.sh --upgrade-module wrapper-system
```

## 📋 Available Modules

| Module | What It Updates |
|--------|-----------------|
| `claude-code` | Claude Code binary |
| `python-installer` | Installer components |
| `wrapper-system` | Shell wrappers |
| `agent-definitions` | Agent .md files |
| `learning-system` | ML system & database |
| `openvino-runtime` | OpenVINO AI runtime |
| `database-schema` | PostgreSQL schema |
| `all` | Everything |

## 🛡️ Safety Options

| Flag | Purpose |
|------|---------|
| `--dry-run` | Show what would happen |
| `--skip-backup` | Skip backup creation |
| `--verbose` | Show detailed output |
| `--analyze-only` | Just check versions |

## 📁 Important Locations

- **Backups**: `~/.config/claude/upgrade_backup/`
- **Logs**: `~/.config/claude/upgrade_backup/upgrade_log_*.txt`
- **Upgrade Script**: `upgrade-to-python-installer.py`
- **Shell Wrapper**: `claude-python-installer.sh`

## 🔧 Common Workflows

### **Safe Full Upgrade**
```bash
# 1. Check status
python3 upgrade-to-python-installer.py --analyze-only

# 2. Test upgrade
python3 upgrade-to-python-installer.py --upgrade-all --dry-run

# 3. Perform upgrade
python3 upgrade-to-python-installer.py --upgrade-all

# 4. Restart shell
source ~/.bashrc
```

### **Quick Claude Code Update**
```bash
python3 upgrade-to-python-installer.py --upgrade claude-code
```

### **Emergency Recovery**
```bash
# Restore from backup
cp ~/.config/claude/upgrade_backup/backup_*/claude ~/.local/bin/

# Or reinstall
./claude-enhanced-installer.py --mode full
```

## ⚡ One-Liners

```bash
# Check + upgrade if needed
python3 upgrade-to-python-installer.py --analyze-only && python3 upgrade-to-python-installer.py --upgrade-all

# Upgrade with full logging
python3 upgrade-to-python-installer.py --upgrade-all --verbose 2>&1 | tee upgrade.log

# Safe wrapper upgrade
python3 upgrade-to-python-installer.py --upgrade wrapper-system --dry-run && python3 upgrade-to-python-installer.py --upgrade wrapper-system
```

## 🚨 Emergency Commands

### **If Claude Stops Working**
```bash
# Quick fix via installer
./claude-enhanced-installer.py --mode full --auto

# Or restore wrapper
cp ~/.config/claude/upgrade_backup/backup_*/claude ~/.local/bin/
```

### **If Python Installer Breaks**
```bash
# Use legacy mode
python3 upgrade-to-python-installer.py --legacy --mode full
```

### **If Git Issues**
```bash
# Reset and retry
git stash
python3 upgrade-to-python-installer.py --upgrade agent-definitions
```

## 📊 Understanding Output

### **Status Indicators**
- `✓ INSTALLED` - Component is installed
- `✗ NOT INSTALLED` - Component missing
- `(NEEDS UPGRADE)` - Newer version available

### **Upgrade Results**
- `✓ SUCCESS` - Upgrade completed successfully
- `✗ FAILED` - Upgrade failed (check logs)
- `⚠ WARNING` - Upgrade completed with warnings

## 📞 Quick Help

```bash
python3 upgrade-to-python-installer.py --help
./claude-python-installer.sh --help
```

---
**💡 Tip**: Always run `--analyze-only` first to see what needs upgrading!