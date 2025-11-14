#!/usr/bin/env python3
"""
Test script for Constructor agent implementation
Tests the core orchestration system functionality
"""

import asyncio
import logging
import sys
from pathlib import Path

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


async def test_basic_import():
    """Test that we can import the orchestrator"""
    try:
        from production_orchestrator import ExecutionMode, Priority, TandemOrchestrator

        logger.info("✅ Successfully imported TandemOrchestrator")
        return TandemOrchestrator, ExecutionMode, Priority
    except Exception as e:
        logger.error(f"❌ Import failed: {e}")
        return None, None, None


async def test_orchestrator_creation():
    """Test creating the orchestrator"""
    try:
        TandemOrchestrator, ExecutionMode, Priority = await test_basic_import()
        if not TandemOrchestrator:
            return None

        orchestrator = TandemOrchestrator()
        logger.info("✅ Successfully created orchestrator instance")
        return orchestrator
    except Exception as e:
        logger.error(f"❌ Orchestrator creation failed: {e}")
        return None


async def test_initialization():
    """Test orchestrator initialization"""
    try:
        orchestrator = await test_orchestrator_creation()
        if not orchestrator:
            return None

        logger.info("🔄 Starting orchestrator initialization...")
        success = await orchestrator.initialize()

        if success:
            logger.info("✅ Orchestrator initialization successful")

            # Check agent registration
            if hasattr(orchestrator, "agent_registration"):
                agent_count = len(orchestrator.agent_registration.registered_agents)
                logger.info(f"📊 Registered {agent_count} agents")

                # Show some sample agents
                sample_agents = list(
                    orchestrator.agent_registration.registered_agents.keys()
                )[:5]
                logger.info(f"🤖 Sample agents: {sample_agents}")
            else:
                logger.warning("⚠️ Agent registration system not found")

            return orchestrator
        else:
            logger.error("❌ Orchestrator initialization failed")
            return None

    except Exception as e:
        logger.error(f"❌ Initialization error: {e}")
        import traceback

        traceback.print_exc()
        return None


async def test_execution_modes():
    """Test different execution modes"""
    try:
        orchestrator = await test_initialization()
        if not orchestrator:
            return False

        logger.info("⚡ Testing execution modes...")

        from production_orchestrator import CommandSet, CommandStep, CommandType

        # Test intelligent mode
        test_command = CommandSet(
            name="Test Intelligent Mode",
            type=CommandType.WORKFLOW,
            mode=ExecutionMode.INTELLIGENT,
            steps=[
                CommandStep(
                    action="test_action",
                    agent="Director",
                    payload={"test": "intelligent_mode"},
                )
            ],
        )

        logger.info("🧠 Testing INTELLIGENT execution mode...")
        result = await orchestrator.execute_command_set(
            test_command, use_dag_engine=False
        )
        logger.info(f"   Result: {result.get('status', 'unknown')}")

        return True

    except Exception as e:
        logger.error(f"❌ Execution modes test failed: {e}")
        return False


async def test_agent_discovery():
    """Test agent discovery functionality"""
    try:
        orchestrator = await test_initialization()
        if not orchestrator:
            return False

        logger.info("🔍 Testing agent discovery...")

        discovery = orchestrator.discover_agents()
        logger.info(f"📊 Discovery results:")
        logger.info(f"   Total agents: {discovery.get('total_agents', 0)}")

        capabilities = discovery.get("agents_by_capability", {})
        logger.info(f"   Available capabilities: {list(capabilities.keys())[:10]}")

        # Test capability-based lookup
        design_agents = orchestrator.agent_registration.get_agents_by_capability(
            "design"
        )
        logger.info(f"   Agents with 'design' capability: {design_agents}")

        return True

    except Exception as e:
        logger.error(f"❌ Agent discovery test failed: {e}")
        return False


async def test_health_monitoring():
    """Test health monitoring system"""
    try:
        orchestrator = await test_initialization()
        if not orchestrator:
            return False

        logger.info("🏥 Testing health monitoring...")

        health_status = orchestrator.agent_registration.get_agent_health_status()
        logger.info(f"📊 Health status:")
        logger.info(f"   Total agents: {health_status['total_agents']}")
        logger.info(f"   Healthy agents: {health_status['healthy_agents']}")
        logger.info(f"   Unhealthy agents: {health_status['unhealthy_agents']}")

        return True

    except Exception as e:
        logger.error(f"❌ Health monitoring test failed: {e}")
        return False


async def test_metrics_collection():
    """Test performance metrics collection"""
    try:
        orchestrator = await test_initialization()
        if not orchestrator:
            return False

        logger.info("📈 Testing metrics collection...")

        metrics = orchestrator.get_metrics()
        logger.info(f"📊 System metrics:")
        logger.info(f"   Registered agents: {metrics.get('registered_agents', 0)}")
        logger.info(
            f"   Binary bridge connected: {metrics.get('binary_bridge_connected', False)}"
        )
        logger.info(f"   Active campaigns: {metrics.get('active_campaigns', 0)}")

        return True

    except Exception as e:
        logger.error(f"❌ Metrics collection test failed: {e}")
        return False


async def run_all_tests():
    """Run comprehensive test suite"""
    logger.info("🚀 Constructor Agent Implementation Test Suite")
    logger.info("=" * 60)

    test_results = {
        "Import Test": False,
        "Creation Test": False,
        "Initialization Test": False,
        "Execution Modes Test": False,
        "Agent Discovery Test": False,
        "Health Monitoring Test": False,
        "Metrics Collection Test": False,
    }

    # Run tests
    try:
        # Basic functionality tests
        TandemOrchestrator, _, _ = await test_basic_import()
        test_results["Import Test"] = TandemOrchestrator is not None

        orchestrator = await test_orchestrator_creation()
        test_results["Creation Test"] = orchestrator is not None

        orchestrator = await test_initialization()
        test_results["Initialization Test"] = orchestrator is not None

        if orchestrator:
            # Advanced functionality tests
            test_results["Execution Modes Test"] = await test_execution_modes()
            test_results["Agent Discovery Test"] = await test_agent_discovery()
            test_results["Health Monitoring Test"] = await test_health_monitoring()
            test_results["Metrics Collection Test"] = await test_metrics_collection()

    except Exception as e:
        logger.error(f"❌ Test suite error: {e}")

    # Report results
    logger.info("\n" + "=" * 60)
    logger.info("📋 TEST RESULTS SUMMARY")
    logger.info("=" * 60)

    passed_tests = 0
    total_tests = len(test_results)

    for test_name, result in test_results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        logger.info(f"{status} - {test_name}")
        if result:
            passed_tests += 1

    logger.info("-" * 60)
    logger.info(
        f"📊 OVERALL RESULTS: {passed_tests}/{total_tests} tests passed ({passed_tests/total_tests*100:.1f}%)"
    )

    if passed_tests == total_tests:
        logger.info(
            "🎉 ALL TESTS PASSED - Constructor implementation is working correctly!"
        )
        return True
    else:
        logger.warning(
            f"⚠️ {total_tests - passed_tests} tests failed - implementation needs fixes"
        )
        return False


if __name__ == "__main__":
    try:
        result = asyncio.run(run_all_tests())
        exit_code = 0 if result else 1
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("🛑 Test interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"💥 Test suite crashed: {e}")
        sys.exit(1)
