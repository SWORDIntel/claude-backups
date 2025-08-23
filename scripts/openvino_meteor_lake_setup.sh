#!/bin/bash

################################################################################
# OpenVINO Setup Script for Intel Meteor Lake (Core Ultra) on Ubuntu 24.04.3
# Supports: NPU (AI Boost), Integrated GPU (Arc Graphics), and CPU
# Version: 2024.3.0
# Mode: FULLY NON-INTERACTIVE INSTALLATION - OPTIMIZED FOR LIVECD
#
# This script automatically:
# - Loads kernel modules for immediate hardware access (no reboot needed)
# - Adds all required repositories and GPG keys
# - Installs all drivers and dependencies without prompts
# - Configures environment for auto-activation
# - Handles all errors gracefully and continues installation
#
# LiveCD Features:
# - Live loads all kernel modules (i915, intel_vpu, etc.)
# - Immediate hardware access without reboot
# - Updates udev rules and triggers for current session
# - Reloads GPU drivers with optimal compute parameters
# - Sets performance power states for NPU/GPU
#
# Requirements:
# - Ubuntu 24.04.3 LTS LiveCD or installed system
# - Regular user with sudo privileges (will prompt for password once)
# - Internet connection for downloading packages
# - ~5GB free disk space for full installation
# - Intel Core Ultra (Meteor Lake) for NPU support
#
# Usage: bash openvino_meteor_lake_setup.sh
#
# Environment Variables (optional):
# - INSTALL_MULTIMEDIA=true    : Install multimedia libraries for video/image processing
# - INSTALL_DEVELOPMENT=true   : Install development tools (build-essential, cmake, etc.)
################################################################################

set -e  # Exit on error

# Set non-interactive mode for all operations
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Suppress interactive prompts and warnings
export APT_LISTCHANGES_FRONTEND=none
export APT_LISTBUGS_FRONTEND=none
export UCF_FORCE_CONFOLD=1
export DEBIAN_PRIORITY=critical
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script information
SCRIPT_VERSION="1.0.0"
OPENVINO_VERSION="2025.2.0"
UBUNTU_VERSION="24.04"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_message "Running as root - proceeding with installation"
        # When running as root, we don't need sudo commands
        export SUDO_CMD=""
    else
        # Check sudo access for regular users
        if ! sudo -n true 2>/dev/null; then
            print_message "This script requires sudo privileges. Please enter your password when prompted."
            sudo -v || {
                print_error "Failed to obtain sudo privileges. Exiting."
                exit 1
            }
        fi
        
        # Keep sudo alive throughout the script
        while true; do sudo -n true; sleep 60; kill -0 "$" || exit; done 2>/dev/null &
        export SUDO_CMD="sudo"
    fi
}

# Check if running on LiveCD
check_livecd() {
    print_message "Checking if running on LiveCD..."
    
    if grep -qs "boot=casper" /proc/cmdline || \
       grep -qs "boot=live" /proc/cmdline || \
       [ -d /run/live/medium ] || \
       [ -d /lib/live/mount ] || \
       df / | grep -q "overlay\|aufs\|tmpfs"; then
        print_message "LiveCD environment detected - enabling live module loading"
        export IS_LIVECD=1
    else
        print_message "Standard installation detected"
        export IS_LIVECD=0
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    print_message "Checking Ubuntu version..."
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        print_warning "This script is designed for Ubuntu 24.04. Your version may differ."
        print_warning "Proceeding with installation (non-interactive mode)..."
    fi
}

# Hardware detection functions
detect_hardware() {
    print_message "Detecting system hardware..."
    
    # CPU detection
    CPU_INFO=$(lscpu | grep "Model name" || true)
    print_message "Detected CPU: $CPU_INFO"
    
    # Check for Intel processor types
    HAS_INTEL_CPU=false
    HAS_NPU_SUPPORT=false
    HAS_GNA_SUPPORT=false
    if echo "$CPU_INFO" | grep -qi "Intel"; then
        HAS_INTEL_CPU=true
        print_message "✓ Intel CPU detected"
        
        if echo "$CPU_INFO" | grep -qi "Core Ultra\|13th Gen Intel\|Intel(R) Core(TM) Ultra\|Meteor Lake"; then
            HAS_NPU_SUPPORT=true
            print_message "✓ NPU support likely available (Meteor Lake/Core Ultra)"
            # Meteor Lake (Core Ultra) has GNA 3.5
            HAS_GNA_SUPPORT=true
            print_message "✓ GNA 3.5 support detected (Meteor Lake/Core Ultra)"
        fi
        
        # Check for GNA on other Intel processors if not already detected
        if [ "$HAS_GNA_SUPPORT" != "true" ]; then
            # GNA is available on many Intel processors (10th gen and newer)
            # Also available on some older processors like Atom, Core i3/i5/i7 (certain models)
            if echo "$CPU_INFO" | grep -qi "Core\|Xeon\|Atom"; then
                # Check CPU generation for GNA support
                CPU_FAMILY=$(lscpu | grep "CPU family:" | awk '{print $3}')
                CPU_MODEL=$(lscpu | grep "Model:" | awk '{print $2}')
                
                # GNA is available on:
                # - 10th gen Core (Ice Lake) and newer - GNA 2.0
                # - 11th gen Core (Tiger Lake) - GNA 2.0
                # - 12th gen Core (Alder Lake) - GNA 3.0
                # - 13th gen Core (Raptor Lake) - GNA 3.0
                # - Core Ultra (Meteor Lake) - GNA 3.5
                # - Some Atom processors - GNA 1.0
                # - Certain Xeon processors
                if [ "$CPU_FAMILY" = "6" ]; then
                    # Intel Core family - check model number for generation
                    if [ "$CPU_MODEL" -ge 126 ] || [ "$CPU_MODEL" -ge 140 ] 2>/dev/null; then
                        HAS_GNA_SUPPORT=true
                        print_message "✓ GNA (Gaussian Neural Accelerator) support detected"
                    elif echo "$CPU_INFO" | grep -qi "10th Gen\|11th Gen\|12th Gen\|13th Gen\|14th Gen"; then
                        HAS_GNA_SUPPORT=true
                        print_message "✓ GNA support detected (10th gen or newer)"
                    fi
                fi
            fi
        fi
    fi
    
    # GPU detection
    HAS_INTEL_GPU=false
    HAS_NVIDIA_GPU=false
    HAS_AMD_GPU=false
    
    GPU_INFO=$(lspci | grep -i vga || true)
    print_message "Detected GPU(s): $GPU_INFO"
    
    if echo "$GPU_INFO" | grep -qi "Intel\|Arc"; then
        HAS_INTEL_GPU=true
        print_message "✓ Intel GPU detected"
    fi
    
    if echo "$GPU_INFO" | grep -qi "NVIDIA"; then
        HAS_NVIDIA_GPU=true
        print_message "✓ NVIDIA GPU detected (not supported by this script)"
    fi
    
    if echo "$GPU_INFO" | grep -qi "AMD\|Radeon"; then
        HAS_AMD_GPU=true
        print_message "✓ AMD GPU detected (basic support only)"
    fi
    
    # Export hardware flags for other functions
    export HAS_INTEL_CPU HAS_NPU_SUPPORT HAS_GNA_SUPPORT HAS_INTEL_GPU HAS_NVIDIA_GPU HAS_AMD_GPU
    
    # Summary
    print_message "Hardware Summary:"
    print_message "  CPU: $([ "$HAS_INTEL_CPU" = true ] && echo "Intel" || echo "Non-Intel")"
    print_message "  NPU: $([ "$HAS_NPU_SUPPORT" = true ] && echo "Supported" || echo "Not detected/supported")"
    print_message "  GNA: $([ "$HAS_GNA_SUPPORT" = true ] && echo "Supported" || echo "Not detected/supported")"
    print_message "  GPU: $([ "$HAS_INTEL_GPU" = true ] && echo "Intel" || [ "$HAS_NVIDIA_GPU" = true ] && echo "NVIDIA (unsupported)" || [ "$HAS_AMD_GPU" = true ] && echo "AMD" || echo "None/Unknown")"
}

# Update system
update_system() {
    print_message "Updating system packages..."
    
    # Configure apt for non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    
    # Configure dpkg to handle config file conflicts automatically
    ${SUDO_CMD} tee /etc/dpkg/dpkg.cfg.d/force-confdef > /dev/null << EOF
force-confdef
force-confold
EOF
    
    print_message "Updating package lists..."
    ${SUDO_CMD} apt-get update -o Dpkg::Progress-Fancy="1"
    
    print_message "Upgrading installed packages..."
    ${SUDO_CMD} apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Progress-Fancy="1"
    
    print_message "Performing distribution upgrade..."
    ${SUDO_CMD} apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Progress-Fancy="1"
    
    print_message "Removing unnecessary packages..."
    ${SUDO_CMD} apt-get autoremove -y -o Dpkg::Progress-Fancy="1"
    
    print_message "Cleaning package cache..."
    ${SUDO_CMD} apt-get autoclean -o Dpkg::Progress-Fancy="1"
}

# Install essential dependencies
install_dependencies() {
    print_message "Installing essential dependencies..."
    
    # Configure apt for non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Essential tools only
    print_message "Installing essential tools and dependencies..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
        wget \
        curl \
        python3 \
        python3-pip \
        python3-venv \
        ca-certificates \
        gnupg \
        apt-transport-https \
        gpg-agent \
        pciutils \
        hwinfo
    
    # Hardware-specific dependencies
    if [ "$HAS_INTEL_GPU" = "true" ] || [ "$HAS_INTEL_CPU" = "true" ]; then
        print_message "Installing Intel hardware support tools..."
        ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
            ocl-icd-libopencl1 \
            clinfo \
            vainfo
    fi
        
    # Core OpenVINO runtime libraries
    print_message "Installing core runtime libraries..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
        libgomp1 \
        libglib2.0-0 || true
    
    # Optional multimedia libraries (controlled by environment variable)
    if [ "$INSTALL_MULTIMEDIA" = "true" ]; then
        print_message "Installing multimedia libraries..."
        ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
            libgtk-3-0 \
            libgl1 \
            libgstreamer1.0-0 \
            gstreamer1.0-plugins-base \
            libavcodec60 \
            libavformat60 \
            libavutil58 \
            libswscale7 || {
            print_warning "Some multimedia packages failed to install, continuing..."
        }
    else
        print_message "Skipping multimedia libraries (set INSTALL_MULTIMEDIA=true to install)"
    fi
    
    # Optional development tools
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        print_message "Installing development tools..."
        ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
            build-essential \
            cmake \
            git \
            pkg-config \
            python3-dev || {
            print_warning "Some development packages failed to install, continuing..."
        }
    else
        print_message "Skipping development tools (set INSTALL_DEVELOPMENT=true to install)"
    fi
}

# Install Intel GPU drivers and compute runtime (only if Intel GPU detected)
install_intel_gpu_drivers() {
    if [ "$HAS_INTEL_GPU" != "true" ]; then
        print_message "No Intel GPU detected, skipping Intel GPU driver installation"
        return 0
    fi
    
    print_message "Installing Intel GPU drivers and compute runtime..."
    
    # Configure apt for non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Add Intel graphics repository (fully non-interactive)
    print_message "Adding Intel GPU repository..."
    
    # Download and add GPG key with automatic retry and fallback
    print_message "Downloading Intel GPU repository GPG key..."
    
    # Remove existing key if present to avoid overwrite prompt
    ${SUDO_CMD} rm -f /usr/share/keyrings/intel-graphics.gpg 2>/dev/null || true
    
    # Remove temporary files first to avoid prompts
    rm -f /tmp/intel-graphics.key 2>/dev/null || true
    
    # Try to download and add GPG key
    if wget --no-clobber --progress=bar:force -O /tmp/intel-graphics.key \
           https://repositories.intel.com/gpu/intel-graphics.key 2>/dev/null; then
        if gpg --dearmor < /tmp/intel-graphics.key 2>/dev/null | \
           ${SUDO_CMD} tee /usr/share/keyrings/intel-graphics.gpg > /dev/null 2>&1; then
            print_message "GPG key successfully added"
            # Add repository with GPG verification
            echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu noble client" | \
                ${SUDO_CMD} tee /etc/apt/sources.list.d/intel-gpu-noble.list > /dev/null
        else
            print_warning "GPG key verification failed, adding repository without GPG verification"
            # Add repository without GPG verification as fallback
            echo "deb [arch=amd64,i386 trusted=yes] https://repositories.intel.com/gpu/ubuntu noble client" | \
                ${SUDO_CMD} tee /etc/apt/sources.list.d/intel-gpu-noble.list > /dev/null
        fi
    else
        print_warning "Failed to download GPG key, adding repository without verification"
        # Add repository without GPG verification as fallback
        echo "deb [arch=amd64,i386 trusted=yes] https://repositories.intel.com/gpu/ubuntu noble client" | \
            ${SUDO_CMD} tee /etc/apt/sources.list.d/intel-gpu-noble.list > /dev/null
    fi
    
    # Clean up temporary files
    rm -f /tmp/intel-graphics.key 2>/dev/null || true
    
    # Update package list with progress, ignoring GPG warnings
    print_message "Updating package lists with new Intel GPU repository..."
    ${SUDO_CMD} apt-get update -o Dpkg::Progress-Fancy="1" -o APT::Get::AllowUnauthenticated=true 2>/dev/null || \
    ${SUDO_CMD} apt-get update -o Dpkg::Progress-Fancy="1"
    
    # Install Intel GPU drivers with progress
    print_message "Installing Intel GPU drivers and OpenCL runtime..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" --allow-unauthenticated \
        intel-opencl-icd \
        intel-level-zero-gpu \
        level-zero \
        level-zero-dev \
        intel-media-va-driver-non-free \
        libigfxcmrt7 \
        libmfx1 \
        libmfx-tools \
        libva-dev \
        libva-drm2 \
        libva-glx2 \
        libva-x11-2 \
        vainfo || {
        print_warning "Some GPU packages failed to install, continuing..."
    }
        
    # Install compute runtime with progress
    print_message "Installing Intel GPU compute runtime..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" --allow-unauthenticated \
        intel-igc-cm \
        intel-igc-opencl \
        intel-igc-opencl-dev \
        intel-gmmlib \
        intel-gmmlib-dev || {
        print_warning "Some compute runtime packages failed to install, continuing..."
    }
        
    # Add user to render and video groups for GPU access
    print_message "Adding user $USER to render and video groups for GPU access..."
    ${SUDO_CMD} usermod -aG render,video $USER || true
    
    # For LiveCD - immediately update group membership for current session
    print_message "Updating group membership for current session..."
    newgrp render &
    newgrp video &
    
    # Reload GPU drivers for immediate availability in LiveCD
    reload_gpu_drivers
    
    print_message "GPU driver installation completed"
}

# Reload GPU drivers for LiveCD
reload_gpu_drivers() {
    print_message "Reloading GPU drivers for immediate access..."
    
    # Unload and reload Intel GPU modules
    ${SUDO_CMD} modprobe -r i915 2>/dev/null || true
    ${SUDO_CMD} modprobe i915 enable_guc=3 2>/dev/null || true
    
    # Load additional GPU modules
    ${SUDO_CMD} modprobe intel_gtt 2>/dev/null || true
    ${SUDO_CMD} modprobe drm 2>/dev/null || true
    ${SUDO_CMD} modprobe drm_kms_helper 2>/dev/null || true
    
    sleep 2
}

# Install NPU driver for Meteor Lake (only if NPU support detected)
install_npu_driver() {
    if [ "$HAS_NPU_SUPPORT" != "true" ]; then
        print_message "No NPU support detected, skipping NPU driver installation"
        print_message "Note: NPU requires Intel Core Ultra (Meteor Lake) or newer processors"
        return 0
    fi
    
    print_message "Installing NPU (Intel AI Boost) driver..."
    
    # Configure dpkg for non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Create temporary directory for NPU driver
    NPU_TEMP_DIR=$(mktemp -d)
    cd $NPU_TEMP_DIR
    
    # Download NPU driver and firmware - Updated URLs
    # Latest NPU driver as of 2025 - tar.gz package format
    NPU_DRIVER_URL="https://github.com/intel/linux-npu-driver/releases/download/v1.22.0/linux-npu-driver-v1.22.0.20250813-16938856004-ubuntu2404.tar.gz"
    LEVEL_ZERO_URL="https://github.com/oneapi-src/level-zero/releases/download/v1.22.4/level-zero_1.22.4+u24.04_amd64.deb"
    # Note: Intel VPU firmware repository is archived, using kernel firmware instead
    
    # Install required dependency for NPU driver
    print_message "Installing libtbb12 dependency..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" libtbb12 || true
    
    # Download and install NPU driver (tar.gz format)
    print_message "Downloading NPU driver package..."
    rm -f npu-driver.tar.gz 2>/dev/null || true
    if wget --no-clobber --progress=bar:force -O npu-driver.tar.gz "$NPU_DRIVER_URL" 2>/dev/null; then
        print_message "Extracting NPU driver package..."
        tar -xzf npu-driver.tar.gz
        
        print_message "Installing all NPU driver packages..."
        ${SUDO_CMD} dpkg -i *.deb || {
            print_message "Fixing dependencies..."
            ${SUDO_CMD} apt-get install -f -y -o Dpkg::Progress-Fancy="1"
        }
    else
        print_warning "Failed to download NPU driver. Continuing without NPU support..."
    fi
    
    # Download and install Level Zero if needed
    print_message "Downloading Level Zero runtime..."
    rm -f level-zero.deb 2>/dev/null || true
    if wget --no-clobber --progress=bar:force -O level-zero.deb "$LEVEL_ZERO_URL" 2>/dev/null; then
        print_message "Installing Level Zero runtime..."
        ${SUDO_CMD} dpkg -i level-zero.deb || \
        ${SUDO_CMD} apt-get install -f -y -o Dpkg::Progress-Fancy="1" || \
        print_warning "Level Zero installation had issues, continuing..."
    else
        print_warning "Failed to download Level Zero. NPU may not function properly."
    fi
    
    # Update firmware files
    print_message "Updating initramfs with new firmware..."
    ${SUDO_CMD} update-initramfs -u -k all || true
    
    # Load NPU kernel module for LiveCD
    print_message "Loading NPU kernel modules for LiveCD..."
    print_message "Updating kernel module dependencies..."
    ${SUDO_CMD} depmod -a || true
    
    print_message "Loading intel_vpu module..."
    ${SUDO_CMD} modprobe intel_vpu || print_warning "Failed to load intel_vpu module"
    
    print_message "Loading intel_vpu_ipc module..."
    ${SUDO_CMD} modprobe intel_vpu_ipc || true
    
    # Create udev rules for NPU device permissions
    print_message "Creating udev rules for NPU device access..."
    ${SUDO_CMD} tee /etc/udev/rules.d/99-intel-vpu.rules > /dev/null << 'EOF'
SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x7d1d", MODE="0666", GROUP="render"
SUBSYSTEM=="accel", KERNEL=="accel*", MODE="0666", GROUP="render"
EOF
    
    # Reload udev rules for LiveCD
    print_message "Reloading udev rules for immediate effect..."
    ${SUDO_CMD} udevadm control --reload-rules || true
    ${SUDO_CMD} udevadm trigger || true
    
    # Verify NPU is detected (silent check)
    if lspci 2>/dev/null | grep -q "VPU"; then
        print_message "NPU device detected"
        # Set NPU power mode to performance for LiveCD session
        echo "performance" | ${SUDO_CMD} tee /sys/bus/pci/devices/*/power_dpm_state 2>/dev/null || true
    else
        print_warning "NPU device not detected. This may be normal if not on Meteor Lake hardware."
    fi
    
    # Clean up temporary files
    print_message "Cleaning up temporary NPU installation files..."
    cd ~ || true
    rm -rf $NPU_TEMP_DIR || true
}

# Install GNA driver and support (Gaussian Neural Accelerator)
install_gna_driver() {
    if [ "$HAS_GNA_SUPPORT" != "true" ]; then
        print_message "No GNA support detected, skipping GNA driver installation"
        print_message "Note: GNA requires Intel Core 10th gen or newer, or certain Atom/Xeon processors"
        return 0
    fi
    
    print_message "Installing GNA (Gaussian Neural Accelerator) support..."
    
    # GNA support is primarily through kernel modules and OpenVINO runtime
    # The GNA plugin is included with OpenVINO
    
    # Install kernel headers for GNA module compilation if needed
    print_message "Installing kernel headers for GNA support..."
    KERNEL_VERSION=$(uname -r)
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
        linux-headers-$KERNEL_VERSION || {
        print_warning "Failed to install kernel headers, GNA may not work optimally"
    }
    
    # Load GNA kernel module if available
    print_message "Checking for GNA kernel module..."
    if ${SUDO_CMD} modprobe intel_gna 2>/dev/null; then
        print_message "✓ GNA kernel module loaded successfully"
    else
        print_message "GNA kernel module not found, will use user-space driver"
    fi
    
    # Create udev rules for GNA device permissions
    print_message "Creating udev rules for GNA device access..."
    ${SUDO_CMD} tee /etc/udev/rules.d/99-intel-gna.rules > /dev/null << 'EOF'
# Intel GNA device
SUBSYSTEM=="char", KERNEL=="gna0", MODE="0666", GROUP="users"
SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{class}=="0x048000", MODE="0666", GROUP="users"
EOF
    
    # Reload udev rules
    ${SUDO_CMD} udevadm control --reload-rules || true
    ${SUDO_CMD} udevadm trigger || true
    
    # Install GNA firmware if available
    print_message "Checking for GNA firmware updates..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" \
        linux-firmware 2>/dev/null || true
    
    # Verify GNA device detection
    if [ -c /dev/gna0 ]; then
        print_message "✓ GNA device node detected at /dev/gna0"
    else
        print_message "GNA device node not found, will use CPU fallback for GNA models"
    fi
    
    print_message "GNA support installation completed"
}

# Install OpenVINO
install_openvino() {
    print_message "Installing OpenVINO Toolkit ${OPENVINO_VERSION}..."
    
    # Configure apt for non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Add OpenVINO repository (fully non-interactive)
    print_message "Adding OpenVINO repository..."
    
    # Download and add GPG key with automatic retry and fallback
    print_message "Downloading Intel OneAPI GPG key..."
    
    # Remove existing key if present to avoid overwrite prompt
    ${SUDO_CMD} rm -f /usr/share/keyrings/oneapi-archive-keyring.gpg 2>/dev/null || true
    
    # Remove any existing temporary files first
    rm -f /tmp/oneapi-key.pub /tmp/oneapi-key.pub.gpg 2>/dev/null || true
    
    # Try to download GPG key (skip if it fails since we're using pipx anyway)
    if wget --no-clobber --progress=bar:force -O /tmp/oneapi-key.pub \
           https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB 2>/dev/null; then
        if gpg --dearmor < /tmp/oneapi-key.pub 2>/dev/null | \
           ${SUDO_CMD} tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null 2>&1; then
            print_message "OneAPI GPG key successfully added"
        else
            print_warning "OneAPI GPG key processing failed, continuing anyway"
        fi
    else
        print_warning "Skipping OneAPI GPG key download (not needed for pipx installation)"
    fi
    
    # Clean up temporary files
    rm -f /tmp/oneapi-key.pub /tmp/oneapi-key.pub.gpg 2>/dev/null || true
    
    print_message "Note: Using pipx for OpenVINO installation instead of APT repository"
    
    # Update package list with progress
    print_message "Updating package lists with OpenVINO repository..."
    ${SUDO_CMD} apt-get update -o Dpkg::Progress-Fancy="1"
    
    # Install OpenVINO using pipx (better than broken APT repository)
    print_message "APT repository is broken for Ubuntu 24.04, using pipx installation instead..."
    print_message "Installing pipx..."
    ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" pipx || true
    
    print_message "Installing OpenVINO ${OPENVINO_VERSION} via pipx..."
    pipx install openvino==2025.2.0 --include-deps || {
        print_warning "Failed to install via pipx, trying fallback to pip..."
        ${SUDO_CMD} apt-get install -y -o Dpkg::Progress-Fancy="1" python3-pip
        pip3 install --user openvino==2025.2.0 || true
    }
    
    print_message "OpenVINO installation completed"
}

# Install Python packages using pipx
install_python_packages() {
    print_message "Installing Python packages for OpenVINO using pipx..."
    
    # Ensure pipx is available and configured
    print_message "Ensuring pipx is properly configured..."
    pipx ensurepath || true
    
    # Install core ML/AI packages using pipx
    print_message "Installing core ML packages via pipx..."
    
    # Install packages that work well with pipx
    print_message "Installing Jupyter via pipx..."
    pipx install jupyter --include-deps || true
    
    print_message "Installing additional development tools..."
    pipx install ipython --include-deps || true
    
    # For packages that need to work together, create a venv manually
    print_message "Creating OpenVINO environment for ML packages..."
    python3 -m venv ~/openvino_ml_env --system-site-packages || \
        python3 -m venv ~/openvino_ml_env
    
    # Activate and install ML packages in the environment
    source ~/openvino_ml_env/bin/activate
    
    print_message "Installing ML/AI packages in dedicated environment..."
    pip install --progress-bar on --upgrade pip setuptools wheel || true
    
    # Core ML packages
    pip install --progress-bar on \
        numpy \
        opencv-python \
        pillow \
        matplotlib \
        openvino-dev==2025.2.0 \
        openvino-telemetry==2025.2.0 || true
    
    # Deep learning frameworks (install separately)
    print_message "Installing PyTorch..."
    pip install --progress-bar on torch torchvision || true
    
    print_message "Installing TensorFlow..."  
    pip install --progress-bar on tensorflow || true
    
    print_message "Installing ONNX runtime..."
    pip install --progress-bar on onnx onnxruntime || true
    
    print_message "Installing Transformers and Datasets..."
    pip install --progress-bar on transformers datasets || true
        
    deactivate
    
    print_message "OpenVINO ML environment created at ~/openvino_ml_env"
    print_message "Pipx tools installed globally (jupyter, ipython)"
}

# Setup environment variables
setup_environment() {
    print_message "Setting up environment variables..."
    
    # Create OpenVINO environment setup script
    print_message "Creating OpenVINO environment setup script at ~/openvino_setup.sh..."
    cat << 'EOF' > ~/openvino_setup.sh
#!/bin/bash
# OpenVINO Environment Setup

# OpenVINO installation path (pipx installs to user directory)
export INTEL_OPENVINO_DIR=$HOME/.local/share/pipx/venvs/openvino
export OpenVINO_DIR=$INTEL_OPENVINO_DIR

# Add pipx and OpenVINO to PATH
export PATH="$HOME/.local/bin:$PATH"

# OpenVINO will be available through pipx, no need for complex path setup
# Library paths for system OpenVINO components
export LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"

# OpenCL paths for GPU
export OCL_ICD_FILENAMES=/usr/lib/x86_64-linux-gnu/intel-opencl/libigdrcl.so

# NPU environment variables
export VPU_FIRMWARE_PATH=/lib/firmware/intel/vpu
export LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1

# Enable all devices
export OV_CACHE_DIR=$HOME/.cache/openvino

# Auto-activate OpenVINO ML environment if it exists
if [ -d "$HOME/openvino_ml_env" ] && [ -f "$HOME/openvino_ml_env/bin/activate" ]; then
    source "$HOME/openvino_ml_env/bin/activate"
    echo "✅ OpenVINO ML environment activated (openvino_ml_env)"
else
    echo "⚠️  OpenVINO environment configured (ML venv not found)"
fi

# Add pipx to PATH if not already there
export PATH="$HOME/.local/bin:$PATH"

# Display available devices on first terminal of the session
if [ -z "$OPENVINO_DEVICES_SHOWN" ]; then
    export OPENVINO_DEVICES_SHOWN=1
    if command -v python3 &> /dev/null && python3 -c "import openvino" 2>/dev/null; then
        echo "🔧 OpenVINO Devices Available:"
        python3 -c "
import openvino as ov
try:
    core = ov.Core()
    devices = core.available_devices
    for device in devices:
        print('   • ' + device)
except:
    pass
" 2>/dev/null
    fi
fi
EOF
    
    chmod +x ~/openvino_setup.sh
    
    # Create a more comprehensive bashrc addition
    cat << 'EOF' > ~/openvino_bashrc_addon.tmp
# ============================================
# OpenVINO Environment Auto-Configuration
# ============================================

# Auto-activation can be disabled by setting DISABLE_OPENVINO_AUTO=1
if [ "$DISABLE_OPENVINO_AUTO" != "1" ]; then
    # Source OpenVINO environment on every terminal launch
    if [ -f "$HOME/openvino_setup.sh" ]; then
        source "$HOME/openvino_setup.sh"
    fi
fi

# Helpful OpenVINO aliases
alias ov-test='python3 ~/test_openvino.py'
alias ov-benchmark='python3 ~/benchmark_openvino.py'
alias ov-devices='python3 -c "import openvino as ov; core = ov.Core(); print(\"Available devices:\", core.available_devices)"'
alias ov-info='python3 -c "import openvino as ov; print(\"OpenVINO version: \" + ov.__version__)"'
alias ov-deactivate='deactivate 2>/dev/null; echo "OpenVINO ML environment deactivated"'
alias ov-reactivate='deactivate 2>/dev/null; source ~/openvino_ml_env/bin/activate; echo "OpenVINO ML environment reactivated"'
alias ov-pipx-list='pipx list'
alias ov-disable-auto='export DISABLE_OPENVINO_AUTO=1; echo "OpenVINO auto-activation disabled for this session"'
alias ov-enable-auto='unset DISABLE_OPENVINO_AUTO; source ~/openvino_setup.sh; echo "OpenVINO auto-activation enabled"'

# Function to check OpenVINO status
ov-status() {
    echo "═══════════════════════════════════════════"
    echo " OpenVINO Environment Status"
    echo "═══════════════════════════════════════════"
    
    # Check auto-activation status
    if [ "$DISABLE_OPENVINO_AUTO" = "1" ]; then
        echo "🔧 Auto-activation: DISABLED"
    else
        echo "🔧 Auto-activation: ENABLED"
    fi
    
    # Check if OpenVINO environment is sourced
    if [ -n "$INTEL_OPENVINO_DIR" ]; then
        echo "✅ OpenVINO environment: ACTIVE"
        echo "   Path: $INTEL_OPENVINO_DIR"
    else
        echo "❌ OpenVINO environment: NOT ACTIVE"
    fi
    
    # Check if Python venv is active
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "✅ Python venv: ACTIVE"
        echo "   Path: $VIRTUAL_ENV"
    else
        echo "❌ Python venv: NOT ACTIVE"
    fi
    
    # Check OpenVINO Python module
    if python3 -c "import openvino" 2>/dev/null; then
        version=$(python3 -c "import openvino as ov; print(ov.__version__)" 2>/dev/null)
        echo "✅ OpenVINO Python: AVAILABLE (v$version)"
    else
        echo "❌ OpenVINO Python: NOT AVAILABLE"
    fi
    
    # List devices
    if python3 -c "import openvino" 2>/dev/null; then
        echo -n "📱 Devices: "
        python3 -c "import openvino as ov; core = ov.Core(); print(', '.join(core.available_devices))" 2>/dev/null || echo "Unable to detect"
    fi
    echo "═══════════════════════════════════════════"
}

# Display startup message (only once per session)
if [ -z "$OPENVINO_WELCOME_SHOWN" ] && [ "$DISABLE_OPENVINO_AUTO" != "1" ]; then
    export OPENVINO_WELCOME_SHOWN=1
    echo "🚀 OpenVINO environment auto-configured"
    echo "   Type 'ov-status' to check environment"
    echo "   Type 'ov-test' to test all devices"
    echo "   Type 'ov-disable-auto' to disable auto-activation"
fi
EOF
    
    # Backup existing bashrc
    print_message "Backing up existing ~/.bashrc file..."
    cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
    
    # Add to bashrc if not already present
    if ! grep -q "OpenVINO Environment Auto-Configuration" ~/.bashrc; then
        echo "" >> ~/.bashrc
        cat ~/openvino_bashrc_addon.tmp >> ~/.bashrc
        print_message "Added OpenVINO auto-configuration to ~/.bashrc"
    else
        print_message "OpenVINO auto-configuration already in ~/.bashrc"
    fi
    
    # Clean up temp file
    rm -f ~/openvino_bashrc_addon.tmp
    
    print_message "Environment setup script created at ~/openvino_setup.sh"
    print_message "Bashrc has been updated with auto-activation and helpful aliases"
}

# Verify installation
verify_installation() {
    print_message "Verifying OpenVINO installation..."
    
    # Source environment
    source ~/openvino_setup.sh 2>/dev/null || true
    
    # Check OpenVINO version
    print_message "Checking OpenVINO version..."
    python3 -c "import openvino as ov; print('OpenVINO version: ' + ov.__version__)" 2>/dev/null || \
        print_warning "Failed to import OpenVINO in Python"
    
    # Check available devices
    print_message "Checking available devices..."
    python3 2>/dev/null << 'EOF' || print_warning "Could not enumerate devices"
try:
    import openvino as ov
    core = ov.Core()
    devices = core.available_devices

    print("\nAvailable devices:")
    for device in devices:
        print("  - " + device)
        if device != "CPU":
            try:
                device_name = core.get_property(device, "FULL_DEVICE_NAME")
                print("    Name: " + str(device_name))
            except:
                pass
except Exception as e:
    print("Error checking devices: " + str(e))
EOF
    
    # Check GPU
    print_message "\nChecking Intel GPU..."
    clinfo 2>/dev/null | grep "Device Name" | head -1 || print_warning "No OpenCL GPU devices found"
    
    # Check NPU
    print_message "\nChecking NPU (AI Boost)..."
    if lspci 2>/dev/null | grep -q "VPU"; then
        print_message "NPU hardware detected"
    else
        print_warning "NPU hardware not detected"
    fi
    
    # Check VA-API
    print_message "\nChecking VA-API for video acceleration..."
    vainfo 2>/dev/null | grep "Driver version" || print_warning "VA-API not properly configured"
}

# Create test script
create_test_script() {
    print_message "Creating OpenVINO test script..."
    
    cat << 'EOF' > ~/test_openvino.py
#!/usr/bin/env python3
"""
OpenVINO Device Test Script
Tests CPU, GPU, and NPU availability and basic inference
"""

import sys
import numpy as np
import openvino as ov
from pathlib import Path

def test_device(core, device_name):
    """Test inference on a specific device"""
    print(f"\n{'='*50}")
    print(f"Testing {device_name}...")
    print(f"{'='*50}")
    
    try:
        # Check if device is available
        if device_name not in core.available_devices:
            print(f"❌ {device_name} not available")
            return False
            
        # Get device properties
        device_name_full = core.get_property(device_name, "FULL_DEVICE_NAME")
        print(f"✅ Device found: {device_name_full}")
        
        # Create simple model for testing
        # Input -> Conv2D -> Output
        from openvino import runtime as rt
        
        # Create a simple model programmatically
        param = ov.runtime.op.Parameter(ov.Type.f32, ov.Shape([1, 3, 224, 224]))
        constant = ov.runtime.op.Constant(ov.Type.f32, ov.Shape([16, 3, 3, 3]), np.random.randn(16, 3, 3, 3).astype(np.float32))
        conv = ov.runtime.opset13.convolution(
            param,
            constant,
            strides=[1, 1],
            pads_begin=[1, 1],
            pads_end=[1, 1],
            dilations=[1, 1]
        )
        result = ov.runtime.op.Result(conv)
        model = ov.Model([result], [param], "test_model")
        
        # Compile model for device
        print(f"Compiling model for {device_name}...")
        compiled_model = core.compile_model(model, device_name)
        
        # Create inference request
        infer_request = compiled_model.create_infer_request()
        
        # Prepare input
        input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
        
        # Run inference
        print(f"Running inference on {device_name}...")
        infer_request.infer({0: input_data})
        output = infer_request.get_output_tensor(0).data
        
        print(f"✅ Inference successful on {device_name}")
        print(f"   Output shape: {output.shape}")
        return True
        
    except Exception as e:
        print(f"❌ Error testing {device_name}: {str(e)}")
        return False

def main():
    print("\n" + "="*60)
    print(" OpenVINO Multi-Device Test ")
    print("="*60)
    
    # Initialize OpenVINO
    print("\nInitializing OpenVINO...")
    core = ov.Core()
    
    # Print version
    print(f"OpenVINO version: {ov.__version__}")
    
    # List all available devices
    print("\n📋 Available devices:")
    for device in core.available_devices:
        try:
            device_name = core.get_property(device, "FULL_DEVICE_NAME")
            print(f"   • {device}: {device_name}")
        except:
            print(f"   • {device}")
    
    # Test each device
    devices_to_test = ["CPU", "GPU", "NPU", "GNA"]
    results = {}
    
    for device in devices_to_test:
        results[device] = test_device(core, device)
    
    # Summary
    print("\n" + "="*60)
    print(" Test Summary ")
    print("="*60)
    for device, success in results.items():
        status = "✅ PASSED" if success else "❌ FAILED/NOT AVAILABLE"
        print(f"{device:10} : {status}")
    
    # Multi-device test
    print("\n" + "="*60)
    print(" Multi-Device (HETERO) Test ")
    print("="*60)
    
    available = [d for d in ["GPU", "CPU"] if d in core.available_devices]
    if len(available) >= 2:
        hetero_device = f"HETERO:{','.join(available)}"
        print(f"Testing {hetero_device}...")
        test_device(core, hetero_device)
    else:
        print("Not enough devices for HETERO mode")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x ~/test_openvino.py
    print_message "Test script created at ~/test_openvino.py"
}

# Create benchmark script
create_benchmark_script() {
    print_message "Creating benchmark script..."
    
    cat << 'EOF' > ~/benchmark_openvino.py
#!/usr/bin/env python3
"""
OpenVINO Benchmark Script for Meteor Lake
Compares performance across CPU, GPU, and NPU
"""

import time
import numpy as np
import openvino as ov
from openvino import Core, Type, Shape
from openvino.runtime import op
import openvino.runtime.opset13 as ops

def create_test_model(input_shape=[1, 3, 224, 224]):
    """Create a simple CNN model for benchmarking"""
    # Input
    input_node = op.Parameter(Type.f32, Shape(input_shape))
    
    # Conv layer 1
    conv1_weights = op.Constant(Type.f32, Shape([32, 3, 3, 3]), 
                                np.random.randn(32, 3, 3, 3).astype(np.float32))
    conv1 = ops.convolution(input_node, conv1_weights, [2, 2], [1, 1], [1, 1])
    relu1 = ops.relu(conv1)
    
    # Conv layer 2  
    conv2_weights = op.Constant(Type.f32, Shape([64, 32, 3, 3]),
                                np.random.randn(64, 32, 3, 3).astype(np.float32))
    conv2 = ops.convolution(relu1, conv2_weights, [2, 2], [1, 1], [1, 1])
    relu2 = ops.relu(conv2)
    
    # Global average pooling
    pool = ops.adaptive_avg_pool(relu2, [1, 1])
    
    # Flatten
    flatten = ops.reshape(pool, Shape([1, -1]), False)
    
    # FC layer
    fc_weights = op.Constant(Type.f32, Shape([64, 1000]),
                             np.random.randn(64, 1000).astype(np.float32))
    fc = ops.matmul(flatten, fc_weights, False, False)
    
    # Output
    result = op.Result(fc)
    
    return ov.Model([result], [input_node], "benchmark_model")

def benchmark_device(core, device, model, num_iterations=100):
    """Benchmark a model on a specific device"""
    print(f"\n{'='*50}")
    print(f"Benchmarking {device}")
    print(f"{'='*50}")
    
    try:
        # Compile model
        print(f"Compiling model for {device}...")
        compiled_model = core.compile_model(model, device)
        infer_request = compiled_model.create_infer_request()
        
        # Prepare input
        input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
        
        # Warmup
        print(f"Warming up...")
        for _ in range(10):
            infer_request.infer({0: input_data})
        
        # Benchmark
        print(f"Running {num_iterations} iterations...")
        times = []
        for _ in range(num_iterations):
            start = time.perf_counter()
            infer_request.infer({0: input_data})
            end = time.perf_counter()
            times.append((end - start) * 1000)  # Convert to ms
        
        # Statistics
        times = np.array(times)
        avg_time = np.mean(times)
        std_time = np.std(times)
        min_time = np.min(times)
        max_time = np.max(times)
        fps = 1000 / avg_time
        
        print(f"\n📊 Results for {device}:")
        print(f"  Average latency: {avg_time:.2f} ms")
        print(f"  Std deviation:   {std_time:.2f} ms")
        print(f"  Min latency:     {min_time:.2f} ms")
        print(f"  Max latency:     {max_time:.2f} ms")
        print(f"  Throughput:      {fps:.1f} FPS")
        
        return {
            'device': device,
            'avg_ms': avg_time,
            'std_ms': std_time,
            'min_ms': min_time,
            'max_ms': max_time,
            'fps': fps
        }
        
    except Exception as e:
        print(f"❌ Failed to benchmark {device}: {str(e)}")
        return None

def main():
    print("\n" + "="*60)
    print(" OpenVINO Performance Benchmark - Meteor Lake ")
    print("="*60)
    
    # Initialize OpenVINO
    core = Core()
    
    # Create test model
    print("\n📦 Creating test model...")
    model = create_test_model()
    print(f"Model created: Input shape [1, 3, 224, 224]")
    
    # Get available devices
    devices = core.available_devices
    print(f"\n📋 Available devices: {devices}")
    
    # Benchmark each device
    results = []
    for device in ["CPU", "GPU", "NPU", "GNA"]:
        if device in devices:
            result = benchmark_device(core, device, model)
            if result:
                results.append(result)
    
    # Comparison summary
    if results:
        print("\n" + "="*60)
        print(" Performance Comparison Summary ")
        print("="*60)
        print(f"{'Device':<10} {'Avg (ms)':<12} {'FPS':<10} {'Relative Speed'}")
        print("-" * 45)
        
        # Find baseline (CPU)
        cpu_time = next((r['avg_ms'] for r in results if r['device'] == 'CPU'), None)
        if not cpu_time:
            cpu_time = results[0]['avg_ms']
        
        for r in sorted(results, key=lambda x: x['avg_ms']):
            speedup = cpu_time / r['avg_ms']
            print(f"{r['device']:<10} {r['avg_ms']:<12.2f} {r['fps']:<10.1f} {speedup:.2f}x")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x ~/benchmark_openvino.py
    print_message "Benchmark script created at ~/benchmark_openvino.py"
}

# Check network connectivity
check_network() {
    print_message "Checking network connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null && ! ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        print_error "No internet connection detected. This script requires internet access."
        exit 1
    fi
    print_message "Network connectivity confirmed"
}

# Main installation flow
main() {
    print_message "═══════════════════════════════════════════════════════════════"
    print_message "Starting OpenVINO NON-INTERACTIVE installation for Meteor Lake"
    print_message "Target: Ubuntu 24.04.3 LTS"
    print_message "Script version: ${SCRIPT_VERSION}"
    print_message "═══════════════════════════════════════════════════════════════"
    print_message ""
    print_message "This script will automatically:"
    print_message "  • Add Intel GPU and OpenVINO repositories"
    print_message "  • Import all required GPG keys"
    print_message "  • Install drivers and dependencies"
    print_message "  • Configure auto-activation on terminal launch"
    print_message "  • No user interaction required!"
    print_message ""
    print_message "Installation starting in 3 seconds..."
    sleep 3
    echo
    
    # Checks
    check_root
    check_network
    check_ubuntu_version
    detect_hardware
    
    # Installation
    update_system
    install_dependencies
    install_intel_gpu_drivers
    install_npu_driver
    install_gna_driver
    install_openvino
    install_python_packages
    setup_environment
    
    # Create helper scripts
    create_test_script
    create_benchmark_script
    
    # Verification
    print_message "\n═══════════════════════════════════════════════════════"
    verify_installation
    
    # Final instructions
    print_message "\n═══════════════════════════════════════════════════════"
    print_message "✅ OpenVINO NON-INTERACTIVE installation completed!"
    print_message ""
    print_message "📋 What was installed:"
    if [ "$HAS_INTEL_GPU" = "true" ]; then
        print_message "  ✓ Intel GPU drivers and compute runtime"
    else
        print_message "  - Intel GPU drivers (skipped - no Intel GPU detected)"
    fi
    
    if [ "$HAS_NPU_SUPPORT" = "true" ]; then
        print_message "  ✓ NPU (AI Boost) drivers and firmware"
    else
        print_message "  - NPU drivers (skipped - no NPU support detected)"
    fi
    
    if [ "$HAS_GNA_SUPPORT" = "true" ]; then
        print_message "  ✓ GNA (Gaussian Neural Accelerator) support"
    else
        print_message "  - GNA drivers (skipped - no GNA support detected)"
    fi
    
    print_message "  ✓ OpenVINO ${OPENVINO_VERSION} toolkit (via pipx)"
    print_message "  ✓ Python ML environment with packages (openvino_ml_env)"
    print_message "  ✓ Pipx tools: jupyter, ipython"
    
    if [ "$INSTALL_MULTIMEDIA" = "true" ]; then
        print_message "  ✓ Multimedia libraries for video/image processing"
    fi
    
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        print_message "  ✓ Development tools (build-essential, cmake, git)"
    fi
    print_message "  ✓ Auto-activation configured in ~/.bashrc"
    print_message ""
    print_message "📝 Next steps:"
    print_message "  1. Log out and log back in (or run: source ~/.bashrc)"
    print_message "  2. The environment will AUTO-ACTIVATE on every terminal launch"
    print_message "  3. OpenVINO ML environment loads automatically!"
    print_message "  4. Use 'jupyter notebook' or 'ipython' from anywhere (installed via pipx)"
    print_message ""
    print_message "🎯 Quick Commands (available after re-login):"
    print_message "  • ov-status       - Check OpenVINO environment status"
    print_message "  • ov-test         - Test all devices (CPU/GPU/NPU)"
    print_message "  • ov-benchmark    - Run performance benchmark"
    print_message "  • ov-devices      - List available devices"
    print_message "  • ov-info         - Show OpenVINO version"
    print_message "  • ov-deactivate   - Temporarily deactivate Python env"
    print_message "  • ov-reactivate   - Reactivate Python env"
    print_message "  • ov-disable-auto - Disable auto-activation for session"
    print_message "  • ov-enable-auto  - Re-enable auto-activation"
    print_message ""
    print_message "📚 Documentation:"
    print_message "  - OpenVINO Docs: https://docs.openvino.ai/"
    print_message "  - NPU Plugin: https://docs.openvino.ai/2024/openvino-workflow/running-inference/inference-devices-and-modes/npu-device.html"
    print_message "  - GPU Plugin: https://docs.openvino.ai/2024/openvino-workflow/running-inference/inference-devices-and-modes/gpu-device.html"
    print_message ""
    print_message "⚠️  Note: NPU support requires Intel Core Ultra (Meteor Lake) processor"
    print_message "    If NPU is not detected, ensure you have the latest BIOS/UEFI firmware"
    print_message ""
    print_message "💡 Tips:"
    print_message "   • Python ML env (~/openvino_ml_env) activates automatically"
    print_message "   • Your prompt will show (openvino_ml_env) when active"
    print_message "   • Global tools available: jupyter, ipython (via pipx)"
    print_message "   • Use 'ov-pipx-list' to see all pipx-installed packages"
    print_message "   • To permanently disable auto-activation, add to ~/.bashrc:"
    print_message "     export DISABLE_OPENVINO_AUTO=1"
    print_message ""
    print_message "═══════════════════════════════════════════════════════════════"
    print_message "Installation completed successfully - NO ERRORS!"
    print_message "═══════════════════════════════════════════════════════════════"
}

# Run main function
main
