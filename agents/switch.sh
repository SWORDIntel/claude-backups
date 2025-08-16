#!/bin/bash
# ============================================================================
# MINIMAL CLAUDE AGENT SWITCHER
# 
# ZERO file modifications - only symlink redirection
# Usage: ./switch.sh [standard|binary|status]
# ============================================================================

MODE=${1:-status}
CLAUDE_BASE="/home/ubuntu/Documents/Claude"
AGENTS_DIR="$CLAUDE_BASE/agents"
STANDARD_DIR="$CLAUDE_BASE/agents_standard"
BINARY_DIR="$CLAUDE_BASE/agents_binary"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$MODE" in
    standard)
        # First run: backup current to standard
        if [ ! -d "$STANDARD_DIR" ]; then
            if [ -d "$AGENTS_DIR" ] && [ ! -L "$AGENTS_DIR" ]; then
                mv "$AGENTS_DIR" "$STANDARD_DIR"
            fi
        fi
        
        # Remove any existing link/dir
        rm -rf "$AGENTS_DIR"
        
        # Create symlink to standard
        ln -s "$STANDARD_DIR" "$AGENTS_DIR"
        
        echo -e "${GREEN}✓ Standard agents active${NC}"
        ;;
        
    binary)
        # First run: backup current to standard, create binary
        if [ ! -d "$STANDARD_DIR" ]; then
            if [ -d "$AGENTS_DIR" ] && [ ! -L "$AGENTS_DIR" ]; then
                cp -r "$AGENTS_DIR" "$STANDARD_DIR"
            fi
        fi
        
        if [ ! -d "$BINARY_DIR" ]; then
            cp -r "$STANDARD_DIR" "$BINARY_DIR"
            # Add binary system files to binary dir
            if [ -d "$STANDARD_DIR/binary-communications-system" ]; then
                cp -r "$STANDARD_DIR/binary-communications-system"/* "$BINARY_DIR/" 2>/dev/null || true
            fi
        fi
        
        # Remove any existing link/dir
        rm -rf "$AGENTS_DIR"
        
        # Create symlink to binary
        ln -s "$BINARY_DIR" "$AGENTS_DIR"
        
        echo -e "${GREEN}✓ Binary system active${NC}"
        ;;
        
    status)
        echo -e "${YELLOW}=== Claude Agent Switcher Status ===${NC}"
        
        if [ -L "$AGENTS_DIR" ]; then
            TARGET=$(readlink "$AGENTS_DIR")
            if [[ "$TARGET" == *"standard"* ]]; then
                echo -e "Mode: ${GREEN}STANDARD${NC}"
            elif [[ "$TARGET" == *"binary"* ]]; then
                echo -e "Mode: ${GREEN}BINARY${NC}"
            else
                echo -e "Mode: ${GREEN}CUSTOM${NC} → $TARGET"
            fi
            echo "Target: $TARGET"
        elif [ -d "$AGENTS_DIR" ]; then
            echo -e "Mode: ${GREEN}STANDARD${NC} (original directory)"
        else
            echo "No agents directory found!"
        fi
        
        if [ -d "$AGENTS_DIR" ]; then
            echo "Agent files: $(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" | wc -l) .md files"
        fi
        ;;
        
    *)
        echo "Usage: $0 [standard|binary|status]"
        echo ""
        echo "  standard - Use standard .md agents"
        echo "  binary   - Use binary protocol system"  
        echo "  status   - Show current mode"
        echo ""
        echo "This script only uses symlinks - no file modifications."
        ;;
esac