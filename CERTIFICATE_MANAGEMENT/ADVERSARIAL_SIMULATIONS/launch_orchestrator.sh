#!/bin/bash

# 🚀 ADVERSARIAL SIMULATION FRAMEWORK - MASTER ORCHESTRATOR
# Advanced launch and management system with scenario execution

set -e

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║   ADVERSARIAL SIMULATION FRAMEWORK - MASTER ORCHESTRATOR     ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║   ██████╗ ██████╗  ██████╗██╗  ██╗███████╗███████╗████████╗ ║
    ║  ██╔═══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔════╝╚══██╔══╝ ║
    ║  ██║   ██║██████╔╝██║     ███████║█████╗  ███████╗   ██║    ║
    ║  ██║   ██║██╔══██╗██║     ██╔══██║██╔══╝  ╚════██║   ██║    ║
    ║  ╚██████╔╝██║  ██║╚██████╗██║  ██║███████╗███████║   ██║    ║
    ║   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝    ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/pids"
CONFIG_DIR="$SCRIPT_DIR/config"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
METRICS_DIR="$SCRIPT_DIR/metrics"

# Create necessary directories
mkdir -p "$LOG_DIR" "$PID_DIR" "$CONFIG_DIR" "$SCENARIOS_DIR" "$METRICS_DIR"

# Log file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MAIN_LOG="$LOG_DIR/orchestrator_${TIMESTAMP}.log"

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAIN_LOG"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    log "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
    log "INFO: $1"
}

# Check system requirements
check_system() {
    echo -e "${CYAN}═══ System Requirements Check ═══${NC}"
    
    local all_good=true
    
    # Check CPU
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 4 ]; then
        print_warning "CPU cores: $cpu_cores (minimum 4 recommended)"
        all_good=false
    else
        print_status "CPU cores: $cpu_cores"
    fi
    
    # Check memory
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 8 ]; then
        print_warning "Memory: ${total_mem}GB (minimum 8GB recommended)"
        all_good=false
    else
        print_status "Memory: ${total_mem}GB"
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        python_version=$(python3 --version | cut -d' ' -f2)
        print_status "Python: $python_version"
    else
        print_error "Python 3 not found"
        all_good=false
    fi
    
    # Check GCC
    if command -v gcc &> /dev/null; then
        gcc_version=$(gcc --version | head -1)
        print_status "GCC: Found"
    else
        print_error "GCC not found"
        all_good=false
    fi
    
    # Check network ports
    for port in 4242 4243 5000 5555 5556; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port already in use"
        else
            print_status "Port $port available"
        fi
    done
    
    if [ "$all_good" = false ]; then
        print_warning "Some requirements not met, but continuing..."
    else
        print_status "All system requirements met"
    fi
    
    echo ""
}

# Install dependencies
install_deps() {
    print_info "Installing Python dependencies..."
    
    if [ ! -f "$SCRIPT_DIR/requirements.txt" ]; then
        cat > "$SCRIPT_DIR/requirements.txt" << EOF
asyncio
numpy>=1.20.0
networkx>=2.6
pyyaml>=5.4
flask>=2.0.0
flask-socketio>=5.0.0
plotly>=5.0.0
psutil>=5.8.0
pyzmq>=22.0.0
numba>=0.54.0
aiofiles>=0.8.0
redis>=4.0.0
EOF
    fi
    
    pip3 install -q -r "$SCRIPT_DIR/requirements.txt" >> "$MAIN_LOG" 2>&1
    
    if [ $? -eq 0 ]; then
        print_status "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        return 1
    fi
}

# Build C components
build_c_bridge() {
    print_info "Building C bridge..."
    
    cd "$SCRIPT_DIR/INTEGRATION"
    
    # Clean and build
    make clean >> "$MAIN_LOG" 2>&1
    make all >> "$MAIN_LOG" 2>&1
    
    if [ -f "simulation_c_bridge" ]; then
        print_status "C bridge built successfully"
        chmod +x simulation_c_bridge
    else
        print_error "C bridge build failed"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Service management functions
start_service() {
    local service_name=$1
    local command=$2
    local pid_file="$PID_DIR/${service_name}.pid"
    local log_file="$LOG_DIR/${service_name}_${TIMESTAMP}.log"
    
    # Kill existing process if running
    if [ -f "$pid_file" ]; then
        old_pid=$(cat "$pid_file")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            print_warning "Stopping existing $service_name (PID: $old_pid)"
            kill -TERM "$old_pid" 2>/dev/null || true
            sleep 2
            kill -9 "$old_pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    fi
    
    # Start new process
    print_info "Starting $service_name..."
    
    # Execute command with proper environment
    export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"
    
    eval "$command" > "$log_file" 2>&1 &
    local new_pid=$!
    echo $new_pid > "$pid_file"
    
    # Wait and verify
    sleep 3
    
    if ps -p "$new_pid" > /dev/null; then
        print_status "$service_name started (PID: $new_pid)"
        return 0
    else
        print_error "$service_name failed to start"
        print_info "Check log: $log_file"
        return 1
    fi
}

# Start all core services
start_core_services() {
    echo -e "${CYAN}═══ Starting Core Services ═══${NC}"
    
    # Start C bridge
    start_service "c_bridge" "cd $SCRIPT_DIR/INTEGRATION && ./simulation_c_bridge"
    
    # Start Python bridge
    start_service "python_bridge" "cd $SCRIPT_DIR/INTEGRATION && python3 agent_bridge.py"
    
    # Start orchestrator
    start_service "orchestrator" "cd $SCRIPT_DIR/ORCHESTRATOR && python3 simulation_orchestrator.py"
    
    # Start visualization
    start_service "visualization" "cd $SCRIPT_DIR/VISUALIZATION && python3 realtime_visualization.py"
    
    # Start performance monitor
    start_service "performance" "cd $SCRIPT_DIR/PERFORMANCE && python3 -c 'from optimizer import PerformanceMonitor; import asyncio; m = PerformanceMonitor(); asyncio.run(m.start_monitoring())'"
    
    echo ""
}

# Health check
health_check() {
    echo -e "${CYAN}═══ Health Check ═══${NC}"
    
    local all_healthy=true
    
    # Check each service
    for service in c_bridge python_bridge orchestrator visualization; do
        local pid_file="$PID_DIR/${service}.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null; then
                # Get CPU and memory usage
                local stats=$(ps -p "$pid" -o %cpu,%mem,etime --no-headers)
                print_status "$service: Running (PID: $pid) - $stats"
            else
                print_error "$service: Not running"
                all_healthy=false
            fi
        else
            print_error "$service: No PID file"
            all_healthy=false
        fi
    done
    
    # Check ports
    echo -e "\n${BLUE}Port Status:${NC}"
    for port in 4242 5000 5555 5556; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_status "Port $port: Listening"
        else
            print_warning "Port $port: Not listening"
        fi
    done
    
    # Check logs for errors
    echo -e "\n${BLUE}Recent Errors:${NC}"
    local error_count=$(grep -i "error\|exception\|failed" "$LOG_DIR"/*_${TIMESTAMP}.log 2>/dev/null | wc -l)
    if [ "$error_count" -gt 0 ]; then
        print_warning "Found $error_count errors in logs"
    else
        print_status "No errors detected"
    fi
    
    echo ""
    
    if [ "$all_healthy" = true ]; then
        print_status "All services healthy"
        return 0
    else
        print_error "Some services unhealthy"
        return 1
    fi
}

# Execute scenario
execute_scenario() {
    local scenario=$1
    
    echo -e "${CYAN}═══ Executing Scenario: $scenario ═══${NC}"
    
    # Create scenario execution script
    cat > "$SCENARIOS_DIR/execute_${scenario}.py" << EOF
#!/usr/bin/env python3
import asyncio
import sys
import os
sys.path.insert(0, '$SCRIPT_DIR')

from ORCHESTRATOR.simulation_orchestrator import SimulationOrchestrator

async def run_scenario():
    orchestrator = SimulationOrchestrator()
    
    # Load scenario
    scenario_file = '$SCENARIOS_DIR/${scenario}.yaml'
    if not os.path.exists(scenario_file):
        print(f"Scenario file not found: {scenario_file}")
        return False
    
    scenario = await orchestrator.load_scenario(scenario_file)
    print(f"Loaded scenario: {scenario.name}")
    
    # Execute
    print("Executing scenario...")
    result = await orchestrator.execute_scenario(scenario.id)
    
    # Report results
    print(f"\\nScenario completed!")
    print(f"Progress: {result.progress_percentage}%")
    print(f"Compromised systems: {len(result.compromised_systems)}")
    print(f"Failures: {len(result.failure_points)}")
    
    return len(result.failure_points) == 0

if __name__ == "__main__":
    success = asyncio.run(run_scenario())
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$SCENARIOS_DIR/execute_${scenario}.py"
    
    # Execute the scenario
    python3 "$SCENARIOS_DIR/execute_${scenario}.py"
    
    if [ $? -eq 0 ]; then
        print_status "Scenario executed successfully"
    else
        print_error "Scenario execution failed"
    fi
}

# Create sample scenarios
create_sample_scenarios() {
    print_info "Creating sample scenarios..."
    
    # Beijing Smart City scenario
    cat > "$SCENARIOS_DIR/beijing_smart_city.yaml" << EOF
name: "Beijing Smart City Infrastructure Attack"
description: "Comprehensive attack on Beijing's smart city systems"
complexity: ADVANCED
duration_hours: 72
actors:
  - "APT-Dragon"
  - "State Actor"
target_certificates:
  - "*.beijing.gov.cn"
  - "*.bjca.org.cn"
  - "*.bj.cegn.cn"
phases:
  - RECONNAISSANCE
  - INITIAL_ACCESS
  - EXECUTION
  - PERSISTENCE
  - PRIVILEGE_ESCALATION
  - DEFENSE_EVASION
  - CREDENTIAL_ACCESS
  - DISCOVERY
  - LATERAL_MOVEMENT
  - COLLECTION
  - COMMAND_CONTROL
  - EXFILTRATION
  - IMPACT
objectives:
  - "Compromise municipal infrastructure"
  - "Control traffic management systems"
  - "Access citizen databases"
  - "Disrupt emergency services"
success_criteria:
  systems_compromised: 100
  time_limit: 259200
  detection_rate: 0.1
metadata:
  impact_actions:
    - "service_disruption"
    - "data_exfiltration"
  stop_on_failure: false
  target_network: "10.0.0.0/8"
EOF
    
    # Financial attack scenario
    cat > "$SCENARIOS_DIR/financial_storm.yaml" << EOF
name: "Operation Yuan Storm"
description: "Global financial system disruption via certificate compromise"
complexity: EXPERT
duration_hours: 168
actors:
  - "FinancialAPT"
  - "Insider Threat"
target_certificates:
  - "*.swift.com"
  - "*.cfca.com.cn"
  - "*.pbccrc.org.cn"
phases:
  - RECONNAISSANCE
  - INITIAL_ACCESS
  - PERSISTENCE
  - CREDENTIAL_ACCESS
  - LATERAL_MOVEMENT
  - COLLECTION
  - EXFILTRATION
  - IMPACT
objectives:
  - "Compromise SWIFT network"
  - "Manipulate exchange rates"
  - "Steal financial data"
  - "Disrupt trading systems"
success_criteria:
  systems_compromised: 50
  time_limit: 604800
  detection_rate: 0.05
metadata:
  impact_actions:
    - "data_exfiltration"
    - "ransomware"
  stop_on_failure: true
  target_network: "172.16.0.0/12"
EOF
    
    print_status "Sample scenarios created"
}

# Monitor mode
monitor_mode() {
    echo -e "${CYAN}═══ Monitoring Mode ═══${NC}"
    print_info "Press Ctrl+C to exit monitoring"
    
    while true; do
        clear
        show_banner
        
        # System stats
        echo -e "${YELLOW}System Statistics:${NC}"
        echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo "Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
        echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""
        
        # Service status
        echo -e "${YELLOW}Service Status:${NC}"
        for service in c_bridge python_bridge orchestrator visualization; do
            local pid_file="$PID_DIR/${service}.pid"
            if [ -f "$pid_file" ] && ps -p $(cat "$pid_file") > /dev/null 2>&1; then
                echo -e "${GREEN}●${NC} $service: Running"
            else
                echo -e "${RED}●${NC} $service: Stopped"
            fi
        done
        echo ""
        
        # Recent logs
        echo -e "${YELLOW}Recent Activity:${NC}"
        tail -5 "$LOG_DIR"/*_${TIMESTAMP}.log 2>/dev/null | grep -v "^==>" | head -10
        
        sleep 5
    done
}

# Stop all services
stop_all() {
    echo -e "${CYAN}═══ Stopping All Services ═══${NC}"
    
    for service in c_bridge python_bridge orchestrator visualization performance; do
        local pid_file="$PID_DIR/${service}.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                print_info "Stopping $service (PID: $pid)"
                kill -TERM "$pid" 2>/dev/null || true
                sleep 1
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Kill any stragglers
    pkill -f simulation_c_bridge 2>/dev/null || true
    pkill -f agent_bridge.py 2>/dev/null || true
    pkill -f simulation_orchestrator.py 2>/dev/null || true
    pkill -f realtime_visualization.py 2>/dev/null || true
    
    print_status "All services stopped"
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        show_banner
        
        echo -e "${CYAN}═══ Main Menu ═══${NC}"
        echo "1) Start All Services"
        echo "2) Stop All Services"
        echo "3) Restart Services"
        echo "4) Health Check"
        echo "5) Execute Scenario"
        echo "6) Monitor Mode"
        echo "7) View Logs"
        echo "8) Clean Logs"
        echo "9) Exit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                check_system
                install_deps
                build_c_bridge
                start_core_services
                health_check
                echo -e "\n${GREEN}Dashboard available at: http://localhost:5000${NC}"
                read -p "Press Enter to continue..."
                ;;
            2)
                stop_all
                read -p "Press Enter to continue..."
                ;;
            3)
                stop_all
                sleep 2
                start_core_services
                health_check
                read -p "Press Enter to continue..."
                ;;
            4)
                health_check
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Available scenarios:"
                echo "1) beijing_smart_city"
                echo "2) financial_storm"
                read -p "Select scenario: " scenario_choice
                case $scenario_choice in
                    1) execute_scenario "beijing_smart_city" ;;
                    2) execute_scenario "financial_storm" ;;
                    *) print_error "Invalid scenario" ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            6)
                monitor_mode
                ;;
            7)
                echo "Recent logs:"
                ls -lt "$LOG_DIR"/*.log 2>/dev/null | head -10
                read -p "Enter log file to view (or Enter to skip): " logfile
                if [ -n "$logfile" ]; then
                    less "$LOG_DIR/$logfile"
                fi
                ;;
            8)
                read -p "Delete all logs? (y/N): " confirm
                if [ "$confirm" = "y" ]; then
                    rm -f "$LOG_DIR"/*.log
                    print_status "Logs cleaned"
                fi
                read -p "Press Enter to continue..."
                ;;
            9)
                echo "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Command line interface
case "${1:-}" in
    start)
        show_banner
        check_system
        install_deps
        build_c_bridge
        start_core_services
        health_check
        echo -e "\n${GREEN}Dashboard: http://localhost:5000${NC}"
        ;;
    stop)
        show_banner
        stop_all
        ;;
    restart)
        show_banner
        stop_all
        sleep 2
        start_core_services
        health_check
        ;;
    status)
        show_banner
        health_check
        ;;
    monitor)
        monitor_mode
        ;;
    scenario)
        if [ -z "$2" ]; then
            echo "Usage: $0 scenario <scenario_name>"
            echo "Available: beijing_smart_city, financial_storm"
            exit 1
        fi
        show_banner
        create_sample_scenarios
        execute_scenario "$2"
        ;;
    menu|interactive)
        interactive_menu
        ;;
    quick)
        # Quick start without checks
        show_banner
        print_info "Quick start mode - skipping checks"
        start_core_services
        echo -e "\n${GREEN}Dashboard: http://localhost:5000${NC}"
        ;;
    help|--help|-h)
        show_banner
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  start       - Start all services with full checks"
        echo "  stop        - Stop all services"
        echo "  restart     - Restart all services"
        echo "  status      - Show health status"
        echo "  monitor     - Enter monitoring mode"
        echo "  scenario    - Execute a scenario"
        echo "  menu        - Interactive menu (default)"
        echo "  quick       - Quick start without checks"
        echo "  help        - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 start                     # Start everything"
        echo "  $0 scenario beijing_smart_city  # Run scenario"
        echo "  $0 menu                      # Interactive mode"
        ;;
    *)
        interactive_menu
        ;;
esac