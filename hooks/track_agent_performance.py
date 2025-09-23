#!/usr/bin/env python3
"""
Real-time agent performance tracker
Records all agent operations to learning database via Docker
"""
import subprocess
import json
import time
import sys
import os
from datetime import datetime
from pathlib import Path

class AgentPerformanceTracker:
    def __init__(self):
        self.container_name = "claude-postgres"
        self.db_user = "claude_agent"
        self.db_name = "claude_agents_auth"
        
    def execute_sql(self, sql_query):
        """Execute SQL via Docker exec"""
        try:
            cmd = [
                "docker", "exec", self.container_name,
                "psql", "-U", self.db_user, "-d", self.db_name,
                "-t", "-c", sql_query
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if result.returncode != 0:
                print(f"SQL Error: {result.stderr}", file=sys.stderr)
                return False
            return True
        except Exception as e:
            print(f"Docker exec error: {e}", file=sys.stderr)
            return False
    
    def record_agent_execution(self, agent_name, task_type, start_time, end_time, 
                              success=True, error_message=None, metadata=None):
        """Record agent execution metrics"""
        try:
            execution_time_ms = (end_time - start_time) * 1000
            
            # Escape single quotes for SQL
            agent_name = agent_name.replace("'", "''")
            task_type = task_type.replace("'", "''")
            error_msg_sql = "NULL" if not error_message else f"'{error_message.replace(chr(39), chr(39)*2)}'"
            
            # Insert into agent_metrics table
            sql = f"""
                INSERT INTO enhanced_learning.agent_metrics
                (agent_name, task_type, execution_time_ms, success, error_message, timestamp)
                VALUES ('{agent_name}', '{task_type}', {execution_time_ms}, {str(success).lower()},
                        {error_msg_sql}, NOW())
            """
            
            return self.execute_sql(sql)
            
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
    execution_time_ms = (end_time - start_time) * 1000
    if tracker.record_agent_execution(
        agent_name, task_type, start_time, end_time, 
        success, error_msg
    ):
        print(f"✓ Recorded: {agent_name} - {task_type} ({execution_time_ms:.2f}ms)")