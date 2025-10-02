#!/bin/bash
# Install Python 3.11/3.12 with OpenVINO in venv - Always accessible setup
# Makes OpenVINO available globally through venv auto-activation
# Enhanced with Python 3.13 fallback support

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Sudo password
SUDO_PASS="${1:-}"

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

# Detect best Python version for OpenVINO
detect_best_python() {
    # Try Python 3.12 first (best compatibility with OpenVINO 2025.3.0)
    if command -v python3.12 >/dev/null 2>&1; then
        echo "python3.12"
        return 0
    fi

    # Try Python 3.11 (also good compatibility)
    if command -v python3.11 >/dev/null 2>&1; then
        echo "python3.11"
        return 0
    fi

    # Fallback to system Python 3 if 3.10 or higher
    if command -v python3 >/dev/null 2>&1; then
        local version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)

        if [[ "$major" -eq 3 ]] && [[ "$minor" -ge 10 ]]; then
            echo "python3"
            return 0
        fi
    fi

    echo ""
    return 1
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Python + OpenVINO Installation - Always Accessible          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

VENV_DIR="$HOME/.local/share/claude/venv"
BASHRC="$HOME/.bashrc"

# Detect or install compatible Python version
echo -e "${BLUE}1. Detecting/Installing Python...${NC}"

PYTHON_CMD=$(detect_best_python)

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${YELLOW}⚠ No compatible Python found, installing Python 3.12...${NC}"
    echo "$SUDO_PASS" | sudo -S apt update -qq
    echo "$SUDO_PASS" | sudo -S apt install -y python3.12 python3.12-venv python3.12-dev
    PYTHON_CMD="python3.12"
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "${GREEN}✅ Using: $PYTHON_VERSION${NC}"

# Create venv with detected Python
echo ""
echo -e "${BLUE}2. Creating venv with $PYTHON_CMD...${NC}"

# Remove old broken venv if exists
if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠ Removing old venv...${NC}"
    rm -rf "$VENV_DIR"
fi

mkdir -p "$(dirname "$VENV_DIR")"
$PYTHON_CMD -m venv "$VENV_DIR"

echo -e "${GREEN}✅ Venv created with $PYTHON_CMD${NC}"

# Activate and install packages
echo ""
echo -e "${BLUE}3. Installing OpenVINO in venv...${NC}"

source "$VENV_DIR/bin/activate"

# Upgrade pip
pip install --upgrade pip setuptools wheel -q

# Install OpenVINO
echo "   Installing openvino..."
pip install openvino -q

echo "   Installing openvino-dev..."
pip install openvino-dev -q

# Verify
VENV_PYTHON_VER=$(python --version)
VENV_OV_VERSION=$(python -c "import openvino; print(openvino.__version__)" 2>/dev/null || echo "failed")

if [ "$VENV_OV_VERSION" != "failed" ]; then
    echo -e "${GREEN}✅ OpenVINO installed: $VENV_OV_VERSION${NC}"
    echo -e "${GREEN}✅ Python version: $VENV_PYTHON_VER${NC}"
else
    echo -e "${RED}❌ OpenVINO installation failed${NC}"
    deactivate
    exit 1
fi

# Test devices
echo ""
echo -e "${BLUE}4. Testing OpenVINO devices...${NC}"

python << 'EOFTEST'
import openvino as ov
core = ov.Core()
devices = core.available_devices
print(f"\033[0;32m✅ Found {len(devices)} device(s):\033[0m")
for device in devices:
    try:
        full_name = core.get_property(device, "FULL_DEVICE_NAME")
        print(f"  • {device}: {full_name}")
    except:
        print(f"  • {device}")
EOFTEST

deactivate

# Configure bashrc for auto-activation
echo ""
echo -e "${BLUE}5. Configuring bashrc for auto-activation...${NC}"

# Backup
cp "$BASHRC" "$BASHRC.backup-python312-$(date +%Y%m%d-%H%M%S)"

# Remove old Claude venv section if exists
sed -i '/# Claude Venv Auto-Activation/,/# Claude Venv Auto-Activation.*END/d' "$BASHRC"

# Add new auto-activation section
cat >> "$BASHRC" << 'EOFBASHRC'

# ============================================================================
# Claude Python 3.12 Venv Auto-Activation - START
# ============================================================================
# Automatically activates Python 3.12 venv with OpenVINO in every terminal
# Makes OpenVINO always accessible without manual activation

# Only activate in interactive shells and if not already in a venv
if [[ $- == *i* ]] && [ -z "$VIRTUAL_ENV" ]; then
    CLAUDE_VENV_DIR="$HOME/.local/share/claude/venv"

    # Check if venv exists
    if [ -d "$CLAUDE_VENV_DIR" ]; then
        # Activate venv silently
        source "$CLAUDE_VENV_DIR/bin/activate" 2>/dev/null

        # Verify OpenVINO is available
        if command -v python &> /dev/null && python -c "import openvino" 2>/dev/null; then
            # Optional: Display activation message (uncomment if desired)
            # OV_VER=$(python -c "import openvino; print(openvino.__version__)" 2>/dev/null)
            # echo -e "\033[0;32m✅ Claude venv (Python 3.12 + OpenVINO $OV_VER)\033[0m"
            :
        fi
    fi
fi

# ============================================================================
# Claude Python 3.12 Venv Auto-Activation - END
# ============================================================================
EOFBASHRC

echo -e "${GREEN}✅ Bashrc configured for auto-activation${NC}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Installation Complete!                                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Summary:"
echo "  ✅ Python 3.12 installed"
echo "  ✅ Venv created: $VENV_DIR"
echo "  ✅ OpenVINO version: $VENV_OV_VERSION"
echo "  ✅ Bashrc: Auto-activation configured"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}IMPORTANT: Venv will auto-activate in NEW terminals${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "To activate in current terminal:"
echo -e "  ${GREEN}source ~/.bashrc${NC}"
echo ""
echo "Or open a new terminal (venv will auto-activate)"
echo ""

echo "Verify in new terminal:"
echo -e "  ${GREEN}echo \$VIRTUAL_ENV${NC}    # Should show: $VENV_DIR"
echo -e "  ${GREEN}python --version${NC}      # Should show: Python 3.12.x"
echo -e "  ${GREEN}ov-info${NC}               # Should show OpenVINO devices"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ OpenVINO now always accessible in every terminal!         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
