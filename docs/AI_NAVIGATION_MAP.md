# AI Navigation Map - Documentation Structure

## 🗺️ Quick Navigation for AI Assistants

This map provides AI assistants with efficient navigation paths through the Claude Agent Framework documentation.

## 📍 Critical Files (READ FIRST)

1. **`/CLAUDE.md`** - Main project context and rules
   - Docker container requirements (Line 758-788)
   - Agent ecosystem overview (Line 79-750)
   - System architecture (Line 18-39)

2. **`/database/docker/docker-compose.yml`** - Docker configuration
   - PostgreSQL 16 container setup
   - Learning system services
   - Network and volume configuration

## 📂 Documentation Structure

### `/docs/` - Main Documentation Directory

#### `/docs/features/` - Feature Documentation
- **`avx-optimized-git-bridge.md`** - AVX2/AVX-512 optimization (810+ MB/s)
- **`shadowgit-avx2-optimization.md`** - Shadowgit with 930M lines/sec
- **`docker-autostart-installer-enhancement.md`** - Container auto-restart
- **`tpm2-integration/`** - TPM hardware security integration

#### `/docs/fixes/` - Bug Fixes and Solutions
- **`BASH_OUTPUT_FIX_SUMMARY.md`** - Bash output wrapper fixes
- **`2025-08-25-agent-name-capitalization.md`** - Agent naming standardization

#### `/docs/guides/` - User Guides
- **`agent-invocation-guide.md`** - How to use agents
- **`docker-learning-system.md`** - Docker PostgreSQL setup

#### `/docs/technical/` - Technical Specifications  
- **`agent-framework-v7.md`** - Complete framework documentation
- **`binary-communication-protocol.md`** - 4.2M msg/sec protocol

## 🐳 Docker-Related Files (CRITICAL)

### Container Management
```
/database/docker/
├── docker-compose.yml          # Main orchestration file
├── Dockerfile.postgres         # PostgreSQL 16 + pgvector
├── Dockerfile.learning         # Learning system container
├── Dockerfile.bridge          # Agent bridge container
└── .env.template              # Environment configuration
```

### Database Scripts
```
/database/sql/
├── auth_db_setup.sql          # Main schema
├── learning_schema.sql        # Learning system tables
└── init-extensions.sql        # pgvector installation
```

## 🤖 Learning System Files (MUST USE DOCKER)

### Core Learning Components
```
/agents/src/python/
├── postgresql_learning_system.py      # Main learning engine
├── learning_orchestrator_bridge.py    # Orchestration integration
├── test_learning_integration.py       # Integration tests
└── launch_learning_system.sh          # Docker-aware launcher
```

### Database Management Scripts
```
/database/
├── check_learning_system.sh           # Docker status check
├── export_docker_learning_data.sh     # Data export via Docker
├── manage_database.sh                 # Docker container management
└── analyze_learning_performance.sh    # Performance analysis
```

## 🚨 Docker-Only Access Patterns

### NEVER DO THIS ❌
```bash
psql -U postgres                      # System PostgreSQL
sudo apt install postgresql           # Local installation
createdb learning_system              # Local database
pg_dump local_db                     # Local backup
```

### ALWAYS DO THIS ✅
```bash
docker exec claude-postgres psql -U claude_agent
docker-compose -f docker/docker-compose.yml up -d
docker exec -i claude-postgres pg_dump
docker volume ls | grep claude
```

## 🔍 Quick Search Patterns

### Find Docker Commands
```bash
grep -r "docker exec" $HOME/claude-backups/
grep -r "docker-compose" $HOME/claude-backups/
grep -r "5433" $HOME/claude-backups/  # Docker PostgreSQL port
```

### Find Learning System Files
```bash
find $HOME/claude-backups -name "*learning*.py"
find $HOME/claude-backups -name "*docker*.yml"
find $HOME/claude-backups -name "*.sql"
```

## 📊 Database Schema Location

### Learning Tables (Docker Container)
- `learning.agent_metrics` - Performance tracking
- `learning.task_embeddings` - Vector similarity (pgvector)
- `learning.interaction_logs` - Agent communication
- `learning.learning_feedback` - Continuous improvement
- `learning.model_performance` - ML metrics

## 🔐 Security Considerations

1. **Container Isolation**: All database operations isolated in Docker
2. **Port Mapping**: PostgreSQL on 5433 (not default 5432)
3. **Volume Persistence**: Data survives container restarts
4. **Network Segmentation**: Custom Docker network (172.20.0.0/16)

## 📝 Common Tasks Reference

### Start Learning System
```bash
cd $HOME/claude-backups/database
docker-compose -f docker/docker-compose.yml up -d
```

### Check System Health
```bash
./database/check_learning_system.sh
docker ps | grep claude
```

### Access Database
```bash
docker exec -it claude-postgres psql -U claude_agent -d claude_agents_auth
```

### Export Learning Data
```bash
./database/export_docker_learning_data.sh
```

## 🎯 AI Assistant Guidelines

1. **Always check Docker status first**: `docker ps | grep claude`
2. **Use Docker exec for all PostgreSQL operations**
3. **Reference this map when navigating documentation**
4. **Update this map when adding new documentation**
5. **Check `/CLAUDE.md` for project-wide rules**

## 📌 Related Documentation

- **Main Project**: `/CLAUDE.md`
- **Database README**: `/database/README.md`
- **Docker Setup**: `/database/docker/README.md`
- **Agent Documentation**: `/agents/docs/`
- **Learning System**: `/docs/features/enhanced-learning-system.md`

---

*Last Updated: 2025-09-01*
*Navigation Version: 1.0*
*Container Requirement: MANDATORY*