#!/bin/bash

# 🚀 QUICK LAUNCH - Adversarial Simulation Framework
# One-command launcher for immediate execution

echo "🚀 Quick Launch - Adversarial Simulation Framework"
echo "=================================================="

# Base directory
BASE_DIR="/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS"
cd "$BASE_DIR"

# Function to check if service is running
check_service() {
    pgrep -f "$1" > /dev/null && echo "✓ $2 running" || echo "✗ $2 not found"
}

# Parse command
case "${1:-start}" in
    start)
        echo "Starting all services..."
        
        # Kill any existing processes
        pkill -f simulation_c_bridge 2>/dev/null
        pkill -f agent_bridge.py 2>/dev/null
        pkill -f simulation_orchestrator.py 2>/dev/null
        pkill -f realtime_visualization.py 2>/dev/null
        
        sleep 1
        
        # Start services in background
        echo "Starting C bridge..."
        cd "$BASE_DIR/INTEGRATION"
        if [ -f simulation_c_bridge ]; then
            ./simulation_c_bridge > /dev/null 2>&1 &
        else
            echo "Building C bridge first..."
            make clean > /dev/null 2>&1
            make > /dev/null 2>&1
            ./simulation_c_bridge > /dev/null 2>&1 &
        fi
        
        echo "Starting Python bridge..."
        python3 agent_bridge.py > /dev/null 2>&1 &
        
        echo "Starting Orchestrator..."
        cd "$BASE_DIR/ORCHESTRATOR"
        python3 simulation_orchestrator.py > /dev/null 2>&1 &
        
        echo "Starting Visualization..."
        cd "$BASE_DIR/VISUALIZATION"
        python3 realtime_visualization.py > /dev/null 2>&1 &
        
        sleep 3
        
        echo ""
        echo "Services Status:"
        check_service "simulation_c_bridge" "C Bridge"
        check_service "agent_bridge.py" "Python Bridge"
        check_service "simulation_orchestrator.py" "Orchestrator"
        check_service "realtime_visualization.py" "Visualization"
        
        echo ""
        echo "📊 Dashboard: http://localhost:5000"
        echo ""
        echo "To stop: $0 stop"
        ;;
        
    stop)
        echo "Stopping all services..."
        pkill -f simulation_c_bridge
        pkill -f agent_bridge.py
        pkill -f simulation_orchestrator.py
        pkill -f realtime_visualization.py
        echo "All services stopped"
        ;;
        
    status)
        echo "Service Status:"
        check_service "simulation_c_bridge" "C Bridge"
        check_service "agent_bridge.py" "Python Bridge"
        check_service "simulation_orchestrator.py" "Orchestrator"
        check_service "realtime_visualization.py" "Visualization"
        
        echo ""
        echo "Network Ports:"
        netstat -tuln 2>/dev/null | grep -E ":(4242|5000|5555|5556)" || echo "No services listening"
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
        
    dashboard)
        echo "Opening dashboard..."
        if command -v xdg-open > /dev/null; then
            xdg-open http://localhost:5000
        elif command -v open > /dev/null; then
            open http://localhost:5000
        else
            echo "Please open: http://localhost:5000"
        fi
        ;;
        
    logs)
        echo "=== Recent Logs ==="
        tail -20 "$BASE_DIR"/logs/*.log 2>/dev/null || echo "No logs found"
        ;;
        
    test)
        echo "Running system test..."
        cd "$BASE_DIR"
        python3 test_simulation.py
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|dashboard|logs|test}"
        echo ""
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  status    - Check service status"
        echo "  dashboard - Open web dashboard"
        echo "  logs      - View recent logs"
        echo "  test      - Run system tests"
        ;;
esac