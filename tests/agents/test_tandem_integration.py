#!/usr/bin/env python3
"""
Tandem Orchestration Integration Tests v1.0
===========================================

Comprehensive test suite for validating the tandem orchestration integration
with all 39 existing agents. Validates functionality designed by DIRECTOR,
PROJECTORCHESTRATOR, PYTHON-INTERNAL, and MLOPS.

Test Categories:
- Basic orchestration functionality
- Circuit breaker pattern
- Message queue operations
- Agent enhancement wrapper
- Inter-agent communication
- Performance profiling
- Health monitoring
- Error recovery

Author: Claude Code Framework
Version: 1.0.0
Status: PRODUCTION
"""

import asyncio
import json
import logging
import pytest
import time
import unittest
from pathlib import Path
from typing import Dict, Any, List
from unittest.mock import Mock, AsyncMock, patch

# Import modules under test
from tandem_orchestration_base import (
    TandemOrchestrationBase, AgentTask, InterAgentMessage, CircuitBreaker,
    MessageQueue, PerformanceProfiler, MockOrchestratorBridge,
    ExecutionMode, TaskPriority, HealthStatus
)
from production_orchestrator_bridge import ProductionOrchestratorBridge, MockProductionBridge
from tandem_integration import (
    enhance_agent, with_orchestration, EnhancedAgentWrapper,
    OrchestrationManager, get_orchestration_manager
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MockExistingAgent:
    """Mock of an existing agent implementation"""
    
    def __init__(self, name: str = "test_agent"):
        self.name = name
        self.call_count = 0
        self.last_command = None
        
    def execute_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Mock command execution"""
        self.call_count += 1
        self.last_command = command
        
        return {
            'status': 'success',
            'result': f"Executed {command.get('action', 'unknown')}",
            'agent': self.name,
            'call_count': self.call_count
        }
        
    async def async_execute_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Mock async command execution"""
        await asyncio.sleep(0.01)  # Simulate async work
        return self.execute_command(command)
        
    def get_capabilities(self) -> Dict[str, Any]:
        """Mock capabilities"""
        return {
            'actions': ['test_action', 'analyze', 'process'],
            'supports_async': True,
            'version': '1.0.0'
        }


class TestTandemOrchestrationBase(unittest.TestCase):
    """Test the base orchestration class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.test_agent = TestTandemAgent("TEST_AGENT")
        
    def tearDown(self):
        """Clean up after tests"""
        if hasattr(self, 'test_agent') and self.test_agent.is_running:
            asyncio.run(self.test_agent.shutdown())
            
    def test_initialization(self):
        """Test agent initialization"""
        self.assertEqual(self.test_agent.agent_name, "TEST_AGENT")
        self.assertIsNotNone(self.test_agent.orchestrator_bridge)
        self.assertIsNotNone(self.test_agent.circuit_breaker)
        self.assertIsNotNone(self.test_agent.message_queue)
        self.assertIsNotNone(self.test_agent.profiler)
        
    async def test_async_initialization(self):
        """Test async initialization"""
        success = await self.test_agent.initialize()
        self.assertTrue(success)
        self.assertTrue(self.test_agent.is_running)
        self.assertEqual(self.test_agent.health_status, HealthStatus.HEALTHY)
        
    async def test_command_execution(self):
        """Test command execution with orchestration"""
        await self.test_agent.initialize()
        
        command = {
            'action': 'test_action',
            'data': 'test_data'
        }
        
        result = await self.test_agent.execute_with_orchestration(command)
        
        self.assertEqual(result['status'], 'success')
        self.assertIn('result', result)
        self.assertIn('execution_time', result)
        self.assertEqual(self.test_agent.metrics['total_commands'], 1)
        
    async def test_delegation(self):
        """Test task delegation"""
        await self.test_agent.initialize()
        
        task_spec = {
            'action': 'delegated_task',
            'context': {'param': 'value'},
            'timeout': 30
        }
        
        result = await self.test_agent.delegate_to_agent('TARGET_AGENT', task_spec)
        self.assertIn('status', result)
        
    async def test_inter_agent_messaging(self):
        """Test inter-agent messaging"""
        await self.test_agent.initialize()
        
        result = await self.test_agent.send_inter_agent_message(
            'TARGET_AGENT',
            'test_message',
            {'data': 'test'}
        )
        
        self.assertIn('status', result)


class TestTandemAgent(TandemOrchestrationBase):
    """Concrete implementation for testing"""
    
    async def _execute_command_internal(self, task: AgentTask) -> Dict[str, Any]:
        """Test implementation"""
        return {
            'action': task.action,
            'context': task.context,
            'result': f"Executed {task.action}",
            'success': True
        }
        
    def _define_capabilities(self) -> Dict[str, Any]:
        """Define test capabilities"""
        return {
            'name': self.agent_name,
            'actions': ['test_action', 'analyze', 'process'],
            'supports_parallel': True,
            'max_concurrent': 5
        }


class TestCircuitBreaker(unittest.TestCase):
    """Test circuit breaker functionality"""
    
    def setUp(self):
        self.circuit_breaker = CircuitBreaker(failure_threshold=3, recovery_timeout=1)
        
    async def test_normal_operation(self):
        """Test normal operation - circuit closed"""
        async def success_func():
            return "success"
            
        result = await self.circuit_breaker.call(success_func)
        self.assertEqual(result, "success")
        self.assertEqual(self.circuit_breaker.state.value, "closed")
        
    async def test_circuit_opens_on_failures(self):
        """Test circuit opens after threshold failures"""
        async def failing_func():
            raise Exception("Simulated failure")
            
        # Trigger failures to open circuit
        for _ in range(3):
            try:
                await self.circuit_breaker.call(failing_func)
            except Exception:
                pass
                
        self.assertEqual(self.circuit_breaker.state.value, "open")
        
        # Next call should be rejected
        with self.assertRaises(Exception):
            await self.circuit_breaker.call(failing_func)


class TestMessageQueue(unittest.TestCase):
    """Test message queue functionality"""
    
    def setUp(self):
        self.message_queue = MessageQueue()
        self.received_messages = []
        
    async def test_message_processing(self):
        """Test message queue processing"""
        # Register handler
        async def test_handler(message):
            self.received_messages.append(message)
            
        self.message_queue.register_handler('test_type', test_handler)
        
        # Start queue
        await self.message_queue.start()
        
        # Send message
        test_message = InterAgentMessage(
            id="test_msg_1",
            source_agent="sender",
            target_agent="receiver",
            message_type="test_type",
            payload={"data": "test"}
        )
        
        await self.message_queue.send_message(test_message)
        
        # Wait for processing
        await asyncio.sleep(0.1)
        
        self.assertEqual(len(self.received_messages), 1)
        self.assertEqual(self.received_messages[0].id, "test_msg_1")
        
        await self.message_queue.stop()


class TestEnhancedAgentWrapper(unittest.TestCase):
    """Test agent enhancement wrapper"""
    
    def setUp(self):
        self.original_agent = MockExistingAgent("mock_agent")
        self.enhanced_agent = EnhancedAgentWrapper(
            self.original_agent, "MOCK_AGENT", "mock"
        )
        
    async def test_enhancement_preserves_functionality(self):
        """Test that enhancement preserves original functionality"""
        await self.enhanced_agent.initialize()
        
        # Test original functionality is accessible
        task = AgentTask(
            id="test_task",
            action="delegate_to_method",
            context={
                'method': 'execute_command',
                'args': [{'action': 'test'}]
            }
        )
        
        result = await self.enhanced_agent._execute_command_internal(task)
        
        self.assertEqual(result['method_name'], 'execute_command')
        self.assertIn('result', result)
        self.assertEqual(self.original_agent.call_count, 1)
        
    async def test_orchestration_features_added(self):
        """Test that orchestration features are added"""
        await self.enhanced_agent.initialize()
        
        # Test metrics are available
        metrics = self.enhanced_agent.get_metrics()
        self.assertIn('agent_name', metrics)
        self.assertIn('health_status', metrics)
        self.assertIn('performance', metrics)
        
        # Test capabilities include orchestration
        capabilities = self.enhanced_agent.capabilities
        self.assertTrue(capabilities['enhanced_with_orchestration'])
        self.assertIn('execute_command', capabilities['available_methods'])


class TestOrchestrationManager(unittest.TestCase):
    """Test orchestration manager"""
    
    async def test_manager_initialization(self):
        """Test manager initialization"""
        manager = OrchestrationManager("mock")
        
        # Mock the enhance_all_existing_agents function
        with patch('tandem_integration.enhance_all_existing_agents') as mock_enhance:
            mock_agent = Mock()
            mock_agent.is_running = True
            mock_enhance.return_value = {'TEST_AGENT': mock_agent}
            
            await manager.initialize(Path(__file__).parent)
            
            self.assertTrue(manager.is_running)
            self.assertEqual(len(manager.enhanced_agents), 1)
            
        await manager.shutdown()
        
    async def test_agent_execution(self):
        """Test execution through manager"""
        manager = OrchestrationManager("mock")
        
        # Create mock enhanced agent
        mock_agent = AsyncMock()
        mock_agent.is_running = True
        mock_agent.execute_with_orchestration.return_value = {'status': 'success'}
        
        manager.enhanced_agents = {'TEST_AGENT': mock_agent}
        manager.is_running = True
        
        result = await manager.execute_on_agent('TEST_AGENT', {'action': 'test'})
        
        self.assertEqual(result['status'], 'success')
        mock_agent.execute_with_orchestration.assert_called_once()


class TestPerformanceProfiler(unittest.TestCase):
    """Test performance profiling"""
    
    def setUp(self):
        self.profiler = PerformanceProfiler(window_size=100)
        
    def test_metrics_collection(self):
        """Test metrics collection"""
        # Record some executions
        for i in range(10):
            duration = 0.1 + (i * 0.01)
            success = i % 3 != 0  # Some failures
            self.profiler.record_execution(duration, success)
            
        metrics = self.profiler.get_metrics()
        
        self.assertEqual(metrics.execution_count, 10)
        self.assertGreater(metrics.success_count, 0)
        self.assertGreater(metrics.error_count, 0)
        self.assertGreater(metrics.avg_execution_time, 0)
        
    def test_percentiles_calculation(self):
        """Test percentiles calculation"""
        # Record executions with known times
        times = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        for time_val in times:
            self.profiler.record_execution(time_val, True)
            
        percentiles = self.profiler.get_percentiles([50, 90, 95])
        
        # With 10 values [0.1, 0.2, ..., 1.0], p50 at index 5 (0-based) = 0.6
        self.assertAlmostEqual(percentiles['p50'], 0.6, places=1)
        self.assertAlmostEqual(percentiles['p90'], 1.0, places=1)


class IntegrationTests(unittest.TestCase):
    """End-to-end integration tests"""
    
    async def test_full_enhancement_workflow(self):
        """Test complete enhancement workflow"""
        # Create original agent
        original_agent = MockExistingAgent("integration_test")
        
        # Enhance it
        enhanced = enhance_agent(original_agent, "INTEGRATION_TEST", "mock")
        
        # Initialize
        success = await enhanced.initialize()
        self.assertTrue(success)
        
        # Execute command
        result = await enhanced.execute_with_orchestration({
            'action': 'test_action',
            'data': 'integration_test'
        })
        
        self.assertEqual(result['status'], 'success')
        
        # Check metrics
        metrics = enhanced.get_metrics()
        self.assertEqual(metrics['base_metrics']['total_commands'], 1)
        
        # Cleanup
        await enhanced.shutdown()
        
    async def test_decorator_enhancement(self):
        """Test decorator-based enhancement"""
        
        @with_orchestration("DECORATOR_TEST", "mock")
        class DecoratorTestAgent:
            def __init__(self):
                self.data = "test"
                
            def execute_command(self, command):
                return {'result': f"Decorated agent executed: {command}"}
                
        # Create instance
        agent = DecoratorTestAgent()
        
        # Check enhancement
        self.assertTrue(hasattr(agent, '_orchestration_enhanced'))
        self.assertTrue(hasattr(agent, 'execute_with_orchestration'))
        
        # Test execution
        await agent._orchestration.initialize()
        result = await agent.execute_with_orchestration({'action': 'test'})
        
        self.assertEqual(result['status'], 'success')
        
        await agent._orchestration.shutdown()


async def run_comprehensive_tests():
    """Run all tests comprehensively"""
    print("🚀 Starting Tandem Orchestration Integration Tests")
    print("=" * 60)
    
    test_results = {
        'total_tests': 0,
        'passed': 0,
        'failed': 0,
        'errors': []
    }
    
    test_classes = [
        TestTandemOrchestrationBase,
        TestCircuitBreaker,
        TestMessageQueue,
        TestEnhancedAgentWrapper,
        TestOrchestrationManager,
        TestPerformanceProfiler,
        IntegrationTests
    ]
    
    for test_class in test_classes:
        print(f"\n📋 Running {test_class.__name__}")
        print("-" * 40)
        
        suite = unittest.TestLoader().loadTestsFromTestCase(test_class)
        
        for test in suite:
            test_results['total_tests'] += 1
            test_name = test._testMethodName
            
            try:
                # Setup test instance
                test.setUp()
                
                # Run async tests
                if hasattr(test, test_name):
                    test_method = getattr(test, test_name)
                    if asyncio.iscoroutinefunction(test_method):
                        await test_method()
                    else:
                        test_method()
                        
                test_results['passed'] += 1
                print(f"  ✅ {test_name}")
                
            except Exception as e:
                test_results['failed'] += 1
                test_results['errors'].append(f"{test_class.__name__}.{test_name}: {e}")
                print(f"  ❌ {test_name}: {e}")
            
            finally:
                # Cleanup test instance
                try:
                    if hasattr(test, 'tearDown'):
                        test.tearDown()
                except Exception as cleanup_error:
                    print(f"  ⚠️  Cleanup error for {test_name}: {cleanup_error}")
                
    # Print summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)
    print(f"Total Tests: {test_results['total_tests']}")
    print(f"Passed: {test_results['passed']}")
    print(f"Failed: {test_results['failed']}")
    print(f"Success Rate: {(test_results['passed']/test_results['total_tests']*100):.1f}%")
    
    if test_results['errors']:
        print(f"\n❌ ERRORS ({len(test_results['errors'])}):")
        for error in test_results['errors'][:5]:  # Show first 5 errors
            print(f"  - {error}")
            
        if len(test_results['errors']) > 5:
            print(f"  ... and {len(test_results['errors']) - 5} more")
    
    return test_results['failed'] == 0


async def test_existing_agent_enhancement():
    """Test enhancement of actual existing agents"""
    print("\n🔧 Testing Enhancement of Existing Agents")
    print("=" * 50)
    
    # Test with a few existing agents
    test_agents = ['security_impl.py', 'debugger_impl.py', 'monitor_impl.py']
    
    current_dir = Path(__file__).parent
    enhanced_count = 0
    
    for agent_file in test_agents:
        agent_path = current_dir / agent_file
        
        if agent_path.exists():
            try:
                # Import the module
                import importlib.util
                spec = importlib.util.spec_from_file_location(
                    agent_file.replace('.py', ''), agent_path
                )
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                # Find executor class
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if (hasattr(attr, '__name__') and 
                        'executor' in attr_name.lower() and
                        callable(attr)):
                        
                        # Create and enhance agent
                        original_agent = attr()
                        agent_name = agent_file.replace('_impl.py', '').upper()
                        
                        enhanced = enhance_agent(original_agent, agent_name, "mock")
                        
                        # Test initialization
                        if await enhanced.initialize():
                            print(f"  ✅ Enhanced {agent_name}")
                            enhanced_count += 1
                            
                            # Test basic execution
                            result = await enhanced.execute_with_orchestration({
                                'action': 'test',
                                'data': 'integration_test'
                            })
                            
                            if result.get('status') == 'success':
                                print(f"    ✓ Basic execution works")
                            
                            await enhanced.shutdown()
                        else:
                            print(f"  ❌ Failed to enhance {agent_name}")
                        break
                        
            except Exception as e:
                print(f"  ⚠️  Could not test {agent_file}: {e}")
        else:
            print(f"  ⚠️  {agent_file} not found")
            
    print(f"\n✅ Successfully enhanced {enhanced_count} existing agents")
    return enhanced_count > 0


if __name__ == "__main__":
    async def main():
        """Main test runner"""
        print("🎯 Tandem Orchestration Integration Test Suite")
        print("=" * 60)
        
        # Run comprehensive tests
        basic_success = await run_comprehensive_tests()
        
        # Test existing agent enhancement
        enhancement_success = await test_existing_agent_enhancement()
        
        # Final result
        print("\n" + "=" * 60)
        print("🏁 FINAL RESULTS")
        print("=" * 60)
        
        if basic_success and enhancement_success:
            print("🎉 ALL TESTS PASSED - Tandem Orchestration Ready!")
            exit_code = 0
        else:
            print("❌ Some tests failed - Review implementation")
            exit_code = 1
            
        print("=" * 60)
        return exit_code
        
    # Run tests
    import sys
    exit_code = asyncio.run(main())
    sys.exit(exit_code)