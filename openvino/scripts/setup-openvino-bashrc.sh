#!/bin/bash
# Setup OpenVINO Environment in bashrc
# Enables OpenVINO automatically in every terminal session

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   OpenVINO bashrc Setup - Auto-enable for Every Terminal     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup-$(date +%Y%m%d-%H%M%S)"

# Create backup
echo -e "${BLUE}1. Creating backup of .bashrc${NC}"
cp "$BASHRC" "$BACKUP"
echo -e "${GREEN}✅ Backup saved: $BACKUP${NC}"
echo ""

# Check if already configured
if grep -q "# OpenVINO Auto-Setup" "$BASHRC"; then
    echo -e "${YELLOW}⚠ OpenVINO already configured in .bashrc${NC}"
    echo ""
    read -p "Remove existing and reinstall? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Removing old configuration...${NC}"
        # Remove old section
        sed -i '/# OpenVINO Auto-Setup - START/,/# OpenVINO Auto-Setup - END/d' "$BASHRC"
        echo -e "${GREEN}✅ Old configuration removed${NC}"
    else
        echo "Keeping existing configuration"
        exit 0
    fi
fi

echo -e "${BLUE}2. Adding OpenVINO configuration to .bashrc${NC}"

# Add OpenVINO setup to bashrc
cat >> "$BASHRC" << 'EOFBASHRC'

# ============================================================================
# OpenVINO Auto-Setup - START
# ============================================================================
# Automatically enables OpenVINO in every terminal session
# Intel Core Ultra 7 165H (Meteor Lake) + Arc Graphics optimized

# Check if OpenVINO Python package is installed
if command -v python3 &> /dev/null && python3 -c "import openvino" 2>/dev/null; then
    # OpenVINO installed via pip
    export OPENVINO_INSTALLED=1

    # Get OpenVINO version (suppress deprecation warnings)
    OPENVINO_VERSION=$(python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null)

    # OpenVINO environment variables
    export OPENVINO_VERSION
    export OPENVINO_PYTHON_PATH=$(python3 -c "import openvino, os; print(os.path.dirname(openvino.__file__))" 2>/dev/null)

    # OpenCL/Level Zero
    export OCL_ICD_VENDORS=/etc/OpenCL/vendors

    # Performance tuning for Meteor Lake (per CLAUDE.md)
    # CPU: Intel Core Ultra 7 165H - 20 logical cores
    export OMP_NUM_THREADS=20
    export OV_CPU_THREADS_NUM=20

    # Intel-specific optimizations
    export KMP_BLOCKTIME=0
    export KMP_AFFINITY=granularity=fine,compact,1,0

    # Quiet mode - suppress deprecation warnings
    export PYTHONWARNINGS="ignore::DeprecationWarning"

    # Optional: Display OpenVINO status on terminal start (comment out if unwanted)
    # echo -e "\033[0;32m✅ OpenVINO ${OPENVINO_VERSION} loaded\033[0m"
fi

# System installation check (if installed to /opt/intel/openvino)
if [ -f /opt/intel/openvino/setupvars.sh ]; then
    source /opt/intel/openvino/setupvars.sh 2>/dev/null
fi

# Aliases for quick OpenVINO operations
alias ov-test='cd ~/Downloads/claude-backups && ./openvino-quick-test.sh'
alias ov-bench='cd ~/Downloads/claude-backups && python3 openvino-demo-inference.py'
alias ov-devices='python3 -c "import openvino as ov; core = ov.Core(); [print(f\"  • {d}: {core.get_property(d, '\"'\"'FULL_DEVICE_NAME'\"'\"')}\") for d in core.available_devices]" 2>/dev/null'
alias ov-version='python3 -c "import openvino; print(openvino.__version__)" 2>/dev/null'
alias ov-info='echo -e "\033[0;34m=== OpenVINO Info ===\033[0m" && ov-version && echo -e "\033[0;34mDevices:\033[0m" && ov-devices'

# ============================================================================
# OpenVINO Auto-Setup - END
# ============================================================================
EOFBASHRC

echo -e "${GREEN}✅ OpenVINO configuration added to .bashrc${NC}"
echo ""

echo -e "${BLUE}3. Configuration Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The following will be enabled in every new terminal:"
echo ""
echo "Environment Variables:"
echo "  • OPENVINO_VERSION"
echo "  • OPENVINO_PYTHON_PATH"
echo "  • OMP_NUM_THREADS=20 (use all cores)"
echo "  • OV_CPU_THREADS_NUM=20"
echo "  • KMP optimizations for Intel CPUs"
echo ""
echo "Aliases:"
echo "  • ov-test      - Run quick OpenVINO test"
echo "  • ov-bench     - Run performance benchmarks"
echo "  • ov-devices   - List available devices"
echo "  • ov-version   - Show OpenVINO version"
echo "  • ov-info      - Complete OpenVINO info"
echo ""

echo -e "${BLUE}4. Testing configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Source the new bashrc to test
if source "$BASHRC" 2>/dev/null; then
    echo -e "${GREEN}✅ Configuration loaded successfully${NC}"

    # Test OpenVINO
    if [ -n "${OPENVINO_VERSION:-}" ]; then
        echo -e "${GREEN}✅ OpenVINO detected: $OPENVINO_VERSION${NC}"
        echo -e "${GREEN}✅ All environment variables set${NC}"
    else
        echo -e "${YELLOW}⚠ OpenVINO environment variables not set (may need new terminal)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not source .bashrc in current shell${NC}"
    echo "  This is normal - open a new terminal to activate"
fi

echo ""
echo -e "${BLUE}5. Next Steps${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To activate OpenVINO in the current terminal:"
echo -e "  ${YELLOW}source ~/.bashrc${NC}"
echo ""
echo "Or open a new terminal (recommended)"
echo ""
echo "Test aliases:"
echo -e "  ${YELLOW}ov-info${NC}       # Show OpenVINO info"
echo -e "  ${YELLOW}ov-test${NC}       # Run quick test"
echo -e "  ${YELLOW}ov-bench${NC}      # Run benchmarks"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Setup Complete - OpenVINO will load in every terminal   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
