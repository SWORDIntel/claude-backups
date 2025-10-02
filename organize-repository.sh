#!/bin/bash
# Repository Organization Script
# Organizes claude-backups into logical folder structure

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Repository Organization - Creating Folder Structure         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create all directories
echo -e "${BLUE}Creating directory structure...${NC}"

mkdir -p docs/{installation,deployment,reports,guides,status}
mkdir -p openvino/{scripts,deprecated}
mkdir -p installers/{claude,wrappers,kernel,system}
mkdir -p learning-system/{scripts,python,docker}
mkdir -p crypto
mkdir -p shadowgit
mkdir -p optimization
mkdir -p integration
mkdir -p deployment
mkdir -p testing/{installer,learning,portability,environment,other}
mkdir -p utilities
mkdir -p hardware/{bios,fixes}
mkdir -p docs-browser
mkdir -p legacy
mkdir -p archived-reports
mkdir -p config

echo -e "${GREEN}✅ Directory structure created${NC}"
echo ""

# Move documentation files
echo -e "${BLUE}Organizing documentation...${NC}"

# Installation docs
mv INSTALL.md docs/installation/ 2>/dev/null || true
mv INSTALLATION.md docs/installation/ 2>/dev/null || true
mv HEADLESS_INSTALL_GUIDE.md docs/installation/ 2>/dev/null || true
mv PYTHON_INSTALLER_README.md docs/installation/ 2>/dev/null || true
mv crypto_pow_implementation_guide.md docs/installation/ 2>/dev/null || true

# Deployment docs
mv DEPLOYMENT_REPORT_v3.1.md docs/deployment/ 2>/dev/null || true
mv TEAM_ALPHA_DEPLOYMENT_REPORT.md docs/deployment/ 2>/dev/null || true
mv TEAM_BETA_DEPLOYMENT_REPORT.md docs/deployment/ 2>/dev/null || true
mv phase3-complete-deployment-summary.md docs/deployment/ 2>/dev/null || true

# Reports
mv COORDINATION_EXECUTION_REPORT.md docs/reports/ 2>/dev/null || true
mv NPU_OPTIMIZATION_REPORT.md docs/reports/ 2>/dev/null || true
mv PORTABILITY_VALIDATION_REPORT.md docs/reports/ 2>/dev/null || true
mv TANDEM_ORCHESTRATOR_ANALYSIS_REPORT.md docs/reports/ 2>/dev/null || true
mv TODO_FILES_ATTRIBUTION_REPORT.md docs/reports/ 2>/dev/null || true

# Guides
mv ENVIRONMENT_DETECTION_GUIDE.md docs/guides/ 2>/dev/null || true
mv hybrid_npu_migration_strategy.md docs/guides/ 2>/dev/null || true
mv README_crypto_pow.md docs/guides/ 2>/dev/null || true

# Status
mv AUTO_UPDATE_SYSTEM_COMPLETE.md docs/status/ 2>/dev/null || true
mv CHECKPOINT_NEURAL_READY.md docs/status/ 2>/dev/null || true
mv LEARNING_SYSTEM_STATUS.md docs/status/ 2>/dev/null || true
mv SYSTEM_SPECS_2025-09-17.md docs/status/ 2>/dev/null || true

echo -e "${GREEN}✅ Documentation organized${NC}"

# Move OpenVINO files
echo -e "${BLUE}Organizing OpenVINO files...${NC}"

mv OPENVINO-STATUS.md openvino/ 2>/dev/null || true
mv BASHRC-SETUP-COMPLETE.md openvino/ 2>/dev/null || true
mv openvino-quick-test.sh openvino/scripts/ 2>/dev/null || true
mv openvino-diagnostic-complete.sh openvino/scripts/ 2>/dev/null || true
mv openvino-resolution.sh openvino/scripts/ 2>/dev/null || true
mv openvino-demo-inference.py openvino/scripts/ 2>/dev/null || true
mv setup-openvino-bashrc.sh openvino/scripts/ 2>/dev/null || true
mv fix-openvino-install.sh openvino/scripts/ 2>/dev/null || true
mv verify-openvino-complete.sh openvino/scripts/ 2>/dev/null || true
mv install-intel-opencl.sh openvino/deprecated/ 2>/dev/null || true

echo -e "${GREEN}✅ OpenVINO files organized${NC}"

# Move installer files
echo -e "${BLUE}Organizing installers...${NC}"

# Claude installers
mv claude-enhanced-installer.py installers/claude/ 2>/dev/null || true
mv claude-enhanced-installer-venv.py installers/claude/ 2>/dev/null || true
mv claude-installer-refactored.sh installers/claude/ 2>/dev/null || true
mv claude-installer.sh installers/claude/ 2>/dev/null || true
mv claude-python-installer.sh installers/claude/ 2>/dev/null || true
mv claude-venv-installer.sh installers/claude/ 2>/dev/null || true
mv claude_installer_config.py installers/claude/ 2>/dev/null || true

# Wrappers
mv claude-wrapper-ultimate.sh installers/wrappers/ 2>/dev/null || true
mv claude-wrapper-portable-fixed.sh installers/wrappers/ 2>/dev/null || true
mv claude-wrapper-portable.sh installers/wrappers/ 2>/dev/null || true
mv claude-wrapper-simple.sh installers/wrappers/ 2>/dev/null || true
mv install-enhanced-wrapper.sh installers/wrappers/ 2>/dev/null || true
mv install-portable-wrapper.sh installers/wrappers/ 2>/dev/null || true
mv install-wrapper-integration.sh installers/wrappers/ 2>/dev/null || true

# Kernel
mv build_complete_custom_kernel.sh installers/kernel/ 2>/dev/null || true
mv build_gna_npu_kernel.sh installers/kernel/ 2>/dev/null || true
mv build_zfs_and_kernel.sh installers/kernel/ 2>/dev/null || true
mv master_kernel_builder.sh installers/kernel/ 2>/dev/null || true
mv safe_kernel_build.sh installers/kernel/ 2>/dev/null || true
mv fix_zfs_and_kernel.sh installers/kernel/ 2>/dev/null || true
mv kernel_options_gna_npu.txt installers/kernel/ 2>/dev/null || true

# System
mv enable_all_accelerators.sh installers/system/ 2>/dev/null || true
mv enable_gna_npu.sh installers/system/ 2>/dev/null || true
mv setup-npu-distribution.sh installers/system/ 2>/dev/null || true
mv bootstrap-universal-database.sh installers/system/ 2>/dev/null || true

echo -e "${GREEN}✅ Installers organized${NC}"

# Move learning system files
echo -e "${BLUE}Organizing learning system...${NC}"

# Scripts
mv launch-learning-system.sh learning-system/scripts/ 2>/dev/null || true
mv enhanced_learning_system_manager.sh learning-system/scripts/ 2>/dev/null || true
mv run_learning_system_with_sudo.sh learning-system/scripts/ 2>/dev/null || true
mv configure_docker_learning_autostart.sh learning-system/scripts/ 2>/dev/null || true
mv claude-learning-hook.sh learning-system/scripts/ 2>/dev/null || true

# Python
mv integrated_learning_setup.py learning-system/python/ 2>/dev/null || true
mv learning_config_manager.py learning-system/python/ 2>/dev/null || true
mv learning_diagnostic.py learning-system/python/ 2>/dev/null || true
mv automated_learning_backup.py learning-system/python/ 2>/dev/null || true
mv fix_learning_session.py learning-system/python/ 2>/dev/null || true
mv sync_learning_data.py learning-system/python/ 2>/dev/null || true

# Docker
mv complete_docker_fix.sh learning-system/docker/ 2>/dev/null || true
mv fix_docker_permissions.sh learning-system/docker/ 2>/dev/null || true
mv test_docker_learning_integration.sh learning-system/docker/ 2>/dev/null || true

echo -e "${GREEN}✅ Learning system organized${NC}"

# Move crypto files
echo -e "${BLUE}Organizing crypto files...${NC}"

mv crypto_system_optimizer.py crypto/ 2>/dev/null || true
mv crypto_performance_monitor.py crypto/ 2>/dev/null || true
mv crypto_auto_start_optimizer.py crypto/ 2>/dev/null || true
mv crypto_analytics_dashboard.py crypto/ 2>/dev/null || true
mv deploy-token-optimization.sh crypto/ 2>/dev/null || true

echo -e "${GREEN}✅ Crypto files organized${NC}"

# Move shadowgit files
echo -e "${BLUE}Organizing ShadowGit files...${NC}"

mv shadowgit_accelerator.py shadowgit/ 2>/dev/null || true
mv shadowgit_phase3_unified.py shadowgit/ 2>/dev/null || true
mv shadowgit_global_handler.sh shadowgit/ 2>/dev/null || true
mv neural_git_accelerator.py shadowgit/ 2>/dev/null || true
mv deploy_shadowgit_phase3.sh shadowgit/ 2>/dev/null || true
mv analyze_shadowgit_performance.py shadowgit/ 2>/dev/null || true

echo -e "${GREEN}✅ ShadowGit files organized${NC}"

# Move optimization files
echo -e "${BLUE}Organizing optimization files...${NC}"

mv claude_universal_optimizer.py optimization/ 2>/dev/null || true
mv install-universal-optimizer.sh optimization/ 2>/dev/null || true
mv demo-optimizer-analysis.sh optimization/ 2>/dev/null || true
mv optimizer-summary.sh optimization/ 2>/dev/null || true
mv deploy_memory_optimization.sh optimization/ 2>/dev/null || true
mv test-critical-optimization.sh optimization/ 2>/dev/null || true

echo -e "${GREEN}✅ Optimization files organized${NC}"

# Move integration files
echo -e "${BLUE}Organizing integration files...${NC}"

mv claude_unified_integration.py integration/ 2>/dev/null || true
mv claude_shell_integration.py integration/ 2>/dev/null || true
mv install_unified_integration.sh integration/ 2>/dev/null || true
mv integrate_hybrid_bridge.sh integration/ 2>/dev/null || true
mv launch_hybrid_system.sh integration/ 2>/dev/null || true
mv agent_coordination_matrix.py integration/ 2>/dev/null || true
mv enable-natural-invocation.sh integration/ 2>/dev/null || true

echo -e "${GREEN}✅ Integration files organized${NC}"

# Move deployment files
echo -e "${BLUE}Organizing deployment files...${NC}"

mv phase1-complete.sh deployment/ 2>/dev/null || true
mv phase2-complete-deployment.sh deployment/ 2>/dev/null || true
mv phase2-deploy-trie-matcher.sh deployment/ 2>/dev/null || true
mv phase3-async-integration.py deployment/ 2>/dev/null || true
mv deployment_dashboard.py deployment/ 2>/dev/null || true
mv team_beta_hardware_acceleration.py deployment/ 2>/dev/null || true
mv team_beta_production_deployment.py deployment/ 2>/dev/null || true
mv director_solution.sh deployment/ 2>/dev/null || true

echo -e "${GREEN}✅ Deployment files organized${NC}"

# Move test files
echo -e "${BLUE}Organizing test files...${NC}"

# Installer tests
mv test-enhanced-wrapper.sh testing/installer/ 2>/dev/null || true
mv test-venv-installer.py testing/installer/ 2>/dev/null || true
mv test-installer-integration.sh testing/installer/ 2>/dev/null || true
mv test_installer_fix.py testing/installer/ 2>/dev/null || true
mv test-headless-install.py testing/installer/ 2>/dev/null || true

# Learning tests
mv test_learning_system_integration.sh testing/learning/ 2>/dev/null || true
mv test-docker-autostart.sh testing/learning/ 2>/dev/null || true
mv validate_docker_learning_integration.sh testing/learning/ 2>/dev/null || true

# Portability tests
mv validate_portability.py testing/portability/ 2>/dev/null || true
mv validate_portability_focused.py testing/portability/ 2>/dev/null || true
mv validate-portable-paths.sh testing/portability/ 2>/dev/null || true
mv validate_portable_paths.sh testing/portability/ 2>/dev/null || true
mv test-portable-paths.sh testing/portability/ 2>/dev/null || true
mv test-portable-wrapper.sh testing/portability/ 2>/dev/null || true

# Environment tests
mv test-environment-detection.py testing/environment/ 2>/dev/null || true
mv test-environment-simple.py testing/environment/ 2>/dev/null || true

# Other tests
mv test-enhanced-semantic-matching.py testing/other/ 2>/dev/null || true
mv test-debug.sh testing/other/ 2>/dev/null || true
mv test_avx512_cores.sh testing/other/ 2>/dev/null || true
mv phase2-orchestrator-test.py testing/other/ 2>/dev/null || true

echo -e "${GREEN}✅ Test files organized${NC}"

# Move utility files
echo -e "${BLUE}Organizing utilities...${NC}"

mv path_utilities.py utilities/ 2>/dev/null || true
mv fix_hardcoded_paths.py utilities/ 2>/dev/null || true
mv fix_hardcoded_paths_comprehensive.sh utilities/ 2>/dev/null || true
mv fix_project_name_references.py utilities/ 2>/dev/null || true
mv conflict_prediction_model.py utilities/ 2>/dev/null || true
mv check_system_status.sh utilities/ 2>/dev/null || true
mv organize_documentation.sh utilities/ 2>/dev/null || true
mv github-sync.sh utilities/ 2>/dev/null || true
mv emergency_cleanup.sh utilities/ 2>/dev/null || true
mv emergency_fix_packages.sh utilities/ 2>/dev/null || true
mv npu_installer_integration.py utilities/ 2>/dev/null || true

echo -e "${GREEN}✅ Utilities organized${NC}"

# Move hardware files
echo -e "${BLUE}Organizing hardware files...${NC}"

mv bios_downgrade_1.11.2.sh hardware/bios/ 2>/dev/null || true
mv bios_downgrade_safe.sh hardware/bios/ 2>/dev/null || true
mv prepare_recovery_usb.sh hardware/bios/ 2>/dev/null || true
mv fix_and_install_kernel.sh hardware/fixes/ 2>/dev/null || true
mv fix_learning_sudo.sh hardware/fixes/ 2>/dev/null || true

echo -e "${GREEN}✅ Hardware files organized${NC}"

# Move docs browser files
echo -e "${BLUE}Organizing docs browsers...${NC}"

mv launch-docs-browser.sh docs-browser/ 2>/dev/null || true
mv launch-docs-simple.sh docs-browser/ 2>/dev/null || true
mv launch-universal-docs.sh docs-browser/ 2>/dev/null || true
mv launch-phase3-optimizer.sh docs-browser/ 2>/dev/null || true

echo -e "${GREEN}✅ Docs browsers organized${NC}"

# Move legacy files
echo -e "${BLUE}Organizing legacy files...${NC}"

mv MOVEME.md legacy/ 2>/dev/null || true
mv tui-installer-optimizer.sh legacy/ 2>/dev/null || true
mv upgrade-to-python-installer.py legacy/ 2>/dev/null || true
mv analyze-implementation-status.py legacy/ 2>/dev/null || true

echo -e "${GREEN}✅ Legacy files organized${NC}"

# Move archived reports
echo -e "${BLUE}Organizing archived reports...${NC}"

mv phase1-completion-report.txt archived-reports/ 2>/dev/null || true
mv phase2-complete-report.txt archived-reports/ 2>/dev/null || true
mv phase2-completion-report.txt archived-reports/ 2>/dev/null || true
mv DOCKER_FIX_SUMMARY.md archived-reports/ 2>/dev/null || true
mv ENHANCED_INSTALLER_COMPLETE_FEATURES.md archived-reports/ 2>/dev/null || true
mv ENHANCED_WRAPPER_FIX_SUMMARY.md archived-reports/ 2>/dev/null || true
mv HARDCODED_PATHS_FIXED.md archived-reports/ 2>/dev/null || true
mv PATH_FIXES_SUMMARY.md archived-reports/ 2>/dev/null || true
mv PYTHON_INSTALLER_SUMMARY.md archived-reports/ 2>/dev/null || true
mv PYTHON_OPTIMIZATION_SUMMARY.md archived-reports/ 2>/dev/null || true
mv PROOFOFWORKCHECK.md archived-reports/ 2>/dev/null || true
mv CLAUDE_VENV_INSTALLER_SOLUTION.md archived-reports/ 2>/dev/null || true

echo -e "${GREEN}✅ Archived reports organized${NC}"

# Move config files
echo -e "${BLUE}Organizing config files...${NC}"

mv CLAUDE.md config/ 2>/dev/null || true
mv VERIF.md config/ 2>/dev/null || true
mv __init__.py config/ 2>/dev/null || true
mv requirements.txt config/ 2>/dev/null || true
mv MANIFEST.txt config/ 2>/dev/null || true

echo -e "${GREEN}✅ Config files organized${NC}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ✅ Repository Organization Complete                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Directory structure created successfully!"
echo "Files organized into logical folders."
echo ""
echo "Next: Review DIRECTORY-STRUCTURE.md for navigation guide"
