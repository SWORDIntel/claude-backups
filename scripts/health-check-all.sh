#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Complete System Health Check
# Monitors all 10 modules and their integration
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Health status counters
HEALTHY=0
UNHEALTHY=0
DEGRADED=0

status_healthy() {
    echo -e "${GREEN}  🟢 $1${RESET}"
    ((HEALTHY++))
}

status_degraded() {
    echo -e "${YELLOW}  🟡 $1${RESET}"
    ((DEGRADED++))
}

status_unhealthy() {
    echo -e "${RED}  🔴 $1${RESET}"
    ((UNHEALTHY++))
}

echo -e "${BOLD}${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║                  System Health Check - All Modules                       ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# DATABASE HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🗄️  Database Systems${RESET}"

if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude_postgres; then
        # Check if database is accepting connections
        if docker exec claude_postgres pg_isready -U claude >/dev/null 2>&1; then
            # Get database stats
            CONNECTIONS=$(docker exec claude_postgres psql -U claude -d claude_db -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs || echo "0")
            DB_SIZE=$(docker exec claude_postgres psql -U claude -d claude_db -t -c "SELECT pg_size_pretty(pg_database_size('claude_db'));" 2>/dev/null | xargs || echo "unknown")

            status_healthy "PostgreSQL operational ($CONNECTIONS connections, $DB_SIZE)"

            # Check pgvector
            if docker exec claude_postgres psql -U claude -d claude_db -t -c "SELECT extversion FROM pg_extension WHERE extname='vector';" 2>/dev/null | grep -q "[0-9]"; then
                status_healthy "pgvector extension loaded"
            else
                status_degraded "pgvector extension not loaded"
            fi
        else
            status_unhealthy "PostgreSQL not accepting connections"
        fi
    else
        status_degraded "PostgreSQL container not running"
    fi

    # Check pgAdmin
    if docker ps | grep -q claude_pgadmin; then
        status_healthy "pgAdmin running (http://localhost:5050)"
    else
        status_degraded "pgAdmin not running"
    fi
else
    status_degraded "Docker not available - cannot check database"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# LEARNING SYSTEM HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🧠 Learning System v2.0${RESET}"

if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude_learning; then
        # Check API health endpoint
        if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
            HEALTH_RESPONSE=$(curl -s http://localhost:8001/health 2>/dev/null)
            status_healthy "Learning API healthy (http://localhost:8001)"

            # Check API stats
            if echo "$HEALTH_RESPONSE" | grep -q "status.*ok\|healthy"; then
                status_healthy "API health check passed"
            fi
        else
            status_unhealthy "Learning API not responding"
        fi
    else
        status_degraded "Learning API container not running"
    fi

    # Check Redis
    if docker ps | grep -q claude_redis; then
        if docker exec claude_redis redis-cli ping 2>/dev/null | grep -q PONG; then
            REDIS_MEMORY=$(docker exec claude_redis redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 || echo "unknown")
            status_healthy "Redis operational ($REDIS_MEMORY used)"
        else
            status_unhealthy "Redis not responding"
        fi
    else
        status_degraded "Redis container not running"
    fi
else
    status_degraded "Docker not available - cannot check learning system"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# AGENT SYSTEMS HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🤖 Agent Coordination & Ecosystem${RESET}"

# Check Python coordination
if python3 -c "import sys; sys.path.insert(0, 'integration'); from agent_coordination_matrix import AgentCoordinationMatrix; acm = AgentCoordinationMatrix(); print('OK')" 2>/dev/null | grep -q OK; then
    status_healthy "Python coordination matrix operational"
else
    status_degraded "Python coordination has import issues"
fi

# Check C engine binary
if [[ -f "agents/build/bin/agent_bridge" ]]; then
    status_healthy "C agent bridge binary exists"
else
    status_degraded "C agent bridge not compiled"
fi

# Check agent count
AGENT_MD_COUNT=$(find agents -name "*.md" -type f 2>/dev/null | wc -l)
if [[ $AGENT_MD_COUNT -ge 80 ]]; then
    status_healthy "Agent definitions found ($AGENT_MD_COUNT agents)"
else
    status_degraded "Limited agent definitions ($AGENT_MD_COUNT found)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# SHADOWGIT HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}⚡ Shadowgit Performance Engine${RESET}"

if [[ -d "hooks/shadowgit" ]]; then
    status_healthy "Shadowgit directory exists"

    # Check Python modules
    SHADOWGIT_PY_COUNT=$(find hooks/shadowgit/python -name "*.py" 2>/dev/null | wc -l)
    if [[ $SHADOWGIT_PY_COUNT -ge 10 ]]; then
        status_healthy "Python modules present ($SHADOWGIT_PY_COUNT files)"
    else
        status_degraded "Limited Python modules ($SHADOWGIT_PY_COUNT found)"
    fi

    # Check C engine
    if [[ -f "hooks/shadowgit/c_diff_engine_impl.c" ]]; then
        status_healthy "C engine source exists"
    else
        status_degraded "C engine source not found"
    fi

    # Test import
    if python3 -c "import sys; sys.path.insert(0, 'hooks/shadowgit/python'); from shadowgit_avx2 import ShadowGitAVX2; s = ShadowGitAVX2(); print(s.get_info())" 2>/dev/null; then
        status_healthy "Shadowgit AVX2 module functional"
    else
        status_degraded "Shadowgit import/execution issues"
    fi
else
    status_unhealthy "Shadowgit directory MISSING"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# NPU BRIDGE HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🧠 NPU Coordination Bridge${RESET}"

if [[ -d "agents/src/rust/npu_coordination_bridge" ]]; then
    status_healthy "NPU bridge directory exists"

    if [[ -f "agents/src/rust/npu_coordination_bridge/Cargo.toml" ]]; then
        status_healthy "Cargo project configured"

        # Check for compiled library
        if [[ -f "agents/src/rust/npu_coordination_bridge/target/release/libnpu_coordination_bridge.so" ]]; then
            LIB_SIZE=$(du -h "agents/src/rust/npu_coordination_bridge/target/release/libnpu_coordination_bridge.so" 2>/dev/null | cut -f1)
            status_healthy "Compiled library exists ($LIB_SIZE)"
        elif [[ -f "agents/src/rust/npu_coordination_bridge/target/debug/libnpu_coordination_bridge.so" ]]; then
            status_degraded "Debug library exists (rebuild with --release for production)"
        else
            status_degraded "Library not compiled (run: cargo build --release)"
        fi
    else
        status_unhealthy "Cargo.toml MISSING"
    fi
else
    status_unhealthy "NPU bridge directory MISSING"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# OPENVINO HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🚀 OpenVINO Runtime${RESET}"

if [[ -d "openvino/scripts" ]]; then
    SCRIPT_COUNT=$(find openvino/scripts -name "*.sh" -o -name "*.py" | wc -l)
    status_healthy "OpenVINO scripts present ($SCRIPT_COUNT scripts)"

    # Check if OpenVINO is configured in shell
    if grep -q "OPENVINO" ~/.bashrc 2>/dev/null || grep -q "openvino" ~/.bashrc 2>/dev/null; then
        status_healthy "OpenVINO environment configured in .bashrc"
    else
        status_degraded "OpenVINO not in shell config (run setup script)"
    fi

    # Check system OpenVINO
    if command -v ov-info >/dev/null 2>&1; then
        status_healthy "OpenVINO system installation detected"
    else
        status_degraded "OpenVINO not installed system-wide"
    fi
else
    status_unhealthy "OpenVINO directory MISSING"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PICMCS HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}📝 PICMCS Context Chopping${RESET}"

if [[ -f "hooks/context_chopping_hooks.py" ]]; then
    FILE_SIZE=$(du -h "hooks/context_chopping_hooks.py" 2>/dev/null | cut -f1)
    status_healthy "PICMCS hooks file exists ($FILE_SIZE)"

    if python3 -m py_compile hooks/context_chopping_hooks.py 2>/dev/null; then
        status_healthy "PICMCS hooks syntax valid"
    else
        status_degraded "PICMCS hooks may have syntax errors"
    fi
else
    status_unhealthy "PICMCS hooks file MISSING"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# OVERALL SYSTEM HEALTH
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}Overall System Health${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

TOTAL_COMPONENTS=$((HEALTHY + DEGRADED + UNHEALTHY))
HEALTH_PERCENTAGE=$((HEALTHY * 100 / TOTAL_COMPONENTS))

echo -e "  Healthy:    ${GREEN}$HEALTHY${RESET} components"
echo -e "  Degraded:   ${YELLOW}$DEGRADED${RESET} components"
echo -e "  Unhealthy:  ${RED}$UNHEALTHY${RESET} components"
echo ""

if [[ $HEALTH_PERCENTAGE -ge 90 ]]; then
    echo -e "${GREEN}${BOLD}✅ System Status: EXCELLENT ($HEALTH_PERCENTAGE% healthy)${RESET}"
    EXIT_CODE=0
elif [[ $HEALTH_PERCENTAGE -ge 75 ]]; then
    echo -e "${YELLOW}${BOLD}⚠️  System Status: GOOD ($HEALTH_PERCENTAGE% healthy)${RESET}"
    EXIT_CODE=0
elif [[ $HEALTH_PERCENTAGE -ge 50 ]]; then
    echo -e "${YELLOW}${BOLD}⚠️  System Status: DEGRADED ($HEALTH_PERCENTAGE% healthy)${RESET}"
    EXIT_CODE=1
else
    echo -e "${RED}${BOLD}❌ System Status: CRITICAL ($HEALTH_PERCENTAGE% healthy)${RESET}"
    EXIT_CODE=2
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "Run this script periodically to monitor system health"
echo "For detailed checks, see: ./scripts/validate-all-modules.sh"
echo ""

exit $EXIT_CODE
