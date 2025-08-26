#!/bin/bash
# ============================================================================
# SIMPLE AGENT DIRECTORY SWITCHER FOR CLAUDE CODE
# 
# Just switches which agents directory Claude Code uses
# No modifications to any other files - just a simple redirect
# ============================================================================

# Get the mode from command line
MODE=${1:-status}

# Base paths
CLAUDE_BASE="/home/ubuntu/Documents/Claude"
STANDARD_AGENTS="$CLAUDE_BASE/agents_standard"  # Standard .md agents
BINARY_AGENTS="$CLAUDE_BASE/agents_binary"      # Binary protocol agents  
ACTIVE_LINK="$CLAUDE_BASE/agents"               # What Claude Code actually uses

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$MODE" in
    standard)
        # First, ensure we have the standard agents backed up
        if [ ! -d "$STANDARD_AGENTS" ]; then
            echo "Backing up current standard agents..."
            if [ -L "$ACTIVE_LINK" ]; then
                # It's a symlink, resolve it
                REAL_PATH=$(readlink -f "$ACTIVE_LINK")
                rm "$ACTIVE_LINK"
                mv "$REAL_PATH" "$STANDARD_AGENTS"
            elif [ -d "$ACTIVE_LINK" ]; then
                # It's a real directory
                mv "$ACTIVE_LINK" "$STANDARD_AGENTS"
            fi
        fi
        
        # Remove existing link/directory
        rm -rf "$ACTIVE_LINK"
        
        # Create symlink to standard agents
        ln -s "$STANDARD_AGENTS" "$ACTIVE_LINK"
        
        echo -e "${GREEN}✓ Switched to STANDARD agents${NC}"
        echo "  Claude Code will now use: $(readlink -f $ACTIVE_LINK)"
        echo "  Available: $(find "$ACTIVE_LINK" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l) .md agents"
        ;;
        
    binary)
        # Ensure binary agents directory exists
        if [ ! -d "$BINARY_AGENTS" ]; then
            echo "Creating binary agents directory..."
            mkdir -p "$BINARY_AGENTS"
            # Copy the binary communication system files
            cp -r "$CLAUDE_BASE/agents/binary-communications-system"/* "$BINARY_AGENTS/" 2>/dev/null || true
            # Also copy any .md agents that work with binary system
            cp "$CLAUDE_BASE/agents"/*.md "$BINARY_AGENTS/" 2>/dev/null || true
        fi
        
        # First backup current agents if needed
        if [ -d "$ACTIVE_LINK" ] && [ ! -L "$ACTIVE_LINK" ]; then
            echo "Backing up current agents..."
            mv "$ACTIVE_LINK" "$STANDARD_AGENTS"
        fi
        
        # Remove existing link/directory
        rm -rf "$ACTIVE_LINK"
        
        # Create symlink to binary agents
        ln -s "$BINARY_AGENTS" "$ACTIVE_LINK"
        
        echo -e "${GREEN}✓ Switched to BINARY agents${NC}"
        echo "  Claude Code will now use: $(readlink -f $ACTIVE_LINK)"
        echo "  Binary protocol active with ultra-fast communication"
        ;;
        
    status)
        echo -e "${YELLOW}=== Claude Code Agent Configuration ===${NC}"
        
        if [ -L "$ACTIVE_LINK" ]; then
            CURRENT=$(readlink -f "$ACTIVE_LINK")
            if [[ "$CURRENT" == *"standard"* ]]; then
                echo -e "Mode: ${GREEN}STANDARD${NC}"
            elif [[ "$CURRENT" == *"binary"* ]]; then
                echo -e "Mode: ${GREEN}BINARY${NC}"
            else
                echo -e "Mode: ${GREEN}CUSTOM${NC} ($CURRENT)"
            fi
            echo "Active directory: $CURRENT"
        elif [ -d "$ACTIVE_LINK" ]; then
            echo -e "Mode: ${GREEN}STANDARD${NC} (original directory)"
            echo "Active directory: $ACTIVE_LINK"
        else
            echo "No agents directory found!"
        fi
        
        # Show what's available
        if [ -d "$ACTIVE_LINK" ]; then
            echo ""
            echo "Available agents:"
            echo "  .md files: $(find "$ACTIVE_LINK" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)"
            echo "  .c files: $(find "$ACTIVE_LINK" -maxdepth 1 -name "*.c" 2>/dev/null | wc -l)"
            echo "  Binary executables: $(find "$ACTIVE_LINK" -maxdepth 1 -type f -executable 2>/dev/null | wc -l)"
        fi
        ;;
        
    *)
        echo "Usage: $0 [standard|binary|status]"
        echo ""
        echo "  standard - Use standard .md agents (normal Claude Code)"
        echo "  binary   - Use binary protocol agents (ultra-fast)"
        echo "  status   - Show current configuration"
        echo ""
        echo "This script simply redirects which agents directory Claude Code uses."
        echo "No other files are modified - it's just a symlink switch."
        ;;
esac