# Agents Directory Organization

## Structure Overview
All agent .md files remain in the root agents/ directory for compatibility.

### Organized Directories:

#### system/ - System Management Scripts
- `BRING_ONLINE.sh` - System startup and initialization
- `STATUS.sh` - System status checking
- `switch.sh` - Mode switching between binary/.md modes
- `verify_agent_mode.sh` - Mode verification

#### services/ - Service Definitions
- `claude-agents.service` - Systemd service configuration

#### integration/ - Integration Tools
- `auto_integrate.py` - Auto integration script for new agents
- `statusline.lua` - Statusline configuration

#### backups/ - Backup Storage
- `backups.zip` - Compressed agent backups

### Convenience Shortcuts (in parent directory):
- `../switch` → Runs agents/system/switch.sh
- `../bring-online` → Runs agents/system/BRING_ONLINE.sh  
- `../status` → Runs agents/system/STATUS.sh
- Symlinks for backward compatibility where needed

### Agent Files:
All 40 agent .md files remain in the root directory to maintain compatibility
with existing scripts and references.

### Usage Examples:
```bash
# From Claude main directory (/home/ubuntu/Documents/Claude/):
./switch md                    # Switch to .md mode
./bring-online                 # Bring system online
./status                       # Check system status

# From agents/ directory:
../switch md                   # Switch to .md mode via parent shortcut
./system/switch.sh binary      # Switch to binary mode (full path)
./system/BRING_ONLINE.sh       # Full path to bring online
./system/STATUS.sh             # Full path to status
```

### Backward Compatibility:
Symlinks are maintained for files with external references:
- BRING_ONLINE.sh → system/BRING_ONLINE.sh
- STATUS.sh → system/STATUS.sh
- switch.sh → system/switch.sh
- auto_integrate.py → integration/auto_integrate.py (if referenced)
