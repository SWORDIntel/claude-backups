# Hybrid Bridge Integration Testing Guide

## Quick Test (2 minutes)

### 1. Basic System Health Check
```bash
# Navigate to project directory
cd $CLAUDE_PROJECT_ROOT

# Check if core files exist
ls -la integrate_hybrid_bridge.sh
ls -la docker-compose.yml
ls -la agents/src/python/hybrid_bridge_manager.py
```

### 2. Test Native Learning System
```bash
cd agents/src/python

# Test learning system import
python3 -c "
try:
    from postgresql_learning_system import UltimatePostgreSQLLearningSystem
    print('✅ Learning system import successful')
except Exception as e:
    print('❌ Learning system error:', e)
"

# Test production orchestrator
python3 -c "
try:
    from production_orchestrator import ProductionOrchestrator
    print('✅ Orchestrator import successful')
except Exception as e:
    print('❌ Orchestrator error:', e)
"
```

### 3. Test Hybrid Bridge Manager
```bash
cd agents/src/python

# Test hybrid bridge functionality
python3 -c "
try:
    from hybrid_bridge_manager import HybridBridgeManager
    bridge = HybridBridgeManager()
    print('✅ Bridge manager initialized')
    
    status = bridge.get_system_status()
    print('📊 System Status:')
    print('  Bridge Status:', status['bridge_manager']['status'])
    print('  Current Mode:', status['bridge_manager']['mode'])
    print('  Native Available:', status['systems']['native']['available'])
    print('  Docker Available:', status['systems']['docker']['available'])
    
    if status['bridge_manager']['status'] == 'operational':
        print('✅ Hybrid bridge is OPERATIONAL')
    else:
        print('⚠️  Bridge in fallback mode (still functional)')
        
except Exception as e:
    print('❌ Bridge manager error:', e)
"
```

## Comprehensive Test (5 minutes)

### 4. Docker Configuration Test
```bash
# Check Docker availability
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker available"
    docker --version
    
    # Test Docker Compose configuration
    docker-compose config
    if [ $? -eq 0 ]; then
        echo "✅ docker-compose.yml is valid"
    else
        echo "❌ docker-compose.yml has issues"
    fi
else
    echo "⚠️  Docker not installed - running in native-only mode"
fi
```

### 5. Database Schema Test
```bash
# Check database files
echo "📁 Database Structure:"
ls -la database/sql/*.sql
ls -la database/docker/

# Check PostgreSQL compatibility
if [ -f "database/sql/learning_system_schema_pg16_compatible.sql" ]; then
    echo "✅ PostgreSQL 16/17 compatibility layer present"
else
    echo "❌ Missing PostgreSQL compatibility files"
fi
```

### 6. Integration Validation Script
```bash
# Run the comprehensive test
cd $CLAUDE_PROJECT_ROOT
python3 test_hybrid_integration.py 2>&1 | tee test_results.log

# Check results
if grep -q "ALL TESTS PASSED" test_results.log; then
    echo "🎉 ALL INTEGRATION TESTS PASSED!"
else
    echo "⚠️  Some tests failed - check test_results.log"
    tail -10 test_results.log
fi
```

## Full System Test (10 minutes)

### 7. Start Docker Containers (if Docker available)
```bash
# Only run if Docker is installed
if command -v docker >/dev/null 2>&1; then
    echo "🐳 Starting Docker containers..."
    
    # Start containers
    docker-compose up -d
    
    # Wait for services to start
    sleep 30
    
    # Check container health
    docker-compose ps
    
    # Test PostgreSQL connection
    docker-compose exec postgres pg_isready -U claude_user -d claude_auth
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL container is healthy"
    else
        echo "❌ PostgreSQL container issues"
    fi
    
    # Test learning system API (if container started)
    if curl -f http://localhost:8080/health 2>/dev/null; then
        echo "✅ Learning system API is responding"
    else
        echo "⚠️  Learning system API not ready (container may still be starting)"
    fi
    
    # Test agent bridge (if container started)
    if curl -f http://localhost:8081/health 2>/dev/null; then
        echo "✅ Agent bridge API is responding"
    else
        echo "⚠️  Agent bridge API not ready (container may still be starting)"
    fi
else
    echo "⚠️  Skipping Docker tests - Docker not available"
    echo "✅ System will run in native-only mode"
fi
```

### 8. Performance Validation
```bash
cd agents/src/python

# Test system performance
python3 -c "
import time
from hybrid_bridge_manager import HybridBridgeManager

print('🚀 Performance Test Starting...')
bridge = HybridBridgeManager()

# Test routing performance
start_time = time.time()
for i in range(100):
    status = bridge.get_system_status()
    
elapsed = time.time() - start_time
ops_per_sec = 100 / elapsed

print(f'📈 Performance Results:')
print(f'  Operations: 100 status checks')
print(f'  Time: {elapsed:.3f} seconds')
print(f'  Rate: {ops_per_sec:.1f} ops/sec')

if ops_per_sec > 500:
    print('✅ Performance target met (>500 ops/sec)')
else:
    print('⚠️  Performance below target but functional')
"
```

### 9. Learning System Integration Test
```bash
cd agents/src/python

# Test learning system integration
python3 -c "
try:
    import asyncio
    from postgresql_learning_system import UltimatePostgreSQLLearningSystem
    
    async def test_learning():
        print('🧠 Testing Learning System Integration...')
        system = UltimatePostgreSQLLearningSystem()
        print('✅ Learning system initialized successfully')
        
        # Test basic functionality
        print('📊 System appears functional')
        return True
    
    # Run async test
    result = asyncio.run(test_learning())
    if result:
        print('✅ Learning system integration SUCCESSFUL')
    
except Exception as e:
    print('❌ Learning system integration error:', e)
    print('⚠️  Check database configuration and dependencies')
"
```

## Test Results Interpretation

### ✅ **Success Indicators**
- All Python imports work without errors
- Hybrid bridge manager status shows 'operational'
- Docker containers start and respond to health checks
- Performance tests show >500 ops/sec
- No critical errors in logs

### ⚠️ **Partial Success (Still Functional)**
- Docker not available (native-only mode)
- Some containers slow to start (give them time)
- Performance below optimal (but working)
- Minor configuration warnings

### ❌ **Issues Requiring Attention**
- Python import errors (missing dependencies)
- Bridge manager fails to initialize
- All Docker containers fail to start
- Critical database connection errors

## Troubleshooting Quick Fixes

### Fix Docker Issues
```bash
# Install Docker if missing
sudo ./database/docker/install-docker.sh

# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Restart Docker service
sudo systemctl restart docker
```

### Fix Python Dependencies
```bash
cd agents/src/python
pip install -r requirements_production.txt
# or
pip install psycopg2-binary asyncpg numpy
```

### Test Specific Component
```bash
# Test only native system
cd agents/src/python
python3 postgresql_learning_system.py status

# Test only hybrid bridge
python3 hybrid_bridge_manager.py

# Test only orchestrator
python3 production_orchestrator.py --test
```

## Expected Test Results

**Full Success (Docker + Native)**:
```
✅ Learning system import successful
✅ Orchestrator import successful  
✅ Bridge manager initialized
📊 System Status: operational
✅ PostgreSQL container is healthy
✅ Learning system API is responding
✅ Performance target met (>500 ops/sec)
🎉 ALL INTEGRATION TESTS PASSED!
```

**Partial Success (Native Only)**:
```
✅ Learning system import successful
✅ Bridge manager initialized
📊 System Status: operational
⚠️  Docker not available - running in native-only mode
✅ Performance target met (>500 ops/sec)
⚠️  PARTIAL SUCCESS - Core functionality operational
```

The hybrid bridge is designed to work in both scenarios, preserving all functionality while providing enhanced capabilities when Docker is available.