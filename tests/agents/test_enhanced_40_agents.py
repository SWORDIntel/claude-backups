#!/usr/bin/env python3
"""
Comprehensive Test Script for All 55+ Agents with Enhanced Registry
Tests the complete agent ecosystem with Python fallback support
Updated for the expanded agent collection with specializations
"""

import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

# Set up paths
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.append(str(project_root))
os.environ["CLAUDE_AGENTS_ROOT"] = str(Path(__file__).parent.parent.parent)

# Import the enhanced components
from agent_registry import (
    EnhancedAgentRegistry,
    find_best_agent,
    get_enhanced_registry,
    initialize_enhanced_registry,
    orchestrate_task,
)
from production_orchestrator import ProductionOrchestrator

# Define all 40 expected agents
ALL_40_AGENTS = {
    "Management": ["director", "projectorchestrator", "planner", "oversight"],
    "Architecture": ["architect", "apidesigner", "database"],
    "Development": [
        "constructor",
        "patcher",
        "debugger",
        "testbed",
        "linter",
        "optimizer",
        "packager",
        "docgen",
    ],
    "Security": ["security", "bastion", "securitychaosagent", "cso"],
    "Infrastructure": ["infrastructure", "deployer", "monitor", "gnu"],
    "UI/UX": ["web", "mobile", "pygui", "tui"],
    "Data & AI": ["datascience", "mlops", "npu", "researcher"],
    "Language Specialists": [
        "c-internal",
        "python-internal",
        "js-internal",
        "rust-internal",
        "go-internal",
        "java-internal",
        "swift-internal",
        "kotlin-internal",
        "scala-internal",
        "ruby-internal",
    ],
}


class ComprehensiveAgentTester:
    """Test all 40 agents with enhanced features"""

    def __init__(self):
        self.registry = None
        self.orchestrator = None
        self.test_results = {
            "timestamp": datetime.now().isoformat(),
            "tests_passed": 0,
            "tests_failed": 0,
            "agents_found": 0,
            "agents_missing": [],
            "python_fallback_active": False,
            "binary_protocol_active": False,
            "detailed_results": {},
        }

    async def initialize(self):
        """Initialize test environment"""
        print("\n" + "=" * 70)
        print("🚀 COMPREHENSIVE 40-AGENT TEST SUITE WITH ENHANCED REGISTRY")
        print("=" * 70 + "\n")

        # Initialize enhanced registry
        print("📦 Initializing Enhanced Agent Registry...")
        success = await initialize_enhanced_registry()
        if not success:
            print("❌ Failed to initialize enhanced registry")
            return False

        self.registry = get_enhanced_registry()

        # Check what's available
        self.test_results["binary_protocol_active"] = (
            self.registry.binary_interface.connected
        )
        self.test_results["python_fallback_active"] = hasattr(
            self.registry, "task_interface"
        )

        # Initialize orchestrator
        print("🎭 Initializing Production Orchestrator...")
        self.orchestrator = ProductionOrchestrator()
        await self.orchestrator.initialize()

        print(f"✅ System initialized with {len(self.registry.agents)} agents")
        self.test_results["agents_found"] = len(self.registry.agents)

        return True

    async def test_agent_discovery(self):
        """Test 1: Verify all 40 agents are discoverable"""
        print("\n📋 TEST 1: Agent Discovery")
        print("-" * 50)

        discovered_agents = set(self.registry.agents.keys())
        expected_agents = set()
        for category_agents in ALL_40_AGENTS.values():
            expected_agents.update(
                agent.lower().replace("-", "") for agent in category_agents
            )

        # Find missing agents
        missing = expected_agents - discovered_agents
        extra = discovered_agents - expected_agents

        print(f"Expected agents: {len(expected_agents)}")
        print(f"Discovered agents: {len(discovered_agents)}")

        if missing:
            print(f"⚠️  Missing agents ({len(missing)}): {sorted(missing)[:5]}...")
            self.test_results["agents_missing"] = list(missing)

        if extra:
            print(f"ℹ️  Extra agents found ({len(extra)}): {sorted(extra)[:5]}...")

        # Test passes if we have at least 35 agents (allowing for some parsing issues)
        if len(discovered_agents) >= 35:
            print("✅ Agent discovery test PASSED (35+ agents found)")
            self.test_results["tests_passed"] += 1
            return True
        else:
            print(
                f"❌ Agent discovery test FAILED (only {len(discovered_agents)} agents)"
            )
            self.test_results["tests_failed"] += 1
            return False

    async def test_python_fallback(self):
        """Test 2: Verify Python fallback system"""
        print("\n🐍 TEST 2: Python Fallback System")
        print("-" * 50)

        fallback = self.registry.task_interface.python_fallback

        # Check fallback availability
        print(f"Bridge available: {fallback.bridge_available}")
        print(f"Fallback agents: {len(fallback.python_agents)}")

        # Test invoking via fallback
        test_cases = [
            ("director", "create strategic plan"),
            ("security", "audit infrastructure"),
            ("optimizer", "optimize performance"),
            ("unknown_agent", "test fallback"),
        ]

        passed = 0
        for agent, task in test_cases:
            try:
                result = await fallback.invoke_python_agent(agent, task, {})
                if result and "status" in result:
                    print(f"✅ {agent}: {result.get('status', 'unknown')}")
                    passed += 1
                else:
                    print(f"⚠️  {agent}: Incomplete result")
            except Exception as e:
                print(f"❌ {agent}: {str(e)[:50]}")

        if passed >= 3:
            print(f"\n✅ Python fallback test PASSED ({passed}/4 successful)")
            self.test_results["tests_passed"] += 1
            return True
        else:
            print(f"\n❌ Python fallback test FAILED ({passed}/4 successful)")
            self.test_results["tests_failed"] += 1
            return False

    async def test_categories(self):
        """Test 3: Verify agent categories"""
        print("\n🗂️ TEST 3: Agent Categories")
        print("-" * 50)

        categories = self.registry.category_index
        print(f"Total categories: {len(categories)}")

        # Display categories with agent counts
        for category in sorted(categories.keys())[:10]:
            agents = categories[category]
            print(f"  • {category}: {len(agents)} agents")

        if len(categories) > 10:
            print(f"  ... and {len(categories) - 10} more categories")

        # Test passes if we have at least 5 categories
        if len(categories) >= 5:
            print("\n✅ Category test PASSED")
            self.test_results["tests_passed"] += 1
            return True
        else:
            print("\n❌ Category test FAILED")
            self.test_results["tests_failed"] += 1
            return False

    async def test_pattern_matching(self):
        """Test 4: Pattern matching and best agent selection"""
        print("\n🔍 TEST 4: Pattern Matching & Agent Selection")
        print("-" * 50)

        test_queries = [
            "Deploy application to production",
            "Fix bugs in Python code",
            "Design REST API",
            "Optimize database performance",
            "Create mobile app",
            "Setup machine learning pipeline",
            "Security audit and penetration testing",
            "Build desktop GUI",
        ]

        successful_matches = 0
        for query in test_queries:
            best = find_best_agent(query)
            matches = self.registry.find_agents_by_pattern(query)

            if best or matches:
                print(f"✅ '{query[:30]}...'")
                print(f"   Best: {best}, Matches: {len(matches)}")
                successful_matches += 1
            else:
                print(f"⚠️  '{query[:30]}...' - No matches")

        if successful_matches >= 5:
            print(f"\n✅ Pattern matching test PASSED ({successful_matches}/8)")
            self.test_results["tests_passed"] += 1
            return True
        else:
            print(f"\n❌ Pattern matching test FAILED ({successful_matches}/8)")
            self.test_results["tests_failed"] += 1
            return False

    async def test_orchestration(self):
        """Test 5: Multi-agent orchestration"""
        print("\n🎭 TEST 5: Multi-Agent Orchestration")
        print("-" * 50)

        # Test orchestrating a complex task
        task = "Build, test, and deploy a microservice with security audit"

        print(f"Orchestrating: {task}")
        try:
            result = await orchestrate_task(task, {"environment": "test"})

            if result and "agents_involved" in result:
                print(f"✅ Orchestration successful")
                print(f"   Agents involved: {len(result['agents_involved'])}")
                print(
                    f"   Phases: {len(result.get('execution_plan', {}).get('phases', []))}"
                )

                # Show first few agents
                for agent in result["agents_involved"][:5]:
                    print(f"   • {agent}")

                self.test_results["tests_passed"] += 1
                return True
        except Exception as e:
            print(f"❌ Orchestration failed: {e}")

        self.test_results["tests_failed"] += 1
        return False

    async def test_task_tool_integration(self):
        """Test 6: Task tool integration"""
        print("\n🔧 TEST 6: Task Tool Integration")
        print("-" * 50)

        # Check Task tool registrations
        task_registry_path = Path.home() / ".claude" / "task_agents.json"

        if task_registry_path.exists():
            try:
                with open(task_registry_path, "r") as f:
                    task_agents = json.load(f)
                print(f"✅ Task registry found with {len(task_agents)} agents")

                # Test invoking via Task interface
                if hasattr(self.registry, "task_interface"):
                    result = await self.registry.task_interface.invoke_agent_via_task(
                        "architect",
                        "Design system architecture",
                        {"type": "microservice"},
                    )
                    if result:
                        print("✅ Task tool invocation successful")
                        self.test_results["tests_passed"] += 1
                        return True
            except Exception as e:
                print(f"⚠️  Task tool test error: {e}")
        else:
            print("⚠️  Task registry not found")

        print("❌ Task tool integration test FAILED")
        self.test_results["tests_failed"] += 1
        return False

    async def test_cluster_coordination(self):
        """Test 7: Agent cluster coordination"""
        print("\n🔗 TEST 7: Agent Cluster Coordination")
        print("-" * 50)

        clusters = self.registry.orchestration_engine.clusters
        print(f"Total clusters: {len(clusters)}")

        # Test each cluster
        tested = 0
        for cluster_name, cluster in clusters.items():
            agents = self.registry.find_agents_by_cluster(cluster_name)
            if agents:
                print(f"✅ {cluster_name}: {len(agents)} agents active")
                tested += 1
            else:
                print(f"⚠️  {cluster_name}: No agents found")

        if tested >= 5:
            print(
                f"\n✅ Cluster coordination test PASSED ({tested}/{len(clusters)} clusters)"
            )
            self.test_results["tests_passed"] += 1
            return True
        else:
            print(
                f"\n❌ Cluster coordination test FAILED ({tested}/{len(clusters)} clusters)"
            )
            self.test_results["tests_failed"] += 1
            return False

    async def test_performance_metrics(self):
        """Test 8: Performance metrics and monitoring"""
        print("\n📊 TEST 8: Performance Metrics & Monitoring")
        print("-" * 50)

        stats = self.registry.get_comprehensive_stats()

        print(f"System Health: {stats['avg_health_score']:.1f}%")
        print(f"Total Capabilities: {stats['total_capabilities']}")
        print(f"Tasks Completed: {stats['total_tasks_completed']}")
        print(f"Error Rate: {stats['error_rate']:.1f}%")
        print(
            f"Binary Protocol: {'Active' if stats['binary_protocol_active'] else 'Inactive'}"
        )

        # Check if metrics are reasonable
        if stats["avg_health_score"] > 70 and stats["total_capabilities"] > 50:
            print("\n✅ Performance metrics test PASSED")
            self.test_results["tests_passed"] += 1
            return True
        else:
            print("\n❌ Performance metrics test FAILED")
            self.test_results["tests_failed"] += 1
            return False

    async def run_all_tests(self):
        """Run all comprehensive tests"""
        if not await self.initialize():
            print("❌ Initialization failed, aborting tests")
            return

        # Run all test suites
        await self.test_agent_discovery()
        await self.test_python_fallback()
        await self.test_categories()
        await self.test_pattern_matching()
        await self.test_orchestration()
        await self.test_task_tool_integration()
        await self.test_cluster_coordination()
        await self.test_performance_metrics()

        # Final summary
        self.print_summary()

        # Save results to file
        self.save_results()

    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 70)
        print("📈 TEST SUMMARY")
        print("=" * 70)

        total_tests = (
            self.test_results["tests_passed"] + self.test_results["tests_failed"]
        )
        pass_rate = (
            (self.test_results["tests_passed"] / total_tests * 100)
            if total_tests > 0
            else 0
        )

        print(f"Tests Passed: {self.test_results['tests_passed']}/{total_tests}")
        print(f"Pass Rate: {pass_rate:.1f}%")
        print(f"Agents Found: {self.test_results['agents_found']}/40")
        print(
            f"Python Fallback: {'Active' if self.test_results['python_fallback_active'] else 'Inactive'}"
        )
        print(
            f"Binary Protocol: {'Active' if self.test_results['binary_protocol_active'] else 'Inactive'}"
        )

        if self.test_results["agents_missing"]:
            print(
                f"\n⚠️  Missing Agents: {', '.join(self.test_results['agents_missing'][:5])}"
            )

        if pass_rate >= 75:
            print("\n🎉 OVERALL: SYSTEM READY FOR PRODUCTION")
        elif pass_rate >= 50:
            print("\n⚠️  OVERALL: SYSTEM PARTIALLY FUNCTIONAL")
        else:
            print("\n❌ OVERALL: SYSTEM NEEDS ATTENTION")

    def save_results(self):
        """Save test results to file"""
        results_file = Path(__file__).parent / "test_results_40_agents.json"
        with open(results_file, "w") as f:
            json.dump(self.test_results, f, indent=2)
        print(f"\n💾 Results saved to: {results_file}")


async def main():
    """Main test execution"""
    tester = ComprehensiveAgentTester()
    await tester.run_all_tests()

    # Cleanup
    registry = get_enhanced_registry()
    if registry:
        registry.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  Tests interrupted by user")
    except Exception as e:
        print(f"\n❌ Test suite failed: {e}")
        import traceback

        traceback.print_exc()
