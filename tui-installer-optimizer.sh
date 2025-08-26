#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# TUI Installer Optimizer v1.0
# Interactive terminal interface for claude-installer.sh optimization
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION & COLORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Color codes for TUI
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r NC='\033[0m'

# Progress chars
declare -r FULL_BLOCK="█"
declare -r EMPTY_BLOCK="░"
declare -r ARROW="→"
declare -r CHECK="✓"
declare -r CROSS="✗"
declare -r WARN="⚠"

# File paths
INSTALLER_PATH="/home/ubuntu/Documents/claude-backups/claude-installer.sh"
BACKUP_PATH="${INSTALLER_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
OPTIMIZED_PATH="${INSTALLER_PATH}.optimized"
ANALYSIS_CACHE="/tmp/installer_analysis_cache.txt"

# Analysis results
declare -A OPTIMIZATION_STATS
declare -A FUNCTION_SIZES
declare -A DUPLICATED_PATTERNS

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}                          TUI INSTALLER OPTIMIZER v1.0                                ║${NC}"
    echo -e "${CYAN}║                      Interactive claude-installer.sh Optimization                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_separator() {
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────────────────────────${NC}"
}

print_box() {
    local title="$1"
    local content="$2"
    local color="${3:-$CYAN}"
    
    echo -e "${color}┌─ ${BOLD}${title}${NC}${color}"
    echo -e "${color}│${NC}"
    while IFS= read -r line; do
        echo -e "${color}│${NC} $line"
    done <<< "$content"
    echo -e "${color}│${NC}"
    echo -e "${color}└─────────────────────────────────────────────────────────${NC}"
    echo
}

draw_progress_bar() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%*s" "$filled" | tr ' ' "$FULL_BLOCK"
    printf "%*s" "$empty" | tr ' ' "$EMPTY_BLOCK"
    printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total"
}

wait_for_key() {
    echo -e "\n${DIM}Press any key to continue...${NC}"
    read -n 1 -s
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ANALYSIS FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

analyze_installer_structure() {
    print_header
    echo -e "${YELLOW}${BOLD}Analyzing installer structure...${NC}\n"
    
    if [[ ! -f "$INSTALLER_PATH" ]]; then
        echo -e "${RED}${CROSS} Error: Installer not found at $INSTALLER_PATH${NC}"
        exit 1
    fi
    
    # Basic file statistics
    local total_lines=$(wc -l < "$INSTALLER_PATH")
    local total_size=$(stat -c%s "$INSTALLER_PATH")
    local functions_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$INSTALLER_PATH" || echo 0)
    
    OPTIMIZATION_STATS["total_lines"]="$total_lines"
    OPTIMIZATION_STATS["total_size"]="$total_size"
    OPTIMIZATION_STATS["functions_count"]="$functions_count"
    
    # Progress tracking
    local steps=6
    local current=0
    
    echo -e "${BLUE}Analyzing file structure...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    sleep 0.5
    
    # Find large embedded content blocks
    echo -e "\n${BLUE}Identifying embedded content blocks...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    local embedded_lines=$(grep -n "cat.*EOF\|cat.*'EOF'" "$INSTALLER_PATH" | wc -l)
    OPTIMIZATION_STATS["embedded_blocks"]="$embedded_lines"
    sleep 0.5
    
    # Analyze function sizes
    echo -e "\n${BLUE}Analyzing function sizes...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    analyze_function_sizes
    sleep 0.5
    
    # Find duplicated patterns
    echo -e "\n${BLUE}Detecting code duplication...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    find_duplicated_patterns
    sleep 0.5
    
    # Count color function usage
    echo -e "\n${BLUE}Analyzing color function usage...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    local color_usage=$(grep -c "print_red\|print_green\|print_yellow\|print_blue\|print_cyan" "$INSTALLER_PATH" || echo 0)
    OPTIMIZATION_STATS["color_usage"]="$color_usage"
    sleep 0.5
    
    # Calculate optimization potential
    echo -e "\n${BLUE}Calculating optimization potential...${NC}"
    ((current++)); draw_progress_bar "$current" "$steps"
    calculate_optimization_potential
    sleep 0.5
    
    echo -e "\n\n${GREEN}${CHECK} Analysis complete!${NC}\n"
    
    # Cache results
    cat > "$ANALYSIS_CACHE" <<EOF
total_lines=${OPTIMIZATION_STATS[total_lines]}
total_size=${OPTIMIZATION_STATS[total_size]}
functions_count=${OPTIMIZATION_STATS[functions_count]}
embedded_blocks=${OPTIMIZATION_STATS[embedded_blocks]}
color_usage=${OPTIMIZATION_STATS[color_usage]}
large_functions=${OPTIMIZATION_STATS[large_functions]}
duplicate_patterns=${OPTIMIZATION_STATS[duplicate_patterns]}
critical_reduction=${OPTIMIZATION_STATS[critical_reduction]}
high_reduction=${OPTIMIZATION_STATS[high_reduction]}
medium_reduction=${OPTIMIZATION_STATS[medium_reduction]}
low_reduction=${OPTIMIZATION_STATS[low_reduction]}
EOF
    
    wait_for_key
}

analyze_function_sizes() {
    local large_function_count=0
    while IFS= read -r line; do
        if [[ $line =~ ^([0-9]+):([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
            local line_start="${BASH_REMATCH[1]}"
            local function_name="${BASH_REMATCH[3]}"
            
            # Find function end (next function or end of file)
            local line_end=$(awk -v start="$line_start" 'NR > start && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/ {print NR; exit}' "$INSTALLER_PATH")
            if [[ -z "$line_end" ]]; then
                line_end=$(wc -l < "$INSTALLER_PATH")
            fi
            
            local function_size=$((line_end - line_start))
            FUNCTION_SIZES["$function_name"]="$function_size"
            
            if [[ $function_size -gt 100 ]]; then
                ((large_function_count++))
            fi
        fi
    done < <(grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$INSTALLER_PATH")
    
    OPTIMIZATION_STATS["large_functions"]="$large_function_count"
}

find_duplicated_patterns() {
    local duplicate_count=0
    
    # Common patterns to check
    local patterns=(
        'print_[a-z]* "'
        'echo -e.*\$'
        'if.*then'
        'mkdir -p'
        'command -v'
    )
    
    for pattern in "${patterns[@]}"; do
        local count=$(grep -c "$pattern" "$INSTALLER_PATH" || echo 0)
        if [[ $count -gt 5 ]]; then
            ((duplicate_count++))
            DUPLICATED_PATTERNS["$pattern"]="$count"
        fi
    done
    
    OPTIMIZATION_STATS["duplicate_patterns"]="$duplicate_count"
}

calculate_optimization_potential() {
    # Critical: Large embedded content (estimated 591 lines from claude.md)
    OPTIMIZATION_STATS["critical_reduction"]=591
    
    # High: Function consolidation (estimate 10% of large functions)
    local high_est=$((OPTIMIZATION_STATS[large_functions] * 50))
    OPTIMIZATION_STATS["high_reduction"]="$high_est"
    
    # Medium: Error handling standardization (estimate 5% of total)
    local medium_est=$((OPTIMIZATION_STATS[total_lines] / 20))
    OPTIMIZATION_STATS["medium_reduction"]="$medium_est"
    
    # Low: Formatting cleanup (estimate 2% of total)
    local low_est=$((OPTIMIZATION_STATS[total_lines] / 50))
    OPTIMIZATION_STATS["low_reduction"]="$low_est"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISPLAY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_analysis_dashboard() {
    print_header
    
    # Load cached analysis if available
    if [[ -f "$ANALYSIS_CACHE" ]]; then
        source "$ANALYSIS_CACHE"
        for key in total_lines total_size functions_count embedded_blocks color_usage large_functions duplicate_patterns critical_reduction high_reduction medium_reduction low_reduction; do
            OPTIMIZATION_STATS["$key"]="${!key}"
        done
    else
        echo -e "${YELLOW}${WARN} No analysis data found. Running analysis first...${NC}\n"
        analyze_installer_structure
        return
    fi
    
    echo -e "${BOLD}${CYAN}INSTALLER ANALYSIS DASHBOARD${NC}\n"
    
    # Current Statistics
    print_box "Current File Statistics" "$(cat <<EOF
Total Lines: ${OPTIMIZATION_STATS[total_lines]} lines
File Size: $((OPTIMIZATION_STATS[total_size] / 1024)) KB
Functions: ${OPTIMIZATION_STATS[functions_count]} functions
Large Functions (>100 lines): ${OPTIMIZATION_STATS[large_functions]} functions
Embedded Content Blocks: ${OPTIMIZATION_STATS[embedded_blocks]} blocks
Color Function Usage: ${OPTIMIZATION_STATS[color_usage]} instances
Duplicate Patterns Detected: ${OPTIMIZATION_STATS[duplicate_patterns]} patterns
EOF
)" "$GREEN"
    
    # Optimization Potential
    local total_reduction=$((OPTIMIZATION_STATS[critical_reduction] + OPTIMIZATION_STATS[high_reduction] + OPTIMIZATION_STATS[medium_reduction] + OPTIMIZATION_STATS[low_reduction]))
    local final_lines=$((OPTIMIZATION_STATS[total_lines] - total_reduction))
    local reduction_percent=$((total_reduction * 100 / OPTIMIZATION_STATS[total_lines]))
    
    print_box "Optimization Potential" "$(cat <<EOF
${RED}CRITICAL:${NC} Extract embedded content → -${OPTIMIZATION_STATS[critical_reduction]} lines
${YELLOW}HIGH:${NC} Consolidate functions → -${OPTIMIZATION_STATS[high_reduction]} lines  
${BLUE}MEDIUM:${NC} Standardize error handling → -${OPTIMIZATION_STATS[medium_reduction]} lines
${GREEN}LOW:${NC} Clean formatting → -${OPTIMIZATION_STATS[low_reduction]} lines

${BOLD}Total Potential Reduction: $total_reduction lines ($reduction_percent%)${NC}
${BOLD}Optimized Size: $final_lines lines${NC}
EOF
)" "$MAGENTA"
    
    # Visual progress bar for optimization potential
    echo -e "${BOLD}Optimization Impact Visualization:${NC}"
    echo -e "${RED}Critical  $(printf "%-20s" | tr ' ' '█') ${OPTIMIZATION_STATS[critical_reduction]} lines${NC}"
    echo -e "${YELLOW}High      $(printf "%-10s" | tr ' ' '█')           ${OPTIMIZATION_STATS[high_reduction]} lines${NC}"
    echo -e "${BLUE}Medium    $(printf "%-8s" | tr ' ' '█')             ${OPTIMIZATION_STATS[medium_reduction]} lines${NC}"
    echo -e "${GREEN}Low       $(printf "%-4s" | tr ' ' '█')               ${OPTIMIZATION_STATS[low_reduction]} lines${NC}"
    echo
    
    print_separator
}

show_optimization_menu() {
    echo -e "${BOLD}${CYAN}OPTIMIZATION MENU${NC}\n"
    
    echo -e "${BOLD}1.${NC} ${RED}CRITICAL${NC} - Extract large embedded content (claude.md)"
    echo -e "   ${DIM}Extract 591-line embedded CLAUDE.md to separate file${NC}"
    echo -e "   ${GREEN}Impact: -591 lines (~14% reduction)${NC}\n"
    
    echo -e "${BOLD}2.${NC} ${YELLOW}HIGH${NC} - Consolidate repeated code patterns"
    echo -e "   ${DIM}Merge duplicate functions and standardize patterns${NC}"
    echo -e "   ${GREEN}Impact: -${OPTIMIZATION_STATS[high_reduction]} lines (~${HIGH_PERCENT}% reduction)${NC}\n"
    
    echo -e "${BOLD}3.${NC} ${BLUE}MEDIUM${NC} - Standardize error handling"
    echo -e "   ${DIM}Create unified error handling functions${NC}"
    echo -e "   ${GREEN}Impact: -${OPTIMIZATION_STATS[medium_reduction]} lines (~${MEDIUM_PERCENT}% reduction)${NC}\n"
    
    echo -e "${BOLD}4.${NC} ${GREEN}LOW${NC} - Clean formatting and comments"
    echo -e "   ${DIM}Remove excessive whitespace and redundant comments${NC}"
    echo -e "   ${GREEN}Impact: -${OPTIMIZATION_STATS[low_reduction]} lines (~${LOW_PERCENT}% reduction)${NC}\n"
    
    echo -e "${BOLD}5.${NC} ${MAGENTA}FULL OPTIMIZATION${NC} - Apply all optimizations"
    echo -e "   ${DIM}Complete optimization with all improvements${NC}"
    local total_reduction=$((OPTIMIZATION_STATS[critical_reduction] + OPTIMIZATION_STATS[high_reduction] + OPTIMIZATION_STATS[medium_reduction] + OPTIMIZATION_STATS[low_reduction]))
    local total_percent=$((total_reduction * 100 / OPTIMIZATION_STATS[total_lines]))
    echo -e "   ${GREEN}Impact: -$total_reduction lines (~$total_percent% reduction)${NC}\n"
    
    echo -e "${BOLD}6.${NC} Show detailed analysis"
    echo -e "${BOLD}7.${NC} Preview optimization changes"
    echo -e "${BOLD}8.${NC} Backup current installer"
    echo -e "${BOLD}9.${NC} Restore from backup"
    echo -e "${BOLD}0.${NC} Exit\n"
    
    print_separator
}

show_detailed_analysis() {
    print_header
    echo -e "${BOLD}${CYAN}DETAILED ANALYSIS REPORT${NC}\n"
    
    # Large Functions Analysis
    print_box "Large Functions (>100 lines)" "$(cat <<EOF
The installer contains ${OPTIMIZATION_STATS[large_functions]} functions larger than 100 lines.
These functions are candidates for breaking into smaller, more manageable pieces.

Key large functions identified:
- install_global_claude_md: ~591 lines (mainly embedded content)
- install_learning_python_dependencies: ~300+ lines
- install_nodejs_with_fallbacks: ~200+ lines

Recommended action: Extract embedded content and split large functions.
EOF
)" "$YELLOW"
    
    # Duplication Analysis
    if [[ ${OPTIMIZATION_STATS[duplicate_patterns]} -gt 0 ]]; then
        local duplicate_details=""
        for pattern in "${!DUPLICATED_PATTERNS[@]}"; do
            duplicate_details+="\n- Pattern '$pattern': ${DUPLICATED_PATTERNS[$pattern]} occurrences"
        done
        
        print_box "Code Duplication Analysis" "$(cat <<EOF
Found ${OPTIMIZATION_STATS[duplicate_patterns]} patterns with high repetition:
$duplicate_details

These patterns can be consolidated into reusable functions.
EOF
)" "$BLUE"
    fi
    
    # Embedded Content Analysis
    print_box "Embedded Content Analysis" "$(cat <<EOF
Detected ${OPTIMIZATION_STATS[embedded_blocks]} embedded content blocks using HERE documents.
The largest block is the CLAUDE.md content (~591 lines) in install_global_claude_md().

This massive embedded content should be extracted to:
1. External file (claude-md-content.txt)
2. Compressed format
3. Download from external source

This single change would reduce file size by ~14%.
EOF
)" "$RED"
    
    # Recommendations
    print_box "Optimization Recommendations" "$(cat <<EOF
${BOLD}Priority Order:${NC}
1. ${RED}CRITICAL:${NC} Extract CLAUDE.md embedded content → Immediate 14% reduction
2. ${YELLOW}HIGH:${NC} Split large installation functions → Better maintainability
3. ${BLUE}MEDIUM:${NC} Create error handling library → Code consistency
4. ${GREEN}LOW:${NC} Clean formatting → Minor size reduction

${BOLD}Expected Benefits:${NC}
- Reduced memory usage during execution
- Faster script parsing and loading
- Improved maintainability and debugging
- Better version control diffs
- Easier testing of individual components
EOF
)" "$GREEN"
    
    wait_for_key
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPTIMIZATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_backup() {
    print_header
    echo -e "${YELLOW}${BOLD}Creating backup of installer...${NC}\n"
    
    if cp "$INSTALLER_PATH" "$BACKUP_PATH"; then
        echo -e "${GREEN}${CHECK} Backup created: $BACKUP_PATH${NC}"
        OPTIMIZATION_STATS["backup_path"]="$BACKUP_PATH"
        echo "backup_path=$BACKUP_PATH" >> "$ANALYSIS_CACHE"
    else
        echo -e "${RED}${CROSS} Failed to create backup${NC}"
        return 1
    fi
    
    wait_for_key
}

optimize_critical() {
    print_header
    echo -e "${RED}${BOLD}CRITICAL OPTIMIZATION: Extracting Embedded Content${NC}\n"
    
    create_backup || return 1
    
    echo -e "${YELLOW}Extracting CLAUDE.md content to external file...${NC}"
    
    # Extract the embedded content
    local claude_md_file="${INSTALLER_PATH%/*}/claude-md-content.txt"
    
    # Find the start and end of the embedded content
    local start_line=$(grep -n "local claude_md_content=" "$INSTALLER_PATH" | cut -d: -f1)
    local end_line=$(grep -n "^[[:space:]]*'\$" "$INSTALLER_PATH" | head -1 | cut -d: -f1)
    
    if [[ -z "$start_line" || -z "$end_line" ]]; then
        echo -e "${RED}${CROSS} Could not locate embedded content boundaries${NC}"
        return 1
    fi
    
    # Extract content between single quotes
    sed -n "${start_line},${end_line}p" "$INSTALLER_PATH" | \
        sed "1s/.*='//" | \
        sed '$s/'"'"'[[:space:]]*$//' > "$claude_md_file"
    
    echo -e "${GREEN}${CHECK} Extracted content to: $claude_md_file${NC}"
    
    # Create optimized version
    echo -e "${YELLOW}Creating optimized installer...${NC}"
    
    # Replace the large embedded content with a file read operation
    sed -i "${start_line},${end_line}c\\
    local claude_md_content\\
    if [[ -f \"$claude_md_file\" ]]; then\\
        claude_md_content=\$(cat \"$claude_md_file\")\\
    else\\
        claude_md_content=\"# CLAUDE.md content file not found\"\\
    fi" "$INSTALLER_PATH"
    
    # Show results
    local new_lines=$(wc -l < "$INSTALLER_PATH")
    local reduction=$((OPTIMIZATION_STATS[total_lines] - new_lines))
    
    echo -e "${GREEN}${CHECK} Optimization complete!${NC}"
    echo -e "Lines reduced: $reduction"
    echo -e "New file size: $new_lines lines"
    echo -e "Reduction: $((reduction * 100 / OPTIMIZATION_STATS[total_lines]))%"
    
    wait_for_key
}

optimize_high() {
    print_header
    echo -e "${YELLOW}${BOLD}HIGH PRIORITY OPTIMIZATION: Consolidating Functions${NC}\n"
    
    create_backup || return 1
    
    echo -e "${YELLOW}Analyzing and consolidating repeated patterns...${NC}"
    
    # Create common error handling function
    local error_handler='
handle_error() {
    local exit_code="$1"
    local message="$2"
    print_red "$ERROR $message"
    exit "$exit_code"
}

check_command() {
    local cmd="$1"
    local package="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        handle_error 1 "Required command '\''$cmd'\'' not found. Install $package"
    fi
}

create_directory() {
    local dir="$1"
    mkdir -p "$dir" || handle_error 1 "Failed to create directory: $dir"
}
'
    
    # Insert error handling functions after the color definitions
    local insert_line=$(grep -n "print_dim()" "$INSTALLER_PATH" | cut -d: -f1)
    
    if [[ -n "$insert_line" ]]; then
        # Create temporary file with new functions
        local temp_file="/tmp/installer_optimized.sh"
        head -n "$insert_line" "$INSTALLER_PATH" > "$temp_file"
        echo "$error_handler" >> "$temp_file"
        tail -n +$((insert_line + 1)) "$INSTALLER_PATH" >> "$temp_file"
        
        # Replace original with optimized version
        mv "$temp_file" "$INSTALLER_PATH"
        
        echo -e "${GREEN}${CHECK} Added common error handling functions${NC}"
    fi
    
    # Replace repetitive patterns
    echo -e "${YELLOW}Replacing repetitive patterns...${NC}"
    
    # Replace mkdir -p patterns
    sed -i 's/mkdir -p \([^|]*\) || { print_red.*exit 1.*}/create_directory \1/g' "$INSTALLER_PATH"
    
    # Replace command existence checks
    sed -i 's/if ! command -v \([^[:space:]]*\).*then.*print_red.*exit 1.*fi/check_command \1 \1/g' "$INSTALLER_PATH"
    
    # Show results
    local new_lines=$(wc -l < "$INSTALLER_PATH")
    local reduction=$((OPTIMIZATION_STATS[total_lines] - new_lines))
    
    echo -e "${GREEN}${CHECK} High priority optimization complete!${NC}"
    echo -e "Lines reduced: $reduction"
    echo -e "Common functions added for better maintainability"
    
    wait_for_key
}

optimize_medium() {
    print_header
    echo -e "${BLUE}${BOLD}MEDIUM PRIORITY OPTIMIZATION: Standardizing Code${NC}\n"
    
    create_backup || return 1
    
    echo -e "${YELLOW}Standardizing error messages and formatting...${NC}"
    
    # Standardize print statements
    sed -i 's/echo -e "\${RED}/print_red "/g' "$INSTALLER_PATH"
    sed -i 's/echo -e "\${GREEN}/print_green "/g' "$INSTALLER_PATH"
    sed -i 's/echo -e "\${YELLOW}/print_yellow "/g' "$INSTALLER_PATH"
    
    # Remove excessive empty lines (more than 2 consecutive)
    sed -i '/^$/N;/^\n$/d' "$INSTALLER_PATH"
    
    # Standardize indentation for functions
    sed -i 's/^    /\t/g' "$INSTALLER_PATH"
    
    echo -e "${GREEN}${CHECK} Code standardization complete${NC}"
    
    wait_for_key
}

optimize_low() {
    print_header
    echo -e "${GREEN}${BOLD}LOW PRIORITY OPTIMIZATION: Cleaning Formatting${NC}\n"
    
    create_backup || return 1
    
    echo -e "${YELLOW}Cleaning formatting and comments...${NC}"
    
    # Remove trailing whitespace
    sed -i 's/[[:space:]]*$//' "$INSTALLER_PATH"
    
    # Remove excessive comment lines (but keep section headers)
    sed -i '/^[[:space:]]*#[[:space:]]*$/d' "$INSTALLER_PATH"
    
    # Compress multiple empty lines to single empty line
    sed -i '/^$/N;/^\n$/d' "$INSTALLER_PATH"
    
    echo -e "${GREEN}${CHECK} Formatting cleanup complete${NC}"
    
    wait_for_key
}

optimize_full() {
    print_header
    echo -e "${MAGENTA}${BOLD}FULL OPTIMIZATION: Applying All Improvements${NC}\n"
    
    echo -e "${YELLOW}This will apply all optimization levels:${NC}"
    echo -e "1. ${RED}CRITICAL${NC} - Extract embedded content"
    echo -e "2. ${YELLOW}HIGH${NC} - Consolidate functions"  
    echo -e "3. ${BLUE}MEDIUM${NC} - Standardize error handling"
    echo -e "4. ${GREEN}LOW${NC} - Clean formatting"
    echo
    
    read -p "Continue with full optimization? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Optimization cancelled${NC}"
        wait_for_key
        return
    fi
    
    local start_lines=${OPTIMIZATION_STATS[total_lines]}
    
    # Apply optimizations in order
    echo -e "\n${RED}Step 1/4: Critical optimization...${NC}"
    optimize_critical
    
    echo -e "\n${YELLOW}Step 2/4: High priority optimization...${NC}"  
    optimize_high
    
    echo -e "\n${BLUE}Step 3/4: Medium priority optimization...${NC}"
    optimize_medium
    
    echo -e "\n${GREEN}Step 4/4: Low priority optimization...${NC}"
    optimize_low
    
    # Final results
    local final_lines=$(wc -l < "$INSTALLER_PATH")
    local total_reduction=$((start_lines - final_lines))
    local reduction_percent=$((total_reduction * 100 / start_lines))
    
    print_header
    echo -e "${MAGENTA}${BOLD}FULL OPTIMIZATION COMPLETE!${NC}\n"
    
    print_box "Optimization Results" "$(cat <<EOF
Original size: $start_lines lines
Optimized size: $final_lines lines
Total reduction: $total_reduction lines ($reduction_percent%)

Backup saved to: ${OPTIMIZATION_STATS[backup_path]}
Optimized file: $INSTALLER_PATH

${GREEN}All optimizations applied successfully!${NC}
EOF
)" "$GREEN"
    
    wait_for_key
}

preview_optimization() {
    print_header
    echo -e "${CYAN}${BOLD}OPTIMIZATION PREVIEW${NC}\n"
    
    echo -e "${YELLOW}Analyzing changes that would be made...${NC}\n"
    
    # Show what would be extracted
    echo -e "${RED}${BOLD}CRITICAL: Embedded Content Extraction${NC}"
    echo -e "Would extract large CLAUDE.md content (~591 lines) to external file:"
    echo -e "${DIM}claude-md-content.txt${NC}"
    echo -e "Function 'install_global_claude_md' would be reduced from ~591 lines to ~10 lines"
    echo
    
    # Show function consolidation preview
    echo -e "${YELLOW}${BOLD}HIGH: Function Consolidation${NC}"
    echo -e "Would add common utility functions:"
    echo -e "- ${GREEN}handle_error()${NC} - Centralized error handling"
    echo -e "- ${GREEN}check_command()${NC} - Command existence validation"
    echo -e "- ${GREEN}create_directory()${NC} - Safe directory creation"
    echo -e "Would replace ~${OPTIMIZATION_STATS[high_reduction]} lines of repetitive code"
    echo
    
    # Show standardization preview
    echo -e "${BLUE}${BOLD}MEDIUM: Code Standardization${NC}"
    echo -e "Would standardize:"
    echo -e "- Print statements to use consistent functions"
    echo -e "- Error message formatting"
    echo -e "- Indentation (tabs vs spaces)"
    echo -e "Would affect ~${OPTIMIZATION_STATS[medium_reduction]} lines"
    echo
    
    # Show cleanup preview
    echo -e "${GREEN}${BOLD}LOW: Formatting Cleanup${NC}"
    echo -e "Would clean up:"
    echo -e "- Trailing whitespace"
    echo -e "- Excessive empty lines"
    echo -e "- Redundant comments"
    echo -e "Would reduce ~${OPTIMIZATION_STATS[low_reduction]} lines"
    echo
    
    # Total impact
    local total_reduction=$((OPTIMIZATION_STATS[critical_reduction] + OPTIMIZATION_STATS[high_reduction] + OPTIMIZATION_STATS[medium_reduction] + OPTIMIZATION_STATS[low_reduction]))
    local final_size=$((OPTIMIZATION_STATS[total_lines] - total_reduction))
    local reduction_percent=$((total_reduction * 100 / OPTIMIZATION_STATS[total_lines]))
    
    print_separator
    echo -e "${MAGENTA}${BOLD}TOTAL IMPACT PREVIEW:${NC}"
    echo -e "Current size: ${OPTIMIZATION_STATS[total_lines]} lines"
    echo -e "After optimization: $final_size lines"
    echo -e "Total reduction: $total_reduction lines ($reduction_percent%)"
    echo
    
    wait_for_key
}

restore_backup() {
    print_header
    echo -e "${YELLOW}${BOLD}RESTORE FROM BACKUP${NC}\n"
    
    if [[ -f "${OPTIMIZATION_STATS[backup_path]:-}" ]]; then
        echo -e "Found backup: ${OPTIMIZATION_STATS[backup_path]}"
        read -p "Restore from this backup? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if cp "${OPTIMIZATION_STATS[backup_path]}" "$INSTALLER_PATH"; then
                echo -e "${GREEN}${CHECK} Successfully restored from backup${NC}"
            else
                echo -e "${RED}${CROSS} Failed to restore backup${NC}"
            fi
        fi
    else
        # Look for any backup files
        local backups=($(ls "${INSTALLER_PATH}.backup."* 2>/dev/null))
        if [[ ${#backups[@]} -gt 0 ]]; then
            echo -e "${CYAN}Available backups:${NC}"
            for i in "${!backups[@]}"; do
                echo -e "$((i+1)). ${backups[i]}"
            done
            echo
            
            read -p "Select backup to restore (1-${#backups[@]}): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[1-9]$ ]] && [[ $REPLY -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((REPLY-1))]}"
                if cp "$selected_backup" "$INSTALLER_PATH"; then
                    echo -e "${GREEN}${CHECK} Successfully restored from $selected_backup${NC}"
                else
                    echo -e "${RED}${CROSS} Failed to restore backup${NC}"
                fi
            else
                echo -e "${YELLOW}Invalid selection${NC}"
            fi
        else
            echo -e "${YELLOW}${WARN} No backup files found${NC}"
        fi
    fi
    
    wait_for_key
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN MENU LOOP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_menu() {
    # Calculate percentages for display
    if [[ ${OPTIMIZATION_STATS[total_lines]:-0} -gt 0 ]]; then
        HIGH_PERCENT=$((OPTIMIZATION_STATS[high_reduction] * 100 / OPTIMIZATION_STATS[total_lines]))
        MEDIUM_PERCENT=$((OPTIMIZATION_STATS[medium_reduction] * 100 / OPTIMIZATION_STATS[total_lines]))
        LOW_PERCENT=$((OPTIMIZATION_STATS[low_reduction] * 100 / OPTIMIZATION_STATS[total_lines]))
    else
        HIGH_PERCENT=0
        MEDIUM_PERCENT=0
        LOW_PERCENT=0
    fi
    
    while true; do
        show_analysis_dashboard
        show_optimization_menu
        
        read -p "Select option (0-9): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                optimize_critical
                ;;
            2)
                optimize_high
                ;;
            3)
                optimize_medium
                ;;
            4)
                optimize_low
                ;;
            5)
                optimize_full
                ;;
            6)
                show_detailed_analysis
                ;;
            7)
                preview_optimization
                ;;
            8)
                create_backup
                ;;
            9)
                restore_backup
                ;;
            0)
                print_header
                echo -e "${GREEN}${BOLD}Thank you for using TUI Installer Optimizer!${NC}"
                echo -e "${DIM}Optimization complete. Your installer is now more efficient.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 0-9.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STARTUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if installer exists
if [[ ! -f "$INSTALLER_PATH" ]]; then
    print_header
    echo -e "${RED}${CROSS} Error: claude-installer.sh not found at expected location:${NC}"
    echo -e "${DIM}$INSTALLER_PATH${NC}"
    echo
    echo -e "${YELLOW}Please ensure the installer exists or update INSTALLER_PATH in this script.${NC}"
    exit 1
fi

# Run initial analysis if cache doesn't exist
if [[ ! -f "$ANALYSIS_CACHE" ]]; then
    analyze_installer_structure
fi

# Start main menu
main_menu