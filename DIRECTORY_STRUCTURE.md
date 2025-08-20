# Claude-Portable Agent Framework v7.0 - Directory Structure

**Last Updated**: 2025-08-20  
**Version**: 7.0.0  
**Status**: PRODUCTION

## Root Directory Organization

```
/home/siducer/Documents/Claude/
├── claude-installer.sh      # Master installer (symlink to installers/)
├── claude-unified           # Main unified command (symlink to orchestration/)
├── CLAUDE.md               # Core project context
├── README.md               # Project overview
├── VERSION                 # Version tracking
├── MANIFEST.txt           # File manifest
│
├── installers/            # Installation scripts
│   ├── claude-installer.sh          # Full installer v5.4 (43KB)
│   ├── claude-livecd-unified-with-agents.sh  # LiveCD installer (36KB)
│   ├── claude-portable-launch.sh    # Portable installer
│   ├── claude-quick-launch-agents.sh # Quick installer
│   └── install.sh                   # Basic installer
│
├── orchestration/         # Orchestration system
│   ├── claude-unified               # Main unified wrapper (426 lines)
│   ├── claude-orchestration-bridge.py # Python bridge
│   ├── claude-orchestrate          # Direct orchestration
│   ├── claude-enhanced             # Enhanced wrapper
│   └── python-orchestrator-launcher.sh # Standalone launcher
│
├── config/               # Configuration files
│   ├── agent-invocation-patterns.yaml
│   ├── claude-agents-global-config.json
│   ├── claude-agent-monitor.service
│   └── statusline.lua
│
├── scripts/              # Utility scripts
│   ├── sync-agents-to-claude.sh    # Agent sync to ~/.claude/
│   ├── setup-tandem-for-claude.sh  # Tandem setup script
│   └── test-agent-visibility.sh    # Agent visibility test
│
├── tools/                # Development tools
│   ├── register-custom-agents.py
│   ├── standardize-all-agents.py
│   ├── claude-global-agents-bridge.py
│   ├── claude-agents-mcp-server.py
│   └── [additional tools]
│
├── docs/                 # Project documentation
│   ├── SEAMLESS_INTEGRATION.md
│   ├── UNIFIED_ORCHESTRATION_SYSTEM.md
│   ├── claude-auto-invoke-agents.md
│   └── statusline.md
│
├── Documentation Files (root)
│   ├── CLAUDE_UNIFIED_SETUP.md      # Unified wrapper docs
│   ├── INSTALLER_COMPARISON.md      # Installer comparison
│   ├── AGENT_VISIBILITY_FIX.md      # Agent visibility fix
│   └── TANDEM_ORCHESTRATION_SETUP.md # Tandem setup guide
│
├── agents/               # 47 Agent Definitions + Source
│   ├── Agent Files (47 total)
│   │   ├── DIRECTOR.md              # Strategic command and control
│   │   ├── PROJECTORCHESTRATOR.md   # Tactical coordination
│   │   ├── ARCHITECT.md             # System design
│   │   ├── SECURITY.md              # Security analysis
│   │   ├── [43 more agents...]      # Complete ecosystem
│   │   └── Template.md              # v7.0 template
│   │
│   ├── src/                         # Source implementations
│   │   ├── c/                      # C implementations (84 files)
│   │   │   ├── *_agent.c files
│   │   │   └── runtime/
│   │   ├── python/                 # Python implementations (24 files)
│   │   │   ├── production_orchestrator.py
│   │   │   ├── tandem_orchestrator.py
│   │   │   └── agent_registry.py
│   │   └── rust/                   # Rust components
│   │
│   ├── binary-communications-system/ # 4.2M msg/sec protocol
│   ├── docs/                        # Agent documentation
│   ├── admin/                       # Administrative tools
│   └── monitoring/                  # System monitoring
│
├── database/             # PostgreSQL 17 Database System
│   ├── sql/             # SQL schemas (PostgreSQL 17)
│   ├── python/          # Python utilities
│   ├── scripts/         # Deployment scripts
│   ├── tests/           # Performance tests (>2000 auth/sec)
│   ├── docs/            # Database documentation
│   └── manage_database.sh # Management script
│
└── Other Files
    ├── requirements.txt  # Python dependencies
    ├── scandeps.py      # Dependency scanner
    └── .gitignore       # Git ignore rules
```

## Quick Access Commands

### Installation
```bash
./installers/claude-installer.sh --full    # Full installation
./installers/claude-livecd-unified-with-agents.sh  # LiveCD install
```

### Daily Use
```bash
claude /task "any task"         # Main command (from anywhere)
claude --unified-status         # Check system status
orchestrator                    # Launch orchestration
claude-agent --list            # List all agents
```

### Management
```bash
./scripts/sync-agents-to-claude.sh        # Sync agents
./scripts/setup-tandem-for-claude.sh      # Setup orchestration
./database/manage_database.sh             # Manage database
```

## Global Access Points

- **Main Command**: `/home/siducer/.local/bin/claude` → unified wrapper
- **Agents Location**: `~/.claude/agents/` → symlink to project
- **Orchestration**: `~/.claude/orchestration/` → tandem system
- **Virtual Environment**: `~/.local/share/claude/venv/`
- **Cron Sync**: Every 5 minutes automatic update

## System Metrics

| Component | Status | Performance |
|-----------|--------|-------------|
| Agents | 47 active | Task tool ready |
| Orchestration | Operational | 85.7% success rate |
| Database | PostgreSQL 17 | >2000 auth/sec |
| Protocol | Binary ready | 4.2M msg/sec |
| Python | 24 modules | Venv supported |
| C Code | 84 files | Runtime optimized |

## Environment Variables

```bash
export CLAUDE_PROJECT_ROOT="/home/siducer/Documents/Claude"
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
export CLAUDE_PERMISSION_BYPASS=true     # LiveCD mode
export CLAUDE_ORCHESTRATION=true         # Enable orchestration
```
