#!/bin/bash
# Hybrid Bridge Integration Test with Virtual Environment
# Automatically activates venv and runs comprehensive tests

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Hybrid Bridge Integration Test with Virtual Environment${NC}"
echo

# Navigate to project root
cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

echo -e "${BLUE}📁 Project Root: ${PROJECT_ROOT}${NC}"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}❌ Virtual environment not found at ${PROJECT_ROOT}/venv${NC}"
    echo -e "${YELLOW}💡 Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
echo -e "${BLUE}🐍 Activating virtual environment...${NC}"
source venv/bin/activate

# Verify activation
if [ "$VIRTUAL_ENV" != "" ]; then
    echo -e "${GREEN}✅ Virtual environment activated: ${VIRTUAL_ENV}${NC}"
else
    echo -e "${RED}❌ Failed to activate virtual environment${NC}"
    exit 1
fi

# Install/update requirements
echo -e "${BLUE}📦 Installing/updating requirements...${NC}"
if [ -f "requirements.txt" ]; then
    pip install -q -r requirements.txt
    echo -e "${GREEN}✅ Requirements installed${NC}"
else
    echo -e "${YELLOW}⚠️  No requirements.txt found, installing basic dependencies...${NC}"
    pip install -q asyncpg psycopg2-binary numpy pandas scikit-learn
fi

# Check Python path
echo -e "${BLUE}🐍 Python environment:${NC}"
echo -e "   Python: $(which python3)"
echo -e "   Pip: $(which pip)"
echo -e "   Virtual Env: ${VIRTUAL_ENV}"

# Navigate to Python source directory  
cd agents/src/python

# Run comprehensive test
echo -e "${BLUE}🧪 Running comprehensive integration test...${NC}"
echo

if python3 comprehensive_integration_test.py "$@"; then
    echo
    echo -e "${GREEN}🎉 Test completed successfully!${NC}"
    exit_code=0
else
    echo
    echo -e "${YELLOW}⚠️  Test completed with issues${NC}"
    exit_code=$?
fi

# Deactivate virtual environment
deactivate

echo -e "${BLUE}📋 Test Summary:${NC}"
echo -e "   Project: Hybrid Bridge Integration"
echo -e "   Virtual Env: Used and deactivated"
echo -e "   Exit Code: ${exit_code}"

exit $exit_code