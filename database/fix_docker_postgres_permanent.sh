#!/bin/bash
#
# Permanent fix for PostgreSQL Docker permission issues
# Run as root to fix ownership problems once and for all
#

set -e

echo "=== PostgreSQL Docker Permission Fix ==="
echo "This will permanently fix the permission issues"
echo ""

# Stop and remove the problematic container
echo "Step 1: Stopping and removing old container..."
docker stop claude-postgres 2>/dev/null || true
docker rm claude-postgres 2>/dev/null || true

# Fix ownership of the data directory
echo "Step 2: Fixing ownership of data directory..."
DATA_DIR="/home/john/claude-backups/database/data/postgresql_docker"

# Check if directory exists and has wrong ownership
if [ -d "$DATA_DIR" ]; then
    echo "Current ownership:"
    ls -la "$DATA_DIR" | head -5
    
    # Fix ownership to postgres user (UID 999 in Docker)
    echo "Changing ownership to UID 999 (postgres in Docker)..."
    chown -R 999:999 "$DATA_DIR"
    
    # Set proper permissions
    chmod -R 700 "$DATA_DIR"
    
    echo "New ownership:"
    ls -la "$DATA_DIR" | head -5
else
    echo "Creating fresh data directory..."
    mkdir -p "$DATA_DIR"
    chown 999:999 "$DATA_DIR"
    chmod 700 "$DATA_DIR"
fi

# Create the container with proper settings
echo "Step 3: Creating new container with correct settings..."
docker run -d \
    --name claude-postgres \
    -e POSTGRES_USER=claude_agent \
    -e POSTGRES_PASSWORD=secure_password_2024 \
    -e POSTGRES_DB=claude_learning \
    -v "$DATA_DIR":/var/lib/postgresql/data \
    -p 5433:5432 \
    --user 999:999 \
    postgres:16

# Wait for PostgreSQL to start
echo "Step 4: Waiting for PostgreSQL to start..."
sleep 10

# Check if it's running properly
echo "Step 5: Verifying PostgreSQL is working..."
docker exec claude-postgres psql -U claude_agent -d claude_learning -c "SELECT version();" || {
    echo "ERROR: PostgreSQL still not working. Checking logs..."
    docker logs claude-postgres --tail 50
    exit 1
}

echo ""
echo "=== Diagnostic Information ==="

# Show container status
echo "Container status:"
docker ps | grep postgres

# Show data directory permissions
echo ""
echo "Data directory permissions:"
ls -la "$DATA_DIR" | head -5

# Show PostgreSQL version
echo ""
echo "PostgreSQL version:"
docker exec claude-postgres psql -U claude_agent -d claude_learning -c "SELECT version();" 2>/dev/null || echo "Failed to connect"

# Check tables
echo ""
echo "Database tables:"
docker exec claude-postgres psql -U claude_agent -d claude_learning -c "\dt" 2>/dev/null || echo "Failed to list tables"

# Check for any data
echo ""
echo "Checking for existing data:"
docker exec claude-postgres psql -U claude_agent -d claude_learning -c "
SELECT 
    'agent_interactions' as table_name, COUNT(*) as row_count FROM agent_interactions
UNION ALL
SELECT 
    'learning_patterns', COUNT(*) FROM learning_patterns
UNION ALL
SELECT 
    'performance_metrics', COUNT(*) FROM performance_metrics
UNION ALL
SELECT 
    'context_embeddings', COUNT(*) FROM context_embeddings
UNION ALL
SELECT 
    'feedback_history', COUNT(*) FROM feedback_history;" 2>/dev/null || echo "No tables found - need to initialize"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "To run this fix:"
echo "  sudo bash $0"
echo "  OR"
echo "  su -c 'bash $0'"
echo ""
echo "The PostgreSQL container should now work permanently without permission issues."
echo ""
echo "Connect with:"
echo "  docker exec -it claude-postgres psql -U claude_agent -d claude_learning"
echo "  OR from host:"
echo "  psql -h localhost -p 5433 -U claude_agent -d claude_learning"