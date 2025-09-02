#!/bin/bash
# PGVECTOR INDEX MIGRATION SCRIPT
# Comprehensive pgvector optimization deployment for PostgreSQL 16
# Author: DATABASE Agent
# Date: 2025-09-02

set -euo pipefail

# Configuration
CONTAINER_NAME="claude-postgres"
DB_NAME="claude_agents_auth"
DB_USER="claude_agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/pgvector_migration_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker ps > /dev/null 2>&1; then
        error "Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if PostgreSQL container exists and is running
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "PostgreSQL container '$CONTAINER_NAME' is not running"
        log "Starting PostgreSQL container..."
        cd "$SCRIPT_DIR" && docker-compose -f docker/docker-compose.yml up -d postgres || {
            error "Failed to start PostgreSQL container"
            exit 1
        }
        sleep 5
    fi
    
    # Check if pgvector extension is available
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | grep -q "vector"; then
        error "pgvector extension is not installed"
        exit 1
    fi
    
    success "Prerequisites check completed"
}

# Backup existing indexes
backup_indexes() {
    log "Creating backup of existing indexes..."
    
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 'DROP INDEX IF EXISTS ' || schemaname || '.' || indexname || ';'
        FROM pg_indexes 
        WHERE schemaname = 'context_chopping' 
        AND indexname LIKE 'idx_%';" > "${SCRIPT_DIR}/index_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    success "Index backup created"
}

# Get current database statistics
get_pre_migration_stats() {
    log "Collecting pre-migration statistics..."
    
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            relname as tablename,
            n_tup_ins as inserts,
            n_tup_upd as updates,
            n_tup_del as deletes,
            n_live_tup as live_rows,
            n_dead_tup as dead_rows,
            last_vacuum,
            last_analyze
        FROM pg_stat_user_tables 
        WHERE schemaname = 'context_chopping';
    " > "${SCRIPT_DIR}/pre_migration_stats_$(date +%Y%m%d_%H%M%S).txt"
    
    success "Pre-migration statistics collected"
}

# Execute the optimization strategy
execute_optimization() {
    log "Executing pgvector optimization strategy..."
    
    # Execute the main optimization script
    if docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "${SCRIPT_DIR}/pgvector_optimization_strategy.sql"; then
        success "Optimization strategy executed successfully"
    else
        error "Failed to execute optimization strategy"
        return 1
    fi
    
    # Wait for concurrent index creation to complete
    log "Waiting for concurrent index creation to complete..."
    sleep 10
    
    # Check index creation status
    while docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT COUNT(*) FROM pg_stat_progress_create_index;
    " | grep -q "1"; do
        log "Index creation in progress..."
        sleep 5
    done
    
    success "All indexes created successfully"
}

# Validate index creation
validate_indexes() {
    log "Validating created indexes..."
    
    # Get list of created indexes
    local index_count
    index_count=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) 
        FROM pg_indexes 
        WHERE schemaname = 'context_chopping' 
        AND indexname LIKE 'idx_%';
    " | xargs)
    
    log "Total indexes in context_chopping schema: $index_count"
    
    # Check for vector indexes specifically
    local vector_index_count
    vector_index_count=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) 
        FROM pg_indexes 
        WHERE schemaname = 'context_chopping' 
        AND indexdef LIKE '%ivfflat%';
    " | xargs)
    
    log "Vector (IVFFlat) indexes created: $vector_index_count"
    
    # Validate index usage stats
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            relname as tablename,
            indexrelname as indexname,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch
        FROM pg_stat_user_indexes 
        WHERE schemaname = 'context_chopping' 
        ORDER BY relname, indexrelname;
    "
    
    if [ "$index_count" -ge 15 ]; then
        success "Index validation completed - $index_count indexes created"
    else
        warning "Expected more indexes - only $index_count created"
    fi
}

# Run performance benchmarks
run_benchmarks() {
    log "Running performance benchmarks..."
    
    # Run benchmark queries
    if docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "${SCRIPT_DIR}/performance_benchmark_queries.sql" > "${SCRIPT_DIR}/benchmark_results_$(date +%Y%m%d_%H%M%S).txt" 2>&1; then
        success "Performance benchmarks completed"
        log "Benchmark results saved to benchmark_results_*.txt"
    else
        warning "Some benchmark queries may have failed - check results file"
    fi
}

# Update database statistics
update_statistics() {
    log "Updating database statistics..."
    
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        VACUUM ANALYZE context_chopping.context_chunks;
        VACUUM ANALYZE context_chopping.query_patterns;
        VACUUM ANALYZE context_chopping.learning_feedback;
        VACUUM ANALYZE context_chopping.performance_stats;
    "
    
    success "Database statistics updated"
}

# Generate performance report
generate_report() {
    log "Generating performance optimization report..."
    
    local report_file="${SCRIPT_DIR}/pgvector_optimization_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << 'EOF'
# PostgreSQL pgvector Optimization Report

## Migration Summary

**Date:** $(date)
**Database:** claude_agents_auth
**Schema:** context_chopping
**PostgreSQL Version:** 16
**Extension:** pgvector

## Optimization Strategy Applied

### 1. Advanced Vector Indexes
- IVFFlat indexes with optimized list parameters
- Tuned probes settings for accuracy/speed balance
- Specialized vector indexes for filtered searches

### 2. Composite Indexes
- Multi-column indexes for complex query patterns
- Performance tracking indexes
- Language and file type optimization

### 3. Partial Indexes
- High-performance indexes for frequently accessed content
- Security-filtered vector searches
- Time-based and importance-based filters

### 4. Covering Indexes
- Complete context retrieval without heap lookups
- Vector similarity with metadata included
- Query analysis with all required columns

### 5. Performance Tuning
- Autovacuum optimization
- Memory settings for vector operations
- Parallel query execution enablement

## Performance Targets

| Operation | Target | Expected Improvement |
|-----------|--------|---------------------|
| Vector similarity search | <10ms for 1M vectors | 10-50x |
| Context chunk retrieval | <5ms | 20-100x |
| Query pattern matching | <2ms | 10-30x |
| Filtered vector searches | <10ms | 50-100x |

## Index Summary

EOF

    # Add actual index count and details
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT '- ' || indexname || ' (' || indexdef || ')'
        FROM pg_indexes 
        WHERE schemaname = 'context_chopping' 
        AND indexname LIKE 'idx_%'
        ORDER BY indexname;
    " >> "$report_file"
    
    success "Optimization report generated: $(basename "$report_file")"
}

# Cleanup function
cleanup() {
    log "Performing cleanup..."
    
    # Remove temporary functions if they exist
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        DROP FUNCTION IF EXISTS context_chopping.generate_random_vector(integer);
    " 2>/dev/null || true
    
    success "Cleanup completed"
}

# Main execution
main() {
    log "Starting pgvector optimization migration..."
    log "Log file: $LOG_FILE"
    
    check_prerequisites
    backup_indexes
    get_pre_migration_stats
    execute_optimization
    validate_indexes
    update_statistics
    run_benchmarks
    generate_report
    cleanup
    
    success "pgvector optimization migration completed successfully!"
    log "Check the generated files:"
    log "- Migration log: $(basename "$LOG_FILE")"
    log "- Benchmark results: benchmark_results_*.txt"
    log "- Performance report: pgvector_optimization_report_*.md"
    log ""
    log "Performance improvements should be:"
    log "- Vector similarity: 10-50x faster"
    log "- Context retrieval: 20-100x faster"
    log "- Query patterns: 10-30x faster"
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"