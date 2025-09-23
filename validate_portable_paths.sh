#!/bin/bash

# Quick validation script to verify portable path implementation
# Checks for any remaining hardcoded paths in documentation

PROJECT_ROOT="/home/john/claude-backups"

echo "🔍 DOCGEN: Portable Paths Validation"
echo "===================================="

# Check for remaining hardcoded paths
echo "📋 Scanning for remaining hardcoded paths..."

# Look for remaining problematic patterns
remaining_issues=0

# Check for remaining /home/ubuntu or /home/john patterns
if grep -r "/home/\(ubuntu\|john\)" "$PROJECT_ROOT" \
    --include="*.md" \
    --include="*.txt" \
    --exclude-dir=".git" \
    --exclude-dir="..bfg-report" \
    --exclude-dir=".claude" \
    --exclude-dir="backup_before_path_fixes_*" \
    --exclude="validate_portable_paths.sh" \
    --exclude="fix_hardcoded_paths_comprehensive.sh" 2>/dev/null; then

    echo "❌ Found remaining hardcoded user paths"
    ((remaining_issues++))
else
    echo "✅ No hardcoded user paths found"
fi

# Check for hardcoded claude-backups references (outside of URLs)
hardcoded_project=$(grep -r "claude-backups" "$PROJECT_ROOT" \
    --include="*.md" \
    --exclude-dir=".git" \
    --exclude-dir="..bfg-report" \
    --exclude-dir=".claude" \
    --exclude-dir="backup_before_path_fixes_*" \
    --exclude="validate_portable_paths.sh" \
    --exclude="fix_hardcoded_paths_comprehensive.sh" \
    | grep -v "github.com/SWORDIntel/claude-backups" \
    | grep -v "repository.*claude-backups" \
    | grep -v "https://.*claude-backups" \
    | wc -l)

if [ "$hardcoded_project" -gt 0 ]; then
    echo "⚠️  Found $hardcoded_project potential hardcoded project references (may be acceptable)"
else
    echo "✅ No problematic project references found"
fi

# Check for usage of environment variables
env_vars_found=$(grep -r "\$CLAUDE_PROJECT_ROOT\|\$HOME\|\$(pwd)" "$PROJECT_ROOT" \
    --include="*.md" \
    --exclude-dir=".git" \
    --exclude-dir="..bfg-report" \
    --exclude-dir=".claude" \
    --exclude-dir="backup_before_path_fixes_*" \
    | wc -l)

echo "✅ Found $env_vars_found uses of portable environment variables"

# Sample some key files for verification
echo ""
echo "🔍 Spot checking key files:"

key_files=("CLAUDE.md" "README.md" "INSTALL.md" "docs/guides/installation-guide.md")
for file in "${key_files[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        hardcoded_count=$(grep -c "/home/\(ubuntu\|john\)" "$PROJECT_ROOT/$file" 2>/dev/null || echo "0")
        portable_count=$(grep -c "\$\(HOME\|CLAUDE_PROJECT_ROOT\)" "$PROJECT_ROOT/$file" 2>/dev/null || echo "0")

        if [ "$hardcoded_count" -eq 0 ]; then
            echo "  ✅ $file: No hardcoded paths (${portable_count} portable paths)"
        else
            echo "  ❌ $file: $hardcoded_count hardcoded paths remaining"
            ((remaining_issues++))
        fi
    fi
done

echo ""
echo "📊 Summary:"
if [ "$remaining_issues" -eq 0 ]; then
    echo "✅ VALIDATION PASSED: All documentation uses portable paths"
    echo "🚀 System is ready for universal deployment"
else
    echo "❌ VALIDATION FAILED: $remaining_issues issues found"
    echo "🔧 Review and fix remaining hardcoded paths"
fi

echo ""
echo "🎯 To use the portable system:"
echo "   export CLAUDE_PROJECT_ROOT=\"\$(pwd)\""
echo "   export HOME=\"\$HOME\""
echo "   # All documentation examples will now work universally"