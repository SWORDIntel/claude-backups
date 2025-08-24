-- ============================================================================
-- SCHEMA DRIFT PREVENTION SYSTEM
-- ============================================================================
-- Creates monitoring and validation tools to prevent future schema mismatches
-- between Python learning system expectations and PostgreSQL schema
-- ============================================================================

-- Create schema evolution tracking table
CREATE TABLE IF NOT EXISTS schema_evolution_tracking (
    evolution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(64) NOT NULL,
    operation VARCHAR(32) NOT NULL, -- 'ADD_COLUMN', 'DROP_COLUMN', 'MODIFY_COLUMN', 'ADD_INDEX'
    column_name VARCHAR(64),
    old_definition TEXT,
    new_definition TEXT,
    evolution_reason TEXT,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    applied_by VARCHAR(64) DEFAULT current_user,
    validation_query TEXT,
    rollback_query TEXT
);

-- Create index for tracking queries
CREATE INDEX IF NOT EXISTS idx_schema_evolution_table_time 
    ON schema_evolution_tracking(table_name, applied_at DESC);

-- Improved schema validation function (fixed ambiguous table_name reference)
CREATE OR REPLACE FUNCTION validate_learning_schema_v2()
RETURNS TABLE (
    table_name_result TEXT,
    missing_columns TEXT[],
    extra_columns TEXT[],
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    missing_cols TEXT[];
    extra_cols TEXT[];
    expected_cols TEXT[];
    actual_cols TEXT[];
BEGIN
    -- Check agent_learning_insights
    expected_cols := ARRAY['category', 'priority', 'source', 'tags'];
    
    SELECT ARRAY_AGG(col) INTO missing_cols
    FROM (SELECT unnest(expected_cols) as col) expected
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns c
        WHERE c.table_name = 'agent_learning_insights' 
        AND c.column_name = expected.col
    );
    
    SELECT ARRAY_AGG(c.column_name) INTO actual_cols
    FROM information_schema.columns c
    WHERE c.table_name = 'agent_learning_insights'
    AND c.column_name = ANY(expected_cols);
    
    SELECT ARRAY_AGG(col) INTO extra_cols
    FROM (SELECT unnest(COALESCE(actual_cols, ARRAY[]::TEXT[])) as col) actual
    WHERE col NOT IN (SELECT unnest(expected_cols));
    
    RETURN QUERY SELECT 
        'agent_learning_insights'::TEXT,
        COALESCE(missing_cols, ARRAY[]::TEXT[]),
        COALESCE(extra_cols, ARRAY[]::TEXT[]),
        CASE 
            WHEN array_length(missing_cols, 1) IS NULL THEN 'OK' 
            ELSE 'MISSING_COLUMNS' 
        END;
    
    -- Check learning_analytics
    expected_cols := ARRAY['category', 'priority', 'dimension'];
    missing_cols := NULL;
    extra_cols := NULL;
    
    SELECT ARRAY_AGG(col) INTO missing_cols
    FROM (SELECT unnest(expected_cols) as col) expected
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns c
        WHERE c.table_name = 'learning_analytics' 
        AND c.column_name = expected.col
    );
    
    RETURN QUERY SELECT 
        'learning_analytics'::TEXT,
        COALESCE(missing_cols, ARRAY[]::TEXT[]),
        ARRAY[]::TEXT[], -- No extra columns check for this table
        CASE 
            WHEN array_length(missing_cols, 1) IS NULL THEN 'OK' 
            ELSE 'MISSING_COLUMNS' 
        END;
END;
$$;

-- Create function to automatically fix common schema drift issues
CREATE OR REPLACE FUNCTION auto_fix_schema_drift()
RETURNS TABLE (
    table_name_result TEXT,
    fix_applied TEXT,
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    validation_result RECORD;
BEGIN
    -- Check current schema status
    FOR validation_result IN SELECT * FROM validate_learning_schema_v2() LOOP
        IF validation_result.status = 'MISSING_COLUMNS' THEN
            -- Auto-fix agent_learning_insights table
            IF validation_result.table_name_result = 'agent_learning_insights' THEN
                IF 'category' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE agent_learning_insights ADD COLUMN category VARCHAR(64);
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('agent_learning_insights', 'ADD_COLUMN', 'category', 'VARCHAR(64)', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added category column', 'FIXED';
                END IF;
                
                IF 'priority' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE agent_learning_insights ADD COLUMN priority INTEGER DEFAULT 1;
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('agent_learning_insights', 'ADD_COLUMN', 'priority', 'INTEGER DEFAULT 1', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added priority column', 'FIXED';
                END IF;
                
                IF 'source' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE agent_learning_insights ADD COLUMN source VARCHAR(32) DEFAULT 'system';
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('agent_learning_insights', 'ADD_COLUMN', 'source', 'VARCHAR(32) DEFAULT system', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added source column', 'FIXED';
                END IF;
                
                IF 'tags' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE agent_learning_insights ADD COLUMN tags JSONB DEFAULT JSON_ARRAY();
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('agent_learning_insights', 'ADD_COLUMN', 'tags', 'JSONB DEFAULT JSON_ARRAY()', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added tags column', 'FIXED';
                END IF;
            END IF;
            
            -- Auto-fix learning_analytics table
            IF validation_result.table_name_result = 'learning_analytics' THEN
                IF 'category' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE learning_analytics ADD COLUMN category VARCHAR(64);
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('learning_analytics', 'ADD_COLUMN', 'category', 'VARCHAR(64)', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added category column', 'FIXED';
                END IF;
                
                IF 'priority' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE learning_analytics ADD COLUMN priority INTEGER DEFAULT 1;
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('learning_analytics', 'ADD_COLUMN', 'priority', 'INTEGER DEFAULT 1', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added priority column', 'FIXED';
                END IF;
                
                IF 'dimension' = ANY(validation_result.missing_columns) THEN
                    ALTER TABLE learning_analytics ADD COLUMN dimension VARCHAR(64);
                    INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason)
                    VALUES ('learning_analytics', 'ADD_COLUMN', 'dimension', 'VARCHAR(64)', 'Auto-fix for Python learning system compatibility');
                    RETURN QUERY SELECT validation_result.table_name_result, 'Added dimension column', 'FIXED';
                END IF;
            END IF;
        ELSE
            RETURN QUERY SELECT validation_result.table_name_result, 'No fixes needed', 'OK';
        END IF;
    END LOOP;
END;
$$;

-- Create monitoring view for schema health
CREATE OR REPLACE VIEW learning_schema_health AS
SELECT 
    'Learning Schema Health Dashboard' as component,
    (SELECT COUNT(*) FROM validate_learning_schema_v2() WHERE status = 'OK') as healthy_tables,
    (SELECT COUNT(*) FROM validate_learning_schema_v2() WHERE status != 'OK') as unhealthy_tables,
    (SELECT COUNT(*) FROM schema_evolution_tracking WHERE applied_at >= NOW() - INTERVAL '24 hours') as recent_changes,
    (SELECT MAX(applied_at) FROM schema_evolution_tracking) as last_schema_change,
    NOW() as health_check_time;

-- Create scheduled schema validation function (for cron or pg_cron)
CREATE OR REPLACE FUNCTION daily_schema_validation()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    validation_results TEXT := '';
    health_status RECORD;
    drift_fixes TEXT := '';
BEGIN
    -- Log validation attempt
    INSERT INTO learning_analytics (metric_name, metric_value, metric_metadata, agent_context, task_context, category)
    VALUES ('schema_validation_run', 1.0, '{"timestamp": "' || NOW()::text || '"}', 'system', 'maintenance', 'metrics');
    
    -- Run validation
    FOR health_status IN SELECT * FROM validate_learning_schema_v2() LOOP
        validation_results := validation_results || health_status.table_name_result || ': ' || health_status.status || E'\n';
        
        -- Auto-fix if issues found
        IF health_status.status != 'OK' THEN
            SELECT string_agg(fix_applied, '; ') INTO drift_fixes
            FROM auto_fix_schema_drift() 
            WHERE table_name_result = health_status.table_name_result;
            
            IF drift_fixes IS NOT NULL THEN
                validation_results := validation_results || 'Auto-fixes applied: ' || drift_fixes || E'\n';
            END IF;
        END IF;
    END LOOP;
    
    -- Log results
    INSERT INTO learning_analytics (metric_name, metric_value, metric_metadata, agent_context, task_context, category)
    VALUES ('schema_validation_result', 
            CASE WHEN validation_results LIKE '%MISSING_COLUMNS%' THEN 0.0 ELSE 1.0 END, 
            jsonb_build_object('validation_details', validation_results), 
            'system', 'maintenance', 'metrics');
    
    RETURN 'Schema validation completed: ' || E'\n' || validation_results;
END;
$$;

-- Record the initial schema fix in tracking
INSERT INTO schema_evolution_tracking (table_name, operation, column_name, new_definition, evolution_reason, validation_query)
VALUES 
('agent_learning_insights', 'ADD_COLUMN', 'category', 'VARCHAR(64)', 'Fix Python learning system compatibility - missing category column', 'SELECT category FROM agent_learning_insights LIMIT 1'),
('agent_learning_insights', 'ADD_COLUMN', 'priority', 'INTEGER DEFAULT 1', 'Add priority field for learning system', 'SELECT priority FROM agent_learning_insights LIMIT 1'),
('agent_learning_insights', 'ADD_COLUMN', 'source', 'VARCHAR(32) DEFAULT system', 'Add source tracking for insights', 'SELECT source FROM agent_learning_insights LIMIT 1'),
('agent_learning_insights', 'ADD_COLUMN', 'tags', 'JSONB DEFAULT JSON_ARRAY()', 'Add tags for flexible categorization', 'SELECT tags FROM agent_learning_insights LIMIT 1'),
('learning_analytics', 'ADD_COLUMN', 'category', 'VARCHAR(64)', 'Add category field to analytics table', 'SELECT category FROM learning_analytics LIMIT 1'),
('learning_analytics', 'ADD_COLUMN', 'priority', 'INTEGER DEFAULT 1', 'Add priority to analytics metrics', 'SELECT priority FROM learning_analytics LIMIT 1'),
('learning_analytics', 'ADD_COLUMN', 'dimension', 'VARCHAR(64)', 'Add dimension field for metric categorization', 'SELECT dimension FROM learning_analytics LIMIT 1');

-- Test the monitoring system
SELECT 'Schema Drift Prevention System Status' as component;
SELECT * FROM learning_schema_health;
SELECT 'Recent Schema Changes (last 7 days)' as info;
SELECT table_name, operation, column_name, evolution_reason, applied_at 
FROM schema_evolution_tracking 
WHERE applied_at >= NOW() - INTERVAL '7 days'
ORDER BY applied_at DESC;