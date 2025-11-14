#!/bin/bash
# Validate Docker Configuration - Comprehensive Validation Script
# Based on agent recommendations from PATCHER, DEBUGGER, OPTIMIZER, LEADENGINEER, QADIRECTOR

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Auto-detect project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATION_PASSED=0
VALIDATION_FAILED=0

log() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((VALIDATION_PASSED++))
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    ((VALIDATION_FAILED++))
}

echo "======================================================"
echo "     Docker Configuration Validation Report"
echo "   Based on Agent Recommendations (COMPREHENSIVE)"
echo "======================================================"
echo

# PATCHER Fixes Validation
echo "🔧 PATCHER FIXES VALIDATION:"
echo "-------------------------------"

# 1. Docker Compose File Validation
if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
    log "docker-compose.yml exists"
    
    # Check for security improvements (PATCHER fix)
    if grep -q "POSTGRES_HOST_AUTH_METHOD.*trust" "$PROJECT_ROOT/docker-compose.yml"; then
        error "Security risk: trust authentication still enabled"
    else
        log "Security: trust authentication properly disabled"
    fi
    
    # Check for proper port configuration
    if grep -q "5433:5432" "$PROJECT_ROOT/docker-compose.yml"; then
        log "Port configuration: PostgreSQL on 5433 (no conflicts)"
    else
        error "Port configuration: PostgreSQL port mapping not found"
    fi
    
    # Check for health checks
    if grep -q "healthcheck:" "$PROJECT_ROOT/docker-compose.yml"; then
        log "Health checks: properly configured"
    else
        error "Health checks: missing from services"
    fi
else
    error "docker-compose.yml missing"
fi

# 2. Dockerfile Validation
if [[ -f "$PROJECT_ROOT/database/docker/Dockerfile.learning" ]]; then
    log "Dockerfile.learning exists"
    
    # Check for non-root user (security)
    if grep -q "USER claude" "$PROJECT_ROOT/database/docker/Dockerfile.learning"; then
        log "Security: non-root user configured in learning container"
    else
        error "Security: learning container running as root"
    fi
else
    error "Dockerfile.learning missing"
fi

if [[ -f "$PROJECT_ROOT/database/docker/Dockerfile.bridge" ]]; then
    log "Dockerfile.bridge exists"
    
    # Check for non-root user (security)
    if grep -q "USER claude" "$PROJECT_ROOT/database/docker/Dockerfile.bridge"; then
        log "Security: non-root user configured in bridge container"
    else
        error "Security: bridge container running as root"
    fi
else
    error "Dockerfile.bridge missing"
fi

echo

# DEBUGGER Analysis Validation
echo "🔍 DEBUGGER ANALYSIS VALIDATION:"
echo "-----------------------------------"

# 3. Required Directories
directories=(
    "$PROJECT_ROOT/database/data/postgresql"
    "$PROJECT_ROOT/database/sql"
    "$PROJECT_ROOT/database/docker/config"
    "$PROJECT_ROOT/logs"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        log "Directory exists: $(basename $dir)"
    else
        error "Directory missing: $dir"
    fi
done

# 4. Required SQL Files
sql_files=(
    "auth_db_setup.sql"
    "learning_system_schema_pg16_compatible.sql"
    "postgresql_16_json_compatibility_layer.sql"
)

for file in "${sql_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/database/sql/$file" ]]; then
        log "SQL file exists: $file"
    else
        error "SQL file missing: $file"
    fi
done

# 5. Configuration Files
config_files=(
    "$PROJECT_ROOT/database/docker/config/postgresql.conf"
    "$PROJECT_ROOT/database/docker/config/prometheus.yml"
    "$PROJECT_ROOT/.env.docker"
)

for file in "${config_files[@]}"; do
    if [[ -f "$file" ]]; then
        log "Config file exists: $(basename $file)"
    else
        error "Config file missing: $file"
    fi
done

echo

# OPTIMIZER Performance Validation
echo "⚡ OPTIMIZER PERFORMANCE VALIDATION:"
echo "--------------------------------------"

# 6. PostgreSQL Configuration Check
if [[ -f "$PROJECT_ROOT/database/docker/config/postgresql.conf" ]]; then
    # Check for performance optimizations
    if grep -q "shared_buffers.*512MB" "$PROJECT_ROOT/database/docker/config/postgresql.conf"; then
        log "Performance: shared_buffers optimized (512MB)"
    else
        warn "Performance: shared_buffers not optimized"
    fi
    
    if grep -q "effective_cache_size.*1536MB" "$PROJECT_ROOT/database/docker/config/postgresql.conf"; then
        log "Performance: effective_cache_size optimized (1536MB)"
    else
        warn "Performance: effective_cache_size not optimized"
    fi
    
    if grep -q "jit = on" "$PROJECT_ROOT/database/docker/config/postgresql.conf"; then
        log "Performance: JIT compilation enabled"
    else
        warn "Performance: JIT compilation not enabled"
    fi
else
    error "PostgreSQL configuration file missing"
fi

# 7. Resource Limits Check
if grep -q "memory: 2G" "$PROJECT_ROOT/docker-compose.yml"; then
    log "Resource limits: memory limits configured"
else
    warn "Resource limits: memory limits not found"
fi

if grep -q "cpus:" "$PROJECT_ROOT/docker-compose.yml"; then
    log "Resource limits: CPU limits configured"
else
    warn "Resource limits: CPU limits not found"
fi

echo

# LEADENGINEER Hardware Validation
echo "🚀 LEADENGINEER HARDWARE VALIDATION:"
echo "---------------------------------------"

# 8. Hardware-Specific Configuration
if [[ -f "$PROJECT_ROOT/.env.docker" ]]; then
    if grep -q "METEOR_LAKE_OPTIMIZATION=true" "$PROJECT_ROOT/.env.docker"; then
        log "Hardware: Intel Meteor Lake optimization enabled"
    else
        warn "Hardware: Meteor Lake optimization not configured"
    fi
    
    if grep -q "ENABLE_AVX512=true" "$PROJECT_ROOT/.env.docker"; then
        log "Hardware: AVX-512 optimization enabled"
    else
        warn "Hardware: AVX-512 optimization not configured"
    fi
    
    if grep -q "THERMAL_THRESHOLD" "$PROJECT_ROOT/.env.docker"; then
        log "Hardware: thermal management configured"
    else
        warn "Hardware: thermal management not configured"
    fi
fi

# 9. Network Configuration
if grep -q "claude_network:" "$PROJECT_ROOT/docker-compose.yml"; then
    log "Network: custom network configured"
    
    if grep -q "ipv4_address:" "$PROJECT_ROOT/docker-compose.yml"; then
        log "Network: static IP addresses assigned"
    else
        warn "Network: static IP addresses not found"
    fi
else
    error "Network: custom network not configured"
fi

echo

# QADIRECTOR Quality Assurance Validation
echo "🛡️ QADIRECTOR QA VALIDATION:"
echo "------------------------------"

# 10. Security Validation
security_score=0

# Check environment variables security
if [[ -f "$PROJECT_ROOT/.env.docker" ]]; then
    if grep -q "POSTGRES_PASSWORD.*change" "$PROJECT_ROOT/.env.docker"; then
        warn "Security: default PostgreSQL password detected - change in production"
    else
        ((security_score++))
        log "Security: PostgreSQL password appears customized"
    fi
    
    if grep -q "JWT_SECRET.*change" "$PROJECT_ROOT/.env.docker"; then
        warn "Security: default JWT secret detected - change in production"
    else
        ((security_score++))
        log "Security: JWT secret appears customized"
    fi
fi

# Check for secrets management
if grep -q "secrets:" "$PROJECT_ROOT/docker-compose.yml"; then
    ((security_score++))
    log "Security: Docker secrets configured"
else
    warn "Security: Docker secrets not configured"
fi

# 11. Volume Security
if grep -q ":ro" "$PROJECT_ROOT/docker-compose.yml"; then
    ((security_score++))
    log "Security: read-only volumes configured"
else
    warn "Security: read-only volumes not found"
fi

# 12. Container Startup Script Validation
startup_scripts=(
    "$PROJECT_ROOT/database/docker/docker-start.sh"
    "$PROJECT_ROOT/database/docker/validate-setup.sh"
)

for script in "${startup_scripts[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            log "Script: $(basename $script) exists and is executable"
        else
            warn "Script: $(basename $script) exists but not executable"
        fi
    else
        error "Script: $(basename $script) missing"
    fi
done

echo
echo "======================================================"
echo "              VALIDATION SUMMARY"
echo "======================================================"

echo
echo "📊 VALIDATION RESULTS:"
echo "  ✅ Passed: $VALIDATION_PASSED"
echo "  ❌ Failed: $VALIDATION_FAILED"
echo "  🔒 Security Score: $security_score/4"
echo

# Overall Assessment
total_checks=$((VALIDATION_PASSED + VALIDATION_FAILED))
success_rate=$((VALIDATION_PASSED * 100 / total_checks))

echo "🎯 OVERALL ASSESSMENT:"
echo "  Success Rate: $success_rate%"

if [[ $success_rate -ge 90 ]]; then
    echo -e "  Status: ${GREEN}EXCELLENT${NC} - Ready for production deployment"
elif [[ $success_rate -ge 80 ]]; then
    echo -e "  Status: ${YELLOW}GOOD${NC} - Minor issues to address"
elif [[ $success_rate -ge 70 ]]; then
    echo -e "  Status: ${YELLOW}FAIR${NC} - Several issues need attention"
else
    echo -e "  Status: ${RED}POOR${NC} - Major issues must be resolved"
fi

echo
echo "📋 NEXT STEPS:"
if [[ $VALIDATION_FAILED -eq 0 ]]; then
    echo "  1. ✅ All validations passed - system ready for deployment"
    echo "  2. 🚀 Run: cd $PROJECT_ROOT && ./database/docker/docker-start.sh"
    echo "  3. 📊 Monitor: docker-compose logs -f"
else
    echo "  1. 🔧 Fix $VALIDATION_FAILED failed validation(s)"
    echo "  2. 🔍 Re-run validation script"
    echo "  3. 🚀 Deploy when all checks pass"
fi

if [[ $security_score -lt 4 ]]; then
    echo "  4. 🔒 Review and improve security configuration"
fi

echo
echo "======================================================"

exit $VALIDATION_FAILED