#!/bin/bash

# 🔐 CERTIFICATE MANAGER - Master Control Script
# Central management interface for certificate analysis

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Base directory
CERT_DIR="/home/ubuntu/Documents/Claude/CERTIFICATE_MANAGEMENT"

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔════════════════════════════════════════════╗
    ║     CERTIFICATE MANAGEMENT SYSTEM         ║
    ║         Security Analysis Suite           ║
    ╚════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Functions
analyze_certs() {
    echo -e "${BLUE}Running comprehensive certificate analysis...${NC}"
    "$CERT_DIR/scripts/analyze_all.sh"
}

view_high_risk() {
    echo -e "${RED}High-Risk Certificates:${NC}"
    if [ -f "$CERT_DIR/analysis/latest/high_risk.txt" ]; then
        cat "$CERT_DIR/analysis/latest/high_risk.txt"
    else
        echo "No analysis found. Run analysis first."
    fi
}

view_statistics() {
    echo -e "${YELLOW}Certificate Statistics:${NC}"
    if [ -f "$CERT_DIR/analysis/latest/summary.txt" ]; then
        cat "$CERT_DIR/analysis/latest/summary.txt"
    else
        echo "No statistics available. Run analysis first."
    fi
}

search_cert() {
    local pattern="$1"
    echo -e "${BLUE}Searching for: $pattern${NC}"
    grep -i "$pattern" "$CERT_DIR/data/certs.txt" | head -20
}

extract_cert() {
    local pattern="$1"
    local output="$2"
    echo -e "${BLUE}Extracting certificates matching: $pattern${NC}"
    
    # Extract certificate blocks
    awk "/Certificate:.*$pattern/,/-----END CERTIFICATE-----/" "$CERT_DIR/data/certs.txt" > "$output"
    
    if [ -s "$output" ]; then
        echo -e "${GREEN}Certificates extracted to: $output${NC}"
        echo "Found $(grep -c "Certificate:" "$output") matching certificates"
    else
        echo -e "${RED}No matching certificates found${NC}"
    fi
}

threat_assessment() {
    echo -e "${RED}═══ THREAT ASSESSMENT ═══${NC}"
    
    echo -e "\n${YELLOW}Nation-State Certificates:${NC}"
    grep -E "BJCA|CFCA|GDCA|vTrus|Crypto-Pro|Russian Trusted" "$CERT_DIR/data/certs.txt" | \
        grep "Subject:" | head -10
    
    echo -e "\n${YELLOW}Critical Infrastructure:${NC}"
    grep -iE "critical|nuclear|power|water|scada|industrial" "$CERT_DIR/data/certs.txt" | \
        grep "Subject:" | head -10
    
    echo -e "\n${YELLOW}Financial Systems:${NC}"
    grep -iE "bank|swift|financial|payment|trading" "$CERT_DIR/data/certs.txt" | \
        grep "Subject:" | head -10
    
    echo -e "\n${YELLOW}Government Systems:${NC}"
    grep -iE "\.gov|government|federal|state|military|\.mil" "$CERT_DIR/data/certs.txt" | \
        grep "Subject:" | head -10
}

monitor_mode() {
    echo -e "${CYAN}Entering Certificate Monitoring Mode${NC}"
    echo "Press Ctrl+C to exit"
    
    while true; do
        clear
        show_banner
        
        echo -e "${YELLOW}Certificate Database Status:${NC}"
        echo "Total Certificates: $(grep -c "Certificate:" "$CERT_DIR/data/certs.txt" 2>/dev/null || echo "0")"
        echo "Last Analysis: $(stat -c %y "$CERT_DIR/analysis/latest" 2>/dev/null || echo "Never")"
        echo ""
        
        echo -e "${RED}Recent High-Risk Detections:${NC}"
        if [ -f "$CERT_DIR/analysis/latest/high_risk.txt" ]; then
            head -10 "$CERT_DIR/analysis/latest/high_risk.txt"
        fi
        
        sleep 5
    done
}

scenario_menu() {
    echo -e "${MAGENTA}═══ ATTACK SCENARIOS ═══${NC}"
    echo "1) Beijing Smart City (BJCA)"
    echo "2) Financial Storm (CFCA)"
    echo "3) Satellite Infrastructure"
    echo "4) View All Scenarios"
    echo ""
    read -p "Select scenario: " choice
    
    case $choice in
        1)
            echo -e "${RED}Beijing Smart City Attack Scenario${NC}"
            cat "$CERT_DIR/scenarios/BJCA_Beijing_CA/smart_city_attack.md" | head -50
            ;;
        2)
            echo -e "${YELLOW}Financial Storm Scenario${NC}"
            cat "$CERT_DIR/scenarios/CFCA_Financial/yuan_storm_operation.md" | head -50
            ;;
        3)
            echo -e "${BLUE}Satellite Attack Scenario${NC}"
            cat "$CERT_DIR/scenarios/satellite_certificate_attack.md" | head -50
            ;;
        4)
            echo "Available scenarios:"
            ls -la "$CERT_DIR/scenarios/"
            ;;
    esac
}

# Interactive menu
interactive_menu() {
    while true; do
        show_banner
        
        echo -e "${CYAN}Main Menu:${NC}"
        echo "1) Run Full Analysis"
        echo "2) View High-Risk Certificates"
        echo "3) View Statistics"
        echo "4) Search Certificate"
        echo "5) Extract Certificates"
        echo "6) Threat Assessment"
        echo "7) Attack Scenarios"
        echo "8) Monitoring Mode"
        echo "9) Exit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                analyze_certs
                read -p "Press Enter to continue..."
                ;;
            2)
                view_high_risk
                read -p "Press Enter to continue..."
                ;;
            3)
                view_statistics
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Enter search pattern: " pattern
                search_cert "$pattern"
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Enter pattern to extract: " pattern
                read -p "Output file: " output
                extract_cert "$pattern" "$output"
                read -p "Press Enter to continue..."
                ;;
            6)
                threat_assessment
                read -p "Press Enter to continue..."
                ;;
            7)
                scenario_menu
                read -p "Press Enter to continue..."
                ;;
            8)
                monitor_mode
                ;;
            9)
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

# Main command routing
case "${1:-menu}" in
    analyze)
        show_banner
        analyze_certs
        ;;
    high-risk)
        show_banner
        view_high_risk
        ;;
    stats)
        show_banner
        view_statistics
        ;;
    search)
        show_banner
        search_cert "$2"
        ;;
    extract)
        show_banner
        extract_cert "$2" "$3"
        ;;
    threat)
        show_banner
        threat_assessment
        ;;
    monitor)
        monitor_mode
        ;;
    menu)
        interactive_menu
        ;;
    help|--help|-h)
        show_banner
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  analyze       - Run full certificate analysis"
        echo "  high-risk     - View high-risk certificates"
        echo "  stats         - View statistics"
        echo "  search PATTERN - Search for certificates"
        echo "  extract PATTERN OUTPUT - Extract matching certificates"
        echo "  threat        - Run threat assessment"
        echo "  monitor       - Enter monitoring mode"
        echo "  menu          - Interactive menu (default)"
        echo "  help          - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 analyze"
        echo "  $0 search '*.gov.cn'"
        echo "  $0 extract BJCA beijing_certs.txt"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac