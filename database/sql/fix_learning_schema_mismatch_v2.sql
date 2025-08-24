-- ============================================================================
-- POSTGRESQL LEARNING SYSTEM SCHEMA MISMATCH FIX V2
-- ============================================================================
-- Adds missing 'category' column and other expected fields to match Python expectations
-- Compatible with PostgreSQL 17 - Fixed for execution without transaction conflicts
-- ============================================================================

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
ADD CONSTRAINT IF NOT EXISTS check_category_values CHECK (
    category IN ('coordination', 'anti_pattern', 'performance', 'resource', 
                'agent_specialty', 'trend_analysis', 'anomaly', 'efficiency', 'general')
);

-- Add other missing columns that might be expected by the Python system
ALTER TABLE agent_learning_insights 
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS source VARCHAR(32) DEFAULT 'system',
ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT JSON_ARRAY();

-- Add constraint for priority
ALTER TABLE agent_learning_insights
ADD CONSTRAINT IF NOT EXISTS check_priority_range CHECK (priority BETWEEN 1 AND 5);

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

-- Create regular indexes (not concurrent since we're not in a transaction)
CREATE INDEX IF NOT EXISTS idx_learning_insights_category 
    ON agent_learning_insights(category, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_learning_analytics_category 
    ON learning_analytics(category, computation_date DESC);

CREATE INDEX IF NOT EXISTS idx_learning_analytics_dimension 
    ON learning_analytics(dimension, metric_name);

-- Create function to safely query insights with fallback
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
ON CONFLICT (insight_id) DO NOTHING;

-- Test the problematic query that was failing
SELECT 'Testing the problematic query...' as status;

-- This is the exact query that was failing according to the log
SELECT 
    insight_type,
    title,
    confidence_score,
    created_at,
    category
FROM agent_learning_insights
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 10;