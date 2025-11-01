-- Claude Enhanced Learning System Database Schema
-- PostgreSQL 16+ with pgvector extension

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enhanced learning schema
CREATE SCHEMA IF NOT EXISTS enhanced_learning;

-- Agent performance metrics table
CREATE TABLE IF NOT EXISTS enhanced_learning.agent_metrics (
    id BIGSERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    execution_time_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    task_embedding VECTOR(512),
    context_size INTEGER,
    tokens_used INTEGER
);

-- Learning analytics table
CREATE TABLE IF NOT EXISTS enhanced_learning.learning_analytics (
    id BIGSERIAL PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(10,4),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_metrics_name_time ON enhanced_learning.agent_metrics(agent_name, timestamp);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_embedding ON enhanced_learning.agent_metrics USING ivfflat (task_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_learning_analytics_category ON enhanced_learning.learning_analytics(category, timestamp);

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA enhanced_learning TO claude_agent;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA enhanced_learning TO claude_agent;
