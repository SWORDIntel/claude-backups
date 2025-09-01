# 🚀 GETTING STARTED - CLAUDE AGENT FRAMEWORK v8.0

## 📊 SYSTEM PERFORMANCE

### Quick Stats
```
Agent Count:           80 specialized agents
Response Time:         <500ms average
Processing Speed:      930M lines/sec (shadowgit)
Database Throughput:   >2000 auth/sec
Learning System:       512-dim vectors, real-time
Success Rate:          >95% task completion
```

## 🔥 Quick Performance Check

```bash
# Check system status
./status

# Monitor agent performance
docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \
"SELECT 'System Health: ' || COUNT(DISTINCT agent_name) || ' agents | ' ||
        ROUND(AVG(execution_time_ms)) || 'ms avg | ' ||
        COUNT(*) || ' total executions'
FROM enhanced_learning.agent_metrics;"
```

## 📋 TABLE OF CONTENTS
1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Quick Start](#quick-start)
4. [Verification](#verification)
5. [First Steps](#first-steps)

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ (or compatible Linux)
- **RAM**: 4GB minimum, 8GB+ recommended (64GB for full performance)
- **Disk**: 2GB free space (10GB for learning system)
- **CPU**: Intel/AMD x86_64 (Meteor Lake optimized, AVX2 required)

### Software Requirements
```bash
# Required
node >= 14.0.0
npm >= 6.0.0
python3 >= 3.8
bash >= 4.0

# Optional but recommended
postgresql >= 16
git
curl
```

## Installation Methods

### Method 1: Quick Installation (Recommended)
```bash
# One-line installation
git clone https://github.com/SWORDIntel/claude-backups.git && \
cd claude-backups && \
./claude-installer.sh --quick
```

### Method 2: Full Installation
```bash
# Clone repository
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups

# Run full installer
./claude-installer.sh --full
```

### Method 3: Manual Symlink Installation
```bash
# Clone and enter directory
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups

# Create symlink
ln -sf $(pwd)/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x claude-wrapper-ultimate.sh

# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Method 4: Custom Installation
```bash
./claude-installer.sh --custom
# Follow interactive prompts to select components
```

## Quick Start

### 1. Verify Installation
```bash
claude --status
```

### 2. List Available Agents
```bash
claude --agents
```

### 3. Run Your First Agent
```bash
claude agent director "What can you help me with?"
```

### 4. Explore Agent Categories
```bash
# Security agents
claude agent security "scan for vulnerabilities"

# Development agents
claude agent architect "design a REST API"

# Infrastructure agents
claude agent docker "containerize my application"
```

## Verification

### Check All Components
```bash
# System status
claude --status

# Agent count (should show 71)
claude --agents | grep "Total:"

# Test agent invocation
claude agent director "test"

# Check wrapper version
claude --help | grep "v13"
```

### Troubleshooting Installation
```bash
# If command not found
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc

# If agents not found
cd /home/ubuntu/Downloads/claude-backups
claude --register-agents

# If permission issues
claude --safe [command]
```

## First Steps

### 1. Explore Agent Capabilities
```bash
# Get detailed info about an agent
claude --agent-info security
claude --agent-info architect
```

### 2. Try Multi-Agent Workflows
```bash
# Development workflow
claude agent architect "design authentication"
claude agent constructor "create project structure"
claude agent testbed "setup testing"
```

### 3. Configure Your Environment
```bash
# Edit ~/.bashrc
export CLAUDE_DEBUG=false
export CLAUDE_PERMISSION_BYPASS=true
export CLAUDE_AUTO_FIX=true

# Create aliases
alias ca='claude agent'
alias cs='claude --status'
```

### 4. Learn Advanced Features
- Read [Configuration Guide](../02-CONFIGURATION/environment-variables.md)
- Explore [Agent Listing](../03-AGENTS/complete-listing.md)
- Try [Workflows](../06-WORKFLOWS/common-workflows.md)

## Next Steps

1. **Read the Documentation**
   - [Project Overview](../00-OVERVIEW/project-overview.md)
   - [Architecture](../00-OVERVIEW/architecture.md)

2. **Explore Agents**
   - [Complete Agent List](../03-AGENTS/complete-listing.md)
   - [Agent Categories](../03-AGENTS/categories.md)

3. **Learn Advanced Features**
   - [Hooks System](../04-ADVANCED/hooks-system.md)
   - [ML Learning System](../05-SYSTEMS/ml-learning-system.md)
   - [Tandem Orchestration](../05-SYSTEMS/tandem-orchestration.md)

---
*Getting Started Guide v1.0 | Framework v7.0*