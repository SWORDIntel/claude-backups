#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CREATE CLAUDE HOOKS CONFIG.JSON
# 
# Simple script to create the config.json file in the correct location
# Usage: ./create_claude_config.sh
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration
CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
CONFIG_FILE="$CLAUDE_HOOKS_DIR/config.json"

echo -e "${GREEN}Creating Claude hooks configuration...${NC}"

# Create directory if it doesn't exist
if [ ! -d "$CLAUDE_HOOKS_DIR" ]; then
    echo "Creating directory: $CLAUDE_HOOKS_DIR"
    mkdir -p "$CLAUDE_HOOKS_DIR"
fi

# Create the config.json file
cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "1.0.0",
  "hooks": {
    "pre-task": {
      "enabled": true,
      "scripts": [
        {
          "name": "Validation & Setup",
          "path": "~/.claude/hooks/pre-task/validate_and_setup.sh",
          "timeout": 10,
          "required": true,
          "on_failure": "abort"
        }
      ]
    },
    "post-edit": {
      "enabled": true,
      "scripts": [
        {
          "name": "Process Changes",
          "path": "~/.claude/hooks/post-edit/process_changes.sh",
          "timeout": 30,
          "required": false,
          "on_failure": "continue"
        }
      ]
    },
    "post-task": {
      "enabled": true,
      "scripts": [
        {
          "name": "Cleanup & Report",
          "path": "~/.claude/hooks/post-task/cleanup_and_report.sh",
          "timeout": 15,
          "required": false,
          "on_failure": "log"
        }
      ]
    }
  },
  "global": {
    "log_file": "~/.claude/hooks/hooks.log",
    "debug": true,
    "parallel_execution": false
  }
}
EOF

echo -e "${GREEN}✅ Config created successfully at: $CONFIG_FILE${NC}"
echo
echo "You can verify it with:"
echo "  cat $CONFIG_FILE | jq ."