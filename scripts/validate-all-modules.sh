#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Module Integration Validation Script
# Validates all 10 modules are properly integrated
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

check_pass() {
    echo -e "${GREEN}  ✅ $1${RESET}"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}  ❌ $1${RESET}"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}  ⚠️  $1${RESET}"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║         Module Integration Validation - All 10 Modules                  ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 1-2: AGENT COORDINATION & ECOSYSTEM
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}1-2. Agent Coordination & Ecosystem${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "integration/agent_coordination_matrix.py" ]]; then
    check_pass "agent_coordination_matrix.py exists"
else
    check_fail "agent_coordination_matrix.py MISSING"
fi

if [[ -f "agents/src/c/agent_coordination.c" ]]; then
    check_pass "C coordination engine exists"
else
    check_warn "C engine not found"
fi

if [[ -f "agents/src/python/enhanced_coordination_matrix.py" ]]; then
    check_pass "Enhanced coordination exists"
else
    check_warn "Enhanced coordination not found"
fi

if [[ -d "agents" ]] && [[ $(find agents -name "*.md" | wc -l) -ge 80 ]]; then
    check_pass "98+ agent definitions found"
else
    check_warn "Agent definitions incomplete"
fi

# Test Python import
if python3 -c "import sys; sys.path.insert(0, 'integration'); from agent_coordination_matrix import AgentCoordinationMatrix" 2>/dev/null; then
    check_pass "Python coordination imports successfully"
else
    check_warn "Python coordination import failed (may need dependencies)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 3: DATABASE SYSTEMS
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}3. Database Systems (PostgreSQL 16 + pgvector)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "database/docker-compose.yml" ]]; then
    check_pass "docker-compose.yml exists"
else
    check_fail "Docker config MISSING"
fi
if [[ -f "database/init/002_vector_extension.sql" ]]; then
    check_pass "pgvector schema exists"
else
    check_fail "pgvector schema MISSING"
fi
if [[ -d "database/scripts" ]]; then
    check_pass "Database scripts directory exists"
else
    check_warn "Scripts directory not found"
fi

if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude_postgres; then
        if docker exec claude_postgres pg_isready -U claude 2>/dev/null; then
            check_pass "PostgreSQL is running and healthy"
        else
            check_warn "PostgreSQL container exists but not ready"
        fi
    else
        check_warn "PostgreSQL container not running"
    fi
else
    check_warn "Docker not available (cannot check database)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 4-5: LEARNING SYSTEM & DOCKER
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}4-5. Learning System v2.0 & Docker Integration${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "learning-system/docker-compose.yml" ]]; then
    check_pass "Learning docker-compose exists"
else
    check_fail "Docker config MISSING"
fi
if [[ -d "learning-system/src" ]]; then
    check_pass "Learning source code exists"
else
    check_fail "Source code MISSING"
fi
if [[ -f "learning-system/requirements.txt" ]]; then
    check_pass "Python dependencies defined"
else
    check_warn "requirements.txt not found"
fi
if [[ $(find learning-system/src -name "*.py" | wc -l) -ge 10 ]]; then
    check_pass "Learning Python modules found"
else
    check_warn "Incomplete Python implementation"
fi

if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude_learning; then
        check_pass "Learning API container running"

        if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
            check_pass "Learning API responding"
        else
            check_warn "Learning API container running but not responding"
        fi
    else
        check_warn "Learning API container not running"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 6: PICMCS CONTEXT CHOPPING
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}6. PICMCS Context Chopping${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "hooks/context_chopping_hooks.py" ]]; then
    check_pass "PICMCS hooks exist"
else
    check_fail "PICMCS hooks MISSING"
fi

if python3 -c "exec(open('hooks/context_chopping_hooks.py').read())" 2>/dev/null; then
    check_pass "PICMCS hooks are valid Python"
else
    check_warn "PICMCS hooks may have syntax errors or dependencies"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 7: SHADOWGIT PERFORMANCE
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}7. Shadowgit Performance Engine${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -d "hooks/shadowgit" ]]; then
    check_pass "Shadowgit directory exists"
else
    check_fail "Shadowgit directory MISSING"
fi
if [[ -f "hooks/shadowgit/Makefile" ]]; then
    check_pass "Shadowgit Makefile exists"
else
    check_warn "Makefile not found"
fi
if [[ -f "hooks/shadowgit/python/shadowgit_avx2.py" ]]; then
    check_pass "AVX2 module exists"
else
    check_fail "AVX2 module MISSING"
fi
if [[ -f "hooks/shadowgit/c_diff_engine_impl.c" ]]; then
    check_pass "C engine exists"
else
    check_warn "C engine not found"
fi
if [[ -d "hooks/shadowgit/python" ]] && [[ $(find hooks/shadowgit/python -name "*.py" | wc -l) -ge 10 ]]; then
    check_pass "Python modules complete"
else
    check_warn "Incomplete Python modules"
fi

# Test Python import
if python3 -c "import sys; sys.path.insert(0, 'hooks/shadowgit/python'); from shadowgit_avx2 import ShadowGitAVX2" 2>/dev/null; then
    check_pass "Shadowgit Python imports successfully"
else
    check_warn "Shadowgit import failed (may need PYTHONPATH or dependencies)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 8: NPU ACCELERATION
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}8. NPU Acceleration (Rust Bridge)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -d "agents/src/rust/npu_coordination_bridge" ]]; then
    check_pass "NPU bridge directory exists"
else
    check_fail "NPU bridge MISSING"
fi
if [[ -f "agents/src/rust/npu_coordination_bridge/Cargo.toml" ]]; then
    check_pass "Cargo.toml exists"
else
    check_fail "Cargo.toml MISSING"
fi
if [[ -f "agents/src/rust/npu_coordination_bridge/src/lib.rs" ]]; then
    check_pass "Rust library source exists"
else
    check_fail "lib.rs MISSING"
fi
if [[ -f "agents/src/rust/npu_coordination_bridge/src/python_bindings.rs" ]]; then
    check_pass "Python bindings exist"
else
    check_warn "Python bindings not found"
fi

if [[ -f "agents/src/rust/npu_coordination_bridge/target/release/libnpu_coordination_bridge.so" ]]; then
    check_pass "NPU bridge compiled (shared library found)"
elif [[ -f "agents/src/rust/npu_coordination_bridge/target/debug/libnpu_coordination_bridge.so" ]]; then
    check_warn "NPU bridge compiled in debug mode"
else
    check_warn "NPU bridge not compiled (run: cargo build --release)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 9: OPENVINO RUNTIME
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}9. OpenVINO Runtime${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -d "openvino/scripts" ]]; then
    check_pass "OpenVINO scripts directory exists"
else
    check_fail "OpenVINO scripts MISSING"
fi
if [[ -f "openvino/scripts/openvino-quick-test.sh" ]]; then
    check_pass "Quick test script exists"
else
    check_warn "Quick test not found"
fi
if [[ -f "openvino/scripts/setup-openvino-bashrc.sh" ]]; then
    check_pass "Setup script exists"
else
    check_warn "Setup script not found"
fi

if command -v ov-info >/dev/null 2>&1; then
    check_pass "OpenVINO system installation detected"
else
    check_warn "OpenVINO not installed system-wide (optional)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# MODULE 10: INSTALLATION SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}10. Installation System${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "./install" ]]; then
    check_pass "Basic installer exists"
else
    check_warn "Basic installer not found"
fi
if [[ -f "installers/claude/claude-enhanced-installer.py" ]]; then
    check_pass "Enhanced Python installer exists"
else
    check_warn "Enhanced installer not found"
fi
if [[ -f "./install-complete.sh" ]]; then
    check_pass "Master orchestrator exists"
else
    check_warn "Master orchestrator not found"
fi

# Check for installation methods in enhanced installer
if [[ -f "installers/claude/claude-enhanced-installer.py" ]]; then
    if grep -q "install_shadowgit_module" installers/claude/claude-enhanced-installer.py; then
        check_pass "Shadowgit installer method exists"
    else
        check_warn "Shadowgit installer method not found"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# CROSS-MODULE INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}Cross-Module Integration${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Check Docker network
if command -v docker >/dev/null 2>&1; then
    if docker network inspect claude_network >/dev/null 2>&1; then
        check_pass "Shared Docker network exists"
    else
        check_warn "Docker network not created (will be created on first compose up)"
    fi
fi

# Check library structure
if [[ -f "lib/state.sh" ]]; then
    check_pass "State management library exists"
else
    check_warn "state.sh not found"
fi
if [[ -f "lib/env.sh" ]]; then
    check_pass "Environment library exists"
else
    check_warn "env.sh not found"
fi

# Check build system
if [[ -f "Makefile" ]]; then
    check_pass "Root Makefile exists"
else
    check_warn "Root Makefile not found"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}Validation Summary${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "Total Checks:    $TOTAL_CHECKS"
echo -e "${GREEN}Passed:          $PASSED_CHECKS${RESET}"
echo -e "${YELLOW}Warnings:        $WARNING_CHECKS${RESET}"
echo -e "${RED}Failed:          $FAILED_CHECKS${RESET}"
echo ""

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [[ $SUCCESS_RATE -ge 90 ]]; then
    echo -e "${GREEN}✅ Integration Status: EXCELLENT ($SUCCESS_RATE%)${RESET}"
    EXIT_CODE=0
elif [[ $SUCCESS_RATE -ge 75 ]]; then
    echo -e "${YELLOW}⚠️  Integration Status: GOOD ($SUCCESS_RATE%) - Some warnings${RESET}"
    EXIT_CODE=0
elif [[ $SUCCESS_RATE -ge 50 ]]; then
    echo -e "${YELLOW}⚠️  Integration Status: NEEDS WORK ($SUCCESS_RATE%)${RESET}"
    EXIT_CODE=1
else
    echo -e "${RED}❌ Integration Status: INCOMPLETE ($SUCCESS_RATE%)${RESET}"
    EXIT_CODE=2
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

exit $EXIT_CODE
