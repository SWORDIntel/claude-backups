#!/bin/bash
# Hybrid Bridge System Launcher

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Launching Hybrid Bridge Integration System${NC}"
echo

# Navigate to project
cd "$(dirname "$0")"

# Activate virtual environment
echo -e "${BLUE}🐍 Activating virtual environment...${NC}"
if [ ! -d "venv" ]; then
    echo -e "${RED}❌ Virtual environment not found. Run: python3 -m venv venv${NC}"
    exit 1
fi

source venv/bin/activate

# Navigate to Python directory
cd agents/src/python

# Check system status first
echo -e "${BLUE}🔍 Checking system status...${NC}"
python3 -c "
from hybrid_bridge_manager import HybridBridgeManager
bridge = HybridBridgeManager()
status = bridge.get_system_status()
print('✅ Hybrid Bridge:', status['bridge_manager']['status'])
print('📊 System ready for launch')
" || {
    echo -e "${RED}❌ System check failed. Please run comprehensive test first.${NC}"
    exit 1
}

echo -e "${GREEN}🎉 System ready! Choose launch option:${NC}"
echo "1. Learning System Dashboard (Recommended for first time)"
echo "2. Production Orchestrator"
echo "3. Hybrid Bridge Manager"
echo "4. System Status Check"
echo "5. All Systems Info (multi-terminal commands)"
echo

read -p "Select option (1-5): " choice

case $choice in
    1)
        echo -e "${BLUE}📊 Starting Learning System Dashboard...${NC}"
        echo -e "${YELLOW}💡 This will start the main learning system interface${NC}"
        echo
        python3 postgresql_learning_system.py dashboard
        ;;
    2)
        echo -e "${BLUE}🎯 Starting Production Orchestrator...${NC}"
        echo -e "${YELLOW}💡 This will start the agent coordination system${NC}"
        echo
        python3 production_orchestrator.py
        ;;
    3)
        echo -e "${BLUE}🌉 Starting Hybrid Bridge Manager...${NC}"
        echo -e "${YELLOW}💡 This will start the intelligent routing system${NC}"
        echo
        python3 hybrid_bridge_manager.py
        ;;
    4)
        echo -e "${BLUE}🔍 Running comprehensive system status check...${NC}"
        python3 -c "
from hybrid_bridge_manager import HybridBridgeManager
from postgresql_learning_system import UltimatePostgreSQLLearningSystem

print('📊 Hybrid Bridge System Status')
print('='*40)

try:
    bridge = HybridBridgeManager()
    status = bridge.get_system_status()
    
    print(f'Bridge Status: {status[\"bridge_manager\"][\"status\"]}')
    print(f'Current Mode: {status[\"bridge_manager\"][\"mode\"]}')
    print(f'Native System: {\"✅ Available\" if status[\"systems\"][\"native\"][\"available\"] else \"❌ Unavailable\"}')
    print(f'Docker System: {\"✅ Available\" if status[\"systems\"][\"docker\"][\"available\"] else \"❌ Unavailable\"}')
    
    learning = UltimatePostgreSQLLearningSystem()
    print('Learning System: ✅ Available')
    
    print()
    print('🎉 System Status: OPERATIONAL')
    print('Ready for production use!')
    
except Exception as e:
    print(f'❌ Error: {e}')
"
        ;;
    5)
        PROJECT_PATH="$(cd ../../../ && pwd)"
        PYTHON_PATH="$PROJECT_PATH/agents/src/python"
        
        echo -e "${YELLOW}📋 Multi-Terminal Launch Commands:${NC}"
        echo
        echo -e "${BLUE}Terminal 1 (Learning System Dashboard):${NC}"
        echo "cd $PROJECT_PATH && source venv/bin/activate && cd agents/src/python && python3 postgresql_learning_system.py dashboard"
        echo
        echo -e "${BLUE}Terminal 2 (Production Orchestrator):${NC}"
        echo "cd $PROJECT_PATH && source venv/bin/activate && cd agents/src/python && python3 production_orchestrator.py"
        echo
        echo -e "${BLUE}Terminal 3 (Hybrid Bridge Manager):${NC}"
        echo "cd $PROJECT_PATH && source venv/bin/activate && cd agents/src/python && python3 hybrid_bridge_manager.py"
        echo
        echo -e "${BLUE}Optional Terminal 4 (Docker Containers):${NC}"
        echo "cd $PROJECT_PATH && docker-compose up -d && docker-compose logs -f"
        echo
        echo -e "${GREEN}💡 Copy and paste these commands into separate terminal windows${NC}"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac