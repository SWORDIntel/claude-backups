# Claude Agent Framework - Docker Containerized Environment

## Overview

Complete Docker containerization of the Claude Agent Framework PostgreSQL + Learning System with full self-containment and production-ready configuration.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │ Learning System │    │  Agent Bridge   │
│      17 +       │◄──►│   Python API    │◄──►│  Communication  │
│   pgvector      │    │   Port: 8080    │    │   Port: 8081    │
│   Port: 5433    │    └─────────────────┘    └─────────────────┘
└─────────────────┘              ▲                      ▲
         ▲                       │                      │
         │              ┌─────────────────┐             │
         │              │   Prometheus    │             │
         │              │   Monitoring    │◄────────────┘
         │              │   Port: 9091    │
         │              └─────────────────┘
         │
    ┌─────────────────┐
    │ Persistent Data │
    │   PostgreSQL    │
    │  Learning Data  │
    └─────────────────┘
```

## Features

### PostgreSQL 17 Container
- **pgvector extension** for vector embeddings
- **Performance optimized** for >2000 auth/sec
- **PostgreSQL 16/17 compatibility** with existing schemas
- **Persistent data** in `./database/data/postgresql`
- **Health monitoring** with automatic recovery

### Learning System Container
- **Python 3.12** with all production dependencies
- **FastAPI** web server with async support
- **Agent orchestration** and coordination
- **ML capabilities** with sklearn/numpy
- **Metrics collection** for monitoring

### Agent Bridge Container  
- **Communication hub** between services
- **REST API** for agent invocation
- **Health monitoring** and metrics
- **Service discovery** and load balancing

### Monitoring Stack
- **Prometheus** metrics collection
- **Health checks** for all services
- **Performance monitoring** and alerting
- **System resource tracking**

## Quick Start

### 1. Environment Setup
```bash
# Copy environment template
cp .env.template .env

# Edit configuration (important for production!)
nano .env
```

### 2. Start Services
```bash
# Make startup script executable
chmod +x database/docker/docker-start.sh

# Start complete stack
./database/docker/docker-start.sh
```

### 3. Verify Deployment
```bash
# Check all services
docker-compose ps

# Health checks
curl http://localhost:8080/health  # Learning System
curl http://localhost:8081/health  # Agent Bridge
curl http://localhost:8081/api/v1/system/status  # Full Status
```

## Service Endpoints

| Service | Port | Endpoint | Description |
|---------|------|----------|-------------|
| PostgreSQL | 5433 | `localhost:5433` | Database connection |
| Learning System | 8080 | `http://localhost:8080` | Python API server |
| Agent Bridge | 8081 | `http://localhost:8081` | Communication hub |
| Prometheus | 9091 | `http://localhost:9091` | Metrics dashboard |

### API Documentation
- **Learning System API**: http://localhost:8080/docs
- **Agent Bridge API**: http://localhost:8081/docs

## Database Connection

```bash
# Command line access
psql postgresql://claude_agent:your_password@localhost:5433/claude_agents_auth

# Connection string for applications
DATABASE_URL=postgresql://claude_agent:your_password@localhost:5433/claude_agents_auth
```

## Agent Operations

### List Agents
```bash
curl http://localhost:8081/api/v1/agents
```

### Invoke Agent
```bash
curl -X POST http://localhost:8081/api/v1/agents/director/invoke \
  -H "Content-Type: application/json" \
  -d '{"task": "create strategic plan", "priority": "high"}'
```

### Agent Status
```bash
curl http://localhost:8081/api/v1/agents/director/status
```

## Learning System Operations

### Trigger Learning
```bash
curl -X POST http://localhost:8081/api/v1/learning/train
```

### Get Metrics
```bash
curl http://localhost:8081/api/v1/learning/metrics
```

## Data Persistence

### Volumes
- **PostgreSQL Data**: `./database/data/postgresql`
- **Learning Data**: `./database/learning_data`
- **Prometheus Data**: Docker volume `prometheus_data`

### Backup
```bash
# Database backup
docker-compose exec postgres pg_dump -U claude_agent claude_agents_auth > backup.sql

# Full data backup
tar -czf claude-framework-backup.tar.gz database/data database/learning_data
```

### Restore
```bash
# Database restore
docker-compose exec -T postgres psql -U claude_agent claude_agents_auth < backup.sql
```

## Configuration

### Environment Variables (.env)
```bash
# Security
POSTGRES_PASSWORD=your_secure_password_here

# Performance
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=256MB

# Networking
POSTGRES_EXTERNAL_PORT=5433
LEARNING_API_PORT=8080
AGENT_BRIDGE_PORT=8081
```

### PostgreSQL Tuning
Default configuration optimized for:
- **200 max connections**
- **256MB shared buffers**
- **4 parallel workers per query**
- **Optimized for SSD storage**

## Monitoring

### Health Checks
```bash
# All services health
./database/docker/health-check.sh

# Individual service health
docker-compose exec postgres pg_isready -U claude_agent
docker-compose exec learning-system curl -f http://localhost:8080/health
docker-compose exec agent-bridge curl -f http://localhost:8081/health
```

### Logs
```bash
# All logs
docker-compose logs -f

# Specific service logs
docker-compose logs -f postgres
docker-compose logs -f learning-system
docker-compose logs -f agent-bridge
```

### Metrics
- **Prometheus UI**: http://localhost:9091
- **Learning System Metrics**: http://localhost:8080/metrics
- **Agent Bridge Metrics**: http://localhost:8081/metrics

## Operations

### Start Services
```bash
# Complete startup with health checks
./database/docker/docker-start.sh

# Or individual services
docker-compose up -d postgres
docker-compose up -d learning-system
docker-compose up -d agent-bridge
```

### Stop Services
```bash
# Graceful shutdown
./database/docker/docker-stop.sh

# Or docker-compose
docker-compose down
```

### Scale Services
```bash
# Scale learning system (multiple workers)
docker-compose up -d --scale learning-system=3

# Scale agent bridge
docker-compose up -d --scale agent-bridge=2
```

### Update Services
```bash
# Rebuild and restart
docker-compose build --no-cache
docker-compose up -d --force-recreate
```

## Development Mode

### Debug Configuration
```bash
# Enable debug mode
echo "DEBUG_MODE=true" >> .env
echo "VERBOSE_LOGGING=true" >> .env

# Restart with debug logging
docker-compose down && docker-compose up -d
```

### Development Volumes
```bash
# Mount source code for development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Troubleshooting

### PostgreSQL Issues
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Connect to database
docker-compose exec postgres psql -U claude_agent claude_agents_auth

# Reset database (WARNING: destroys data)
docker-compose down -v
rm -rf database/data/postgresql/*
docker-compose up -d postgres
```

### Learning System Issues
```bash
# Check Python logs
docker-compose logs learning-system

# Access container shell
docker-compose exec learning-system bash

# Check Python environment
docker-compose exec learning-system pip list
```

### Network Issues
```bash
# Check network connectivity
docker-compose exec learning-system curl http://postgres:5432
docker-compose exec agent-bridge curl http://learning-system:8080/health

# Inspect networks
docker network ls
docker network inspect claude-backups_claude-network
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check PostgreSQL performance
docker-compose exec postgres psql -U claude_agent claude_agents_auth -c "SELECT * FROM pg_stat_activity;"

# Check system resources
htop
```

## Security Considerations

### Production Security
1. **Change default passwords** in `.env`
2. **Enable SSL/TLS** for external connections
3. **Configure firewall** to restrict access
4. **Use secrets management** for sensitive data
5. **Enable audit logging** in PostgreSQL
6. **Regular security updates** of base images

### Network Security
```bash
# Restrict external access
# Only expose necessary ports
# Use internal network for service communication
```

### Data Security
```bash
# Encrypt data at rest
# Use encrypted backup storage
# Implement access controls
```

## Support

### Getting Help
1. Check container logs: `docker-compose logs [service]`
2. Verify health endpoints: `curl http://localhost:808[0|1]/health`
3. Check system status: `curl http://localhost:8081/api/v1/system/status`
4. Review configuration: `cat .env`

### Common Solutions
- **Port conflicts**: Change ports in `.env`
- **Permission issues**: Check file ownership and Docker permissions
- **Memory issues**: Adjust `POSTGRES_SHARED_BUFFERS` and container limits
- **Connection issues**: Verify network configuration and service startup order

---

**Claude Agent Framework Docker Environment**  
**Version**: 2.0.0  
**Status**: Production Ready  
**Last Updated**: 2025-08-25