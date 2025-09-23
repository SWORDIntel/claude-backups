#!/bin/bash
# Install Enhanced Claude Wrapper with Auto Permission Bypass
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE PORTABLE PATH INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

# Dynamic path detection
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"

# Detect project root
if [[ -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
    PROJECT_ROOT="$SCRIPT_DIR"
elif [[ -f "$(dirname "$SCRIPT_DIR")/CLAUDE.md" ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
elif [[ -n "${CLAUDE_PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$CLAUDE_PROJECT_ROOT"
else
    # Search common locations
    for candidate in "$HOME"/claude-* "$HOME"/Downloads/claude-* "$HOME"/Documents/claude-* "$HOME"/Documents/Claude "$PWD"; do
        if [[ -f "$candidate/CLAUDE.md" ]]; then
            PROJECT_ROOT="$candidate"
            break
        fi
    done
    PROJECT_ROOT="${PROJECT_ROOT:-$HOME}"
fi

# XDG-compliant paths
export CLAUDE_USER_BIN="${XDG_DATA_HOME:-$HOME/.local}/bin"
export CLAUDE_SYSTEM_BIN="${CLAUDE_SYSTEM_BIN:-/usr/local/bin}"

# Create user bin directory if needed
mkdir -p "$CLAUDE_USER_BIN" 2>/dev/null || true

echo "🚀 Installing Enhanced Claude Wrapper with Auto Permission Bypass..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detect installation target (prefer user bin, fallback to system)
INSTALL_TARGET=""
if [[ -w "$CLAUDE_USER_BIN" ]]; then
    INSTALL_TARGET="$CLAUDE_USER_BIN"
    echo -e "${CYAN}📍 Installing to user bin: $CLAUDE_USER_BIN${NC}"
elif [[ -w "$CLAUDE_SYSTEM_BIN" ]]; then
    INSTALL_TARGET="$CLAUDE_SYSTEM_BIN"
    echo -e "${CYAN}📍 Installing to system bin: $CLAUDE_SYSTEM_BIN${NC}"
else
    echo -e "${YELLOW}⚠️  Neither user nor system bin directories are writable${NC}"
    echo -e "${YELLOW}   Trying with sudo for system installation...${NC}"
    INSTALL_TARGET="$CLAUDE_SYSTEM_BIN"
    SUDO_PREFIX="sudo"
fi

# Backup existing claude
if [[ -f "$INSTALL_TARGET/claude" ]]; then
    echo -e "${YELLOW}📦 Backing up existing claude to claude-original...${NC}"
    ${SUDO_PREFIX:-} cp "$INSTALL_TARGET/claude" "$INSTALL_TARGET/claude-original" 2>/dev/null || true
fi

# Install enhanced wrapper
echo -e "${CYAN}📥 Installing enhanced wrapper...${NC}"
if [[ -f "$PROJECT_ROOT/scripts/claude-unified" ]]; then
    WRAPPER_SOURCE="$PROJECT_ROOT/scripts/claude-unified"
elif [[ -f "$PROJECT_ROOT/claude-unified" ]]; then
    WRAPPER_SOURCE="$PROJECT_ROOT/claude-unified"
else
    echo -e "${YELLOW}⚠️  Enhanced wrapper not found in project${NC}"
    exit 1
fi

${SUDO_PREFIX:-} cp "$WRAPPER_SOURCE" "$INSTALL_TARGET/claude-enhanced"
${SUDO_PREFIX:-} chmod +x "$INSTALL_TARGET/claude-enhanced"

# Update binary path in the wrapper to point to original Claude
CLAUDE_PATHS=(
    "${CLAUDE_SYSTEM_BIN}/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    "$INSTALL_TARGET/claude-original"
    "${CLAUDE_USER_BIN}/claude-original"
    "${CLAUDE_SYSTEM_BIN}/claude-original"
)

CLAUDE_PATH=""
for path in "${CLAUDE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        CLAUDE_PATH="$path"
        break
    fi
done

if [[ -z "$CLAUDE_PATH" ]]; then
    echo -e "${YELLOW}⚠️  Original Claude binary not found. Using system claude command.${NC}"
    CLAUDE_PATH="claude"
fi

# Update the placeholder in the wrapper if it exists
if grep -q "BINARY_PLACEHOLDER" "$INSTALL_TARGET/claude-enhanced" 2>/dev/null; then
    ${SUDO_PREFIX:-} sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_PATH|g" "$INSTALL_TARGET/claude-enhanced"
fi

# Create symlink to replace claude
echo -e "${CYAN}🔗 Creating symlink...${NC}"
${SUDO_PREFIX:-} rm -f "$INSTALL_TARGET/claude"
${SUDO_PREFIX:-} ln -sf claude-enhanced "$INSTALL_TARGET/claude"

echo -e "${GREEN}✅ Enhanced Claude Wrapper installed successfully!${NC}"
echo
echo "Features enabled:"
echo "  🔓 Auto permission bypass for SSH, Docker, headless environments"
echo "  🧠 Smart task analysis with orchestration suggestions"
echo "  📊 Performance metrics and learning"
echo "  🚀 Quick access shortcuts"
echo
echo "Test with: claude /task \"test\""
echo "Check status: claude --status"
echo
echo "To disable permission bypass: export CLAUDE_PERMISSION_BYPASS=false"
echo "To restore original: ln -sf claude-original $INSTALL_TARGET/claude"