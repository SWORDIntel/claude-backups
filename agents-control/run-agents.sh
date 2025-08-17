#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE AGENT COMMUNICATION SYSTEM LAUNCHER - FIXED VERSION
# Comprehensive launcher with compilation and optimization support
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/agent-system-$(date +%Y%m%d-%H%M%S).log"

# Possible agent directory locations
AGENT_SEARCH_PATHS=(
    "${SCRIPT_DIR}/agents"
    "${SCRIPT_DIR}/.local/share/claude/agents"
    "$HOME/.local/share/claude/agents"
    "$HOME/Documents/Claude/agents"
)

# Find agents directory
AGENTS_DIR=""
for path in "${AGENT_SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        AGENTS_DIR="$path"
        break
    fi
done

# Logging functions
log() { 
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

error() { 
    echo -e "${RED}[ERROR]${NC} $1" >&2 | tee -a "$LOG_FILE"
}

warn() { 
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2 | tee -a "$LOG_FILE"
}

success() { 
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Banner
show_banner() {
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}        Claude Agent Communication System Launcher              ${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

# CPU Feature Detection
detect_cpu_features() {
    log "Detecting CPU capabilities..."
    
    local cpu_flags=""
    
    if grep -q "avx512" /proc/cpuinfo 2>/dev/null; then
        cpu_flags="AVX512"
        echo -e "${GREEN}  ✓ AVX512 support detected${NC}"
    elif grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
        cpu_flags="AVX2"
        echo -e "${GREEN}  ✓ AVX2 support detected${NC}"
    elif grep -q "sse4_2" /proc/cpuinfo 2>/dev/null; then
        cpu_flags="SSE4.2"
        echo -e "${YELLOW}  ✓ SSE4.2 support detected${NC}"
    else
        cpu_flags="Generic"
        echo -e "${YELLOW}  ⚠ No advanced CPU features detected${NC}"
    fi
    
    echo "$cpu_flags"
}

# Check and compile agents if needed
compile_agents() {
    log "Checking agent binaries..."
    
    cd "$AGENTS_DIR"
    
    # Count existing binaries
    local binary_count=$(find . -type f -executable -name "*.out" -o -name "*.bin" 2>/dev/null | wc -l)
    
    if [ "$binary_count" -gt 0 ]; then
        success "Found $binary_count compiled agent binaries"
        return 0
    fi
    
    warn "No compiled binaries found. Attempting compilation..."
    
    # Check for Makefile
    if [ -f "Makefile" ]; then
        log "Found Makefile, building agents..."
        if make clean && make all 2>&1 | tee -a "$LOG_FILE"; then
            success "Agents compiled via Makefile"
        else
            warn "Makefile build had issues, trying direct compilation"
        fi
    fi
    
    # Try to compile C files directly
    local c_files=($(find . -name "*.c" -type f 2>/dev/null | head -20))
    local compiled=0
    
    if [ ${#c_files[@]} -gt 0 ]; then
        log "Found ${#c_files[@]} C source files to compile"
        
        mkdir -p build
        
        for src in "${c_files[@]}"; do
            local basename=$(basename "$src" .c)
            local output="build/${basename}"
            
            echo -n "  Compiling $basename... "
            
            if gcc -O2 -pthread "$src" -o "$output" -lm -lrt -lpthread 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                chmod +x "$output"
                compiled=$((compiled + 1))
            else
                echo -e "${RED}✗${NC}"
            fi
        done
        
        if [ "$compiled" -gt 0 ]; then
            success "Compiled $compiled agent binaries"
        else
            warn "Could not compile agent binaries"
        fi
    fi
    
    cd - > /dev/null
}

# Install dependencies
install_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    local optional_deps=()
    
    # Essential dependencies
    for tool in git gcc make; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    # Statusline dependencies
    for tool in jq bc curl wget; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            optional_deps+=("$tool")
        fi
    done
    
    # Report status
    if [ ${#missing_deps[@]} -eq 0 ]; then
        success "All essential dependencies installed"
    else
        warn "Missing essential tools: ${missing_deps[*]}"
        
        if command -v apt-get >/dev/null 2>&1; then
            echo -n "Install missing dependencies? (Y/n): "
            read -r response
            
            if [[ ! "$response" =~ ^[Nn]$ ]]; then
                log "Installing dependencies..."
                sudo apt-get update -qq >/dev/null 2>&1
                sudo apt-get install -y "${missing_deps[@]}" "${optional_deps[@]}" >/dev/null 2>&1 || {
                    warn "Some dependencies could not be installed"
                }
            fi
        fi
    fi
    
    if [ ${#optional_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}  ⚠ Optional tools missing: ${optional_deps[*]}${NC}"
        echo -e "${CYAN}    These enhance functionality but aren't required${NC}"
    fi
}

# Launch agent system
launch_agents() {
    log "Launching Agent Communication System..."
    
    cd "$AGENTS_DIR"
    
    # Check for BRING_ONLINE.sh
    if [ -f "BRING_ONLINE.sh" ]; then
        chmod +x "BRING_ONLINE.sh"
        success "Found BRING_ONLINE.sh launcher"
        
        echo
        echo -e "${CYAN}Starting agent infrastructure...${NC}"
        echo
        
        if ./BRING_ONLINE.sh 2>&1 | tee -a "$LOG_FILE"; then
            success "Agent Communication System is online!"
        else
            warn "Agent system started with warnings - check log for details"
        fi
    else
        # Fallback: Try to start individual components
        warn "BRING_ONLINE.sh not found, attempting manual startup..."
        
        # Look for agent executables
        local agents=($(find . -type f -executable -name "*agent*" 2>/dev/null | head -10))
        
        if [ ${#agents[@]} -gt 0 ]; then
            log "Found ${#agents[@]} agent executables"
            
            for agent in "${agents[@]}"; do
                local name=$(basename "$agent")
                echo -n "  Starting $name... "
                
                if nohup "$agent" >> "$LOG_FILE" 2>&1 & then
                    echo -e "${GREEN}✓${NC}"
                else
                    echo -e "${RED}✗${NC}"
                fi
            done
            
            success "Manual agent startup complete"
        else
            error "No agent executables found"
            echo
            echo "Please ensure agents are properly installed:"
            echo "  1. Run the main installer: bash paste.txt"
            echo "  2. Or compile manually: cd $AGENTS_DIR && make"
            exit 1
        fi
    fi
    
    cd - > /dev/null
}

# System status check
show_status() {
    echo -e "${CYAN}${BOLD}System Status:${NC}"
    echo
    
    # Agent directory
    if [ -n "$AGENTS_DIR" ]; then
        echo -e "  ${GREEN}✓${NC} Agents directory: $AGENTS_DIR"
        
        local md_count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
        local bin_count=$(find "$AGENTS_DIR" -type f -executable 2>/dev/null | wc -l)
        
        echo "    • Configurations: $md_count"
        echo "    • Executables: $bin_count"
    else
        echo -e "  ${RED}✗${NC} Agents directory not found"
    fi
    
    # Claude binary
    echo -n "  Claude Code: "
    if command -v claude >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Installed${NC}"
    else
        echo -e "${YELLOW}✗ Not found${NC}"
    fi
    
    # Running processes
    local agent_procs=$(pgrep -f "agent" 2>/dev/null | wc -l)
    if [ "$agent_procs" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Agent processes running: $agent_procs"
    else
        echo -e "  ${YELLOW}⚠${NC} No agent processes detected"
    fi
    
    echo
}

# Main menu
main_menu() {
    while true; do
        clear
        show_banner
        show_status
        
        echo "Choose an option:"
        echo
        echo "  1) Quick Launch - Start all agents"
        echo "  2) Compile Agents - Build from source"
        echo "  3) Install Dependencies"
        echo "  4) View Logs"
        echo "  5) Stop All Agents"
        echo "  6) Exit"
        echo
        
        echo -n "Enter your choice [1-6]: "
        read -r choice
        
        case "$choice" in
            1)
                if [ -n "$AGENTS_DIR" ]; then
                    launch_agents
                else
                    error "Agents directory not found"
                    echo "Please install agents first using the main installer"
                fi
                echo
                echo "Press ENTER to continue..."
                read -r
                ;;
            2)
                if [ -n "$AGENTS_DIR" ]; then
                    compile_agents
                else
                    error "Agents directory not found"
                fi
                echo
                echo "Press ENTER to continue..."
                read -r
                ;;
            3)
                install_dependencies
                echo
                echo "Press ENTER to continue..."
                read -r
                ;;
            4)
                if [ -f "$LOG_FILE" ]; then
                    less "$LOG_FILE"
                else
                    echo "No log file found"
                    echo "Press ENTER to continue..."
                    read -r
                fi
                ;;
            5)
                log "Stopping all agent processes..."
                pkill -f "agent" 2>/dev/null || true
                pkill -f "BRING_ONLINE" 2>/dev/null || true
                success "All agents stopped"
                echo "Press ENTER to continue..."
                read -r
                ;;
            6)
                echo -e "${GREEN}Exiting agent launcher${NC}"
                exit 0
                ;;
            *)
                error "Invalid choice"
                sleep 2
                ;;
        esac
    done
}

# Parse command line arguments
QUICK_MODE=false
COMPILE_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --compile|-c)
            COMPILE_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --quick, -q     Quick launch without menu"
            echo "  --compile, -c   Compile agents and exit"
            echo "  --help, -h      Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Main execution
show_banner

# Check if agents directory exists
if [ -z "$AGENTS_DIR" ] || [ ! -d "$AGENTS_DIR" ]; then
    error "Agent directory not found!"
    echo
    echo "Searched locations:"
    for path in "${AGENT_SEARCH_PATHS[@]}"; do
        echo "  • $path"
    done
    echo
    echo "Please install agents using the main installer:"
    echo "  bash paste.txt --auto-mode"
    exit 1
fi

log "Using agents directory: $AGENTS_DIR"

# Export for child processes
export CLAUDE_AGENTS_DIR="$AGENTS_DIR"

# Detect CPU features
CPU_FEATURES=$(detect_cpu_features)
log "CPU optimization level: $CPU_FEATURES"

# Handle different modes
if [ "$COMPILE_ONLY" = true ]; then
    compile_agents
    exit 0
elif [ "$QUICK_MODE" = true ]; then
    install_dependencies
    compile_agents
    launch_agents
else
    # Interactive menu
    main_menu
fi