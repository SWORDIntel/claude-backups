#!/usr/bin/env python3
"""
Claude Agent Bridge API for Container Orchestration
Production-ready FastAPI service for agent communication
"""

import asyncio
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

try:
    import asyncpg
    import httpx
    import structlog
    from fastapi import Depends, FastAPI, HTTPException, status
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import JSONResponse
    from prometheus_client import Counter, Gauge, Histogram, generate_latest
    from prometheus_client.openmetrics.exposition import CONTENT_TYPE_LATEST
    from starlette.responses import Response
except ImportError as e:
    print(f"Required dependencies not installed: {e}")
    sys.exit(1)

# Configure structured logging
logging.basicConfig(level=logging.INFO)
logger = structlog.get_logger()

# Prometheus metrics
REQUEST_COUNT = Counter(
    "claude_bridge_requests_total", "Total requests", ["method", "endpoint"]
)
REQUEST_DURATION = Histogram(
    "claude_bridge_request_duration_seconds", "Request duration"
)
ACTIVE_CONNECTIONS = Gauge(
    "claude_bridge_active_connections", "Active database connections"
)
LEARNING_SYSTEM_STATUS = Gauge(
    "claude_learning_system_status", "Learning system health status"
)

# FastAPI application
app = FastAPI(
    title="Claude Agent Bridge API",
    description="Production agent communication bridge for containerized Claude Framework",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global connection pool
connection_pool: Optional[asyncpg.Pool] = None

# Configuration from environment
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://claude_agent:secure_default_2024@postgres:5432/claude_agents_auth",
)
LEARNING_SYSTEM_URL = os.getenv("LEARNING_SYSTEM_URL", "http://learning-system:8080")


async def get_db_pool():
    """Get database connection pool"""
    global connection_pool
    if connection_pool is None:
        connection_pool = await asyncpg.create_pool(
            DATABASE_URL, min_size=5, max_size=20, command_timeout=60
        )
    return connection_pool


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("Starting Claude Agent Bridge API")

    # Initialize database pool
    await get_db_pool()
    logger.info("Database connection pool initialized")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global connection_pool
    if connection_pool:
        await connection_pool.close()
    logger.info("Claude Agent Bridge API shutting down")


@app.middleware("http")
async def metrics_middleware(request, call_next):
    """Collect request metrics"""
    start_time = datetime.now(timezone.utc)
    REQUEST_COUNT.labels(method=request.method, endpoint=request.url.path).inc()

    with REQUEST_DURATION.time():
        response = await call_next(request)

    logger.info(
        "request_processed",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=(datetime.now(timezone.utc) - start_time).total_seconds() * 1000,
    )

    return response


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        pool = await get_db_pool()
        async with pool.acquire() as conn:
            result = await conn.fetchval("SELECT 1")

        # Check learning system
        async with httpx.AsyncClient() as client:
            try:
                learning_response = await client.get(
                    f"{LEARNING_SYSTEM_URL}/health", timeout=5
                )
                learning_healthy = learning_response.status_code == 200
                LEARNING_SYSTEM_STATUS.set(1 if learning_healthy else 0)
            except:
                learning_healthy = False
                LEARNING_SYSTEM_STATUS.set(0)

        ACTIVE_CONNECTIONS.set(pool.get_size())

        return JSONResponse(
            {
                "status": "healthy",
                "service": "claude-agent-bridge",
                "database": "connected" if result == 1 else "disconnected",
                "learning_system": "healthy" if learning_healthy else "unhealthy",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "version": "2.0.0",
            }
        )
    except Exception as e:
        logger.error("health_check_failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/v1/agents")
async def list_agents():
    """List available agents"""
    try:
        pool = await get_db_pool()
        async with pool.acquire() as conn:
            # Get active agent sessions or configurations
            agents = await conn.fetch(
                """
                SELECT DISTINCT 
                    'agent' as type,
                    username as name,
                    status,
                    last_login,
                    created_at
                FROM users 
                WHERE status = 'active' 
                ORDER BY last_login DESC NULLS LAST
                LIMIT 50
            """
            )

        return JSONResponse(
            {
                "agents": [dict(agent) for agent in agents],
                "count": len(agents),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )
    except Exception as e:
        logger.error("list_agents_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to list agents")


@app.post("/api/v1/agents/{agent_id}/invoke")
async def invoke_agent(agent_id: str, payload: Dict[str, Any]):
    """Invoke an agent with payload"""
    try:
        # Forward to learning system
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{LEARNING_SYSTEM_URL}/api/v1/agents/{agent_id}/invoke",
                json=payload,
                timeout=30,
            )

        if response.status_code == 200:
            return JSONResponse(response.json())
        else:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Agent invocation failed: {response.text}",
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=408, detail="Agent invocation timeout")
    except Exception as e:
        logger.error("agent_invocation_failed", agent_id=agent_id, error=str(e))
        raise HTTPException(status_code=500, detail="Agent invocation failed")


@app.get("/api/v1/agents/{agent_id}/status")
async def get_agent_status(agent_id: str):
    """Get agent status"""
    try:
        pool = await get_db_pool()
        async with pool.acquire() as conn:
            agent = await conn.fetchrow(
                """
                SELECT 
                    u.user_id,
                    u.username,
                    u.status,
                    u.last_login,
                    u.created_at,
                    s.session_id,
                    s.last_activity,
                    s.is_active as session_active
                FROM users u
                LEFT JOIN user_sessions s ON u.user_id = s.user_id AND s.is_active = true
                WHERE u.username = $1 OR u.user_id::text = $1
                ORDER BY s.last_activity DESC NULLS LAST
                LIMIT 1
            """,
                agent_id,
            )

        if not agent:
            raise HTTPException(status_code=404, detail="Agent not found")

        return JSONResponse(
            {"agent": dict(agent), "timestamp": datetime.now(timezone.utc).isoformat()}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_agent_status_failed", agent_id=agent_id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get agent status")


@app.post("/api/v1/learning/train")
async def trigger_learning():
    """Trigger learning system training"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{LEARNING_SYSTEM_URL}/api/v1/train", timeout=60
            )

        return JSONResponse(response.json())
    except Exception as e:
        logger.error("trigger_learning_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to trigger learning")


@app.get("/api/v1/learning/metrics")
async def get_learning_metrics():
    """Get learning system metrics"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{LEARNING_SYSTEM_URL}/api/v1/metrics", timeout=10
            )

        return JSONResponse(response.json())
    except Exception as e:
        logger.error("get_learning_metrics_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get learning metrics")


@app.get("/api/v1/system/status")
async def system_status():
    """Get comprehensive system status"""
    try:
        pool = await get_db_pool()

        # Database stats
        async with pool.acquire() as conn:
            db_stats = await conn.fetchrow(
                """
                SELECT 
                    (SELECT count(*) FROM users WHERE status = 'active') as active_users,
                    (SELECT count(*) FROM user_sessions WHERE is_active = true AND expires_at > NOW()) as active_sessions,
                    (SELECT count(*) FROM security_events WHERE timestamp >= NOW() - INTERVAL '1 hour') as recent_events
            """
            )

        # Learning system status
        learning_status = "unknown"
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{LEARNING_SYSTEM_URL}/health", timeout=5)
                learning_status = (
                    "healthy" if response.status_code == 200 else "unhealthy"
                )
        except:
            learning_status = "unhealthy"

        return JSONResponse(
            {
                "system": "claude-agent-framework",
                "version": "2.0.0",
                "status": "operational",
                "components": {
                    "database": {
                        "status": "connected",
                        "pool_size": pool.get_size(),
                        "active_users": db_stats["active_users"],
                        "active_sessions": db_stats["active_sessions"],
                        "recent_events": db_stats["recent_events"],
                    },
                    "learning_system": {
                        "status": learning_status,
                        "url": LEARNING_SYSTEM_URL,
                    },
                    "bridge": {"status": "healthy", "uptime_seconds": "dynamic"},
                },
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )
    except Exception as e:
        logger.error("system_status_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get system status")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8081, log_level="info", access_log=True)
