#!/bin/bash
#
# Fix PostgreSQL Permission Issues for Claude-Backups Database
# This script diagnoses and fixes permission problems with local PostgreSQL
#

set -e

echo "=== PostgreSQL Permission Fix Script ==="
echo "Date: $(date)"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/postgresql"
LOG_FILE="$SCRIPT_DIR/data/postgresql.log"
SOCKET_DIR="$SCRIPT_DIR/data/run"
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Current Situation ===${NC}"
echo "Current User: $CURRENT_USER"
echo "Current Group: $CURRENT_GROUP"
echo "Data Directory: $DATA_DIR"
echo ""

# Function to check PostgreSQL processes
check_postgres_processes() {
    echo -e "${YELLOW}Checking PostgreSQL processes...${NC}"
    
    # Check system PostgreSQL
    if systemctl is-active --quiet postgresql; then
        echo "✓ System PostgreSQL is running on port 5432"
    else
        echo "✗ System PostgreSQL is not running"
    fi
    
    # Check for local PostgreSQL
    if pgrep -f "postgres.*$DATA_DIR" > /dev/null; then
        echo "✓ Local PostgreSQL is running from $DATA_DIR"
        LOCAL_PG_PID=$(pgrep -f "postgres.*$DATA_DIR" | head -1)
        echo "  PID: $LOCAL_PG_PID"
    else
        echo "✗ No local PostgreSQL running from $DATA_DIR"
    fi
    
    echo ""
}

# Function to diagnose permission issues
diagnose_permissions() {
    echo -e "${YELLOW}Diagnosing permission issues...${NC}"
    
    if [ -d "$DATA_DIR" ]; then
        # Check directory ownership
        DIR_OWNER=$(stat -c "%U" "$DATA_DIR")
        DIR_GROUP=$(stat -c "%G" "$DATA_DIR")
        DIR_PERMS=$(stat -c "%a" "$DATA_DIR")
        
        echo "Data directory: $DATA_DIR"
        echo "  Owner: $DIR_OWNER"
        echo "  Group: $DIR_GROUP"
        echo "  Permissions: $DIR_PERMS"
        
        # Check if we can access it
        if [ -r "$DATA_DIR" ]; then
            echo "  ✓ Directory is readable"
        else
            echo "  ✗ Directory is NOT readable"
        fi
        
        # Check some key files if accessible
        if [ -r "$DATA_DIR/PG_VERSION" ]; then
            PG_VERSION=$(cat "$DATA_DIR/PG_VERSION")
            echo "  PostgreSQL Version: $PG_VERSION"
        else
            echo "  ✗ Cannot read PG_VERSION file"
        fi
        
        # Count permission denied files
        DENIED_COUNT=$(find "$DATA_DIR" -type f 2>&1 | grep -c "Permission denied" || true)
        if [ "$DENIED_COUNT" -gt 0 ]; then
            echo -e "  ${RED}✗ $DENIED_COUNT files have permission issues${NC}"
        fi
    else
        echo "✗ Data directory does not exist: $DATA_DIR"
    fi
    
    echo ""
}

# Function to explain the root cause
explain_issue() {
    echo -e "${BLUE}=== Root Cause Analysis ===${NC}"
    
    echo "The permission issues occur because:"
    echo ""
    echo "1. PostgreSQL creates files with restrictive permissions (0600 or 0700)"
    echo "   for security reasons - only the postgres user should access them."
    echo ""
    echo "2. When initdb runs as your user ($CURRENT_USER), it creates files"
    echo "   owned by $CURRENT_USER but with PostgreSQL's restrictive permissions."
    echo ""
    echo "3. Git cannot read these files because they have 0600 permissions,"
    echo "   causing 'Permission denied' errors during git operations."
    echo ""
    echo "4. PostgreSQL requires these permissions for security and will refuse"
    echo "   to start if permissions are too open (e.g., 0777)."
    echo ""
}

# Function to provide solutions
provide_solutions() {
    echo -e "${BLUE}=== Solutions ===${NC}"
    
    echo "Option 1: Exclude PostgreSQL data from Git (RECOMMENDED)"
    echo -e "${GREEN}Add to .gitignore:${NC}"
    cat << 'EOF'
# PostgreSQL data files
database/data/postgresql/
database/data/*.log
database/data/run/
EOF
    echo ""
    
    echo "Option 2: Use Docker for PostgreSQL (CLEAN SEPARATION)"
    echo "  - Keeps database files outside project directory"
    echo "  - No permission conflicts with Git"
    echo "  - Professional deployment approach"
    echo ""
    
    echo "Option 3: Fix permissions for current session (TEMPORARY)"
    echo "  WARNING: This may break PostgreSQL security!"
    echo "  Run: chmod -R 755 $DATA_DIR"
    echo "  But PostgreSQL may refuse to start with these permissions."
    echo ""
}

# Function to implement the fix
implement_fix() {
    echo -e "${BLUE}=== Implementing Fix ===${NC}"
    
    # Check if .gitignore exists
    GITIGNORE="$SCRIPT_DIR/../.gitignore"
    
    echo "1. Updating .gitignore..."
    
    # Check if already ignored
    if grep -q "database/data/postgresql" "$GITIGNORE" 2>/dev/null; then
        echo "   ✓ PostgreSQL data already in .gitignore"
    else
        echo "   Adding PostgreSQL data to .gitignore..."
        cat >> "$GITIGNORE" << 'EOF'

# PostgreSQL data files (permission conflicts)
database/data/postgresql/
database/data/*.log
database/data/run/
EOF
        echo "   ✓ Updated .gitignore"
    fi
    
    echo ""
    echo "2. Removing PostgreSQL data from Git index..."
    cd "$SCRIPT_DIR/.."
    
    # Remove from git index (but keep files)
    git rm -r --cached database/data/postgresql/ 2>/dev/null || true
    git rm --cached database/data/*.log 2>/dev/null || true
    git rm -r --cached database/data/run/ 2>/dev/null || true
    
    echo "   ✓ Removed from Git tracking"
    echo ""
    
    echo "3. Creating README for database data..."
    cat > "$DATA_DIR/../README.md" << 'EOF'
# Database Data Directory

This directory contains PostgreSQL data files that are:
- Created with restrictive permissions (0600) for security
- Excluded from Git due to permission conflicts
- Specific to your local environment

## Setup
To initialize the database:
```bash
./manage_database.sh setup
```

## Important
- Do NOT commit PostgreSQL data files
- Do NOT change permissions to 777 (PostgreSQL will refuse to start)
- Use manage_database.sh for all database operations
EOF
    echo "   ✓ Created data directory README"
    echo ""
}

# Function to show current git status
show_git_status() {
    echo -e "${BLUE}=== Git Status ===${NC}"
    
    cd "$SCRIPT_DIR/.."
    
    # Count permission denied errors
    ERRORS=$(git status 2>&1 | grep -c "Permission denied" || true)
    
    if [ "$ERRORS" -eq 0 ]; then
        echo -e "${GREEN}✓ No permission errors in git status${NC}"
    else
        echo -e "${YELLOW}⚠ $ERRORS permission errors detected${NC}"
        echo "These will be resolved after implementing the fix."
    fi
    
    echo ""
}

# Main execution
main() {
    check_postgres_processes
    diagnose_permissions
    explain_issue
    provide_solutions
    
    echo ""
    read -p "Do you want to implement the recommended fix? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        implement_fix
        show_git_status
        
        echo -e "${GREEN}=== Fix Complete ===${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Commit the updated .gitignore:"
        echo "   git add .gitignore"
        echo "   git commit -m 'fix: Exclude PostgreSQL data files from Git'"
        echo ""
        echo "2. The permission errors should now be resolved."
        echo "3. PostgreSQL data will remain local and not be tracked by Git."
    else
        echo ""
        echo "Fix not applied. You can run this script again later."
    fi
}

# Run main function
main