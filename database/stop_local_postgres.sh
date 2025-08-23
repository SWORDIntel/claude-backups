#!/bin/bash
# Stop local PostgreSQL instance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"

echo "🛑 Stopping local PostgreSQL instance..."

/usr/lib/postgresql/17/bin/pg_ctl \
    -D "$DATA_DIR" \
    stop

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL stopped successfully"
else
    echo "❌ Failed to stop PostgreSQL"
    exit 1
fi