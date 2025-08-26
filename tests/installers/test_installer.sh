#!/bin/bash
# Test script to verify installer components

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "         Claude Installer Component Test"
echo "═══════════════════════════════════════════════════════════════"
echo ""

PROJECT_ROOT="/home/ubuntu/Documents/Claude"
ERRORS=0
WARNINGS=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test function
test_component() {
    local name="$1"
    local path="$2"
    local type="${3:-file}"
    
    printf "Testing %-40s: " "$name"
    
    if [ "$type" = "file" ]; then
        if [ -f "$path" ]; then
            echo -e "${GREEN}✓ Found${NC}"
            return 0
        else
            echo -e "${RED}✗ Missing${NC}"
            ((ERRORS++))
            return 1
        fi
    elif [ "$type" = "dir" ]; then
        if [ -d "$path" ]; then
            echo -e "${GREEN}✓ Found${NC}"
            return 0
        else
            echo -e "${RED}✗ Missing${NC}"
            ((ERRORS++))
            return 1
        fi
    elif [ "$type" = "command" ]; then
        if command -v "$path" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Available${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Not installed${NC}"
            ((WARNINGS++))
            return 1
        fi
    fi
}

echo "1. Core Components"
echo "──────────────────"
test_component "Installer script" "$PROJECT_ROOT/installers/claude-installer.sh" "file"
test_component "Agents directory" "$PROJECT_ROOT/agents" "dir"
test_component "Database directory" "$PROJECT_ROOT/database" "dir"
test_component "Hooks directory" "$PROJECT_ROOT/hooks" "dir"
test_component "Scripts directory" "$PROJECT_ROOT/scripts" "dir"
echo ""

echo "2. Database System"
echo "──────────────────"
test_component "Database initializer" "$PROJECT_ROOT/database/initialize_complete_system.sh" "file"
test_component "Start script" "$PROJECT_ROOT/database/start_local_postgres.sh" "file"
test_component "Stop script" "$PROJECT_ROOT/database/stop_local_postgres.sh" "file"
test_component "Learning sync script" "$PROJECT_ROOT/database/scripts/learning_sync.sh" "file"
test_component "Auth schema" "$PROJECT_ROOT/database/sql/auth_db_setup.sql" "file"
test_component "Learning schema" "$PROJECT_ROOT/database/sql/learning_system_schema.sql" "file"
test_component "PostgreSQL" "psql" "command"
echo ""

echo "3. Learning System"
echo "──────────────────"
test_component "Learning setup" "$PROJECT_ROOT/agents/src/python/setup_learning_system.py" "file"
test_component "Learning system" "$PROJECT_ROOT/agents/src/python/postgresql_learning_system.py" "file"
test_component "Learning CLI" "$PROJECT_ROOT/agents/src/python/learning_cli.py" "file"
test_component "Orchestrator bridge" "$PROJECT_ROOT/agents/src/python/learning_orchestrator_bridge.py" "file"
test_component "Agent learning system" "$PROJECT_ROOT/agents/src/python/agent_learning_system.py" "file"
test_component "Python3" "python3" "command"
echo ""

echo "4. Orchestration System"
echo "──────────────────"
test_component "Production orchestrator" "$PROJECT_ROOT/agents/src/python/production_orchestrator.py" "file"
test_component "Agent registry" "$PROJECT_ROOT/agents/src/python/agent_registry.py" "file"
test_component "Tandem test" "$PROJECT_ROOT/agents/src/python/test_tandem_system.py" "file"
echo ""

echo "5. Hooks System"
echo "──────────────────"
test_component "Install hooks script" "$PROJECT_ROOT/hooks/install_claude_hooks.sh" "file"
test_component "Setup hooks script" "$PROJECT_ROOT/hooks/setup_claude_hooks.sh" "file"
test_component "Hooks bridge" "$PROJECT_ROOT/hooks/claude_hooks_bridge.py" "file"
echo ""

echo "6. Agent Files"
echo "──────────────────"
AGENT_COUNT=$(find "$PROJECT_ROOT/agents" -maxdepth 1 -name "*.md" 2>/dev/null | grep -v -E "Template|STANDARDIZED" | wc -l)
printf "Testing %-40s: " "Agent count"
if [ "$AGENT_COUNT" -ge 30 ]; then
    echo -e "${GREEN}✓ $AGENT_COUNT agents found${NC}"
else
    echo -e "${YELLOW}⚠ Only $AGENT_COUNT agents found${NC}"
    ((WARNINGS++))
fi
echo ""

echo "7. Required Commands"
echo "──────────────────"
test_component "Git" "git" "command"
test_component "Node.js" "node" "command"
test_component "npm" "npm" "command"
test_component "pip" "pip3" "command"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "Summary:"
echo "  Errors: $ERRORS"
echo "  Warnings: $WARNINGS"

if [ "$ERRORS" -eq 0 ]; then
    echo -e "  Status: ${GREEN}✓ Ready to install${NC}"
    echo ""
    echo "To install, run:"
    echo "  cd $PROJECT_ROOT"
    echo "  ./installers/claude-installer.sh"
else
    echo -e "  Status: ${RED}✗ Missing required components${NC}"
    echo ""
    echo "Please ensure all required files are present before installing."
fi
echo "═══════════════════════════════════════════════════════════════"