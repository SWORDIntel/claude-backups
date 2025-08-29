-- ============================================================================
-- CLAUDE AGENT LEARNING SYSTEM - PostgreSQL 17 Integration
-- ============================================================================
-- Extends existing authentication database with learning capabilities
-- Compatible with existing schema in auth_db_setup.sql
-- Performance optimized for agent orchestration learning
-- ============================================================================

-- Enable additional extensions for learning system
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Query performance analysis
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Trigram matching for text similarity

-- ============================================================================
-- AGENT TASK EXECUTION TRACKING
-- ============================================================================

-- Main table for tracking all agent task executions
CREATE TABLE IF NOT EXISTS agent_task_executions (
    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_type VARCHAR(64) NOT NULL,
    task_description TEXT,
    agents_invoked JSONB DEFAULT JSON_ARRAY(), -- PostgreSQL 17 JSON constructor
    execution_sequence JSONB DEFAULT JSON_ARRAY(), -- Order of agent invocation
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_seconds FLOAT NOT NULL CHECK (duration_seconds >= 0),
    success BOOLEAN NOT NULL,
    error_message TEXT,
    error_code VARCHAR(32),
    user_satisfaction INTEGER CHECK (user_satisfaction BETWEEN 1 AND 10),
    complexity_score FLOAT DEFAULT 1.0 CHECK (complexity_score > 0),
    resource_metrics JSONB DEFAULT JSON_OBJECT(), -- CPU, memory, etc.
    context_data JSONB DEFAULT JSON_OBJECT(), -- Additional context
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Integration with existing auth system
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    session_id UUID REFERENCES user_sessions(session_id) ON DELETE SET NULL,
    
    -- Audit fields
    created_by VARCHAR(64) DEFAULT current_user,
    
    -- Performance constraints
    CONSTRAINT execution_time_valid CHECK (end_time > start_time),
    CONSTRAINT agents_not_empty CHECK (jsonb_array_length(agents_invoked) > 0)
);

-- Optimized indexes for learning queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_type_time 
    ON agent_task_executions(task_type, start_time DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_success_time 
    ON agent_task_executions(success, start_time DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_user_time 
    ON agent_task_executions(user_id, start_time DESC) WHERE user_id IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_agents 
    ON agent_task_executions USING GIN(agents_invoked);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_duration 
    ON agent_task_executions(duration_seconds) WHERE success = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_executions_complexity 
    ON agent_task_executions(complexity_score, success);

-- ============================================================================
-- AGENT PERFORMANCE METRICS
-- ============================================================================

-- Aggregated performance metrics for individual agents
CREATE TABLE IF NOT EXISTS agent_performance_metrics (
    agent_name VARCHAR(64) PRIMARY KEY,
    total_invocations BIGINT DEFAULT 0,
    successful_invocations BIGINT DEFAULT 0,
    success_rate FLOAT GENERATED ALWAYS AS (
        CASE WHEN total_invocations > 0 
        THEN successful_invocations::FLOAT / total_invocations 
        ELSE 0 END
    ) STORED,
    avg_duration_seconds FLOAT DEFAULT 0,
    min_duration_seconds FLOAT DEFAULT 0,
    max_duration_seconds FLOAT DEFAULT 0,
    p95_duration_seconds FLOAT DEFAULT 0,
    error_patterns JSONB DEFAULT JSON_ARRAY(), -- Common error types
    best_partner_agents JSONB DEFAULT JSON_ARRAY(), -- Agents that work well together
    specialization_scores JSONB DEFAULT JSON_OBJECT(), -- Task type specializations
    resource_efficiency JSONB DEFAULT JSON_OBJECT(), -- Resource usage patterns
    last_invocation TIMESTAMP WITH TIME ZONE,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Performance tracking
    trend_7d FLOAT DEFAULT 0, -- 7-day success rate trend
    trend_30d FLOAT DEFAULT 0, -- 30-day success rate trend
    
    CONSTRAINT success_rate_valid CHECK (success_rate BETWEEN 0 AND 1),
    CONSTRAINT duration_stats_valid CHECK (
        min_duration_seconds <= avg_duration_seconds 
        AND avg_duration_seconds <= max_duration_seconds
    )
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_agent_performance_success 
    ON agent_performance_metrics(success_rate DESC, total_invocations DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_agent_performance_duration 
    ON agent_performance_metrics(avg_duration_seconds);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_agent_performance_updated 
    ON agent_performance_metrics(last_updated DESC);

-- ============================================================================
-- AGENT COMBINATION PATTERNS
-- ============================================================================

-- Tracks success patterns for agent combinations
CREATE TABLE IF NOT EXISTS agent_combination_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_combination JSONB NOT NULL, -- Sorted array of agent names
    combination_hash VARCHAR(64) GENERATED ALWAYS AS (
        encode(digest(agent_combination::text, 'sha256'), 'hex')
    ) STORED,
    task_types JSONB DEFAULT JSON_ARRAY(), -- Task types this combo works for
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    success_rate FLOAT GENERATED ALWAYS AS (
        CASE WHEN (success_count + failure_count) > 0 
        THEN success_count::FLOAT / (success_count + failure_count)
        ELSE 0 END
    ) STORED,
    avg_duration_seconds FLOAT DEFAULT 0,
    min_duration_seconds FLOAT DEFAULT 0,
    max_duration_seconds FLOAT DEFAULT 0,
    confidence_level FLOAT DEFAULT 0.0, -- Statistical confidence
    sample_size INTEGER GENERATED ALWAYS AS (success_count + failure_count) STORED,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Performance characteristics
    resource_efficiency_score FLOAT DEFAULT 0,
    parallel_execution_capable BOOLEAN DEFAULT FALSE,
    
    UNIQUE(combination_hash),
    CONSTRAINT combination_not_empty CHECK (jsonb_array_length(agent_combination) >= 2),
    CONSTRAINT success_rate_valid CHECK (success_rate BETWEEN 0 AND 1),
    CONSTRAINT confidence_valid CHECK (confidence_level BETWEEN 0 AND 1)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_combination_patterns_success 
    ON agent_combination_patterns(success_rate DESC, confidence_level DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_combination_patterns_agents 
    ON agent_combination_patterns USING GIN(agent_combination);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_combination_patterns_tasks 
    ON agent_combination_patterns USING GIN(task_types);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_combination_patterns_sample 
    ON agent_combination_patterns(sample_size DESC) WHERE sample_size >= 5;

-- ============================================================================
-- LEARNING INSIGHTS AND RECOMMENDATIONS
-- ============================================================================

-- Stores AI-generated insights from pattern analysis
CREATE TABLE IF NOT EXISTS agent_learning_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(32) NOT NULL CHECK (
        insight_type IN ('optimal_combo', 'avoid_pattern', 'performance_tip', 
                        'resource_optimization', 'specialization', 'trend_alert',
                        'anomaly_detection', 'efficiency_improvement')
    ),
    confidence_score FLOAT NOT NULL CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    title VARCHAR(256) NOT NULL,
    description TEXT NOT NULL,
    supporting_data JSONB DEFAULT JSON_OBJECT(),
    applicable_contexts JSONB DEFAULT JSON_ARRAY(), -- Task types or conditions
    impact_score FLOAT DEFAULT 0 CHECK (impact_score BETWEEN 0 AND 10),
    
    -- Validation tracking
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_validated TIMESTAMP WITH TIME ZONE,
    validation_count INTEGER DEFAULT 0,
    positive_validations INTEGER DEFAULT 0,
    validation_rate FLOAT GENERATED ALWAYS AS (
        CASE WHEN validation_count > 0 
        THEN positive_validations::FLOAT / validation_count 
        ELSE 0 END
    ) STORED,
    
    -- Lifecycle management
    is_active BOOLEAN DEFAULT TRUE,
    archived_at TIMESTAMP WITH TIME ZONE,
    archived_reason TEXT,
    
    -- Integration with existing system
    created_by_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_insights_type_confidence 
    ON agent_learning_insights(insight_type, confidence_score DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_insights_active_created 
    ON agent_learning_insights(is_active, created_at DESC) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_insights_contexts 
    ON agent_learning_insights USING GIN(applicable_contexts);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_insights_validation 
    ON agent_learning_insights(validation_rate DESC, validation_count DESC) 
    WHERE validation_count >= 3;

-- ============================================================================
-- TASK TYPE ANALYSIS AND CLASSIFICATION
-- ============================================================================

-- Analyze task types and their characteristics
CREATE TABLE IF NOT EXISTS task_type_analysis (
    task_type VARCHAR(64) PRIMARY KEY,
    total_executions BIGINT DEFAULT 0,
    success_rate FLOAT DEFAULT 0,
    avg_complexity FLOAT DEFAULT 0,
    avg_duration_seconds FLOAT DEFAULT 0,
    preferred_agents JSONB DEFAULT JSON_ARRAY(),
    optimal_combinations JSONB DEFAULT JSON_ARRAY(),
    common_failures JSONB DEFAULT JSON_ARRAY(),
    resource_requirements JSONB DEFAULT JSON_OBJECT(),
    
    -- Trend analysis
    trend_direction VARCHAR(10) CHECK (trend_direction IN ('up', 'down', 'stable', 'unknown')),
    trend_strength FLOAT DEFAULT 0,
    
    -- Classification
    difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level BETWEEN 1 AND 5),
    automation_potential FLOAT DEFAULT 0 CHECK (automation_potential BETWEEN 0 AND 1),
    
    last_analyzed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_type_success 
    ON task_type_analysis(success_rate DESC, total_executions DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_task_type_difficulty 
    ON task_type_analysis(difficulty_level, avg_duration_seconds);

-- ============================================================================
-- REAL-TIME LEARNING FUNCTIONS
-- ============================================================================

-- Function to update agent metrics efficiently
CREATE OR REPLACE FUNCTION update_agent_performance_metrics(
    p_agent_name VARCHAR(64),
    p_duration_seconds FLOAT,
    p_success BOOLEAN,
    p_task_type VARCHAR(64) DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO agent_performance_metrics (
        agent_name, 
        total_invocations, 
        successful_invocations,
        avg_duration_seconds,
        min_duration_seconds,
        max_duration_seconds,
        last_invocation
    ) VALUES (
        p_agent_name,
        1,
        CASE WHEN p_success THEN 1 ELSE 0 END,
        p_duration_seconds,
        p_duration_seconds,
        p_duration_seconds,
        NOW()
    )
    ON CONFLICT (agent_name) DO UPDATE SET
        total_invocations = agent_performance_metrics.total_invocations + 1,
        successful_invocations = agent_performance_metrics.successful_invocations + 
            CASE WHEN p_success THEN 1 ELSE 0 END,
        avg_duration_seconds = (
            agent_performance_metrics.avg_duration_seconds * agent_performance_metrics.total_invocations + p_duration_seconds
        ) / (agent_performance_metrics.total_invocations + 1),
        min_duration_seconds = LEAST(agent_performance_metrics.min_duration_seconds, p_duration_seconds),
        max_duration_seconds = GREATEST(agent_performance_metrics.max_duration_seconds, p_duration_seconds),
        last_invocation = NOW(),
        last_updated = NOW();
END;
$$;

-- Function to get optimal agent combination for a task
CREATE OR REPLACE FUNCTION get_optimal_agents(
    p_task_type VARCHAR(64),
    p_max_agents INTEGER DEFAULT 5,
    p_min_confidence FLOAT DEFAULT 0.6
)
RETURNS JSONB
LANGUAGE SQL
STABLE
AS $$
    SELECT agent_combination
    FROM agent_combination_patterns
    WHERE task_types ? p_task_type
        AND success_rate >= p_min_confidence
        AND sample_size >= 3
        AND jsonb_array_length(agent_combination) <= p_max_agents
    ORDER BY success_rate DESC, confidence_level DESC, sample_size DESC
    LIMIT 1;
$$;

-- Function to predict task success
CREATE OR REPLACE FUNCTION predict_task_success(
    p_task_type VARCHAR(64),
    p_agents JSONB,
    p_complexity FLOAT DEFAULT 1.0
)
RETURNS TABLE (
    predicted_success_rate FLOAT,
    predicted_duration FLOAT,
    confidence FLOAT,
    recommendation TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    combo_hash VARCHAR(64);
    pattern_data RECORD;
    individual_avg FLOAT;
BEGIN
    -- Create hash for agent combination
    SELECT encode(digest((SELECT jsonb_agg(value ORDER BY value) FROM jsonb_array_elements_text(p_agents))::text, 'sha256'), 'hex') 
    INTO combo_hash;
    
    -- Check for exact combination match
    SELECT success_rate, avg_duration_seconds, confidence_level, sample_size
    INTO pattern_data
    FROM agent_combination_patterns
    WHERE combination_hash = combo_hash
        AND task_types ? p_task_type;
    
    IF FOUND AND pattern_data.sample_size >= 3 THEN
        -- Use exact match data
        RETURN QUERY SELECT 
            pattern_data.success_rate,
            pattern_data.avg_duration_seconds * p_complexity,
            LEAST(0.95, pattern_data.confidence_level),
            'Based on ' || pattern_data.sample_size || ' historical executions';
        RETURN;
    END IF;
    
    -- Fallback to individual agent analysis
    SELECT AVG(success_rate), AVG(avg_duration_seconds)
    INTO predicted_success_rate, predicted_duration
    FROM agent_performance_metrics
    WHERE agent_name = ANY(SELECT jsonb_array_elements_text(p_agents));
    
    IF predicted_success_rate IS NOT NULL THEN
        RETURN QUERY SELECT 
            COALESCE(predicted_success_rate, 0.7),
            COALESCE(predicted_duration * p_complexity, 30.0),
            0.6::FLOAT,
            'Based on individual agent performance';
        RETURN;
    END IF;
    
    -- Ultimate fallback
    RETURN QUERY SELECT 
        0.7::FLOAT,
        30.0::FLOAT,
        0.3::FLOAT,
        'Fallback estimate - no historical data';
END;
$$;

-- ============================================================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================================================

-- High-performance view for learning dashboard
CREATE MATERIALIZED VIEW IF NOT EXISTS learning_dashboard_mv AS
SELECT 
    -- Overall statistics
    (SELECT COUNT(*) FROM agent_task_executions) as total_executions,
    (SELECT AVG(CASE WHEN success THEN 1.0 ELSE 0.0 END) FROM agent_task_executions) as overall_success_rate,
    (SELECT AVG(duration_seconds) FROM agent_task_executions WHERE success = true) as avg_duration,
    (SELECT COUNT(DISTINCT task_type) FROM agent_task_executions) as unique_task_types,
    (SELECT COUNT(*) FROM agent_task_executions WHERE start_time >= NOW() - INTERVAL '24 hours') as executions_24h,
    (SELECT COUNT(*) FROM agent_task_executions WHERE start_time >= NOW() - INTERVAL '7 days') as executions_7d,
    
    -- Top performing agents
    (SELECT jsonb_agg(
        jsonb_build_object('agent', agent_name, 'success_rate', success_rate, 'invocations', total_invocations)
        ORDER BY success_rate DESC
    ) FROM (
        SELECT agent_name, success_rate, total_invocations
        FROM agent_performance_metrics 
        WHERE total_invocations >= 5 
        ORDER BY success_rate DESC 
        LIMIT 10
    ) top_agents) as top_agents,
    
    -- Recent insights count
    (SELECT COUNT(*) FROM agent_learning_insights WHERE is_active = true AND created_at >= NOW() - INTERVAL '7 days') as recent_insights,
    
    -- Last refresh
    NOW() as last_refreshed;

CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_dashboard_mv_refresh 
    ON learning_dashboard_mv(last_refreshed);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC LEARNING
-- ============================================================================

-- Trigger to update metrics when new execution is recorded
CREATE OR REPLACE FUNCTION update_learning_metrics_trigger()
RETURNS TRIGGER AS $$
DECLARE
    agent_name TEXT;
BEGIN
    -- Update individual agent metrics
    FOR agent_name IN SELECT jsonb_array_elements_text(NEW.agents_invoked) LOOP
        PERFORM update_agent_performance_metrics(
            agent_name, 
            NEW.duration_seconds, 
            NEW.success,
            NEW.task_type
        );
    END LOOP;
    
    -- Update combination patterns
    IF jsonb_array_length(NEW.agents_invoked) >= 2 THEN
        INSERT INTO agent_combination_patterns (
            agent_combination,
            task_types,
            success_count,
            failure_count,
            avg_duration_seconds,
            min_duration_seconds,
            max_duration_seconds
        )
        VALUES (
            (SELECT jsonb_agg(value ORDER BY value) FROM jsonb_array_elements_text(NEW.agents_invoked)),
            jsonb_build_array(NEW.task_type),
            CASE WHEN NEW.success THEN 1 ELSE 0 END,
            CASE WHEN NEW.success THEN 0 ELSE 1 END,
            NEW.duration_seconds,
            NEW.duration_seconds,
            NEW.duration_seconds
        )
        ON CONFLICT (combination_hash) DO UPDATE SET
            success_count = agent_combination_patterns.success_count + CASE WHEN NEW.success THEN 1 ELSE 0 END,
            failure_count = agent_combination_patterns.failure_count + CASE WHEN NEW.success THEN 0 ELSE 1 END,
            task_types = CASE 
                WHEN NOT (agent_combination_patterns.task_types ? NEW.task_type)
                THEN agent_combination_patterns.task_types || jsonb_build_array(NEW.task_type)
                ELSE agent_combination_patterns.task_types
            END,
            avg_duration_seconds = (
                agent_combination_patterns.avg_duration_seconds * 
                (agent_combination_patterns.success_count + agent_combination_patterns.failure_count) + 
                NEW.duration_seconds
            ) / (agent_combination_patterns.success_count + agent_combination_patterns.failure_count + 1),
            min_duration_seconds = LEAST(agent_combination_patterns.min_duration_seconds, NEW.duration_seconds),
            max_duration_seconds = GREATEST(agent_combination_patterns.max_duration_seconds, NEW.duration_seconds),
            last_seen = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger
DROP TRIGGER IF EXISTS learning_metrics_update_trigger ON agent_task_executions;
CREATE TRIGGER learning_metrics_update_trigger
    AFTER INSERT ON agent_task_executions
    FOR EACH ROW EXECUTE FUNCTION update_learning_metrics_trigger();

-- Function to refresh learning materialized view
CREATE OR REPLACE FUNCTION refresh_learning_dashboard()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY learning_dashboard_mv;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SAMPLE DATA AND PERFORMANCE VALIDATION
-- ============================================================================

-- Insert sample data for testing (optional - remove in production)
DO $$
BEGIN
    -- Only insert if no data exists
    IF (SELECT COUNT(*) FROM agent_task_executions) = 0 THEN
        -- Sample task execution
        INSERT INTO agent_task_executions (
            task_type, task_description, agents_invoked, execution_sequence,
            start_time, end_time, duration_seconds, success, complexity_score
        ) VALUES (
            'web_development',
            'Create responsive login page with authentication',
            '["WEB", "APIDESIGNER", "SECURITY", "TESTBED"]',
            '["WEB", "APIDESIGNER", "SECURITY", "TESTBED"]',
            NOW() - INTERVAL '2 minutes',
            NOW() - INTERVAL '30 seconds',
            90.5,
            true,
            2.5
        );
        
        RAISE NOTICE 'Sample learning data inserted for testing';
    END IF;
END $$;

-- Refresh materialized view
SELECT refresh_learning_dashboard();

-- ============================================================================
-- PERFORMANCE MONITORING AND CLEANUP
-- ============================================================================

-- Function to cleanup old learning data
CREATE OR REPLACE FUNCTION cleanup_learning_data()
RETURNS TABLE (
    cleaned_executions INTEGER,
    cleaned_insights INTEGER,
    cleaned_patterns INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    exec_count INTEGER;
    insight_count INTEGER;
    pattern_count INTEGER;
BEGIN
    -- Clean old executions (keep 6 months)
    WITH deleted AS (
        DELETE FROM agent_task_executions 
        WHERE start_time < NOW() - INTERVAL '6 months'
        RETURNING execution_id
    )
    SELECT COUNT(*) INTO exec_count FROM deleted;
    
    -- Archive old insights (keep active ones)
    WITH updated AS (
        UPDATE agent_learning_insights 
        SET is_active = false, archived_at = NOW(), archived_reason = 'auto_cleanup'
        WHERE created_at < NOW() - INTERVAL '3 months' 
            AND validation_rate < 0.3
            AND is_active = true
        RETURNING insight_id
    )
    SELECT COUNT(*) INTO insight_count FROM updated;
    
    -- Clean unused patterns (very low confidence)
    WITH deleted AS (
        DELETE FROM agent_combination_patterns
        WHERE last_seen < NOW() - INTERVAL '6 months'
            AND sample_size < 3
            AND success_rate < 0.3
        RETURNING pattern_id
    )
    SELECT COUNT(*) INTO pattern_count FROM deleted;
    
    -- Refresh materialized view
    PERFORM refresh_learning_dashboard();
    
    RETURN QUERY SELECT exec_count, insight_count, pattern_count;
END;
$$;

-- ============================================================================
-- FINAL STATUS AND PERFORMANCE CHECK
-- ============================================================================

-- Performance check view
CREATE OR REPLACE VIEW learning_system_status AS
SELECT 
    'Learning System Status' as component,
    (SELECT COUNT(*) FROM agent_task_executions) as total_executions,
    (SELECT COUNT(*) FROM agent_performance_metrics) as tracked_agents,
    (SELECT COUNT(*) FROM agent_combination_patterns WHERE sample_size >= 5) as validated_patterns,
    (SELECT COUNT(*) FROM agent_learning_insights WHERE is_active = true) as active_insights,
    pg_size_pretty(pg_total_relation_size('agent_task_executions')) as executions_table_size,
    pg_size_pretty(pg_database_size(current_database())) as total_database_size,
    'PostgreSQL 17 Compatible' as compatibility,
    'Ready for Production Learning' as status;

COMMIT;

-- Show final status
SELECT * FROM learning_system_status;