-- ============================================================================
-- CLAUDE AGENT FRAMEWORK - AUTHENTICATION DATABASE SETUP
-- ============================================================================
-- Database Agent Production Schema v2.0 - PostgreSQL 17 Optimized
-- Performance Target: >2000 auth/sec with <25ms P95 latency
-- Compatible with existing auth_security.h/.c implementation
-- Leverages PostgreSQL 17 features: Enhanced JSON, improved VACUUM, SQL/JSON
-- ============================================================================

-- Enable required extensions (PostgreSQL 17 compatible)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- PostgreSQL 17 performance optimizations
SET max_parallel_workers_per_gather = 4;
SET work_mem = '256MB';
SET maintenance_work_mem = '1GB';

-- Enable enhanced JSON performance features in PostgreSQL 17
SET log_statement_stats = OFF; -- Better performance for JSON operations

-- ============================================================================
-- USERS AND AUTHENTICATION
-- ============================================================================

-- Users table with secure password storage
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(256) NOT NULL UNIQUE,
    password_hash VARCHAR(256) NOT NULL, -- Argon2id hash from auth_security.c
    salt BYTEA NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    account_locked_until TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disabled', 'locked', 'pending')),
    password_changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    requires_password_change BOOLEAN DEFAULT FALSE,
    
    -- Security metadata for auth_security.c integration
    created_ip INET,
    last_login_ip INET,
    password_history JSONB DEFAULT JSON_ARRAY(), -- PostgreSQL 17 JSON constructor
    
    -- Audit fields
    created_by UUID,
    updated_by UUID,
    version INTEGER DEFAULT 1,
    
    CONSTRAINT users_username_length CHECK (char_length(username) >= 3),
    CONSTRAINT users_password_age CHECK (password_changed_at <= NOW())
);

-- High-performance indexes for authentication queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_username_active 
    ON users(username) WHERE status = 'active';
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_active 
    ON users(email) WHERE status = 'active';
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_last_login 
    ON users(last_login) WHERE status = 'active';
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_status_created 
    ON users(status, created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_locked_until 
    ON users(account_locked_until) WHERE account_locked_until > NOW();

-- User profiles for additional data
CREATE TABLE IF NOT EXISTS user_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    display_name VARCHAR(128),
    avatar_url TEXT,
    timezone VARCHAR(64) DEFAULT 'UTC',
    locale VARCHAR(10) DEFAULT 'en_US',
    preferences JSONB DEFAULT JSON_OBJECT(), -- PostgreSQL 17 JSON constructor
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_user_id 
    ON user_profiles(user_id);

-- ============================================================================
-- ROLE-BASED ACCESS CONTROL (RBAC)
-- ============================================================================

-- Roles table - compatible with auth_security.h agent_role_t
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(64) NOT NULL UNIQUE,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    role_level INTEGER DEFAULT 3, -- Maps to agent_role_t enum values
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    CONSTRAINT roles_name_format CHECK (role_name ~ '^[a-z0-9_]+$')
);

-- Insert system roles matching auth_security.h definitions
INSERT INTO roles (role_name, description, is_system_role, role_level) VALUES
('admin', 'System administrator with full access', TRUE, 1),
('system', 'System-level operations role', TRUE, 2), 
('agent', 'Standard agent role', TRUE, 3),
('monitor', 'Monitoring and observability role', TRUE, 4),
('guest', 'Read-only guest access', TRUE, 5)
ON CONFLICT (role_name) DO NOTHING;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roles_name 
    ON roles(role_name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roles_system 
    ON roles(is_system_role, role_name);

-- Permissions table - compatible with auth_security.h permission_t
CREATE TABLE IF NOT EXISTS permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_name VARCHAR(128) NOT NULL UNIQUE,
    resource_type VARCHAR(64) NOT NULL,
    resource_pattern VARCHAR(256), -- Glob pattern or specific resource
    action VARCHAR(32) NOT NULL,
    permission_value INTEGER NOT NULL, -- Bitmask value from auth_security.h
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT permissions_action_valid CHECK (
        action IN ('read', 'write', 'execute', 'admin', 'monitor', 'system')
    )
);

-- Insert permissions matching auth_security.h permission_t enum
INSERT INTO permissions (permission_name, resource_type, resource_pattern, action, permission_value, description) VALUES
('read', 'all', '*', 'read', 1, 'Read permission'),
('write', 'all', '*', 'write', 2, 'Write permission'), 
('execute', 'all', '*', 'execute', 4, 'Execute permission'),
('admin', 'all', '*', 'admin', 8, 'Admin permission'),
('monitor', 'all', '*', 'monitor', 16, 'Monitor permission'),
('system', 'all', '*', 'system', 32, 'System permission'),
('agents.read', 'agent', '*', 'read', 1, 'Read agent information'),
('agents.write', 'agent', '*', 'write', 2, 'Modify agent configuration'),
('agents.execute', 'agent', '*', 'execute', 4, 'Execute agent operations'),
('monitoring.read', 'metrics', '*', 'read', 16, 'Read monitoring data'),
('users.admin', 'user', '*', 'admin', 8, 'User administration')
ON CONFLICT (permission_name) DO NOTHING;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_permissions_name 
    ON permissions(permission_name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_permissions_resource 
    ON permissions(resource_type, action);

-- Role-Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
    role_permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    granted_by UUID,
    
    UNIQUE(role_id, permission_id)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_role_permissions_role 
    ON role_permissions(role_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_role_permissions_permission 
    ON role_permissions(permission_id);

-- User-Role mapping
CREATE TABLE IF NOT EXISTS user_roles (
    user_role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID,
    expires_at TIMESTAMP WITH TIME ZONE, -- Optional role expiration
    
    UNIQUE(user_id, role_id)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_roles_user 
    ON user_roles(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_roles_role 
    ON user_roles(role_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_roles_expires 
    ON user_roles(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================================
-- SESSION AND TOKEN MANAGEMENT
-- ============================================================================

-- Active sessions - compatible with JWT tokens from auth_security.c
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    jwt_token_id VARCHAR(64) NOT NULL, -- JWT jti claim from auth_security.c
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET NOT NULL,
    user_agent TEXT,
    device_fingerprint VARCHAR(256),
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Session metadata
    login_method VARCHAR(32) DEFAULT 'password',
    session_data JSONB DEFAULT JSON_OBJECT(), -- PostgreSQL 17 JSON constructor
    
    CONSTRAINT sessions_expiry_future CHECK (expires_at > created_at)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_user_active 
    ON user_sessions(user_id) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_token 
    ON user_sessions(jwt_token_id) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_expires 
    ON user_sessions(expires_at) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_activity 
    ON user_sessions(last_activity) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_sessions_ip 
    ON user_sessions(ip_address, created_at);

-- API Keys for service-to-service authentication
CREATE TABLE IF NOT EXISTS api_keys (
    api_key_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    key_name VARCHAR(128) NOT NULL,
    key_hash VARCHAR(256) NOT NULL, -- Hashed API key
    key_prefix VARCHAR(16) NOT NULL, -- First few chars for identification
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used TIMESTAMP WITH TIME ZONE,
    usage_count BIGINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    allowed_ips INET[] DEFAULT '{}',
    rate_limit_per_minute INTEGER DEFAULT 1000,
    
    -- Permissions for this API key
    scopes JSONB DEFAULT JSON_ARRAY(), -- PostgreSQL 17 JSON constructor
    
    UNIQUE(key_hash),
    CONSTRAINT api_keys_expiry_check CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_hash 
    ON api_keys(key_hash) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_prefix 
    ON api_keys(key_prefix) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_user 
    ON api_keys(user_id) WHERE is_active = TRUE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_expires 
    ON api_keys(expires_at) WHERE is_active = TRUE AND expires_at IS NOT NULL;

-- ============================================================================
-- SECURITY AUDIT AND LOGGING
-- ============================================================================

-- Security events log - compatible with auth_security.h security_event_type_t
CREATE TABLE IF NOT EXISTS security_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(32) NOT NULL,
    severity INTEGER NOT NULL CHECK (severity BETWEEN 1 AND 5),
    user_id UUID REFERENCES users(user_id),
    session_id UUID REFERENCES user_sessions(session_id),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    
    -- Event details
    description TEXT NOT NULL,
    details JSONB DEFAULT JSON_OBJECT(), -- PostgreSQL 17 JSON constructor
    
    -- Risk assessment
    risk_score INTEGER DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
    
    -- Incident tracking
    incident_id UUID,
    resolved BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT security_events_type_valid CHECK (
        event_type IN ('login_success', 'login_failure', 'token_issued', 'token_expired',
                      'permission_denied', 'rate_limit_exceeded', 'ddos_detected',
                      'key_rotated', 'tls_handshake', 'hmac_failure', 'account_locked',
                      'password_changed', 'role_assigned', 'suspicious_activity')
    )
);

-- Indexes for security event queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_timestamp 
    ON security_events(timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_user_time 
    ON security_events(user_id, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_type_time 
    ON security_events(event_type, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_severity 
    ON security_events(severity, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_ip 
    ON security_events(ip_address, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_risk 
    ON security_events(risk_score) WHERE risk_score > 50;

-- Audit trail for all database operations
CREATE TABLE IF NOT EXISTS audit_log (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(64) NOT NULL,
    operation VARCHAR(16) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id UUID,
    user_id UUID REFERENCES users(user_id),
    session_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Change tracking
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    
    -- Request context
    ip_address INET,
    user_agent TEXT,
    request_id UUID,
    
    -- Risk assessment
    risk_score INTEGER DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_timestamp 
    ON audit_log(timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_table_time 
    ON audit_log(table_name, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_user_time 
    ON audit_log(user_id, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_operation 
    ON audit_log(operation, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_risk 
    ON audit_log(risk_score) WHERE risk_score > 30;

-- Rate limiting tracking - compatible with auth_security.c rate limiting
CREATE TABLE IF NOT EXISTS rate_limit_events (
    rate_limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier VARCHAR(256) NOT NULL, -- IP, user_id, api_key, etc.
    identifier_type VARCHAR(32) NOT NULL, -- 'ip', 'user', 'api_key'
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    window_end TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER NOT NULL,
    limit_exceeded BOOLEAN DEFAULT FALSE,
    blocked_until TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(identifier, identifier_type, window_start)
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_rate_limit_identifier 
    ON rate_limit_events(identifier, identifier_type, window_start);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_rate_limit_blocked 
    ON rate_limit_events(blocked_until) WHERE blocked_until > NOW();

-- ============================================================================
-- PERFORMANCE OPTIMIZATION VIEWS
-- ============================================================================

-- Materialized view for fast user permission lookups
CREATE MATERIALIZED VIEW IF NOT EXISTS user_permissions_mv AS
SELECT 
    u.user_id, 
    u.username,
    u.status,
    ARRAY_AGG(DISTINCT r.role_name) FILTER (WHERE r.role_name IS NOT NULL) as roles,
    ARRAY_AGG(DISTINCT p.permission_name) FILTER (WHERE p.permission_name IS NOT NULL) as permissions,
    BIT_OR(p.permission_value) as permission_bitmask, -- For auth_security.c compatibility
    MAX(ur.assigned_at) as last_role_change
FROM users u
LEFT JOIN user_roles ur ON u.user_id = ur.user_id 
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
LEFT JOIN roles r ON ur.role_id = r.role_id
LEFT JOIN role_permissions rp ON r.role_id = rp.role_id
LEFT JOIN permissions p ON rp.permission_id = p.permission_id
WHERE u.status = 'active'
GROUP BY u.user_id, u.username, u.status;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_permissions_mv_user 
    ON user_permissions_mv(user_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_mv_username 
    ON user_permissions_mv(username);

-- ============================================================================
-- HIGH-PERFORMANCE AUTHENTICATION FUNCTIONS
-- ============================================================================

-- Fast authentication function compatible with auth_security.c
CREATE OR REPLACE FUNCTION authenticate_user(
    p_username VARCHAR(64),
    p_password_hash VARCHAR(256)
) RETURNS TABLE (
    user_id UUID,
    username VARCHAR(64),
    password_hash VARCHAR(256),
    salt BYTEA,
    status VARCHAR(20),
    failed_attempts INTEGER,
    locked_until TIMESTAMP WITH TIME ZONE,
    roles TEXT[],
    permissions TEXT[],
    permission_bitmask BIGINT
) 
LANGUAGE SQL
STABLE
AS $$
    SELECT 
        u.user_id,
        u.username,
        u.password_hash,
        u.salt,
        u.status,
        u.failed_login_attempts,
        u.account_locked_until,
        COALESCE(upm.roles, '{}') as roles,
        COALESCE(upm.permissions, '{}') as permissions,
        COALESCE(upm.permission_bitmask, 0) as permission_bitmask
    FROM users u
    LEFT JOIN user_permissions_mv upm ON u.user_id = upm.user_id
    WHERE u.username = p_username 
        AND u.status = 'active'
        AND (u.account_locked_until IS NULL OR u.account_locked_until <= NOW());
$$;

-- Fast session validation function
CREATE OR REPLACE FUNCTION validate_session(
    p_jwt_token_id VARCHAR(64)
) RETURNS TABLE (
    session_id UUID,
    user_id UUID,
    username VARCHAR(64),
    expires_at TIMESTAMP WITH TIME ZONE,
    permissions TEXT[],
    permission_bitmask BIGINT
)
LANGUAGE SQL
STABLE  
AS $$
    SELECT 
        s.session_id,
        s.user_id,
        u.username,
        s.expires_at,
        COALESCE(upm.permissions, '{}') as permissions,
        COALESCE(upm.permission_bitmask, 0) as permission_bitmask
    FROM user_sessions s
    JOIN users u ON s.user_id = u.user_id
    LEFT JOIN user_permissions_mv upm ON u.user_id = upm.user_id
    WHERE s.jwt_token_id = p_jwt_token_id 
        AND s.is_active = TRUE 
        AND s.expires_at > NOW()
        AND u.status = 'active';
$$;

-- Permission check function compatible with auth_security.c RBAC
CREATE OR REPLACE FUNCTION check_permission(
    p_user_id UUID,
    p_resource VARCHAR(256),
    p_required_permission INTEGER -- Bitmask from permission_t enum
) RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
    SELECT EXISTS(
        SELECT 1
        FROM user_permissions_mv upm
        WHERE upm.user_id = p_user_id
            AND (upm.permission_bitmask & p_required_permission) = p_required_permission
    );
$$;

-- ============================================================================
-- TRIGGERS FOR AUDIT LOGGING
-- ============================================================================

-- Function to refresh materialized view when roles change
CREATE OR REPLACE FUNCTION refresh_user_permissions()
RETURNS TRIGGER AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY user_permissions_mv;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers to refresh materialized view
DROP TRIGGER IF EXISTS refresh_user_permissions_trigger ON user_roles;
CREATE TRIGGER refresh_user_permissions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH STATEMENT EXECUTE FUNCTION refresh_user_permissions();

DROP TRIGGER IF EXISTS refresh_user_permissions_role_trigger ON role_permissions;  
CREATE TRIGGER refresh_user_permissions_role_trigger
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH STATEMENT EXECUTE FUNCTION refresh_user_permissions();

-- Audit logging trigger function
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    audit_user_id UUID;
    audit_session_id UUID;
BEGIN
    -- Get current user context (would be set by application)
    audit_user_id := current_setting('app.current_user_id', TRUE)::UUID;
    audit_session_id := current_setting('app.current_session_id', TRUE)::UUID;
    
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (
            table_name, operation, record_id, user_id, session_id,
            new_values, changed_fields
        ) VALUES (
            TG_TABLE_NAME, TG_OP, NEW.user_id, audit_user_id, audit_session_id,
            row_to_json(NEW), ARRAY[]::TEXT[]
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (
            table_name, operation, record_id, user_id, session_id,
            old_values, new_values, changed_fields
        ) VALUES (
            TG_TABLE_NAME, TG_OP, NEW.user_id, audit_user_id, audit_session_id,
            row_to_json(OLD), row_to_json(NEW),
            (SELECT ARRAY_AGG(key) FROM jsonb_each(to_jsonb(NEW)) WHERE to_jsonb(NEW) -> key != to_jsonb(OLD) -> key)
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (
            table_name, operation, record_id, user_id, session_id,
            old_values, changed_fields
        ) VALUES (
            TG_TABLE_NAME, TG_OP, OLD.user_id, audit_user_id, audit_session_id,
            row_to_json(OLD), ARRAY[]::TEXT[]
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to key tables
DROP TRIGGER IF EXISTS audit_users_trigger ON users;
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

DROP TRIGGER IF EXISTS audit_user_roles_trigger ON user_roles;
CREATE TRIGGER audit_user_roles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- ============================================================================
-- INITIAL DATA AND DEFAULT ADMIN USER
-- ============================================================================

-- Setup default role permissions
DO $$
DECLARE
    admin_role_id UUID;
    system_role_id UUID;
    agent_role_id UUID;
    monitor_role_id UUID;
    guest_role_id UUID;
    
    admin_perm_id UUID;
    system_perm_id UUID;
    read_perm_id UUID;
    write_perm_id UUID;
    execute_perm_id UUID;
    monitor_perm_id UUID;
BEGIN
    -- Get role IDs
    SELECT role_id INTO admin_role_id FROM roles WHERE role_name = 'admin';
    SELECT role_id INTO system_role_id FROM roles WHERE role_name = 'system';  
    SELECT role_id INTO agent_role_id FROM roles WHERE role_name = 'agent';
    SELECT role_id INTO monitor_role_id FROM roles WHERE role_name = 'monitor';
    SELECT role_id INTO guest_role_id FROM roles WHERE role_name = 'guest';
    
    -- Get permission IDs
    SELECT permission_id INTO admin_perm_id FROM permissions WHERE permission_name = 'admin';
    SELECT permission_id INTO system_perm_id FROM permissions WHERE permission_name = 'system';
    SELECT permission_id INTO read_perm_id FROM permissions WHERE permission_name = 'read';
    SELECT permission_id INTO write_perm_id FROM permissions WHERE permission_name = 'write';
    SELECT permission_id INTO execute_perm_id FROM permissions WHERE permission_name = 'execute';
    SELECT permission_id INTO monitor_perm_id FROM permissions WHERE permission_name = 'monitor';
    
    -- Assign permissions to roles
    INSERT INTO role_permissions (role_id, permission_id) VALUES
    -- Admin gets all permissions
    (admin_role_id, admin_perm_id),
    (admin_role_id, system_perm_id),
    (admin_role_id, read_perm_id),
    (admin_role_id, write_perm_id),
    (admin_role_id, execute_perm_id),
    (admin_role_id, monitor_perm_id),
    
    -- System gets system, read, write, execute
    (system_role_id, system_perm_id),
    (system_role_id, read_perm_id),
    (system_role_id, write_perm_id),
    (system_role_id, execute_perm_id),
    
    -- Agent gets read, write, execute
    (agent_role_id, read_perm_id),
    (agent_role_id, write_perm_id),
    (agent_role_id, execute_perm_id),
    
    -- Monitor gets read and monitor
    (monitor_role_id, read_perm_id),
    (monitor_role_id, monitor_perm_id),
    
    -- Guest gets only read
    (guest_role_id, read_perm_id)
    
    ON CONFLICT (role_id, permission_id) DO NOTHING;
END $$;

-- Create default admin user (compatible with auth_security.c)
DO $$
DECLARE
    admin_user_id UUID;
    admin_role_id UUID;
    salt BYTEA;
    password_hash VARCHAR(256);
BEGIN
    -- Check if admin user already exists
    SELECT user_id INTO admin_user_id FROM users WHERE username = 'admin';
    
    IF admin_user_id IS NULL THEN
        -- Generate salt and hash for default admin password
        -- In production, this should use Argon2id from auth_security.c
        salt := gen_random_bytes(32);
        password_hash := encode(digest('admin123' || encode(salt, 'hex'), 'sha256'), 'hex');
        
        -- Create admin user
        INSERT INTO users (user_id, username, email, password_hash, salt, status, created_ip)
        VALUES (gen_random_uuid(), 'admin', 'admin@claude-agents.local', password_hash, salt, 'active', '127.0.0.1'::INET)
        RETURNING user_id INTO admin_user_id;
        
        -- Get admin role
        SELECT role_id INTO admin_role_id FROM roles WHERE role_name = 'admin';
        
        -- Assign admin role
        INSERT INTO user_roles (user_id, role_id) VALUES (admin_user_id, admin_role_id);
        
        -- Create user profile
        INSERT INTO user_profiles (user_id, display_name) VALUES (admin_user_id, 'System Administrator');
        
        RAISE NOTICE 'Default admin user created with username: admin, password: admin123';
        RAISE NOTICE 'SECURITY WARNING: Change the default admin password immediately!';
    ELSE
        RAISE NOTICE 'Admin user already exists, skipping creation';
    END IF;
END $$;

-- Refresh materialized view
REFRESH MATERIALIZED VIEW user_permissions_mv;

-- ============================================================================
-- PERFORMANCE MONITORING VIEW
-- ============================================================================

CREATE OR REPLACE VIEW auth_performance_metrics AS
SELECT 
    'authentication_latency' as metric,
    AVG(EXTRACT(EPOCH FROM (se2.timestamp - se1.timestamp)) * 1000) as avg_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (se2.timestamp - se1.timestamp)) * 1000) as p95_ms,
    COUNT(*) as sample_size
FROM security_events se1
JOIN security_events se2 ON se1.session_id = se2.session_id 
    AND se2.timestamp > se1.timestamp
WHERE se1.event_type = 'login_success'
    AND se2.event_type = 'token_issued'
    AND se1.timestamp >= NOW() - INTERVAL '1 hour'

UNION ALL

SELECT 
    'session_creation_rate' as metric,
    COUNT(*)::FLOAT / GREATEST(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))), 1) * 60 as per_minute,
    NULL as p95_ms,
    COUNT(*) as sample_size
FROM user_sessions
WHERE created_at >= NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
    'concurrent_sessions' as metric,
    COUNT(*) as current_count,
    NULL as p95_ms,
    COUNT(*) as sample_size
FROM user_sessions
WHERE is_active = TRUE AND expires_at > NOW();

-- ============================================================================
-- CLEANUP AND MAINTENANCE PROCEDURES
-- ============================================================================

-- Cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER
LANGUAGE SQL
AS $$
    WITH deleted_sessions AS (
        DELETE FROM user_sessions 
        WHERE expires_at <= NOW() OR (is_active = FALSE AND last_activity < NOW() - INTERVAL '24 hours')
        RETURNING session_id
    )
    SELECT COUNT(*) FROM deleted_sessions;
$$;

-- Cleanup old audit logs (keep 90 days)
CREATE OR REPLACE FUNCTION cleanup_audit_logs()
RETURNS INTEGER
LANGUAGE SQL  
AS $$
    WITH deleted_logs AS (
        DELETE FROM audit_log 
        WHERE timestamp < NOW() - INTERVAL '90 days'
        RETURNING audit_id
    )
    SELECT COUNT(*) FROM deleted_logs;
$$;

-- Cleanup old security events (keep 30 days for high volume events)
CREATE OR REPLACE FUNCTION cleanup_security_events()
RETURNS INTEGER
LANGUAGE SQL
AS $$
    WITH deleted_events AS (
        DELETE FROM security_events 
        WHERE timestamp < NOW() - INTERVAL '30 days'
            AND event_type IN ('login_success', 'token_issued')
            AND severity <= 2
        RETURNING event_id
    )
    SELECT COUNT(*) FROM deleted_events;
$$;

COMMIT;

-- Final status message
SELECT 'Claude Agent Framework Authentication Database Setup Complete' as status,
       'Performance Target: >1000 auth/sec with <50ms P95 latency' as target,
       'Compatible with auth_security.h/.c implementation' as compatibility;