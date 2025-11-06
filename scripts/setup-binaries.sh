#!/bin/bash
# Setup Script - Make compiled binaries easily accessible
# Adds symlinks to ~/.local/bin for quick access

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$HOME/.local/bin"

echo -e "${CYAN}Setting up compiled binaries...${NC}"
echo ""

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Crypto-POW binary
CRYPTO_POW_BIN="$PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/target/release/crypto-pow"
if [ -f "$CRYPTO_POW_BIN" ]; then
    ln -sf "$CRYPTO_POW_BIN" "$BIN_DIR/crypto-pow"
    echo -e "${GREEN}✓${NC} Linked crypto-pow to $BIN_DIR/crypto-pow"
else
    echo -e "${YELLOW}⚠${NC} Crypto-POW not compiled yet (run: cd hooks/crypto-pow/crypto-pow-enhanced && cargo build --release)"
fi

# Shadowgit binary
SHADOWGIT_BIN="$PROJECT_ROOT/hooks/shadowgit/shadowgit_phase3_test"
if [ -f "$SHADOWGIT_BIN" ]; then
    ln -sf "$SHADOWGIT_BIN" "$BIN_DIR/shadowgit"
    echo -e "${GREEN}✓${NC} Linked shadowgit to $BIN_DIR/shadowgit"
else
    echo -e "${YELLOW}⚠${NC} Shadowgit not compiled yet (run: cd hooks/shadowgit && make)"
fi

# Shadowgit shared library
SHADOWGIT_LIB="$PROJECT_ROOT/hooks/shadowgit/shadowgit_phase3_integration.so"
if [ -f "$SHADOWGIT_LIB" ]; then
    echo -e "${GREEN}✓${NC} Shadowgit shared library available: shadowgit_phase3_integration.so"
else
    echo -e "${YELLOW}⚠${NC} Shadowgit shared library not compiled yet"
fi

echo ""
echo -e "${CYAN}Available commands:${NC}"
echo "  crypto-pow --help     # Cryptographic POW operations"
echo "  crypto-pow info       # Show hardware capabilities"
echo "  crypto-pow solve      # Solve POW challenge"
echo "  shadowgit [N]         # Run shadowgit test with N tasks"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
