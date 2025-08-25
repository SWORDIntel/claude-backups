#!/bin/bash
# Restore Important Files to Root Directory

echo "🔄 Restoring important files to root directory..."

# Restore from bin/
echo "📂 Restoring from bin/..."
if [ -d "bin" ]; then
    for file in claude-installer.sh claude-wrapper-fixed.sh claude-wrapper-ultimate.sh integrate_hybrid_bridge.sh bring-online switch status launch_hybrid_system.sh check_system_status.sh; do
        if [ -f "bin/$file" ]; then
            mv "bin/$file" . && echo "  ✅ Restored $file"
        else
            echo "  ⚠️  $file not found in bin/"
        fi
    done
fi

# Restore from learning-setup/
echo "📂 Restoring from learning-setup/..."
if [ -d "learning-setup" ]; then
    for file in integrated_learning_setup.py learning_config_manager.py; do
        if [ -f "learning-setup/$file" ]; then
            mv "learning-setup/$file" . && echo "  ✅ Restored $file"
        fi
    done
fi

# Restore from maintenance/
echo "📂 Restoring from maintenance/..."
if [ -d "maintenance" ]; then
    for file in github-sync.sh; do
        if [ -f "maintenance/$file" ]; then
            mv "maintenance/$file" . && echo "  ✅ Restored $file"
        fi
    done
fi

# Restore from archive/
echo "📂 Restoring from archive/..."
if [ -d "archive" ]; then
    for file in HYBRID_INTEGRATION_STATUS.md FIRST_TIME_LAUNCH_GUIDE.md; do
        if [ -f "archive/$file" ]; then
            mv "archive/$file" . && echo "  ✅ Restored $file"
        fi
    done
fi

# Update symlinks to point to root files
echo "🔗 Updating symlinks..."
rm -f launch status-check install 2>/dev/null
ln -sf launch_hybrid_system.sh launch && echo "  ✅ Updated ./launch symlink"
ln -sf check_system_status.sh status-check && echo "  ✅ Updated ./status-check symlink"
ln -sf claude-installer.sh install && echo "  ✅ Updated ./install symlink"

echo
echo "✅ Important files restored to root!"
echo
echo "📋 Files now in root:"
ls -la *.sh *.py 2>/dev/null | grep -E "(claude-|launch|check|integrate|bring|switch|status|learning|github)" || echo "  No matching files found"
echo
echo "🎯 Ready to use:"
echo "  ./launch - Launch system"
echo "  ./status-check - Check status" 
echo "  ./install - Install system"
echo "  ./claude-installer.sh - Main installer"
echo "  ./integrate_hybrid_bridge.sh - Integration script"