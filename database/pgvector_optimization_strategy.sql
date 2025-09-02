-- COMPREHENSIVE PGVECTOR OPTIMIZATION STRATEGY
-- PostgreSQL 16 with pgvector extension
-- Target: 10-100x performance improvement for context chopping database
-- Author: DATABASE Agent
-- Date: 2025-09-02

BEGIN;

-- =============================================
-- SECTION 1: ADVANCED VECTOR INDEXES
-- =============================================

-- Drop existing basic vector indexes to recreate with optimal parameters
DROP INDEX IF EXISTS context_chopping.idx_context_chunks_embedding;
DROP INDEX IF EXISTS context_chopping.idx_query_patterns_embedding;

-- Create optimized IVFFlat vector indexes with tuned parameters
-- IVFFlat with 100 lists for ~10K vectors, 1000 lists for ~100K+ vectors
-- Using vector_cosine_ops for semantic similarity

-- Context chunks vector index (optimized for similarity search)
CREATE INDEX CONCURRENTLY idx_context_chunks_embedding_ivf 
    ON context_chopping.context_chunks 
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 200);  -- Optimal for 10K-100K vectors

-- Query patterns vector index 
CREATE INDEX CONCURRENTLY idx_query_patterns_embedding_ivf
    ON context_chopping.query_patterns 
    USING ivfflat (query_embedding vector_cosine_ops)
    WITH (lists = 50);   -- Smaller dataset, fewer lists

-- Set probes for optimal query performance (20% of lists)
-- This balances accuracy vs speed
SET ivfflat.probes = 40;  -- For context_chunks (200 lists * 0.2)

-- =============================================
-- SECTION 2: COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =============================================

-- Multi-column index for filtered vector searches by security + relevance
CREATE INDEX CONCURRENTLY idx_chunks_security_relevance_embedding
    ON context_chopping.context_chunks 
    USING ivfflat (embedding vector_cosine_ops)
    WHERE security_level IN ('public', 'internal') 
    AND current_relevance_score > 0.3
    WITH (lists = 100);

-- Composite index for file-based context retrieval
CREATE INDEX CONCURRENTLY idx_chunks_file_project_lines
    ON context_chopping.context_chunks (file_path, project_path, start_line, end_line)
    INCLUDE (token_count, current_relevance_score, language);

-- Performance tracking composite index
CREATE INDEX CONCURRENTLY idx_chunks_performance_tracking
    ON context_chopping.context_chunks (last_accessed DESC, access_count DESC)
    INCLUDE (success_count, current_relevance_score)
    WHERE access_count > 0;

-- Language and file type optimization
CREATE INDEX CONCURRENTLY idx_chunks_lang_type_complexity
    ON context_chopping.context_chunks (language, file_type, complexity_score DESC)
    WHERE language IS NOT NULL AND file_type IS NOT NULL;

-- =============================================
-- SECTION 3: PARTIAL INDEXES FOR FILTERED QUERIES
-- =============================================

-- High-performance index for frequently accessed content
CREATE INDEX CONCURRENTLY idx_chunks_hot_content
    ON context_chopping.context_chunks (current_relevance_score DESC, access_count DESC)
    WHERE access_count >= 5 AND current_relevance_score >= 0.5;

-- Security-filtered vector search (public content only)
CREATE INDEX CONCURRENTLY idx_chunks_public_embedding
    ON context_chopping.context_chunks 
    USING ivfflat (embedding vector_cosine_ops)
    WHERE security_level = 'public' AND contains_secrets = false
    WITH (lists = 150);

-- Recent content index for temporal relevance
CREATE INDEX CONCURRENTLY idx_chunks_recent_activity
    ON context_chopping.context_chunks (last_accessed DESC, last_modified DESC)
    WHERE last_accessed > (now() - interval '30 days');

-- Important sections index for priority content
CREATE INDEX CONCURRENTLY idx_chunks_important_sections
    ON context_chopping.context_chunks USING GIN (important_sections)
    WHERE important_sections IS NOT NULL AND jsonb_array_length(important_sections) > 0;

-- Dependencies index for relationship queries
CREATE INDEX CONCURRENTLY idx_chunks_dependencies_gin
    ON context_chopping.context_chunks USING GIN (dependencies)
    WHERE dependencies IS NOT NULL AND array_length(dependencies, 1) > 0;

-- =============================================
-- SECTION 4: QUERY PATTERNS OPTIMIZATION
-- =============================================

-- Query success pattern index
CREATE INDEX CONCURRENTLY idx_query_success_performance
    ON context_chopping.query_patterns (api_success, response_quality_score DESC, execution_time_ms ASC)
    WHERE api_success = true AND response_quality_score >= 0.7;

-- Token efficiency index
CREATE INDEX CONCURRENTLY idx_query_token_efficiency
    ON context_chopping.query_patterns (tokens_saved DESC, total_tokens_used ASC)
    WHERE tokens_saved > 0;

-- Security prevention tracking
CREATE INDEX CONCURRENTLY idx_query_security_prevention
    ON context_chopping.query_patterns (security_issues_prevented DESC, rejection_avoided)
    WHERE security_issues_prevented > 0 OR rejection_avoided = true;

-- Time-based performance analysis
CREATE INDEX CONCURRENTLY idx_query_time_analysis
    ON context_chopping.query_patterns (timestamp DESC, execution_time_ms ASC)
    INCLUDE (total_tokens_used, response_quality_score);

-- =============================================
-- SECTION 5: COVERING INDEXES TO ELIMINATE LOOKUPS
-- =============================================

-- Complete context retrieval covering index
CREATE INDEX CONCURRENTLY idx_chunks_complete_context
    ON context_chopping.context_chunks (chunk_id)
    INCLUDE (file_path, project_path, content, start_line, end_line, 
             token_count, current_relevance_score, security_level, 
             language, file_type, complexity_score, created_at);

-- Vector similarity with metadata covering index
CREATE INDEX CONCURRENTLY idx_chunks_vector_with_metadata
    ON context_chopping.context_chunks 
    USING ivfflat (embedding vector_cosine_ops)
    INCLUDE (file_path, token_count, current_relevance_score, security_level, language)
    WHERE embedding IS NOT NULL
    WITH (lists = 200);

-- Query pattern analysis covering index
CREATE INDEX CONCURRENTLY idx_query_analysis_complete
    ON context_chopping.query_patterns (pattern_id)
    INCLUDE (query_text, selected_chunk_ids, total_tokens_used, 
             api_success, response_quality_score, execution_time_ms,
             tokens_saved, timestamp);

-- =============================================
-- SECTION 6: PERFORMANCE MONITORING TABLES
-- =============================================

-- Table to track index usage and performance
CREATE TABLE IF NOT EXISTS context_chopping.index_performance_stats (
    stat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name text NOT NULL,
    index_name text NOT NULL,
    query_type text NOT NULL,
    execution_time_ms integer NOT NULL,
    rows_examined integer,
    rows_returned integer,
    index_scan_count integer DEFAULT 1,
    last_updated timestamp with time zone DEFAULT now()
);

-- Index on performance stats for monitoring
CREATE INDEX CONCURRENTLY idx_perf_stats_monitoring
    ON context_chopping.index_performance_stats (table_name, index_name, last_updated DESC);

-- =============================================
-- SECTION 7: VACUUM AND ANALYZE OPTIMIZATION
-- =============================================

-- Update statistics for all tables to ensure optimal query planning
ANALYZE context_chopping.context_chunks;
ANALYZE context_chopping.query_patterns;
ANALYZE context_chopping.learning_feedback;
ANALYZE context_chopping.performance_stats;

-- Set autovacuum parameters for optimal performance
ALTER TABLE context_chopping.context_chunks SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_cost_limit = 2000
);

ALTER TABLE context_chopping.query_patterns SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- =============================================
-- SECTION 8: MEMORY AND PERFORMANCE TUNING
-- =============================================

-- Optimize memory settings for vector operations
-- These should be set in postgresql.conf but can be set per session for testing

-- Increase work memory for sorting and hash operations
-- SET work_mem = '256MB';

-- Increase shared buffers for frequent access (if not already set)
-- SET shared_buffers = '2GB';

-- Optimize random page cost for SSD storage
-- SET random_page_cost = 1.1;

-- Increase effective cache size
-- SET effective_cache_size = '8GB';

-- Enable parallel query execution
-- SET max_parallel_workers_per_gather = 4;

COMMIT;

-- =============================================
-- SECTION 9: PERFORMANCE VALIDATION QUERIES
-- =============================================

-- Test vector similarity search performance
-- EXPLAIN (ANALYZE, BUFFERS, COSTS) 
-- SELECT chunk_id, file_path, current_relevance_score, 
--        embedding <-> '[0.1,0.2,0.3,...]'::vector as distance
-- FROM context_chopping.context_chunks 
-- WHERE security_level = 'public'
-- ORDER BY embedding <-> '[0.1,0.2,0.3,...]'::vector 
-- LIMIT 10;

-- Test composite query performance
-- EXPLAIN (ANALYZE, BUFFERS, COSTS)
-- SELECT cc.chunk_id, cc.file_path, cc.content, cc.current_relevance_score
-- FROM context_chopping.context_chunks cc
-- WHERE cc.language = 'python' 
--   AND cc.security_level IN ('public', 'internal')
--   AND cc.current_relevance_score > 0.5
--   AND cc.last_accessed > (now() - interval '7 days')
-- ORDER BY cc.current_relevance_score DESC, cc.access_count DESC
-- LIMIT 20;