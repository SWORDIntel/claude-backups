#!/usr/bin/env python3
"""
Claude Agent Framework - Authentication Database Performance Test Suite
Database Agent Production Performance Testing v1.0

Tests authentication database performance against targets:
- Authentication queries: <50ms P95 latency
- User lookups: <20ms P95 latency  
- Concurrent connections: >500
- Throughput: >1000 authentications/second

Compatible with auth_security.h/.c implementation.
"""

import asyncio
import asyncpg
import redis.asyncio as redis
import time
import statistics
import hashlib
import secrets
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import List, Dict, Any
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('auth_performance_test')

@dataclass
class PerformanceMetrics:
    """Performance metrics structure"""
    test_name: str
    total_operations: int
    successful_operations: int
    failed_operations: int
    total_duration: float
    avg_latency_ms: float
    p50_latency_ms: float
    p95_latency_ms: float
    p99_latency_ms: float
    throughput_ops_per_sec: float
    success_rate: float

@dataclass
class TestConfig:
    """Test configuration"""
    db_host: str = 'localhost'
    db_port: int = 5432
    db_name: str = 'claude_auth'
    db_user: str = 'postgres'
    db_password: str = 'password'
    redis_host: str = 'localhost'
    redis_port: int = 6379
    redis_password: str = None
    
    # Test parameters
    concurrent_users: int = 1000
    operations_per_user: int = 10
    test_duration_seconds: int = 60

class AuthDatabasePerformanceTest:
    """Authentication database performance test suite"""
    
    def __init__(self, config: TestConfig):
        self.config = config
        self.db_pool = None
        self.redis_pool = None
        self.test_users = []
        
    async def setup(self):
        """Initialize database connections and test data"""
        logger.info("Setting up performance test environment...")
        
        # Create database connection pool
        self.db_pool = await asyncpg.create_pool(
            host=self.config.db_host,
            port=self.config.db_port,
            user=self.config.db_user,
            password=self.config.db_password,
            database=self.config.db_name,
            min_size=50,
            max_size=200,
            command_timeout=5
        )
        
        # Create Redis connection pool
        self.redis_pool = redis.ConnectionPool(
            host=self.config.redis_host,
            port=self.config.redis_port,
            password=self.config.redis_password,
            decode_responses=True,
            max_connections=100
        )
        
        # Create test users
        await self.create_test_users()
        
        logger.info(f"Setup complete. Created {len(self.test_users)} test users.")
    
    async def create_test_users(self):
        """Create test users for performance testing"""
        async with self.db_pool.acquire() as conn:
            async with conn.transaction():
                # Get agent role ID
                agent_role_id = await conn.fetchval(
                    "SELECT role_id FROM roles WHERE role_name = 'agent'"
                )
                
                if not agent_role_id:
                    raise RuntimeError("Agent role not found. Run ../sql/auth_db_setup.sql first.")
                
                # Create test users
                for i in range(self.config.concurrent_users):
                    username = f"testuser_{i:06d}"
                    email = f"testuser_{i:06d}@claude-agents.test"
                    
                    # Generate salt and hash (simplified - production should use Argon2id)
                    salt = secrets.token_bytes(32)
                    password_hash = hashlib.sha256(b"testpass123" + salt).hexdigest()
                    
                    # Insert user
                    user_id = await conn.fetchval("""
                        INSERT INTO users (username, email, password_hash, salt, status, created_ip)
                        VALUES ($1, $2, $3, $4, 'active', '127.0.0.1'::INET)
                        ON CONFLICT (username) DO UPDATE SET updated_at = NOW()
                        RETURNING user_id
                    """, username, email, password_hash, salt)
                    
                    # Assign agent role
                    await conn.execute("""
                        INSERT INTO user_roles (user_id, role_id)
                        VALUES ($1, $2)
                        ON CONFLICT (user_id, role_id) DO NOTHING
                    """, user_id, agent_role_id)
                    
                    # Create user profile
                    await conn.execute("""
                        INSERT INTO user_profiles (user_id, display_name)
                        VALUES ($1, $2)
                        ON CONFLICT (user_id) DO NOTHING  
                    """, user_id, f"Test User {i:06d}")
                    
                    self.test_users.append({
                        'user_id': user_id,
                        'username': username,
                        'password_hash': password_hash,
                        'salt': salt
                    })
                
                # Refresh materialized view
                await conn.execute("REFRESH MATERIALIZED VIEW user_permissions_mv")
    
    async def test_authentication_performance(self) -> PerformanceMetrics:
        """Test authentication query performance"""
        logger.info("Testing authentication performance...")
        
        response_times = []
        successful_ops = 0
        failed_ops = 0
        
        async def auth_operation():
            """Single authentication operation"""
            nonlocal successful_ops, failed_ops
            
            user = secrets.choice(self.test_users)
            start_time = time.perf_counter()
            
            try:
                async with self.db_pool.acquire() as conn:
                    result = await conn.fetchrow("""
                        SELECT * FROM authenticate_user($1, $2)
                    """, user['username'], user['password_hash'])
                    
                    if result:
                        successful_ops += 1
                    else:
                        failed_ops += 1
                        
            except Exception as e:
                logger.error(f"Authentication failed: {e}")
                failed_ops += 1
            
            end_time = time.perf_counter()
            response_times.append((end_time - start_time) * 1000)  # Convert to ms
        
        # Run concurrent authentication tests
        start_time = time.perf_counter()
        tasks = [auth_operation() for _ in range(self.config.concurrent_users * self.config.operations_per_user)]
        await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.perf_counter()
        
        total_duration = end_time - start_time
        
        return PerformanceMetrics(
            test_name="Authentication Performance",
            total_operations=len(tasks),
            successful_operations=successful_ops,
            failed_operations=failed_ops,
            total_duration=total_duration,
            avg_latency_ms=statistics.mean(response_times) if response_times else 0,
            p50_latency_ms=statistics.median(response_times) if response_times else 0,
            p95_latency_ms=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            p99_latency_ms=statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else 0,
            throughput_ops_per_sec=len(tasks) / total_duration if total_duration > 0 else 0,
            success_rate=(successful_ops / len(tasks)) * 100 if tasks else 0
        )
    
    async def test_session_validation_performance(self) -> PerformanceMetrics:
        """Test session validation performance"""
        logger.info("Testing session validation performance...")
        
        # Create test sessions
        session_tokens = []
        async with self.db_pool.acquire() as conn:
            for user in self.test_users[:100]:  # Create sessions for first 100 users
                jwt_token_id = secrets.token_urlsafe(32)
                session_id = await conn.fetchval("""
                    INSERT INTO user_sessions (user_id, jwt_token_id, expires_at, ip_address, user_agent)
                    VALUES ($1, $2, NOW() + INTERVAL '24 hours', '127.0.0.1'::INET, 'PerformanceTest/1.0')
                    RETURNING session_id
                """, user['user_id'], jwt_token_id)
                session_tokens.append(jwt_token_id)
        
        response_times = []
        successful_ops = 0
        failed_ops = 0
        
        async def session_validation_operation():
            """Single session validation operation"""
            nonlocal successful_ops, failed_ops
            
            token = secrets.choice(session_tokens)
            start_time = time.perf_counter()
            
            try:
                async with self.db_pool.acquire() as conn:
                    result = await conn.fetchrow("""
                        SELECT * FROM validate_session($1)
                    """, token)
                    
                    if result:
                        successful_ops += 1
                    else:
                        failed_ops += 1
                        
            except Exception as e:
                logger.error(f"Session validation failed: {e}")
                failed_ops += 1
            
            end_time = time.perf_counter()
            response_times.append((end_time - start_time) * 1000)
        
        # Run concurrent session validation tests
        start_time = time.perf_counter()
        tasks = [session_validation_operation() for _ in range(1000)]
        await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.perf_counter()
        
        total_duration = end_time - start_time
        
        return PerformanceMetrics(
            test_name="Session Validation Performance",
            total_operations=len(tasks),
            successful_operations=successful_ops,
            failed_operations=failed_ops,
            total_duration=total_duration,
            avg_latency_ms=statistics.mean(response_times) if response_times else 0,
            p50_latency_ms=statistics.median(response_times) if response_times else 0,
            p95_latency_ms=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            p99_latency_ms=statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else 0,
            throughput_ops_per_sec=len(tasks) / total_duration if total_duration > 0 else 0,
            success_rate=(successful_ops / len(tasks)) * 100 if tasks else 0
        )
    
    async def test_permission_check_performance(self) -> PerformanceMetrics:
        """Test permission check performance"""
        logger.info("Testing permission check performance...")
        
        response_times = []
        successful_ops = 0
        failed_ops = 0
        
        async def permission_check_operation():
            """Single permission check operation"""
            nonlocal successful_ops, failed_ops
            
            user = secrets.choice(self.test_users)
            start_time = time.perf_counter()
            
            try:
                async with self.db_pool.acquire() as conn:
                    result = await conn.fetchval("""
                        SELECT check_permission($1, $2, $3)
                    """, user['user_id'], 'agent.*', 1)  # Check read permission
                    
                    if result is not None:
                        successful_ops += 1
                    else:
                        failed_ops += 1
                        
            except Exception as e:
                logger.error(f"Permission check failed: {e}")
                failed_ops += 1
            
            end_time = time.perf_counter()
            response_times.append((end_time - start_time) * 1000)
        
        # Run concurrent permission check tests
        start_time = time.perf_counter()
        tasks = [permission_check_operation() for _ in range(2000)]
        await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.perf_counter()
        
        total_duration = end_time - start_time
        
        return PerformanceMetrics(
            test_name="Permission Check Performance",
            total_operations=len(tasks),
            successful_operations=successful_ops,
            failed_operations=failed_ops,
            total_duration=total_duration,
            avg_latency_ms=statistics.mean(response_times) if response_times else 0,
            p50_latency_ms=statistics.median(response_times) if response_times else 0,
            p95_latency_ms=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            p99_latency_ms=statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else 0,
            throughput_ops_per_sec=len(tasks) / total_duration if total_duration > 0 else 0,
            success_rate=(successful_ops / len(tasks)) * 100 if tasks else 0
        )
    
    async def test_redis_caching_performance(self) -> PerformanceMetrics:
        """Test Redis caching performance"""
        logger.info("Testing Redis caching performance...")
        
        redis_client = redis.Redis(connection_pool=self.redis_pool)
        
        # Populate cache with user permissions
        for user in self.test_users[:100]:
            cache_key = f"user_perms:{user['user_id']}"
            permissions = ["agents.read", "agents.write", "agents.execute"]
            await redis_client.set(cache_key, json.dumps(permissions), ex=900)  # 15 min TTL
        
        response_times = []
        successful_ops = 0
        failed_ops = 0
        
        async def cache_operation():
            """Single cache operation"""
            nonlocal successful_ops, failed_ops
            
            user = secrets.choice(self.test_users[:100])
            cache_key = f"user_perms:{user['user_id']}"
            start_time = time.perf_counter()
            
            try:
                result = await redis_client.get(cache_key)
                if result:
                    json.loads(result)  # Parse JSON
                    successful_ops += 1
                else:
                    failed_ops += 1
                    
            except Exception as e:
                logger.error(f"Cache operation failed: {e}")
                failed_ops += 1
            
            end_time = time.perf_counter()
            response_times.append((end_time - start_time) * 1000)
        
        # Run concurrent cache operations
        start_time = time.perf_counter()
        tasks = [cache_operation() for _ in range(5000)]
        await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.perf_counter()
        
        total_duration = end_time - start_time
        await redis_client.close()
        
        return PerformanceMetrics(
            test_name="Redis Caching Performance",
            total_operations=len(tasks),
            successful_operations=successful_ops,
            failed_operations=failed_ops,
            total_duration=total_duration,
            avg_latency_ms=statistics.mean(response_times) if response_times else 0,
            p50_latency_ms=statistics.median(response_times) if response_times else 0,
            p95_latency_ms=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            p99_latency_ms=statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else 0,
            throughput_ops_per_sec=len(tasks) / total_duration if total_duration > 0 else 0,
            success_rate=(successful_ops / len(tasks)) * 100 if tasks else 0
        )
    
    async def test_concurrent_connections(self) -> PerformanceMetrics:
        """Test concurrent database connections"""
        logger.info("Testing concurrent database connections...")
        
        response_times = []
        successful_ops = 0
        failed_ops = 0
        
        async def concurrent_query():
            """Single concurrent query"""
            nonlocal successful_ops, failed_ops
            
            start_time = time.perf_counter()
            
            try:
                async with self.db_pool.acquire() as conn:
                    result = await conn.fetchval("SELECT COUNT(*) FROM users WHERE status = 'active'")
                    if result is not None:
                        successful_ops += 1
                    else:
                        failed_ops += 1
                        
            except Exception as e:
                logger.error(f"Concurrent query failed: {e}")
                failed_ops += 1
            
            end_time = time.perf_counter()
            response_times.append((end_time - start_time) * 1000)
        
        # Test with 500+ concurrent connections
        start_time = time.perf_counter()
        tasks = [concurrent_query() for _ in range(600)]
        await asyncio.gather(*tasks, return_exceptions=True)
        end_time = time.perf_counter()
        
        total_duration = end_time - start_time
        
        return PerformanceMetrics(
            test_name="Concurrent Connections Test",
            total_operations=len(tasks),
            successful_operations=successful_ops,
            failed_operations=failed_ops,
            total_duration=total_duration,
            avg_latency_ms=statistics.mean(response_times) if response_times else 0,
            p50_latency_ms=statistics.median(response_times) if response_times else 0,
            p95_latency_ms=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            p99_latency_ms=statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else 0,
            throughput_ops_per_sec=len(tasks) / total_duration if total_duration > 0 else 0,
            success_rate=(successful_ops / len(tasks)) * 100 if tasks else 0
        )
    
    def print_metrics(self, metrics: PerformanceMetrics):
        """Print performance metrics in a formatted way"""
        print(f"\n{'='*80}")
        print(f"TEST: {metrics.test_name}")
        print(f"{'='*80}")
        print(f"Total Operations:     {metrics.total_operations:,}")
        print(f"Successful:           {metrics.successful_operations:,}")
        print(f"Failed:               {metrics.failed_operations:,}")
        print(f"Success Rate:         {metrics.success_rate:.2f}%")
        print(f"Total Duration:       {metrics.total_duration:.3f}s")
        print(f"Throughput:           {metrics.throughput_ops_per_sec:.0f} ops/sec")
        print(f"\nLatency Metrics:")
        print(f"  Average:            {metrics.avg_latency_ms:.2f}ms")
        print(f"  Median (P50):       {metrics.p50_latency_ms:.2f}ms")
        print(f"  95th Percentile:    {metrics.p95_latency_ms:.2f}ms")
        print(f"  99th Percentile:    {metrics.p99_latency_ms:.2f}ms")
        
        # Performance targets validation
        print(f"\nPerformance Target Validation:")
        
        if "Authentication" in metrics.test_name:
            print(f"  P95 < 50ms:         {'✓ PASS' if metrics.p95_latency_ms < 50 else '✗ FAIL'} ({metrics.p95_latency_ms:.2f}ms)")
            print(f"  Throughput >1000:   {'✓ PASS' if metrics.throughput_ops_per_sec > 1000 else '✗ FAIL'} ({metrics.throughput_ops_per_sec:.0f} ops/sec)")
        
        elif "Session" in metrics.test_name or "Permission" in metrics.test_name:
            print(f"  P95 < 20ms:         {'✓ PASS' if metrics.p95_latency_ms < 20 else '✗ FAIL'} ({metrics.p95_latency_ms:.2f}ms)")
        
        elif "Concurrent" in metrics.test_name:
            print(f"  Success Rate >95%:  {'✓ PASS' if metrics.success_rate > 95 else '✗ FAIL'} ({metrics.success_rate:.2f}%)")
        
        elif "Redis" in metrics.test_name:
            print(f"  P95 < 5ms:          {'✓ PASS' if metrics.p95_latency_ms < 5 else '✗ FAIL'} ({metrics.p95_latency_ms:.2f}ms)")
        
        print(f"  Success Rate >95%:  {'✓ PASS' if metrics.success_rate > 95 else '✗ FAIL'} ({metrics.success_rate:.2f}%)")
    
    async def run_all_tests(self) -> List[PerformanceMetrics]:
        """Run all performance tests"""
        logger.info("Starting comprehensive performance test suite...")
        
        results = []
        
        try:
            # Test 1: Authentication Performance
            auth_metrics = await self.test_authentication_performance()
            results.append(auth_metrics)
            self.print_metrics(auth_metrics)
            
            # Test 2: Session Validation Performance
            session_metrics = await self.test_session_validation_performance()
            results.append(session_metrics)
            self.print_metrics(session_metrics)
            
            # Test 3: Permission Check Performance
            perm_metrics = await self.test_permission_check_performance()
            results.append(perm_metrics)
            self.print_metrics(perm_metrics)
            
            # Test 4: Redis Caching Performance
            redis_metrics = await self.test_redis_caching_performance()
            results.append(redis_metrics)
            self.print_metrics(redis_metrics)
            
            # Test 5: Concurrent Connections
            conn_metrics = await self.test_concurrent_connections()
            results.append(conn_metrics)
            self.print_metrics(conn_metrics)
            
        except Exception as e:
            logger.error(f"Test suite failed: {e}")
            raise
        
        return results
    
    async def cleanup(self):
        """Cleanup test resources"""
        logger.info("Cleaning up test resources...")
        
        try:
            # Clean up test users
            async with self.db_pool.acquire() as conn:
                await conn.execute("DELETE FROM users WHERE username LIKE 'testuser_%'")
                await conn.execute("REFRESH MATERIALIZED VIEW user_permissions_mv")
            
            # Close connections
            if self.db_pool:
                await self.db_pool.close()
            
            if self.redis_pool:
                await self.redis_pool.disconnect()
                
        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

async def main():
    """Main test execution"""
    print("Claude Agent Framework - Authentication Database Performance Test Suite")
    print("Database Agent Production Performance Testing v1.0")
    print("="*80)
    
    # Test configuration
    config = TestConfig(
        concurrent_users=1000,
        operations_per_user=10
    )
    
    # Run tests
    test_suite = AuthDatabasePerformanceTest(config)
    
    try:
        await test_suite.setup()
        results = await test_suite.run_all_tests()
        
        # Summary
        print(f"\n{'='*80}")
        print("PERFORMANCE TEST SUMMARY")
        print(f"{'='*80}")
        
        overall_pass = True
        for result in results:
            test_pass = True
            
            if "Authentication" in result.test_name:
                test_pass = result.p95_latency_ms < 50 and result.throughput_ops_per_sec > 1000 and result.success_rate > 95
            elif "Session" in result.test_name or "Permission" in result.test_name:
                test_pass = result.p95_latency_ms < 20 and result.success_rate > 95
            elif "Redis" in result.test_name:
                test_pass = result.p95_latency_ms < 5 and result.success_rate > 95
            elif "Concurrent" in result.test_name:
                test_pass = result.success_rate > 95
            
            status = "✓ PASS" if test_pass else "✗ FAIL"
            print(f"{result.test_name:<35} {status}")
            overall_pass = overall_pass and test_pass
        
        print(f"\nOVERALL RESULT: {'✓ ALL TESTS PASSED' if overall_pass else '✗ SOME TESTS FAILED'}")
        print(f"Database is {'READY FOR PRODUCTION' if overall_pass else 'NOT READY - OPTIMIZATION REQUIRED'}")
        
        return 0 if overall_pass else 1
        
    except Exception as e:
        logger.error(f"Test suite failed: {e}")
        return 1
        
    finally:
        await test_suite.cleanup()

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)