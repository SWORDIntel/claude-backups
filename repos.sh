#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ FIX PYTHON ON UBUNTU 24.04+ WITH PEP 668 PROTECTION                        ║
# ║ Handles externally-managed-environment properly                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

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
# │ SYSTEM CHECKS                                                               │
# └──────────────────────────────────────────────────────────────────────────────┘

check_system() {
    log "Performing system checks..."
    
    # Check Python installation
    if command -v python3 &>/dev/null; then
        local py_version=$(python3 --version)
        success "Python installed: $py_version"
    else
        error "Python3 not found!"
        return 1
    fi
    
    # Check pip status
    if python3 -m pip --version >/dev/null 2>&1; then
        local pip_version=$(python3 -m pip --version)
        success "pip available: $pip_version"
    else
        warn "pip not installed or not working"
        info "Will attempt to install pip during setup"
    fi
    
    # Check for PEP 668 protection
    if [ -f /usr/lib/python3*/EXTERNALLY-MANAGED ]; then
        info "PEP 668 protection: ACTIVE"
    else
        info "PEP 668 protection: INACTIVE"
    fi
    
    # Check repository status
    if grep -q "^deb.*canonical" /etc/apt/sources.list 2>/dev/null; then
        warn "Problematic canonical repository detected"
    fi
    
    # Check for duplicate repositories
    local dup_test=$($SUDO apt-get update 2>&1 | grep -c "configured multiple times" || echo "0")
    if [ "$dup_test" -gt 0 ]; then
        warn "Found $dup_test duplicate repository entries"
    fi
    
    # Check DNS
    if nslookup google.com >/dev/null 2>&1; then
        success "DNS resolution working"
    else
        warn "DNS resolution issues detected"
    fi
    
    return 0
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ FIX DNS AND REPOSITORY ISSUES                                               │
# └──────────────────────────────────────────────────────────────────────────────┘

fix_dns_and_repos() {
    log "Fixing DNS and repository configuration..."
    
    # Backup current DNS configuration
    $SUDO cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    
    # Set reliable DNS servers (Google and Cloudflare)
    info "Setting reliable DNS servers..."
    cat << 'EOF' | $SUDO tee /etc/resolv.conf > /dev/null
# Fixed DNS configuration
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    
    # AGGRESSIVE repository cleanup
    info "Cleaning up repository configuration..."
    
    # Backup sources.list
    $SUDO cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d) 2>/dev/null || true
    
    # Method 1: Disable ALL entries in sources.list to prevent duplicates
    info "Disabling all entries in sources.list (using ubuntu.sources instead)..."
    $SUDO sed -i 's/^deb /#deb /g' /etc/apt/sources.list
    $SUDO sed -i 's/^deb-src /#deb-src /g' /etc/apt/sources.list
    
    # Method 2: Specifically target and disable canonical entries
    $SUDO sed -i '/canonical\.com/s/^deb/#deb/' /etc/apt/sources.list
    $SUDO sed -i '/canonical\.com/s/^/#*/#/' /etc/apt/sources.list
    
    # Verify canonical is disabled
    if grep -q "^deb.*canonical" /etc/apt/sources.list; then
        warn "Canonical repository still active, using nuclear option..."
        # Nuclear option - completely clear sources.list
        $SUDO bash -c 'cat > /etc/apt/sources.list << EOF
# Ubuntu 24.04 Noble repositories
# All repositories managed by /etc/apt/sources.list.d/ubuntu.sources
# Legacy entries disabled to prevent conflicts and errors
EOF'
    fi
    
    # Ensure we have working Ubuntu repositories via new format
    if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        info "Creating modern ubuntu.sources file..."
        cat << 'EOF' | $SUDO tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null
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
    fi
    
    # Clean apt cache
    info "Cleaning apt cache..."
    $SUDO apt-get clean
    
    # Update package lists
    info "Updating package lists..."
    if $SUDO apt-get update 2>&1 | tee /tmp/apt-update.log | grep -E "canonical|404|Failed"; then
        error "Repository errors detected. Check /tmp/apt-update.log"
    else
        success "Repositories updated successfully"
    fi
    
    success "DNS and repositories configured"
    
    # Test DNS resolution
    info "Testing DNS resolution..."
    if nslookup archive.ubuntu.com >/dev/null 2>&1; then
        success "DNS resolution working"
    else
        warn "DNS resolution may still have issues"
    fi
    
    # Test connectivity to repositories
    info "Testing repository connectivity..."
    if curl -s --connect-timeout 5 http://archive.ubuntu.com >/dev/null 2>&1; then
        success "Repository connectivity working"
    else
        warn "Repository connectivity issues detected"
    fi
    
    # Report duplicate warnings
    local dup_count=$(grep -c "configured multiple times" /tmp/apt-update.log 2>/dev/null || echo "0")
    if [ "$dup_count" -gt 0 ]; then
        warn "Found $dup_count duplicate repository warnings"
        info "Run 'cat /tmp/apt-update.log' to see details"
    fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 1: INSTALL PYTHON-FULL AND PIPX (RECOMMENDED)                       │
# └──────────────────────────────────────────────────────────────────────────────┐

install_python_full() {
    log "Installing python3-full and pipx (Ubuntu recommended method)..."
    
    # Fix DNS and repositories first
    fix_dns_and_repos
    
    # Update package list
    info "Updating package lists..."
    $SUDO apt-get update || error "Failed to update package lists"
    
    # Install python3-full which includes everything needed for venvs
    info "Installing Python packages..."
    $SUDO apt-get install -y \
        python3-full \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        python3-setuptools \
        python3-wheel || error "Failed to install Python packages"
    
    # Install pipx separately to handle potential failures
    info "Installing pipx..."
    $SUDO apt-get install -y pipx || warn "Failed to install pipx via apt"
    
    # Verify pip is installed
    if ! python3 -m pip --version >/dev/null 2>&1; then
        warn "pip not found, attempting manual installation..."
        # Download and install pip manually
        info "Downloading get-pip.py..."
        curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
        $SUDO python3 /tmp/get-pip.py --break-system-packages || error "Failed to install pip manually"
    fi
    
    # Ensure pipx path is in PATH
    if command -v pipx &>/dev/null; then
        pipx ensurepath
        success "pipx installed and configured"
    else
        warn "pipx not available, may need manual installation"
    fi
    
    success "python3-full installation complete"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 2: OVERRIDE PEP 668 (USE WITH CAUTION)                              │
# └──────────────────────────────────────────────────────────────────────────────┘

override_pep668() {
    log "Overriding PEP 668 protection (USE WITH CAUTION)..."
    
    # Method 1: Remove the EXTERNALLY-MANAGED file
    if [ -f /usr/lib/python3*/EXTERNALLY-MANAGED ]; then
        warn "Removing EXTERNALLY-MANAGED file..."
        $SUDO rm -f /usr/lib/python3*/EXTERNALLY-MANAGED
        success "PEP 668 protection removed"
    fi
    
    # Method 2: Configure pip to break system packages
    log "Configuring pip to allow system packages..."
    
    # Global config (for all users)
    if [ "$EUID" -eq 0 ]; then
        mkdir -p /etc/pip
        cat > /etc/pip/pip.conf << 'EOF'
[global]
break-system-packages = true
user = false
EOF
        success "Global pip config created"
    fi
    
    # User config
    mkdir -p "$USER_HOME/.config/pip"
    cat > "$USER_HOME/.config/pip/pip.conf" << 'EOF'
[global]
break-system-packages = true
user = false
EOF
    success "User pip config created"
    
    # Also set environment variable
    export PIP_BREAK_SYSTEM_PACKAGES=1
    echo "export PIP_BREAK_SYSTEM_PACKAGES=1" >> "$USER_HOME/.bashrc"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 3: CREATE DEVELOPMENT ENVIRONMENT                                    │
# └──────────────────────────────────────────────────────────────────────────────┘

create_dev_environment() {
    log "Creating development environment..."
    
    # Ensure we have a working python3-venv package
    if ! python3 -m venv --help >/dev/null 2>&1; then
        warn "python3-venv not available, installing dependencies..."
        fix_dns_and_repos
        $SUDO apt-get update
        $SUDO apt-get install -y python3-venv python3-dev python3-pip
    fi
    
    # Create a directory for virtual environments
    DEV_DIR="$USER_HOME/python-dev"
    mkdir -p "$DEV_DIR"
    
    # Create main development virtual environment
    info "Creating virtual environment at $DEV_DIR/venv..."
    python3 -m venv "$DEV_DIR/venv"
    
    # Activate and upgrade pip
    source "$DEV_DIR/venv/bin/activate"
    
    # Upgrade pip in the virtual environment
    python -m pip install --upgrade pip setuptools wheel
    
    # Install development tools
    info "Installing development tools in virtual environment..."
    pip install \
        black \
        flake8 \
        pylint \
        pytest \
        ipython \
        jupyter \
        notebook \
        jupyterlab \
        pandas \
        numpy \
        matplotlib \
        requests \
        virtualenv
    
    deactivate
    
    # Create activation script
    cat > "$DEV_DIR/activate.sh" << 'EOF'
#!/bin/bash
source ~/python-dev/venv/bin/activate
echo "Python development environment activated!"
echo "Python: $(which python)"
echo "Pip: $(which pip)"
EOF
    chmod +x "$DEV_DIR/activate.sh"
    
    success "Development environment created at $DEV_DIR"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 4: INSTALL WITH PIPX                                                 │
# └──────────────────────────────────────────────────────────────────────────────┘

install_with_pipx() {
    log "Installing Python tools with pipx..."
    
    # Ensure pipx is in PATH
    export PATH="$USER_HOME/.local/bin:$PATH"
    
    # Install tools that work well as standalone applications
    local tools=(
        "black"
        "flake8"
        "pylint"
        "pytest"
        "poetry"
        "ipython"
        "jupyter"
        "cookiecutter"
        "httpie"
        "glances"
    )
    
    for tool in "${tools[@]}"; do
        info "Installing $tool with pipx..."
        pipx install "$tool" || warn "Failed to install $tool"
    done
    
    # For jupyter, also inject commonly needed packages
    pipx inject jupyter numpy pandas matplotlib || true
    
    success "Tools installed with pipx"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 5: SYSTEM-WIDE INSTALL WITH --break-system-packages                  │
# └──────────────────────────────────────────────────────────────────────────────┘

force_system_install() {
    log "Force installing packages system-wide..."
    
    # Check if pip is available
    if ! python3 -m pip --version >/dev/null 2>&1; then
        warn "pip not installed, attempting to install it first..."
        
        # Try to install pip via apt
        $SUDO apt-get update
        $SUDO apt-get install -y python3-pip || {
            error "Failed to install pip via apt, trying manual installation..."
            # Download and install pip manually
            curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
            $SUDO python3 /tmp/get-pip.py --break-system-packages || {
                error "Failed to install pip. Cannot proceed with system-wide package installation."
                return 1
            }
        }
    fi
    
    # Verify pip is now available
    if ! python3 -m pip --version >/dev/null 2>&1; then
        error "pip still not available after installation attempts"
        return 1
    fi
    
    # Upgrade pip with break-system-packages
    info "Upgrading pip..."
    python3 -m pip install --upgrade pip --break-system-packages || warn "Failed to upgrade pip"
    
    # Install packages
    local packages=(
        "virtualenv"
        "black"
        "flake8"
        "pylint"
        "pytest"
        "ipython"
        "notebook"
        "jupyterlab"
        "pandas"
        "numpy"
        "matplotlib"
        "requests"
    )
    
    for pkg in "${packages[@]}"; do
        info "Installing $pkg..."
        python3 -m pip install "$pkg" --break-system-packages || warn "Failed: $pkg"
    done
    
    success "Packages installed system-wide"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ VERIFICATION                                                                 │
# └──────────────────────────────────────────────────────────────────────────────┘

verify_installation() {
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    VERIFICATION                                    ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Python and pip
    echo "System Python:"
    python3 --version
    python3 -m pip --version 2>/dev/null || echo "  System pip: Not working without --break-system-packages"
    echo
    
    # Virtual environment
    if [ -f "$USER_HOME/python-dev/venv/bin/python" ]; then
        echo "Development Environment:"
        echo "  Location: $USER_HOME/python-dev/venv"
        echo "  Activate with: source ~/python-dev/activate.sh"
        "$USER_HOME/python-dev/venv/bin/python" --version
        echo "  Installed packages:"
        "$USER_HOME/python-dev/venv/bin/pip" list | grep -E "black|pytest|jupyter|ipython" | head -5
        echo
    fi
    
    # Pipx
    if command -v pipx &>/dev/null; then
        echo "Pipx tools:"
        pipx list 2>/dev/null | head -10 || echo "  No tools installed yet"
        echo
    fi
    
    # Check if PEP 668 is still active
    if [ -f /usr/lib/python3*/EXTERNALLY-MANAGED ]; then
        echo "PEP 668 Status: ACTIVE (system packages protected)"
    else
        echo "PEP 668 Status: DISABLED (system packages unprotected)"
    fi
    echo
    
    # DNS Configuration
    echo "DNS Configuration:"
    if grep -q "8.8.8.8" /etc/resolv.conf 2>/dev/null; then
        echo "  Status: FIXED (using reliable DNS servers)"
        echo "  Primary: 8.8.8.8 (Google)"
        echo "  Backup: 1.1.1.1 (Cloudflare)"
    else
        echo "  Status: Default system DNS"
    fi
    echo
    
    # Repository Status
    echo "Repository Status:"
    if grep -q "^#.*canonical" /etc/apt/sources.list 2>/dev/null; then
        echo "  Canonical partner: DISABLED (prevents 404 errors)"
    else
        echo "  Canonical partner: Active (may cause errors)"
    fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ MAIN MENU                                                                   │
# └──────────────────────────────────────────────────────────────────────────────┘

main() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        FIX PYTHON ON UBUNTU 24.04+ (PEP 668 PROTECTED)              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "Ubuntu 24.04+ protects system Python packages (PEP 668)."
    echo "This script provides multiple solutions:"
    echo
    echo "  1) Install python3-full + pipx (RECOMMENDED - Ubuntu way)"
    echo "  2) Create development virtual environment (SAFE)"
    echo "  3) Override PEP 668 protection (RISKY - may break system)"
    echo "  4) Force install with --break-system-packages (RISKY)"
    echo "  5) Do all safe methods (1 + 2)"
    echo "  6) Do everything including risky methods"
    echo "  7) Fix DNS and repositories only"
    echo "  0) Exit"
    echo
    
    read -p "Select option [0-7]: " choice
    echo
    
    case $choice in
        1)
            install_python_full
            install_with_pipx
            ;;
        2)
            create_dev_environment
            ;;
        3)
            read -p "This may break system packages. Continue? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                override_pep668
            fi
            ;;
        4)
            read -p "This may break system packages. Continue? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                force_system_install
            fi
            ;;
        5)
            install_python_full
            create_dev_environment
            install_with_pipx
            ;;
        6)
            read -p "This includes risky methods. Continue? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                install_python_full
                override_pep668
                create_dev_environment
                install_with_pipx
                force_system_install
            fi
            ;;
        7)
            fix_dns_and_repos
            info "Testing repository access..."
            $SUDO apt-get update
            success "DNS and repository fixes applied"
            ;;
        0)
            exit 0
            ;;
        *)
            error "Invalid option"
            exit 1
            ;;
    esac
    
    # Verify installation (skip for DNS-only option)
    if [ "$choice" != "7" ] && [ "$choice" != "0" ]; then
        verify_installation
        
        echo
        echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                    SETUP COMPLETE                                  ${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    fi
    echo
    echo "RECOMMENDED USAGE:"
    echo
    echo "1. For project development:"
    echo "   source ~/python-dev/activate.sh"
    echo "   pip install <any-package>"
    echo
    echo "2. For standalone tools:"
    echo "   pipx install <tool-name>"
    echo
    echo "3. For Jupyter:"
    if [ -f "$USER_HOME/python-dev/venv/bin/jupyter" ]; then
        echo "   source ~/python-dev/activate.sh"
        echo "   jupyter notebook"
    else
        echo "   pipx run jupyter notebook"
    fi
    echo
    echo "4. To create new project environments:"
    echo "   python3 -m venv myproject"
    echo "   source myproject/bin/activate"
    echo
    
    # Add to PATH if needed
    if ! echo "$PATH" | grep -q "$USER_HOME/.local/bin"; then
        echo "Add to your ~/.bashrc:"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Run main function
main