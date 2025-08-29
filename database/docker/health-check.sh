#!/bin/bash

# Claude Agent Framework Health Check Script

set -e

echo "=== Claude Agent Framework Health Check ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall health
overall_health=true

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local description=$3
    
    printf "%-20s" "$description:"
    
    if curl -f -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
        overall_health=false
    fi
}

# Function to check port
check_port() {
    local port=$1
    local description=$2
    
    printf "%-20s" "$description:"
    
    if nc -z localhost "$port" 2>/dev/null; then
        echo -e "${GREEN}✓ Listening${NC}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
        overall_health=false
    fi
}

# Check Docker services
echo "Docker Services:"
docker-compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check individual service health
echo "Service Health Checks:"
check_port 5433 "PostgreSQL"
check_service "Learning System" "http://localhost:8080/health"
check_service "Agent Bridge" "http://localhost:8081/health"
check_port 9091 "Prometheus"

echo ""

# Check system status through bridge API
echo "System Status:"
if curl -f -s "http://localhost:8081/api/v1/system/status" | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✓ System API responding${NC}"
    curl -s "http://localhost:8081/api/v1/system/status" | jq '.components | to_entries[] | "\(.key): \(.value.status)"' -r | sed 's/^/  /'
else
    echo -e "${RED}✗ System API not responding${NC}"
    overall_health=false
fi

echo ""

# Database connectivity test
echo "Database Connectivity:"
if docker-compose exec -T postgres pg_isready -U claude_agent -d claude_agents_auth > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL connection${NC}"
    
    # Get basic database stats
    db_stats=$(docker-compose exec -T postgres psql -U claude_agent -d claude_agents_auth -t -c "
        SELECT 
            'Users: ' || count(*) || ' (active: ' || sum(case when status='active' then 1 else 0 end) || ')'
        FROM users;
    " 2>/dev/null | tr -d ' ')
    
    if [ -n "$db_stats" ]; then
        echo "  $db_stats"
    fi
else
    echo -e "${RED}✗ PostgreSQL connection failed${NC}"
    overall_health=false
fi

echo ""

# Resource usage
echo "Resource Usage:"
if command -v docker &> /dev/null; then
    echo "Container Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep claude || echo "No Claude containers found"
fi

echo ""

# Final status
if $overall_health; then
    echo -e "${GREEN}=== Overall System Status: HEALTHY ===${NC}"
    echo ""
    echo "All services are operational. You can access:"
    echo "  • Learning System: http://localhost:8080"
    echo "  • Agent Bridge:    http://localhost:8081"  
    echo "  • API Docs:        http://localhost:8081/docs"
    echo "  • Prometheus:      http://localhost:9091"
    echo ""
    exit 0
else
    echo -e "${RED}=== Overall System Status: UNHEALTHY ===${NC}"
    echo ""
    echo "Some services are not responding. Check logs with:"
    echo "  docker-compose logs [service_name]"
    echo ""
    exit 1
fi