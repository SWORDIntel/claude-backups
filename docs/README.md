# Claude Agent Framework v10.0 Documentation

Welcome to the comprehensive documentation for the Claude Agent Framework. This guide will help you navigate through all aspects of the system.

## 🔴 CURRENT SYSTEM STATUS (2025-09-01)

### 🚀 Enhanced Learning System v2.0 - LIVE METRICS
| Metric | Current Value | Status | Trend |
|--------|--------------|--------|-------|
| **Processing Speed** | **930M lines/sec** | 🟢 OPTIMAL | ↑ |
| **AVX2 Efficiency** | **87%** (8x parallel) | 🟢 HIGH | → |
| **Repositories Tracked** | **5 active** | 🟢 TRACKING | ↑ |
| **Learning Tables** | **14 operational** | 🟢 COLLECTING | → |
| **Vector Dimensions** | **512** | 🟢 ML READY | → |
| **Container Uptime** | **100%** | 🟢 PERSISTENT | → |

### Active Systems
| System | Status | Performance | Documentation |
|--------|--------|-------------|---------------|
| **PICMCS v3.0** | ✅ DEPLOYED | 85x performance, universal hardware support | [Full Documentation](features/picmcs-v3-hardware-adaptive-context-chopping.md) |
| **Enhanced Learning v2.0** | ✅ DEPLOYED | 930M lines/sec, 512-dim vectors | [Full Documentation](features/enhanced-learning-system-v2.md) |
| **AVX2 Shadowgit** | ✅ INTEGRATED | 930M lines/sec with learning | [Technical Details](technical/shadowgit-avx2-learning-integration.md) |
| **Cross-Repo Learning** | ✅ ACTIVE | 5 repos monitored | [User Guide](guides/cross-repository-learning-guide.md) |
| **Docker PostgreSQL** | ✅ RUNNING | Port 5433, auto-restart | [Best Practices](technical/docker-containerization-best-practices.md) |
| **80 Agents** | ✅ OPERATIONAL | All active | [Agent List](reference/COMPLETE_AGENT_LISTING.md) |
| **OpenVINO** | ✅ DEPLOYED | CPU/GPU/NPU ready | [Integration](features/openvino/) |

### 📊 Quick System Check
```bash
# One-line system health check
docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c "SELECT 'Status: ✅ LEARNING from ' || COUNT(DISTINCT repo_path) || ' repos | ' || COUNT(*) || ' events | ' || ROUND(AVG(throughput_mbps)) || ' MB/s avg' FROM enhanced_learning.shadowgit_events;"
```

### Latest Updates
- **2025-09-15**: PICMCS v3.0 deployed with 8-level hardware fallback (NPU/GNA→CPU)
- **2025-09-15**: Universal hardware support from high-end NPU to memory-constrained systems
- **2025-09-15**: Hardware-adaptive context chopping with 85x performance improvement
- **2025-09-01**: Enhanced Learning System v2.0 deployed with shadowgit integration
- **2025-09-01**: Cross-repository learning active across 5 repos
- **2025-08-31**: AVX2 Shadowgit achieving 930M lines/sec
- **2025-08-30**: Neural hardware integration complete

## 📚 Navigation

### 🚀 Getting Started
**Path:** `guides/`
- [`installation-guide.md`](guides/installation-guide.md) - Complete installation instructions
- [`CONFIGURATION_GUIDE.md`](guides/CONFIGURATION_GUIDE.md) - System configuration guide
- [`README.md`](guides/README.md) - Quick start guide
- [`docgen-integration-complete.md`](guides/docgen-integration-complete.md) - Documentation generation setup
- [`FIRST_TIME_LAUNCH_GUIDE.md`](guides/FIRST_TIME_LAUNCH_GUIDE.md) - First launch walkthrough
- [`README_COMPLETE.md`](guides/README_COMPLETE.md) - Comprehensive setup guide
- [`README_CONTAINERIZED_SYSTEM.md`](guides/README_CONTAINERIZED_SYSTEM.md) - Docker setup guide
- [`picmcs-v3-quick-start-guide.md`](guides/picmcs-v3-quick-start-guide.md) - **NEW: PICMCS v3.0 Quick Start Guide**

### 📖 Reference Documentation  
**Path:** `reference/`
- [`PROJECT_OVERVIEW.md`](reference/PROJECT_OVERVIEW.md) - Complete project overview
- [`COMPLETE_AGENT_LISTING.md`](reference/COMPLETE_AGENT_LISTING.md) - All 65+ agents documented
- [`INSTALLER_LAUNCH_SEQUENCE.md`](reference/INSTALLER_LAUNCH_SEQUENCE.md) - Installer component launch order
- [`DOCUMENTATION_FILING_RULES.md`](reference/DOCUMENTATION_FILING_RULES.md) - Documentation standards
- [`TUI_INSTALLER_OPTIMIZER.md`](reference/TUI_INSTALLER_OPTIMIZER.md) - Terminal UI optimizer tool
- [`directory-structure.md`](reference/directory-structure.md) - Project structure reference
- [`241007-hybrid-threats-and-hybrid-warfare.pdf`](reference/241007-hybrid-threats-and-hybrid-warfare.pdf) - Security research
- [`Cyber-Reports-2019-10-CyberInfluence.pdf`](reference/Cyber-Reports-2019-10-CyberInfluence.pdf) - Cyber influence analysis

### 🏗️ Architecture & Technical
**Path:** `architecture/`
- [`tandem-orchestration.md`](architecture/tandem-orchestration.md) - Tandem Orchestration System
- [`binary-communication.md`](architecture/binary-communication.md) - Binary communication protocol
- [`ml-learning-system.md`](architecture/ml-learning-system.md) - Machine learning integration
- [`docgen-auto-invocation-system.md`](architecture/docgen-auto-invocation-system.md) - Auto-invocation system
- [`CONTAINERIZED_POSTGRESQL_SYSTEM.md`](architecture/CONTAINERIZED_POSTGRESQL_SYSTEM.md) - Database architecture
- [`hooks-system.md`](architecture/hooks-system.md) - Advanced hooks system
- [`existing-agent-enhancement-guide.md`](architecture/existing-agent-enhancement-guide.md) - Agent enhancement guide
- [`missing-python-implementations.md`](architecture/missing-python-implementations.md) - Implementation gaps
- [`python-implementation-priority-guide.md`](architecture/python-implementation-priority-guide.md) - Implementation priorities

**Path:** `technical/`
- [`picmcs-v3-technical-specification.md`](technical/picmcs-v3-technical-specification.md) - **NEW: PICMCS v3.0 Technical Specification**
- [`shadowgit-avx2-learning-integration.md`](technical/shadowgit-avx2-learning-integration.md) - AVX2 shadowgit integration
- [`docker-containerization-best-practices.md`](technical/docker-containerization-best-practices.md) - Docker best practices

### 🔧 Implementation Reports
**Path:** `implementation/`
- [`LEARNING_SYSTEM_IMPLEMENTATION_COMPLETE.md`](implementation/LEARNING_SYSTEM_IMPLEMENTATION_COMPLETE.md) - Learning system completion
- [`LEARNING_SYSTEM_INTEGRATION.md`](implementation/LEARNING_SYSTEM_INTEGRATION.md) - Learning system integration
- [`LEARNING_SYSTEM_COMPLETION_PLAN.md`](implementation/LEARNING_SYSTEM_COMPLETION_PLAN.md) - Completion planning
- [`LEARNING_SYSTEM_AGENT_COORDINATION_PLAN.md`](implementation/LEARNING_SYSTEM_AGENT_COORDINATION_PLAN.md) - Agent coordination
- [`WRAPPER_INTEGRATION_DEFAULT.md`](implementation/WRAPPER_INTEGRATION_DEFAULT.md) - Wrapper integration
- [`WRAPPER_INTEGRATION_PRO_COMPLETE.md`](implementation/WRAPPER_INTEGRATION_PRO_COMPLETE.md) - Advanced wrapper features
- [`WRAPPER_PERFORMANCE_OPTIMIZATIONS.md`](implementation/WRAPPER_PERFORMANCE_OPTIMIZATIONS.md) - Performance optimizations
- [`WRAPPER_QUICK_REFERENCE.md`](implementation/WRAPPER_QUICK_REFERENCE.md) - Wrapper quick reference
- [`WRAPPER_VENV_ENHANCEMENT.md`](implementation/WRAPPER_VENV_ENHANCEMENT.md) - Virtual environment enhancements
- [`INSTALLER_INTEGRATION_SUMMARY.md`](implementation/INSTALLER_INTEGRATION_SUMMARY.md) - Installer integration summary

### ✨ Features
**Path:** `features/`

#### 🔴 ACTIVE SYSTEMS
- [`picmcs-v3-hardware-adaptive-context-chopping.md`](features/picmcs-v3-hardware-adaptive-context-chopping.md) - **NEW: PICMCS v3.0 (85x performance, universal hardware support)**
- [`shadowgit-avx2-integration.md`](features/shadowgit-avx2-integration.md) - **ONLINE: AVX2 Shadowgit (142.7B lines/sec)**
- [`docker-learning-system-status.md`](features/docker-learning-system-status.md) - **RUNNING: Docker PostgreSQL Learning System**
- [`learning-data-flow.md`](features/learning-data-flow.md) - **ACTIVE: Automatic data export/import**
- [`openvino/`](features/openvino/) - **DEPLOYED: OpenVINO 2025.4.0 AI Runtime**
- [`global-git-intelligence-system.md`](features/global-git-intelligence-system.md) - **NEW: Global Git Intelligence (85% operational)**
- [`global-git-current-status.md`](features/global-git-current-status.md) - **NEW: Current deployment status report**

#### 📦 Integrations
- [`docker-autostart-installer-enhancement.md`](features/docker-autostart-installer-enhancement.md) - Docker container auto-restart configuration
- [`docker-database-integration.md`](features/docker-database-integration.md) - Docker database integration
- [`docgen-file-saving-enhancements.md`](features/docgen-file-saving-enhancements.md) - Documentation file saving
- [`shadowgit-avx2-optimization.md`](features/shadowgit-avx2-optimization.md) - AVX2 diff engine optimization
- [`tpm2-integration/`](features/tpm2-integration/) - TPM2 hardware security integration

### 🔧 Fixes & Updates
**Path:** `fixes/`
- [`2025-08-25-agent-name-capitalization.md`](fixes/2025-08-25-agent-name-capitalization.md) - Agent naming standardization
- [`BASH_OUTPUT_FIX_IMPLEMENTATION_REPORT.md`](fixes/BASH_OUTPUT_FIX_IMPLEMENTATION_REPORT.md) - Bash output fix report

### 🛠️ Troubleshooting
**Path:** `troubleshooting/`
- [`TROUBLESHOOTING_GUIDE.md`](troubleshooting/TROUBLESHOOTING_GUIDE.md) - Complete troubleshooting guide

### 📚 Legacy Documentation
**Path:** `legacy/`
- [`AGENT_VISIBILITY_FIX.md`](legacy/AGENT_VISIBILITY_FIX.md) - Historical agent visibility fixes
- [`SEAMLESS_INTEGRATION.md`](legacy/SEAMLESS_INTEGRATION.md) - Legacy integration approach
- [`UNIFIED_ORCHESTRATION_SYSTEM.md`](legacy/UNIFIED_ORCHESTRATION_SYSTEM.md) - Historical orchestration design
- [`claude-auto-invoke-agents.md`](legacy/claude-auto-invoke-agents.md) - Legacy auto-invocation
- [`statusline.md`](legacy/statusline.md) - Legacy statusline implementation
- [`activate-agents.md`](legacy/activate-agents.md) - Legacy activation system
- [`CLAUDE_ULTIMATE_WRAPPER_v13.1.md`](legacy/CLAUDE_ULTIMATE_WRAPPER_v13.1.md) - Historical wrapper version
- [`HYBRID_INTEGRATION_STATUS.md`](legacy/HYBRID_INTEGRATION_STATUS.md) - Integration status history
- [`VERIFICATION_REPORT.md`](legacy/VERIFICATION_REPORT.md) - Historical verification reports

## 🔍 Quick Access

### For New Users
1. Start with [`guides/installation-guide.md`](guides/installation-guide.md)
2. Read [`reference/PROJECT_OVERVIEW.md`](reference/PROJECT_OVERVIEW.md)
3. Follow [`guides/FIRST_TIME_LAUNCH_GUIDE.md`](guides/FIRST_TIME_LAUNCH_GUIDE.md)

### For Developers
1. Review [`architecture/tandem-orchestration.md`](architecture/tandem-orchestration.md)
2. Check [`reference/COMPLETE_AGENT_LISTING.md`](reference/COMPLETE_AGENT_LISTING.md)
3. Study [`architecture/existing-agent-enhancement-guide.md`](architecture/existing-agent-enhancement-guide.md)

### For System Administrators
1. Read [`guides/CONFIGURATION_GUIDE.md`](guides/CONFIGURATION_GUIDE.md)
2. Review [`architecture/CONTAINERIZED_POSTGRESQL_SYSTEM.md`](architecture/CONTAINERIZED_POSTGRESQL_SYSTEM.md)
3. Check [`troubleshooting/TROUBLESHOOTING_GUIDE.md`](troubleshooting/TROUBLESHOOTING_GUIDE.md)

### For Researchers
1. Review [`reference/241007-hybrid-threats-and-hybrid-warfare.pdf`](reference/241007-hybrid-threats-and-hybrid-warfare.pdf)
2. Check [`architecture/ml-learning-system.md`](architecture/ml-learning-system.md)
3. Study [`implementation/LEARNING_SYSTEM_IMPLEMENTATION_COMPLETE.md`](implementation/LEARNING_SYSTEM_IMPLEMENTATION_COMPLETE.md)

## 📋 Document Categories

| Category | Purpose | File Count |
|----------|---------|------------|
| **guides** | Getting started, installation, configuration | 8 files |
| **reference** | Complete references, overviews, standards | 8 files |
| **architecture** | Technical architecture, system design | 9 files |
| **implementation** | Implementation reports, completion status | 10 files |
| **features** | New features and enhancements | 3 files |
| **technical** | Technical specifications and implementation details | 2 files |
| **fixes** | Bug fixes and updates | 2 files |
| **troubleshooting** | Problem solving and debugging | 1 file |
| **legacy** | Historical documentation and deprecated info | 8 files |

## 🔄 Documentation Standards

All documentation follows the standards outlined in [`reference/DOCUMENTATION_FILING_RULES.md`](reference/DOCUMENTATION_FILING_RULES.md):

- **Markdown format** (.md files)
- **Descriptive filenames** with dates for time-sensitive docs
- **Clear headers** with proper hierarchy
- **Code examples** in fenced blocks
- **Status indicators**: ✅ Complete, 🚧 In Progress, ❌ Deprecated

## 📊 System Status

- **Framework Version**: v7.0
- **Agent Count**: 65+ specialized agents
- **Documentation Status**: ✅ Complete and organized
- **Last Updated**: 2025-08-26

---

*This documentation covers the complete Claude Agent Framework ecosystem. For additional support, refer to the troubleshooting guide or check the implementation reports for specific component details.*