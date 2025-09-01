-- Claude Global Learning System Schema Extensions
-- Enables cross-project intelligence and pattern recognition

-- Create global schema if not exists
CREATE SCHEMA IF NOT EXISTS claude_global;

-- Table for tracking all projects in the system
CREATE TABLE IF NOT EXISTS claude_global.projects (
    project_id SERIAL PRIMARY KEY,
    project_path TEXT UNIQUE NOT NULL,
    project_name TEXT NOT NULL,
    project_type VARCHAR(50), -- python, web, systems, ml, etc.
    first_seen TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW(),
    total_commits INTEGER DEFAULT 0,
    active_agents TEXT[], -- List of agents used in this project
    performance_score DECIMAL(5,2) DEFAULT 0.0,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Cross-project pattern recognition table
CREATE TABLE IF NOT EXISTS claude_global.cross_project_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pattern_type VARCHAR(100) NOT NULL,
    pattern_description TEXT,
    pattern_embedding VECTOR(256), -- pgvector for similarity search
    source_projects INTEGER[], -- Array of project_ids
    occurrence_count INTEGER DEFAULT 1,
    effectiveness_score DECIMAL(5,3) DEFAULT 0.0,
    first_detected TIMESTAMP DEFAULT NOW(),
    last_seen TIMESTAMP DEFAULT NOW(),
    confidence_level DECIMAL(5,3) DEFAULT 0.0,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Global agent performance tracking across all projects
CREATE TABLE IF NOT EXISTS claude_global.agent_performance_global (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    project_id INTEGER REFERENCES claude_global.projects(project_id),
    task_category VARCHAR(100),
    execution_count INTEGER DEFAULT 0,
    success_rate DECIMAL(5,3) DEFAULT 0.0,
    avg_execution_time_ms INTEGER,
    total_execution_time_ms BIGINT DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    last_execution TIMESTAMP DEFAULT NOW(),
    performance_trend DECIMAL(5,3), -- Positive = improving, negative = declining
    UNIQUE(agent_name, project_id, task_category)
);

-- Project similarity and correlation matrix
CREATE TABLE IF NOT EXISTS claude_global.project_correlations (
    correlation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_a_id INTEGER REFERENCES claude_global.projects(project_id),
    project_b_id INTEGER REFERENCES claude_global.projects(project_id),
    similarity_score DECIMAL(5,3) NOT NULL,
    shared_patterns INTEGER DEFAULT 0,
    shared_agents TEXT[],
    correlation_type VARCHAR(50), -- code_style, dependencies, patterns, etc.
    learning_transfer_success DECIMAL(5,3) DEFAULT 0.0,
    calculated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(project_a_id, project_b_id),
    CHECK (project_a_id < project_b_id) -- Ensure no duplicate pairs
);

-- Global learning insights aggregation
CREATE TABLE IF NOT EXISTS claude_global.learning_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(100) NOT NULL,
    insight_content TEXT NOT NULL,
    applicable_projects INTEGER[], -- Projects this insight applies to
    confidence_score DECIMAL(5,3) DEFAULT 0.0,
    validation_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP, -- Some insights may be time-limited
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Cross-project workflow templates discovered through learning
CREATE TABLE IF NOT EXISTS claude_global.workflow_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_name VARCHAR(255) NOT NULL,
    template_description TEXT,
    involved_agents TEXT[] NOT NULL,
    execution_order JSONB NOT NULL, -- Detailed workflow steps
    success_rate DECIMAL(5,3) DEFAULT 0.0,
    projects_used INTEGER[], -- Projects that have used this workflow
    avg_completion_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Global metrics for system-wide performance tracking
CREATE TABLE IF NOT EXISTS claude_global.system_metrics (
    metric_id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(20,5) NOT NULL,
    metric_unit VARCHAR(50),
    project_id INTEGER REFERENCES claude_global.projects(project_id),
    recorded_at TIMESTAMP DEFAULT NOW(),
    metric_category VARCHAR(50), -- performance, quality, efficiency, etc.
    INDEX idx_metrics_time (recorded_at DESC),
    INDEX idx_metrics_project (project_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_projects_path ON claude_global.projects(project_path);
CREATE INDEX IF NOT EXISTS idx_projects_activity ON claude_global.projects(last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_type ON claude_global.cross_project_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_patterns_effectiveness ON claude_global.cross_project_patterns(effectiveness_score DESC);
CREATE INDEX IF NOT EXISTS idx_agent_perf_agent ON claude_global.agent_performance_global(agent_name);
CREATE INDEX IF NOT EXISTS idx_agent_perf_project ON claude_global.agent_performance_global(project_id);
CREATE INDEX IF NOT EXISTS idx_correlations_similarity ON claude_global.project_correlations(similarity_score DESC);
CREATE INDEX IF NOT EXISTS idx_insights_type ON claude_global.learning_insights(insight_type);
CREATE INDEX IF NOT EXISTS idx_workflow_success ON claude_global.workflow_templates(success_rate DESC);

-- Vector similarity index for pattern matching (pgvector)
CREATE INDEX IF NOT EXISTS idx_patterns_embedding ON claude_global.cross_project_patterns 
USING ivfflat (pattern_embedding vector_cosine_ops)
WITH (lists = 100);

-- Function to calculate project similarity
CREATE OR REPLACE FUNCTION claude_global.calculate_project_similarity(
    p1_id INTEGER,
    p2_id INTEGER
) RETURNS DECIMAL AS $$
DECLARE
    similarity DECIMAL(5,3);
    shared_agent_count INTEGER;
    shared_pattern_count INTEGER;
BEGIN
    -- Calculate based on shared agents
    SELECT COUNT(DISTINCT agent) INTO shared_agent_count
    FROM (
        SELECT UNNEST(active_agents) AS agent FROM claude_global.projects WHERE project_id = p1_id
        INTERSECT
        SELECT UNNEST(active_agents) AS agent FROM claude_global.projects WHERE project_id = p2_id
    ) AS shared;
    
    -- Calculate based on shared patterns
    SELECT COUNT(*) INTO shared_pattern_count
    FROM claude_global.cross_project_patterns
    WHERE p1_id = ANY(source_projects) AND p2_id = ANY(source_projects);
    
    -- Weighted similarity calculation
    similarity := (shared_agent_count * 0.3 + shared_pattern_count * 0.7) / 10.0;
    
    -- Ensure similarity is between 0 and 1
    IF similarity > 1.0 THEN similarity := 1.0; END IF;
    IF similarity < 0.0 THEN similarity := 0.0; END IF;
    
    RETURN similarity;
END;
$$ LANGUAGE plpgsql;

-- Function to recommend agents based on project characteristics
CREATE OR REPLACE FUNCTION claude_global.recommend_agents_for_project(
    p_id INTEGER
) RETURNS TABLE(agent_name VARCHAR, recommendation_score DECIMAL) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        apg.agent_name,
        AVG(apg.success_rate) * 
        (1.0 + LOG(1 + SUM(apg.execution_count))) AS recommendation_score
    FROM claude_global.agent_performance_global apg
    JOIN claude_global.project_correlations pc 
        ON (pc.project_a_id = p_id OR pc.project_b_id = p_id)
        AND pc.similarity_score > 0.6
    WHERE apg.project_id IN (
        CASE WHEN pc.project_a_id = p_id THEN pc.project_b_id ELSE pc.project_a_id END
    )
    AND apg.success_rate > 0.7
    GROUP BY apg.agent_name
    ORDER BY recommendation_score DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update project activity timestamp
CREATE OR REPLACE FUNCTION claude_global.update_project_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE claude_global.projects 
    SET last_activity = NOW(),
        total_commits = total_commits + 1
    WHERE project_id = NEW.project_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for agent performance updates
CREATE TRIGGER update_project_on_agent_execution
AFTER INSERT OR UPDATE ON claude_global.agent_performance_global
FOR EACH ROW
EXECUTE FUNCTION claude_global.update_project_activity();

-- Grant appropriate permissions
GRANT ALL ON SCHEMA claude_global TO claude_agent;
GRANT ALL ON ALL TABLES IN SCHEMA claude_global TO claude_agent;
GRANT ALL ON ALL SEQUENCES IN SCHEMA claude_global TO claude_agent;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA claude_global TO claude_agent;