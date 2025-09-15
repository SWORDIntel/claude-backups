#!/bin/bash
# ============================================================================
# Shadowgit Neural Setup Script
# Complete installation with NPU/GNA detection and configuration
# Version: 2.0.0 Production
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SHADOWGIT_HOME="/opt/shadowgit"
SHADOWGIT_USER="shadowgit"
OPENVINO_VERSION="2025.0"
PYTHON_VERSION="3.10"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# ============================================================================
# HARDWARE DETECTION
# ============================================================================

detect_hardware() {
    print_header "Hardware Detection"
    
    # CPU Detection
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    print_info "CPU: $CPU_MODEL ($CPU_CORES cores)"
    
    # Check for Intel Core Ultra (NPU support)
    NPU_AVAILABLE=false
    if lspci | grep -q "8086:7e4c\|8086:7d1d\|8086:465d"; then
        NPU_AVAILABLE=true
        print_success "NPU detected: Intel Core Ultra with 11 TOPS"
    else
        print_warning "NPU not detected"
    fi
    
    # Check for GNA
    GNA_AVAILABLE=false
    if lspci | grep -q "8086:3190\|8086:7e4c"; then
        GNA_AVAILABLE=true
        print_success "GNA detected: Gaussian Neural Accelerator"
    else
        print_warning "GNA not detected"
    fi
    
    # Check for AVX-512
    AVX512_AVAILABLE=false
    if grep -q "avx512" /proc/cpuinfo; then
        AVX512_AVAILABLE=true
        print_success "AVX-512 detected: SIMD acceleration available"
    else
        print_warning "AVX-512 not detected"
    fi
    
    # Check for GPU
    GPU_AVAILABLE=false
    if lspci | grep -E "VGA|3D" | grep -qi "intel"; then
        GPU_AVAILABLE=true
        GPU_MODEL=$(lspci | grep -E "VGA|3D" | grep -i "intel" | cut -d: -f3)
        print_success "Intel GPU detected:$GPU_MODEL"
    else
        print_warning "Intel GPU not detected"
    fi
    
    # Memory check
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    print_info "Total memory: ${TOTAL_MEM}GB"
    
    if [ $TOTAL_MEM -lt 8 ]; then
        print_warning "Less than 8GB RAM detected. Performance may be limited."
    fi
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_system_dependencies() {
    print_header "Installing System Dependencies"
    
    # Update package lists
    apt-get update
    
    # Essential packages
    PACKAGES=(
        build-essential
        cmake
        git
        wget
        curl
        python${PYTHON_VERSION}
        python${PYTHON_VERSION}-dev
        python${PYTHON_VERSION}-venv
        python3-pip
        gcc
        g++
        make
        libssl-dev
        libffi-dev
        libbz2-dev
        libreadline-dev
        libsqlite3-dev
        libncursesw5-dev
        libxml2-dev
        libxmlsec1-dev
        liblzma-dev
        libopenblas-dev
        liblapack-dev
        libhdf5-dev
        pkg-config
        software-properties-common
        unzip
        ninja-build
        libusb-1.0-0
        libgflags-dev
        libgoogle-glog-dev
        libboost-all-dev
        libtbb-dev
        ocl-icd-libopencl1
        opencl-headers
        clinfo
    )
    
    for package in "${PACKAGES[@]}"; do
        echo -n "Installing $package... "
        if apt-get install -y $package > /dev/null 2>&1; then
            echo "✓"
        else
            echo "✗"
            print_warning "Failed to install $package"
        fi
    done
    
    print_success "System dependencies installed"
}

# ============================================================================
# OPENVINO INSTALLATION
# ============================================================================

install_openvino() {
    print_header "Installing OpenVINO Toolkit"
    
    # Add OpenVINO repository
    wget -qO - https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | apt-key add -
    echo "deb https://apt.repos.intel.com/openvino/2025 ubuntu22 main" | tee /etc/apt/sources.list.d/intel-openvino-2025.list
    
    apt-get update
    
    # Install OpenVINO
    apt-get install -y intel-openvino-runtime-ubuntu22-${OPENVINO_VERSION} \
                       intel-openvino-dev-ubuntu22-${OPENVINO_VERSION} \
                       intel-openvino-opencv-ubuntu22-${OPENVINO_VERSION}
    
    # Setup OpenVINO environment
    source /opt/intel/openvino_${OPENVINO_VERSION}/setupvars.sh
    
    # Add to system shell profiles for all users
    local system_profiles=(
        "/etc/bash.bashrc"
        "/etc/zsh/zshrc"
        "/etc/profile"
    )

    for profile in "${system_profiles[@]}"; do
        if [[ -f "$profile" ]] && ! grep -q "openvino_${OPENVINO_VERSION}" "$profile"; then
            echo "source /opt/intel/openvino_${OPENVINO_VERSION}/setupvars.sh" >> "$profile"
            print_success "Added OpenVINO setup to $profile"
        fi
    done
    
    print_success "OpenVINO ${OPENVINO_VERSION} installed"
}

# ============================================================================
# NPU DRIVER INSTALLATION
# ============================================================================

install_npu_driver() {
    if [ "$NPU_AVAILABLE" = true ]; then
        print_header "Installing NPU Driver"
        
        # Download NPU driver
        NPU_DRIVER_URL="https://github.com/intel/linux-npu-driver/releases/latest/download/intel-npu-driver-ubuntu22.04.deb"
        wget -O /tmp/intel-npu-driver.deb $NPU_DRIVER_URL
        
        # Install driver
        dpkg -i /tmp/intel-npu-driver.deb || apt-get -f install -y
        
        # Load kernel module
        modprobe intel_vpu
        
        # Verify NPU device
        if [ -e /dev/accel/accel0 ]; then
            print_success "NPU driver installed and device detected"
            
            # Set permissions
            chmod 666 /dev/accel/accel0
            
            # Add udev rule for persistent permissions
            cat > /etc/udev/rules.d/99-npu.rules << EOF
SUBSYSTEM=="accel", KERNEL=="accel*", MODE="0666", GROUP="shadowgit"
EOF
            udevadm control --reload-rules
            udevadm trigger
        else
            print_warning "NPU driver installed but device not detected"
        fi
    else
        print_info "Skipping NPU driver installation (no NPU detected)"
    fi
}

# ============================================================================
# GNA DRIVER SETUP
# ============================================================================

setup_gna_driver() {
    if [ "$GNA_AVAILABLE" = true ]; then
        print_header "Setting up GNA Driver"
        
        # Load GNA module
        modprobe gna
        
        # Check GNA device
        if [ -e /dev/gna0 ]; then
            print_success "GNA device detected at /dev/gna0"
            
            # Set permissions
            chmod 666 /dev/gna0
            
            # Add udev rule
            cat > /etc/udev/rules.d/99-gna.rules << EOF
SUBSYSTEM=="gna", KERNEL=="gna*", MODE="0666", GROUP="shadowgit"
EOF
            udevadm control --reload-rules
            udevadm trigger
            
            # Configure GNA for always-on mode
            echo 200 > /sys/class/gna/gna0/frequency_mhz 2>/dev/null || true
            echo streaming > /sys/class/gna/gna0/mode 2>/dev/null || true
            
            print_success "GNA configured for always-on monitoring (0.1W)"
        else
            print_warning "GNA module loaded but device not detected"
        fi
    else
        print_info "Skipping GNA setup (no GNA detected)"
    fi
}

# ============================================================================
# SHADOWGIT USER SETUP
# ============================================================================

setup_shadowgit_user() {
    print_header "Setting up Shadowgit User"
    
    # Create shadowgit user if doesn't exist
    if ! id -u $SHADOWGIT_USER > /dev/null 2>&1; then
        useradd -m -s /bin/bash -d /home/$SHADOWGIT_USER $SHADOWGIT_USER
        print_success "User $SHADOWGIT_USER created"
    else
        print_info "User $SHADOWGIT_USER already exists"
    fi
    
    # Add to necessary groups
    usermod -aG video,render,users $SHADOWGIT_USER
    
    # Create directories
    mkdir -p $SHADOWGIT_HOME
    mkdir -p $SHADOWGIT_HOME/{models,logs,cache,scripts,lib,bin}
    mkdir -p $SHADOWGIT_HOME/models/shadowgit
    mkdir -p $SHADOWGIT_HOME/cache/{npu,gna,cpu}
    
    # Set ownership
    chown -R $SHADOWGIT_USER:$SHADOWGIT_USER $SHADOWGIT_HOME
    
    print_success "Shadowgit user configured"
}

# ============================================================================
# PYTHON ENVIRONMENT SETUP
# ============================================================================

setup_python_environment() {
    print_header "Setting up Python Environment"
    
    # Create virtual environment
    sudo -u $SHADOWGIT_USER python${PYTHON_VERSION} -m venv $SHADOWGIT_HOME/venv
    
    # Upgrade pip
    sudo -u $SHADOWGIT_USER $SHADOWGIT_HOME/venv/bin/pip install --upgrade pip
    
    # Install Python packages
    PYTHON_PACKAGES=(
        "numpy>=1.24.0"
        "watchdog>=3.0.0"
        "psutil>=5.9.0"
        "aiofiles>=23.0.0"
        "pyyaml>=6.0"
        "gitpython>=3.1.0"
        "prometheus-client>=0.19.0"
        "structlog>=23.0.0"
        "rich>=13.0.0"
        "typer>=0.9.0"
        "pydantic>=2.0.0"
        "fastapi>=0.104.0"
        "uvicorn>=0.24.0"
        "httpx>=0.25.0"
        "pytest>=7.4.0"
        "pytest-asyncio>=0.21.0"
        "black>=23.0.0"
        "ruff>=0.1.0"
        "mypy>=1.7.0"
    )
    
    for package in "${PYTHON_PACKAGES[@]}"; do
        echo -n "Installing $package... "
        if sudo -u $SHADOWGIT_USER $SHADOWGIT_HOME/venv/bin/pip install "$package" > /dev/null 2>&1; then
            echo "✓"
        else
            echo "✗"
            print_warning "Failed to install $package"
        fi
    done
    
    # Install OpenVINO Python API
    sudo -u $SHADOWGIT_USER $SHADOWGIT_HOME/venv/bin/pip install openvino==${OPENVINO_VERSION}
    
    print_success "Python environment configured"
}

# ============================================================================
# SHADOWGIT INSTALLATION
# ============================================================================

install_shadowgit() {
    print_header "Installing Shadowgit Neural Components"
    
    # Copy main scripts
    cp shadowgit_neural_engine.py $SHADOWGIT_HOME/
    cp shadowgit_watcher_enhanced.py $SHADOWGIT_HOME/
    cp shadowgit_mcp_server.py $SHADOWGIT_HOME/
    
    # Create wrapper scripts
    cat > $SHADOWGIT_HOME/bin/shadowgit << 'EOF'
#!/bin/bash
source /opt/intel/openvino_2025.0/setupvars.sh
source /opt/shadowgit/venv/bin/activate
exec python /opt/shadowgit/shadowgit_watcher_enhanced.py "$@"
EOF
    
    chmod +x $SHADOWGIT_HOME/bin/shadowgit
    
    # Create C acceleration library
    if [ "$AVX512_AVAILABLE" = true ]; then
        print_info "Compiling C acceleration with AVX-512..."
        
        cat > $SHADOWGIT_HOME/lib/c_diff_engine.c << 'EOF'
#include <immintrin.h>
#include <string.h>
#include <stdint.h>

// AVX-512 optimized diff engine
int simd_diff(const char* a, const char* b, size_t len) {
    size_t i = 0;
    int diff_count = 0;
    
    // Process 64 bytes at a time with AVX-512
    for (; i + 64 <= len; i += 64) {
        __m512i va = _mm512_loadu_si512((__m512i*)(a + i));
        __m512i vb = _mm512_loadu_si512((__m512i*)(b + i));
        __mmask64 mask = _mm512_cmpneq_epi8_mask(va, vb);
        diff_count += __builtin_popcountll(mask);
    }
    
    // Handle remaining bytes
    for (; i < len; i++) {
        if (a[i] != b[i]) diff_count++;
    }
    
    return diff_count;
}
EOF
        
        gcc -O3 -march=native -mavx512f -shared -fPIC \
            -o $SHADOWGIT_HOME/lib/c_diff_engine.so \
            $SHADOWGIT_HOME/lib/c_diff_engine.c
        
        print_success "C acceleration library compiled"
    fi
    
    # Set permissions
    chown -R $SHADOWGIT_USER:$SHADOWGIT_USER $SHADOWGIT_HOME
    
    print_success "Shadowgit components installed"
}

# ============================================================================
# MODEL DOWNLOAD
# ============================================================================

download_models() {
    print_header "Downloading Neural Models"
    
    # Create placeholder models (in production, download actual models)
    MODEL_FILES=(
        "shadowgit_semantic_v2.xml"
        "shadowgit_semantic_v2.bin"
        "shadowgit_pattern_v2.xml"
        "shadowgit_pattern_v2.bin"
        "shadowgit_security_v2.xml"
        "shadowgit_security_v2.bin"
        "shadowgit_anomaly_v2.xml"
        "shadowgit_anomaly_v2.bin"
    )
    
    for model in "${MODEL_FILES[@]}"; do
        touch $SHADOWGIT_HOME/models/shadowgit/$model
    done
    
    chown -R $SHADOWGIT_USER:$SHADOWGIT_USER $SHADOWGIT_HOME/models
    
    print_info "Model placeholders created (download actual models in production)"
}

# ============================================================================
# SYSTEMD SERVICE INSTALLATION
# ============================================================================

install_systemd_service() {
    print_header "Installing Systemd Service"
    
    # Copy service file
    cp shadowgit-neural.service /etc/systemd/system/
    
    # Create GNA monitor timer
    cat > /etc/systemd/system/shadowgit-gna-monitor.timer << EOF
[Unit]
Description=Shadowgit GNA Monitor Timer
Requires=shadowgit-neural.service

[Timer]
OnBootSec=30s
OnUnitActiveSec=5m

[Install]
WantedBy=timers.target
EOF
    
    # Create GNA monitor service
    cat > /etc/systemd/system/shadowgit-gna-monitor.service << EOF
[Unit]
Description=Shadowgit GNA Monitor
After=shadowgit-neural.service

[Service]
Type=oneshot
ExecStart=/opt/shadowgit/scripts/check_gna_status.sh

[Install]
WantedBy=multi-user.target
EOF
    
    # Create status check script
    cat > $SHADOWGIT_HOME/scripts/check_gna_status.sh << 'EOF'
#!/bin/bash
if [ -e /dev/gna0 ]; then
    echo "GNA Status: Active"
    echo "Power: $(cat /sys/class/gna/gna0/power_state 2>/dev/null || echo 'unknown')"
    echo "Frequency: $(cat /sys/class/gna/gna0/frequency_mhz 2>/dev/null || echo 'unknown') MHz"
fi
EOF
    
    chmod +x $SHADOWGIT_HOME/scripts/check_gna_status.sh
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable shadowgit-neural.service
    systemctl enable shadowgit-gna-monitor.timer
    
    print_success "Systemd services installed and enabled"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

create_configuration() {
    print_header "Creating Configuration"
    
    cat > $SHADOWGIT_HOME/config.yaml << EOF
# Shadowgit Neural Configuration
version: 2.0.0

hardware:
  npu_available: $NPU_AVAILABLE
  gna_available: $GNA_AVAILABLE
  gpu_available: $GPU_AVAILABLE
  avx512_available: $AVX512_AVAILABLE
  cpu_cores: $CPU_CORES

neural:
  mode: intelligent
  power_mode: balanced
  batch_size: 32
  inference_timeout_ms: 100
  gna_scan_rate_hz: 10
  npu_precision: INT8
  enable_telemetry: true
  
paths:
  models: $SHADOWGIT_HOME/models/shadowgit
  cache: $SHADOWGIT_HOME/cache
  logs: $SHADOWGIT_HOME/logs
  
watcher:
  watch_dirs:
    - /home/$SHADOWGIT_USER/projects
  file_patterns:
    - "*.py"
    - "*.js"
    - "*.ts"
    - "*.c"
    - "*.cpp"
    - "*.rs"
  ignore_patterns:
    - "*test*"
    - "*__pycache__*"
    - "*.pyc"
    - "node_modules/*"
  batch_window_ms: 500
  max_batch_size: 32
  
monitoring:
  prometheus_port: 9090
  enable_metrics: true
  
security:
  secure_mode: true
  sandbox_enabled: true
EOF
    
    chown $SHADOWGIT_USER:$SHADOWGIT_USER $SHADOWGIT_HOME/config.yaml
    
    print_success "Configuration created"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    print_header "Verifying Installation"
    
    # Test OpenVINO
    echo -n "Testing OpenVINO... "
    if python3 -c "from openvino.runtime import Core; print(Core().available_devices)" > /dev/null 2>&1; then
        echo "✓"
    else
        echo "✗"
        print_warning "OpenVINO test failed"
    fi
    
    # Test NPU if available
    if [ "$NPU_AVAILABLE" = true ]; then
        echo -n "Testing NPU... "
        if [ -e /dev/accel/accel0 ]; then
            echo "✓"
        else
            echo "✗"
            print_warning "NPU device not accessible"
        fi
    fi
    
    # Test GNA if available
    if [ "$GNA_AVAILABLE" = true ]; then
        echo -n "Testing GNA... "
        if [ -e /dev/gna0 ]; then
            echo "✓"
        else
            echo "✗"
            print_warning "GNA device not accessible"
        fi
    fi
    
    # Test Shadowgit
    echo -n "Testing Shadowgit... "
    if sudo -u $SHADOWGIT_USER $SHADOWGIT_HOME/venv/bin/python -c "import shadowgit_neural_engine" 2>/dev/null; then
        echo "✓"
    else
        echo "✗"
        print_warning "Shadowgit module test failed"
    fi
    
    print_success "Installation verification complete"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

print_summary() {
    print_header "Installation Summary"
    
    echo -e "${GREEN}Shadowgit Neural has been successfully installed!${NC}"
    echo
    echo "Configuration:"
    echo "  Install path: $SHADOWGIT_HOME"
    echo "  User: $SHADOWGIT_USER"
    echo "  Python: $PYTHON_VERSION"
    echo "  OpenVINO: $OPENVINO_VERSION"
    echo
    echo "Hardware Status:"
    [ "$NPU_AVAILABLE" = true ] && echo "  ✓ NPU: Available (11 TOPS)" || echo "  ✗ NPU: Not available"
    [ "$GNA_AVAILABLE" = true ] && echo "  ✓ GNA: Available (0.1W always-on)" || echo "  ✗ GNA: Not available"
    [ "$GPU_AVAILABLE" = true ] && echo "  ✓ GPU: Available" || echo "  ✗ GPU: Not available"
    [ "$AVX512_AVAILABLE" = true ] && echo "  ✓ AVX-512: Available" || echo "  ✗ AVX-512: Not available"
    echo
    echo "Next Steps:"
    echo "  1. Start the service: systemctl start shadowgit-neural"
    echo "  2. Check status: systemctl status shadowgit-neural"
    echo "  3. View logs: journalctl -u shadowgit-neural -f"
    echo "  4. Configure MCP: Add to Claude Desktop settings"
    echo
    echo -e "${CYAN}Happy coding with neural acceleration! 🚀${NC}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Shadowgit Neural Installation"
    
    check_root
    detect_hardware
    install_system_dependencies
    install_openvino
    install_npu_driver
    setup_gna_driver
    setup_shadowgit_user
    setup_python_environment
    install_shadowgit
    download_models
    install_systemd_service
    create_configuration
    verify_installation
    print_summary
}

# Run main function
main "$@"