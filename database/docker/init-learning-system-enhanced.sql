-- Enhanced PostgreSQL Learning System Schema v2.0
-- Auto-initialized when Docker container starts

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS learning;

-- Enhanced agent_metrics table with comprehensive tracking
CREATE TABLE IF NOT EXISTS learning.agent_metrics (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    agent_uuid UUID DEFAULT uuid_generate_v4(),
    task_id UUID DEFAULT uuid_generate_v4(),
    execution_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    execution_end TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    status VARCHAR(20) NOT NULL CHECK (status IN ('started', 'completed', 'failed', 'timeout')),
    
    -- Performance metrics
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INTEGER,
    disk_io_kb INTEGER,
    network_io_kb INTEGER,
    
    -- Context information
    execution_context JSONB,
    input_size_bytes INTEGER,
    output_size_bytes INTEGER,
    coordination_depth INTEGER DEFAULT 0,
    parent_task_id UUID,
    
    -- Success tracking
    success_score DECIMAL(3,2) CHECK (success_score >= 0 AND success_score <= 1),
    error_message TEXT,
    error_type VARCHAR(50),
    retry_count INTEGER DEFAULT 0,
    
    -- Hardware context
    hardware_platform VARCHAR(100),
    cpu_cores_used INTEGER,
    parallel_execution BOOLEAN DEFAULT false,
    gpu_usage_percent DECIMAL(5,2),
    npu_usage_percent DECIMAL(5,2),
    
    -- Git operations specific
    git_operation_type VARCHAR(50),
    files_changed INTEGER,
    lines_added INTEGER,
    lines_removed INTEGER,
    conflict_detected BOOLEAN DEFAULT false,
    
    -- User context
    user_id VARCHAR(100),
    session_id UUID,
    project_path TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enhanced task_embeddings with better vector support
CREATE TABLE IF NOT EXISTS learning.task_embeddings (
    id SERIAL PRIMARY KEY,
    task_id UUID NOT NULL,
    agent_name VARCHAR(100) NOT NULL,
    task_description TEXT NOT NULL,
    embedding vector(384),
    
    -- Task classification
    task_category VARCHAR(50),
    complexity_score DECIMAL(3,2),
    estimated_duration_ms INTEGER,
    actual_duration_ms INTEGER,
    
    -- Context vectors
    input_embedding vector(256),
    output_embedding vector(256),
    
    -- Performance correlation
    success_rate DECIMAL(5,4),
    average_performance DECIMAL(8,3),
    optimization_potential DECIMAL(3,2),
    
    -- Learning metrics
    learning_iteration INTEGER DEFAULT 0,
    confidence_score DECIMAL(3,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enhanced interaction_logs for agent coordination
CREATE TABLE IF NOT EXISTS learning.interaction_logs (
    id SERIAL PRIMARY KEY,
    session_id UUID DEFAULT uuid_generate_v4(),
    source_agent VARCHAR(100) NOT NULL,
    target_agent VARCHAR(100),
    interaction_type VARCHAR(50) NOT NULL,
    
    -- Message details
    message_content TEXT,
    message_size_bytes INTEGER,
    response_content TEXT,
    response_size_bytes INTEGER,
    
    -- Timing
    request_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    response_timestamp TIMESTAMP WITH TIME ZONE,
    latency_ms INTEGER,
    
    -- Context
    coordination_pattern VARCHAR(100),
    workflow_id UUID,
    dependency_chain JSONB,
    
    -- Performance
    success BOOLEAN,
    error_details JSONB,
    retry_attempt INTEGER DEFAULT 0,
    
    -- Resource usage
    total_cpu_ms INTEGER,
    total_memory_mb INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enhanced learning_feedback with user interaction tracking
CREATE TABLE IF NOT EXISTS learning.learning_feedback (
    id SERIAL PRIMARY KEY,
    task_id UUID NOT NULL,
    agent_name VARCHAR(100) NOT NULL,
    
    -- Feedback details
    feedback_type VARCHAR(30) CHECK (feedback_type IN ('positive', 'negative', 'neutral', 'correction', 'suggestion')),
    user_rating INTEGER CHECK (user_rating >= 1 AND user_rating <= 5),
    feedback_text TEXT,
    
    -- Context
    feedback_source VARCHAR(50),
    correction_applied BOOLEAN DEFAULT false,
    improvement_suggested TEXT,
    
    -- Impact tracking
    feedback_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT false,
    impact_score DECIMAL(3,2),
    performance_before DECIMAL(5,2),
    performance_after DECIMAL(5,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enhanced model_performance with ML tracking
CREATE TABLE IF NOT EXISTS learning.model_performance (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    
    -- Performance metrics
    accuracy DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall_score DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    auc_roc DECIMAL(5,4),
    
    -- Training details
    training_start TIMESTAMP WITH TIME ZONE,
    training_end TIMESTAMP WITH TIME ZONE,
    training_samples INTEGER,
    validation_samples INTEGER,
    test_samples INTEGER,
    
    -- Model metadata
    model_type VARCHAR(50),
    hyperparameters JSONB,
    feature_importance JSONB,
    model_size_mb DECIMAL(10,2),
    
    -- Deployment tracking
    deployed BOOLEAN DEFAULT false,
    deployment_timestamp TIMESTAMP WITH TIME ZONE,
    production_performance JSONB,
    inference_latency_ms INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- New table: agent_coordination_patterns
CREATE TABLE IF NOT EXISTS learning.agent_coordination_patterns (
    id SERIAL PRIMARY KEY,
    pattern_name VARCHAR(100) NOT NULL,
    pattern_type VARCHAR(50),
    
    -- Pattern details
    agents_involved TEXT[],
    coordination_sequence JSONB,
    success_conditions JSONB,
    
    -- Performance metrics
    average_completion_time_ms INTEGER,
    success_rate DECIMAL(5,4),
    resource_efficiency DECIMAL(5,4),
    
    -- Usage tracking
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMP WITH TIME ZONE,
    effectiveness_score DECIMAL(3,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- New table: system_health_metrics
CREATE TABLE IF NOT EXISTS learning.system_health_metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Database metrics
    db_connections INTEGER,
    db_cpu_usage DECIMAL(5,2),
    db_memory_usage_mb INTEGER,
    db_disk_usage_gb DECIMAL(10,2),
    
    -- Agent ecosystem metrics
    active_agents INTEGER,
    total_tasks_running INTEGER,
    average_response_time_ms INTEGER,
    error_rate DECIMAL(5,4),
    
    -- Hardware metrics
    system_cpu_usage DECIMAL(5,2),
    system_memory_usage_gb DECIMAL(8,2),
    disk_io_rate_mbps DECIMAL(10,3),
    network_io_rate_mbps DECIMAL(10,3),
    gpu_utilization DECIMAL(5,2),
    npu_utilization DECIMAL(5,2),
    
    -- Performance indicators
    throughput_tasks_per_second DECIMAL(10,3),
    queue_depth INTEGER,
    average_wait_time_ms INTEGER,
    
    -- OpenVINO metrics
    openvino_inference_count INTEGER,
    openvino_avg_latency_ms DECIMAL(10,2)
);

-- New table: performance_baselines
CREATE TABLE IF NOT EXISTS learning.performance_baselines (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    task_category VARCHAR(50) NOT NULL,
    
    -- Baseline metrics
    baseline_duration_ms INTEGER,
    baseline_cpu_usage DECIMAL(5,2),
    baseline_memory_mb INTEGER,
    baseline_success_rate DECIMAL(5,4),
    
    -- Thresholds
    performance_threshold_ms INTEGER,
    alert_threshold_ms INTEGER,
    degradation_threshold DECIMAL(5,4),
    
    -- Statistical metrics
    stddev_duration_ms DECIMAL(10,2),
    p50_duration_ms INTEGER,
    p90_duration_ms INTEGER,
    p99_duration_ms INTEGER,
    
    -- Metadata
    baseline_established TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sample_size INTEGER,
    confidence_level DECIMAL(5,4),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(agent_name, task_category)
);

-- New table: git_operations_tracking
CREATE TABLE IF NOT EXISTS learning.git_operations_tracking (
    id SERIAL PRIMARY KEY,
    operation_id UUID DEFAULT uuid_generate_v4(),
    operation_type VARCHAR(50) NOT NULL,
    repository_path TEXT,
    branch_name VARCHAR(100),
    
    -- Operation details
    files_affected INTEGER,
    lines_changed INTEGER,
    commit_hash VARCHAR(40),
    commit_message TEXT,
    
    -- Performance metrics
    operation_duration_ms INTEGER,
    shadowgit_performance DECIMAL(12,2),
    acceleration_factor DECIMAL(5,2),
    
    -- Conflict tracking
    conflicts_detected INTEGER DEFAULT 0,
    conflicts_resolved INTEGER DEFAULT 0,
    merge_strategy VARCHAR(50),
    
    -- ML predictions
    conflict_probability DECIMAL(3,2),
    suggested_reviewers TEXT[],
    risk_score DECIMAL(3,2),
    
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Comprehensive indexing for performance
CREATE INDEX IF NOT EXISTS idx_agent_metrics_agent_time ON learning.agent_metrics(agent_name, execution_start DESC);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_status_time ON learning.agent_metrics(status, execution_start DESC);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_task_id ON learning.agent_metrics(task_id);
CREATE INDEX IF NOT EXISTS idx_agent_metrics_session ON learning.agent_metrics(session_id);

CREATE INDEX IF NOT EXISTS idx_task_embeddings_agent ON learning.task_embeddings(agent_name);
CREATE INDEX IF NOT EXISTS idx_task_embeddings_category ON learning.task_embeddings(task_category);
CREATE INDEX IF NOT EXISTS idx_task_embeddings_vector ON learning.task_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_interaction_logs_session ON learning.interaction_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_interaction_logs_agents ON learning.interaction_logs(source_agent, target_agent);
CREATE INDEX IF NOT EXISTS idx_interaction_logs_workflow ON learning.interaction_logs(workflow_id);

CREATE INDEX IF NOT EXISTS idx_learning_feedback_agent_time ON learning.learning_feedback(agent_name, feedback_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_learning_feedback_processed ON learning.learning_feedback(processed) WHERE NOT processed;

CREATE INDEX IF NOT EXISTS idx_system_health_timestamp ON learning.system_health_metrics(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_performance_baselines_agent ON learning.performance_baselines(agent_name, task_category);

CREATE INDEX IF NOT EXISTS idx_git_operations_timestamp ON learning.git_operations_tracking(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_git_operations_type ON learning.git_operations_tracking(operation_type);

-- Views for analytics
CREATE OR REPLACE VIEW learning.agent_performance_summary AS
SELECT 
    agent_name,
    COUNT(*) as total_tasks,
    AVG(duration_ms) as avg_duration_ms,
    AVG(success_score) as avg_success_rate,
    AVG(cpu_usage_percent) as avg_cpu_usage,
    AVG(memory_usage_mb) as avg_memory_usage,
    AVG(gpu_usage_percent) as avg_gpu_usage,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_tasks,
    MAX(execution_start) as last_execution
FROM learning.agent_metrics
WHERE execution_start >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY agent_name;

CREATE OR REPLACE VIEW learning.coordination_efficiency AS
SELECT 
    source_agent,
    target_agent,
    interaction_type,
    COUNT(*) as interaction_count,
    AVG(latency_ms) as avg_latency_ms,
    SUM(CASE WHEN success THEN 1 ELSE 0 END)::DECIMAL / COUNT(*) as success_rate,
    MAX(request_timestamp) as last_interaction
FROM learning.interaction_logs
WHERE request_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY source_agent, target_agent, interaction_type;

-- Functions for maintenance
CREATE OR REPLACE FUNCTION learning.update_performance_baselines()
RETURNS void AS $$
BEGIN
    INSERT INTO learning.performance_baselines (
        agent_name, task_category, baseline_duration_ms, 
        baseline_cpu_usage, baseline_memory_mb, baseline_success_rate,
        performance_threshold_ms, alert_threshold_ms, sample_size,
        stddev_duration_ms, p50_duration_ms, p90_duration_ms, p99_duration_ms
    )
    SELECT 
        agent_name,
        COALESCE(execution_context->>'category', 'general') as task_category,
        AVG(duration_ms)::INTEGER as baseline_duration,
        AVG(cpu_usage_percent) as avg_cpu,
        AVG(memory_usage_mb)::INTEGER as avg_memory,
        AVG(success_score) as avg_success,
        (AVG(duration_ms) + STDDEV(duration_ms) * 2)::INTEGER as performance_threshold,
        (AVG(duration_ms) + STDDEV(duration_ms) * 3)::INTEGER as alert_threshold,
        COUNT(*)::INTEGER as sample_count,
        STDDEV(duration_ms) as stddev_duration,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms)::INTEGER as p50,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY duration_ms)::INTEGER as p90,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)::INTEGER as p99
    FROM learning.agent_metrics
    WHERE status = 'completed' 
        AND execution_start >= CURRENT_TIMESTAMP - INTERVAL '7 days'
        AND duration_ms IS NOT NULL
    GROUP BY agent_name, COALESCE(execution_context->>'category', 'general')
    HAVING COUNT(*) >= 5
    ON CONFLICT (agent_name, task_category) 
    DO UPDATE SET
        baseline_duration_ms = EXCLUDED.baseline_duration_ms,
        baseline_cpu_usage = EXCLUDED.baseline_cpu_usage,
        baseline_memory_mb = EXCLUDED.baseline_memory_mb,
        baseline_success_rate = EXCLUDED.baseline_success_rate,
        performance_threshold_ms = EXCLUDED.performance_threshold_ms,
        alert_threshold_ms = EXCLUDED.alert_threshold_ms,
        sample_size = EXCLUDED.sample_size,
        stddev_duration_ms = EXCLUDED.stddev_duration_ms,
        p50_duration_ms = EXCLUDED.p50_duration_ms,
        p90_duration_ms = EXCLUDED.p90_duration_ms,
        p99_duration_ms = EXCLUDED.p99_duration_ms,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Trigger for timestamp updates
CREATE OR REPLACE FUNCTION learning.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_agent_metrics_modtime 
    BEFORE UPDATE ON learning.agent_metrics 
    FOR EACH ROW EXECUTE FUNCTION learning.update_modified_column();

CREATE TRIGGER update_model_performance_modtime 
    BEFORE UPDATE ON learning.model_performance 
    FOR EACH ROW EXECUTE FUNCTION learning.update_modified_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA learning TO claude_agent;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA learning TO claude_agent;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA learning TO claude_agent;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA learning TO claude_agent;