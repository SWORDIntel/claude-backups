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
# │ METHOD 1: INSTALL PYTHON-FULL AND PIPX (RECOMMENDED)                       │
# └──────────────────────────────────────────────────────────────────────────────┐

install_python_full() {
    log "Installing python3-full and pipx (Ubuntu recommended method)..."
    
    # Update package list
    $SUDO apt-get update
    
    # Install python3-full which includes everything needed for venvs
    $SUDO apt-get install -y \
        python3-full \
        python3-pip \
        python3-venv \
        python3-dev \
        pipx \
        build-essential \
        python3-setuptools \
        python3-wheel
    
    # Ensure pipx path is in PATH
    pipx ensurepath
    
    success "python3-full and pipx installed"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ METHOD 2: OVERRIDE PEP 668 (USE WITH CAUTION)                              │
# └──────────────────────────────────────────────────────────────────────────────┐

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
# └──────────────────────────────────────────────────────────────────────────────┐

create_dev_environment() {
    log "Creating development environment..."
    
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
# └──────────────────────────────────────────────────────────────────────────────┐

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
    
    # Upgrade pip with break-system-packages
    python3 -m pip install --upgrade pip --break-system-packages
    
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
# └──────────────────────────────────────────────────────────────────────────────┐

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
    echo "  0) Exit"
    echo
    
    read -p "Select option [0-6]: " choice
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
        0)
            exit 0
            ;;
        *)
            error "Invalid option"
            exit 1
            ;;
    esac
    
    # Verify
    verify_installation
    
    echo
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    SETUP COMPLETE                                  ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
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

# Run main
main
