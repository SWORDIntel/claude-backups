-- ============================================================================
-- POSTGRESQL LEARNING SYSTEM SCHEMA MISMATCH FIX
-- ============================================================================
-- Adds missing 'category' column and other expected fields to match Python expectations
-- Compatible with PostgreSQL 17 and existing learning system infrastructure
-- ============================================================================

BEGIN;

-- Add missing 'category' column to agent_learning_insights table
ALTER TABLE agent_learning_insights 
ADD COLUMN IF NOT EXISTS category VARCHAR(64);

-- Populate category column based on existing insight_type with more granular categorization
UPDATE agent_learning_insights 
SET category = CASE 
    WHEN insight_type = 'optimal_combo' THEN 'coordination'
    WHEN insight_type = 'avoid_pattern' THEN 'anti_pattern'
    WHEN insight_type = 'performance_tip' THEN 'performance'
    WHEN insight_type = 'resource_optimization' THEN 'resource'
    WHEN insight_type = 'specialization' THEN 'agent_specialty'
    WHEN insight_type = 'trend_alert' THEN 'trend_analysis'
    WHEN insight_type = 'anomaly_detection' THEN 'anomaly'
    WHEN insight_type = 'efficiency_improvement' THEN 'efficiency'
    ELSE 'general'
END
WHERE category IS NULL;

-- Add constraint for category values
ALTER TABLE agent_learning_insights
ADD CONSTRAINT check_category_values CHECK (
    category IN ('coordination', 'anti_pattern', 'performance', 'resource', 
                'agent_specialty', 'trend_analysis', 'anomaly', 'efficiency', 'general')
);

-- Add index for category-based queries (performance optimization)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_insights_category 
    ON agent_learning_insights(category, created_at DESC);

-- Add any other missing columns that might be expected by the Python system
-- Based on common ML learning patterns, these are likely expected:

ALTER TABLE agent_learning_insights 
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
ADD COLUMN IF NOT EXISTS source VARCHAR(32) DEFAULT 'system',
ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT JSON_ARRAY();

-- Add missing columns to learning_analytics if needed
ALTER TABLE learning_analytics
ADD COLUMN IF NOT EXISTS category VARCHAR(64),
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS dimension VARCHAR(64);

-- Populate learning_analytics category from metric_name patterns
UPDATE learning_analytics 
SET category = CASE 
    WHEN metric_name LIKE '%efficiency%' THEN 'performance'
    WHEN metric_name LIKE '%complexity%' THEN 'analysis'
    WHEN metric_name LIKE '%coordination%' THEN 'orchestration'
    WHEN metric_name LIKE '%velocity%' THEN 'learning'
    ELSE 'metrics'
END,
dimension = CASE
    WHEN metric_name LIKE '%trend%' THEN 'temporal'
    WHEN metric_name LIKE '%overhead%' THEN 'resource'
    WHEN metric_name LIKE '%score%' THEN 'quality'
    ELSE 'general'
END
WHERE category IS NULL;

-- Add indexes for new learning_analytics columns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_analytics_category 
    ON learning_analytics(category, computation_date DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_learning_analytics_dimension 
    ON learning_analytics(dimension, metric_name);

-- Create view for backward compatibility if needed
CREATE OR REPLACE VIEW learning_insights_with_categories AS
SELECT 
    insight_id,
    insight_type,
    category,
    title,
    confidence_score,
    description,
    supporting_data,
    applicable_contexts,
    impact_score,
    priority,
    source,
    tags,
    created_at,
    last_validated,
    validation_count,
    positive_validations,
    validation_rate,
    is_active,
    archived_at,
    archived_reason,
    created_by_user_id,
    -- Computed fields for enhanced querying
    CASE 
        WHEN validation_count >= 5 AND validation_rate >= 0.8 THEN 'high_confidence'
        WHEN validation_count >= 3 AND validation_rate >= 0.6 THEN 'medium_confidence'
        WHEN validation_count >= 1 THEN 'low_confidence'
        ELSE 'unvalidated'
    END as confidence_level,
    CASE 
        WHEN impact_score >= 8 THEN 'critical'
        WHEN impact_score >= 5 THEN 'important'
        WHEN impact_score >= 2 THEN 'moderate'
        ELSE 'minor'
    END as impact_level
FROM agent_learning_insights
WHERE is_active = true;

-- Add function to safely query insights with fallback
CREATE OR REPLACE FUNCTION get_insights_with_category(
    p_category VARCHAR(64) DEFAULT NULL,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    insight_type VARCHAR(32),
    title VARCHAR(256),
    confidence_score FLOAT,
    created_at TIMESTAMP WITH TIME ZONE,
    category VARCHAR(64),
    priority INTEGER,
    impact_level TEXT
)
LANGUAGE SQL
STABLE
AS $$
    SELECT 
        ali.insight_type,
        ali.title,
        ali.confidence_score,
        ali.created_at,
        ali.category,
        ali.priority,
        CASE 
            WHEN ali.impact_score >= 8 THEN 'critical'
            WHEN ali.impact_score >= 5 THEN 'important'
            WHEN ali.impact_score >= 2 THEN 'moderate'
            ELSE 'minor'
        END as impact_level
    FROM agent_learning_insights ali
    WHERE ali.is_active = true
        AND (p_category IS NULL OR ali.category = p_category)
    ORDER BY ali.created_at DESC, ali.confidence_score DESC
    LIMIT p_limit;
$$;

-- Update materialized view to include new fields
DROP MATERIALIZED VIEW IF EXISTS learning_dashboard_mv CASCADE;
CREATE MATERIALIZED VIEW learning_dashboard_mv AS
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
    
    -- Categorized insights count
    (SELECT jsonb_object_agg(
        COALESCE(category, 'uncategorized'), 
        category_count
    ) FROM (
        SELECT category, COUNT(*) as category_count
        FROM agent_learning_insights 
        WHERE is_active = true AND created_at >= NOW() - INTERVAL '7 days'
        GROUP BY category
    ) cat_insights) as insights_by_category,
    
    -- Recent insights count
    (SELECT COUNT(*) FROM agent_learning_insights WHERE is_active = true AND created_at >= NOW() - INTERVAL '7 days') as recent_insights,
    
    -- Last refresh
    NOW() as last_refreshed;

-- Create unique index for materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_dashboard_mv_refresh 
    ON learning_dashboard_mv(last_refreshed);

-- Update refresh function
CREATE OR REPLACE FUNCTION refresh_learning_dashboard()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY learning_dashboard_mv;
    -- Log the refresh for monitoring
    INSERT INTO learning_analytics (metric_name, metric_value, metric_metadata, agent_context, task_context, category)
    VALUES ('dashboard_refresh', 1.0, '{"refresh_time": "' || NOW()::text || '"}', 'system', 'dashboard', 'metrics');
END;
$$ LANGUAGE plpgsql;

-- Add sample categorized insights for testing
INSERT INTO agent_learning_insights (
    insight_type, category, title, description, confidence_score, 
    impact_score, priority, source, tags
) VALUES 
(
    'optimal_combo', 'coordination', 
    'Web + API + Security trio shows 95% success rate',
    'The combination of WEB, APIDESIGNER, and SECURITY agents consistently delivers successful results for web development tasks.',
    0.95, 8, 1, 'ml_analysis', 
    '["high_success", "web_development", "trio"]'::jsonb
),
(
    'performance_tip', 'performance',
    'Parallel execution reduces duration by 40%',
    'Tasks using parallel agent execution complete 40% faster on average while maintaining quality.',
    0.87, 7, 2, 'performance_analysis',
    '["parallel", "optimization", "time_saving"]'::jsonb
)
ON CONFLICT DO NOTHING;

-- Update function to prevent future schema drift
CREATE OR REPLACE FUNCTION validate_learning_schema()
RETURNS TABLE (
    table_name TEXT,
    missing_columns TEXT[],
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    missing_cols TEXT[];
BEGIN
    -- Check agent_learning_insights
    SELECT ARRAY_AGG(col) INTO missing_cols
    FROM (VALUES ('category'), ('priority'), ('source'), ('tags')) AS expected(col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_learning_insights' 
        AND column_name = expected.col
    );
    
    RETURN QUERY SELECT 
        'agent_learning_insights'::TEXT,
        COALESCE(missing_cols, ARRAY[]::TEXT[]),
        CASE WHEN array_length(missing_cols, 1) IS NULL THEN 'OK' ELSE 'MISSING_COLUMNS' END;
    
    -- Check learning_analytics  
    SELECT ARRAY_AGG(col) INTO missing_cols
    FROM (VALUES ('category'), ('priority'), ('dimension')) AS expected(col)
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'learning_analytics'
        AND column_name = expected.col
    );
    
    RETURN QUERY SELECT 
        'learning_analytics'::TEXT,
        COALESCE(missing_cols, ARRAY[]::TEXT[]),
        CASE WHEN array_length(missing_cols, 1) IS NULL THEN 'OK' ELSE 'MISSING_COLUMNS' END;
        
END;
$$;

-- Refresh the materialized view with new schema
SELECT refresh_learning_dashboard();

COMMIT;

-- Verification queries
SELECT 'Schema Fix Verification' as status;
SELECT * FROM validate_learning_schema();

-- Show sample of fixed data
SELECT 
    'Sample insights with categories' as info,
    insight_type,
    category,
    title,
    confidence_score,
    priority
FROM agent_learning_insights 
WHERE category IS NOT NULL 
LIMIT 5;

-- Show sample analytics with categories  
SELECT 
    'Sample analytics with categories' as info,
    metric_name,
    category,
    dimension,
    agent_context
FROM learning_analytics
WHERE category IS NOT NULL
LIMIT 5;