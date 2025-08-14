#!/bin/bash

# Detailed Error Analysis for livecd-gen scripts
LIVECD_DIR="/home/ubuntu/Documents/livecd-gen"
OUTPUT_DIR="/home/ubuntu/Documents/Claude"

echo "DETAILED ERROR ANALYSIS FOR LIVECD-GEN SCRIPTS"
echo "=============================================="
echo "Analysis Date: $(date)"
echo ""

# Error categories analysis
declare -A error_categories
declare -A error_files

echo "Analyzing specific error patterns in ERROR scripts..."
echo ""

# Function to analyze specific error types
analyze_error_script() {
    local script="$1"
    local script_path="$LIVECD_DIR/$script"
    
    if [[ ! -f "$script_path" ]]; then
        echo "WARNING: Script not found: $script_path"
        return
    fi
    
    echo "--- ANALYZING: $script ---"
    
    # Get bash syntax error
    local bash_error=$(bash -n "$script_path" 2>&1)
    local error_line=$(echo "$bash_error" | grep -o "line [0-9]*" | head -1 | cut -d' ' -f2)
    
    echo "Bash Error: $bash_error"
    
    if [[ -n "$error_line" ]]; then
        echo "Error Context (lines $((error_line-2)) to $((error_line+2))):"
        sed -n "$((error_line-2)),$((error_line+2))p" "$script_path" 2>/dev/null | cat -n
    fi
    
    # Categorize error type
    local error_type="UNKNOWN"
    if [[ "$bash_error" =~ "unexpected token" ]]; then
        if [[ "$bash_error" =~ "unexpected token.*\(" ]]; then
            error_type="MALFORMED_FUNCTION_CALL"
        elif [[ "$bash_error" =~ "unexpected token.*\)" ]]; then
            error_type="UNMATCHED_PARENTHESES"
        elif [[ "$bash_error" =~ "unexpected token.*\$" ]]; then
            error_type="MALFORMED_VARIABLE_SUBSTITUTION"
        else
            error_type="SYNTAX_ERROR_TOKEN"
        fi
    elif [[ "$bash_error" =~ "unexpected end of file" ]]; then
        error_type="UNCLOSED_BLOCK"
    elif [[ "$bash_error" =~ "unexpected EOF" ]]; then
        error_type="UNCLOSED_QUOTE_OR_HEREDOC"
    fi
    
    echo "ERROR CATEGORY: $error_type"
    
    # Track categories
    error_categories["$error_type"]=$((${error_categories["$error_type"]} + 1))
    error_files["$script"]="$error_type"
    
    echo ""
}

# List of ERROR scripts from analysis
error_scripts=(
    "OSBuilders/ZFSOS.sh"
    "add-dell-blocking-to-desktop.sh"
    "add-enhanced-repos-and-sources.sh"
    "add-firefox-with-session.sh"
    "add-ml-debugging-validation-system.sh"
    "deploy/environment-setup.sh"
    "final-build-check.sh"
    "lib/plugin-interface.sh"
    "plugins/hardware-optimizer.sh"
    "plugins/memory-forensics-suite.sh"
    "plugins/network-boot-server-new.sh"
    "plugins/network-boot-server.sh"
    "plugins/security-research-tools.sh"
    "ring-minus-orchestrator.sh"
    "src/build/build-zfs-livecd-ramdisk-fixed.sh"
    "src/build/build-zfs-livecd-ramdisk.sh"
)

# Analyze each error script
for script in "${error_scripts[@]}"; do
    analyze_error_script "$script"
done

echo "ERROR CATEGORY SUMMARY:"
echo "======================"
for category in "${!error_categories[@]}"; do
    echo "$category: ${error_categories[$category]} scripts"
done

echo ""
echo "DETAILED BREAKDOWN BY CATEGORY:"
echo "==============================="

for category in "${!error_categories[@]}"; do
    echo ""
    echo "### $category (${error_categories[$category]} scripts)"
    echo "Scripts:"
    for script in "${!error_files[@]}"; do
        if [[ "${error_files[$script]}" == "$category" ]]; then
            echo "  - $script"
        fi
    done
    
    # Provide fix recommendations
    echo "Fix Strategy:"
    case "$category" in
        "MALFORMED_FUNCTION_CALL")
            echo "  - Check for double flags in commands (e.g., apt-get install -y -y)"
            echo "  - Verify function call syntax"
            echo "  - Agent: Patcher (syntax correction specialist)"
            ;;
        "UNMATCHED_PARENTHESES")
            echo "  - Find and match all parentheses pairs"
            echo "  - Check for malformed variable substitutions like )\$("
            echo "  - Agent: Patcher (bracket matching specialist)"
            ;;
        "MALFORMED_VARIABLE_SUBSTITUTION")
            echo "  - Fix \$() and \${} syntax"
            echo "  - Check for escaped variables"
            echo "  - Agent: Patcher (variable syntax specialist)"
            ;;
        "UNCLOSED_BLOCK")
            echo "  - Find missing closing braces } for functions/conditions"
            echo "  - Check if/else/fi and for/done blocks"
            echo "  - Agent: Patcher (block structure specialist)"
            ;;
        "UNCLOSED_QUOTE_OR_HEREDOC")
            echo "  - Find unmatched quotes (' or \")"
            echo "  - Check heredoc (<<) syntax"
            echo "  - Agent: Patcher (quote/heredoc specialist)"
            ;;
        "SYNTAX_ERROR_TOKEN")
            echo "  - General syntax review needed"
            echo "  - Check for shell reserved words misuse"
            echo "  - Agent: Linter + Patcher combination"
            ;;
    esac
    echo ""
done

echo "SEVERITY AND COMPLEXITY ANALYSIS:"
echo "================================="
echo "HIGH SEVERITY (Prevent script execution):"
echo "  - All 36 ERROR scripts require immediate attention"
echo "  - These break the build system completely"
echo ""
echo "COMPLEXITY LEVELS:"
echo "  - SIMPLE (1-3 line fixes): MALFORMED_FUNCTION_CALL, UNMATCHED_PARENTHESES"
echo "  - MEDIUM (3-10 line fixes): MALFORMED_VARIABLE_SUBSTITUTION, UNCLOSED_QUOTE_OR_HEREDOC"  
echo "  - COMPLEX (10+ line fixes): UNCLOSED_BLOCK, SYNTAX_ERROR_TOKEN"
echo ""

echo "RECOMMENDED AGENT DEPLOYMENT SEQUENCE:"
echo "======================================"
echo "1. PHASE 1 - Critical Syntax Fixes (Patcher Agent)"
echo "   - Focus on SIMPLE fixes first (function calls, parentheses)"
echo "   - Target: 15-20 scripts in first batch"
echo "   - Time estimate: 2-3 hours"
echo ""
echo "2. PHASE 2 - Variable and Quote Fixes (Patcher Agent)"
echo "   - Handle MEDIUM complexity issues"
echo "   - Target: 10-15 scripts"
echo "   - Time estimate: 3-4 hours"
echo ""
echo "3. PHASE 3 - Complex Structural Issues (Patcher + Linter)"
echo "   - Handle COMPLEX block structure problems"
echo "   - Target: Remaining 5-10 scripts"
echo "   - Time estimate: 4-6 hours"
echo ""
echo "4. PHASE 4 - PARTIAL Script Cleanup (Linter Agent)"
echo "   - Add missing shebangs (180 scripts need this)"
echo "   - Fix undefined variable warnings"
echo "   - Time estimate: 6-8 hours"
echo ""

echo "TOTAL ESTIMATED EFFORT: 15-21 hours across all phases"
echo "CRITICAL PATH: Complete Phase 1-3 before system is functional"