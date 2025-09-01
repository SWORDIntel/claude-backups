-- Initialize learning system schema
CREATE SCHEMA IF NOT EXISTS learning;

-- Agent performance metrics table
CREATE TABLE IF NOT EXISTS learning.agent_metrics (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    duration_ms INTEGER,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task embeddings for similarity search
CREATE TABLE IF NOT EXISTS learning.task_embeddings (
    id SERIAL PRIMARY KEY,
    task_description TEXT NOT NULL,
    embedding vector(384),  -- Using 384-dimensional vectors
    agent_name VARCHAR(100),
    success_rate FLOAT,
    avg_duration_ms INTEGER,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Agent interaction logs
CREATE TABLE IF NOT EXISTS learning.interaction_logs (
    id SERIAL PRIMARY KEY,
    source_agent VARCHAR(100),
    target_agent VARCHAR(100),
    message_type VARCHAR(50),
    payload JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Learning feedback for continuous improvement
CREATE TABLE IF NOT EXISTS learning.learning_feedback (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100),
    task_id INTEGER,
    feedback_type VARCHAR(50),
    feedback_value JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Model performance tracking
CREATE TABLE IF NOT EXISTS learning.model_performance (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100),
    version VARCHAR(50),
    accuracy FLOAT,
    precision_score FLOAT,
    recall_score FLOAT,
    f1_score FLOAT,
    training_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_metrics_agent_name ON learning.agent_metrics(agent_name);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_task_type ON learning.agent_metrics(task_type);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_created_at ON learning.agent_metrics(created_at);
CREATE INDEX IF NOT EXISTS idx_task_embeddings_agent ON learning.task_embeddings(agent_name);
CREATE INDEX IF NOT EXISTS idx_interaction_logs_timestamp ON learning.interaction_logs(timestamp);

-- Create vector similarity index for embeddings
CREATE INDEX IF NOT EXISTS idx_task_embeddings_vector ON learning.task_embeddings 
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA learning TO claude;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA learning TO claude;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA learning TO claude;