#!/bin/bash
# run-agents.sh - Quick launcher for Claude Agent Communication System
# This script starts the entire agent infrastructure with one command

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Claude Agent Communication System Launcher              ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Determine script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AGENTS_DIR="$SCRIPT_DIR/agents"

# Check if BRING_ONLINE.sh exists
if [ ! -f "$AGENTS_DIR/BRING_ONLINE.sh" ]; then
    echo -e "${YELLOW}⚠ BRING_ONLINE.sh not found in $AGENTS_DIR${NC}"
    echo "Please ensure you're in the Claude directory."
    exit 1
fi

# Make sure BRING_ONLINE.sh is executable
chmod +x "$AGENTS_DIR/BRING_ONLINE.sh"

echo -e "${GREEN}➜ Launching Agent Communication System...${NC}"
echo ""

# Change to agents directory and run the launcher
cd "$AGENTS_DIR"
./BRING_ONLINE.sh

echo ""
echo -e "${GREEN}✓ Agent system is now online!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"