# Installer Comparison: Global Agent Access

## Answer: YES - Both Installers Deploy the Unified Wrapper with Global Agents!

Both installers in the `installers/` directory properly set up the claude-unified wrapper with full global agent access.

## 1. claude-installer.sh (Full Installer)

### What It Installs:
- ✅ **Unified Wrapper**: Copies `claude-unified` to `/home/siducer/.local/bin/claude`
- ✅ **Global Agents**: Links agents from project to `~/agents` for Task tool discovery
- ✅ **Python venv**: Creates virtual environment with dependencies
- ✅ **Orchestration**: Sets up Tandem Orchestration System
- ✅ **Permission Bypass**: Enabled by default

### Key Code:
```bash
deploy_unified_wrapper() {
    cp "$UNIFIED_WRAPPER" "$USER_BIN_DIR/claude"        # Main command
    cp "$UNIFIED_WRAPPER" "$USER_BIN_DIR/claude-unified" # Also as claude-unified
    chmod +x "$USER_BIN_DIR/claude"
}

install_agents_with_sync() {
    ln -s "$SOURCE_AGENTS_DIR" "$CLAUDE_HOME_AGENTS"    # Link to ~/agents
    # Sets up CLAUDE_AGENTS_DIR environment variable
}
```

### Installation Command:
```bash
./claude-installer.sh --full
```

## 2. claude-livecd-unified-with-agents.sh (LiveCD Installer)

### What It Installs:
- ✅ **Unified Wrapper**: Deploys to multiple locations including `/home/siducer/.local/bin/claude`
- ✅ **Global Agents**: Copies agents to `~/agents` for Task tool discovery
- ✅ **Permission Bypass**: Always enabled (LiveCD mode)
- ✅ **Agent Sync**: Sets up 5-minute sync for agent updates
- ✅ **Orchestration**: Full orchestration support

### Key Code:
```bash
deploy_unified_wrapper() {
    # Checks multiple locations for claude-unified
    cp "$found_wrapper" "$wrapper_path"
    cp "$found_wrapper" "$USER_BIN_DIR/claude"
}

install_agents_with_discovery() {
    cp -r "$SOURCE_AGENTS_DIR" "$CLAUDE_HOME_AGENTS"    # Copy to ~/agents
    # CRITICAL: Copy to ~/agents for Task tool discovery
}
```

### Installation Command:
```bash
./claude-livecd-unified-with-agents.sh --auto-mode
```

## Feature Comparison

| Feature | claude-installer.sh | livecd-installer |
|---------|-------------------|------------------|
| **Unified Wrapper** | ✅ Yes | ✅ Yes |
| **Global `claude` Command** | ✅ Yes | ✅ Yes |
| **Agent Installation** | ✅ Symlink | ✅ Copy |
| **~/agents Directory** | ✅ Yes | ✅ Yes |
| **Permission Bypass** | ✅ Configurable | ✅ Always On |
| **Python venv** | ✅ Yes | ❌ No |
| **Orchestration** | ✅ Yes | ✅ Yes |
| **Agent Sync** | ✅ Manual | ✅ Auto (5 min) |
| **Project Root Detection** | ✅ Dynamic | ✅ Dynamic |

## Both Installers Provide:

### 1. Global Claude Command
```bash
# From anywhere:
claude /task "create feature with tests"
```

### 2. Global Agent Access
- **Via Task Tool**: All 46 agents available
- **Via CLI**: `claude-agent` command works
- **Via Orchestration**: Multi-agent workflows

### 3. Environment Setup
Both set these environment variables:
```bash
export CLAUDE_PROJECT_ROOT="/home/siducer/Documents/Claude"
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PERMISSION_BYPASS=true  # LiveCD installer
```

### 4. Wrapper Features
- Automatic permission bypass (LiveCD compatibility)
- Orchestration detection for complex tasks
- Dynamic path finding
- Virtual environment support (claude-installer.sh)

## Key Differences:

### claude-installer.sh:
- **More Comprehensive**: Includes Python venv setup
- **Symlinks Agents**: Uses symlinks (more efficient)
- **Configurable**: Can disable permission bypass
- **Better for Development**: Full development environment

### livecd-installer:
- **LiveCD Focused**: Always enables permission bypass
- **Copies Agents**: Physical copies (works on LiveCD)
- **Auto-Sync**: 5-minute agent synchronization
- **Better for LiveCD**: Optimized for read-only systems

## Which Should You Use?

### Use `claude-installer.sh` if:
- Installing on a regular system
- Need Python virtual environment
- Want full development setup
- Need configurable options

### Use `claude-livecd-unified-with-agents.sh` if:
- Running from LiveCD/USB
- Need guaranteed permission bypass
- Want automatic agent syncing
- Working with read-only filesystems

## Verification

After either installation:
```bash
# Check status
claude --unified-status

# Should show:
# ✓ Project Root: Found
# ✓ Claude Binary: Found
# ✓ Permission Bypass: Enabled
# ✓ Orchestration: Available
# ✓ Agents: 46 agents found

# Test agent access
claude-agent --list

# Test orchestration detection
claude /task "create and test a feature"
```

## Conclusion

**YES** - Both installers properly set up:
- ✅ The claude-unified wrapper as the main `claude` command
- ✅ Global access to all 46 agents
- ✅ Automatic permission bypass
- ✅ Orchestration detection
- ✅ Dynamic path finding

The main difference is that `claude-installer.sh` is more comprehensive (includes Python venv), while `claude-livecd-unified-with-agents.sh` is optimized for LiveCD environments with automatic syncing.