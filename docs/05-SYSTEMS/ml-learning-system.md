# ML Learning System v3.1 Documentation

## 🧠 Overview

The ML Learning System v3.1 is an advanced machine learning powered analytics system that optimizes agent performance through pattern recognition, task similarity detection, and predictive routing. Built on PostgreSQL 16/17 with pgvector extension, it provides real-time performance monitoring and adaptive learning strategies.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ML Learning System v3.1              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Learning   │  │   Analytics  │  │  Prediction  │   │
│  │    Engine    │  │    Engine    │  │    Engine    │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
│         │                 │                 │          │
│  ┌──────┴─────────────────┴─────────────────┴──────┐  │
│  │            PostgreSQL 16/17 + pgvector           │  │
│  │         VECTOR(256) Embeddings Storage           │  │
│  └───────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ Performance │  │    Agent     │  │   Schema     │   │
│  │   Metrics   │  │   Registry   │  │  Evolution   │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Learning Engine (postgresql_learning_system.py)
- **Size**: 97,678 bytes
- **Purpose**: Core ML engine for pattern recognition
- **Features**:
  - Task similarity detection using vector embeddings
  - Agent performance tracking
  - Success/failure pattern analysis
  - Adaptive strategy development

### 2. Orchestrator Bridge (learning_orchestrator_bridge.py)
- **Size**: 57,503 bytes
- **Purpose**: Integration with Tandem Orchestration
- **Features**:
  - Real-time performance metrics
  - Agent recommendation engine
  - Workflow optimization
  - Load balancing

### 3. Setup Orchestrator (integrated_learning_setup.py)
- **Size**: 39,926 bytes (1,049 lines)
- **Purpose**: Comprehensive system setup
- **Features**:
  - Dependency management
  - Database schema creation
  - Extension installation
  - Configuration validation

### 4. Configuration Manager (learning_config_manager.py)
- **Purpose**: Advanced configuration management
- **Features**:
  - Environment setup
  - Connection pooling
  - Feature flags
  - Performance tuning

## Database Schema

### Core Tables

```sql
-- Agent performance tracking
CREATE TABLE agent_performance (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    context_embedding VECTOR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task similarity tracking
CREATE TABLE task_embeddings (
    id SERIAL PRIMARY KEY,
    task_description TEXT,
    task_embedding VECTOR(256),
    agent_used VARCHAR(100),
    performance_score FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Learning analytics
CREATE TABLE learning_analytics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100),
    metric_value JSONB,
    category VARCHAR(50),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Agent recommendations
CREATE TABLE agent_recommendations (
    id SERIAL PRIMARY KEY,
    task_pattern TEXT,
    recommended_agents JSONB,
    confidence_score FLOAT,
    usage_count INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Indexes for Performance

```sql
-- Vector similarity search
CREATE INDEX idx_task_embedding ON task_embeddings 
USING ivfflat (task_embedding vector_cosine_ops)
WITH (lists = 100);

-- Performance queries
CREATE INDEX idx_agent_performance_time ON agent_performance(created_at DESC);
CREATE INDEX idx_agent_name ON agent_performance(agent_name);
CREATE INDEX idx_success ON agent_performance(success);
```

## Installation

### Prerequisites
```bash
# PostgreSQL 16 or 17
sudo apt-get install postgresql-16 postgresql-contrib-16

# pgvector extension
sudo apt-get install postgresql-16-pgvector

# Python dependencies
pip install psycopg2-binary pandas numpy scikit-learn
```

### Quick Setup
```bash
# Run integrated setup
python3 integrated_learning_setup.py

# Or with options
python3 integrated_learning_setup.py --reset  # Reset database
python3 integrated_learning_setup.py --verbose  # Detailed output
```

### Manual Setup
```bash
# 1. Create database
sudo -u postgres createdb claude_learning

# 2. Enable extensions
sudo -u postgres psql claude_learning -c "CREATE EXTENSION IF NOT EXISTS vector;"
sudo -u postgres psql claude_learning -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# 3. Run schema
psql -U claude -d claude_learning < database/sql/learning_schema.sql

# 4. Configure environment
export CLAUDE_LEARNING_DB="postgresql://claude:password@localhost/claude_learning"
```

## Configuration

### learning_config.json
```json
{
  "enabled": true,
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "claude_learning",
    "user": "claude",
    "pool_size": 10,
    "use_pgvector": true,
    "embedding_dimension": 256
  },
  "ml": {
    "model_type": "sklearn",
    "update_frequency": "daily",
    "min_samples": 100,
    "confidence_threshold": 0.75,
    "similarity_threshold": 0.85
  },
  "monitoring": {
    "track_performance": true,
    "track_errors": true,
    "track_patterns": true,
    "retention_days": 30
  },
  "features": {
    "auto_recommendation": true,
    "adaptive_routing": true,
    "performance_prediction": true,
    "anomaly_detection": true
  }
}
```

### Environment Variables
```bash
# Database connection
export CLAUDE_LEARNING_DB_HOST="localhost"
export CLAUDE_LEARNING_DB_PORT="5432"
export CLAUDE_LEARNING_DB_NAME="claude_learning"
export CLAUDE_LEARNING_DB_USER="claude"
export CLAUDE_LEARNING_DB_PASSWORD="secure_password"

# ML settings
export CLAUDE_ML_MODEL_TYPE="sklearn"
export CLAUDE_ML_EMBEDDING_DIM="256"
export CLAUDE_ML_UPDATE_FREQ="daily"

# Features
export CLAUDE_LEARNING_ENABLED="true"
export CLAUDE_AUTO_RECOMMENDATION="true"
export CLAUDE_ADAPTIVE_ROUTING="true"
```

## Usage

### Command Line Interface
```bash
# View dashboard
python3 postgresql_learning_system.py dashboard

# Check status
python3 postgresql_learning_system.py status

# Export data
python3 postgresql_learning_system.py export --format json

# Train models
python3 postgresql_learning_system.py train

# Analyze patterns
python3 postgresql_learning_system.py analyze --days 7
```

### Python API
```python
from postgresql_learning_system import LearningSystem

# Initialize
learning = LearningSystem()

# Track performance
learning.track_performance(
    agent_name="security",
    task_type="vulnerability_scan",
    execution_time_ms=1250,
    success=True
)

# Get recommendations
recommendations = learning.get_agent_recommendations(
    task="scan for SQL injection vulnerabilities"
)
print(f"Recommended agents: {recommendations}")

# Analyze patterns
patterns = learning.analyze_patterns(days=30)
for pattern in patterns:
    print(f"Pattern: {pattern['description']}")
    print(f"Frequency: {pattern['frequency']}")
    print(f"Success rate: {pattern['success_rate']}")
```

### Integration with Orchestrator
```python
from learning_orchestrator_bridge import LearningOrchestrator

# Initialize bridge
orchestrator = LearningOrchestrator()

# Smart agent selection
best_agent = orchestrator.select_best_agent(
    task="optimize database performance"
)
print(f"Selected: {best_agent['name']} (confidence: {best_agent['confidence']})")

# Workflow optimization
optimized_workflow = orchestrator.optimize_workflow(
    steps=["design", "implement", "test", "deploy"]
)
```

## Features

### 1. Task Similarity Detection
Uses vector embeddings to find similar tasks:
```python
# Find similar tasks
similar_tasks = learning.find_similar_tasks(
    task="implement user authentication",
    threshold=0.85
)
```

### 2. Agent Performance Analytics
Track and analyze agent performance:
```python
# Get performance metrics
metrics = learning.get_agent_metrics("optimizer")
print(f"Success rate: {metrics['success_rate']}%")
print(f"Avg execution time: {metrics['avg_time']}ms")
print(f"Error rate: {metrics['error_rate']}%")
```

### 3. Predictive Routing
Predict best agent for a task:
```python
# Predict agent
prediction = learning.predict_agent(
    task="refactor legacy code"
)
print(f"Predicted agent: {prediction['agent']}")
print(f"Expected time: {prediction['expected_time']}ms")
print(f"Success probability: {prediction['success_prob']}")
```

### 4. Anomaly Detection
Detect unusual patterns:
```python
# Check for anomalies
anomalies = learning.detect_anomalies(
    window_hours=24
)
for anomaly in anomalies:
    print(f"Anomaly: {anomaly['description']}")
    print(f"Severity: {anomaly['severity']}")
```

### 5. Adaptive Learning
System learns from successes and failures:
```python
# Update learning model
learning.update_model(
    feedback_type="success",
    agent="architect",
    task="design microservices",
    context={"complexity": "high", "domain": "finance"}
)
```

## Performance Metrics

### Current Performance
- **Database Operations**: >2000 ops/sec
- **Vector Search**: <10ms for 100k embeddings
- **Model Training**: <5 seconds for 10k samples
- **Prediction Latency**: <50ms P95
- **Memory Usage**: <500MB typical

### Optimization Tips
1. **Index Management**:
   ```sql
   -- Periodic reindexing
   REINDEX INDEX idx_task_embedding;
   ```

2. **Connection Pooling**:
   ```python
   # Use connection pool
   pool = psycopg2.pool.ThreadedConnectionPool(
       minconn=2, maxconn=20
   )
   ```

3. **Batch Operations**:
   ```python
   # Batch insert for performance
   learning.batch_track_performance(performance_data)
   ```

## Dashboard

### Accessing the Dashboard
```bash
# Launch dashboard
python3 postgresql_learning_system.py dashboard

# Or via launcher
./launch_learning_system.sh dashboard
```

### Dashboard Sections
1. **System Health**: Overall system status
2. **Agent Performance**: Success rates, execution times
3. **Task Patterns**: Common task types and trends
4. **Recommendations**: Suggested optimizations
5. **Anomalies**: Detected issues and warnings

### Example Dashboard Output
```
═══════════════════════════════════════════════════════════
           ML Learning System v3.1 Dashboard
═══════════════════════════════════════════════════════════

System Status: ✓ ACTIVE (PostgreSQL 17)
Uptime: 7 days, 14 hours
Total Tasks Processed: 15,234
Active Agents: 71/71

Top Performing Agents:
1. optimizer     - 98.5% success rate (avg: 125ms)
2. architect     - 97.2% success rate (avg: 230ms)
3. security      - 96.8% success rate (avg: 450ms)

Recent Patterns Detected:
• High security scan frequency (↑ 45%)
• Optimization tasks clustered around deployment
• Documentation generation follows feature completion

Recommendations:
• Pre-cache security scan results
• Parallelize optimization tasks
• Auto-trigger docs after deployment
```

## Troubleshooting

### Common Issues

#### Database Connection Failed
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Verify connection
psql -U claude -d claude_learning -c "SELECT version();"

# Check pgvector
psql -U claude -d claude_learning -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

#### Model Training Fails
```bash
# Check data volume
psql -U claude -d claude_learning -c "SELECT COUNT(*) FROM agent_performance;"

# Minimum 100 samples needed
# Clear old data if needed
psql -U claude -d claude_learning -c "DELETE FROM agent_performance WHERE created_at < NOW() - INTERVAL '30 days';"
```

#### High Memory Usage
```bash
# Check connection pool
python3 -c "from learning_config_manager import check_connections; check_connections()"

# Reduce pool size if needed
export CLAUDE_LEARNING_POOL_SIZE=5
```

## Schema Evolution

### Migration System
The system includes automatic schema evolution:
```python
# Check current version
python3 learning_config_manager.py check-schema

# Apply migrations
python3 learning_config_manager.py migrate

# Rollback if needed
python3 learning_config_manager.py rollback --version 3.0
```

### Version History
- **v3.1**: Added drift prevention, enhanced analytics
- **v3.0**: PostgreSQL 16/17 compatibility
- **v2.0**: Added pgvector support
- **v1.0**: Initial schema

## Integration with Agents

### All 71 Agents Supported
The learning system tracks performance for all agents:
- Command & Control (2)
- Security Specialists (13)
- Core Development (8)
- Language-Specific (14)
- Infrastructure & DevOps (6)
- Specialized Platforms (7)
- Data & ML (4)
- Network & Systems (8)
- Hardware & Acceleration (2)
- Planning & Documentation (4)
- Quality & Oversight (3)

### Agent-Specific Learning
```python
# Configure agent-specific parameters
learning.configure_agent(
    agent="security",
    parameters={
        "min_confidence": 0.9,
        "max_cache_time": 3600,
        "priority": "high"
    }
)
```

## Best Practices

1. **Regular Maintenance**:
   ```bash
   # Weekly vacuum
   psql -U claude -d claude_learning -c "VACUUM ANALYZE;"
   
   # Monthly reindex
   psql -U claude -d claude_learning -c "REINDEX DATABASE claude_learning;"
   ```

2. **Data Retention**:
   ```python
   # Clean old data
   learning.cleanup_old_data(days=30)
   ```

3. **Backup Strategy**:
   ```bash
   # Daily backups
   pg_dump claude_learning > backup_$(date +%Y%m%d).sql
   ```

4. **Monitoring**:
   ```python
   # Set up alerts
   learning.configure_alerts(
       email="admin@example.com",
       thresholds={
           "error_rate": 0.05,
           "latency_p95": 1000
       }
   )
   ```

## Future Enhancements

### Planned Features
- Deep learning models (PyTorch integration)
- Real-time streaming analytics
- Distributed learning across instances
- Advanced visualization dashboard
- Natural language query interface
- Automated A/B testing

### Research Areas
- Reinforcement learning for agent selection
- Graph neural networks for workflow optimization
- Causal inference for failure analysis
- Federated learning for privacy
- Quantum-inspired optimization

---
*ML Learning System v3.1 Documentation | Framework v7.0*