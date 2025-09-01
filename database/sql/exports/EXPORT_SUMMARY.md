# Learning Data Export Summary

**Date**: Mon Sep  1 01:26:03 AM BST 2025  
**Export Location**: /home/john/claude-backups/database/sql/exports

## Exported Files

### SQL Dumps (Full Database Backups)


### CSV Exports (For Analysis)
- /home/john/claude-backups/database/sql/exports/csv/agent_metrics.csv (1.5K)
- /home/john/claude-backups/database/sql/exports/csv/interaction_logs.csv (75)
- /home/john/claude-backups/database/sql/exports/csv/learning_feedback.csv (61)
- /home/john/claude-backups/database/sql/exports/csv/model_performance.csv (69)
- /home/john/claude-backups/database/sql/exports/csv/task_embeddings.csv (0)

## How to Restore

### To Docker PostgreSQL
```bash
cd database/sql/exports
./import_learning_data.sh
```

### To Local PostgreSQL
```bash
psql -h localhost -p 5433 -U $USER -d claude_learning < claude_learning_20250901.sql
```

## Git Tracking

The SQL exports are tracked in Git for portability.
Binary database files are excluded to keep repository size manageable.

To commit the latest export:
```bash
git add database/sql/exports/*.sql
git commit -m "backup: Learning data snapshot 20250901"
```
