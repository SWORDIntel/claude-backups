# Claude Unified Orchestration System
**Version**: 2.0  
**Status**: PRODUCTION READY  
**Last Updated**: 2025-08-18  

## Overview

The **Claude Unified Orchestration System** seamlessly combines automatic permission bypass (for LiveCD environments) with the Python Tandem Orchestration System, creating a powerful unified interface that:

1. **Automatically bypasses permissions** for LiveCD compatibility
2. **Detects multi-agent workflow opportunities** in your tasks  
3. **Routes to optimal execution layer** (Python orchestration or direct Claude)
4. **Maintains full backward compatibility** with existing Claude Code commands

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Input/Command                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               claude-unified (Bash Wrapper)                  │
│  • Adds --dangerously-skip-permissions automatically         │
│  • Detects orchestration patterns                           │
│  • Routes to appropriate handler                            │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────────────┐
│  Direct Claude   │    │ Orchestration Bridge     │
│  with permission │    │ (Python)                 │
│  bypass          │    │ • Pattern detection      │
│                  │    │ • Workflow generation    │
│                  │    │ • Agent coordination     │
└──────────────────┘    └────────┬─────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────────┐
                    │ Tandem Orchestrator        │
                    │ • 32 specialized agents    │
                    │ • 5 execution modes        │
                    │ • Mock + real execution    │
                    └────────────────────────────┘
```

## Installation

### Quick Setup

```bash
# 1. Make scripts executable
chmod +x claude-unified claude-orchestration-bridge.py

# 2. Create alias for seamless integration
echo "alias claude='$PWD/claude-unified'" >> ~/.bashrc
source ~/.bashrc

# 3. Test the installation
claude --unified-status
```

### Environment Variables

```bash
# Control permission bypass (default: true)
export CLAUDE_PERMISSION_BYPASS=false  # Disable auto permission bypass

# Control orchestration (default: true)  
export CLAUDE_ORCHESTRATION=false      # Disable orchestration suggestions

# Set agents directory (auto-detected by default)
export CLAUDE_AGENTS_DIR=/path/to/agents
```

## Usage

### Basic Commands

```bash
# Regular Claude command - automatically enhanced
claude /task "fix this bug"
# → Adds permission bypass, no orchestration needed

# Complex task - triggers orchestration suggestion
claude /task "create a new feature and test it"
# → Adds permission bypass, suggests multi-agent workflow

# Force safe mode (no permission bypass)
claude --safe /task "sensitive operation"
# → No permission bypass, normal execution

# Direct orchestration
python3 claude-orchestration-bridge.py "complete development cycle"
# → Direct access to orchestration capabilities
```

### Special Commands

```bash
# Show unified wrapper help
claude --unified-help

# Show system status
claude --unified-status

# Show orchestration help
python3 claude-orchestration-bridge.py
```

## How It Works

### 1. Permission Bypass Layer

The unified wrapper automatically adds `--dangerously-skip-permissions` to all Claude invocations unless:
- You explicitly use `--safe` or `--no-skip-permissions`
- Environment variable `CLAUDE_PERMISSION_BYPASS=false`

This ensures LiveCD compatibility by default while allowing opt-out for regular environments.

### 2. Orchestration Detection

The system analyzes your task for patterns that indicate multi-agent workflows:

**Trigger Keywords:**
- Multi-step: "create and test", "build and deploy", "design and implement"
- Comprehensive: "full development", "complete project", "entire system"
- Workflow: "pipeline", "orchestrate", "workflow"

**Agent Mapping:**
```python
pattern_triggers = {
    "create": ["architect", "constructor"],
    "build": ["constructor", "testbed"],
    "test": ["testbed", "debugger"],
    "fix": ["debugger", "patcher"],
    "deploy": ["deployer", "monitor"],
    "document": ["docgen", "tui"],
    "review": ["linter", "security"],
    "optimize": ["optimizer", "monitor"]
}
```

### 3. Execution Modes

When orchestration is triggered, you get 5 execution modes:

1. **INTELLIGENT**: Python orchestrates, leverages best of both layers
2. **REDUNDANT**: Both layers execute for critical reliability
3. **CONSENSUS**: Both layers must agree on outcomes
4. **SPEED_CRITICAL**: Optimized for maximum performance
5. **PYTHON_ONLY**: Pure Python for complex logic and libraries

### 4. Agent Coordination

The system coordinates 32 specialized agents:

**Command & Control:**
- Director: Strategic planning
- ProjectOrchestrator: Tactical coordination

**Development:**
- Architect, Constructor, Patcher, Debugger, Testbed, Linter, Optimizer

**Infrastructure:**
- Infrastructure, Deployer, Monitor, Packager

**Security:**
- Security, Bastion, SecurityChaosAgent, Oversight

**And many more...**

## Example Workflows

### Simple Task (No Orchestration)
```bash
$ claude /task "fix typo in README"
[PERMISSION] Auto-adding permission bypass (LiveCD mode)
# → Direct Claude execution with permission bypass
```

### Complex Task (With Orchestration)
```bash
$ claude /task "create user authentication system with tests and documentation"
[UNIFIED] Analyzing task...
[ORCHESTRATE] Detected multi-agent workflow opportunity
[PERMISSION] Auto-adding permission bypass (LiveCD mode)

╔════════════════════════════════════════════════════════════╗
║         Tandem Orchestration System Available              ║
╚════════════════════════════════════════════════════════════╝

Detected task that could benefit from multi-agent coordination.

Options:
  [1] Use Tandem Orchestrator (recommended for complex tasks)
  [2] Use regular Claude Code
  [3] Show orchestration analysis

Choice [1-3, default=2]: 1

[ORCHESTRATE] Launching Tandem Orchestrator...
Executing workflow with agents:
  • architect: Design authentication system
  • constructor: Build authentication module
  • testbed: Create comprehensive tests
  • docgen: Generate documentation
  • security: Security review

✓ Workflow completed successfully!
```

### Direct Orchestration
```bash
$ python3 claude-orchestration-bridge.py "security audit"
🔍 Analyzing task for orchestration opportunities...
🔓 Permission bypass: ENABLED (LiveCD mode)

Executing Security Audit Campaign with:
  • security: Comprehensive vulnerability scan
  • securitychaosagent: Chaos testing
  • docgen: Security report generation

✓ Orchestration completed successfully!
```

## Integration with Existing Systems

### LiveCD Integration
The unified wrapper is specifically designed for LiveCD environments where:
- File system permissions may be restricted
- User confirmation dialogs would break automation
- Speed and efficiency are critical

### Claude Code Integration
The system acts as a transparent wrapper around Claude Code:
- All existing Claude commands work unchanged
- New orchestration capabilities are additive, not disruptive
- Full backward compatibility maintained

### Tandem Orchestrator Integration
Direct access to the Python Tandem Orchestration System:
- Mock execution for testing
- Real agent invocation when available
- Seamless fallback between layers

## Troubleshooting

### Permission Bypass Not Working
```bash
# Check if permission bypass is enabled
echo $CLAUDE_PERMISSION_BYPASS

# Force enable
export CLAUDE_PERMISSION_BYPASS=true

# Verify with status
claude --unified-status
```

### Orchestration Not Triggering
```bash
# Check if orchestration is enabled
echo $CLAUDE_ORCHESTRATION

# Force enable
export CLAUDE_ORCHESTRATION=true

# Test with explicit pattern
claude /task "create and test and deploy"
```

### Claude Binary Not Found
```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Or specify path manually
export CLAUDE_BINARY=/path/to/claude
```

## Advanced Configuration

### Custom Agent Patterns
Edit `claude-orchestration-bridge.py` to add custom patterns:

```python
self.pattern_triggers = {
    "your_pattern": ["agent1", "agent2"],
    # Add more patterns...
}
```

### Custom Workflows
Add to `StandardWorkflows` class in `production_orchestrator.py`:

```python
@staticmethod
def create_custom_workflow() -> CommandSet:
    return CommandSet(
        name="Custom Workflow",
        steps=[
            # Define your steps...
        ]
    )
```

### Execution Mode Selection
Set default execution mode:

```python
mode=ExecutionMode.INTELLIGENT  # Change to your preference
```

## Performance Considerations

- **Permission Bypass**: Zero overhead - flag is added at command line
- **Pattern Detection**: <10ms for typical inputs
- **Orchestration Initialization**: ~200ms first time, cached afterward
- **Agent Discovery**: Automatic, happens once at startup
- **Mock Execution**: Instant results for testing
- **Real Execution**: Depends on agent complexity

## Security Notes

⚠️ **Permission Bypass Warning**: The automatic permission bypass is designed for trusted LiveCD environments. In production or multi-user systems, consider:

```bash
# Disable by default
export CLAUDE_PERMISSION_BYPASS=false

# Use --safe flag for sensitive operations
claude --safe /task "production deployment"
```

## Future Enhancements

- [ ] GUI for orchestration visualization
- [ ] Real-time progress tracking
- [ ] Custom agent creation wizard
- [ ] Performance profiling tools
- [ ] Distributed execution support
- [ ] Cloud orchestration backend

## Support

For issues or questions:
- Check `claude --unified-help`
- Run `claude --unified-status` for diagnostics
- Review orchestration logs in `~/.local/share/claude/logs/`
- See CLAUDE.md for project context

---

*Unified Orchestration System - Bringing together the best of permission bypass and intelligent orchestration*