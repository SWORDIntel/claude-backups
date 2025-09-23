# Claude Ultimate Wrapper v13.1 Documentation

## Overview

The Claude Ultimate Wrapper v13.1 is an advanced command-line interface wrapper for Claude that provides automatic agent discovery, intelligent error recovery, and comprehensive system management capabilities. This wrapper enhances the Claude experience with 71 automatically discovered agents and seamless integration features.

## Key Features

### 1. Automatic Agent Discovery & Registration
- **Auto-detection**: Discovers all 71 agents from the `agents/` directory
- **Metadata Extraction**: Automatically extracts category, description, UUID, and tools from agent files
- **Status Classification**: Categorizes agents as:
  - **Active**: Fully implemented agents (>100 bytes with implementation sections)
  - **Template**: Basic agent files without full implementation
  - **Stub**: Minimal placeholder files (<100 bytes)
- **JSON Registry**: Maintains a cached registry at `~/.cache/claude/registered_agents.json`

### 2. Intelligent Path Discovery
- **Symlink-aware**: Follows symlinks to find the actual script location
- **Multiple search paths**:
  1. Current working directory
  2. Script directory (via `${BASH_SOURCE[0]}`)
  3. Environment variable `$CLAUDE_PROJECT_ROOT`
  4. Common project locations (`~/Documents/Claude`, `~/Documents/claude-backups`)
  5. Fallback to `~/claude-project`

### 3. Enhanced Error Recovery
- **Yoga.wasm detection**: Automatically detects and fixes yoga.wasm issues
- **NPM package healing**: Self-healing npm package management
- **Multiple execution fallbacks**: Tries direct execution, node, and npx
- **Graceful error handling**: Never crashes, provides helpful error messages

### 4. Virtual Environment Support
The wrapper now includes enhanced virtual environment detection with relative path support:
- Checks multiple venv locations: `./venv`, `./.venv`, `../venv`, `../.venv`
- Uses `realpath` for absolute path resolution
- Automatically activates if found
- Sets up proper Python paths and environment variables

## Installation

### Symlink Installation (Recommended)
Preserves agent discovery by maintaining directory relationships:

```bash
# Create symlink for global 'claude' command
ln -sf $CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh $HOME/.local/bin/claude

# Make wrapper executable
chmod +x $CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.bashrc for persistence
```

### Why Symlinks?
- **Agent Discovery**: The wrapper can find the `agents/` directory relative to its actual location
- **Always Updated**: Changes to the wrapper are immediately available
- **No Hardcoding**: Intelligent path discovery works naturally

## Command Reference

### Core Commands

#### System Status
```bash
claude --status
```
Shows comprehensive system information including:
- Node.js and npm versions
- Claude binary location and health
- Virtual environment status
- Directories (project root, agents, cache)
- Agent registry statistics
- Feature flags status

#### Agent Management
```bash
# List all available agents by category
claude --agents
claude agents

# Manually refresh agent registry
claude --register-agents

# Run a specific agent
claude --agent <name>
claude agent <name>

# Show detailed agent information
claude --agent-info <name>
```

#### System Maintenance
```bash
# Auto-detect and fix issues
claude --fix

# Run without permission bypass
claude --safe

# Enable debug output
claude --debug [command]

# Show help
claude --help
```

### Agent Discovery Process

1. **Automatic Registration**: On first use or when agents directory changes
2. **Metadata Extraction**: Parses YAML frontmatter and markdown formats
3. **Category Grouping**: Organizes agents by their categories
4. **Status Detection**: Determines if agent is active, template, or stub
5. **Cache Management**: Stores registry for fast subsequent access

### Environment Variables

```bash
# Core Configuration
CLAUDE_PROJECT_ROOT      # Project root directory
CLAUDE_AGENTS_DIR        # Path to agents directory
CLAUDE_VENV             # Path to Python virtual environment
CLAUDE_HOME             # Claude home directory

# Feature Flags
CLAUDE_PERMISSION_BYPASS # Enable permission bypass (default: true)
CLAUDE_AUTO_FIX         # Enable automatic issue fixing (default: true)
CLAUDE_ORCHESTRATION    # Enable orchestration (default: true)
CLAUDE_LEARNING         # Enable learning mode (default: true)
CLAUDE_DEBUG            # Enable debug mode (default: false)

# Suppression Flags
CLAUDE_QUIET_MODE       # Suppress verbose output
CLAUDE_SUPPRESS_BANNER  # Suppress banner headers
NO_AGENT_BRIDGE_HEADER  # Disable agent bridge headers
```

## Agent Registry Structure

The registry is stored as JSON with the following structure:

```json
{
  "agents": {
    "agent_name": {
      "name": "agent_name",
      "display_name": "AGENT_NAME",
      "file_path": "/full/path/to/agent.md",
      "category": "security",
      "description": "Agent description",
      "uuid": "unique-identifier",
      "tools": ["Task", "Read", "Write"],
      "status": "active",
      "last_modified": "2025-08-25T10:00:00Z"
    }
  },
  "last_updated": "2025-08-25T10:00:00Z",
  "total_count": 71
}
```

## 71 Detected Agents

### Categories and Counts
- **Command & Control**: 2 agents (Director, ProjectOrchestrator)
- **Security Specialists**: 13 agents (includes Ghost-Protocol, Cognitive-Defense)
- **Core Development**: 8 agents (Architect, Constructor, Debugger, etc.)
- **Infrastructure & DevOps**: 6 agents (Docker, Deployer, Monitor, etc.)
- **Language-Specific**: 14 agents (C, Python, Rust, Go, Java, TypeScript, etc.)
- **Specialized Platforms**: 7 agents (Web, Mobile, GUI, TUI, etc.)
- **Data & ML**: 4 agents (DataScience, MLOps, NPU, SQL-Internal)
- **Network & Systems**: 7 agents (Cisco, BGP teams, IoT, DD-WRT)
- **Hardware & Acceleration**: 2 agents (GNA, LeadEngineer)
- **Planning & Documentation**: 4 agents (Planner, Docgen, Researcher)
- **Quality & Oversight**: 2 agents (Oversight, Integration)
- **Additional Specialized**: Various prompt defense, wrapper liberation agents

## Troubleshooting

### Common Issues and Solutions

#### Claude Not Found
```bash
# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Or use auto-fix
claude --fix
```

#### Agents Not Discovered
```bash
# Manually register agents
claude --register-agents

# Check agents directory
ls -la $CLAUDE_PROJECT_ROOT/agents/
```

#### Permission Issues
```bash
# Run without permission bypass
claude --safe [command]

# Or disable globally
export CLAUDE_PERMISSION_BYPASS=false
```

#### Yoga.wasm Error
The wrapper automatically detects and fixes this issue. If persistent:
```bash
# Force reinstall
CLAUDE_AUTO_FIX=true claude --fix
```

### Debug Mode
Enable detailed debug output for troubleshooting:
```bash
# One-time debug
claude --debug [command]

# Persistent debug mode
export CLAUDE_DEBUG=true
```

## Technical Details

### File Locations
- **Wrapper**: `$CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh`
- **Symlink**: `$HOME/.local/bin/claude`
- **Agents**: `$CLAUDE_PROJECT_ROOT/agents/`
- **Cache**: `~/.cache/claude/`
- **Registry**: `~/.cache/claude/registered_agents.json`

### Version Information
- **Wrapper Version**: 13.1
- **Enhanced Features**: Added in v13.0-13.1
  - v13.0: Banner suppression, correct status reporting
  - v13.1: Automatic agent registration, enhanced venv support

### Performance Characteristics
- **Agent Discovery**: ~100ms for 71 agents
- **Registry Cache**: Instant after first run
- **Health Check**: <50ms
- **Auto-fix**: 2-10 seconds depending on issue

## Integration with Claude Installer

The `claude-installer.sh` has been updated to use symlinks instead of copying:

```bash
# Old approach (copying - breaks agent discovery)
cp claude-wrapper-ultimate.sh ~/.local/bin/claude

# New approach (symlink - preserves agent discovery)
ln -sf "$PROJECT_ROOT/claude-wrapper-ultimate.sh" "$LOCAL_BIN/claude"
```

This ensures the wrapper can always find the agents directory relative to its actual location.

## Best Practices

1. **Always use symlinks** for installation to preserve agent discovery
2. **Keep agents in the same directory** as the wrapper script
3. **Run `claude --status`** periodically to check system health
4. **Use `claude --register-agents`** after adding new agents
5. **Enable debug mode** when troubleshooting issues
6. **Check virtual environment** activation for Python agents

## Security Considerations

- **Permission Bypass**: Enabled by default for LiveCD compatibility
- **Safe Mode**: Use `--safe` flag for production environments
- **Agent Validation**: Wrapper validates agent files before registration
- **Cache Security**: Registry cache uses user-only permissions

## Future Enhancements

Planned improvements for future versions:
- Agent dependency resolution
- Parallel agent execution
- Interactive agent selection menu
- Agent health monitoring
- Performance metrics collection
- Agent versioning support

## Support and Feedback

- **GitHub Issues**: Report bugs at the project repository
- **Documentation**: This file and CLAUDE.md in project root
- **Debug Output**: Use `--debug` flag for diagnostic information
- **System Status**: Run `--status` for comprehensive system check

---

*Last Updated: 2025-08-25*  
*Version: 13.1*  
*Status: Production Ready*