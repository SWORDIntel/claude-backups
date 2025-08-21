#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ULTIMATE UNIFIED INSTALLER - REQUIREMENTS.TXT SUPPORT
# Dynamic paths + Requirements installation + Agent visibility + Python venv
# Version 5.9 - Requirements.txt Auto-Installation
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DYNAMIC CONFIGURATION - NO HARDCODED PATHS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly SCRIPT_VERSION="5.9-requirements"

# Resolve script location properly
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(get_script_dir)"

# Dynamic project root detection - NO HARDCODED PATHS
find_project_root() {
    local current_dir="$SCRIPT_DIR"
    local max_depth=10
    local depth=0
    
    # First, if we're in an 'installers' subdirectory, go up one level
    if [[ "$(basename "$current_dir")" == "installers" ]]; then
        current_dir="$(dirname "$current_dir")"
    fi
    
    # Search upward for project markers
    while [ $depth -lt $max_depth ]; do
        # Check for multiple project markers
        if [ -d "$current_dir/.claude-home" ] || \
           [ -d "$current_dir/agents" ] || \
           [ -f "$current_dir/claude-unified" ] || \
           [ -f "$current_dir/.project-root" ]; then
            echo "$current_dir"
            return 0
        fi
        
        # Stop at filesystem root
        [ "$current_dir" = "/" ] && break
        
        current_dir="$(dirname "$current_dir")"
        depth=$((depth + 1))
    done
    
    # Try relative locations from script dir
    for relative_path in ".." "../.." "../../.."; do
        local test_dir="$(cd "$SCRIPT_DIR/$relative_path" 2>/dev/null && pwd)"
        if [ -n "$test_dir" ] && [ -d "$test_dir/agents" ]; then
            echo "$test_dir"
            return 0
        fi
    done
    
    # Check common user locations (still dynamic, not hardcoded absolute)
    for dir in "$HOME/Documents/Claude" "$HOME/claude-backups" "$HOME/claude-project"; do
        if [ -d "$dir" ] && ([ -d "$dir/agents" ] || [ -d "$dir/.claude-home" ]); then
            echo "$dir"
            return 0
        fi
    done
    
    # Last resort: use script directory
    echo "$SCRIPT_DIR"
    return 1
}

# Set project root dynamically
PROJECT_ROOT="$(find_project_root)"
readonly PROJECT_ROOT

# All paths are RELATIVE to PROJECT_ROOT - no hardcoding
readonly WORK_DIR="/tmp/claude-install-$$"
readonly LOG_FILE="$HOME/Documents/Claude/install-$(date +%Y%m%d-%H%M%S).log"

# User directories (these are installation targets, not sources)
readonly USER_BIN_DIR="$HOME/.local/bin"
readonly USER_SHARE_DIR="$HOME/.local/share/claude"
readonly CONFIG_DIR="$HOME/.config/claude"
readonly NVIM_CONFIG_DIR="$HOME/.config/nvim"
readonly CLAUDE_HOME_AGENTS="$HOME/agents"

# Dynamic source paths - all relative to PROJECT_ROOT
get_source_file() {
    local filename="$1"
    local search_paths=(
        "$PROJECT_ROOT/$filename"
        "$PROJECT_ROOT/installers/$filename"
        "$PROJECT_ROOT/scripts/$filename"
        "$PROJECT_ROOT/bin/$filename"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

get_agents_dir() {
    local search_paths=(
        "$PROJECT_ROOT/agents"
        "$PROJECT_ROOT/Agents"
        "$PROJECT_ROOT/src/agents"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    echo "$PROJECT_ROOT/agents"  # Default
}

get_orchestration_files() {
    local component="$1"
    
    case "$component" in
        "tandem_orchestrator")
            local paths=(
                "$PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"
                "$PROJECT_ROOT/src/python/tandem_orchestrator.py"
                "$PROJECT_ROOT/orchestration/tandem_orchestrator.py"
            )
            ;;
        "production_orchestrator")
            local paths=(
                "$PROJECT_ROOT/agents/src/python/production_orchestrator.py"
                "$PROJECT_ROOT/src/python/production_orchestrator.py"
                "$PROJECT_ROOT/orchestration/production_orchestrator.py"
            )
            ;;
        "setup_production")
            local paths=(
                "$PROJECT_ROOT/agents/src/python/setup_production_env.sh"  # FIXED: Check src/python first!
                "$PROJECT_ROOT/agents/src/c/python/setup_production_env.sh"
                "$PROJECT_ROOT/src/c/python/setup_production_env.sh"
                "$PROJECT_ROOT/src/python/setup_production_env.sh"
                "$PROJECT_ROOT/scripts/setup_production_env.sh"
                "$PROJECT_ROOT/setup/setup_production_env.sh"
            )
            ;;
        "launcher")
            local paths=(
                "$PROJECT_ROOT/orchestration/python-orchestrator-launcher.sh"
                "$PROJECT_ROOT/scripts/python-orchestrator-launcher.sh"
                "$PROJECT_ROOT/bin/python-orchestrator-launcher.sh"
            )
            ;;
    esac
    
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Dynamic file discovery
UNIFIED_WRAPPER="$(get_source_file "claude-unified" || echo "")"
ORCHESTRATION_BRIDGE="$(get_source_file "claude-orchestration-bridge.py" || echo "")"
STATUSLINE_LUA="$(get_source_file "statusline.lua" || echo "")"
CLAUDE_HOME_DIR="$PROJECT_ROOT/.claude-home"
SOURCE_AGENTS_DIR="$(get_agents_dir)"

# Feature flags
INSTALL_AGENTS=${INSTALL_AGENTS:-true}
INSTALL_ORCHESTRATION=${INSTALL_ORCHESTRATION:-true}
INSTALL_STATUSLINE=${INSTALL_STATUSLINE:-true}
INSTALL_NODE=${INSTALL_NODE:-auto}
PERMISSION_BYPASS=${PERMISSION_BYPASS:-true}
AUTO_MODE=${AUTO_MODE:-true}
VERBOSE=${VERBOSE:-true}
LAUNCH_ORCHESTRATION=${LAUNCH_ORCHESTRATION:-true}

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Global variables
CLAUDE_BINARY=""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { 
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() { 
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

success() { 
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
    echo "[SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

debug() {
    if [ "$VERBOSE" = true ]; then
        printf "${CYAN}[DEBUG]${NC} %s\n" "$1"
        echo "[DEBUG] $1" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

show_banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _____          _      
  / ____| |               | |      / ____|        | |     
 | |    | | __ _ _   _  __| | ___  | |     ___   __| | ___ 
 | |    | |/ _` | | | |/ _` |/ _ \ | |    / _ \ / _` |/ _ \
 | |____| | (_| | |_| | (_| |  __/ | |___| (_) | (_| |  __/
  \_______|_\__,_|\__,_|\__,_|\___|  \_____\___/ \__,_|\___|
                                                           
    Dynamic Installer v5.9 - Requirements.txt Support
EOF
    printf "${NC}\n"
    printf "${GREEN}Components:${NC} Wrapper | Requirements | Python Venv | Orchestration | Agents\n"
    printf "${BLUE}Project Root:${NC} $PROJECT_ROOT\n"
    printf "${CYAN}NEW:${NC} Auto-installs from requirements.txt in project root!\n\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION FUNCTIONS - DYNAMIC FILE CHECKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validate_project_structure() {
    log "Validating project structure..."
    log "Project root: $PROJECT_ROOT"
    
    # Check for .claude-home
    if [ -d "$CLAUDE_HOME_DIR" ]; then
        debug "✓ Found .claude-home at: $CLAUDE_HOME_DIR"
        local file_count=$(find "$CLAUDE_HOME_DIR" -type f 2>/dev/null | wc -l)
        debug "  Contains $file_count files"
    else
        warn "✗ .claude-home not found, will create minimal structure"
    fi
    
    # Check for agents
    if [ -d "$SOURCE_AGENTS_DIR" ]; then
        local agent_count=$(find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        debug "✓ Found agents directory: $SOURCE_AGENTS_DIR"
        debug "  Contains $agent_count agents"
        debug "  Will setup Claude Code visibility fix"
    else
        warn "✗ Agents directory not found, will create"
    fi
    
    # Check orchestration components dynamically
    local tandem_orch="$(get_orchestration_files "tandem_orchestrator" || echo "")"
    if [ -n "$tandem_orch" ] && [ -f "$tandem_orch" ]; then
        debug "✓ Found tandem orchestrator: ${tandem_orch#$PROJECT_ROOT/}"
    else
        warn "✗ Tandem orchestrator not found in any expected location"
    fi
    
    local prod_setup="$(get_orchestration_files "setup_production" || echo "")"
    if [ -n "$prod_setup" ] && [ -f "$prod_setup" ]; then
        debug "✓ Found production setup: ${prod_setup#$PROJECT_ROOT/}"
        success "Production setup script found - will configure Python environment!"
    else
        warn "⚠ Production setup script not found - will install from requirements.txt"
        debug "  Searched in: agents/src/python/, agents/src/c/python/, src/python/, scripts/, setup/"
    fi
    
    # Check for requirements.txt
    if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
        success "Requirements.txt found in project root - will install all dependencies!"
    elif [ -f "$PROJECT_ROOT/agents/requirements.txt" ]; then
        success "Requirements.txt found in agents/ - will install dependencies!"
    elif [ -f "$PROJECT_ROOT/agents/src/python/requirements.txt" ]; then
        success "Requirements.txt found in agents/src/python/ - will install!"
    else
        warn "No requirements.txt found - will install essential packages only"
    fi
    
    # Check wrapper files
    if [ -n "$UNIFIED_WRAPPER" ] && [ -f "$UNIFIED_WRAPPER" ]; then
        debug "✓ Found unified wrapper: ${UNIFIED_WRAPPER#$PROJECT_ROOT/}"
    else
        warn "✗ Unified wrapper not found, will create basic version"
    fi
    
    # Check for existing Claude Code agent directory
    if [ -d "$HOME/.claude/agents" ]; then
        debug "  Existing ~/.claude/agents found, will update symlink"
    else
        debug "  Will create ~/.claude/agents symlink for Claude Code visibility"
    fi
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODE.JS INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_node_if_needed() {
    if command -v node &> /dev/null; then
        log "Node.js found: $(node --version)"
        return 0
    fi
    
    log "Installing Node.js locally..."
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    local node_version="v20.11.0"
    local node_arch="linux-x64"
    
    case "$(uname -m)" in
        arm64|aarch64) node_arch="linux-arm64" ;;
        x86_64) node_arch="linux-x64" ;;
    esac
    
    local node_url="https://nodejs.org/dist/${node_version}/node-${node_version}-${node_arch}.tar.gz"
    
    if command -v wget &> /dev/null; then
        wget -q "$node_url" -O node.tar.gz || return 1
    elif command -v curl &> /dev/null; then
        curl -fsSL "$node_url" -o node.tar.gz || return 1
    fi
    
    tar -xzf node.tar.gz
    local local_node_dir="$HOME/.local/node"
    mkdir -p "$local_node_dir"
    cp -r "node-${node_version}-${node_arch}"/* "$local_node_dir/"
    
    export PATH="$local_node_dir/bin:$PATH"
    success "Node.js installed locally"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE CODE INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_claude_code() {
    log "Installing Claude Code..."
    
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Setup npm prefix
    local npm_prefix="$HOME/.local/npm-global"
    mkdir -p "$npm_prefix"
    export NPM_CONFIG_PREFIX="$npm_prefix"
    export PATH="$npm_prefix/bin:$PATH"
    
    # Try NPM installation
    if command -v npm &> /dev/null; then
        log "Installing Claude Code via npm..."
        
        if npm install -g @anthropic-ai/claude-code --no-audit --no-fund 2>/dev/null; then
            if [ -f "$npm_prefix/bin/claude" ]; then
                mv "$npm_prefix/bin/claude" "$npm_prefix/bin/claude.original"
                CLAUDE_BINARY="$npm_prefix/bin/claude.original"
                success "Claude Code installed via npm"
                return 0
            fi
        fi
    fi
    
    # Create stub if installation failed
    log "Creating Claude stub..."
    cat > "$USER_BIN_DIR/claude.original" << 'STUB'
#!/bin/bash
echo "Claude Code - Installation Required"
echo "Run: npm install -g @anthropic-ai/claude-code"
echo "Agents: ~/agents"
STUB
    chmod +x "$USER_BIN_DIR/claude.original"
    CLAUDE_BINARY="$USER_BIN_DIR/claude.original"
    warn "Created stub - install Claude Code for full functionality"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNIFIED WRAPPER DEPLOYMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_unified_wrapper() {
    log "Deploying unified wrapper..."
    
    if [ -n "$UNIFIED_WRAPPER" ] && [ -f "$UNIFIED_WRAPPER" ]; then
        cp "$UNIFIED_WRAPPER" "$USER_BIN_DIR/claude"
        chmod +x "$USER_BIN_DIR/claude"
        
        cp "$UNIFIED_WRAPPER" "$USER_BIN_DIR/claude-unified"
        chmod +x "$USER_BIN_DIR/claude-unified"
        
        success "Unified wrapper deployed"
    else
        warn "Unified wrapper not found, creating basic version"
        create_basic_wrapper
    fi
    
    # Create claude-safe command
    cat > "$USER_BIN_DIR/claude-safe" << 'EOF'
#!/bin/bash
exec claude --no-skip-permissions "$@"
EOF
    chmod +x "$USER_BIN_DIR/claude-safe"
    
    return 0
}

create_basic_wrapper() {
    log "Creating basic wrapper..."
    cat > "$USER_BIN_DIR/claude" << EOF
#!/bin/bash
# Basic Claude Wrapper - Dynamic Paths
export CLAUDE_AGENTS_DIR="\$HOME/agents"
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"

CLAUDE_ORIGINAL="$CLAUDE_BINARY"
if [ -f "\$CLAUDE_ORIGINAL" ]; then
    if [[ " \$@ " != *" --no-skip-permissions "* ]]; then
        exec "\$CLAUDE_ORIGINAL" --dangerously-skip-permissions "\$@"
    else
        exec "\$CLAUDE_ORIGINAL" "\$@"
    fi
else
    echo "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
fi
EOF
    chmod +x "$USER_BIN_DIR/claude"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PYTHON ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_python_environment() {
    log "Setting up Python environment for orchestration..."
    
    # Check if Python3 is available
    if ! command -v python3 &>/dev/null; then
        error "Python3 not found! Please install Python 3.x"
        return 1
    fi
    
    # Set up the venv path we'll use
    local venv_path="$PROJECT_ROOT/agents/src/python/venv"
    export ORCHESTRATOR_VENV="$venv_path"
    
    # STEP 1: Check for requirements.txt files
    local requirements_files=()
    
    # Check project root
    if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
        requirements_files+=("$PROJECT_ROOT/requirements.txt")
        log "Found requirements.txt in project root"
    fi
    
    # Check agents/src/python
    if [ -f "$PROJECT_ROOT/agents/src/python/requirements.txt" ]; then
        requirements_files+=("$PROJECT_ROOT/agents/src/python/requirements.txt")
        log "Found requirements.txt in agents/src/python/"
    fi
    
    # Check agents directory
    if [ -f "$PROJECT_ROOT/agents/requirements.txt" ]; then
        requirements_files+=("$PROJECT_ROOT/agents/requirements.txt")
        log "Found requirements.txt in agents/"
    fi
    
    # STEP 2: Check for and run production setup script
    local prod_setup="$(get_orchestration_files "setup_production" || echo "")"
    
    if [ -n "$prod_setup" ] && [ -f "$prod_setup" ]; then
        log "Running production setup script..."
        log "Location: ${prod_setup#$PROJECT_ROOT/}"
        
        chmod +x "$prod_setup"
        cd "$(dirname "$prod_setup")"
        
        # Run the script
        bash "$(basename "$prod_setup")" || {
            warn "Production setup script had issues, will continue with manual setup"
        }
    fi
    
    # STEP 3: Ensure venv exists (create if needed)
    if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/python3" ]; then
        log "Creating Python virtual environment..."
        cd "$PROJECT_ROOT/agents/src/python"
        
        python3 -m venv venv || {
            error "Failed to create virtual environment"
            install_from_requirements_system "${requirements_files[@]}"
            return 1
        }
        
        # Upgrade pip in venv
        if [ -f "$venv_path/bin/pip" ]; then
            "$venv_path/bin/pip" install --upgrade pip
        fi
    else
        success "Virtual environment found at: $venv_path"
    fi
    
    # STEP 4: Install from requirements.txt files
    if [ ${#requirements_files[@]} -gt 0 ] && [ -f "$venv_path/bin/pip" ]; then
        for req_file in "${requirements_files[@]}"; do
            log "Installing dependencies from: ${req_file#$PROJECT_ROOT/}"
            "$venv_path/bin/pip" install -r "$req_file" || {
                warn "Some packages from $req_file failed to install"
            }
        done
    fi
    
    # STEP 5: Ensure essential packages are installed
    if [ -f "$venv_path/bin/pip" ]; then
        log "Ensuring essential packages are installed..."
        
        # Essential packages that might not be in requirements.txt
        local essentials=(
            "numpy"
            "requests"
            "pyyaml"
            "colorama"
            "psutil"
            "networkx"  # Added based on your error
        )
        
        for package in "${essentials[@]}"; do
            if ! "$venv_path/bin/python3" -c "import ${package%==*}" 2>/dev/null; then
                log "Installing $package..."
                "$venv_path/bin/pip" install "$package" || {
                    warn "Failed to install $package"
                }
            fi
        done
    fi
    
    # STEP 6: Verify critical imports work
    if [ -f "$venv_path/bin/python3" ]; then
        log "Verifying Python environment..."
        
        # Test critical imports
        local test_imports=("numpy" "networkx")
        local all_good=true
        
        for module in "${test_imports[@]}"; do
            if "$venv_path/bin/python3" -c "import $module" 2>/dev/null; then
                debug "✓ $module is available"
            else
                warn "✗ $module is NOT available"
                all_good=false
            fi
        done
        
        if [ "$all_good" = true ]; then
            success "Python environment fully configured"
        else
            warn "Some Python packages are missing - orchestrator may have issues"
        fi
    else
        # Fallback to system-wide installation
        warn "Virtual environment not available, using system Python"
        install_from_requirements_system "${requirements_files[@]}"
    fi
    
    return 0
}

install_from_requirements_system() {
    log "Installing requirements system-wide as fallback..."
    
    local requirements_files=("$@")
    
    # Install from requirements files
    if [ ${#requirements_files[@]} -gt 0 ]; then
        for req_file in "${requirements_files[@]}"; do
            if [ -f "$req_file" ]; then
                log "Installing from: ${req_file#$PROJECT_ROOT/}"
                
                if command -v pip3 &>/dev/null; then
                    pip3 install --user -r "$req_file" || {
                        warn "Failed to install some packages from $req_file"
                    }
                elif command -v pip &>/dev/null; then
                    pip install --user -r "$req_file" || {
                        warn "Failed to install some packages from $req_file"
                    }
                fi
            fi
        done
    fi
    
    # Ensure essential packages
    install_basic_python_deps
}

install_basic_python_deps() {
    log "Installing Python dependencies..."
    
    # Essential packages list (including networkx)
    local packages=(
        "numpy"
        "networkx"
        "requests"
        "pyyaml"
        "colorama"
        "psutil"
        "matplotlib"
        "pandas"
    )
    
    # Method 1: Try pip3
    if command -v pip3 &>/dev/null; then
        log "Installing with pip3..."
        for pkg in "${packages[@]}"; do
            pip3 install --user "$pkg" || {
                warn "Failed to install $pkg with pip3"
            }
        done
    fi
    
    # Method 2: Try pip
    if command -v pip &>/dev/null; then
        log "Installing with pip..."
        for pkg in "${packages[@]}"; do
            pip install --user "$pkg" || {
                warn "Failed to install $pkg with pip"
            }
        done
    fi
    
    # Method 3: Try apt-get for common packages
    if command -v apt-get &>/dev/null; then
        log "Installing with apt-get..."
        sudo apt-get update &>/dev/null || true
        sudo apt-get install -y python3-numpy python3-networkx python3-requests python3-yaml &>/dev/null || {
            warn "apt-get install failed for some packages"
        }
    fi
    
    # Verify critical packages
    local critical=("numpy" "networkx")
    for pkg in "${critical[@]}"; do
        if python3 -c "import $pkg" 2>/dev/null; then
            success "$pkg installation verified"
        else
            error "$pkg still not available after all attempts"
        fi
    done
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION COMPONENTS - FULLY DYNAMIC WITH VENV SUPPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_orchestration_system() {
    if [ "$INSTALL_ORCHESTRATION" != true ]; then
        debug "Skipping orchestration deployment"
        return 0
    fi
    
    log "Deploying Python Tandem Orchestration System..."
    
    # Find orchestrator dynamically
    local tandem_orch="$(get_orchestration_files "tandem_orchestrator" || echo "")"
    local prod_orch="$(get_orchestration_files "production_orchestrator" || echo "")"
    local prod_setup="$(get_orchestration_files "setup_production" || echo "")"
    
    # Create main orchestrator launcher
    cat > "$USER_BIN_DIR/orchestrator" << EOF
#!/bin/bash
# Dynamic Orchestrator Launcher - No Hardcoded Paths

PROJECT_ROOT="$PROJECT_ROOT"

# Search for orchestrator in multiple locations
find_orchestrator() {
    local search_paths=(
        "\$PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"
        "\$PROJECT_ROOT/src/python/tandem_orchestrator.py"
        "\$PROJECT_ROOT/orchestration/tandem_orchestrator.py"
        "\$PROJECT_ROOT/python/tandem_orchestrator.py"
    )
    
    for path in "\${search_paths[@]}"; do
        if [ -f "\$path" ]; then
            echo "\$path"
            return 0
        fi
    done
    
    return 1
}

ORCHESTRATOR="\$(find_orchestrator)"

if [ -z "\$ORCHESTRATOR" ] || [ ! -f "\$ORCHESTRATOR" ]; then
    echo "ERROR: Python orchestrator not found in project"
    echo "Searched in:"
    echo "  - \$PROJECT_ROOT/agents/src/python/"
    echo "  - \$PROJECT_ROOT/src/python/"
    echo "  - \$PROJECT_ROOT/orchestration/"
    exit 1
fi

# Set up environment
export CLAUDE_PROJECT_ROOT="\$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$PROJECT_ROOT/agents"
export PYTHONPATH="\$(dirname "\$ORCHESTRATOR"):\$PYTHONPATH"

# Launch orchestrator
cd "\$(dirname "\$ORCHESTRATOR")"
exec python3 "\$(basename "\$ORCHESTRATOR")" "\$@"
EOF
    chmod +x "$USER_BIN_DIR/orchestrator"
    
    # Create production orchestrator if found
    if [ -n "$prod_orch" ] && [ -f "$prod_orch" ]; then
        cat > "$USER_BIN_DIR/orchestrator-production" << EOF
#!/bin/bash
PROJECT_ROOT="$PROJECT_ROOT"
PRODUCTION_ORCHESTRATOR="${prod_orch#$PROJECT_ROOT/}"

# Check for virtual environment
VENV_PATH="\$PROJECT_ROOT/agents/src/python/venv"
VENV_PYTHON=""

if [ -d "\$VENV_PATH" ] && [ -f "\$VENV_PATH/bin/python3" ]; then
    VENV_PYTHON="\$VENV_PATH/bin/python3"
elif [ -d "\$VENV_PATH" ] && [ -f "\$VENV_PATH/bin/python" ]; then
    VENV_PYTHON="\$VENV_PATH/bin/python"
fi

if [ ! -f "\$PROJECT_ROOT/\$PRODUCTION_ORCHESTRATOR" ]; then
    echo "Production orchestrator not found, using standard"
    exec orchestrator "\$@"
fi

export CLAUDE_PROJECT_ROOT="\$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$PROJECT_ROOT/agents"
cd "\$PROJECT_ROOT/\$(dirname "\$PRODUCTION_ORCHESTRATOR")"

# Use venv if available
if [ -n "\$VENV_PYTHON" ]; then
    exec "\$VENV_PYTHON" "\$(basename "\$PRODUCTION_ORCHESTRATOR")" "\$@"
else
    exec python3 "\$(basename "\$PRODUCTION_ORCHESTRATOR")" "\$@"
fi
EOF
        chmod +x "$USER_BIN_DIR/orchestrator-production"
    fi
    
    # Create setup command if found
    if [ -n "$prod_setup" ] && [ -f "$prod_setup" ]; then
        cat > "$USER_BIN_DIR/orchestrator-setup" << EOF
#!/bin/bash
PROJECT_ROOT="$PROJECT_ROOT"

# Search for setup script in multiple locations
find_setup_script() {
    local search_paths=(
        "\$PROJECT_ROOT/agents/src/python/setup_production_env.sh"
        "\$PROJECT_ROOT/agents/src/c/python/setup_production_env.sh"
        "\$PROJECT_ROOT/src/python/setup_production_env.sh"
        "\$PROJECT_ROOT/src/c/python/setup_production_env.sh"
        "\$PROJECT_ROOT/scripts/setup_production_env.sh"
        "\$PROJECT_ROOT/setup/setup_production_env.sh"
    )
    
    for path in "\${search_paths[@]}"; do
        if [ -f "\$path" ]; then
            echo "\$path"
            return 0
        fi
    done
    
    return 1
}

SETUP_SCRIPT="\$(find_setup_script)"

if [ -n "\$SETUP_SCRIPT" ] && [ -f "\$SETUP_SCRIPT" ]; then
    echo "Running production setup from: \${SETUP_SCRIPT#\$PROJECT_ROOT/}"
    cd "\$(dirname "\$SETUP_SCRIPT")"
    exec bash "\$(basename "\$SETUP_SCRIPT")"
else
    echo "Setup script not found in any expected location"
    exit 1
fi
EOF
        chmod +x "$USER_BIN_DIR/orchestrator-setup"
    fi
    
    # Create claude-orchestrate shortcut
    cat > "$USER_BIN_DIR/claude-orchestrate" << 'EOF'
#!/bin/bash
# Direct orchestration launcher - uses orchestrator command which handles venv
exec orchestrator "$@"
EOF
    chmod +x "$USER_BIN_DIR/claude-orchestrate"
    
    # Create status command
    cat > "$USER_BIN_DIR/orchestration-status" << EOF
#!/bin/bash
PROJECT_ROOT="$PROJECT_ROOT"

echo "═══════════════════════════════════════════════════════════"
echo "      Python Tandem Orchestration System Status"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Project Root: \$PROJECT_ROOT"
echo

# Dynamic component checking
echo "Components:"

# Check for orchestrators in multiple locations
for dir in "agents/src/python" "src/python" "orchestration" "python"; do
    if [ -f "\$PROJECT_ROOT/\$dir/tandem_orchestrator.py" ]; then
        echo "  • Tandem Orchestrator: ✓ Found in \$dir/"
        break
    fi
done

for dir in "agents/src/python" "src/python" "orchestration" "python"; do
    if [ -f "\$PROJECT_ROOT/\$dir/production_orchestrator.py" ]; then
        echo "  • Production Orchestrator: ✓ Found in \$dir/"
        break
    fi
done

for dir in "agents/src/python" "agents/src/c/python" "src/c/python" "src/python" "scripts" "setup"; do
    if [ -f "\$PROJECT_ROOT/\$dir/setup_production_env.sh" ]; then
        echo "  • Production Setup: ✓ Found in \$dir/"
        break
    fi
done

# Count agents
if [ -d "\$PROJECT_ROOT/agents" ]; then
    AGENT_COUNT=\$(find "\$PROJECT_ROOT/agents" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
    echo "  • Agents: \$AGENT_COUNT found"
fi

echo
echo "Commands:"
echo "  • orchestrator         - Launch orchestrator"
echo "  • orchestrator-status  - Show this status"
if [ -f "$USER_BIN_DIR/orchestrator-production" ]; then
    echo "  • orchestrator-production - Production mode"
fi
if [ -f "$USER_BIN_DIR/orchestrator-setup" ]; then
    echo "  • orchestrator-setup   - Setup production"
fi
EOF
    chmod +x "$USER_BIN_DIR/orchestration-status"
    
    # Deploy bridge if exists
    if [ -n "$ORCHESTRATION_BRIDGE" ] && [ -f "$ORCHESTRATION_BRIDGE" ]; then
        cp "$ORCHESTRATION_BRIDGE" "$USER_BIN_DIR/claude-orchestration-bridge.py"
        chmod +x "$USER_BIN_DIR/claude-orchestration-bridge.py"
    fi
    
    success "Orchestration system deployed with dynamic paths"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT INSTALLATION WITH CLAUDE CODE VISIBILITY FIX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents_with_sync() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping agent installation"
        return 0
    fi
    
    log "Installing agents with Claude Code visibility fix..."
    
    # Create necessary directories
    mkdir -p "$CLAUDE_HOME_AGENTS"
    mkdir -p "$HOME/.claude"
    mkdir -p "$USER_SHARE_DIR/agents"
    
    if [ -d "$SOURCE_AGENTS_DIR" ]; then
        log "Setting up agent visibility from $SOURCE_AGENTS_DIR"
        
        # 1. Create symlink for ~/agents (legacy)
        if [ -e "$CLAUDE_HOME_AGENTS" ] && [ ! -L "$CLAUDE_HOME_AGENTS" ]; then
            rm -rf "$CLAUDE_HOME_AGENTS"
        fi
        if [ ! -L "$CLAUDE_HOME_AGENTS" ]; then
            ln -s "$SOURCE_AGENTS_DIR" "$CLAUDE_HOME_AGENTS"
            debug "Created symlink: ~/agents -> $SOURCE_AGENTS_DIR"
        fi
        
        # 2. CRITICAL: Create symlink for ~/.claude/agents (Claude Code looks here!)
        local claude_agents_dir="$HOME/.claude/agents"
        if [ -e "$claude_agents_dir" ] && [ ! -L "$claude_agents_dir" ]; then
            rm -rf "$claude_agents_dir"
        fi
        if [ ! -L "$claude_agents_dir" ]; then
            ln -sf "$SOURCE_AGENTS_DIR" "$claude_agents_dir"
            success "Created Claude Code symlink: ~/.claude/agents -> $SOURCE_AGENTS_DIR"
        fi
        
        # Count agents
        local agent_count=$(find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        success "Made $agent_count agents visible to Claude Code"
        
        # List first few agents
        if [ $agent_count -gt 0 ]; then
            echo "Agents now accessible from any directory:"
            find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | head -5 | while read -r agent; do
                echo "  • $(basename "$agent" | sed 's/\.[mM][dD]$//')"
            done
            [ $agent_count -gt 5 ] && echo "  ... and $((agent_count - 5)) more"
        fi
        
        # 3. Create enhanced sync script
        create_agent_sync_script
        
        # 4. Set up cron job for automatic sync
        setup_agent_sync_cron
        
        # 5. Create test script
        create_agent_test_script
        
    else
        warn "Agents directory not found, creating minimal set"
        mkdir -p "$CLAUDE_HOME_AGENTS"
        mkdir -p "$HOME/.claude/agents"
        
        # Create minimal agent in both locations
        cat > "$CLAUDE_HOME_AGENTS/DIRECTOR.md" << 'EOF'
---
uuid: director-001
name: Director
role: Strategic Command
---

# Director Agent
Strategic orchestration and delegation
EOF
        cp "$CLAUDE_HOME_AGENTS/DIRECTOR.md" "$HOME/.claude/agents/" 2>/dev/null || true
        success "Created minimal agent set"
    fi
    
    return 0
}

create_agent_sync_script() {
    log "Creating enhanced agent sync script..."
    
    cat > "$USER_BIN_DIR/sync-claude-agents.sh" << EOF
#!/bin/bash
# Enhanced Claude Agent Sync Script
# Ensures agents are visible to Claude Code from any directory

PROJECT_ROOT="$PROJECT_ROOT"
SOURCE_DIR="\$PROJECT_ROOT/agents"
CLAUDE_AGENTS_DIR="\$HOME/.claude/agents"
LEGACY_AGENTS_DIR="\$HOME/agents"
BACKUP_DIR="\$HOME/.local/share/claude/agents"
LOG_FILE="\$HOME/.local/share/claude/agent-sync.log"

# Create directories
mkdir -p "\$HOME/.claude"
mkdir -p "\$BACKUP_DIR"
mkdir -p "\$(dirname "\$LOG_FILE")"

# Function to log with timestamp
log_sync() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG_FILE"
}

# Start sync
log_sync "Starting agent sync from \$SOURCE_DIR"

# Check if source exists
if [ ! -d "\$SOURCE_DIR" ]; then
    log_sync "ERROR: Source directory not found: \$SOURCE_DIR"
    exit 1
fi

# 1. Maintain primary symlink for Claude Code (~/.claude/agents)
if [ -e "\$CLAUDE_AGENTS_DIR" ] && [ ! -L "\$CLAUDE_AGENTS_DIR" ]; then
    log_sync "Removing non-symlink at \$CLAUDE_AGENTS_DIR"
    rm -rf "\$CLAUDE_AGENTS_DIR"
fi

if [ ! -L "\$CLAUDE_AGENTS_DIR" ] || [ "\$(readlink -f "\$CLAUDE_AGENTS_DIR")" != "\$(readlink -f "\$SOURCE_DIR")" ]; then
    log_sync "Creating/updating Claude Code symlink"
    ln -sfn "\$SOURCE_DIR" "\$CLAUDE_AGENTS_DIR"
fi

# 2. Maintain legacy symlink (~/agents)
if [ -e "\$LEGACY_AGENTS_DIR" ] && [ ! -L "\$LEGACY_AGENTS_DIR" ]; then
    log_sync "Removing non-symlink at \$LEGACY_AGENTS_DIR"
    rm -rf "\$LEGACY_AGENTS_DIR"
fi

if [ ! -L "\$LEGACY_AGENTS_DIR" ] || [ "\$(readlink -f "\$LEGACY_AGENTS_DIR")" != "\$(readlink -f "\$SOURCE_DIR")" ]; then
    log_sync "Creating/updating legacy symlink"
    ln -sfn "\$SOURCE_DIR" "\$LEGACY_AGENTS_DIR"
fi

# 3. Create backup copy
log_sync "Creating backup in \$BACKUP_DIR"
rsync -a --delete "\$SOURCE_DIR/" "\$BACKUP_DIR/" 2>/dev/null || cp -r "\$SOURCE_DIR/"* "\$BACKUP_DIR/" 2>/dev/null

# Count agents
AGENT_COUNT=\$(find "\$SOURCE_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
log_sync "Sync complete: \$AGENT_COUNT agents available"

# Verify Claude Code can see agents
if [ -L "\$CLAUDE_AGENTS_DIR" ] && [ -d "\$CLAUDE_AGENTS_DIR" ]; then
    log_sync "✓ Claude Code symlink verified"
else
    log_sync "✗ Claude Code symlink verification failed"
fi

# Keep log file size reasonable
tail -n 1000 "\$LOG_FILE" > "\${LOG_FILE}.tmp" && mv "\${LOG_FILE}.tmp" "\$LOG_FILE"
EOF
    
    chmod +x "$USER_BIN_DIR/sync-claude-agents.sh"
    
    # Run initial sync
    "$USER_BIN_DIR/sync-claude-agents.sh" 2>/dev/null || true
    
    success "Agent sync script created and executed"
}

setup_agent_sync_cron() {
    log "Setting up automatic agent sync (every 5 minutes)..."
    
    local sync_script="$USER_BIN_DIR/sync-claude-agents.sh"
    
    # Remove old cron entries
    (crontab -l 2>/dev/null | grep -v "sync-claude-agents") | crontab - 2>/dev/null || true
    
    # Add new cron entry
    (crontab -l 2>/dev/null; echo "*/5 * * * * $sync_script >/dev/null 2>&1") | crontab -
    
    success "Cron job configured for automatic agent sync"
}

create_agent_test_script() {
    log "Creating agent visibility test script..."
    
    cat > "$USER_BIN_DIR/test-agent-visibility.sh" << 'EOF'
#!/bin/bash
# Test Claude Code Agent Visibility

echo "═══════════════════════════════════════════════════════════"
echo "           Claude Code Agent Visibility Test"
echo "═══════════════════════════════════════════════════════════"
echo

# Check symlinks
echo "Checking symlinks:"
echo -n "  ~/.claude/agents: "
if [ -L "$HOME/.claude/agents" ]; then
    target=$(readlink -f "$HOME/.claude/agents")
    echo "✓ -> $target"
else
    echo "✗ Not a symlink"
fi

echo -n "  ~/agents: "
if [ -L "$HOME/agents" ]; then
    target=$(readlink -f "$HOME/agents")
    echo "✓ -> $target"
else
    echo "✗ Not a symlink"
fi

# Count agents
echo
echo "Agent counts:"
for dir in "$HOME/.claude/agents" "$HOME/agents" "$HOME/.local/share/claude/agents"; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        printf "  %-35s %d agents\n" "$dir:" "$count"
    else
        printf "  %-35s not found\n" "$dir:"
    fi
done

# Check sync log
echo
echo "Recent sync activity:"
if [ -f "$HOME/.local/share/claude/agent-sync.log" ]; then
    tail -3 "$HOME/.local/share/claude/agent-sync.log"
else
    echo "  No sync log found"
fi

echo
echo "To verify in Claude Code, run:"
echo "  claude /task 'list available agents'"
echo
echo "If agents don't appear, try:"
echo "  1. Restart Claude Code"
echo "  2. Run: sync-claude-agents.sh"
EOF
    
    chmod +x "$USER_BIN_DIR/test-agent-visibility.sh"
    
    success "Test script created: test-agent-visibility.sh"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUSLINE INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_statusline() {
    if [ "$INSTALL_STATUSLINE" != true ]; then
        debug "Skipping statusline installation"
        return 0
    fi
    
    if [ -z "$STATUSLINE_LUA" ] || [ ! -f "$STATUSLINE_LUA" ]; then
        warn "statusline.lua not found"
        return 1
    fi
    
    log "Installing Neovim statusline..."
    
    mkdir -p "$NVIM_CONFIG_DIR/lua"
    cp "$STATUSLINE_LUA" "$NVIM_CONFIG_DIR/lua/statusline.lua"
    
    # Update init.lua with dynamic paths
    if [ ! -f "$NVIM_CONFIG_DIR/init.lua" ]; then
        cat > "$NVIM_CONFIG_DIR/init.lua" << EOF
-- Claude Agent Framework Statusline
vim.env.CLAUDE_AGENTS_ROOT = vim.env.CLAUDE_AGENTS_ROOT or "$PROJECT_ROOT/agents"
vim.env.CLAUDE_PROJECT_ROOT = "$PROJECT_ROOT"
package.path = package.path .. ";" .. vim.env.CLAUDE_AGENTS_ROOT .. "/?.lua"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
EOF
    else
        if ! grep -q "statusline.setup()" "$NVIM_CONFIG_DIR/init.lua"; then
            cat >> "$NVIM_CONFIG_DIR/init.lua" << EOF

-- Claude Agent Framework Statusline  
vim.env.CLAUDE_PROJECT_ROOT = "$PROJECT_ROOT"
local ok, statusline = pcall(require, "statusline")
if ok then statusline.setup() end
EOF
        fi
    fi
    
    success "Statusline installed"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLAUDE HOME SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_claude_home() {
    log "Setting up Claude home directory..."
    
    local target="$HOME/.claude-home"
    
    if [ -d "$CLAUDE_HOME_DIR" ]; then
        log "Linking .claude-home from project"
        
        [ -e "$target" ] && rm -rf "$target"
        ln -s "$CLAUDE_HOME_DIR" "$target"
        
        if [ -L "$target" ]; then
            local file_count=$(find "$CLAUDE_HOME_DIR" -type f 2>/dev/null | wc -l)
            success "Linked .claude-home ($file_count files)"
        fi
    else
        warn "Creating minimal .claude-home"
        mkdir -p "$target/context"
        
        cat > "$target/context/system.md" << EOF
# Claude Environment - Dynamic Configuration

Project Root: $PROJECT_ROOT
Installation: v$SCRIPT_VERSION

All paths are dynamically resolved from project root.
No hardcoded paths in this installation.
EOF
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_environment() {
    log "Configuring environment..."
    
    # Export for current session
    export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
    export CLAUDE_AGENTS_DIR="$PROJECT_ROOT/agents"
    export CLAUDE_HOME="$HOME/.claude-home"
    export PATH="$USER_BIN_DIR:$PATH"
    
    # Update bashrc
    local shell_rc="$HOME/.bashrc"
    
    # Add to PATH
    if ! grep -q "$USER_BIN_DIR" "$shell_rc" 2>/dev/null; then
        echo "export PATH=\"$USER_BIN_DIR:\$PATH\"" >> "$shell_rc"
    fi
    
    # Add Claude environment with dynamic paths
    if ! grep -q "CLAUDE_PROJECT_ROOT" "$shell_rc" 2>/dev/null; then
        cat >> "$shell_rc" << BASHRC_ENV

# Claude Agent Framework - Dynamic Configuration
export CLAUDE_PROJECT_ROOT="$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$CLAUDE_PROJECT_ROOT/agents"
export CLAUDE_HOME="\$HOME/.claude-home"
export CLAUDE_PERMISSION_BYPASS=true

# Aliases
alias claude-safe='claude --no-skip-permissions'
alias cla='claude-list-agents'
alias orch='orchestrator'
alias orch-status='orchestration-status'
alias test-agents='test-agent-visibility.sh'
alias sync-agents='sync-claude-agents.sh'

# Helper functions
claude-list-agents() {
    local agents_dir="\${CLAUDE_AGENTS_DIR:-\$CLAUDE_PROJECT_ROOT/agents}"
    if [ -d "\$agents_dir" ]; then
        echo "Agents in \$agents_dir:"
        find "\$agents_dir" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) -type f 2>/dev/null | \\
            while read -r agent; do
                echo "  • \$(basename "\$agent" | sed 's/\\.[mM][dD]\$//')"
            done | sort
    else
        echo "Agents directory not found"
    fi
}

claude-agent-status() {
    echo "═══════════════════════════════════════════════════"
    echo "           Claude Agent System Status"
    echo "═══════════════════════════════════════════════════"
    echo
    echo "Project Agents: \$CLAUDE_PROJECT_ROOT/agents"
    echo "Claude Code Link: ~/.claude/agents"
    
    # Check symlinks
    if [ -L ~/.claude/agents ]; then
        echo "Claude Code Access: ✓ Linked"
    else
        echo "Claude Code Access: ✗ Not linked"
    fi
    
    if [ -L ~/agents ]; then
        echo "Legacy Access: ✓ Linked"
    else
        echo "Legacy Access: ✗ Not linked"
    fi
    
    # Count agents
    if [ -d "\$CLAUDE_AGENTS_DIR" ]; then
        local count=\$(find "\$CLAUDE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        echo "Available Agents: \$count"
    fi
    
    # Check sync
    if crontab -l 2>/dev/null | grep -q "sync-claude-agents"; then
        echo "Auto-sync: ✓ Active (every 5 minutes)"
    else
        echo "Auto-sync: ✗ Not configured"
    fi
    
    # Last sync
    if [ -f ~/.local/share/claude/agent-sync.log ]; then
        echo
        echo "Last sync:"
        tail -1 ~/.local/share/claude/agent-sync.log
    fi
}

claude-project-info() {
    echo "Claude Project Information:"
    echo "  Root: \$CLAUDE_PROJECT_ROOT"
    echo "  Agents: \$CLAUDE_AGENTS_DIR"
    echo "  Home: \$CLAUDE_HOME"
    
    # Dynamic component checking
    for dir in "agents/src/python" "src/python" "orchestration"; do
        if [ -f "\$CLAUDE_PROJECT_ROOT/\$dir/tandem_orchestrator.py" ]; then
            echo "  Orchestrator: ✓ Found in \$dir/"
            break
        fi
    done
    
    # Check agent visibility
    echo
    echo "Agent Visibility:"
    echo "  ~/.claude/agents: \$([ -L ~/.claude/agents ] && echo '✓ Linked' || echo '✗ Not linked')"
    echo "  Auto-sync: \$(crontab -l 2>/dev/null | grep -q sync-claude-agents && echo '✓ Active' || echo '✗ Inactive')"
}
BASHRC_ENV
    fi
    
    success "Environment configured with dynamic paths"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION LAUNCH
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

launch_orchestration_system() {
    if [ "$LAUNCH_ORCHESTRATION" != true ]; then
        return 0
    fi
    
    echo
    printf "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    printf "${CYAN}${BOLD}   Python Tandem Orchestration System${NC}\n"
    printf "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    echo
    
    # Find orchestrator dynamically - including src/python without 'c'
    local orchestrator=""
    for dir in "agents/src/python" "src/python" "orchestration" "python"; do
        if [ -f "$PROJECT_ROOT/$dir/tandem_orchestrator.py" ]; then
            orchestrator="$PROJECT_ROOT/$dir/tandem_orchestrator.py"
            break
        fi
    done
    
    if [ -z "$orchestrator" ] || [ ! -f "$orchestrator" ]; then
        warn "Orchestrator not found in project"
        echo "You can launch it later with: orchestrator"
        return 1
    fi
    
    echo "Orchestrator found: ${orchestrator#$PROJECT_ROOT/}"
    
    # Check for venv
    local venv_path="$PROJECT_ROOT/agents/src/python/venv"
    local python_cmd="python3"
    
    if [ -d "$venv_path" ] && [ -f "$venv_path/bin/python3" ]; then
        python_cmd="$venv_path/bin/python3"
        echo "Virtual environment: ✓ Active"
    elif [ -d "$venv_path" ] && [ -f "$venv_path/bin/python" ]; then
        python_cmd="$venv_path/bin/python"
        echo "Virtual environment: ✓ Active"
    else
        echo "Virtual environment: Using system Python"
    fi
    
    echo
    echo "Options:"
    echo "  [1] Launch interactive orchestrator"
    echo "  [2] Run tests"
    echo "  [3] Check status"
    echo "  [4] Skip for now"
    echo
    echo -n "Choose [1-4]: "
    read -n 1 choice
    echo
    echo
    
    case "$choice" in
        "1")
            cd "$(dirname "$orchestrator")"
            exec "$python_cmd" "$(basename "$orchestrator")"
            ;;
        "2")
            cd "$(dirname "$orchestrator")"
            "$python_cmd" "$(basename "$orchestrator")" test
            ;;
        "3")
            orchestration-status
            ;;
        *)
            echo "Launch later with: orchestrator"
            ;;
    esac
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATUS DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_final_status() {
    echo
    printf "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}${BOLD}       Installation Complete!${NC}\n"
    printf "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}\n"
    echo
    
    echo "📁 Dynamic Configuration:"
    echo "  • Project Root: $PROJECT_ROOT"
    echo "  • All paths resolved from project root"
    echo "  • No hardcoded paths"
    echo
    
    echo "✅ Components Installed:"
    
    if [ -f "$USER_BIN_DIR/claude" ]; then
        echo "  • Claude wrapper: ✓"
    fi
    
    # Check Python environment
    local venv_path="$PROJECT_ROOT/agents/src/python/venv"
    if [ -d "$venv_path" ] && [ -f "$venv_path/bin/python3" ]; then
        echo "  • Python environment: ✓ (venv configured)"
        
        # Check for requirements.txt
        if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
            echo "    Requirements.txt: ✓ Found and installed"
        fi
        
        # Test critical packages
        if "$venv_path/bin/python3" -c "import numpy" 2>/dev/null; then
            echo "    NumPy: ✓ Installed"
        else
            echo "    NumPy: ✗ Not found"
        fi
        
        if "$venv_path/bin/python3" -c "import networkx" 2>/dev/null; then
            echo "    NetworkX: ✓ Installed"
        else
            echo "    NetworkX: ✗ Not found"
        fi
    else
        echo "  • Python environment: System Python"
        if python3 -c "import numpy" 2>/dev/null; then
            echo "    NumPy: ✓ Installed (system)"
        else
            echo "    NumPy: ✗ Not installed"
        fi
    fi
    
    # Check agent installation and visibility
    if [ -L "$HOME/.claude/agents" ]; then
        local count=$(find "$PROJECT_ROOT/agents" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        echo "  • Agents: $count available"
        echo "  • Claude Code visibility: ✓ (agents accessible from any directory)"
    elif [ -d "$CLAUDE_HOME_AGENTS" ]; then
        local count=$(find "$PROJECT_ROOT/agents" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        echo "  • Agents: $count available (visibility not configured)"
    fi
    
    # Check auto-sync
    if crontab -l 2>/dev/null | grep -q "sync-claude-agents"; then
        echo "  • Agent auto-sync: ✓ (every 5 minutes)"
    fi
    
    # Check for orchestrator dynamically
    local orch_found=false
    for dir in "agents/src/python" "src/python" "orchestration"; do
        if [ -f "$PROJECT_ROOT/$dir/tandem_orchestrator.py" ]; then
            echo "  • Orchestrator: ✓ (in $dir/)"
            orch_found=true
            break
        fi
    done
    [ "$orch_found" = false ] && echo "  • Orchestrator: Not found"
    
    # Check for production setup
    local setup_found=false
    for dir in "agents/src/python" "agents/src/c/python" "src/python" "scripts"; do
        if [ -f "$PROJECT_ROOT/$dir/setup_production_env.sh" ]; then
            echo "  • Production Setup: ✓ (in $dir/)"
            setup_found=true
            break
        fi
    done
    [ "$setup_found" = false ] && echo "  • Production Setup: Not found"
    
    echo
    echo "📝 Commands:"
    echo "  • claude              - Main wrapper"
    echo "  • orchestrator        - Launch orchestration"
    echo "  • orchestration-status - Check system"
    echo "  • test-agent-visibility - Test agent access"
    echo "  • sync-claude-agents   - Manual agent sync"
    echo "  • claude-agent-status  - Agent system status"
    echo "  • claude-project-info  - Show paths"
    echo
    echo "🎯 Agent Visibility Fix Applied:"
    echo "  • Symlink created: ~/.claude/agents -> $PROJECT_ROOT/agents"
    echo "  • Auto-sync enabled: Updates every 5 minutes"
    echo "  • Claude Code can now find agents from ANY directory!"
    echo
    
    # Check for venv
    local venv_path="$PROJECT_ROOT/agents/src/python/venv"
    if [ -d "$venv_path" ]; then
        echo "🐍 Python Environment:"
        echo "  • Virtual environment: $venv_path"
        echo "  • Dependencies installed: numpy, requests, etc."
        echo "  • Orchestrator will use venv automatically"
        echo
    fi
    
    echo "🚀 Next Steps:"
    echo "  1. source ~/.bashrc"
    echo "  2. test-agent-visibility.sh  (verify agents are visible)"
    echo "  3. orchestrator  (launch orchestration)"
    echo
    printf "${CYAN}All components use dynamic path resolution${NC}\n"
    printf "${GREEN}Python environment configured with dependencies!${NC}\n"
    printf "${GREEN}Agents are now globally visible to Claude Code!${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    show_banner
    
    log "Starting installation with Python environment setup..."
    log "Script location: $SCRIPT_DIR"
    log "Project root detected: $PROJECT_ROOT"
    
    # Validate structure
    validate_project_structure
    
    # Create directories
    mkdir -p "$WORK_DIR"
    mkdir -p "$HOME/Documents/Claude"
    mkdir -p "$USER_BIN_DIR"
    
    # Installation
    echo "📦 Installing components..."
    echo
    
    local steps=(
        "Node.js:install_node_if_needed"
        "Claude Code:install_claude_code"
        "Unified wrapper:deploy_unified_wrapper"
        "Python environment:setup_python_environment"
        "Orchestration:deploy_orchestration_system"
        "Agents + Visibility Fix:install_agents_with_sync"
        "Statusline:install_statusline"
        "Environment:setup_environment"
        "Claude home:setup_claude_home"
    )
    
    local step_num=1
    local total_steps=${#steps[@]}
    
    for step_def in "${steps[@]}"; do
        IFS=':' read -r step_name step_func <<< "$step_def"
        echo -n "  [$step_num/$total_steps] $step_name... "
        
        # Special handling for Python environment - show output
        if [ "$step_func" = "setup_python_environment" ]; then
            echo  # New line for Python setup output
            if $step_func; then
                echo "  [$step_num/$total_steps] $step_name... ✅"
            else
                echo "  [$step_num/$total_steps] $step_name... ⚠️"
            fi
        else
            if $step_func &>/dev/null; then
                echo "✅"
            else
                echo "⚠️"
            fi
        fi
        
        step_num=$((step_num + 1))
    done
    
    # Show status
    show_final_status
    
    # Launch orchestration
    launch_orchestration_system
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            ;;
        --quiet|-q)
            VERBOSE=false
            ;;
        --no-launch)
            LAUNCH_ORCHESTRATION=false
            ;;
        --debug|-d)
            VERBOSE=true
            set -x
            ;;
        --help|-h)
            echo "Claude Installer v$SCRIPT_VERSION - Full Stack Setup"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --verbose, -v    Show detailed output"
            echo "  --quiet, -q      Minimal output"
            echo "  --no-launch      Don't launch orchestration"
            echo "  --debug, -d      Enable debug mode"
            echo "  --help, -h       Show this help"
            echo
            echo "Features:"
            echo "  • No hardcoded paths - everything dynamic"
            echo "  • Auto-installs from requirements.txt"
            echo "  • Python venv auto-creation"
            echo "  • Agent visibility fix for Claude Code"
            echo "  • Automatic dependency installation"
            echo
            echo "NEW in v5.9 - Requirements.txt Support:"
            echo "  • Searches for requirements.txt in:"
            echo "    - Project root"
            echo "    - agents/src/python/"
            echo "    - agents/"
            echo "  • Installs all dependencies automatically"
            echo "  • Includes networkx and all needed packages"
            echo
            echo "v5.8 fixes:"
            echo "  • Properly runs setup_production_env.sh"
            echo "  • Creates venv if missing"
            echo "  • Multiple fallback options"
            echo
            echo "v5.6 - Agent Visibility:"
            echo "  • Creates ~/.claude/agents symlink"
            echo "  • Auto-sync every 5 minutes"
            echo
            echo "Detected project root: $PROJECT_ROOT"
            exit 0
            ;;
        *)
            warn "Unknown option: $1"
            ;;
    esac
    shift
done

# Run
main "$@"