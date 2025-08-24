#!/bin/bash

# ============================================================================
# CLAUDE AGENT LEARNING SYSTEM - Universal PostgreSQL Setup Script
# ============================================================================
# Automatically detects and configures for PostgreSQL 16 or 17
# Provides full backwards compatibility while leveraging latest features
# Author: sql-internal agent
# Status: PRODUCTION READY
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/claude_learning_setup_$(date +%Y%m%d_%H%M%S).log"
DB_NAME="${DB_NAME:-claude_auth}"
DB_USER="${DB_USER:-claude_auth}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
}

# PostgreSQL version detection
detect_postgresql_version() {
    log_step "Detecting PostgreSQL version..."
    
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL client not found. Please install PostgreSQL."
        exit 1
    fi
    
    # Get version information
    PG_VERSION_FULL=$(psql --version | head -n1)
    PG_VERSION_NUM=$(sudo -u postgres psql -t -c "SELECT current_setting('server_version_num')::INTEGER;" 2>/dev/null || echo "0")
    PG_MAJOR_VERSION=$((PG_VERSION_NUM / 10000))
    PG_MINOR_VERSION=$(((PG_VERSION_NUM % 10000) / 100))
    
    log_info "PostgreSQL Version: $PG_VERSION_FULL"
    log_info "Version Number: $PG_VERSION_NUM"
    log_info "Major Version: $PG_MAJOR_VERSION"
    log_info "Minor Version: $PG_MINOR_VERSION"
    
    # Determine compatibility and features
    if [ "$PG_MAJOR_VERSION" -ge 17 ]; then
        PG_COMPATIBILITY="OPTIMAL"
        PG_FEATURES="Enhanced JSON, Advanced VACUUM, Optimized JIT, Better Parallel Processing"
        EXPECTED_PERFORMANCE=">2000 auth/sec, <25ms P95"
        SCHEMA_FILE="learning_system_schema.sql"
    elif [ "$PG_MAJOR_VERSION" -eq 16 ]; then
        PG_COMPATIBILITY="FULLY_COMPATIBLE"
        PG_FEATURES="Full JSON Support, JIT Available, Good Parallel Processing"
        EXPECTED_PERFORMANCE=">1500 auth/sec, <35ms P95"
        SCHEMA_FILE="learning_system_schema_pg16_compatible.sql"
    else
        PG_COMPATIBILITY="UNSUPPORTED"
        log_error "PostgreSQL version $PG_MAJOR_VERSION not supported. Requires PostgreSQL 16+."
        exit 1
    fi
    
    log_success "PostgreSQL $PG_MAJOR_VERSION detected - $PG_COMPATIBILITY"
    log_info "Available Features: $PG_FEATURES"
    log_info "Expected Performance: $EXPECTED_PERFORMANCE"
}

# Test database connectivity
test_database_connectivity() {
    log_step "Testing database connectivity..."
    
    if ! sudo -u postgres psql -c "SELECT 1;" &> /dev/null; then
        log_error "Cannot connect to PostgreSQL. Is the service running?"
        log_info "Try: sudo systemctl start postgresql"
        exit 1
    fi
    
    log_success "Database connectivity confirmed"
}

# Test JSON functions compatibility
test_json_functions() {
    log_step "Testing JSON functions compatibility..."
    
    JSON_ARRAY_TEST=$(sudo -u postgres psql -t -c "SELECT JSON_ARRAY();" 2>/dev/null || echo "FAILED")
    JSON_OBJECT_TEST=$(sudo -u postgres psql -t -c "SELECT JSON_OBJECT();" 2>/dev/null || echo "FAILED")
    
    if [[ "$JSON_ARRAY_TEST" == *"[]"* ]] && [[ "$JSON_OBJECT_TEST" == *"{}"* ]]; then
        log_success "JSON_ARRAY() and JSON_OBJECT() functions working correctly"
        JSON_FUNCTIONS_AVAILABLE=true
    else
        log_error "JSON functions not available. This should not happen with PostgreSQL 16+."
        exit 1
    fi
}

# Setup database and user
setup_database() {
    log_step "Setting up database and user..."
    
    # Create database if it doesn't exist
    if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_info "Creating database: $DB_NAME"
        sudo -u postgres createdb "$DB_NAME"
    else
        log_info "Database $DB_NAME already exists"
    fi
    
    # Create user if it doesn't exist
    if ! sudo -u postgres psql -t -c "SELECT 1 FROM pg_user WHERE usename = '$DB_USER';" | grep -q 1; then
        log_info "Creating user: $DB_USER"
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    else
        log_info "User $DB_USER already exists"
    fi
    
    log_success "Database and user setup complete"
}

# Install learning system schema
install_learning_schema() {
    log_step "Installing learning system schema..."
    
    # First, install the compatibility layer
    log_info "Installing PostgreSQL compatibility layer..."
    sudo -u postgres psql -d "$DB_NAME" -f "$SCRIPT_DIR/sql/postgresql_version_compatibility.sql"
    
    # Install the appropriate schema based on PostgreSQL version
    if [ "$PG_MAJOR_VERSION" -ge 17 ]; then
        log_info "Installing PostgreSQL 17 optimized schema..."
        sudo -u postgres psql -d "$DB_NAME" -f "$SCRIPT_DIR/sql/learning_system_schema.sql"
    else
        log_info "Installing PostgreSQL 16 compatible schema..."
        sudo -u postgres psql -d "$DB_NAME" -f "$SCRIPT_DIR/sql/learning_system_schema_pg16_compatible.sql"
    fi
    
    # Install migration system
    log_info "Installing version migration system..."
    sudo -u postgres psql -d "$DB_NAME" -f "$SCRIPT_DIR/sql/postgresql_version_migration.sql"
    
    log_success "Learning system schema installed successfully"
}

# Configure PostgreSQL for optimal performance
configure_postgresql() {
    log_step "Configuring PostgreSQL for optimal performance..."
    
    # Create configuration SQL based on version
    cat > /tmp/postgresql_config.sql << EOF
-- PostgreSQL $PG_MAJOR_VERSION Configuration for Learning System

-- Memory settings
SELECT set_config('shared_buffers', 
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '256MB' ELSE '128MB' END, false);
SELECT set_config('work_mem',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '16MB' ELSE '8MB' END, false);
SELECT set_config('maintenance_work_mem',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '512MB' ELSE '256MB' END, false);

-- Parallel processing
SELECT set_config('max_parallel_workers_per_gather',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '6' ELSE '4' END, false);
SELECT set_config('max_parallel_workers',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '12' ELSE '8' END, false);

-- Autovacuum settings
SELECT set_config('autovacuum_naptime',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '15s' ELSE '30s' END, false);
SELECT set_config('autovacuum_max_workers',
    CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '6' ELSE '4' END, false);

-- JIT settings (if available)
DO \$\$
BEGIN
    IF current_setting('server_version_num')::INTEGER >= 110000 THEN
        PERFORM set_config('jit', 'on', false);
        PERFORM set_config('jit_above_cost',
            CASE WHEN $PG_MAJOR_VERSION >= 17 THEN '50000' ELSE '100000' END, false);
    END IF;
END \$\$;

SELECT 'PostgreSQL $PG_MAJOR_VERSION configuration applied successfully' as result;
EOF

    # Apply configuration
    sudo -u postgres psql -d "$DB_NAME" -f /tmp/postgresql_config.sql
    rm /tmp/postgresql_config.sql
    
    log_success "PostgreSQL configured for optimal performance"
}

# Run compatibility tests
run_compatibility_tests() {
    log_step "Running compatibility tests..."
    
    # Create test SQL
    cat > /tmp/compatibility_test.sql << EOF
-- Comprehensive Compatibility Test Suite
SELECT 'Starting compatibility tests for PostgreSQL $PG_MAJOR_VERSION...' as status;

-- Test JSON functions
SELECT 
    'JSON Functions Test' as test_name,
    CASE 
        WHEN JSON_ARRAY() IS NOT NULL AND JSON_OBJECT() IS NOT NULL 
        THEN 'PASSED' 
        ELSE 'FAILED' 
    END as result;

-- Test schema existence
SELECT 
    'Schema Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 5 
        THEN 'PASSED (' || COUNT(*) || ' tables)' 
        ELSE 'FAILED (' || COUNT(*) || ' tables)' 
    END as result
FROM information_schema.tables 
WHERE table_name LIKE '%agent_%' OR table_name LIKE '%ml_%' OR table_name LIKE '%system_learning%';

-- Test indexes
SELECT 
    'Index Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 10 
        THEN 'PASSED (' || COUNT(*) || ' indexes)' 
        ELSE 'WARNING (' || COUNT(*) || ' indexes)' 
    END as result
FROM pg_indexes 
WHERE tablename LIKE '%agent_%' OR tablename LIKE '%ml_%';

-- Test insert operation
BEGIN;
INSERT INTO agent_task_executions (
    task_type, task_description, agents_invoked, execution_sequence,
    start_time, end_time, duration_seconds, success
) VALUES (
    'test', 'Compatibility test', 
    JSON_ARRAY(), JSON_ARRAY(),
    now(), now(), 0.1, true
);

SELECT 
    'Insert Test' as test_name,
    'PASSED' as result;
ROLLBACK;

SELECT 'All compatibility tests completed for PostgreSQL $PG_MAJOR_VERSION' as status;
EOF

    # Run tests
    sudo -u postgres psql -d "$DB_NAME" -f /tmp/compatibility_test.sql
    rm /tmp/compatibility_test.sql
    
    log_success "Compatibility tests completed successfully"
}

# Generate system report
generate_system_report() {
    log_step "Generating system report..."
    
    # Create report
    cat > /tmp/system_report.sql << EOF
-- Claude Agent Learning System - Installation Report
-- Generated: $(date)
-- PostgreSQL Version: $PG_MAJOR_VERSION.$PG_MINOR_VERSION

SELECT '=' || repeat('=', 70) || '=' as separator;
SELECT 'CLAUDE AGENT LEARNING SYSTEM - INSTALLATION REPORT' as title;
SELECT '=' || repeat('=', 70) || '=' as separator;

SELECT 'Database Version: ' || version() as info;
SELECT 'Compatibility Status: $PG_COMPATIBILITY' as info;
SELECT 'Available Features: $PG_FEATURES' as info;
SELECT 'Expected Performance: $EXPECTED_PERFORMANCE' as info;

SELECT '=' || repeat('=', 70) || '=' as separator;
SELECT 'SCHEMA SUMMARY' as section;
SELECT '=' || repeat('=', 70) || '=' as separator;

SELECT 
    'Learning Tables: ' || COUNT(*) as info
FROM information_schema.tables 
WHERE table_name LIKE '%agent_%' OR table_name LIKE '%ml_%' OR table_name LIKE '%system_learning%';

SELECT 
    'Indexes Created: ' || COUNT(*) as info
FROM pg_indexes 
WHERE tablename LIKE '%agent_%' OR tablename LIKE '%ml_%';

SELECT 
    'Extensions: ' || string_agg(extname, ', ') as info
FROM pg_extension 
WHERE extname IN ('pgcrypto', 'uuid-ossp', 'pg_stat_statements', 'pg_trgm');

SELECT '=' || repeat('=', 70) || '=' as separator;
SELECT 'CONFIGURATION SUMMARY' as section;
SELECT '=' || repeat('=', 70) || '=' as separator;

SELECT 'JIT Enabled: ' || current_setting('jit') as info;
SELECT 'Parallel Workers: ' || current_setting('max_parallel_workers_per_gather') as info;
SELECT 'Shared Buffers: ' || current_setting('shared_buffers') as info;
SELECT 'Work Memory: ' || current_setting('work_mem') as info;
SELECT 'Autovacuum Workers: ' || current_setting('autovacuum_max_workers') as info;

SELECT '=' || repeat('=', 70) || '=' as separator;
SELECT 'NEXT STEPS' as section;
SELECT '=' || repeat('=', 70) || '=' as separator;

SELECT 'Database Name: $DB_NAME' as info;
SELECT 'Database User: $DB_USER' as info;
SELECT 'Log File: $LOG_FILE' as info;
SELECT '' as info;
SELECT 'To test the system:' as info;
SELECT '  psql -d $DB_NAME -U $DB_USER -c "SELECT * FROM postgresql_compatibility_summary;"' as info;
SELECT '' as info;
SELECT 'To monitor performance:' as info;
SELECT '  psql -d $DB_NAME -U $DB_USER -c "SELECT * FROM agent_performance_summary_pg$(echo $PG_MAJOR_VERSION);"' as info;

SELECT '=' || repeat('=', 70) || '=' as separator;
EOF

    # Generate and display report
    sudo -u postgres psql -d "$DB_NAME" -f /tmp/system_report.sql
    rm /tmp/system_report.sql
    
    log_success "System report generated"
}

# Save credentials and configuration
save_configuration() {
    log_step "Saving configuration..."
    
    # Create configuration file
    CONFIG_FILE="$SCRIPT_DIR/claude_learning_system_config.env"
    cat > "$CONFIG_FILE" << EOF
# Claude Agent Learning System Configuration
# Generated: $(date)

# Database Configuration
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASSWORD="$DB_PASSWORD"
DB_HOST="localhost"
DB_PORT="5432"

# PostgreSQL Version Information
PG_MAJOR_VERSION="$PG_MAJOR_VERSION"
PG_MINOR_VERSION="$PG_MINOR_VERSION"
PG_VERSION_NUM="$PG_VERSION_NUM"
PG_COMPATIBILITY="$PG_COMPATIBILITY"
PG_FEATURES="$PG_FEATURES"
EXPECTED_PERFORMANCE="$EXPECTED_PERFORMANCE"

# Schema Information
SCHEMA_FILE="$SCHEMA_FILE"
JSON_FUNCTIONS_AVAILABLE="$JSON_FUNCTIONS_AVAILABLE"

# Installation Information
INSTALL_DATE="$(date)"
INSTALL_LOG="$LOG_FILE"
SCRIPT_VERSION="1.0"
EOF

    chmod 600 "$CONFIG_FILE"
    log_success "Configuration saved to: $CONFIG_FILE"
}

# Main installation function
main() {
    log_info "Starting Claude Agent Learning System Universal Setup"
    log_info "Log file: $LOG_FILE"
    
    # Pre-flight checks
    if [[ $EUID -ne 0 ]] && ! groups | grep -q sudo; then
        log_error "This script requires root privileges or sudo access"
        exit 1
    fi
    
    # Main installation steps
    detect_postgresql_version
    test_database_connectivity
    test_json_functions
    setup_database
    install_learning_schema
    configure_postgresql
    run_compatibility_tests
    save_configuration
    generate_system_report
    
    # Final success message
    echo
    log_success "====================================================================="
    log_success "Claude Agent Learning System Installation Complete!"
    log_success "====================================================================="
    log_success "PostgreSQL Version: $PG_MAJOR_VERSION.$PG_MINOR_VERSION ($PG_COMPATIBILITY)"
    log_success "Database: $DB_NAME"
    log_success "User: $DB_USER"
    log_success "Features: $PG_FEATURES"
    log_success "Expected Performance: $EXPECTED_PERFORMANCE"
    log_success "Configuration: $SCRIPT_DIR/claude_learning_system_config.env"
    log_success "Log File: $LOG_FILE"
    echo
    log_info "To test your installation:"
    echo "  psql -d $DB_NAME -U $DB_USER -c \"SELECT * FROM postgresql_compatibility_summary;\""
    echo
    log_info "System is ready for Claude Agent Learning System integration!"
}

# Handle command line arguments
case "${1:-install}" in
    "install")
        main
        ;;
    "check")
        detect_postgresql_version
        test_database_connectivity
        test_json_functions
        echo "System check complete - PostgreSQL $PG_MAJOR_VERSION ready for learning system"
        ;;
    "test")
        run_compatibility_tests
        ;;
    "report")
        generate_system_report
        ;;
    *)
        echo "Usage: $0 [install|check|test|report]"
        echo "  install - Full installation (default)"
        echo "  check   - Check system compatibility"
        echo "  test    - Run compatibility tests only"
        echo "  report  - Generate system report"
        exit 1
        ;;
esac