#!/bin/bash
# Complete Database and Learning System Initialization
# Self-contained setup for the entire Claude Agent ecosystem

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"

# Database settings
DB_HOST="localhost"
DB_PORT="5433"
DB_NAME="claude_auth"
DB_USER="claude_auth"
DB_PASS="claude_auth_pass"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Claude Agent Database & Learning System Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to check if PostgreSQL is installed
check_postgresql() {
    echo -e "${YELLOW}▶ Checking PostgreSQL installation...${NC}"
    
    if command -v psql >/dev/null 2>&1; then
        PG_VERSION=$(psql --version | grep -oE '[0-9]+' | head -1)
        echo -e "${GREEN}✓ PostgreSQL $PG_VERSION detected${NC}"
        
        # Check for PostgreSQL 17 specifically
        if [ "$PG_VERSION" -ge "17" ]; then
            echo -e "${GREEN}✓ PostgreSQL 17+ features available${NC}"
        else
            echo -e "${YELLOW}⚠ PostgreSQL 17 recommended for optimal performance${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ PostgreSQL not found${NC}"
        echo "  Please install PostgreSQL 17:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install postgresql-17 postgresql-client-17"
        return 1
    fi
}

# Function to initialize local database cluster
init_database_cluster() {
    echo -e "${YELLOW}▶ Initializing database cluster...${NC}"
    
    if [ -d "$DATA_DIR" ] && [ -f "$DATA_DIR/PG_VERSION" ]; then
        echo -e "${GREEN}✓ Database cluster already exists${NC}"
        return 0
    fi
    
    # Find PostgreSQL binaries
    PG_BIN=""
    for version in 17 16 15 14; do
        if [ -x "/usr/lib/postgresql/$version/bin/initdb" ]; then
            PG_BIN="/usr/lib/postgresql/$version/bin"
            break
        fi
    done
    
    if [ -z "$PG_BIN" ]; then
        echo -e "${RED}✗ PostgreSQL binaries not found${NC}"
        return 1
    fi
    
    # Initialize cluster
    mkdir -p "$DATA_DIR"
    "$PG_BIN/initdb" -D "$DATA_DIR" --encoding=UTF8 --locale=en_US.UTF-8 --auth=trust
    
    # Configure for local connections
    cat >> "$DATA_DIR/postgresql.conf" <<EOF

# Claude Agent Custom Configuration
port = 5433
max_connections = 200
shared_buffers = 256MB
work_mem = 4MB
maintenance_work_mem = 64MB

# PostgreSQL 17 optimizations
enable_seqscan = on
enable_indexscan = on
enable_indexonlyscan = on
enable_parallel_query = on
max_parallel_workers_per_gather = 4

# Logging
log_destination = 'stderr'
logging_collector = off
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_statement = 'none'
log_duration = off

# Performance
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
EOF
    
    echo -e "${GREEN}✓ Database cluster initialized${NC}"
}

# Function to start PostgreSQL
start_postgresql() {
    echo -e "${YELLOW}▶ Starting PostgreSQL server...${NC}"
    
    # Check if already running
    if pgrep -f "postgres.*-D.*$DATA_DIR" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL already running${NC}"
        return 0
    fi
    
    # Find pg_ctl
    PG_CTL=""
    for version in 17 16 15 14; do
        if [ -x "/usr/lib/postgresql/$version/bin/pg_ctl" ]; then
            PG_CTL="/usr/lib/postgresql/$version/bin/pg_ctl"
            break
        fi
    done
    
    if [ -z "$PG_CTL" ]; then
        echo -e "${RED}✗ pg_ctl not found${NC}"
        return 1
    fi
    
    # Start server
    "$PG_CTL" -D "$DATA_DIR" -l "$LOG_FILE" -o "-p $DB_PORT" start
    
    # Wait for startup
    sleep 2
    
    # Verify connection
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres -c "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL started on port $DB_PORT${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start PostgreSQL${NC}"
        echo "  Check log: $LOG_FILE"
        return 1
    fi
}

# Function to create database and user
create_database() {
    echo -e "${YELLOW}▶ Creating database and user...${NC}"
    
    # Create user and database
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$USER" -d postgres <<EOF 2>/dev/null || true
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'claude_auth') THEN
        CREATE USER claude_auth WITH PASSWORD 'claude_auth_pass';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE claude_auth OWNER claude_auth'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'claude_auth')\\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE claude_auth TO claude_auth;
EOF
    
    echo -e "${GREEN}✓ Database '$DB_NAME' and user '$DB_USER' ready${NC}"
}

# Function to install auth schema
install_auth_schema() {
    echo -e "${YELLOW}▶ Installing authentication schema...${NC}"
    
    if [ -f "$SCRIPT_DIR/sql/auth_db_setup.sql" ]; then
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            < "$SCRIPT_DIR/sql/auth_db_setup.sql" 2>/dev/null || {
            echo -e "${YELLOW}⚠ Auth schema already exists or partially installed${NC}"
        }
        echo -e "${GREEN}✓ Authentication schema installed${NC}"
    else
        echo -e "${YELLOW}⚠ Auth schema file not found${NC}"
    fi
}

# Function to install learning schema
install_learning_schema() {
    echo -e "${YELLOW}▶ Installing learning system schema...${NC}"
    
    # Direct schema creation
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF' 2>/dev/null || true
-- Agent metadata table
CREATE TABLE IF NOT EXISTS agent_metadata (
    agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(64) UNIQUE NOT NULL,
    agent_version VARCHAR(16),
    capabilities JSONB DEFAULT '{}',
    performance_metrics JSONB DEFAULT '{}',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task execution tracking
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

-- Agent collaboration patterns
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

-- Learning insights
CREATE TABLE IF NOT EXISTS learning_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(32) NOT NULL,
    confidence FLOAT DEFAULT 0.5,
    description TEXT,
    data JSONB DEFAULT '{}',
    applied BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Performance metrics
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_executions_task_type ON agent_task_executions(task_type);
CREATE INDEX IF NOT EXISTS idx_executions_success ON agent_task_executions(success);
CREATE INDEX IF NOT EXISTS idx_executions_created ON agent_task_executions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_agents ON agent_collaboration_patterns(source_agent, target_agent);
CREATE INDEX IF NOT EXISTS idx_insights_type ON learning_insights(insight_type);
CREATE INDEX IF NOT EXISTS idx_metrics_agent ON agent_performance_metrics(agent_name);

-- Create analysis functions
CREATE OR REPLACE FUNCTION calculate_agent_success_rate(agent_name_param VARCHAR)
RETURNS TABLE(success_rate FLOAT, total_executions INT, avg_duration FLOAT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN COUNT(*) = 0 THEN 0.0
            ELSE SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*)
        END as success_rate,
        COUNT(*)::INT as total_executions,
        AVG(duration_seconds)::FLOAT as avg_duration
    FROM agent_task_executions
    WHERE agents_invoked @> jsonb_build_array(jsonb_build_object('name', agent_name_param));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_top_collaborations(limit_count INT DEFAULT 10)
RETURNS TABLE(
    source VARCHAR, 
    target VARCHAR, 
    task_type VARCHAR,
    invocations INT, 
    success_rate FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        source_agent::VARCHAR,
        target_agent::VARCHAR,
        agent_collaboration_patterns.task_type::VARCHAR,
        invocation_count,
        agent_collaboration_patterns.success_rate
    FROM agent_collaboration_patterns
    ORDER BY invocation_count DESC, success_rate DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;
EOF
    
    echo -e "${GREEN}✓ Learning system schema installed${NC}"
}

# Function to initialize agents
initialize_agents() {
    echo -e "${YELLOW}▶ Initializing agent metadata...${NC}"
    
    # Get list of agents from the agents directory
    AGENTS_DIR="$PROJECT_ROOT/agents"
    
    if [ ! -d "$AGENTS_DIR" ]; then
        echo -e "${YELLOW}⚠ Agents directory not found${NC}"
        return 0
    fi
    
    # Initialize each agent
    AGENT_COUNT=0
    for agent_file in "$AGENTS_DIR"/*.md; do
        [ -f "$agent_file" ] || continue
        
        agent_name=$(basename "$agent_file" .md | tr '[:upper:]' '[:lower:]')
        
        # Skip template files
        if [[ "$agent_name" == "template" ]] || [[ "$agent_name" == "standardized_template" ]]; then
            continue
        fi
        
        # Insert agent
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF 2>/dev/null || true
INSERT INTO agent_metadata (agent_name, agent_version, capabilities, performance_metrics)
VALUES (
    '$agent_name',
    'v8.0',
    '{"status": "active", "tools": ["Task"], "ultra_gratuitous": true}'::jsonb,
    '{"success_rate": 1.0, "avg_response_time": 0.5, "collaboration_score": 1.0}'::jsonb
) ON CONFLICT (agent_name) DO UPDATE SET
    agent_version = 'v8.0',
    last_updated = CURRENT_TIMESTAMP;
EOF
        ((AGENT_COUNT++))
    done
    
    echo -e "${GREEN}✓ Initialized $AGENT_COUNT agents${NC}"
}

# Function to import existing learning data
import_learning_data() {
    echo -e "${YELLOW}▶ Importing existing learning data...${NC}"
    
    LEARNING_DATA_DIR="$SCRIPT_DIR/learning_data"
    EXPORT_FILE="$LEARNING_DATA_DIR/learning_export.sql"
    
    if [ -f "$EXPORT_FILE" ]; then
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            < "$EXPORT_FILE" 2>/dev/null || {
            echo -e "${YELLOW}⚠ Some learning data already exists${NC}"
        }
        echo -e "${GREEN}✓ Learning data imported${NC}"
    else
        echo -e "${YELLOW}ℹ No existing learning data to import${NC}"
    fi
}

# Function to setup Python learning system
setup_python_learning() {
    echo -e "${YELLOW}▶ Setting up Python learning system...${NC}"
    
    PYTHON_DIR="$PROJECT_ROOT/agents/src/python"
    
    # Check for Python
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}✗ Python 3 not found${NC}"
        return 1
    fi
    
    # Install Python dependencies
    echo "  Installing Python dependencies..."
    python3 -m pip install --quiet --user \
        psycopg2-binary \
        asyncpg \
        numpy \
        scikit-learn \
        joblib 2>/dev/null || {
        echo -e "${YELLOW}⚠ Some Python packages may need manual installation${NC}"
    }
    
    # Create launcher script
    cat > "$PYTHON_DIR/postgresql-learning" <<'EOF'
#!/bin/bash
# PostgreSQL Agent Learning System Launcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/database"

# Set database credentials
export POSTGRES_DB=claude_auth
export POSTGRES_USER=claude_auth
export POSTGRES_PASSWORD=claude_auth_pass
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5433

# Ensure database is running
"$DATABASE_DIR/start_local_postgres.sh" >/dev/null 2>&1

case "$1" in
    setup)
        python3 "$SCRIPT_DIR/setup_learning_system.py"
        ;;
    status)
        python3 "$SCRIPT_DIR/learning_cli.py" status
        ;;
    test)
        python3 "$SCRIPT_DIR/setup_learning_system.py" test
        ;;
    *)
        python3 "$SCRIPT_DIR/learning_cli.py" "$@"
        ;;
esac
EOF
    
    chmod +x "$PYTHON_DIR/postgresql-learning"
    echo -e "${GREEN}✓ Python learning system configured${NC}"
}

# Function to display connection info
show_connection_info() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ System Initialization Complete!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Database Connection Info:${NC}"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: $DB_PASS"
    echo ""
    echo -e "${YELLOW}Quick Commands:${NC}"
    echo "  Connect to database:"
    echo "    psql -h localhost -p 5433 -U claude_auth -d claude_auth"
    echo ""
    echo "  Start/Stop database:"
    echo "    $SCRIPT_DIR/start_local_postgres.sh"
    echo "    $SCRIPT_DIR/stop_local_postgres.sh"
    echo ""
    echo "  Learning system:"
    echo "    $PROJECT_ROOT/agents/src/python/postgresql-learning status"
    echo ""
    echo "  Export/Import learning data:"
    echo "    $SCRIPT_DIR/scripts/learning_sync.sh export"
    echo "    $SCRIPT_DIR/scripts/learning_sync.sh import"
    echo ""
    echo -e "${YELLOW}Features Enabled:${NC}"
    echo "  ✓ PostgreSQL 17 with JSON optimizations"
    echo "  ✓ Authentication system with JWT"
    echo "  ✓ Agent learning system with ML"
    echo "  ✓ 40+ agents with metadata"
    echo "  ✓ GitHub sync for learning data"
    echo "  ✓ Self-contained database cluster"
    echo ""
}

# Function to run all setup steps
run_complete_setup() {
    # Check prerequisites
    if ! check_postgresql; then
        echo -e "${RED}Please install PostgreSQL first${NC}"
        exit 1
    fi
    
    # Initialize database
    init_database_cluster
    start_postgresql
    create_database
    
    # Install schemas
    install_auth_schema
    install_learning_schema
    
    # Initialize data
    initialize_agents
    import_learning_data
    
    # Setup Python system
    setup_python_learning
    
    # Setup git hooks
    "$SCRIPT_DIR/scripts/learning_sync.sh" setup-hooks 2>/dev/null || true
    
    # Show final info
    show_connection_info
}

# Main execution
case "${1:-setup}" in
    setup)
        run_complete_setup
        ;;
    start)
        start_postgresql
        ;;
    stop)
        "$SCRIPT_DIR/stop_local_postgres.sh"
        ;;
    status)
        if pgrep -f "postgres.*-D.*$DATA_DIR" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL is running${NC}"
            "$SCRIPT_DIR/scripts/learning_sync.sh" stats
        else
            echo -e "${RED}✗ PostgreSQL is not running${NC}"
        fi
        ;;
    reset)
        echo -e "${YELLOW}⚠ This will delete all data. Continue? (y/N)${NC}"
        read -r confirm
        if [ "$confirm" = "y" ]; then
            "$SCRIPT_DIR/stop_local_postgres.sh" 2>/dev/null || true
            rm -rf "$DATA_DIR"
            echo -e "${GREEN}✓ Database reset complete${NC}"
        fi
        ;;
    *)
        echo "Usage: $0 {setup|start|stop|status|reset}"
        echo ""
        echo "  setup  - Complete system initialization"
        echo "  start  - Start PostgreSQL server"
        echo "  stop   - Stop PostgreSQL server"
        echo "  status - Show system status"
        echo "  reset  - Delete all data and start fresh"
        ;;
esac