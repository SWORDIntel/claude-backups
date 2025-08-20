#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE ULTIMATE UNIFIED INSTALLER - DYNAMIC PATH DETECTION
# No hardcoded paths - everything relative to detected PROJECT_ROOT
# Version 5.4 - Fully Dynamic Path Resolution
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DYNAMIC CONFIGURATION - NO HARDCODED PATHS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly SCRIPT_VERSION="5.4-dynamic"

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

# Python venv path
readonly VENV_DIR="$HOME/.local/share/claude/venv"

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
                "$PROJECT_ROOT/agents/src/python/production_orchestrator.py"
                "$PROJECT_ROOT/src/python/tandem_orchestrator.py"
                "$PROJECT_ROOT/orchestration/tandem_orchestrator.py"
                "$PROJECT_ROOT/python/tandem_orchestrator.py"
            )
            ;;
        "production_orchestrator")
            local paths=(
                "$PROJECT_ROOT/agents/src/python/production_orchestrator.py"
                "$PROJECT_ROOT/src/python/production_orchestrator.py"
                "$PROJECT_ROOT/orchestration/production_orchestrator.py"
                "$PROJECT_ROOT/python/production_orchestrator.py"
            )
            ;;
        "setup_production")
            local paths=(
                "$PROJECT_ROOT/agents/src/c/python/setup_production_env.sh"
                "$PROJECT_ROOT/src/c/python/setup_production_env.sh"
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
                                                           
    Dynamic Installer v5.4 - No Hardcoded Paths
EOF
    printf "${NC}\n"
    printf "${GREEN}Components:${NC} Unified Wrapper | Python Orchestration | Agents | Statusline\n"
    printf "${BLUE}Project Root:${NC} $PROJECT_ROOT\n\n"
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
    else
        warn "⚠ Production setup not found (optional component)"
    fi
    
    # Check wrapper files
    if [ -n "$UNIFIED_WRAPPER" ] && [ -f "$UNIFIED_WRAPPER" ]; then
        debug "✓ Found unified wrapper: ${UNIFIED_WRAPPER#$PROJECT_ROOT/}"
    else
        warn "✗ Unified wrapper not found, will create basic version"
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
# PYTHON VIRTUAL ENVIRONMENT SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_python_venv() {
    log "Setting up Python virtual environment..."
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
        return 1
    fi
    
    # Create venv directory if it doesn't exist
    mkdir -p "$(dirname "$VENV_DIR")"
    
    # Create virtual environment
    if [ ! -d "$VENV_DIR" ]; then
        log "Creating virtual environment at $VENV_DIR..."
        python3 -m venv "$VENV_DIR" || {
            error "Failed to create virtual environment"
            return 1
        }
        success "Virtual environment created"
    else
        debug "Virtual environment already exists at $VENV_DIR"
    fi
    
    # Activate venv and upgrade pip
    log "Activating virtual environment and upgrading pip..."
    source "$VENV_DIR/bin/activate"
    python3 -m pip install --upgrade pip setuptools wheel &> /dev/null || {
        warn "Failed to upgrade pip/setuptools/wheel"
    }
    
    # Install requirements.txt if it exists
    local requirements_files=(
        "$PROJECT_ROOT/requirements.txt"
        "$PROJECT_ROOT/agents/requirements.txt"
        "$PROJECT_ROOT/orchestration/requirements.txt"
    )
    
    local installed_requirements=false
    for req_file in "${requirements_files[@]}"; do
        if [ -f "$req_file" ]; then
            log "Installing dependencies from ${req_file#$PROJECT_ROOT/}..."
            # Show progress for large requirements files
            if command -v pv &> /dev/null; then
                python3 -m pip install -r "$req_file" 2>&1 | pv -l -s $(wc -l < "$req_file") > /dev/null || {
                    warn "Some dependencies from ${req_file#$PROJECT_ROOT/} failed to install"
                }
            else
                python3 -m pip install -r "$req_file" || {
                    warn "Some dependencies from ${req_file#$PROJECT_ROOT/} failed to install"
                }
            fi
            installed_requirements=true
        fi
    done
    
    if [ "$installed_requirements" = false ]; then
        log "No requirements.txt found, installing basic dependencies..."
        python3 -m pip install aiofiles aiohttp asyncpg PyYAML rich click psutil &> /dev/null || {
            warn "Failed to install basic dependencies"
        }
    fi
    
    success "Python environment setup complete"
    
    # Create activation script for users
    cat > "$USER_BIN_DIR/claude-venv" << EOF
#!/bin/bash
# Activate Claude Python virtual environment
source "$VENV_DIR/bin/activate"
echo "Claude virtual environment activated"
echo "Python: \$(which python3)"
echo "Pip: \$(which pip3)"
EOF
    chmod +x "$USER_BIN_DIR/claude-venv"
    
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORCHESTRATION COMPONENTS - FULLY DYNAMIC
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
# Dynamic Orchestrator Launcher with Virtual Environment

PROJECT_ROOT="$PROJECT_ROOT"
VENV_DIR="$VENV_DIR"

# Activate virtual environment if it exists
if [ -d "\$VENV_DIR" ] && [ -f "\$VENV_DIR/bin/activate" ]; then
    source "\$VENV_DIR/bin/activate"
fi

# Search for orchestrator in multiple locations
find_orchestrator() {
    local search_paths=(
        "\$PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"
        "\$PROJECT_ROOT/agents/src/python/production_orchestrator.py"
        "\$PROJECT_ROOT/src/python/tandem_orchestrator.py"
        "\$PROJECT_ROOT/src/python/production_orchestrator.py"
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
    echo ""
    echo "Available Python files:"
    find "\$PROJECT_ROOT" -name "*orchestrator*.py" -type f 2>/dev/null | head -10
    exit 1
fi

# Set up environment
export CLAUDE_PROJECT_ROOT="\$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$PROJECT_ROOT/agents"
export PYTHONPATH="\$(dirname "\$ORCHESTRATOR"):\$PROJECT_ROOT/agents/src/python:\$PYTHONPATH"

echo "Using orchestrator: \${ORCHESTRATOR#\$PROJECT_ROOT/}"
echo "Python: \$(which python3)"

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
VENV_DIR="$VENV_DIR"
PRODUCTION_ORCHESTRATOR="${prod_orch#$PROJECT_ROOT/}"

# Activate virtual environment if it exists
if [ -d "\$VENV_DIR" ] && [ -f "\$VENV_DIR/bin/activate" ]; then
    source "\$VENV_DIR/bin/activate"
fi

if [ ! -f "\$PROJECT_ROOT/\$PRODUCTION_ORCHESTRATOR" ]; then
    echo "Production orchestrator not found, using standard"
    exec orchestrator "\$@"
fi

export CLAUDE_PROJECT_ROOT="\$PROJECT_ROOT"
export CLAUDE_AGENTS_DIR="\$PROJECT_ROOT/agents"
export PYTHONPATH="\$PROJECT_ROOT/\$(dirname "\$PRODUCTION_ORCHESTRATOR"):\$PROJECT_ROOT/agents/src/python:\$PYTHONPATH"

echo "Using production orchestrator: \$PRODUCTION_ORCHESTRATOR"
echo "Python: \$(which python3)"

cd "\$PROJECT_ROOT/\$(dirname "\$PRODUCTION_ORCHESTRATOR")"
exec python3 "\$(basename "\$PRODUCTION_ORCHESTRATOR")" "\$@"
EOF
        chmod +x "$USER_BIN_DIR/orchestrator-production"
    fi
    
    # Create setup command if found
    if [ -n "$prod_setup" ] && [ -f "$prod_setup" ]; then
        cat > "$USER_BIN_DIR/orchestrator-setup" << EOF
#!/bin/bash
PROJECT_ROOT="$PROJECT_ROOT"
SETUP_SCRIPT="${prod_setup#$PROJECT_ROOT/}"

if [ -f "\$PROJECT_ROOT/\$SETUP_SCRIPT" ]; then
    cd "\$PROJECT_ROOT/\$(dirname "\$SETUP_SCRIPT")"
    exec bash "\$(basename "\$SETUP_SCRIPT")"
else
    echo "Setup script not found"
    exit 1
fi
EOF
        chmod +x "$USER_BIN_DIR/orchestrator-setup"
    fi
    
    # Create claude-orchestrate shortcut
    cat > "$USER_BIN_DIR/claude-orchestrate" << 'EOF'
#!/bin/bash
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

for dir in "agents/src/c/python" "src/c/python" "scripts" "setup"; do
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
# AGENT INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_agents_with_sync() {
    if [ "$INSTALL_AGENTS" != true ]; then
        debug "Skipping agent installation"
        return 0
    fi
    
    log "Installing agents..."
    
    # Create ~/agents directory
    mkdir -p "$CLAUDE_HOME_AGENTS"
    
    if [ -d "$SOURCE_AGENTS_DIR" ]; then
        log "Linking agents from $SOURCE_AGENTS_DIR"
        
        # Remove old ~/agents if it exists and isn't a symlink
        if [ -e "$CLAUDE_HOME_AGENTS" ] && [ ! -L "$CLAUDE_HOME_AGENTS" ]; then
            rm -rf "$CLAUDE_HOME_AGENTS"
        fi
        
        # Create symlink
        if [ ! -L "$CLAUDE_HOME_AGENTS" ]; then
            ln -s "$SOURCE_AGENTS_DIR" "$CLAUDE_HOME_AGENTS"
        fi
        
        local agent_count=$(find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        success "Linked $agent_count agents from project"
        
        # List first few agents
        if [ $agent_count -gt 0 ]; then
            echo "Discovered agents:"
            find "$SOURCE_AGENTS_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | head -5 | while read -r agent; do
                echo "  • $(basename "$agent" | sed 's/\.[mM][dD]$//')"
            done
        fi
    else
        warn "Agents directory not found, creating minimal set"
        mkdir -p "$CLAUDE_HOME_AGENTS"
        
        # Create minimal agent
        cat > "$CLAUDE_HOME_AGENTS/DIRECTOR.md" << 'EOF'
---
uuid: director-001
name: Director
role: Strategic Command
---

# Director Agent
Strategic orchestration and delegation
EOF
        success "Created minimal agent set"
    fi
    
    return 0
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
    
    # Activate virtual environment if it exists
    if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
        echo "Virtual environment activated"
    fi
    
    # Find orchestrator dynamically - prefer production_orchestrator
    local orchestrator=""
    for dir in "agents/src/python" "src/python" "orchestration" "python"; do
        # First try production_orchestrator
        if [ -f "$PROJECT_ROOT/$dir/production_orchestrator.py" ]; then
            orchestrator="$PROJECT_ROOT/$dir/production_orchestrator.py"
            break
        fi
        # Fall back to tandem_orchestrator
        if [ -f "$PROJECT_ROOT/$dir/tandem_orchestrator.py" ]; then
            orchestrator="$PROJECT_ROOT/$dir/tandem_orchestrator.py"
            break
        fi
    done
    
    if [ -z "$orchestrator" ] || [ ! -f "$orchestrator" ]; then
        warn "Orchestrator not found in project"
        echo "Available Python files:"
        find "$PROJECT_ROOT" -name "*orchestrator*.py" -type f 2>/dev/null | head -10
        echo ""
        echo "You can launch it later with: orchestrator"
        return 1
    fi
    
    echo "Orchestrator found: ${orchestrator#$PROJECT_ROOT/}"
    echo "Python: $(which python3)"
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
    
    # Set up Python path
    export PYTHONPATH="$(dirname "$orchestrator"):$PROJECT_ROOT/agents/src/python:$PYTHONPATH"
    
    case "$choice" in
        "1")
            cd "$(dirname "$orchestrator")"
            exec python3 "$(basename "$orchestrator")"
            ;;
        "2")
            cd "$(dirname "$orchestrator")"
            python3 "$(basename "$orchestrator")" test
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
    
    if [ -L "$CLAUDE_HOME_AGENTS" ] || [ -d "$CLAUDE_HOME_AGENTS" ]; then
        local count=$(find "$PROJECT_ROOT/agents" -maxdepth 1 \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l || echo 0)
        echo "  • Agents: $count available"
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
    
    echo
    echo "📝 Commands:"
    echo "  • claude              - Main wrapper"
    echo "  • orchestrator        - Launch orchestration"
    echo "  • orchestration-status - Check system"
    echo "  • claude-project-info  - Show paths"
    echo "  • claude-venv         - Activate Python environment"
    echo
    echo "🚀 Next Steps:"
    echo "  1. source ~/.bashrc"
    echo "  2. orchestrator"
    echo
    printf "${CYAN}All components use dynamic path resolution${NC}\n"
    printf "${CYAN}No hardcoded paths in this installation${NC}\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    show_banner
    
    log "Starting installation..."
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
        "Python venv:setup_python_venv"
        "Unified wrapper:deploy_unified_wrapper"
        "Orchestration:deploy_orchestration_system"
        "Agents:install_agents_with_sync"
        "Statusline:install_statusline"
        "Environment:setup_environment"
        "Claude home:setup_claude_home"
    )
    
    local step_num=1
    local total_steps=${#steps[@]}
    
    for step_def in "${steps[@]}"; do
        IFS=':' read -r step_name step_func <<< "$step_def"
        echo -n "  [$step_num/$total_steps] $step_name... "
        
        if $step_func &>/dev/null; then
            echo "✅"
        else
            echo "⚠️"
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
            echo "Claude Installer v$SCRIPT_VERSION - Dynamic Path Resolution"
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
            echo "  • No hardcoded paths"
            echo "  • Dynamic component discovery"
            echo "  • Intelligent project root detection"
            echo "  • Flexible file structure support"
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