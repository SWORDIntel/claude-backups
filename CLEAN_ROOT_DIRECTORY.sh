#!/bin/bash
# Final root directory cleanup - creates the clean structure

set -e

echo "🧹 FINAL ROOT DIRECTORY CLEANUP"
echo "================================="

# Create all organizational directories
mkdir -p {bin,tests,utilities,maintenance,network-tools,learning-setup,archive}

echo "📁 Moving files to organized structure..."

# EXECUTABLES → bin/
echo "🚀 Executables → bin/"
for file in launch_hybrid_system.sh check_system_status.sh claude-installer.sh integrate_hybrid_bridge.sh bring-online switch status claude-wrapper-*.sh; do
    if [ -f "$file" ]; then
        mv "$file" bin/ && echo "  ✅ $file → bin/"
    fi
done

# TESTS → tests/
echo "🧪 Test files → tests/"
for file in test_*.* test-*.* *test*.py *test*.sh validate_*.sh verify-*.sh quick_test.py; do
    if [ -f "$file" ]; then
        mv "$file" tests/ && echo "  ✅ $file → tests/"
    fi
done

# UTILITIES → utilities/
echo "🔧 Utilities → utilities/"
for file in standardize-agents.py create-complete-registry.py fix-agent-registration.py enable-natural-invocation.sh pdf-text-extractor-tui.py organize_root_directory.sh cleanup_root.sh; do
    if [ -f "$file" ]; then
        mv "$file" utilities/ && echo "  ✅ $file → utilities/"
    fi
done

# MAINTENANCE → maintenance/
echo "🛠️  Maintenance → maintenance/"
for file in github-sync.sh apply-bash-output-fix.sh install-wrapper.sh fix-bash-output.patch; do
    if [ -f "$file" ]; then
        mv "$file" maintenance/ && echo "  ✅ $file → maintenance/"
    fi
done

# NETWORK TOOLS → network-tools/
echo "🌐 Network tools → network-tools/"
for file in advanced-network-fix.sh check-network-status.sh fix-wired-connection.sh switch-to-systemd-network.sh; do
    if [ -f "$file" ]; then
        mv "$file" network-tools/ && echo "  ✅ $file → network-tools/"
    fi
done

# LEARNING SETUP → learning-setup/
echo "🧠 Learning setup → learning-setup/"
for file in integrated_learning_setup.py learning_config_manager.py; do
    if [ -f "$file" ]; then
        mv "$file" learning-setup/ && echo "  ✅ $file → learning-setup/"
    fi
done

# DOCUMENTATION → archive/
echo "📚 Documentation → archive/"
for file in *_SUMMARY.md *_STATUS.md *_GUIDE.md TESTING_GUIDE.md VERIFICATION_REPORT.md files.txt all_md_agents.txt claude.md.txt; do
    if [ -f "$file" ]; then
        mv "$file" archive/ && echo "  ✅ $file → archive/"
    fi
done

# Create convenient symlinks in root
echo "🔗 Creating convenient symlinks..."
ln -sf bin/launch_hybrid_system.sh launch && echo "  ✅ ./launch → bin/launch_hybrid_system.sh"
ln -sf bin/check_system_status.sh status-check && echo "  ✅ ./status-check → bin/check_system_status.sh"
ln -sf bin/claude-installer.sh install && echo "  ✅ ./install → bin/claude-installer.sh"

# Show final clean structure
echo
echo "✅ ROOT DIRECTORY NOW ORGANIZED!"
echo "================================="
echo
echo "📁 Directory Structure:"
ls -la | grep "^d" | awk '{print "  📂 " $9}' | grep -v "^\.$\|^\.\.$"
echo
echo "📄 Core Files (staying in root):"
ls -la *.md *.yml *.json *.txt *.lua 2>/dev/null | awk '{print "  📄 " $9}' || echo "  (None)"
echo
echo "🔗 Quick Access Commands:"
echo "  ./launch           - Launch hybrid system"
echo "  ./status-check     - Check system status"
echo "  ./install          - Install system"
echo "  ./bin/             - All main executables"
echo "  ./tests/           - All test scripts"
echo "  ./utilities/       - Utility scripts"
echo
echo "🎉 Root directory is now clean and professional!"