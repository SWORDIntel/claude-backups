#!/bin/bash
# Quick OpenVINO Test - Safe execution without crashes
# Tests OpenVINO installation and device access

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== OpenVINO Quick Test ===${NC}"
echo ""

# Test 1: Check OpenVINO Python import
echo -e "${BLUE}1. Testing OpenVINO Python import${NC}"
echo "─────────────────────────────────"

if python3 -c "import openvino" 2>/dev/null; then
    VERSION=$(python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ OpenVINO installed: version $VERSION${NC}"
else
    echo -e "${RED}❌ OpenVINO NOT installed${NC}"
    echo ""
    echo "Install with: pip install openvino openvino-dev"
    exit 1
fi

# Test 2: Device enumeration
echo ""
echo -e "${BLUE}2. Listing available devices${NC}"
echo "─────────────────────────────────"

python3 << 'EOF'
try:
    import openvino as ov
    core = ov.Core()
    devices = core.available_devices

    if devices:
        print(f"\033[0;32m✅ Found {len(devices)} device(s):\033[0m")
        for device in devices:
            try:
                full_name = core.get_property(device, "FULL_DEVICE_NAME")
                print(f"  • {device}: {full_name}")
            except:
                print(f"  • {device}: (unable to get name)")
    else:
        print("\033[0;31m❌ No devices found\033[0m")
        exit(1)
except Exception as e:
    print(f"\033[0;31m❌ Error: {e}\033[0m")
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Device enumeration failed${NC}"
    exit 1
fi

# Test 3: Simple CPU inference
echo ""
echo -e "${BLUE}3. Testing CPU inference${NC}"
echo "─────────────────────────────────"

python3 << 'EOF'
try:
    import openvino as ov
    import numpy as np
    from openvino.runtime import Model, opset10

    core = ov.Core()

    # Create minimal test model
    param = opset10.parameter([1, 10], np.float32, name="input")
    relu = opset10.relu(param)
    model = Model([relu], [param], "test")

    # Compile for CPU
    compiled = core.compile_model(model, "CPU")

    # Run one inference
    input_data = np.random.randn(1, 10).astype(np.float32)
    result = compiled([input_data])

    print("\033[0;32m✅ Inference test PASSED\033[0m")
except Exception as e:
    print(f"\033[0;31m❌ Inference test FAILED: {e}\033[0m")
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Inference test failed${NC}"
    exit 1
fi

# Test 4: Check OpenCL
echo ""
echo -e "${BLUE}4. Checking OpenCL status${NC}"
echo "─────────────────────────────────"

if command -v clinfo &> /dev/null; then
    PLATFORMS=$(clinfo -l 2>&1 | grep -c "Platform #" || echo "0")
    if [ "$PLATFORMS" -gt 0 ]; then
        echo -e "${GREEN}✅ OpenCL available: $PLATFORMS platform(s)${NC}"
        clinfo -l 2>&1 | grep "Platform #" | head -3
    else
        echo -e "${YELLOW}⚠ OpenCL installed but no platforms${NC}"
    fi
else
    echo -e "${YELLOW}⚠ clinfo not installed${NC}"
    echo "  Install: sudo apt install clinfo"
fi

# Test 5: Check GPU device nodes
echo ""
echo -e "${BLUE}5. Checking GPU hardware access${NC}"
echo "─────────────────────────────────"

if [ -e /dev/dri/renderD128 ]; then
    echo -e "${GREEN}✅ GPU render device: /dev/dri/renderD128${NC}"
    ls -l /dev/dri/renderD128
else
    echo -e "${RED}❌ GPU render device not found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════${NC}"
echo -e "${GREEN}✅ OpenVINO is functional!${NC}"
echo ""
echo "Recommended usage (per CLAUDE.md):"
echo "  • GPU: Intel Arc Graphics (best for inference)"
echo "  • CPU: Core Ultra 7 155H (excellent parallel performance)"
echo "  • Avoid NPU: 95% non-functional on Meteor Lake"
echo ""
