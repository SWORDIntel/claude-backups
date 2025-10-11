#!/bin/bash
# Setup Claude venv with auto-activation in new terminals
# This makes OpenVINO and Python packages available automatically
# Enhanced with multi-Python version support

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect best Python version
detect_best_python() {
    # Try Python 3.12 first
    if command -v python3.12 >/dev/null 2>&1; then
        echo "python3.12"
        return 0
    fi

    # Try Python 3.11
    if command -v python3.11 >/dev/null 2>&1; then
        echo "python3.11"
        return 0
    fi

    # Fallback to system python3 if 3.10+
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
echo -e "${BLUE}║   Claude Venv Auto-Load Setup                                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

VENV_DIR="$HOME/.local/share/claude/venv"
BASHRC="$HOME/.bashrc"

# Check if venv exists
if [ -d "$VENV_DIR" ]; then
    echo -e "${GREEN}✅ Claude venv already exists: $VENV_DIR${NC}"
else
    echo -e "${BLUE}Creating Claude venv with best Python version...${NC}"

    PYTHON_CMD=$(detect_best_python)

    if [ -z "$PYTHON_CMD" ]; then
        echo -e "${YELLOW}⚠ No compatible Python found (need 3.10+)${NC}"
        echo "Install Python 3.12 with: sudo apt install python3.12 python3.12-venv"
        exit 1
    fi

    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
    echo -e "${BLUE}Using: $PYTHON_VERSION${NC}"

    mkdir -p "$(dirname "$VENV_DIR")"
    $PYTHON_CMD -m venv "$VENV_DIR"
    echo -e "${GREEN}✅ Venv created with $PYTHON_CMD${NC}"
fi

# Activate and install OpenVINO
echo ""
echo -e "${BLUE}Installing OpenVINO in venv...${NC}"

source "$VENV_DIR/bin/activate"

# Install OpenVINO
pip install --upgrade pip -q
pip install openvino openvino-dev -q

echo -e "${GREEN}✅ OpenVINO installed in venv${NC}"

# Verify
VENV_OV_VERSION=$(python -c "import openvino; print(openvino.__version__)" 2>/dev/null || echo "failed")
if [ "$VENV_OV_VERSION" != "failed" ]; then
    echo -e "${GREEN}✅ OpenVINO version in venv: $VENV_OV_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ OpenVINO verification failed${NC}"
fi

deactivate

# Add auto-activation to bashrc
echo ""
echo -e "${BLUE}Configuring bashrc auto-activation...${NC}"

# Backup bashrc
cp "$BASHRC" "$BASHRC.backup-venv-$(date +%Y%m%d-%H%M%S)"

# Check if already configured
if grep -q "Claude Venv Auto-Activation" "$BASHRC"; then
    echo -e "${YELLOW}⚠ Bashrc already configured for venv auto-activation${NC}"
    echo ""
    read -p "Remove and reconfigure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old section
        sed -i '/# Claude Venv Auto-Activation - START/,/# Claude Venv Auto-Activation - END/d' "$BASHRC"
        echo -e "${GREEN}✅ Removed old configuration${NC}"
    else
        echo "Keeping existing configuration"
        exit 0
    fi
fi

# Add auto-activation section
cat >> "$BASHRC" << 'EOFBASHRC'

# ============================================================================
# Claude Venv Auto-Activation - START
# ============================================================================
# Automatically activates Claude Python venv in every terminal
# Provides OpenVINO and all Python packages globally
# Compatible with Python 3.10, 3.11, 3.12, 3.13

# Only activate in interactive shells
if [[ $- == *i* ]]; then
    CLAUDE_VENV_DIR="$HOME/.local/share/claude/venv"

    # Check if venv exists and not already activated
    if [ -d "$CLAUDE_VENV_DIR" ] && [ -z "$VIRTUAL_ENV" ]; then
        # Activate venv silently
        source "$CLAUDE_VENV_DIR/bin/activate" 2>/dev/null

        # Optional: Display activation message (uncomment if desired)
        # if command -v python &> /dev/null; then
        #     PYTHON_VER=$(python --version 2>&1)
        #     if python -c "import openvino" 2>/dev/null; then
        #         OV_VER=$(python -c "import openvino; print(openvino.__version__)" 2>/dev/null)
        #         echo -e "\033[0;32m✅ Claude venv ($PYTHON_VER + OpenVINO $OV_VER)\033[0m"
        #     else
        #         echo -e "\033[0;32m✅ Claude venv ($PYTHON_VER)\033[0m"
        #     fi
        # fi
    fi
fi

# ============================================================================
# Claude Venv Auto-Activation - END
# ============================================================================
EOFBASHRC

echo -e "${GREEN}✅ Bashrc configured for auto-activation${NC}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Setup Complete!                                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Summary:"
echo "  Venv location: $VENV_DIR"
echo "  OpenVINO version: $VENV_OV_VERSION"
echo "  Bashrc: Auto-activation configured"
echo ""

echo -e "${YELLOW}IMPORTANT: The venv will auto-activate in NEW terminals${NC}"
echo ""
echo "To activate in current terminal:"
echo -e "  ${YELLOW}source ~/.bashrc${NC}"
echo ""
echo "Or open a new terminal to test auto-activation"
echo ""

echo "Verify in new terminal:"
echo "  echo \$VIRTUAL_ENV    # Should show venv path"
echo "  python -c 'import openvino; print(openvino.__version__)'"
echo ""
