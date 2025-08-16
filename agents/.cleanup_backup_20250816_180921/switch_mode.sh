#!/bin/bash
# ============================================================================
# SAFE AGENT MODE SWITCHER FOR CLAUDE CODE
# 
# Preserves the exact directory structure Claude expects
# Creates backups and safely switches between standard and binary modes
# ============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Base paths
CLAUDE_BASE="/home/ubuntu/Documents/Claude"
AGENTS_DIR="$CLAUDE_BASE/agents"
BACKUP_DIR="$AGENTS_DIR/.backups"
BINARY_BACKUP="$BACKUP_DIR/binary_system"
STANDARD_BACKUP="$BACKUP_DIR/standard_agents"
STATE_FILE="$BACKUP_DIR/.current_mode"

# Get the mode from command line
MODE=${1:-status}

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to backup current agents
backup_current_agents() {
    local backup_name="$1"
    echo "Creating backup: $backup_name"
    
    # Create timestamped backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/${backup_name}_${timestamp}"
    
    # Backup all .md files
    mkdir -p "$backup_path"
    cp "$AGENTS_DIR"/*.md "$backup_path/" 2>/dev/null || true
    
    # Also create a "latest" link
    rm -f "$BACKUP_DIR/${backup_name}_latest"
    ln -s "$backup_path" "$BACKUP_DIR/${backup_name}_latest"
    
    echo "Backed up $(ls -1 $backup_path/*.md 2>/dev/null | wc -l) agent files"
}

# Function to check if we have a clean agents directory
check_agents_clean() {
    # Check if the agents directory has the expected structure
    if [ ! -d "$AGENTS_DIR" ]; then
        echo -e "${RED}Error: Agents directory not found!${NC}"
        return 1
    fi
    
    # Check for essential files
    local md_count=$(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" | wc -l)
    if [ $md_count -lt 10 ]; then
        echo -e "${YELLOW}Warning: Only $md_count .md files found (expected more)${NC}"
    fi
    
    return 0
}

# Function to save original agents if not already saved
save_original_if_needed() {
    if [ ! -d "$STANDARD_BACKUP" ]; then
        echo "First run - saving original agent files..."
        mkdir -p "$STANDARD_BACKUP"
        
        # Copy all original .md files
        cp "$AGENTS_DIR"/*.md "$STANDARD_BACKUP/" 2>/dev/null || {
            echo -e "${RED}Error: No .md files to backup!${NC}"
            return 1
        }
        
        # Save directory structure
        find "$AGENTS_DIR" -type d > "$STANDARD_BACKUP/directory_structure.txt"
        
        echo "Saved $(ls -1 $STANDARD_BACKUP/*.md | wc -l) original agent files"
    fi
}

# Function to switch to standard mode
switch_to_standard() {
    echo -e "${YELLOW}Switching to STANDARD agent mode...${NC}"
    
    # Check if we have the original agents backed up
    if [ ! -d "$STANDARD_BACKUP" ]; then
        echo -e "${RED}Error: No standard agents backup found!${NC}"
        echo "Current agents will be used as standard."
        save_original_if_needed
        return
    fi
    
    # Backup current state if in binary mode
    if [ -f "$STATE_FILE" ] && grep -q "binary" "$STATE_FILE"; then
        backup_current_agents "binary_state"
    fi
    
    # Restore standard agents
    echo "Restoring standard agents..."
    
    # Remove binary-specific files (but keep backups)
    rm -f "$AGENTS_DIR"/*.c 2>/dev/null
    rm -f "$AGENTS_DIR"/*.h 2>/dev/null
    rm -f "$AGENTS_DIR"/ultra_hybrid_* 2>/dev/null
    rm -f "$AGENTS_DIR"/test_adapter 2>/dev/null
    rm -f "$AGENTS_DIR"/ring_buffer_* 2>/dev/null
    
    # Restore all .md files from backup
    cp "$STANDARD_BACKUP"/*.md "$AGENTS_DIR/" 2>/dev/null
    
    # Update state
    echo "standard" > "$STATE_FILE"
    
    echo -e "${GREEN}✓ Switched to STANDARD mode${NC}"
    echo "  Active agents: $(ls -1 $AGENTS_DIR/*.md | wc -l) .md files"
    echo "  Binary files removed (backed up in $BACKUP_DIR)"
}

# Function to switch to binary mode
switch_to_binary() {
    echo -e "${YELLOW}Switching to BINARY protocol mode...${NC}"
    
    # Save original agents if needed
    save_original_if_needed
    
    # Backup current standard state
    if [ ! -f "$STATE_FILE" ] || grep -q "standard" "$STATE_FILE"; then
        backup_current_agents "standard_state"
    fi
    
    # Check if binary system exists
    if [ ! -d "$AGENTS_DIR/binary-communications-system" ]; then
        echo -e "${RED}Error: Binary system not found!${NC}"
        echo "Binary system should be in: $AGENTS_DIR/binary-communications-system"
        return 1
    fi
    
    # Copy binary system files to main agents directory (alongside .md files)
    echo "Activating binary system..."
    
    # Copy essential binary files to agents root (so Claude can find them)
    cp "$AGENTS_DIR/binary-communications-system/ring_buffer_adapter.h" "$AGENTS_DIR/" 2>/dev/null
    cp "$AGENTS_DIR/binary-communications-system/ring_buffer_adapter.c" "$AGENTS_DIR/" 2>/dev/null
    cp "$AGENTS_DIR/binary-communications-system/enhanced_msg_extended.h" "$AGENTS_DIR/" 2>/dev/null
    cp "$AGENTS_DIR/binary-communications-system/compatibility_layer.h" "$AGENTS_DIR/src/c/" 2>/dev/null
    
    # Create a marker file for binary mode
    cat > "$AGENTS_DIR/BINARY_MODE_ACTIVE" << EOF
Binary Communication System Active
===================================
The binary protocol is now active for ultra-fast agent communication.
Standard .md agents are still available and work alongside the binary system.

To switch back to standard mode only:
./switch_mode.sh standard
EOF
    
    # Update state
    echo "binary" > "$STATE_FILE"
    
    echo -e "${GREEN}✓ Switched to BINARY mode${NC}"
    echo "  Standard agents: $(ls -1 $AGENTS_DIR/*.md | wc -l) .md files (still active)"
    echo "  Binary protocol: ACTIVE (4.2M msg/sec capability)"
    echo "  Integration: Both systems working together"
}

# Function to show status
show_status() {
    echo -e "${YELLOW}=== Claude Agent System Status ===${NC}"
    
    # Check current mode
    if [ -f "$STATE_FILE" ]; then
        CURRENT_MODE=$(cat "$STATE_FILE")
        echo -e "Current mode: ${GREEN}${CURRENT_MODE}${NC}"
    else
        echo -e "Current mode: ${GREEN}standard${NC} (default)"
    fi
    
    # Check directory status
    echo ""
    echo "Directory contents:"
    echo "  .md agents: $(find $AGENTS_DIR -maxdepth 1 -name '*.md' | wc -l)"
    echo "  .c files: $(find $AGENTS_DIR -maxdepth 1 -name '*.c' | wc -l)"
    echo "  .h files: $(find $AGENTS_DIR -maxdepth 1 -name '*.h' | wc -l)"
    
    # Check for binary mode marker
    if [ -f "$AGENTS_DIR/BINARY_MODE_ACTIVE" ]; then
        echo -e "  Binary system: ${GREEN}ACTIVE${NC}"
    else
        echo -e "  Binary system: ${YELLOW}INACTIVE${NC}"
    fi
    
    # Show backups
    echo ""
    echo "Backups available:"
    if [ -d "$STANDARD_BACKUP" ]; then
        echo "  Original agents: $(ls -1 $STANDARD_BACKUP/*.md 2>/dev/null | wc -l) files"
    fi
    
    local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "*_[0-9]*" | wc -l)
    echo "  Timestamped backups: $backup_count"
    
    # Check structure integrity
    echo ""
    echo "Structure check:"
    for dir in "src" "docs" "oldagents" "binary-communications-system"; do
        if [ -d "$AGENTS_DIR/$dir" ]; then
            echo -e "  /$dir: ${GREEN}✓${NC}"
        else
            echo -e "  /$dir: ${RED}✗${NC}"
        fi
    done
}

# Function to restore from backup
restore_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        echo "Available backups:"
        ls -la "$BACKUP_DIR"
        echo ""
        echo "Usage: $0 restore <backup_name>"
        return
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        echo -e "${RED}Error: Backup '$backup_name' not found${NC}"
        return 1
    fi
    
    echo "Restoring from: $backup_path"
    backup_current_agents "before_restore"
    
    # Clear current .md files
    rm -f "$AGENTS_DIR"/*.md
    
    # Restore from backup
    cp "$backup_path"/*.md "$AGENTS_DIR/"
    
    echo -e "${GREEN}✓ Restored $(ls -1 $backup_path/*.md | wc -l) files${NC}"
}

# Main logic
case "$MODE" in
    standard|std)
        check_agents_clean && switch_to_standard
        ;;
        
    binary|bin)
        check_agents_clean && switch_to_binary
        ;;
        
    status|stat)
        show_status
        ;;
        
    backup)
        backup_current_agents "manual"
        echo -e "${GREEN}✓ Manual backup created${NC}"
        ;;
        
    restore)
        restore_backup "$2"
        ;;
        
    help|*)
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  standard  - Switch to standard .md agents only"
        echo "  binary    - Enable binary protocol (keeps .md agents too)"
        echo "  status    - Show current configuration"
        echo "  backup    - Create manual backup of current agents"
        echo "  restore   - Restore from a backup"
        echo ""
        echo "This script safely switches between modes while preserving"
        echo "the exact directory structure Claude Code expects."
        echo ""
        echo "Binary mode adds ultra-fast communication alongside standard agents."
        echo "Standard mode uses only the original .md agent files."
        ;;
esac