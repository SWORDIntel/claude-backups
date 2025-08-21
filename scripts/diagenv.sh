#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE INSTALLATION DIAGNOSTIC TOOL
# Helps identify why files aren't being found
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}         Claude Installation Diagnostic Tool${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: DETECT PROJECT ROOT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 1: Detecting Project Root${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script location: $SCRIPT_DIR"

# Find project root
find_project_root() {
    local current_dir="$SCRIPT_DIR"
    local max_depth=10
    local depth=0
    
    # If in installers subdirectory
    if [[ "$(basename "$current_dir")" == "installers" ]]; then
        current_dir="$(dirname "$current_dir")"
        echo "  Detected 'installers' subdirectory, checking parent..."
    fi
    
    # Search upward
    while [ $depth -lt $max_depth ]; do
        echo -n "  Checking: $current_dir ... "
        
        if [ -d "$current_dir/.claude-home" ]; then
            echo -e "${GREEN}Found .claude-home${NC}"
            echo "$current_dir"
            return 0
        elif [ -d "$current_dir/agents" ]; then
            echo -e "${GREEN}Found agents/${NC}"
            echo "$current_dir"
            return 0
        elif [ -f "$current_dir/claude-unified" ]; then
            echo -e "${GREEN}Found claude-unified${NC}"
            echo "$current_dir"
            return 0
        else
            echo "not project root"
        fi
        
        [ "$current_dir" = "/" ] && break
        current_dir="$(dirname "$current_dir")"
        depth=$((depth + 1))
    done
    
    # Check user directories
    for dir in "$HOME/Documents/Claude" "$HOME/claude-backups" "$HOME/claude-project"; do
        if [ -d "$dir" ]; then
            echo -n "  Checking: $dir ... "
            if [ -d "$dir/agents" ] || [ -d "$dir/.claude-home" ]; then
                echo -e "${GREEN}Found project markers${NC}"
                echo "$dir"
                return 0
            else
                echo "no markers"
            fi
        fi
    done
    
    echo "$SCRIPT_DIR"
    return 1
}

PROJECT_ROOT="$(find_project_root)"
echo
echo -e "${GREEN}Project Root: $PROJECT_ROOT${NC}"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: SEARCH FOR PRODUCTION SETUP FILE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 2: Searching for setup_production_env.sh${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# List of paths to check
search_paths=(
    "agents/src/c/python/setup_production_env.sh"
    "src/c/python/setup_production_env.sh"
    "scripts/setup_production_env.sh"
    "setup/setup_production_env.sh"
    "bin/setup_production_env.sh"
    "orchestration/setup_production_env.sh"
    "agents/setup_production_env.sh"
    "python/setup_production_env.sh"
)

found_setup=false
for relative_path in "${search_paths[@]}"; do
    full_path="$PROJECT_ROOT/$relative_path"
    echo -n "  Checking: $relative_path ... "
    
    if [ -f "$full_path" ]; then
        echo -e "${GREEN}FOUND!${NC}"
        echo -e "    Full path: ${CYAN}$full_path${NC}"
        echo -e "    Size: $(stat -c%s "$full_path" 2>/dev/null || stat -f%z "$full_path" 2>/dev/null || echo "unknown") bytes"
        echo -e "    Permissions: $(ls -l "$full_path" | awk '{print $1}')"
        found_setup=true
        SETUP_PATH="$full_path"
    elif [ -e "$full_path" ]; then
        echo -e "${YELLOW}exists but not a regular file${NC}"
    else
        echo "not found"
    fi
done

if [ "$found_setup" = false ]; then
    echo
    echo -e "${YELLOW}Running comprehensive search...${NC}"
    echo "  Using find to locate any setup_production* files:"
    find "$PROJECT_ROOT" -name "*setup_production*" -type f 2>/dev/null | while read -r file; do
        echo -e "    ${CYAN}Found: ${file#$PROJECT_ROOT/}${NC}"
    done
fi
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: SEARCH FOR ORCHESTRATION FILES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 3: Searching for Orchestration Components${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Search for tandem_orchestrator.py
echo "Looking for tandem_orchestrator.py:"
tandem_paths=(
    "agents/src/python/tandem_orchestrator.py"
    "src/python/tandem_orchestrator.py"
    "orchestration/tandem_orchestrator.py"
    "python/tandem_orchestrator.py"
)

for relative_path in "${tandem_paths[@]}"; do
    full_path="$PROJECT_ROOT/$relative_path"
    echo -n "  Checking: $relative_path ... "
    
    if [ -f "$full_path" ]; then
        echo -e "${GREEN}FOUND!${NC}"
        TANDEM_PATH="$full_path"
        break
    else
        echo "not found"
    fi
done

# Search for production_orchestrator.py
echo
echo "Looking for production_orchestrator.py:"
prod_paths=(
    "agents/src/python/production_orchestrator.py"
    "src/python/production_orchestrator.py"
    "orchestration/production_orchestrator.py"
    "python/production_orchestrator.py"
)

for relative_path in "${prod_paths[@]}"; do
    full_path="$PROJECT_ROOT/$relative_path"
    echo -n "  Checking: $relative_path ... "
    
    if [ -f "$full_path" ]; then
        echo -e "${GREEN}FOUND!${NC}"
        PROD_ORCH_PATH="$full_path"
        break
    else
        echo "not found"
    fi
done
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: DIRECTORY STRUCTURE ANALYSIS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 4: Directory Structure Analysis${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Project structure:"
# Show tree-like structure (limited depth)
if command -v tree &>/dev/null; then
    tree -L 4 -d "$PROJECT_ROOT" 2>/dev/null | head -30
else
    # Fallback to find
    echo "  Directory listing (up to 4 levels):"
    find "$PROJECT_ROOT" -type d -maxdepth 4 2>/dev/null | \
        sed "s|$PROJECT_ROOT|.|" | \
        sort | \
        head -30 | \
        while read -r dir; do
            depth=$(echo "$dir" | tr -cd '/' | wc -c)
            indent=""
            for ((i=0; i<depth; i++)); do
                indent="  $indent"
            done
            basename_dir=$(basename "$dir")
            echo "${indent}├── $basename_dir"
        done
fi
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: CHECK SPECIFIC PATHS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 5: Checking Specific Directory Contents${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check agents/src/c/python specifically
check_path="$PROJECT_ROOT/agents/src/c/python"
echo "Contents of agents/src/c/python/:"
if [ -d "$check_path" ]; then
    ls -la "$check_path" 2>/dev/null | head -10
    echo
    echo "  Python files in this directory:"
    find "$check_path" -name "*.py" -o -name "*.sh" 2>/dev/null | while read -r file; do
        echo "    - $(basename "$file")"
    done
else
    echo "  Directory does not exist"
fi
echo

# Check agents/src/python
check_path="$PROJECT_ROOT/agents/src/python"
echo "Contents of agents/src/python/:"
if [ -d "$check_path" ]; then
    ls -la "$check_path" 2>/dev/null | head -10
else
    echo "  Directory does not exist"
fi
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: GENERATE FIX SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Step 6: Generating Fix Recommendations${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$found_setup" = true ] && [ -n "${SETUP_PATH:-}" ]; then
    echo -e "${GREEN}Production setup file was found at:${NC}"
    echo "  $SETUP_PATH"
    echo
    echo "To fix the installer to find this file, create this wrapper:"
    echo
    cat << 'FIX_SCRIPT'
#!/bin/bash
# Save as: fix-orchestrator-paths.sh

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Create fixed orchestrator command
cat > ~/.local/bin/orchestrator-setup << EOF
#!/bin/bash
PROJECT_ROOT="$PROJECT_ROOT"
SETUP_SCRIPT="${SETUP_PATH#$PROJECT_ROOT/}"

if [ -f "\$PROJECT_ROOT/\$SETUP_SCRIPT" ]; then
    echo "Running production setup from: \$SETUP_SCRIPT"
    cd "\$(dirname "\$PROJECT_ROOT/\$SETUP_SCRIPT")"
    exec bash "\$(basename "\$SETUP_SCRIPT")"
else
    echo "Setup script not found at: \$PROJECT_ROOT/\$SETUP_SCRIPT"
    exit 1
fi
EOF

chmod +x ~/.local/bin/orchestrator-setup
echo "Fixed orchestrator-setup command created"
FIX_SCRIPT
else
    echo -e "${YELLOW}Production setup file not found in standard locations.${NC}"
    echo
    echo "Please check if the file exists with a different name or location:"
    echo "  find $PROJECT_ROOT -name '*production*.sh' -type f"
fi

echo
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}                   Diagnostic Complete${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}Summary:${NC}"
echo "• Project Root: $PROJECT_ROOT"

if [ "$found_setup" = true ]; then
    echo -e "• Production Setup: ${GREEN}Found${NC} at ${SETUP_PATH#$PROJECT_ROOT/}"
else
    echo -e "• Production Setup: ${RED}Not found${NC} in expected locations"
fi

if [ -n "${TANDEM_PATH:-}" ]; then
    echo -e "• Tandem Orchestrator: ${GREEN}Found${NC} at ${TANDEM_PATH#$PROJECT_ROOT/}"
else
    echo -e "• Tandem Orchestrator: ${RED}Not found${NC}"
fi

if [ -n "${PROD_ORCH_PATH:-}" ]; then
    echo -e "• Production Orchestrator: ${GREEN}Found${NC} at ${PROD_ORCH_PATH#$PROJECT_ROOT/}"
else
    echo -e "• Production Orchestrator: ${YELLOW}Not found${NC} (optional)"
fi

echo
echo "If files exist but aren't being found, please share the output above"
echo "so we can update the installer's search paths."
