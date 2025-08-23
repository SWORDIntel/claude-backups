#!/bin/bash
export POSTGRES_PORT=5433
export POSTGRES_DB=claude_auth
export POSTGRES_USER=claude_auth
export POSTGRES_PASSWORD=claude_auth_pass

echo "Learning System Status"
echo "====================="
python3 "/home/ubuntu/Documents/Claude/agents/src/python/learning_cli.py" status
