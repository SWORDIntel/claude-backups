#!/usr/bin/env python3
"""
Health check endpoint for Claude Learning System
"""

import os
import sys
import asyncio
import logging
from typing import Dict, Any

try:
    import asyncpg
    import psutil
except ImportError:
    print("Required dependencies not installed")
    sys.exit(1)

async def check_database_connection() -> bool:
    """Check PostgreSQL database connection"""
    try:
        database_url = os.getenv('DATABASE_URL', 'postgresql://claude_agent:secure_default_2024@postgres:5432/claude_agents_auth')
        
        conn = await asyncpg.connect(database_url)
        result = await conn.fetchval('SELECT 1')
        await conn.close()
        
        return result == 1
    except Exception as e:
        logging.error(f"Database health check failed: {e}")
        return False

async def check_system_resources() -> Dict[str, Any]:
    """Check system resource usage"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "memory_available_gb": round(memory.available / (1024**3), 2),
            "disk_percent": disk.percent,
            "disk_free_gb": round(disk.free / (1024**3), 2)
        }
    except Exception as e:
        logging.error(f"System resource check failed: {e}")
        return {}

async def main():
    """Main health check function"""
    # Check database connection
    db_healthy = await check_database_connection()
    
    # Check system resources
    resources = await check_system_resources()
    
    # Determine overall health
    healthy = db_healthy and resources.get('memory_percent', 100) < 90
    
    health_data = {
        "status": "healthy" if healthy else "unhealthy",
        "database": "connected" if db_healthy else "disconnected",
        "resources": resources,
        "service": "claude-learning-system"
    }
    
    if healthy:
        print(f"Health check passed: {health_data}")
        sys.exit(0)
    else:
        print(f"Health check failed: {health_data}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())