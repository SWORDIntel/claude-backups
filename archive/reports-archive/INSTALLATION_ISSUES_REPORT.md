# Installation Issues Report
**Generated:** 2025-10-11 06:09
**Installation Command:** `./install` (complete installer)

## Executive Summary
Installation completed with **multiple critical failures** across several modules. 8/11 modules have issues requiring attention.

---

## ✅ Successful Modules (3)

### 1. OpenVINO Runtime
- **Status:** ✅ FULLY FUNCTIONAL
- **Version:** 2025.3.0-19807-44526285f24-releases/2025/3
- **Devices Detected:**
  - CPU: Intel Core Ultra 7 165H
  - GPU: Intel Arc Graphics (iGPU)
  - NPU: Intel AI Boost (95% non-functional per design)
- **Tests:** All passed including inference test, OpenCL, GPU access

### 2. Shadowgit C Engine
- **Status:** ✅ COMPILED SUCCESSFULLY
- **Optimizations:** AVX2/AVX-512 acceleration enabled
- **Profile:** Meteor Lake (AVX2+FMA+AVX-VNNI)

### 3. Agent System & Python Installer
- **Status:** ✅ INSTALLED
- **Agents:** 98 agents available
- **Location:** `/home/john/.local/share/claude/agents` → `/home/john/claude-backups/agents`

---

## ❌ Critical Failures (5)

### 1. NPU Coordination Bridge (Rust) - **FAILED TO COMPILE**
**Severity:** HIGH
**Error Count:** 15 compilation errors + 16 warnings

**Root Causes:**
```
error[E0432]: unresolved import `libloading`
  --> src/matlab.rs:13:5
   |
13 | use libloading::{Library, Symbol};
   |     ^^^^^^^^^^ use of unresolved module or unlinked crate `libloading`
```

**Key Issues:**
- Missing `libloading` crate dependency in `Cargo.toml`
- `CoordinationMetrics` missing `Serialize` derive: `#[derive(serde::Serialize)]`
- Type mismatch in `record_operation_completion()` - expects `&OperationResult`, got `&Result<OperationResult, Error>`
- Rust borrow checker errors in `coordination.rs:471` - use of moved value
- Python bindings thread safety violations (`*mut Python` not `Sync`)
- MATLAB binding issues with temporary value lifetimes
- Missing dereference in `matlab.rs:451` for window_size casting

**Files Affected:**
- `agents/src/rust/npu_coordination_bridge/src/matlab.rs`
- `agents/src/rust/npu_coordination_bridge/src/bridge.rs`
- `agents/src/rust/npu_coordination_bridge/src/coordination.rs`
- `agents/src/rust/npu_coordination_bridge/src/lib.rs`
- `agents/src/rust/npu_coordination_bridge/src/python_bindings.rs`
- `agents/src/rust/npu_coordination_bridge/Cargo.toml` (missing deps)

**Impact:** NPU coordination completely non-functional

---

### 2. Crypto-POW Module - **COMPILATION FAILED**
**Severity:** HIGH
**Error:**
```bash
gcc: error: unrecognized command-line option '-mavx-vnni'
did you mean '-mavxvnni'?
make: *** [Makefile:174: build/crypto_pow_core.o] Error 1
```

**Root Cause:**
- GCC 15.2.0 renamed `-mavx-vnni` flag to `-mavxvnni` (no dash)
- Build profile `meteorlake` uses outdated flag syntax

**Files Affected:**
- `Makefile` line 174
- `build-profiles/meteorlake.mk` (optimization flags)

**Fix Required:**
Replace all instances of `-mavx-vnni` with `-mavxvnni` in:
- Main Makefile
- `build-profiles/*.mk` files

---

### 3. C Agent Coordination Engine - **COMPILATION FAILED**
**Severity:** MEDIUM
**Error:** Build failed during `make production`

**Likely Causes:**
- Same AVX-VNNI flag issue as Crypto-POW
- Missing build dependencies (libnuma-dev, liburing-dev)
- Path to dependencies incorrect

**Files Affected:**
- `agents/src/c/Makefile`

---

### 4. Docker Services - **PERMISSION DENIED**
**Severity:** HIGH
**Errors:**
```
permission denied while trying to connect to Docker daemon socket
sudo: a password is required
```

**Root Causes:**
- User `john` not in `docker` group
- Docker daemon requires sudo but password not available in non-interactive mode
- `/var/run/docker.sock` not accessible

**Services Affected:**
- PostgreSQL 16 + pgvector database
- Learning System v2.0 containers

**Fix Required:**
```bash
# Add user to docker group (requires logout/login after)
sudo usermod -aG docker john

# Or fix socket permissions
sudo chmod 666 /var/run/docker.sock

# Start docker service
sudo systemctl start docker
```

---

### 5. Python Dependencies - **VIRTUALENV CONFLICT**
**Severity:** MEDIUM
**Error:**
```
ERROR: Can not perform a '--user' install.
User site-packages are not visible in this virtualenv.
```

**Packages Affected:**
- openvino
- psycopg2-binary
- numpy
- watchdog
- asyncpg
- cryptography
- pycryptodome

**Root Cause:**
Installer using `pip3 install --user` inside a virtualenv where `--user` is meaningless/forbidden.

**Fix Required:**
In `installers/claude/claude-enhanced-installer.py`, change:
```python
# Bad
['pip3', 'install', '--user', 'openvino']

# Good (use venv pip directly)
[str(venv_path / "bin" / "pip"), "install", "openvino"]
```

---

## ⚠️ Warnings (3)

### 1. System Build Dependencies
**Status:** PARTIAL FAILURE
**Error:** `sudo: a password is required`

**Missing Packages (not installed):**
- libnuma-dev
- liburing-dev
- librdkafka-dev
- libssl-dev
- build-essential

**Impact:** C/C++ compilation may fail

---

### 2. PICMCS Context Chopping
**Status:** NOT VERIFIED
**Warning:** "PICMCS hooks may need dependencies"

**File:** `hooks/context_chopping_hooks.py`
**Issue:** Python import test failed

---

### 3. Python Coordination Matrix
**Status:** NOT VERIFIED
**Warning:** "Python coordination needs dependencies"

**File:** `integration/agent_coordination_matrix.py`
**Issue:** Import test failed

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total Modules | 11 |
| Fully Successful | 3 |
| Critical Failures | 5 |
| Warnings | 3 |
| **Success Rate** | **27%** |

---

## Priority Fix List

### Priority 1 (Blocking Issues)
1. **Fix Crypto-POW GCC flags** - Change `-mavx-vnni` → `-mavxvnni` in Makefiles
2. **Fix Docker permissions** - Add user to docker group or fix socket permissions
3. **Fix NPU Bridge Rust code**:
   - Add `libloading` to `Cargo.toml`
   - Add `#[derive(serde::Serialize)]` to `CoordinationMetrics`
   - Fix type mismatches and borrow checker errors
   - Refactor Python bindings for thread safety

### Priority 2 (Important)
4. **Fix Python installer virtualenv logic** - Remove `--user` flag when in venv
5. **Install system dependencies** - Run apt-get with proper sudo
6. **Fix C Agent engine compilation** - Address AVX-VNNI flags

### Priority 3 (Nice to Have)
7. Verify PICMCS hooks dependencies
8. Verify Python coordination matrix dependencies

---

## Recommended Actions

### Immediate (Required for functionality)
```bash
# 1. Fix GCC flags globally
sed -i 's/-mavx-vnni/-mavxvnni/g' Makefile
sed -i 's/-mavx-vnni/-mavxvnni/g' build-profiles/*.mk

# 2. Fix Docker access
sudo usermod -aG docker john
sudo systemctl restart docker
# THEN logout and login

# 3. Install missing dependencies
sudo apt-get update
sudo apt-get install -y libnuma-dev liburing-dev librdkafka-dev \
    libssl-dev build-essential libpcre2-dev

# 4. Retry compilation
make clean && make production
```

### Code Fixes Required
1. **Cargo.toml** - Add `libloading = "0.8"` to dependencies
2. **coordination.rs** - Add `#[derive(Serialize)]` to structs
3. **lib.rs:235** - Fix type mismatch with proper error handling
4. **python_bindings.rs** - Refactor to avoid Python GIL issues
5. **claude-enhanced-installer.py** - Remove `--user` from pip commands in venv

---

## Installation Logs
- Main log: `/tmp/install-full-output.log`
- Python installer log: `/tmp/claude-install.log`
