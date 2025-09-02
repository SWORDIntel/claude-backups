# Learning Data Export Summary

**Date**: Tue Sep  2 08:53:04 PM BST 2025  
**Export Location**: /home/john/claude-backups/database/sql/exports

## Exported Files

### SQL Dumps (Full Database Backups)


### CSV Exports (For Analysis)
- /home/john/claude-backups/database/sql/exports/csv/agent_metrics.csv (0)
- /home/john/claude-backups/database/sql/exports/csv/interaction_logs.csv (0)
- /home/john/claude-backups/database/sql/exports/csv/learning_feedback.csv (0)
- /home/john/claude-backups/database/sql/exports/csv/model_performance.csv (0)
- /home/john/claude-backups/database/sql/exports/csv/task_embeddings.csv (0)

## How to Restore

### To Docker PostgreSQL
```bash
cd database/sql/exports
./import_learning_data.sh
```

### To Local PostgreSQL
```bash
psql -h localhost -p 5433 -U $USER -d claude_learning < claude_learning_20250902.sql
```

## Git Tracking

The SQL exports are tracked in Git for portability.
Binary database files are excluded to keep repository size manageable.

To commit the latest export:
```bash
git add database/sql/exports/*.sql
git commit -m "backup: Learning data snapshot 20250902"
```
