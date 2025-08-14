#!/bin/bash

# Comprehensive analysis of livecd-gen scripts
LIVECD_DIR="/home/ubuntu/Documents/livecd-gen"
OUTPUT_FILE="/home/ubuntu/Documents/Claude/livecd_script_analysis.json"

echo "Starting comprehensive analysis of livecd-gen scripts..."
echo "Analysis timestamp: $(date)" > analysis_report.txt

# Initialize counters
total_scripts=0
syntax_errors=0
partial_fixes=0
working_scripts=0

# JSON output initialization
echo "{" > "$OUTPUT_FILE"
echo '  "analysis_timestamp": "'$(date -Iseconds)'",' >> "$OUTPUT_FILE"
echo '  "total_scripts": 0,' >> "$OUTPUT_FILE"
echo '  "error_scripts": [],' >> "$OUTPUT_FILE"
echo '  "partial_scripts": [],' >> "$OUTPUT_FILE"
echo '  "working_scripts": [],' >> "$OUTPUT_FILE"
echo '  "summary": {}' >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

# Arrays to store script categorization
declare -a error_scripts=()
declare -a partial_scripts=()
declare -a working_scripts=()

# Find all shell scripts (excluding backups and deprecated)
echo "Finding all shell scripts..."
scripts_list=$(find "$LIVECD_DIR" -name "*.sh" -type f ! -path "*/deprecated/*" ! -name "*.backup" ! -name "*.optimizer_backup" | sort)

echo "Found scripts to analyze:"
echo "$scripts_list" | wc -l
echo ""

# Function to check syntax
check_syntax() {
    local script="$1"
    local basename=$(basename "$script")
    
    echo "Analyzing: $basename"
    
    # Basic bash syntax check
    bash_check=$(bash -n "$script" 2>&1)
    bash_exit_code=$?
    
    # Shellcheck if available
    shellcheck_output=""
    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck_output=$(shellcheck "$script" 2>&1 || true)
    fi
    
    # Check for common issues
    missing_shebang=""
    if ! head -1 "$script" | grep -q "^#!"; then
        missing_shebang="Missing shebang"
    fi
    
    # Check for undefined variables
    undefined_vars=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*' "$script" | grep -v 'export\|declare\|local\|read\|=\|"' | head -5 || true)
    
    # Check for unmatched quotes/brackets
    quote_issues=$(grep -n '[^\\]["\047].*[^\\]["\047].*[^\\]["\047]' "$script" | head -3 || true)
    
    # Determine category
    if [ $bash_exit_code -ne 0 ]; then
        error_scripts+=("$basename")
        echo "  STATUS: ERROR - Syntax errors prevent execution"
        echo "  BASH_CHECK: $bash_check"
    elif [[ -n "$shellcheck_output" && "$shellcheck_output" =~ "error:" ]]; then
        error_scripts+=("$basename")
        echo "  STATUS: ERROR - Shellcheck found critical errors"
    elif [[ -n "$shellcheck_output" && "$shellcheck_output" =~ "warning:" ]] || [[ -n "$missing_shebang" ]] || [[ -n "$undefined_vars" ]]; then
        partial_scripts+=("$basename")
        echo "  STATUS: PARTIAL - Has warnings or minor issues"
    else
        working_scripts+=("$basename")
        echo "  STATUS: WORKING - No major issues detected"
    fi
    
    if [[ -n "$missing_shebang" ]]; then
        echo "  ISSUE: $missing_shebang"
    fi
    
    if [[ -n "$undefined_vars" ]]; then
        echo "  POTENTIAL_UNDEFINED_VARS:"
        echo "$undefined_vars" | head -3
    fi
    
    if [[ -n "$shellcheck_output" ]]; then
        echo "  SHELLCHECK_SUMMARY:"
        echo "$shellcheck_output" | head -5
    fi
    
    echo ""
    
    total_scripts=$((total_scripts + 1))
}

# Analyze each script
while IFS= read -r script; do
    check_syntax "$script"
done <<< "$scripts_list"

# Count results
syntax_errors=${#error_scripts[@]}
partial_fixes=${#partial_scripts[@]}
working_scripts_count=${#working_scripts[@]}

echo "=== ANALYSIS SUMMARY ===" | tee -a analysis_report.txt
echo "Total scripts analyzed: $total_scripts" | tee -a analysis_report.txt
echo "Scripts with ERRORS: $syntax_errors" | tee -a analysis_report.txt
echo "Scripts with PARTIAL issues: $partial_fixes" | tee -a analysis_report.txt
echo "WORKING scripts: $working_scripts_count" | tee -a analysis_report.txt
echo "" | tee -a analysis_report.txt

if [ ${#error_scripts[@]} -gt 0 ]; then
    echo "=== ERROR SCRIPTS (require immediate attention) ===" | tee -a analysis_report.txt
    printf '%s\n' "${error_scripts[@]}" | tee -a analysis_report.txt
    echo "" | tee -a analysis_report.txt
fi

if [ ${#partial_scripts[@]} -gt 0 ]; then
    echo "=== PARTIAL SCRIPTS (minor issues) ===" | tee -a analysis_report.txt
    printf '%s\n' "${partial_scripts[@]}" | tee -a analysis_report.txt
    echo "" | tee -a analysis_report.txt
fi

# Generate detailed JSON report
cat > "$OUTPUT_FILE" << EOF
{
  "analysis_timestamp": "$(date -Iseconds)",
  "total_scripts": $total_scripts,
  "error_scripts": [
$(printf '    "%s"' "${error_scripts[@]}" | paste -sd ',' -)
  ],
  "partial_scripts": [
$(printf '    "%s"' "${partial_scripts[@]}" | paste -sd ',' -)
  ],
  "working_scripts": [
$(printf '    "%s"' "${working_scripts[@]}" | paste -sd ',' -)
  ],
  "summary": {
    "total": $total_scripts,
    "errors": $syntax_errors,
    "partial": $partial_fixes,
    "working": $working_scripts_count,
    "error_percentage": $(echo "scale=1; $syntax_errors * 100 / $total_scripts" | bc -l 2>/dev/null || echo "0"),
    "partial_percentage": $(echo "scale=1; $partial_fixes * 100 / $total_scripts" | bc -l 2>/dev/null || echo "0")
  }
}
EOF

echo "Analysis complete. Results saved to:"
echo "- analysis_report.txt"
echo "- $OUTPUT_FILE"
echo ""
echo "Recommended next steps:"
echo "1. Fix ERROR scripts first (syntax issues)"
echo "2. Address PARTIAL scripts (warnings/minor issues)" 
echo "3. Deploy appropriate agents: Patcher for errors, Linter for partial fixes"