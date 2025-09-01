# Docker Containerization Best Practices - Enhanced Learning System

## Overview

This document outlines the Docker containerization strategy used in the Enhanced Learning System, ensuring data persistence, portability, and zero data loss across system reboots.

## Container Architecture

### Service Composition

```yaml
services:
  postgres:       # Primary database (PostgreSQL 16 + pgvector)
  pgbouncer:      # Connection pooling
  redis:          # Caching layer (optional)
```

### Key Design Principles

1. **Data Persistence First**: All data in named volumes
2. **Path Independence**: Relative paths only
3. **Auto-Recovery**: Restart policies for resilience
4. **Resource Optimization**: Hardware-aware limits
5. **Security Isolation**: Minimal attack surface

## Best Practices Implemented

### 1. Path Management

#### ❌ AVOID: Hardcoded Absolute Paths
```yaml
# BAD - User-specific, non-portable
volumes:
  - /home/john/claude-backups/database/data:/var/lib/postgresql/data
```

#### ✅ USE: Relative or Environment-Based Paths
```yaml
# GOOD - Portable across systems
volumes:
  - ./data:/var/lib/postgresql/data/pgdata
  - ${PWD}/backups:/backups
  - ./logs:/var/log/postgresql
```

**Benefits**:
- Works for any user
- Portable across systems
- No modification needed for deployment
- Supports CI/CD pipelines

### 2. Data Persistence Strategy

#### Three-Layer Protection

```yaml
# Layer 1: Named volumes
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${PWD}/data

# Layer 2: Restart policy
services:
  postgres:
    restart: unless-stopped  # Survives reboots

# Layer 3: Backup strategy
    volumes:
      - ./backups:/backups  # Regular dumps
```

#### Volume Management
```bash
# List volumes
docker volume ls | grep claude

# Inspect volume
docker volume inspect docker_postgres_data

# Backup volume
docker run --rm -v docker_postgres_data:/data \
  -v $(pwd):/backup alpine \
  tar czf /backup/postgres_data_$(date +%Y%m%d).tar.gz /data

# Restore volume
docker run --rm -v docker_postgres_data:/data \
  -v $(pwd):/backup alpine \
  tar xzf /backup/postgres_data_20250901.tar.gz -C /
```

### 3. Container Lifecycle Management

#### Startup Order and Dependencies

```yaml
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U claude_agent"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    
  pgbouncer:
    depends_on:
      postgres:
        condition: service_healthy  # Wait for healthy state
```

#### Graceful Shutdown
```bash
# Stop with timeout for clean shutdown
docker-compose stop -t 30

# Ensure data flush
docker exec claude-postgres pg_ctl stop -D /var/lib/postgresql/data -m smart
```

### 4. Resource Management

#### Memory and CPU Limits

```yaml
deploy:
  resources:
    limits:
      memory: 62G        # Maximum memory
      cpus: '20'         # CPU cores
    reservations:
      memory: 31G        # Guaranteed memory
      cpus: '10'         # Guaranteed cores
```

#### PostgreSQL Tuning for Container

```yaml
environment:
  # Shared memory (25% of container limit)
  POSTGRES_SHARED_BUFFERS: 15GB
  
  # Effective cache (assume 80% available)
  POSTGRES_EFFECTIVE_CACHE_SIZE: 50GB
  
  # Work memory (per operation)
  POSTGRES_WORK_MEM: 256MB
  
  # Parallel workers (match CPU cores)
  POSTGRES_MAX_PARALLEL_WORKERS: 10
```

### 5. Security Hardening

#### User and Permission Management

```yaml
services:
  postgres:
    user: "999:999"  # Non-root user
    read_only: true   # Read-only root filesystem
    tmpfs:
      - /tmp
      - /run
    security_opt:
      - no-new-privileges:true
```

#### Network Isolation

```yaml
networks:
  claude_network:
    driver: bridge
    internal: true  # No external access
    
services:
  postgres:
    networks:
      - claude_network
    ports:
      - "127.0.0.1:5433:5432"  # Local only
```

### 6. Logging and Monitoring

#### Structured Logging

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "50m"
    max-file: "5"
    labels: "service=postgres,env=production"
```

#### Health Monitoring
```bash
# Container health
docker inspect claude-postgres --format='{{.State.Health.Status}}'

# Resource usage
docker stats --no-stream claude-postgres

# Logs with timestamps
docker logs -t --since 1h claude-postgres
```

### 7. Build Optimization

#### Multi-stage Dockerfile

```dockerfile
# Build stage - compile extensions
FROM postgres:16 AS builder
RUN apt-get update && apt-get install -y build-essential
COPY simd_optimized_operations.c /tmp/
RUN gcc -O3 -mavx2 -shared -fPIC /tmp/simd_optimized_operations.c \
    -o /tmp/libsimd.so

# Runtime stage - minimal image
FROM postgres:16
COPY --from=builder /tmp/libsimd.so /usr/lib/postgresql/16/lib/
# Only runtime dependencies
```

#### Layer Caching
```dockerfile
# Order matters - least changing first
COPY requirements.txt .
RUN pip install -r requirements.txt

# Frequently changing last
COPY application_code .
```

### 8. Environment Configuration

#### Environment Files

```bash
# .env file for defaults
POSTGRES_USER=claude_agent
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-default_secure_password}
POSTGRES_DB=claude_agents_auth
POSTGRES_PORT=5433
```

#### Override Hierarchy
```bash
# 1. docker-compose.yml defaults
# 2. .env file
# 3. Shell environment
# 4. docker-compose.override.yml
# 5. Command line: -e flags

docker-compose --env-file .env.production up
```

### 9. Backup and Recovery

#### Automated Backups

```bash
#!/bin/bash
# backup.sh - Run via cron
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Database dump
docker exec claude-postgres pg_dump -U claude_agent \
  -d claude_agents_auth > "$BACKUP_DIR/db_$TIMESTAMP.sql"

# Compress and checksum
gzip "$BACKUP_DIR/db_$TIMESTAMP.sql"
sha256sum "$BACKUP_DIR/db_$TIMESTAMP.sql.gz" > "$BACKUP_DIR/db_$TIMESTAMP.sha256"

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +30 -delete
```

#### Recovery Procedure
```bash
# Stop container
docker-compose stop postgres

# Restore from backup
gunzip -c backups/db_20250901_120000.sql.gz | \
  docker exec -i claude-postgres psql -U claude_agent -d claude_agents_auth

# Verify
docker exec claude-postgres psql -U claude_agent -d claude_agents_auth \
  -c "SELECT COUNT(*) FROM enhanced_learning.shadowgit_events;"
```

### 10. Development vs Production

#### Development Override
```yaml
# docker-compose.override.yml (git-ignored)
services:
  postgres:
    ports:
      - "5433:5432"  # Expose for debugging
    environment:
      POSTGRES_LOG_STATEMENT: all  # Verbose logging
    volumes:
      - ./dev_data:/var/lib/postgresql/data/pgdata
```

#### Production Deployment
```bash
# Use production compose file only
docker-compose -f docker-compose.yml up -d

# No override file in production
rm docker-compose.override.yml
```

## Container Commands Reference

### Essential Operations

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f postgres

# Execute SQL
docker exec claude-postgres psql -U claude_agent -d claude_agents_auth

# Backup database
docker exec claude-postgres pg_dump -U claude_agent claude_agents_auth > backup.sql

# Stop services
docker-compose down  # Keeps volumes
docker-compose down -v  # Removes volumes (CAUTION)

# Update container
docker-compose pull
docker-compose up -d --force-recreate

# Clean up
docker system prune -a --volumes  # Remove everything unused
```

### Troubleshooting

```bash
# Check container status
docker ps -a | grep claude

# Inspect container
docker inspect claude-postgres

# View container processes
docker top claude-postgres

# Access container shell
docker exec -it claude-postgres bash

# Check PostgreSQL logs
docker exec claude-postgres tail -f /var/log/postgresql/postgresql.log

# Test connectivity
docker exec claude-postgres pg_isready

# Resource usage
docker stats claude-postgres
```

## Migration and Upgrades

### PostgreSQL Version Upgrade

```bash
# 1. Dump current data
docker exec claude-postgres pg_dumpall -U claude_agent > full_backup.sql

# 2. Stop old container
docker-compose down

# 3. Update image version in docker-compose.yml
# postgres:16 -> postgres:17

# 4. Start new container
docker-compose up -d

# 5. Restore data
docker exec -i claude-postgres psql -U claude_agent < full_backup.sql
```

### Zero-Downtime Updates

```bash
# 1. Create new container with different name
docker-compose up -d --scale postgres=2

# 2. Sync data
docker exec claude-postgres pg_basebackup \
  -h claude-postgres-2 -U replicator -D /backup

# 3. Switch traffic
# Update application connection string

# 4. Remove old container
docker-compose stop postgres
docker-compose rm postgres
```

## Performance Optimization

### Container-Specific Tuning

```yaml
services:
  postgres:
    sysctls:
      # Increase shared memory
      kernel.shmmax: 68719476736
      kernel.shmall: 16777216
      
      # Network tuning
      net.core.somaxconn: 1024
      net.ipv4.tcp_max_syn_backlog: 2048
    
    ulimits:
      # File descriptors
      nofile:
        soft: 65536
        hard: 65536
      # Core dumps
      core:
        soft: unlimited
        hard: unlimited
```

### Volume Performance

```yaml
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${FAST_SSD_PATH}/postgres  # Use fast storage
```

## Monitoring and Alerting

### Prometheus Metrics

```yaml
services:
  postgres_exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://claude_agent:password@postgres:5432/claude_agents_auth?sslmode=disable"
    ports:
      - "9187:9187"
```

### Health Checks

```bash
#!/bin/bash
# healthcheck.sh
set -e

# Database connection
docker exec claude-postgres pg_isready || exit 1

# Query execution
docker exec claude-postgres psql -U claude_agent -d claude_agents_auth \
  -c "SELECT 1" > /dev/null || exit 1

# Disk space
USAGE=$(docker exec claude-postgres df /var/lib/postgresql/data | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$USAGE" -gt 90 ]; then
  echo "Warning: Disk usage at ${USAGE}%"
  exit 1
fi

echo "All health checks passed"
```

## Summary

The Docker containerization strategy ensures:

✅ **Data Persistence**: Never lose data, even across reboots
✅ **Portability**: Works on any system without modification
✅ **Security**: Isolated, non-root, minimal attack surface
✅ **Performance**: Hardware-aware resource allocation
✅ **Maintainability**: Easy updates, backups, and monitoring

By following these practices, the Enhanced Learning System achieves enterprise-grade reliability while maintaining developer-friendly simplicity.

---
*Docker Containerization Best Practices*
*Last Updated: 2025-09-01*
*Container Version: PostgreSQL 16 with pgvector*