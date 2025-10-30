#!/bin/bash
# Self-Debug System Startup for 40+ TFLOPS Military-Grade Claude System
# Integrates with our full modular stack for comprehensive autonomous debugging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/self_debug_$(date +%Y%m%d_%H%M%S).log"
PYTHON_CMD="/home/john/claude-backups/.torch-venv/bin/python"

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/debug"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "🚀 Starting Self-Debug System - 40+ TFLOPS Military-Grade Claude"
log "================================================================="
log "Session: $(date '+%Y-%m-%d %H:%M:%S')"
log "Script Dir: $SCRIPT_DIR"
log "Log File: $LOG_FILE"
log ""

# Function to check if our modular stack is running
check_modular_stack() {
    log "🔍 Checking modular stack status..."

    # Check if Opus servers are running
    local opus_count=0
    for port in 3451 3452 3453 3454; do
        if curl -s --max-time 2 "http://localhost:$port/health" >/dev/null 2>&1; then
            ((opus_count++))
            log "  ✅ Opus server on port $port: Running"
        else
            log "  ❌ Opus server on port $port: Not responding"
        fi
    done

    if [ $opus_count -eq 4 ]; then
        log "✅ All 4 Opus servers operational"
    elif [ $opus_count -gt 0 ]; then
        log "⚠️  Only $opus_count/4 Opus servers running"
    else
        log "❌ No Opus servers detected - starting them first..."
        start_opus_servers
    fi

    # Check thermal manager
    if pgrep -f "thermal_manager.py" >/dev/null; then
        log "✅ Thermal manager: Running"
    else
        log "⚠️  Thermal manager: Not running - will start with self-debug"
    fi

    # Check monitoring
    if pgrep -f "production_health_monitor.py" >/dev/null; then
        log "✅ Health monitor: Running"
    else
        log "⚠️  Health monitor: Not running - will start with self-debug"
    fi

    log ""
}

# Function to start Opus servers if needed
start_opus_servers() {
    log "🎯 Starting Opus servers..."

    if [ -f "$SCRIPT_DIR/phase7_production_deployment.sh" ]; then
        bash "$SCRIPT_DIR/phase7_production_deployment.sh" &
        log "Opus deployment script started"

        # Wait for servers to come online
        for i in {1..30}; do
            local healthy_count=0
            for port in 3451 3452 3453 3454; do
                if curl -s --max-time 2 "http://localhost:$port/health" >/dev/null 2>&1; then
                    ((healthy_count++))
                fi
            done

            if [ $healthy_count -eq 4 ]; then
                log "✅ All Opus servers started successfully"
                break
            fi

            log "Waiting for servers... ($healthy_count/4 ready)"
            sleep 2
        done
    else
        log "❌ Opus deployment script not found"
    fi
}

# Function to run system validation
validate_system() {
    log "🧪 Running system validation..."

    # Test basic Python environment
    if $PYTHON_CMD -c "import asyncio, aiohttp, psutil; print('✅ Python environment OK')" 2>/dev/null; then
        log "✅ Python environment: OK"
    else
        log "❌ Python environment: Missing dependencies"
        exit 1
    fi

    # Test individual components
    local components=(
        "orchestration/parallel_agent_coordinator.py"
        "monitoring/production_health_monitor.py"
        "hardware/thermal_manager.py"
        "interface/local_claude_interface.py"
    )

    for component in "${components[@]}"; do
        if [ -f "$SCRIPT_DIR/$component" ]; then
            log "✅ Component: $component"
        else
            log "⚠️  Component missing: $component"
        fi
    done

    # Test self-debug orchestrator
    if [ -f "$SCRIPT_DIR/debug/self_debug_orchestrator.py" ]; then
        log "✅ Self-debug orchestrator: Ready"
    else
        log "❌ Self-debug orchestrator: Not found"
        exit 1
    fi

    log "✅ System validation complete"
    log ""
}

# Function to start the main self-debug system
start_self_debug() {
    log "🔧 Starting Self-Debug Orchestrator..."

    cd "$SCRIPT_DIR"

    # Start the main self-debug system
    $PYTHON_CMD debug/self_debug_orchestrator.py &
    SELF_DEBUG_PID=$!

    log "Self-Debug Orchestrator started with PID: $SELF_DEBUG_PID"

    # Monitor the self-debug process
    while kill -0 $SELF_DEBUG_PID 2>/dev/null; do
        sleep 30

        # Check if process is still healthy
        if ! kill -0 $SELF_DEBUG_PID 2>/dev/null; then
            log "❌ Self-debug process died, restarting..."
            $PYTHON_CMD debug/self_debug_orchestrator.py &
            SELF_DEBUG_PID=$!
        fi
    done
}

# Function to show system status
show_status() {
    log "📊 Current System Status:"
    log "========================"

    # Opus servers status
    log "Opus Servers:"
    local ports=(3451 3452 3453 3454)
    local configs=("NPU_Military" "GPU_Acceleration" "NPU_Standard" "CPU_Fallback")

    for i in "${!ports[@]}"; do
        local port=${ports[$i]}
        local config=${configs[$i]}

        if curl -s --max-time 2 "http://localhost:$port/health" >/dev/null 2>&1; then
            log "  ✅ Port $port ($config): Healthy"
        else
            log "  ❌ Port $port ($config): Down"
        fi
    done

    # Process status
    log ""
    log "Core Processes:"
    local process_checks=(
        "opus_server:local_opus_server.py"
        "thermal_manager:thermal_manager.py"
        "health_monitor:production_health_monitor.py"
        "self_debug:self_debug_orchestrator.py"
    )

    for check in "${process_checks[@]}"; do
        local name=$(echo $check | cut -d: -f1)
        local process=$(echo $check | cut -d: -f2)

        local count=$(pgrep -f "$process" | wc -l)
        if [ $count -gt 0 ]; then
            log "  ✅ $name: $count processes"
        else
            log "  ❌ $name: Not running"
        fi
    done

    # System resources
    log ""
    log "System Resources:"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    log "  CPU Usage: ${cpu_usage:-Unknown}%"
    log "  Memory Usage: ${mem_usage:-Unknown}%"
    log "  Disk Usage: ${disk_usage:-Unknown}%"

    # Thermal status
    local max_temp=0
    for i in {0..4}; do
        local temp_file="/sys/class/thermal/thermal_zone$i/temp"
        if [ -f "$temp_file" ]; then
            local temp=$(($(cat "$temp_file") / 1000))
            if [ $temp -gt $max_temp ]; then
                max_temp=$temp
            fi
        fi
    done

    if [ $max_temp -gt 0 ]; then
        log "  Max Temperature: ${max_temp}°C"
    fi

    log ""
}

# Function to cleanup on exit
cleanup() {
    log "🛑 Self-debug system shutdown requested"

    # Kill self-debug process if running
    if [ -n "${SELF_DEBUG_PID:-}" ]; then
        kill $SELF_DEBUG_PID 2>/dev/null || true
        log "Self-debug orchestrator stopped"
    fi

    log "Cleanup complete"
}

# Setup signal handlers
trap cleanup EXIT INT TERM

# Main execution
case "${1:-start}" in
    "start")
        check_modular_stack
        validate_system
        show_status
        start_self_debug
        ;;
    "status")
        show_status
        ;;
    "stop")
        log "Stopping self-debug system..."
        pkill -f "self_debug_orchestrator.py" || true
        log "Self-debug system stopped"
        ;;
    "restart")
        log "Restarting self-debug system..."
        pkill -f "self_debug_orchestrator.py" || true
        sleep 3
        exec "$0" start
        ;;
    "validate")
        validate_system
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|validate}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the self-debug system (default)"
        echo "  stop     - Stop the self-debug system"
        echo "  restart  - Restart the self-debug system"
        echo "  status   - Show current system status"
        echo "  validate - Validate system components"
        exit 1
        ;;
esac

log "Self-debug operation complete"