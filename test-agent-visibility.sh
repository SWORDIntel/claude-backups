#!/bin/bash
# Test if Claude Code can see custom agents

echo "Testing Claude Code agent visibility..."
echo ""
echo "Agents in ~/.claude/agents/:"
ls ~/.claude/agents/*.md 2>/dev/null | wc -l
echo ""
echo "Sample agents:"
ls ~/.claude/agents/*.md 2>/dev/null | head -5 | xargs -n1 basename
echo ""
echo "Now restart Claude Code or open a new session to see all agents!"
echo ""
echo "The agents should appear when you:"
echo "1. Use the Task tool in Claude"
echo "2. Type @agents or look for agent mentions"
echo ""
echo "Symlink status:"
ls -la ~/.claude/agents | head -1