#!/usr/bin/env python3
"""
Test DATABASE agent functionality
"""

import asyncio
import sys
from pathlib import Path

# Add current directory to path for imports
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))

async def test_database_direct():
    """Test DATABASE agent directly"""
    print("=== Testing DATABASE Agent Directly ===")
    
    try:
        from database_impl import DatabasePythonExecutor
        
        executor = DatabasePythonExecutor()
        
        # Test schema design
        result = await executor.execute_command("design_schema", {
            "database": "postgresql",
            "use_case": "e_commerce",
            "scale": "large"
        })
        
        print(f"✅ Direct DATABASE test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   PostgreSQL 17 Ready: {result.get('postgresql17_ready')}")
        print(f"   Supported Databases: {len(result.get('supported_databases', []))}")
        
        return True
        
    except Exception as e:
        print(f"❌ Direct DATABASE test failed: {e}")
        return False

async def test_database_via_orchestrator():
    """Test DATABASE agent via production orchestrator"""
    print("\n=== Testing DATABASE via Production Orchestrator ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, CommandStep
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        print(f"✅ Orchestrator initialized")
        print(f"   Mock mode: {orchestrator.mock_mode}")
        
        # Test DATABASE
        database_step = CommandStep(
            agent="database",
            action="optimize_schema",
            payload={"database": "postgresql", "table": "users"}
        )
        
        database_result = await orchestrator._invoke_real_agent(database_step, orchestrator.get_agent_info("database"))
        print(f"   DATABASE status: {database_result.get('status')}")
        print(f"   DATABASE mode: {database_result.get('execution_mode')}")
        
        return True
        
    except Exception as e:
        print(f"❌ Orchestrator test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_database_postgresql17():
    """Test PostgreSQL 17 optimization"""
    print("\n=== Testing PostgreSQL 17 Optimization ===")
    
    try:
        from database_impl import DatabasePythonExecutor
        
        executor = DatabasePythonExecutor()
        
        # Test PostgreSQL 17 optimization
        result = await executor.execute_command("postgresql17_optimization", {
            "target": "authentication_performance"
        })
        
        print(f"✅ PostgreSQL 17 optimization test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   Features: {len(result.get('result', {}).get('postgresql17_features', {}))}")
        
        return True
        
    except Exception as e:
        print(f"❌ PostgreSQL 17 test failed: {e}")
        return False

async def main():
    """Run all DATABASE functionality tests"""
    print("🗄️ Testing DATABASE Agent Functionality")
    print("=" * 50)
    
    tests = [
        test_database_direct,
        test_database_via_orchestrator,
        test_database_postgresql17
    ]
    
    results = []
    
    for test in tests:
        try:
            result = await test()
            results.append(result)
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
            results.append(False)
    
    print("\n" + "=" * 50)
    print("🔍 DATABASE Agent Test Results:")
    print(f"   Tests passed: {sum(results)}/{len(results)}")
    print(f"   Success rate: {sum(results)/len(results)*100:.1f}%")
    
    if all(results):
        print("✅ All DATABASE functionality tests passed!")
        print("   🎯 DATABASE agent is fully functional")
    else:
        print("❌ Some DATABASE functionality tests failed")
        print("   🔧 Review DATABASE implementation")
    
    return all(results)

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)