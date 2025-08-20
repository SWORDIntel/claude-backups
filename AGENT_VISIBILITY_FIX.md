# Claude Code Agent Visibility Fix

## Problem Solved
Claude Code wasn't finding your custom agents when launched from other directories because it looks for agents in `~/.claude/agents/`, not in your project directory.

## Solution Implemented

### 1. Immediate Fix: Symlink
Created a symbolic link from `~/.claude/agents/` to your project agents:
```bash
ln -sf /home/siducer/Documents/Claude/agents ~/.claude/agents
```

### 2. Automatic Sync: Cron Job
Set up a cron job that runs every 5 minutes to ensure agents stay synced:
```bash
*/5 * * * * /home/siducer/.local/bin/sync-claude-agents-enhanced.sh
```

The enhanced sync script:
- Maintains symlink to `~/.claude/agents/` (for Claude Code)
- Syncs to `~/agents/` (for legacy compatibility)
- Creates backups in `~/.local/share/claude/agents/`
- Logs all operations to `~/.local/share/claude/agent-sync.log`

## Result
✅ **47 agents now visible to Claude Code from any directory!**

## How to Verify

### In Claude Code:
When you use Claude from any directory, the Task tool should now show all your custom agents:
- director
- architect
- security
- debugger
- ... and 43 more!

### From Terminal:
```bash
# Check symlink
ls -la ~/.claude/agents

# Count agents
ls ~/.claude/agents/*.md | wc -l

# View sync log
tail ~/.local/share/claude/agent-sync.log

# Test agent visibility
claude /task "list available agents"
```

## Important Notes

1. **Restart Claude Code**: You may need to restart Claude or start a new session for it to detect the agents.

2. **Agent Discovery**: Claude Code looks for agents in these locations:
   - `~/.claude/agents/` (primary location)
   - Built-in agents directory

3. **Sync Frequency**: The cron job runs every 5 minutes, so any new agents you add will be available within 5 minutes maximum.

4. **Manual Sync**: To sync immediately:
   ```bash
   /home/siducer/.local/bin/sync-claude-agents-enhanced.sh
   ```

## Troubleshooting

If agents still don't appear:
1. Restart Claude Code completely
2. Check the symlink: `ls -la ~/.claude/agents`
3. Check sync log: `tail ~/.local/share/claude/agent-sync.log`
4. Run manual sync: `/home/siducer/.local/bin/sync-claude-agents-enhanced.sh`
5. Verify agent files: `ls ~/.claude/agents/*.md`

## Files Created

1. **Sync Script**: `/home/siducer/.local/bin/sync-claude-agents-enhanced.sh`
2. **Test Script**: `/home/siducer/Documents/Claude/test-agent-visibility.sh`
3. **Symlink**: `~/.claude/agents -> /home/siducer/Documents/Claude/agents`
4. **Cron Job**: Every 5 minutes automatic sync

## Summary

Your agents are now globally accessible to Claude Code! The combination of:
- Symlink for immediate access
- Cron job for automatic updates
- Enhanced sync script for reliability

Ensures that no matter where you launch Claude from, all 47 agents will be available to the Task tool.