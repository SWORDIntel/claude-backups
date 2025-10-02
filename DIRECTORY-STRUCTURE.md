# Directory Structure Guide

**Repository**: claude-backups
**Organization Date**: October 2, 2025
**System**: Intel Meteor Lake (Core Ultra 7 165H)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Navigation](#quick-navigation)
- [Directory Listing](#complete-directory-listing)
- [File Counts](#file-statistics)

---

## Overview

The repository is organized into **16 main categories**, each containing related files and subdirectories for easy navigation and maintenance.

### Organization Principles

1. **Functional grouping** - Related files together
2. **Clear naming** - Self-explanatory directory names
3. **Logical hierarchy** - Subdirectories for sub-categories
4. **Separation of concerns** - Tests, docs, code separated

---

## Quick Navigation

### 🚀 Start Here

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| **[openvino/](#openvino)** | GPU/CPU acceleration | `openvino-quick-test.sh`, `setup-openvino-bashrc.sh` |
| **[installers/](#installers)** | Installation scripts | `claude-enhanced-installer.py` |
| **[docs/](#docs)** | Documentation | Installation guides, reports, guides |

### 🔧 Development

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| **[testing/](#testing)** | Test suites | Installer, learning, portability tests |
| **[utilities/](#utilities)** | Helper tools | Path utilities, system checks |
| **[deployment/](#deployment)** | Production deployment | Phase 1-3 deployment scripts |

### 🧠 Advanced Features

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| **[learning-system/](#learning-system)** | AI learning | Learning scripts, Docker configs |
| **[crypto/](#crypto)** | Crypto optimization | System optimizers, dashboards |
| **[shadowgit/](#shadowgit)** | Git acceleration | Neural git accelerator |
| **[optimization/](#optimization)** | Performance tuning | Universal optimizer |

### 📚 Reference

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| **[config/](#config)** | Configuration | CLAUDE.md, requirements.txt |
| **[archived-reports/](#archived-reports)** | Historical data | Old reports and summaries |
| **[legacy/](#legacy)** | Deprecated files | Old implementations |

---

## Complete Directory Listing

### openvino/

**Purpose**: OpenVINO GPU/CPU/NPU acceleration for Intel Meteor Lake

```
openvino/
├── README.md                          # OpenVINO documentation
├── OPENVINO-STATUS.md                 # Current status and benchmarks
├── BASHRC-SETUP-COMPLETE.md           # Bashrc configuration guide
├── scripts/                            # Executable scripts
│   ├── openvino-quick-test.sh         # Fast verification (4.1KB)
│   ├── openvino-diagnostic-complete.sh # Full diagnostic (23KB)
│   ├── openvino-resolution.sh         # Auto-installer/fixer (19KB)
│   ├── openvino-demo-inference.py     # Performance benchmarks (5.9KB)
│   ├── setup-openvino-bashrc.sh       # Bashrc setup (7.0KB)
│   ├── fix-openvino-install.sh        # Installation fixes (3.1KB)
│   └── verify-openvino-complete.sh    # Complete verification (9.3KB)
└── deprecated/                         # Deprecated scripts
    └── install-intel-opencl.sh        # Old OpenCL installer (1.3KB)
```

**Quick Start**:
```bash
cd openvino/scripts
./openvino-quick-test.sh              # Test current setup
./setup-openvino-bashrc.sh            # Enable auto-load
```

**Status**: ✅ Fully functional (CPU: 19,330 FPS, GPU: 440 FPS)

---

### installers/

**Purpose**: Installation scripts for Claude, system components, and kernels

```
installers/
├── claude/                             # Claude-specific installers
│   ├── claude-enhanced-installer.py   # Main Python installer (124KB)
│   ├── claude-enhanced-installer-venv.py # Venv version (21KB)
│   ├── claude-installer-refactored.sh # Refactored bash (35KB)
│   ├── claude-installer.sh            # Simple bash installer (2.9KB)
│   ├── claude-python-installer.sh     # Python wrapper (7.0KB)
│   ├── claude-venv-installer.sh       # Venv installer (8.7KB)
│   └── claude_installer_config.py     # Configuration (16KB)
│
├── wrappers/                           # Claude wrapper scripts
│   ├── claude-wrapper-ultimate.sh     # Full-featured (30KB)
│   ├── claude-wrapper-portable-fixed.sh # Portable fixed (8.6KB)
│   ├── claude-wrapper-portable.sh     # Portable original (15KB)
│   ├── claude-wrapper-simple.sh       # Minimal wrapper (8.6KB)
│   ├── install-enhanced-wrapper.sh    # Enhanced installer (4.7KB)
│   ├── install-portable-wrapper.sh    # Portable installer (3.5KB)
│   └── install-wrapper-integration.sh # Integration script (28KB)
│
├── kernel/                             # Kernel building scripts
│   ├── build_complete_custom_kernel.sh # Complete build (7.5KB)
│   ├── build_gna_npu_kernel.sh        # GNA/NPU kernel (4.0KB)
│   ├── build_zfs_and_kernel.sh        # ZFS + kernel (4.6KB)
│   ├── master_kernel_builder.sh       # Master builder (11KB)
│   ├── safe_kernel_build.sh           # Safe build (6.3KB)
│   ├── fix_zfs_and_kernel.sh          # ZFS fixes (5.4KB)
│   └── kernel_options_gna_npu.txt     # Kernel config options (3.1KB)
│
└── system/                             # System-level installers
    ├── enable_all_accelerators.sh     # Enable GPU/NPU/GNA (8.1KB)
    ├── enable_gna_npu.sh              # Enable NPU (3.5KB)
    ├── setup-npu-distribution.sh      # NPU setup (8.6KB)
    └── bootstrap-universal-database.sh # Database bootstrap (4.3KB)
```

**Quick Start**:
```bash
cd installers/claude
./claude-enhanced-installer.py        # Main installer
```

---

### learning-system/

**Purpose**: AI learning and training infrastructure

```
learning-system/
├── README.md                           # Learning system documentation
├── scripts/                            # Management scripts
│   ├── launch-learning-system.sh      # Launch system (15KB)
│   ├── enhanced_learning_system_manager.sh # Manager (9.2KB)
│   ├── run_learning_system_with_sudo.sh # Sudo wrapper (4.7KB)
│   ├── configure_docker_learning_autostart.sh # Docker config (8.3KB)
│   └── claude-learning-hook.sh        # Hook integration (4.0KB)
│
├── python/                             # Python modules
│   ├── integrated_learning_setup.py   # Setup system (39KB)
│   ├── learning_config_manager.py     # Configuration (31KB)
│   ├── learning_diagnostic.py         # Diagnostics (10KB)
│   ├── automated_learning_backup.py   # Backup system (17KB)
│   ├── fix_learning_session.py        # Session fixes (8.8KB)
│   └── sync_learning_data.py          # Data sync (7.6KB)
│
└── docker/                             # Docker integration
    ├── complete_docker_fix.sh         # Docker fixes (6.0KB)
    ├── fix_docker_permissions.sh      # Permission fixes (1.5KB)
    └── test_docker_learning_integration.sh # Integration test (9.1KB)
```

**Quick Start**:
```bash
cd learning-system/scripts
./launch-learning-system.sh           # Start learning system
```

---

### crypto/

**Purpose**: Cryptocurrency optimization and monitoring

```
crypto/
├── README.md                           # Crypto optimization guide
├── crypto_system_optimizer.py         # System optimizer (16KB)
├── crypto_performance_monitor.py      # Performance monitor (11KB)
├── crypto_auto_start_optimizer.py     # Auto-start optimizer (13KB)
├── crypto_analytics_dashboard.py      # Analytics dashboard (16KB)
└── deploy-token-optimization.sh       # Token deployment (8.8KB)
```

---

### shadowgit/

**Purpose**: Git operations with neural acceleration

```
shadowgit/
├── README.md                           # ShadowGit documentation
├── shadowgit_accelerator.py           # Main accelerator (31KB)
├── shadowgit_phase3_unified.py        # Phase 3 system (15KB)
├── shadowgit_global_handler.sh        # Global handler (7.6KB)
├── neural_git_accelerator.py          # Neural accelerator (29KB)
├── deploy_shadowgit_phase3.sh         # Phase 3 deployment (21KB)
└── analyze_shadowgit_performance.py   # Performance analysis (22KB)
```

**Performance**: 930M → 3.5B lines/sec acceleration

---

### optimization/

**Purpose**: System-wide performance optimization

```
optimization/
├── README.md                           # Optimization documentation
├── claude_universal_optimizer.py      # Universal optimizer (16KB)
├── install-universal-optimizer.sh     # Optimizer installer (2.1KB)
├── demo-optimizer-analysis.sh         # Analysis demo (6.7KB)
├── optimizer-summary.sh               # Summary script (5.9KB)
├── deploy_memory_optimization.sh      # Memory optimization (16KB)
└── test-critical-optimization.sh      # Critical path test (5.4KB)
```

---

### integration/

**Purpose**: Multi-agent coordination and integration

```
integration/
├── claude_unified_integration.py      # Unified integration (30KB)
├── claude_shell_integration.py        # Shell integration (21KB)
├── install_unified_integration.sh     # Integration installer (8.9KB)
├── integrate_hybrid_bridge.sh         # Hybrid bridge (17KB)
├── launch_hybrid_system.sh            # Hybrid launcher (4.2KB)
├── agent_coordination_matrix.py       # Coordination matrix (21KB)
└── enable-natural-invocation.sh       # Natural invocation (31KB)
```

---

### deployment/

**Purpose**: Production deployment scripts

```
deployment/
├── phase1-complete.sh                 # Phase 1 deployment (18KB)
├── phase2-complete-deployment.sh      # Phase 2 deployment (51KB)
├── phase2-deploy-trie-matcher.sh      # Trie matcher (21KB)
├── phase3-async-integration.py        # Phase 3 async (32KB)
├── deployment_dashboard.py            # Dashboard (20KB)
├── team_beta_hardware_acceleration.py # Hardware accel (36KB)
├── team_beta_production_deployment.py # Production deploy (25KB)
└── director_solution.sh               # Director script (14KB)
```

---

### testing/

**Purpose**: Comprehensive test suites

```
testing/
├── installer/                          # Installer tests
│   ├── test-enhanced-wrapper.sh
│   ├── test-venv-installer.py
│   ├── test-installer-integration.sh
│   ├── test_installer_fix.py
│   └── test-headless-install.py
│
├── learning/                           # Learning system tests
│   ├── test_learning_system_integration.sh
│   ├── test-docker-autostart.sh
│   └── validate_docker_learning_integration.sh
│
├── portability/                        # Portability tests
│   ├── validate_portability.py
│   ├── validate_portability_focused.py
│   ├── validate-portable-paths.sh
│   ├── validate_portable_paths.sh
│   ├── test-portable-paths.sh
│   └── test-portable-wrapper.sh
│
├── environment/                        # Environment tests
│   ├── test-environment-detection.py
│   └── test-environment-simple.py
│
└── other/                              # Miscellaneous tests
    ├── test-enhanced-semantic-matching.py
    ├── test-debug.sh
    ├── test_avx512_cores.sh
    └── phase2-orchestrator-test.py
```

---

### utilities/

**Purpose**: Helper scripts and utilities

```
utilities/
├── path_utilities.py                  # Path manipulation (11KB)
├── fix_hardcoded_paths.py             # Path fixes (15KB)
├── fix_hardcoded_paths_comprehensive.sh # Comprehensive fix (4.0KB)
├── fix_project_name_references.py     # Name fixes (2.2KB)
├── conflict_prediction_model.py       # Conflict prediction (21KB)
├── check_system_status.sh             # System status (3.5KB)
├── organize_documentation.sh          # Doc organizer (3.3KB)
├── github-sync.sh                     # GitHub sync (8.4KB)
├── emergency_cleanup.sh               # Emergency cleanup (1.7KB)
├── emergency_fix_packages.sh          # Package fixes (2.3KB)
└── npu_installer_integration.py       # NPU integration (14KB)
```

---

### hardware/

**Purpose**: Hardware-specific configurations and fixes

```
hardware/
├── bios/                               # BIOS management
│   ├── bios_downgrade_1.11.2.sh       # BIOS downgrade (1.1KB)
│   ├── bios_downgrade_safe.sh         # Safe downgrade (7.0KB)
│   └── prepare_recovery_usb.sh        # Recovery USB (1.4KB)
│
└── fixes/                              # Hardware fixes
    ├── fix_and_install_kernel.sh      # Kernel install fix (1.8KB)
    └── fix_learning_sudo.sh           # Sudo fix (4.9KB)
```

---

### docs/

**Purpose**: Comprehensive documentation

```
docs/
├── installation/                       # Installation guides
│   ├── INSTALL.md
│   ├── INSTALLATION.md
│   ├── HEADLESS_INSTALL_GUIDE.md
│   ├── PYTHON_INSTALLER_README.md
│   └── crypto_pow_implementation_guide.md
│
├── deployment/                         # Deployment documentation
│   ├── DEPLOYMENT_REPORT_v3.1.md
│   ├── TEAM_ALPHA_DEPLOYMENT_REPORT.md
│   ├── TEAM_BETA_DEPLOYMENT_REPORT.md
│   └── phase3-complete-deployment-summary.md
│
├── reports/                            # Technical reports
│   ├── COORDINATION_EXECUTION_REPORT.md
│   ├── NPU_OPTIMIZATION_REPORT.md
│   ├── PORTABILITY_VALIDATION_REPORT.md
│   ├── TANDEM_ORCHESTRATOR_ANALYSIS_REPORT.md
│   └── TODO_FILES_ATTRIBUTION_REPORT.md
│
├── guides/                             # User guides
│   ├── ENVIRONMENT_DETECTION_GUIDE.md
│   ├── hybrid_npu_migration_strategy.md
│   └── README_crypto_pow.md
│
└── status/                             # System status reports
    ├── AUTO_UPDATE_SYSTEM_COMPLETE.md
    ├── CHECKPOINT_NEURAL_READY.md
    ├── LEARNING_SYSTEM_STATUS.md
    └── SYSTEM_SPECS_2025-09-17.md
```

---

### docs-browser/

**Purpose**: Documentation browsing tools

```
docs-browser/
├── launch-docs-browser.sh             # Full browser (16KB)
├── launch-docs-simple.sh              # Simple viewer (4.2KB)
├── launch-universal-docs.sh           # Universal browser (21KB)
└── launch-phase3-optimizer.sh         # Phase 3 docs (1.2KB)
```

---

### config/

**Purpose**: Configuration files

```
config/
├── CLAUDE.md                          # Claude Agent config (5.2KB)
├── VERIF.md                           # Verification config (5.2KB)
├── __init__.py                        # Python init (3.9KB)
├── requirements.txt                   # Python dependencies (2.0KB)
└── MANIFEST.txt                       # Project manifest (9.5KB)
```

---

### archived-reports/

**Purpose**: Historical reports and summaries

```
archived-reports/
├── phase1-completion-report.txt
├── phase2-complete-report.txt
├── phase2-completion-report.txt
├── DOCKER_FIX_SUMMARY.md
├── ENHANCED_INSTALLER_COMPLETE_FEATURES.md
├── ENHANCED_WRAPPER_FIX_SUMMARY.md
├── HARDCODED_PATHS_FIXED.md
├── PATH_FIXES_SUMMARY.md
├── PYTHON_INSTALLER_SUMMARY.md
├── PYTHON_OPTIMIZATION_SUMMARY.md
├── PROOFOFWORKCHECK.md
└── CLAUDE_VENV_INSTALLER_SOLUTION.md
```

---

### legacy/

**Purpose**: Deprecated and old files

```
legacy/
├── MOVEME.md                          # Migration guide (14KB)
├── tui-installer-optimizer.sh         # Old TUI installer (34KB)
├── upgrade-to-python-installer.py     # Old upgrade script (30KB)
└── analyze-implementation-status.py   # Old analyzer (11KB)
```

---

## File Statistics

### By Category

| Category | Files | Total Size |
|----------|-------|------------|
| OpenVINO | 10 | ~71KB |
| Installers | 25 | ~300KB |
| Learning System | 13 | ~200KB |
| Crypto | 6 | ~80KB |
| ShadowGit | 7 | ~130KB |
| Optimization | 7 | ~70KB |
| Integration | 7 | ~150KB |
| Deployment | 8 | ~200KB |
| Testing | 20+ | ~180KB |
| Utilities | 11 | ~100KB |
| Hardware | 5 | ~20KB |
| Documentation | 30+ | ~200KB |

### File Types

| Type | Count | Purpose |
|------|-------|---------|
| `.sh` | 100+ | Bash scripts |
| `.py` | 50+ | Python scripts |
| `.md` | 40+ | Documentation |
| `.txt` | 10+ | Configuration/data |

---

## Navigation Tips

### Finding Files

```bash
# Search by name
find . -name "*openvino*"

# Search by type
find . -name "*.py" | grep learning

# Search by content
grep -r "OpenVINO" docs/
```

### Quick Access

```bash
# Jump to category
cd openvino/scripts
cd installers/claude
cd learning-system/python

# List category contents
ls -lh openvino/scripts/
ls -lh installers/*/
```

### Documentation

```bash
# View README files
cat openvino/README.md
cat learning-system/README.md
cat crypto/README.md

# Browse all docs
cd docs-browser
./launch-docs-browser.sh
```

---

## Maintenance

### Reorganizing

If files become disorganized, run:
```bash
./organize-repository.sh
```

This script will restore the proper directory structure.

### Adding New Files

Follow the organization pattern:
- **Scripts**: Place in appropriate category
- **Documentation**: Add to `docs/`
- **Tests**: Add to `testing/`
- **Config**: Add to `config/`

---

**Last Updated**: October 2, 2025
**Total Directories**: 40+
**Total Files**: 200+
**Organization Script**: `organize-repository.sh`
