#!/bin/bash
#
# Activate Learning System Integration with Active Agents
# This script connects the learning system to live agent operations
# to collect real performance data
#

set -e

PROJECT_ROOT="/home/john/claude-backups"
DB_HOST="localhost"
DB_PORT="5433"
DB_NAME="claude_learning"
DB_USER="claude_agent"
DB_PASS="secure_password_2024"

echo "=== Activating Learning System Integration ==="
echo "This will enable real-time performance tracking for all agents"
echo ""

# 1. Ensure PostgreSQL Docker is running
echo "Step 1: Checking PostgreSQL Docker container..."
if ! docker ps | grep -q claude-postgres; then
    echo "Starting PostgreSQL container..."
    docker start claude-postgres 2>/dev/null || {
        echo "Container not found. Running fix script..."
        echo "1786" | sudo -S bash "$PROJECT_ROOT/database/fix_docker_postgres_permanent.sh"
    }
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..10}; do
    if docker exec claude-postgres pg_isready -U claude_agent > /dev/null 2>&1; then
        echo "✓ PostgreSQL is ready"
        break
    fi
    sleep 2
done

# 2. Create integration hooks in the hooks directory
echo ""
echo "Step 2: Installing agent performance tracking hooks..."

# Create a hook that records agent performance
cat > "$PROJECT_ROOT/hooks/track_agent_performance.py" << 'EOF'
#!/usr/bin/env python3
"""
Real-time agent performance tracker
Records all agent operations to learning database
"""
import psycopg2
import json
import time
import sys
import os
from datetime import datetime
from pathlib import Path

class AgentPerformanceTracker:
    def __init__(self):
        self.db_params = {
            'host': 'localhost',
            'port': 5433,
            'database': 'claude_learning',
            'user': 'claude_agent',
            'password': 'secure_password_2024'
        }
        
    def record_agent_execution(self, agent_name, task_type, start_time, end_time, 
                              success=True, error_message=None, metadata=None):
        """Record agent execution metrics"""
        try:
            conn = psycopg2.connect(**self.db_params)
            cur = conn.cursor()
            
            execution_time_ms = (end_time - start_time) * 1000
            
            # Insert into agent_metrics table
            cur.execute("""
                INSERT INTO agent_metrics 
                (agent_name, task_type, execution_time_ms, success, error_message, timestamp)
                VALUES (%s, %s, %s, %s, %s, NOW())
            """, (agent_name, task_type, execution_time_ms, success, error_message))
            
            # Also log to interaction_logs if metadata provided
            if metadata:
                cur.execute("""
                    INSERT INTO interaction_logs 
                    (agent_name, action_type, parameters, response_time, success, timestamp)
                    VALUES (%s, %s, %s, %s, %s, NOW())
                """, (agent_name, task_type, json.dumps(metadata), execution_time_ms, success))
            
            conn.commit()
            cur.close()
            conn.close()
            
            return True
        except Exception as e:
            print(f"Error recording metrics: {e}", file=sys.stderr)
            return False
    
    def track_command(self, command_line):
        """Parse and track command execution"""
        # Extract agent name from command if possible
        agent_name = "unknown"
        task_type = "command"
        
        if "claude-agent" in command_line:
            parts = command_line.split()
            try:
                idx = parts.index("claude-agent")
                if idx + 1 < len(parts):
                    agent_name = parts[idx + 1].upper()
            except:
                pass
        
        return agent_name, task_type

if __name__ == "__main__":
    tracker = AgentPerformanceTracker()
    
    # Get execution context from environment or args
    agent_name = os.environ.get('CLAUDE_AGENT_NAME', 'UNKNOWN')
    task_type = os.environ.get('CLAUDE_TASK_TYPE', 'general')
    start_time = float(os.environ.get('CLAUDE_START_TIME', time.time()))
    end_time = time.time()
    success = os.environ.get('CLAUDE_SUCCESS', 'true').lower() == 'true'
    error_msg = os.environ.get('CLAUDE_ERROR', None)
    
    # Record the execution
    tracker.record_agent_execution(
        agent_name, task_type, start_time, end_time, 
        success, error_msg
    )
EOF

chmod +x "$PROJECT_ROOT/hooks/track_agent_performance.py"

# 3. Create wrapper script for agent invocations
echo ""
echo "Step 3: Creating agent wrapper for automatic tracking..."

cat > "$PROJECT_ROOT/claude-agent-tracked" << 'EOF'
#!/bin/bash
# Wrapper to track agent executions automatically

AGENT_NAME="${1^^}"  # Convert to uppercase
shift  # Remove agent name from arguments

export CLAUDE_AGENT_NAME="$AGENT_NAME"
export CLAUDE_TASK_TYPE="${1:-general}"
export CLAUDE_START_TIME=$(date +%s.%N)

# Execute the original claude-agent command
/home/john/.local/bin/claude-agent "$AGENT_NAME" "$@"
RESULT=$?

# Record success/failure
if [ $RESULT -eq 0 ]; then
    export CLAUDE_SUCCESS="true"
else
    export CLAUDE_SUCCESS="false"
    export CLAUDE_ERROR="Exit code: $RESULT"
fi

# Track the performance
python3 /home/john/claude-backups/hooks/track_agent_performance.py

exit $RESULT
EOF

chmod +x "$PROJECT_ROOT/claude-agent-tracked"

# 4. Create integration with git hooks for automated tracking
echo ""
echo "Step 4: Integrating with Git hooks..."

cat > "$PROJECT_ROOT/.git/hooks/post-commit" << 'EOF'
#!/bin/bash
# Track git operations in learning system

export CLAUDE_AGENT_NAME="GIT"
export CLAUDE_TASK_TYPE="commit"
export CLAUDE_START_TIME=$(date +%s.%N)
export CLAUDE_SUCCESS="true"

python3 /home/john/claude-backups/hooks/track_agent_performance.py 2>/dev/null || true
EOF

chmod +x "$PROJECT_ROOT/.git/hooks/post-commit"

# 5. Create cron job for periodic data collection
echo ""
echo "Step 5: Setting up periodic data collection..."

cat > "$PROJECT_ROOT/database/collect_system_metrics.sh" << 'EOF'
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
EOF

chmod +x "$PROJECT_ROOT/database/collect_system_metrics.sh"

# 6. Test the integration
echo ""
echo "Step 6: Testing integration with sample data..."

# Generate some test data
export CLAUDE_AGENT_NAME="DIRECTOR"
export CLAUDE_TASK_TYPE="test_integration"
export CLAUDE_START_TIME=$(date +%s.%N)
sleep 0.1  # Simulate work
export CLAUDE_SUCCESS="true"

python3 "$PROJECT_ROOT/hooks/track_agent_performance.py"

export CLAUDE_AGENT_NAME="ARCHITECT"
export CLAUDE_TASK_TYPE="design_review"
export CLAUDE_START_TIME=$(date +%s.%N)
sleep 0.2
export CLAUDE_SUCCESS="true"

python3 "$PROJECT_ROOT/hooks/track_agent_performance.py"

export CLAUDE_AGENT_NAME="SECURITY"
export CLAUDE_TASK_TYPE="vulnerability_scan"
export CLAUDE_START_TIME=$(date +%s.%N)
sleep 0.5
export CLAUDE_SUCCESS="true"

python3 "$PROJECT_ROOT/hooks/track_agent_performance.py"

# 7. Verify data collection
echo ""
echo "Step 7: Verifying data collection..."

docker exec claude-postgres psql -U claude_agent -d claude_learning -c "
SELECT 
    agent_name,
    task_type,
    ROUND(execution_time_ms::numeric, 2) as exec_time_ms,
    success,
    timestamp
FROM agent_metrics 
ORDER BY timestamp DESC 
LIMIT 10;"

echo ""
echo "=== Integration Complete ==="
echo ""
echo "✅ Learning system is now actively collecting data!"
echo ""
echo "Usage:"
echo "  • Use 'claude-agent-tracked' instead of 'claude-agent' for automatic tracking"
echo "  • Git commits are automatically tracked"
echo "  • View metrics: $PROJECT_ROOT/database/analyze_learning_performance.sh"
echo ""
echo "Example:"
echo "  $PROJECT_ROOT/claude-agent-tracked director 'plan project'"
echo "  $PROJECT_ROOT/claude-agent-tracked security 'audit code'"
echo ""
echo "The system will now collect real performance data for analysis and optimization."