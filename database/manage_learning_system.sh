#!/bin/bash
# ============================================================================
# Claude Agent Learning System - Database Management Script
# Integrates with existing PostgreSQL 17 database infrastructure
# ============================================================================

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-claude_agents}"
DB_USER="${DB_USER:-postgres}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PostgreSQL is available
check_postgresql() {
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL client (psql) not found. Please install PostgreSQL."
        return 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Please install Python 3."
        return 1
    fi
    
    return 0
}

# Test database connection
test_connection() {
    log_info "Testing database connection to ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" &>/dev/null; then
        local version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" | head -1 | xargs)
        log_success "Connected to database: $version"
        return 0
    else
        log_error "Failed to connect to database. Please check your connection parameters."
        return 1
    fi
}

# Setup learning system schema
setup_schema() {
    log_info "Setting up learning system schema..."
    
    local schema_file="$SCRIPT_DIR/sql/learning_system_schema.sql"
    
    if [[ ! -f "$schema_file" ]]; then
        log_error "Schema file not found: $schema_file"
        return 1
    fi
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$schema_file"; then
        log_success "Learning system schema setup complete"
        return 0
    else
        log_error "Failed to setup learning system schema"
        return 1
    fi
}

# Install Python dependencies
install_dependencies() {
    log_info "Installing Python dependencies for learning system..."
    
    local requirements=(
        "asyncpg>=0.27.0"
        "psycopg2-binary>=2.9.0"
        "numpy>=1.21.0"
        "scikit-learn>=1.0.0"
        "joblib>=1.0.0"
    )
    
    for package in "${requirements[@]}"; do
        log_info "Installing $package..."
        if python3 -m pip install "$package" --quiet; then
            log_success "Installed $package"
        else
            log_warning "Failed to install $package (may already be installed)"
        fi
    done
}

# Verify integration
verify_integration() {
    log_info "Verifying learning system integration..."
    
    cd "$SCRIPT_DIR/python"
    
    # Set environment variables
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    
    if python3 postgresql_learning_integration.py; then
        log_success "Learning system integration verified"
        return 0
    else
        log_error "Learning system integration verification failed"
        return 1
    fi
}

# Show database status
show_status() {
    log_info "Learning System Database Status"
    echo "=================================="
    
    # Connection info
    echo "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "User: ${DB_USER}"
    echo ""
    
    # Check if connected
    if ! test_connection &>/dev/null; then
        log_error "Cannot connect to database"
        return 1
    fi
    
    # Get learning system statistics
    local stats=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT 
            COALESCE((SELECT COUNT(*) FROM agent_task_executions), 0) as executions,
            COALESCE((SELECT COUNT(*) FROM agent_performance_metrics), 0) as agents,
            COALESCE((SELECT COUNT(*) FROM agent_combination_patterns WHERE sample_size >= 5), 0) as patterns,
            COALESCE((SELECT COUNT(*) FROM agent_learning_insights WHERE is_active = true), 0) as insights;
    " 2>/dev/null || echo "0|0|0|0")
    
    IFS='|' read -r executions agents patterns insights <<< "$stats"
    
    echo "Learning System Statistics:"
    echo "  Task Executions: $executions"
    echo "  Tracked Agents: $agents" 
    echo "  Combination Patterns: $patterns"
    echo "  Active Insights: $insights"
    echo ""
    
    # Database size
    local size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT pg_size_pretty(pg_database_size('$DB_NAME'));
    " 2>/dev/null | xargs)
    
    echo "Database Size: ${size:-unknown}"
    
    # Check for learning tables
    local tables=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name LIKE 'agent_%';
    " 2>/dev/null | xargs)
    
    echo "Learning Tables: ${tables:-0}"
}

# Run learning system tests
run_tests() {
    log_info "Running learning system tests..."
    
    cd "$SCRIPT_DIR/python"
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    
    # Run the PostgreSQL learning system demo
    if python3 postgresql_learning_system.py demo; then
        log_success "Learning system tests passed"
    else
        log_error "Learning system tests failed"
        return 1
    fi
}

# Create sample data
create_sample_data() {
    log_info "Creating sample learning data..."
    
    cd "$SCRIPT_DIR/python"
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    
    if python3 -c "
import asyncio
from postgresql_learning_integration import DatabaseLearningIntegration

async def create_samples():
    integration = DatabaseLearningIntegration()
    result = await integration.create_sample_learning_data()
    print(result)

asyncio.run(create_samples())
"; then
        log_success "Sample data created"
    else
        log_error "Failed to create sample data"
        return 1
    fi
}

# Export learning data
export_data() {
    local output_file="${1:-learning_export_$(date +%Y%m%d_%H%M%S).json}"
    
    log_info "Exporting learning data to $output_file..."
    
    cd "$SCRIPT_DIR/python"
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    
    if python3 postgresql_learning_system.py export "$output_file"; then
        log_success "Learning data exported to $output_file"
    else
        log_error "Failed to export learning data"
        return 1
    fi
}

# Cleanup old data
cleanup_data() {
    log_info "Cleaning up old learning data..."
    
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT * FROM cleanup_learning_data();
    "
    
    log_success "Learning data cleanup complete"
}

# Show learning dashboard
show_dashboard() {
    log_info "Learning System Dashboard"
    echo "========================="
    
    cd "$SCRIPT_DIR/python"
    export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
    
    python3 postgresql_learning_system.py dashboard
}

# Main command handler
main() {
    local command="${1:-help}"
    
    # Check for password
    if [[ -z "$DB_PASSWORD" ]]; then
        echo -n "Enter PostgreSQL password for user $DB_USER: "
        read -s DB_PASSWORD
        echo
        export DB_PASSWORD
    fi
    
    case "$command" in
        "setup")
            log_info "Setting up learning system..."
            check_postgresql || exit 1
            test_connection || exit 1
            install_dependencies || exit 1
            setup_schema || exit 1
            verify_integration || exit 1
            log_success "Learning system setup complete!"
            ;;
        "status")
            show_status
            ;;
        "test")
            check_postgresql || exit 1
            test_connection || exit 1
            run_tests
            ;;
        "verify")
            verify_integration
            ;;
        "sample")
            create_sample_data
            ;;
        "export")
            export_data "$2"
            ;;
        "cleanup")
            cleanup_data
            ;;
        "dashboard")
            show_dashboard
            ;;
        "connect")
            log_info "Connecting to database..."
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
            ;;
        "help"|*)
            cat << EOF
Claude Agent Learning System - Database Management

Usage: $0 <command> [options]

Commands:
  setup              Full setup of learning system (schema + dependencies)
  status             Show learning system database status
  test               Run learning system tests
  verify             Verify integration with existing database
  sample             Create sample learning data for testing
  export [file]      Export learning data to JSON file
  cleanup            Clean up old learning data
  dashboard          Show learning system dashboard
  connect            Connect to database with psql
  help               Show this help message

Environment Variables:
  DB_HOST            Database host (default: localhost)
  DB_PORT            Database port (default: 5432)
  DB_NAME            Database name (default: claude_agents)
  DB_USER            Database user (default: postgres)
  DB_PASSWORD        Database password (will prompt if not set)

Examples:
  $0 setup                    # Full setup
  $0 status                   # Check status
  $0 test                     # Run tests
  $0 export my_data.json      # Export to specific file
  $0 dashboard                # View dashboard

The learning system integrates with your existing PostgreSQL 17 database
and provides AI-powered agent orchestration optimization.
EOF
            ;;
    esac
}

# Run main function with all arguments
main "$@"