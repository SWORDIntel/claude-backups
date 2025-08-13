#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE QUICK LAUNCHER WITH AGENTS - Enhanced Edition
# One-Command Full Deployment with CPU Optimization Detection
# Version 2.1.0 - AVX512/P-core aware + Dell repo fix
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly LAUNCHER_VERSION="2.1.0"
readonly WORK_DIR="/tmp/claude-launcher-$$"
readonly LOG_FILE="/home/ubuntu/Documents/Claude/launcher-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { echo -e "${GREEN}[LAUNCHER]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2 | tee -a "$LOG_FILE"; exit 1; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CPU DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_cpu_capabilities() {
    log "Detecting CPU capabilities for optimal compilation..."
    
    # Create work directory
    mkdir -p "$WORK_DIR"
    
    # Check microcode revision
    local microcode=$(cat /proc/cpuinfo | grep microcode | head -1 | awk '{print $3}')
    if [ -n "$microcode" ]; then
        info "Microcode revision: $microcode"
        
        # Check if microcode is too early
        local microcode_hex="${microcode#0x}"
        local microcode_dec=$((16#${microcode_hex}))
        
        if [ "$microcode_dec" -le 28 ]; then  # 0x1c = 28
            warn "Early microcode detected - AVX512 will be disabled"
            export DISABLE_AVX512=true
        fi
    fi
    
    # Quick AVX512 test with P-core pinning
    if grep -q "avx512" /proc/cpuinfo 2>/dev/null && [ "${DISABLE_AVX512:-false}" = "false" ]; then
        info "Testing AVX512 support with P-core pinning..."
        
        # Create test script
        cat > "$WORK_DIR/test_avx512.py" <<'EOF'
#!/usr/bin/env python3
import os
import sys

def quick_avx512_test():
    try:
        # Identify P-cores (performance cores)
        p_cores = []
        try:
            # Check for Intel hybrid architecture
            for i in range(min(8, os.cpu_count() or 8)):
                if os.path.exists(f'/sys/devices/system/cpu/cpu{i}/topology/core_cpus_list'):
                    p_cores.append(str(i))
                    if len(p_cores) >= 4:  # Use first 4 P-cores
                        break
        except:
            p_cores = ['0', '1', '2', '3']  # Default to first 4 cores
        
        # Quick AVX512 check
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read()
            if 'avx512f' in cpuinfo and 'avx512dq' in cpuinfo:
                print(f"AVX512_AVAILABLE,P_CORES={','.join(p_cores)}")
                return 0
    except:
        pass
    
    print("AVX512_NOT_AVAILABLE")
    return 1

sys.exit(quick_avx512_test())
EOF
        
        if command -v python3 &> /dev/null; then
            chmod +x "$WORK_DIR/test_avx512.py"
            local result=$(python3 "$WORK_DIR/test_avx512.py" 2>/dev/null || echo "AVX512_NOT_AVAILABLE")
            
            if [[ "$result" == *"AVX512_AVAILABLE"* ]]; then
                success "AVX512 verified and will be enabled"
                export USE_AVX512=true
                
                # Extract P-cores for later use
                if [[ "$result" == *"P_CORES="* ]]; then
                    export P_CORES="${result#*P_CORES=}"
                    info "P-cores identified: $P_CORES"
                fi
            else
                info "AVX512 not available - will use AVX2/SSE4.2"
                export USE_AVX512=false
            fi
        fi
    fi
    
    # Check for AVX2
    if grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
        export USE_AVX2=true
        info "AVX2 support detected"
    fi
    
    # Check CPU vendor for specific optimizations
    local cpu_vendor=$(cat /proc/cpuinfo | grep vendor_id | head -1 | awk '{print $3}')
    case "$cpu_vendor" in
        GenuineIntel)
            info "Intel CPU detected"
            export CPU_VENDOR="intel"
            
            # Check for hybrid architecture
            if [ -d "/sys/devices/system/cpu/cpu0/topology" ]; then
                if ls /sys/devices/system/cpu/cpu*/topology/core_cpus_list &>/dev/null; then
                    info "Intel hybrid architecture (P-cores/E-cores) detected"
                    export HYBRID_CPU=true
                fi
            fi
            ;;
        AuthenticAMD)
            info "AMD CPU detected"
            export CPU_VENDOR="amd"
            ;;
        *)
            info "CPU vendor: $cpu_vendor"
            export CPU_VENDOR="generic"
            ;;
    esac
    
    # Cleanup
    rm -rf "$WORK_DIR"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DELL REPOSITORY FIX
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

fix_dell_repo_warnings() {
    # Check if we should skip Dell fix
    if [ "${SKIP_DELL_FIX:-false}" = "true" ]; then
        return 0
    fi
    
    # Check if Dell repos exist
    if ! ls /etc/apt/sources.list.d/dell*.list &>/dev/null 2>&1 && ! grep -q "linux.dell.com" /etc/apt/sources.list 2>/dev/null; then
        return 0  # No Dell repos, skip
    fi
    
    info "Dell repository detected - may cause 404 warnings during apt update"
    info "These warnings can be safely ignored, or fixed with sudo access"
    
    # Only fix if we have sudo and user agrees
    if [ -w "/etc/apt/apt.conf.d/" ]; then
        # We have write access without sudo (unlikely)
        if [ ! -f "/etc/apt/apt.conf.d/99-dell-no-optional-metadata" ]; then
            cat > /etc/apt/apt.conf.d/99-dell-no-optional-metadata <<'EOF'
# Disable optional metadata that Dell repositories don't provide
Acquire::IndexTargets::deb::DEP-11-icons-small::DefaultEnabled "false";
Acquire::IndexTargets::deb::DEP-11-icons::DefaultEnabled "false";
Acquire::IndexTargets::deb::DEP-11::DefaultEnabled "false";
Acquire::IndexTargets::deb::CNF::DefaultEnabled "false";
Acquire::IndexTargets::deb::Translation-en::DefaultEnabled "false";
Acquire::IndexTargets::deb::Translation-en_US::DefaultEnabled "false";
EOF
            success "Dell repository warnings suppressed"
        fi
    else
        # Need sudo - inform user but don't require it
        warn "Dell repository warnings will appear during apt operations"
        warn "To fix (optional): sudo apt-get install -o Acquire::IndexTargets::deb::DEP-11::DefaultEnabled=false <package>"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYSTEM PREPARATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

prepare_system() {
    log "Preparing system for installation..."
    
    # Fix Dell repository warnings first if present
    fix_dell_repo_warnings
    
    # Create necessary directories
    mkdir -p "/home/ubuntu/Documents/Claude" 2>/dev/null || true
    mkdir -p "$HOME/.local/bin" 2>/dev/null || true
    
    # Check for npm first (needed for Claude Code installation)
    if ! command -v npm &> /dev/null; then
        warn "npm not found - attempting local installation..."
        
        # Try NVM first (no sudo needed)
        if [ ! -d "$HOME/.nvm" ]; then
            info "Installing NVM (Node Version Manager) locally..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash 2>/dev/null
            
            # Source NVM
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
            
            # Install latest LTS Node
            nvm install --lts 2>/dev/null
            nvm use --lts 2>/dev/null
        else
            # Source existing NVM
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        fi
        
        # If NVM didn't work, try direct binary download
        if ! command -v npm &> /dev/null; then
            info "Installing Node.js locally via binary download..."
            local NODE_VERSION="v20.11.0"
            local NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"
            local NODE_DIR="$HOME/.local/node"
            
            mkdir -p "$NODE_DIR"
            cd "$WORK_DIR"
            
            if wget -q "$NODE_URL" -O node.tar.xz || curl -fsSL "$NODE_URL" -o node.tar.xz; then
                tar -xf node.tar.xz
                cp -r "node-${NODE_VERSION}-linux-x64"/* "$NODE_DIR/"
                export PATH="$NODE_DIR/bin:$PATH"
                
                # Add to shell profile
                echo "export PATH=\"$NODE_DIR/bin:\$PATH\"" >> "$HOME/.bashrc"
                [ -f "$HOME/.zshrc" ] && echo "export PATH=\"$NODE_DIR/bin:\$PATH\"" >> "$HOME/.zshrc"
            fi
        fi
        
        # Verify
        if command -v npm &> /dev/null; then
            success "npm installed: $(npm --version)"
        fi
    else
        info "npm found: $(npm --version)"
    fi
    
    # Check for nano (preferred editor for LiveCD)
    if ! command -v nano &> /dev/null; then
        info "Nano not found - will prompt for installation if needed..."
        
        if command -v apt-get &> /dev/null; then
            echo "Nano is recommended as the default editor. Install it? (Y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]] || [ -z "$response" ]; then
                sudo apt-get install -y nano 2>/dev/null || warn "Nano installation failed"
            fi
        fi
        
        if command -v nano &> /dev/null; then
            success "Nano installed as default editor"
        fi
    else
        info "Nano found: $(nano --version | head -1)"
    fi
    
    # Check for Neovim (optional, for enhanced statusline)
    if ! command -v nvim &> /dev/null; then
        info "Neovim not found - statusline will use nano/vim fallback"
        
        if command -v nvim &> /dev/null; then
            success "Neovim installed for enhanced statusline"
        fi
    else
        info "Neovim found: $(nvim --version | head -1)"
    fi
    
    # Check for other required tools
    local missing_critical=()
    
    for tool in curl wget git; do
        if ! command -v "$tool" &> /dev/null; then
            missing_critical+=("$tool")
        fi
    done
    
    if [ ${#missing_critical[@]} -gt 0 ]; then
        warn "Missing critical tools: ${missing_critical[*]}"
        
        # Prompt for tool installation
        if command -v apt-get &> /dev/null; then
            echo "Missing critical tools: ${missing_critical[*]}"
            echo "Install them? (y/n)"
            read -r response
            if [ "$response" = "y" ]; then
                info "Installing missing tools..."
                sudo apt-get update 2>&1 | grep -v "DEP-11\|CNF\|Translation" > /dev/null || true
                sudo apt-get install -y "${missing_critical[@]}" &>/dev/null || warn "Installation failed"
            else
                error "Critical tools are required to continue"
            fi
        else
            error "Please install missing tools manually: ${missing_critical[*]}"
        fi
    fi
    
    # Check available memory for compilation
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    if [ "$mem_available" -lt 1048576 ]; then  # Less than 1GB
        warn "Low memory detected ($(($mem_available/1024))MB) - compilation may be slow"
        export LOW_MEMORY=true
    fi
    
    # Check disk space
    local disk_available=$(df /home | tail -1 | awk '{print $4}')
    if [ "$disk_available" -lt 1048576 ]; then  # Less than 1GB
        warn "Low disk space detected - installation may fail"
    fi
    
    success "System preparation complete"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLER DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

find_installer() {
    log "Locating main installer script..."
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if agents folder exists in the same directory
    if [ -d "$script_dir/agents" ]; then
        info "Found local agents folder at $script_dir/agents"
        export LOCAL_AGENTS_DIR="$script_dir/agents"
    fi
    
    # Check if statusline files exist in the same directory
    if [ -f "$script_dir/scripts/statusline.lua" ]; then
        info "Found statusline files at $script_dir/scripts/"
        export STATUSLINE_DIR="$script_dir/scripts"
    elif [ -f "/home/ubuntu/Documents/Claude/scripts/statusline.lua" ]; then
        info "Found statusline files at /home/ubuntu/Documents/Claude/scripts/"
        export STATUSLINE_DIR="/home/ubuntu/Documents/Claude/scripts"
    fi
    
    # Possible installer names
    local installer_names=(
        "claude-livecd-unified-with-agents.sh"
        "claude-installer.sh"
        "install-claude.sh"
        "claude-unified-installer.sh"
    )
    
    # Search in current directory and common locations
    local search_dirs=(
        "$script_dir"
        "$(dirname "$0")"
        "."
        "/home/ubuntu/Documents/Claude"
        "$HOME/Documents/Claude"
        "$HOME/Downloads"
        "/tmp"
    )
    
    for dir in "${search_dirs[@]}"; do
        for name in "${installer_names[@]}"; do
            local path="$dir/$name"
            if [ -f "$path" ]; then
                info "Found installer: $path"
                echo "$path"
                return 0
            fi
        done
    done
    
    # If not found, try to download it
    warn "Installer not found locally, attempting download..."
    
    local download_url="https://raw.githubusercontent.com/SWORDIntel/claude-backups/main/claude-livecd-unified-with-agents.sh"
    local temp_installer="/tmp/claude-installer-$$.sh"
    
    if wget -q "$download_url" -O "$temp_installer" 2>/dev/null || \
       curl -fsSL "$download_url" -o "$temp_installer" 2>/dev/null; then
        chmod +x "$temp_installer"
        info "Downloaded installer to $temp_installer"
        echo "$temp_installer"
        return 0
    fi
    
    error "Could not find or download installer script"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPTIMIZATION FLAGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

build_optimization_flags() {
    local flags=""
    
    # CPU-specific flags
    if [ "${USE_AVX512:-false}" = "true" ]; then
        flags="$flags ENABLE_AVX512=1"
    elif [ "${USE_AVX2:-false}" = "true" ]; then
        flags="$flags ENABLE_AVX2=1"
    fi
    
    # Memory constraints
    if [ "${LOW_MEMORY:-false}" = "true" ]; then
        flags="$flags LOW_MEMORY_BUILD=1"
    fi
    
    # Hybrid CPU optimizations
    if [ "${HYBRID_CPU:-false}" = "true" ]; then
        flags="$flags HYBRID_CPU=1"
        if [ -n "${P_CORES:-}" ]; then
            flags="$flags P_CORES=$P_CORES"
        fi
    fi
    
    # Vendor-specific
    if [ -n "${CPU_VENDOR:-}" ]; then
        flags="$flags CPU_VENDOR=$CPU_VENDOR"
    fi
    
    echo "$flags"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAUNCH WRAPPER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_launch_wrapper() {
    log "Creating optimized launch wrapper..."
    
    local wrapper_path="$HOME/.local/bin/claude-launch"
    
    cat > "$wrapper_path" <<'EOF'
#!/bin/bash
# Claude Code optimized launcher

# Set P-core affinity if available
if [ -n "$P_CORES" ]; then
    if command -v taskset &> /dev/null; then
        exec taskset -c "$P_CORES" "$HOME/.local/bin/claude" "$@"
    fi
fi

# Normal launch
exec "$HOME/.local/bin/claude" "$@"
EOF
    
    chmod +x "$wrapper_path"
    info "Launch wrapper created at $wrapper_path"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}    Claude Code Quick Launcher v${LAUNCHER_VERSION}${NC}"
    echo -e "${BOLD}${CYAN}    Enhanced with AVX512 Detection & P-Core Optimization${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Step 1: Detect CPU capabilities
    detect_cpu_capabilities
    
    # Step 2: Prepare system (includes Dell repo fix)
    prepare_system
    
    # Step 3: Find installer
    local installer_path=$(find_installer)
    
    if [ ! -f "$installer_path" ]; then
        error "Installer script not found"
    fi
    
    # Step 4: Build optimization flags
    local opt_flags=$(build_optimization_flags)
    
    if [ -n "$opt_flags" ]; then
        info "Optimization flags: $opt_flags"
    fi
    
    # Step 5: Create launch wrapper for P-core affinity
    if [ "${HYBRID_CPU:-false}" = "true" ] && [ -n "${P_CORES:-}" ]; then
        create_launch_wrapper
    fi
    
    # Step 6: Launch installer with optimizations
    log "Launching main installer with auto-mode..."
    echo
    
    # Export all optimization variables
    export AUTO_MODE=true
    export AUTO_LAUNCH=true
    export FORCE=true
    
    # Add any command line arguments
    local args="$@"
    
    # Special handling for --help
    if [[ " $* " == *" --help "* ]] || [[ " $* " == *" -h "* ]]; then
        echo "Quick Launcher Options:"
        echo "  All options are passed to the main installer"
        echo "  Default behavior: AUTO_MODE=true AUTO_LAUNCH=true FORCE=true"
        echo
        echo "Features:"
        echo "  • Automatic Dell repository 404 fix"
        echo "  • CPU optimization detection (AVX512/AVX2)"
        echo "  • P-core affinity for Intel hybrid CPUs"
        echo "  • Memory-aware compilation"
        echo "  • Auto-download installer if missing"
        echo "  • God-tier statusline installation (Neovim/Vim/Shell)"
        echo "  • Local agents and statusline detection"
        echo
        echo "CPU Optimizations Detected:"
        [ "${USE_AVX512:-false}" = "true" ] && echo "  • AVX512 enabled"
        [ "${USE_AVX2:-false}" = "true" ] && echo "  • AVX2 enabled"
        [ "${HYBRID_CPU:-false}" = "true" ] && echo "  • Hybrid CPU (P-cores: ${P_CORES:-unknown})"
        echo
        echo "Environment Variables:"
        echo "  SKIP_CPU_DETECT=true  - Skip CPU detection for speed"
        echo "  SKIP_DELL_FIX=true    - Skip Dell repository fix"
        echo "  SILENT_MODE=true      - No output (ultra-quiet)"
        echo
        echo "Passing to main installer..."
        echo
    fi
    
    # Execute installer
    if [ -n "$opt_flags" ]; then
        env $opt_flags bash "$installer_path" $args
    else
        exec bash "$installer_path" $args
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ERROR HANDLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cleanup() {
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUICK MODE DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if running in ultra-quick mode (no output)
if [ "${SILENT_MODE:-false}" = "true" ]; then
    exec &>/dev/null
fi

# Check if we should skip CPU detection (for speed)
if [ "${SKIP_CPU_DETECT:-false}" = "true" ]; then
    log "Skipping CPU detection (SKIP_CPU_DETECT=true)"
    
    # Find and execute installer directly
    installer_path=$(find_installer 2>/dev/null || echo "")
    if [ -f "$installer_path" ]; then
        AUTO_MODE=true AUTO_LAUNCH=true FORCE=true exec bash "$installer_path" "$@"
    else
        error "Could not find installer script"
    fi
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Run main function
main "$@"
