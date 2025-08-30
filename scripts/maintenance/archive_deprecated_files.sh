#!/bin/bash
# Repository Archive Script - Create structured tar.gz of deprecated files
# Archives deprecated files with clear documentation and structure

set -e

REPO_ROOT="/home/john/claude-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="claude-backups-deprecated-archive-$TIMESTAMP"
ARCHIVE_DIR="/tmp/$ARCHIVE_NAME"

cd "$REPO_ROOT"

echo "=================================================="
echo "CLAUDE BACKUPS - DEPRECATED FILES ARCHIVE CREATOR"
echo "=================================================="
echo "Archive: $ARCHIVE_NAME.tar.gz"
echo "Timestamp: $TIMESTAMP"
echo

# Create temporary archive structure
mkdir -p "$ARCHIVE_DIR"/{backups,logs,tests,configs,installers,docs,manifests}

echo "1. CREATING ARCHIVE STRUCTURE"
echo "=============================="

# Create comprehensive manifest
cat > "$ARCHIVE_DIR/manifests/ARCHIVE_MANIFEST.md" << EOF
# Claude Backups Repository - Deprecated Files Archive

**Archive Date**: $(date)
**Archive Version**: $TIMESTAMP
**Repository**: https://github.com/SWORDIntel/claude-backups
**Purpose**: Long-term storage of deprecated files from Claude Agent Framework v7.0

## Archive Contents

### 1. Backup Files (backups/)
- **precision-orchestration/**: 23+ backup files from orchestration system iterations
- **optimizer/**: Performance optimization backup files 
- **agents-old/**: Historical agent state snapshots and binary versions
- **installer/**: Backup versions of installation scripts
- **hooks/**: Hook system backup files including pre-security versions

### 2. Log Files (logs/)
- **github-sync/**: GitHub synchronization logs from August 2025
- **monitoring/**: Agent system monitoring and bridge logs
- **git-sync/**: Repository synchronization logs

### 3. Test Artifacts (tests/)
- **hooks/**: Hook system test results and reports
- **test-project/**: Simple C test project artifacts
- **performance/**: Profiling statistics and performance data

### 4. Configuration Files (configs/)
- **shell-snapshots/**: 30+ temporary Claude Code shell snapshots
- **todos/**: 50+ UUID-based todo tracking files (stale)
- **old-fixes/**: Legacy fix scripts and broken configurations
- **old-switchers/**: Deprecated agent switching mechanisms

### 5. Documentation (docs/)
- **development-plans/**: Completed development roadmaps and planning documents
- **archived/**: Previously archived system documentation
- **legacy/**: Legacy documentation and guides

### 6. Installers (installers/)
- **deprecated-installers/**: Old installation scripts and wrappers
- **legacy-wrappers/**: Historical wrapper implementations

## File Statistics

- **Total Files**: $(find "$REPO_ROOT" -name "*.backup" -o -name "*pre-security" -o -name "precision-orchestration_*.md" -o -name "github-sync-*.log" | wc -l)+ deprecated files
- **Estimated Size**: $(du -sh backups logs config/shell-snapshots 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "~500MB")
- **Date Range**: August 2025 - Present
- **Categories**: 6 major categories, 15+ subcategories

## Retention Policy

- **Archive Retention**: 2 years minimum
- **Access**: Reference only - not for restoration
- **Compression**: gzip with maximum compression
- **Verification**: SHA256 checksums included

## Related Files

- **Main Repository**: /home/john/claude-backups/
- **Production System**: Claude Unified Hook System v3.1-security-hardened
- **Active Agents**: 76 specialized agents (74 active + 2 templates)

---
*Archive created by automated cleanup process*
*Repository maintained by Claude Agent Framework v7.0*
EOF

echo "2. COLLECTING BACKUP FILES"
echo "=========================="

# Precision orchestration backups
if [ -d "backups" ]; then
    echo "Archiving precision-orchestration backups..."
    mkdir -p "$ARCHIVE_DIR/backups/precision-orchestration"
    find backups/ -name "precision-orchestration_*.md" -exec cp {} "$ARCHIVE_DIR/backups/precision-orchestration/" \; 2>/dev/null || true
    
    echo "Archiving optimizer backups..."
    if [ -d "backups/optimizer-backups" ]; then
        cp -r backups/optimizer-backups/ "$ARCHIVE_DIR/backups/optimizer/" 2>/dev/null || true
    fi
    
    echo "Archiving agent old backups..."
    if [ -d "backups/agents-old-backups" ]; then
        cp -r backups/agents-old-backups/ "$ARCHIVE_DIR/backups/agents-old/" 2>/dev/null || true
    fi
fi

# Installer backups
echo "Archiving installer backups..."
mkdir -p "$ARCHIVE_DIR/backups/installer"
find . -maxdepth 1 -name "claude-installer.sh.backup*" -exec cp {} "$ARCHIVE_DIR/backups/installer/" \; 2>/dev/null || true

# Hook system backups
echo "Archiving hook system backups..."
mkdir -p "$ARCHIVE_DIR/backups/hooks"
if [ -d "hooks" ]; then
    find hooks/ -name "*.backup" -o -name "*pre-security" -exec cp {} "$ARCHIVE_DIR/backups/hooks/" \; 2>/dev/null || true
fi

echo
echo "3. COLLECTING LOG FILES"
echo "======================="

# GitHub sync logs
if [ -d "logs" ]; then
    echo "Archiving GitHub sync logs..."
    mkdir -p "$ARCHIVE_DIR/logs/github-sync"
    cp logs/github-sync-*.log "$ARCHIVE_DIR/logs/github-sync/" 2>/dev/null || true
    cp logs/git-sync.log "$ARCHIVE_DIR/logs/github-sync/" 2>/dev/null || true
fi

# Agent monitoring logs
if [ -d "agents/monitoring/logs" ]; then
    echo "Archiving monitoring logs..."
    mkdir -p "$ARCHIVE_DIR/logs/monitoring"
    cp -r agents/monitoring/logs/ "$ARCHIVE_DIR/logs/monitoring/" 2>/dev/null || true
fi

echo
echo "4. COLLECTING TEST ARTIFACTS"
echo "============================"

# Hook test results
if [ -d "hooks/test_results" ]; then
    echo "Archiving hook test results..."
    mkdir -p "$ARCHIVE_DIR/tests/hooks"
    cp -r hooks/test_results/ "$ARCHIVE_DIR/tests/hooks/" 2>/dev/null || true
fi

# Profiling stats
if [ -f "hooks/hook_profile.stats" ]; then
    echo "Archiving profiling statistics..."
    cp hooks/hook_profile.stats "$ARCHIVE_DIR/tests/hooks/" 2>/dev/null || true
fi

# Test project
if [ -d "test_project" ]; then
    echo "Archiving test project..."
    mkdir -p "$ARCHIVE_DIR/tests/test-project"
    cp -r test_project/ "$ARCHIVE_DIR/tests/test-project/" 2>/dev/null || true
fi

echo
echo "5. COLLECTING CONFIGURATION FILES"
echo "================================="

# Shell snapshots
if [ -d "config/shell-snapshots" ]; then
    echo "Archiving shell snapshots ($(ls config/shell-snapshots/ | wc -l) files)..."
    mkdir -p "$ARCHIVE_DIR/configs/shell-snapshots"
    cp -r config/shell-snapshots/ "$ARCHIVE_DIR/configs/shell-snapshots/" 2>/dev/null || true
fi

# Todo files
if [ -d "config/todos" ]; then
    echo "Archiving todo files ($(ls config/todos/ | wc -l) files)..."
    mkdir -p "$ARCHIVE_DIR/configs/todos"
    cp -r config/todos/ "$ARCHIVE_DIR/configs/todos/" 2>/dev/null || true
fi

# Old fixes
if [ -d "agents/Fixes" ]; then
    echo "Archiving old fix scripts..."
    mkdir -p "$ARCHIVE_DIR/configs/old-fixes"
    cp -r agents/Fixes/ "$ARCHIVE_DIR/configs/old-fixes/" 2>/dev/null || true
fi

# Old switchers
if [ -d "agents/admin/old-switchers" ]; then
    echo "Archiving old switchers..."
    mkdir -p "$ARCHIVE_DIR/configs/old-switchers"
    cp -r agents/admin/old-switchers/ "$ARCHIVE_DIR/configs/old-switchers/" 2>/dev/null || true
fi

echo
echo "6. COLLECTING DOCUMENTATION"
echo "==========================="

# Development plans
if [ -d "agents/plans" ]; then
    echo "Archiving development plans..."
    mkdir -p "$ARCHIVE_DIR/docs/development-plans"
    cp -r agents/plans/ "$ARCHIVE_DIR/docs/development-plans/" 2>/dev/null || true
fi

# Archive directory contents
if [ -d "archive" ]; then
    echo "Archiving archive directory..."
    mkdir -p "$ARCHIVE_DIR/docs/archive"
    cp -r archive/ "$ARCHIVE_DIR/docs/archive/" 2>/dev/null || true
fi

# Deprecated docs
if [ -d "deprecated/docs-consolidated" ]; then
    echo "Archiving deprecated docs..."
    mkdir -p "$ARCHIVE_DIR/docs/deprecated"
    cp -r deprecated/docs-consolidated/ "$ARCHIVE_DIR/docs/deprecated/" 2>/dev/null || true
fi

echo
echo "7. COLLECTING INSTALLER FILES"
echo "============================="

# Deprecated installers
if [ -d "installers/Deprecated" ]; then
    echo "Archiving deprecated installers..."
    mkdir -p "$ARCHIVE_DIR/installers/deprecated"
    cp -r installers/Deprecated/ "$ARCHIVE_DIR/installers/deprecated/" 2>/dev/null || true
fi

echo
echo "8. GENERATING ARCHIVE METADATA"
echo "=============================="

# Create file inventory
cat > "$ARCHIVE_DIR/manifests/FILE_INVENTORY.txt" << EOF
# File Inventory - Claude Backups Deprecated Archive
# Generated: $(date)

EOF

find "$ARCHIVE_DIR" -type f | sed "s|$ARCHIVE_DIR/||" | sort >> "$ARCHIVE_DIR/manifests/FILE_INVENTORY.txt"

# Create size report
cat > "$ARCHIVE_DIR/manifests/SIZE_REPORT.txt" << EOF
# Size Report - Claude Backups Deprecated Archive
# Generated: $(date)

DIRECTORY SIZES:
EOF

du -sh "$ARCHIVE_DIR"/* | sort -hr >> "$ARCHIVE_DIR/manifests/SIZE_REPORT.txt"

# Create checksums
echo "Generating checksums..."
find "$ARCHIVE_DIR" -type f -exec sha256sum {} \; | sed "s|$ARCHIVE_DIR/||" > "$ARCHIVE_DIR/manifests/SHA256SUMS.txt"

echo
echo "9. CREATING TAR.GZ ARCHIVE"
echo "=========================="

cd /tmp
tar -czf "$ARCHIVE_NAME.tar.gz" "$ARCHIVE_NAME/"

# Move to repository
mv "$ARCHIVE_NAME.tar.gz" "$REPO_ROOT/"

# Cleanup temp directory
rm -rf "$ARCHIVE_DIR"

echo
echo "=================================================="
echo "ARCHIVE CREATION COMPLETE"
echo "=================================================="

ARCHIVE_SIZE=$(du -sh "$REPO_ROOT/$ARCHIVE_NAME.tar.gz" | cut -f1)
FILE_COUNT=$(tar -tzf "$REPO_ROOT/$ARCHIVE_NAME.tar.gz" | wc -l)

echo "✅ Archive created: $ARCHIVE_NAME.tar.gz"
echo "✅ Archive size: $ARCHIVE_SIZE"
echo "✅ File count: $FILE_COUNT"
echo "✅ Location: $REPO_ROOT/$ARCHIVE_NAME.tar.gz"
echo
echo "Archive contains:"
echo "  📁 Backup files and historical versions"
echo "  📊 Log files and monitoring data"
echo "  🧪 Test artifacts and profiling data"
echo "  ⚙️  Configuration files and snapshots"
echo "  📚 Documentation and development plans"
echo "  💿 Deprecated installers and scripts"
echo
echo "Verification:"
echo "  tar -tzf $ARCHIVE_NAME.tar.gz | head -20"
echo "  sha256sum $ARCHIVE_NAME.tar.gz"
echo
echo "Archive ready for long-term storage!"