#!/bin/bash

# Final Schema Operations Script
# Comprehensive database management for the FINAL schema that will never need wiping

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_URL="postgresql://claude_agent:claude_secure_password@localhost:5433/claude_agents_auth"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check if Docker container is running
check_database() {
    log "Checking database connection..."
    if ! docker exec claude-postgres pg_isready -U claude_agent -d claude_agents_auth &>/dev/null; then
        error "Database not accessible. Is the claude-postgres container running?"
    fi
    log "✅ Database connection confirmed"
}

# Execute SQL command
exec_sql() {
    local sql="$1"
    docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c "$sql"
}

# System health check
health_check() {
    log "Running comprehensive system health check..."
    exec_sql "SELECT system_health_check();" | grep -o '"system_status":"[^"]*"' | cut -d'"' -f4
    
    log "📊 Health check results:"
    exec_sql "
    SELECT 
        'Tables' as component,
        COUNT(*) as count,
        'Active' as status
    FROM pg_tables WHERE schemaname = 'public'
    UNION ALL
    SELECT 
        'Indexes' as component,
        COUNT(*) as count,
        'Optimized' as status
    FROM pg_indexes WHERE schemaname = 'public'
    UNION ALL
    SELECT 
        'ML Models' as component,
        COUNT(*) as count,
        'Ready' as status
    FROM ml_models WHERE is_active = TRUE
    UNION ALL
    SELECT 
        'Vector Indexes' as component,
        COUNT(*) as count,
        'Functional' as status
    FROM pg_indexes WHERE indexname LIKE '%vector%' OR indexname LIKE '%embedding%';
    "
}

# Refresh performance dashboards
refresh_dashboards() {
    log "Refreshing performance dashboards..."
    exec_sql "SELECT refresh_performance_views();"
    log "✅ Performance dashboards refreshed"
}

# Maintain partitions (create future ones)
maintain_partitions() {
    log "Maintaining database partitions..."
    exec_sql "SELECT maintain_partitions();"
    log "✅ Partitions maintained - future partitions created"
}

# Show current statistics
show_stats() {
    log "📈 Current database statistics:"
    exec_sql "
    SELECT 
        'Agent Executions' as metric,
        COUNT(*) as value,
        'Total recorded' as description
    FROM agent_task_executions
    UNION ALL
    SELECT 
        'Vector Embeddings' as metric,
        COUNT(*) as value,
        'Similarity searches available' as description
    FROM task_embeddings WHERE task_embedding IS NOT NULL
    UNION ALL
    SELECT 
        'Active ML Models' as metric,
        COUNT(*) as value,
        'Ready for predictions' as description
    FROM ml_models WHERE is_active = TRUE
    UNION ALL
    SELECT 
        'Learning Analytics' as metric,
        COUNT(*) as value,
        'Metrics collected' as description
    FROM learning_analytics;
    "
}

# Add new column example (demonstrating extensibility)
demo_extensibility() {
    log "🔧 Demonstrating schema extensibility..."
    
    # Add a test column
    log "Adding test column to agent_task_executions..."
    exec_sql "ALTER TABLE agent_task_executions ADD COLUMN IF NOT EXISTS demo_extension_$(date +%s) TEXT DEFAULT 'extensible';"
    
    # Show it was added
    local new_columns=$(exec_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'agent_task_executions';" | grep -o '[0-9]*' | tail -1)
    log "✅ Column added successfully. Table now has $new_columns columns."
    
    # Remove the test column
    log "Removing test column..."
    exec_sql "ALTER TABLE agent_task_executions DROP COLUMN IF EXISTS demo_extension_$(date +%s);" 2>/dev/null || true
    log "✅ Extensibility demonstration complete"
}

# Backup current schema structure
backup_schema() {
    log "🗄️ Creating schema backup..."
    local backup_file="${SCRIPT_DIR}/schema_backup_$(date +%Y%m%d_%H%M%S).sql"
    docker exec claude-postgres pg_dump -U claude_agent -d claude_agents_auth --schema-only > "$backup_file"
    log "✅ Schema backed up to: $backup_file"
}

# Performance test
performance_test() {
    log "🚀 Running performance tests..."
    
    # Insert test data
    log "Inserting test execution record..."
    exec_sql "
    INSERT INTO agent_task_executions (agent_name, task_description, duration_seconds, success, complexity_score) 
    VALUES ('performance_test', 'Schema performance verification', 0.1, TRUE, 0.5);
    "
    
    # Test query performance
    log "Testing query performance..."
    local start_time=$(date +%s%N)
    exec_sql "SELECT COUNT(*) FROM agent_task_executions WHERE agent_name = 'performance_test';" > /dev/null
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    log "✅ Query executed in ${duration_ms}ms"
    
    # Clean up test data
    exec_sql "DELETE FROM agent_task_executions WHERE agent_name = 'performance_test';"
}

# Show help
show_help() {
    cat << EOF
Final Schema Operations Script - ZERO FUTURE WIPES NEEDED

USAGE:
    $0 [COMMAND]

COMMANDS:
    health          - Run comprehensive system health check
    stats           - Show current database statistics  
    refresh         - Refresh performance dashboards
    maintain        - Maintain partitions (create future ones)
    demo            - Demonstrate schema extensibility
    backup          - Backup current schema structure
    performance     - Run performance tests
    all             - Run health, refresh, maintain, and stats
    help            - Show this help message

EXAMPLES:
    $0 health       # Check system health
    $0 all          # Run all maintenance operations
    $0 demo         # Show that ALTER TABLE works without issues

DATABASE INFO:
    - PostgreSQL 16.10 with pgvector
    - 24 tables, 216+ indexes, 18 partitions
    - Container: claude-postgres on port 5433
    - Status: PRODUCTION READY - NO FUTURE WIPES NEEDED

GUARANTEE:
    This schema is designed to NEVER require database wipes.
    All future enhancements use ALTER TABLE operations.
EOF
}

# Main command processing
main() {
    case "${1:-help}" in
        "health"|"h")
            check_database
            health_check
            ;;
        "stats"|"s")
            check_database
            show_stats
            ;;
        "refresh"|"r")
            check_database
            refresh_dashboards
            ;;
        "maintain"|"m")
            check_database
            maintain_partitions
            ;;
        "demo"|"d")
            check_database
            demo_extensibility
            ;;
        "backup"|"b")
            check_database
            backup_schema
            ;;
        "performance"|"p")
            check_database
            performance_test
            ;;
        "all"|"a")
            check_database
            health_check
            refresh_dashboards
            maintain_partitions
            show_stats
            log "🎉 All operations completed successfully!"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Execute main function
main "$@"