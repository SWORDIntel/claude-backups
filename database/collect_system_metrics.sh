#!/bin/bash
# Collect system performance metrics periodically

docker exec claude-postgres psql -U claude_agent -d claude_learning -c "
INSERT INTO agent_metrics (agent_name, task_type, execution_time_ms, success, timestamp)
SELECT 
    'SYSTEM' as agent_name,
    'health_check' as task_type,
    EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time())) * 1000 as execution_time_ms,
    true as success,
    NOW() as timestamp;" 2>/dev/null || true
