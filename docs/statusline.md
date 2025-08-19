# Statusline Integration Guide

## Overview

The Claude Agent Framework v7.0 includes a comprehensive Neovim statusline that provides real-time monitoring of:

- **Git Status**: Branch, changes, ahead/behind counts
- **Project Health**: CI/CD status, test coverage, lint errors, security issues
- **Agent System**: Binary bridge status, active agents, chaos testing, task counts
- **Military Hardware**: DSMIL devices, Mode 5 status (Dell MIL-SPEC systems)
- **Performance**: Build times, bundle sizes, queue depths

## Files

- `statusline.lua` - Main Neovim statusline module
- `src/python/statusline_bridge.py` - Python bridge for agent status
- `runtime/status.json` - Shared status file (auto-created)

## Installation

### 1. Neovim Configuration

Add to your `~/.config/nvim/init.lua` or `~/.config/nvim/lua/config.lua`:

```lua
-- Set CLAUDE_AGENTS_ROOT if not already set
if not vim.env.CLAUDE_AGENTS_ROOT then
  vim.env.CLAUDE_AGENTS_ROOT = vim.fn.expand("~/Documents/Claude/agents")
end

-- Add Claude agents directory to Lua path
local claude_root = vim.env.CLAUDE_AGENTS_ROOT
package.path = package.path .. ";" .. claude_root .. "/?.lua"

-- Load and setup statusline
local statusline = require("statusline")
statusline.setup()
```

### 2. Environment Variables

Set the environment variable for your shell (add to `~/.bashrc` or `~/.zshrc`):

```bash
export CLAUDE_AGENTS_ROOT="$HOME/Documents/Claude/agents"
```

### 3. Python Integration

The Python statusline bridge automatically creates status files that the Lua statusline reads:

```python
from src.python.statusline_bridge import update_statusline

# Update statusline when tasks start/complete
update_statusline("task_started", agent="Director")
update_statusline("task_completed", agent="Director")
update_statusline("task_error", agent="Security", error="Connection failed")
```

## Features

### Status Components

The statusline displays information in this order:
1. **Project Info**: `🎯 project-name [type]`
2. **Git Status**: `🔀 main (~2 +1 ?3) ↑1`
3. **Binary Bridge**: `🟢 Bridge ✅ 15 ❌ 2`
4. **CI/CD**: `✅ CI:passing`
5. **Coverage**: `🟢 COV:85%`
6. **Linting**: `✨ LINT:0`
7. **Security**: `🔒 SEC:0`
8. **Agents**: `🤖 Agents:34`
9. **Chaos Testing**: `🔬 Tests:3`
10. **Military Hardware**: `🛡️ DSMIL:2 🔐 Mode5`
11. **Performance**: `⚡2.1s 📦15MB`

### Commands

Available Neovim commands:

- `:StatuslineDebug` - Toggle debug mode (shows timing)
- `:StatuslineUpdate` - Force refresh all status
- `:ProjectStatus` - Show detailed project status
- `:AgentStatus` - Show detailed agent status
- `:AgentList` - List all available agents
- `:AgentBridge start|stop|restart|status` - Control binary bridge
- `:AgentChaosTest [target]` - Initiate chaos testing

### Color Coding

- 🟢 Green: Good status, passing tests, no issues
- 🟡 Yellow: Warnings, medium coverage, minor issues  
- 🔴 Red: Errors, failing tests, critical issues
- ⚪ White/Gray: Unknown or neutral status
- 🔥 Fire: Critical chaos testing findings
- ⚠️ Warning: Issues requiring attention

## Integration with Agent Framework

### Automatic Status Updates

The statusline automatically updates when:
- Files are written (`BufWritePost`)
- Buffers are entered (`BufEnter`)
- Neovim gains focus (`FocusGained`)
- Agent events occur (`User AgentStatusUpdate`)
- Every 30 seconds (periodic update)

### Agent Status Integration

The statusline reads from several sources:
- `runtime/status.json` - Python bridge status file
- `runtime/claude_agent_bridge.sock` - Binary bridge socket
- `logs/chaos_latest.json` - Chaos testing results
- Git repository status
- Project files (package.json, requirements.txt, etc.)

### Performance Monitoring

Debug mode shows timing for each component:
- Git command execution time
- Agent status check time
- File system check time
- Total update time

## Troubleshooting

### Common Issues

1. **Statusline not showing**: Check that `statusline.lua` is in the Lua path
2. **No agent data**: Verify `CLAUDE_AGENTS_ROOT` environment variable
3. **Socket errors**: Ensure binary bridge is running
4. **Performance issues**: Enable debug mode to check timing

### Debug Commands

```vim
:StatuslineDebug          " Show timing information
:ProjectStatus            " Detailed project status
:AgentStatus              " Raw agent status data
:echo $CLAUDE_AGENTS_ROOT " Check environment variable
```

### Log Files

Status information is logged to:
- `runtime/status.json` - Current status snapshot
- `logs/chaos_latest.json` - Chaos testing results
- Neovim command output for debugging

## Binary System Offline Mode

When the binary communication system is offline:
- Bridge status shows 🔴 (red)
- Socket status shows ⚠️ (warning)
- Agent count still displays available .md agents
- Git, CI/CD, and project status continue working
- Performance monitoring remains functional

The statusline gracefully degrades and provides useful information even when the ultra-fast binary protocol is unavailable.

## Configuration

### Custom Colors

Override colors in your Neovim config:

```lua
local statusline = require("statusline")
-- Modify colors before setup
statusline.colors.git_clean = "#your_color"
statusline.setup()
```

### Custom Components

Add custom status components:

```lua
-- Add after statusline.setup()
local original_get_statusline = statusline.get_statusline
statusline.get_statusline = function()
  local base = original_get_statusline()
  return base .. " | 🌡️ " .. vim.fn.system("sensors | grep temp1 | awk '{print $2}'")
end
```

---

*Updated: 2025-08-18*  
*Framework Version: 7.0*  
*Status: PRODUCTION*