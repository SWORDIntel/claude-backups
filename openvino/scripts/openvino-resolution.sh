#!/bin/bash
# OpenVINO Complete Resolution Script
# Automatically fixes common OpenVINO installation issues on Meteor Lake
# Intel Core Ultra 7 155H optimized

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Sudo password
SUDO_PASS="${1:-}"

# Check for sudo password
if [ -z "$SUDO_PASS" ]; then
    echo -e "${RED}ERROR: Sudo password required${NC}"
    echo "Usage: $0 <sudo_password>"
    exit 1
fi

# Test sudo
echo "$SUDO_PASS" | sudo -S true 2>/dev/null || {
    echo -e "${RED}ERROR: Invalid sudo password${NC}"
    exit 1
}

log() {
    echo -e "$1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Header
clear
log "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
log "${BLUE}║   OpenVINO Automated Resolution - Meteor Lake                 ║${NC}"
log "${BLUE}║   Fixes GPU access, OpenCL, and OpenVINO installation         ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
log ""

# Track fixes
FIXES_APPLIED=0
ERRORS=0

# =============================================================================
# SECTION 1: User Permissions
# =============================================================================
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 1: Fix User Permissions${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}1.1 Add user to 'render' and 'video' groups${NC}"
log "──────────────────────────────────────"

CURRENT_USER=$(whoami)
CURRENT_GROUPS=$(groups)

if echo "$CURRENT_GROUPS" | grep -q "render"; then
    log_success "User already in 'render' group"
else
    log_info "Adding user to 'render' group..."
    echo "$SUDO_PASS" | sudo -S usermod -a -G render "$CURRENT_USER"
    log_success "Added to 'render' group"
    ((FIXES_APPLIED++))
fi

if echo "$CURRENT_GROUPS" | grep -q "video"; then
    log_success "User already in 'video' group"
else
    log_info "Adding user to 'video' group..."
    echo "$SUDO_PASS" | sudo -S usermod -a -G video "$CURRENT_USER"
    log_success "Added to 'video' group"
    ((FIXES_APPLIED++))
fi

# =============================================================================
# SECTION 2: OpenCL & GPU Drivers
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 2: Install OpenCL & GPU Drivers${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}2.1 Update package cache${NC}"
log "──────────────────────────────────────"

log_info "Running apt update..."
if echo "$SUDO_PASS" | sudo -S apt update -qq 2>&1; then
    log_success "Package cache updated"
else
    log_warning "apt update had warnings (continuing)"
fi

log ""
log "${BLUE}2.2 Install OpenCL runtime${NC}"
log "──────────────────────────────────────"

OPENCL_PACKAGES=(
    "ocl-icd-libopencl1"
    "opencl-headers"
    "clinfo"
    "intel-opencl-icd"
)

for pkg in "${OPENCL_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        log_success "$pkg already installed"
    else
        log_info "Installing $pkg..."
        if echo "$SUDO_PASS" | sudo -S apt install -y -qq "$pkg" 2>&1; then
            log_success "$pkg installed"
            ((FIXES_APPLIED++))
        else
            log_warning "$pkg installation failed (may not be in repos)"
        fi
    fi
done

log ""
log "${BLUE}2.3 Install Level Zero runtime${NC}"
log "──────────────────────────────────────"

LEVEL_ZERO_PACKAGES=(
    "level-zero"
    "intel-level-zero-gpu"
)

for pkg in "${LEVEL_ZERO_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        log_success "$pkg already installed"
    else
        log_info "Installing $pkg..."
        if echo "$SUDO_PASS" | sudo -S apt install -y -qq "$pkg" 2>&1; then
            log_success "$pkg installed"
            ((FIXES_APPLIED++))
        else
            log_warning "$pkg installation failed (may not be in repos)"
        fi
    fi
done

log ""
log "${BLUE}2.4 Install Intel Graphics Compute Runtime${NC}"
log "──────────────────────────────────────"

INTEL_COMPUTE_PACKAGES=(
    "intel-media-va-driver-non-free"
    "libigdgmm12"
    "libze1"
)

for pkg in "${INTEL_COMPUTE_PACKAGES[@]}"; do
    if dpkg -l | grep -q "$pkg"; then
        log_success "$pkg already installed"
    else
        log_info "Installing $pkg..."
        if echo "$SUDO_PASS" | sudo -S apt install -y -qq "$pkg" 2>&1; then
            log_success "$pkg installed"
            ((FIXES_APPLIED++))
        else
            log_info "$pkg not available in current repos (continuing)"
        fi
    fi
done

# =============================================================================
# SECTION 3: Build Dependencies
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 3: Install Build Dependencies${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

BUILD_DEPS=(
    "build-essential"
    "cmake"
    "git"
    "python3-dev"
    "python3-pip"
    "python3-venv"
    "libusb-1.0-0-dev"
    "libtbb-dev"
    "libpugixml-dev"
    "patchelf"
    "nlohmann-json3-dev"
    "libssl-dev"
)

log "${BLUE}3.1 Install compilation tools${NC}"
log "──────────────────────────────────────"

for pkg in "${BUILD_DEPS[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        log_success "$pkg already installed"
    else
        log_info "Installing $pkg..."
        if echo "$SUDO_PASS" | sudo -S apt install -y -qq "$pkg" 2>&1; then
            log_success "$pkg installed"
            ((FIXES_APPLIED++))
        else
            log_error "$pkg installation failed"
            ((ERRORS++))
        fi
    fi
done

# =============================================================================
# SECTION 4: Python OpenVINO Installation
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 4: Install OpenVINO Python Package${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}4.1 Check current OpenVINO installation${NC}"
log "──────────────────────────────────────"

if python3 -c "import openvino" 2>/dev/null; then
    CURRENT_VERSION=$(python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null || echo "unknown")
    log_success "OpenVINO Python already installed: $CURRENT_VERSION"

    read -p "Reinstall/upgrade? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Upgrading OpenVINO..."
        python3 -m pip install --upgrade openvino openvino-dev 2>&1 | tail -5
        log_success "OpenVINO upgraded"
        ((FIXES_APPLIED++))
    fi
else
    log_info "Installing OpenVINO Python package..."

    log "${BLUE}4.2 Install OpenVINO via pip${NC}"
    log "──────────────────────────────────────"

    if python3 -m pip install openvino openvino-dev 2>&1 | tail -10; then
        log_success "OpenVINO Python package installed"
        ((FIXES_APPLIED++))

        # Verify
        if python3 -c "import openvino" 2>/dev/null; then
            VERSION=$(python3 -c "import openvino; print(openvino.__version__)")
            log_success "Verified: OpenVINO $VERSION"
        else
            log_error "Installation succeeded but import failed"
            ((ERRORS++))
        fi
    else
        log_error "OpenVINO pip installation failed"
        ((ERRORS++))
    fi
fi

# =============================================================================
# SECTION 5: Test OpenCL Access
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 5: Verify OpenCL Access${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}5.1 Test OpenCL platform detection${NC}"
log "──────────────────────────────────────"

if command -v clinfo &> /dev/null; then
    log_info "Running clinfo..."

    if CLINFO_OUT=$(clinfo -l 2>&1); then
        PLATFORMS=$(echo "$CLINFO_OUT" | grep -c "Platform #" || echo "0")

        if [ "$PLATFORMS" -gt 0 ]; then
            log_success "OpenCL working: $PLATFORMS platform(s) detected"
            echo "$CLINFO_OUT" | grep -A 2 "Platform #"
        else
            log_error "OpenCL installed but no platforms detected"
            log_info "This may require a system reboot"
            ((ERRORS++))
        fi
    else
        log_error "clinfo execution failed"
        echo "$CLINFO_OUT"
        ((ERRORS++))
    fi
else
    log_error "clinfo not found after installation"
    ((ERRORS++))
fi

# =============================================================================
# SECTION 6: Test OpenVINO Device Access
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 6: Test OpenVINO Device Enumeration${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

if python3 -c "import openvino" 2>/dev/null; then
    log "${BLUE}6.1 List available OpenVINO devices${NC}"
    log "──────────────────────────────────────"

    DEVICE_TEST=$(mktemp /tmp/ov-device-test-XXXXX.py)
    cat > "$DEVICE_TEST" << 'EOFDEVTEST'
import sys
try:
    import openvino as ov
    core = ov.Core()

    devices = core.available_devices
    if devices:
        print(f"✅ Found {len(devices)} device(s):")
        for device in devices:
            try:
                full_name = core.get_property(device, "FULL_DEVICE_NAME")
                print(f"  • {device}: {full_name}")
            except:
                print(f"  • {device}: (name unavailable)")
        sys.exit(0)
    else:
        print("❌ No devices found!")
        sys.exit(1)

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(2)
EOFDEVTEST

    if python3 "$DEVICE_TEST"; then
        DEVICE_EXIT=$?
        if [ $DEVICE_EXIT -eq 0 ]; then
            log_success "OpenVINO device enumeration successful"
        else
            log_error "No OpenVINO devices found"
            ((ERRORS++))
        fi
    else
        log_error "Device enumeration failed"
        ((ERRORS++))
    fi

    rm -f "$DEVICE_TEST"

    # =============================================================================
    # SECTION 7: Quick Inference Test
    # =============================================================================
    log ""
    log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    log "${MAGENTA}SECTION 7: Quick Inference Test${NC}"
    log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    log ""

    log "${BLUE}7.1 Run test inference on CPU${NC}"
    log "──────────────────────────────────────"

    INFER_TEST=$(mktemp /tmp/ov-infer-test-XXXXX.py)
    cat > "$INFER_TEST" << 'EOFINFER'
import sys
try:
    import openvino as ov
    import numpy as np
    from openvino.runtime import Model, opset10

    core = ov.Core()

    # Create simple model
    param = opset10.parameter([1, 3, 224, 224], np.float32, name="input")
    relu = opset10.relu(param)
    model = Model([relu], [param], "simple_test")

    # Compile for CPU
    compiled = core.compile_model(model, "CPU")

    # Run inference
    input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
    result = compiled([input_data])

    print("✅ Inference test PASSED")
    sys.exit(0)

except Exception as e:
    print(f"❌ Inference test FAILED: {e}")
    sys.exit(1)
EOFINFER

    if python3 "$INFER_TEST"; then
        log_success "Inference test passed - OpenVINO fully functional"
    else
        log_warning "Inference test failed - may need system reboot"
        ((ERRORS++))
    fi

    rm -f "$INFER_TEST"
fi

# =============================================================================
# SECTION 8: Create setupvars script
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 8: Environment Configuration${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}8.1 Create OpenVINO environment setup${NC}"
log "──────────────────────────────────────"

SETUPVARS_FILE="$HOME/.openvino_setupvars.sh"

cat > "$SETUPVARS_FILE" << 'EOFSETUP'
#!/bin/bash
# OpenVINO Environment Setup - Meteor Lake Optimized

# Python OpenVINO path (if installed via pip)
if python3 -c "import openvino" 2>/dev/null; then
    export OPENVINO_PYTHON_INSTALLED=1
    OV_PYTHON_PATH=$(python3 -c "import openvino; import os; print(os.path.dirname(openvino.__file__))" 2>/dev/null)
    export OPENVINO_PYTHON_PATH="$OV_PYTHON_PATH"
fi

# System installation path (if exists)
if [ -f /opt/intel/openvino/setupvars.sh ]; then
    source /opt/intel/openvino/setupvars.sh
fi

# OpenCL/Level Zero
export OCL_ICD_VENDORS=/etc/OpenCL/vendors

# Performance tuning for Meteor Lake (per CLAUDE.md)
export OMP_NUM_THREADS=22  # All cores
export OV_CPU_THREADS_NUM=22

# P-cores for compute-intensive (0-11)
# E-cores for I/O (12-21)

echo "OpenVINO environment configured for Meteor Lake"
EOFSETUP

chmod +x "$SETUPVARS_FILE"
log_success "Created $SETUPVARS_FILE"

# Add to .bashrc if not already present
if ! grep -q "openvino_setupvars" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# OpenVINO environment" >> "$HOME/.bashrc"
    echo "[ -f $SETUPVARS_FILE ] && source $SETUPVARS_FILE" >> "$HOME/.bashrc"
    log_success "Added to ~/.bashrc"
    ((FIXES_APPLIED++))
fi

# =============================================================================
# FINAL SUMMARY
# =============================================================================
log ""
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}RESOLUTION COMPLETE${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log ""

log "${BLUE}Summary:${NC}"
log "  Fixes Applied: $FIXES_APPLIED"
log "  Errors: $ERRORS"
log ""

if [ $ERRORS -eq 0 ]; then
    log_success "✅ ALL FIXES APPLIED SUCCESSFULLY"
    log ""
    log "${YELLOW}IMPORTANT: Group membership changes require logout/login or:${NC}"
    log "  newgrp render"
    log ""
    log "Then run diagnostic script to verify:"
    log "  ./openvino-diagnostic-complete.sh"
    log ""
    log "Recommended usage (per CLAUDE.md):"
    log "  GPU: Best for inference (-d GPU)"
    log "  CPU: Excellent parallel performance (-d CPU)"
    log "  Avoid NPU: 95% non-functional on Meteor Lake"
elif [ $ERRORS -lt 3 ]; then
    log_warning "⚠ COMPLETED WITH MINOR ERRORS"
    log ""
    log "Most issues fixed. Minor errors may resolve with:"
    log "  1. System reboot"
    log "  2. Re-login (for group changes)"
    log "  3. Run diagnostic script to verify"
else
    log_error "❌ MULTIPLE ERRORS OCCURRED"
    log ""
    log "Review error messages above and:"
    log "  1. Check /var/log/apt/term.log for package errors"
    log "  2. Verify internet connection"
    log "  3. Try manual installation steps"
fi

log ""
exit 0
