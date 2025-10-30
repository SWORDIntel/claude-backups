#!/bin/bash
# Organize markdown files from root into appropriate doc subfolders

BASE="/home/john/Downloads/claude-backups"
cd "$BASE"

echo "📚 Organizing Markdown Files"
echo "============================"
echo ""

# Ensure doc subdirectories exist
mkdir -p docs/{status,reports,guides,reference}
mkdir -p archive/old-docs

# Categorize and move files
echo "Moving status/upgrade documents..."
[ -f "CLAUDE-2.0.2-UPGRADE-COMPLETE.md" ] && mv -v "CLAUDE-2.0.2-UPGRADE-COMPLETE.md" "docs/status/" && echo "  ✓ Upgrade report"

echo ""
echo "Moving session and review reports..."
[ -f "COMPLETE-SESSION-SUMMARY.md" ] && mv -v "COMPLETE-SESSION-SUMMARY.md" "docs/reports/" && echo "  ✓ Session summary"
[ -f "FINAL-CODE-REVIEW-REPORT.md" ] && mv -v "FINAL-CODE-REVIEW-REPORT.md" "docs/reports/" && echo "  ✓ Code review"
[ -f "REORGANIZATION-AND-FIXES-COMPLETE.md" ] && mv -v "REORGANIZATION-AND-FIXES-COMPLETE.md" "docs/reports/" && echo "  ✓ Reorganization report"
[ -f "REPOSITORY-REORGANIZATION-COMPLETE.md" ] && mv -v "REPOSITORY-REORGANIZATION-COMPLETE.md" "docs/reports/" && echo "  ✓ Repository report"
[ -f "HTML-ORGANIZATION-COMPLETE.md" ] && mv -v "HTML-ORGANIZATION-COMPLETE.md" "docs/reports/" && echo "  ✓ HTML organization"

echo ""
echo "Moving guides..."
[ -f "VENV-EXPLANATION.md" ] && mv -v "VENV-EXPLANATION.md" "docs/guides/" && echo "  ✓ Venv guide"

echo ""
echo "Moving directory structure to reference..."
[ -f "DIRECTORY-STRUCTURE.md" ] && cp -v "DIRECTORY-STRUCTURE.md" "docs/reference/" && echo "  ✓ Copied (keeping in root too)"

echo ""
echo "Archiving old files..."
[ -f "README-OLD.md" ] && mv -v "README-OLD.md" "archive/old-docs/" && echo "  ✓ Old README"

echo ""
echo "Keeping in root..."
echo "  ✓ README.md (main documentation)"
echo "  ✓ DIRECTORY-STRUCTURE.md (navigation reference)"

echo ""
echo "Creating index files in doc folders..."

# Create index for reports
cat > docs/reports/README.md << 'REPORTSEOF'
# Reports

## Session and Review Reports

This directory contains comprehensive reports from major system updates and reviews.

### Files

- **COMPLETE-SESSION-SUMMARY.md** - Complete session summary with all accomplishments
- **FINAL-CODE-REVIEW-REPORT.md** - Comprehensive code review after October 2025 over
