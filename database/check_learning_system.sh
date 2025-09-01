#!/bin/bash
#
# Check Learning System Status and Export Data
# 
# 🚨 DOCKER CONTAINER ONLY - DO NOT USE SYSTEM POSTGRESQL 🚨
# This script ONLY works with the Docker container on port 5433
# NEVER modify to use local PostgreSQL installations
#

echo "=== Claude Learning System Status Check ==="
echo "Date: $(date)"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check Docker PostgreSQL
echo -e "${YELLOW}1. Checking PostgreSQL Container...${NC}"
if docker ps | grep -q claude-postgres; then
    echo -e "${GREEN}✓ PostgreSQL container is running${NC}"
    
    # Get container details
    docker ps --filter name=claude-postgres --format "table {{.Status}}\t{{.Ports}}" | tail -n 1
else
    echo -e "${RED}✗ PostgreSQL container not running${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Checking Database Connection...${NC}"
if docker exec claude-postgres pg_isready -U claude_agent > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database is accepting connections${NC}"
    
    # Show version
    VERSION=$(docker exec claude-postgres psql -U claude_agent -t -c "SELECT version();" 2>/dev/null | head -n 1)
    echo "  PostgreSQL: $VERSION"
else
    echo -e "${RED}✗ Cannot connect to database${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}3. Checking Learning System Schema...${NC}"

# Check tables and row counts
docker exec claude-postgres psql -U claude_agent -d claude_learning << 'EOF'
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY tablename;
EOF

echo ""
echo -e "${YELLOW}4. Checking pgvector Extension...${NC}"
VECTOR_STATUS=$(docker exec claude-postgres psql -U claude_agent -d claude_learning -t -c "
    SELECT installed_version 
    FROM pg_available_extensions 
    WHERE name = 'vector';" 2>/dev/null | tr -d ' ')

if [ ! -z "$VECTOR_STATUS" ] && [ "$VECTOR_STATUS" != "" ]; then
    echo -e "${GREEN}✓ pgvector extension installed: v$VECTOR_STATUS${NC}"
else
    echo -e "${RED}✗ pgvector extension not installed${NC}"
fi

echo ""
echo -e "${YELLOW}5. Learning Data Summary...${NC}"

docker exec claude-postgres psql -U claude_agent -d claude_learning << 'EOF'
-- Agent metrics summary
SELECT 
    'Agent Metrics' as category,
    COUNT(*) as total_records,
    COUNT(DISTINCT agent_name) as unique_agents,
    AVG(execution_time_ms)::numeric(10,2) as avg_time_ms,
    (COUNT(CASE WHEN success THEN 1 END)::float / NULLIF(COUNT(*), 0) * 100)::numeric(5,2) as success_rate
FROM agent_metrics
UNION ALL
-- Interaction logs summary
SELECT 
    'Interactions' as category,
    COUNT(*) as total_records,
    COUNT(DISTINCT from_agent || '->' || to_agent) as unique_pairs,
    AVG(duration_ms)::numeric(10,2) as avg_time_ms,
    100.00 as success_rate
FROM interaction_logs
UNION ALL
-- Task embeddings summary
SELECT 
    'Task Embeddings' as category,
    COUNT(*) as total_records,
    COUNT(DISTINCT agent_name) as unique_agents,
    AVG(avg_execution_time_ms)::numeric(10,2) as avg_time_ms,
    AVG(success_rate)::numeric(5,2) as success_rate
FROM task_embeddings;
EOF

echo ""
echo -e "${YELLOW}6. Database Size...${NC}"
DB_SIZE=$(docker exec claude-postgres psql -U claude_agent -d claude_learning -t -c "
    SELECT pg_size_pretty(pg_database_size('claude_learning'));" 2>/dev/null)
echo -e "Total Database Size: ${BLUE}$DB_SIZE${NC}"

echo ""
echo -e "${YELLOW}7. Export Options...${NC}"
echo "To export learning data:"
echo "  ./export_docker_learning_data.sh    # Export to SQL files"
echo ""
echo "To backup entire database:"
echo "  docker exec claude-postgres pg_dump -U claude_agent claude_learning > backup.sql"
echo ""

echo -e "${GREEN}=== Status Check Complete ===${NC}"