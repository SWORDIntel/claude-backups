#!/bin/bash
# Tandem Orchestration System Launcher
# Complete startup and verification script for production use

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLAUDE_ROOT="${HOME}/Documents/claude-backups"
AGENTS_ROOT="${CLAUDE_ROOT}/agents"
PYTHON_SRC="${AGENTS_ROOT}/src/python"
export CLAUDE_AGENTS_ROOT="${AGENTS_ROOT}"
export PYTHONPATH="${PYTHON_SRC}:${PYTHONPATH}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Header
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        TANDEM ORCHESTRATION SYSTEM LAUNCHER v2.0          ║${NC}"
echo -e "${CYAN}║              41 Agents with Full Categories               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check environment
print_status "Checking environment..."

if [ ! -d "${AGENTS_ROOT}" ]; then
    print_error "Agents directory not found: ${AGENTS_ROOT}"
    exit 1
fi

if [ ! -d "${PYTHON_SRC}" ]; then
    print_error "Python source directory not found: ${PYTHON_SRC}"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | awk '{print $2}')
print_success "Python version: ${PYTHON_VERSION}"

# Check for required files
print_status "Verifying system files..."

REQUIRED_FILES=(
    "${PYTHON_SRC}/production_orchestrator.py"
    "${PYTHON_SRC}/agent_registry.py"
    "${PYTHON_SRC}/agent_dynamic_loader.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $(basename $file)"
    else
        print_error "Missing: $file"
        exit 1
    fi
done

# Initialize system
print_status "Initializing Tandem Orchestration System..."

cd "${PYTHON_SRC}"

# Run comprehensive system test
python3 - <<'EOF'
import sys
import os
import asyncio
import json
from pathlib import Path

sys.path.append('.')
os.environ['CLAUDE_AGENTS_ROOT'] = os.environ.get('CLAUDE_AGENTS_ROOT', '/home/ubuntu/Documents/claude-backups/agents')

from production_orchestrator import ProductionOrchestrator

# Try to import enhanced registry
try:
    from agent_registry import EnhancedAgentRegistry, get_enhanced_registry
    ENHANCED_AVAILABLE = True
except ImportError:
    from agent_registry import AgentRegistry
    ENHANCED_AVAILABLE = False

async def startup_system():
    """Initialize and verify the complete Tandem Orchestration System with Enhanced Registry"""
    
    print("\n📊 SYSTEM INITIALIZATION")
    print("=" * 60)
    
    if ENHANCED_AVAILABLE:
        print("🚀 Using Enhanced Agent Registry with Python Fallback")
    else:
        print("📦 Using standard Agent Registry")
    
    # Initialize orchestrator
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    
    # Get system status
    status = orchestrator.get_status()
    
    print(f"✅ System initialized: {status['initialized']}")
    print(f"📦 Agents discovered: {status['discovered_agents']}")
    print(f"⚡ C Layer: {'Available' if status['c_layer_available'] else 'Python-only mode'}")
    print(f"🖥️ CPU Cores: {status['hardware_topology']['total_cores']}")
    
    # Categorize agents
    print("\n🗂️ AGENT CATEGORIES")
    print("=" * 60)
    
    categories = {}
    for agent_name in orchestrator.list_available_agents():
        info = orchestrator.get_agent_info(agent_name)
        category = info['category']
        if category not in categories:
            categories[category] = []
        categories[category].append(agent_name)
    
    # Display by category
    for category in sorted(categories.keys()):
        agents = categories[category]
        print(f"\n{category} ({len(agents)} agents):")
        for i, agent in enumerate(sorted(agents)[:5]):
            print(f"  • {agent}")
        if len(agents) > 5:
            print(f"  ... and {len(agents) - 5} more")
    
    # Test basic functionality
    print("\n🧪 FUNCTIONALITY TESTS")
    print("=" * 60)
    
    tests_passed = 0
    tests_total = 5
    
    # Test 1: Agent discovery
    try:
        agents = orchestrator.list_available_agents()
        if len(agents) >= 40:
            print("✅ Test 1: Agent discovery - PASSED ({} agents)".format(len(agents)))
            tests_passed += 1
        else:
            print("❌ Test 1: Agent discovery - FAILED (only {} agents)".format(len(agents)))
    except Exception as e:
        print(f"❌ Test 1: Agent discovery - ERROR: {e}")
    
    # Test 2: Agent invocation
    try:
        result = await orchestrator.invoke_agent('director', 'status_check', {})
        print("✅ Test 2: Agent invocation - PASSED")
        tests_passed += 1
    except Exception as e:
        print(f"❌ Test 2: Agent invocation - ERROR: {e}")
    
    # Test 3: Category detection
    try:
        info = orchestrator.get_agent_info('security')
        if info['category'] == 'SECURITY':
            print("✅ Test 3: Category detection - PASSED")
            tests_passed += 1
        else:
            print(f"❌ Test 3: Category detection - FAILED (got {info['category']})")
    except Exception as e:
        print(f"❌ Test 3: Category detection - ERROR: {e}")
    
    # Test 4: Multi-agent workflow
    try:
        workflow = await orchestrator.execute_workflow([
            {'agent': 'architect', 'action': 'design'},
            {'agent': 'security', 'action': 'review'}
        ])
        if workflow.get('status') == 'completed':
            print("✅ Test 4: Multi-agent workflow - PASSED")
            tests_passed += 1
        else:
            print(f"❌ Test 4: Multi-agent workflow - FAILED ({workflow.get('status')})")
    except Exception as e:
        print(f"❌ Test 4: Multi-agent workflow - ERROR: {e}")
    
    # Test 5: System status
    try:
        status = orchestrator.get_status()
        if status['initialized'] and status['discovered_agents'] >= 40:
            print("✅ Test 5: System status - PASSED")
            tests_passed += 1
        else:
            print("❌ Test 5: System status - FAILED")
    except Exception as e:
        print(f"❌ Test 5: System status - ERROR: {e}")
    
    # Summary
    print("\n📈 TEST SUMMARY")
    print("=" * 60)
    print(f"Tests passed: {tests_passed}/{tests_total}")
    
    if tests_passed == tests_total:
        print("\n🎉 SYSTEM FULLY OPERATIONAL!")
        return True
    else:
        print(f"\n⚠️ SYSTEM PARTIALLY OPERATIONAL ({tests_passed}/{tests_total} tests passed)")
        return False

# Run the startup
try:
    result = asyncio.run(startup_system())
    if result:
        print("\n✅ Tandem Orchestration System: ONLINE")
        print("📖 All 41 agents ready for Task tool invocation")
        print("🔧 Example: Task(subagent_type='director', prompt='Create project plan')")
        sys.exit(0)
    else:
        print("\n⚠️ System started with warnings. Some features may not work correctly.")
        sys.exit(1)
except Exception as e:
    print(f"\n❌ CRITICAL ERROR: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           TANDEM ORCHESTRATION SYSTEM: ONLINE             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
else
    echo
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║         TANDEM ORCHESTRATION SYSTEM: FAILED TO START      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
fi

exit $EXIT_CODE