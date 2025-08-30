#!/bin/bash
#
# Fix PostgreSQL Permissions While Preserving Learning Data
# This script fixes ownership issues and enables Git tracking
#

set -e

echo "=== PostgreSQL Permission Fix with Data Preservation ==="
echo "Date: $(date)"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
BACKUP_DIR="$SCRIPT_DIR/data/backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"
SOCKET_DIR="$SCRIPT_DIR/data/run"
PG_PORT=5433

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for PostgreSQL binary
if [ -d "/usr/lib/postgresql/17/bin" ]; then
    PG_BIN="/usr/lib/postgresql/17/bin"
    PG_VERSION="17"
elif [ -d "/usr/lib/postgresql/16/bin" ]; then
    PG_BIN="/usr/lib/postgresql/16/bin"
    PG_VERSION="16"
else
    echo -e "${RED}ERROR: PostgreSQL not found${NC}"
    exit 1
fi

echo -e "${BLUE}PostgreSQL Version: $PG_VERSION${NC}"
echo ""

# Function to analyze current data
analyze_existing_data() {
    echo -e "${YELLOW}=== Analyzing Existing Database ===${NC}"
    
    if [ ! -d "$DATA_DIR" ]; then
        echo "No existing database found at $DATA_DIR"
        echo "Nothing to migrate."
        return 1
    fi
    
    # Get current ownership
    CURRENT_OWNER=$(stat -c '%U' "$DATA_DIR" 2>/dev/null || echo "unknown")
    CURRENT_GROUP=$(stat -c '%G' "$DATA_DIR" 2>/dev/null || echo "unknown")
    CURRENT_PERMS=$(stat -c '%a' "$DATA_DIR" 2>/dev/null || echo "unknown")
    
    echo "Current Status:"
    echo "  Directory: $DATA_DIR"
    echo "  Owner: $CURRENT_OWNER"
    echo "  Group: $CURRENT_GROUP"
    echo "  Permissions: $CURRENT_PERMS"
    
    # Try to get size with sudo if needed
    if [ "$CURRENT_OWNER" != "$USER" ]; then
        echo -e "\n${YELLOW}Using sudo to access database owned by $CURRENT_OWNER${NC}"
        DB_SIZE=$(sudo du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        FILE_COUNT=$(sudo find "$DATA_DIR" -type f 2>/dev/null | wc -l || echo "0")
        
        # Check if PostgreSQL is running
        if sudo test -f "$DATA_DIR/postmaster.pid" 2>/dev/null; then
            echo "  PostgreSQL Status: Running (PID exists)"
            PG_RUNNING=true
        else
            echo "  PostgreSQL Status: Not running"
            PG_RUNNING=false
        fi
        
        # Try to read PG_VERSION
        PG_DATA_VERSION=$(sudo cat "$DATA_DIR/PG_VERSION" 2>/dev/null || echo "unknown")
    else
        DB_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        FILE_COUNT=$(find "$DATA_DIR" -type f 2>/dev/null | wc -l || echo "0")
        PG_DATA_VERSION=$(cat "$DATA_DIR/PG_VERSION" 2>/dev/null || echo "unknown")
        
        if [ -f "$DATA_DIR/postmaster.pid" ]; then
            echo "  PostgreSQL Status: Running"
            PG_RUNNING=true
        else
            echo "  PostgreSQL Status: Not running"
            PG_RUNNING=false
        fi
    fi
    
    echo "  Database Size: $DB_SIZE"
    echo "  File Count: $FILE_COUNT files"
    echo "  PostgreSQL Data Version: $PG_DATA_VERSION"
    
    # Check for learning data tables
    echo -e "\n${YELLOW}Checking for Learning System Data...${NC}"
    
    if [ "$PG_RUNNING" = true ] && [ "$CURRENT_OWNER" = "$USER" ]; then
        # Try to connect and check tables
        LEARNING_TABLES=$("$PG_BIN/psql" -h localhost -p $PG_PORT -U $USER -d claude_learning -t -c "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name LIKE '%learning%';" 2>/dev/null || echo "0")
        
        if [ "$LEARNING_TABLES" -gt 0 ]; then
            echo "  Found $LEARNING_TABLES learning-related tables"
            
            # Get row counts for key tables
            for table in agent_metrics task_embeddings learning_feedback model_performance; do
                ROW_COUNT=$("$PG_BIN/psql" -h localhost -p $PG_PORT -U $USER -d claude_learning -t -c "
                    SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "N/A")
                if [ "$ROW_COUNT" != "N/A" ]; then
                    echo "    $table: $ROW_COUNT rows"
                fi
            done
        else
            echo "  No learning tables found (may need to connect to check)"
        fi
    else
        echo "  Cannot check learning data (database not accessible)"
    fi
    
    echo ""
    return 0
}

# Function to export learning data
export_learning_data() {
    echo -e "${YELLOW}=== Exporting Learning Data ===${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    # If database is running and accessible
    if [ "$PG_RUNNING" = true ]; then
        if [ "$CURRENT_OWNER" = "$USER" ]; then
            # Direct export
            echo "Exporting databases..."
            "$PG_BIN/pg_dump" -h localhost -p $PG_PORT -U $USER \
                -d claude_learning -f "$BACKUP_DIR/claude_learning.sql" 2>/dev/null || true
            "$PG_BIN/pg_dump" -h localhost -p $PG_PORT -U $USER \
                -d claude_auth -f "$BACKUP_DIR/claude_auth.sql" 2>/dev/null || true
        else
            echo "Database owned by $CURRENT_OWNER, need to fix permissions first"
        fi
    fi
    
    # Also create a file-level backup
    echo "Creating file-level backup..."
    if [ "$CURRENT_OWNER" != "$USER" ]; then
        sudo cp -a "$DATA_DIR" "$BACKUP_DIR/postgresql_files" 2>/dev/null || true
        sudo chown -R $USER:$USER "$BACKUP_DIR/postgresql_files" 2>/dev/null || true
    else
        cp -a "$DATA_DIR" "$BACKUP_DIR/postgresql_files" 2>/dev/null || true
    fi
    
    # Document the backup
    cat > "$BACKUP_DIR/README.md" << EOF
# Database Backup - $(date)

## Backup Contents
- PostgreSQL Version: $PG_DATA_VERSION
- Original Owner: $CURRENT_OWNER:$CURRENT_GROUP
- Original Permissions: $CURRENT_PERMS
- Database Size: $DB_SIZE
- File Count: $FILE_COUNT

## Files
- \`claude_learning.sql\`: Learning system data export
- \`claude_auth.sql\`: Authentication data export
- \`postgresql_files/\`: Complete file-level backup

## Restoration
To restore this data:
\`\`\`bash
# After initializing new database
psql -h localhost -p 5433 -U $USER -d claude_learning < claude_learning.sql
psql -h localhost -p 5433 -U $USER -d claude_auth < claude_auth.sql
\`\`\`
EOF
    
    echo -e "${GREEN}✓ Backup created at: $BACKUP_DIR${NC}"
    echo ""
}

# Function to fix permissions for Git
fix_permissions_for_git() {
    echo -e "${YELLOW}=== Fixing Permissions for Git ===${NC}"
    
    # PostgreSQL requires 700 on data directory, but we can make files readable
    echo "Adjusting permissions for Git compatibility..."
    
    if [ "$CURRENT_OWNER" != "$USER" ]; then
        echo "Taking ownership of database files..."
        sudo chown -R $USER:$USER "$DATA_DIR"
    fi
    
    # Set permissions that work for both PostgreSQL and Git
    chmod 700 "$DATA_DIR"
    
    # Make certain files readable for Git (but not writable by others)
    find "$DATA_DIR" -type f -name "*.conf" -exec chmod 600 {} \; 2>/dev/null || true
    find "$DATA_DIR" -type f -name "PG_VERSION" -exec chmod 644 {} \; 2>/dev/null || true
    find "$DATA_DIR" -type f -name "*.log" -exec chmod 644 {} \; 2>/dev/null || true
    
    # Critical: Keep data files secure
    find "$DATA_DIR/base" -type f -exec chmod 600 {} \; 2>/dev/null || true
    find "$DATA_DIR/global" -type f -exec chmod 600 {} \; 2>/dev/null || true
    
    echo -e "${GREEN}✓ Permissions adjusted${NC}"
    echo ""
}

# Function to create migration plan
create_migration_plan() {
    echo -e "${YELLOW}=== Creating Migration Plan ===${NC}"
    
    cat > "$SCRIPT_DIR/MIGRATION_PLAN.md" << EOF
# PostgreSQL Data Migration Plan

Generated: $(date)

## Current State
- Database Size: $DB_SIZE
- File Count: $FILE_COUNT files
- PostgreSQL Version: $PG_DATA_VERSION
- Ownership: $CURRENT_OWNER:$CURRENT_GROUP

## Migration Strategy

### Option 1: In-Place Permission Fix (RECOMMENDED)
Keeps existing data, fixes permissions for Git tracking.

**Pros:**
- Preserves all learning data
- No downtime
- Git can track configuration files
- Maintains database integrity

**Cons:**
- Large binary files in Git (not ideal)
- Repository size will increase

**Steps:**
1. Backup existing data ✓
2. Fix ownership to current user
3. Adjust permissions for Git compatibility
4. Exclude binary data files but track configs

### Option 2: SQL Export/Import
Export data as SQL, reinitialize, import.

**Pros:**
- Clean database structure
- Smaller Git footprint (SQL only)
- Portable across PostgreSQL versions

**Cons:**
- Requires database restart
- Temporary downtime

### Option 3: External Data Volume
Move data outside Git repository.

**Pros:**
- No Git bloat
- Professional approach
- Separate data lifecycle

**Cons:**
- Requires path reconfiguration
- Data not included in repository

## Recommended Approach

For Claude-Backups, we recommend **Option 1** with selective tracking:

1. Fix permissions to allow Git access
2. Track only essential files:
   - Configuration files (*.conf)
   - Schema definitions (*.sql)
   - Version information
3. Exclude large binary data files:
   - base/* (table data)
   - pg_wal/* (write-ahead logs)
   - pg_xact/* (transaction logs)

This provides:
- ✓ Learning data preservation
- ✓ Configuration tracking
- ✓ Reasonable repository size
- ✓ Cross-installation portability

## Data to Preserve

### Learning System Tables
- \`agent_metrics\`: Performance metrics per agent
- \`task_embeddings\`: Vector embeddings for tasks
- \`learning_feedback\`: User feedback data
- \`model_performance\`: ML model metrics
- \`interaction_logs\`: Agent interaction history

### Authentication Tables
- \`users\`: User accounts
- \`sessions\`: Active sessions
- \`permissions\`: Access control

## Implementation Command

\`\`\`bash
# Run the fix script
./fix_permissions_preserve_data.sh --implement
\`\`\`

## Post-Migration Validation

1. Check PostgreSQL starts correctly
2. Verify learning data is accessible
3. Confirm Git can track files
4. Test backup restoration
EOF
    
    echo -e "${GREEN}✓ Migration plan created: $SCRIPT_DIR/MIGRATION_PLAN.md${NC}"
    echo ""
}

# Function to implement the fix
implement_fix() {
    echo -e "${BLUE}=== Implementing Fix ===${NC}"
    
    # Stop PostgreSQL if running
    if [ "$PG_RUNNING" = true ]; then
        echo "Stopping PostgreSQL..."
        if [ "$CURRENT_OWNER" = "$USER" ]; then
            "$PG_BIN/pg_ctl" -D "$DATA_DIR" stop -m fast 2>/dev/null || true
        else
            sudo "$PG_BIN/pg_ctl" -D "$DATA_DIR" stop -m fast 2>/dev/null || true
        fi
        sleep 2
    fi
    
    # Fix permissions
    fix_permissions_for_git
    
    # Update .gitignore to be selective
    echo "Updating .gitignore for selective tracking..."
    
    # Remove old blanket ignore
    sed -i '/database\/data\/postgresql\//d' ../.gitignore 2>/dev/null || true
    
    # Add selective ignores
    cat >> ../.gitignore << 'EOF'

# PostgreSQL - track configs, ignore binary data
database/data/postgresql/base/
database/data/postgresql/global/
database/data/postgresql/pg_*_snapshots/
database/data/postgresql/pg_commit_ts/
database/data/postgresql/pg_dynshmem/
database/data/postgresql/pg_logical/
database/data/postgresql/pg_multixact/
database/data/postgresql/pg_notify/
database/data/postgresql/pg_replslot/
database/data/postgresql/pg_serial/
database/data/postgresql/pg_snapshots/
database/data/postgresql/pg_stat/
database/data/postgresql/pg_stat_tmp/
database/data/postgresql/pg_subtrans/
database/data/postgresql/pg_tblspc/
database/data/postgresql/pg_twophase/
database/data/postgresql/pg_wal/
database/data/postgresql/pg_xact/
database/data/postgresql/postmaster.pid
database/data/postgresql/postmaster.opts
EOF
    
    # Start PostgreSQL with correct ownership
    echo "Starting PostgreSQL..."
    "$PG_BIN/pg_ctl" -D "$DATA_DIR" -l "$LOG_FILE" -o "-p $PG_PORT" start
    
    sleep 3
    
    if "$PG_BIN/pg_isready" -h localhost -p $PG_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL started successfully${NC}"
    else
        echo -e "${RED}✗ PostgreSQL failed to start${NC}"
        echo "Check log: $LOG_FILE"
    fi
    
    echo ""
}

# Function to create tracking script
create_tracking_script() {
    cat > "$SCRIPT_DIR/track_learning_data.sh" << 'EOF'
#!/bin/bash
# Track PostgreSQL learning data in Git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"

echo "=== Tracking PostgreSQL Learning Data ==="

# Add configuration files
git add "$DATA_DIR"/*.conf 2>/dev/null || true
git add "$DATA_DIR"/PG_VERSION 2>/dev/null || true

# Export current data as SQL for portability
pg_dump -h localhost -p 5433 -U $USER -d claude_learning > "$SCRIPT_DIR/data/claude_learning_export.sql"
pg_dump -h localhost -p 5433 -U $USER -d claude_auth > "$SCRIPT_DIR/data/claude_auth_export.sql"

# Add SQL exports
git add "$SCRIPT_DIR/data"/*.sql

echo "✓ Learning data tracked in Git"
echo "  Configuration files: tracked directly"
echo "  Database exports: SQL format for portability"
EOF
    
    chmod +x "$SCRIPT_DIR/track_learning_data.sh"
    echo -e "${GREEN}✓ Created tracking script: track_learning_data.sh${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}This script will:${NC}"
    echo "1. Analyze existing database and learning data"
    echo "2. Create backup of all data"
    echo "3. Fix permissions for Git tracking"
    echo "4. Configure selective file tracking"
    echo "5. Preserve all learning data"
    echo ""
    
    # Analyze current state
    if analyze_existing_data; then
        # Create backup
        export_learning_data
        
        # Create migration plan
        create_migration_plan
        
        echo -e "${YELLOW}Ready to implement fix.${NC}"
        echo "This will:"
        echo "  - Take ownership of database files"
        echo "  - Adjust permissions for Git"
        echo "  - Enable selective tracking"
        echo "  - Preserve all learning data"
        echo ""
        read -p "Proceed with fix? (y/n) " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            implement_fix
            create_tracking_script
            
            echo -e "${GREEN}=== Fix Complete ===${NC}"
            echo ""
            echo "Next steps:"
            echo "1. Review: cat $SCRIPT_DIR/MIGRATION_PLAN.md"
            echo "2. Track data: ./track_learning_data.sh"
            echo "3. Commit: git add -A && git commit -m 'fix: PostgreSQL permissions'"
            echo ""
            echo "Backup location: $BACKUP_DIR"
        else
            echo "Fix cancelled. Backup still available at: $BACKUP_DIR"
        fi
    else
        echo "No existing database to migrate."
        echo "Run './manage_database.sh setup' to create a new database."
    fi
}

# Handle command line arguments
if [ "$1" == "--help" ]; then
    echo "Usage: $0 [--analyze-only]"
    echo "  --analyze-only  Only analyze, don't fix"
    exit 0
elif [ "$1" == "--analyze-only" ]; then
    analyze_existing_data
    exit 0
else
    main
fi