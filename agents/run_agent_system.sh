#!/bin/bash

# Agent System Runner - Keeps the binary protocol alive
# This wrapper ensures the agent system stays running

AGENTS_DIR="/home/ubuntu/Documents/Claude/agents"
BUILD_DIR="$AGENTS_DIR/build"
BINARY="$BUILD_DIR/ultra_hybrid_enhanced"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           Starting Claude Agent Communication System           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Create .online flag
touch "$AGENTS_DIR/.online"
echo -e "${GREEN}✓ System flag set${NC}"

# Function to run binary protocol
run_binary() {
    while [ -f "$AGENTS_DIR/.online" ]; do
        echo -e "\n${YELLOW}Starting binary protocol...${NC}"
        if [ -f "$BINARY" ]; then
            # Run the binary and capture output
            "$BINARY" 2>&1 | while IFS= read -r line; do
                # Only show important lines
                if [[ "$line" == *"Throughput:"* ]] || 
                   [[ "$line" == *"PROTOCOL"* ]] || 
                   [[ "$line" == *"RESULTS"* ]]; then
                    echo "$line"
                fi
            done
            
            # Wait before restarting
            if [ -f "$AGENTS_DIR/.online" ]; then
                echo -e "${YELLOW}Binary completed benchmark, restarting in 5 seconds...${NC}"
                sleep 5
            fi
        else
            echo -e "${YELLOW}Binary not found, waiting...${NC}"
            sleep 10
        fi
    done
}

# Function to run Python bridge
run_python_bridge() {
    if [ -f "$AGENTS_DIR/agent_bridge.py" ]; then
        echo -e "${YELLOW}Starting Python agent bridge...${NC}"
        cd "$AGENTS_DIR"
        python3 agent_bridge.py > agent_bridge.log 2>&1 &
        PYTHON_PID=$!
        echo -e "${GREEN}✓ Python bridge started (PID: $PYTHON_PID)${NC}"
    fi
}

# Trap to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down agent system...${NC}"
    rm -f "$AGENTS_DIR/.online"
    pkill -f ultra_hybrid_enhanced
    pkill -f agent_bridge.py
    echo -e "${GREEN}✓ Agent system stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start Python bridge
run_python_bridge

# Start binary protocol in background
run_binary &
BINARY_PID=$!

echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Agent System is RUNNING (Press Ctrl+C to stop)              ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "\nMonitoring agent system..."
echo -e "  Binary Protocol PID: $BINARY_PID"
echo -e "  Status: ./STATUS.sh"
echo -e "  Stop: Ctrl+C or rm $AGENTS_DIR/.online"

# Keep script running
while [ -f "$AGENTS_DIR/.online" ]; do
    sleep 10
    # Check if processes are still running
    if ! kill -0 $BINARY_PID 2>/dev/null; then
        echo -e "${YELLOW}Binary protocol stopped, restarting...${NC}"
        run_binary &
        BINARY_PID=$!
    fi
done

cleanup