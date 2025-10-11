#!/bin/bash
#
# Python Root Directory Cleanup Script
# Categorizes and moves 107 orphaned root-level Python files
# Generated: 2025-10-11
#
# IMPORTANT: Review CLEANUP_CATEGORIZATION.md before running!
#
# Usage:
#   bash execute_cleanup.sh [--dry-run]
#

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No files will be moved"
    echo ""
fi

# Function to execute or display command
run_cmd() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        echo "▶ $*"
        "$@"
    fi
}

echo "=============================================="
echo " Python Root Cleanup - File Reorganization"
echo "=============================================="
echo "Working directory: $SCRIPT_DIR"
echo "Total files to process: 107"
echo ""

# ========================================
# PHASE 1: Create Archive Directories
# ========================================
echo "📁 PHASE 1: Creating archive directories..."
run_cmd mkdir -p deprecated/demos
run_cmd mkdir -p deprecated/test_files
run_cmd mkdir -p deprecated/installers_old
run_cmd mkdir -p deprecated/reorganize_scripts
run_cmd mkdir -p deprecated/unused_root

echo "✓ Archive directories created"
echo ""

# ========================================
# PHASE 2: Create Package Directories
# ========================================
echo "📦 PHASE 2: Creating claude_agents package directories..."
run_cmd mkdir -p claude_agents/implementations/specialized
run_cmd mkdir -p claude_agents/implementations/language
run_cmd mkdir -p claude_agents/implementations/security
run_cmd mkdir -p claude_agents/orchestration
run_cmd mkdir -p claude_agents/learning
run_cmd mkdir -p claude_agents/think_mode
run_cmd mkdir -p claude_agents/performance
run_cmd mkdir -p claude_agents/integration
run_cmd mkdir -p claude_agents/npu
run_cmd mkdir -p claude_agents/hardware
run_cmd mkdir -p claude_agents/git
run_cmd mkdir -p claude_agents/bridges
run_cmd mkdir -p claude_agents/security
run_cmd mkdir -p claude_agents/utils
run_cmd mkdir -p claude_agents/analysis

echo "✓ Package directories created"
echo ""

# ========================================
# PHASE 3: KEEP IN ROOT (8 files)
# ========================================
echo "📌 PHASE 3: Files kept in root..."
echo "  - npu_accelerated_orchestrator.py (primary orchestrator)"
echo "  - npu_orchestrator_launcher.py (launcher)"
echo "  - production_orchestrator_optimized.py"
echo "  - unified_orchestrator_system.py"
echo "  - auto_calibrating_think_mode.py (ACTIVE - recently modified)"
echo "  - lightweight_think_mode_selector.py (imported by auto_calibrating)"
echo "  - think_mode_auto_calibration.py"
echo "  - import_helper.py"
echo "✓ 8 files remain in root"
echo ""

# ========================================
# PHASE 4: MOVE TO claude_agents/ (43 files)
# ========================================
echo "📦 PHASE 4: Moving files to claude_agents package..."

# Agent implementations
echo "  Moving agent implementations..."
run_cmd mv -v agentsmith_impl.py claude_agents/implementations/specialized/ || true
run_cmd mv -v julia_internal_agent_impl.py claude_agents/implementations/language/ || true
run_cmd mv -v DISASSEMBLER_impl.py claude_agents/implementations/security/ || true

# Orchestration systems
echo "  Moving orchestration systems..."
run_cmd mv -v dynamic_orchestrator_launcher.py claude_agents/orchestration/ || true
run_cmd mv -v multi_agent_workflow_engine.py claude_agents/orchestration/ || true
run_cmd mv -v enhanced_coordination_matrix.py claude_agents/orchestration/ || true
run_cmd mv -v team_gamma_integration_bridge.py claude_agents/orchestration/ || true
run_cmd mv -v team_gamma_ml_engine.py claude_agents/orchestration/ || true

# Learning & analytics
echo "  Moving learning & analytics systems..."
run_cmd mv -v advanced_learning_analytics.py claude_agents/learning/ || true
run_cmd mv -v enhanced_learning_collector.py claude_agents/learning/ || true
run_cmd mv -v enterprise_learning_orchestrator.py claude_agents/learning/ || true
run_cmd mv -v postgresql_learning_system.py claude_agents/learning/ || true
run_cmd mv -v postgresql_performance_monitor.py claude_agents/learning/ || true

# Think mode variants
echo "  Moving think mode selectors..."
run_cmd mv -v dynamic_think_mode_selector.py claude_agents/think_mode/ || true
run_cmd mv -v enhanced_dynamic_think_mode_selector.py claude_agents/think_mode/ || true

# Performance & optimization
echo "  Moving performance systems..."
run_cmd mv -v token_optimizer.py claude_agents/performance/ || true
run_cmd mv -v unified_async_optimization_pipeline.py claude_agents/performance/ || true
run_cmd mv -v integrated_context_optimizer.py claude_agents/performance/ || true
run_cmd mv -v intelligent_context_chopper.py claude_agents/performance/ || true

# Integration systems
echo "  Moving integration systems..."
run_cmd mv -v claude_code_integration_hub.py claude_agents/integration/ || true
run_cmd mv -v claude_code_think_hooks.py claude_agents/integration/ || true
run_cmd mv -v claude_execution_tracker.py claude_agents/integration/ || true
run_cmd mv -v claude_rejection_reducer.py claude_agents/integration/ || true
run_cmd mv -v ultrathink_system_integration.py claude_agents/integration/ || true
run_cmd mv -v claude_npu_installer_integration.py claude_agents/integration/ || true

# NPU systems
echo "  Moving NPU systems..."
run_cmd mv -v npu_orchestrator_bridge.py claude_agents/npu/ || true
run_cmd mv -v npu_orchestrator_real.py claude_agents/npu/ || true
run_cmd mv -v npu_orchestrator_ultimate.py claude_agents/npu/ || true
run_cmd mv -v npu_optimized_final.py claude_agents/npu/ || true
run_cmd mv -v intel_npu_async_pipeline.py claude_agents/npu/ || true
run_cmd mv -v intel_npu_hardware_detector.py claude_agents/npu/ || true
run_cmd mv -v npu_performance_validation.py claude_agents/npu/ || true
run_cmd mv -v npu_performance_intelligence.py claude_agents/npu/ || true
run_cmd mv -v npu_production_monitor.py claude_agents/npu/ || true
run_cmd mv -v npu_release_manager.py claude_agents/npu/ || true

# Hardware detection
echo "  Moving hardware systems..."
run_cmd mv -v hardware_detection_unified.py claude_agents/hardware/ || true
run_cmd mv -v cpu_orchestrator_fallback.py claude_agents/hardware/ || true
run_cmd mv -v avx512_vectorizer.py claude_agents/hardware/ || true
run_cmd mv -v avx2_vector_operations.py claude_agents/hardware/ || true

# Git intelligence
echo "  Moving git systems..."
run_cmd mv -v git_intelligence_engine.py claude_agents/git/ || true
run_cmd mv -v neural_git_accelerator.py claude_agents/git/ || true
run_cmd mv -v conflict_predictor.py claude_agents/git/ || true
run_cmd mv -v smart_merge_suggester.py claude_agents/git/ || true

# Bridges
echo "  Moving bridge systems..."
run_cmd mv -v io_uring_bridge.py claude_agents/bridges/ || true

# Security & crypto
echo "  Moving security systems..."
run_cmd mv -v cryptographic_proof_of_work_verifier.py claude_agents/security/ || true
run_cmd mv -v cryptd_testing_framework.py claude_agents/security/ || true
run_cmd mv -v cryptd_automation_workflows.py claude_agents/security/ || true

# Utils
echo "  Moving utilities..."
run_cmd mv -v agent_path_resolver.py claude_agents/utils/ || true
run_cmd mv -v agent_template_factory.py claude_agents/utils/ || true
run_cmd mv -v trie_keyword_matcher.py claude_agents/utils/ || true
run_cmd mv -v multilevel_cache_system.py claude_agents/utils/ || true
run_cmd mv -v secure_database_wrapper.py claude_agents/utils/ || true
run_cmd mv -v permission_fallback_system.py claude_agents/utils/ || true
run_cmd mv -v enhanced_trigger_system.py claude_agents/utils/ || true

# Analysis
echo "  Moving analysis tools..."
run_cmd mv -v neural_code_reviewer.py claude_agents/analysis/ || true
run_cmd mv -v rejection_reduction_optimizer.py claude_agents/analysis/ || true
run_cmd mv -v rejection_reduction_integration.py claude_agents/analysis/ || true

echo "✓ Moved 43 files to claude_agents/"
echo ""

# ========================================
# PHASE 5: ARCHIVE - Demos (13 files)
# ========================================
echo "📦 PHASE 5: Archiving demo files..."
run_cmd mv -v demo_shadowgit_max_performance.py deprecated/demos/ || true
run_cmd mv -v cache_system_demo.py deprecated/demos/ || true
run_cmd mv -v git_intelligence_demo.py deprecated/demos/ || true
run_cmd mv -v quick_orchestrator_demo.py deprecated/demos/ || true
run_cmd mv -v quick_cache_validation.py deprecated/demos/ || true
run_cmd mv -v npu_demonstration.py deprecated/demos/ || true
run_cmd mv -v npu_integration_example.py deprecated/demos/ || true
run_cmd mv -v npu_baseline_test.py deprecated/demos/ || true
run_cmd mv -v npu_benchmark_comparison.py deprecated/demos/ || true
run_cmd mv -v npu_cv_pipeline.py deprecated/demos/ || true
run_cmd mv -v cache_performance_benchmark.py deprecated/demos/ || true
run_cmd mv -v trie_performance_test.py deprecated/demos/ || true
run_cmd mv -v performance_integration_guide.py deprecated/demos/ || true
echo "✓ Archived 13 demo files"
echo ""

# ========================================
# PHASE 6: ARCHIVE - Test Files (10 files)
# ========================================
echo "📦 PHASE 6: Archiving test files..."
run_cmd mv -v test_disassembler_security.py deprecated/test_files/ || true
run_cmd mv -v test_enterprise_learning.py deprecated/test_files/ || true
run_cmd mv -v test_json_internal.py deprecated/test_files/ || true
run_cmd mv -v test_npu_acceleration.py deprecated/test_files/ || true
run_cmd mv -v test_npu_launcher_system.py deprecated/test_files/ || true
run_cmd mv -v test_pipeline_core.py deprecated/test_files/ || true
run_cmd mv -v test_shadowgit_bridge_integration.py deprecated/test_files/ || true
run_cmd mv -v test_shadowgit_max_performance.py deprecated/test_files/ || true
run_cmd mv -v test_unified_pipeline_performance.py deprecated/test_files/ || true
run_cmd mv -v integrated_systems_test.py deprecated/test_files/ || true
echo "✓ Archived 10 test files"
echo ""

# ========================================
# PHASE 7: ARCHIVE - Old Installers (12 files)
# ========================================
echo "📦 PHASE 7: Archiving old installer scripts..."
run_cmd mv -v deploy_auto_calibration_system.py deprecated/installers_old/ || true
run_cmd mv -v setup_unified_optimization.py deprecated/installers_old/ || true
run_cmd mv -v install_npu_acceleration.py deprecated/installers_old/ || true
run_cmd mv -v initialize_git_intelligence.py deprecated/installers_old/ || true
run_cmd mv -v docker_calibration_integration.py deprecated/installers_old/ || true
run_cmd mv -v npu_binary_installer.py deprecated/installers_old/ || true
run_cmd mv -v npu_binary_distribution_coordinator.py deprecated/installers_old/ || true
run_cmd mv -v npu_constructor_integration.py deprecated/installers_old/ || true
run_cmd mv -v npu_coordination_bridge.py deprecated/installers_old/ || true
run_cmd mv -v npu_installation_error_handler.py deprecated/installers_old/ || true
run_cmd mv -v npu_fallback_compiler.py deprecated/installers_old/ || true
run_cmd mv -v production_agent_instrumentation.py deprecated/installers_old/ || true
echo "✓ Archived 12 installer files"
echo ""

# ========================================
# PHASE 8: ARCHIVE - Reorganize Scripts (5 files)
# ========================================
echo "📦 PHASE 8: Archiving reorganization scripts..."
run_cmd mv -v reorganize_master.py deprecated/reorganize_scripts/ || true
run_cmd mv -v reorganize_step1_backup.py deprecated/reorganize_scripts/ || true
run_cmd mv -v reorganize_step2_move.py deprecated/reorganize_scripts/ || true
run_cmd mv -v reorganize_step3_update.py deprecated/reorganize_scripts/ || true
run_cmd mv -v reorganize_structure.py deprecated/reorganize_scripts/ || true
echo "✓ Archived 5 reorganization scripts"
echo ""

# ========================================
# PHASE 9: Summary
# ========================================
echo "=============================================="
echo " Cleanup Complete!"
echo "=============================================="
echo ""
echo "Summary:"
echo "  ✓ Kept in root: 8 files"
echo "  ✓ Moved to claude_agents/: 43 files"
echo "  ✓ Archived to deprecated/: 56 files"
echo "    - demos/: 13 files"
echo "    - test_files/: 10 files"
echo "    - installers_old/: 12 files"
echo "    - reorganize_scripts/: 5 files"
echo ""
echo "Next steps:"
echo "  1. Review moved files in new locations"
echo "  2. Update import statements (see CLEANUP_CATEGORIZATION.md)"
echo "  3. Test core functionality"
echo "  4. Update documentation"
echo ""

if $DRY_RUN; then
    echo "🔍 This was a DRY RUN - no files were actually moved"
    echo "   Run without --dry-run to execute moves"
else
    echo "✅ All file moves completed successfully!"
fi

echo "=============================================="
