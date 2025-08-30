#!/bin/bash
# Repository Cleanup Script - Deprecated Files and Directories
# Safely moves deprecated files to organized deprecated/ structure

set -e

REPO_ROOT="/home/john/claude-backups"
DEPRECATED_ROOT="$REPO_ROOT/deprecated"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cd "$REPO_ROOT"

echo "==================================="
echo "REPOSITORY CLEANUP - DEPRECATED FILES"
echo "==================================="
echo "Timestamp: $TIMESTAMP"
echo

# Create organized deprecated structure
mkdir -p "$DEPRECATED_ROOT"/{backups,logs,tests,configs,installers,docs}

echo "1. BACKUP FILES CLEANUP"
echo "----------------------"

# Move precision orchestration backup files
if [ -d "backups" ]; then
    echo "Moving precision-orchestration backup files..."
    mkdir -p "$DEPRECATED_ROOT/backups/precision-orchestration-$TIMESTAMP"
    mv backups/precision-orchestration_*.md "$DEPRECATED_ROOT/backups/precision-orchestration-$TIMESTAMP/" 2>/dev/null || true
    
    echo "Moving optimizer backups..."
    mkdir -p "$DEPRECATED_ROOT/backups/optimizer-$TIMESTAMP"
    mv backups/optimizer-backups/ "$DEPRECATED_ROOT/backups/optimizer-$TIMESTAMP/" 2>/dev/null || true
    
    echo "Moving agent old backups..."
    mv backups/agents-old-backups/ "$DEPRECATED_ROOT/backups/agents-old-$TIMESTAMP/" 2>/dev/null || true
fi

# Move installer backups
echo "Moving installer backup files..."
mkdir -p "$DEPRECATED_ROOT/backups/installer-$TIMESTAMP"
mv claude-installer.sh.backup* "$DEPRECATED_ROOT/backups/installer-$TIMESTAMP/" 2>/dev/null || true

# Move hook system backups
if [ -d "hooks" ]; then
    echo "Moving hook system backup files..."
    mkdir -p "$DEPRECATED_ROOT/backups/hooks-$TIMESTAMP"
    mv hooks/*.backup "$DEPRECATED_ROOT/backups/hooks-$TIMESTAMP/" 2>/dev/null || true
    mv hooks/*pre-security "$DEPRECATED_ROOT/backups/hooks-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "2. TEMPORARY FILES CLEANUP"
echo "-------------------------"

# Move shell snapshots
if [ -d "config/shell-snapshots" ]; then
    echo "Moving shell snapshots ($(ls config/shell-snapshots/ | wc -l) files)..."
    mkdir -p "$DEPRECATED_ROOT/configs/shell-snapshots-$TIMESTAMP"
    mv config/shell-snapshots/ "$DEPRECATED_ROOT/configs/shell-snapshots-$TIMESTAMP/" 2>/dev/null || true
fi

# Move todo files  
if [ -d "config/todos" ]; then
    echo "Moving todo files ($(ls config/todos/ | wc -l) files)..."
    mkdir -p "$DEPRECATED_ROOT/configs/todos-$TIMESTAMP"
    mv config/todos/ "$DEPRECATED_ROOT/configs/todos-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "3. LOG FILES CLEANUP"
echo "-------------------"

# Move GitHub sync logs
if [ -d "logs" ]; then
    echo "Moving GitHub sync logs..."
    mkdir -p "$DEPRECATED_ROOT/logs/github-sync-$TIMESTAMP"
    mv logs/github-sync-*.log "$DEPRECATED_ROOT/logs/github-sync-$TIMESTAMP/" 2>/dev/null || true
fi

# Move agent monitoring logs
if [ -d "agents/monitoring/logs" ]; then
    echo "Moving agent monitoring logs..."
    mkdir -p "$DEPRECATED_ROOT/logs/monitoring-$TIMESTAMP"
    mv agents/monitoring/logs/ "$DEPRECATED_ROOT/logs/monitoring-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "4. TEST ARTIFACTS CLEANUP"
echo "------------------------"

# Move test results
if [ -d "hooks/test_results" ]; then
    echo "Moving hook test results..."
    mkdir -p "$DEPRECATED_ROOT/tests/hooks-$TIMESTAMP"
    mv hooks/test_results/ "$DEPRECATED_ROOT/tests/hooks-$TIMESTAMP/" 2>/dev/null || true
fi

# Move hook profiling stats
if [ -f "hooks/hook_profile.stats" ]; then
    echo "Moving hook profiling stats..."
    mv hooks/hook_profile.stats "$DEPRECATED_ROOT/tests/hooks-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "5. REDUNDANT DIRECTORIES CLEANUP"
echo "-------------------------------"

# Move agents/plans (completed development plans)
if [ -d "agents/plans" ]; then
    echo "Moving completed development plans..."
    mkdir -p "$DEPRECATED_ROOT/docs/development-plans-$TIMESTAMP"
    mv agents/plans/ "$DEPRECATED_ROOT/docs/development-plans-$TIMESTAMP/" 2>/dev/null || true
fi

# Move agents/Fixes (old fix scripts)
if [ -d "agents/Fixes" ]; then
    echo "Moving old fix scripts..."
    mkdir -p "$DEPRECATED_ROOT/configs/old-fixes-$TIMESTAMP"
    mv agents/Fixes/ "$DEPRECATED_ROOT/configs/old-fixes-$TIMESTAMP/" 2>/dev/null || true
fi

# Move old switchers
if [ -d "agents/admin/old-switchers" ]; then
    echo "Moving old switching scripts..."
    mkdir -p "$DEPRECATED_ROOT/configs/old-switchers-$TIMESTAMP"
    mv agents/admin/old-switchers/ "$DEPRECATED_ROOT/configs/old-switchers-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "6. INSTALLER DEPRECATION"
echo "-----------------------"

# The Deprecated/ directory in installers is already properly organized
echo "Deprecated installers already organized in installers/Deprecated/"

echo
echo "7. RUNTIME ARTIFACTS"
echo "-------------------"

# Move test project (simple C test)
if [ -d "test_project" ]; then
    echo "Moving test project artifacts..."
    mkdir -p "$DEPRECATED_ROOT/tests/test-project-$TIMESTAMP"
    mv test_project/ "$DEPRECATED_ROOT/tests/test-project-$TIMESTAMP/" 2>/dev/null || true
fi

echo
echo "8. GITIGNORE UPDATE"
echo "------------------"

# Add runtime artifacts to .gitignore
cat >> .gitignore << 'EOF'

# Runtime artifacts
venv/
*.stats
*.log
agents/runtime/status.json
config/shell-snapshots/
config/todos/
database/data/postgresql/
*.backup
*pre-security

EOF

echo "Updated .gitignore with runtime artifacts"

echo
echo "==================================="
echo "CLEANUP SUMMARY"
echo "==================================="

# Count deprecated files
DEPRECATED_COUNT=$(find "$DEPRECATED_ROOT" -type f 2>/dev/null | wc -l)
echo "✅ Files moved to deprecated/: $DEPRECATED_COUNT"
echo "✅ Organized by category and timestamp: $TIMESTAMP"
echo "✅ Updated .gitignore for runtime artifacts"
echo
echo "Deprecated files organized in:"
echo "  - $DEPRECATED_ROOT/backups/"
echo "  - $DEPRECATED_ROOT/logs/"
echo "  - $DEPRECATED_ROOT/tests/"
echo "  - $DEPRECATED_ROOT/configs/"
echo "  - $DEPRECATED_ROOT/docs/"
echo
echo "Repository cleanup complete!"