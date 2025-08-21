#!/bin/bash
# Create: setup_claude_hooks.sh

echo "🚀 Setting up Claude Code Hooks Integration"

# 1. Install Python hook system
echo "📦 Installing Python hooks..."
cd /home/ubuntu/Documents/Claude/agents
python3 -m pip install pyyaml psutil

# 2. Create hook directories
echo "📁 Creating hook structure..."
mkdir -p ~/.claude/hooks/{pre-task,post-edit,post-task}
mkdir -p hooks  # For Python hook modules
mkdir -p .agent_cache reports generated_code

# 3. Register with Claude Code
echo "🔗 Registering with Claude Code..."
python3 claude_code_hook_adapter.py --register

# 4. Install hook scripts
echo "📝 Installing hook scripts..."
./install_claude_hooks.sh

# 5. Test the integration
echo "🧪 Testing hook integration..."
python3 claude_hook_manager.py test pre-task

echo "✅ Claude Code hooks integration complete!"
echo ""
echo "Usage in Claude Code:"
echo "  /hooks enable       - Enable all hooks"
echo "  /hooks disable      - Disable all hooks"
echo "  /hooks list         - List registered hooks"
echo "  /hooks test pre-task - Test pre-task hook"
echo ""
echo "The hooks will now automatically trigger during:"
echo "  • Task validation (pre-task)"
echo "  • Code edits (post-edit)"
echo "  • Task completion (post-task)"
