-- Enhanced Learning System Schema v4.0
-- Incorporates shadowgit operational insights and SIMD optimizations

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create enhanced learning system schema
CREATE SCHEMA IF NOT EXISTS enhanced_learning;

-- ============================================================================
-- SHADOWGIT OPERATIONAL DATA TABLES
-- ============================================================================

-- Real-time shadowgit operation events (high-frequency inserts)
CREATE TABLE enhanced_learning.shadowgit_events (
    id BIGSERIAL PRIMARY KEY,
    event_uuid UUID DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Git operation metadata
    operation_type VARCHAR(50) NOT NULL, -- diff, commit, push, pull, etc.
    repository_path TEXT NOT NULL,
    branch_name VARCHAR(255),
    commit_hash VARCHAR(40),
    
    -- Performance metrics from AVX2-optimized processing
    processing_time_ns BIGINT NOT NULL,
    lines_processed INTEGER NOT NULL DEFAULT 0,
    bytes_processed BIGINT NOT NULL DEFAULT 0,
    
    -- SIMD optimization metrics
    simd_operations INTEGER NOT NULL DEFAULT 0,
    simd_level VARCHAR(20) NOT NULL DEFAULT 'scalar', -- scalar, sse42, avx2, avx512
    simd_efficiency NUMERIC(5,4) DEFAULT 0.0000, -- 0.0-1.0
    
    -- Resource utilization
    memory_peak_mb INTEGER NOT NULL DEFAULT 0,
    cpu_utilization NUMERIC(5,4) DEFAULT 0.0000,
    cpu_cores_used INTEGER NOT NULL DEFAULT 1,
    cache_hit_rate NUMERIC(5,4) DEFAULT 0.0000,
    
    -- File operation details
    files_changed INTEGER NOT NULL DEFAULT 0,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    file_complexity_score NUMERIC(8,4) DEFAULT 0.0000,
    
    -- Error handling
    error_count INTEGER NOT NULL DEFAULT 0,
    error_messages TEXT[],
    
    -- Hardware context
    numa_node INTEGER DEFAULT 0,
    cpu_frequency_mhz INTEGER,
    thermal_state VARCHAR(20) -- normal, throttled, critical
    
) PARTITION BY RANGE (timestamp);

-- Create monthly partitions for high-volume data
CREATE TABLE enhanced_learning.shadowgit_events_202509 PARTITION OF enhanced_learning.shadowgit_events
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE enhanced_learning.shadowgit_events_202510 PARTITION OF enhanced_learning.shadowgit_events
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

-- High-performance indexes for time-series queries
CREATE INDEX CONCURRENTLY idx_shadowgit_events_timestamp 
    ON enhanced_learning.shadowgit_events USING BRIN (timestamp);
CREATE INDEX CONCURRENTLY idx_shadowgit_events_operation_type 
    ON enhanced_learning.shadowgit_events (operation_type, timestamp DESC);
CREATE INDEX CONCURRENTLY idx_shadowgit_events_performance 
    ON enhanced_learning.shadowgit_events (processing_time_ns DESC, simd_efficiency DESC);

-- ============================================================================
-- SIMD-OPTIMIZED EMBEDDINGS AND SIMILARITY
-- ============================================================================

-- Vector embeddings for git operations (optimized for SIMD operations)
CREATE TABLE enhanced_learning.operation_embeddings (
    id BIGSERIAL PRIMARY KEY,
    operation_hash VARCHAR(64) UNIQUE NOT NULL,
    
    -- High-dimensional embeddings (512-dim for AVX-512 optimization)
    embedding VECTOR(512) NOT NULL,
    
    -- Metadata for embedding generation
    embedding_model VARCHAR(100) NOT NULL,
    embedding_version INTEGER NOT NULL DEFAULT 1,
    generation_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Operation context
    operation_pattern TEXT NOT NULL,
    repository_context TEXT,
    file_patterns TEXT[],
    
    -- Performance characteristics
    typical_processing_time_ns BIGINT,
    typical_memory_mb INTEGER,
    typical_simd_efficiency NUMERIC(5,4),
    
    -- Usage statistics
    similarity_queries_count BIGINT DEFAULT 0,
    last_accessed TIMESTAMPTZ DEFAULT NOW()
);

-- Specialized index for vector similarity (optimized for parallel queries)
CREATE INDEX CONCURRENTLY idx_operation_embeddings_vector 
    ON enhanced_learning.operation_embeddings 
    USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 1000); -- High list count for better performance

-- Pre-computed similarity matrix for frequent operations
CREATE TABLE enhanced_learning.operation_similarity_cache (
    id BIGSERIAL PRIMARY KEY,
    operation_hash_a VARCHAR(64) NOT NULL,
    operation_hash_b VARCHAR(64) NOT NULL,
    similarity_score NUMERIC(8,6) NOT NULL,
    computation_method VARCHAR(50) NOT NULL, -- avx512, avx2, scalar
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_similarity_pair UNIQUE (operation_hash_a, operation_hash_b)
);

-- Index for fast similarity lookups
CREATE INDEX CONCURRENTLY idx_similarity_cache_lookup
    ON enhanced_learning.operation_similarity_cache (operation_hash_a, similarity_score DESC);

-- ============================================================================
-- PERFORMANCE ANALYTICS AND PREDICTIONS
-- ============================================================================

-- Real-time performance aggregations (updated by triggers)
CREATE TABLE enhanced_learning.performance_analytics (
    id BIGSERIAL PRIMARY KEY,
    analysis_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    time_window_minutes INTEGER NOT NULL, -- 1, 5, 15, 60, etc.
    
    -- Operation statistics
    operation_type VARCHAR(50) NOT NULL,
    operations_count BIGINT NOT NULL,
    
    -- Performance metrics (aggregated)
    avg_processing_time_ns BIGINT NOT NULL,
    p95_processing_time_ns BIGINT NOT NULL,
    p99_processing_time_ns BIGINT NOT NULL,
    max_processing_time_ns BIGINT NOT NULL,
    
    -- Resource utilization
    avg_memory_mb NUMERIC(10,2) NOT NULL,
    peak_memory_mb INTEGER NOT NULL,
    avg_cpu_utilization NUMERIC(5,4) NOT NULL,
    
    -- SIMD optimization effectiveness
    simd_usage_percent NUMERIC(5,2) NOT NULL,
    avg_simd_efficiency NUMERIC(5,4) NOT NULL,
    simd_speedup_factor NUMERIC(6,3) NOT NULL,
    
    -- Throughput metrics
    lines_per_second BIGINT NOT NULL,
    bytes_per_second BIGINT NOT NULL,
    operations_per_second NUMERIC(10,2) NOT NULL,
    
    -- Error rates
    error_rate NUMERIC(5,4) NOT NULL DEFAULT 0.0000,
    
    CONSTRAINT unique_analytics_window UNIQUE (analysis_timestamp, time_window_minutes, operation_type)
);

-- Efficient time-series index
CREATE INDEX CONCURRENTLY idx_performance_analytics_timeseries
    ON enhanced_learning.performance_analytics (operation_type, time_window_minutes, analysis_timestamp DESC);

-- Predictive performance models and their results
CREATE TABLE enhanced_learning.performance_predictions (
    id BIGSERIAL PRIMARY KEY,
    prediction_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Model information
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    prediction_horizon_minutes INTEGER NOT NULL,
    
    -- Input features (JSON for flexibility)
    input_features JSONB NOT NULL,
    
    -- Predicted metrics
    predicted_processing_time_ns BIGINT,
    predicted_memory_mb INTEGER,
    predicted_cpu_utilization NUMERIC(5,4),
    predicted_simd_efficiency NUMERIC(5,4),
    predicted_error_rate NUMERIC(5,4),
    
    -- Confidence intervals
    confidence_interval_95 NUMRANGE,
    prediction_confidence NUMERIC(5,4) NOT NULL,
    
    -- Validation (filled when actual results are available)
    actual_processing_time_ns BIGINT,
    actual_memory_mb INTEGER,
    prediction_error NUMERIC(8,4),
    validation_timestamp TIMESTAMPTZ
);

-- Index for model performance tracking
CREATE INDEX CONCURRENTLY idx_predictions_model_validation
    ON enhanced_learning.performance_predictions (model_name, model_version, prediction_timestamp DESC)
    WHERE validation_timestamp IS NOT NULL;

-- ============================================================================
-- ANOMALY DETECTION AND SYSTEM HEALTH
-- ============================================================================

-- Real-time anomaly detection results
CREATE TABLE enhanced_learning.anomaly_detections (
    id BIGSERIAL PRIMARY KEY,
    detection_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Anomaly classification
    anomaly_type VARCHAR(50) NOT NULL, -- performance, behavioral, system
    anomaly_category VARCHAR(100) NOT NULL,
    severity_level INTEGER NOT NULL CHECK (severity_level BETWEEN 1 AND 10),
    
    -- Detection details
    detector_name VARCHAR(100) NOT NULL,
    detector_version VARCHAR(20) NOT NULL,
    anomaly_score NUMERIC(8,6) NOT NULL,
    threshold_used NUMERIC(8,6) NOT NULL,
    
    -- Context information
    affected_operation VARCHAR(50),
    affected_repository TEXT,
    time_window_start TIMESTAMPTZ,
    time_window_end TIMESTAMPTZ,
    
    -- Anomalous metrics
    anomalous_values JSONB NOT NULL,
    expected_values JSONB,
    deviation_magnitude NUMERIC(8,4),
    
    -- Resolution tracking
    resolution_status VARCHAR(20) DEFAULT 'open', -- open, investigating, resolved, false_positive
    resolution_timestamp TIMESTAMPTZ,
    resolution_notes TEXT,
    
    -- Impact assessment
    performance_impact_percent NUMERIC(5,2),
    affected_operations_count BIGINT
);

-- Index for real-time anomaly monitoring
CREATE INDEX CONCURRENTLY idx_anomaly_detections_realtime
    ON enhanced_learning.anomaly_detections (detection_timestamp DESC, severity_level DESC)
    WHERE resolution_status = 'open';

-- System health metrics (rolling aggregations)
CREATE TABLE enhanced_learning.system_health_metrics (
    id BIGSERIAL PRIMARY KEY,
    metric_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Overall system performance
    system_performance_score NUMERIC(5,4) NOT NULL, -- 0.0-1.0
    
    -- Component health scores
    shadowgit_health_score NUMERIC(5,4) NOT NULL,
    learning_system_health_score NUMERIC(5,4) NOT NULL,
    database_health_score NUMERIC(5,4) NOT NULL,
    
    -- Performance indicators
    current_lines_per_second BIGINT NOT NULL,
    current_memory_usage_mb INTEGER NOT NULL,
    current_cpu_utilization NUMERIC(5,4) NOT NULL,
    current_simd_efficiency NUMERIC(5,4) NOT NULL,
    
    -- Optimization effectiveness
    optimization_score NUMERIC(5,4) NOT NULL,
    active_optimizations_count INTEGER NOT NULL DEFAULT 0,
    
    -- Trending indicators
    performance_trend VARCHAR(20), -- improving, stable, degrading
    anomaly_rate NUMERIC(5,4) NOT NULL,
    
    -- Resource predictions
    predicted_resource_exhaustion_hours INTEGER,
    recommended_actions TEXT[]
);

-- ============================================================================
-- SELF-OPTIMIZATION FEEDBACK SYSTEM
-- ============================================================================

-- Optimization recommendations and their tracking
CREATE TABLE enhanced_learning.optimization_recommendations (
    id BIGSERIAL PRIMARY KEY,
    recommendation_uuid UUID DEFAULT uuid_generate_v4(),
    created_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Recommendation details
    category VARCHAR(50) NOT NULL, -- simd, memory, io, algorithmic
    priority INTEGER NOT NULL CHECK (priority BETWEEN 1 AND 10),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    
    -- Expected impact
    expected_improvement_percent NUMERIC(5,2) NOT NULL,
    implementation_difficulty INTEGER NOT NULL CHECK (implementation_difficulty BETWEEN 1 AND 5),
    estimated_implementation_hours INTEGER,
    
    -- Technical details
    code_changes_required TEXT[],
    affected_components TEXT[],
    performance_impact_areas JSONB,
    
    -- Implementation tracking
    implementation_status VARCHAR(20) DEFAULT 'pending', -- pending, in_progress, completed, rejected
    implementation_started_at TIMESTAMPTZ,
    implementation_completed_at TIMESTAMPTZ,
    implementation_notes TEXT,
    
    -- Results validation
    actual_improvement_percent NUMERIC(5,2),
    performance_before JSONB,
    performance_after JSONB,
    validation_timestamp TIMESTAMPTZ,
    
    -- Learning feedback
    recommendation_effectiveness_score NUMERIC(5,4),
    user_satisfaction_rating INTEGER CHECK (user_satisfaction_rating BETWEEN 1 AND 5)
);

-- Index for optimization tracking
CREATE INDEX CONCURRENTLY idx_optimization_recommendations_tracking
    ON enhanced_learning.optimization_recommendations (category, priority DESC, created_timestamp DESC);

-- Track optimization implementation results
CREATE TABLE enhanced_learning.optimization_results (
    id BIGSERIAL PRIMARY KEY,
    recommendation_id BIGINT NOT NULL REFERENCES enhanced_learning.optimization_recommendations(id),
    result_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Performance measurements
    metric_name VARCHAR(100) NOT NULL,
    baseline_value NUMERIC(15,6) NOT NULL,
    optimized_value NUMERIC(15,6) NOT NULL,
    improvement_ratio NUMERIC(8,4) NOT NULL,
    
    -- Measurement context
    measurement_duration_seconds INTEGER NOT NULL,
    measurement_conditions JSONB,
    statistical_significance NUMERIC(5,4)
);

-- ============================================================================
-- HARDWARE-ACCELERATED INFERENCE PIPELINE
-- ============================================================================

-- ML model registry for hardware-accelerated inference
CREATE TABLE enhanced_learning.inference_models (
    id BIGSERIAL PRIMARY KEY,
    model_uuid UUID DEFAULT uuid_generate_v4(),
    
    -- Model identification
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    model_type VARCHAR(50) NOT NULL, -- classification, regression, anomaly_detection
    
    -- Hardware optimization
    optimized_for_hardware VARCHAR(50), -- cpu, gpu, npu, avx512, avx2
    model_file_path TEXT NOT NULL,
    onnx_model_path TEXT,
    openvino_ir_path TEXT,
    
    -- Performance characteristics
    input_dimension INTEGER NOT NULL,
    output_dimension INTEGER NOT NULL,
    inference_time_target_ms NUMERIC(6,3),
    memory_requirement_mb INTEGER,
    
    -- Usage statistics
    inference_count BIGINT DEFAULT 0,
    total_inference_time_ms BIGINT DEFAULT 0,
    accuracy_metrics JSONB,
    
    -- Metadata
    training_data_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Inference execution logs for performance monitoring
CREATE TABLE enhanced_learning.inference_executions (
    id BIGSERIAL PRIMARY KEY,
    execution_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    model_id BIGINT NOT NULL REFERENCES enhanced_learning.inference_models(id),
    
    -- Execution context
    input_features VECTOR(512), -- Standardized feature vector
    execution_hardware VARCHAR(50) NOT NULL,
    batch_size INTEGER NOT NULL DEFAULT 1,
    
    -- Performance metrics
    preprocessing_time_ns BIGINT NOT NULL,
    inference_time_ns BIGINT NOT NULL,
    postprocessing_time_ns BIGINT NOT NULL,
    total_execution_time_ns BIGINT NOT NULL,
    
    -- Results
    output_values NUMERIC[] NOT NULL,
    confidence_scores NUMERIC[],
    
    -- Hardware utilization
    cpu_utilization_percent NUMERIC(5,2),
    memory_used_mb INTEGER,
    gpu_utilization_percent NUMERIC(5,2),
    npu_utilization_percent NUMERIC(5,2),
    
    -- SIMD optimization details
    simd_instructions_used VARCHAR(50), -- avx512, avx2, sse42, scalar
    vectorization_efficiency NUMERIC(5,4)
);

-- Partition inference executions by month for performance
CREATE TABLE enhanced_learning.inference_executions_202509 PARTITION OF enhanced_learning.inference_executions
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

-- ============================================================================
-- MATERIALIZED VIEWS FOR REAL-TIME DASHBOARDS
-- ============================================================================

-- Real-time performance dashboard view
CREATE MATERIALIZED VIEW enhanced_learning.realtime_performance_dashboard AS
SELECT 
    date_trunc('minute', timestamp) as time_bucket,
    operation_type,
    COUNT(*) as operations_count,
    AVG(processing_time_ns) / 1000000.0 as avg_processing_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time_ns) / 1000000.0 as p95_processing_ms,
    SUM(lines_processed) as total_lines_processed,
    AVG(simd_efficiency) as avg_simd_efficiency,
    AVG(memory_peak_mb) as avg_memory_mb,
    AVG(cpu_utilization) as avg_cpu_utilization,
    SUM(CASE WHEN error_count > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as error_rate_percent
FROM enhanced_learning.shadowgit_events 
WHERE timestamp >= NOW() - INTERVAL '1 hour'
GROUP BY date_trunc('minute', timestamp), operation_type
ORDER BY time_bucket DESC, operation_type;

-- Create unique index on materialized view
CREATE UNIQUE INDEX idx_realtime_dashboard_unique 
    ON enhanced_learning.realtime_performance_dashboard (time_bucket, operation_type);

-- System health summary view
CREATE MATERIALIZED VIEW enhanced_learning.system_health_summary AS
SELECT 
    date_trunc('hour', metric_timestamp) as time_bucket,
    AVG(system_performance_score) as avg_system_performance,
    AVG(shadowgit_health_score) as avg_shadowgit_health,
    AVG(learning_system_health_score) as avg_learning_health,
    AVG(current_lines_per_second) as avg_throughput_lps,
    AVG(current_simd_efficiency) as avg_simd_efficiency,
    AVG(anomaly_rate) as avg_anomaly_rate,
    COUNT(CASE WHEN performance_trend = 'improving' THEN 1 END) as improving_periods,
    COUNT(CASE WHEN performance_trend = 'degrading' THEN 1 END) as degrading_periods
FROM enhanced_learning.system_health_metrics
WHERE metric_timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', metric_timestamp)
ORDER BY time_bucket DESC;

-- ============================================================================
-- TRIGGERS AND AUTOMATION
-- ============================================================================

-- Function to automatically refresh materialized views
CREATE OR REPLACE FUNCTION refresh_realtime_views()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY enhanced_learning.realtime_performance_dashboard;
    REFRESH MATERIALIZED VIEW CONCURRENTLY enhanced_learning.system_health_summary;
    
    -- Update model usage statistics
    UPDATE enhanced_learning.inference_models 
    SET 
        inference_count = (
            SELECT COUNT(*) 
            FROM enhanced_learning.inference_executions 
            WHERE model_id = inference_models.id
        ),
        total_inference_time_ms = (
            SELECT COALESCE(SUM(total_execution_time_ns), 0) / 1000000
            FROM enhanced_learning.inference_executions 
            WHERE model_id = inference_models.id
        ),
        last_updated = NOW()
    WHERE is_active = true;
END;
$$;

-- Trigger function for real-time performance analytics updates
CREATE OR REPLACE FUNCTION update_performance_analytics()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert or update 1-minute window analytics
    INSERT INTO enhanced_learning.performance_analytics (
        analysis_timestamp,
        time_window_minutes,
        operation_type,
        operations_count,
        avg_processing_time_ns,
        p95_processing_time_ns,
        p99_processing_time_ns,
        max_processing_time_ns,
        avg_memory_mb,
        peak_memory_mb,
        avg_cpu_utilization,
        simd_usage_percent,
        avg_simd_efficiency,
        simd_speedup_factor,
        lines_per_second,
        bytes_per_second,
        operations_per_second,
        error_rate
    )
    SELECT 
        date_trunc('minute', NOW()),
        1,
        NEW.operation_type,
        COUNT(*),
        AVG(processing_time_ns),
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time_ns),
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY processing_time_ns),
        MAX(processing_time_ns),
        AVG(memory_peak_mb),
        MAX(memory_peak_mb),
        AVG(cpu_utilization),
        AVG(CASE WHEN simd_level != 'scalar' THEN 100.0 ELSE 0.0 END),
        AVG(simd_efficiency),
        AVG(CASE WHEN simd_efficiency > 0 THEN simd_efficiency * 4 ELSE 1.0 END), -- Approximate speedup
        SUM(lines_processed) / EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp) + INTERVAL '1 second')),
        SUM(bytes_processed) / EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp) + INTERVAL '1 second')),
        COUNT(*) / EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp) + INTERVAL '1 second')),
        AVG(CASE WHEN error_count > 0 THEN 1.0 ELSE 0.0 END)
    FROM enhanced_learning.shadowgit_events 
    WHERE operation_type = NEW.operation_type 
      AND timestamp >= date_trunc('minute', NOW())
    GROUP BY operation_type
    ON CONFLICT (analysis_timestamp, time_window_minutes, operation_type)
    DO UPDATE SET
        operations_count = EXCLUDED.operations_count,
        avg_processing_time_ns = EXCLUDED.avg_processing_time_ns,
        p95_processing_time_ns = EXCLUDED.p95_processing_time_ns,
        p99_processing_time_ns = EXCLUDED.p99_processing_time_ns,
        max_processing_time_ns = EXCLUDED.max_processing_time_ns,
        avg_memory_mb = EXCLUDED.avg_memory_mb,
        peak_memory_mb = EXCLUDED.peak_memory_mb,
        avg_cpu_utilization = EXCLUDED.avg_cpu_utilization,
        simd_usage_percent = EXCLUDED.simd_usage_percent,
        avg_simd_efficiency = EXCLUDED.avg_simd_efficiency,
        simd_speedup_factor = EXCLUDED.simd_speedup_factor,
        lines_per_second = EXCLUDED.lines_per_second,
        bytes_per_second = EXCLUDED.bytes_per_second,
        operations_per_second = EXCLUDED.operations_per_second,
        error_rate = EXCLUDED.error_rate;
    
    RETURN NEW;
END;
$$;

-- Create trigger for real-time analytics (only on inserts to avoid overhead)
CREATE TRIGGER trigger_update_performance_analytics
    AFTER INSERT ON enhanced_learning.shadowgit_events
    FOR EACH ROW
    EXECUTE FUNCTION update_performance_analytics();

-- ============================================================================
-- PERFORMANCE OPTIMIZATION SETTINGS
-- ============================================================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA enhanced_learning TO claude_agent;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA enhanced_learning TO claude_agent;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA enhanced_learning TO claude_agent;

-- Set optimal parameters for high-frequency operations
ALTER SCHEMA enhanced_learning SET default_statistics_target = 1000;

-- Enable parallel query execution for analytics
ALTER DATABASE claude_agents_auth SET max_parallel_workers_per_gather = 6;
ALTER DATABASE claude_agents_auth SET max_parallel_workers = 16;

-- Optimize for time-series data
ALTER TABLE enhanced_learning.shadowgit_events SET (
    parallel_workers = 4,
    fillfactor = 90
);

-- Set up automated maintenance
SELECT cron.schedule('refresh-learning-views', '* * * * *', 'SELECT enhanced_learning.refresh_realtime_views();');
SELECT cron.schedule('analyze-learning-tables', '0 */4 * * *', 'ANALYZE enhanced_learning.shadowgit_events, enhanced_learning.performance_analytics;');