# Claude Agent Framework - Directory Structure Guide

## 📁 Complete Directory Organization

This document provides a comprehensive overview of the Claude Agent Framework v7.0 directory structure, explaining the purpose and contents of each directory.

```
/home/ubuntu/Downloads/claude-backups/
├── 📄 Core Files
│   ├── CLAUDE.md                    # Global project context and agent auto-invocation guide
│   ├── README.md                    # Project overview and quick start
│   ├── VERSION                      # Current version (7.0)
│   ├── MANIFEST.txt                 # Complete file manifest
│   ├── .gitignore                   # Git ignore patterns
│   └── LICENSE                      # Project license
│
├── 🔧 Wrappers & Launchers
│   ├── claude-wrapper-ultimate.sh   # v13.1 Ultimate wrapper with agent discovery
│   ├── claude-unified               # Unified orchestration + permission bypass
│   ├── claude-enhanced              # Seamless integration wrapper
│   ├── claude-orchestrate           # Direct orchestration access
│   ├── claude-installer.sh          # Universal installer v4.0
│   ├── claude-portable-launch.sh    # Portable installation launcher
│   ├── claude-quick-launch-agents.sh # Quick system installation
│   └── python-orchestrator-launcher.sh # Python orchestration launcher
│
├── 📚 docs/                         # Comprehensive documentation
│   ├── README.md                    # Documentation index
│   ├── 00-OVERVIEW/                # Project overview
│   │   ├── project-overview.md     # Complete system overview
│   │   ├── architecture.md         # System architecture
│   │   └── directory-structure.md  # This file
│   ├── 01-GETTING-STARTED/         # Getting started guides
│   │   ├── README.md               # Quick start guide
│   │   ├── installation-guide.md   # Detailed installation
│   │   └── first-steps.md         # Initial usage guide
│   ├── 02-CONFIGURATION/           # Configuration guides
│   │   ├── environment-variables.md # Environment setup
│   │   ├── config-files.md        # Configuration files
│   │   └── database-setup.md      # Database configuration
│   ├── 03-AGENTS/                  # Agent documentation
│   │   ├── complete-listing.md    # All 71 agents
│   │   ├── categories.md          # Agent categories
│   │   └── coordination.md        # Agent coordination patterns
│   ├── 04-ADVANCED/                # Advanced features
│   │   ├── hooks-system.md        # Hooks system documentation
│   │   ├── performance-tuning.md  # Performance optimization
│   │   └── security.md            # Security features
│   ├── 05-SYSTEMS/                 # Core systems
│   │   ├── ml-learning-system.md  # ML Learning System v3.1
│   │   ├── tandem-orchestration.md # Tandem Orchestration
│   │   ├── binary-communication.md # Binary Communication Protocol
│   │   └── database-architecture.md # PostgreSQL architecture
│   ├── 06-WORKFLOWS/               # Workflow examples
│   │   ├── common-workflows.md    # Standard workflows
│   │   ├── security-audit.md      # Security audit workflow
│   │   └── development-cycle.md   # Development workflow
│   ├── fixes/                      # Bug fixes and patches
│   │   ├── BASH_OUTPUT_FIX_SUMMARY.md # Bash output fix
│   │   └── VERIFICATION_REPORT.md # Fix verification
│   ├── features/                   # New features
│   ├── guides/                     # User guides
│   ├── technical/                  # Technical specs
│   └── CONTRIBUTING.md             # Contribution guidelines
│
├── 🤖 agents/                       # 71 Specialized Agents
│   ├── Template.md                 # v7.0 agent template
│   ├── DIRECTOR.md                 # Strategic command agent
│   ├── PROJECTORCHESTRATOR.md      # Tactical coordination
│   ├── [69 more agent files...]    # All specialized agents
│   │
│   ├── src/                        # Agent source code
│   │   ├── c/                      # C implementations
│   │   │   ├── runtime/            # Runtime system
│   │   │   │   ├── main.c         # Runtime entry
│   │   │   │   ├── shm_arena.c    # Shared memory
│   │   │   │   ├── module_loader.c # Module loading
│   │   │   │   └── io_dispatcher.c # I/O dispatch
│   │   │   ├── agents/             # Agent implementations
│   │   │   │   ├── director_agent.c
│   │   │   │   ├── security_agent.c
│   │   │   │   └── [69 more .c files]
│   │   │   ├── Makefile            # Build system
│   │   │   └── Makefile.modular    # Modular build
│   │   │
│   │   ├── python/                 # Python components
│   │   │   ├── production_orchestrator.py # Main orchestrator
│   │   │   ├── agent_registry.py   # Agent discovery
│   │   │   ├── test_tandem_system.py # Test suite
│   │   │   ├── postgresql_learning_system.py # ML engine
│   │   │   ├── learning_orchestrator_bridge.py # Integration
│   │   │   ├── integrated_learning_setup.py # Setup script
│   │   │   ├── learning_config_manager.py # Config manager
│   │   │   └── launch_learning_system.sh # Launcher
│   │   │
│   │   └── rust/                   # Rust components
│   │       └── [Future Rust implementations]
│   │
│   ├── binary-communications-system/ # Binary protocol
│   │   ├── msg_router.c           # Message router
│   │   ├── protocol.h             # Protocol definitions
│   │   ├── auth_security.c        # Authentication
│   │   └── performance_test.c     # Performance tests
│   │
│   ├── docs/                       # Agent-specific docs
│   ├── monitoring/                 # Monitoring tools
│   ├── system/                     # System scripts
│   │   ├── switch.sh              # Mode switcher
│   │   ├── status.sh              # Status checker
│   │   └── bring-online.sh        # System startup
│   └── admin/                      # Admin tools
│
├── 💾 database/                     # PostgreSQL 16/17 System
│   ├── README.md                   # Database overview
│   ├── manage_database.sh          # Management script
│   ├── sql/                        # SQL schemas
│   │   ├── auth_db_setup.sql      # Auth schema
│   │   ├── learning_schema.sql    # Learning schema
│   │   └── agent_registry.sql     # Agent registry
│   ├── python/                     # Python utilities
│   │   ├── db_connection.py       # Connection manager
│   │   └── migrations.py          # Schema migrations
│   ├── scripts/                    # Deployment scripts
│   │   ├── install_postgres.sh    # PostgreSQL install
│   │   └── configure_pgvector.sh  # pgvector setup
│   ├── tests/                      # Performance tests
│   │   ├── auth_performance.py    # Auth benchmarks
│   │   └── learning_tests.py      # Learning tests
│   └── docs/                       # Database docs
│       ├── auth_database_architecture.md
│       └── BINARY_INTEGRATION_READINESS.md
│
├── ⚙️ config/                       # Configuration files
│   ├── database.json               # Database config
│   ├── learning_config.json        # Learning system config
│   ├── orchestration.json          # Orchestration config
│   ├── agents.json                 # Agent registry cache
│   └── .env.example                # Environment template
│
├── 🛠️ tools/                        # Development tools
│   ├── claude-global-agents-bridge.py # Global bridge v10.0
│   ├── agent_validator.py          # Agent validation
│   ├── performance_profiler.py     # Performance analysis
│   └── debug_helper.sh             # Debug utilities
│
├── 📜 scripts/                      # Utility scripts
│   ├── backup.sh                   # Backup script
│   ├── restore.sh                  # Restore script
│   ├── health_check.sh             # System health check
│   └── update.sh                   # Update script
│
├── 🎼 orchestration/                # Orchestration tools
│   ├── workflows/                  # Workflow definitions
│   │   ├── security_audit.yaml    # Security workflow
│   │   ├── development.yaml        # Dev workflow
│   │   └── deployment.yaml         # Deploy workflow
│   └── templates/                  # Workflow templates
│
├── 📦 installers/                   # Installation packages
│   ├── deb/                        # Debian packages
│   ├── rpm/                        # RPM packages
│   └── docker/                     # Docker files
│       ├── Dockerfile              # Container definition
│       └── docker-compose.yml      # Compose config
│
├── 🧪 tests/                        # Test suites
│   ├── unit/                       # Unit tests
│   ├── integration/                # Integration tests
│   ├── performance/                # Performance tests
│   └── e2e/                        # End-to-end tests
│
├── 📝 logs/                         # System logs
│   ├── agent.log                   # Agent activity
│   ├── orchestration.log           # Orchestration events
│   ├── error.log                   # Error logs
│   └── audit.log                   # Security audit
│
├── 💾 cache/                        # Cache directory
│   ├── agent_registry.json         # Agent cache
│   ├── learning_models/            # ML models
│   └── compiled/                   # Compiled binaries
│
├── 🗄️ backup/                       # Backup storage
│   ├── database/                   # Database backups
│   ├── config/                     # Config backups
│   └── agents/                     # Agent backups
│
└── 🗑️ deprecated/                   # Deprecated code
    ├── old_agents/                 # Legacy agents
    ├── v6_code/                    # Version 6 code
    └── README.md                   # Deprecation notes
```

## Directory Purposes

### Core Directories

#### `/` (Root)
Contains essential project files:
- **CLAUDE.md**: Master documentation with auto-invocation patterns
- **Wrappers**: Various Claude command wrappers for different use cases
- **Installers**: Installation scripts for different environments

#### `docs/`
Comprehensive documentation organized by topic:
- **00-OVERVIEW**: High-level project information
- **01-GETTING-STARTED**: New user guides
- **02-CONFIGURATION**: Setup and configuration
- **03-AGENTS**: Agent documentation
- **04-ADVANCED**: Advanced features
- **05-SYSTEMS**: Core system documentation
- **06-WORKFLOWS**: Workflow examples

#### `agents/`
Heart of the system with 71 specialized agents:
- **Agent Files**: Individual .md files for each agent
- **src/**: Source code in C, Python, and Rust
- **binary-communications-system/**: High-performance messaging
- **system/**: System management scripts

#### `database/`
PostgreSQL 16/17 database system:
- **sql/**: Schema definitions
- **python/**: Database utilities
- **scripts/**: Setup and deployment
- **tests/**: Performance benchmarks

### Supporting Directories

#### `config/`
Configuration files for all systems:
- Database connections
- Learning system settings
- Orchestration parameters
- Agent registries

#### `tools/`
Development and debugging tools:
- Global agents bridge
- Validation utilities
- Performance profilers
- Debug helpers

#### `orchestration/`
Workflow management:
- Pre-built workflows
- Workflow templates
- Execution configurations

#### `tests/`
Comprehensive test coverage:
- Unit tests for components
- Integration tests for systems
- Performance benchmarks
- End-to-end validation

### Operational Directories

#### `logs/`
System logging:
- Agent activity logs
- Orchestration events
- Error tracking
- Security audits

#### `cache/`
Performance optimization:
- Agent registry cache
- ML model storage
- Compiled binaries

#### `backup/`
Data protection:
- Database backups
- Configuration snapshots
- Agent state preservation

## File Naming Conventions

### Agent Files
- **Format**: `AGENTNAME.md` (ALL CAPS)
- **Example**: `DIRECTOR.md`, `SECURITY.md`

### Source Files
- **C Files**: `snake_case.c`
- **Python Files**: `snake_case.py`
- **Headers**: `snake_case.h`

### Documentation
- **Guides**: `kebab-case.md`
- **Technical**: `CAPS_FOR_EMPHASIS.md`

### Scripts
- **Shell Scripts**: `kebab-case.sh`
- **Python Scripts**: `snake_case.py`

## Key File Locations

### Essential Files
```bash
# Project documentation
/home/ubuntu/Downloads/claude-backups/CLAUDE.md
/home/ubuntu/Downloads/claude-backups/README.md

# Main wrapper
/home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh

# Installer
/home/ubuntu/Downloads/claude-backups/claude-installer.sh

# Orchestrator
/home/ubuntu/Downloads/claude-backups/agents/src/python/production_orchestrator.py

# Learning system
/home/ubuntu/Downloads/claude-backups/integrated_learning_setup.py
```

### Agent Locations
```bash
# Command & Control
agents/DIRECTOR.md
agents/PROJECTORCHESTRATOR.md

# Security specialists (13 agents)
agents/SECURITY.md
agents/CSO.md
agents/SECURITYAUDITOR.md
# ... and 10 more

# Development agents (8 agents)
agents/ARCHITECT.md
agents/CONSTRUCTOR.md
agents/DEBUGGER.md
# ... and 5 more
```

### Configuration Files
```bash
# Database
config/database.json

# Learning
config/learning_config.json

# Orchestration
config/orchestration.json

# Environment
config/.env
```

## Directory Size Guidelines

### Expected Sizes
- **agents/**: ~50MB (includes all agent definitions and source)
- **database/**: ~10MB (schemas and scripts)
- **docs/**: ~20MB (comprehensive documentation)
- **cache/**: Variable (can grow to 1GB+)
- **logs/**: Variable (rotate at 100MB)

### Cleanup Targets
```bash
# Safe to clean
cache/
logs/*.log
backup/old/

# Never clean
agents/*.md
database/sql/
config/
```

## Access Patterns

### Read-Heavy Directories
- `agents/` - Constant agent discovery
- `config/` - Configuration loading
- `docs/` - Documentation access

### Write-Heavy Directories
- `logs/` - Continuous logging
- `cache/` - Dynamic caching
- `database/` - Data persistence

### Performance-Critical
- `agents/binary-communications-system/` - 4.2M msg/sec
- `agents/src/c/runtime/` - Low-latency operations
- `cache/compiled/` - Binary execution

## Best Practices

### Organization
1. Keep agent files in root of `agents/`
2. Source code in `agents/src/<language>/`
3. Documentation in `docs/` with clear categories
4. Configuration in `config/` with .example templates

### Maintenance
1. Regular log rotation (daily)
2. Cache cleanup (weekly)
3. Backup verification (weekly)
4. Deprecated code review (monthly)

### Development
1. New agents go in `agents/` directory
2. Tests mirror source structure
3. Documentation updates with code
4. Configuration changes need .example updates

---
*Directory Structure Guide v1.0 | Framework v7.0*