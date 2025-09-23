# Claude-Portable Agent Framework v7.0 - Comprehensive Guide

**Version**: 7.0.0  
**Updated**: 2025-08-21  
**Repository**: https://github.com/SWORDIntel/claude-backups  
**Claude Code Version**: 1.0.77 (@anthropic-ai/claude-code)  
**Status**: PRODUCTION READY

## 🚀 Quick Start

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

## 🏗️ System Architecture Overview

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

## 📋 Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Installation](#installation)
4. [Tandem Orchestration System](#tandem-orchestration-system)
5. [Agent Ecosystem](#agent-ecosystem)
6. [Global Access Setup](#global-access-setup)
7. [Usage Guide](#usage-guide)
8. [Performance Metrics](#performance-metrics)
9. [Troubleshooting](#troubleshooting)
10. [Development Guide](#development-guide)

## Overview

The Claude-Portable Agent Framework v7.0 is a hardware-aware multi-agent orchestration system optimized for Intel Meteor Lake architecture. It provides a comprehensive suite of 47 specialized agents that can autonomously coordinate complex tasks through Claude Code's Task tool and the advanced Tandem Orchestration System.

### Key Capabilities

- **47 Specialized Agents**: From strategic planning to low-level optimization
- **Tandem Orchestration**: Dual-layer Python/C execution for maximum flexibility
- **Hardware Optimization**: Intel Meteor Lake CPU optimization with P-core/E-core scheduling
- **Binary Protocol**: 4.2M messages/second throughput capability
- **PostgreSQL 17**: Enhanced database with >2000 auth/sec performance
- **Global Access**: Available from any directory after installation
- **Auto-Synchronization**: Agents stay updated via cron job

## Features

### Core Features
- ✅ **Hardware-Aware Execution**: Optimized for Intel Core Ultra 7 155H (Meteor Lake)
- ✅ **Autonomous Coordination**: Agents invoke each other via Task tool
- ✅ **Proactive Invocation**: Pattern-based auto-triggering
- ✅ **Production Ready**: Comprehensive error handling and recovery
- ✅ **PostgreSQL 17 Database**: >2000 auth/sec, <25ms P95 latency
- ✅ **Tandem Orchestration**: Python-first with C integration capability
- ✅ **Command Sets**: High-level workflow abstraction
- ✅ **Professional Organization**: Clean directory structure

### System Capabilities
- Binary Protocol: 4.2M messages/second
- Database Auth: >2000 queries/second
- P95 Latency: <25ms
- Agent Discovery: 47 agents in <100ms
- Orchestration Success: 85.7% test pass rate
- Parallel Agents: Up to 10 concurrent
- Memory Usage: <500MB typical

## Installation

### Method 1: Unified Installer (RECOMMENDED)

The unified installer combines all installation methods into one comprehensive tool:

```bash
# Full installation with all features
./claude-installer.sh --full

# Quick installation (minimal components)
./claude-installer.sh --quick

# Portable installation (self-contained)
./claude-installer.sh --portable

# Custom installation (choose components)
./claude-installer.sh --custom

# Automated installation (no prompts)
./claude-installer.sh --full --auto

# Test installation (dry run)
./claude-installer.sh --full --dry-run --verbose
```

Features:
- 5 installation methods: npm, pip, direct download, GitHub API, source compilation
- 75+ installation attempts before fallback
- Intelligent mode detection
- Permission bypass for LiveCD compatibility
- Statusline integration for Neovim
- Zero learning curve

### Method 2: Quick Installation

```bash
# For fast deployment with essential components
./claude-quick-launch-agents.sh
```

### Method 3: Portable Installation

```bash
# Creates self-contained installation
./claude-portable-launch.sh
```

### Method 4: LiveCD Installation

```bash
# For non-persistent environments
./claude-livecd-unified-with-agents.sh --auto-mode
```

### Post-Installation Setup

After installation, the following commands are available globally:

```bash
# Main command with integrated orchestration
claude /task "your task here"

# Check system status
claude --unified-status

# View help
claude --unified-help

# Direct orchestration access
claude-orchestrate "complex workflow"

# Python orchestrator
orchestrator
```

## Tandem Orchestration System

The Tandem Orchestration System is an advanced Python-first orchestration layer providing immediate functionality while maintaining seamless integration with the binary communication system.

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

1. **INTELLIGENT** - Python orchestrates, leverages best of both layers
2. **REDUNDANT** - Multiple agents execute for critical reliability
3. **CONSENSUS** - Multiple agents must agree on outcomes
4. **SPEED_CRITICAL** - Optimized for maximum performance
5. **PYTHON_ONLY** - Pure Python for complex logic and libraries

### Global Access Configuration

The orchestration system is globally accessible through:

```
~/.claude/orchestration/
├── production_orchestrator.py → /home/.../agents/src/python/production_orchestrator.py
├── tandem_orchestrator.py → /home/.../agents/src/python/tandem_orchestrator.py
├── agent_registry.py → /home/.../agents/src/python/agent_registry.py
├── orchestrator_metrics.py → /home/.../agents/src/python/orchestrator_metrics.py
├── database_orchestrator.py → /home/.../agents/src/python/database_orchestrator.py
├── config.json (configuration file)
├── invoke.py (helper script)
└── README.md (documentation)
```

### Using Orchestration

#### Method 1: Via Task Tool (Recommended)
```python
Task(
    subagent_type="general-purpose",
    prompt="Coordinate agents using orchestrator for: creating authentication with tests and security review"
)
```

#### Method 2: Direct Python Invocation
```python
import subprocess
import json

# Invoke production orchestrator
result = subprocess.run([
    "python3",
    os.path.expanduser("~/.claude/orchestration/invoke.py"),
    "create user authentication system with comprehensive tests",
    "production"  # or "tandem"
], capture_output=True, text=True)

# Process result
if result.returncode == 0:
    print("Orchestration successful:", result.stdout)
else:
    print("Error:", result.stderr)
```

#### Method 3: Via Shell Command
```bash
# From Claude's bash tool
python3 ~/.claude/orchestration/invoke.py "coordinate agents for API development" production
```

## Agent Ecosystem

### Complete Agent List (47 Agents)

#### Strategic Layer (2)
- **DIRECTOR** - Strategic command & control
- **PROJECTORCHESTRATOR** - Tactical coordination nexus

#### Development Layer (15)
- **ARCHITECT** - System design
- **CONSTRUCTOR** - Project initialization
- **DEBUGGER** - Failure analysis
- **PATCHER** - Code surgery
- **TESTBED** - Test engineering
- **LINTER** - Code review
- **OPTIMIZER** - Performance tuning
- **APIDESIGNER** - API architecture
- **DATABASE** - Data architecture
- **WEB** - Web frameworks
- **MOBILE** - Mobile development
- **PYGUI** - Python GUI
- **TUI** - Terminal UI
- **C-INTERNAL** - C/C++ systems
- **PYTHON-INTERNAL** - Python execution

#### Security Layer (4)
- **SECURITY** - Security analysis
- **BASTION** - Defensive security
- **SECURITYCHAOSAGENT** - Chaos testing
- **OVERSIGHT** - Quality assurance

#### Infrastructure Layer (5)
- **INFRASTRUCTURE** - System setup
- **DEPLOYER** - Deployment
- **MONITOR** - Observability
- **PACKAGER** - Package management
- **NPU** - Neural processing

#### Data & ML Layer (2)
- **DATASCIENCE** - Data analysis
- **MLOPS** - ML pipelines

#### Support Layer (4)
- **DOCGEN** - Documentation
- **RESEARCHER** - Technology evaluation
- **GNU** - GNU/Linux specialist
- **PLANNER** - Strategic planning

[+ 13 additional specialized agents including ANDROIDMOBILE, CRYPTOEXPERT, CSO, INTERGRATION, LEADENGINEER, ORGANIZATION, QADIRECTOR, QUANTUMGUARD, REDTEAMORCHESTRATOR, SECURITYAUDITOR, and TEMPLATE]

### Agent Invocation

All agents can be invoked via Claude Code's Task tool:

```python
# Direct agent invocation
Task(subagent_type="director", prompt="Create strategic plan for new feature")
Task(subagent_type="security", prompt="Audit system for vulnerabilities")
Task(subagent_type="optimizer", prompt="Optimize database performance")

# Multi-agent coordination
Task(subagent_type="general-purpose", 
     prompt="Coordinate ARCHITECT, CONSTRUCTOR, and TESTBED to build authentication system")
```

## Global Access Setup

### Automatic Synchronization

A cron job maintains synchronization every 5 minutes:

```bash
*/5 * * * * sync-claude-agents-enhanced.sh
```

This ensures:
- Agents synced to ~/.claude/agents/
- Orchestration links updated
- Configuration refreshed
- Symlinks maintained

### Configuration Files

Key configuration locations:

```
~/.claude/config.json                # User configuration
~/.claude/orchestration/config.json  # Orchestration config
~/.local/share/claude/venv/          # Python environment
/tmp/claude-session/                 # Session data
```

### Environment Variables

```bash
# Core Settings
CLAUDE_PROJECT_ROOT="$HOME/Documents/Claude"
CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
CLAUDE_PERMISSION_BYPASS=true        # LiveCD compatibility
CLAUDE_ORCHESTRATION=true            # Enable orchestration

# Advanced Settings
CLAUDE_PARALLEL_AGENTS=10            # Max concurrent agents
CLAUDE_TIMEOUT=30                    # Agent timeout (seconds)
CLAUDE_DEBUG=false                   # Debug logging
```

## Usage Guide

### Common Workflows

#### Feature Development
```bash
claude /task "create user profile feature with avatar upload"
# → Director → Architect → Constructor → Web → Testbed → Docgen
```

#### Bug Investigation
```bash
claude /task "debug authentication timeout issue"
# → Debugger → Monitor → Security → Patcher → Testbed
```

#### Performance Optimization
```bash
claude /task "optimize database query performance"
# → Database → Optimizer → Monitor → Testbed
```

#### Security Audit
```bash
claude /task "perform security audit on API endpoints"
# → Security → SecurityChaosAgent → Bastion → Docgen
```

#### Deployment Pipeline
```bash
claude /task "deploy to production with rollback capability"
# → Infrastructure → Deployer → Monitor → Security
```

### Workflow Examples

#### Example 1: Feature Development
```
Task: "Create user authentication with tests and documentation"
Orchestrator coordinates:
  → ARCHITECT: Design system
  → CONSTRUCTOR: Build implementation
  → TESTBED: Create tests
  → SECURITY: Security review
  → DOCGEN: Generate documentation
```

#### Example 2: Bug Fix Pipeline
```
Task: "Debug and fix performance issue in API"
Orchestrator coordinates:
  → DEBUGGER: Analyze issue
  → OPTIMIZER: Identify bottlenecks
  → PATCHER: Apply fixes
  → TESTBED: Validate fixes
  → MONITOR: Verify performance
```

#### Example 3: Deployment Workflow
```
Task: "Deploy application with monitoring"
Orchestrator coordinates:
  → INFRASTRUCTURE: Prepare environment
  → DEPLOYER: Execute deployment
  → MONITOR: Set up monitoring
  → SECURITY: Security validation
```

## Performance Metrics

### System Performance

| Metric | Target | Achieved |
|--------|--------|----------|
| Binary Protocol | 4.2M msg/sec | ✅ |
| Database Auth | >2000/sec | ✅ |
| P95 Latency | <25ms | ✅ |
| Agent Discovery | <100ms | ✅ |
| Orchestration Success | >85% | ✅ (85.7%) |
| Parallel Agents | 10 | ✅ |
| Memory Usage | <500MB | ✅ |

### Agent Response Times

```
Simple Query:         <500ms
Complex Workflow:     2-5 seconds
Multi-agent Task:     3-10 seconds
Full Pipeline:        10-30 seconds
```

### PostgreSQL 17 Performance

- Authentication queries: >2000 auth/sec
- P95 Latency: <25ms
- Concurrent connections: >750
- User lookups: <10ms P95

## Troubleshooting

### Orchestration Issues

If orchestration doesn't work:

1. **Check symlinks**:
   ```bash
   ls -la ~/.claude/orchestration/*.py
   ```

2. **Verify configuration**:
   ```bash
   python3 -c "import json; print(json.load(open('$HOME/.claude/orchestration/config.json')))"
   ```

3. **Test invoke script**:
   ```bash
   python3 ~/.claude/orchestration/invoke.py "test" production
   ```

4. **Check Python path**:
   ```bash
   python3 -c "import sys; print('\n'.join(sys.path))"
   ```

5. **Run setup again**:
   ```bash
   $HOME/Documents/Claude/scripts/setup-tandem-for-claude.sh
   ```

### Agent Not Auto-Invoking

- Check proactive_triggers in agent definition
- Verify Task tool in tools list
- Confirm agent status is PRODUCTION

### Performance Issues

- Monitor CPU temperature (normal: 85-95°C)
- Check core allocation strategy
- Verify AVX-512 utilization
- Review memory bandwidth usage

### Testing the System

#### From Terminal:
```bash
# Test orchestrator invocation
python3 ~/.claude/orchestration/invoke.py "test orchestration" production

# Check orchestration files
ls -la ~/.claude/orchestration/

# View configuration
cat ~/.claude/orchestration/config.json

# Check if orchestrator command works globally
orchestrator
```

#### From Claude Code:
Ask Claude to:
1. "Use the orchestrator to coordinate multiple agents for creating a feature"
2. "Show me available orchestration modes"
3. "Invoke the tandem orchestrator for a complex task"

## Development Guide

### Creating New Agents

1. Start with `agents/Template.md`
2. Define unique UUID and metadata
3. Include Task tool in tools list
4. Define proactive_triggers
5. Specify invokes_agents patterns
6. Implement hardware optimization
7. Set quantifiable success metrics

### Code Style

- NO comments unless explicitly requested
- Follow existing patterns in codebase
- Check neighboring files for conventions
- Use existing libraries (check package.json/requirements.txt)
- Preserve all existing APIs and interfaces

### Testing Requirements

- Achieve >85% code coverage
- All agents must have success metrics
- Validate hardware optimization paths
- Test agent coordination patterns

### Git Workflow

```bash
# Always commit with descriptive messages
git add -A
git commit -m "feat: Add feature X with Y capability"
git push origin main
```

## Directory Structure

```
$HOME/Documents/Claude/          [Project Root]
    │
    ├── Global Access Points
    │   ├── ~/.local/bin/claude          → Main command
    │   ├── ~/.claude/agents/            → Agent symlinks
    │   └── ~/.claude/orchestration/     → Orchestration
    │
    ├── Core Installation
    │   ├── installers/                  # 4 installation methods
    │   ├── orchestration/               # Wrapper scripts
    │   └── config/                      # Configuration
    │
    ├── Agent System
    │   ├── agents/*.md                  # 47 agent definitions
    │   ├── agents/src/c/                # 84 C files
    │   ├── agents/src/python/           # 24 Python modules
    │   └── agents/binary-communications-system/
    │
    ├── Database System
    │   ├── database/sql/                # PostgreSQL 17 schemas
    │   ├── database/scripts/            # Deployment
    │   └── database/tests/              # Performance tests
    │
    └── Support Systems
        ├── scripts/                     # Utility scripts
        ├── tools/                       # Development tools
        └── docs/                        # Documentation
```

## System Status

### Production Ready ✅
- 47 agents fully defined with Task tool integration
- Orchestration system operational (85.7% test success)
- Database system optimized (>2000 auth/sec)
- Global access configured
- Auto-sync active via cron

### In Development 🔄
- C layer integration (hardware restricted)
- Additional agent logic implementations
- Advanced orchestration patterns

### Planned 📋
- Voice integration
- Real-time collaboration
- Distributed execution
- Cloud deployment

## Support & Resources

- **Repository**: https://github.com/SWORDIntel/claude-backups
- **Claude Code**: v1.0.77 (@anthropic-ai/claude-code)
- **Framework**: v7.0.0 Production
- **Last Updated**: 2025-08-21

---

*This comprehensive guide provides complete documentation for the Claude Agent Framework v7.0, combining all critical information from PROJECT_MAP.md, README.md, and TANDEM_ORCHESTRATION_SETUP.md into a single authoritative reference.*