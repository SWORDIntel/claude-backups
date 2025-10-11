# Hooks Integration Analysis
**Date:** 2025-10-11 08:05
**Location:** `/home/john/claude-backups/hooks/`

---

## Hooks Directory Structure

```
hooks/
├── crypto-pow/          # Crypto POW module hooks
├── shadowgit/           # Shadowgit git hooks
├── pre-commit/          # Git pre-commit hooks
├── post-task/           # Git post-task hooks
├── backup/              # Backup hook scripts
├── __pycache__/        # Python cache
└── [root level hooks]   # 40+ hook scripts
```

---

## Hook Categories & Integration Status

### 1. ✅ Crypto-POW Hooks - **INTEGRATED**

**Location:** `hooks/crypto-pow/`

**Components:**
- C engine: 4 object files compiled ✅
- Python tools:
  - `crypto_system_optimizer.py` - System optimizer
  - `crypto_analytics_dashboard.py` - Analytics UI
  - `crypto_auto_start_optimizer.py` - Auto-start service
  - `crypto_performance_monitor.py` - Performance monitor
  - `deploy-token-optimization.sh` - Deployment

**Integration Status:**
- ✅ Python dependencies installed (asyncpg, cryptography, pycryptodome)
- ✅ C objects compiled with meteorlake profile
- ✅ Auto-installed by Python installer
- ⚠️ Runtime hooks NOT auto-started

**Usage:**
```bash
# Manual start
python3 hooks/crypto-pow/crypto_system_optimizer.py
```

**Process-Specific:** Can be enabled via environment variable in Claude wrapper

---

### 2. ✅ Shadowgit Hooks - **INTEGRATED**

**Location:** `hooks/shadowgit/`

**Components:**
- C engine: shadowgit_phase3_integration.so (39KB) ✅
- Python modules: shadowgit_avx2.py, neural_accelerator.py
- Global handler: global_handler.sh

**Integration Status:**
- ✅ C engine compiled (AVX2+io_uring)
- ✅ Python modules in PYTHONPATH
- ✅ Auto-installed by Python installer
- ✅ SHADOWGIT environment added to shell

**Process-Specific:** Git operations - activated via git hooks

---

### 3. ❌ Context Chopping Hooks - **PARTIALLY INTEGRATED**

**Location:** `hooks/context_chopping_hooks.py`

**Components:**
- Python module: 17KB (context chopping logic)
- Dependencies: psycopg2-binary, psutil ✅

**Integration Status:**
- ✅ Python module exists and imports
- ✅ Dependencies installed
- ❌ NOT installed to Claude Code hooks directory
- ❌ NOT registered with Claude Code

**Required Integration:**
```bash
# Copy to Claude hooks
cp hooks/context_chopping_hooks.py ~/.claude/hooks/

# Or symlink
ln -s /home/john/claude-backups/hooks/context_chopping_hooks.py ~/.claude/hooks/
```

**Process-Specific:** Claude Code runtime - should activate during Claude sessions

---

### 4. ❌ Git Hooks (pre-commit/post-task) - **NOT INTEGRATED**

**Location:** `hooks/pre-commit/`, `hooks/post-task/`

**Components:**
- `pre-commit/export_learning_data.sh` - Export learning data before commit
- `post-task/record_learning_data.sh` - Record task execution

**Integration Status:**
- ❌ NOT installed to .git/hooks/
- ❌ NOT auto-configured

**Required Integration:**
```bash
# Install to git hooks
ln -s ../../hooks/pre-commit/export_learning_data.sh .git/hooks/pre-commit
ln -s ../../hooks/post-task/record_learning_data.sh .git/hooks/post-commit
chmod +x .git/hooks/pre-commit .git/hooks/post-commit
```

**Process-Specific:** Git operations - triggers on git commit/push

---

### 5. ❌ Unified Hook System - **NOT INTEGRATED**

**Location:**
- `hooks/claude_unified_hook_system_v2.py` (56KB)
- `hooks/claude_unified_hook_system.py` (53KB)
- `hooks/install_unified_hooks.sh`

**Components:**
- Unified hook orchestration system
- Agent registry integration
- Multi-hook coordination

**Integration Status:**
- ❌ NOT installed to ~/.claude/hooks/
- ❌ NOT registered with Claude Code
- ❌ Installer script exists but not called

**Required Integration:**
```bash
bash hooks/install_unified_hooks.sh
```

**Process-Specific:** Claude Code runtime - coordinates all hooks

---

### 6. ❌ Monitoring Hooks - **NOT INTEGRATED**

**Location:** `hooks/monitoring_setup.py`, `hooks/performance_monitor.py`

**Components:**
- Performance monitoring (CPU, memory, throughput)
- Health checks (60s interval)
- Alert thresholds
- Metrics retention

**Configuration:** `hooks/monitoring_config.json`

**Integration Status:**
- ❌ NOT auto-started
- ❌ NOT configured as service

**Process-Specific:** Background service - should run continuously

---

### 7. ❌ Security Hooks - **NOT INTEGRATED**

**Location:**
- `hooks/security_hardening.py`
- `hooks/security_patch.py`

**Integration Status:**
- ❌ NOT applied
- ❌ NOT configured

**Process-Specific:** One-time security hardening

---

### 8. ❌ Disassembler Hooks - **NOT INTEGRATED**

**Location:**
- `hooks/disassembler_hook.py` (14KB)
- `hooks/disassembler_bridge.py` (13KB)
- `hooks/ghidra-integration.sh` (57KB)

**Integration Status:**
- ❌ NOT installed
- ❌ NOT configured

**Process-Specific:** Binary analysis tasks

---

## Integration Priority

### Priority 1: Claude Code Runtime Hooks
These should auto-load when Claude Code runs:

1. **Context Chopping** (PICMCS)
   - Install to: `~/.claude/hooks/context_chopping_hooks.py`
   - Auto-activates during Claude sessions

2. **Unified Hook System**
   - Install via: `bash hooks/install_unified_hooks.sh`
   - Coordinates all hooks

### Priority 2: Git Process Hooks
These activate during git operations:

1. **Pre-commit Hook**
   - Install to: `.git/hooks/pre-commit`
   - Exports learning data before commit

2. **Post-commit Hook**
   - Install to: `.git/hooks/post-commit`
   - Records task execution

### Priority 3: Background Services
These run continuously:

1. **Monitoring**
   - Start: `python3 hooks/monitoring_setup.py &`
   - Systemd service recommended

2. **Crypto-POW Auto-start**
   - Enable via wrapper env var
   - Starts with Claude Code

### Priority 4: One-Time Setup
Run once:

1. **Security Hardening**
   - Run: `python3 hooks/security_hardening.py`

---

## Installer Integration Needed

**Add to Python installer** (`installers/claude/claude-enhanced-installer.py`):

```python
def install_claude_code_hooks(self) -> bool:
    """Install Claude Code runtime hooks"""
    self._print_section("Installing Claude Code Hooks")

    claude_hooks_dir = self.system_info.home_dir / ".claude" / "hooks"
    claude_hooks_dir.mkdir(parents=True, exist_ok=True)

    # 1. Context chopping (PICMCS)
    context_hook = self.project_root / "hooks" / "context_chopping_hooks.py"
    if context_hook.exists():
        (claude_hooks_dir / "context_chopping_hooks.py").symlink_to(context_hook)

    # 2. Unified hook system
    unified_hook = self.project_root / "hooks" / "claude_unified_hook_system_v2.py"
    if unified_hook.exists():
        (claude_hooks_dir / "claude_unified_hook_system.py").symlink_to(unified_hook)

    return True

def install_git_hooks(self) -> bool:
    """Install git hooks for learning data"""
    self._print_section("Installing Git Hooks")

    git_hooks_dir = self.project_root / ".git" / "hooks"
    if not git_hooks_dir.exists():
        return True  # Not a git repo

    # Pre-commit: Export learning data
    pre_commit = self.project_root / "hooks" / "pre-commit" / "export_learning_data.sh"
    if pre_commit.exists():
        (git_hooks_dir / "pre-commit").symlink_to(pre_commit)
        (git_hooks_dir / "pre-commit").chmod(0o755)

    # Post-commit: Record learning
    post_task = self.project_root / "hooks" / "post-task" / "record_learning_data.sh"
    if post_task.exists():
        (git_hooks_dir / "post-commit").symlink_to(post_task)
        (git_hooks_dir / "post-commit").chmod(0o755)

    return True
```

**Call in `run_installation()`:**
```python
# After agent installation
self.install_claude_code_hooks()
self.install_git_hooks()
```

---

## Current Installer Coverage

**Already Integrated:**
- ✅ Crypto-POW Python deps
- ✅ Crypto-POW C compilation
- ✅ Shadowgit C compilation
- ✅ Shadowgit Python modules
- ✅ PICMCS module (but not as Claude hook)
- ✅ Hybrid bridge

**NOT Integrated:**
- ❌ Context chopping as Claude Code hook
- ❌ Unified hook system
- ❌ Git hooks (pre-commit, post-task)
- ❌ Monitoring hooks
- ❌ Security hardening
- ❌ Disassembler hooks

---

## Recommendations

### Immediate (Add to Installer)
1. Install context_chopping_hooks.py to ~/.claude/hooks/
2. Install git hooks to .git/hooks/
3. Run unified hooks installer

### Optional (Manual/On-Demand)
1. Monitoring - start as background service
2. Crypto-POW auto-start - enable via env var
3. Security hardening - run once
4. Disassembler - enable for binary analysis tasks

---

## Usage After Integration

**Automatic (no user action):**
- Context chopping during Claude Code sessions
- Learning data export on git commit
- Task recording after git operations

**Manual Start:**
```bash
# Monitoring
python3 hooks/monitoring_setup.py &

# Crypto dashboard
python3 hooks/crypto-pow/crypto_analytics_dashboard.py

# Unified hooks
bash hooks/install_unified_hooks.sh
```

---

**Next Step:** Add `install_claude_code_hooks()` and `install_git_hooks()` to Python installer for full automation.
