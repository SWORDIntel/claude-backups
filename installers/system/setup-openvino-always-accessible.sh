#!/bin/bash
# Make OpenVINO always accessible - Enhanced bashrc setup
# Works with existing global OpenVINO installation

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   OpenVINO Always Accessible Setup                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

BASHRC="$HOME/.bashrc"

# Verify OpenVINO is installed globally
echo -e "${BLUE}1. Verifying OpenVINO installation...${NC}"

if python3 -c "import openvino" 2>/dev/null; then
    OV_VERSION=$(python3 -c "import openvino; print(openvino.__version__)")
    echo -e "${GREEN}✅ OpenVINO ${OV_VERSION} is installed globally${NC}"
else
    echo -e "${YELLOW}⚠ OpenVINO not found. Installing...${NC}"
    pip install --user openvino openvino-dev
    OV_VERSION=$(python3 -c "import openvino; print(openvino.__version__)")
    echo -e "${GREEN}✅ OpenVINO ${OV_VERSION} installed${NC}"
fi

# Backup bashrc
echo ""
echo -e "${BLUE}2. Backing up .bashrc...${NC}"
cp "$BASHRC" "$BASHRC.backup-always-accessible-$(date +%Y%m%d-%H%M%S)"
echo -e "${GREEN}✅ Backup created${NC}"

# Enhanced bashrc configuration
echo ""
echo -e "${BLUE}3. Configuring enhanced bashrc setup...${NC}"

# Remove any old OpenVINO sections
sed -i '/# OpenVINO Auto-Setup - START/,/# OpenVINO Auto-Setup - END/d' "$BASHRC"
sed -i '/# Claude.*Venv.*START/,/# Claude.*Venv.*END/d' "$BASHRC"

# Add comprehensive OpenVINO setup
cat >> "$BASHRC" << 'EOFBASHRC'

# ============================================================================
# OpenVINO Always Accessible - START
# ============================================================================
# Comprehensive OpenVINO setup for Intel Meteor Lake
# Makes OpenVINO and all tools available in every terminal

# Only configure in interactive shells
if [[ $- == *i* ]]; then
    # Check if OpenVINO is available
    if command -v python3 &> /dev/null && python3 -c "import openvino" 2>/dev/null; then
        export OPENVINO_INSTALLED=1

        # Get OpenVINO version (suppress warnings)
        export OPENVINO_VERSION=$(python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null)
        export OPENVINO_PYTHON_PATH=$(python3 -c "import openvino, os; print(os.path.dirname(openvino.__file__))" 2>/dev/null)

        # OpenCL/Level Zero configuration
        export OCL_ICD_VENDORS=/etc/OpenCL/vendors

        # Performance tuning for Meteor Lake (Intel Core Ultra 7 165H)
        TOTAL_CORES=$(nproc)
        export OMP_NUM_THREADS=$TOTAL_CORES
        export OV_CPU_THREADS_NUM=$TOTAL_CORES

        # Intel-specific optimizations
        export KMP_BLOCKTIME=0
        export KMP_AFFINITY=granularity=fine,compact,1,0

        # Suppress deprecation warnings
        export PYTHONWARNINGS="ignore::DeprecationWarning"

        # Aliases for quick OpenVINO operations
        alias ov-test='python3 << "EOFTEST"
import openvino as ov
core = ov.Core()
print(f"\n✅ OpenVINO {ov.__version__}")
print(f"Devices: {len(core.available_devices)}")
for d in core.available_devices:
    full_name = core.get_property(d, "FULL_DEVICE_NAME")
    print(f"  • {d}: {full_name}")
EOFTEST
'

        alias ov-devices='python3 -c "import openvino as ov; core = ov.Core(); [print(f\"  • {d}: {core.get_property(d, '\"'\"'FULL_DEVICE_NAME'\"'\"')}\") for d in core.available_devices]" 2>/dev/null'

        alias ov-version='python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null'

        alias ov-info='echo -e "\033[0;34m=== OpenVINO Info ===\033[0m" && ov-version && echo -e "\033[0;34mDevices:\033[0m" && ov-devices'

        alias ov-bench='python3 << "EOFBENCH"
import openvino as ov
import numpy as np
from openvino.runtime import opset10, Model
import time

core = ov.Core()
print("\n🔥 Quick Benchmark...")

# Simple test model
param = opset10.parameter([1, 100], np.float32, name="input")
relu = opset10.relu(param)
model = Model([relu], [param], "bench")

# CPU test
compiled = core.compile_model(model, "CPU")
data = np.random.randn(1, 100).astype(np.float32)
start = time.time()
for _ in range(100):
    compiled([data])
elapsed = time.time() - start
print(f"✅ CPU: {100/elapsed:.0f} inferences/sec ({elapsed*10:.1f}ms per 100)")
EOFBENCH
'

        # Optional: Display activation message on terminal start
        # Uncomment the line below if you want a message in each new terminal
        # echo -e "\033[0;32m✅ OpenVINO ${OPENVINO_VERSION} ready\033[0m"
    else
        # OpenVINO not installed - provide installation hint
        alias ov-install='pip install --user openvino openvino-dev && echo "✅ OpenVINO installed. Restart terminal to activate."'
    fi
fi

# ============================================================================
# OpenVINO Always Accessible - END
# ============================================================================
EOFBASHRC

echo -e "${GREEN}✅ Enhanced bashrc configuration added${NC}"

# Test the configuration
echo ""
echo -e "${BLUE}4. Testing configuration...${NC}"

source "$BASHRC"

if [ -n "${OPENVINO_VERSION:-}" ]; then
    echo -e "${GREEN}✅ OpenVINO ${OPENVINO_VERSION} configured${NC}"
    echo -e "${GREEN}✅ Environment variables set${NC}"
else
    echo -e "${YELLOW}⚠ Configuration will activate in new terminals${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Setup Complete!                                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "OpenVINO is now always accessible!"
echo ""
echo "Available commands in ANY terminal:"
echo -e "  ${GREEN}ov-info${NC}      - Show OpenVINO version and devices"
echo -e "  ${GREEN}ov-test${NC}      - Run quick test"
echo -e "  ${GREEN}ov-bench${NC}     - Run performance benchmark"
echo -e "  ${GREEN}ov-devices${NC}   - List available devices"
echo -e "  ${GREEN}ov-version${NC}   - Show version only"
echo ""

echo "To activate in current terminal:"
echo -e "  ${YELLOW}source ~/.bashrc${NC}"
echo ""
echo "Or open a new terminal (auto-configured)"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ OpenVINO now works in every terminal automatically!       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
