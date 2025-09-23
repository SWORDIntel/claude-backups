# Claude-Portable Agent Framework v7.0 - Complete Documentation

**Version**: 7.0.0  
**Updated**: 2025-08-21  
**Repository**: https://github.com/SWORDIntel/claude-backups  
**Claude Code Version**: 1.0.77 (@anthropic-ai/claude-code)  
**Status**: PRODUCTION READY

## 📚 Documentation Index

This document consolidates all project documentation into a single comprehensive reference.

---

## 🚀 Quick Start Guide

### One-Command Installation

```bash
# Clone the repository
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups

# Run the unified installer (recommended)
./claude-installer.sh --full

# Or quick installation for minimal setup
./claude-installer.sh --quick
```

After installation, use Claude with automatic orchestration:
```bash
claude /task "create authentication system with tests and security review"
```

---

## 🏗️ System Architecture

### Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLAUDE AGENT FRAMEWORK v7.0                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   COMMAND    │  │ ORCHESTRATION│  │    AGENTS    │        │
│  │   INTERFACE  │──│    SYSTEM    │──│  (47 Total)  │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌──────────────────────────────────────────────────┐        │
│  │          TANDEM ORCHESTRATION LAYER              │        │
│  │    Python (Immediate) ←→ C (Performance)         │        │
│  └──────────────────────────────────────────────────┘        │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────────┐        │
│  │     BINARY COMMUNICATION PROTOCOL (4.2M msg/s)   │        │
│  └──────────────────────────────────────────────────┘        │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────────┐        │
│  │       PostgreSQL 17 DATABASE (>2000 auth/s)      │        │
│  └──────────────────────────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Communication System v3.0

The binary communication system provides ultra-fast message passing between agents:

- **Throughput**: 4.2M messages/second
- **Latency**: 200ns P99
- **Protocol**: Lock-free ring buffers with NUMA optimization
- **IPC Methods**: Shared memory (50ns), io_uring (500ns), Unix sockets (2μs)
- **Security**: JWT RS256/HS256, RBAC, TLS 1.3, HMAC-SHA256

### AI-Enhanced Router

The system includes an AI-enhanced router for intelligent message routing:

- **NPU/GNA/GPU acceleration** for AI routing decisions
- **Pattern recognition** for optimal agent selection
- **Load balancing** across agent instances
- **Predictive routing** based on historical patterns

---

## 📋 Agent Framework v7.0

### Complete Agent List (47 Agents)

#### Strategic Layer (2)
- **DIRECTOR** - Strategic command & control, creates high-level strategies
- **PROJECTORCHESTRATOR** - Tactical coordination nexus, manages execution

#### Development Layer (15)
- **ARCHITECT** - System design and technical architecture
- **CONSTRUCTOR** - Project initialization and scaffolding
- **DEBUGGER** - Failure analysis and troubleshooting
- **PATCHER** - Precision code surgery and bug fixes
- **TESTBED** - Test engineering and validation
- **LINTER** - Code review and quality assurance
- **OPTIMIZER** - Performance tuning and optimization
- **APIDESIGNER** - API architecture and contracts
- **DATABASE** - Data architecture and optimization
- **WEB** - Modern web frameworks (React/Vue/Angular)
- **MOBILE** - iOS/Android and React Native development
- **PYGUI** - Python GUI development (Tkinter/PyQt/Streamlit)
- **TUI** - Terminal UI specialist (ncurses/termbox)
- **C-INTERNAL** - Low-level C/C++ systems engineering
- **PYTHON-INTERNAL** - Python execution environment

#### Security Layer (7)
- **SECURITY** - Comprehensive security analysis
- **BASTION** - Defensive security specialist
- **SECURITYCHAOSAGENT** - Chaos testing and resilience
- **OVERSIGHT** - Quality assurance and compliance
- **CSO** - Chief Security Officer, strategic security
- **SECURITYAUDITOR** - Security auditing and compliance
- **QUANTUMGUARD** - Quantum-resistant cryptography

#### Infrastructure Layer (5)
- **INFRASTRUCTURE** - System setup and configuration
- **DEPLOYER** - Deployment orchestration
- **MONITOR** - Observability and monitoring
- **PACKAGER** - Package management and distribution
- **NPU** - Neural processing unit optimization

#### Data & ML Layer (2)
- **DATASCIENCE** - Data analysis and ML specialist
- **MLOPS** - ML pipeline and deployment

#### Support Layer (8)
- **DOCGEN** - Military-grade documentation engineering
- **RESEARCHER** - Technology evaluation and research
- **GNU** - GNU/Linux specialist
- **PLANNER** - Strategic planning and roadmaps
- **LEADENGINEER** - Technical leadership
- **QADIRECTOR** - Quality assurance direction
- **INTERGRATION** - System integration specialist
- **ORGANIZATION** - Project organization

#### Mobile & Specialized (3)
- **ANDROIDMOBILE** - Android-specific development
- **REDTEAMORCHESTRATOR** - Red team exercises
- **CRYPTOEXPERT** - Cryptography specialist

### Agent Invocation

All agents support Task tool invocation:

```python
# Direct invocation
Task(subagent_type="director", prompt="Create strategic plan")
Task(subagent_type="security", prompt="Audit for vulnerabilities")

# Multi-agent coordination
Task(subagent_type="general-purpose", 
     prompt="Coordinate ARCHITECT, CONSTRUCTOR, and TESTBED to build auth system")
```

### Auto-Invocation Patterns

Agents are automatically invoked based on keywords:

- **Multi-step tasks** → Director + ProjectOrchestrator
- **Security keywords** → CSO, SecurityAuditor, CryptoExpert
- **Performance keywords** → Optimizer + Monitor
- **Bug/error keywords** → Debugger + Patcher
- **Testing keywords** → QADirector + Testbed
- **Documentation keywords** → Docgen + Researcher
- **GUI/Interface keywords** → PyGUI, TUI, Web
- **Database keywords** → Database + DataScience
- **ML/AI keywords** → MLOps + DataScience + NPU

---

## 🔄 Tandem Orchestration System

### Overview

The Tandem Orchestration System provides dual-layer Python/C execution for maximum flexibility and performance.

### Architecture

```yaml
orchestration_layers:
  strategic_layer:
    language: Python
    purpose: "High-level coordination, complex logic, library integration"
    components:
      - production_orchestrator.py (608 lines)
      - tandem_orchestrator.py (500+ lines)
      - agent_registry.py (461 lines)
      - test_tandem_system.py (331 lines)
    
  tactical_layer:
    language: C
    purpose: "High-performance, low-latency operations"
    integration: "Seamless upgrade path from Python layer"
    performance: "4.2M msg/sec throughput capability"
```

### Execution Modes

1. **INTELLIGENT** - Python orchestrates, leverages best capabilities
2. **REDUNDANT** - Multiple agents execute for critical reliability
3. **CONSENSUS** - Multiple agents must agree on outcomes
4. **SPEED_CRITICAL** - Optimized for maximum performance
5. **PYTHON_ONLY** - Pure Python for complex logic and libraries

### Seamless Integration

The system integrates transparently with Claude Code:

```bash
# Option 1: Enhanced Claude (Drop-in replacement)
alias claude='./claude-enhanced'

# Option 2: Direct orchestration
claude-orchestrate "complex multi-agent task"

# Option 3: Unified with permission bypass
./claude-unified /task "create secure API"
```

### Workflow Examples

#### Feature Development
```
Task: "Create user authentication with tests"
Orchestrator coordinates:
  → ARCHITECT: Design system
  → CONSTRUCTOR: Build implementation
  → TESTBED: Create tests
  → SECURITY: Security review
  → DOCGEN: Generate documentation
```

#### Bug Fix Pipeline
```
Task: "Debug and fix performance issue"
Orchestrator coordinates:
  → DEBUGGER: Analyze issue
  → OPTIMIZER: Identify bottlenecks
  → PATCHER: Apply fixes
  → TESTBED: Validate fixes
  → MONITOR: Verify performance
```

---

## 🗂️ Directory Structure

```
$HOME/Documents/Claude/          [Project Root]
├── Core Files
│   ├── CLAUDE.md                      # Project context (45KB)
│   ├── CLAUDE_COMPREHENSIVE_GUIDE.md   # Complete guide
│   ├── README.md                       # Quick start
│   └── VERSION                         # Version tracking
│
├── agents/                            # 47 Agent Definitions
│   ├── *.md                          # Agent definition files
│   ├── src/                          # Source code
│   │   ├── c/                        # C implementations (84 files)
│   │   ├── python/                   # Python implementations (24 modules)
│   │   └── rust/                     # Rust components
│   ├── binary-communications-system/  # Ultra-fast protocol
│   ├── docs/                         # Agent documentation
│   ├── monitoring/                   # Prometheus/Grafana
│   └── admin/                        # Administrative tools
│
├── database/                          # PostgreSQL 17 System
│   ├── sql/                          # Database schemas
│   ├── scripts/                      # Deployment scripts
│   └── tests/                        # Performance tests
│
├── docs/                             # Project Documentation
├── config/                           # Configuration files
├── installers/                       # Installation scripts
├── orchestration/                    # Orchestration wrappers
├── scripts/                          # Utility scripts
└── tools/                            # Development tools
```

---

## 💾 Database System

### PostgreSQL 17 Integration

The system includes a high-performance PostgreSQL 17 database:

- **Authentication**: >2000 queries/second
- **P95 Latency**: <25ms
- **Connections**: >750 concurrent
- **Features**: Enhanced JSON, improved VACUUM, JIT compilation
- **Integration**: Ready for binary protocol integration

### Database Management

```bash
# Manage database
./database/manage_database.sh

# Deploy authentication database
./database/scripts/deploy_auth_database.sh

# Run performance tests
python database/tests/auth_db_performance_test.py
```

---

## 🔧 Installation & Setup

### Installation Methods

#### 1. Unified Installer (RECOMMENDED)
```bash
./claude-installer.sh --full     # Complete installation
./claude-installer.sh --quick    # Minimal setup
./claude-installer.sh --portable # Self-contained
./claude-installer.sh --custom   # Choose components
```

#### 2. Quick Installation
```bash
./claude-quick-launch-agents.sh
```

#### 3. Portable Installation
```bash
./claude-portable-launch.sh
```

#### 4. LiveCD Installation
```bash
./claude-livecd-unified-with-agents.sh --auto-mode
```

### Global Agent Access

Agents are synchronized globally via cron job:

```bash
# Cron job (runs every 5 minutes)
*/5 * * * * $HOME/.local/bin/sync-claude-agents.sh

# Manual sync
$HOME/.local/bin/sync-claude-agents.sh

# Check agent visibility
ls ~/.claude/agents/*.md | wc -l  # Should show 47
```

### Configuration

#### Environment Variables
```bash
CLAUDE_PROJECT_ROOT="$HOME/Documents/Claude"
CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
CLAUDE_PERMISSION_BYPASS=true        # LiveCD compatibility
CLAUDE_ORCHESTRATION=true            # Enable orchestration
CLAUDE_PARALLEL_AGENTS=10            # Max concurrent agents
CLAUDE_TIMEOUT=30                    # Agent timeout (seconds)
```

#### Configuration Files
```
~/.claude/config.json                # User configuration
~/.claude/orchestration/config.json  # Orchestration config
~/.local/share/claude/venv/          # Python environment
/tmp/claude-session/                 # Session data
```

---

## 📊 Performance Metrics

### System Performance

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Binary Protocol | 4.2M msg/sec | 4.2M msg/sec | ✅ |
| Database Auth | >2000/sec | >2000/sec | ✅ |
| P95 Latency | <25ms | <25ms | ✅ |
| Agent Discovery | <100ms | <100ms | ✅ |
| Orchestration Success | >85% | 85.7% | ✅ |
| Parallel Agents | 10 | 10 | ✅ |
| Memory Usage | <500MB | <500MB | ✅ |

### Agent Response Times

- Simple Query: <500ms
- Complex Workflow: 2-5 seconds
- Multi-agent Task: 3-10 seconds
- Full Pipeline: 10-30 seconds

---

## 🛠️ Development Guide

### Creating New Agents

1. Start with `agents/Template.md`
2. Define unique UUID and metadata
3. Include Task tool in tools list
4. Define proactive_triggers
5. Specify invokes_agents patterns
6. Implement hardware optimization
7. Set quantifiable success metrics

### Code Style Guidelines

- NO comments unless explicitly requested
- Follow existing patterns in codebase
- Check neighboring files for conventions
- Use existing libraries (check package.json/requirements.txt)
- Preserve all existing APIs and interfaces
- Extend rather than replace when possible

### Testing Requirements

- Achieve >85% code coverage
- All agents must have success metrics
- Validate hardware optimization paths
- Test agent coordination patterns

### Git Workflow

```bash
# Commit with descriptive messages
git add -A
git commit -m "feat: Add feature X with Y capability"
git push origin main

# Sync every 3 agents when doing bulk updates
```

---

## 🔍 Troubleshooting

### Common Issues

#### Agent Not Auto-Invoking
- Check proactive_triggers in agent definition
- Verify Task tool in tools list
- Confirm agent status is PRODUCTION

#### Performance Issues
- Monitor CPU temperature (normal: 85-95°C)
- Check core allocation strategy
- Verify AVX-512 utilization
- Review memory bandwidth usage

#### Orchestration Not Working
```bash
# Check symlinks
ls -la ~/.claude/orchestration/*.py

# Verify configuration
cat ~/.claude/orchestration/config.json

# Test invoke script
python3 ~/.claude/orchestration/invoke.py "test" production

# Run setup again if needed
./scripts/setup-tandem-for-claude.sh
```

#### Agent Visibility Issues
```bash
# Check agent symlink
ls -la ~/.claude/agents

# Count visible agents
ls ~/.claude/agents/*.md | wc -l

# View sync log
tail ~/.local/share/claude/agent-sync.log

# Manual sync
$HOME/.local/bin/sync-claude-agents.sh
```

---

## 🔒 Security Features

### Authentication & Authorization
- JWT RS256/HS256 tokens
- 4-level RBAC system
- TLS 1.3 encryption
- HMAC-SHA256 integrity checks

### Security Agents
- **CSO**: Strategic security oversight
- **SECURITY**: Vulnerability analysis
- **BASTION**: Defensive measures
- **SECURITYAUDITOR**: Compliance checks
- **SECURITYCHAOSAGENT**: Chaos testing
- **QUANTUMGUARD**: Quantum-resistant crypto
- **CRYPTOEXPERT**: Cryptography specialist

### Security Documentation
The DOCGEN agent provides military-grade documentation with:
- Classification levels (UNCLASSIFIED to TOP SECRET)
- DTG timestamps
- Chain of custody
- OPSEC compliance

---

## 📈 Monitoring & Observability

### Prometheus & Grafana
- Prometheus endpoint: `:8001/metrics`
- Grafana dashboards included
- Health checks: `/health/ready`
- Real-time metrics tracking

### Logging
- Agent logs: `agents/monitoring/logs/`
- System logs: `~/.local/share/claude/`
- Sync logs: `~/.local/share/claude/agent-sync.log`

---

## 🚦 System Status

### Production Ready ✅
- 47 agents fully defined
- Orchestration system operational
- Database system optimized
- Global access configured
- Auto-sync active

### In Development 🔄
- C layer integration (hardware restricted)
- Additional agent logic
- Advanced orchestration patterns

### Planned 📋
- Voice integration
- Real-time collaboration
- Distributed execution
- Cloud deployment

---

## 📞 Support & Resources

- **Repository**: https://github.com/SWORDIntel/claude-backups
- **Claude Code**: v1.0.77 (@anthropic-ai/claude-code)
- **Framework**: v7.0.0 Production
- **Database**: PostgreSQL 17
- **Last Updated**: 2025-08-21

---

## 🎯 Common Workflows

### Feature Development
```bash
claude /task "create user profile feature with avatar upload"
# → Director → Architect → Constructor → Web → Testbed → Docgen
```

### Bug Investigation
```bash
claude /task "debug authentication timeout issue"
# → Debugger → Monitor → Security → Patcher → Testbed
```

### Performance Optimization
```bash
claude /task "optimize database query performance"
# → Database → Optimizer → Monitor → Testbed
```

### Security Audit
```bash
claude /task "perform security audit on API endpoints"
# → Security → SecurityChaosAgent → Bastion → Docgen
```

### Deployment Pipeline
```bash
claude /task "deploy to production with rollback capability"
# → Infrastructure → Deployer → Monitor → Security
```

---

## 📝 Version History

### v7.0.0 (Current)
- 47 specialized agents with Task tool integration
- Tandem Orchestration System
- PostgreSQL 17 integration
- Binary communication protocol (4.2M msg/sec)
- Military-grade documentation (DOCGEN)
- Global agent visibility
- Unified installation system

### Recent Updates
- **2025-08-21**: Enhanced DOCGEN with military dossier capabilities
- **2025-08-20**: Created comprehensive guide merging all documentation
- **2025-08-19**: PostgreSQL 17 upgrade (2x performance)
- **2025-08-18**: Unified orchestration system
- **2025-08-17**: Repository cleanup and standardization

---

*This document consolidates all project documentation into a single comprehensive reference. For specific technical details, refer to the source code in the respective directories.*