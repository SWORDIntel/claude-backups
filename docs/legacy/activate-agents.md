# Claude Global Agents Bridge v10.0 - Implementation Guide

## 🚀 Overview

The Claude Global Agents Bridge v10.0 is a unified coordination system that seamlessly integrates all project agents with Claude Code's Task tool while providing intelligent routing between multiple execution layers for optimal performance.

## 🎯 Key Features

### 1. **Multi-Layer Execution**
- **Task Tool Integration**: Direct integration with Claude Code's Task() function
- **Tandem Orchestration**: Python strategic planning + C tactical execution
- **C Binary Bridge**: Ultra-high-performance execution (100K+ msg/sec)
- **Python Fallback**: Always-available baseline execution (5K msg/sec)

### 2. **Execution Modes**
- **INTELLIGENT**: Automatic selection of best execution path
- **PYTHON_ONLY**: Pure Python execution for compatibility
- **SPEED_CRITICAL**: Maximum performance via C layer
- **REDUNDANT**: Both layers for critical operations

### 3. **System Capabilities Detection**
- Automatic detection of available components
- AVX-512 instruction set support
- Thermal state monitoring
- Dynamic performance optimization

### 4. **Agent Discovery & Management**
- Automatic discovery of all `.md` agent files
- Real-time monitoring for new/removed agents
- Priority-based execution routing
- Tool capability extraction

## 📦 Installation

### Step 1: Install the Enhanced Registration System

```bash
# Download the updated registration script
cd /home/ubuntu/Documents/Claude
wget <updated-script-url> -O register-custom-agents-v10.py

# Make it executable
chmod +x register-custom-agents-v10.py

# Install the agent system
python3 register-custom-agents-v10.py --install
```

### Step 2: Activate the Agent System

```bash
# Source the activation script
source ~/.config/claude/activate-agents.sh

# Or add to your shell profile for permanent activation
echo "source ~/.config/claude/activate-agents.sh" >> ~/.bashrc
```

## 🎮 Usage

### Command Line Interface

```bash
# List all available agents
claude-agents

# Check system status
claude-status

# Invoke an agent directly
claude-invoke director "Create a project plan for a web application"

# Get agent information
claude-info optimizer

# Show performance metrics
claude-metrics

# Test the system
claude-test
```

### Using in Claude Code

```python
# Direct Task tool invocation
Task(subagent_type="director", prompt="Plan the architecture")
Task(subagent_type="optimizer", prompt="Optimize this code for performance")
Task(subagent_type="security", prompt="Audit for vulnerabilities")

# With execution mode specification
Task(
    subagent_type="cryptoexpert",
    prompt="Implement AES encryption",
    mode="SPEED_CRITICAL"  # Use C layer for crypto operations
)
```

### Python Integration

```python
from register_custom_agents_v10 import GlobalAgentCoordinator, ExecutionMode

# Initialize the coordinator
coordinator = GlobalAgentCoordinator()
coordinator.initialize()

# Invoke an agent
result = coordinator.invoke_agent(
    agent_name="optimizer",
    prompt="Optimize database queries",
    mode=ExecutionMode.INTELLIGENT
)

if result['success']:
    print(result['output'])
    print(f"Execution path: {result['execution_path']}")
    print(f"Response time: {result['execution_time']}s")
```

## 🔍 Monitoring & Maintenance

### Real-time Monitoring

```bash
# Start foreground monitoring
claude-monitor

# Start background daemon
claude-daemon

# Check for agent changes
python3 register-custom-agents-v10.py --check
```

### Performance Optimization

The system automatically selects the best execution path based on:
- System capabilities (C bridge, Tandem, AVX-512)
- Thermal state (throttles under high temperature)
- Agent priority (CRITICAL, HIGH, NORMAL)
- Execution mode (INTELLIGENT, SPEED_CRITICAL, etc.)

## 📊 Performance Characteristics

| Execution Path | Throughput | Latency (p99) | Use Case |
|---------------|------------|---------------|----------|
| C Binary Bridge | 100K+ msg/sec | 200ns | High-frequency operations |
| Tandem Orchestration | 10-50K msg/sec | 2ms | Complex coordination |
| Task Tool | 5-10K msg/sec | 10ms | Standard operations |
| Python Direct | 5K msg/sec | 20ms | Fallback/compatibility |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│           Claude Code (Task Tool)           │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│      Global Agent Coordinator (v10.0)       │
│  • Agent Discovery & Registry               │
│  • Intelligent Routing Logic                │
│  • Performance Monitoring                   │
└──────┬──────────┬──────────┬────────────────┘
       │          │          │
┌──────▼────┐ ┌──▼───┐ ┌────▼────┐
│  Tandem   │ │  C   │ │ Python  │
│Orchestrator│ │Bridge│ │ Direct  │
└───────────┘ └──────┘ └─────────┘
```

## 🛠️ Troubleshooting

### C Binary Layer Not Available
```bash
# Check if binary exists
ls -la /home/ubuntu/Documents/Claude/agents/binary-communications-system/

# Check if process is running
ps aux | grep agent_bridge

# Fallback to Python mode
export CLAUDE_EXECUTION_MODE=PYTHON_ONLY
```

### Tandem Orchestrator Issues
```bash
# Verify orchestrator files
ls -la /home/ubuntu/Documents/Claude/agents/src/python/

# Test orchestrator directly
python3 /home/ubuntu/Documents/Claude/agents/src/python/production_orchestrator.py --test
```

### Agent Not Found
```bash
# Rescan and update registry
claude-install

# Check agent file exists
ls /home/ubuntu/Documents/Claude/agents/*.md

# View registry
cat ~/.config/claude/project-agents.json | jq
```

## 🔄 Updates & Compatibility

### Backward Compatibility
- Maintains legacy `project-agents.json` format
- Supports original Task tool invocation patterns
- Falls back gracefully when components unavailable

### Future Enhancements
- GPU acceleration for ML agents
- NPU integration for AI operations
- Distributed agent execution
- Cloud-native deployment options

## 📝 Configuration

### Environment Variables
```bash
# Execution mode preference
export CLAUDE_EXECUTION_MODE=INTELLIGENT  # or PYTHON_ONLY, SPEED_CRITICAL, REDUNDANT

# Feature flags
export CLAUDE_TANDEM_ENABLED=true
export CLAUDE_C_BRIDGE_ENABLED=true
export CLAUDE_MONITORING_ENABLED=true

# Performance tuning
export CLAUDE_MAX_WORKERS=8
export CLAUDE_TIMEOUT=300
```

### Configuration Files
- `~/.config/claude/project-agents.json` - Agent registry
- `~/.config/claude/task_extension.py` - Task tool extension
- `~/.cache/claude-agents/coordination_config.json` - System configuration
- `~/Documents/Claude/agents/config/tandem_config.json` - Tandem settings
- `~/Documents/Claude/agents/config/ipc_config.json` - IPC configuration

## 💡 Best Practices

1. **Use INTELLIGENT mode by default** - Let the system choose the best path
2. **Monitor thermal state** - System auto-throttles under high temperature
3. **Batch operations** - Group related agent invocations for efficiency
4. **Enable monitoring** - Detect and adapt to agent changes automatically
5. **Check metrics regularly** - Identify performance bottlenecks

## 🤝 Contributing

To add a new agent:
1. Create an `.md` file in `/home/ubuntu/Documents/Claude/agents/`
2. Include YAML frontmatter with metadata
3. Specify supported execution modes
4. Run `claude-install` to update registry

## 📚 Additional Resources

- [Agent Template](agents/Template.md)
- [Tandem Orchestration Guide](docs/tandem-orchestration.md)
- [C Binary Bridge Documentation](agents/binary-communications-system/README.md)
- [Performance Tuning Guide](docs/performance-tuning.md)

## 🎉 Quick Start Example

```bash
# 1. Install and activate
python3 register-custom-agents-v10.py --install
source ~/.config/claude/activate-agents.sh

# 2. Test the system
claude-test

# 3. List available agents
claude-agents

# 4. Invoke your first agent
claude-invoke director "Create a REST API project structure"

# 5. Monitor performance
claude-metrics
```

## 📞 Support

For issues or questions:
- Check system status: `claude-status`
- Run diagnostics: `claude-test`
- View logs: `tail -f ~/.cache/claude-agents/*.log`
- Monitor in real-time: `claude-monitor`

---

**Version**: 10.0.0  
**Last Updated**: 2024  
**Compatibility**: Claude Code 1.0+  
**Performance**: 5K-100K+ msg/sec (mode dependent)
