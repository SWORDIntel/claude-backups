# Claude-Portable Agent Framework v7.0

**Complete Multi-Agent Orchestration System with 47 Specialized Agents**

[![Version](https://img.shields.io/badge/version-7.0.0-blue.svg)](VERSION)
[![Status](https://img.shields.io/badge/status-production-green.svg)](docs/COMPLETE_DOCUMENTATION.md)
[![Agents](https://img.shields.io/badge/agents-47-orange.svg)](agents/)
[![Performance](https://img.shields.io/badge/throughput-4.2M%20msg%2Fs-red.svg)](docs/TECHNICAL_REFERENCE.md)
[![Database](https://img.shields.io/badge/PostgreSQL-17-336791.svg)](database/)

## 🚀 Quick Start

```bash
# Clone and install
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups
./claude-installer.sh --full

# Use Claude with orchestration
claude /task "create authentication system with tests and security review"
```

## 📚 Documentation

- **[Complete Documentation](docs/COMPLETE_DOCUMENTATION.md)** - Comprehensive guide to the entire system
- **[Technical Reference](docs/TECHNICAL_REFERENCE.md)** - Detailed technical specifications
- **[Project Context](CLAUDE.md)** - Detailed project context for Claude Code
- **[Comprehensive Guide](CLAUDE_COMPREHENSIVE_GUIDE.md)** - All-in-one reference

## ✨ Key Features

### 47 Specialized Agents
From strategic planning (DIRECTOR) to low-level optimization (C-INTERNAL), each agent is specialized for specific tasks and can coordinate autonomously via Claude Code's Task tool.

### Tandem Orchestration System
Dual-layer Python/C execution with 5 execution modes:
- **INTELLIGENT** - Best of both layers
- **REDUNDANT** - Critical reliability
- **CONSENSUS** - Agreement required
- **SPEED_CRITICAL** - Maximum performance
- **PYTHON_ONLY** - Complex logic

### Binary Communication Protocol
- **4.2M messages/second** throughput
- **200ns P99 latency**
- Lock-free ring buffers
- NUMA optimization

### PostgreSQL 17 Database
- **>2000 auth queries/second**
- **<25ms P95 latency**
- Enhanced JSON operations
- JIT compilation

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLAUDE AGENT FRAMEWORK v7.0                  │
├─────────────────────────────────────────────────────────────────┤
│  Command Interface → Orchestration → 47 Agents                 │
│         ↓                  ↓              ↓                     │
│  Tandem Layer: Python (Logic) ←→ C (Performance)               │
│         ↓                                                       │
│  Binary Protocol (4.2M msg/s) → PostgreSQL 17 (>2000 auth/s)   │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
Claude/
├── 📚 docs/                          # Consolidated documentation
│   ├── COMPLETE_DOCUMENTATION.md     # Full system documentation
│   └── TECHNICAL_REFERENCE.md        # Technical specifications
│
├── 🤖 agents/                        # 47 Specialized Agents
│   ├── *.md                          # Agent definitions
│   ├── src/                          # Source code (C/Python/Rust)
│   └── binary-communications-system/ # Ultra-fast protocol
│
├── 🗄️ database/                      # PostgreSQL 17 System
│   ├── sql/                          # Database schemas
│   ├── scripts/                      # Deployment scripts
│   └── tests/                        # Performance tests
│
├── 🎭 orchestration/                 # Orchestration tools
├── 🔧 installers/                    # Installation scripts
└── 🛠️ tools/                         # Development utilities
```

## 🚦 Installation

### Method 1: Unified Installer (Recommended)
```bash
./claude-installer.sh --full     # Complete installation
./claude-installer.sh --quick    # Minimal setup
./claude-installer.sh --portable # Self-contained
```

### Method 2: Quick Launch
```bash
./claude-quick-launch-agents.sh
```

## 💻 Usage Examples

### Simple Task
```bash
claude /task "fix typo in README"
```

### Complex Multi-Agent Workflow
```bash
claude /task "design, implement, test, and deploy a REST API with authentication"
# Automatically coordinates: Director → Architect → Constructor → Security → Testbed → Deployer
```

### Direct Agent Invocation
```python
Task(subagent_type="security", prompt="Audit system for vulnerabilities")
```

## 📊 Performance Metrics

| Component | Metric | Performance |
|-----------|--------|-------------|
| Binary Protocol | Throughput | 4.2M msg/sec |
| Database | Auth Queries | >2000/sec |
| Latency | P95 | <25ms |
| Agents | Discovery | <100ms |
| Orchestration | Success Rate | 85.7% |

## 🔧 Configuration

```bash
# Environment variables
export CLAUDE_PROJECT_ROOT="/path/to/claude"
export CLAUDE_ORCHESTRATION=true
export CLAUDE_PERMISSION_BYPASS=true  # For LiveCD
export CLAUDE_PARALLEL_AGENTS=10
```

## 🤝 Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines and agent creation instructions.

## 📞 Support

- **Repository**: [github.com/SWORDIntel/claude-backups](https://github.com/SWORDIntel/claude-backups)
- **Claude Code**: v1.0.77
- **Framework**: v7.0.0 Production

## 📄 License

See LICENSE file for details.

---

*For complete documentation, see [docs/COMPLETE_DOCUMENTATION.md](docs/COMPLETE_DOCUMENTATION.md)*