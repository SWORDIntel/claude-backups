#!/bin/bash
# Install Enhanced Claude Wrapper with Auto Permission Bypass
set -euo pipefail

echo "🚀 Installing Enhanced Claude Wrapper with Auto Permission Bypass..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Backup existing claude
if [[ -f "/usr/local/bin/claude" ]]; then
    echo -e "${YELLOW}📦 Backing up existing claude to claude-original...${NC}"
    cp /usr/local/bin/claude /usr/local/bin/claude-original 2>/dev/null || true
fi

# Install enhanced wrapper
echo -e "${CYAN}📥 Installing enhanced wrapper...${NC}"
cp /home/john/claude-backups/scripts/claude-unified /usr/local/bin/claude-enhanced
chmod +x /usr/local/bin/claude-enhanced

# Update binary path in the wrapper to point to original Claude
if [[ -f "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js" ]]; then
    CLAUDE_PATH="/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
elif [[ -f "/usr/local/bin/claude-original" ]]; then
    CLAUDE_PATH="/usr/local/bin/claude-original"
else
    echo -e "${YELLOW}⚠️  Original Claude binary not found. You may need to manually set CLAUDE_BINARY.${NC}"
    CLAUDE_PATH="claude"
fi

# Update the placeholder in the wrapper
sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_PATH|g" /usr/local/bin/claude-enhanced

# Create symlink to replace claude
echo -e "${CYAN}🔗 Creating symlink...${NC}"
rm -f /usr/local/bin/claude
ln -sf claude-enhanced /usr/local/bin/claude

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
echo "To restore original: ln -sf claude-original /usr/local/bin/claude"