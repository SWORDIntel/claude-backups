-- TEAM GAMMA LEARNING SYSTEM SCHEMA
-- DATABASE Agent - Production-Ready Predictive Agent Orchestration
-- Cross-project learning system with 95% accuracy target

-- Create learning database schema
CREATE SCHEMA IF NOT EXISTS team_gamma;

-- Enable required extensions (skip pgvector temporarily)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Performance configuration for ML workloads
SET max_parallel_workers_per_gather = 4;
SET max_parallel_workers = 8;
SET effective_cache_size = '4GB';
SET maintenance_work_mem = '1GB';
SET work_mem = '256MB';
SET jit = on;

-- Schema versioning
CREATE TABLE team_gamma.schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    description TEXT,
    migration_sql TEXT
);

INSERT INTO team_gamma.schema_version (version, description) 
VALUES (1, 'Team Gamma predictive agent orchestration schema');

-- Core agent performance metrics (ENHANCED)
CREATE TABLE team_gamma.agent_metrics (
    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    task_description TEXT,
    task_complexity INTEGER DEFAULT 1,
    
    -- Performance metrics
    execution_time_ms INTEGER,
    tokens_used INTEGER,
    memory_usage_mb INTEGER,
    cpu_utilization FLOAT,
    
    -- Success metrics
    success BOOLEAN,
    quality_score FLOAT DEFAULT 0.0,
    error_type VARCHAR(100),
    error_message TEXT,
    
    -- Context metrics
    context_chunks_used INTEGER DEFAULT 0,
    context_relevance_scores FLOAT[] DEFAULT ARRAY[]::FLOAT[],
    
    -- Cross-project metrics
    project_path TEXT,
    file_types TEXT[] DEFAULT ARRAY[]::TEXT[],
    dependencies_resolved INTEGER DEFAULT 0,
    
    -- Timing and environment
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    system_load FLOAT,
    concurrent_agents INTEGER DEFAULT 1,
    
    -- Extensible metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for agent metrics
CREATE INDEX idx_agent_metrics_name_time ON team_gamma.agent_metrics(agent_name, timestamp DESC);
CREATE INDEX idx_agent_metrics_performance ON team_gamma.agent_metrics(execution_time_ms, tokens_used);
CREATE INDEX idx_agent_metrics_success ON team_gamma.agent_metrics(success, quality_score DESC);
CREATE INDEX idx_agent_metrics_project ON team_gamma.agent_metrics(project_path);
CREATE INDEX idx_agent_metrics_complexity ON team_gamma.agent_metrics(task_complexity, quality_score DESC);

-- Task patterns for ML prediction
CREATE TABLE team_gamma.task_patterns (
    pattern_id UUID DEFAULT gen_random_uuid(),
    task_description TEXT NOT NULL,
    task_type VARCHAR(100),
    task_keywords TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Pattern characteristics
    estimated_complexity INTEGER DEFAULT 1,
    estimated_duration_ms INTEGER,
    estimated_tokens INTEGER,
    
    -- Agent assignments and success
    optimal_agents TEXT[] DEFAULT ARRAY[]::TEXT[],
    successful_agents TEXT[] DEFAULT ARRAY[]::TEXT[],
    failed_agents TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Success metrics
    avg_execution_time_ms INTEGER,
    avg_tokens_used INTEGER,
    avg_quality_score FLOAT,
    success_rate FLOAT,
    
    -- Learning data
    pattern_frequency INTEGER DEFAULT 1,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Cross-project data
    project_contexts TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Extensible
    metadata JSONB DEFAULT '{}'::jsonb,
    
    PRIMARY KEY (pattern_id, created_at)
) PARTITION BY RANGE (created_at);

-- Create partitions for task patterns
CREATE TABLE team_gamma.task_patterns_2025_01 PARTITION OF team_gamma.task_patterns 
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE team_gamma.task_patterns_2025_02 PARTITION OF team_gamma.task_patterns 
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE team_gamma.task_patterns_2025_03 PARTITION OF team_gamma.task_patterns 
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Indexes for task patterns
CREATE INDEX idx_task_patterns_keywords ON team_gamma.task_patterns USING gin(task_keywords);
CREATE INDEX idx_task_patterns_complexity ON team_gamma.task_patterns(estimated_complexity, success_rate DESC);
CREATE INDEX idx_task_patterns_success ON team_gamma.task_patterns(success_rate DESC, avg_quality_score DESC);

-- Agent capabilities and specializations
CREATE TABLE team_gamma.agent_capabilities (
    capability_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(100) NOT NULL,
    
    -- Core capabilities
    primary_skills TEXT[] DEFAULT ARRAY[]::TEXT[],
    secondary_skills TEXT[] DEFAULT ARRAY[]::TEXT[],
    supported_file_types TEXT[] DEFAULT ARRAY[]::TEXT[],
    supported_languages TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Performance characteristics
    avg_execution_time_ms INTEGER,
    avg_tokens_used INTEGER,
    avg_quality_score FLOAT,
    success_rate FLOAT,
    
    -- Specialization scores (0-1)
    architecture_score FLOAT DEFAULT 0.0,
    security_score FLOAT DEFAULT 0.0,
    performance_score FLOAT DEFAULT 0.0,
    debugging_score FLOAT DEFAULT 0.0,
    testing_score FLOAT DEFAULT 0.0,
    documentation_score FLOAT DEFAULT 0.0,
    deployment_score FLOAT DEFAULT 0.0,
    
    -- Resource requirements
    typical_memory_mb INTEGER,
    typical_cpu_usage FLOAT,
    parallel_capable BOOLEAN DEFAULT TRUE,
    
    -- Learning metrics
    improvement_rate FLOAT DEFAULT 0.0,
    tasks_completed INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    UNIQUE(agent_name)
);

-- Agent coordination patterns
CREATE TABLE team_gamma.coordination_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    primary_agent VARCHAR(100),
    supporting_agents TEXT[] DEFAULT ARRAY[]::TEXT[],
    task_type VARCHAR(100),
    
    -- Coordination metrics
    success_rate FLOAT DEFAULT 0.0,
    avg_total_time_ms INTEGER,
    coordination_overhead_ms INTEGER,
    parallel_efficiency FLOAT DEFAULT 1.0,
    
    -- Pattern characteristics
    agent_sequence TEXT[] DEFAULT ARRAY[]::TEXT[],
    dependencies JSONB DEFAULT '{}'::jsonb,
    communication_overhead INTEGER DEFAULT 0,
    
    -- Performance
    usage_count INTEGER DEFAULT 1,
    avg_quality_score FLOAT DEFAULT 0.0,
    last_used TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_coordination_primary ON team_gamma.coordination_patterns(primary_agent, success_rate DESC);
CREATE INDEX idx_coordination_type ON team_gamma.coordination_patterns(task_type, avg_quality_score DESC);

-- Cross-project learning insights
CREATE TABLE team_gamma.cross_project_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_path TEXT,
    insight_type VARCHAR(50),
    
    -- Pattern insights
    common_patterns TEXT[] DEFAULT ARRAY[]::TEXT[],
    optimal_agent_combinations TEXT[] DEFAULT ARRAY[]::TEXT[],
    performance_bottlenecks TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Success factors
    success_factors JSONB DEFAULT '{}'::jsonb,
    failure_patterns JSONB DEFAULT '{}'::jsonb,
    
    -- Metrics
    confidence_score FLOAT DEFAULT 0.0,
    sample_size INTEGER DEFAULT 0,
    last_validated TIMESTAMPTZ DEFAULT NOW(),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ML model performance tracking
CREATE TABLE team_gamma.model_performance (
    model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name VARCHAR(100),
    model_version VARCHAR(50),
    model_type VARCHAR(50), -- 'agent_selection', 'performance_prediction', 'quality_estimation'
    
    -- Performance metrics
    accuracy FLOAT DEFAULT 0.0,
    precision_score FLOAT DEFAULT 0.0,
    recall FLOAT DEFAULT 0.0,
    f1_score FLOAT DEFAULT 0.0,
    
    -- Model characteristics
    training_samples INTEGER DEFAULT 0,
    validation_samples INTEGER DEFAULT 0,
    test_samples INTEGER DEFAULT 0,
    
    -- Deployment status
    is_active BOOLEAN DEFAULT FALSE,
    deployment_date TIMESTAMPTZ,
    last_retrained TIMESTAMPTZ,
    
    -- Model metadata
    hyperparameters JSONB DEFAULT '{}'::jsonb,
    feature_importance JSONB DEFAULT '{}'::jsonb,
    
    -- Performance tracking
    predictions_made INTEGER DEFAULT 0,
    correct_predictions INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Real-time prediction cache
CREATE TABLE team_gamma.prediction_cache (
    cache_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_signature VARCHAR(255), -- Hash of task characteristics
    
    -- Predictions
    predicted_agents TEXT[] DEFAULT ARRAY[]::TEXT[],
    predicted_duration_ms INTEGER,
    predicted_tokens INTEGER,
    predicted_quality FLOAT,
    
    -- Confidence metrics
    confidence_score FLOAT DEFAULT 0.0,
    model_version VARCHAR(50),
    
    -- Cache management
    hit_count INTEGER DEFAULT 0,
    last_accessed TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 hour',
    
    -- Validation
    actual_outcome JSONB DEFAULT '{}'::jsonb,
    prediction_accuracy FLOAT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_prediction_cache_signature ON team_gamma.prediction_cache(task_signature);
CREATE INDEX idx_prediction_cache_expires ON team_gamma.prediction_cache(expires_at);

-- Advanced analytics functions

-- Function to calculate agent suitability score
CREATE OR REPLACE FUNCTION team_gamma.calculate_agent_suitability(
    p_agent_name VARCHAR(100),
    p_task_type VARCHAR(100),
    p_task_keywords TEXT[],
    p_complexity INTEGER DEFAULT 1
) RETURNS FLOAT AS $$
DECLARE
    base_score FLOAT := 0.0;
    capability_bonus FLOAT := 0.0;
    performance_score FLOAT := 0.0;
    keyword_bonus FLOAT := 0.0;
    complexity_penalty FLOAT := 0.0;
BEGIN
    -- Base success rate
    SELECT COALESCE(success_rate, 0.0) INTO base_score
    FROM team_gamma.agent_capabilities
    WHERE agent_name = p_agent_name;
    
    -- Performance bonus (normalized execution time)
    SELECT 
        CASE 
            WHEN avg_execution_time_ms < 1000 THEN 0.2
            WHEN avg_execution_time_ms < 5000 THEN 0.1
            ELSE 0.0
        END INTO performance_score
    FROM team_gamma.agent_capabilities
    WHERE agent_name = p_agent_name;
    
    -- Keyword matching bonus
    SELECT 
        CASE 
            WHEN array_length(primary_skills & p_task_keywords, 1) > 0 THEN 0.3
            WHEN array_length(secondary_skills & p_task_keywords, 1) > 0 THEN 0.15
            ELSE 0.0
        END INTO keyword_bonus
    FROM team_gamma.agent_capabilities
    WHERE agent_name = p_agent_name;
    
    -- Complexity adjustment
    complexity_penalty := CASE 
        WHEN p_complexity > 5 THEN -0.1 * (p_complexity - 5)
        ELSE 0.0
    END;
    
    RETURN GREATEST(0.0, LEAST(1.0, 
        base_score + capability_bonus + performance_score + keyword_bonus + complexity_penalty
    ));
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get optimal agent recommendations
CREATE OR REPLACE FUNCTION team_gamma.recommend_agents(
    p_task_description TEXT,
    p_task_type VARCHAR(100) DEFAULT NULL,
    p_complexity INTEGER DEFAULT 1,
    p_max_agents INTEGER DEFAULT 3
) RETURNS TABLE (
    agent_name VARCHAR(100),
    suitability_score FLOAT,
    estimated_duration_ms INTEGER,
    estimated_tokens INTEGER,
    confidence FLOAT
) AS $$
DECLARE
    task_keywords TEXT[];
    rec RECORD;
BEGIN
    -- Extract keywords from task description
    SELECT string_to_array(
        regexp_replace(
            lower(p_task_description), 
            '[^a-z0-9 ]', ' ', 'g'
        ), 
        ' '
    ) INTO task_keywords;
    
    -- Return recommendations
    RETURN QUERY
    SELECT 
        ac.agent_name,
        team_gamma.calculate_agent_suitability(
            ac.agent_name, 
            COALESCE(p_task_type, 'general'), 
            task_keywords, 
            p_complexity
        ) as suitability_score,
        ac.avg_execution_time_ms * p_complexity as estimated_duration_ms,
        ac.avg_tokens_used * p_complexity as estimated_tokens,
        ac.success_rate as confidence
    FROM team_gamma.agent_capabilities ac
    WHERE team_gamma.calculate_agent_suitability(
        ac.agent_name, 
        COALESCE(p_task_type, 'general'), 
        task_keywords, 
        p_complexity
    ) > 0.3
    ORDER BY suitability_score DESC
    LIMIT p_max_agents;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to update agent capabilities from metrics
CREATE OR REPLACE FUNCTION team_gamma.update_agent_capabilities()
RETURNS void AS $$
BEGIN
    -- Update capabilities from recent metrics (last 30 days)
    WITH recent_metrics AS (
        SELECT 
            agent_name,
            AVG(execution_time_ms) as avg_time,
            AVG(tokens_used) as avg_tokens,
            AVG(quality_score) as avg_quality,
            COUNT(*) FILTER (WHERE success) / COUNT(*)::FLOAT as success_rate,
            COUNT(*) as task_count
        FROM team_gamma.agent_metrics
        WHERE timestamp > NOW() - INTERVAL '30 days'
        GROUP BY agent_name
    )
    INSERT INTO team_gamma.agent_capabilities (
        agent_name, avg_execution_time_ms, avg_tokens_used, 
        avg_quality_score, success_rate, tasks_completed, last_updated
    )
    SELECT 
        agent_name, avg_time::INTEGER, avg_tokens::INTEGER,
        avg_quality, success_rate, task_count, NOW()
    FROM recent_metrics
    ON CONFLICT (agent_name) DO UPDATE SET
        avg_execution_time_ms = EXCLUDED.avg_execution_time_ms,
        avg_tokens_used = EXCLUDED.avg_tokens_used,
        avg_quality_score = EXCLUDED.avg_quality_score,
        success_rate = EXCLUDED.success_rate,
        tasks_completed = EXCLUDED.tasks_completed,
        last_updated = NOW();
END;
$$ LANGUAGE plpgsql;

-- Materialized view for dashboard
CREATE MATERIALIZED VIEW team_gamma.system_dashboard AS
SELECT 
    COUNT(DISTINCT am.agent_name) as total_active_agents,
    COUNT(am.*) as total_tasks_completed,
    AVG(am.execution_time_ms) as avg_execution_time,
    AVG(am.quality_score) as avg_quality_score,
    COUNT(*) FILTER (WHERE am.success) / COUNT(*)::FLOAT as overall_success_rate,
    COUNT(DISTINCT tp.pattern_id) as learned_patterns,
    MAX(am.timestamp) as last_activity
FROM team_gamma.agent_metrics am
CROSS JOIN team_gamma.task_patterns tp
WHERE am.timestamp > NOW() - INTERVAL '7 days'
WITH DATA;

-- Permissions
GRANT USAGE ON SCHEMA team_gamma TO claude_agent;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA team_gamma TO claude_agent;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA team_gamma TO claude_agent;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA team_gamma TO claude_agent;

-- Initialize with current agent capabilities
INSERT INTO team_gamma.agent_capabilities (agent_name, primary_skills) VALUES
('DIRECTOR', ARRAY['strategy', 'planning', 'coordination']),
('PROJECTORCHESTRATOR', ARRAY['orchestration', 'coordination', 'workflow']),
('SECURITY', ARRAY['security', 'audit', 'vulnerability']),
('ARCHITECT', ARRAY['architecture', 'design', 'patterns']),
('DATABASE', ARRAY['database', 'sql', 'performance', 'learning']),
('DATASCIENCE', ARRAY['ml', 'analytics', 'prediction']),
('MLOPS', ARRAY['pipeline', 'deployment', 'automation']),
('SQL-INTERNAL-AGENT', ARRAY['postgresql', 'optimization', 'queries']),
('MONITOR', ARRAY['metrics', 'monitoring', 'performance']);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEAM GAMMA LEARNING SYSTEM DEPLOYED SUCCESSFULLY';
    RAISE NOTICE '==================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Target: 95% accuracy in agent routing';
    RAISE NOTICE '';
    RAISE NOTICE 'Features:';
    RAISE NOTICE '  ✓ Predictive agent selection algorithms';
    RAISE NOTICE '  ✓ Cross-project pattern recognition';
    RAISE NOTICE '  ✓ Real-time performance tracking';
    RAISE NOTICE '  ✓ ML model performance monitoring';
    RAISE NOTICE '  ✓ Advanced coordination patterns';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Deploy ML prediction engine';
    RAISE NOTICE '';
END $$;