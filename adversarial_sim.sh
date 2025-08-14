#!/bin/bash

# 🎯 ADVERSARIAL SIMULATION - MASTER CONTROL
# Central control script for the simulation framework

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SIM_DIR="/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS"

# Header
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════╗"
echo "║  ADVERSARIAL SIMULATION MASTER CONTROL    ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Ensure simulation directory exists
if [ ! -d "$SIM_DIR" ]; then
    echo -e "${RED}Error: Simulation directory not found!${NC}"
    echo "Expected: $SIM_DIR"
    exit 1
fi

# Main command routing
case "${1:-help}" in
    # === QUICK COMMANDS ===
    go|start|run)
        echo -e "${GREEN}▶ Starting Simulation Framework${NC}"
        "$SIM_DIR/quick_launch.sh" start
        ;;
    
    stop|kill|halt)
        echo -e "${RED}■ Stopping Simulation Framework${NC}"
        "$SIM_DIR/quick_launch.sh" stop
        ;;
    
    restart|reload)
        echo -e "${YELLOW}⟲ Restarting Simulation Framework${NC}"
        "$SIM_DIR/quick_launch.sh" restart
        ;;
    
    status|check)
        echo -e "${BLUE}ℹ System Status${NC}"
        "$SIM_DIR/quick_launch.sh" status
        ;;
    
    # === ADVANCED COMMANDS ===
    orchestrate|orch)
        echo -e "${CYAN}🎯 Launching Advanced Orchestrator${NC}"
        "$SIM_DIR/launch_orchestrator.sh" menu
        ;;
    
    build)
        echo -e "${YELLOW}🔨 Building Framework${NC}"
        "$SIM_DIR/build_and_run.sh" --build-only
        ;;
    
    full)
        echo -e "${GREEN}🚀 Full Build & Launch${NC}"
        "$SIM_DIR/build_and_run.sh" --all
        ;;
    
    test)
        echo -e "${BLUE}🧪 Running Tests${NC}"
        cd "$SIM_DIR" && python3 test_simulation.py
        ;;
    
    dashboard|web|ui)
        echo -e "${CYAN}📊 Opening Dashboard${NC}"
        echo "URL: http://localhost:5000"
        if command -v xdg-open > /dev/null; then
            xdg-open http://localhost:5000
        elif command -v open > /dev/null; then
            open http://localhost:5000
        fi
        ;;
    
    # === SCENARIO EXECUTION ===
    beijing|smart-city)
        echo -e "${RED}🏙️ Executing Beijing Smart City Attack${NC}"
        "$SIM_DIR/launch_orchestrator.sh" scenario beijing_smart_city
        ;;
    
    financial|yuan)
        echo -e "${YELLOW}💰 Executing Financial Storm Attack${NC}"
        "$SIM_DIR/launch_orchestrator.sh" scenario financial_storm
        ;;
    
    satellite|space)
        echo -e "${BLUE}🛰️ Executing Satellite Attack${NC}"
        echo "Scenario: STARFALL"
        cat "$SIM_DIR/11_SPACE_SATELLITE/satellite_certificate_attack.md" | head -20
        ;;
    
    # === MONITORING ===
    monitor|watch)
        echo -e "${CYAN}📡 Entering Monitor Mode${NC}"
        "$SIM_DIR/launch_orchestrator.sh" monitor
        ;;
    
    logs|log)
        echo -e "${YELLOW}📜 Recent Logs${NC}"
        tail -50 "$SIM_DIR"/logs/*.log 2>/dev/null | less
        ;;
    
    # === UTILITIES ===
    clean)
        echo -e "${YELLOW}🧹 Cleaning Framework${NC}"
        read -p "Delete all logs and build artifacts? (y/N): " confirm
        if [ "$confirm" = "y" ]; then
            rm -rf "$SIM_DIR"/logs/*
            rm -rf "$SIM_DIR"/pids/*
            rm -rf "$SIM_DIR"/build/*
            cd "$SIM_DIR/INTEGRATION" && make clean
            echo "Cleaned"
        fi
        ;;
    
    paths|files)
        echo -e "${BLUE}📁 Key File Paths${NC}"
        echo ""
        echo "Main Scripts:"
        echo "  $SIM_DIR/quick_launch.sh"
        echo "  $SIM_DIR/launch_orchestrator.sh"
        echo "  $SIM_DIR/build_and_run.sh"
        echo ""
        echo "Components:"
        echo "  $SIM_DIR/ORCHESTRATOR/simulation_orchestrator.py"
        echo "  $SIM_DIR/VISUALIZATION/realtime_visualization.py"
        echo "  $SIM_DIR/INTEGRATION/agent_bridge.py"
        echo "  $SIM_DIR/INTEGRATION/simulation_c_bridge"
        echo "  $SIM_DIR/PERFORMANCE/optimizer.py"
        echo ""
        echo "Scenarios:"
        echo "  $SIM_DIR/01_CHINESE_OPERATIONS/BJCA_Beijing_CA/smart_city_attack.md"
        echo "  $SIM_DIR/01_CHINESE_OPERATIONS/CFCA_Financial/yuan_storm_operation.md"
        echo "  $SIM_DIR/11_SPACE_SATELLITE/satellite_certificate_attack.md"
        ;;
    
    # === HELP ===
    help|--help|-h|*)
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo -e "${GREEN}Quick Commands:${NC}"
        echo "  go/start/run    - Start simulation framework"
        echo "  stop/kill       - Stop all services"
        echo "  restart         - Restart services"
        echo "  status          - Check status"
        echo ""
        echo -e "${CYAN}Advanced Commands:${NC}"
        echo "  orchestrate     - Launch interactive orchestrator"
        echo "  build           - Build components only"
        echo "  full            - Full build and launch"
        echo "  test            - Run system tests"
        echo "  dashboard       - Open web dashboard"
        echo ""
        echo -e "${RED}Scenarios:${NC}"
        echo "  beijing         - Beijing smart city attack"
        echo "  financial       - Financial system attack"
        echo "  satellite       - Satellite infrastructure attack"
        echo ""
        echo -e "${YELLOW}Monitoring:${NC}"
        echo "  monitor         - Real-time monitoring"
        echo "  logs            - View recent logs"
        echo ""
        echo -e "${BLUE}Utilities:${NC}"
        echo "  clean           - Clean build artifacts"
        echo "  paths           - Show file paths"
        echo "  help            - Show this help"
        echo ""
        echo -e "${GREEN}Examples:${NC}"
        echo "  $0 go           # Quick start"
        echo "  $0 orchestrate  # Interactive menu"
        echo "  $0 beijing      # Run Beijing scenario"
        echo "  $0 dashboard    # Open web UI"
        ;;
esac

echo ""