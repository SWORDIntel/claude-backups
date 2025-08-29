# Claude Agent Framework v7.0 - Technical Reference

## Communication System v3.0

### Binary Protocol Specifications

```c
// Ultra-fast protocol header
typedef struct {
    uint64_t timestamp;
    uint32_t msg_id;
    uint32_t source_agent;
    uint32_t target_agent;
    uint16_t msg_type;
    uint16_t priority;
    uint32_t payload_size;
    uint8_t  checksum[32];
} enhanced_msg_header_t;
```

### Performance Characteristics
- **Throughput**: 4.2M messages/second
- **Latency**: 200ns P99
- **Memory**: Lock-free ring buffers
- **CPU**: NUMA-aware allocation
- **IPC Methods**:
  - Shared memory: 50ns
  - io_uring: 500ns
  - Unix sockets: 2μs
  - mmap files: 10μs
  - DMA regions: Batch operations

### Message Patterns
1. **Publish/Subscribe**: Broadcast to multiple agents
2. **Request/Response**: Direct agent-to-agent
3. **Work Queues**: Load-balanced task distribution
4. **Broadcast**: System-wide announcements
5. **Multicast**: Group messaging

## Agent Integration Specifications

### Agent Registration Protocol

```python
class AgentRegistry:
    def register_agent(self, agent_path: Path) -> Dict[str, Any]:
        """
        Register an agent with the system
        Returns: {
            'uuid': 'unique-identifier',
            'name': 'AGENT_NAME',
            'capabilities': [...],
            'status': 'PRODUCTION|DEVELOPMENT',
            'tools': [...],
            'proactive_triggers': [...]
        }
        """
```

### Agent Communication Interface

```python
# Python implementation
from auto_integrate import integrate_with_claude_agent_system
agent = integrate_with_claude_agent_system("agent_name")

# C implementation
#include "ultra_fast_protocol.h"
ufp_context_t* ctx = ufp_create_context("agent_name");
```

### Tandem Execution Protocol

```yaml
tandem_execution:
  supported_modes:
    - INTELLIGENT      # Python orchestrates, C executes
    - PYTHON_ONLY     # Pure Python fallback
    - REDUNDANT       # Both layers execute
    - CONSENSUS       # Both must agree
    - SPEED_CRITICAL  # C layer only
    
  fallback_strategy:
    when_c_unavailable: PYTHON_ONLY
    when_performance_degraded: PYTHON_ONLY
    when_consensus_fails: RETRY_PYTHON
    max_retries: 3
```

## Hardware Optimization

### Intel Meteor Lake Specifications

```yaml
cpu_requirements:
  meteor_lake_specific: true
  avx512_benefit: HIGH|MEDIUM|LOW
  microcode_sensitive: true|false
  
  core_allocation_strategy:
    single_threaded: P_CORES_ONLY
    multi_threaded:
      compute_intensive: P_CORES
      memory_bandwidth: ALL_CORES
      background_tasks: E_CORES
      mixed_workload: THREAD_DIRECTOR
```

### Core Allocation
- **P-Cores (0,2,4,6,8,10)**: High-performance tasks
- **E-Cores (12-19)**: Background/IO operations
- **LP-E-Cores (20-21)**: Ultra-low power tasks

## Database Architecture

### PostgreSQL 17 Configuration

```sql
-- Optimized for >2000 auth/sec
CREATE TABLE auth_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token_hash VARCHAR(256) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
) WITH (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.01,
    fillfactor = 90
);

-- Indexes for performance
CREATE INDEX idx_sessions_user ON auth_sessions(user_id);
CREATE INDEX idx_sessions_token ON auth_sessions USING hash(token_hash);
CREATE INDEX idx_sessions_expiry ON auth_sessions(expires_at);
CREATE INDEX idx_sessions_metadata ON auth_sessions USING gin(metadata);
```

### Performance Optimizations
- JIT compilation enabled
- Parallel workers: 6
- Work memory: 256MB
- Shared buffers: 2GB
- Effective cache: 8GB

## AI Router Integration

### Neural Processing Configuration

```python
class AIEnhancedRouter:
    def __init__(self):
        self.npu_available = check_npu_support()
        self.gna_available = check_gna_support()
        self.gpu_available = check_gpu_support()
        
    def route_message(self, msg):
        if self.npu_available:
            return self.npu_route(msg)
        elif self.gpu_available:
            return self.gpu_route(msg)
        else:
            return self.cpu_route(msg)
```

### Routing Algorithms
1. **Pattern Recognition**: Historical analysis
2. **Load Balancing**: Even distribution
3. **Priority Routing**: Urgency-based
4. **Predictive Routing**: ML-based prediction
5. **Failover Routing**: Automatic recovery

## Security Implementation

### Authentication Flow

```python
# JWT Token Generation
def generate_token(user_id: str, role: str) -> str:
    payload = {
        'user_id': user_id,
        'role': role,
        'exp': datetime.utcnow() + timedelta(hours=24),
        'iat': datetime.utcnow(),
        'jti': str(uuid.uuid4())
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='RS256')
```

### RBAC Levels
1. **ADMIN**: Full system access
2. **OPERATOR**: Agent management
3. **USER**: Standard operations
4. **OBSERVER**: Read-only access

### Encryption Standards
- **Transport**: TLS 1.3
- **Storage**: AES-256-GCM
- **Hashing**: SHA-256/SHA-512
- **Signatures**: HMAC-SHA256
- **Keys**: RSA-4096/Ed25519

## Monitoring & Metrics

### Prometheus Exporters

```python
# Agent metrics
agent_requests_total = Counter('agent_requests_total', 
                              'Total agent requests',
                              ['agent', 'status'])
agent_latency_seconds = Histogram('agent_latency_seconds',
                                 'Agent response latency',
                                 ['agent'])
agent_errors_total = Counter('agent_errors_total',
                            'Total agent errors',
                            ['agent', 'error_type'])
```

### Grafana Dashboard Panels
1. **System Overview**: CPU, Memory, Network
2. **Agent Performance**: Latency, Throughput
3. **Error Tracking**: Failures, Retries
4. **Database Metrics**: Queries, Connections
5. **Binary Protocol**: Messages/sec, Latency

## Build System

### Makefile Configuration

```makefile
# Optimized build flags
CFLAGS = -O3 -march=native -mtune=native \
         -mavx512f -mavx512bw -mavx512dq \
         -ffast-math -funroll-loops \
         -flto -fomit-frame-pointer

# NUMA optimization
LDFLAGS = -lnuma -lpthread -lrt -ldl \
          -lio_uring -lssl -lcrypto

# Build targets
all: agents binary_protocol database_connector
```

### Python Environment

```bash
# Virtual environment setup
python3 -m venv venv_production
source venv_production/bin/activate
pip install -r requirements.txt

# Required packages
aiohttp>=3.8.0
asyncio>=3.4.3
pyyaml>=6.0
prometheus_client>=0.15.0
psycopg2-binary>=2.9.0
cryptography>=41.0.0
```

## Testing Framework

### Unit Tests
```bash
# C tests
./agents/src/c/tests/run_all_tests.sh

# Python tests
pytest agents/src/python/test_*.py -v --cov=agents

# Integration tests
python agents/src/python/test_tandem_system.py --comprehensive
```

### Performance Benchmarks
```bash
# Binary protocol benchmark
./agents/binary-communications-system/performance_test

# Database benchmark
python database/tests/auth_db_performance_test.py

# Agent coordination benchmark
python agents/src/python/test_agent_communication.py
```

## Deployment Configuration

### SystemD Service

```ini
[Unit]
Description=Claude Agent Framework
After=network.target postgresql.service

[Service]
Type=forking
User=claude
Group=claude
WorkingDirectory=/home/ubuntu/Documents/Claude
ExecStart=/home/ubuntu/Documents/Claude/bring-online
ExecStop=/home/ubuntu/Documents/Claude/agents/system/shutdown.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Docker Compose

```yaml
version: '3.8'
services:
  agents:
    build: .
    volumes:
      - ./agents:/app/agents
    environment:
      - CLAUDE_PROJECT_ROOT=/app
      - CLAUDE_ORCHESTRATION=true
    networks:
      - claude-network
      
  database:
    image: postgres:17
    environment:
      - POSTGRES_DB=claude_auth
      - POSTGRES_USER=claude
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - claude-network
```

## API Specifications

### REST Endpoints

```yaml
/api/v1/agents:
  GET: List all agents
  POST: Register new agent
  
/api/v1/agents/{id}:
  GET: Get agent details
  PUT: Update agent
  DELETE: Remove agent
  
/api/v1/tasks:
  POST: Submit task
  GET: List tasks
  
/api/v1/tasks/{id}:
  GET: Get task status
  DELETE: Cancel task
  
/api/v1/orchestration:
  POST: Execute workflow
  GET: List workflows
```

### WebSocket Protocol

```javascript
// Connect to agent system
const ws = new WebSocket('ws://localhost:8080/ws');

// Subscribe to agent events
ws.send(JSON.stringify({
  type: 'subscribe',
  agents: ['director', 'architect'],
  events: ['status', 'message']
}));

// Receive updates
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(`Agent ${data.agent}: ${data.message}`);
};
```

## Error Handling

### Error Codes

| Code | Description | Recovery |
|------|-------------|----------|
| 1000 | Agent not found | Check agent name |
| 1001 | Agent timeout | Retry with backoff |
| 1002 | Invalid message | Check format |
| 1003 | Authentication failed | Refresh token |
| 1004 | Rate limited | Wait and retry |
| 2000 | Database error | Check connection |
| 2001 | Query timeout | Optimize query |
| 3000 | Binary protocol error | Restart bridge |
| 3001 | IPC failure | Check permissions |
| 4000 | Orchestration error | Check workflow |

### Recovery Strategies

```python
async def execute_with_retry(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await func()
        except TemporaryError as e:
            wait_time = 2 ** attempt
            await asyncio.sleep(wait_time)
        except PermanentError as e:
            raise
    raise MaxRetriesExceeded()
```

---

*This technical reference provides detailed specifications for all system components. For implementation examples, see the source code in the respective directories.*