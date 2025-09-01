-- Intelligent Context Chopping Database Schema
-- Stores wider context and learning patterns for optimized context selection

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS context_chopping;

-- Context chunks storage (wider context preserved in database)
CREATE TABLE IF NOT EXISTS context_chopping.context_chunks (
    chunk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path TEXT NOT NULL,
    project_path TEXT NOT NULL,
    content TEXT NOT NULL,  -- Full chunk content
    content_hash VARCHAR(64) UNIQUE NOT NULL,  -- MD5 hash for deduplication
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    token_count INTEGER NOT NULL,
    
    -- Relevance and scoring
    base_relevance_score FLOAT DEFAULT 0.0,
    current_relevance_score FLOAT DEFAULT 0.0,
    access_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    
    -- Security classification
    security_level VARCHAR(20) DEFAULT 'public' 
        CHECK (security_level IN ('public', 'internal', 'sensitive', 'classified', 'redacted')),
    contains_secrets BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    language VARCHAR(20),
    file_type VARCHAR(20),
    complexity_score FLOAT,
    important_sections JSONB,  -- Shadowgit analysis results
    dependencies TEXT[],  -- Extracted imports/requires
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_accessed TIMESTAMPTZ DEFAULT NOW(),
    last_modified TIMESTAMPTZ,
    
    -- Indexing
    embedding VECTOR(512),  -- For ML similarity search
    
    CONSTRAINT valid_lines CHECK (start_line >= 0 AND end_line >= start_line)
);

-- Indexes for performance
CREATE INDEX idx_context_chunks_file_path ON context_chopping.context_chunks(file_path);
CREATE INDEX idx_context_chunks_relevance ON context_chopping.context_chunks(current_relevance_score DESC);
CREATE INDEX idx_context_chunks_security ON context_chopping.context_chunks(security_level);
CREATE INDEX idx_context_chunks_hash ON context_chopping.context_chunks(content_hash);
CREATE INDEX idx_context_chunks_embedding ON context_chopping.context_chunks USING ivfflat (embedding vector_cosine_ops);

-- Query patterns and their successful context selections
CREATE TABLE IF NOT EXISTS context_chopping.query_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_text TEXT NOT NULL,
    query_embedding VECTOR(512),
    
    -- Selected chunks for this query
    selected_chunk_ids UUID[],
    total_tokens_used INTEGER,
    
    -- Performance metrics
    api_success BOOLEAN DEFAULT TRUE,
    response_quality_score FLOAT,
    execution_time_ms INTEGER,
    tokens_saved INTEGER,  -- Compared to full context
    
    -- Learning metrics
    rejection_avoided BOOLEAN DEFAULT FALSE,
    security_issues_prevented INTEGER DEFAULT 0,
    
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_query_patterns_embedding ON context_chopping.query_patterns 
    USING ivfflat (query_embedding vector_cosine_ops);
CREATE INDEX idx_query_patterns_timestamp ON context_chopping.query_patterns(timestamp DESC);

-- Context window configurations per agent/task
CREATE TABLE IF NOT EXISTS context_chopping.window_configurations (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name VARCHAR(100),
    task_type VARCHAR(100),
    
    -- Window settings
    max_tokens INTEGER DEFAULT 8000,
    min_relevance_score FLOAT DEFAULT 0.3,
    include_dependencies BOOLEAN DEFAULT TRUE,
    security_filter_level VARCHAR(20) DEFAULT 'standard',
    
    -- Prioritization rules
    prioritize_recent BOOLEAN DEFAULT TRUE,
    prioritize_modified BOOLEAN DEFAULT TRUE,
    prioritize_error_context BOOLEAN DEFAULT TRUE,
    
    -- File type preferences
    preferred_extensions TEXT[] DEFAULT ARRAY['.py', '.js', '.ts', '.md'],
    excluded_patterns TEXT[] DEFAULT ARRAY['test_', 'spec_', '__pycache__'],
    
    -- Performance stats
    avg_tokens_used INTEGER,
    success_rate FLOAT,
    avg_response_time_ms INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Shadowgit analysis cache
CREATE TABLE IF NOT EXISTS context_chopping.shadowgit_analysis (
    file_path TEXT PRIMARY KEY,
    analysis_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Shadowgit AVX2 analysis results (930M lines/sec)
    lines_processed INTEGER,
    processing_time_ns BIGINT,
    processing_speed TEXT,  -- e.g., "930M lines/sec"
    
    -- Extracted information
    important_lines INTEGER[],  -- Line numbers of important sections
    function_definitions JSONB,  -- {name: line_number}
    class_definitions JSONB,
    imports JSONB,
    complexity_metrics JSONB,
    
    -- File metrics
    total_lines INTEGER,
    code_lines INTEGER,
    comment_lines INTEGER,
    blank_lines INTEGER,
    
    file_hash VARCHAR(64),  -- For change detection
    last_modified TIMESTAMPTZ
);

CREATE INDEX idx_shadowgit_analysis_timestamp ON context_chopping.shadowgit_analysis(analysis_timestamp DESC);

-- Learning feedback table
CREATE TABLE IF NOT EXISTS context_chopping.learning_feedback (
    feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_pattern_id UUID REFERENCES context_chopping.query_patterns(pattern_id),
    
    -- Feedback metrics
    context_was_sufficient BOOLEAN,
    missed_important_context BOOLEAN,
    included_irrelevant_context BOOLEAN,
    security_leak_detected BOOLEAN,
    
    -- Adjustments made
    relevance_adjustments JSONB,  -- {chunk_id: adjustment_delta}
    tokens_adjustment INTEGER,  -- Suggested token limit change
    
    -- Outcome
    task_completed BOOLEAN,
    error_message TEXT,
    
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Statistics and monitoring
CREATE TABLE IF NOT EXISTS context_chopping.performance_stats (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    -- Chopping performance
    total_chunks_stored INTEGER,
    total_queries_processed INTEGER,
    avg_context_reduction_percent FLOAT,
    avg_tokens_per_request INTEGER,
    
    -- Security metrics
    secrets_redacted_count INTEGER,
    sensitive_chunks_filtered INTEGER,
    
    -- Efficiency metrics
    cache_hit_rate FLOAT,
    shadowgit_usage_rate FLOAT,
    avg_selection_time_ms INTEGER,
    
    -- Learning metrics
    relevance_accuracy FLOAT,
    rejection_prevention_rate FLOAT,
    
    period_start TIMESTAMPTZ,
    period_end TIMESTAMPTZ
);

-- Functions for context selection
CREATE OR REPLACE FUNCTION context_chopping.get_relevant_chunks(
    p_query TEXT,
    p_max_tokens INTEGER DEFAULT 8000,
    p_security_level VARCHAR DEFAULT 'internal'
) RETURNS TABLE (
    chunk_id UUID,
    file_path TEXT,
    content TEXT,
    relevance_score FLOAT,
    token_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH query_embedding AS (
        -- Would compute embedding in real implementation
        SELECT NULL::VECTOR(512) as embedding
    ),
    ranked_chunks AS (
        SELECT 
            c.chunk_id,
            c.file_path,
            c.content,
            c.current_relevance_score + 
                CASE 
                    WHEN c.last_accessed > NOW() - INTERVAL '1 hour' THEN 0.2
                    WHEN c.last_accessed > NOW() - INTERVAL '1 day' THEN 0.1
                    ELSE 0
                END as relevance_score,
            c.token_count,
            SUM(c.token_count) OVER (ORDER BY c.current_relevance_score DESC) as running_total
        FROM context_chopping.context_chunks c
        WHERE c.security_level NOT IN ('classified', 'sensitive')
            OR p_security_level IN ('classified', 'sensitive')
        ORDER BY relevance_score DESC
    )
    SELECT 
        chunk_id,
        file_path,
        content,
        relevance_score,
        token_count
    FROM ranked_chunks
    WHERE running_total - token_count < p_max_tokens;
END;
$$ LANGUAGE plpgsql;

-- Function to update relevance scores based on success
CREATE OR REPLACE FUNCTION context_chopping.update_relevance_scores(
    p_chunk_ids UUID[],
    p_success BOOLEAN,
    p_adjustment_factor FLOAT DEFAULT 0.1
) RETURNS VOID AS $$
BEGIN
    UPDATE context_chopping.context_chunks
    SET 
        current_relevance_score = CASE
            WHEN p_success THEN 
                LEAST(current_relevance_score * (1 + p_adjustment_factor), 1.0)
            ELSE 
                GREATEST(current_relevance_score * (1 - p_adjustment_factor), 0.0)
        END,
        access_count = access_count + 1,
        success_count = success_count + CASE WHEN p_success THEN 1 ELSE 0 END,
        last_accessed = NOW()
    WHERE chunk_id = ANY(p_chunk_ids);
END;
$$ LANGUAGE plpgsql;

-- Partitioning for performance (by month)
CREATE TABLE context_chopping.query_patterns_2025_01 
    PARTITION OF context_chopping.query_patterns 
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE context_chopping.query_patterns_2025_02 
    PARTITION OF context_chopping.query_patterns 
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Add more partitions as needed

-- Monitoring view
CREATE VIEW context_chopping.system_overview AS
SELECT 
    (SELECT COUNT(*) FROM context_chopping.context_chunks) as total_chunks,
    (SELECT COUNT(*) FROM context_chopping.query_patterns) as total_queries,
    (SELECT AVG(tokens_saved) FROM context_chopping.query_patterns) as avg_tokens_saved,
    (SELECT COUNT(*) FROM context_chopping.context_chunks WHERE security_level = 'redacted') as redacted_chunks,
    (SELECT AVG(current_relevance_score) FROM context_chopping.context_chunks) as avg_relevance,
    (SELECT COUNT(DISTINCT file_path) FROM context_chopping.context_chunks) as unique_files,
    NOW() as snapshot_time;