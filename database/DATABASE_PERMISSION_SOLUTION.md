# PostgreSQL Database Permission Solution

## Current Issue

The PostgreSQL data directory has incorrect ownership:
- **Directory**: `database/data/postgresql/`
- **Current Owner**: `dnsmasq` (incorrect)
- **Expected Owner**: `john` (your user)
- **Problem**: This prevents both Git tracking and normal database operations

## Why This Happened

1. The database was likely initialized with incorrect user context
2. The `dnsmasq` user ownership suggests a system service conflict
3. PostgreSQL creates files with restrictive permissions (0600/0700) for security

## Solutions

### Solution 1: Fix Ownership and Track in Git (RECOMMENDED)

This preserves any existing data and enables Git tracking.

```bash
# Step 1: Take ownership (requires sudo)
sudo chown -R john:john database/data/postgresql/

# Step 2: Check if there's any data
ls -la database/data/postgresql/

# Step 3: If empty, initialize fresh database
./database/manage_database.sh setup

# Step 4: Configure selective Git tracking
```

### Solution 2: Use SQL Exports for Portability

Instead of tracking binary database files, track SQL exports:

```bash
# Create export script
cat > database/export_learning_data.sh << 'EOF'
#!/bin/bash
# Export learning data to SQL for Git tracking

PG_PORT=5433
EXPORT_DIR="database/sql/exports"
mkdir -p "$EXPORT_DIR"

# Export databases if running
if pg_isready -h localhost -p $PG_PORT > /dev/null 2>&1; then
    pg_dump -h localhost -p $PG_PORT -U $USER -d claude_learning \
        > "$EXPORT_DIR/claude_learning_$(date +%Y%m%d).sql"
    pg_dump -h localhost -p $PG_PORT -U $USER -d claude_auth \
        > "$EXPORT_DIR/claude_auth_$(date +%Y%m%d).sql"
    echo "✓ Exported to $EXPORT_DIR"
else
    echo "Database not running"
fi
EOF

chmod +x database/export_learning_data.sh
```

### Solution 3: Initialize Fresh with Correct Permissions

Start clean with proper setup:

```bash
# Remove corrupted directory
sudo rm -rf database/data/postgresql

# Initialize fresh
./database/manage_database.sh setup

# This will create database with correct ownership
```

## Recommended Git Strategy

### .gitignore Configuration

```gitignore
# Track configuration, ignore binary data
database/data/postgresql/base/
database/data/postgresql/global/
database/data/postgresql/pg_wal/
database/data/postgresql/pg_xact/
database/data/postgresql/pg_multixact/
database/data/postgresql/pg_stat/
database/data/postgresql/pg_stat_tmp/
database/data/postgresql/*.pid
database/data/postgresql/*.opts

# Track these files
!database/data/postgresql/*.conf
!database/data/postgresql/PG_VERSION

# Track SQL exports
!database/sql/exports/*.sql
```

### What to Track vs Not Track

**TRACK** (Small, important files):
- PostgreSQL configuration files (`*.conf`)
- SQL schema definitions
- SQL data exports
- Version information
- Learning system configuration

**DON'T TRACK** (Large binary files):
- Table data files (`base/*`)
- Transaction logs (`pg_wal/*`)
- Temporary files
- Process IDs

## Learning Data Preservation

### Current Learning System Tables

The learning system uses these tables that should be preserved:

1. **agent_metrics**: Performance data for each agent
2. **task_embeddings**: Vector embeddings for task similarity
3. **learning_feedback**: User feedback and corrections
4. **model_performance**: ML model performance metrics
5. **interaction_logs**: Agent interaction history

### Export/Import Commands

```bash
# Export learning data
pg_dump -h localhost -p 5433 -U john -d claude_learning > learning_backup.sql

# Import learning data (after fresh setup)
psql -h localhost -p 5433 -U john -d claude_learning < learning_backup.sql
```

## Immediate Action Required

Run these commands to fix the current issue:

```bash
# 1. Fix ownership
sudo chown -R john:john database/data/postgresql/

# 2. Check contents
ls -la database/data/postgresql/

# 3. If empty or corrupted, reinitialize
./database/manage_database.sh setup

# 4. Start database
./database/manage_database.sh start

# 5. Verify it works
psql -h localhost -p 5433 -U john -d postgres -c "SELECT version();"
```

## Long-term Maintenance

### Daily Backup Script

```bash
#!/bin/bash
# database/backup_daily.sh

BACKUP_DIR="database/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Export databases
pg_dump -h localhost -p 5433 -U john -d claude_learning > "$BACKUP_DIR/learning.sql"
pg_dump -h localhost -p 5433 -U john -d claude_auth > "$BACKUP_DIR/auth.sql"

# Keep only last 7 days
find database/backups -type d -mtime +7 -exec rm -rf {} \;

echo "Backup complete: $BACKUP_DIR"
```

### Git Commit Strategy

```bash
# Before committing
./database/export_learning_data.sh

# Add SQL exports to Git
git add database/sql/exports/*.sql

# Commit with data snapshot
git commit -m "feat: Update learning data snapshot $(date +%Y%m%d)"
```

## Benefits of This Approach

1. **Portability**: SQL exports work across PostgreSQL versions
2. **Size Efficiency**: SQL is much smaller than binary data
3. **Reviewability**: Can see data changes in Git diffs
4. **Recovery**: Easy to restore from SQL exports
5. **Cross-platform**: SQL works on any system

## Next Steps

1. Fix ownership issue: `sudo chown -R john:john database/data/postgresql/`
2. Run `./database/fix_permissions_preserve_data.sh` to implement the solution
3. Set up regular exports with `export_learning_data.sh`
4. Commit SQL exports instead of binary files
5. Document any important learning data for preservation