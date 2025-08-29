#!/usr/bin/env python3
"""
Pytest Configuration and Fixtures for Claude Unified Hook System Tests
TESTBED Agent - Comprehensive Test Configuration

This module provides:
- Global pytest configuration
- Shared fixtures for all tests
- Test environment setup/teardown
- Performance monitoring fixtures
- Security testing fixtures
"""

import os
import sys
import pytest
import asyncio
import tempfile
import shutil
from pathlib import Path
from typing import Dict, Any, AsyncGenerator, Generator
import psutil
import time
import json
import logging

# Add project to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from test_fixtures import (
    TestDataGenerator, TestFixtures, 
    MockExecutionResult, MockTaskTool
)

# Configure logging for tests
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('test_execution.log')
    ]
)

logger = logging.getLogger('TestFramework')

# ============================================================================
# PYTEST CONFIGURATION
# ============================================================================

def pytest_configure(config):
    """Configure pytest with custom markers"""
    config.addinivalue_line(
        "markers", "unit: mark test as a unit test"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as an integration test"
    )
    config.addinivalue_line(
        "markers", "performance: mark test as a performance test"
    )
    config.addinivalue_line(
        "markers", "security: mark test as a security test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers", "docker: mark test as requiring Docker environment"
    )

def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers automatically"""
    for item in items:
        # Add markers based on test name patterns
        if "security" in item.name.lower():
            item.add_marker(pytest.mark.security)
        if "performance" in item.name.lower():
            item.add_marker(pytest.mark.performance)
        if "integration" in item.name.lower():
            item.add_marker(pytest.mark.integration)
        if "docker" in item.name.lower():
            item.add_marker(pytest.mark.docker)
        if any(keyword in item.name.lower() for keyword in ["load", "stress", "benchmark"]):
            item.add_marker(pytest.mark.slow)

def pytest_runtest_setup(item):
    """Setup for each test item"""
    # Skip Docker tests if not in Docker environment
    if item.get_closest_marker("docker"):
        if not DockerTestEnvironment.is_running_in_docker():
            pytest.skip("Test requires Docker environment")
    
    # Record test start time
    item.test_start_time = time.time()

def pytest_runtest_teardown(item, nextitem):
    """Teardown for each test item"""
    # Log test execution time
    if hasattr(item, 'test_start_time'):
        execution_time = time.time() - item.test_start_time
        logger.info(f"Test {item.name} completed in {execution_time:.3f}s")

# ============================================================================
# CORE FIXTURES
# ============================================================================

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
def test_session_data():
    """Session-wide test data and configuration"""
    return {
        "session_id": f"test_session_{int(time.time())}",
        "start_time": time.time(),
        "total_tests": 0,
        "passed_tests": 0,
        "failed_tests": 0,
        "performance_results": {},
        "security_results": {},
        "memory_usage": []
    }

@pytest.fixture(scope="function")
def temp_project_dir() -> Generator[Path, None, None]:
    """Create temporary project directory for tests"""
    temp_dir = create_temporary_project_structure()
    logger.info(f"Created temporary project directory: {temp_dir}")
    
    try:
        yield temp_dir
    finally:
        cleanup_test_environment(temp_dir)
        logger.info(f"Cleaned up temporary project directory: {temp_dir}")

@pytest.fixture(scope="function")
def test_config(temp_project_dir):
    """Create test configuration"""
    from claude_unified_hook_system_v2 import UnifiedConfig
    
    config = UnifiedConfig()
    config.project_root = temp_project_dir
    config.agents_dir = temp_project_dir / "agents"
    config.config_dir = temp_project_dir / "config"
    config.cache_dir = temp_project_dir / "cache"
    config.max_input_length = 10000
    config.execution_timeout = 5  # Shorter for tests
    config.max_parallel_agents = 4  # Limited for tests
    config.worker_pool_size = 2  # Limited for tests
    config.max_cache_size = 50  # Smaller for tests
    
    return config

@pytest.fixture(scope="function") 
def mock_agents():
    """Generate mock agents for testing"""
    return TestDataGenerator.generate_agent_definitions(20)  # Smaller set for tests

@pytest.fixture(scope="function")
def test_registry(test_config, mock_agents):
    """Create test agent registry"""
    from claude_unified_hook_system_v2 import UnifiedAgentRegistry
    
    registry = UnifiedAgentRegistry(test_config)
    
    # Pre-populate with mock agents
    for agent in mock_agents:
        registry.agents[agent.name] = {
            "name": agent.name,
            "category": agent.category,
            "description": agent.description,
            "status": agent.status,
            "priority": agent.priority,
            "tools": agent.tools,
            "triggers": agent.triggers
        }
    
    return registry

@pytest.fixture(scope="function")
def test_matcher(test_registry, test_config):
    """Create test pattern matcher"""
    from claude_unified_hook_system_v2 import UnifiedMatcher
    
    return UnifiedMatcher(test_registry, test_config)

@pytest.fixture(scope="function")
def test_engine(test_config):
    """Create test hook engine"""
    from claude_unified_hook_system_v2 import UnifiedHookEngine
    
    return UnifiedHookEngine(test_config)

@pytest.fixture(scope="function")
def test_hooks(test_config):
    """Create complete hook system for testing"""
    from claude_unified_hook_system_v2 import ClaudeUnifiedHooks
    
    return ClaudeUnifiedHooks(test_config)

# ============================================================================
# TEST DATA FIXTURES
# ============================================================================

@pytest.fixture(scope="session")
def test_inputs():
    """Generate test inputs for pattern matching tests"""
    return TestDataGenerator.generate_test_inputs(100)

@pytest.fixture(scope="session")
def malicious_inputs():
    """Generate malicious inputs for security testing"""
    return TestDataGenerator.generate_malicious_inputs()

@pytest.fixture(scope="session")
def performance_test_data():
    """Generate performance test data"""
    return TestDataGenerator.generate_performance_test_data()

# ============================================================================
# PERFORMANCE MONITORING FIXTURES
# ============================================================================

@pytest.fixture(scope="function")
def performance_monitor():
    """Performance monitoring fixture"""
    benchmark = PerformanceBenchmark()
    
    # Monitor system resources
    process = psutil.Process()
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB
    initial_cpu_percent = process.cpu_percent()
    
    benchmark.initial_memory = initial_memory
    benchmark.initial_cpu = initial_cpu_percent
    
    yield benchmark
    
    # Record final metrics
    final_memory = process.memory_info().rss / 1024 / 1024
    final_cpu_percent = process.cpu_percent()
    
    benchmark.memory_delta = final_memory - initial_memory
    benchmark.cpu_usage = final_cpu_percent
    
    logger.info(f"Memory usage: {final_memory:.1f}MB (Δ{benchmark.memory_delta:+.1f}MB)")
    logger.info(f"CPU usage: {final_cpu_percent:.1f}%")

@pytest.fixture(scope="function")
def memory_tracker():
    """Memory usage tracking fixture"""
    process = psutil.Process()
    memory_readings = []
    
    def track_memory(label=""):
        memory_mb = process.memory_info().rss / 1024 / 1024
        memory_readings.append((time.time(), memory_mb, label))
        return memory_mb
    
    # Initial reading
    initial_memory = track_memory("initial")
    
    yield track_memory
    
    # Final reading
    final_memory = track_memory("final")
    
    # Check for memory leaks
    memory_growth = final_memory - initial_memory
    if memory_growth > 50:  # More than 50MB growth
        logger.warning(f"Potential memory leak detected: {memory_growth:.1f}MB growth")
    
    # Store readings for analysis
    memory_tracker.readings = memory_readings

# ============================================================================
# SECURITY TESTING FIXTURES
# ============================================================================

@pytest.fixture(scope="function")
def security_framework():
    """Security testing framework"""
    framework = SecurityTestFramework()
    
    # Register standard vulnerability tests
    framework.register_vulnerability_test(
        "path_traversal",
        framework.test_path_traversal_prevention
    )
    framework.register_vulnerability_test(
        "command_injection", 
        framework.test_command_injection_prevention
    )
    framework.register_vulnerability_test(
        "input_validation",
        framework.test_input_validation
    )
    
    return framework

@pytest.fixture(scope="function")
def vulnerability_scanner():
    """Vulnerability scanning fixture"""
    class VulnerabilityScanner:
        def __init__(self):
            self.vulnerabilities_found = []
            self.tests_run = []
        
        def scan_for_vulnerability(self, vuln_type: str, test_func, target):
            """Scan for a specific vulnerability"""
            self.tests_run.append(vuln_type)
            try:
                if asyncio.iscoroutinefunction(test_func):
                    # For async tests, return a coroutine
                    return test_func(target)
                else:
                    result = test_func(target)
                    if not result:
                        self.vulnerabilities_found.append(vuln_type)
                    return result
            except Exception as e:
                logger.error(f"Vulnerability scan for {vuln_type} failed: {e}")
                return False
        
        def get_scan_results(self):
            return {
                "vulnerabilities_found": self.vulnerabilities_found,
                "tests_run": self.tests_run,
                "clean": len(self.vulnerabilities_found) == 0
            }
    
    return VulnerabilityScanner()

# ============================================================================
# DOCKER ENVIRONMENT FIXTURES  
# ============================================================================

@pytest.fixture(scope="session")
def docker_environment():
    """Docker environment information"""
    return DockerTestEnvironment.get_container_resources()

@pytest.fixture(scope="function") 
def docker_test_env():
    """Docker-specific test environment"""
    if not DockerTestEnvironment.is_running_in_docker():
        pytest.skip("Docker environment required")
    
    # Create isolated test environment
    test_env = DockerTestEnvironment.create_test_environment()
    
    yield test_env
    
    # Cleanup
    cleanup_test_environment(test_env)

# ============================================================================
# ASYNC TESTING FIXTURES
# ============================================================================

@pytest.fixture
async def async_test_setup():
    """Async test setup fixture"""
    # Setup async resources
    semaphore = asyncio.Semaphore(5)
    queue = asyncio.Queue(maxsize=100)
    
    async def cleanup():
        # Cancel any remaining tasks
        tasks = [t for t in asyncio.all_tasks() if not t.done()]
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
    
    yield {"semaphore": semaphore, "queue": queue}
    
    await cleanup()

@pytest.fixture
def async_timeout():
    """Async timeout fixture"""
    return 10.0  # 10 second default timeout for async tests

# ============================================================================
# MOCK FIXTURES
# ============================================================================

@pytest.fixture(scope="function")
def mock_task_tool():
    """Mock Task tool for testing"""
    return MockFactory.create_mock_task_tool()

@pytest.fixture(scope="function") 
def mock_circuit_breaker():
    """Mock circuit breaker for testing"""
    return MockFactory.create_mock_circuit_breaker()

@pytest.fixture(scope="function")
def mock_file_system(temp_project_dir):
    """Mock file system operations"""
    class MockFileSystem:
        def __init__(self, root_dir):
            self.root_dir = root_dir
            self.operations = []
        
        def mock_file_read(self, path):
            full_path = self.root_dir / path
            self.operations.append(("read", str(full_path)))
            if full_path.exists():
                return full_path.read_text()
            else:
                raise FileNotFoundError(f"File not found: {path}")
        
        def mock_file_write(self, path, content):
            full_path = self.root_dir / path
            self.operations.append(("write", str(full_path)))
            full_path.parent.mkdir(parents=True, exist_ok=True)
            full_path.write_text(content)
        
        def get_operations(self):
            return self.operations.copy()
    
    return MockFileSystem(temp_project_dir)

# ============================================================================
# REPORTING FIXTURES
# ============================================================================

@pytest.fixture(scope="session", autouse=True)
def test_session_reporter(test_session_data):
    """Session-wide test reporting"""
    logger.info("=" * 60)
    logger.info("CLAUDE UNIFIED HOOKS TEST SESSION STARTED")
    logger.info("=" * 60)
    
    yield
    
    # Generate final session report
    session_duration = time.time() - test_session_data["start_time"]
    
    logger.info("=" * 60)
    logger.info("TEST SESSION COMPLETED")
    logger.info("=" * 60)
    logger.info(f"Session Duration: {session_duration:.2f}s")
    logger.info(f"Total Tests: {test_session_data.get('total_tests', 0)}")
    logger.info(f"Passed: {test_session_data.get('passed_tests', 0)}")
    logger.info(f"Failed: {test_session_data.get('failed_tests', 0)}")
    
    # Save detailed results
    results_file = Path("test_results.json")
    with open(results_file, 'w') as f:
        json.dump(test_session_data, f, indent=2, default=str)
    
    logger.info(f"Detailed results saved to: {results_file}")

@pytest.fixture(scope="function", autouse=True)
def test_result_tracker(request, test_session_data):
    """Track individual test results"""
    test_name = request.node.name
    start_time = time.time()
    
    yield
    
    # Update session data based on test outcome
    duration = time.time() - start_time
    test_session_data["total_tests"] += 1
    
    if hasattr(request.node, "rep_call") and request.node.rep_call.passed:
        test_session_data["passed_tests"] += 1
    else:
        test_session_data["failed_tests"] += 1
    
    # Log test completion
    logger.debug(f"Test {test_name} completed in {duration:.3f}s")

# ============================================================================
# CLEANUP FIXTURES
# ============================================================================

@pytest.fixture(scope="function", autouse=True)
def cleanup_test_artifacts():
    """Cleanup test artifacts after each test"""
    yield
    
    # Clean up any temporary files in current directory
    temp_files = list(Path.cwd().glob("*.tmp"))
    temp_files.extend(Path.cwd().glob("test_*.log"))
    temp_files.extend(Path.cwd().glob("*.lock"))
    
    for temp_file in temp_files:
        try:
            temp_file.unlink()
        except OSError:
            pass  # Ignore cleanup errors

# ============================================================================
# PARAMETRIZATION HELPERS
# ============================================================================

def pytest_generate_tests(metafunc):
    """Generate parameterized tests"""
    
    # Parameterize security vulnerability tests
    if "vulnerability_type" in metafunc.fixturenames:
        vulnerability_types = [
            "path_traversal", "command_injection", "input_validation",
            "dos_protection", "memory_bounds", "race_conditions",
            "privilege_escalation", "information_disclosure"
        ]
        metafunc.parametrize("vulnerability_type", vulnerability_types)
    
    # Parameterize performance test scenarios
    if "performance_scenario" in metafunc.fixturenames:
        scenarios = [
            ("single_agent", 1), ("few_agents", 3), ("many_agents", 8),
            ("high_load", 50), ("stress_test", 100)
        ]
        metafunc.parametrize("performance_scenario", scenarios, 
                           ids=[s[0] for s in scenarios])
    
    # Parameterize input validation tests
    if "input_validation_case" in metafunc.fixturenames:
        cases = [
            ("empty", ""), ("whitespace", "   "), ("normal", "test input"),
            ("long", "A" * 1000), ("unicode", "测试输入"), ("special", "!@#$%^&*()")
        ]
        metafunc.parametrize("input_validation_case", cases,
                           ids=[c[0] for c in cases])

# ============================================================================
# UTILITY FUNCTIONS FOR TESTS
# ============================================================================

def skip_if_not_docker():
    """Skip test if not running in Docker"""
    return pytest.mark.skipif(
        not DockerTestEnvironment.is_running_in_docker(),
        reason="Test requires Docker environment"
    )

def require_performance_mode():
    """Mark test as requiring performance mode"""
    return pytest.mark.skipif(
        os.environ.get("PERFORMANCE_TESTS", "false").lower() != "true",
        reason="Performance tests disabled (set PERFORMANCE_TESTS=true to enable)"
    )

def slow_test(timeout=60):
    """Mark test as slow with custom timeout"""
    return pytest.mark.timeout(timeout)

# Export commonly used fixtures
__all__ = [
    'temp_project_dir', 'test_config', 'mock_agents', 'test_registry',
    'test_matcher', 'test_engine', 'test_hooks', 'test_inputs',
    'malicious_inputs', 'performance_test_data', 'performance_monitor',
    'memory_tracker', 'security_framework', 'vulnerability_scanner',
    'docker_environment', 'async_test_setup', 'mock_task_tool',
    'skip_if_not_docker', 'require_performance_mode', 'slow_test'
]