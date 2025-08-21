#!/usr/bin/env python3
"""
Test critical missing agents to see if they cause issues when invoked
"""

import asyncio
import sys
from pathlib import Path

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

async def test_missing_agent_invocation():
    """Test if missing agents can be invoked via orchestrator"""
    print("=== Testing Critical Missing Agents ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Test critical missing agents
        critical_missing = [
            "architect",
            "constructor", 
            "debugger",
            "deployer",
            "infrastructure",
            "linter", 
            "patcher",
            "packager",
            "tui",
            "bastion",
            "researcher",
            "planner"
        ]
        
        results = {}
        
        print(f"Testing {len(critical_missing)} critical missing agents...")
        
        for agent_name in critical_missing:
            try:
                result = await orchestrator.invoke_agent(agent_name, "status_check", {})
                
                status = result.get('status', 'unknown')
                execution_mode = result.get('execution_mode', 'unknown')
                
                results[agent_name] = {
                    'status': status,
                    'execution_mode': execution_mode,
                    'working': status == 'success'
                }
                
                print(f"   {agent_name}: {status} ({execution_mode})")
                
            except Exception as e:
                results[agent_name] = {
                    'status': 'error',
                    'execution_mode': 'failed',
                    'working': False,
                    'error': str(e)
                }
                print(f"   {agent_name}: ERROR - {e}")
        
        # Analyze results
        working_count = sum(1 for r in results.values() if r['working'])
        mock_count = sum(1 for r in results.values() if r.get('execution_mode') == 'mock')
        
        print(f"\n📊 Results Summary:")
        print(f"   Working agents: {working_count}/{len(critical_missing)}")
        print(f"   Mock execution: {mock_count}/{len(critical_missing)}")
        print(f"   Success rate: {working_count/len(critical_missing)*100:.1f}%")
        
        return working_count == len(critical_missing)
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

async def test_workflow_with_missing_agents():
    """Test workflow that includes missing agents"""
    print("\n=== Testing Workflow with Missing Agents ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, CommandStep, CommandSet, CommandType, ExecutionMode
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Create workflow that includes missing agents
        development_workflow = CommandSet(
            name="Full Development Workflow",
            type=CommandType.ORCHESTRATION,
            mode=ExecutionMode.INTELLIGENT,
            steps=[
                CommandStep(
                    id="planning",
                    agent="planner",
                    action="create_development_plan",
                    payload={"project": "test_project"}
                ),
                CommandStep(
                    id="architecture",
                    agent="architect",
                    action="design_system_architecture",
                    payload={"requirements": ["scalable", "secure"]}
                ),
                CommandStep(
                    id="construction",
                    agent="constructor",
                    action="setup_project_structure",
                    payload={"framework": "fastapi"}
                ),
                CommandStep(
                    id="implementation",
                    agent="patcher",
                    action="implement_features",
                    payload={"features": ["auth", "api"]}
                ),
                CommandStep(
                    id="testing",
                    agent="testbed",
                    action="create_test_suite",
                    payload={"coverage_target": 90}
                ),
                CommandStep(
                    id="linting",
                    agent="linter",
                    action="code_quality_check",
                    payload={"strict": True}
                ),
                CommandStep(
                    id="packaging",
                    agent="packager",
                    action="create_deployment_package",
                    payload={"format": "docker"}
                ),
                CommandStep(
                    id="deployment",
                    agent="deployer",
                    action="deploy_to_staging",
                    payload={"environment": "staging"}
                )
            ],
            dependencies={
                "architecture": ["planning"],
                "construction": ["architecture"],
                "implementation": ["construction"],
                "testing": ["implementation"],
                "linting": ["implementation"],
                "packaging": ["testing", "linting"],
                "deployment": ["packaging"]
            }
        )
        
        result = await orchestrator.execute_command_set(development_workflow)
        
        print(f"✅ Development workflow completed")
        print(f"   Status: {result.get('status')}")
        print(f"   Steps executed: {len(result.get('results', {}))}")
        
        # Analyze which agents were used
        results = result.get('results', {})
        execution_modes = {}
        
        for step_result in results.values():
            agent = step_result.get('agent', 'unknown')
            mode = step_result.get('execution_mode', 'unknown')
            execution_modes[agent] = mode
        
        print(f"   Agent execution modes:")
        for agent, mode in execution_modes.items():
            print(f"     {agent}: {mode}")
        
        # Check if any failed
        failed_steps = [step for step in results.values() if step.get('status') != 'success']
        
        print(f"   Failed steps: {len(failed_steps)}")
        
        return len(failed_steps) == 0
        
    except Exception as e:
        print(f"❌ Workflow test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def check_agent_discovery():
    """Check if missing agents are discovered by the registry"""
    print("\n=== Checking Agent Discovery ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Get system status
        status = orchestrator.get_system_status()
        
        print(f"✅ Agent Registry Status:")
        print(f"   Total agents: {status['total_agents']}")
        print(f"   Healthy agents: {status['healthy_agents']}")
        print(f"   Available agents: {status['available_agents']}")
        
        # Check specific missing agents
        missing_agents_to_check = ["architect", "constructor", "debugger", "tui", "bastion"]
        
        print(f"\n🔍 Checking specific missing agents:")
        for agent_name in missing_agents_to_check:
            agent_info = orchestrator.get_agent_info(agent_name)
            if agent_info:
                print(f"   {agent_name}: ✅ Discovered (status: {agent_info.status})")
            else:
                print(f"   {agent_name}: ❌ Not found")
        
        return True
        
    except Exception as e:
        print(f"❌ Discovery check failed: {e}")
        return False

async def main():
    """Run all missing agent tests"""
    print("🔍 Testing Critical Missing Agents Impact")
    print("=" * 50)
    
    tests = [
        ("Agent Discovery Check", check_agent_discovery),
        ("Missing Agent Invocation", test_missing_agent_invocation),
        ("Workflow with Missing Agents", test_workflow_with_missing_agents)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        try:
            print(f"\n🧪 Running {test_name}...")
            result = await test_func()
            results.append(result)
            print(f"   Result: {'✅ PASSED' if result else '❌ FAILED'}")
        except Exception as e:
            print(f"   Result: ❌ CRASHED - {e}")
            results.append(False)
    
    print("\n" + "=" * 50)
    print("📊 Missing Agent Impact Results:")
    print(f"   Tests passed: {sum(results)}/{len(results)}")
    print(f"   Success rate: {sum(results)/len(results)*100:.1f}%")
    
    if all(results):
        print("✅ All missing agents work via mock execution")
        print("   💡 System is resilient to missing implementations")
    else:
        print("⚠️ Some issues found with missing agents")
        print("   🔧 May need to implement critical missing agents")
    
    return all(results)

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)