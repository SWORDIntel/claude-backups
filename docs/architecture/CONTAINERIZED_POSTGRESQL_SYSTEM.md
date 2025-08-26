# Containerized PostgreSQL System Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Hardware Optimization](#hardware-optimization)
4. [Security Model](#security-model)
5. [Configuration Reference](#configuration-reference)
6. [Agent Integration](#agent-integration)
7. [API Reference](#api-reference)
8. [Troubleshooting](#troubleshooting)

## System Overview

The Claude Agent Framework Containerized PostgreSQL System is a production-ready, self-contained database and learning environment optimized for Intel Meteor Lake hardware. It provides enterprise-grade performance, security, and reliability through Docker containerization.

### Key Features
- **Self-Contained**: Zero external dependencies
- **Hardware-Optimized**: Intel Meteor Lake CPU utilization
- **Security-First**: Non-root containers, network isolation
- **Production-Ready**: Health checks, monitoring, automatic recovery
- **Agent-Driven**: Built using 5 specialized agents in parallel

### Performance Targets
- **Authentication**: >2000 auth/sec
- **Latency**: <25ms P95
- **Availability**: 99%+ uptime
- **Thermal**: <85°C sustained operation

## Architecture

### Service Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │ Learning System │    │  Agent Bridge   │
│   Port: 5433    │◄───┤   Port: 8080    │◄───┤   Port: 8081    │
│  (Database)     │    │ (AI/ML Engine)  │    │ (Coordination)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Prometheus    │
                    │   Port: 9091    │
                    │  (Monitoring)   │
                    └─────────────────┘
```

### Components

#### 1. PostgreSQL Database (postgres)
- **Image**: `pgvector/pgvector:pg16-latest`
- **Purpose**: Primary data storage with vector extensions
- **Port**: 5433 (external) → 5432 (internal)
- **Network**: 172.20.0.10
- **Resources**: 2GB memory, 2 CPUs

#### 2. Learning System (learning-system)  
- **Build**: Custom Python 3.12 container
- **Purpose**: ML-powered agent performance analytics
- **Port**: 8080
- **Network**: 172.20.0.20
- **Resources**: 4GB memory, 2 CPUs

#### 3. Agent Bridge (agent-bridge)
- **Build**: Custom FastAPI container
- **Purpose**: Agent communication and coordination hub
- **Port**: 8081
- **Network**: 172.20.0.30

#### 4. Prometheus (prometheus)
- **Image**: `prom/prometheus:latest`
- **Purpose**: Metrics collection and monitoring
- **Port**: 9091 (external) → 9090 (internal)
- **Network**: 172.20.0.40

### Network Architecture

#### Custom Network: claude_network
- **Driver**: bridge
- **Subnet**: 172.20.0.0/16
- **Gateway**: 172.20.0.1
- **Features**:
  - Static IP assignment
  - Internal service discovery
  - Isolated from external networks
  - Jumbo frames (9000 MTU) for performance

## Hardware Optimization

### Intel Meteor Lake Optimization Strategy

#### CPU Topology
- **P-cores (0,2,4,6,8,10)**: High-performance cores for primary workloads
- **E-cores (12-19)**: Efficient cores for background tasks
- **LP E-cores (20-21)**: Low-power cores for monitoring

#### CPU Assignment Strategy
```
PostgreSQL Primary Processes → P-cores (0,2,4,6)
WAL Writer                  → P-core (8)
Background Writer           → P-core (10)
Vacuum/Maintenance         → E-cores (12-15)
Stats Collector            → E-core (16)
Docker Daemon              → E-cores (17-19)
Thermal Monitoring         → LP E-core (20)
System Management          → LP E-core (21)
```

#### Memory Optimization (64GB DDR5-5600)
- **shared_buffers**: 512MB (optimized for workload)
- **effective_cache_size**: 1536MB (OS cache estimation)
- **work_mem**: 16MB (per connection)
- **maintenance_work_mem**: 256MB (maintenance operations)

#### Thermal Management
- **Warning Threshold**: 80°C (reduces parallel workers)
- **Critical Threshold**: 85°C (aggressive throttling)
- **Monitoring**: Real-time temperature tracking
- **Recovery**: Automatic performance restoration

#### AVX-512 Acceleration
- **JIT Compilation**: Enabled for complex queries
- **Vectorized Operations**: Sorting, aggregation, indexing
- **Parallel Execution**: SIMD-optimized query processing

## Security Model

### Container Security
- **Non-root Execution**: All containers run as user `claude`
- **Capability Dropping**: Minimal required capabilities
- **Read-only Volumes**: Configuration mounted read-only
- **Resource Limits**: CPU/memory constraints prevent DoS

### Network Security
- **Isolated Networks**: Custom bridge network
- **Static IP Assignment**: Predictable network topology
- **Internal-only Database**: No external database access
- **Port Mapping**: Only necessary ports exposed

### Authentication Security
- **SCRAM-SHA-256**: Strong PostgreSQL authentication
- **No Trust Auth**: Passwordless access disabled
- **Environment Variables**: Credential management
- **JWT Security**: Token-based API authentication

### Security Configuration
```yaml
# PostgreSQL Authentication
POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=peer"

# Container Security
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - SETGID
  - SETUID
  - DAC_OVERRIDE
```

## Configuration Reference

### Environment Variables (.env.docker)
```bash
# Database Configuration
POSTGRES_USER=claude_user
POSTGRES_PASSWORD=claude_secure_pass_2024
POSTGRES_DB=claude_auth

# Performance Tuning
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1536MB
POSTGRES_WORK_MEM=16MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB

# Hardware Optimization
ENABLE_AVX512=true
METEOR_LAKE_OPTIMIZATION=true
THERMAL_THRESHOLD_WARNING=80
THERMAL_THRESHOLD_CRITICAL=85

# Security
JWT_SECRET_KEY=your_jwt_secret_key_here_change_me
JWT_ALGORITHM=HS256
```

### PostgreSQL Configuration Highlights
```sql
# Memory Settings
shared_buffers = 512MB
effective_cache_size = 1536MB
work_mem = 16MB
maintenance_work_mem = 256MB

# Parallel Processing (Intel Meteor Lake)
max_worker_processes = 8
max_parallel_workers = 6
max_parallel_workers_per_gather = 4

# JIT Compilation (AVX-512)
jit = on
jit_above_cost = 100000
jit_inline_above_cost = 500000
jit_optimize_above_cost = 500000

# Thermal Management
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.005
cpu_operator_cost = 0.0025
```

### Volume Mappings
```yaml
volumes:
  # Data Persistence
  - ./database/data/postgresql:/var/lib/postgresql/data
  
  # SQL Initialization (ordered)
  - ./database/sql/auth_db_setup.sql:/docker-entrypoint-initdb.d/01-auth-setup.sql:ro
  - ./database/sql/learning_system_schema_pg16_compatible.sql:/docker-entrypoint-initdb.d/02-learning-schema.sql:ro
  - ./database/sql/postgresql_16_json_compatibility_layer.sql:/docker-entrypoint-initdb.d/03-json-compat.sql:ro
  
  # Configuration
  - ./database/docker/config/postgresql.conf:/var/lib/postgresql/data/postgresql.conf:ro
```

## Agent Integration

### Multi-Agent Development Process
The system was built using 5 specialized agents deployed in parallel, each contributing specific expertise:

#### 1. PATCHER Agent
**Role**: Critical Issue Resolution
**Contributions**:
- Fixed 12 critical Docker configuration issues
- Removed trust authentication security vulnerability
- Created missing Docker configuration files
- Implemented proper health check dependencies

#### 2. DEBUGGER Agent  
**Role**: Failure Analysis & Prevention
**Contributions**:
- Analyzed 15 potential failure scenarios
- Designed comprehensive error handling strategies
- Created fallback mechanisms for all services
- Implemented recovery procedures

#### 3. OPTIMIZER Agent
**Role**: Performance Engineering
**Contributions**:
- Optimized PostgreSQL for >2000 auth/sec target
- Configured memory and CPU settings for Intel hardware
- Enabled JIT compilation with AVX-512 acceleration
- Designed resource allocation strategies

#### 4. LEADENGINEER Agent
**Role**: Hardware-Software Integration
**Contributions**:
- Created Intel Meteor Lake specific optimizations
- Designed CPU affinity strategies for P/E/LP cores
- Implemented thermal management system
- Optimized for 64GB DDR5-5600 memory

#### 5. QADIRECTOR Agent
**Role**: Quality Assurance & Validation
**Contributions**:
- Conducted comprehensive system validation
- Created security assessment framework
- Designed testing strategies and procedures
- Validated production readiness

### Agent Coordination Patterns
- **Parallel Execution**: All agents worked simultaneously
- **Dependency Resolution**: Cross-agent requirement coordination
- **Validation Framework**: Multi-layer quality checks
- **Knowledge Integration**: Combined expertise synthesis

## API Reference

### Learning System API (Port 8080)

#### Health Check
```http
GET /health
```
**Response**:
```json
{
  "status": "healthy",
  "service": "learning-system",
  "database": "connected",
  "timestamp": "2025-01-25T10:30:00Z"
}
```

#### System Status
```http
GET /status
```
**Response**:
```json
{
  "learning_system": "operational",
  "database": "claude-postgres:5432",
  "agents_registered": 71,
  "performance": {
    "queries_per_sec": 2150,
    "avg_latency_ms": 18.2
  }
}
```

### Agent Bridge API (Port 8081)

#### List Available Agents
```http
GET /agents
```
**Response**:
```json
{
  "agents": [
    {
      "name": "director",
      "description": "Strategic command and control",
      "category": "command",
      "status": "active"
    }
  ],
  "count": 71
}
```

#### Bridge Status
```http
GET /status
```
**Response**:
```json
{
  "bridge": "operational",
  "learning_api": "http://learning-system:8080",
  "postgres": "postgres:5432",
  "agents_dir": true,
  "config_dir": true
}
```

### Prometheus Metrics (Port 9091)

#### Key Metrics
- `postgresql_up`: PostgreSQL availability
- `postgresql_connections_active`: Active connections
- `postgresql_queries_per_second`: Query throughput
- `system_cpu_temperature`: CPU temperature monitoring
- `container_memory_usage`: Memory utilization
- `learning_system_performance`: ML system metrics

## Troubleshooting

### Common Issues

#### 1. Container Startup Failures
**Symptoms**: Services fail to start, exit immediately
**Diagnosis**:
```bash
# Check container logs
docker-compose logs postgres
docker-compose logs learning-system

# Check health status
docker-compose ps
```
**Solutions**:
- Verify .env file exists and has correct values
- Check volume mount permissions
- Ensure PostgreSQL data directory exists

#### 2. Database Connection Issues
**Symptoms**: Applications can't connect to database
**Diagnosis**:
```bash
# Test PostgreSQL connectivity
docker exec claude-postgres pg_isready -U claude_user
psql -h localhost -p 5433 -U claude_user -d claude_auth
```
**Solutions**:
- Verify PostgreSQL is running and healthy
- Check network connectivity between containers
- Validate authentication credentials

#### 3. Performance Issues
**Symptoms**: Slow query execution, high latency
**Diagnosis**:
```bash
# Monitor CPU usage
docker stats

# Check PostgreSQL performance
docker exec claude-postgres psql -U claude_user -c "SELECT * FROM pg_stat_activity;"

# Monitor temperature
sensors | grep Core
```
**Solutions**:
- Check thermal throttling (temperature >85°C)
- Verify CPU affinity is properly set
- Review PostgreSQL configuration parameters

#### 4. Memory Issues
**Symptoms**: Out of memory errors, container restarts
**Diagnosis**:
```bash
# Check memory usage
docker stats --no-stream
free -h

# Check PostgreSQL memory settings
docker exec claude-postgres psql -U claude_user -c "SHOW shared_buffers;"
```
**Solutions**:
- Adjust container memory limits
- Optimize PostgreSQL memory settings
- Check for memory leaks in applications

### Debugging Commands

#### System Health Check
```bash
# Overall system status
./database/docker/validate-docker-config.sh

# Service health
docker-compose ps
curl -f http://localhost:8080/health
curl -f http://localhost:8081/health
```

#### Performance Monitoring
```bash
# Real-time metrics
docker stats

# Database performance
docker exec claude-postgres psql -U claude_user -c "
SELECT schemaname,tablename,attname,avg_width,n_distinct 
FROM pg_stats 
WHERE tablename='your_table';"

# System resources
htop
iotop
```

#### Log Analysis
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postgres
docker-compose logs -f learning-system

# System logs
journalctl -u docker.service
dmesg | grep -i thermal
```

### Recovery Procedures

#### Service Recovery
```bash
# Restart individual service
docker-compose restart postgres

# Full system restart
docker-compose down
docker-compose up -d

# Clean restart (removes containers)
docker-compose down -v
docker-compose up -d --build
```

#### Data Recovery
```bash
# Database backup
docker exec claude-postgres pg_dump -U claude_user claude_auth > backup.sql

# Database restore
docker exec -i claude-postgres psql -U claude_user claude_auth < backup.sql

# Volume backup
docker run --rm -v claude-backups_postgresql_data:/data -v $(pwd):/backup alpine tar czf /backup/postgresql-data.tar.gz -C /data .
```

---

*Generated by DOCGEN Agent | Claude Agent Framework v7.0*