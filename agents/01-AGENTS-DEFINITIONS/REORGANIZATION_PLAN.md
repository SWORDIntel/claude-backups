# Agents Directory Reorganization Plan

## Current Issues
1. Mixed production and migration files
2. Unclear naming conventions  
3. Duplicate/backup files scattered
4. Stub agents mixed with functional ones
5. Voice system files deprecated but referenced

## Proposed Structure

```
agents/
├── 00-STARTUP/                      # System initialization
│   ├── BRING_ONLINE.sh              # Main startup script
│   ├── STATUS.sh                    # System status checker
│   └── verify_integration.sh        # Integration verifier
│
├── 01-AGENTS-DEFINITIONS/           # Agent markdown definitions
│   ├── ACTIVE/                      # Production agents
│   │   ├── Director.md
│   │   ├── ProjectOrchestrator.md
│   │   └── [26 other .md files]
│   ├── Template.md                  # Agent template
│   └── README.md                    # Agent system docs
│
├── 02-BINARY-PROTOCOL/              # Core binary communication
│   ├── ultra_hybrid_enhanced.c      # Main protocol (4.2M msg/sec)
│   ├── ultra_fast_protocol.h        # Protocol API
│   ├── hybrid_protocol_asm.S        # AVX-512 optimizations
│   ├── compatibility_layer.h        # Compatibility header
│   └── README_PRODUCTION.md         # Protocol documentation
│
├── 03-BRIDGES/                      # Connection layers
│   ├── agent_server.py              # Binary protocol server
│   ├── claude_agent_bridge.py       # Claude Code bridge config
│   └── bridge_monitor.py            # Bridge monitoring
│
├── 04-SOURCE/                       # Implementation code
│   ├── c-implementations/           # C agent implementations
│   │   ├── COMPLETE/               # Fully implemented
│   │   │   ├── unified_agent_runtime.c
│   │   │   ├── message_router.c
│   │   │   ├── agent_discovery.c
│   │   │   ├── auth_security.c
│   │   │   └── [other complete agents]
│   │   └── STUBS/                  # 65-line stub files
│   │       └── [23 stub files]
│   ├── python-modules/              # Python support
│   │   └── ENHANCED_AGENT_INTEGRATION.py
│   └── rust-components/             # Rust components
│       └── vector_router.rs
│
├── 05-CONFIG/                       # Configuration files
│   ├── agents.yaml                  # Agent configuration
│   ├── meteor_lake_config.json      # Hardware config
│   ├── security_config.json         # Security settings
│   └── voice_config.json            # Voice settings (deprecated?)
│
├── 06-BUILD-RUNTIME/                # Build artifacts and runtime
│   ├── build/                       # Compiled binaries
│   └── runtime/                     # Runtime sockets
│
├── 07-SERVICES/                     # System services
│   ├── claude-agents.service        # Systemd service
│   └── run_agent_system.sh          # Service runner
│
├── 08-ADMIN-TOOLS/                  # Administration
│   ├── admin_core.py
│   ├── claude_admin_cli.py
│   └── deployment_manager.py
│
├── 09-MONITORING/                   # Monitoring and metrics
│   ├── prometheus_config.yml
│   ├── grafana_dashboard.json
│   └── transport_metrics_exporter.c
│
├── 10-TESTS/                        # Testing
│   ├── run_all_tests.sh
│   ├── test_agent_communication.py
│   └── test_performance.c
│
├── 11-DOCS/                         # Documentation
│   ├── AGENT_FRAMEWORK_V7.md
│   ├── COMMUNICATION_SYSTEM_V3.md
│   └── WHERE_I_AM.md
│
└── DEPRECATED/                      # Deprecated files
    ├── migration-files/             # Old migration scripts
    ├── optimizer-backups/           # Optimizer backup files
    ├── old-voice-system/           # Old voice implementation
    └── backup_current/             # Old agent backups
```

## Renaming Strategy

### Clear Prefixes for File Types
- `STARTUP_*.sh` - Initialization scripts
- `AGENT_*.md` - Agent definitions
- `PROTOCOL_*.c` - Binary protocol files
- `BRIDGE_*.py` - Bridge/connection files
- `CONFIG_*.json/yaml` - Configuration files
- `TEST_*.py/c` - Test files
- `ADMIN_*.py` - Admin tools
- `MONITOR_*.py/c` - Monitoring tools

### Examples of New Names
- `BRING_ONLINE.sh` → `STARTUP_main.sh`
- `ultra_hybrid_enhanced.c` → `PROTOCOL_main.c`
- `agent_server.py` → `BRIDGE_binary_server.py`
- `claude_agent_bridge.py` → `BRIDGE_claude_config.py`

## Key Dependencies to Update

1. **BRING_ONLINE.sh references:**
   - `$BINARY_SRC_DIR/ultra_hybrid_enhanced.c`
   - `$AGENTS_DIR/claude_agent_bridge.py`
   - Socket paths in multiple files

2. **Python imports:**
   - `from claude_agent_bridge import`
   - Socket path configurations

3. **C includes:**
   - `#include "ultra_fast_protocol.h"`
   - `#include "compatibility_layer.h"`

4. **Service files:**
   - Paths in claude-agents.service
   - References in run_agent_system.sh

## Action Plan

1. Create new directory structure
2. Move files with clear names
3. Update all path references
4. Test BRING_ONLINE.sh still works
5. Verify agents can still be invoked
6. Clean up deprecated folder