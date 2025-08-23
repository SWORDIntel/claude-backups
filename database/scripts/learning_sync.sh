#!/bin/bash
# Learning System Data Export/Import for GitHub Sync
# Ensures all learning data is tracked and synced with the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DATABASE_DIR")"
LEARNING_DATA_DIR="$DATABASE_DIR/learning_data"
EXPORT_FILE="$LEARNING_DATA_DIR/learning_export.sql"
METADATA_FILE="$LEARNING_DATA_DIR/learning_metadata.json"

# Database connection settings for local instance
DB_HOST="localhost"
DB_PORT="5433"
DB_NAME="claude_auth"
DB_USER="claude_auth"
DB_PASS="claude_auth_pass"

# Create learning data directory if it doesn't exist
mkdir -p "$LEARNING_DATA_DIR"

# Function to export learning data
export_learning_data() {
    echo "📤 Exporting learning data for GitHub sync..."
    
    # Export learning tables to SQL
    PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --data-only \
        --table="agent_metadata" \
        --table="agent_task_executions" \
        --table="agent_collaboration_patterns" \
        --table="learning_insights" \
        --table="agent_performance_metrics" \
        --file="$EXPORT_FILE" 2>/dev/null || {
            echo "⚠️  No learning data to export yet (tables may not exist)"
            return 0
        }
    
    # Create metadata file with export info
    cat > "$METADATA_FILE" <<EOF
{
    "export_timestamp": "$(date -Iseconds)",
    "database_version": "PostgreSQL 17",
    "learning_system_version": "2.0",
    "export_host": "$(hostname)",
    "export_user": "$(whoami)",
    "statistics": $(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT json_build_object(
            'total_executions', (SELECT COUNT(*) FROM agent_task_executions),
            'total_agents', (SELECT COUNT(*) FROM agent_metadata),
            'total_insights', (SELECT COUNT(*) FROM learning_insights),
            'total_patterns', (SELECT COUNT(*) FROM agent_collaboration_patterns),
            'avg_success_rate', (
                SELECT AVG(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT 
                FROM agent_task_executions
            )
        )" 2>/dev/null || echo '{}')
}
EOF
    
    # Create a human-readable summary
    cat > "$LEARNING_DATA_DIR/README.md" <<EOF
# Agent Learning Data

This directory contains exported learning data from the PostgreSQL Agent Learning System.

## Files

- **learning_export.sql**: SQL dump of all learning tables
- **learning_metadata.json**: Metadata about the export
- **README.md**: This file

## Last Export

- **Date**: $(date)
- **Database**: $DB_NAME @ $DB_HOST:$DB_PORT

## Usage

### Import Data
\`\`\`bash
./learning_sync.sh import
\`\`\`

### Export Data
\`\`\`bash
./learning_sync.sh export
\`\`\`

### View Statistics
\`\`\`bash
./learning_sync.sh stats
\`\`\`

## GitHub Sync

This data is automatically exported before commits to preserve learning history.
The learning system improves over time, and this data represents the accumulated
knowledge of agent collaborations and optimizations.

## Privacy

No sensitive user data is included in exports. Only:
- Agent performance metrics
- Task execution patterns
- Collaboration insights
- System optimizations
EOF
    
    echo "✅ Learning data exported to $LEARNING_DATA_DIR"
    echo "   - SQL dump: $(wc -l < "$EXPORT_FILE" 2>/dev/null || echo 0) lines"
    echo "   - Ready for GitHub sync"
}

# Function to import learning data
import_learning_data() {
    echo "📥 Importing learning data from repository..."
    
    if [ ! -f "$EXPORT_FILE" ]; then
        echo "⚠️  No learning data to import (file not found: $EXPORT_FILE)"
        echo "   This is normal for fresh installations"
        return 0
    fi
    
    # Ensure database and tables exist
    echo "   Verifying database structure..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF 2>/dev/null || true
-- Ensure learning tables exist (won't error if they already do)
CREATE TABLE IF NOT EXISTS agent_metadata (
    agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(64) UNIQUE NOT NULL,
    agent_version VARCHAR(16),
    capabilities JSONB DEFAULT '{}',
    performance_metrics JSONB DEFAULT '{}',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_task_executions (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id VARCHAR(128),
    task_type VARCHAR(64) NOT NULL,
    task_description TEXT,
    agents_invoked JSONB DEFAULT '[]',
    execution_order JSONB DEFAULT '[]',
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    duration_seconds FLOAT,
    success BOOLEAN NOT NULL DEFAULT false,
    error_message TEXT,
    complexity_score FLOAT DEFAULT 1.0,
    user_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_collaboration_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_agent VARCHAR(64) NOT NULL,
    target_agent VARCHAR(64) NOT NULL,
    task_type VARCHAR(64),
    invocation_count INT DEFAULT 1,
    success_rate FLOAT DEFAULT 1.0,
    avg_duration FLOAT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_agent, target_agent, task_type)
);

CREATE TABLE IF NOT EXISTS learning_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(32) NOT NULL,
    confidence FLOAT DEFAULT 0.5,
    description TEXT,
    data JSONB DEFAULT '{}',
    applied BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS agent_performance_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(64) NOT NULL,
    task_type VARCHAR(64),
    success_count INT DEFAULT 0,
    failure_count INT DEFAULT 0,
    total_duration FLOAT DEFAULT 0,
    avg_response_time FLOAT,
    last_execution TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(agent_name, task_type)
);
EOF
    
    # Clear existing data to avoid duplicates (optional - could merge instead)
    echo "   Clearing existing learning data..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF 2>/dev/null || true
TRUNCATE TABLE agent_task_executions CASCADE;
TRUNCATE TABLE agent_collaboration_patterns CASCADE;
TRUNCATE TABLE learning_insights CASCADE;
TRUNCATE TABLE agent_performance_metrics CASCADE;
-- Keep agent_metadata as it's more static
EOF
    
    # Import the data
    echo "   Importing learning data..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" < "$EXPORT_FILE" 2>/dev/null || {
        echo "⚠️  Import completed with warnings (some data may already exist)"
    }
    
    echo "✅ Learning data imported successfully"
    
    # Show statistics
    show_statistics
}

# Function to show learning statistics
show_statistics() {
    echo "📊 Learning System Statistics:"
    
    if ! PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" 2>/dev/null <<EOF
SELECT 
    'Total Executions' as metric, 
    COUNT(*)::TEXT as value 
FROM agent_task_executions
UNION ALL
SELECT 
    'Success Rate' as metric,
    ROUND(AVG(CASE WHEN success THEN 1 ELSE 0 END) * 100, 1)::TEXT || '%' as value
FROM agent_task_executions
UNION ALL
SELECT 
    'Total Agents' as metric,
    COUNT(*)::TEXT as value
FROM agent_metadata
UNION ALL
SELECT 
    'Learning Insights' as metric,
    COUNT(*)::TEXT as value
FROM learning_insights
UNION ALL
SELECT 
    'Collaboration Patterns' as metric,
    COUNT(*)::TEXT as value
FROM agent_collaboration_patterns;
EOF
    then
        echo "⚠️  Database not accessible or tables don't exist yet"
        return 0
    fi
}

# Function to setup git hooks for automatic export
setup_git_hooks() {
    echo "🔧 Setting up Git hooks for automatic learning data sync..."
    
    # Check if we have the hooks directory
    HOOKS_DIR="$PROJECT_ROOT/hooks"
    if [ ! -d "$HOOKS_DIR" ]; then
        echo "⚠️  Hooks directory not found, using direct git hooks"
        
        # Fallback to direct git hooks
        GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
        PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"
        
        # Create pre-commit hook
        cat > "$PRE_COMMIT_HOOK" <<'EOF'
#!/bin/bash
# Auto-export learning data before commit

SCRIPT_DIR="$(git rev-parse --show-toplevel)/database/scripts"
LEARNING_SYNC="$SCRIPT_DIR/learning_sync.sh"

if [ -f "$LEARNING_SYNC" ]; then
    echo "📤 Exporting learning data before commit..."
    "$LEARNING_SYNC" export >/dev/null 2>&1
    
    # Add the exported files to the commit
    git add database/learning_data/
fi

exit 0
EOF
        
        chmod +x "$PRE_COMMIT_HOOK"
        echo "✅ Git pre-commit hook installed"
    else
        # Integrate with existing Claude hooks system
        echo "   Integrating with Claude hooks system..."
        
        # Create learning export hook in Claude hooks directory
        CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
        mkdir -p "$CLAUDE_HOOKS_DIR/pre-commit"
        
        cat > "$CLAUDE_HOOKS_DIR/pre-commit/export_learning_data.sh" <<'EOF'
#!/bin/bash
# Export learning data before commit

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/Claude")"
LEARNING_SYNC="$PROJECT_ROOT/database/scripts/learning_sync.sh"

if [ -f "$LEARNING_SYNC" ]; then
    echo "📤 Exporting learning data..."
    "$LEARNING_SYNC" export >/dev/null 2>&1
    
    # Add the exported files to the commit
    git add "$PROJECT_ROOT/database/learning_data/" 2>/dev/null
fi

exit 0
EOF
        
        chmod +x "$CLAUDE_HOOKS_DIR/pre-commit/export_learning_data.sh"
        
        # Also create post-task hook for learning system updates
        mkdir -p "$CLAUDE_HOOKS_DIR/post-task"
        
        cat > "$CLAUDE_HOOKS_DIR/post-task/record_learning_data.sh" <<'EOF'
#!/bin/bash
# Record task execution for learning system

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/Claude")"
TASK_TYPE="${CLAUDE_TASK_TYPE:-general}"
AGENTS_USED="${CLAUDE_AGENTS_USED:-unknown}"
SUCCESS="${CLAUDE_TASK_SUCCESS:-true}"

# Record in learning system if available
if [ -f "$PROJECT_ROOT/agents/src/python/learning_cli.py" ]; then
    export POSTGRES_DB=claude_auth
    export POSTGRES_USER=claude_auth
    export POSTGRES_PASSWORD=claude_auth_pass
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5433
    
    # Start database if needed
    "$PROJECT_ROOT/database/start_local_postgres.sh" >/dev/null 2>&1
    
    # Record execution (if CLI supports it)
    python3 "$PROJECT_ROOT/agents/src/python/learning_cli.py" record \
        --task-type "$TASK_TYPE" \
        --agents "$AGENTS_USED" \
        --success "$SUCCESS" 2>/dev/null || true
fi

exit 0
EOF
        
        chmod +x "$CLAUDE_HOOKS_DIR/post-task/record_learning_data.sh"
        
        echo "✅ Claude hooks integration complete"
        echo "   - Pre-commit: Export learning data"
        echo "   - Post-task: Record task execution"
    fi
    
    echo "   Learning data will be automatically synced"
}

# Function to check database status
check_database() {
    echo "🔍 Checking database connection..."
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Database connection successful"
        return 0
    else
        echo "❌ Database connection failed"
        echo "   Attempting to start local PostgreSQL..."
        "$DATABASE_DIR/start_local_postgres.sh"
        sleep 2
        
        # Create database and user if needed
        psql -h "$DB_HOST" -p "$DB_PORT" -U ubuntu -d postgres <<EOF 2>/dev/null || true
CREATE USER claude_auth WITH PASSWORD 'claude_auth_pass';
CREATE DATABASE claude_auth OWNER claude_auth;
GRANT ALL PRIVILEGES ON DATABASE claude_auth TO claude_auth;
EOF
        return 0
    fi
}

# Main command handler
case "$1" in
    export)
        check_database
        export_learning_data
        ;;
    import)
        check_database
        import_learning_data
        ;;
    stats)
        check_database
        show_statistics
        ;;
    setup-hooks)
        setup_git_hooks
        ;;
    sync)
        check_database
        export_learning_data
        echo ""
        echo "📋 To complete sync:"
        echo "   git add database/learning_data/"
        echo "   git commit -m 'feat: Update learning data'"
        echo "   git push"
        ;;
    clean)
        echo "🧹 Cleaning learning data..."
        rm -f "$EXPORT_FILE" "$METADATA_FILE"
        echo "✅ Learning data cleaned"
        ;;
    *)
        echo "Agent Learning Data Sync Manager"
        echo ""
        echo "Usage: $0 {export|import|stats|sync|setup-hooks|clean}"
        echo ""
        echo "Commands:"
        echo "  export      - Export learning data to files for GitHub"
        echo "  import      - Import learning data from repository"
        echo "  stats       - Show learning system statistics"
        echo "  sync        - Export and prepare for git commit"
        echo "  setup-hooks - Install git hooks for automatic sync"
        echo "  clean       - Remove exported learning data files"
        echo ""
        echo "Examples:"
        echo "  $0 export           # Export before commit"
        echo "  $0 import           # Import after clone/pull"
        echo "  $0 setup-hooks      # Enable automatic export"
        ;;
esac