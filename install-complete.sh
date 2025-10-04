#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Agent Framework - Complete Installation Orchestrator
# Unified installation script for all 10 modules
# Version: 1.0 Production
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ═══════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${RESET} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${RESET} $1" >&2
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        log_success "$1 is available"
        return 0
    else
        log_warning "$1 not found"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# HEADER
# ═══════════════════════════════════════════════════════════════════════════

clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║           Claude Agent Framework - Complete Installation                ║
║                                                                          ║
║                     All 10 Modules - Unified Setup                       ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"
echo ""

log_info "Installation starting at $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: SYSTEM PREREQUISITES
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 1: System Prerequisites${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

log_info "Checking system requirements..."

# Check Python
if check_command python3; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    log_info "Python version: $PYTHON_VERSION"
else
    log_error "Python 3 is required but not installed"
    exit 1
fi

# Check Docker
if check_command docker; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_info "Docker version: $DOCKER_VERSION"
else
    log_warning "Docker not found - some modules will run in non-containerized mode"
fi

# Check Rust (for NPU bridge)
if check_command cargo; then
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    log_info "Cargo version: $CARGO_VERSION"
else
    log_warning "Rust/Cargo not found - NPU bridge will need manual compilation"
fi

# Check GCC (for C modules)
if check_command gcc; then
    GCC_VERSION=$(gcc --version | head -1 | awk '{print $NF}')
    log_info "GCC version: $GCC_VERSION"
else
    log_warning "GCC not found - C acceleration may not compile"
fi

# Check Make
check_command make || log_warning "Make not found - manual build required"

# Check npm
check_command npm || log_warning "npm not found - Claude Code install may need manual setup"

echo ""
log_success "Prerequisites check complete"
echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: DATABASE SETUP
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 2: Database Systems (PostgreSQL 16 + pgvector)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -f "database/scripts/install.sh" ]]; then
    log_info "Installing database system..."
    if bash database/scripts/install.sh; then
        log_success "Database system installed"
    else
        log_warning "Database install had issues (may already be installed)"
    fi
else
    if [[ -d "database" ]] && command -v docker >/dev/null 2>&1; then
        log_info "Starting database via Docker Compose..."
        cd database
        if docker-compose up -d; then
            log_success "Database containers started"
        else
            log_warning "Database containers may already be running"
        fi
        cd "$SCRIPT_DIR"
    else
        log_warning "Database directory not found or Docker unavailable"
    fi
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: LEARNING SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 3: Learning System v2.0${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -f "learning-system/scripts/setup.sh" ]]; then
    log_info "Setting up learning system..."
    if bash learning-system/scripts/setup.sh; then
        log_success "Learning system configured"
    else
        log_warning "Learning system setup had issues"
    fi
else
    if [[ -d "learning-system" ]] && command -v docker >/dev/null 2>&1; then
        log_info "Starting learning system via Docker Compose..."
        cd learning-system
        if docker-compose up -d; then
            log_success "Learning system containers started"
        else
            log_warning "Learning containers may already be running"
        fi
        cd "$SCRIPT_DIR"
    else
        log_warning "Learning system directory not found or Docker unavailable"
    fi
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: SHADOWGIT PERFORMANCE ENGINE
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 4: Shadowgit Performance Engine (AVX2/NPU)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -d "hooks/shadowgit" ]]; then
    log_info "Installing Shadowgit module..."

    # Use enhanced installer if available
    if [[ -f "installers/claude/claude-enhanced-installer.py" ]]; then
        if python3 installers/claude/claude-enhanced-installer.py --module shadowgit 2>/dev/null; then
            log_success "Shadowgit installed via enhanced installer"
        else
            log_info "Trying direct installation..."
            # Compile C engine
            if [[ -f "hooks/shadowgit/Makefile" ]]; then
                cd hooks/shadowgit
                if make all 2>/dev/null; then
                    log_success "Shadowgit C engine compiled"
                else
                    log_warning "C engine compilation skipped (may need dependencies)"
                fi
                cd "$SCRIPT_DIR"
            fi

            # Add to PYTHONPATH
            if [[ -d "hooks/shadowgit/python" ]]; then
                SHADOWGIT_PYTHON="$SCRIPT_DIR/hooks/shadowgit/python"
                echo "export PYTHONPATH=\"$SHADOWGIT_PYTHON:\$PYTHONPATH\"" >> ~/.bashrc
                log_success "Shadowgit added to PYTHONPATH"
            fi
        fi
    else
        log_warning "Enhanced installer not found, using basic setup"
    fi
else
    log_warning "Shadowgit directory not found at hooks/shadowgit/"
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: OPENVINO RUNTIME
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 5: OpenVINO Runtime${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -d "openvino/scripts" ]]; then
    log_info "Setting up OpenVINO runtime..."

    # Run setup script
    if [[ -f "openvino/scripts/setup-openvino-bashrc.sh" ]]; then
        if bash openvino/scripts/setup-openvino-bashrc.sh 2>/dev/null; then
            log_success "OpenVINO configured"
        else
            log_warning "OpenVINO setup completed with warnings"
        fi
    fi

    # Quick test
    if [[ -f "openvino/scripts/openvino-quick-test.sh" ]]; then
        log_info "Running OpenVINO verification..."
        if bash openvino/scripts/openvino-quick-test.sh 2>/dev/null; then
            log_success "OpenVINO verification passed"
        else
            log_warning "OpenVINO verification had issues (may need system OpenVINO install)"
        fi
    fi
else
    log_warning "OpenVINO directory not found at openvino/scripts/"
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: NPU COORDINATION BRIDGE (Rust)
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 6: NPU Coordination Bridge (Rust)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -d "agents/src/rust/npu_coordination_bridge" ]] && command -v cargo >/dev/null 2>&1; then
    log_info "Building NPU coordination bridge..."
    cd agents/src/rust/npu_coordination_bridge

    if cargo build --release 2>/dev/null; then
        log_success "NPU bridge compiled successfully"

        # Install Python bindings if available
        if cargo build --release --features python-bindings 2>/dev/null; then
            log_success "Python bindings compiled"
        fi
    else
        log_warning "NPU bridge compilation failed (may need Intel NPU drivers)"
    fi

    cd "$SCRIPT_DIR"
else
    if [[ ! -d "agents/src/rust/npu_coordination_bridge" ]]; then
        log_warning "NPU bridge directory not found"
    else
        log_warning "Cargo not available - NPU bridge not compiled"
    fi
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7: AGENT SYSTEMS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 7: Agent Systems (Coordination + Ecosystem)${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Compile C agent coordination
if [[ -f "agents/src/c/Makefile" ]]; then
    log_info "Compiling C agent coordination engine..."
    cd agents/src/c

    if make clean && make all 2>/dev/null; then
        log_success "C agent engine compiled"
    else
        log_warning "C compilation skipped (may need libnuma-dev, liburing-dev)"
    fi

    cd "$SCRIPT_DIR"
fi

# Setup Python agent coordination
if [[ -f "integration/agent_coordination_matrix.py" ]]; then
    log_info "Verifying Python agent coordination..."
    if python3 -c "import sys; sys.path.insert(0, 'integration'); from agent_coordination_matrix import AgentCoordinationMatrix; print('✓')" 2>/dev/null; then
        log_success "Python coordination matrix operational"
    else
        log_warning "Python coordination needs dependencies"
    fi
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 8: PICMCS CONTEXT CHOPPING
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 8: PICMCS Context Chopping${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -f "hooks/context_chopping_hooks.py" ]]; then
    log_info "Verifying PICMCS context chopping..."
    if python3 -c "exec(open('hooks/context_chopping_hooks.py').read()); print('✓')" 2>/dev/null; then
        log_success "PICMCS hooks validated"
    else
        log_warning "PICMCS hooks may need dependencies"
    fi
else
    log_warning "PICMCS hooks not found at hooks/context_chopping_hooks.py"
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 9: ENHANCED PYTHON INSTALLER
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 9: Enhanced Python Installer & Remaining Modules${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ -f "installers/claude/claude-enhanced-installer.py" ]]; then
    log_info "Running enhanced Python installer..."
    log_info "This will install: Claude Code, agents, and remaining components"
    echo ""

    # Run with all modules enabled
    if python3 installers/claude/claude-enhanced-installer.py \
        --install-agents \
        --install-database \
        --install-learning-system \
        --install-picmcs 2>&1 | tee /tmp/claude-install.log; then
        log_success "Enhanced installer completed"
    else
        EXIT_CODE=$?
        log_warning "Enhanced installer finished with code $EXIT_CODE (check /tmp/claude-install.log)"
    fi
else
    log_warning "Enhanced Python installer not found"
    log_info "Trying basic installer..."

    if [[ -f "./install" ]]; then
        if bash ./install; then
            log_success "Basic installer completed"
        else
            log_warning "Basic installer had issues"
        fi
    fi
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 10: INTEGRATION VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 10: Cross-Module Integration Validation${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

log_info "Validating module integration..."

# Check Docker services
if command -v docker >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$(docker ps --filter "name=claude" --format "{{.Names}}" 2>/dev/null | wc -l)
    if [[ $RUNNING_CONTAINERS -gt 0 ]]; then
        log_success "Found $RUNNING_CONTAINERS Claude containers running"
        docker ps --filter "name=claude" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_info "No Docker containers running (OK if not using Docker mode)"
    fi
fi

echo ""

# Check Python modules
log_info "Checking Python module imports..."

MODULES_TO_CHECK=(
    "integration.agent_coordination_matrix:AgentCoordinationMatrix"
    "hooks.shadowgit.python.shadowgit_avx2:ShadowGitAVX2"
)

for module_check in "${MODULES_TO_CHECK[@]}"; do
    module="${module_check%:*}"
    class="${module_check#*:}"

    if python3 -c "from ${module} import ${class}; print('✓')" 2>/dev/null; then
        log_success "${module} is importable"
    else
        log_warning "${module} import failed (may need PYTHONPATH or dependencies)"
    fi
done

echo ""

# Check file structure
log_info "Verifying critical directories..."

CRITICAL_DIRS=(
    "agents"
    "database"
    "learning-system"
    "hooks/shadowgit"
    "openvino"
    "integration"
    "lib"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log_success "$dir/"
    else
        log_warning "$dir/ not found"
    fi
done

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 11: HEALTH CHECKS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Phase 11: System Health Checks${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Database health
if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude_postgres; then
        log_info "Checking database health..."
        if docker exec claude_postgres pg_isready -U claude 2>/dev/null; then
            log_success "Database is healthy"
        else
            log_warning "Database health check failed"
        fi
    fi

    # Learning API health
    if docker ps | grep -q claude_learning; then
        log_info "Checking learning API health..."
        if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
            log_success "Learning API is healthy"
        else
            log_warning "Learning API not responding (may still be starting)"
        fi
    fi
fi

# Check for compiled binaries
if [[ -f "agents/build/bin/agent_bridge" ]]; then
    log_success "Agent bridge binary found"
fi

if [[ -f "agents/src/rust/npu_coordination_bridge/target/release/libnpu_coordination_bridge.so" ]]; then
    log_success "NPU bridge shared library found"
fi

echo ""
sleep 1

# ═══════════════════════════════════════════════════════════════════════════
# COMPLETION SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${GREEN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    ✅ INSTALLATION COMPLETE ✅                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"
echo ""

log_success "All 10 modules processed"
echo ""

echo -e "${BOLD}📋 Next Steps:${RESET}"
echo ""
echo "1. Source your shell config:"
echo "   ${CYAN}source ~/.bashrc${RESET}"
echo ""
echo "2. Verify installations:"
echo "   ${CYAN}claude --version${RESET}"
echo "   ${CYAN}docker ps${RESET} (check containers)"
echo "   ${CYAN}python3 -c 'from hooks.shadowgit.python import shadowgit_avx2'${RESET}"
echo ""
echo "3. View system status:"
echo "   ${CYAN}./scripts/health-check-all.sh${RESET} (if created)"
echo ""
echo "4. Access services:"
echo "   ${CYAN}http://localhost:5050${RESET} - pgAdmin (database)"
echo "   ${CYAN}http://localhost:8001/docs${RESET} - Learning API"
echo ""
echo "5. Documentation:"
echo "   ${CYAN}firefox html/index.html${RESET} - Interactive system map"
echo ""

log_info "Installation log: /tmp/claude-install.log"
log_info "For issues, check: html/modules/FINAL_INTEGRATION_REPORT.md"
echo ""

echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}Installation completed at $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════${RESET}"
echo ""
