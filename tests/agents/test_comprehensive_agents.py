#!/usr/bin/env python3
"""
Comprehensive test of all fixed agents: OPTIMIZER, QUANTUMGUARD, Security, and DATABASE
"""

import asyncio
import sys
from pathlib import Path

# Add current directory to path for imports
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))


async def test_all_agents_orchestration():
    """Test complex workflow with all fixed agents"""
    print("=== Testing Multi-Agent Complex Workflow ===")

    try:
        from production_orchestrator import (
            CommandSet,
            CommandStep,
            CommandType,
            ExecutionMode,
            ProductionOrchestrator,
        )

        orchestrator = ProductionOrchestrator()

        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False

        # Create comprehensive multi-agent workflow
        comprehensive_workflow = CommandSet(
            name="Complete System Analysis and Optimization",
            type=CommandType.ORCHESTRATION,
            mode=ExecutionMode.INTELLIGENT,
            steps=[
                CommandStep(
                    id="database_optimization",
                    agent="database",
                    action="optimize_performance",
                    payload={"database": "postgresql", "target": "authentication"},
                ),
                CommandStep(
                    id="security_audit",
                    agent="security",
                    action="comprehensive_audit",
                    payload={"frameworks": ["owasp", "nist"]},
                ),
                CommandStep(
                    id="quantum_assessment",
                    agent="quantumguard",
                    action="quantum_readiness_assessment",
                    payload={"scope": "infrastructure"},
                ),
                CommandStep(
                    id="performance_optimization",
                    agent="optimizer",
                    action="analyze_performance",
                    payload={"target": "system_wide", "generate_plan": True},
                ),
                CommandStep(
                    id="database_security",
                    agent="database",
                    action="security_audit",
                    payload={"database": "postgresql"},
                ),
                CommandStep(
                    id="pqc_implementation",
                    agent="quantumguard",
                    action="implement_pqc",
                    payload={"algorithm": "kyber768"},
                ),
            ],
            dependencies={
                "security_audit": ["database_optimization"],
                "quantum_assessment": ["security_audit"],
                "performance_optimization": ["database_optimization"],
                "database_security": ["security_audit"],
                "pqc_implementation": ["quantum_assessment", "database_security"],
            },
        )

        result = await orchestrator.execute_command_set(comprehensive_workflow)

        print(f"✅ Comprehensive workflow completed")
        print(f"   Status: {result.get('status')}")
        print(f"   Steps executed: {len(result.get('results', {}))}")

        # Check that all agents executed
        results = result.get("results", {})
        agent_executions = {}

        for step_result in results.values():
            agent = step_result.get("agent", "unknown")
            execution_mode = step_result.get("execution_mode", "unknown")
            agent_executions[agent] = execution_mode

        print(f"   Agent Executions:")
        for agent, mode in agent_executions.items():
            print(f"     {agent}: {mode}")

        # Verify all target agents executed with Python implementation
        target_agents = ["database", "security", "quantumguard", "optimizer"]
        python_executions = [
            agent
            for agent, mode in agent_executions.items()
            if agent in target_agents and mode == "python_implementation"
        ]

        print(
            f"   Python implementations: {len(python_executions)}/{len(target_agents)}"
        )

        return len(python_executions) == len(target_agents)

    except Exception as e:
        print(f"❌ Comprehensive workflow test failed: {e}")
        import traceback

        traceback.print_exc()
        return False


async def test_agent_capabilities():
    """Test individual agent capabilities"""
    print("\n=== Testing Individual Agent Capabilities ===")

    agents_to_test = [
        ("database_impl", "DatabasePythonExecutor"),
        ("security_impl", "SecurityPythonExecutor"),
        ("quantumguard_impl", "QUANTUMGUARDPythonExecutor"),
        ("optimizer_impl", "OPTIMIZERPythonExecutor"),
    ]

    results = []

    for module_name, class_name in agents_to_test:
        try:
            module = __import__(module_name)
            executor_class = getattr(module, class_name)
            executor = executor_class()

            capabilities = executor.get_capabilities()
            status = executor.get_status()

            print(
                f"   {executor.agent_name}: {len(capabilities)} capabilities, status: {status['status']}"
            )
            results.append(True)

        except Exception as e:
            print(f"   {module_name}: ❌ Failed - {e}")
            results.append(False)

    return all(results)


async def test_production_readiness():
    """Test production readiness of all agents"""
    print("\n=== Testing Production Readiness ===")

    try:
        from production_orchestrator import ProductionOrchestrator

        orchestrator = ProductionOrchestrator()

        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False

        # Check system status
        status = orchestrator.get_system_status()
        metrics = orchestrator.get_metrics()

        print(f"   Orchestrator Status: {status['orchestrator_status']}")
        print(f"   Total Agents: {status['total_agents']}")
        print(f"   Healthy Agents: {status['healthy_agents']}")
        print(f"   Success Rate: {status['success_rate']}")

        # Test direct agent invocation for each fixed agent
        test_agents = [
            ("database", "schema_analysis"),
            ("security", "vulnerability_scan"),
            ("quantumguard", "pqc_status"),
            ("optimizer", "performance_check"),
        ]

        all_successful = True

        for agent_name, action in test_agents:
            try:
                result = await orchestrator.invoke_agent(agent_name, action, {})
                execution_mode = result.get("execution_mode", "unknown")
                success = result.get("status") == "success"

                print(
                    f"   {agent_name}: {execution_mode} - {'✅' if success else '❌'}"
                )

                if not success or execution_mode != "python_implementation":
                    all_successful = False

            except Exception as e:
                print(f"   {agent_name}: ❌ Failed - {e}")
                all_successful = False

        return all_successful

    except Exception as e:
        print(f"❌ Production readiness test failed: {e}")
        return False


async def main():
    """Run comprehensive agent testing"""
    print(
        "🔧 Comprehensive Agent Testing - OPTIMIZER, QUANTUMGUARD, Security, DATABASE"
    )
    print("=" * 80)

    tests = [
        ("Agent Capabilities", test_agent_capabilities),
        ("Production Readiness", test_production_readiness),
        ("Multi-Agent Orchestration", test_all_agents_orchestration),
    ]

    results = []

    for test_name, test_func in tests:
        try:
            print(f"\n🧪 Running {test_name} Test...")
            result = await test_func()
            results.append(result)
            print(f"   Result: {'✅ PASSED' if result else '❌ FAILED'}")
        except Exception as e:
            print(f"   Result: ❌ CRASHED - {e}")
            results.append(False)

    print("\n" + "=" * 80)
    print("📊 Comprehensive Test Results:")
    print(f"   Tests passed: {sum(results)}/{len(results)}")
    print(f"   Success rate: {sum(results)/len(results)*100:.1f}%")

    if all(results):
        print("🎉 ALL TESTS PASSED!")
        print("   ✅ OPTIMIZER: Fully synchronized")
        print("   ✅ QUANTUMGUARD: Quantum-resistant cryptography ready")
        print("   ✅ Security: Comprehensive security analysis operational")
        print("   ✅ DATABASE: Multi-database optimization specialist ready")
        print("   🚀 All agents fully functional on Python-only system")
    else:
        print("⚠️ Some tests failed - review implementations")

    return all(results)


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
