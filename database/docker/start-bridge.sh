#!/bin/bash
set -e

# Start script for Claude Agent Bridge
echo "Starting Claude Agent Bridge..."

# Wait for learning system to be ready
echo "Waiting for learning system to be ready..."
while ! curl -f http://learning-system:8080/health 2>/dev/null; do
    echo "Learning system is not ready. Waiting..."
    sleep 5
done

echo "Learning system is ready!"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
while ! pg_isready -h postgres -p 5432 -U claude_agent; do
    echo "PostgreSQL is not ready. Waiting..."
    sleep 2
done

echo "PostgreSQL is ready!"

# Start the bridge service
echo "Starting agent bridge service..."

exec python -m uvicorn claude_agent_bridge:app \
    --host 0.0.0.0 \
    --port 8081 \
    --workers 1 \
    --loop uvloop \
    --log-level info \
    --access-log