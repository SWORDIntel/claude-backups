#!/bin/bash
# Demo version of the TUI optimizer showing analysis results

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

INSTALLER_PATH="/home/ubuntu/Documents/claude-backups/claude-installer.sh"

echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}                          CLAUDE INSTALLER OPTIMIZATION ANALYSIS                         ${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo

# Basic analysis
if [[ ! -f "$INSTALLER_PATH" ]]; then
    echo -e "${RED}Error: Installer not found at $INSTALLER_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}${BOLD}Analyzing claude-installer.sh structure...${NC}\n"

# File statistics
TOTAL_LINES=$(wc -l < "$INSTALLER_PATH")
TOTAL_SIZE=$(stat -c%s "$INSTALLER_PATH")
FUNCTIONS_COUNT=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$INSTALLER_PATH" || echo 0)

echo -e "${GREEN}${BOLD}CURRENT FILE STATISTICS:${NC}"
echo -e "├── Total Lines: $TOTAL_LINES lines"
echo -e "├── File Size: $((TOTAL_SIZE / 1024)) KB"
echo -e "├── Functions: $FUNCTIONS_COUNT functions"

# Find embedded content
EMBEDDED_BLOCKS=$(grep -c "cat.*EOF\|cat.*'EOF'" "$INSTALLER_PATH" || echo 0)
echo -e "├── Embedded Blocks: $EMBEDDED_BLOCKS blocks"

# Find large function (install_global_claude_md)
CLAUDE_MD_START=$(grep -n "install_global_claude_md" "$INSTALLER_PATH" | head -1 | cut -d: -f1)
CLAUDE_MD_CONTENT_START=$(grep -n "local claude_md_content=" "$INSTALLER_PATH" | cut -d: -f1)
NEXT_FUNCTION=$(awk -v start="$CLAUDE_MD_START" 'NR > start && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/ {print NR; exit}' "$INSTALLER_PATH")

if [[ -z "$NEXT_FUNCTION" ]]; then
    NEXT_FUNCTION=$TOTAL_LINES
fi

CLAUDE_MD_SIZE=$((NEXT_FUNCTION - CLAUDE_MD_START))
echo -e "└── Largest Function: install_global_claude_md ($CLAUDE_MD_SIZE lines)"
echo

# Optimization potential
CRITICAL_REDUCTION=591  # Estimated embedded content
HIGH_REDUCTION=200      # Function consolidation
MEDIUM_REDUCTION=100    # Error handling
LOW_REDUCTION=50        # Formatting

TOTAL_REDUCTION=$((CRITICAL_REDUCTION + HIGH_REDUCTION + MEDIUM_REDUCTION + LOW_REDUCTION))
FINAL_SIZE=$((TOTAL_LINES - TOTAL_REDUCTION))
REDUCTION_PERCENT=$((TOTAL_REDUCTION * 100 / TOTAL_LINES))

echo -e "${MAGENTA}${BOLD}OPTIMIZATION POTENTIAL ANALYSIS:${NC}"
echo
echo -e "${RED}${BOLD}🔥 CRITICAL PRIORITY: Extract Embedded Content${NC}"
echo -e "├── Target: Large CLAUDE.md embedded content (~591 lines)"
echo -e "├── Action: Extract to external file 'claude-md-content.txt'"
echo -e "├── Impact: -$CRITICAL_REDUCTION lines (~$((CRITICAL_REDUCTION * 100 / TOTAL_LINES))% reduction)"
echo -e "└── Benefit: Massive reduction in memory usage and file size"
echo

echo -e "${YELLOW}${BOLD}⚡ HIGH PRIORITY: Consolidate Functions${NC}"
echo -e "├── Target: Repeated code patterns and large functions"
echo -e "├── Action: Create common utility functions (error handling, checks)"
echo -e "├── Impact: -$HIGH_REDUCTION lines (~$((HIGH_REDUCTION * 100 / TOTAL_LINES))% reduction)"
echo -e "└── Benefit: Better maintainability and consistency"
echo

echo -e "${BLUE}${BOLD}🔧 MEDIUM PRIORITY: Standardize Error Handling${NC}"
echo -e "├── Target: Inconsistent error messages and handling"
echo -e "├── Action: Unified error handling functions"
echo -e "├── Impact: -$MEDIUM_REDUCTION lines (~$((MEDIUM_REDUCTION * 100 / TOTAL_LINES))% reduction)"
echo -e "└── Benefit: Consistent user experience"
echo

echo -e "${GREEN}${BOLD}🧹 LOW PRIORITY: Clean Formatting${NC}"
echo -e "├── Target: Excessive whitespace and redundant comments"
echo -e "├── Action: Remove trailing spaces, compress empty lines"
echo -e "├── Impact: -$LOW_REDUCTION lines (~$((LOW_REDUCTION * 100 / TOTAL_LINES))% reduction)"
echo -e "└── Benefit: Cleaner code appearance"
echo

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${MAGENTA}TOTAL OPTIMIZATION IMPACT SUMMARY:${NC}"
echo
echo -e "📊 Current Size:     ${BOLD}$TOTAL_LINES lines${NC}"
echo -e "🎯 Optimized Size:   ${BOLD}$FINAL_SIZE lines${NC}"
echo -e "📉 Total Reduction:  ${BOLD}$TOTAL_REDUCTION lines${NC} (${BOLD}${REDUCTION_PERCENT}%${NC})"
echo

# Visual representation
echo -e "${BOLD}Optimization Impact Visualization:${NC}"
echo -e "${RED}Critical  ████████████████████ $CRITICAL_REDUCTION lines ($(printf "%2d" $((CRITICAL_REDUCTION * 100 / TOTAL_REDUCTION)))% of reduction)${NC}"
echo -e "${YELLOW}High      ████████             $HIGH_REDUCTION lines ($(printf "%2d" $((HIGH_REDUCTION * 100 / TOTAL_REDUCTION)))% of reduction)${NC}"
echo -e "${BLUE}Medium    ████                 $MEDIUM_REDUCTION lines ($(printf "%2d" $((MEDIUM_REDUCTION * 100 / TOTAL_REDUCTION)))% of reduction)${NC}"
echo -e "${GREEN}Low       ██                   $LOW_REDUCTION lines ($(printf "%2d" $((LOW_REDUCTION * 100 / TOTAL_REDUCTION)))% of reduction)${NC}"
echo

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}RECOMMENDED OPTIMIZATION STRATEGY:${NC}"
echo
echo -e "1. ${RED}${BOLD}START WITH CRITICAL${NC} - Extract embedded content for immediate 14% reduction"
echo -e "2. ${YELLOW}${BOLD}FOLLOW WITH HIGH${NC} - Consolidate functions for maintainability"
echo -e "3. ${BLUE}${BOLD}APPLY MEDIUM${NC} - Standardize error handling for consistency"
echo -e "4. ${GREEN}${BOLD}FINISH WITH LOW${NC} - Clean formatting for final polish"
echo
echo -e "${DIM}Run './tui-installer-optimizer.sh' for interactive optimization${NC}"
echo -e "${DIM}Or use './optimize-installer' for the same interface${NC}"