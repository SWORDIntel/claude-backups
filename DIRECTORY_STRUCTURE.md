# Claude Project Directory Structure

## Root Directory Organization

```
/home/ubuntu/Documents/Claude/
├── claude-installer.sh      # Master installer (symlink to installers/)
├── claude-unified           # Main unified command (symlink to orchestration/)
├── CLAUDE.md               # Core project context
├── README.md               # Project overview
├── VERSION                 # Version tracking
├── MANIFEST.txt           # File manifest
│
├── installers/            # Installation scripts
│   ├── claude-installer.sh          # Master installer (actual file)
│   ├── claude-livecd-unified-with-agents.sh
│   ├── claude-quick-launch-agents.sh
│   ├── install.sh
│   └── install-global-agents.sh
│
├── orchestration/         # Orchestration system
│   ├── claude-orchestration-bridge.py
│   ├── claude-orchestrate
│   ├── claude-unified               # Unified command (actual file)
│   ├── claude-enhanced
│   └── python-orchestrator-launcher.sh
│
├── config/               # Configuration files
│   ├── agent-invocation-patterns.yaml
│   ├── claude-agents-global-config.json
│   ├── claude-agent-monitor.service
│   └── statusline.lua
│
├── tools/                # Utility tools
│   ├── register-custom-agents.py
│   ├── standardize-all-agents.py
│   ├── claude-global-agents-bridge.py
│   ├── claude-agents-mcp-server.py
│   ├── agent-semantic-matcher.py
│   ├── claude-fuzzy-agent-matcher.py
│   ├── agent_color_batch_update.sh
│   ├── check_final_status.sh
│   └── test-sync-integration.sh
│
├── docs/                 # Documentation
│   ├── SEAMLESS_INTEGRATION.md
│   ├── UNIFIED_ORCHESTRATION_SYSTEM.md
│   ├── claude-auto-invoke-agents.md
│   ├── statusline.md
│   └── [other documentation files]
│
├── agents/               # Agent definitions
│   ├── *.md             # 37 agent definitions
│   ├── src/             # Source code
│   │   ├── c/          # C implementations
│   │   ├── python/     # Python implementations
│   │   └── rust/       # Rust implementations
│   └── [other agent directories]
│
└── scripts/             # Helper scripts
    ├── fix-repos.sh
    └── repos.sh
```

## Quick Access

- **To install**: Run `./claude-installer.sh`
- **To use Claude**: Run `./claude-unified`
- **To check agents**: Look in `agents/` directory
- **To configure**: Edit files in `config/` directory
- **To read docs**: Browse `docs/` directory

## Import Path Notes

All installer scripts have been updated to reference files from their new locations.
Symlinks ensure backward compatibility for critical commands.
