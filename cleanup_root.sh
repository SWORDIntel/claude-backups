#!/bin/bash
# Aggressive root directory cleanup

set -e

echo "🧹 Cleaning up root directory..."

# Create directories
mkdir -p bin tests utilities maintenance network-tools learning-setup archive

# Move executables to bin/ (keep core ones)
echo "Moving main executables..."
for file in launch_hybrid_system.sh check_system_status.sh claude-installer.sh claude-wrapper-*.sh integrate_hybrid_bridge.sh bring-online switch status; do
    [ -f "$file" ] && mv "$file" bin/ && echo "Moved $file to bin/"
done

# Move all test files to tests/
echo "Moving test files..."
for pattern in "test_*" "test-*" "*test*" "validate_*" "verify-*" "quick_test.py"; do
    for file in $pattern; do
        [ -f "$file" ] && mv "$file" tests/ && echo "Moved $file to tests/"
    done
done

# Move utilities
echo "Moving utilities..."
for file in standardize-agents.py create-complete-registry.py fix-agent-registration.py enable-natural-invocation.sh pdf-text-extractor-tui.py organize_root_directory.sh; do
    [ -f "$file" ] && mv "$file" utilities/ && echo "Moved $file to utilities/"
done

# Move maintenance
echo "Moving maintenance files..."
for file in github-sync.sh apply-bash-output-fix.sh install-wrapper.sh fix-bash-output.patch; do
    [ -f "$file" ] && mv "$file" maintenance/ && echo "Moved $file to maintenance/"
done

# Move network tools
echo "Moving network tools..."
for file in advanced-network-fix.sh check-network-status.sh fix-wired-connection.sh switch-to-systemd-network.sh; do
    [ -f "$file" ] && mv "$file" network-tools/ && echo "Moved $file to network-tools/"
done

# Move learning setup
echo "Moving learning setup..."
for file in integrated_learning_setup.py learning_config_manager.py; do
    [ -f "$file" ] && mv "$file" learning-setup/ && echo "Moved $file to learning-setup/"
done

# Move documentation to archive
echo "Moving documentation..."
for pattern in "*_SUMMARY.md" "*_STATUS.md" "*_GUIDE.md" "files.txt" "all_md_agents.txt" "claude.md.txt"; do
    for file in $pattern; do
        [ -f "$file" ] && mv "$file" archive/ && echo "Moved $file to archive/"
    done
done

# Create convenient symlinks
echo "Creating symlinks..."
ln -sf bin/launch_hybrid_system.sh launch 2>/dev/null && echo "Created ./launch symlink"
ln -sf bin/check_system_status.sh status-check 2>/dev/null && echo "Created ./status-check symlink"
ln -sf bin/claude-installer.sh install 2>/dev/null && echo "Created ./install symlink"

echo "✅ Root directory cleanup complete!"
echo
echo "📁 Organized structure:"
echo "  bin/ - Main executables"
echo "  tests/ - All test scripts"  
echo "  utilities/ - Utility scripts"
echo "  maintenance/ - Maintenance tools"
echo "  network-tools/ - Network utilities"
echo "  learning-setup/ - Learning system setup"
echo "  archive/ - Documentation archive"
echo
echo "🔗 Quick access:"
echo "  ./launch - Launch system"
echo "  ./status-check - Check status"
echo "  ./install - Install system"