#!/usr/bin/env python3
"""
Comprehensive Test Suite for Enhanced Agent Coordination System
Tests all agent interactions, coordination protocols, and error recovery
"""

import unittest
import asyncio
import json
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime
import time

# Import the enhanced agent system
from ENHANCED_AGENT_INTEGRATION import (
    AgentOrchestrator,
    AgentRegistry,
    AgentMessage,
    AgentCommunicationBridge,
    Priority,
    AgentStatus
)


class TestAgentCoordination(unittest.TestCase):
    """Test suite for agent coordination framework"""
    
    def setUp(self):
        """Set up test environment"""
        self.orchestrator = AgentOrchestrator()
        self.bridge = AgentCommunicationBridge(self.orchestrator)
        
    def test_agent_registry_initialization(self):
        """Test that all agents are properly registered"""
        registry = AgentRegistry()
        
        # Verify all agents are registered
        expected_agents = [
            "DIRECTOR", "PROJECT_ORCHESTRATOR", "ARCHITECT", "CONSTRUCTOR",
            "SECURITY", "TESTBED", "OPTIMIZER", "DEBUGGER", "DEPLOYER",
            "MONITOR", "DATABASE", "ML_OPS", "WEB", "PATCHER", "LINTER",
            "DOCGEN", "PACKAGER", "API_DESIGNER", "C_INTERNAL",
            "PYTHON_INTERNAL", "MOBILE", "PYGUI"
        ]
        
        for agent in expected_agents:
            self.assertIn(agent, registry.agents)
            
    def test_dependency_graph_construction(self):
        """Test dependency graph is correctly built"""
        graph = self.orchestrator.dependency_graph
        
        # Test critical dependencies
        self.assertTrue(graph.has_edge("DIRECTOR", "PROJECT_ORCHESTRATOR"))
        self.assertTrue(graph.has_edge("ARCHITECT", "CONSTRUCTOR"))
        self.assertTrue(graph.has_edge("TESTBED", "OPTIMIZER"))
        self.assertTrue(graph.has_edge("PACKAGER", "DEPLOYER"))
        
    def test_execution_wave_calculation(self):
        """Test parallel execution wave calculation"""
        agents = ["ARCHITECT", "CONSTRUCTOR", "TESTBED", "OPTIMIZER"]
        waves = self.orchestrator._calculate_execution_waves(agents)
        
        # ARCHITECT should be in first wave
        self.assertIn("ARCHITECT", waves[0])
        
        # CONSTRUCTOR depends on ARCHITECT, should be in later wave
        architect_wave = next(i for i, wave in enumerate(waves) if "ARCHITECT" in wave)
        constructor_wave = next(i for i, wave in enumerate(waves) if "CONSTRUCTOR" in wave)
        self.assertGreater(constructor_wave, architect_wave)
        
    def test_circular_dependency_detection(self):
        """Test that circular dependencies are detected"""
        # Create circular dependency
        self.orchestrator.dependency_graph.add_edge("TESTBED", "CONSTRUCTOR")
        self.orchestrator.dependency_graph.add_edge("CONSTRUCTOR", "TESTBED")
        
        with self.assertRaises(ValueError) as context:
            self.orchestrator._calculate_execution_waves(["CONSTRUCTOR", "TESTBED"])
        
        self.assertIn("Circular dependency", str(context.exception))


class TestAsyncAgentOperations(unittest.TestCase):
    """Test async agent operations"""
    
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
    def tearDown(self):
        self.loop.close()
        
    def test_message_passing(self):
        """Test message passing between agents"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            bridge = AgentCommunicationBridge(orchestrator)
            
            # Create test message
            message = AgentMessage(
                source_agent="DIRECTOR",
                target_agents=["ARCHITECT", "DATABASE"],
                action="design",
                payload={"requirements": "test"},
                priority=Priority.HIGH
            )
            
            # Send message
            await bridge.send_message(message)
            
            # Verify message in queue
            self.assertFalse(orchestrator.message_queue.empty())
            queued_message = await orchestrator.message_queue.get()
            self.assertEqual(queued_message.action, "design")
            
        self.loop.run_until_complete(run_test())
        
    def test_workflow_execution(self):
        """Test complete workflow execution"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            # Simple test workflow
            workflow = {
                "name": "Test Workflow",
                "steps": [
                    {
                        "name": "Design",
                        "agents": ["ARCHITECT"],
                        "action": "design",
                        "parameters": {"type": "microservice"}
                    },
                    {
                        "name": "Build",
                        "agents": ["CONSTRUCTOR"],
                        "action": "build",
                        "parameters": {"framework": "fastapi"}
                    }
                ]
            }
            
            # Mock agent execution
            with patch.object(orchestrator, '_simulate_agent_execution', 
                            new_callable=AsyncMock) as mock_exec:
                mock_exec.return_value = {"status": "success"}
                
                result = await orchestrator.execute_workflow(workflow)
                
                # Verify workflow completed
                self.assertIn("ARCHITECT", result)
                self.assertIn("CONSTRUCTOR", result)
                self.assertEqual(result["ARCHITECT"]["status"], "success")
                
        self.loop.run_until_complete(run_test())
        
    def test_parallel_wave_execution(self):
        """Test that agents in same wave execute in parallel"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            # Workflow with parallel agents
            workflow = {
                "name": "Parallel Test",
                "steps": [
                    {
                        "name": "Parallel Design",
                        "agents": ["DATABASE", "SECURITY"],  # No dependencies between them
                        "action": "analyze",
                        "parameters": {}
                    }
                ]
            }
            
            execution_times = {}
            
            async def mock_execution(workflow_id, agent_id, step):
                start = time.time()
                await asyncio.sleep(0.1)  # Simulate work
                execution_times[agent_id] = time.time()
                return {"status": "success"}
            
            with patch.object(orchestrator, '_execute_agent', mock_execution):
                await orchestrator.execute_workflow(workflow)
                
                # Verify agents executed in parallel (within small time window)
                times = list(execution_times.values())
                time_diff = max(times) - min(times)
                self.assertLess(time_diff, 0.05)  # Should complete nearly simultaneously
                
        self.loop.run_until_complete(run_test())


class TestAgentCommunicationProtocols(unittest.TestCase):
    """Test agent communication protocols"""
    
    def test_message_priority(self):
        """Test message priority ordering"""
        messages = [
            AgentMessage(action="low", priority=Priority.LOW),
            AgentMessage(action="critical", priority=Priority.CRITICAL),
            AgentMessage(action="medium", priority=Priority.MEDIUM),
        ]
        
        # Sort by priority
        sorted_messages = sorted(messages, key=lambda m: m.priority.value)
        
        # Verify critical comes first
        self.assertEqual(sorted_messages[0].action, "critical")
        self.assertEqual(sorted_messages[-1].action, "low")
        
    def test_message_correlation(self):
        """Test message correlation tracking"""
        parent_message = AgentMessage(
            action="parent",
            correlation_id="parent-123"
        )
        
        child_message = AgentMessage(
            action="child",
            correlation_id=parent_message.correlation_id
        )
        
        self.assertEqual(parent_message.correlation_id, child_message.correlation_id)
        
    def test_capability_lookup(self):
        """Test agent capability lookup"""
        registry = AgentRegistry()
        
        # Mock capability registration
        registry.capabilities["ml_training"] = ["ML_OPS"]
        registry.capabilities["security_scan"] = ["SECURITY"]
        
        ml_agents = registry.find_agents_with_capability("ml_training")
        self.assertIn("ML_OPS", ml_agents)
        
        security_agents = registry.find_agents_with_capability("security_scan")
        self.assertIn("SECURITY", security_agents)


class TestErrorHandling(unittest.TestCase):
    """Test error handling and recovery"""
    
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
    def tearDown(self):
        self.loop.close()
        
    def test_agent_failure_handling(self):
        """Test handling of agent failures"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            workflow = {
                "name": "Failure Test",
                "steps": [
                    {
                        "name": "Failing Step",
                        "agents": ["TESTBED"],
                        "action": "test",
                        "parameters": {}
                    }
                ]
            }
            
            # Mock agent to fail
            async def failing_execution(workflow_id, agent_id, step):
                raise RuntimeError("Agent failed")
            
            with patch.object(orchestrator, '_execute_agent', failing_execution):
                with self.assertRaises(RuntimeError) as context:
                    await orchestrator.execute_workflow(workflow)
                
                self.assertIn("Agent TESTBED failed", str(context.exception))
                
        self.loop.run_until_complete(run_test())
        
    def test_timeout_handling(self):
        """Test message timeout handling"""
        message = AgentMessage(
            action="test",
            timeout=1  # 1 second timeout
        )
        
        # Check if message has expired
        time.sleep(2)
        current_time = datetime.now()
        message_age = (current_time - message.timestamp).total_seconds()
        
        self.assertGreater(message_age, message.timeout)


class TestSecurityVetoPower(unittest.TestCase):
    """Test SECURITY agent veto power"""
    
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
    def tearDown(self):
        self.loop.close()
        
    def test_security_veto(self):
        """Test that SECURITY can veto operations"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            # Simulate dangerous operation
            dangerous_message = AgentMessage(
                source_agent="DEPLOYER",
                target_agents=["PRODUCTION"],
                action="deploy_unsafe_code",
                payload={"contains_vulnerability": True},
                priority=Priority.HIGH
            )
            
            # Mock SECURITY agent detection
            async def security_check(message):
                if message.payload.get("contains_vulnerability"):
                    veto_message = AgentMessage(
                        source_agent="SECURITY",
                        target_agents=["ALL"],
                        action="VETO",
                        payload={"reason": "Vulnerability detected"},
                        priority=Priority.CRITICAL
                    )
                    return veto_message
                return None
            
            veto = await security_check(dangerous_message)
            
            self.assertIsNotNone(veto)
            self.assertEqual(veto.action, "VETO")
            self.assertEqual(veto.priority, Priority.CRITICAL)
            
        self.loop.run_until_complete(run_test())


class TestPerformanceMetrics(unittest.TestCase):
    """Test performance monitoring and metrics"""
    
    def test_execution_timing(self):
        """Test agent execution timing"""
        start_time = time.time()
        
        # Simulate agent work
        time.sleep(0.1)
        
        execution_time = time.time() - start_time
        
        # Verify timing is tracked correctly
        self.assertGreater(execution_time, 0.09)
        self.assertLess(execution_time, 0.15)
        
    def test_resource_tracking(self):
        """Test resource usage tracking"""
        agent_resources = {
            "OPTIMIZER": {"cpu": 4, "memory": 8},
            "ML_OPS": {"cpu": 8, "memory": 16},
            "TESTBED": {"cpu": 2, "memory": 4}
        }
        
        total_cpu = sum(r["cpu"] for r in agent_resources.values())
        total_memory = sum(r["memory"] for r in agent_resources.values())
        
        # Verify resource limits
        self.assertLessEqual(total_cpu, 32)  # Max 32 cores
        self.assertLessEqual(total_memory, 128)  # Max 128GB


class TestIntegrationScenarios(unittest.TestCase):
    """Test complete integration scenarios"""
    
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
    def tearDown(self):
        self.loop.close()
        
    def test_full_stack_development_workflow(self):
        """Test complete full-stack development workflow"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            # Complex multi-agent workflow
            workflow = {
                "name": "Full Stack Development",
                "steps": [
                    {
                        "name": "Architecture",
                        "agents": ["ARCHITECT", "DATABASE", "API_DESIGNER"],
                        "action": "design",
                        "parameters": {"type": "microservices"}
                    },
                    {
                        "name": "Security Review",
                        "agents": ["SECURITY"],
                        "action": "review",
                        "parameters": {}
                    },
                    {
                        "name": "Implementation",
                        "agents": ["CONSTRUCTOR", "WEB", "PYTHON_INTERNAL"],
                        "action": "implement",
                        "parameters": {}
                    },
                    {
                        "name": "Testing",
                        "agents": ["TESTBED", "LINTER"],
                        "action": "test",
                        "parameters": {"coverage_target": 0.8}
                    },
                    {
                        "name": "Optimization",
                        "agents": ["OPTIMIZER"],
                        "action": "optimize",
                        "parameters": {}
                    },
                    {
                        "name": "Deployment",
                        "agents": ["PACKAGER", "DEPLOYER", "MONITOR"],
                        "action": "deploy",
                        "parameters": {"environment": "staging"}
                    }
                ]
            }
            
            # Mock all agent executions
            with patch.object(orchestrator, '_simulate_agent_execution',
                            new_callable=AsyncMock) as mock_exec:
                mock_exec.return_value = {"status": "success", "output": "completed"}
                
                result = await orchestrator.execute_workflow(workflow)
                
                # Verify all agents executed
                expected_agents = [
                    "ARCHITECT", "DATABASE", "API_DESIGNER", "SECURITY",
                    "CONSTRUCTOR", "WEB", "PYTHON_INTERNAL", "TESTBED",
                    "LINTER", "OPTIMIZER", "PACKAGER", "DEPLOYER", "MONITOR"
                ]
                
                for agent in expected_agents:
                    self.assertIn(agent, result)
                    self.assertEqual(result[agent]["status"], "success")
                    
        self.loop.run_until_complete(run_test())
        
    def test_ml_pipeline_workflow(self):
        """Test ML pipeline workflow"""
        async def run_test():
            orchestrator = AgentOrchestrator()
            
            workflow = {
                "name": "ML Pipeline",
                "steps": [
                    {
                        "name": "Data Preparation",
                        "agents": ["DATABASE", "PYTHON_INTERNAL"],
                        "action": "prepare_data",
                        "parameters": {"dataset": "training_data"}
                    },
                    {
                        "name": "Model Training",
                        "agents": ["ML_OPS"],
                        "action": "train_model",
                        "parameters": {"algorithm": "xgboost"}
                    },
                    {
                        "name": "Model Optimization",
                        "agents": ["OPTIMIZER"],
                        "action": "optimize_model",
                        "parameters": {}
                    },
                    {
                        "name": "Model Deployment",
                        "agents": ["DEPLOYER", "MONITOR"],
                        "action": "deploy_model",
                        "parameters": {"strategy": "canary"}
                    }
                ]
            }
            
            with patch.object(orchestrator, '_simulate_agent_execution',
                            new_callable=AsyncMock) as mock_exec:
                mock_exec.return_value = {"status": "success", "model_accuracy": 0.95}
                
                result = await orchestrator.execute_workflow(workflow)
                
                # Verify ML pipeline completed
                self.assertIn("ML_OPS", result)
                self.assertEqual(result["ML_OPS"]["status"], "success")
                
        self.loop.run_until_complete(run_test())


def run_tests():
    """Run all tests"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestAgentCoordination))
    suite.addTests(loader.loadTestsFromTestCase(TestAsyncAgentOperations))
    suite.addTests(loader.loadTestsFromTestCase(TestAgentCommunicationProtocols))
    suite.addTests(loader.loadTestsFromTestCase(TestErrorHandling))
    suite.addTests(loader.loadTestsFromTestCase(TestSecurityVetoPower))
    suite.addTests(loader.loadTestsFromTestCase(TestPerformanceMetrics))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegrationScenarios))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "="*50)
    print("TEST SUMMARY")
    print("="*50)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Success rate: {((result.testsRun - len(result.failures) - len(result.errors)) / result.testsRun * 100):.1f}%")
    
    return result


if __name__ == "__main__":
    result = run_tests()
    
    # Exit with appropriate code
    exit(0 if result.wasSuccessful() else 1)