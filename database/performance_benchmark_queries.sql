-- PERFORMANCE BENCHMARK QUERIES FOR PGVECTOR OPTIMIZATION
-- PostgreSQL 16 with pgvector extension
-- Target: Validate 10-100x performance improvement
-- Author: DATABASE Agent
-- Date: 2025-09-02

-- =============================================
-- BENCHMARK SETUP: CREATE TEST DATA IF NEEDED
-- =============================================

-- Function to generate random vectors for testing
CREATE OR REPLACE FUNCTION context_chopping.generate_random_vector(dim integer)
RETURNS vector AS $$
DECLARE
    result float4[];
    i integer;
BEGIN
    result := ARRAY[]::float4[];
    FOR i IN 1..dim LOOP
        result := array_append(result, (random() - 0.5) * 2.0);
    END LOOP;
    RETURN result::vector;
END;
$$ LANGUAGE plpgsql;

-- Insert test data if table is empty (for benchmarking)
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM context_chopping.context_chunks) = 0 THEN
        INSERT INTO context_chopping.context_chunks 
        (file_path, project_path, content, content_hash, start_line, end_line, 
         token_count, current_relevance_score, security_level, language, file_type,
         complexity_score, embedding)
        SELECT 
            '/test/file_' || i || '.py',
            '/test/project',
            'Test content for chunk ' || i,
            md5('test_content_' || i),
            i,
            i + 10,
            100 + (i % 500),
            random(),
            CASE (i % 5) 
                WHEN 0 THEN 'public'
                WHEN 1 THEN 'internal' 
                WHEN 2 THEN 'sensitive'
                ELSE 'public'
            END,
            CASE (i % 4)
                WHEN 0 THEN 'python'
                WHEN 1 THEN 'javascript'
                WHEN 2 THEN 'sql'
                ELSE 'markdown'
            END,
            CASE (i % 3)
                WHEN 0 THEN 'py'
                WHEN 1 THEN 'js'  
                ELSE 'md'
            END,
            random() * 10,
            context_chopping.generate_random_vector(512)
        FROM generate_series(1, 10000) i;
        
        RAISE NOTICE 'Inserted 10,000 test records for benchmarking';
    END IF;
END $$;

-- =============================================
-- BENCHMARK 1: VECTOR SIMILARITY SEARCH
-- =============================================

-- Benchmark basic vector similarity (should be <10ms for 1M vectors, <2ms for 10K)
\timing on
\echo '\n=== BENCHMARK 1: Vector Similarity Search ==='

-- Create test query vector
\set test_vector '''[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0]'''

-- Test 1: Basic vector similarity search
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT chunk_id, file_path, current_relevance_score,
       embedding <-> :test_vector::vector as distance
FROM context_chopping.context_chunks 
ORDER BY embedding <-> :test_vector::vector
LIMIT 10;

-- Test 2: Filtered vector similarity search with security
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT chunk_id, file_path, current_relevance_score,
       embedding <-> :test_vector::vector as distance
FROM context_chopping.context_chunks 
WHERE security_level = 'public'
ORDER BY embedding <-> :test_vector::vector
LIMIT 10;

-- =============================================
-- BENCHMARK 2: CONTEXT CHUNK RETRIEVAL
-- =============================================

\echo '\n=== BENCHMARK 2: Context Chunk Retrieval ==='

-- Test 3: Multi-column filtered retrieval (should be <5ms)
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT chunk_id, file_path, content, current_relevance_score, token_count
FROM context_chopping.context_chunks
WHERE language = 'python' 
  AND security_level IN ('public', 'internal')
  AND current_relevance_score > 0.5
  AND token_count BETWEEN 100 AND 500
ORDER BY current_relevance_score DESC, access_count DESC
LIMIT 20;

-- Test 4: File-based context retrieval with line ranges
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT chunk_id, file_path, start_line, end_line, content, token_count
FROM context_chopping.context_chunks
WHERE file_path LIKE '/test/file_%'
  AND project_path = '/test/project'
  AND start_line >= 1 AND end_line <= 100
ORDER BY start_line, end_line;

-- =============================================
-- BENCHMARK 3: COMPOSITE QUERY PATTERNS
-- =============================================

\echo '\n=== BENCHMARK 3: Composite Query Patterns ==='

-- Test 5: Complex multi-table join with vector similarity
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT cc.chunk_id, cc.file_path, cc.current_relevance_score,
       qp.query_text, qp.response_quality_score,
       cc.embedding <-> :test_vector::vector as distance
FROM context_chopping.context_chunks cc
JOIN context_chopping.query_patterns qp ON cc.chunk_id = ANY(qp.selected_chunk_ids)
WHERE cc.security_level = 'public'
  AND qp.api_success = true
  AND qp.response_quality_score > 0.7
  AND cc.current_relevance_score > 0.3
ORDER BY cc.embedding <-> :test_vector::vector, qp.response_quality_score DESC
LIMIT 15;

-- Test 6: Performance analytics query (should be <2ms with composite indexes)
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT language, file_type, 
       COUNT(*) as chunk_count,
       AVG(current_relevance_score) as avg_relevance,
       AVG(access_count) as avg_access,
       MAX(complexity_score) as max_complexity
FROM context_chopping.context_chunks
WHERE access_count > 0
  AND last_accessed > (now() - interval '30 days')
GROUP BY language, file_type
ORDER BY avg_relevance DESC, chunk_count DESC;

-- =============================================
-- BENCHMARK 4: COVERING INDEX TESTS
-- =============================================

\echo '\n=== BENCHMARK 4: Covering Index Performance ==='

-- Test 7: Query using covering index (should eliminate heap lookups)
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT chunk_id, file_path, project_path, start_line, end_line, 
       token_count, current_relevance_score, security_level, language
FROM context_chopping.context_chunks
WHERE current_relevance_score > 0.7
ORDER BY current_relevance_score DESC
LIMIT 25;

-- Test 8: Vector search with metadata (covering index test)
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT file_path, token_count, current_relevance_score, security_level, language,
       embedding <-> :test_vector::vector as distance
FROM context_chopping.context_chunks
WHERE embedding IS NOT NULL
ORDER BY embedding <-> :test_vector::vector
LIMIT 20;

-- =============================================
-- BENCHMARK 5: AGGREGATION AND ANALYTICS
-- =============================================

\echo '\n=== BENCHMARK 5: Aggregation and Analytics ==='

-- Test 9: Security-level analytics
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT security_level,
       COUNT(*) as total_chunks,
       AVG(token_count) as avg_tokens,
       AVG(current_relevance_score) as avg_relevance,
       SUM(access_count) as total_accesses
FROM context_chopping.context_chunks
GROUP BY security_level
ORDER BY total_chunks DESC;

-- Test 10: Time-based performance analysis
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT DATE(last_accessed) as access_date,
       COUNT(*) as chunks_accessed,
       AVG(current_relevance_score) as avg_relevance,
       SUM(access_count) as total_accesses
FROM context_chopping.context_chunks
WHERE last_accessed > (now() - interval '7 days')
GROUP BY DATE(last_accessed)
ORDER BY access_date DESC;

-- =============================================
-- BENCHMARK 6: SPECIALIZED VECTOR OPERATIONS
-- =============================================

\echo '\n=== BENCHMARK 6: Specialized Vector Operations ==='

-- Test 11: Batch vector similarity (multiple queries)
EXPLAIN (ANALYZE, BUFFERS, COSTS)
WITH query_vectors AS (
    SELECT generate_series(1, 5) as query_id, 
           context_chopping.generate_random_vector(512) as query_vec
),
similarities AS (
    SELECT qv.query_id, cc.chunk_id, cc.file_path,
           cc.embedding <-> qv.query_vec as distance
    FROM query_vectors qv
    CROSS JOIN context_chopping.context_chunks cc
    WHERE cc.embedding IS NOT NULL
)
SELECT query_id, chunk_id, file_path, distance
FROM similarities
WHERE distance < 1.5  -- Similarity threshold
ORDER BY query_id, distance
LIMIT 50;

-- Test 12: Vector clustering analysis
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT language, security_level,
       COUNT(*) as cluster_size,
       AVG(current_relevance_score) as avg_relevance,
       -- Vector centroid approximation using first vector as representative
       (SELECT embedding FROM context_chopping.context_chunks cc2 
        WHERE cc2.language = cc.language AND cc2.security_level = cc.security_level
        LIMIT 1) as representative_vector
FROM context_chopping.context_chunks cc
WHERE embedding IS NOT NULL
GROUP BY language, security_level
HAVING COUNT(*) >= 10
ORDER BY cluster_size DESC;

-- =============================================
-- BENCHMARK SUMMARY AND CLEANUP
-- =============================================

\timing off

\echo '\n=== BENCHMARK COMPLETE ==='
\echo 'Performance Targets:'
\echo '- Vector similarity search: <10ms for 1M vectors, <2ms for 10K vectors'
\echo '- Context chunk retrieval: <5ms for relevance-based selection'
\echo '- Query pattern matching: <2ms with composite indexes'
\echo '- Target: 10-100x improvement over non-indexed queries'
\echo ''
\echo 'Review EXPLAIN ANALYZE output above to verify performance targets are met.'
\echo 'Look for:'
\echo '- Index Scan instead of Seq Scan'
\echo '- Low "actual time" values in milliseconds'
\echo '- High "rows" values with low "loops" values'
\echo '- Minimal "Buffers" usage indicating efficient memory utilization'

-- Optional: Drop test data if it was created for benchmarking
-- TRUNCATE context_chopping.context_chunks;
-- DROP FUNCTION context_chopping.generate_random_vector(integer);