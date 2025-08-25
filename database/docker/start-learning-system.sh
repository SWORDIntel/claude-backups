#!/bin/bash
set -e

# Start script for Claude Learning System
echo "Starting Claude Learning System..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
while ! pg_isready -h $DATABASE_HOST -p $DATABASE_PORT -U $DATABASE_USER; do
    echo "PostgreSQL is not ready. Waiting..."
    sleep 2
done

echo "PostgreSQL is ready!"

# Set up the database if needed
echo "Setting up learning system database..."
cd /app/agents/src/python

# Run database migrations/setup
if [ -f "postgresql_learning_system.py" ]; then
    python postgresql_learning_system.py setup 2>/dev/null || echo "Database setup skipped or already completed"
fi

# Start the learning system with multiple workers
echo "Starting learning system services..."

# Start the main learning system API
exec python -m uvicorn claude_agent_bridge:app \
    --host 0.0.0.0 \
    --port 8080 \
    --workers 2 \
    --loop uvloop \
    --log-level info \
    --access-log \
    --timeout-keep-alive 65 \
    --limit-concurrency 1000 \
    --limit-max-requests 10000