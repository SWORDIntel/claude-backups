# Claude Unified Setup - Global Access Configuration

## Overview
Yes, **when you invoke `claude` from anywhere, it now executes the claude-unified wrapper** with all its features!

## Current Setup

### 1. Global `claude` Command
- **Location**: `/home/siducer/.local/bin/claude`
- **Type**: Enhanced unified wrapper (claude-unified)
- **Features**:
  - ✅ Automatic permission bypass for LiveCD environments
  - ✅ Intelligent orchestration detection for multi-agent workflows
  - ✅ Dynamic project root detection
  - ✅ Automatic agent discovery

### 2. How It Works From Anywhere

When you run `claude` from any directory:

```bash
# From any location:
cd /tmp
claude /task "create a feature with tests"
```

The wrapper:
1. **Finds Project Root**: Automatically detects `/home/siducer/Documents/Claude/`
2. **Locates Agents**: Finds all 46 agents in the `agents/` directory
3. **Finds Orchestrator**: Locates `production_orchestrator.py` or `tandem_orchestrator.py`
4. **Sets Environment**: Configures PYTHONPATH and environment variables
5. **Routes Appropriately**: 
   - Simple tasks → Claude Code with permission bypass
   - Complex tasks → Offers Tandem Orchestration

### 3. Global Agent Access

All agents are accessible globally through multiple methods:

#### Via Task Tool (within Claude):
```python
Task(subagent_type="director", prompt="Create strategic plan")
Task(subagent_type="security", prompt="Audit for vulnerabilities")
```

#### Via Command Line:
```bash
# Direct agent invocation
claude-agent director "Create project plan"
claude-agent --list  # List all available agents

# Via orchestrator
orchestrator  # Launch orchestration system
orchestrator-status  # Check system status
```

#### Via Claude with Orchestration:
```bash
# These commands trigger orchestration detection:
claude /task "create and test a new feature"
claude /task "build and deploy the application"
claude /task "comprehensive security audit"
```

### 4. Available Agents (46 total)

The following agents are globally accessible:

**Command & Control:**
- DIRECTOR - Strategic command and control
- PROJECTORCHESTRATOR - Tactical coordination

**Development:**
- ARCHITECT - System design
- CONSTRUCTOR - Project initialization
- DEBUGGER - Failure analysis
- PATCHER - Code fixes
- TESTBED - Test engineering
- LINTER - Code review
- OPTIMIZER - Performance

**Security:**
- SECURITY - Security analysis
- BASTION - Defensive security
- SECURITYCHAOSAGENT - Chaos testing
- SECURITYAUDITOR - Security audits
- CSO - Chief Security Officer
- CRYPTOEXPERT - Cryptography

**Infrastructure:**
- INFRASTRUCTURE - System setup
- DEPLOYER - Deployment
- MONITOR - Observability
- PACKAGER - Package management

**Specialized:**
- APIDESIGNER - API architecture
- DATABASE - Data architecture
- WEB - Web frameworks
- MOBILE - Mobile development
- PYGUI - Python GUI
- TUI - Terminal UI
- DATASCIENCE - Data analysis
- MLOPS - ML operations

*And 20+ more specialized agents...*

### 5. Environment Variables

These work globally from any location:

```bash
# Disable permission bypass
CLAUDE_PERMISSION_BYPASS=false claude /task "production task"

# Disable orchestration suggestions
CLAUDE_ORCHESTRATION=false claude /task "simple task"

# Custom agents directory (rarely needed)
CLAUDE_AGENTS_DIR=/custom/path claude /task "any task"
```

### 6. Special Commands (Work Globally)

```bash
# Check system status
claude --unified-status

# Show help
claude --unified-help

# Safe mode (no permission bypass)
claude --safe /task "sensitive operation"
```

## Verification

To verify everything is working globally:

```bash
# From any directory:
cd /
claude --unified-status

# Should show:
# ✓ Project Root: /home/siducer/Documents/Claude
# ✓ Claude Binary: Found
# ✓ Orchestration: Available
# ✓ Agents: 46 agents found
```

## How the Magic Works

1. **Dynamic Path Detection**: The wrapper automatically finds the project root by searching for directories containing `agents/` and `CLAUDE.md`

2. **Smart Binary Detection**: It finds the real Claude binary (not other wrappers) by checking multiple locations and avoiding infinite loops

3. **Orchestration Intelligence**: Pattern matching detects multi-agent tasks like:
   - "create and test"
   - "build and deploy"
   - "comprehensive"
   - "security audit"

4. **Virtual Environment Support**: Ready to activate Python venv when created for dependencies

## Summary

✅ **YES** - `claude` command works globally from anywhere
✅ **YES** - All 46 agents are available globally
✅ **YES** - Automatic permission bypass works everywhere
✅ **YES** - Orchestration detection works from any directory
✅ **YES** - Project files are found automatically regardless of where you run from

The system is fully configured for global access with intelligent routing!