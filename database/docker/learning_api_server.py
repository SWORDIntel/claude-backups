#!/usr/bin/env python3
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional
import uvicorn
import sys
import os
import asyncio
import logging
from datetime import datetime
from enum import Enum

sys.path.insert(0, '/app/learning')

try:
    from postgresql_learning_system import PostgreSQLLearningSystem, TaskType, LearningMode
except ImportError as e:
    logging.warning(f"Could not import learning system: {e}")
    PostgreSQLLearningSystem = None

app = FastAPI(
    title="Claude Learning API",
    version="3.1",
    description="ML-powered agent performance analytics and optimization"
)

learning_system = None
initialization_lock = asyncio.Lock()
system_status = {
    "initialized": False,
    "ml_available": False,
    "database_connected": False,
    "last_heartbeat": None,
    "error_message": None
}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AgentPerformanceRequest(BaseModel):
    agent_id: str = Field(..., description="Agent identifier")
    task_type: str = Field(..., description="Type of task performed")
    execution_time: float = Field(..., description="Execution time in seconds")
    success: bool = Field(..., description="Whether task succeeded")
    metrics: Dict[str, Any] = Field(default_factory=dict, description="Performance metrics")
    context: Dict[str, Any] = Field(default_factory=dict, description="Task context")

class TaskRecommendationRequest(BaseModel):
    task_description: str = Field(..., description="Natural language task description")
    complexity: str = Field("medium", description="Task complexity: low, medium, high")
    constraints: Dict[str, Any] = Field(default_factory=dict, description="Task constraints")
    history: List[str] = Field(default_factory=list, description="Recent agent history")

class AgentRecommendationResponse(BaseModel):
    primary_agent: str = Field(..., description="Recommended primary agent")
    alternative_agents: List[str] = Field(..., description="Alternative agent options")
    confidence: float = Field(..., description="Confidence score 0-1")
    reasoning: str = Field(..., description="Explanation for recommendation")
    performance_estimate: Dict[str, Any] = Field(..., description="Expected performance")

class SystemHealthResponse(BaseModel):
    status: str = Field(..., description="System status")
    database_connected: bool = Field(..., description="Database connectivity")
    ml_available: bool = Field(..., description="ML models availability")
    agent_count: int = Field(..., description="Registered agent count")
    performance_metrics: Dict[str, Any] = Field(..., description="System performance")
    error_message: Optional[str] = Field(None, description="Current error if any")

@app.on_event("startup")
async def startup_event():
    global learning_system, system_status
    
    async with initialization_lock:
        try:
            if PostgreSQLLearningSystem:
                logger.info("Initializing PostgreSQL Learning System...")
                learning_system = PostgreSQLLearningSystem()
                
                await asyncio.wait_for(
                    learning_system.initialize_async(),
                    timeout=30.0
                )
                
                system_status["initialized"] = True
                system_status["ml_available"] = hasattr(learning_system, 'model') and learning_system.model is not None
                system_status["database_connected"] = learning_system.db_connection is not None
                system_status["last_heartbeat"] = datetime.now().isoformat()
                system_status["error_message"] = None
                
                logger.info(f"Learning system initialized: ML={system_status['ml_available']}, DB={system_status['database_connected']}")
            else:
                raise ImportError("Learning system module not available")
                
        except asyncio.TimeoutError:
            error_msg = "Learning system initialization timed out"
            logger.error(error_msg)
            system_status["error_message"] = error_msg
        except Exception as e:
            error_msg = f"Failed to initialize learning system: {str(e)}"
            logger.error(error_msg)
            system_status["error_message"] = error_msg

@app.on_event("shutdown")
async def shutdown_event():
    global learning_system
    
    if learning_system:
        try:
            await learning_system.cleanup()
            logger.info("Learning system cleanup completed")
        except Exception as e:
            logger.error(f"Error during cleanup: {e}")

@app.get("/health", response_model=SystemHealthResponse)
async def health():
    if not system_status["initialized"]:
        raise HTTPException(status_code=503, detail="System not initialized")
    
    agent_count = 0
    performance_metrics = {}
    
    if learning_system:
        try:
            agent_count = await learning_system.get_agent_count()
            performance_metrics = await learning_system.get_system_metrics()
        except Exception as e:
            logger.warning(f"Could not fetch metrics: {e}")
    
    return SystemHealthResponse(
        status="healthy" if system_status["initialized"] else "unhealthy",
        database_connected=system_status["database_connected"],
        ml_available=system_status["ml_available"],
        agent_count=agent_count,
        performance_metrics=performance_metrics,
        error_message=system_status["error_message"]
    )

@app.post("/agent/performance")
async def record_performance(request: AgentPerformanceRequest, background_tasks: BackgroundTasks):
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    try:
        background_tasks.add_task(
            learning_system.record_agent_performance_async,
            agent_id=request.agent_id,
            task_type=request.task_type,
            execution_time=request.execution_time,
            success=request.success,
            metrics=request.metrics,
            context=request.context
        )
        
        return JSONResponse(
            content={
                "status": "accepted",
                "agent_id": request.agent_id,
                "timestamp": datetime.now().isoformat()
            },
            status_code=202
        )
    except Exception as e:
        logger.error(f"Error recording performance: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/agent/{agent_id}/recommendations", response_model=AgentRecommendationResponse)
async def get_agent_recommendations(agent_id: str):
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    try:
        recommendations = await learning_system.get_agent_recommendations(agent_id)
        
        return AgentRecommendationResponse(
            primary_agent=recommendations.get("primary", agent_id),
            alternative_agents=recommendations.get("alternatives", []),
            confidence=recommendations.get("confidence", 0.5),
            reasoning=recommendations.get("reasoning", "Based on historical performance"),
            performance_estimate=recommendations.get("performance_estimate", {})
        )
    except Exception as e:
        logger.error(f"Error getting recommendations: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/task/recommend", response_model=AgentRecommendationResponse)
async def recommend_agent_for_task(request: TaskRecommendationRequest):
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    try:
        recommendation = await learning_system.recommend_agent_for_task(
            task_description=request.task_description,
            complexity=request.complexity,
            constraints=request.constraints,
            history=request.history
        )
        
        return AgentRecommendationResponse(
            primary_agent=recommendation["agent"],
            alternative_agents=recommendation.get("alternatives", []),
            confidence=recommendation.get("confidence", 0.7),
            reasoning=recommendation.get("reasoning", "ML-based recommendation"),
            performance_estimate=recommendation.get("estimate", {})
        )
    except Exception as e:
        logger.error(f"Error recommending agent: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/agents/performance")
async def get_all_agent_performance():
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    try:
        performance_data = await learning_system.get_all_agent_performance()
        return JSONResponse(content=performance_data)
    except Exception as e:
        logger.error(f"Error fetching performance data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/learning/mode")
async def set_learning_mode(mode: str):
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    if mode not in ["exploration", "exploitation", "balanced"]:
        raise HTTPException(status_code=400, detail="Invalid learning mode")
    
    try:
        await learning_system.set_learning_mode(LearningMode[mode.upper()])
        return JSONResponse(content={"status": "success", "mode": mode})
    except Exception as e:
        logger.error(f"Error setting learning mode: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/dashboard")
async def get_analytics_dashboard():
    if not learning_system:
        raise HTTPException(status_code=503, detail="Learning system not available")
    
    try:
        dashboard_data = await learning_system.generate_dashboard()
        return JSONResponse(content=dashboard_data)
    except Exception as e:
        logger.error(f"Error generating dashboard: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/model/retrain")
async def retrain_models(background_tasks: BackgroundTasks):
    if not learning_system or not system_status["ml_available"]:
        raise HTTPException(status_code=503, detail="ML models not available")
    
    try:
        background_tasks.add_task(learning_system.retrain_models_async)
        return JSONResponse(
            content={
                "status": "training_started",
                "timestamp": datetime.now().isoformat()
            },
            status_code=202
        )
    except Exception as e:
        logger.error(f"Error starting model retraining: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {
        "service": "Claude Learning System API",
        "version": "3.1",
        "status": "operational" if system_status["initialized"] else "initializing",
        "endpoints": [
            "/health",
            "/agent/performance",
            "/agent/{agent_id}/recommendations",
            "/task/recommend",
            "/agents/performance",
            "/learning/mode",
            "/analytics/dashboard",
            "/model/retrain"
        ]
    }

if __name__ == "__main__":
    port = int(os.environ.get("LEARNING_API_PORT", 8080))
    host = os.environ.get("LEARNING_API_HOST", "0.0.0.0")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info",
        access_log=True
    )