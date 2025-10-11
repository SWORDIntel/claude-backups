# Hardcoded Paths Fix Report
**Generated:** 2025-10-11
**Project:** /home/john/claude-backups

## Executive Summary

Found **4 Python files** with hardcoded `/home/john` paths that need fixing. These files are actively used and should be made portable.

---

## Python Files Requiring Fixes

### 1. `/home/john/claude-backups/agents/src/python/DISASSEMBLER_impl.py`

**Lines 170-171:** Hardcoded paths for ULTRATHINK integration

```python
# CURRENT (WRONG):
ULTRATHINK_SCRIPT_PATH = Path("/home/john/claude-backups/hooks/ghidra-integration.sh")
HOOKS_DIR = Path("/home/john/claude-backups/hooks")
```

**FIX:**
```python
# FIXED (PORTABLE):
def find_project_root():
    """Find the project root directory"""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "hooks").exists() or (current / ".git").exists():
            return current
        current = current.parent
    return Path.home() / "claude-backups"

_PROJECT_ROOT = find_project_root()
ULTRATHINK_SCRIPT_PATH = _PROJECT_ROOT / "hooks" / "ghidra-integration.sh"
HOOKS_DIR = _PROJECT_ROOT / "hooks"
```

**Exact sed command:**
```bash
cd /home/john/claude-backups/agents/src/python
# First, add the helper function after line 167 (after logging.basicConfig)
sed -i '167a\\n# Helper function to find project root\\ndef find_project_root():\\n    """Find the project root directory"""\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        if (current / "hooks").exists() or (current / ".git").exists():\\n            return current\\n        current = current.parent\\n    return Path.home() / "claude-backups"\\n\\n_PROJECT_ROOT = find_project_root()' DISASSEMBLER_impl.py

# Then replace the hardcoded paths
sed -i '170s|Path("/home/john/claude-backups/hooks/ghidra-integration.sh")|_PROJECT_ROOT / "hooks" / "ghidra-integration.sh"|' DISASSEMBLER_impl.py
sed -i '171s|Path("/home/john/claude-backups/hooks")|_PROJECT_ROOT / "hooks"|' DISASSEMBLER_impl.py
```

---

### 2. `/home/john/claude-backups/agents/src/python/initialize_git_intelligence.py`

**Line 374:** Hardcoded shadowgit path

```python
# CURRENT (WRONG):
shadowgit_path = Path("/home/john/shadowgit/shadowgit_avx2.py")
```

**FIX:**
```python
# FIXED (PORTABLE):
shadowgit_path = Path.home() / "shadowgit" / "shadowgit_avx2.py"
```

**Exact sed command:**
```bash
cd /home/john/claude-backups/agents/src/python
sed -i '374s|Path("/home/john/shadowgit/shadowgit_avx2.py")|Path.home() / "shadowgit" / "shadowgit_avx2.py"|' initialize_git_intelligence.py
```

---

### 3. `/home/john/claude-backups/agents/src/python/npu_fallback_compiler.py`

**Line 949:** Hardcoded default source directory

```python
# CURRENT (WRONG):
parser.add_argument(
    "--source-dir",
    default="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge",
    help="Source directory containing Cargo.toml"
)
```

**FIX:**
```python
# FIXED (PORTABLE):
def get_default_source_dir():
    """Get default source directory dynamically"""
    # Try to find project root
    current = Path(__file__).resolve().parent
    while current != current.parent:
        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"
        if rust_path.exists():
            return str(rust_path)
        current = current.parent
    # Fallback to relative path
    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")

parser.add_argument(
    "--source-dir",
    default=get_default_source_dir(),
    help="Source directory containing Cargo.toml"
)
```

**Exact Python edit:**
```python
# Add this function before line 940 (before def main():)
# Insert at line 939:
def get_default_source_dir():
    """Get default source directory dynamically"""
    from pathlib import Path
    current = Path(__file__).resolve().parent
    while current != current.parent:
        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"
        if rust_path.exists():
            return str(rust_path)
        current = current.parent
    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")

# Then replace line 949:
sed -i '949s|default="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|default=get_default_source_dir()|' npu_fallback_compiler.py
```

---

### 4. `/home/john/claude-backups/agents/src/python/npu_binary_distribution_coordinator.py`

**Lines 153 and 157:** Hardcoded paths in two places

```python
# CURRENT (WRONG):
# Line 153:
detector = NPUFallbackCompiler(
    "/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"
)

# Line 157 (in _execute_fallback_compilation method):
compiler = NPUFallbackCompiler(
    source_dir="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge",
    output_dir=None
)
```

**FIX:**
```python
# FIXED (PORTABLE):
def get_npu_bridge_source():
    """Get NPU bridge source directory dynamically"""
    from pathlib import Path
    current = Path(__file__).resolve().parent
    while current != current.parent:
        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"
        if rust_path.exists():
            return str(rust_path)
        current = current.parent
    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")

# Add as class variable at top of NPUBinaryDistributionCoordinator.__init__:
self.npu_bridge_source = get_npu_bridge_source()

# Then use throughout:
detector = NPUFallbackCompiler(self.npu_bridge_source)

compiler = NPUFallbackCompiler(
    source_dir=self.npu_bridge_source,
    output_dir=None
)
```

**Exact Python code to add:**
```bash
cd /home/john/claude-backups/agents/src/python

# Add helper function after imports (around line 26, after logger = ...)
sed -i '26a\\ndef get_npu_bridge_source():\\n    """Get NPU bridge source directory dynamically"""\\n    from pathlib import Path\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"\\n        if rust_path.exists():\\n            return str(rust_path)\\n        current = current.parent\\n    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")\\n' npu_binary_distribution_coordinator.py

# Replace line 153
sed -i '153s|"/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|get_npu_bridge_source()|' npu_binary_distribution_coordinator.py

# Replace line 157
sed -i '157s|source_dir="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|source_dir=get_npu_bridge_source()|' npu_binary_distribution_coordinator.py
```

---

### 5. `/home/john/claude-backups/agents/src/python/claude_agents/implementations/language/python_security_executor.py`

**Lines 51-56:** ULTRATHINK integration paths

```python
# CURRENT (WRONG):
self.ultrathink_integration = {
    'ghidra_scripts_dir': '/home/john/claude-backups/hooks/ghidra-workspace/scripts',
    'analysis_workspace': '/home/john/.claude/ghidra-workspace',
    'hostile_samples_dir': '/home/john/.claude/hostile-samples',
    'quarantine_dir': '/home/john/.claude/quarantine',
    'reports_dir': '/home/john/.claude/analysis-reports',
    'yara_rules_dir': '/home/john/.claude/yara-rules'
}
```

**FIX:**
```python
# FIXED (PORTABLE):
def find_project_root():
    """Find project root directory"""
    from pathlib import Path
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "hooks").exists() or (current / ".git").exists():
            return current
        current = current.parent
    return Path.home() / "claude-backups"

_PROJECT_ROOT = find_project_root()
_CLAUDE_DIR = Path.home() / ".claude"

self.ultrathink_integration = {
    'ghidra_scripts_dir': str(_PROJECT_ROOT / "hooks" / "ghidra-workspace" / "scripts"),
    'analysis_workspace': str(_CLAUDE_DIR / "ghidra-workspace"),
    'hostile_samples_dir': str(_CLAUDE_DIR / "hostile-samples"),
    'quarantine_dir': str(_CLAUDE_DIR / "quarantine"),
    'reports_dir': str(_CLAUDE_DIR / "analysis-reports"),
    'yara_rules_dir': str(_CLAUDE_DIR / "yara-rules")
}
```

**Exact edit:**
```bash
cd /home/john/claude-backups/agents/src/python/claude_agents/implementations/language

# Add helper function after imports (line 23, after logger = logging.getLogger(__name__))
sed -i '23a\\ndef find_project_root():\\n    """Find project root directory"""\\n    from pathlib import Path\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        if (current / "hooks").exists() or (current / ".git").exists():\\n            return current\\n        current = current.parent\\n    return Path.home() / "claude-backups"\\n\\n_PROJECT_ROOT = find_project_root()\\n_CLAUDE_DIR = Path.home() / ".claude"' python_security_executor.py

# Replace the paths in lines 51-56
sed -i "51s|'/home/john/claude-backups/hooks/ghidra-workspace/scripts'|str(_PROJECT_ROOT / 'hooks' / 'ghidra-workspace' / 'scripts')|" python_security_executor.py
sed -i "52s|'/home/john/.claude/ghidra-workspace'|str(_CLAUDE_DIR / 'ghidra-workspace')|" python_security_executor.py
sed -i "53s|'/home/john/.claude/hostile-samples'|str(_CLAUDE_DIR / 'hostile-samples')|" python_security_executor.py
sed -i "54s|'/home/john/.claude/quarantine'|str(_CLAUDE_DIR / 'quarantine')|" python_security_executor.py
sed -i "55s|'/home/john/.claude/analysis-reports'|str(_CLAUDE_DIR / 'analysis-reports')|" python_security_executor.py
sed -i "56s|'/home/john/.claude/yara-rules'|str(_CLAUDE_DIR / 'yara-rules')|" python_security_executor.py
```

---

## Script Files with Hardcoded Paths

### High Priority Scripts (Active Use)

1. **`/home/john/claude-backups/config/npu_environment.sh`** (Lines 4-5)
   - Used for NPU configuration
   - Replace with `$(dirname "$(realpath "$0")")/..`

2. **`/home/john/claude-backups/database/activate_learning_integration.sh`** (Lines 10, 156, 168, 188)
   - Active learning system integration
   - Replace with `PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"`

3. **`/home/john/claude-backups/database/deploy_persistent_learning_system.sh`** (Multiple lines)
   - Database deployment script
   - Use dynamic project root detection

4. **`/home/john/claude-backups/hardware/fixes/fix_learning_sudo.sh`** (Lines 19, 93, 123)
   - Hardware fix script
   - Make portable with `$(dirname "$0")/../..`

### Lower Priority (Tests/Deprecated)

- Test files in `/home/john/claude-backups/tests/` - Can be fixed but less critical
- Deprecated configs in `/home/john/claude-backups/deprecated/` - Archive or ignore
- Archive files in `/home/john/claude-backups/archive/` - Safe to leave as-is

---

## Automated Fix Script

Create `/home/john/claude-backups/fix_hardcoded_paths.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/agents/src/python"

echo "=== Fixing Python Hardcoded Paths ==="

# Backup files first
mkdir -p ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)
cp DISASSEMBLER_impl.py ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)/
cp initialize_git_intelligence.py ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)/
cp npu_fallback_compiler.py ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)/
cp npu_binary_distribution_coordinator.py ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)/
cp claude_agents/implementations/language/python_security_executor.py ../../../backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)/

echo "✓ Backups created"

# Fix 1: DISASSEMBLER_impl.py
echo "Fixing DISASSEMBLER_impl.py..."
sed -i '167a\\n# Helper function to find project root\\ndef find_project_root():\\n    """Find the project root directory"""\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        if (current / "hooks").exists() or (current / ".git").exists():\\n            return current\\n        current = current.parent\\n    return Path.home() / "claude-backups"\\n\\n_PROJECT_ROOT = find_project_root()' DISASSEMBLER_impl.py
sed -i 's|Path("/home/john/claude-backups/hooks/ghidra-integration.sh")|_PROJECT_ROOT / "hooks" / "ghidra-integration.sh"|' DISASSEMBLER_impl.py
sed -i 's|Path("/home/john/claude-backups/hooks")|_PROJECT_ROOT / "hooks"|' DISASSEMBLER_impl.py

# Fix 2: initialize_git_intelligence.py
echo "Fixing initialize_git_intelligence.py..."
sed -i 's|Path("/home/john/shadowgit/shadowgit_avx2.py")|Path.home() / "shadowgit" / "shadowgit_avx2.py"|' initialize_git_intelligence.py

# Fix 3: npu_fallback_compiler.py
echo "Fixing npu_fallback_compiler.py..."
sed -i '939i\\ndef get_default_source_dir():\\n    """Get default source directory dynamically"""\\n    from pathlib import Path\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"\\n        if rust_path.exists():\\n            return str(rust_path)\\n        current = current.parent\\n    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")\\n' npu_fallback_compiler.py
sed -i 's|default="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|default=get_default_source_dir()|' npu_fallback_compiler.py

# Fix 4: npu_binary_distribution_coordinator.py
echo "Fixing npu_binary_distribution_coordinator.py..."
sed -i '26a\\ndef get_npu_bridge_source():\\n    """Get NPU bridge source directory dynamically"""\\n    from pathlib import Path\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"\\n        if rust_path.exists():\\n            return str(rust_path)\\n        current = current.parent\\n    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")\\n' npu_binary_distribution_coordinator.py
sed -i 's|"/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|get_npu_bridge_source()|g' npu_binary_distribution_coordinator.py

# Fix 5: python_security_executor.py
echo "Fixing python_security_executor.py..."
cd claude_agents/implementations/language
sed -i '23a\\ndef find_project_root():\\n    """Find project root directory"""\\n    from pathlib import Path\\n    current = Path(__file__).resolve().parent\\n    while current != current.parent:\\n        if (current / "hooks").exists() or (current / ".git").exists():\\n            return current\\n        current = current.parent\\n    return Path.home() / "claude-backups"\\n\\n_PROJECT_ROOT = find_project_root()\\n_CLAUDE_DIR = Path.home() / ".claude"' python_security_executor.py
sed -i "s|'/home/john/claude-backups/hooks/ghidra-workspace/scripts'|str(_PROJECT_ROOT / 'hooks' / 'ghidra-workspace' / 'scripts')|" python_security_executor.py
sed -i "s|'/home/john/.claude/ghidra-workspace'|str(_CLAUDE_DIR / 'ghidra-workspace')|" python_security_executor.py
sed -i "s|'/home/john/.claude/hostile-samples'|str(_CLAUDE_DIR / 'hostile-samples')|" python_security_executor.py
sed -i "s|'/home/john/.claude/quarantine'|str(_CLAUDE_DIR / 'quarantine')|" python_security_executor.py
sed -i "s|'/home/john/.claude/analysis-reports'|str(_CLAUDE_DIR / 'analysis-reports')|" python_security_executor.py
sed -i "s|'/home/john/.claude/yara-rules'|str(_CLAUDE_DIR / 'yara-rules')|" python_security_executor.py

echo "✓ All Python files fixed"

# Test syntax
cd "$SCRIPT_DIR/agents/src/python"
echo "Testing Python syntax..."
python3 -m py_compile DISASSEMBLER_impl.py && echo "  ✓ DISASSEMBLER_impl.py"
python3 -m py_compile initialize_git_intelligence.py && echo "  ✓ initialize_git_intelligence.py"
python3 -m py_compile npu_fallback_compiler.py && echo "  ✓ npu_fallback_compiler.py"
python3 -m py_compile npu_binary_distribution_coordinator.py && echo "  ✓ npu_binary_distribution_coordinator.py"
python3 -m py_compile claude_agents/implementations/language/python_security_executor.py && echo "  ✓ python_security_executor.py"

echo ""
echo "=== All fixes complete! ==="
echo "Backups saved to: $SCRIPT_DIR/backups/hardcoded-paths-*"
```

---

## Verification Commands

```bash
# Check for remaining hardcoded paths
cd /home/john/claude-backups
grep -r "/home/john" agents/src/python/*.py | grep -v deprecated | grep -v ".pyc"
grep -r "/home/ubuntu" agents/src/python/*.py | grep -v deprecated

# Test imports
python3 -c "from agents.src.python import DISASSEMBLER_impl"
python3 -c "from agents.src.python import initialize_git_intelligence"
python3 -c "from agents.src.python import npu_fallback_compiler"
python3 -c "from agents.src.python import npu_binary_distribution_coordinator"
python3 -c "from agents.src.python.claude_agents.implementations.language import python_security_executor"
```

---

## Summary

- **Python files to fix:** 5
- **Critical scripts to fix:** 4
- **Test/deprecated files:** Can be ignored for now
- **Estimated fix time:** 15 minutes with automated script
- **Risk level:** Low (all paths have fallback mechanisms)

**Recommended Action:** Run the automated fix script, then verify syntax and test imports.
