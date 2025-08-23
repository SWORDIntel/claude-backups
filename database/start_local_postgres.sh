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

# Start PostgreSQL
/usr/lib/postgresql/17/bin/pg_ctl \
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