#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups/hardcoded-paths-$(date +%Y%m%d-%H%M%S)"

echo "==================================================================="
echo "  Fixing Hardcoded Paths in Python Files"
echo "==================================================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "[1/6] Creating backups in: $BACKUP_DIR"

# Backup all files we're about to modify
cd "$SCRIPT_DIR/agents/src/python"
cp DISASSEMBLER_impl.py "$BACKUP_DIR/"
cp initialize_git_intelligence.py "$BACKUP_DIR/"
cp npu_fallback_compiler.py "$BACKUP_DIR/"
cp npu_binary_distribution_coordinator.py "$BACKUP_DIR/"
cp claude_agents/implementations/language/python_security_executor.py "$BACKUP_DIR/"
echo "   ✓ All files backed up"
echo ""

# Fix 1: DISASSEMBLER_impl.py
echo "[2/6] Fixing DISASSEMBLER_impl.py"
echo "   - Adding find_project_root() helper function"
echo "   - Replacing hardcoded ULTRATHINK_SCRIPT_PATH"
echo "   - Replacing hardcoded HOOKS_DIR"

# Add helper function after line 167
sed -i '167a\
\
# Helper function to find project root\
def find_project_root():\
    """Find the project root directory"""\
    current = Path(__file__).resolve().parent\
    while current != current.parent:\
        if (current / "hooks").exists() or (current / ".git").exists():\
            return current\
        current = current.parent\
    return Path.home() / "claude-backups"\
\
_PROJECT_ROOT = find_project_root()' DISASSEMBLER_impl.py

# Replace hardcoded paths
sed -i 's|Path("/home/john/claude-backups/hooks/ghidra-integration.sh")|_PROJECT_ROOT / "hooks" / "ghidra-integration.sh"|' DISASSEMBLER_impl.py
sed -i 's|Path("/home/john/claude-backups/hooks")|_PROJECT_ROOT / "hooks"|' DISASSEMBLER_impl.py
echo "   ✓ DISASSEMBLER_impl.py fixed"
echo ""

# Fix 2: initialize_git_intelligence.py
echo "[3/6] Fixing initialize_git_intelligence.py"
echo "   - Replacing hardcoded shadowgit path with Path.home()"

sed -i 's|Path("/home/john/shadowgit/shadowgit_avx2.py")|Path.home() / "shadowgit" / "shadowgit_avx2.py"|' initialize_git_intelligence.py
echo "   ✓ initialize_git_intelligence.py fixed"
echo ""

# Fix 3: npu_fallback_compiler.py
echo "[4/6] Fixing npu_fallback_compiler.py"
echo "   - Adding get_default_source_dir() helper function"
echo "   - Replacing hardcoded default source directory"

# Add helper function before main() (line 939)
sed -i '939i\
\
def get_default_source_dir():\
    """Get default source directory dynamically"""\
    from pathlib import Path\
    current = Path(__file__).resolve().parent\
    while current != current.parent:\
        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"\
        if rust_path.exists():\
            return str(rust_path)\
        current = current.parent\
    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")\
' npu_fallback_compiler.py

# Replace the default argument
sed -i 's|default="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|default=get_default_source_dir()|' npu_fallback_compiler.py
echo "   ✓ npu_fallback_compiler.py fixed"
echo ""

# Fix 4: npu_binary_distribution_coordinator.py
echo "[5/6] Fixing npu_binary_distribution_coordinator.py"
echo "   - Adding get_npu_bridge_source() helper function"
echo "   - Replacing all hardcoded NPU bridge paths"

# Add helper function after imports (line 26)
sed -i '26a\
\
def get_npu_bridge_source():\
    """Get NPU bridge source directory dynamically"""\
    from pathlib import Path\
    current = Path(__file__).resolve().parent\
    while current != current.parent:\
        rust_path = current / "agents" / "src" / "rust" / "npu_coordination_bridge"\
        if rust_path.exists():\
            return str(rust_path)\
        current = current.parent\
    return str(Path(__file__).parent.parent / "rust" / "npu_coordination_bridge")\
' npu_binary_distribution_coordinator.py

# Replace all occurrences of the hardcoded path
sed -i 's|"/home/john/claude-backups/agents/src/rust/npu_coordination_bridge"|get_npu_bridge_source()|g' npu_binary_distribution_coordinator.py
echo "   ✓ npu_binary_distribution_coordinator.py fixed"
echo ""

# Fix 5: python_security_executor.py
echo "[6/6] Fixing python_security_executor.py"
echo "   - Adding find_project_root() helper function"
echo "   - Replacing all ULTRATHINK integration paths"

cd claude_agents/implementations/language

# Add helper function after line 23
sed -i '23a\
\
def find_project_root():\
    """Find project root directory"""\
    from pathlib import Path\
    current = Path(__file__).resolve().parent\
    while current != current.parent:\
        if (current / "hooks").exists() or (current / ".git").exists():\
            return current\
        current = current.parent\
    return Path.home() / "claude-backups"\
\
_PROJECT_ROOT = find_project_root()\
_CLAUDE_DIR = Path.home() / ".claude"' python_security_executor.py

# Replace all ULTRATHINK paths
sed -i "s|'/home/john/claude-backups/hooks/ghidra-workspace/scripts'|str(_PROJECT_ROOT / 'hooks' / 'ghidra-workspace' / 'scripts')|" python_security_executor.py
sed -i "s|'/home/john/.claude/ghidra-workspace'|str(_CLAUDE_DIR / 'ghidra-workspace')|" python_security_executor.py
sed -i "s|'/home/john/.claude/hostile-samples'|str(_CLAUDE_DIR / 'hostile-samples')|" python_security_executor.py
sed -i "s|'/home/john/.claude/quarantine'|str(_CLAUDE_DIR / 'quarantine')|" python_security_executor.py
sed -i "s|'/home/john/.claude/analysis-reports'|str(_CLAUDE_DIR / 'analysis-reports')|" python_security_executor.py
sed -i "s|'/home/john/.claude/yara-rules'|str(_CLAUDE_DIR / 'yara-rules')|" python_security_executor.py

echo "   ✓ python_security_executor.py fixed"
echo ""

# Return to project root
cd "$SCRIPT_DIR/agents/src/python"

# Test syntax
echo "==================================================================="
echo "  Testing Python Syntax"
echo "==================================================================="
echo ""

SYNTAX_ERRORS=0

echo "[1/5] Testing DISASSEMBLER_impl.py..."
if python3 -m py_compile DISASSEMBLER_impl.py 2>/dev/null; then
    echo "   ✓ DISASSEMBLER_impl.py - Syntax OK"
else
    echo "   ✗ DISASSEMBLER_impl.py - Syntax ERROR"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

echo "[2/5] Testing initialize_git_intelligence.py..."
if python3 -m py_compile initialize_git_intelligence.py 2>/dev/null; then
    echo "   ✓ initialize_git_intelligence.py - Syntax OK"
else
    echo "   ✗ initialize_git_intelligence.py - Syntax ERROR"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

echo "[3/5] Testing npu_fallback_compiler.py..."
if python3 -m py_compile npu_fallback_compiler.py 2>/dev/null; then
    echo "   ✓ npu_fallback_compiler.py - Syntax OK"
else
    echo "   ✗ npu_fallback_compiler.py - Syntax ERROR"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

echo "[4/5] Testing npu_binary_distribution_coordinator.py..."
if python3 -m py_compile npu_binary_distribution_coordinator.py 2>/dev/null; then
    echo "   ✓ npu_binary_distribution_coordinator.py - Syntax OK"
else
    echo "   ✗ npu_binary_distribution_coordinator.py - Syntax ERROR"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

echo "[5/5] Testing python_security_executor.py..."
if python3 -m py_compile claude_agents/implementations/language/python_security_executor.py 2>/dev/null; then
    echo "   ✓ python_security_executor.py - Syntax OK"
else
    echo "   ✗ python_security_executor.py - Syntax ERROR"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

echo ""
echo "==================================================================="
echo "  Verification"
echo "==================================================================="
echo ""

# Check for remaining hardcoded paths
REMAINING=$(grep -r "/home/john" DISASSEMBLER_impl.py initialize_git_intelligence.py npu_fallback_compiler.py npu_binary_distribution_coordinator.py claude_agents/implementations/language/python_security_executor.py 2>/dev/null | grep -v "# CURRENT" | grep -v "# WRONG" | grep -v ".pyc" | wc -l || true)

echo "Remaining hardcoded paths: $REMAINING"
echo "Syntax errors: $SYNTAX_ERRORS"
echo "Backups saved to: $BACKUP_DIR"
echo ""

if [ $SYNTAX_ERRORS -eq 0 ] && [ $REMAINING -eq 0 ]; then
    echo "==================================================================="
    echo "  ✓ SUCCESS - All files fixed and verified"
    echo "==================================================================="
    echo ""
    echo "Next steps:"
    echo "  1. Test imports: python3 -c 'from agents.src.python import DISASSEMBLER_impl'"
    echo "  2. Run unit tests if available"
    echo "  3. Commit changes: git add -A && git commit -m 'Fix hardcoded paths for portability'"
    echo ""
    exit 0
elif [ $SYNTAX_ERRORS -gt 0 ]; then
    echo "==================================================================="
    echo "  ✗ ERROR - Syntax errors detected"
    echo "==================================================================="
    echo ""
    echo "Some files have syntax errors. To restore:"
    echo "  cp $BACKUP_DIR/*.py $SCRIPT_DIR/agents/src/python/"
    echo ""
    exit 1
elif [ $REMAINING -gt 0 ]; then
    echo "==================================================================="
    echo "  ⚠ WARNING - Some hardcoded paths remain"
    echo "==================================================================="
    echo ""
    echo "Manual review required. Check with:"
    echo "  grep -n '/home/john' agents/src/python/*.py"
    echo ""
    exit 2
fi
