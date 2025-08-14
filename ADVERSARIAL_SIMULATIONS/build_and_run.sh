#!/bin/bash

# 🔨 ADVERSARIAL SIMULATION FRAMEWORK - BUILD & RUN
# Automated build and deployment script

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$SCRIPT_DIR/logs"
BUILD_DIR="$SCRIPT_DIR/build"
PID_DIR="$SCRIPT_DIR/pids"

# Create directories
mkdir -p "$LOG_DIR" "$BUILD_DIR" "$PID_DIR"

# Functions
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found"
        exit 1
    fi
    
    # Check GCC
    if ! command -v gcc &> /dev/null; then
        print_error "GCC not found"
        exit 1
    fi
    
    # Check make
    if ! command -v make &> /dev/null; then
        print_error "Make not found"
        exit 1
    fi
    
    print_status "Prerequisites checked"
}

install_dependencies() {
    echo "Installing dependencies..."
    
    # Create requirements.txt if not exists
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
EOF
    fi
    
    # Install Python packages
    pip3 install -q -r "$SCRIPT_DIR/requirements.txt" 2>&1 | tee "$LOG_DIR/pip_install.log"
    
    print_status "Dependencies installed"
}

build_c_components() {
    echo "Building C components..."
    
    cd "$SCRIPT_DIR/INTEGRATION"
    
    # Clean previous builds
    make clean > /dev/null 2>&1 || true
    
    # Build with optimizations
    CFLAGS="-O3 -march=native -mtune=native" make all 2>&1 | tee "$LOG_DIR/c_build.log"
    
    if [ -f "simulation_c_bridge" ]; then
        print_status "C bridge built successfully"
    else
        print_error "C bridge build failed"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

start_c_bridge() {
    echo "Starting C bridge..."
    
    cd "$SCRIPT_DIR/INTEGRATION"
    
    # Kill existing process if running
    if [ -f "$PID_DIR/c_bridge.pid" ]; then
        old_pid=$(cat "$PID_DIR/c_bridge.pid")
        kill -9 "$old_pid" 2>/dev/null || true
    fi
    
    # Start C bridge
    ./simulation_c_bridge > "$LOG_DIR/c_bridge.log" 2>&1 &
    echo $! > "$PID_DIR/c_bridge.pid"
    
    sleep 2
    
    # Check if running
    if ps -p $(cat "$PID_DIR/c_bridge.pid") > /dev/null; then
        print_status "C bridge started (PID: $(cat "$PID_DIR/c_bridge.pid"))"
    else
        print_error "C bridge failed to start"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

start_python_bridge() {
    echo "Starting Python bridge..."
    
    # Kill existing process if running
    if [ -f "$PID_DIR/python_bridge.pid" ]; then
        old_pid=$(cat "$PID_DIR/python_bridge.pid")
        kill -9 "$old_pid" 2>/dev/null || true
    fi
    
    # Start Python bridge
    cd "$SCRIPT_DIR/INTEGRATION"
    python3 agent_bridge.py > "$LOG_DIR/python_bridge.log" 2>&1 &
    echo $! > "$PID_DIR/python_bridge.pid"
    
    sleep 2
    
    if ps -p $(cat "$PID_DIR/python_bridge.pid") > /dev/null; then
        print_status "Python bridge started (PID: $(cat "$PID_DIR/python_bridge.pid"))"
    else
        print_error "Python bridge failed to start"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

start_orchestrator() {
    echo "Starting orchestrator..."
    
    # Kill existing process if running
    if [ -f "$PID_DIR/orchestrator.pid" ]; then
        old_pid=$(cat "$PID_DIR/orchestrator.pid")
        kill -9 "$old_pid" 2>/dev/null || true
    fi
    
    # Start orchestrator
    cd "$SCRIPT_DIR/ORCHESTRATOR"
    python3 simulation_orchestrator.py > "$LOG_DIR/orchestrator.log" 2>&1 &
    echo $! > "$PID_DIR/orchestrator.pid"
    
    sleep 2
    
    if ps -p $(cat "$PID_DIR/orchestrator.pid") > /dev/null; then
        print_status "Orchestrator started (PID: $(cat "$PID_DIR/orchestrator.pid"))"
    else
        print_error "Orchestrator failed to start"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

start_visualization() {
    echo "Starting visualization..."
    
    # Kill existing process if running
    if [ -f "$PID_DIR/visualization.pid" ]; then
        old_pid=$(cat "$PID_DIR/visualization.pid")
        kill -9 "$old_pid" 2>/dev/null || true
    fi
    
    # Ensure templates directory exists
    mkdir -p "$SCRIPT_DIR/VISUALIZATION/templates"
    
    # Start visualization
    cd "$SCRIPT_DIR/VISUALIZATION"
    python3 realtime_visualization.py > "$LOG_DIR/visualization.log" 2>&1 &
    echo $! > "$PID_DIR/visualization.pid"
    
    sleep 3
    
    if ps -p $(cat "$PID_DIR/visualization.pid") > /dev/null; then
        print_status "Visualization started (PID: $(cat "$PID_DIR/visualization.pid"))"
        print_status "Dashboard available at http://localhost:5000"
    else
        print_error "Visualization failed to start"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
}

verify_system() {
    echo "Verifying system..."
    
    # Check all components
    all_good=true
    
    # Check C bridge
    if [ -f "$PID_DIR/c_bridge.pid" ] && ps -p $(cat "$PID_DIR/c_bridge.pid") > /dev/null; then
        print_status "C bridge: Running"
    else
        print_error "C bridge: Not running"
        all_good=false
    fi
    
    # Check Python bridge
    if [ -f "$PID_DIR/python_bridge.pid" ] && ps -p $(cat "$PID_DIR/python_bridge.pid") > /dev/null; then
        print_status "Python bridge: Running"
    else
        print_error "Python bridge: Not running"
        all_good=false
    fi
    
    # Check orchestrator
    if [ -f "$PID_DIR/orchestrator.pid" ] && ps -p $(cat "$PID_DIR/orchestrator.pid") > /dev/null; then
        print_status "Orchestrator: Running"
    else
        print_error "Orchestrator: Not running"
        all_good=false
    fi
    
    # Check visualization
    if [ -f "$PID_DIR/visualization.pid" ] && ps -p $(cat "$PID_DIR/visualization.pid") > /dev/null; then
        print_status "Visualization: Running"
    else
        print_error "Visualization: Not running"
        all_good=false
    fi
    
    # Check ports
    if netstat -tuln 2>/dev/null | grep -q ":4242"; then
        print_status "Agent port (4242): Open"
    else
        print_warning "Agent port (4242): Not listening"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":5000"; then
        print_status "Visualization port (5000): Open"
    else
        print_warning "Visualization port (5000): Not listening"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":5555"; then
        print_status "Simulation port (5555): Open"
    else
        print_warning "Simulation port (5555): Not listening"
    fi
    
    if [ "$all_good" = true ]; then
        echo ""
        print_status "All systems operational!"
        echo ""
        echo "📊 Dashboard: http://localhost:5000"
        echo "📁 Logs: $LOG_DIR"
        echo "🔧 PIDs: $PID_DIR"
        echo ""
        echo "To stop all services: $0 --stop"
        echo "To view logs: tail -f $LOG_DIR/*.log"
    else
        print_error "Some components failed to start"
        echo "Check logs in $LOG_DIR for details"
        exit 1
    fi
}

stop_all() {
    echo "Stopping all services..."
    
    # Stop C bridge
    if [ -f "$PID_DIR/c_bridge.pid" ]; then
        kill -9 $(cat "$PID_DIR/c_bridge.pid") 2>/dev/null || true
        rm "$PID_DIR/c_bridge.pid"
        print_status "C bridge stopped"
    fi
    
    # Stop Python bridge
    if [ -f "$PID_DIR/python_bridge.pid" ]; then
        kill -9 $(cat "$PID_DIR/python_bridge.pid") 2>/dev/null || true
        rm "$PID_DIR/python_bridge.pid"
        print_status "Python bridge stopped"
    fi
    
    # Stop orchestrator
    if [ -f "$PID_DIR/orchestrator.pid" ]; then
        kill -9 $(cat "$PID_DIR/orchestrator.pid") 2>/dev/null || true
        rm "$PID_DIR/orchestrator.pid"
        print_status "Orchestrator stopped"
    fi
    
    # Stop visualization
    if [ -f "$PID_DIR/visualization.pid" ]; then
        kill -9 $(cat "$PID_DIR/visualization.pid") 2>/dev/null || true
        rm "$PID_DIR/visualization.pid"
        print_status "Visualization stopped"
    fi
    
    # Kill any remaining processes
    pkill -f simulation_c_bridge 2>/dev/null || true
    pkill -f agent_bridge.py 2>/dev/null || true
    pkill -f simulation_orchestrator.py 2>/dev/null || true
    pkill -f realtime_visualization.py 2>/dev/null || true
    
    print_status "All services stopped"
}

show_help() {
    echo "Adversarial Simulation Framework - Build & Run"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all           Build and start all components (default)"
    echo "  --build-only    Only build, don't start services"
    echo "  --start-only    Only start services (skip build)"
    echo "  --stop          Stop all services"
    echo "  --restart       Stop and restart all services"
    echo "  --status        Show status of all services"
    echo "  --clean         Clean build artifacts and logs"
    echo "  --help          Show this help message"
}

# Main execution
case "${1:---all}" in
    --all)
        echo "🚀 Building and starting Adversarial Simulation Framework"
        echo "=================================================="
        check_prerequisites
        install_dependencies
        build_c_components
        start_c_bridge
        start_python_bridge
        start_orchestrator
        start_visualization
        verify_system
        ;;
    --build-only)
        echo "🔨 Building components only"
        check_prerequisites
        install_dependencies
        build_c_components
        print_status "Build complete"
        ;;
    --start-only)
        echo "▶️ Starting services"
        start_c_bridge
        start_python_bridge
        start_orchestrator
        start_visualization
        verify_system
        ;;
    --stop)
        stop_all
        ;;
    --restart)
        stop_all
        echo ""
        start_c_bridge
        start_python_bridge
        start_orchestrator
        start_visualization
        verify_system
        ;;
    --status)
        verify_system
        ;;
    --clean)
        echo "Cleaning build artifacts and logs..."
        rm -rf "$BUILD_DIR"/*
        rm -rf "$LOG_DIR"/*
        rm -rf "$PID_DIR"/*
        cd "$SCRIPT_DIR/INTEGRATION" && make clean
        find "$SCRIPT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        find "$SCRIPT_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
        print_status "Clean complete"
        ;;
    --help)
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac