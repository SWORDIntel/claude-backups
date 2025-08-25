#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# FULL WRAPPER INSTALLATION - BASH OUTPUT FIX MODULE
# 
# This script resolves the bash output suppression issue by:
# • Using claude-wrapper-ultimate.sh as baseline template (ALL FUNCTIONALITY PRESERVED)
# • Installing the wrapper directly (no symlinks) 
# • Pre-detecting and hardcoding all dynamic paths at install time
# • Eliminating runtime path discovery that interferes with I/O
# • Maintaining 100% compatibility with existing wrapper features
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Status symbols
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly INFO="ℹ"
readonly FIXING="🔧"

log_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

log_fixing() {
    echo -e "${YELLOW}${FIXING} $1${NC}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION-TIME PATH DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_installation_paths() {
    log_info "Detecting installation paths..."
    
    # Detect script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Source wrapper location
    SOURCE_WRAPPER="$SOURCE_DIR/claude-wrapper-ultimate.sh"
    
    # Detect project root
    PROJECT_ROOT=""
    local search_paths=(
        "$SOURCE_DIR"
        "$(pwd)"
        "$HOME/Downloads/claude-backups"
        "$HOME/Documents/Claude"
        "$HOME/claude-project"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path/agents" ]] || [[ -f "$path/CLAUDE.md" ]]; then
            PROJECT_ROOT="$path"
            break
        fi
    done
    
    if [[ -z "$PROJECT_ROOT" ]]; then
        PROJECT_ROOT="$SOURCE_DIR"
    fi
    
    # Detect agents directory
    if [[ -d "$PROJECT_ROOT/agents" ]]; then
        AGENTS_DIR="$PROJECT_ROOT/agents"
    else
        AGENTS_DIR="$HOME/agents"
        mkdir -p "$AGENTS_DIR" 2>/dev/null || true
    fi
    
    # Detect Claude binary
    CLAUDE_BINARY=""
    local claude_paths=(
        "$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$(which claude 2>/dev/null || true)"
    )
    
    for path in "${claude_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path" ]]; then
            CLAUDE_BINARY="$path"
            break
        fi
    done
    
    # Install target
    INSTALL_TARGET="$HOME/.local/bin/claude"
    mkdir -p "$(dirname "$INSTALL_TARGET")" 2>/dev/null || true
    
    # Cache directory
    CACHE_DIR="$HOME/.cache/claude"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    
    log_success "Paths detected:"
    echo "  Source Wrapper:   $SOURCE_WRAPPER"
    echo "  Project Root:     $PROJECT_ROOT"
    echo "  Agents Dir:       $AGENTS_DIR"
    echo "  Claude Binary:    ${CLAUDE_BINARY:-NOT FOUND}"
    echo "  Install Target:   $INSTALL_TARGET"
    echo "  Cache Dir:        $CACHE_DIR"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PRE-REGISTER AGENTS AT INSTALL TIME
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

preregister_agents() {
    log_info "Pre-registering agents for optimized runtime..."
    
    local registry_file="$CACHE_DIR/registered_agents.json"
    local agent_count=0
    
    # Create registry structure
    cat > "$registry_file" << 'EOF'
{
    "agents": {},
    "last_updated": "",
    "total_count": 0,
    "installation_time": "",
    "project_root": "",
    "agents_dir": ""
}
EOF
    
    # Use Python to build registry if available
    if command -v python3 >/dev/null 2>&1 && [[ -d "$AGENTS_DIR" ]]; then
        python3 << EOF
import json, os, glob, re
from datetime import datetime

registry_file = "$registry_file"
agents_dir = "$AGENTS_DIR"
project_root = "$PROJECT_ROOT"

try:
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    registry['installation_time'] = datetime.now().isoformat()
    registry['project_root'] = project_root
    registry['agents_dir'] = agents_dir
    registry['last_updated'] = datetime.now().isoformat()
    
    agent_files = glob.glob(os.path.join(agents_dir, "*.md")) + glob.glob(os.path.join(agents_dir, "*.MD"))
    
    for agent_file in agent_files:
        if 'template' in os.path.basename(agent_file).lower():
            continue
            
        agent_name = os.path.splitext(os.path.basename(agent_file))[0].lower()
        display_name = os.path.splitext(os.path.basename(agent_file))[0]
        
        # Extract metadata
        category = "general"
        description = "No description available"
        uuid = "unknown"
        tools = []
        status = "active"
        
        try:
            with open(agent_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            # Extract category
            if match := re.search(r'^category:\s*(.+)', content, re.MULTILINE | re.IGNORECASE):
                category = match.group(1).strip()
            elif match := re.search(r'\*\*Category:\*\*\s*(.+)', content, re.IGNORECASE):
                category = match.group(1).strip()
                
            # Extract description  
            if match := re.search(r'^description:\s*(.+)', content, re.MULTILINE | re.IGNORECASE):
                description = match.group(1).strip()
            elif match := re.search(r'\*\*Purpose:\*\*\s*(.+)', content, re.IGNORECASE):
                description = match.group(1).strip()
                
            # Extract UUID
            if match := re.search(r'^uuid:\s*(.+)', content, re.MULTILINE | re.IGNORECASE):
                uuid = match.group(1).strip()
                
            # Extract tools
            tools_match = re.search(r'^tools:\s*$(.+?)^[a-zA-Z]', content, re.MULTILINE | re.DOTALL | re.IGNORECASE)
            if tools_match:
                tools_section = tools_match.group(1)
                tools = re.findall(r'^\s*-\s*(.+)', tools_section, re.MULTILINE)
                tools = [tool.strip() for tool in tools if tool.strip()]
            
            # Determine status
            file_size = os.path.getsize(agent_file)
            if file_size < 100:
                status = "stub"
            elif "## Implementation" not in content:
                status = "template"
            else:
                status = "active"
                
        except Exception as e:
            print(f"Error processing {agent_file}: {e}")
            continue
        
        # Add agent to registry
        registry['agents'][agent_name] = {
            'name': agent_name,
            'display_name': display_name,
            'file_path': agent_file,
            'category': category,
            'description': description,
            'uuid': uuid,
            'tools': tools,
            'status': status,
            'last_modified': datetime.fromtimestamp(os.path.getmtime(agent_file)).isoformat()
        }
    
    registry['total_count'] = len(registry['agents'])
    
    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)
        
    print(f"Registered {len(registry['agents'])} agents")
    
except Exception as e:
    print(f"Error: {e}")
EOF
    
        agent_count=$(python3 -c "
import json
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
    print(registry.get('total_count', 0))
except:
    print('0')
" 2>/dev/null)
    
    else
        # Fallback: simple count
        if [[ -d "$AGENTS_DIR" ]]; then
            agent_count=$(find "$AGENTS_DIR" -name "*.md" -o -name "*.MD" | wc -l)
            echo "{\"agents\": {}, \"total_count\": $agent_count, \"last_updated\": \"$(date -Iseconds)\", \"project_root\": \"$PROJECT_ROOT\", \"agents_dir\": \"$AGENTS_DIR\"}" > "$registry_file"
        fi
    fi
    
    log_success "Pre-registered $agent_count agents"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HARDCODE PATHS IN EXISTING WRAPPER (PRESERVING ALL FUNCTIONALITY)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

generate_hardcoded_wrapper() {
    log_info "Creating wrapper with hardcoded paths (preserving ALL functionality)..."
    
    # Check if source wrapper exists
    if [[ ! -f "$SOURCE_WRAPPER" ]]; then
        log_error "Source wrapper not found: $SOURCE_WRAPPER"
        return 1
    fi
    
    # Backup existing wrapper if it exists
    if [[ -f "$INSTALL_TARGET" ]]; then
        cp "$INSTALL_TARGET" "$INSTALL_TARGET.backup.$(date +%s)" 2>/dev/null || true
    fi
    
    log_info "Using template: $SOURCE_WRAPPER"
    log_info "Installing to: $INSTALL_TARGET"
    
    # Read the source wrapper content
    local wrapper_content
    wrapper_content=$(cat "$SOURCE_WRAPPER")
    
    # Replace dynamic path functions with hardcoded versions
    # 1. Replace find_project_root function
    local hardcoded_find_project_root='find_project_root() {
    echo "'"$PROJECT_ROOT"'"
    return 0
}'
    
    # 2. Replace find_claude_binary function
    local hardcoded_find_claude_binary='find_claude_binary() {
    echo "'"$CLAUDE_BINARY"'"
    return 0
}'
    
    # 3. Hardcode initialize_environment function key variables
    local hardcoded_env_vars='    # HARDCODED PATHS (SET AT INSTALL TIME)
    export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude-home}"
    export CLAUDE_PROJECT_ROOT="'"$PROJECT_ROOT"'"
    export CLAUDE_AGENTS_DIR="'"$AGENTS_DIR"'"
    export CLAUDE_CONFIG_DIR="'"$PROJECT_ROOT/config"'"
    export CACHE_DIR="'"$CACHE_DIR"'"'
    
    # Apply replacements using sed-like operations
    # Replace the find_project_root function
    wrapper_content=$(echo "$wrapper_content" | sed '/^find_project_root() {/,/^}/c\
find_project_root() {\
    echo "'"$PROJECT_ROOT"'"\
    return 0\
}')
    
    # Replace the find_claude_binary function
    wrapper_content=$(echo "$wrapper_content" | sed '/^find_claude_binary() {/,/^}/c\
find_claude_binary() {\
    echo "'"$CLAUDE_BINARY"'"\
    return 0\
}')
    
    # Hardcode the main environment variables in initialize_environment
    wrapper_content=$(echo "$wrapper_content" | sed '/export CLAUDE_PROJECT_ROOT=.*find_project_root/c\
    export CLAUDE_PROJECT_ROOT="'"$PROJECT_ROOT"'"')
    
    wrapper_content=$(echo "$wrapper_content" | sed '/export CLAUDE_AGENTS_DIR=.*agents/c\
        export CLAUDE_AGENTS_DIR="'"$AGENTS_DIR"'"')
    
    wrapper_content=$(echo "$wrapper_content" | sed '/export CLAUDE_CONFIG_DIR=.*config/c\
        export CLAUDE_CONFIG_DIR="'"$PROJECT_ROOT/config"'"')
    
    # Add hardcoded paths comment at the top after the header
    local header_comment='# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v13.1 - HARDCODED PATHS VERSION
# 
# This version has been optimized with hardcoded paths at install time:
# • Project Root: '"$PROJECT_ROOT"'
# • Agents Dir: '"$AGENTS_DIR"'
# • Claude Binary: '"$CLAUDE_BINARY"'
# • Cache Dir: '"$CACHE_DIR"'
# • Generated: '"$(date -Iseconds)"'
# 
# All original functionality preserved - only path discovery hardcoded
# ═══════════════════════════════════════════════════════════════════════════'
    
    # Insert the header after the first comment block
    wrapper_content=$(echo "$wrapper_content" | sed '20i\
'"$header_comment"'')
    
    # Write the modified wrapper
    echo "$wrapper_content" > "$INSTALL_TARGET"
    
    # Make executable
    chmod +x "$INSTALL_TARGET"
    
    log_success "Hardcoded wrapper created successfully"
    log_info "All original functionality preserved with optimized path resolution"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VERIFY INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

verify_installation() {
    log_info "Verifying installation..."
    
    # Check if wrapper exists and is executable
    if [[ ! -x "$INSTALL_TARGET" ]]; then
        log_error "Wrapper not executable: $INSTALL_TARGET"
        return 1
    fi
    
    # Check if wrapper contains hardcoded paths
    if grep -q "HARDCODED PATHS VERSION" "$INSTALL_TARGET"; then
        log_success "Hardcoded paths detected in wrapper"
    else
        log_error "Hardcoded paths not found in wrapper"
        return 1
    fi
    
    # Test basic wrapper functionality
    if "$INSTALL_TARGET" --help >/dev/null 2>&1; then
        log_success "Wrapper help command works"
    else
        log_error "Wrapper help command failed"
        return 1
    fi
    
    log_success "Installation verification complete"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION FUNCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}          Full Wrapper Installation - Bash Output Fix${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Step 1: Detect paths
    detect_installation_paths
    echo
    
    # Step 2: Pre-register agents
    preregister_agents
    echo
    
    # Step 3: Generate hardcoded wrapper
    generate_hardcoded_wrapper
    echo
    
    # Step 4: Verify installation
    if verify_installation; then
        echo
        log_success "Installation completed successfully!"
        echo
        echo -e "${BOLD}The wrapper now has:${NC}"
        echo "  • All original functionality preserved"
        echo "  • Hardcoded paths for optimal performance"
        echo "  • Direct installation (no symlinks)"
        echo "  • Pre-registered agent system"
        echo
        echo -e "${BOLD}Quick test commands:${NC}"
        echo "  claude --status"
        echo "  claude --agents"
        echo "  claude --help"
        echo
        echo -e "${BOLD}Bash output test:${NC}"
        echo "  claude /task \"echo 'Testing bash output'\""
        echo "  claude /task \"ls -la\""
        echo
        log_info "This should resolve the bash output suppression issue"
        log_info "by eliminating runtime path discovery complexity"
    else
        log_error "Installation verification failed!"
        return 1
    fi
}

# Run main installation
main "$@"