#!/bin/bash
#
# Export Learning Data from Docker PostgreSQL
# Preserves all learning system data for Git tracking
#

set -e

echo "=== Docker PostgreSQL Learning Data Export ==="
echo "Date: $(date)"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$SCRIPT_DIR/sql/exports"
BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Create directories
mkdir -p "$EXPORT_DIR"
mkdir -p "$BACKUP_DIR"

# Function to check Docker PostgreSQL
check_docker_postgres() {
    echo -e "${YELLOW}Checking Docker PostgreSQL status...${NC}"
    
    if docker ps | grep -q claude-postgres; then
        STATUS=$(docker ps --filter name=claude-postgres --format "table {{.Status}}" | tail -n 1)
        echo "Container Status: $STATUS"
        
        if docker exec claude-postgres pg_isready -U claude_agent > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL is running and ready${NC}"
            return 0
        else
            echo -e "${RED}✗ PostgreSQL container exists but database not ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ PostgreSQL container not running${NC}"
        echo ""
        echo "To start it:"
        echo "  cd database/docker && docker-compose up -d postgres"
        return 1
    fi
}

# Function to export databases
export_databases() {
    echo -e "\n${YELLOW}Exporting databases...${NC}"
    
    # Get database list
    DBS=$(docker exec claude-postgres psql -U claude_agent -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" 2>/dev/null || echo "")
    
    if [ -z "$DBS" ]; then
        echo "No user databases found"
        return
    fi
    
    for DB in $DBS; do
        DB=$(echo $DB | tr -d ' ')
        echo -n "  Exporting $DB... "
        
        # Export to SQL
        if docker exec claude-postgres pg_dump -U claude_agent -d "$DB" > "$EXPORT_DIR/${DB}_$(date +%Y%m%d).sql" 2>/dev/null; then
            SIZE=$(du -h "$EXPORT_DIR/${DB}_$(date +%Y%m%d).sql" | cut -f1)
            echo -e "${GREEN}✓${NC} ($SIZE)"
            
            # Also create versioned backup
            cp "$EXPORT_DIR/${DB}_$(date +%Y%m%d).sql" "$BACKUP_DIR/${DB}.sql"
        else
            echo -e "${RED}✗${NC}"
        fi
    done
}

# Function to analyze learning data
analyze_learning_data() {
    echo -e "\n${YELLOW}Analyzing learning system data...${NC}"
    
    # Check for learning tables
    TABLES=$(docker exec claude-postgres psql -U claude_agent -d claude_learning -t -c "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name;" 2>/dev/null || echo "")
    
    if [ -z "$TABLES" ]; then
        echo "No learning tables found"
        return
    fi
    
    echo "Learning System Tables:"
    for TABLE in $TABLES; do
        TABLE=$(echo $TABLE | tr -d ' ')
        if [ ! -z "$TABLE" ]; then
            COUNT=$(docker exec claude-postgres psql -U claude_agent -d claude_learning -t -c "
                SELECT COUNT(*) FROM $TABLE;" 2>/dev/null || echo "0")
            COUNT=$(echo $COUNT | tr -d ' ')
            printf "  %-30s %8s rows\n" "$TABLE" "$COUNT"
        fi
    done
    
    # Get total database size
    TOTAL_SIZE=$(docker exec claude-postgres psql -U claude_agent -d claude_learning -t -c "
        SELECT pg_size_pretty(pg_database_size('claude_learning'));" 2>/dev/null || echo "unknown")
    echo -e "\nTotal Learning Database Size: ${BLUE}$TOTAL_SIZE${NC}"
}

# Function to export specific learning data as CSV
export_learning_csv() {
    echo -e "\n${YELLOW}Exporting learning data as CSV...${NC}"
    
    CSV_DIR="$EXPORT_DIR/csv"
    mkdir -p "$CSV_DIR"
    
    # Export key tables as CSV for analysis
    TABLES="agent_metrics task_embeddings learning_feedback model_performance interaction_logs"
    
    for TABLE in $TABLES; do
        echo -n "  Exporting $TABLE.csv... "
        
        if docker exec claude-postgres psql -U claude_agent -d claude_learning -c "
            COPY (SELECT * FROM $TABLE) TO STDOUT WITH CSV HEADER;" > "$CSV_DIR/$TABLE.csv" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped (table may not exist)${NC}"
        fi
    done
}

# Function to create import script
create_import_script() {
    cat > "$EXPORT_DIR/import_learning_data.sh" << 'EOF'
#!/bin/bash
# Import learning data into PostgreSQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Importing Learning Data ==="

# Check if running in Docker or local
if docker ps | grep -q claude-postgres; then
    echo "Importing to Docker PostgreSQL..."
    
    for SQL in "$SCRIPT_DIR"/*_*.sql; do
        if [ -f "$SQL" ]; then
            DB=$(basename "$SQL" | cut -d_ -f1)
            echo -n "  Importing $DB... "
            
            # Create database if not exists
            docker exec claude-postgres psql -U claude_agent -c "CREATE DATABASE IF NOT EXISTS $DB;" 2>/dev/null || true
            
            # Import data
            if docker exec -i claude-postgres psql -U claude_agent -d "$DB" < "$SQL"; then
                echo "✓"
            else
                echo "✗"
            fi
        fi
    done
else
    echo "Importing to local PostgreSQL..."
    
    for SQL in "$SCRIPT_DIR"/*_*.sql; do
        if [ -f "$SQL" ]; then
            DB=$(basename "$SQL" | cut -d_ -f1)
            echo -n "  Importing $DB... "
            
            # Create database if not exists
            createdb -h localhost -p 5433 -U $USER "$DB" 2>/dev/null || true
            
            # Import data
            if psql -h localhost -p 5433 -U $USER -d "$DB" < "$SQL"; then
                echo "✓"
            else
                echo "✗"
            fi
        fi
    done
fi

echo "Import complete!"
EOF
    
    chmod +x "$EXPORT_DIR/import_learning_data.sh"
    echo -e "${GREEN}✓ Created import script${NC}"
}

# Function to fix Git tracking
setup_git_tracking() {
    echo -e "\n${YELLOW}Setting up Git tracking...${NC}"
    
    # Update .gitignore for proper tracking
    GITIGNORE="$SCRIPT_DIR/../.gitignore"
    
    # Check if already configured
    if ! grep -q "# PostgreSQL Docker data" "$GITIGNORE" 2>/dev/null; then
        cat >> "$GITIGNORE" << 'EOF'

# PostgreSQL Docker data - track exports only
database/data/postgresql/
!database/sql/exports/*.sql
!database/sql/exports/csv/*.csv
database/backups/
EOF
        echo "  Updated .gitignore"
    fi
    
    # Add SQL exports to Git
    cd "$SCRIPT_DIR/.."
    git add sql/exports/*.sql 2>/dev/null || true
    git add sql/exports/csv/*.csv 2>/dev/null || true
    
    echo -e "${GREEN}✓ SQL exports ready for Git tracking${NC}"
}

# Function to create summary
create_summary() {
    cat > "$EXPORT_DIR/EXPORT_SUMMARY.md" << EOF
# Learning Data Export Summary

**Date**: $(date)  
**Export Location**: $EXPORT_DIR

## Exported Files

### SQL Dumps (Full Database Backups)
$(ls -lh "$EXPORT_DIR"/*.sql 2>/dev/null | awk '{print "- " $9 " (" $5 ")"}')

### CSV Exports (For Analysis)
$(ls -lh "$EXPORT_DIR/csv"/*.csv 2>/dev/null | awk '{print "- " $9 " (" $5 ")"}')

## How to Restore

### To Docker PostgreSQL
\`\`\`bash
cd database/sql/exports
./import_learning_data.sh
\`\`\`

### To Local PostgreSQL
\`\`\`bash
psql -h localhost -p 5433 -U \$USER -d claude_learning < claude_learning_$(date +%Y%m%d).sql
\`\`\`

## Git Tracking

The SQL exports are tracked in Git for portability.
Binary database files are excluded to keep repository size manageable.

To commit the latest export:
\`\`\`bash
git add database/sql/exports/*.sql
git commit -m "backup: Learning data snapshot $(date +%Y%m%d)"
\`\`\`
EOF
    
    echo -e "\n${GREEN}✓ Export summary created${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}This script will export all learning data from Docker PostgreSQL${NC}"
    echo ""
    
    # Check Docker PostgreSQL
    if ! check_docker_postgres; then
        echo -e "\n${RED}Cannot proceed without running PostgreSQL${NC}"
        echo ""
        echo "To start PostgreSQL:"
        echo "  cd database/docker"
        echo "  docker-compose up -d postgres"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
    
    # Export data
    export_databases
    analyze_learning_data
    export_learning_csv
    create_import_script
    setup_git_tracking
    create_summary
    
    echo ""
    echo -e "${GREEN}=== Export Complete ===${NC}"
    echo ""
    echo "Exported to: $EXPORT_DIR"
    echo "Backup at: $BACKUP_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Review exports: ls -la $EXPORT_DIR/"
    echo "2. Commit to Git: git add database/sql/exports/*.sql && git commit -m 'backup: Learning data'"
    echo "3. To restore later: cd database/sql/exports && ./import_learning_data.sh"
}

# Run main function
main