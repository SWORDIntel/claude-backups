#!/bin/bash
set -e

# Docker Stop Script for Claude Agent Framework

echo "=== Stopping Claude Agent Framework ==="

# Graceful shutdown with dependency order
echo "Stopping Agent Bridge..."
docker-compose stop agent-bridge

echo "Stopping Learning System..."
docker-compose stop learning-system

echo "Stopping Prometheus..."
docker-compose stop prometheus

echo "Stopping PostgreSQL..."
docker-compose stop postgres

echo "Removing containers..."
docker-compose down

echo ""
echo "=== Claude Agent Framework Stopped ==="
echo ""
echo "Data preserved in:"
echo "  • PostgreSQL data: ./database/data/postgresql"
echo "  • Learning data:   ./database/learning_data"
echo ""
echo "To completely remove (including data): docker-compose down -v"
echo "To restart: ./database/docker/docker-start.sh"