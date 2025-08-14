#!/bin/bash

# 🛡️ UNIFIED SECURITY SUITE
# Combined certificate management and adversarial simulation system

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Paths
CERT_DIR="/home/ubuntu/Documents/Claude/CERTIFICATE_MANAGEMENT"
SIM_DIR="/home/ubuntu/Documents/Claude/CERTIFICATE_MANAGEMENT/ADVERSARIAL_SIMULATIONS"

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════╗
    ║        UNIFIED SECURITY SUITE                ║
    ║   Certificate & Adversarial Management       ║
    ╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Main menu
main_menu() {
    while true; do
        clear
        show_banner
        
        echo -e "${YELLOW}═══ MAIN MENU ═══${NC}"
        echo ""
        echo -e "${BLUE}Certificate Management:${NC}"
        echo "  1) Certificate Analysis"
        echo "  2) View High-Risk Certs"
        echo "  3) Threat Assessment"
        echo ""
        echo -e "${RED}Adversarial Simulations:${NC}"
        echo "  4) Start Simulation Framework"
        echo "  5) Run Attack Scenario"
        echo "  6) View Dashboard"
        echo ""
        echo -e "${GREEN}Combined Operations:${NC}"
        echo "  7) Full Security Analysis"
        echo "  8) Certificate Attack Scenarios"
        echo "  9) Monitoring Mode"
        echo ""
        echo "  0) Exit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}Running Certificate Analysis...${NC}"
                "$CERT_DIR/cert_manager.sh" analyze
                read -p "Press Enter to continue..."
                ;;
            2)
                "$CERT_DIR/cert_manager.sh" high-risk
                read -p "Press Enter to continue..."
                ;;
            3)
                "$CERT_DIR/cert_manager.sh" threat
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${RED}Starting Adversarial Simulation Framework...${NC}"
                "$SIM_DIR/quick_launch.sh" start
                read -p "Press Enter to continue..."
                ;;
            5)
                scenario_menu
                ;;
            6)
                echo -e "${CYAN}Opening Dashboard...${NC}"
                echo "URL: http://localhost:5000"
                if command -v xdg-open > /dev/null; then
                    xdg-open http://localhost:5000
                fi
                read -p "Press Enter to continue..."
                ;;
            7)
                full_analysis
                ;;
            8)
                cert_attack_scenarios
                ;;
            9)
                monitoring_mode
                ;;
            0)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Scenario menu
scenario_menu() {
    echo -e "${MAGENTA}═══ ATTACK SCENARIOS ═══${NC}"
    echo "1) Beijing Smart City (Certificate-based)"
    echo "2) Financial System Attack (CFCA)"
    echo "3) Satellite Infrastructure"
    echo "4) Custom Scenario"
    echo ""
    read -p "Select scenario: " choice
    
    case $choice in
        1)
            echo -e "${RED}Executing Beijing Smart City Attack...${NC}"
            cd "$SIM_DIR"
            ./launch_orchestrator.sh scenario beijing_smart_city
            ;;
        2)
            echo -e "${YELLOW}Executing Financial Storm...${NC}"
            cd "$SIM_DIR"
            ./launch_orchestrator.sh scenario financial_storm
            ;;
        3)
            echo -e "${BLUE}Satellite Attack Scenario${NC}"
            cat "$CERT_DIR/scenarios/satellite_certificate_attack.md" | head -50
            ;;
        4)
            echo "Custom scenario execution not yet implemented"
            ;;
    esac
    read -p "Press Enter to continue..."
}

# Full security analysis
full_analysis() {
    echo -e "${GREEN}═══ FULL SECURITY ANALYSIS ═══${NC}"
    
    echo -e "\n${YELLOW}[1/4] Analyzing Certificates...${NC}"
    "$CERT_DIR/scripts/analyze_all.sh"
    
    echo -e "\n${YELLOW}[2/4] Identifying Attack Vectors...${NC}"
    "$CERT_DIR/cert_manager.sh" threat
    
    echo -e "\n${YELLOW}[3/4] Checking Simulation Framework...${NC}"
    "$SIM_DIR/quick_launch.sh" status
    
    echo -e "\n${YELLOW}[4/4] Generating Combined Report...${NC}"
    generate_combined_report
    
    read -p "Press Enter to continue..."
}

# Certificate attack scenarios
cert_attack_scenarios() {
    echo -e "${RED}═══ CERTIFICATE-BASED ATTACK SCENARIOS ═══${NC}"
    
    echo "Available scenarios:"
    echo "1) Nation-State CA Compromise"
    echo "2) Financial Certificate Manipulation"
    echo "3) Infrastructure Certificate Hijacking"
    echo "4) Wildcard Certificate Abuse"
    echo ""
    
    read -p "Select scenario type: " choice
    
    case $choice in
        1)
            echo -e "${RED}Nation-State CA Scenarios:${NC}"
            ls -la "$CERT_DIR/scenarios/"*Beijing* 2>/dev/null
            ls -la "$CERT_DIR/scenarios/"*CFCA* 2>/dev/null
            ;;
        2)
            echo -e "${YELLOW}Financial Certificate Attacks:${NC}"
            cat "$CERT_DIR/scenarios/CFCA_Financial/yuan_storm_operation.md" | head -30
            ;;
        3)
            echo -e "${BLUE}Infrastructure Attacks:${NC}"
            cat "$CERT_DIR/scenarios/satellite_certificate_attack.md" | head -30
            ;;
        4)
            echo "Wildcard certificate abuse analysis..."
            grep -i "wildcard" "$CERT_DIR/data/certs.txt" | head -10
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Monitoring mode
monitoring_mode() {
    echo -e "${CYAN}═══ SECURITY MONITORING MODE ═══${NC}"
    echo "Press Ctrl+C to exit"
    
    while true; do
        clear
        show_banner
        
        echo -e "${YELLOW}Certificate Status:${NC}"
        if [ -f "$CERT_DIR/data/certs.txt" ]; then
            echo "Total Certificates: $(grep -c "Certificate:" "$CERT_DIR/data/certs.txt")"
        fi
        
        echo -e "\n${YELLOW}Simulation Status:${NC}"
        "$SIM_DIR/quick_launch.sh" status 2>/dev/null | grep -E "running|stopped"
        
        echo -e "\n${YELLOW}High-Risk Detections:${NC}"
        if [ -f "$CERT_DIR/analysis/latest/high_risk.txt" ]; then
            head -5 "$CERT_DIR/analysis/latest/high_risk.txt"
        fi
        
        echo -e "\n${YELLOW}System Resources:${NC}"
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo "Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
        
        sleep 5
    done
}

# Generate combined report
generate_combined_report() {
    local report_file="/tmp/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
UNIFIED SECURITY ANALYSIS REPORT
Generated: $(date)
=====================================

CERTIFICATE ANALYSIS:
$(if [ -f "$CERT_DIR/analysis/latest/summary.txt" ]; then cat "$CERT_DIR/analysis/latest/summary.txt"; fi)

HIGH-RISK CERTIFICATES:
$(if [ -f "$CERT_DIR/analysis/latest/high_risk.txt" ]; then head -20 "$CERT_DIR/analysis/latest/high_risk.txt"; fi)

SIMULATION FRAMEWORK STATUS:
$("$SIM_DIR/quick_launch.sh" status 2>/dev/null || echo "Not running")

AVAILABLE ATTACK SCENARIOS:
- Beijing Smart City (BJCA)
- Financial Storm (CFCA)
- Satellite Infrastructure
- IoT Botnet Assembly
- Blockchain Bridge Exploits

RECOMMENDATIONS:
1. Review high-risk certificates immediately
2. Monitor nation-state CA activities
3. Run regular attack simulations
4. Update certificate pinning policies
5. Implement CT log monitoring
EOF
    
    echo -e "${GREEN}Report saved to: $report_file${NC}"
}

# Command line interface
case "${1:-menu}" in
    cert|certificate)
        "$CERT_DIR/cert_manager.sh" "${@:2}"
        ;;
    sim|simulation)
        cd "$SIM_DIR"
        ./quick_launch.sh "${@:2}"
        ;;
    analyze)
        full_analysis
        ;;
    monitor)
        monitoring_mode
        ;;
    menu)
        main_menu
        ;;
    help|--help|-h)
        show_banner
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  cert [args]    - Certificate management"
        echo "  sim [args]     - Simulation control"
        echo "  analyze        - Full security analysis"
        echo "  monitor        - Monitoring mode"
        echo "  menu           - Interactive menu (default)"
        echo "  help           - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 cert analyze            # Analyze certificates"
        echo "  $0 sim start               # Start simulations"
        echo "  $0 analyze                 # Full analysis"
        echo ""
        echo "Paths:"
        echo "  Certificates: $CERT_DIR"
        echo "  Simulations:  $SIM_DIR"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use '$0 help' for usage"
        exit 1
        ;;
esac