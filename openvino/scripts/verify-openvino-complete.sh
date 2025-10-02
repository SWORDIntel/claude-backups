#!/bin/bash
# OpenVINO Complete Hardware Access Verification
# Tests GPU, NPU/VPU, and GNA access for OpenVINO 2024.5

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== OpenVINO Hardware Access Verification ===${NC}"
echo ""

# Check if running with necessary permissions
if [[ $EUID -ne 0 ]]; then
   if ! groups | grep -q "render\|video"; then
      echo -e "${YELLOW}⚠ Warning: User not in 'render' or 'video' group${NC}"
      echo "  Run: sudo usermod -a -G render,video $USER"
      echo "  Then logout/login for changes to take effect"
   fi
fi

echo -e "${BLUE}1. GPU Access (Intel Arc Graphics - Meteor Lake)${NC}"
echo "─────────────────────────────────────────────────"

# Check GPU hardware
GPU_DEVICE=$(lspci | grep -i "VGA.*Intel.*Meteor Lake" || echo "")
if [ -n "$GPU_DEVICE" ]; then
    echo -e "${GREEN}✅ GPU Hardware: $GPU_DEVICE${NC}"
else
    echo -e "${RED}❌ Intel Meteor Lake GPU not found${NC}"
fi

# Check DRI devices
if [ -e /dev/dri/card0 ] && [ -e /dev/dri/renderD128 ]; then
    echo -e "${GREEN}✅ DRI Devices:${NC}"
    ls -l /dev/dri/card0 /dev/dri/renderD128
else
    echo -e "${RED}❌ Missing DRI devices${NC}"
fi

# Check OpenCL
echo ""
echo -e "${BLUE}OpenCL Status:${NC}"
if command -v clinfo &> /dev/null; then
    OPENCL_PLATFORMS=$(clinfo -l 2>&1 | grep -c "Platform #" || echo "0")
    if [ "$OPENCL_PLATFORMS" -gt 0 ]; then
        echo -e "${GREEN}✅ OpenCL available: $OPENCL_PLATFORMS platform(s)${NC}"
        clinfo -l 2>&1 | grep -A 1 "Platform #"

        # Show GPU details
        GPU_NAME=$(clinfo 2>&1 | grep "Device Name" | head -1 | cut -d: -f2 | xargs)
        GPU_VERSION=$(clinfo 2>&1 | grep "Device Version" | head -1 | cut -d: -f2 | xargs)
        echo -e "  Device: ${GREEN}$GPU_NAME${NC}"
        echo -e "  Version: $GPU_VERSION"
    else
        echo -e "${RED}❌ No OpenCL platforms found${NC}"
        echo "  Install: sudo apt install intel-opencl-icd intel-level-zero-gpu"
    fi
else
    echo -e "${YELLOW}⚠ clinfo not installed${NC}"
    echo "  Install: sudo apt install clinfo"
fi

# Check Level Zero
echo ""
if [ -f /usr/lib/x86_64-linux-gnu/libze_loader.so.1 ]; then
    echo -e "${GREEN}✅ Level Zero runtime installed${NC}"
    ls -l /usr/lib/x86_64-linux-gnu/libze_loader.so* 2>/dev/null | head -2
else
    echo -e "${YELLOW}⚠ Level Zero runtime not found${NC}"
fi

echo ""
echo -e "${BLUE}2. NPU/VPU Access (Intel Neural Processing Unit)${NC}"
echo "───────────────────────────────────────────────────"

# Check NPU device
if [ -e /dev/accel/accel0 ]; then
    echo -e "${GREEN}✅ NPU Device: /dev/accel/accel0${NC}"
    ls -l /dev/accel/accel0

    # Check NPU driver
    if lsmod | grep -q "intel_vpu"; then
        echo -e "${GREEN}✅ NPU Kernel Module: intel_vpu loaded${NC}"
        VPU_VERSION=$(modinfo intel_vpu 2>/dev/null | grep "^version:" | awk '{print $2}')
        echo "  Version: $VPU_VERSION"
    else
        echo -e "${YELLOW}⚠ intel_vpu module not loaded${NC}"
    fi

    # Check NPU userspace driver
    if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino_intel_npu_plugin.so ]; then
        echo -e "${GREEN}✅ NPU Plugin: OpenVINO NPU plugin found${NC}"
    elif [ -f /usr/lib/x86_64-linux-gnu/libze_intel_vpu.so ]; then
        echo -e "${GREEN}✅ NPU Plugin: Level Zero VPU plugin found${NC}"
    else
        echo -e "${YELLOW}⚠ NPU userspace plugin not found${NC}"
        echo "  Note: Per CLAUDE.md, NPU v1.17.0 is 95% non-functional on Meteor Lake"
        echo "  Recommendation: Use CPU fallback for inference"
    fi
else
    echo -e "${RED}❌ NPU device /dev/accel/accel0 not found${NC}"
    echo "  This is expected if NPU driver not installed"
    echo "  Meteor Lake NPU support is limited (see CLAUDE.md)"
fi

echo ""
echo -e "${BLUE}3. GNA Access (Gaussian Neural Accelerator)${NC}"
echo "────────────────────────────────────────────────"

# Note: GNA is legacy, mostly discontinued in Meteor Lake
echo -e "${YELLOW}ℹ GNA Status:${NC}"
echo "  Meteor Lake primarily uses NPU, not traditional GNA"
echo "  OpenVINO GNA plugin auto-downloads pre-built library v03.05.00.2116"
echo "  CPU fallback recommended for Meteor Lake (see CLAUDE.md)"

if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino_intel_gna_plugin.so ]; then
    echo -e "${GREEN}✅ GNA Plugin: Found in OpenVINO installation${NC}"
elif find /usr -name "libgna*.so*" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✅ GNA Libraries: System installation detected${NC}"
    find /usr -name "libgna*.so*" 2>/dev/null
else
    echo -e "${YELLOW}⚠ GNA libraries not found${NC}"
    echo "  Will be downloaded during OpenVINO build if ENABLE_INTEL_GNA=ON"
fi

echo ""
echo -e "${BLUE}4. OpenVINO Installation Status${NC}"
echo "─────────────────────────────────────────────────"

# Check for OpenVINO installation
OPENVINO_FOUND=0

# Method 1: Standard installation
if [ -f /opt/intel/openvino/setupvars.sh ]; then
    echo -e "${GREEN}✅ OpenVINO installed: /opt/intel/openvino/${NC}"
    if [ -f /opt/intel/openvino/runtime/lib/intel64/libopenvino.so ]; then
        OV_VERSION=$(/opt/intel/openvino/runtime/lib/intel64/libopenvino.so --version 2>/dev/null || echo "unknown")
        echo "  Version: $OV_VERSION"
    fi
    OPENVINO_FOUND=1
fi

# Method 2: pip installation
if python3 -c "import openvino" 2>/dev/null; then
    echo -e "${GREEN}✅ OpenVINO Python package installed${NC}"
    OV_PY_VER=$(python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null)
    echo "  Version: $OV_PY_VER"
    OPENVINO_FOUND=1
fi

# Method 3: Local build
if [ -d /home/john/Downloads/claude-backups/openvino-build ]; then
    echo -e "${YELLOW}⚠ Local build found: openvino-build/${NC}"
    echo "  Run 'sudo make install' to install system-wide"
    OPENVINO_FOUND=1
fi

if [ $OPENVINO_FOUND -eq 0 ]; then
    echo -e "${RED}❌ OpenVINO not found${NC}"
    echo ""
    echo -e "${BLUE}Installation Options:${NC}"
    echo ""
    echo "Option A (Recommended): Pre-built Runtime"
    echo "  wget https://storage.openvinotoolkit.org/repositories/openvino/packages/2024.5/linux/l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64.tgz"
    echo "  tar -xzf l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64.tgz"
    echo "  cd l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64"
    echo "  sudo ./install_dependencies/install_openvino_dependencies.sh"
    echo "  source setupvars.sh"
    echo ""
    echo "Option B: Python Package (easiest)"
    echo "  pip install openvino openvino-dev"
    echo ""
    echo "Option C: Build from Source (see fix-openvino-install.sh)"
fi

echo ""
echo -e "${BLUE}5. Recommended Configuration for Meteor Lake${NC}"
echo "──────────────────────────────────────────────────────"
echo "Per CLAUDE.md hardware specifications:"
echo ""
echo -e "✅ ${GREEN}USE GPU:${NC} Intel Arc Graphics (fully functional)"
echo "   - OpenCL 3.0 support"
echo "   - Best for inference workloads"
echo "   - Enable with: -d GPU"
echo ""
echo -e "✅ ${GREEN}USE CPU:${NC} Intel Core Ultra 7 155H (22 cores)"
echo "   - P-Cores (0-11): 119.3 GFLOPS or 75 GFLOPS depending on microcode"
echo "   - E-Cores (12-21): 59.4 GFLOPS"
echo "   - Excellent parallel performance"
echo "   - Enable with: -d CPU"
echo ""
echo -e "⚠ ${YELLOW}AVOID NPU:${NC} 95% non-functional (driver v1.17.0)"
echo "   - Known limitation in Meteor Lake"
echo "   - Use CPU or GPU fallback instead"
echo ""
echo -e "⚠ ${YELLOW}GNA:${NC} Legacy accelerator, use CPU for similar workloads"
echo ""

echo -e "${BLUE}6. Quick Test (if OpenVINO installed)${NC}"
echo "──────────────────────────────────────────────────"

if [ $OPENVINO_FOUND -eq 1 ]; then
    echo "Test OpenVINO device enumeration:"
    echo ""

    # Try Python API
    if python3 -c "import openvino" 2>/dev/null; then
        python3 << 'EOPYTHON'
import openvino as ov
core = ov.Core()
print("Available devices:")
for device in core.available_devices:
    print(f"  - {device}: {core.get_property(device, 'FULL_DEVICE_NAME')}")
EOPYTHON
    else
        echo "Python API not available, install: pip install openvino"
    fi
else
    echo "Install OpenVINO first (see options above)"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}Verification Complete!${NC}"
echo ""
echo "Summary:"
echo "  GPU (Intel Arc): $([ -e /dev/dri/renderD128 ] && echo -e "${GREEN}Ready${NC}" || echo -e "${RED}Not Ready${NC}")"
echo "  NPU (Meteor Lake): $([ -e /dev/accel/accel0 ] && echo -e "${YELLOW}Present (limited)${NC}" || echo -e "${YELLOW}Not Present${NC}")"
echo "  OpenVINO: $([ $OPENVINO_FOUND -eq 1 ] && echo -e "${GREEN}Installed${NC}" || echo -e "${RED}Not Installed${NC}")"
echo ""
