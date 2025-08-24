#!/bin/bash
# Database Management Convenience Script with Local PostgreSQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"
SOCKET_DIR="$SCRIPT_DIR/data/run"
PG_PORT=5433  # Local PostgreSQL port

# Auto-detect PostgreSQL version
if [ -d "/usr/lib/postgresql/17/bin" ]; then
    PG_BIN="/usr/lib/postgresql/17/bin"
    echo "🔍 Using PostgreSQL 17"
elif [ -d "/usr/lib/postgresql/16/bin" ]; then
    PG_BIN="/usr/lib/postgresql/16/bin"
    echo "🔍 Using PostgreSQL 16"
elif [ -d "/usr/lib/postgresql/15/bin" ]; then
    PG_BIN="/usr/lib/postgresql/15/bin"
    echo "🔍 Using PostgreSQL 15"
elif [ -d "/usr/lib/postgresql/14/bin" ]; then
    PG_BIN="/usr/lib/postgresql/14/bin"
    echo "🔍 Using PostgreSQL 14"
else
    echo "❌ No PostgreSQL installation found in /usr/lib/postgresql/"
    echo "💡 Please install PostgreSQL with: sudo apt-get install postgresql postgresql-client"
    exit 1
fi

# Function to check if local PostgreSQL is running
check_postgresql_running() {
    # Check if local PostgreSQL data directory exists
    if [ ! -d "$DATA_DIR" ]; then
        return 1  # Not initialized
    fi
    
    # Check if PostgreSQL is running on local port
    if pg_isready -h localhost -p $PG_PORT > /dev/null 2>&1; then
        return 0  # PostgreSQL is running
    fi
    
    return 1  # PostgreSQL is not running
}

# Function to initialize local PostgreSQL if needed
initialize_postgresql() {
    if [ ! -d "$DATA_DIR" ]; then
        echo "🔧 Initializing local PostgreSQL database..."
        "$PG_BIN/initdb" -D "$DATA_DIR" --auth-local trust --auth-host trust --no-instructions
        if [ $? -eq 0 ]; then
            echo "✅ PostgreSQL initialized successfully"
            
            # Create socket directory if it doesn't exist
            mkdir -p "$SOCKET_DIR"
            
            # Configure PostgreSQL to use custom socket directory
            echo "unix_socket_directories = '$SOCKET_DIR'" >> "$DATA_DIR/postgresql.conf"
            echo "port = $PG_PORT" >> "$DATA_DIR/postgresql.conf"
        else
            echo "❌ Failed to initialize PostgreSQL"
            return 1
        fi
    fi
    
    # Always ensure socket directory exists
    mkdir -p "$SOCKET_DIR"
    return 0
}

# Function to start local PostgreSQL
start_postgresql() {
    if ! check_postgresql_running; then
        echo "🚀 Starting local PostgreSQL..."
        "$PG_BIN/pg_ctl" -D "$DATA_DIR" -l "$LOG_FILE" -o "-p $PG_PORT" start
        sleep 2
        if check_postgresql_running; then
            echo "✅ PostgreSQL started on port $PG_PORT"
        else
            echo "❌ Failed to start PostgreSQL"
            return 1
        fi
    fi
    return 0
}


case "$1" in
    "start")
        initialize_postgresql
        start_postgresql
        ;;
    "stop")
        echo "🛑 Stopping local PostgreSQL..."
        "$PG_BIN/pg_ctl" -D "$DATA_DIR" stop
        ;;
    "setup")
        echo "🗄️  Setting up local PostgreSQL authentication database..."
        initialize_postgresql
        start_postgresql
        
        # Wait a moment for PostgreSQL to be fully ready
        sleep 2
        
        # Create database and user (using localhost connection with trust auth)
        echo "📦 Creating database and user..."
        psql -h localhost -p $PG_PORT -U ubuntu -d postgres <<EOF
CREATE USER claude_auth WITH PASSWORD 'claude_auth_pass';
CREATE DATABASE claude_auth OWNER claude_auth;
GRANT ALL PRIVILEGES ON DATABASE claude_auth TO claude_auth;
EOF
        
        # Run SQL setup if exists
        if [ -f "$SCRIPT_DIR/sql/auth_db_setup.sql" ]; then
            echo "🔨 Running database schema setup..."
            psql -h localhost -p $PG_PORT -U ubuntu -d claude_auth -f "$SCRIPT_DIR/sql/auth_db_setup.sql"
            echo "✅ Database setup complete"
        else
            echo "⚠️  SQL setup file not found: $SCRIPT_DIR/sql/auth_db_setup.sql"
        fi
        ;;
    "test")
        echo "🧪 Running PostgreSQL 17 performance tests..."
        if ! check_postgresql_running; then
            initialize_postgresql
            start_postgresql
        fi
        echo "Target: >2000 auth/sec, <25ms P95 latency"
        cd "$SCRIPT_DIR"
        PGHOST=localhost PGPORT=$PG_PORT python3 tests/auth_db_performance_test.py
        ;;
    "redis")
        echo "📊 Setting up Redis caching layer..."
        cd "$SCRIPT_DIR"
        python3 python/auth_redis_setup.py
        ;;
    "status")
        echo "📋 Local PostgreSQL Database Status:"
        if [ -d "$DATA_DIR" ]; then
            echo "  ✅ Data directory: $DATA_DIR"
            if check_postgresql_running; then
                echo "  ✅ PostgreSQL: RUNNING on port $PG_PORT"
                psql -h localhost -p $PG_PORT -U ubuntu -d postgres -c "SELECT version();" 2>/dev/null | grep PostgreSQL || echo "  ❌ Unable to connect"
            else
                echo "  ⏸️  PostgreSQL: STOPPED"
                echo "  💡 Run '$0 start' to start PostgreSQL"
            fi
        else
            echo "  ❌ PostgreSQL: NOT INITIALIZED"
            echo "  💡 Run '$0 setup' to initialize and setup database"
        fi
        echo ""
        echo "  Performance Target: >2000 auth/sec, <25ms P95"
        echo "  SQL Scripts: $SCRIPT_DIR/sql/"
        echo "  Python Utils: $SCRIPT_DIR/python/"
        echo "  Test Suite: $SCRIPT_DIR/tests/"
        echo "  Documentation: $SCRIPT_DIR/docs/"
        echo "  Log file: $LOG_FILE"
        ;;
    "psql")
        if ! check_postgresql_running; then
            initialize_postgresql
            start_postgresql
        fi
        echo "Connecting to local PostgreSQL..."
        psql -h localhost -p $PG_PORT -U ubuntu -d postgres
        ;;
    *)
        echo "Usage: $0 {start|stop|setup|test|redis|status|psql}"
        echo ""
        echo "Commands (Local PostgreSQL in project directory):"
        echo "  start   - Start local PostgreSQL server"
        echo "  stop    - Stop local PostgreSQL server"
        echo "  setup   - Initialize and setup authentication database"
        echo "  test    - Run enhanced performance tests >2000 auth/sec"
        echo "  redis   - Setup Redis caching layer"
        echo "  status  - Show local PostgreSQL status"
        echo "  psql    - Connect to local PostgreSQL with psql"
        echo ""
        echo "📁 All data is stored locally in: $DATA_DIR"
        echo "🔌 PostgreSQL runs on port: $PG_PORT (socket: $SOCKET_DIR)"
        ;;
esac
