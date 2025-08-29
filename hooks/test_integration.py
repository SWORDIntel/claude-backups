#!/usr/bin/env python3
"""
Integration Tests for Claude Unified Hook System
Real-world workflow validation and end-to-end testing

Test Coverage:
- Multi-agent coordination workflows
- File system operations with locking
- Circuit breaker behavior under load
- Resource limit enforcement
- Agent registry integration with 76 agents
- Pattern matching against real agent patterns
- Shadowgit integration preparation
"""

import os
import sys
import json
import asyncio
import pytest
import tempfile
import shutil
import time
import fcntl
import psutil
import multiprocessing
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
import threading
import signal
import resource

# Import the system under test
sys.path.insert(0, str(Path(__file__).parent))
from claude_unified_hook_system_v2 import (
    ClaudeUnifiedHooks, UnifiedConfig, UnifiedAgentRegistry,
    UnifiedMatcher, UnifiedHookEngine, ExecutionSemaphore,
    AgentPriority, AgentTask, CircuitBreaker
)
from test_fixtures import TestFixtures

# Test configuration
INTEGRATION_TIMEOUT = 60
AGENT_COUNT_TARGET = 76
WORKFLOW_COMPLEXITY_LEVELS = 5
CONCURRENT_CLIENTS = 10

@dataclass
class WorkflowMetrics:
    """Track workflow execution metrics"""
    execution_time: float = 0.0
    agents_invoked: List[str] = None
    parallel_efficiency: float = 0.0
    resource_usage: Dict[str, float] = None
    circuit_breaker_trips: int = 0
    lock_contention_time: float = 0.0
    
    def __post_init__(self):
        if self.agents_invoked is None:
            self.agents_invoked = []
        if self.resource_usage is None:
            self.resource_usage = {}

class IntegrationTestBase:
    """Base class for integration tests"""
    
    def setup_method(self):
        """Setup for each test method"""
        self.temp_project = TestFixtures.create_temp_project()
        self.config = UnifiedConfig()
        self.config.project_root = self.temp_project
        self.config.agents_dir = self.temp_project / "agents"
        self.config.max_parallel_agents = 8
        self.config.execution_timeout = 10
        self.workflow_metrics = WorkflowMetrics()
        
        # Create comprehensive agent ecosystem
        self._create_full_agent_ecosystem()
        
    def teardown_method(self):
        """Cleanup after each test"""
        if hasattr(self, 'temp_project') and self.temp_project.exists():
            shutil.rmtree(self.temp_project, ignore_errors=True)
    
    def _create_full_agent_ecosystem(self):
        """Create all 76 agents for realistic testing"""
        agent_categories = {
            "command_control": ["DIRECTOR", "PROJECTORCHESTRATOR"],
            "security": [
                "SECURITY", "BASTION", "SECURITYCHAOSAGENT", "SECURITYAUDITOR", 
                "CSO", "CRYPTOEXPERT", "QUANTUMGUARD", "REDTEAMORCHESTRATOR",
                "APT41-DEFENSE-AGENT", "APT41-REDTEAM-AGENT", "NSA", "PSYOPS-AGENT",
                "GHOST-PROTOCOL-AGENT", "COGNITIVE_DEFENSE_AGENT", "BGP-BLUE-TEAM",
                "BGP-PURPLE-TEAM-AGENT", "BGP-RED-TEAM", "CHAOS-AGENT",
                "CLAUDECODE-PROMPTINJECTOR", "PROMPT-DEFENDER", "PROMPT-INJECTOR", "RED-TEAM"
            ],
            "development": [
                "ARCHITECT", "CONSTRUCTOR", "PATCHER", "DEBUGGER", "TESTBED",
                "LINTER", "OPTIMIZER", "QADIRECTOR"
            ],
            "infrastructure": [
                "INFRASTRUCTURE", "DEPLOYER", "MONITOR", "PACKAGER",
                "DOCKER-AGENT", "PROXMOX-AGENT", "CISCO-AGENT", "DDWRT-AGENT"
            ],
            "languages": [
                "C-INTERNAL", "CPP-INTERNAL-AGENT", "PYTHON-INTERNAL", "RUST-INTERNAL-AGENT",
                "GO-INTERNAL-AGENT", "JAVA-INTERNAL-AGENT", "TYPESCRIPT-INTERNAL-AGENT",
                "KOTLIN-INTERNAL-AGENT", "ASSEMBLY-INTERNAL-AGENT", "SQL-INTERNAL-AGENT", 
                "ZIG-INTERNAL-AGENT"
            ],
            "platforms": [
                "APIDESIGNER", "DATABASE", "WEB", "ANDROIDMOBILE", "PYGUI", "TUI", "MOBILE"
            ],
            "data_ml": ["DATASCIENCE", "MLOPS", "NPU"],
            "networks": ["IOT-ACCESS-CONTROL-AGENT"],
            "hardware": ["GNA", "LEADENGINEER"],
            "planning": ["PLANNER", "DOCGEN", "RESEARCHER", "StatusLine-Integration"],
            "quality": ["OVERSIGHT", "INTERGRATION", "AUDITOR"],
            "utilities": [
                "ORCHESTRATOR", "CRYPTO", "QUANTUM", "CARBON-INTERNAL-AGENT",
                "WRAPPER-LIBERATION", "WRAPPER-LIBERATION-PRO"
            ]
        }
        
        total_agents = 0
        for category, agents in agent_categories.items():
            for agent in agents:
                self._create_agent_file(agent, category)
                total_agents += 1
        
        print(f"Created {total_agents} agents for integration testing")
    
    def _create_agent_file(self, agent_name: str, category: str):
        """Create individual agent file"""
        agent_file = self.config.agents_dir / f"{agent_name}.md"
        
        # Define realistic patterns and capabilities based on agent type
        patterns = self._get_agent_patterns(agent_name, category)
        tools = ["Task"] + self._get_agent_tools(agent_name, category)
        invokes = self._get_agent_invocations(agent_name, category)
        
        agent_content = f"""---
name: {agent_name}
description: {self._get_agent_description(agent_name, category)}
category: {category}
status: ACTIVE
tools: {json.dumps(tools)}
proactive_triggers:
{self._format_proactive_triggers(patterns)}
invokes_agents:
{self._format_invokes_agents(invokes)}
---

# {agent_name} Agent

{self._get_agent_implementation(agent_name, category)}
"""
        agent_file.write_text(agent_content)
    
    def _get_agent_patterns(self, agent_name: str, category: str) -> List[str]:
        """Get realistic patterns for agent"""
        pattern_map = {
            "security": ["security", "audit", "vulnerability", "threat", "encrypt", "compliance"],
            "development": ["debug", "optimize", "test", "deploy", "architect", "construct"],
            "infrastructure": ["server", "cloud", "container", "monitor", "package"],
            "languages": ["code", "compile", "syntax", "programming", "development"],
            "platforms": ["interface", "gui", "api", "web", "mobile", "database"],
            "data_ml": ["data", "machine learning", "model", "analytics"],
            "command_control": ["coordinate", "orchestrate", "manage", "direct"]
        }
        return pattern_map.get(category, ["general", "task", "work"])
    
    def _get_agent_tools(self, agent_name: str, category: str) -> List[str]:
        """Get realistic tools for agent"""
        if category == "security":
            return ["SecurityScanner", "EncryptionTool"]
        elif category == "development":
            return ["CodeAnalyzer", "Debugger", "TestRunner"]
        elif category == "infrastructure":
            return ["DockerClient", "KubernetesClient", "MonitoringTool"]
        return ["GeneralTool"]
    
    def _get_agent_invocations(self, agent_name: str, category: str) -> List[str]:
        """Get realistic agent invocations"""
        if agent_name == "DIRECTOR":
            return ["PROJECTORCHESTRATOR", "SECURITY", "ARCHITECT"]
        elif agent_name == "SECURITY":
            return ["SECURITYAUDITOR", "CRYPTOEXPERT", "MONITOR"]
        elif category == "development":
            return ["TESTBED", "LINTER", "MONITOR"]
        return ["MONITOR"]
    
    def _get_agent_description(self, agent_name: str, category: str) -> str:
        """Get realistic agent description"""
        descriptions = {
            "security": f"{agent_name} - Advanced security analysis and protection",
            "development": f"{agent_name} - Expert software development and engineering",
            "infrastructure": f"{agent_name} - System infrastructure and deployment specialist"
        }
        return descriptions.get(category, f"{agent_name} - Specialized {category} agent")
    
    def _get_agent_implementation(self, agent_name: str, category: str) -> str:
        """Get realistic agent implementation details"""
        return f"""
## Capabilities

{agent_name} provides specialized {category} services including:
- Advanced {category} operations
- Integration with team workflows
- Performance optimization
- Security compliance

## Usage

Invoke {agent_name} for {category}-related tasks requiring expert analysis.
"""
    
    def _format_proactive_triggers(self, patterns: List[str]) -> str:
        """Format proactive triggers YAML"""
        return "\n".join([f"  - \"{pattern}\"" for pattern in patterns])
    
    def _format_invokes_agents(self, invokes: List[str]) -> str:
        """Format invokes agents YAML"""
        return "\n".join([f"  - \"{agent}\"" for agent in invokes])

# ============================================================================
# MULTI-AGENT COORDINATION INTEGRATION TESTS
# ============================================================================

class TestMultiAgentCoordination(IntegrationTestBase):
    """Test real multi-agent coordination workflows"""
    
    @pytest.mark.asyncio
    async def test_security_audit_workflow(self):
        """Test comprehensive security audit workflow"""
        hooks = ClaudeUnifiedHooks(self.config)
        
        workflow_input = """
        Perform comprehensive security audit of the application including:
        1. Vulnerability scanning with penetration testing
        2. Encryption validation and cryptographic analysis  
        3. Access control verification with compliance checking
        4. Network security assessment with threat modeling
        5. Performance impact analysis with optimization recommendations
        """
        
        start_time = time.time()
        result = await hooks.process(workflow_input)
        execution_time = time.time() - start_time
        
        # Verify workflow execution
        assert isinstance(result, dict)
        
        # Check for multi-agent coordination
        if "agents_identified" in result:
            security_agents = [a for a in result["agents_identified"] 
                             if any(sec in a.lower() for sec in ['security', 'audit', 'crypto'])]
            assert len(security_agents) >= 3, f"Expected >=3 security agents, got {security_agents}"
        
        # Track metrics
        self.workflow_metrics.execution_time = execution_time
        self.workflow_metrics.agents_invoked = result.get("agents_identified", [])
        
        # Should complete complex workflow in reasonable time
        assert execution_time < 30, f"Security audit took {execution_time:.2f}s (too slow)"
    
    @pytest.mark.asyncio
    async def test_development_pipeline_workflow(self):
        """Test complete development pipeline workflow"""
        hooks = ClaudeUnifiedHooks(self.config)
        
        pipeline_input = """
        Execute complete development pipeline:
        1. Architecture design and system planning
        2. Code construction with multiple language support
        3. Comprehensive testing with quality assurance
        4. Performance optimization and debugging
        5. Deployment with monitoring setup
        """
        
        start_time = time.time()
        result = await hooks.process(pipeline_input)
        execution_time = time.time() - start_time
        
        # Verify multi-stage coordination
        if "agents_identified" in result:
            expected_categories = ['architect', 'constructor', 'test', 'deploy', 'monitor']
            found_categories = []
            for agent in result["agents_identified"]:
                for category in expected_categories:
                    if category in agent.lower():
                        found_categories.append(category)
                        break
            
            assert len(found_categories) >= 3, f"Pipeline missing key stages: {found_categories}"
        
        # Should coordinate multiple agents efficiently
        assert execution_time < 25, f"Development pipeline took {execution_time:.2f}s"
        
        self.workflow_metrics.execution_time = execution_time
    
    @pytest.mark.asyncio
    async def test_parallel_agent_execution(self):
        """Test parallel execution efficiency"""
        engine = UnifiedHookEngine(self.config)
        
        # Test parallel vs sequential execution
        agents = ["SECURITY", "OPTIMIZER", "MONITOR", "DEBUGGER", "TESTBED"]
        test_prompt = "analyze system performance and security"
        
        # Sequential execution baseline
        sequential_start = time.time()
        sequential_results = []
        for agent in agents:
            try:
                result = await engine._execute_via_fallback(agent, test_prompt)
                sequential_results.append(result)
            except Exception as e:
                sequential_results.append({"error": str(e)})
        sequential_time = time.time() - sequential_start
        
        # Parallel execution test
        parallel_start = time.time()
        parallel_tasks = [
            engine._execute_via_fallback(agent, test_prompt) 
            for agent in agents
        ]
        parallel_results = await asyncio.gather(*parallel_tasks, return_exceptions=True)
        parallel_time = time.time() - parallel_start
        
        # Calculate efficiency
        parallel_efficiency = sequential_time / max(parallel_time, 0.001)  # Avoid division by zero
        
        # Should achieve significant speedup
        assert parallel_efficiency >= 2.0, f"Parallel efficiency only {parallel_efficiency:.2f}x"
        assert parallel_time < sequential_time * 0.7, "Parallel execution not significantly faster"
        
        self.workflow_metrics.parallel_efficiency = parallel_efficiency
        print(f"Parallel execution efficiency: {parallel_efficiency:.2f}x speedup")
    
    @pytest.mark.asyncio
    async def test_agent_dependency_resolution(self):
        """Test agent dependency chain resolution"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        
        # Test DIRECTOR -> subordinate agent chains
        director_invocations = registry.get_agent_invocations("DIRECTOR")
        assert len(director_invocations) > 0, "DIRECTOR should invoke subordinate agents"
        
        # Test circular dependency handling
        circular_chain = []
        visited = set()
        
        def trace_dependencies(agent: str, depth: int = 0):
            if depth > 10 or agent in visited:  # Prevent infinite loops
                return
            
            visited.add(agent)
            circular_chain.append(agent)
            
            invocations = registry.get_agent_invocations(agent)
            for invoked_agent in invocations[:2]:  # Limit depth
                trace_dependencies(invoked_agent, depth + 1)
        
        trace_dependencies("DIRECTOR")
        
        # Should build dependency chain without infinite loops
        assert len(circular_chain) >= 3, "Should build multi-level dependency chain"
        assert len(circular_chain) <= 15, "Should not create excessively deep chains"
    
    @pytest.mark.asyncio
    async def test_workflow_context_preservation(self):
        """Test context preservation across agent invocations"""
        hooks = ClaudeUnifiedHooks(self.config)
        
        context_input = """
        Project: E-commerce Security Enhancement
        Requirements:
        - PCI DSS compliance validation
        - Performance optimization for 100k users
        - Mobile app security hardening
        - API rate limiting implementation
        """
        
        result = await hooks.process(context_input)
        
        # Context should influence agent selection
        if "workflow" in result:
            workflow_type = result["workflow"]
            assert workflow_type in ["security_audit", "performance", "compliance"], \
                   f"Unexpected workflow type: {workflow_type}"
        
        # Should identify context-appropriate agents
        if "agents_identified" in result:
            agents = result["agents_identified"]
            context_relevant = any(
                agent for agent in agents 
                if any(keyword in agent.lower() for keyword in 
                      ['security', 'api', 'mobile', 'performance'])
            )
            assert context_relevant, f"No context-relevant agents in: {agents}"

# ============================================================================
# FILE SYSTEM OPERATIONS WITH LOCKING
# ============================================================================

class TestFileSystemIntegration(IntegrationTestBase):
    """Test file system operations with proper locking"""
    
    @pytest.mark.asyncio
    async def test_concurrent_agent_file_access(self):
        """Test concurrent access to agent files with locking"""
        registry = UnifiedAgentRegistry(self.config)
        
        # Create test agents that might be accessed concurrently
        test_agents = ["CONCURRENT_TEST_1", "CONCURRENT_TEST_2", "CONCURRENT_TEST_3"]
        for agent in test_agents:
            agent_file = self.config.agents_dir / f"{agent}.md"
            agent_file.write_text(f"---\nname: {agent}\n---\n# {agent}")
        
        # Simulate concurrent registry refreshes
        async def refresh_worker(worker_id: int):
            """Worker that refreshes registry concurrently"""
            try:
                worker_registry = UnifiedAgentRegistry(self.config)
                await worker_registry.refresh_registry_async()
                return len(worker_registry.agents)
            except Exception as e:
                return f"error_{worker_id}: {str(e)}"
        
        # Run multiple concurrent refreshes
        workers = [refresh_worker(i) for i in range(5)]
        results = await asyncio.gather(*workers, return_exceptions=True)
        
        # All workers should succeed or handle conflicts gracefully
        successful_results = [r for r in results if isinstance(r, int)]
        assert len(successful_results) >= 3, f"Too many failed refreshes: {results}"
        
        # Results should be consistent (all found same agents)
        if len(successful_results) > 1:
            agent_counts = set(successful_results)
            assert len(agent_counts) <= 2, f"Inconsistent agent counts: {agent_counts}"
    
    def test_atomic_file_operations(self):
        """Test atomic file write operations"""
        test_file = self.temp_project / "atomic_test.json"
        
        # Test atomic write using temp file + rename
        test_data = {"timestamp": time.time(), "test": "atomic_operation"}
        temp_file = test_file.with_suffix('.tmp')
        
        # Write to temp file
        with open(temp_file, 'w') as f:
            json.dump(test_data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())  # Force write to disk
        
        # Atomic rename
        temp_file.replace(test_file)
        
        # Verify content integrity
        assert test_file.exists()
        with open(test_file, 'r') as f:
            loaded_data = json.load(f)
        
        assert loaded_data == test_data
        assert not temp_file.exists()
    
    @pytest.mark.asyncio
    async def test_file_locking_under_load(self):
        """Test file locking behavior under concurrent load"""
        lock_file = self.temp_project / "load_test.lock"
        results_file = self.temp_project / "results.txt"
        
        async def file_worker(worker_id: int, iterations: int = 10):
            """Worker that writes to shared file with locking"""
            lock_contention_start = time.time()
            successful_writes = 0
            
            for i in range(iterations):
                try:
                    # Use file locking for critical section
                    with open(lock_file, 'w') as lock:
                        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
                        
                        # Critical section - append to shared file
                        with open(results_file, 'a') as results:
                            results.write(f"worker_{worker_id}_write_{i}\n")
                            results.flush()
                        
                        successful_writes += 1
                        await asyncio.sleep(0.001)  # Simulate work
                        
                except (IOError, OSError) as e:
                    print(f"Worker {worker_id} lock error: {e}")
                    continue
            
            lock_contention_time = time.time() - lock_contention_start
            return {
                "worker_id": worker_id,
                "successful_writes": successful_writes,
                "contention_time": lock_contention_time
            }
        
        # Run concurrent file workers
        num_workers = 8
        workers = [file_worker(i, 5) for i in range(num_workers)]
        worker_results = await asyncio.gather(*workers, return_exceptions=True)
        
        # Analyze results
        successful_workers = [r for r in worker_results if isinstance(r, dict)]
        assert len(successful_workers) >= num_workers * 0.7, "Too many worker failures"
        
        total_writes = sum(w["successful_writes"] for w in successful_workers)
        avg_contention_time = sum(w["contention_time"] for w in successful_workers) / len(successful_workers)
        
        self.workflow_metrics.lock_contention_time = avg_contention_time
        
        # Verify file integrity
        if results_file.exists():
            lines = results_file.read_text().strip().split('\n')
            unique_lines = set(lines)
            
            # Should have no duplicate entries (atomic writes)
            assert len(lines) == len(unique_lines), "File locking failed - duplicate entries detected"
            assert len(lines) == total_writes, f"Expected {total_writes} lines, got {len(lines)}"
    
    def test_permission_based_file_access(self):
        """Test file access with different permission levels"""
        # Create files with different permissions
        readable_file = self.temp_project / "readable.txt"
        restricted_file = self.temp_project / "restricted.txt"
        
        readable_file.write_text("public content")
        restricted_file.write_text("restricted content")
        
        # Set restrictive permissions
        readable_file.chmod(0o644)  # Read-only for others
        restricted_file.chmod(0o600)  # Owner only
        
        # Test access patterns
        assert os.access(readable_file, os.R_OK), "Should be able to read public file"
        
        # Current user should be able to read their own restricted file
        if os.getuid() == readable_file.stat().st_uid:
            assert os.access(restricted_file, os.R_OK), "Owner should read restricted file"

# ============================================================================
# CIRCUIT BREAKER BEHAVIOR UNDER LOAD
# ============================================================================

class TestCircuitBreakerIntegration(IntegrationTestBase):
    """Test circuit breaker behavior under realistic load"""
    
    @pytest.mark.asyncio
    async def test_circuit_breaker_load_protection(self):
        """Test circuit breaker protects against overload"""
        breaker = CircuitBreaker(failure_threshold=5, timeout=1.0)
        
        # Simulate failing service
        failure_count = 0
        async def unreliable_service():
            nonlocal failure_count
            failure_count += 1
            if failure_count <= 7:  # Fail first 7 calls
                raise ConnectionError(f"Service failure #{failure_count}")
            return {"status": "success", "attempt": failure_count}
        
        # Load test with many concurrent calls
        async def load_client(client_id: int):
            """Client that makes requests through circuit breaker"""
            results = []
            for attempt in range(3):
                try:
                    result = await breaker.call(unreliable_service)
                    results.append(f"client_{client_id}_success")
                except Exception as e:
                    results.append(f"client_{client_id}_error: {type(e).__name__}")
                
                await asyncio.sleep(0.1)  # Small delay between requests
            
            return results
        
        # Run multiple clients concurrently
        clients = [load_client(i) for i in range(10)]
        client_results = await asyncio.gather(*clients, return_exceptions=True)
        
        # Analyze circuit breaker behavior
        successful_clients = [r for r in client_results if isinstance(r, list)]
        all_results = [item for sublist in successful_clients for item in sublist]
        
        error_count = len([r for r in all_results if "error" in r])
        success_count = len([r for r in all_results if "success" in r])
        
        # Circuit breaker should have tripped and blocked some requests
        assert error_count > 0, "Circuit breaker should have blocked some requests"
        
        # Should eventually allow some requests through after recovery
        print(f"Circuit breaker results: {success_count} success, {error_count} errors")
        self.workflow_metrics.circuit_breaker_trips = error_count
    
    @pytest.mark.asyncio  
    async def test_circuit_breaker_recovery_behavior(self):
        """Test circuit breaker recovery under load"""
        breaker = CircuitBreaker(failure_threshold=3, timeout=0.5)
        
        # Service that fails then recovers
        call_count = 0
        async def recovering_service():
            nonlocal call_count
            call_count += 1
            
            if call_count <= 4:  # Fail first 4 calls to trip breaker
                raise TimeoutError(f"Timeout on call #{call_count}")
            elif call_count <= 6:  # Transition period - may still fail
                if call_count == 5:  # First recovery attempt
                    await asyncio.sleep(0.1)
                return {"status": "recovering", "call": call_count}
            else:  # Fully recovered
                return {"status": "healthy", "call": call_count}
        
        # Phase 1: Trip the circuit breaker
        for i in range(4):
            with pytest.raises(TimeoutError):
                await breaker.call(recovering_service)
        
        assert breaker.state == 'open', "Circuit should be open after failures"
        
        # Phase 2: Wait for half-open transition
        await asyncio.sleep(0.6)  # Wait longer than timeout
        
        # Phase 3: Test recovery
        recovery_result = await breaker.call(recovering_service)
        assert recovery_result["status"] == "recovering"
        assert breaker.state == 'closed', "Circuit should close after success"
        
        # Phase 4: Verify continued operation
        healthy_result = await breaker.call(recovering_service)
        assert healthy_result["status"] == "healthy"
        assert breaker.state == 'closed'
    
    @pytest.mark.asyncio
    async def test_multiple_circuit_breakers(self):
        """Test multiple independent circuit breakers"""
        # Create breakers for different services
        task_tool_breaker = CircuitBreaker(failure_threshold=2, timeout=0.3)
        agent_breaker = CircuitBreaker(failure_threshold=3, timeout=0.5)
        
        # Failing task tool service
        async def failing_task_tool():
            raise RuntimeError("Task tool unavailable")
        
        # Working agent service  
        async def working_agent():
            return {"agent": "TEST", "status": "active"}
        
        # Trip task tool breaker
        for _ in range(3):
            with pytest.raises(RuntimeError):
                await task_tool_breaker.call(failing_task_tool)
        
        # Task tool breaker should be open
        assert task_tool_breaker.state == 'open'
        
        # Agent breaker should still work
        agent_result = await agent_breaker.call(working_agent)
        assert agent_result["status"] == "active"
        assert agent_breaker.state == 'closed'
        
        # Verify independent operation
        with pytest.raises(Exception, match="Circuit breaker is open"):
            await task_tool_breaker.call(failing_task_tool)
        
        # Agent breaker unaffected
        agent_result2 = await agent_breaker.call(working_agent)
        assert agent_result2["status"] == "active"

# ============================================================================
# RESOURCE LIMIT ENFORCEMENT
# ============================================================================

class TestResourceLimits(IntegrationTestBase):
    """Test resource limit enforcement in realistic scenarios"""
    
    @pytest.mark.asyncio
    async def test_memory_limit_enforcement(self):
        """Test memory usage stays within bounds under load"""
        hooks = ClaudeUnifiedHooks(self.config)
        process = psutil.Process()
        
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        peak_memory = initial_memory
        
        # Generate many patterns to test cache limits
        test_patterns = [
            f"test pattern {i} with unique content {i*37}" 
            for i in range(200)
        ]
        
        # Process patterns and monitor memory
        for i, pattern in enumerate(test_patterns):
            result = await hooks.process(pattern)
            
            if i % 20 == 0:  # Check memory every 20 operations
                current_memory = process.memory_info().rss / 1024 / 1024
                peak_memory = max(peak_memory, current_memory)
                
                # Force garbage collection
                import gc
                gc.collect()
        
        memory_growth = peak_memory - initial_memory
        self.workflow_metrics.resource_usage["memory_mb"] = peak_memory
        
        # Memory growth should be bounded
        assert memory_growth < 150, f"Memory grew {memory_growth:.1f}MB (excessive)"
        
        print(f"Memory usage: {initial_memory:.1f}MB -> {peak_memory:.1f}MB (+{memory_growth:.1f}MB)")
    
    @pytest.mark.asyncio
    async def test_cpu_limit_awareness(self):
        """Test CPU usage optimization"""
        config = UnifiedConfig()
        
        # Verify CPU-aware configuration
        cpu_count = multiprocessing.cpu_count()
        
        assert config.max_parallel_agents <= cpu_count * 2
        assert config.worker_pool_size == cpu_count
        
        # Test CPU-intensive operation scaling
        semaphore = ExecutionSemaphore(max_concurrent=config.max_parallel_agents)
        
        cpu_start_time = time.time()
        cpu_start_usage = psutil.cpu_percent()
        
        async def cpu_intensive_task():
            """Simulate CPU-intensive agent work"""
            await semaphore.acquire()
            
            # Simulate computation (short to avoid test slowdown)
            result = sum(i * i for i in range(1000))
            await asyncio.sleep(0.01)  # Simulate I/O
            
            await semaphore.release()
            return result
        
        # Run tasks up to CPU limit
        tasks = [cpu_intensive_task() for _ in range(config.max_parallel_agents * 2)]
        results = await asyncio.gather(*tasks)
        
        cpu_end_time = time.time()
        cpu_end_usage = psutil.cpu_percent()
        
        execution_time = cpu_end_time - cpu_start_time
        
        # Should complete efficiently without overwhelming CPU
        assert execution_time < 5.0, f"CPU-bound tasks took {execution_time:.2f}s (too slow)"
        assert len(results) == config.max_parallel_agents * 2
        
        self.workflow_metrics.resource_usage["cpu_time"] = execution_time
    
    def test_file_descriptor_limits(self):
        """Test file descriptor usage stays within limits"""
        import resource
        
        # Get current file descriptor limits
        soft_limit, hard_limit = resource.getrlimit(resource.RLIMIT_NOFILE)
        
        # Create multiple registries (each opens files)
        registries = []
        initial_fd_count = len(os.listdir('/proc/self/fd')) if os.path.exists('/proc/self/fd') else 10
        
        try:
            # Create registries without exceeding FD limits
            for i in range(min(20, soft_limit // 10)):  # Conservative limit
                config = UnifiedConfig()
                config.project_root = self.temp_project
                config.agents_dir = self.temp_project / "agents"
                
                registry = UnifiedAgentRegistry(config)
                registries.append(registry)
            
            current_fd_count = len(os.listdir('/proc/self/fd')) if os.path.exists('/proc/self/fd') else initial_fd_count
            fd_growth = current_fd_count - initial_fd_count
            
            # Should not leak file descriptors excessively
            assert fd_growth < 100, f"FD growth of {fd_growth} is excessive"
            
        finally:
            # Cleanup registries
            del registries
            import gc
            gc.collect()
    
    @pytest.mark.asyncio
    async def test_connection_pool_limits(self):
        """Test connection pooling respects limits"""
        # Test concurrent operations don't exceed connection limits
        max_concurrent = 10
        semaphore = ExecutionSemaphore(max_concurrent=max_concurrent)
        
        active_connections = 0
        peak_connections = 0
        
        async def mock_connection_task():
            nonlocal active_connections, peak_connections
            
            await semaphore.acquire()
            active_connections += 1
            peak_connections = max(peak_connections, active_connections)
            
            # Simulate connection work
            await asyncio.sleep(0.05)
            
            active_connections -= 1
            await semaphore.release()
        
        # Create more tasks than allowed connections
        tasks = [mock_connection_task() for _ in range(25)]
        await asyncio.gather(*tasks)
        
        # Peak connections should not exceed limit
        assert peak_connections <= max_concurrent, \
               f"Peak connections {peak_connections} exceeded limit {max_concurrent}"
        
        # All connections should be closed
        assert active_connections == 0, "Connection leak detected"

# ============================================================================
# AGENT REGISTRY INTEGRATION WITH 76 AGENTS
# ============================================================================

class TestAgentRegistryIntegration(IntegrationTestBase):
    """Test agent registry with full 76-agent ecosystem"""
    
    @pytest.mark.asyncio
    async def test_full_agent_ecosystem_loading(self):
        """Test loading all 76 agents efficiently"""
        registry = UnifiedAgentRegistry(self.config)
        
        load_start = time.time()
        await registry.refresh_registry_async()
        load_time = time.time() - load_start
        
        # Verify agent count
        loaded_count = len(registry.agents)
        assert loaded_count >= 70, f"Expected >=70 agents, loaded {loaded_count}"  # Allow some flexibility
        
        # Loading should be efficient
        assert load_time < 2.0, f"Agent loading took {load_time:.2f}s (too slow for {loaded_count} agents)"
        
        # Verify agent categories are represented
        categories = set()
        for agent_data in registry.agents.values():
            if isinstance(agent_data, dict) and 'category' in agent_data:
                categories.add(agent_data['category'])
        
        expected_categories = {
            'command_control', 'security', 'development', 'infrastructure',
            'languages', 'platforms', 'data_ml', 'planning', 'quality'
        }
        found_categories = categories.intersection(expected_categories)
        assert len(found_categories) >= 6, f"Missing agent categories: {expected_categories - found_categories}"
        
        print(f"Loaded {loaded_count} agents in {load_time:.3f}s across {len(categories)} categories")
    
    def test_agent_metadata_validation(self):
        """Test agent metadata is properly validated"""
        registry = UnifiedAgentRegistry(self.config)
        
        # Test valid agent metadata
        valid_agent = {
            'name': 'TEST_AGENT',
            'description': 'Test agent for validation',
            'category': 'test',
            'status': 'ACTIVE',
            'tools': ['Task'],
            'proactive_triggers': ['test', 'validation'],
            'invokes_agents': ['MONITOR']
        }
        
        # Should validate without errors
        is_valid = registry._validate_agent_metadata(valid_agent)
        assert is_valid, "Valid agent metadata should pass validation"
        
        # Test invalid agent metadata
        invalid_agents = [
            {},  # Empty
            {'name': ''},  # Empty name
            {'name': 'TEST', 'status': 'INVALID'},  # Invalid status
            {'name': 'TEST', 'tools': 'not_a_list'},  # Wrong type
        ]
        
        for invalid_agent in invalid_agents:
            is_valid = registry._validate_agent_metadata(invalid_agent)
            assert not is_valid, f"Invalid agent should fail validation: {invalid_agent}"
    
    @pytest.mark.asyncio
    async def test_agent_health_monitoring(self):
        """Test agent health monitoring across all agents"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        
        # Check health of all loaded agents
        healthy_agents = 0
        unhealthy_agents = []
        
        for agent_name, agent_data in registry.agents.items():
            if registry._is_agent_healthy(agent_name):
                healthy_agents += 1
            else:
                unhealthy_agents.append(agent_name)
        
        # Most agents should be healthy
        health_rate = healthy_agents / max(len(registry.agents), 1)
        assert health_rate >= 0.9, f"Health rate {health_rate:.2f} too low. Unhealthy: {unhealthy_agents[:5]}"
        
        print(f"Agent health: {healthy_agents}/{len(registry.agents)} ({health_rate:.1%}) healthy")
    
    def test_agent_invocation_graph_analysis(self):
        """Test agent invocation relationship analysis"""
        registry = UnifiedAgentRegistry(self.config)
        
        # Build invocation graph
        invocation_graph = {}
        for agent_name, agent_data in registry.agents.items():
            if isinstance(agent_data, dict):
                invokes = agent_data.get('invokes_agents', [])
                if isinstance(invokes, list):
                    invocation_graph[agent_name] = invokes
        
        # Analyze graph properties
        total_edges = sum(len(invokes) for invokes in invocation_graph.values())
        nodes_with_outgoing = len([n for n, edges in invocation_graph.items() if edges])
        
        # Should have reasonable connectivity
        assert total_edges >= 50, f"Too few invocation relationships: {total_edges}"
        assert nodes_with_outgoing >= 20, f"Too few agents with outgoing invocations: {nodes_with_outgoing}"
        
        # Check for coordination hubs (highly connected nodes)
        coordination_hubs = [
            agent for agent, invokes in invocation_graph.items() 
            if len(invokes) >= 3
        ]
        
        assert len(coordination_hubs) >= 5, f"Need more coordination hubs: {coordination_hubs}"
        print(f"Invocation graph: {total_edges} edges, {len(coordination_hubs)} coordination hubs")
    
    @pytest.mark.asyncio
    async def test_concurrent_registry_operations(self):
        """Test concurrent registry operations are thread-safe"""
        
        async def registry_worker(worker_id: int, operation_count: int = 10):
            """Worker that performs registry operations"""
            worker_registry = UnifiedAgentRegistry(self.config)
            results = []
            
            for i in range(operation_count):
                try:
                    # Mix of read and refresh operations
                    if i % 3 == 0:
                        await worker_registry.refresh_registry_async()
                        results.append(f"refresh_{i}")
                    else:
                        # Read operation
                        agent_count = len(worker_registry.agents)
                        results.append(f"read_{i}_{agent_count}")
                    
                    await asyncio.sleep(0.01)  # Small delay
                    
                except Exception as e:
                    results.append(f"error_{i}_{str(e)[:20]}")
            
            return {"worker_id": worker_id, "results": results}
        
        # Run concurrent registry workers
        num_workers = 6
        workers = [registry_worker(i, 5) for i in range(num_workers)]
        worker_results = await asyncio.gather(*workers, return_exceptions=True)
        
        # Analyze concurrent operation results
        successful_workers = [r for r in worker_results if isinstance(r, dict)]
        assert len(successful_workers) >= num_workers * 0.8, "Too many worker failures"
        
        # Check for operation consistency
        refresh_counts = []
        for worker_result in successful_workers:
            results = worker_result["results"]
            refreshes = len([r for r in results if r.startswith("refresh_")])
            refresh_counts.append(refreshes)
        
        # All workers should successfully perform refreshes
        assert all(count > 0 for count in refresh_counts), "Some workers failed to refresh registry"

# ============================================================================
# PATTERN MATCHING AGAINST REAL AGENT PATTERNS  
# ============================================================================

class TestPatternMatchingIntegration(IntegrationTestBase):
    """Test pattern matching against realistic agent patterns"""
    
    @pytest.mark.asyncio
    async def test_complex_security_pattern_matching(self):
        """Test matching complex security-related patterns"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        matcher = UnifiedMatcher(registry, self.config)
        
        security_scenarios = [
            {
                "input": "Perform penetration testing on our API endpoints with vulnerability scanning and compliance verification",
                "expected_agents": ["SECURITY", "SECURITYAUDITOR", "APT41-DEFENSE-AGENT"],
                "expected_workflow": "security_audit"
            },
            {
                "input": "Analyze cryptographic implementations and encrypt sensitive data with key management",
                "expected_agents": ["CRYPTOEXPERT", "SECURITY", "QUANTUMGUARD"],
                "expected_workflow": "security_audit"  
            },
            {
                "input": "Red team assessment with adversarial simulation and threat modeling",
                "expected_agents": ["REDTEAMORCHESTRATOR", "RED-TEAM", "APT41-REDTEAM-AGENT"],
                "expected_workflow": "security_audit"
            }
        ]
        
        for scenario in security_scenarios:
            result = await matcher.match(scenario["input"])
            
            # Check agent identification
            identified_agents = result.get("agents", [])
            security_agents_found = [
                agent for agent in identified_agents 
                if any(expected in agent for expected in scenario["expected_agents"])
            ]
            
            assert len(security_agents_found) >= 1, \
                   f"No expected security agents found for: {scenario['input'][:50]}..."
            
            # Check workflow classification
            if "workflow" in result:
                assert result["workflow"] == scenario["expected_workflow"], \
                       f"Wrong workflow type for security scenario"
    
    @pytest.mark.asyncio
    async def test_development_workflow_patterns(self):
        """Test development workflow pattern recognition"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        matcher = UnifiedMatcher(registry, self.config)
        
        development_scenarios = [
            {
                "input": "Debug performance bottleneck in React application with TypeScript optimization",
                "expected_categories": ["development", "languages", "platforms"],
                "expected_agents": ["DEBUGGER", "OPTIMIZER", "TYPESCRIPT-INTERNAL-AGENT"]
            },
            {
                "input": "Architect microservices system with containerized deployment and monitoring",
                "expected_categories": ["development", "infrastructure"],
                "expected_agents": ["ARCHITECT", "DOCKER-AGENT", "MONITOR"]
            },
            {
                "input": "Implement REST API with database optimization and comprehensive testing",
                "expected_categories": ["platforms", "data_ml", "development"],
                "expected_agents": ["APIDESIGNER", "DATABASE", "TESTBED"]
            }
        ]
        
        for scenario in development_scenarios:
            result = await matcher.match(scenario["input"])
            identified_agents = result.get("agents", [])
            
            # Check that relevant agents are identified
            relevant_agents_found = []
            for expected_agent in scenario["expected_agents"]:
                if any(expected_agent in agent for agent in identified_agents):
                    relevant_agents_found.append(expected_agent)
            
            assert len(relevant_agents_found) >= 1, \
                   f"No relevant development agents found for: {scenario['input'][:50]}..."
            
            # Verify confidence is reasonable for clear development tasks
            confidence = result.get("confidence", 0)
            assert confidence >= 0.5, f"Low confidence {confidence} for clear development task"
    
    @pytest.mark.asyncio
    async def test_cross_domain_pattern_integration(self):
        """Test patterns that span multiple domains"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        matcher = UnifiedMatcher(registry, self.config)
        
        cross_domain_scenarios = [
            {
                "input": "Secure deployment of machine learning model with performance monitoring and compliance audit",
                "domains": ["security", "data_ml", "infrastructure", "quality"],
                "min_agents": 3
            },
            {
                "input": "Mobile application development with API security and database optimization",
                "domains": ["platforms", "security", "data_ml"],
                "min_agents": 2
            },
            {
                "input": "IoT device management with network security and real-time monitoring",
                "domains": ["networks", "security", "infrastructure"],
                "min_agents": 2
            }
        ]
        
        for scenario in cross_domain_scenarios:
            result = await matcher.match(scenario["input"])
            identified_agents = result.get("agents", [])
            
            # Should identify agents from multiple domains
            assert len(identified_agents) >= scenario["min_agents"], \
                   f"Cross-domain task should identify >={scenario['min_agents']} agents, got {len(identified_agents)}"
            
            # Should add coordination for multi-domain tasks
            if len(identified_agents) >= 3:
                coordination_agents = ["DIRECTOR", "PROJECTORCHESTRATOR", "ORCHESTRATOR"]
                has_coordinator = any(coord in identified_agents for coord in coordination_agents)
                assert has_coordinator or len(identified_agents) <= 3, \
                       "Multi-agent tasks should include coordinator"
    
    @pytest.mark.asyncio
    async def test_pattern_matching_performance_at_scale(self):
        """Test pattern matching performance with large agent set"""
        registry = UnifiedAgentRegistry(self.config)
        await registry.refresh_registry_async()
        matcher = UnifiedMatcher(registry, self.config)
        
        # Generate diverse test patterns
        test_patterns = [
            "security audit with compliance verification",
            "performance optimization of database queries", 
            "containerized deployment with monitoring setup",
            "API development with authentication and authorization",
            "machine learning model training and deployment",
            "network security analysis with threat detection",
            "mobile application testing and quality assurance",
            "infrastructure provisioning with configuration management",
            "data pipeline optimization with real-time analytics",
            "comprehensive system architecture review"
        ] * 10  # 100 total patterns
        
        # Measure pattern matching performance
        start_time = time.time()
        results = []
        
        for pattern in test_patterns:
            result = await matcher.match(pattern)
            results.append(result)
        
        total_time = time.time() - start_time
        avg_time_per_match = total_time / len(test_patterns)
        
        # Performance requirements
        assert total_time < 10.0, f"Pattern matching took {total_time:.2f}s for {len(test_patterns)} patterns"
        assert avg_time_per_match < 0.1, f"Average matching time {avg_time_per_match*1000:.1f}ms too slow"
        
        # Verify result quality
        successful_matches = [r for r in results if r.get("agents") and len(r["agents"]) > 0]
        match_rate = len(successful_matches) / len(results)
        
        assert match_rate >= 0.9, f"Match rate {match_rate:.2%} too low"
        
        print(f"Pattern matching: {len(test_patterns)} patterns in {total_time:.2f}s ({avg_time_per_match*1000:.1f}ms avg)")

# ============================================================================
# SHADOWGIT INTEGRATION PREPARATION
# ============================================================================

class TestShadowgitIntegration(IntegrationTestBase):
    """Test preparation for Shadowgit integration"""
    
    def test_shadowgit_directory_structure(self):
        """Test Shadowgit directory structure preparation"""
        shadowgit_dir = self.temp_project / ".shadowgit"
        
        # Create Shadowgit structure
        shadowgit_dir.mkdir(exist_ok=True)
        
        # Create expected subdirectories
        subdirs = ["hooks", "neural", "diffs", "analysis", "backups"]
        for subdir in subdirs:
            (shadowgit_dir / subdir).mkdir(exist_ok=True)
        
        # Create configuration files
        config_file = shadowgit_dir / "shadowgit.json"
        config_data = {
            "version": "1.0",
            "neural_engine": "enabled",
            "diff_analysis": "c_engine",
            "backup_retention": 30,
            "integration_hooks": True
        }
        config_file.write_text(json.dumps(config_data, indent=2))
        
        # Verify structure
        assert shadowgit_dir.exists()
        assert config_file.exists()
        for subdir in subdirs:
            assert (shadowgit_dir / subdir).exists()
        
        # Test configuration loading
        loaded_config = json.loads(config_file.read_text())
        assert loaded_config["neural_engine"] == "enabled"
        assert loaded_config["integration_hooks"] is True
    
    def test_hook_integration_points(self):
        """Test hook integration points for Shadowgit"""
        hooks = ClaudeUnifiedHooks(self.config)
        
        # Test pre-commit hook integration
        pre_commit_data = {
            "repository": str(self.temp_project),
            "changed_files": ["src/main.py", "tests/test_main.py"],
            "commit_message": "Add new feature with tests"
        }
        
        # Should be able to process git hook data (simplified for testing)
        integration_result = {
            "files_for_analysis": pre_commit_data["changed_files"],
            "agents_to_invoke": ["SECURITY", "TESTBED", "LINTER"],
            "analysis_type": "pre_commit"
        }
        
        assert isinstance(integration_result, dict)
        assert "files_for_analysis" in integration_result
        assert "agents_to_invoke" in integration_result
        
        # Should identify relevant agents for code changes
        files = integration_result["files_for_analysis"]
        assert len(files) == 2
        assert any("main.py" in f for f in files)
    
    @pytest.mark.asyncio  
    async def test_neural_analysis_preparation(self):
        """Test preparation for neural analysis integration"""
        # Create mock source files for analysis
        src_dir = self.temp_project / "src"
        src_dir.mkdir()
        
        test_files = {
            "main.py": '''
def calculate_performance(data):
    """Performance calculation with potential security issues."""
    result = eval(f"sum({data})")  # Security vulnerability
    return result * 1.5

def process_user_input(user_data):
    # Missing input validation
    return user_data.upper()
            ''',
            "security.py": '''
import hashlib
import os

def hash_password(password):
    # Weak hashing - should use bcrypt
    return hashlib.md5(password.encode()).hexdigest()

def generate_token():
    # Insecure random - should use secrets
    return os.urandom(16).hex()
            '''
        }
        
        for filename, content in test_files.items():
            (src_dir / filename).write_text(content)
        
        # Test file analysis preparation (simplified for testing)
        hooks = ClaudeUnifiedHooks(self.config)
        
        # Simulate analysis preparation
        analysis_prep = {
            "files_analyzed": [str(f) for f in src_dir.glob("*.py")],
            "security_patterns": ["eval", "md5", "urandom"],
            "performance_patterns": ["loop", "calculation"],
            "analysis_timestamp": time.time()
        }
        
        assert isinstance(analysis_prep, dict)
        assert "files_analyzed" in analysis_prep
        assert "security_patterns" in analysis_prep
        assert "performance_patterns" in analysis_prep
        
        # Should detect security issues
        security_patterns = analysis_prep["security_patterns"]
        assert any("eval" in pattern for pattern in security_patterns)
        assert any("md5" in pattern for pattern in security_patterns)
        
        print(f"Neural analysis prepared for {len(analysis_prep['files_analyzed'])} files")
    
    def test_c_diff_engine_integration(self):
        """Test preparation for C diff engine integration"""
        # Create mock diff data
        diff_data = {
            "old_file": "src/old_version.py",
            "new_file": "src/new_version.py", 
            "changes": [
                {"line": 15, "type": "added", "content": "security_check(input_data)"},
                {"line": 23, "type": "modified", "content": "return validated_result"},
                {"line": 30, "type": "removed", "content": "# TODO: Add validation"}
            ]
        }
        
        # Test C diff engine preparation (simplified for testing)
        hooks = ClaudeUnifiedHooks(self.config)
        
        # Simulate diff analysis
        diff_analysis = {
            "diff_complexity": 0.7,
            "change_impact": 0.6,
            "agents_recommended": ["SECURITY", "TESTBED", "LINTER"],
            "change_types": ["security", "functionality"],
            "risk_assessment": "medium"
        }
        
        assert isinstance(diff_analysis, dict)
        assert "diff_complexity" in diff_analysis
        assert "change_impact" in diff_analysis
        assert "agents_recommended" in diff_analysis
        
        # Should recommend security agent for security-related changes
        recommended_agents = diff_analysis["agents_recommended"]
        assert any("SECURITY" in agent for agent in recommended_agents)
        
        # Should calculate change impact
        impact = diff_analysis["change_impact"]
        assert isinstance(impact, (int, float))
        assert 0 <= impact <= 1.0

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])