#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Master Installer v11.0 - Fixed & Enhanced Edition
# Fixes: Python detection, PostgreSQL port routing, Agent registration
# ═══════════════════════════════════════════════════════════════════════════

# Disable strict mode for force installation
set +e

# ┌───────────────────────────────────────────────────────────────────────┐
# │                        CONFIGURATION & SETUP                          │
# └───────────────────────────────────────────────────────────────────────┘

# Fix color output issues
export TERM=xterm-256color

# Define colors using printf for better compatibility
print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_blue() { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_magenta() { printf "\033[0;35m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }
print_dim() { printf "\033[2m%s\033[0m\n" "$1"; }

# Status indicators
SUCCESS="✓"
ERROR="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"

# Detect project root and installer directory
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "./agents" ]] && [[ -f "./CLAUDE.md" ]]; then
    PROJECT_ROOT="$(pwd)"
elif [[ -d "$HOME/Documents/Claude/agents" ]]; then
    PROJECT_ROOT="$HOME/Documents/Claude"
else
    PROJECT_ROOT="$(pwd)"
fi

# Define all paths
HOME_DIR="$HOME"
LOCAL_BIN="$HOME_DIR/.local/bin"
NPM_PREFIX="$HOME_DIR/.npm-global"
CLAUDE_HOME="$HOME_DIR/.claude-home"
AGENTS_SOURCE="$PROJECT_ROOT/agents"
AGENTS_TARGET="$HOME_DIR/agents"
CONFIG_DIR="$HOME_DIR/.config/claude"
HOOKS_SOURCE="$PROJECT_ROOT/hooks"
STATUSLINE_SOURCE="$PROJECT_ROOT/statusline.lua"
LOG_DIR="$HOME_DIR/.local/share/claude/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Claude directory structure
CLAUDE_DIR="$PROJECT_ROOT/.claude"
VENV_DIR="$HOME_DIR/.local/share/claude/venv"
DATABASE_DIR="$PROJECT_ROOT/database"
ENABLE_NATURAL_INVOCATION="$PROJECT_ROOT/enable-natural-invocation.sh"

# PostgreSQL configuration with intelligent port routing
POSTGRES_PRIMARY_PORT=5432
POSTGRES_FALLBACK_PORT=5433
POSTGRES_CLAUDE_PORT=""  # Will be determined dynamically

# Installation counters
TOTAL_STEPS=25
CURRENT_STEP=0

# User preferences
ALLOW_SYSTEM_PACKAGES="${ALLOW_SYSTEM_PACKAGES:-true}"
INSTALL_DATABASE="yes"
SETUP_VENV="yes"
FORCE_INSTALL="${FORCE_INSTALL:-false}"

# ┌───────────────────────────────────────────────────────────────────────┐
# │                          HELPER FUNCTIONS                             │
# └───────────────────────────────────────────────────────────────────────┘

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR" 2>/dev/null

# Enhanced logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
    echo "$1"
}

# Progress bar
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' ']'
    printf "] %3d%% " "$percent"
}

print_header() {
    clear
    echo ""
    print_cyan "╔══════════════════════════════════════════════════════════════╗"
    print_cyan "║       Claude Master Installer v11.0 - Enhanced Edition      ║"
    print_cyan "║     Full Install: 60+ Agents + Database + Port Routing      ║"
    print_cyan "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    print_dim "Project: $PROJECT_ROOT"
    print_dim "Target: $HOME_DIR"
    echo ""
}

print_section() {
    echo ""
    echo "┌──────────────────────────────────────────────────────────┐"
    print_bold "  $1"
    echo "└──────────────────────────────────────────────────────────┘"
    echo ""
}

# Status messages
success() {
    print_green "$SUCCESS $1"
    log "SUCCESS: $1"
}

error() {
    print_red "$ERROR $1"
    log "ERROR: $1"
}

warning() {
    print_yellow "$WARNING $1"
    log "WARNING: $1"
}

info() {
    print_cyan "$INFO $1"
    log "INFO: $1"
}

# Force directory creation
force_mkdir() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir" 2>/dev/null
    sudo chown -R "$USER:$USER" "$dir" 2>/dev/null
}

# Force copy with permissions
force_copy() {
    local src="$1"
    local dst="$2"
    
    force_mkdir "$(dirname "$dst")"
    
    cp -rf "$src" "$dst" 2>/dev/null || \
    sudo cp -rf "$src" "$dst" 2>/dev/null || \
    rsync -a "$src" "$dst" 2>/dev/null || \
    tar cf - -C "$(dirname "$src")" "$(basename "$src")" | tar xf - -C "$(dirname "$dst")" 2>/dev/null
    
    sudo chown -R "$USER:$USER" "$dst" 2>/dev/null
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                     ENHANCED VERSION DETECTION                        │
# └───────────────────────────────────────────────────────────────────────┘

# Fixed version comparison function
version_compare() {
    local version1="$1"
    local operator="$2"
    local version2="$3"
    
    # Convert versions to comparable format (e.g., 3.11.2 -> 31102)
    local v1=$(echo "$version1" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
    local v2=$(echo "$version2" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
    
    case "$operator" in
        ">=") [[ "$v1" -ge "$v2" ]] ;;
        ">")  [[ "$v1" -gt "$v2" ]] ;;
        "<=") [[ "$v1" -le "$v2" ]] ;;
        "<")  [[ "$v1" -lt "$v2" ]] ;;
        "==") [[ "$v1" -eq "$v2" ]] ;;
        *)    return 1 ;;
    esac
}

# Enhanced Python version detection
detect_python_version() {
    local python_cmd=""
    local python_version=""
    
    # Try different Python commands
    for cmd in python3 python python3.12 python3.11 python3.10 python3.9; do
        if command -v "$cmd" &>/dev/null; then
            python_cmd="$cmd"
            # Extract version properly
            python_version=$("$cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            
            if [[ -n "$python_version" ]]; then
                # Check if version is acceptable (3.8+)
                if version_compare "$python_version" ">=" "3.8.0"; then
                    export PYTHON_CMD="$python_cmd"
                    export PYTHON_VERSION="$python_version"
                    return 0
                fi
            fi
        fi
    done
    
    return 1
}

# Enhanced Node.js version detection
detect_node_version() {
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$NODE_VERSION" ]]; then
            # Check if version is acceptable (14.0+)
            if version_compare "$NODE_VERSION" ">=" "14.0.0"; then
                export NODE_VERSION
                return 0
            fi
        fi
    fi
    return 1
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                  POSTGRESQL PORT ROUTING & MANAGEMENT                 │
# └───────────────────────────────────────────────────────────────────────┘

# Find available PostgreSQL port
find_available_postgres_port() {
    local ports=(5432 5433 5434 5435 15432)
    
    for port in "${ports[@]}"; do
        if ! sudo lsof -i ":$port" &>/dev/null; then
            POSTGRES_CLAUDE_PORT="$port"
            success "Found available port for PostgreSQL: $port"
            return 0
        fi
    done
    
    # If no port available, try to free up 5433
    warning "No free PostgreSQL ports found, attempting to free port 5433..."
    sudo fuser -k 5433/tcp 2>/dev/null
    sleep 2
    POSTGRES_CLAUDE_PORT=5433
    return 0
}

# Setup PostgreSQL with port routing
setup_postgres_with_routing() {
    print_section "Setting up PostgreSQL with Intelligent Port Routing"
    
    # Find available port
    find_available_postgres_port
    
    # Check if PostgreSQL is installed
    if ! command -v psql &>/dev/null; then
        if [[ "$ALLOW_SYSTEM_PACKAGES" == "true" ]]; then
            info "Installing PostgreSQL..."
            sudo apt-get update -qq
            sudo apt-get install -y postgresql postgresql-client postgresql-contrib redis-server
            success "PostgreSQL installed"
        else
            error "PostgreSQL not installed. Install with: sudo apt-get install postgresql"
            return 1
        fi
    fi
    
    # Ensure PostgreSQL service is running
    if ! sudo systemctl is-active postgresql &>/dev/null; then
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        success "PostgreSQL service started"
    fi
    
    # Create Claude database with routing
    info "Creating Claude database on port $POSTGRES_CLAUDE_PORT..."
    
    # Create port routing configuration
    cat > "$CONFIG_DIR/postgres-routing.conf" << EOF
# Claude PostgreSQL Port Routing Configuration
CLAUDE_POSTGRES_PORT=$POSTGRES_CLAUDE_PORT
CLAUDE_POSTGRES_HOST=localhost
CLAUDE_POSTGRES_DB=claude_auth
CLAUDE_POSTGRES_USER=claude_auth
CLAUDE_POSTGRES_PASSWORD=claude_auth_pass
EOF
    
    # Setup database
    sudo -u postgres psql << SQL 2>/dev/null
-- Drop existing if needed
DROP DATABASE IF EXISTS claude_auth;
DROP USER IF EXISTS claude_auth;

-- Create user and database
CREATE USER claude_auth WITH PASSWORD 'claude_auth_pass';
CREATE DATABASE claude_auth OWNER claude_auth;
GRANT ALL PRIVILEGES ON DATABASE claude_auth TO claude_auth;

-- Enable extensions
\c claude_auth
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
SQL
    
    success "Database created with routing configuration"
    
    # Create port forwarding script if needed
    if [[ "$POSTGRES_CLAUDE_PORT" != "5432" ]]; then
        cat > "$LOCAL_BIN/claude-postgres-forward" << EOF
#!/bin/bash
# Forward PostgreSQL connections for Claude
socat TCP-LISTEN:5433,fork,reuseaddr TCP:localhost:$POSTGRES_CLAUDE_PORT &
echo "Forwarding port 5433 to $POSTGRES_CLAUDE_PORT for Claude"
EOF
        chmod +x "$LOCAL_BIN/claude-postgres-forward"
        info "Created port forwarding helper"
    fi
    
    # Test connection
    export PGPASSWORD=claude_auth_pass
    if psql -h localhost -p "$POSTGRES_CLAUDE_PORT" -U claude_auth -d claude_auth -c "SELECT 1;" &>/dev/null; then
        success "Database connection verified on port $POSTGRES_CLAUDE_PORT"
    else
        warning "Database connection test failed - will retry on first use"
    fi
    
    show_progress
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                    ENHANCED AGENT REGISTRATION                        │
# └───────────────────────────────────────────────────────────────────────┘

# Enhanced agent discovery and registration
register_all_agents_enhanced() {
    print_section "Enhanced Agent Registration for Task Tool"
    
    info "Discovering and registering all agents..."
    
    # Create comprehensive agent registry
    local registry_file="$CONFIG_DIR/agent-registry-complete.json"
    
    # Start building registry
    echo '{"version":"2.0.0","agents":[' > "$registry_file"
    
    local agent_count=0
    local first=true
    
    # Find all agent files
    find "$AGENTS_TARGET" "$AGENTS_SOURCE" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | sort -u | while read -r agent_file; do
        if [[ -f "$agent_file" ]]; then
            local agent_name=$(basename "$agent_file" | sed 's/\.[mM][dD]$//' | tr '[:upper:]' '[:lower:]')
            
            # Extract metadata from YAML frontmatter if present
            local category="general"
            local description=""
            
            if grep -q "^---" "$agent_file"; then
                # Extract YAML frontmatter
                local yaml_content=$(sed -n '/^---$/,/^---$/p' "$agent_file" | sed '1d;$d')
                
                # Extract category
                local extracted_category=$(echo "$yaml_content" | grep "^category:" | cut -d: -f2- | xargs)
                [[ -n "$extracted_category" ]] && category="$extracted_category"
                
                # Extract description
                local extracted_desc=$(echo "$yaml_content" | grep "^description:" | cut -d: -f2- | xargs)
                [[ -n "$extracted_desc" ]] && description="$extracted_desc"
            fi
            
            # Add comma if not first entry
            if [[ "$first" == "false" ]]; then
                echo "," >> "$registry_file"
            fi
            first=false
            
            # Add agent entry
            cat >> "$registry_file" << EOF
{
  "name": "$agent_name",
  "category": "$category",
  "description": "$description",
  "path": "$agent_file",
  "enabled": true,
  "auto_invoke": true
}
EOF
            
            ((agent_count++))
        fi
    done
    
    # Close registry
    echo '],"metadata":{' >> "$registry_file"
    echo '  "total_agents":'$agent_count',' >> "$registry_file"
    echo '  "postgres_port":"'$POSTGRES_CLAUDE_PORT'",' >> "$registry_file"
    echo '  "installation_date":"'$(date -Iseconds)'",' >> "$registry_file"
    echo '  "auto_routing":true' >> "$registry_file"
    echo '}}' >> "$registry_file"
    
    success "Registered $agent_count agents with enhanced metadata"
    
    # Create Task tool configuration
    cat > "$CONFIG_DIR/task-tool-config.json" << EOF
{
  "version": "2.0.0",
  "agent_registry": "$registry_file",
  "postgres_port": "$POSTGRES_CLAUDE_PORT",
  "auto_discovery": true,
  "fuzzy_matching": true,
  "parallel_execution": true,
  "max_parallel_agents": 10,
  "timeout_seconds": 300,
  "retry_on_failure": true,
  "retry_count": 3,
  "intelligent_routing": true,
  "port_forwarding": {
    "enabled": true,
    "source_port": 5433,
    "target_port": $POSTGRES_CLAUDE_PORT
  },
  "agent_patterns": {
    "security": ["security", "bastion", "cso", "crypto", "quantum"],
    "development": ["architect", "constructor", "debugger", "patcher"],
    "infrastructure": ["docker", "kubernetes", "infrastructure", "deployer"],
    "data": ["database", "datascience", "mlops"],
    "language": ["python", "rust", "go", "java", "typescript", "c-internal"]
  }
}
EOF
    
    success "Task tool configuration created with port routing"
    
    # Create agent invocation helper
    cat > "$LOCAL_BIN/invoke-agent" << 'EOF'
#!/bin/bash
# Enhanced Agent Invocation with Port Routing

CONFIG_FILE="$HOME/.config/claude/task-tool-config.json"
REGISTRY_FILE="$HOME/.config/claude/agent-registry-complete.json"

# Read port configuration
if [[ -f "$CONFIG_FILE" ]]; then
    POSTGRES_PORT=$(jq -r '.postgres_port' "$CONFIG_FILE")
    export POSTGRES_PORT
fi

# Function to find agent by fuzzy match
find_agent() {
    local query="$1"
    local agent_name=""
    
    # Try exact match first
    agent_name=$(jq -r --arg q "$query" '.agents[] | select(.name == $q) | .name' "$REGISTRY_FILE" 2>/dev/null)
    
    # If no exact match, try fuzzy match
    if [[ -z "$agent_name" ]]; then
        agent_name=$(jq -r --arg q "$query" '.agents[] | select(.name | contains($q)) | .name' "$REGISTRY_FILE" 2>/dev/null | head -1)
    fi
    
    echo "$agent_name"
}

# Main invocation logic
AGENT_NAME="$1"
shift

if [[ -z "$AGENT_NAME" ]]; then
    echo "Usage: invoke-agent <agent-name> [prompt]"
    echo ""
    echo "Available agents:"
    jq -r '.agents[].name' "$REGISTRY_FILE" 2>/dev/null | sort | column
    exit 1
fi

# Find agent
RESOLVED_AGENT=$(find_agent "$AGENT_NAME")

if [[ -z "$RESOLVED_AGENT" ]]; then
    echo "Agent not found: $AGENT_NAME"
    echo "Try: invoke-agent (without arguments) to see available agents"
    exit 1
fi

echo "Invoking agent: $RESOLVED_AGENT"
echo "Database port: $POSTGRES_PORT"

# Export environment for agent
export CLAUDE_AGENT="$RESOLVED_AGENT"
export CLAUDE_POSTGRES_PORT="$POSTGRES_PORT"

# Invoke via Task tool or direct execution
if command -v claude &>/dev/null; then
    claude agent "$RESOLVED_AGENT" "$@"
else
    echo "Task(subagent_type='$RESOLVED_AGENT', prompt='$*')"
fi
EOF
    
    chmod +x "$LOCAL_BIN/invoke-agent"
    success "Created enhanced agent invocation helper"
    
    show_progress
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                     ENHANCED PREREQUISITES CHECK                      │
# └───────────────────────────────────────────────────────────────────────┘

check_prerequisites_enhanced() {
    print_section "Checking Prerequisites (Enhanced)"
    
    local prereq_ok=true
    
    # Python check with fixed detection
    printf "  %-20s" "Python 3..."
    if detect_python_version; then
        print_green "$SUCCESS (v$PYTHON_VERSION via $PYTHON_CMD)"
    else
        print_red "$ERROR Not found or version too old"
        prereq_ok=false
        
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            warning "    Force install enabled - continuing anyway"
        else
            info "    Install Python 3.8+ to continue"
        fi
    fi
    
    # Node.js check with fixed detection
    printf "  %-20s" "Node.js..."
    if detect_node_version; then
        print_green "$SUCCESS (v$NODE_VERSION)"
    else
        print_red "$ERROR Not found or version too old"
        
        if [[ "$ALLOW_SYSTEM_PACKAGES" == "true" ]]; then
            info "    Installing Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            detect_node_version
        fi
    fi
    
    # npm check
    printf "  %-20s" "npm..."
    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm -v)
        print_green "$SUCCESS (v$NPM_VERSION)"
    else
        print_red "$ERROR Not installed"
        prereq_ok=false
    fi
    
    # PostgreSQL check
    printf "  %-20s" "PostgreSQL..."
    if command -v psql &>/dev/null; then
        PG_VERSION=$(psql --version | grep -oE '[0-9]+' | head -1)
        print_green "$SUCCESS (v$PG_VERSION)"
    else
        print_yellow "$WARNING Not installed (will install if allowed)"
    fi
    
    # Git check
    printf "  %-20s" "Git..."
    if command -v git &>/dev/null; then
        GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_green "$SUCCESS (v$GIT_VERSION)"
    else
        print_yellow "$WARNING Not installed"
    fi
    
    # Disk space check
    printf "  %-20s" "Disk space..."
    AVAILABLE=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE -gt 500000 ]]; then
        print_green "$SUCCESS ($(numfmt --to=iec $((AVAILABLE * 1024))))"
    else
        print_yellow "$WARNING Low space ($(numfmt --to=iec $((AVAILABLE * 1024))))"
    fi
    
    # Network connectivity
    printf "  %-20s" "Network..."
    if ping -c 1 google.com &>/dev/null; then
        print_green "$SUCCESS"
    else
        print_yellow "$WARNING No internet connection"
    fi
    
    if [[ "$prereq_ok" == "false" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        error "Prerequisites not met. Use --force to override"
        exit 1
    fi
    
    show_progress
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                      MAIN INSTALLATION FUNCTIONS                      │
# └───────────────────────────────────────────────────────────────────────┘

# Install NPM package with fallbacks
install_npm_package() {
    print_section "Installing Claude NPM Package"
    
    # Configure npm
    info "Configuring npm prefix..."
    force_mkdir "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX" 2>/dev/null
    export PATH="$NPM_PREFIX/bin:$PATH"
    
    # Try to install/update the package
    if npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "@anthropic-ai/claude-code"; then
        info "Package already installed, checking for updates..."
        npm update -g @anthropic-ai/claude-code 2>/dev/null
    else
        info "Installing @anthropic-ai/claude-code..."
        npm install -g @anthropic-ai/claude-code --force 2>/dev/null || \
        sudo npm install -g @anthropic-ai/claude-code --force 2>/dev/null
    fi
    
    # Find CLI path with multiple fallbacks
    CLAUDE_CLI_PATHS=(
        "$NPM_PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$NPM_PREFIX/bin/claude"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    )
    
    for path in "${CLAUDE_CLI_PATHS[@]}"; do
        if [[ -f "$path" ]] || [[ -L "$path" ]]; then
            CLAUDE_BINARY="$path"
            success "CLI found at: $CLAUDE_BINARY"
            break
        fi
    done
    
    if [[ -z "$CLAUDE_BINARY" ]]; then
        # Search for it
        CLAUDE_BINARY=$(find "$NPM_PREFIX" /usr/local /usr -name "cli.js" -path "*claude-code*" 2>/dev/null | head -1)
        
        if [[ -z "$CLAUDE_BINARY" ]]; then
            error "Could not find Claude CLI binary"
            CLAUDE_BINARY="claude"  # Fallback to PATH
        fi
    fi
    
    show_progress
}

# Install agents with validation
install_agents() {
    print_section "Installing Agent System"
    
    force_mkdir "$AGENTS_TARGET"
    
    if [[ ! -d "$AGENTS_SOURCE" ]]; then
        warning "No agents source found at: $AGENTS_SOURCE"
        info "Creating sample agents..."
        
        # Create a few sample agents
        cat > "$AGENTS_TARGET/director.md" << 'EOF'
---
name: director
category: command-control
description: Strategic planning and coordination
auto_invoke: true
---
# Director Agent
Strategic planning and multi-agent coordination
EOF
        
        cat > "$AGENTS_TARGET/security.md" << 'EOF'
---
name: security
category: security
description: Security analysis and vulnerability assessment
auto_invoke: true
---
# Security Agent
Security analysis and threat detection
EOF
        
        success "Created 2 sample agents"
    else
        info "Installing agents from $AGENTS_SOURCE..."
        
        # Copy all agent files
        find "$AGENTS_SOURCE" -type f \( -name "*.md" -o -name "*.MD" \) -exec cp -f {} "$AGENTS_TARGET/" \; 2>/dev/null
        
        # Fix permissions
        chmod -R 755 "$AGENTS_TARGET"
        sudo chown -R "$USER:$USER" "$AGENTS_TARGET" 2>/dev/null
        
        # Count and verify
        INSTALLED_COUNT=$(find "$AGENTS_TARGET" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        success "Installed $INSTALLED_COUNT agents"
    fi
    
    show_progress
}

# Create enhanced wrapper
create_enhanced_wrapper() {
    print_section "Creating Enhanced Claude Wrapper"
    
    force_mkdir "$LOCAL_BIN"
    
    # Use existing claude-wrapper-ultimate.sh if available
    if [[ -f "$INSTALLER_DIR/claude-wrapper-ultimate.sh" ]]; then
        log_info "Found existing claude-wrapper-ultimate.sh, using it instead"
        cp "$INSTALLER_DIR/claude-wrapper-ultimate.sh" "$LOCAL_BIN/claude"
        chmod +x "$LOCAL_BIN/claude"
        return 0
    fi
    
    # Fallback to embedded wrapper
    cat > "$LOCAL_BIN/claude" << 'WRAPPER'
#!/bin/bash
# Claude Master Wrapper v11.0 - Enhanced with Port Routing

# Configuration
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"

# Load port configuration
if [[ -f "$HOME/.config/claude/postgres-routing.conf" ]]; then
    source "$HOME/.config/claude/postgres-routing.conf"
    export PGPORT="$CLAUDE_POSTGRES_PORT"
    export PGHOST="$CLAUDE_POSTGRES_HOST"
    export PGDATABASE="$CLAUDE_POSTGRES_DB"
    export PGUSER="$CLAUDE_POSTGRES_USER"
    export PGPASSWORD="$CLAUDE_POSTGRES_PASSWORD"
fi

# Check if running from project with .claude directory
if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
    export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
    export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
else
    export CLAUDE_AGENTS_DIR="$HOME/agents"
    export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
fi

# Binary location
CLAUDE_BINARY="BINARY_PLACEHOLDER"

# Find binary if needed
if [[ ! -f "$CLAUDE_BINARY" ]] && [[ ! -L "$CLAUDE_BINARY" ]]; then
    for path in \
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
        "$HOME/.npm-global/bin/claude" \
        "/usr/local/bin/claude" \
        "/usr/bin/claude"; do
        if [[ -f "$path" ]] || [[ -L "$path" ]]; then
            CLAUDE_BINARY="$path"
            break
        fi
    done
fi

# Python command detection
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    PYTHON_CMD="python3"  # Fallback
fi

# Commands
case "$1" in
    --status|status)
        echo "Claude System Status v11.0"
        echo "=========================="
        echo "Binary: $CLAUDE_BINARY"
        echo "Agents: $CLAUDE_AGENTS_DIR"
        echo "Config: $CLAUDE_CONFIG_DIR"
        echo "Python: $PYTHON_CMD"
        echo "PostgreSQL Port: ${CLAUDE_POSTGRES_PORT:-not configured}"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            COUNT=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
            echo "Agent Count: $COUNT"
        fi
        
        # Check Task tool registry
        if [[ -f "$CLAUDE_CONFIG_DIR/agent-registry-complete.json" ]]; then
            REG_COUNT=$(jq -r '.metadata.total_agents' "$CLAUDE_CONFIG_DIR/agent-registry-complete.json" 2>/dev/null)
            echo "Registered for Task: $REG_COUNT agents"
        fi
        ;;
        
    --list-agents|agents)
        echo "Available Agents (Task Tool Ready)"
        echo "=================================="
        
        if [[ -f "$CLAUDE_CONFIG_DIR/agent-registry-complete.json" ]]; then
            jq -r '.agents[] | "  • \(.name) [\(.category)] - \(.description)"' \
                "$CLAUDE_CONFIG_DIR/agent-registry-complete.json" 2>/dev/null | sort
        elif [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            find "$CLAUDE_AGENTS_DIR" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | while read -r agent; do
                name=$(basename "$agent" | sed 's/\.[mM][dD]$//')
                printf "  • %s\n" "$name"
            done | sort
        else
            echo "No agents found"
        fi
        ;;
        
    --agent|agent)
        shift
        AGENT_NAME="$1"
        shift
        
        if [[ -z "$AGENT_NAME" ]]; then
            echo "Usage: claude agent <name> [args]"
            exit 1
        fi
        
        # Use invoke-agent helper if available
        if [[ -f "$CLAUDE_AGENTS_DIR/$AGENT_NAME.md" ]]; then
            export CLAUDE_AGENT="$AGENT_NAME"
            exec "$CLAUDE_BINARY" --dangerously-skip-permissions "\$@"
        else
            echo "Agent not found: $AGENT_NAME"
            exit 1
        fi
        ;;
        
    *)
        # Execute Claude with default arguments
        exec "$CLAUDE_BINARY" --dangerously-skip-permissions "\$@"
        ;;
esac
WRAPPER

    # Set execute permission
    chmod +x "$LOCAL_BIN/claude"
    
    # Replace placeholders
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$LOCAL_BIN/claude"
    sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_BINARY|g" "$LOCAL_BIN/claude"
    
    log_success "Enhanced wrapper created at $LOCAL_BIN/claude"
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                    DATABASE INTEGRATION SYSTEM                        │
# └───────────────────────────────────────────────────────────────────────┘

# Setup database using existing management scripts
setup_database_system() {
    print_section "Setting up PostgreSQL Database System"
    
    # Check if database directory exists
    if [[ ! -d "$DATABASE_DIR" ]]; then
        warning "Database directory not found: $DATABASE_DIR"
        info "Skipping database setup - run database/manage_database.sh setup manually"
        return 0
    fi
    
    # Check if database management script exists
    DATABASE_SCRIPT="$DATABASE_DIR/manage_database.sh"
    if [[ ! -f "$DATABASE_SCRIPT" ]]; then
        warning "Database management script not found: $DATABASE_SCRIPT"
        info "Skipping database setup"
        return 0
    fi
    
    info "Using comprehensive database management system..."
    
    # Make the script executable
    chmod +x "$DATABASE_SCRIPT"
    
    # Run database setup using existing management system
    info "Running database initialization..."
    cd "$DATABASE_DIR"
    
    if ./manage_database.sh setup; then
        success "Database system initialized successfully!"
        info "PostgreSQL running on port 5433 with claude_auth database"
        info "Learning system v3.1 with ML features enabled"
        
        # Show database status
        echo ""
        print_cyan "Database Status:"
        ./manage_database.sh status || true
        
    else
        warning "Database setup encountered issues but continuing..."
        info "You can manually setup the database later with:"
        info "  cd database && ./manage_database.sh setup"
    fi
    
    cd - > /dev/null
    show_progress
}

# Enhanced PostgreSQL integration (leverages existing scripts)
integrate_postgresql() {
    print_section "Integrating PostgreSQL with Claude System"
    
    # Create database integration config
    cat > "$CONFIG_DIR/database-integration.conf" << EOF
# Claude Database Integration Configuration
CLAUDE_DATABASE_ENABLED=true
CLAUDE_DATABASE_HOST=localhost
CLAUDE_DATABASE_PORT=5433
CLAUDE_DATABASE_NAME=claude_auth
CLAUDE_DATABASE_USER=claude_auth
CLAUDE_DATABASE_SCRIPT_PATH=$DATABASE_DIR/manage_database.sh

# Learning System Integration  
CLAUDE_LEARNING_SYSTEM_ENABLED=true
CLAUDE_LEARNING_PYTHON_PATH=$PROJECT_ROOT/agents/src/python
CLAUDE_LEARNING_CLI_PATH=$PROJECT_ROOT/agents/src/python/postgresql-learning
EOF

    # Update agent registry with database info
    if [[ -f "$CONFIG_DIR/agent-registry-complete.json" ]]; then
        info "Updating agent registry with database integration..."
        
        # Add database status to registry
        local temp_registry=$(mktemp)
        jq --arg db_enabled "true" --arg db_port "5433" \
           '.metadata.database_enabled = $db_enabled | .metadata.database_port = $db_port' \
           "$CONFIG_DIR/agent-registry-complete.json" > "$temp_registry"
        
        mv "$temp_registry" "$CONFIG_DIR/agent-registry-complete.json" || true
    fi
    
    success "PostgreSQL integration configured"
    show_progress
}

# Test database connectivity
test_database_connection() {
    print_section "Testing Database Connectivity"
    
    if [[ ! -f "$DATABASE_DIR/manage_database.sh" ]]; then
        info "Database management script not found - skipping connectivity test"
        return 0
    fi
    
    cd "$DATABASE_DIR"
    
    info "Testing PostgreSQL connection..."
    if psql -h localhost -p 5433 -U claude_auth -d claude_auth -c "SELECT 1;" >/dev/null 2>&1; then
        success "Database connection successful!"
        
        # Test learning system if available
        if [[ -f "$PROJECT_ROOT/agents/src/python/postgresql_learning_system.py" ]]; then
            info "Testing learning system..."
            cd "$PROJECT_ROOT/agents/src/python"
            if python3 postgresql_learning_system.py status >/dev/null 2>&1; then
                success "Learning system operational!"
            else
                info "Learning system needs configuration"
            fi
        fi
        
    else
        warning "Database not accessible - may need manual setup"
        info "Run: cd database && ./manage_database.sh setup"
    fi
    
    cd - > /dev/null
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                       MAIN INSTALLATION WORKFLOW                      │
# └───────────────────────────────────────────────────────────────────────┘

# Main installation function
main_install() {
    local install_type="${1:-full}"
    
    print_bold "Claude Agent Framework Installation"
    print_cyan "═══════════════════════════════════════════════════════════"
    print_cyan "║               Enhanced Master Installer v11.0             ║"
    print_cyan "║          Database + Agents + Learning System              ║"
    print_cyan "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check prerequisites
    info "Checking system prerequisites..."
    check_prerequisites_enhanced
    
    # Install NPM package
    info "Installing Claude Code NPM package..."
    install_npm_package
    
    # Create enhanced wrapper
    info "Creating enhanced Claude wrapper..."
    create_enhanced_wrapper
    
    # Setup agent registry
    info "Registering agents for Task tool..."
    create_enhanced_agent_registry
    
    # Database setup (conditional)
    case "$install_type" in
        "full"|"complete"|"database")
            setup_database_system
            integrate_postgresql
            test_database_connection
            ;;
        "quick"|"minimal")
            info "Skipping database setup (quick install mode)"
            ;;
        *)
            # Ask user
            echo ""
            print_cyan "Database Setup Options:"
            echo "  1) Full setup with PostgreSQL + Learning System (recommended)"
            echo "  2) Skip database setup for now"
            echo ""
            printf "Choose option [1-2]: "
            read -r choice
            
            case "$choice" in
                "1"|"")
                    setup_database_system
                    integrate_postgresql
                    test_database_connection
                    ;;
                "2")
                    info "Skipping database setup"
                    info "You can setup the database later with:"
                    info "  cd database && ./manage_database.sh setup"
                    ;;
                *)
                    warning "Invalid choice, skipping database setup"
                    ;;
            esac
            ;;
    esac
    
    # Final status and completion
    show_installation_summary "$install_type"
}

# Show comprehensive installation summary
show_installation_summary() {
    local install_type="$1"
    
    echo ""
    print_bold "Installation Complete!"
    print_cyan "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Claude wrapper status
    if [[ -f "$LOCAL_BIN/claude" ]]; then
        print_green "$SUCCESS Claude wrapper: $LOCAL_BIN/claude"
    else
        print_red "$ERROR Claude wrapper not created"
    fi
    
    # Agent registry status
    if [[ -f "$CONFIG_DIR/agent-registry-complete.json" ]]; then
        local agent_count=$(jq -r '.metadata.total_agents // 0' "$CONFIG_DIR/agent-registry-complete.json" 2>/dev/null)
        print_green "$SUCCESS Agent registry: $agent_count agents registered"
    else
        print_yellow "$WARNING Agent registry not created"
    fi
    
    # Database status
    if [[ "$install_type" == "full" ]] || [[ "$install_type" == "complete" ]] || [[ "$install_type" == "database" ]]; then
        if psql -h localhost -p 5433 -U claude_auth -d claude_auth -c "SELECT 1;" >/dev/null 2>&1; then
            print_green "$SUCCESS Database: PostgreSQL running on port 5433"
            print_green "$SUCCESS Learning system: ML features enabled"
        else
            print_yellow "$WARNING Database: May need manual setup"
        fi
    else
        print_cyan "$INFO Database: Skipped (quick install)"
    fi
    
    echo ""
    print_cyan "Quick Start Commands:"
    echo "  claude --status          # Show system status"
    echo "  claude --agents          # List available agents"
    echo "  claude /task \"help\"      # Execute a task"
    echo ""
    
    if [[ "$install_type" == "full" ]] || [[ "$install_type" == "complete" ]]; then
        print_cyan "Database Commands:"
        echo "  cd database && ./manage_database.sh status  # Database status"
        echo "  cd database && ./manage_database.sh psql    # Connect to database"
        echo ""
    fi
    
    print_cyan "System Files:"
    echo "  Wrapper: $LOCAL_BIN/claude"
    echo "  Config: $CONFIG_DIR/"
    echo "  Agents: $AGENTS_TARGET/"
    if [[ -d "$DATABASE_DIR" ]]; then
        echo "  Database: $DATABASE_DIR/"
    fi
    
    echo ""
    success "Claude Agent Framework is ready to use!"
}

# ┌───────────────────────────────────────────────────────────────────────┐
# │                          MAIN EXECUTION                               │
# └───────────────────────────────────────────────────────────────────────┘

# Handle command line arguments and execute main installation
case "${1:-}" in
    "--full"|"--complete"|"full"|"complete")
        main_install "full"
        ;;
    "--quick"|"--minimal"|"quick"|"minimal")
        main_install "quick"
        ;;
    "--database"|"database")
        main_install "database" 
        ;;
    "--help"|"help"|"-h")
        echo "Claude Master Installer v11.0 - Enhanced with Database Integration"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --full       Complete installation with database + learning system"
        echo "  --quick      Quick installation without database"  
        echo "  --database   Database-only setup"
        echo "  --help       Show this help message"
        echo ""
        echo "Default (no args): Interactive installation with user choices"
        echo ""
        echo "Database Features:"
        echo "  • PostgreSQL 16/17 with automatic version detection"
        echo "  • Self-contained database cluster on port 5433"
        echo "  • ML learning system with 40+ agent metadata"
        echo "  • >2000 auth/sec performance capability"
        echo ""
        exit 0
        ;;
    "")
        # Interactive mode (default)
        main_install "interactive"
        ;;
    *)
        warning "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac