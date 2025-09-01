-- Performance optimization for Intel Meteor Lake (22 cores, 64GB RAM)

-- Connection and memory settings
ALTER SYSTEM SET max_connections = 500;
ALTER SYSTEM SET shared_buffers = '1GB';
ALTER SYSTEM SET effective_cache_size = '62GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET maintenance_work_mem = '512MB';

-- Parallelism settings
ALTER SYSTEM SET max_worker_processes = 20;
ALTER SYSTEM SET max_parallel_workers_per_gather = 5;
ALTER SYSTEM SET max_parallel_workers = 10;
ALTER SYSTEM SET parallel_tuple_cost = 0.1;
ALTER SYSTEM SET parallel_setup_cost = 1000.0;

-- I/O and checkpoint settings
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '64MB';
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Query optimization
ALTER SYSTEM SET default_statistics_target = 1000;
ALTER SYSTEM SET constraint_exclusion = 'partition';

-- Logging for performance analysis
ALTER SYSTEM SET log_min_duration_statement = 1000;
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_lock_waits = on;

-- Extensions for monitoring
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements,pg_prewarm';
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.max = 10000;

-- Apply configuration
SELECT pg_reload_conf();

\echo 'Performance optimization applied'
