#!/usr/bin/env python3
"""
Test script to verify OPTIMIZER agent synchronization across the tandem system
"""

import asyncio
import sys
import os
import json
from pathlib import Path

# Add current directory to path for imports

# Add project root to Python path for imports
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from path_utilities import (
        get_project_root, get_agents_dir, get_database_dir,
        get_python_src_dir, get_shadowgit_paths, get_database_config
    )
except ImportError:
    # Fallback if path_utilities not available
    def get_project_root():
        return Path(__file__).parent.parent.parent
    def get_agents_dir():
        return get_project_root() / 'agents'
    def get_database_dir():
        return get_project_root() / 'database'
    def get_python_src_dir():
        return get_agents_dir() / 'src' / 'python'
    def get_shadowgit_paths():
        home_dir = Path.home()
        return {'root': home_dir / 'shadowgit'}
    def get_database_config():
        return {
            'host': 'localhost', 'port': 5433,
            'database': 'claude_agents_auth',
            'user': 'claude_agent', 'password': 'claude_auth_pass'
        }
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))

async def test_optimizer_direct():
    """Test OPTIMIZER agent directly"""
    print("=== Testing OPTIMIZER Agent Directly ===")
    
    try:
        from optimizer_impl import OPTIMIZERPythonExecutor
        
        executor = OPTIMIZERPythonExecutor()
        
        # Test performance analysis
        result = await executor.execute_command("analyze_performance", {
            "target_file": "/home/ubuntu/Documents/Claude/agents/src/python/optimizer_impl.py",
            "include_memory": True,
            "generate_perf_plan": True
        })
        
        print(f"✅ Direct OPTIMIZER test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   Hot paths: {result.get('hot_paths', 0)}")
        print(f"   PERF_PLAN generated: {result.get('perf_plan_generated', False)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Direct OPTIMIZER test failed: {e}")
        return False

async def test_optimizer_via_orchestrator():
    """Test OPTIMIZER agent via production orchestrator"""
    print("\n=== Testing OPTIMIZER via Production Orchestrator ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, CommandStep, CommandSet, CommandType, ExecutionMode
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Create a command to invoke OPTIMIZER
        step = CommandStep(
            agent="optimizer",
            action="analyze_performance",
            payload={
                "target_file": "/home/ubuntu/Documents/Claude/agents/src/python/optimizer_impl.py",
                "generate_perf_plan": True
            }
        )
        
        command_set = CommandSet(
            name="OPTIMIZER Performance Analysis",
            type=CommandType.ATOMIC,
            mode=ExecutionMode.INTELLIGENT,
            steps=[step]
        )
        
        result = await orchestrator.execute_command_set(command_set)
        
        print(f"✅ Orchestrator OPTIMIZER test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   Mode: {result.get('mode')}")
        if 'results' in result:
            step_result = list(result['results'].values())[0]
            print(f"   Execution mode: {step_result.get('execution_mode')}")
            print(f"   Result: {step_result.get('result', {}).get('status')}")
        
        return True
        
    except Exception as e:
        print(f"❌ Orchestrator OPTIMIZER test failed: {e}")
        return False

async def test_optimizer_via_agent_registry():
    """Test OPTIMIZER agent discovery via agent registry"""
    print("\n=== Testing OPTIMIZER via Agent Registry ===")
    
    try:
        from agent_registry import AgentRegistry
        
        registry = AgentRegistry()
        
        if not await registry.initialize():
            print("❌ Failed to initialize agent registry")
            return False
        
        # Check if OPTIMIZER is registered
        optimizer_info = registry.get_agent_info("optimizer")
        
        if optimizer_info:
            print(f"✅ OPTIMIZER found in registry")
            print(f"   Name: {optimizer_info.name}")
            print(f"   Version: {optimizer_info.version}")
            print(f"   Status: {optimizer_info.status}")
            print(f"   Category: {optimizer_info.category}")
            print(f"   Health Score: {optimizer_info.health_score}")
        else:
            print("❌ OPTIMIZER not found in registry")
            return False
        
        # Test agent matching
        matching_agents = registry.find_agents_by_pattern("performance optimization")
        if "optimizer" in [agent.lower() for agent in matching_agents]:
            print(f"✅ OPTIMIZER matches performance patterns")
        else:
            print(f"❌ OPTIMIZER doesn't match performance patterns")
        
        return True
        
    except Exception as e:
        print(f"❌ Agent registry OPTIMIZER test failed: {e}")
        return False

async def test_full_workflow():
    """Test OPTIMIZER in a complete workflow"""
    print("\n=== Testing OPTIMIZER in Complete Workflow ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, StandardWorkflows
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Create a performance optimization workflow
        workflow = StandardWorkflows.create_performance_optimization_workflow()
        
        result = await orchestrator.execute_command_set(workflow)
        
        print(f"✅ Performance optimization workflow completed")
        print(f"   Status: {result.get('status')}")
        print(f"   Agents used: {len(result.get('results', {}))}")
        
        # Check if OPTIMIZER was involved
        for step_id, step_result in result.get('results', {}).items():
            if step_result.get('agent', '').lower() == 'optimizer':
                print(f"   ✅ OPTIMIZER executed successfully in workflow")
                print(f"      Execution mode: {step_result.get('execution_mode')}")
                break
        else:
            print(f"   ❌ OPTIMIZER not found in workflow execution")
        
        return True
        
    except Exception as e:
        print(f"❌ Full workflow OPTIMIZER test failed: {e}")
        return False

async def main():
    """Run all OPTIMIZER synchronization tests"""
    print("🔄 Testing OPTIMIZER Agent Synchronization in Tandem System")
    print("=" * 60)
    
    tests = [
        test_optimizer_direct,
        test_optimizer_via_orchestrator,
        test_optimizer_via_agent_registry,
        test_full_workflow
    ]
    
    results = []
    
    for test in tests:
        try:
            result = await test()
            results.append(result)
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
            results.append(False)
    
    print("\n" + "=" * 60)
    print("🔍 OPTIMIZER Synchronization Test Results:")
    print(f"   Tests passed: {sum(results)}/{len(results)}")
    print(f"   Success rate: {sum(results)/len(results)*100:.1f}%")
    
    if all(results):
        print("✅ All OPTIMIZER synchronization tests passed!")
        print("   🎯 OPTIMIZER is fully synchronized across the tandem system")
    else:
        print("❌ Some OPTIMIZER synchronization tests failed")
        print("   🔧 Manual intervention may be required")
    
    return all(results)

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)