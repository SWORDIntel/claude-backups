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

# Check and install statusline dependencies if needed
echo -e "${GREEN}➜ Checking statusline dependencies...${NC}"
missing_deps=()

# Check for essential statusline tools
for tool in jq git wc grep awk bc curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_deps+=("$tool")
    fi
done

# Install missing dependencies if any
if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Installing missing dependencies: ${missing_deps[*]}${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq >/dev/null 2>&1
        sudo apt-get install -y "${missing_deps[@]}" >/dev/null 2>&1
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠ Could not install dependencies automatically${NC}"
    fi
else
    echo -e "${GREEN}✓ All statusline dependencies available${NC}"
fi

echo -e "${GREEN}➜ Launching Agent Communication System...${NC}"
echo ""

# Change to agents directory and run the launcher
cd "$AGENTS_DIR"
./BRING_ONLINE.sh

echo ""
echo -e "${GREEN}✓ Agent system is now online!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"