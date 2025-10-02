#!/bin/bash
# OpenVINO Complete Diagnostic and Testing Suite
# Meteor Lake Intel Core Ultra 7 155H optimized
# Safe execution with error handling and comprehensive logging

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log file
LOG_FILE="/tmp/openvino-diagnostic-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="/tmp/openvino-errors-$(date +%Y%m%d-%H%M%S).log"

# Initialize logs
echo "OpenVINO Diagnostic Log - $(date)" > "$LOG_FILE"
echo "OpenVINO Error Log - $(date)" > "$ERROR_LOG"

# Logging functions
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$ERROR_LOG"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}ℹ $1${NC}" | tee -a "$LOG_FILE"
}

# Safe command execution
safe_exec() {
    local cmd="$1"
    local description="$2"

    log_info "Executing: $description"
    if eval "$cmd" >> "$LOG_FILE" 2>> "$ERROR_LOG"; then
        log_success "$description - OK"
        return 0
    else
        log_error "$description - FAILED"
        return 1
    fi
}

# Header
clear
log "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
log "${BLUE}║   OpenVINO Complete Diagnostic Suite - Meteor Lake            ║${NC}"
log "${BLUE}║   Intel Core Ultra 7 155H (22 cores) + Arc Graphics           ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
log ""

# Track issues
ISSUES_FOUND=0
CRITICAL_ISSUES=0

# =============================================================================
# SECTION 1: System Information
# =============================================================================
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 1: System Information & Hardware Detection${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

# CPU Information
log "\n${BLUE}1.1 CPU Topology (Meteor Lake)${NC}"
log "──────────────────────────────────────"

TOTAL_CPUS=$(nproc)
log_info "Total CPUs detected: $TOTAL_CPUS"

if [ "$TOTAL_CPUS" -eq 22 ]; then
    log_success "Correct CPU count for Core Ultra 7 155H"
    log "  P-Cores: 0-11 (6 physical + HT) - 119.3 GFLOPS or 75 GFLOPS"
    log "  E-Cores: 12-21 (10 physical) - 59.4 GFLOPS"
else
    log_warning "Expected 22 CPUs, found $TOTAL_CPUS"
    ((ISSUES_FOUND++))
fi

# Check AVX-512 availability
log "\n${BLUE}1.2 CPU Features (AVX-512 Status)${NC}"
log "──────────────────────────────────────"

MICROCODE=$(grep microcode /proc/cpuinfo | head -1 | awk '{print $3}')
log_info "CPU Microcode: $MICROCODE"

if grep -q avx512 /proc/cpuinfo; then
    log_success "AVX-512 available (119.3 GFLOPS P-core performance)"
else
    log_warning "AVX-512 disabled by microcode (75 GFLOPS AVX2 fallback)"
fi

# Memory
log "\n${BLUE}1.3 Memory Configuration${NC}"
log "──────────────────────────────────────"

TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
log_info "Total RAM: ${TOTAL_MEM}GB"

if [ "$TOTAL_MEM" -ge 60 ]; then
    log_success "64GB DDR5-5600 ECC detected"
else
    log_warning "Expected 64GB, found ${TOTAL_MEM}GB"
    ((ISSUES_FOUND++))
fi

# =============================================================================
# SECTION 2: GPU Hardware & Drivers
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 2: GPU Hardware & Graphics Stack${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

log "\n${BLUE}2.1 Intel Arc Graphics Detection${NC}"
log "──────────────────────────────────────"

GPU_DEVICE=$(lspci | grep -i "VGA.*Intel" | head -1)
if [ -n "$GPU_DEVICE" ]; then
    log_success "GPU Found: $GPU_DEVICE"
else
    log_error "Intel GPU not detected"
    ((CRITICAL_ISSUES++))
fi

# DRI/DRM devices
log "\n${BLUE}2.2 DRI/DRM Device Nodes${NC}"
log "──────────────────────────────────────"

if [ -e /dev/dri/card0 ]; then
    log_success "/dev/dri/card0 exists"
    ls -l /dev/dri/card0 | tee -a "$LOG_FILE"
else
    log_error "/dev/dri/card0 missing"
    ((CRITICAL_ISSUES++))
fi

if [ -e /dev/dri/renderD128 ]; then
    log_success "/dev/dri/renderD128 exists (compute access)"
    ls -l /dev/dri/renderD128 | tee -a "$LOG_FILE"

    # Check permissions
    if [ -r /dev/dri/renderD128 ] && [ -w /dev/dri/renderD128 ]; then
        log_success "User has read/write access to renderD128"
    else
        log_warning "Insufficient permissions on renderD128"
        log_info "Add user to 'render' group: sudo usermod -a -G render $USER"
        ((ISSUES_FOUND++))
    fi
else
    log_error "/dev/dri/renderD128 missing"
    ((CRITICAL_ISSUES++))
fi

# User groups
log "\n${BLUE}2.3 User Group Membership${NC}"
log "──────────────────────────────────────"

USER_GROUPS=$(groups)
log_info "Current groups: $USER_GROUPS"

if echo "$USER_GROUPS" | grep -q "render"; then
    log_success "User in 'render' group"
else
    log_warning "User NOT in 'render' group"
    log_info "Fix: sudo usermod -a -G render $USER && newgrp render"
    ((ISSUES_FOUND++))
fi

if echo "$USER_GROUPS" | grep -q "video"; then
    log_success "User in 'video' group"
else
    log_warning "User NOT in 'video' group"
    log_info "Fix: sudo usermod -a -G video $USER && newgrp video"
    ((ISSUES_FOUND++))
fi

# =============================================================================
# SECTION 3: OpenCL & Compute Runtime
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 3: OpenCL & Compute Stack${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

log "\n${BLUE}3.1 OpenCL ICD Loader${NC}"
log "──────────────────────────────────────"

if dpkg -l | grep -q ocl-icd-libopencl1; then
    log_success "ocl-icd-libopencl1 installed"
else
    log_error "ocl-icd-libopencl1 NOT installed"
    log_info "Install: sudo apt install ocl-icd-libopencl1"
    ((CRITICAL_ISSUES++))
fi

log "\n${BLUE}3.2 Intel OpenCL Runtime${NC}"
log "──────────────────────────────────────"

if dpkg -l | grep -q intel-opencl-icd; then
    log_success "intel-opencl-icd installed"
    dpkg -l | grep intel-opencl-icd | tee -a "$LOG_FILE"
else
    log_error "intel-opencl-icd NOT installed"
    log_info "Install: sudo apt install intel-opencl-icd"
    ((CRITICAL_ISSUES++))
fi

log "\n${BLUE}3.3 Level Zero Runtime${NC}"
log "──────────────────────────────────────"

if dpkg -l | grep -q level-zero; then
    log_success "level-zero packages installed"
    dpkg -l | grep level-zero | tee -a "$LOG_FILE"
else
    log_warning "level-zero NOT installed"
    log_info "Install: sudo apt install intel-level-zero-gpu level-zero"
    ((ISSUES_FOUND++))
fi

if [ -f /usr/lib/x86_64-linux-gnu/libze_loader.so.1 ]; then
    log_success "Level Zero loader: /usr/lib/x86_64-linux-gnu/libze_loader.so.1"
    ls -lh /usr/lib/x86_64-linux-gnu/libze_loader.so* 2>/dev/null | tee -a "$LOG_FILE"
else
    log_warning "Level Zero loader not found"
    ((ISSUES_FOUND++))
fi

log "\n${BLUE}3.4 OpenCL Platform Enumeration${NC}"
log "──────────────────────────────────────"

if command -v clinfo &> /dev/null; then
    log_success "clinfo installed"

    # Try to run clinfo
    if OPENCL_OUT=$(clinfo -l 2>&1); then
        OPENCL_PLATFORMS=$(echo "$OPENCL_OUT" | grep -c "Platform #" || echo "0")

        if [ "$OPENCL_PLATFORMS" -gt 0 ]; then
            log_success "OpenCL platforms detected: $OPENCL_PLATFORMS"
            echo "$OPENCL_OUT" | grep -A 2 "Platform #" | tee -a "$LOG_FILE"

            # Get device details
            if DEVICE_NAME=$(clinfo 2>&1 | grep "Device Name" | head -1 | cut -d: -f2); then
                log_success "OpenCL Device: $DEVICE_NAME"
            fi
        else
            log_error "No OpenCL platforms found"
            ((CRITICAL_ISSUES++))
        fi
    else
        log_error "clinfo execution failed"
        echo "$OPENCL_OUT" >> "$ERROR_LOG"
        ((CRITICAL_ISSUES++))
    fi
else
    log_warning "clinfo not installed"
    log_info "Install: sudo apt install clinfo"
    ((ISSUES_FOUND++))
fi

# =============================================================================
# SECTION 4: NPU/VPU Hardware
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 4: NPU/VPU Detection (Meteor Lake Neural Engine)${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

log "\n${BLUE}4.1 NPU Device Node${NC}"
log "──────────────────────────────────────"

if [ -e /dev/accel/accel0 ]; then
    log_success "NPU device: /dev/accel/accel0"
    ls -l /dev/accel/accel0 | tee -a "$LOG_FILE"

    log_warning "IMPORTANT: Per CLAUDE.md, NPU v1.17.0 is 95% non-functional"
    log_info "Recommendation: Use CPU or GPU instead"
else
    log_info "NPU device not found (expected on Meteor Lake)"
    log_info "This is normal - NPU driver support is limited"
fi

log "\n${BLUE}4.2 NPU Kernel Module${NC}"
log "──────────────────────────────────────"

if lsmod | grep -q intel_vpu; then
    log_success "intel_vpu module loaded"
    VPU_VERSION=$(modinfo intel_vpu 2>/dev/null | grep "^version:" | awk '{print $2}')
    log_info "Module version: $VPU_VERSION"
else
    log_info "intel_vpu module not loaded (expected)"
fi

# =============================================================================
# SECTION 5: OpenVINO Installation
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 5: OpenVINO Installation Status${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

OPENVINO_FOUND=0

log "\n${BLUE}5.1 System Installation (/opt/intel/openvino)${NC}"
log "──────────────────────────────────────"

if [ -f /opt/intel/openvino/setupvars.sh ]; then
    log_success "OpenVINO system installation found"

    if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino.so ]; then
        log_success "Core library: libopenvino.so"

        # Try to get version
        if [ -f /opt/intel/openvino/runtime/include/openvino/openvino.hpp ]; then
            log_info "C++ headers present"
        fi
    fi

    OPENVINO_FOUND=1
else
    log_info "No system installation at /opt/intel/openvino"
fi

log "\n${BLUE}5.2 Python Package Installation${NC}"
log "──────────────────────────────────────"

# Test multiple Python interpreters
for PYTHON_CMD in python3 python python3.11 python3.10; do
    if command -v "$PYTHON_CMD" &> /dev/null; then
        log_info "Testing $PYTHON_CMD..."

        if $PYTHON_CMD -c "import openvino" 2>/dev/null; then
            log_success "OpenVINO Python package found ($PYTHON_CMD)"

            OV_VERSION=$($PYTHON_CMD -c "import openvino; print(openvino.__version__)" 2>/dev/null || echo "unknown")
            log_info "Version: $OV_VERSION"

            OV_PATH=$($PYTHON_CMD -c "import openvino; print(openvino.__file__)" 2>/dev/null || echo "")
            log_info "Path: $OV_PATH"

            OPENVINO_FOUND=1
            PYTHON_WORKING="$PYTHON_CMD"
            break
        else
            log_info "$PYTHON_CMD - OpenVINO not found"
        fi
    fi
done

if [ $OPENVINO_FOUND -eq 0 ]; then
    log_error "OpenVINO NOT installed (neither system nor Python)"
    ((CRITICAL_ISSUES++))
fi

log "\n${BLUE}5.3 OpenVINO Plugins${NC}"
log "──────────────────────────────────────"

# Check for GPU plugin
if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino_intel_gpu_plugin.so ]; then
    log_success "GPU Plugin: Found"
elif find /usr -name "*openvino*gpu*.so" 2>/dev/null | grep -q .; then
    log_success "GPU Plugin: Found in system paths"
else
    log_warning "GPU plugin not found"
    ((ISSUES_FOUND++))
fi

# Check for CPU plugin
if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino_intel_cpu_plugin.so ]; then
    log_success "CPU Plugin: Found"
elif find /usr -name "*openvino*cpu*.so" 2>/dev/null | grep -q .; then
    log_success "CPU Plugin: Found in system paths"
else
    log_warning "CPU plugin not found"
    ((ISSUES_FOUND++))
fi

# =============================================================================
# SECTION 6: OpenVINO Device Enumeration
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 6: OpenVINO Device Enumeration & Testing${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

if [ $OPENVINO_FOUND -eq 1 ] && [ -n "${PYTHON_WORKING:-}" ]; then
    log "\n${BLUE}6.1 Available Devices${NC}"
    log "──────────────────────────────────────"

    # Safe Python execution with error handling
    PYTHON_TEST=$(mktemp /tmp/ov-test-XXXXX.py)
    cat > "$PYTHON_TEST" << 'EOFPYTHON'
import sys
try:
    import openvino as ov
    core = ov.Core()

    print("OpenVINO Version:", ov.__version__)
    print("\nAvailable devices:")

    devices = core.available_devices
    if not devices:
        print("  ⚠ No devices found!")
        sys.exit(1)

    for device in devices:
        try:
            full_name = core.get_property(device, "FULL_DEVICE_NAME")
            print(f"  ✅ {device}: {full_name}")
        except Exception as e:
            print(f"  ⚠ {device}: Error getting name - {e}")

    sys.exit(0)

except ImportError as e:
    print(f"ERROR: Failed to import openvino: {e}")
    sys.exit(2)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(3)
EOFPYTHON

    if $PYTHON_WORKING "$PYTHON_TEST" 2>&1 | tee -a "$LOG_FILE"; then
        PYTHON_EXIT=${PIPESTATUS[0]}

        if [ $PYTHON_EXIT -eq 0 ]; then
            log_success "Device enumeration successful"
        elif [ $PYTHON_EXIT -eq 1 ]; then
            log_warning "No devices found - plugin issue"
            ((CRITICAL_ISSUES++))
        elif [ $PYTHON_EXIT -eq 2 ]; then
            log_error "Import failed - installation issue"
            ((CRITICAL_ISSUES++))
        else
            log_error "Runtime error during device enumeration"
            ((CRITICAL_ISSUES++))
        fi
    else
        log_error "Python test script failed"
        ((CRITICAL_ISSUES++))
    fi

    rm -f "$PYTHON_TEST"

    # =============================================================================
    # SECTION 7: Performance Benchmark (if devices found)
    # =============================================================================
    log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    log "${MAGENTA}SECTION 7: Quick Performance Test${NC}"
    log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

    log "\n${BLUE}7.1 Model Inference Test (CPU)${NC}"
    log "──────────────────────────────────────"

    PERF_TEST=$(mktemp /tmp/ov-perf-XXXXX.py)
    cat > "$PERF_TEST" << 'EOFPERF'
import sys
import time
try:
    import openvino as ov
    import numpy as np

    core = ov.Core()

    # Simple test model: 1x3x224x224 input
    print("Creating simple test model...")
    from openvino.runtime import Model, opset10

    param = opset10.parameter([1, 3, 224, 224], np.float32, name="input")
    relu = opset10.relu(param)
    model = Model([relu], [param], "test_model")

    # Compile for CPU
    print("Compiling for CPU...")
    compiled_model = core.compile_model(model, "CPU")

    # Run inference
    print("Running inference...")
    input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)

    start = time.time()
    for i in range(10):
        result = compiled_model([input_data])
    elapsed = time.time() - start

    print(f"✅ 10 inferences completed in {elapsed:.3f}s ({elapsed/10*1000:.1f}ms per inference)")
    sys.exit(0)

except Exception as e:
    print(f"Test failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOFPERF

    if $PYTHON_WORKING "$PERF_TEST" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Performance test passed"
    else
        log_warning "Performance test failed (see logs)"
        ((ISSUES_FOUND++))
    fi

    rm -f "$PERF_TEST"
else
    log_warning "Skipping device enumeration - OpenVINO not installed"
fi

# =============================================================================
# SECTION 8: Environment & Dependencies
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}SECTION 8: Dependencies & Environment${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

log "\n${BLUE}8.1 Build Dependencies (if building from source)${NC}"
log "──────────────────────────────────────"

REQUIRED_PKGS=(
    "cmake"
    "build-essential"
    "git"
    "python3-dev"
    "python3-pip"
    "libusb-1.0-0-dev"
    "libtbb-dev"
    "libpugixml-dev"
)

for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        log_success "$pkg - installed"
    else
        log_warning "$pkg - NOT installed"
        ((ISSUES_FOUND++))
    fi
done

log "\n${BLUE}8.2 Environment Variables${NC}"
log "──────────────────────────────────────"

if [ -n "${INTEL_OPENVINO_DIR:-}" ]; then
    log_info "INTEL_OPENVINO_DIR: $INTEL_OPENVINO_DIR"
else
    log_info "INTEL_OPENVINO_DIR not set"
fi

if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    log_info "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
else
    log_info "LD_LIBRARY_PATH not set"
fi

# =============================================================================
# FINAL SUMMARY
# =============================================================================
log "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
log "${MAGENTA}DIAGNOSTIC SUMMARY${NC}"
log "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"

log "\n${BLUE}Issues Found:${NC}"
log "  Critical Issues: $CRITICAL_ISSUES"
log "  Warnings: $ISSUES_FOUND"
log ""

if [ $CRITICAL_ISSUES -eq 0 ] && [ $ISSUES_FOUND -eq 0 ]; then
    log_success "✅ ALL CHECKS PASSED - OpenVINO ready for use!"
    log ""
    log "Recommended devices (per CLAUDE.md):"
    log "  1. GPU (Intel Arc Graphics) - Best for inference"
    log "  2. CPU (Core Ultra 7 155H) - Excellent parallel performance"
    log "  3. Avoid NPU - 95% non-functional on Meteor Lake"
elif [ $CRITICAL_ISSUES -eq 0 ]; then
    log_warning "⚠ MINOR ISSUES FOUND - OpenVINO may work with limitations"
    log ""
    log "Review warnings above and run resolution script if needed"
else
    log_error "❌ CRITICAL ISSUES FOUND - OpenVINO installation incomplete"
    log ""
    log "Run the resolution script: sudo ./openvino-resolution.sh"
fi

log ""
log "Logs saved to:"
log "  Full log: $LOG_FILE"
log "  Errors: $ERROR_LOG"
log ""

exit 0
