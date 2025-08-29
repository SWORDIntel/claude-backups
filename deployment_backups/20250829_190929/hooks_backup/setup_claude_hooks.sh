#!/bin/bash
# setup_claude_hooks.sh - Fixed Version
# Complete setup for Claude Code Hooks Integration with Agent Registry

set -e

echo "🚀 Setting up Claude Code Hooks Integration with Agent Registry"

# Dynamic path discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root dynamically
find_project_root() {
    local current="$SCRIPT_DIR"
    local markers=(".claude" "agents" "CLAUDE.md" ".git")
    
    while [ "$current" != "/" ]; do
        for marker in "${markers[@]}"; do
            if [ -e "$current/$marker" ]; then
                echo "$current"
                return 0
            fi
        done
        current="$(dirname "$current")"
    done
    
    # Fallback to current directory
    echo "$(pwd)"
}

PROJECT_ROOT="$(find_project_root)"
AGENTS_DIR="$PROJECT_ROOT/agents"
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
CACHE_DIR="$HOME/.cache/claude-agents"

echo "📂 Project Configuration:"
echo "   • Project root: $PROJECT_ROOT"
echo "   • Agents directory: $AGENTS_DIR"
echo "   • Config directory: $CLAUDE_CONFIG_DIR"
echo ""

# Step 1: Check Python and install dependencies
echo "1️⃣ Checking Python environment..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "   ✅ Python $PYTHON_VERSION found"

echo "   📦 Installing Python dependencies..."
python3 -m pip install --quiet --user pyyaml psutil 2>/dev/null || {
    echo "   ⚠️ Could not install Python packages. Trying with apt..."
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -qq python3-yaml python3-psutil 2>/dev/null || {
        echo "   ℹ️ Manual installation may be required for: pyyaml, psutil"
    }
}

# Step 2: Create directory structure
echo "2️⃣ Creating directory structure..."
mkdir -p "$CLAUDE_CONFIG_DIR"
mkdir -p "$CLAUDE_HOOKS_DIR"/{pre-task,post-edit,post-task}
mkdir -p "$CACHE_DIR"/{tasks,edits,archives}
mkdir -p "$PROJECT_ROOT"/{hooks,reports,generated_code,.agent_cache}
mkdir -p "$AGENTS_DIR" 2>/dev/null || true

echo "   ✅ Directories created"

# Step 3: Check for Python adapter files
echo "3️⃣ Checking for Python adapter files..."

# Check for claude_code_hook_adapter.py
if [ ! -f "$AGENTS_DIR/claude_code_hook_adapter.py" ]; then
    echo "   ⚠️ claude_code_hook_adapter.py not found"
    echo "   🔍 Searching for adapter in alternate locations..."
    
    FOUND_ADAPTER=""
    for alt_path in \
        "$PROJECT_ROOT/claude_code_hook_adapter.py" \
        "$SCRIPT_DIR/claude_code_hook_adapter.py" \
        "$HOME/Documents/Claude/agents/claude_code_hook_adapter.py"; do
        if [ -f "$alt_path" ]; then
            echo "   📍 Found adapter at: $alt_path"
            FOUND_ADAPTER="$alt_path"
            break
        fi
    done
    
    if [ -n "$FOUND_ADAPTER" ]; then
        echo "   📋 Copying adapter to agents directory..."
        cp "$FOUND_ADAPTER" "$AGENTS_DIR/claude_code_hook_adapter.py"
        echo "   ✅ Adapter installed"
    else
        echo "   ❌ claude_code_hook_adapter.py not found"
        echo "   Please ensure claude_code_hook_adapter.py is available"
    fi
else
    echo "   ✅ claude_code_hook_adapter.py found"
fi

# Check for claude_registry_bridge.py
if [ ! -f "$AGENTS_DIR/claude_registry_bridge.py" ]; then
    echo "   ⚠️ claude_registry_bridge.py not found"
    echo "   ℹ️ Registry bridge is optional but recommended"
else
    echo "   ✅ claude_registry_bridge.py found"
fi

# Step 4: Build agent registry
echo "4️⃣ Building agent registry..."

# Create a temporary Python script to build the registry
cat > "/tmp/build_registry.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path
from datetime import datetime

def find_project_root():
    """Find project root dynamically"""
    current = Path.cwd()
    markers = ['.claude', 'agents', 'CLAUDE.md', '.git']
    
    while current != current.parent:
        for marker in markers:
            if (current / marker).exists():
                return current
        current = current.parent
    
    return Path.cwd()

PROJECT_ROOT = find_project_root()
AGENTS_DIR = PROJECT_ROOT / 'agents'
CONFIG_DIR = Path.home() / '.config' / 'claude'
REGISTRY_FILE = CONFIG_DIR / 'project-agents.json'

# Ensure config directory exists
CONFIG_DIR.mkdir(parents=True, exist_ok=True)

# Build registry
registry = {
    "version": "2.0.0",
    "updated": datetime.now().isoformat(),
    "project_root": str(PROJECT_ROOT),
    "custom_agents": {},
    "agent_mappings": {},
    "categories": {}
}

# Excluded files
excluded = {
    "README.md", "Template.md", "STATUSLINE_INTEGRATION.md",
    "WHERE_I_AM.md", "DIRECTORY_STRUCTURE.md", "ORGANIZATION.md",
    "INTEGRATION_COMPLETE.md", "INTEGRATION_EXAMPLE.md", "CLAUDE.md"
}

# Find all agent files
if AGENTS_DIR.exists():
    agent_files = []
    for pattern in ["*.md", "*.MD"]:
        agent_files.extend(AGENTS_DIR.glob(pattern))
    
    agent_files = [f for f in agent_files if f.name not in excluded]
    
    for agent_file in agent_files:
        agent_name = agent_file.stem.lower()
        
        # Add to registry
        registry["custom_agents"][agent_name] = {
            "type": agent_name,
            "name": agent_name.replace('_', ' ').replace('-', ' ').title(),
            "description": f"{agent_name} agent",
            "source": "project",
            "file_path": str(agent_file.relative_to(PROJECT_ROOT))
        }
        
        # Create mappings
        registry["agent_mappings"][agent_name] = agent_name
        registry["agent_mappings"][agent_name.replace('-', '_')] = agent_name
        registry["agent_mappings"][agent_name.replace('_', '-')] = agent_name

# Save registry
with open(REGISTRY_FILE, 'w') as f:
    json.dump(registry, f, indent=2)

print(f"   ✅ Registry built with {len(registry['custom_agents'])} agents")
print(f"   📍 Registry saved to: {REGISTRY_FILE}")
PYTHON_EOF

python3 /tmp/build_registry.py
rm -f /tmp/build_registry.py

# Step 5: Install hook scripts
echo "5️⃣ Installing hook scripts..."
if [ -f "$SCRIPT_DIR/install_claude_hooks.sh" ]; then
    bash "$SCRIPT_DIR/install_claude_hooks.sh"
elif [ -f "./install_claude_hooks.sh" ]; then
    bash ./install_claude_hooks.sh
else
    echo "   ⚠️ install_claude_hooks.sh not found, creating basic hooks..."
    
    # Create basic hook wrapper
    cat > "$CLAUDE_HOOKS_DIR/claude_hook_wrapper.sh" << 'EOF'
#!/bin/bash
HOOK_PHASE="$1"
echo "Hook triggered: $HOOK_PHASE"

# Find and call Python adapter if available
for adapter_path in \
    "$(pwd)/agents/claude_code_hook_adapter.py" \
    "$HOME/Documents/Claude/agents/claude_code_hook_adapter.py"; do
    if [ -f "$adapter_path" ]; then
        python3 "$adapter_path" --trigger "$HOOK_PHASE"
        break
    fi
done
EOF
    chmod +x "$CLAUDE_HOOKS_DIR/claude_hook_wrapper.sh"
    echo "   ✅ Basic hooks installed"
fi

# Step 6: Register with Claude Code
echo "6️⃣ Registering with Claude Code..."

if [ -f "$AGENTS_DIR/claude_code_hook_adapter.py" ]; then
    python3 "$AGENTS_DIR/claude_code_hook_adapter.py" --register && \
        echo "   ✅ Registered with Claude Code" || \
        echo "   ⚠️ Registration may require manual completion"
else
    echo "   ⚠️ Cannot register - adapter not found"
fi

# Step 7: Test the integration
echo "7️⃣ Testing hook integration..."

# Test Python imports
echo "   Testing Python environment..."
python3 -c "
import sys
import json
import pathlib
from datetime import datetime
print('   ✅ Core Python modules working')
" 2>/dev/null || echo "   ⚠️ Python module issues detected"

# Test hook execution
if [ -f "$CLAUDE_HOOKS_DIR/claude_hook_wrapper.sh" ]; then
    echo "   Testing hook wrapper..."
    export CLAUDE_TASK_ID="test_$(date +%s)"
    "$CLAUDE_HOOKS_DIR/claude_hook_wrapper.sh" pre-task > /dev/null 2>&1 && \
        echo "   ✅ Hook wrapper executable" || \
        echo "   ⚠️ Hook wrapper execution issues"
fi

# Step 8: Create test script
echo "8️⃣ Creating test script..."
cat > "$PROJECT_ROOT/test_hooks.sh" << 'EOF'
#!/bin/bash
# Test Claude Code hooks

echo "🧪 Testing Claude Code Hooks"

# Test each hook phase
for phase in pre-task post-edit post-task; do
    echo ""
    echo "Testing $phase hook..."
    
    export CLAUDE_TASK_ID="test_$(date +%s)"
    export CLAUDE_AGENT_NAME="test_agent"
    
    if [ -f "$HOME/.claude/hooks/claude_hook_wrapper.sh" ]; then
        "$HOME/.claude/hooks/claude_hook_wrapper.sh" "$phase"
    else
        echo "Hook wrapper not found"
    fi
done

echo ""
echo "✅ Hook test complete"
EOF
chmod +x "$PROJECT_ROOT/test_hooks.sh"

# Final summary
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Claude Code Hooks Integration Setup Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📍 Important Locations:"
echo "   • Project root: $PROJECT_ROOT"
echo "   • Hooks directory: $CLAUDE_HOOKS_DIR"
echo "   • Config directory: $CLAUDE_CONFIG_DIR"
echo "   • Registry file: $CLAUDE_CONFIG_DIR/project-agents.json"
echo ""
echo "🔧 Usage in Claude Code:"
echo "   /hooks enable       - Enable all hooks"
echo "   /hooks disable      - Disable all hooks"
echo "   /hooks list         - List registered hooks"
echo "   /hooks test <phase> - Test specific hook phase"
echo ""
echo "📝 Hook Phases:"
echo "   • pre-task   - Validates and prepares for task execution"
echo "   • post-edit  - Processes file changes after edits"
echo "   • post-task  - Cleanup and reporting after task completion"
echo ""
echo "🧪 To test the integration:"
echo "   bash $PROJECT_ROOT/test_hooks.sh"
echo ""

# Check for any warnings
if [ ! -f "$AGENTS_DIR/claude_code_hook_adapter.py" ]; then
    echo "⚠️ WARNING: Python adapter not found"
    echo "   Please ensure claude_code_hook_adapter.py is in:"
    echo "   $AGENTS_DIR/"
    echo ""
fi

echo "🎉 Setup complete! The hooks will now automatically integrate with Claude Code."
