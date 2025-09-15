-- Git Analytics Engine Schema
-- PostgreSQL 16+ with pgvector for code similarity analysis
-- Target: <10ms query performance with 95% accuracy

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Core git repository metadata
CREATE TABLE IF NOT EXISTS git_repositories (
    repo_id BIGSERIAL PRIMARY KEY,
    repo_path TEXT NOT NULL UNIQUE,
    repo_name VARCHAR(255) NOT NULL,
    branch_name VARCHAR(100) DEFAULT 'main',
    last_analyzed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_commits BIGINT DEFAULT 0,
    total_files BIGINT DEFAULT 0,
    repo_size_bytes BIGINT DEFAULT 0,
    
    -- Performance indexes
    CONSTRAINT repo_path_valid CHECK (length(repo_path) > 0),
    CONSTRAINT repo_name_valid CHECK (length(repo_name) > 0)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_git_repos_path_hash ON git_repositories USING hash(repo_path);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_git_repos_analyzed ON git_repositories (last_analyzed DESC);

-- File-level change tracking with vector embeddings
CREATE TABLE IF NOT EXISTS file_changes (
    change_id BIGSERIAL PRIMARY KEY,
    repo_id BIGINT REFERENCES git_repositories(repo_id) ON DELETE CASCADE,
    commit_hash CHAR(40) NOT NULL,
    file_path TEXT NOT NULL,
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('ADD', 'MODIFY', 'DELETE', 'RENAME')),
    lines_added INTEGER DEFAULT 0,
    lines_deleted INTEGER DEFAULT 0,
    
    -- Vector embeddings for semantic similarity (256 dimensions)
    content_embedding vector(256),
    diff_embedding vector(256),
    
    -- Change metadata
    author_name VARCHAR(255),
    commit_message TEXT,
    change_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Performance columns
    file_size_bytes INTEGER DEFAULT 0,
    complexity_score REAL DEFAULT 0.0,
    
    -- Constraints
    CONSTRAINT valid_commit_hash CHECK (commit_hash ~ '^[a-f0-9]{40}$'),
    CONSTRAINT valid_lines CHECK (lines_added >= 0 AND lines_deleted >= 0)
);

-- Optimized indexes for sub-10ms queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_changes_repo_time ON file_changes (repo_id, change_timestamp DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_changes_commit ON file_changes USING hash(commit_hash);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_changes_path_trgm ON file_changes USING gin(file_path gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_changes_author ON file_changes (author_name);

-- Vector similarity indexes for content and diff embeddings
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_content_embedding_ivf ON file_changes 
USING ivfflat (content_embedding vector_cosine_ops) WITH (lists = 1000);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_diff_embedding_ivf ON file_changes 
USING ivfflat (diff_embedding vector_cosine_ops) WITH (lists = 1000);

-- Conflict prediction patterns
CREATE TABLE IF NOT EXISTS conflict_patterns (
    pattern_id BIGSERIAL PRIMARY KEY,
    repo_id BIGINT REFERENCES git_repositories(repo_id) ON DELETE CASCADE,
    
    -- Pattern identification
    file_pattern TEXT NOT NULL, -- regex pattern for file paths
    author_pair TEXT[], -- authors involved in conflicts
    time_window_hours INTEGER DEFAULT 24,
    
    -- Conflict statistics
    conflicts_detected INTEGER DEFAULT 0,
    conflicts_predicted INTEGER DEFAULT 0,
    prediction_accuracy REAL DEFAULT 0.0,
    
    -- Pattern features
    pattern_embedding vector(128),
    common_change_types TEXT[],
    avg_lines_changed REAL DEFAULT 0.0,
    
    -- Timestamps
    pattern_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_accuracy CHECK (prediction_accuracy >= 0.0 AND prediction_accuracy <= 1.0)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conflict_patterns_repo ON conflict_patterns (repo_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_conflict_patterns_accuracy ON conflict_patterns (prediction_accuracy DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pattern_embedding_hnsw ON conflict_patterns 
USING hnsw (pattern_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Real-time performance metrics
CREATE TABLE IF NOT EXISTS query_performance (
    metric_id BIGSERIAL PRIMARY KEY,
    query_type VARCHAR(50) NOT NULL,
    execution_time_ms REAL NOT NULL,
    rows_processed BIGINT DEFAULT 0,
    cache_hit_ratio REAL DEFAULT 0.0,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_query_perf_time ON query_performance (recorded_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_query_perf_type ON query_performance (query_type);

-- Optimized functions for git analytics

-- Function: Find similar code changes using vector similarity
CREATE OR REPLACE FUNCTION find_similar_changes(
    p_content_embedding vector(256),
    p_similarity_threshold REAL DEFAULT 0.8,
    p_limit INTEGER DEFAULT 10
) 
RETURNS TABLE (
    change_id BIGINT,
    file_path TEXT,
    commit_hash CHAR(40),
    similarity_score REAL,
    change_timestamp TIMESTAMP WITH TIME ZONE
) 
LANGUAGE SQL STABLE
AS $$
    SELECT 
        fc.change_id,
        fc.file_path,
        fc.commit_hash,
        1 - (fc.content_embedding <=> p_content_embedding) as similarity_score,
        fc.change_timestamp
    FROM file_changes fc
    WHERE fc.content_embedding IS NOT NULL
        AND 1 - (fc.content_embedding <=> p_content_embedding) >= p_similarity_threshold
    ORDER BY fc.content_embedding <=> p_content_embedding
    LIMIT p_limit;
$$;

-- Function: Predict conflict probability for file changes
CREATE OR REPLACE FUNCTION predict_conflict_probability(
    p_repo_id BIGINT,
    p_file_path TEXT,
    p_author_name TEXT,
    p_change_embedding vector(256)
) 
RETURNS REAL
LANGUAGE PLPGSQL STABLE
AS $$
DECLARE
    v_conflict_score REAL := 0.0;
    v_pattern_match REAL;
    v_author_history REAL;
    v_file_complexity REAL;
BEGIN
    -- Check against known conflict patterns
    SELECT COALESCE(AVG(cp.prediction_accuracy), 0.0) INTO v_pattern_match
    FROM conflict_patterns cp
    WHERE cp.repo_id = p_repo_id 
        AND p_file_path ~ cp.file_pattern
        AND p_author_name = ANY(cp.author_pair);
    
    -- Analyze author's recent change frequency
    SELECT COALESCE(
        GREATEST(0.0, LEAST(1.0, COUNT(*)::REAL / 10.0)), 0.0
    ) INTO v_author_history
    FROM file_changes fc
    WHERE fc.repo_id = p_repo_id
        AND fc.file_path = p_file_path
        AND fc.author_name = p_author_name
        AND fc.change_timestamp > NOW() - INTERVAL '7 days';
    
    -- Calculate file complexity factor
    SELECT COALESCE(AVG(fc.complexity_score), 0.0) INTO v_file_complexity
    FROM file_changes fc
    WHERE fc.repo_id = p_repo_id 
        AND fc.file_path = p_file_path
        AND fc.change_timestamp > NOW() - INTERVAL '30 days';
    
    -- Weighted conflict probability
    v_conflict_score := (
        v_pattern_match * 0.5 +
        v_author_history * 0.3 +
        LEAST(v_file_complexity / 100.0, 1.0) * 0.2
    );
    
    RETURN GREATEST(0.0, LEAST(1.0, v_conflict_score));
END;
$$;

-- Function: High-performance repository statistics
CREATE OR REPLACE FUNCTION get_repo_stats(p_repo_id BIGINT)
RETURNS TABLE (
    total_commits BIGINT,
    total_files BIGINT,
    active_authors INTEGER,
    conflict_rate REAL,
    avg_complexity REAL,
    last_activity TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL STABLE
AS $$
    SELECT 
        COUNT(DISTINCT fc.commit_hash) as total_commits,
        COUNT(DISTINCT fc.file_path) as total_files,
        COUNT(DISTINCT fc.author_name) as active_authors,
        COALESCE(AVG(cp.prediction_accuracy), 0.0) as conflict_rate,
        COALESCE(AVG(fc.complexity_score), 0.0) as avg_complexity,
        MAX(fc.change_timestamp) as last_activity
    FROM file_changes fc
    LEFT JOIN conflict_patterns cp ON cp.repo_id = fc.repo_id
    WHERE fc.repo_id = p_repo_id
        AND fc.change_timestamp > NOW() - INTERVAL '90 days';
$$;

-- Optimized materialized view for dashboard queries
CREATE MATERIALIZED VIEW IF NOT EXISTS repo_dashboard_stats AS
SELECT 
    gr.repo_id,
    gr.repo_name,
    gr.branch_name,
    COUNT(DISTINCT fc.commit_hash) as commits_90d,
    COUNT(DISTINCT fc.file_path) as files_changed_90d,
    COUNT(DISTINCT fc.author_name) as active_authors_90d,
    COALESCE(AVG(cp.prediction_accuracy), 0.0) as avg_conflict_accuracy,
    SUM(fc.lines_added) as total_lines_added,
    SUM(fc.lines_deleted) as total_lines_deleted,
    MAX(fc.change_timestamp) as last_change,
    AVG(fc.complexity_score) as avg_complexity
FROM git_repositories gr
LEFT JOIN file_changes fc ON gr.repo_id = fc.repo_id 
    AND fc.change_timestamp > NOW() - INTERVAL '90 days'
LEFT JOIN conflict_patterns cp ON gr.repo_id = cp.repo_id
GROUP BY gr.repo_id, gr.repo_name, gr.branch_name;

CREATE UNIQUE INDEX IF NOT EXISTS idx_dashboard_stats_repo ON repo_dashboard_stats (repo_id);

-- Refresh materialized view function
CREATE OR REPLACE FUNCTION refresh_dashboard_stats()
RETURNS void
LANGUAGE SQL
AS $$
    REFRESH MATERIALIZED VIEW CONCURRENTLY repo_dashboard_stats;
$$;

-- Performance monitoring triggers
CREATE OR REPLACE FUNCTION log_query_performance()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO query_performance (query_type, execution_time_ms, rows_processed)
        VALUES ('file_change_insert', extract(epoch from clock_timestamp() - statement_timestamp()) * 1000, 1);
    END IF;
    RETURN NEW;
END;
$$;

-- Apply performance monitoring
DROP TRIGGER IF EXISTS file_changes_perf_trigger ON file_changes;
CREATE TRIGGER file_changes_perf_trigger
    AFTER INSERT ON file_changes
    FOR EACH ROW EXECUTE FUNCTION log_query_performance();

-- Maintenance procedures
CREATE OR REPLACE FUNCTION cleanup_old_metrics()
RETURNS void
LANGUAGE SQL
AS $$
    DELETE FROM query_performance 
    WHERE recorded_at < NOW() - INTERVAL '7 days';
    
    VACUUM ANALYZE query_performance;
$$;

-- Performance optimization settings
ALTER TABLE file_changes SET (fillfactor = 90);
ALTER TABLE conflict_patterns SET (fillfactor = 90);

-- Table statistics for query planner
ANALYZE git_repositories;
ANALYZE file_changes;
ANALYZE conflict_patterns;
ANALYZE query_performance;