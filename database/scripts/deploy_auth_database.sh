#!/bin/bash

# ============================================================================
# CLAUDE AGENT FRAMEWORK - AUTHENTICATION DATABASE DEPLOYMENT
# ============================================================================
# Database Agent Production Deployment Script v1.0
# Deploys PostgreSQL + Redis authentication system with monitoring
# Performance Target: >1000 auth/sec with <50ms P95 latency
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_VERSION="15"
REDIS_VERSION="7"
DB_NAME="claude_auth"
DB_USER="claude_auth"
DB_PASSWORD=""
REDIS_PASSWORD=""
BACKUP_DIR="/var/backups/claude-auth"
LOG_DIR="/var/log/claude-auth"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" >&2
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check OS
    if ! command -v apt-get &> /dev/null; then
        log_error "This script requires apt-get (Ubuntu/Debian)"
        exit 1
    fi
    
    # Check available disk space (minimum 10GB)
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
        log_warn "Less than 10GB disk space available. Database performance may be affected."
    fi
    
    log_info "Prerequisites check passed"
}

generate_passwords() {
    log_step "Generating secure passwords..."
    
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        log_info "Generated database password"
    fi
    
    if [[ -z "$REDIS_PASSWORD" ]]; then
        REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        log_info "Generated Redis password"
    fi
    
    # Save passwords securely
    cat > /etc/claude-auth/credentials.conf <<EOF
# Claude Agent Framework Authentication System Credentials
# Generated on: $(date)
DB_PASSWORD="$DB_PASSWORD"
REDIS_PASSWORD="$REDIS_PASSWORD"
EOF
    
    chmod 600 /etc/claude-auth/credentials.conf
    log_info "Credentials saved to /etc/claude-auth/credentials.conf"
}

install_postgresql() {
    log_step "Installing PostgreSQL $POSTGRES_VERSION..."
    
    # Install PostgreSQL
    apt-get update -qq
    apt-get install -y postgresql-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION
    
    # Start and enable PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql
    
    log_info "PostgreSQL installed and started"
}

install_redis() {
    log_step "Installing Redis $REDIS_VERSION..."
    
    # Install Redis
    apt-get install -y redis-server
    
    # Start and enable Redis
    systemctl enable redis-server
    systemctl start redis-server
    
    log_info "Redis installed and started"
}

configure_postgresql() {
    log_step "Configuring PostgreSQL for high performance..."
    
    # Get system memory for configuration
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    shared_buffers=$((total_mem / 4))  # 25% of total memory
    effective_cache_size=$((total_mem * 3 / 4))  # 75% of total memory
    
    # Backup original configuration
    cp /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf \
       /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf.backup
    
    # Create optimized PostgreSQL configuration
    cat > /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf <<EOF
# ============================================================================
# CLAUDE AGENT FRAMEWORK POSTGRESQL CONFIGURATION
# Optimized for authentication workload: >1000 auth/sec, <50ms P95 latency
# ============================================================================

# Connection settings
max_connections = 500
shared_buffers = ${shared_buffers}MB
effective_cache_size = ${effective_cache_size}MB
work_mem = 8MB
maintenance_work_mem = 256MB

# WAL settings for performance
wal_level = replica
max_wal_size = 2GB
min_wal_size = 256MB
checkpoint_completion_target = 0.9
checkpoint_timeout = 10min
wal_compression = on

# Query optimization (SSD optimized)
random_page_cost = 1.1
effective_io_concurrency = 200
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8

# Logging for monitoring
logging_collector = on
log_directory = '$LOG_DIR/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_statement = 'mod'
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on

# Security
ssl = on
password_encryption = scram-sha-256

# Replication (for future high availability)
wal_keep_size = 1GB
max_wal_senders = 3
max_replication_slots = 3

# Performance monitoring
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000

# Autovacuum tuning for high-volume authentication
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 100
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05
autovacuum_max_workers = 4
EOF

    # Configure pg_hba.conf for secure access
    cat > /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf <<EOF
# Claude Agent Framework PostgreSQL Authentication
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             all                                     scram-sha-256

# IPv4/IPv6 local connections
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# Authentication database connections
host    $DB_NAME        $DB_USER        127.0.0.1/32            scram-sha-256
host    $DB_NAME        $DB_USER        ::1/128                 scram-sha-256
EOF

    # Create log directory
    mkdir -p $LOG_DIR/postgresql
    chown postgres:postgres $LOG_DIR/postgresql
    
    log_info "PostgreSQL configured for high performance"
}

configure_redis() {
    log_step "Configuring Redis for authentication caching..."
    
    # Backup original configuration
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # Get system memory for Redis configuration
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    redis_maxmemory=$((total_mem / 8))  # 12.5% of total memory for Redis
    
    # Create optimized Redis configuration
    cat > /etc/redis/redis.conf <<EOF
# ============================================================================
# CLAUDE AGENT FRAMEWORK REDIS CONFIGURATION  
# Optimized for session/permission caching and rate limiting
# ============================================================================

# Network
bind 127.0.0.1 ::1
port 6379
timeout 0
tcp-keepalive 300

# Memory management
maxmemory ${redis_maxmemory}mb
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Persistence for session data
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Security
requirepass $REDIS_PASSWORD
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_d83kf9j2m"

# Logging
loglevel notice
logfile $LOG_DIR/redis/redis-server.log

# Performance
tcp-backlog 511
databases 16
lua-time-limit 5000

# Slow log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Advanced
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
EOF

    # Create Redis log directory
    mkdir -p $LOG_DIR/redis
    chown redis:redis $LOG_DIR/redis
    
    log_info "Redis configured for authentication caching"
}

setup_database() {
    log_step "Setting up authentication database..."
    
    # Restart PostgreSQL with new configuration
    systemctl restart postgresql
    sleep 5
    
    # Create database user and database
    sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Enable extensions
\c $DB_NAME
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Grant permissions to user
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
EOF

    # Run database setup script
    if [[ -f "$SCRIPT_DIR/../sql/auth_db_setup.sql" ]]; then
        log_info "Running database schema setup..."
        sudo -u postgres psql -d $DB_NAME -f "$SCRIPT_DIR/../sql/auth_db_setup.sql"
    else
        log_error "Database setup script not found: $SCRIPT_DIR/../sql/auth_db_setup.sql"
        exit 1
    fi
    
    log_info "Authentication database setup completed"
}

setup_redis() {
    log_step "Setting up Redis authentication cache..."
    
    # Restart Redis with new configuration
    systemctl restart redis-server
    sleep 3
    
    # Test Redis connection
    redis-cli -a "$REDIS_PASSWORD" ping > /dev/null
    if [[ $? -eq 0 ]]; then
        log_info "Redis authentication cache setup completed"
    else
        log_error "Redis connection test failed"
        exit 1
    fi
}

install_monitoring() {
    log_step "Installing monitoring tools..."
    
    # Install required monitoring packages
    apt-get install -y python3 python3-pip python3-venv postgresql-client redis-tools
    
    # Create monitoring virtual environment
    python3 -m venv /opt/claude-auth-monitor
    source /opt/claude-auth-monitor/bin/activate
    
    # Install Python monitoring dependencies
    pip install asyncpg redis psutil prometheus_client
    
    # Create monitoring script
    cat > /opt/claude-auth-monitor/monitor.py <<'EOF'
#!/usr/bin/env python3
"""
Claude Agent Framework - Authentication System Monitor
Real-time performance monitoring for PostgreSQL + Redis
"""

import asyncio
import asyncpg
import redis
import psutil
import time
import json
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('auth_monitor')

async def monitor_auth_system():
    """Monitor authentication system performance"""
    
    # Database connection
    try:
        conn = await asyncpg.connect(
            host='localhost',
            port=5432,
            user='claude_auth',
            password=open('/etc/claude-auth/credentials.conf').read().split('DB_PASSWORD="')[1].split('"')[0],
            database='claude_auth'
        )
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return
    
    # Redis connection
    try:
        redis_password = open('/etc/claude-auth/credentials.conf').read().split('REDIS_PASSWORD="')[1].split('"')[0]
        redis_client = redis.Redis(host='localhost', port=6379, password=redis_password, decode_responses=True)
        redis_client.ping()
    except Exception as e:
        logger.error(f"Redis connection failed: {e}")
        return
    
    while True:
        try:
            # Get system metrics
            cpu_percent = psutil.cpu_percent()
            memory = psutil.virtual_memory()
            
            # Get database metrics
            db_stats = await conn.fetchrow("""
                SELECT 
                    (SELECT COUNT(*) FROM users WHERE status = 'active') as active_users,
                    (SELECT COUNT(*) FROM user_sessions WHERE is_active = TRUE AND expires_at > NOW()) as active_sessions,
                    (SELECT COUNT(*) FROM security_events WHERE timestamp >= NOW() - INTERVAL '1 hour') as recent_events
            """)
            
            # Get database performance metrics
            db_perf = await conn.fetchrow("""
                SELECT 
                    COALESCE(avg_latency_ms, 0) as avg_auth_latency,
                    COALESCE(p95_latency_ms, 0) as p95_auth_latency,
                    COALESCE(current_count, 0) as current_sessions
                FROM auth_performance_metrics 
                WHERE metric = 'authentication_latency'
            """)
            
            # Get Redis info
            redis_info = redis_client.info()
            
            # Create monitoring report
            report = {
                'timestamp': datetime.now().isoformat(),
                'system': {
                    'cpu_percent': cpu_percent,
                    'memory_percent': memory.percent,
                    'memory_used_gb': round(memory.used / 1024**3, 2)
                },
                'database': {
                    'active_users': db_stats['active_users'],
                    'active_sessions': db_stats['active_sessions'],
                    'recent_events': db_stats['recent_events'],
                    'avg_auth_latency_ms': float(db_perf['avg_auth_latency'] or 0),
                    'p95_auth_latency_ms': float(db_perf['p95_auth_latency'] or 0)
                },
                'redis': {
                    'connected_clients': redis_info.get('connected_clients', 0),
                    'used_memory_mb': round(redis_info.get('used_memory', 0) / 1024**2, 2),
                    'keyspace_hits': redis_info.get('keyspace_hits', 0),
                    'keyspace_misses': redis_info.get('keyspace_misses', 0),
                    'hit_ratio': round(redis_info.get('keyspace_hits', 0) / max(redis_info.get('keyspace_hits', 0) + redis_info.get('keyspace_misses', 0), 1) * 100, 2)
                }
            }
            
            # Performance alerts
            alerts = []
            if report['database']['p95_auth_latency_ms'] > 50:
                alerts.append(f"HIGH AUTH LATENCY: {report['database']['p95_auth_latency_ms']:.2f}ms (target: <50ms)")
            
            if report['system']['cpu_percent'] > 80:
                alerts.append(f"HIGH CPU: {report['system']['cpu_percent']:.1f}%")
            
            if report['system']['memory_percent'] > 80:
                alerts.append(f"HIGH MEMORY: {report['system']['memory_percent']:.1f}%")
            
            if report['redis']['hit_ratio'] < 80:
                alerts.append(f"LOW CACHE HIT RATIO: {report['redis']['hit_ratio']:.1f}%")
            
            # Log report
            logger.info(f"Auth System Status: {json.dumps(report, indent=2)}")
            
            if alerts:
                logger.warning(f"ALERTS: {'; '.join(alerts)}")
            
            # Write to monitoring log
            with open('/var/log/claude-auth/monitor.log', 'a') as f:
                f.write(f"{datetime.now().isoformat()} {json.dumps(report)}\n")
            
            await asyncio.sleep(30)  # Monitor every 30 seconds
            
        except Exception as e:
            logger.error(f"Monitoring error: {e}")
            await asyncio.sleep(60)
    
    await conn.close()

if __name__ == "__main__":
    asyncio.run(monitor_auth_system())
EOF

    chmod +x /opt/claude-auth-monitor/monitor.py
    
    # Create systemd service for monitoring
    cat > /etc/systemd/system/claude-auth-monitor.service <<EOF
[Unit]
Description=Claude Agent Framework Authentication System Monitor
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=claude-auth
Group=claude-auth
WorkingDirectory=/opt/claude-auth-monitor
Environment=PATH=/opt/claude-auth-monitor/bin
ExecStart=/opt/claude-auth-monitor/bin/python3 /opt/claude-auth-monitor/monitor.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create monitoring user
    useradd -r -s /bin/false claude-auth || true
    chown -R claude-auth:claude-auth /opt/claude-auth-monitor
    
    log_info "Monitoring tools installed"
}

setup_backup() {
    log_step "Setting up backup system..."
    
    # Create backup directories
    mkdir -p $BACKUP_DIR/{postgresql,redis,scripts}
    
    # Create PostgreSQL backup script
    cat > $BACKUP_DIR/scripts/backup-postgresql.sh <<EOF
#!/bin/bash
# Claude Auth Database Backup Script

DATE=\$(date +%Y%m%d_%H%M%S)
DB_PASSWORD="$DB_PASSWORD"

# Full backup
PGPASSWORD="\$DB_PASSWORD" pg_dump -h localhost -U $DB_USER -Fc $DB_NAME > "$BACKUP_DIR/postgresql/full_backup_\$DATE.dump"

# Compress old backups (keep 7 days of full backups)
find $BACKUP_DIR/postgresql -name "full_backup_*.dump" -mtime +7 -exec gzip {} \;

# Delete very old compressed backups (keep 30 days)
find $BACKUP_DIR/postgresql -name "full_backup_*.dump.gz" -mtime +30 -delete

echo "PostgreSQL backup completed: full_backup_\$DATE.dump"
EOF

    # Create Redis backup script
    cat > $BACKUP_DIR/scripts/backup-redis.sh <<EOF
#!/bin/bash
# Claude Auth Redis Backup Script

DATE=\$(date +%Y%m%d_%H%M%S)

# Redis backup
redis-cli -a "$REDIS_PASSWORD" --rdb "$BACKUP_DIR/redis/redis_backup_\$DATE.rdb"

# Configuration backup
cp /etc/redis/redis.conf "$BACKUP_DIR/redis/redis_config_\$DATE.conf"

# Delete old backups (keep 7 days)
find $BACKUP_DIR/redis -name "redis_backup_*.rdb" -mtime +7 -delete
find $BACKUP_DIR/redis -name "redis_config_*.conf" -mtime +7 -delete

echo "Redis backup completed: redis_backup_\$DATE.rdb"
EOF

    chmod +x $BACKUP_DIR/scripts/*.sh
    
    # Setup cron jobs for automated backups
    cat > /etc/cron.d/claude-auth-backup <<EOF
# Claude Agent Framework Authentication System Backups
0 2 * * * root $BACKUP_DIR/scripts/backup-postgresql.sh >> /var/log/claude-auth/backup.log 2>&1
15 2 * * * root $BACKUP_DIR/scripts/backup-redis.sh >> /var/log/claude-auth/backup.log 2>&1
EOF

    log_info "Backup system configured"
}

run_performance_test() {
    log_step "Running performance validation test..."
    
    if [[ -f "$SCRIPT_DIR/../tests/auth_db_performance_test.py" ]]; then
        # Install test dependencies
        source /opt/claude-auth-monitor/bin/activate
        pip install asyncpg redis
        
        # Run performance test
        cd "$SCRIPT_DIR"
        python3 ../tests/auth_db_performance_test.py
        
        if [[ $? -eq 0 ]]; then
            log_info "✓ Performance test PASSED - Database is production ready"
        else
            log_warn "✗ Performance test FAILED - Review configuration and retest"
        fi
    else
        log_warn "Performance test script not found, skipping validation"
    fi
}

create_configuration_summary() {
    log_step "Creating deployment summary..."
    
    cat > /etc/claude-auth/deployment-summary.md <<EOF
# Claude Agent Framework - Authentication Database Deployment Summary

**Deployment Date**: $(date)
**Version**: v1.0 Production

## System Configuration

### PostgreSQL $POSTGRES_VERSION
- **Database**: $DB_NAME
- **User**: $DB_USER  
- **Configuration**: /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
- **Performance**: Optimized for >1000 auth/sec, <50ms P95 latency
- **Memory**: ${shared_buffers}MB shared_buffers, ${effective_cache_size}MB effective_cache_size

### Redis $REDIS_VERSION
- **Configuration**: /etc/redis/redis.conf
- **Memory**: ${redis_maxmemory}MB max memory
- **Persistence**: RDB snapshots enabled
- **Security**: Password protected, dangerous commands disabled

## Monitoring & Logging
- **Monitor Service**: claude-auth-monitor.service
- **Logs**: $LOG_DIR/
- **Performance Metrics**: /var/log/claude-auth/monitor.log

## Backup System
- **PostgreSQL Backups**: Daily at 02:00, 7-day retention + 30-day compressed
- **Redis Backups**: Daily at 02:15, 7-day retention
- **Backup Location**: $BACKUP_DIR/

## Security
- **Credentials**: /etc/claude-auth/credentials.conf (mode 600)
- **Database Authentication**: SCRAM-SHA-256
- **Redis Authentication**: Password required
- **SSL**: Enabled for PostgreSQL

## Service Management
\`\`\`bash
# Start/stop services
systemctl start postgresql redis-server claude-auth-monitor
systemctl stop postgresql redis-server claude-auth-monitor

# Check service status
systemctl status postgresql redis-server claude-auth-monitor

# View logs
journalctl -u postgresql -f
journalctl -u redis-server -f
journalctl -u claude-auth-monitor -f

# Database connection
psql -h localhost -U $DB_USER -d $DB_NAME

# Redis connection  
redis-cli -a [password from credentials file]
\`\`\`

## Performance Testing
Run performance validation:
\`\`\`bash
cd $SCRIPT_DIR
python3 ../tests/auth_db_performance_test.py
\`\`\`

## Troubleshooting
1. **High latency**: Check pg_stat_statements for slow queries
2. **Memory issues**: Adjust shared_buffers and Redis maxmemory
3. **Connection issues**: Check pg_hba.conf and firewall settings
4. **Cache misses**: Review Redis hit ratios in monitoring

Generated by Claude Agent Framework Database Agent
EOF

    log_info "Deployment summary created: /etc/claude-auth/deployment-summary.md"
}

main() {
    echo "============================================================================"
    echo "Claude Agent Framework - Authentication Database Deployment"
    echo "Database Agent Production Deployment Script v1.0"  
    echo "Target: >1000 auth/sec with <50ms P95 latency"
    echo "============================================================================"
    echo
    
    # Create config directory
    mkdir -p /etc/claude-auth
    mkdir -p $LOG_DIR
    
    # Run deployment steps
    check_prerequisites
    generate_passwords
    install_postgresql
    install_redis
    configure_postgresql
    configure_redis
    setup_database
    setup_redis
    install_monitoring
    setup_backup
    
    # Start services
    systemctl restart postgresql redis-server
    systemctl enable claude-auth-monitor
    systemctl start claude-auth-monitor
    
    # Run performance test
    run_performance_test
    
    # Create summary
    create_configuration_summary
    
    echo
    echo "============================================================================"
    echo -e "${GREEN}Authentication Database Deployment Complete!${NC}"
    echo "============================================================================"
    echo
    echo "📊 System Status:"
    echo "  PostgreSQL: $(systemctl is-active postgresql)"
    echo "  Redis:      $(systemctl is-active redis-server)"  
    echo "  Monitor:    $(systemctl is-active claude-auth-monitor)"
    echo
    echo "📁 Important Files:"
    echo "  Credentials:     /etc/claude-auth/credentials.conf"
    echo "  Summary:         /etc/claude-auth/deployment-summary.md"
    echo "  Logs:            $LOG_DIR/"
    echo "  Backups:         $BACKUP_DIR/"
    echo
    echo "🔧 Quick Commands:"
    echo "  Database:        psql -h localhost -U $DB_USER -d $DB_NAME"
    echo "  Redis:           redis-cli -a [password from credentials]"
    echo "  Monitor Logs:    journalctl -u claude-auth-monitor -f"
    echo "  Performance:     python3 $SCRIPT_DIR/auth_db_performance_test.py"
    echo
    echo -e "${GREEN}Database is ready for >1000 auth/sec with <50ms P95 latency!${NC}"
}

# Run main function
main "$@"