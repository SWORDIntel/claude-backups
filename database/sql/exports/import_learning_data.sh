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
