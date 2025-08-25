#!/bin/bash

# PostgreSQL Health Check Script
pg_isready -U claude_agent -d claude_agents_auth

if [ $? -eq 0 ]; then
    echo "PostgreSQL is healthy"
    exit 0
else
    echo "PostgreSQL health check failed"
    exit 1
fi