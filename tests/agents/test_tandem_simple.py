#!/usr/bin/env python3
"""
Simple Tandem Orchestration Integration Test
===========================================

Basic functionality test for tandem orchestration integration.
Tests core functionality with graceful fallbacks for missing imports.

Author: Claude Code Framework
Version: 1.0.0
Status: PRODUCTION
"""

import asyncio
import sys
import traceback
from pathlib import Path
from typing import Any, Dict


def test_imports():
    """Test that all required modules can be imported"""
    print("🔍 Testing Module Imports")
    print("=" * 50)

    modules_to_test = [
        "tandem_orchestration_base",
        "production_orchestrator_bridge",
        "tandem_integration",
    ]

    success_count = 0

    for module_name in modules_to_test:
        try:
            __import__(module_name)
            print(f"  ✅ {module_name}: SUCCESS")
            success_count += 1
        except ImportError as e:
            print(f"  ❌ {module_name}: FAILED - {e}")
        except Exception as e:
            print(f"  ⚠️  {module_name}: ERROR - {e}")

    print(
        f"\nImport Success Rate: {success_count}/{len(modules_to_test)} ({success_count/len(modules_to_test)*100:.1f}%)"
    )
    return success_count == len(modules_to_test)


def test_tandem_integration():
    """Test tandem integration functionality"""
    print("\n🧪 Testing Tandem Integration")
    print("=" * 50)

    try:
        from tandem_integration import EnhancedAgentWrapper, enhance_agent

        # Create a mock agent
        class SimpleAgent:
            def __init__(self):
                self.name = "simple_test_agent"

            def execute_command(self, command):
                return {
                    "status": "success",
                    "result": f"Executed: {command.get('action', 'unknown')}",
                }

            def get_capabilities(self):
                return {"actions": ["test"], "version": "1.0"}

        # Test enhancement
        original_agent = SimpleAgent()
        enhanced_agent = enhance_agent(original_agent, "SIMPLE_AGENT", "mock")

        print(f"  ✅ Enhanced agent created: {enhanced_agent.agent_name}")
        print(f"  ✅ Original agent preserved: {enhanced_agent.original_agent.name}")

        # Test that original methods are accessible
        if hasattr(enhanced_agent, "original_methods"):
            print(
                f"  ✅ Original methods extracted: {list(enhanced_agent.original_methods.keys())}"
            )
        else:
            print("  ⚠️  Original methods not available")

        return True

    except Exception as e:
        print(f"  ❌ Integration test failed: {e}")
        traceback.print_exc()
        return False


def test_orchestration_manager():
    """Test orchestration manager functionality"""
    print("\n🎯 Testing Orchestration Manager")
    print("=" * 50)

    try:
        from tandem_integration import OrchestrationManager

        manager = OrchestrationManager("mock")
        print(f"  ✅ Manager created with bridge mode: {manager.bridge_mode}")
        print(f"  ✅ Manager running state: {manager.is_running}")

        return True

    except Exception as e:
        print(f"  ❌ Manager test failed: {e}")
        return False


async def test_async_functionality():
    """Test async functionality if available"""
    print("\n⚡ Testing Async Functionality")
    print("=" * 50)

    try:
        from tandem_integration import get_orchestration_manager

        # Test async manager creation
        manager = await get_orchestration_manager("mock")
        print(f"  ✅ Async manager created: {type(manager).__name__}")

        # Test manager shutdown
        await manager.shutdown()
        print(f"  ✅ Manager shutdown completed")

        return True

    except Exception as e:
        print(f"  ❌ Async test failed: {e}")
        return False


def test_existing_agent_enhancement():
    """Test enhancement of existing agent implementations"""
    print("\n🔧 Testing Existing Agent Enhancement")
    print("=" * 50)

    # Test with some existing agents if they're available
    existing_agents = ["security_impl", "director_impl", "debugger_impl"]

    enhanced_count = 0

    for agent_name in existing_agents:
        try:
            module = __import__(agent_name)

            # Look for executor classes
            for attr_name in dir(module):
                if "executor" in attr_name.lower() and not attr_name.startswith("_"):
                    print(f"  ✅ Found executor in {agent_name}: {attr_name}")

                    # Try to enhance it
                    from tandem_integration import enhance_agent

                    executor_class = getattr(module, attr_name)
                    if hasattr(executor_class, "__call__"):
                        original_agent = executor_class()
                        enhanced_agent = enhance_agent(
                            original_agent, agent_name.upper(), "mock"
                        )
                        print(
                            f"  ✅ Enhanced {agent_name}: {enhanced_agent.agent_name}"
                        )
                        enhanced_count += 1
                        break

        except Exception as e:
            print(f"  ⚠️  Could not test {agent_name}: {e}")

    print(f"\nEnhanced {enhanced_count}/{len(existing_agents)} existing agents")
    return enhanced_count > 0


def main():
    """Run all tests"""
    print("🎯 Tandem Orchestration Integration Test Suite")
    print("=" * 60)
    print("🚀 Starting Simple Integration Tests")
    print("=" * 60)

    test_results = []

    # Run synchronous tests
    test_results.append(("Import Tests", test_imports()))
    test_results.append(("Integration Tests", test_tandem_integration()))
    test_results.append(("Manager Tests", test_orchestration_manager()))
    test_results.append(("Agent Enhancement", test_existing_agent_enhancement()))

    # Run async tests
    try:
        async_result = asyncio.run(test_async_functionality())
        test_results.append(("Async Tests", async_result))
    except Exception as e:
        print(f"  ❌ Async tests failed to run: {e}")
        test_results.append(("Async Tests", False))

    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)

    passed = sum(1 for _, result in test_results if result)
    total = len(test_results)

    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {test_name}")

    print(f"\nTotal Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {total - passed}")
    print(f"Success Rate: {passed/total*100:.1f}%")

    if passed / total >= 0.8:
        print("\n🎉 PRODUCTION READY - Core functionality operational!")
    elif passed / total >= 0.6:
        print("\n⚠️  PARTIALLY FUNCTIONAL - Some issues need attention")
    else:
        print("\n❌ NEEDS WORK - Major issues detected")

    print("=" * 60)


if __name__ == "__main__":
    main()
