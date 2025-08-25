# Learning System Integration Guide

## Overview

This guide provides detailed instructions for integrating with the containerized learning system, which provides ML-powered agent performance analytics and pattern recognition for the Claude Agent Framework.

## Table of Contents
1. [Quick Integration](#quick-integration)
2. [Learning System Architecture](#learning-system-architecture)
3. [API Integration](#api-integration)
4. [Python Integration](#python-integration)
5. [Agent Performance Analytics](#agent-performance-analytics)
6. [Data Models](#data-models)
7. [Configuration](#configuration)
8. [Monitoring](#monitoring)
9. [Troubleshooting](#troubleshooting)

## Quick Integration

### 1. Verify Learning System is Running
```bash
# Check learning system health
curl http://localhost:8080/health

# Expected response:
{
  "status": "healthy",
  "service": "learning-system",
  "database": "connected",
  "agents_registered": 71,
  "timestamp": "2025-01-25T10:30:00Z"
}
```

### 2. Basic Integration Test
```bash
# Test basic API connectivity
curl http://localhost:8080/status

# View available endpoints
curl http://localhost:8080/api/docs  # If FastAPI documentation is enabled
```

### 3. Agent Registration Check
```bash
# Verify all 71 agents are registered
curl http://localhost:8080/agents/list

# Check specific agent status
curl http://localhost:8080/agents/director/status
```

## Learning System Architecture

### Components
- **PostgreSQL Database**: Data persistence with pgvector for embeddings
- **Python ML Engine**: scikit-learn, numpy for machine learning
- **Agent Registry**: Dynamic agent discovery and health monitoring
- **Performance Analytics**: Real-time metrics and pattern recognition
- **API Layer**: RESTful interface for integration

### Data Flow
```
Agent Execution → Performance Metrics → Learning System → Pattern Analysis → Insights
                                    ↓
                            PostgreSQL Storage ← Vector Embeddings
```

## API Integration

### Authentication
```python
import httpx

# Basic API client setup
class LearningSystemClient:
    def __init__(self, base_url="http://localhost:8080"):
        self.base_url = base_url
        self.client = httpx.AsyncClient()
    
    async def get_health(self):
        response = await self.client.get(f"{self.base_url}/health")
        return response.json()
```

### Core API Endpoints

#### 1. System Status
```python
async def get_system_status(client):
    response = await client.get("/status")
    return response.json()

# Example response:
{
  "learning_system": "operational",
  "database": "connected",
  "agents_registered": 71,
  "performance": {
    "queries_per_sec": 2150,
    "avg_latency_ms": 18.2,
    "success_rate": 98.7
  },
  "ml_models": {
    "pattern_recognition": "active",
    "performance_prediction": "active",
    "anomaly_detection": "active"
  }
}
```

#### 2. Agent Management
```python
# List all registered agents
async def list_agents(client):
    response = await client.get("/agents/list")
    return response.json()

# Get specific agent performance
async def get_agent_performance(client, agent_name):
    response = await client.get(f"/agents/{agent_name}/performance")
    return response.json()

# Register new agent
async def register_agent(client, agent_data):
    response = await client.post("/agents/register", json=agent_data)
    return response.json()
```

#### 3. Performance Analytics
```python
# Get overall performance metrics
async def get_performance_metrics(client):
    response = await client.get("/analytics/performance")
    return response.json()

# Get agent coordination patterns
async def get_coordination_patterns(client):
    response = await client.get("/analytics/coordination")
    return response.json()

# Get learning insights
async def get_learning_insights(client):
    response = await client.get("/analytics/insights")
    return response.json()
```

## Python Integration

### 1. Direct Database Integration
```python
import asyncpg
import asyncio

class DatabaseIntegration:
    def __init__(self):
        self.connection_string = "postgresql://claude_user:password@localhost:5433/claude_auth"
    
    async def connect(self):
        self.conn = await asyncpg.connect(self.connection_string)
        return self.conn
    
    async def get_agent_performance(self, agent_name):
        query = """
        SELECT agent_name, avg_execution_time, success_rate, last_updated
        FROM agents.performance_metrics 
        WHERE agent_name = $1
        ORDER BY last_updated DESC
        LIMIT 10
        """
        return await self.conn.fetch(query, agent_name)
    
    async def log_agent_execution(self, agent_name, task_id, execution_time, success):
        query = """
        INSERT INTO agents.execution_log (agent_name, task_id, execution_time, success, timestamp)
        VALUES ($1, $2, $3, $4, NOW())
        """
        await self.conn.execute(query, agent_name, task_id, execution_time, success)
```

### 2. Learning System Python Library
```python
# Custom learning system integration
from learning_system_client import LearningSystemClient

class AgentPerformanceTracker:
    def __init__(self):
        self.learning_client = LearningSystemClient()
    
    async def track_agent_performance(self, agent_name, task_data, result):
        """Track agent performance and send to learning system"""
        performance_data = {
            "agent_name": agent_name,
            "task_id": task_data.get("id"),
            "task_type": task_data.get("type"),
            "execution_time": result.get("execution_time"),
            "success": result.get("success", False),
            "resource_usage": result.get("resource_usage", {}),
            "timestamp": result.get("timestamp")
        }
        
        await self.learning_client.log_performance(performance_data)
    
    async def get_agent_recommendations(self, task_type):
        """Get ML-powered agent recommendations for task type"""
        return await self.learning_client.get_recommendations(task_type)
```

### 3. Container Integration
```python
# Integrate with learning system container
import docker

class ContainerIntegration:
    def __init__(self):
        self.client = docker.from_env()
        self.learning_container = "claude-learning"
    
    def execute_learning_task(self, command):
        """Execute command in learning system container"""
        container = self.client.containers.get(self.learning_container)
        result = container.exec_run(f"python3 /app/learning/{command}")
        return result.output.decode()
    
    def get_container_logs(self):
        """Get learning system container logs"""
        container = self.client.containers.get(self.learning_container)
        return container.logs(tail=100).decode()
```

## Agent Performance Analytics

### 1. Performance Metrics Collection
```python
# Automatic performance tracking
class PerformanceCollector:
    def __init__(self, learning_client):
        self.learning_client = learning_client
    
    async def collect_agent_metrics(self, agent_name):
        """Collect comprehensive agent performance metrics"""
        metrics = {
            "response_time": await self.measure_response_time(agent_name),
            "throughput": await self.measure_throughput(agent_name),
            "resource_usage": await self.get_resource_usage(agent_name),
            "success_rate": await self.calculate_success_rate(agent_name),
            "coordination_effectiveness": await self.measure_coordination(agent_name)
        }
        
        await self.learning_client.submit_metrics(agent_name, metrics)
        return metrics
```

### 2. Pattern Recognition
```python
# ML-powered pattern recognition
class PatternAnalyzer:
    def __init__(self, learning_client):
        self.learning_client = learning_client
    
    async def analyze_task_patterns(self):
        """Analyze patterns in agent task execution"""
        patterns = await self.learning_client.get_patterns()
        
        # Example patterns:
        # - Which agents work best together
        # - Optimal task scheduling patterns  
        # - Resource utilization patterns
        # - Failure prediction patterns
        
        return {
            "collaboration_patterns": patterns.get("collaboration", []),
            "performance_patterns": patterns.get("performance", []),
            "resource_patterns": patterns.get("resources", []),
            "failure_patterns": patterns.get("failures", [])
        }
```

### 3. Predictive Analytics
```python
# Predictive performance analytics
class PredictiveAnalytics:
    def __init__(self, learning_client):
        self.learning_client = learning_client
    
    async def predict_agent_performance(self, agent_name, task_type):
        """Predict agent performance for specific task type"""
        prediction = await self.learning_client.predict_performance(
            agent_name=agent_name,
            task_type=task_type
        )
        
        return {
            "predicted_execution_time": prediction.get("execution_time"),
            "predicted_success_rate": prediction.get("success_rate"),
            "confidence_score": prediction.get("confidence"),
            "recommended_resources": prediction.get("resources")
        }
```

## Data Models

### 1. Agent Performance Schema
```sql
-- Agent performance tracking table
CREATE TABLE IF NOT EXISTS agents.performance_metrics (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(255) NOT NULL,
    task_type VARCHAR(255),
    avg_execution_time FLOAT,
    success_rate FLOAT,
    resource_cpu FLOAT,
    resource_memory FLOAT,
    coordination_score FLOAT,
    last_updated TIMESTAMP DEFAULT NOW()
);

-- Agent execution log
CREATE TABLE IF NOT EXISTS agents.execution_log (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(255) NOT NULL,
    task_id UUID,
    task_type VARCHAR(255),
    execution_time FLOAT,
    success BOOLEAN,
    error_message TEXT,
    resource_usage JSONB,
    timestamp TIMESTAMP DEFAULT NOW()
);
```

### 2. Vector Embeddings Schema
```sql
-- Agent similarity vectors (using pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS agents.agent_embeddings (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(255) NOT NULL,
    task_type VARCHAR(255),
    embedding VECTOR(256),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Similarity search index
CREATE INDEX IF NOT EXISTS agent_embeddings_idx 
ON agents.agent_embeddings USING ivfflat (embedding vector_cosine_ops);
```

### 3. Learning Models Schema
```sql
-- ML model metadata
CREATE TABLE IF NOT EXISTS agents.ml_models (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(255) NOT NULL,
    model_type VARCHAR(100),
    version VARCHAR(50),
    accuracy FLOAT,
    trained_on TIMESTAMP,
    model_data BYTEA,
    hyperparameters JSONB
);
```

## Configuration

### 1. Learning System Configuration
```python
# learning_config.py
LEARNING_CONFIG = {
    "database": {
        "host": "postgres",
        "port": 5432,
        "database": "claude_auth",
        "user": "claude_user",
        "max_connections": 20
    },
    "ml": {
        "vector_size": 256,
        "similarity_threshold": 0.85,
        "learning_rate": 0.001,
        "batch_size": 32,
        "model_update_frequency": 3600  # seconds
    },
    "performance": {
        "metrics_retention_days": 90,
        "performance_tracking_interval": 60,  # seconds
        "anomaly_detection_threshold": 2.0,
        "prediction_confidence_threshold": 0.8
    },
    "agents": {
        "total_agents": 71,
        "health_check_interval": 30,  # seconds
        "performance_tracking": True,
        "pattern_recognition": True,
        "predictive_analytics": True
    }
}
```

### 2. Environment Variables
```bash
# Learning system specific configuration
LEARNING_ENV=docker
LEARNING_LOG_LEVEL=INFO
LEARNING_API_PORT=8080

# ML configuration
ML_MODEL_UPDATE_INTERVAL=3600
ML_VECTOR_SIZE=256
ML_BATCH_SIZE=32

# Performance configuration
PERFORMANCE_TRACKING_ENABLED=true
ANOMALY_DETECTION_ENABLED=true
PATTERN_RECOGNITION_ENABLED=true
```

## Monitoring

### 1. Health Monitoring
```python
# Health monitoring integration
class HealthMonitor:
    def __init__(self, learning_client):
        self.learning_client = learning_client
    
    async def monitor_learning_system_health(self):
        """Monitor learning system health continuously"""
        while True:
            try:
                health = await self.learning_client.get_health()
                
                if health["status"] != "healthy":
                    await self.alert_unhealthy_system(health)
                
                # Check database connection
                db_status = health.get("database", "unknown")
                if db_status != "connected":
                    await self.alert_database_issue(db_status)
                
                # Check model performance
                ml_status = health.get("ml_models", {})
                for model, status in ml_status.items():
                    if status != "active":
                        await self.alert_model_issue(model, status)
                
                await asyncio.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                await self.alert_system_error(str(e))
                await asyncio.sleep(60)  # Longer interval on error
```

### 2. Performance Monitoring
```python
# Performance monitoring
class PerformanceMonitor:
    def __init__(self):
        self.metrics = []
    
    async def collect_learning_system_metrics(self):
        """Collect learning system performance metrics"""
        response = await httpx.get("http://localhost:8080/metrics")
        metrics = response.json()
        
        return {
            "query_performance": metrics.get("queries_per_sec", 0),
            "prediction_accuracy": metrics.get("prediction_accuracy", 0),
            "model_training_time": metrics.get("training_time", 0),
            "agent_response_time": metrics.get("agent_response_time", 0),
            "memory_usage": metrics.get("memory_usage_mb", 0),
            "cpu_usage": metrics.get("cpu_usage_percent", 0)
        }
```

## Troubleshooting

### Common Issues

#### 1. Learning System Won't Start
```bash
# Check container status
docker-compose ps learning-system

# Check logs
docker-compose logs learning-system

# Common causes:
# - Database not ready
# - Python dependency issues
# - Configuration errors
```

#### 2. Database Connection Issues
```bash
# Test database connectivity from learning system
docker-compose exec learning-system python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(host='postgres', user='claude_user', database='claude_auth')
    print('✅ Database connection successful')
except Exception as e:
    print(f'❌ Database connection failed: {e}')
"
```

#### 3. Performance Issues
```bash
# Check learning system resource usage
docker stats claude-learning

# Monitor PostgreSQL performance
docker exec claude-postgres psql -U claude_user -d claude_auth -c "
SELECT schemaname,tablename,n_tup_ins,n_tup_upd,n_tup_del 
FROM pg_stat_user_tables 
WHERE schemaname = 'agents'
ORDER BY n_tup_ins DESC;"
```

#### 4. ML Model Issues
```python
# Test ML model functionality
async def test_ml_models():
    client = httpx.AsyncClient()
    
    # Test pattern recognition
    response = await client.get("http://localhost:8080/ml/test/patterns")
    print(f"Pattern Recognition: {response.json()}")
    
    # Test performance prediction
    response = await client.post("http://localhost:8080/ml/test/prediction", 
                                json={"agent": "director", "task": "strategic_planning"})
    print(f"Performance Prediction: {response.json()}")
```

### Recovery Procedures
```bash
# Reset learning system
docker-compose restart learning-system

# Clear learning data (if needed)
docker exec claude-postgres psql -U claude_user -d claude_auth -c "
TRUNCATE agents.performance_metrics, agents.execution_log, agents.agent_embeddings;"

# Rebuild learning system container
docker-compose build learning-system --no-cache
docker-compose up -d learning-system
```

---

*Generated by DOCGEN Agent #2 | Learning System Integration Guide | v7.0*