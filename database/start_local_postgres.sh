#!/bin/bash
# Start local PostgreSQL instance for Claude Database

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"
PID_FILE="$SCRIPT_DIR/data/postgresql.pid"

# Check if PostgreSQL is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "✅ PostgreSQL is already running (PID: $PID)"
        exit 0
    fi
fi

echo "🚀 Starting local PostgreSQL instance..."

# Find PostgreSQL installation
PG_CTL_PATH=""
if command -v pg_ctl >/dev/null 2>&1; then
    PG_CTL_PATH=$(which pg_ctl)
    echo "📍 Found pg_ctl at: $PG_CTL_PATH"
else
    # Try common PostgreSQL paths
    for version in 17 16 15 14 13 12; do
        if [ -x "/usr/lib/postgresql/$version/bin/pg_ctl" ]; then
            PG_CTL_PATH="/usr/lib/postgresql/$version/bin/pg_ctl"
            echo "📍 Found PostgreSQL $version at: $PG_CTL_PATH"
            break
        fi
    done
fi

if [ -z "$PG_CTL_PATH" ]; then
    echo "❌ PostgreSQL not found. Please install PostgreSQL."
    echo "   sudo apt-get update && sudo apt-get install -y postgresql postgresql-client"
    exit 1
fi

# Start PostgreSQL
"$PG_CTL_PATH" \
    -D "$DATA_DIR" \
    -l "$LOG_FILE" \
    -o "-p 5433" \
    start

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL started successfully on port 5433"
    echo "📁 Data directory: $DATA_DIR"
    echo "📝 Log file: $LOG_FILE"
    echo ""
    echo "Connection string:"
    echo "  psql -h localhost -p 5433 -U ubuntu -d postgres"
else
    echo "❌ Failed to start PostgreSQL"
    echo "Check log file: $LOG_FILE"
    exit 1
fi