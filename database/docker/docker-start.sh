#!/bin/bash
# Claude Agent Framework - Docker Container Startup Script
# Self-contained database and learning system launcher

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🐳 Claude Agent Framework - Containerized Environment"
echo "======================================================"
echo

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "   Install with: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    # Try docker compose (newer syntax)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        echo "❌ Docker Compose is not installed!"
        echo "   Install with: sudo apt-get install docker-compose"
        exit 1
    fi
else
    COMPOSE_CMD="docker-compose"
fi

cd "$PROJECT_ROOT"

# Check if .env exists, create from template if not
if [ ! -f .env ]; then
    if [ -f .env.docker ]; then
        echo "📝 Creating .env from template..."
        cp .env.docker .env
        echo "   Please edit .env to set secure passwords!"
        echo
    else
        echo "⚠️  No .env file found. Using defaults (not secure!)"
        echo
    fi
fi

# Check if PostgreSQL data exists
if [ ! -d "database/data/postgresql" ]; then
    echo "📁 Creating PostgreSQL data directory..."
    mkdir -p database/data/postgresql
fi

# Pull/build images
echo "🔨 Building containers..."
$COMPOSE_CMD build --quiet

# Start services
echo "🚀 Starting services..."
$COMPOSE_CMD up -d

# Wait for services
echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check service status
echo
echo "📊 Service Status:"
echo "=================="

# Check PostgreSQL
POSTGRES_USER=${POSTGRES_USER:-claude_user}
if $COMPOSE_CMD exec -T postgres pg_isready -U "$POSTGRES_USER" &> /dev/null; then
    echo "✅ PostgreSQL:      Ready on port 5433 (user: $POSTGRES_USER)"
else
    echo "❌ PostgreSQL:      Not ready (user: $POSTGRES_USER)"
    echo "   Checking logs: $COMPOSE_CMD logs postgres"
fi

# Check Learning System
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Learning System: Ready on http://localhost:8080"
else
    echo "⚠️  Learning System: Starting up..."
fi

# Check Agent Bridge
if curl -s http://localhost:8081/health > /dev/null 2>&1; then
    echo "✅ Agent Bridge:    Ready on http://localhost:8081"
else
    echo "⚠️  Agent Bridge:    Starting up..."
fi

# Check Prometheus
if curl -s http://localhost:9091/-/ready > /dev/null 2>&1; then
    echo "✅ Prometheus:      Ready on http://localhost:9091"
else
    echo "⚠️  Prometheus:      Starting up..."
fi

echo
echo "🎉 Claude containerized environment is running!"
echo
echo "📚 Quick Commands:"
echo "  View logs:     $COMPOSE_CMD logs -f [service]"
echo "  Stop all:      $COMPOSE_CMD down"
echo "  Reset data:    $COMPOSE_CMD down -v"
echo "  Connect DB:    psql -h localhost -p 5433 -U \$POSTGRES_USER -d \$POSTGRES_DB
  Check logs:    $COMPOSE_CMD logs -f [service]
  Shell access:  $COMPOSE_CMD exec [service] /bin/bash"
echo
echo "🔗 Service URLs:"
echo "  Learning API:  http://localhost:8080"
echo "  Agent Bridge:  http://localhost:8081"
echo "  Prometheus:    http://localhost:9091"
echo "  PostgreSQL:    localhost:5433"
echo