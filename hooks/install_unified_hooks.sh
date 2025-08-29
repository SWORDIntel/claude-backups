#!/bin/bash
# Install Unified Hook System
# Consolidates all hook functionality into single system

set -e

echo "==================================="
echo "Claude Unified Hook System Installer"
echo "Version: 3.1 (Optimized)"
echo "==================================="

# Find project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/hooks"
CONFIG_DIR="$HOME/.config/claude"
CACHE_DIR="$HOME/.cache/claude-agents"

echo "Project root: $PROJECT_ROOT"

# Create directories
echo "Creating directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$HOME/.local/bin"

# Backup old hook files (if they exist)
if [ -d "$HOOKS_DIR/backup" ]; then
    echo "Backup directory already exists, skipping backup"
else
    echo "Backing up old hook files..."
    mkdir -p "$HOOKS_DIR/backup"
    
    # Move old files to backup (don't fail if they don't exist)
    for file in agent-semantic-matcher.py claude-fuzzy-agent-matcher.py \
                natural-invocation-hook.py claude_hooks_bridge.py \
                claude_code_hook_adapter.py; do
        if [ -f "$HOOKS_DIR/$file" ]; then
            mv "$HOOKS_DIR/$file" "$HOOKS_DIR/backup/" 2>/dev/null || true
            echo "  Backed up: $file"
        fi
    done
fi

# Create main hook command
echo "Creating unified hook command..."
cat > "$HOME/.local/bin/claude-hooks" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import asyncio

# Add hooks directory to path
hooks_dir = os.path.expanduser("~/claude-backups/hooks")
if os.path.exists(hooks_dir):
    sys.path.insert(0, hooks_dir)
else:
    # Try to find it relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    hooks_dir = os.path.join(project_root, "hooks")
    if os.path.exists(hooks_dir):
        sys.path.insert(0, hooks_dir)

from claude_unified_hook_system import ClaudeUnifiedHooks, UnifiedConfig

async def main():
    # Get input from command line or stdin
    if len(sys.argv) > 1:
        user_input = " ".join(sys.argv[1:])
    else:
        print("Enter your request (or 'help' for usage):")
        user_input = input("> ").strip()
    
    if user_input.lower() in ['help', '--help', '-h']:
        print("""
Claude Unified Hook System

Usage:
  claude-hooks <request>              Process a request
  claude-hooks list [category]        List available agents
  claude-hooks status                 Show system status
  claude-hooks test                   Run test cases
  
Examples:
  claude-hooks "fix the authentication bug"
  claude-hooks "deploy to production"
  claude-hooks "run security audit"
  claude-hooks list security
  
Agents are automatically selected based on your request.
        """)
        return
    
    # Special commands
    if user_input.startswith("list"):
        parts = user_input.split()
        category = parts[1] if len(parts) > 1 else None
        
        config = UnifiedConfig()
        hooks = ClaudeUnifiedHooks(config)
        agents = hooks.list_agents(category=category)
        
        print(f"\nFound {len(agents)} agents:\n")
        for agent in agents:
            status = "✓" if agent["status"] == "ACTIVE" else "○"
            desc = agent.get('description', 'No description')[:50]
            print(f"  {status} {agent['name']:30} [{agent['category']:15}] {desc}...")
        return
    
    if user_input == "status":
        config = UnifiedConfig()
        hooks = ClaudeUnifiedHooks(config)
        status = hooks.get_status()
        
        import json
        print(json.dumps(status, indent=2))
        return
    
    if user_input == "test":
        # Run automated tests
        test_cases = [
            "fix the authentication bug",
            "deploy to production",
            "run security audit",
            "optimize performance",
            "create documentation"
        ]
        
        config = UnifiedConfig()
        hooks = ClaudeUnifiedHooks(config)
        
        print("\nRunning test cases:\n")
        for test in test_cases:
            print(f"Input: {test}")
            result = await hooks.process(test)
            
            if result.get('agents_executed'):
                print(f"  ✓ Agents: {', '.join(result['agents_executed'])}")
            elif result.get('suggested_commands'):
                print(f"  → Commands: {len(result['suggested_commands'])} generated")
            else:
                print(f"  ✗ No agents matched")
            print()
        return
    
    # Process normal input
    config = UnifiedConfig()
    hooks = ClaudeUnifiedHooks(config)
    
    print(f"\nProcessing: {user_input}\n")
    result = await hooks.process(user_input)
    
    if result.get('success'):
        print("✓ Success!\n")
        
        if result.get('agents_executed'):
            print(f"Agents executed: {', '.join(result['agents_executed'])}")
        
        if result.get('workflow'):
            print(f"Workflow: {result['workflow']}")
        
        if result.get('results'):
            print("\nResults:")
            for agent, res in result['results'].items():
                print(f"  {agent}: {res}")
    else:
        print("⚠ Task tool not available\n")
        
        if result.get('suggested_commands'):
            print("Run these commands in Claude Code:\n")
            for cmd in result['suggested_commands']:
                print(f"  {cmd}")
        
        if result.get('message'):
            print(f"\n{result['message']}")
    
    if result.get('errors'):
        print("\nErrors:")
        for error in result['errors']:
            print(f"  ✗ {error}")

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x "$HOME/.local/bin/claude-hooks"

# Create configuration file
echo "Creating configuration..."
cat > "$CONFIG_DIR/unified_hooks.json" << EOF
{
  "version": "3.0",
  "features": {
    "fuzzy_matching": true,
    "semantic_matching": true,
    "natural_invocation": true,
    "shadowgit": false,
    "learning": true
  },
  "performance": {
    "cache_ttl_seconds": 3600,
    "max_parallel_agents": 8,
    "confidence_threshold": 0.7
  },
  "paths": {
    "project_root": "$PROJECT_ROOT",
    "agents_dir": "$PROJECT_ROOT/agents",
    "shadow_repo": "$PROJECT_ROOT/.shadowgit"
  }
}
EOF

# Create symlinks for backward compatibility
echo "Creating compatibility symlinks..."
cd "$HOOKS_DIR"

# Create simple wrapper scripts that use the unified system
for old_script in agent-semantic-matcher.py claude-fuzzy-agent-matcher.py \
                  natural-invocation-hook.py claude_hooks_bridge.py; do
    
    base_name="${old_script%.py}"
    
    cat > "$old_script" << 'EOF'
#!/usr/bin/env python3
"""
Compatibility wrapper - redirects to unified hook system
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from claude_unified_hook_system import *

print(f"Note: {__file__} is deprecated. Using unified hook system.")

# Maintain backward compatibility
if __name__ == "__main__":
    import asyncio
    
    config = UnifiedConfig()
    hooks = ClaudeUnifiedHooks(config)
    
    if len(sys.argv) > 1:
        input_text = " ".join(sys.argv[1:])
        result = asyncio.run(hooks.process(input_text))
        print(result)
    else:
        status = hooks.get_status()
        print(f"Unified Hook System Status: {status}")
EOF
    
    chmod +x "$old_script"
    echo "  Created compatibility wrapper: $old_script"
done

# Test the installation
echo ""
echo "Testing installation..."
if python3 -c "import sys; sys.path.insert(0, '$HOOKS_DIR'); from claude_unified_hook_system import ClaudeUnifiedHooks; print('✓ Import successful')" 2>/dev/null; then
    echo "✓ Python module loads correctly"
else
    echo "✗ Failed to load Python module"
    exit 1
fi

if [ -x "$HOME/.local/bin/claude-hooks" ]; then
    echo "✓ Command installed to ~/.local/bin/claude-hooks"
else
    echo "✗ Command installation failed"
    exit 1
fi

# Show summary
echo ""
echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "The unified hook system consolidates:"
echo "  • agent-semantic-matcher.py"
echo "  • claude-fuzzy-agent-matcher.py"  
echo "  • natural-invocation-hook.py"
echo "  • claude_hooks_bridge.py"
echo "  • claude_code_hook_adapter.py"
echo ""
echo "Into a single file:"
echo "  → claude_unified_hook_system.py"
echo ""
echo "Usage:"
echo "  claude-hooks 'fix the authentication bug'"
echo "  claude-hooks list"
echo "  claude-hooks status"
echo "  claude-hooks test"
echo ""
echo "Old files backed up to: $HOOKS_DIR/backup/"
echo ""
echo "Features:"
echo "  ✓ All 76 agents accessible"
echo "  ✓ Fuzzy matching for typos"
echo "  ✓ Semantic pattern matching"
echo "  ✓ Workflow detection"
echo "  ✓ Learning system integration"
echo "  ⚠ Shadowgit ready (not active)"
echo "  ⚠ Task tool integration (pending)"
echo ""
echo "Next steps:"
echo "  1. Test with: claude-hooks test"
echo "  2. Enable shadowgit when ready"
echo "  3. Connect Task tool for full integration"