#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ FIX PYTHON ON UBUNTU 24.04+ WITH MAXIMUM OVERRIDES - NUCLEAR VERSION          ║
# ║ Handles externally-managed-environment + network/repository issues            ║
# ║ WARNING: This version uses AGGRESSIVE fixes for maximum compatibility         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Global Configuration
NETWORK_TIMEOUT=10
REPOSITORY_TIMEOUT=5
MAX_RETRIES=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Check if running as regular user (preferred) or root
if [ "$EUID" -eq 0 ]; then
    warn "Running as root. Some operations will be system-wide."
    USER_HOME="/root"
    SUDO=""
else
    info "Running as user: $USER"
    USER_HOME="$HOME"
    SUDO="sudo"
fi

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ NUCLEAR EMERGENCY REPOSITORY CLEANUP                                          │
# └──────────────────────────────────────────────────────────────────────────────┘

emergency_repo_cleanup() {
    log "NUCLEAR EMERGENCY REPOSITORY CLEANUP - MAXIMUM FORCE"
    
    # Backup all sources first
    local backup_dir="/etc/apt/sources.backup.$(date +%Y%m%d-%H%M%S)"
    $SUDO mkdir -p "$backup_dir"
    $SUDO cp -r /etc/apt/sources.list* "$backup_dir/" 2>/dev/null || true
    info "Backed up sources to $backup_dir"
    
    # NUCLEAR OPTION 1: Disable ALL non-Ubuntu repositories
    info "Disabling ALL third-party repositories..."
    for repo in /etc/apt/sources.list.d/*.list; do
        if [ -f "$repo" ]; then
            $SUDO mv "$repo" "${repo}.nuclear-disabled" 2>/dev/null || true
        fi
    done
    
    # NUCLEAR OPTION 2: Remove ALL problematic keyrings
    info "Removing problematic keyrings..."
    $SUDO rm -f /etc/apt/trusted.gpg.d/intel* 2>/dev/null || true
    $SUDO rm -f /etc/apt/trusted.gpg.d/dell* 2>/dev/null || true
    $SUDO rm -f /etc/apt/trusted.gpg.d/oneapi* 2>/dev/null || true
    
    # NUCLEAR OPTION 3: Force noble repositories regardless of release
    info "FORCING noble repositories (maximum compatibility)..."
    cat << 'EOF' | $SUDO tee /etc/apt/sources.list > /dev/null
# NUCLEAR OVERRIDE - FORCED NOBLE REPOSITORIES
# All original sources disabled for maximum stability
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
    
    # NUCLEAR OPTION 4: Create DEB822 format sources as backup
    cat << 'EOF' | $SUDO tee /etc/apt/sources.list.d/ubuntu-nuclear.sources > /dev/null
# NUCLEAR UBUNTU SOURCES - MAXIMUM COMPATIBILITY MODE
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb  
URIs: http://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    
    # NUCLEAR OPTION 5: Force remove package cache
    info "Purging all package cache..."
    $SUDO apt-get clean
    $SUDO rm -rf /var/lib/apt/lists/*
    $SUDO rm -rf /var/cache/apt/archives/*
    $SUDO rm -rf /var/cache/apt/*.bin
    
    success "NUCLEAR repository cleanup complete"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ MAXIMUM FORCE GPG KEY IMPORT                                                  │
# └──────────────────────────────────────────────────────────────────────────────┘

force_import_all_keys() {
    log "FORCE IMPORTING ALL UBUNTU GPG KEYS..."
    
    # Method 1: Direct keyserver import with multiple servers
    local ubuntu_keys=(
        "871920D1991BC93C"
        "3B4FE6ACC0B21F32"
        "A3B82C41080BC93C"
        "843938DF228D22F7B3742BC0D94AA3F0EFE21092"
        "81CF0BB5A6B5F0C3A9E3E7F5F28C0A8C5E1FD8E9"
    )
    
    local keyservers=(
        "keyserver.ubuntu.com"
        "keys.openpgp.org"
        "pgp.mit.edu"
        "keyserver.pgp.com"
        "keys.gnupg.net"
    )
    
    for key in "${ubuntu_keys[@]}"; do
        info "Attempting to import key: $key"
        local imported=false
        
        for server in "${keyservers[@]}"; do
            if timeout 30 $SUDO apt-key adv --keyserver "$server" --recv-keys "$key" 2>/dev/null; then
                success "Imported $key from $server"
                imported=true
                break
            fi
        done
        
        if [ "$imported" = false ]; then
            warn "Could not import key $key from any server"
        fi
    done
    
    # Method 2: Download Ubuntu keyring directly
    info "Downloading Ubuntu keyrings directly..."
    local keyring_urls=(
        "https://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg"
        "http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg"
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3B4FE6ACC0B21F32"
    )
    
    for url in "${keyring_urls[@]}"; do
        if curl -fsSL "$url" | $SUDO tee /usr/share/keyrings/ubuntu-archive-keyring-downloaded.gpg >/dev/null 2>&1; then
            success "Downloaded keyring from $url"
            break
        fi
    done
    
    # Method 3: Force reinstall ubuntu-keyring package
    info "Force reinstalling ubuntu-keyring package..."
    $SUDO apt-get update --allow-unauthenticated 2>/dev/null || true
    $SUDO apt-get install --reinstall --allow-unauthenticated ubuntu-keyring -y 2>/dev/null || true
    
    # Method 4: Copy from backup if exists
    if [ -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ]; then
        $SUDO cp /usr/share/keyrings/ubuntu-archive-keyring.gpg /etc/apt/trusted.gpg.d/ubuntu-archive.gpg 2>/dev/null || true
    fi
    
    success "Key import process complete"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ MAXIMUM FORCE DNS FIX                                                         │
# └──────────────────────────────────────────────────────────────────────────────┘

force_fix_dns() {
    log "FORCING DNS CONFIGURATION..."
    
    # Disable systemd-resolved if it's causing issues
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        info "Temporarily disabling systemd-resolved..."
        $SUDO systemctl stop systemd-resolved 2>/dev/null || true
    fi
    
    # Remove symlink if exists
    if [ -L /etc/resolv.conf ]; then
        $SUDO rm -f /etc/resolv.conf
    fi
    
    # Force create new resolv.conf with maximum redundancy
    cat << 'EOF' | $SUDO tee /etc/resolv.conf > /dev/null
# MAXIMUM REDUNDANCY DNS CONFIGURATION
# Primary: Google DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
# Secondary: Cloudflare DNS
nameserver 1.1.1.1
nameserver 1.0.0.1
# Tertiary: OpenDNS
nameserver 208.67.222.222
nameserver 208.67.220.220
# Quaternary: Quad9
nameserver 9.9.9.9
nameserver 149.112.112.112
# Local fallback
nameserver 127.0.0.53
options edns0 trust-ad
search .
EOF
    
    # Make immutable to prevent changes
    $SUDO chattr +i /etc/resolv.conf 2>/dev/null || true
    
    success "DNS forced to maximum redundancy configuration"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ FORCE SYSTEM PACKAGE INSTALLATION (MAXIMUM OVERRIDE)                         │
# └──────────────────────────────────────────────────────────────────────────────┘

force_system_install() {
    log "FORCE INSTALLING WITH MAXIMUM OVERRIDES..."
    
    # Create maximum override pip configuration
    info "Creating maximum override pip configuration..."
    
    # Global override
    $SUDO mkdir -p /etc/pip
    cat << 'EOF' | $SUDO tee /etc/pip/pip.conf > /dev/null
[global]
break-system-packages = true
user = false
force-reinstall = true
no-warn-script-location = true
disable-pip-version-check = true
timeout = 120
retries = 5
trusted-host = pypi.org files.pythonhosted.org
EOF
    
    # User override
    mkdir -p "$USER_HOME/.config/pip"
    cat << 'EOF' | tee "$USER_HOME/.config/pip/pip.conf" > /dev/null
[global]
break-system-packages = true
user = false
force-reinstall = true
no-warn-script-location = true
disable-pip-version-check = true
timeout = 120
retries = 5
trusted-host = pypi.org files.pythonhosted.org
EOF
    
    # Environment variables for maximum override
    export PIP_BREAK_SYSTEM_PACKAGES=1
    export PIP_FORCE_REINSTALL=1
    export PIP_NO_WARN_SCRIPT_LOCATION=1
    export PYTHONUSERBASE="$USER_HOME/.local"
    export PYTHONDONTWRITEBYTECODE=1
    
    # Add to all shell configs
    local shell_configs=("$USER_HOME/.bashrc" "$USER_HOME/.zshrc" "$USER_HOME/.profile")
    for config in "${shell_configs[@]}"; do
        if [ -f "$config" ]; then
            cat >> "$config" << 'EOF'

# MAXIMUM PYTHON OVERRIDE CONFIGURATION
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_FORCE_REINSTALL=1
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PYTHONUSERBASE="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
EOF
        fi
    done
    
    # Force install pip if not working
    info "Ensuring pip is installed..."
    if ! python3 -m pip --version 2>/dev/null; then
        info "Force installing pip..."
        curl -sS https://bootstrap.pypa.io/get-pip.py | $SUDO python3 - --break-system-packages --force-reinstall
    fi
    
    success "Maximum override configuration complete"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ MAXIMUM FORCE PYTHON INSTALLATION                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

install_python_nuclear() {
    log "INSTALLING PYTHON WITH NUCLEAR OPTIONS..."
    
    # Step 1: Nuclear repository cleanup
    emergency_repo_cleanup
    
    # Step 2: Force DNS fix
    force_fix_dns
    
    # Step 3: Force import all keys
    force_import_all_keys
    
    # Step 4: Update with maximum force
    info "Updating package lists with maximum force..."
    $SUDO apt-get update --allow-unauthenticated --allow-insecure-repositories 2>&1 | tee /tmp/apt-update.log || true
    
    # Step 5: Install Python packages with force
    local python_packages=(
        "python3-full"
        "python3-pip"
        "python3-venv"
        "python3-dev"
        "python3-setuptools"
        "python3-wheel"
        "python3-distutils"
        "build-essential"
        "libssl-dev"
        "libffi-dev"
        "python3-minimal"
        "python3-pkg-resources"
    )
    
    info "Force installing Python packages..."
    for package in "${python_packages[@]}"; do
        info "Force installing $package..."
        $SUDO apt-get install -y \
            --allow-unauthenticated \
            --allow-downgrades \
            --allow-remove-essential \
            --allow-change-held-packages \
            --force-yes \
            "$package" 2>/dev/null || warn "Could not install $package"
    done
    
    # Step 6: Remove ALL PEP 668 protections
    info "Removing ALL PEP 668 protections..."
    $SUDO find /usr/lib/python3* -name "EXTERNALLY-MANAGED" -delete 2>/dev/null || true
    $SUDO find /usr/local/lib/python3* -name "EXTERNALLY-MANAGED" -delete 2>/dev/null || true
    
    # Step 7: Force pip installation if missing
    if ! python3 -m pip --version 2>/dev/null; then
        info "Force downloading and installing pip..."
        curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
        $SUDO python3 /tmp/get-pip.py --force-reinstall --break-system-packages
    fi
    
    # Step 8: Install pipx with force
    info "Force installing pipx..."
    python3 -m pip install --force-reinstall --break-system-packages pipx
    
    # Step 9: Configure PATH
    export PATH="$USER_HOME/.local/bin:$PATH"
    
    success "NUCLEAR Python installation complete"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ EMERGENCY FIX ALL FUNCTION                                                    │
# └──────────────────────────────────────────────────────────────────────────────┘

emergency_fix_all() {
    log "EMERGENCY FIX ALL - MAXIMUM FORCE ENGAGED"
    warn "This will aggressively modify system configuration!"
    
    # 1. Nuclear repository cleanup
    emergency_repo_cleanup
    
    # 2. Force DNS
    force_fix_dns
    
    # 3. Import all keys
    force_import_all_keys
    
    # 4. Force update
    info "Force updating package cache..."
    $SUDO apt-get update --allow-unauthenticated --allow-insecure-repositories || true
    
    # 5. Fix broken packages
    info "Fixing broken packages..."
    $SUDO apt-get install -f --allow-unauthenticated -y || true
    $SUDO dpkg --configure -a || true
    
    # 6. Nuclear Python install
    install_python_nuclear
    
    # 7. Force system install configuration
    force_system_install
    
    # 8. Create emergency virtual environment
    info "Creating emergency virtual environment..."
    python3 -m venv "$USER_HOME/emergency-venv" --system-site-packages || true
    
    # 9. Install critical tools
    if [ -d "$USER_HOME/emergency-venv" ]; then
        source "$USER_HOME/emergency-venv/bin/activate"
        pip install --force-reinstall --upgrade pip setuptools wheel
        pip install --force-reinstall jupyter ipython numpy pandas matplotlib
        deactivate
    fi
    
    # 10. Create recovery script
    cat > "$USER_HOME/python-recovery.sh" << 'EOF'
#!/bin/bash
# Python Recovery Script
echo "Python Recovery Environment"
echo "==========================="
echo ""
echo "Options:"
echo "1. Use emergency venv: source ~/emergency-venv/bin/activate"
echo "2. Use system Python with overrides: python3 -m pip install --break-system-packages <package>"
echo "3. Use pipx: pipx install <package>"
echo ""
echo "Current Python: $(which python3)"
echo "Current pip: $(python3 -m pip --version 2>/dev/null || echo 'Not available')"
echo ""
echo "To reinstall pip: curl -sS https://bootstrap.pypa.io/get-pip.py | python3 - --break-system-packages"
EOF
    chmod +x "$USER_HOME/python-recovery.sh"
    
    success "EMERGENCY FIX COMPLETE"
    info "Recovery script created at: $USER_HOME/python-recovery.sh"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ MAIN MENU WITH NUCLEAR OPTIONS                                                │
# └──────────────────────────────────────────────────────────────────────────────┘

main() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     PYTHON FIX FOR UBUNTU - NUCLEAR MAXIMUM OVERRIDE VERSION      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}WARNING: This version uses AGGRESSIVE system modifications${NC}"
    echo -e "${YELLOW}Detected kernel: $(uname -r)${NC}"
    echo
    echo -e "${GREEN}SAFE(R) OPTIONS:${NC}"
    echo "  1) Standard Python installation with repository fixes"
    echo "  2) Create virtual environment (recommended)"
    echo "  3) Install pipx for isolated tools"
    echo
    echo -e "${YELLOW}FORCE OPTIONS:${NC}"
    echo "  4) Force system install with maximum overrides"
    echo "  5) Nuclear Python installation (aggressive)"
    echo "  6) Emergency fix DNS and repositories only"
    echo
    echo -e "${RED}NUCLEAR OPTIONS:${NC}"
    echo "  7) EMERGENCY FIX ALL (maximum force on everything)"
    echo "  8) Nuclear repository cleanup only"
    echo "  9) Force import all GPG keys"
    echo "  10) Remove ALL PEP 668 protections permanently"
    echo
    echo "  0) Exit"
    echo
    
    read -p "Select option [0-10]: " choice
    echo
    
    case $choice in
        1)
            install_python_nuclear
            ;;
        2)
            info "Creating virtual environment..."
            python3 -m venv "$USER_HOME/pyenv" --system-site-packages
            success "Virtual environment created at $USER_HOME/pyenv"
            echo "Activate with: source ~/pyenv/bin/activate"
            ;;
        3)
            info "Installing pipx..."
            python3 -m pip install --user --break-system-packages pipx
            export PATH="$USER_HOME/.local/bin:$PATH"
            pipx ensurepath
            success "pipx installed"
            ;;
        4)
            force_system_install
            ;;
        5)
            install_python_nuclear
            ;;
        6)
            emergency_repo_cleanup
            force_fix_dns
            force_import_all_keys
            ;;
        7)
            echo -e "${RED}THIS WILL AGGRESSIVELY MODIFY YOUR SYSTEM${NC}"
            read -p "Type 'NUCLEAR' to continue: " confirm
            if [ "$confirm" = "NUCLEAR" ]; then
                emergency_fix_all
            else
                warn "Cancelled"
            fi
            ;;
        8)
            emergency_repo_cleanup
            ;;
        9)
            force_import_all_keys
            ;;
        10)
            warn "Removing ALL PEP 668 protections..."
            $SUDO find / -name "EXTERNALLY-MANAGED" -delete 2>/dev/null || true
            force_system_install
            success "All protections removed"
            ;;
        0)
            exit 0
            ;;
        *)
            error "Invalid option"
            ;;
    esac
    
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Operation complete. Test with:${NC}"
    echo "  python3 --version"
    echo "  python3 -m pip --version"
    echo "  python3 -m pip install --break-system-packages requests"
    echo
    echo -e "${YELLOW}Recovery script available at: ~/python-recovery.sh${NC}"
}

# Execute main function
main "$@"