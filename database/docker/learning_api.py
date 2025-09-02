#!/usr/bin/env python3
"""
Learning System API v3.1
FastAPI-based monitoring and management interface
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
import asyncio
import asyncpg
import json
import os
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Claude Learning System API", version="3.1")

# Database configuration
DATABASE_URL = os.environ.get('DATABASE_URL', 
    'postgresql://claude_agent:claude_secure_password@postgres:5432/claude_agents_auth')

class LearningStats(BaseModel):
    """Learning statistics model"""
    total_executions: int
    success_rate: float
    avg_duration_ms: float
    top_agents: List[Dict[str, Any]]
    recent_performance: List[Dict[str, Any]]

class AgentMetrics(BaseModel):
    """Agent performance metrics"""
    agent_name: str
    total_executions: int
    success_rate: float
    avg_duration_ms: float
    last_execution: Optional[datetime]

@app.on_event("startup")
async def startup_event():
    """Initialize database connection pool"""
    global db_pool
    try:
        app.db_pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=5,
            max_size=20
        )
        logger.info("Database connection pool initialized")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Close database connections"""
    if hasattr(app, 'db_pool'):
        await app.db_pool.close()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        async with app.db_pool.acquire() as conn:
            await conn.execute("SELECT 1")
        return {"status": "healthy", "timestamp": datetime.utcnow()}
    except:
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "timestamp": datetime.utcnow()}
        )

@app.get("/stats", response_model=LearningStats)
async def get_learning_stats():
    """Get comprehensive learning statistics"""
    try:
        async with app.db_pool.acquire() as conn:
            # Total executions
            total_executions = await conn.fetchval(
                "SELECT COUNT(*) FROM learning.agent_metrics"
            )
            
            # Success rate
            success_rate = await conn.fetchval("""
                SELECT COALESCE(AVG(success_score), 0) * 100 
                FROM learning.agent_metrics 
                WHERE status != 'started'
            """) or 0
            
            # Average duration
            avg_duration = await conn.fetchval("""
                SELECT COALESCE(AVG(duration_ms), 0) 
                FROM learning.agent_metrics 
                WHERE duration_ms IS NOT NULL
            """) or 0
            
            # Top performing agents
            top_agents = await conn.fetch("""
                SELECT agent_name, 
                       COUNT(*) as executions,
                       AVG(success_score) * 100 as success_rate,
                       AVG(duration_ms) as avg_duration
                FROM learning.agent_metrics 
                WHERE status != 'started'
                GROUP BY agent_name 
                ORDER BY success_rate DESC, executions DESC 
                LIMIT 10
            """)
            
            # Recent performance (last 24 hours)
            recent_performance = await conn.fetch("""
                SELECT DATE_TRUNC('hour', execution_start) as hour,
                       COUNT(*) as executions,
                       AVG(success_score) * 100 as success_rate
                FROM learning.agent_metrics 
                WHERE execution_start >= NOW() - INTERVAL '24 hours'
                  AND status != 'started'
                GROUP BY hour 
                ORDER BY hour DESC 
                LIMIT 24
            """)
            
            return LearningStats(
                total_executions=total_executions,
                success_rate=float(success_rate),
                avg_duration_ms=float(avg_duration),
                top_agents=[dict(row) for row in top_agents],
                recent_performance=[dict(row) for row in recent_performance]
            )
            
    except Exception as e:
        logger.error(f"Failed to get learning stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/agents", response_model=List[AgentMetrics])
async def get_agent_metrics():
    """Get metrics for all agents"""
    try:
        async with app.db_pool.acquire() as conn:
            agents = await conn.fetch("""
                SELECT agent_name,
                       COUNT(*) as total_executions,
                       AVG(success_score) * 100 as success_rate,
                       AVG(duration_ms) as avg_duration_ms,
                       MAX(execution_start) as last_execution
                FROM learning.agent_metrics
                WHERE status != 'started'
                GROUP BY agent_name
                ORDER BY total_executions DESC
            """)
            
            return [AgentMetrics(**dict(row)) for row in agents]
            
    except Exception as e:
        logger.error(f"Failed to get agent metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/agents/{agent_name}/performance")
async def get_agent_performance(agent_name: str):
    """Get detailed performance data for specific agent"""
    try:
        async with app.db_pool.acquire() as conn:
            performance = await conn.fetch("""
                SELECT execution_start,
                       duration_ms,
                       success_score,
                       status,
                       execution_context
                FROM learning.agent_metrics
                WHERE agent_name = $1
                  AND execution_start >= NOW() - INTERVAL '7 days'
                ORDER BY execution_start DESC
                LIMIT 100
            """, agent_name)
            
            if not performance:
                raise HTTPException(status_code=404, detail="Agent not found")
                
            return [dict(row) for row in performance]
            
    except Exception as e:
        logger.error(f"Failed to get agent performance: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/optimize/{agent_name}")
async def optimize_agent(agent_name: str, background_tasks: BackgroundTasks):
    """Trigger ML optimization for specific agent"""
    background_tasks.add_task(run_agent_optimization, agent_name)
    return {"message": f"Optimization started for agent {agent_name}"}

async def run_agent_optimization(agent_name: str):
    """Background task for agent optimization"""
    try:
        # Import and run the learning system optimizer
        import sys
        sys.path.append('/app/agents/src/python')
        
        from postgresql_learning_system import AgentLearningSystem
        
        learning_system = AgentLearningSystem()
        await learning_system.initialize()
        
        # Run optimization
        recommendations = await learning_system.optimize_agent_performance(agent_name)
        logger.info(f"Optimization completed for {agent_name}: {recommendations}")
        
    except Exception as e:
        logger.error(f"Agent optimization failed for {agent_name}: {e}")

@app.get("/export/data")
async def export_learning_data():
    """Export learning data for backup/analysis"""
    try:
        async with app.db_pool.acquire() as conn:
            # Export last 30 days of data
            data = await conn.fetch("""
                SELECT * FROM learning.agent_metrics 
                WHERE execution_start >= NOW() - INTERVAL '30 days'
                ORDER BY execution_start DESC
            """)
            
            exported_data = {
                "export_timestamp": datetime.utcnow().isoformat(),
                "record_count": len(data),
                "data": [dict(row) for row in data]
            }
            
            return exported_data
            
    except Exception as e:
        logger.error(f"Failed to export data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dashboard")
async def get_dashboard_data():
    """Get comprehensive dashboard data"""
    try:
        stats = await get_learning_stats()
        agents = await get_agent_metrics()
        
        return {
            "stats": stats,
            "agents": agents[:10],  # Top 10 agents
            "system_status": "operational",
            "last_updated": datetime.utcnow()
        }
        
    except Exception as e:
        logger.error(f"Failed to get dashboard data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)