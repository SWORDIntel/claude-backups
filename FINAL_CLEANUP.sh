#!/bin/bash
# FINAL AGGRESSIVE CLEANUP - Root directory organization

echo "🧹 FINAL ROOT DIRECTORY CLEANUP (AGGRESSIVE)"
echo "=============================================="

# Create directories
mkdir -p bin tests utilities maintenance network-tools learning-setup archive

# FORCE MOVE FILES (explicit list to avoid wildcards issues)

echo "📁 Moving executables to bin/..."
for file in launch_hybrid_system.sh check_system_status.sh claude-installer.sh claude-wrapper-fixed.sh claude-wrapper-ultimate.sh integrate_hybrid_bridge.sh bring-online switch status; do
    [ -f "$file" ] && { mv "$file" bin/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving test files to tests/..."
files_to_move=(
    "test-agent-registration.py"
    "test-agent-registration.sh"
    "test-bash-output.sh"
    "test-installer-integration.sh"
    "test-registration-manual.py"
    "test-wrapper-venv.sh"
    "test-wrapper.sh"
    "test_fixes.py"
    "test_hybrid_integration.py"
    "test_with_venv.sh"
    "test_wrapper_functions.sh"
    "validate_docker_fixes.sh"
    "verify-installation.sh"
    "verify-no-functionality-lost.sh"
    "quick_test.py"
)
for file in "${files_to_move[@]}"; do
    [ -f "$file" ] && { mv "$file" tests/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving utilities to utilities/..."
utility_files=(
    "standardize-agents.py"
    "create-complete-registry.py"
    "fix-agent-registration.py"
    "enable-natural-invocation.sh"
    "pdf-text-extractor-tui.py"
    "organize_root_directory.sh"
    "cleanup_root.sh"
    "CLEAN_ROOT_DIRECTORY.sh"
)
for file in "${utility_files[@]}"; do
    [ -f "$file" ] && { mv "$file" utilities/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving maintenance files to maintenance/..."
maintenance_files=(
    "github-sync.sh"
    "apply-bash-output-fix.sh"
    "install-wrapper.sh"
    "fix-bash-output.patch"
)
for file in "${maintenance_files[@]}"; do
    [ -f "$file" ] && { mv "$file" maintenance/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving network tools to network-tools/..."
network_files=(
    "advanced-network-fix.sh"
    "check-network-status.sh"
    "fix-wired-connection.sh"
    "switch-to-systemd-network.sh"
)
for file in "${network_files[@]}"; do
    [ -f "$file" ] && { mv "$file" network-tools/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving learning setup to learning-setup/..."
learning_files=(
    "integrated_learning_setup.py"
    "learning_config_manager.py"
)
for file in "${learning_files[@]}"; do
    [ -f "$file" ] && { mv "$file" learning-setup/ 2>/dev/null || true; echo "  → $file"; }
done

echo "📁 Moving documentation to archive/..."
doc_files=(
    "BASH_OUTPUT_FIX_SUMMARY.md"
    "DOCKER_FIXES_SUMMARY.md"
    "FIRST_TIME_LAUNCH_GUIDE.md"
    "HYBRID_INTEGRATION_STATUS.md"
    "README_COMPLETE.md"
    "README_CONTAINERIZED_SYSTEM.md"
    "TESTING_GUIDE.md"
    "VERIFICATION_REPORT.md"
    "files.txt"
    "all_md_agents.txt"
    "claude.md.txt"
)
for file in "${doc_files[@]}"; do
    [ -f "$file" ] && { mv "$file" archive/ 2>/dev/null || true; echo "  → $file"; }
done

# Create symlinks
echo "🔗 Creating convenience symlinks..."
ln -sf bin/launch_hybrid_system.sh launch 2>/dev/null && echo "  → ./launch"
ln -sf bin/check_system_status.sh status-check 2>/dev/null && echo "  → ./status-check" 
ln -sf bin/claude-installer.sh install 2>/dev/null && echo "  → ./install"

echo
echo "✅ ROOT DIRECTORY CLEANUP COMPLETE!"
echo
echo "📂 Clean Structure Created:"
ls -d */ 2>/dev/null | head -20
echo
echo "📄 Remaining in root (core files only):"
ls -la *.md *.yml *.json *.lua 2>/dev/null | wc -l | xargs echo "  Core files:"
echo
echo "🔗 Quick access commands:"
echo "  ./launch       - Launch system"
echo "  ./status-check - Check status"
echo "  ./install      - Install system"