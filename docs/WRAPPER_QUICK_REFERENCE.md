# Claude Ultimate Wrapper v13.1 - Quick Reference

## Installation (One Command)
```bash
ln -sf /home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh /home/ubuntu/.local/bin/claude && chmod +x /home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh
```

## Essential Commands

### 🎯 Most Used
```bash
claude --help              # Show help
claude --agents            # List all 71 agents
claude agent <name>        # Run specific agent
claude --status            # System status
```

### 🔧 Maintenance
```bash
claude --fix               # Auto-fix issues
claude --register-agents   # Refresh agent registry
claude --safe              # Run without permission bypass
claude --debug <cmd>       # Debug mode
```

### 📊 Agent Information
```bash
claude agents              # List by category
claude --agent-info <name> # Detailed agent info
claude agent director      # Run Director agent
claude agent security      # Run Security agent
```

## Available Agents (71 Total)

### Top Agents by Category

**🎖️ Command & Control**
- `director` - Strategic command
- `projectorchestrator` - Tactical coordination

**🔒 Security (13 agents)**
- `security` - General security
- `cso` - Chief Security Officer
- `cryptoexpert` - Cryptography
- `quantumguard` - Quantum security
- `ghost-protocol` - Counter-intelligence

**🏗️ Development (8 agents)**
- `architect` - System design
- `constructor` - Project init
- `debugger` - Bug analysis
- `optimizer` - Performance

**💻 Languages (14 agents)**
- `python-internal` - Python
- `c-internal` - C/C++
- `rust-internal` - Rust
- `go-internal` - Go
- `java-internal` - Java
- `typescript-internal` - TypeScript

**🌐 Platforms (7 agents)**
- `web` - Web development
- `mobile` - Mobile apps
- `tui` - Terminal UI
- `pygui` - Python GUI
- `apidesigner` - API design

**📦 Infrastructure (6 agents)**
- `docker` - Containers
- `deployer` - Deployment
- `monitor` - Monitoring
- `infrastructure` - Setup

## Quick Troubleshooting

### Issue: Command not found
```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Issue: Agents not found
```bash
claude --register-agents
cd /home/ubuntu/Downloads/claude-backups
claude --status
```

### Issue: Permission errors
```bash
claude --safe <command>  # One time
export CLAUDE_PERMISSION_BYPASS=false  # Permanent
```

## Environment Variables

```bash
# Quick disable permission bypass
export CLAUDE_PERMISSION_BYPASS=false

# Enable debug mode
export CLAUDE_DEBUG=true

# Set custom agents directory
export CLAUDE_AGENTS_DIR="/path/to/agents"

# Activate virtual environment
export CLAUDE_VENV="/path/to/venv"
```

## Agent Discovery Paths

The wrapper looks for agents in this order:
1. `$CLAUDE_PROJECT_ROOT/agents`
2. Script directory + `/agents`
3. Current directory + `/agents`
4. `$HOME/agents`

## File Locations

| Component | Path |
|-----------|------|
| Wrapper Script | `/home/ubuntu/Downloads/claude-backups/claude-wrapper-ultimate.sh` |
| Symlink | `/home/ubuntu/.local/bin/claude` |
| Agents Directory | `/home/ubuntu/Downloads/claude-backups/agents/` |
| Cache Directory | `~/.cache/claude/` |
| Registry File | `~/.cache/claude/registered_agents.json` |

## Status Indicators

When running `claude --agents`:
- ✓ **Green**: Active agent (fully implemented)
- ○ **Yellow**: Template (basic implementation)
- ✗ **Red**: Stub (placeholder)

## Common Workflows

### Explore Available Agents
```bash
claude --agents           # See all agents
claude --agent-info security  # Get details about security agent
claude agent security "scan for vulnerabilities"  # Run the agent
```

### System Health Check
```bash
claude --status           # Full system status
claude --fix             # Fix any issues
claude --register-agents # Refresh agent list
```

### Development Workflow
```bash
claude agent architect "design authentication system"
claude agent constructor "initialize project"
claude agent testbed "create test suite"
claude agent deployer "setup CI/CD"
```

### Security Audit
```bash
claude agent cso "security assessment"
claude agent security "vulnerability scan"
claude agent cryptoexpert "review encryption"
```

## Tips & Tricks

1. **Tab Completion**: Agent names support tab completion in bash
2. **Case Insensitive**: Agent names work in any case
3. **Partial Names**: Full names not always needed (if unique)
4. **Debug Info**: Use `--debug` before any command for details
5. **Quick Status**: `claude --status | grep Registry` for agent count

## Version Info

- **Wrapper**: v13.1
- **Agents**: 71 detected
- **Categories**: 12+ categories
- **Installation**: Symlink-based

---
*Quick Reference v1.0 | Updated: 2025-08-25*