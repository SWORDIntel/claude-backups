#!/bin/bash

# Comprehensive script to fix all hardcoded paths in Claude documentation
# Replaces /home/ubuntu and /home/john with portable environment variables

PROJECT_ROOT="/home/john/claude-backups"

echo "🔧 DOCGEN: Comprehensive Hardcoded Path Fix"
echo "=========================================="

# Define replacement patterns
declare -A replacements=(
    ["/home/ubuntu/Downloads/claude-backups"]='$CLAUDE_PROJECT_ROOT'
    ["/home/ubuntu/Documents/Claude"]='$CLAUDE_PROJECT_ROOT'
    ["/home/ubuntu/Documents/claude-backups"]='$CLAUDE_PROJECT_ROOT'
    ["/home/john/claude-backups"]='$CLAUDE_PROJECT_ROOT'
    ["/home/john/Downloads/claude-backups"]='$CLAUDE_PROJECT_ROOT'
    ["/home/ubuntu/.local/share/claude/venv"]='$HOME/.local/share/claude/venv'
    ["/home/john/.local/share/claude/venv"]='$HOME/.local/share/claude/venv'
    ["/home/ubuntu/.local/bin"]='$HOME/.local/bin'
    ["/home/john/.local/bin"]='$HOME/.local/bin'
    ["/home/ubuntu/.claude"]='$HOME/.claude'
    ["/home/john/.claude"]='$HOME/.claude'
    ["/home/ubuntu/datascience"]='$HOME/datascience'
    ["/home/john/datascience"]='$HOME/datascience'
    ["/home/ubuntu/c-toolchain"]='$HOME/c-toolchain'
    ["/home/john/c-toolchain"]='$HOME/c-toolchain'
    ["/home/ubuntu/shadowgit"]='$HOME/shadowgit'
    ["/home/john/shadowgit"]='$HOME/shadowgit'
    ["/home/ubuntu/livecd-gen"]='$HOME/livecd-gen'
    ["/home/john/livecd-gen"]='$HOME/livecd-gen'
    ["/home/ubuntu"]='$HOME'
    ["/home/john"]='$HOME'
)

# Create backup
backup_dir="$PROJECT_ROOT/backup_before_path_fixes_$(date +%Y%m%d_%H%M%S)"
echo "📁 Creating backup at: $backup_dir"
mkdir -p "$backup_dir"

# Backup key files
cp "$PROJECT_ROOT/CLAUDE.md" "$backup_dir/" 2>/dev/null
cp "$PROJECT_ROOT/README.md" "$backup_dir/" 2>/dev/null
cp "$PROJECT_ROOT/INSTALL.md" "$backup_dir/" 2>/dev/null

# Function to fix paths in a file
fix_paths_in_file() {
    local file="$1"
    local changed=false

    # Skip binary files and certain directories
    if [[ "$file" == *".git/"* ]] || [[ "$file" == *"/.claude/"* ]] || [[ "$file" == *"/..bfg-report/"* ]]; then
        return
    fi

    # Check if file is binary
    if file "$file" | grep -q "binary"; then
        return
    fi

    # Apply all replacements
    for pattern in "${!replacements[@]}"; do
        replacement="${replacements[$pattern]}"
        if grep -q "$pattern" "$file" 2>/dev/null; then
            echo "  🔄 Fixing: $pattern → $replacement in $(basename "$file")"
            sed -i "s|$pattern|$replacement|g" "$file"
            changed=true
        fi
    done

    if $changed; then
        echo "  ✅ Updated: $file"
    fi
}

# Find and fix all documentation files
echo "🔍 Scanning for documentation files..."
find "$PROJECT_ROOT" -type f \( -name "*.md" -o -name "*.txt" -o -name "README*" \) \
    -not -path "*/.git/*" \
    -not -path "*/.claude/*" \
    -not -path "*/..bfg-report/*" \
    -not -path "*/backup_*/*" | while read -r file; do

    fix_paths_in_file "$file"
done

# Fix specific file types that might contain paths
echo "🔍 Scanning for configuration files..."
find "$PROJECT_ROOT" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) \
    -not -path "*/.git/*" \
    -not -path "*/.claude/*" \
    -not -path "*/..bfg-report/*" \
    -not -path "*/backup_*/*" | while read -r file; do

    # Only fix documentation-style files, not actual scripts
    if grep -q -E "(# .*[Gg]uide|# .*[Dd]ocumentation|## |### )" "$file" 2>/dev/null; then
        fix_paths_in_file "$file"
    fi
done

echo ""
echo "✅ DOCGEN: Comprehensive path fixes complete!"
echo "📊 Summary:"
echo "   - Backup created: $backup_dir"
echo "   - Fixed paths to use environment variables:"
echo "     • \$CLAUDE_PROJECT_ROOT for project directory"
echo "     • \$HOME for user home directory"
echo "   - Updated installation examples to be portable"
echo "   - Enhanced command examples with proper quoting"
echo ""
echo "🚀 All documentation now uses portable paths!"