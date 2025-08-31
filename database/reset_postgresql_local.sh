#!/bin/bash
#
# Reset Local PostgreSQL Database
# Fixes ownership issues and re-initializes database
#

set -e

echo "=== PostgreSQL Local Database Reset ==="
echo "This will:"
echo "  1. Stop any local PostgreSQL instances"
echo "  2. Remove corrupted data directory"
echo "  3. Re-initialize with correct permissions"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"
SOCKET_DIR="$SCRIPT_DIR/data/run"
PG_PORT=5433

# Check for PostgreSQL binary
if [ -d "/usr/lib/postgresql/17/bin" ]; then
    PG_BIN="/usr/lib/postgresql/17/bin"
    echo "Using PostgreSQL 17"
elif [ -d "/usr/lib/postgresql/16/bin" ]; then
    PG_BIN="/usr/lib/postgresql/16/bin"
    echo "Using PostgreSQL 16"
else
    echo "ERROR: PostgreSQL not found"
    exit 1
fi

echo ""
read -p "Continue with reset? This will delete existing data! (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Stopping any local PostgreSQL..."

# Try to stop gracefully if it's running
if [ -f "$DATA_DIR/postmaster.pid" ]; then
    "$PG_BIN/pg_ctl" -D "$DATA_DIR" stop -m immediate 2>/dev/null || true
    sleep 2
fi

# Kill any remaining processes
pkill -f "postgres.*$DATA_DIR" 2>/dev/null || true

echo "Step 2: Removing corrupted data directory..."

# Check current ownership
if [ -d "$DATA_DIR" ]; then
    echo "Current owner: $(stat -c '%U:%G' "$DATA_DIR")"
    
    # If owned by another user (like dnsmasq), we need sudo
    if [ "$(stat -c '%U' "$DATA_DIR")" != "$USER" ]; then
        echo "Directory owned by another user, using sudo to remove..."
        sudo rm -rf "$DATA_DIR"
    else
        rm -rf "$DATA_DIR"
    fi
fi

# Also clean up other data files
rm -f "$LOG_FILE"
rm -rf "$SOCKET_DIR"

echo "Step 3: Creating fresh data directory..."

# Create data directory with correct ownership
mkdir -p "$SCRIPT_DIR/data"
mkdir -p "$DATA_DIR"
mkdir -p "$SOCKET_DIR"

echo "Step 4: Initializing PostgreSQL with correct permissions..."

# Initialize database as current user
"$PG_BIN/initdb" -D "$DATA_DIR" \
    --auth-local=trust \
    --auth-host=md5 \
    --username="$USER" \
    --pwfile=<(echo "claude-backups-2025") \
    --no-instructions

# Verify ownership
echo ""
echo "New ownership: $(stat -c '%U:%G' "$DATA_DIR")"
echo "Permissions: $(stat -c '%a' "$DATA_DIR")"

echo "Step 5: Configuring PostgreSQL..."

# Configure PostgreSQL
cat >> "$DATA_DIR/postgresql.conf" << EOF

# Custom configuration for claude-backups
unix_socket_directories = '$SOCKET_DIR'
port = $PG_PORT
shared_buffers = 256MB
max_connections = 100
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB
EOF

# Update pg_hba.conf for local connections
cat > "$DATA_DIR/pg_hba.conf" << EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

echo "Step 6: Starting PostgreSQL..."

# Start PostgreSQL
"$PG_BIN/pg_ctl" -D "$DATA_DIR" -l "$LOG_FILE" -o "-p $PG_PORT" start

# Wait for startup
sleep 3

# Check if running
if "$PG_BIN/pg_isready" -h localhost -p $PG_PORT > /dev/null 2>&1; then
    echo "✓ PostgreSQL started successfully on port $PG_PORT"
else
    echo "✗ PostgreSQL failed to start"
    echo "Check log file: $LOG_FILE"
    exit 1
fi

echo "Step 7: Creating databases..."

# Create databases
"$PG_BIN/createdb" -h localhost -p $PG_PORT claude_auth 2>/dev/null || true
"$PG_BIN/createdb" -h localhost -p $PG_PORT claude_learning 2>/dev/null || true

echo ""
echo "=== Reset Complete ==="
echo ""
echo "PostgreSQL is now running with:"
echo "  Port: $PG_PORT"
echo "  Data: $DATA_DIR"
echo "  Socket: $SOCKET_DIR"
echo "  Owner: $USER"
echo ""
echo "Connect with:"
echo "  psql -h localhost -p $PG_PORT -U $USER -d claude_auth"
echo ""
echo "Stop with:"
echo "  $PG_BIN/pg_ctl -D $DATA_DIR stop"
echo ""
echo "The data directory is excluded from Git via .gitignore"