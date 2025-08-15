#!/bin/bash
# setup_agent_env.sh - Set up environment for agent binary protocol
# Run this or source it before using the agent system

AGENTS_DIR="/home/ubuntu/Documents/Claude/agents"

# Export critical environment variables with CORRECTED PATHS
export AGENT_SOCKET_PATH="$AGENTS_DIR/06-BUILD-RUNTIME/runtime/claude_agent_bridge.sock"
export AGENT_RUNTIME_DIR="$AGENTS_DIR/06-BUILD-RUNTIME/runtime"
export AGENT_BUILD_DIR="$AGENTS_DIR/06-BUILD-RUNTIME/build"
export AGENT_CONFIG_DIR="$AGENTS_DIR/05-CONFIG"
export AGENT_BINARY_DIR="$AGENTS_DIR/02-BINARY-PROTOCOL"
export AGENT_BRIDGES_DIR="$AGENTS_DIR/03-BRIDGES"

# Create necessary directories
mkdir -p "$AGENT_RUNTIME_DIR"
mkdir -p "$AGENT_BUILD_DIR"
chmod 755 "$AGENT_RUNTIME_DIR"

# Clean up any stale sockets
if [ -S "$AGENT_SOCKET_PATH" ]; then
    echo "Removing stale socket..."
    rm -f "$AGENT_SOCKET_PATH"
fi

# Set up Python path with CORRECTED PATHS
export PYTHONPATH="$AGENTS_DIR:$AGENTS_DIR/03-BRIDGES:$AGENTS_DIR/04-SOURCE/python-modules:$PYTHONPATH"

# Function to test socket connection
test_agent_socket() {
    if [ -S "$AGENT_SOCKET_PATH" ]; then
        echo "Testing socket connection..."
        echo "test" | timeout 1 nc -U "$AGENT_SOCKET_PATH" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Socket connection successful"
            return 0
        else
            echo "⚠️  Socket exists but not responding"
            return 1
        fi
    else
        echo "❌ Socket not found at: $AGENT_SOCKET_PATH"
        return 1
    fi
}

# Function to check binary bridge status
check_bridge_status() {
    if pgrep -f "ultra_hybrid_enhanced" > /dev/null; then
        PID=$(pgrep -f "ultra_hybrid_enhanced" | head -1)
        echo "✅ Binary bridge running (PID: $PID)"
        
        # Check if it's using the correct socket
        if lsof -p $PID 2>/dev/null | grep -q "$AGENT_SOCKET_PATH"; then
            echo "  ✓ Using correct socket path"
        else
            echo "  ⚠ Not using expected socket path"
        fi
        
        return 0
    else
        echo "❌ Binary bridge not running"
        return 1
    fi
}

# Function to restart binary bridge
restart_bridge() {
    echo "Restarting binary bridge..."
    
    # Stop existing
    pkill -f "ultra_hybrid_enhanced" 2>/dev/null || true
    sleep 1
    
    # Start new
    if [ -f "$AGENT_BUILD_DIR/ultra_hybrid_enhanced" ]; then
        nohup "$AGENT_BUILD_DIR/ultra_hybrid_enhanced" \
            > "$AGENTS_DIR/binary_bridge.log" 2>&1 &
        echo "Binary bridge restarted"
        sleep 2
        test_agent_socket
    else
        echo "Binary bridge not built. Run: cd $AGENTS_DIR/00-STARTUP && ./BRING_ONLINE.sh"
    fi
}

# Alias for quick socket test
alias test-socket='echo "test" | nc -U $AGENT_SOCKET_PATH'
alias agent-status='check_bridge_status && test_agent_socket'
alias agent-restart='restart_bridge'
alias agent-log='tail -f $AGENTS_DIR/binary_bridge.log'
alias agent-bring-online='cd $AGENTS_DIR/00-STARTUP && ./BRING_ONLINE.sh'

# Function to show statusline
show_statusline() {
    python3 -c "
import sys
sys.path.append('$AGENTS_DIR/03-BRIDGES')
from statusline_bridge import get_statusline
sl = get_statusline()
print(sl.get_status_line())
" 2>/dev/null || echo "Statusline not available"
}

# Display current configuration
echo "🔧 AGENT ENVIRONMENT CONFIGURED"
echo "================================"
echo "Socket Path:  $AGENT_SOCKET_PATH"
echo "Runtime Dir:  $AGENT_RUNTIME_DIR"
echo "Build Dir:    $AGENT_BUILD_DIR"
echo "Config Dir:   $AGENT_CONFIG_DIR"
echo "Binary Dir:   $AGENT_BINARY_DIR"
echo "Bridges Dir:  $AGENT_BRIDGES_DIR"
echo ""
echo "Available commands:"
echo "  test-socket        - Test socket connection"
echo "  agent-status       - Check bridge status"
echo "  agent-restart      - Restart binary bridge"
echo "  agent-log          - View bridge logs"
echo "  agent-bring-online - Run BRING_ONLINE.sh"
echo "  show_statusline    - Display current statusline"
echo ""

# Check current status
check_bridge_status
test_agent_socket

# If not running, offer to start
if [ $? -ne 0 ]; then
    echo ""
    echo "💡 Binary bridge not active."
    echo "   Start with: agent-bring-online"
    echo "   Or restart: agent-restart"
fi

# Show current statusline
echo ""
echo "📊 Current Status Line:"
show_statusline