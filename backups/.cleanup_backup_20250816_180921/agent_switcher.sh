#!/bin/bash
# ============================================================================
# AGENT SYSTEM SWITCHER
# 
# Simple script to switch between standard .md agents and binary system
# Usage: source agent_switcher.sh [standard|binary|status]
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
CLAUDE_BASE="/home/ubuntu/Documents/Claude"
AGENTS_DIR="$CLAUDE_BASE/agents"
BINARY_DIR="$CLAUDE_BASE/agents/binary-communications-system"
CONFIG_FILE="$HOME/.claude_agent_config"

# Function to show current status
show_status() {
    echo -e "${YELLOW}=== Agent System Status ===${NC}"
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "Current mode: ${GREEN}${AGENT_MODE:-standard}${NC}"
    else
        echo -e "Current mode: ${GREEN}standard${NC} (default)"
    fi
    
    # Check if binary system is built
    if [ -f "$BINARY_DIR/ultra_hybrid_final" ]; then
        echo -e "Binary system: ${GREEN}Available${NC}"
    else
        echo -e "Binary system: ${RED}Not built${NC}"
    fi
    
    # Check if compatibility layer is built
    if [ -f "$BINARY_DIR/test_adapter" ]; then
        echo -e "Adapter layer: ${GREEN}Available${NC}"
    else
        echo -e "Adapter layer: ${YELLOW}Not tested${NC}"
    fi
    
    # Count agents
    MD_COUNT=$(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" | wc -l)
    echo -e "Standard agents: ${GREEN}$MD_COUNT${NC} .md files"
    
    # Show environment
    echo -e "\nEnvironment variables:"
    echo "  CLAUDE_AGENT_PATH=${CLAUDE_AGENT_PATH:-not set}"
    echo "  USE_BINARY_PROTOCOL=${USE_BINARY_PROTOCOL:-0}"
    echo "  AGENT_MODE=${AGENT_MODE:-standard}"
}

# Function to switch to standard mode
switch_to_standard() {
    echo -e "${YELLOW}Switching to STANDARD agent mode...${NC}"
    
    # Update config
    cat > "$CONFIG_FILE" << EOF
# Claude Agent Configuration
export AGENT_MODE="standard"
export CLAUDE_AGENT_PATH="$AGENTS_DIR"
export USE_BINARY_PROTOCOL=0
export CLAUDE_USE_MD_AGENTS=1
EOF
    
    # Source it
    source "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ Switched to standard .md agents${NC}"
    echo "  Path: $CLAUDE_AGENT_PATH"
    echo "  Agents available: $(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" | wc -l)"
}

# Function to switch to binary mode
switch_to_binary() {
    echo -e "${YELLOW}Switching to BINARY protocol mode...${NC}"
    
    # Check if binary system is built
    if [ ! -f "$BINARY_DIR/ultra_hybrid_final" ]; then
        echo -e "${RED}Error: Binary system not built${NC}"
        echo "Building binary system..."
        
        cd "$BINARY_DIR"
        gcc -o ultra_hybrid_final ultra_hybrid_enhanced.c \
            ring_buffer_adapter.c \
            ../src/c/compatibility_layer.c \
            -pthread -lnuma -luring -lm -march=native -O3 2>/dev/null || {
            echo -e "${RED}Build failed. Falling back to standard mode.${NC}"
            switch_to_standard
            return 1
        }
        echo -e "${GREEN}✓ Binary system built${NC}"
    fi
    
    # Update config
    cat > "$CONFIG_FILE" << EOF
# Claude Agent Configuration
export AGENT_MODE="binary"
export CLAUDE_AGENT_PATH="$BINARY_DIR"
export USE_BINARY_PROTOCOL=1
export CLAUDE_USE_MD_AGENTS=0
export BINARY_RING_BUFFER_SIZE=$((256 * 1024 * 1024))  # 256MB
export BINARY_USE_NUMA=1
export BINARY_USE_ADAPTER=1
EOF
    
    # Source it
    source "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ Switched to binary protocol${NC}"
    echo "  Path: $CLAUDE_AGENT_PATH"
    echo "  Protocol: Ultra-fast binary (4.2M msg/sec)"
    echo "  Features: NUMA-aware, work-stealing, lock-free"
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}Running integration tests...${NC}"
    
    if [ "$AGENT_MODE" = "binary" ]; then
        if [ -f "$BINARY_DIR/test_adapter" ]; then
            "$BINARY_DIR/test_adapter"
        else
            echo -e "${YELLOW}Building test suite...${NC}"
            cd "$BINARY_DIR"
            gcc -o test_adapter test_adapter.c \
                ring_buffer_adapter.c \
                ../src/c/compatibility_layer.c \
                -pthread -lnuma -luring -I../src/c -O2
            ./test_adapter
        fi
    else
        echo "Standard mode uses Claude's built-in tests"
    fi
}

# Main script logic
case "${1:-status}" in
    standard|std)
        switch_to_standard
        ;;
    binary|bin)
        switch_to_binary
        ;;
    status|stat)
        show_status
        ;;
    test)
        run_tests
        ;;
    help)
        echo "Usage: source agent_switcher.sh [command]"
        echo "Commands:"
        echo "  standard  - Switch to standard .md agents"
        echo "  binary    - Switch to binary protocol"
        echo "  status    - Show current configuration"
        echo "  test      - Run integration tests"
        echo "  help      - Show this help"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use 'help' for usage information"
        exit 1
        ;;
esac

# Show reminder if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo -e "${YELLOW}Note: Run with 'source' to update environment:${NC}"
    echo "  source agent_switcher.sh [command]"
fi