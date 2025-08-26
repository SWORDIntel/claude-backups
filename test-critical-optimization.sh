#!/bin/bash
# Test Critical Optimization - Safe Demo of Embedded Content Extraction

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

INSTALLER_PATH="/home/ubuntu/Documents/claude-backups/claude-installer.sh"

echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}                          CRITICAL OPTIMIZATION DEMONSTRATION                           ${NC}"
echo -e "${CYAN}${BOLD}                         (SAFE DEMO - NO ACTUAL CHANGES)                               ${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo

echo -e "${YELLOW}${BOLD}Demonstrating the largest optimization opportunity...${NC}\n"

# Find the embedded content
echo -e "${BLUE}${BOLD}1. Locating embedded CLAUDE.md content${NC}"
CLAUDE_MD_START=$(grep -n "local claude_md_content=" "$INSTALLER_PATH" | cut -d: -f1)
NEXT_FUNCTION=$(awk -v start="$CLAUDE_MD_START" 'NR > start && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/ {print NR; exit}' "$INSTALLER_PATH")

if [[ -z "$NEXT_FUNCTION" ]]; then
    NEXT_FUNCTION=$(wc -l < "$INSTALLER_PATH")
fi

CONTENT_SIZE=$((NEXT_FUNCTION - CLAUDE_MD_START))
echo -e "   ${GREEN}✓${NC} Found embedded content at line $CLAUDE_MD_START"
echo -e "   ${GREEN}✓${NC} Content spans $CONTENT_SIZE lines"
echo

# Show the function structure
echo -e "${BLUE}${BOLD}2. Function structure analysis${NC}"
echo -e "   Function: install_global_claude_md()"
echo -e "   Start line: $CLAUDE_MD_START"
echo -e "   End line: $NEXT_FUNCTION"
echo -e "   Total size: $CONTENT_SIZE lines"
echo

# Show what would be extracted
echo -e "${BLUE}${BOLD}3. Content extraction preview${NC}"
echo -e "   ${DIM}Would extract embedded CLAUDE.md content to:${NC} ${CYAN}claude-md-content.txt${NC}"
echo -e "   ${DIM}Would replace ${CONTENT_SIZE}-line inline content with file read operation${NC}"
echo

# Show the optimization impact
TOTAL_LINES=$(wc -l < "$INSTALLER_PATH")
REDUCTION_PERCENT=$((CONTENT_SIZE * 100 / TOTAL_LINES))
NEW_SIZE=$((TOTAL_LINES - CONTENT_SIZE + 10))  # +10 for replacement code

echo -e "${BLUE}${BOLD}4. Optimization impact calculation${NC}"
echo -e "   Current file size: $TOTAL_LINES lines"
echo -e "   Content to extract: $CONTENT_SIZE lines"
echo -e "   Replacement code: ~10 lines (file read operation)"
echo -e "   Net reduction: $((CONTENT_SIZE - 10)) lines"
echo -e "   New file size: $NEW_SIZE lines"
echo -e "   Percentage reduction: ${BOLD}$REDUCTION_PERCENT%${NC}"
echo

# Show the replacement code that would be used
echo -e "${BLUE}${BOLD}5. Replacement code preview${NC}"
echo -e "${DIM}The large embedded content would be replaced with:${NC}"
echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}│${NC} local claude_md_content"
echo -e "${GREEN}│${NC} if [[ -f \"claude-md-content.txt\" ]]; then"
echo -e "${GREEN}│${NC}     claude_md_content=\$(cat \"claude-md-content.txt\")"
echo -e "${GREEN}│${NC} else"
echo -e "${GREEN}│${NC}     claude_md_content=\"# CLAUDE.md content file not found\""
echo -e "${GREEN}│${NC} fi"
echo -e "${GREEN}└─────────────────────────────────────────────────────────────────────────${NC}"
echo

# Show the benefits
echo -e "${BLUE}${BOLD}6. Optimization benefits${NC}"
echo -e "   ${GREEN}✓${NC} ${BOLD}Memory Usage:${NC} $REDUCTION_PERCENT% reduction in script memory footprint"
echo -e "   ${GREEN}✓${NC} ${BOLD}Loading Speed:${NC} Faster script parsing and execution startup"
echo -e "   ${GREEN}✓${NC} ${BOLD}Maintainability:${NC} External content can be version controlled separately"
echo -e "   ${GREEN}✓${NC} ${BOLD}Modularity:${NC} Content updates don't require installer changes"
echo -e "   ${GREEN}✓${NC} ${BOLD}Version Control:${NC} Smaller diffs and better change tracking"
echo

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}DEMO COMPLETE - This would be the single most impactful optimization!${NC}"
echo
echo -e "${DIM}To apply this optimization safely:${NC}"
echo -e "1. Run: ${CYAN}./tui-installer-optimizer.sh${NC}"
echo -e "2. Select option 8 (create backup)"
echo -e "3. Select option 1 (CRITICAL optimization)"
echo -e "4. Verify the installer still works"
echo
echo -e "${DIM}This single change reduces the installer by ${BOLD}$REDUCTION_PERCENT%${NC}${DIM} with minimal risk.${NC}"