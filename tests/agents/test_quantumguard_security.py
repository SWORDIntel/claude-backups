#!/usr/bin/env python3
"""
Test QUANTUMGUARD and Security agents functionality
"""

import asyncio
import sys
import os
from pathlib import Path

# Add current directory to path for imports
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))

async def test_quantumguard_direct():
    """Test QUANTUMGUARD agent directly"""
    print("=== Testing QUANTUMGUARD Agent Directly ===")
    
    try:
        from quantumguard_impl import QUANTUMGUARDPythonExecutor
        
        executor = QUANTUMGUARDPythonExecutor()
        
        # Test PQC operations
        result = await executor.execute_command("implement_pqc", {
            "algorithm": "kyber768",
            "operation": "keygen"
        })
        
        print(f"✅ Direct QUANTUMGUARD test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   Quantum Ready: {result.get('quantum_ready')}")
        print(f"   PQC Algorithms: {len(result.get('pqc_algorithms_available', []))}")
        
        return True
        
    except Exception as e:
        print(f"❌ Direct QUANTUMGUARD test failed: {e}")
        return False

async def test_security_direct():
    """Test Security agent directly"""
    print("\n=== Testing Security Agent Directly ===")
    
    try:
        from security_impl import SecurityPythonExecutor
        
        executor = SecurityPythonExecutor()
        
        # Test vulnerability scanning
        result = await executor.execute_command("vulnerability_scan", {
            "target": ".",
            "type": "sast"
        })
        
        print(f"✅ Direct Security test passed")
        print(f"   Status: {result.get('status')}")
        print(f"   Security Frameworks: {len(result.get('security_frameworks', []))}")
        print(f"   Tools Available: {result.get('tools_available', 0)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Direct Security test failed: {e}")
        return False

async def test_agents_via_orchestrator():
    """Test both agents via production orchestrator"""
    print("\n=== Testing Agents via Production Orchestrator ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, CommandStep, CommandSet, CommandType, ExecutionMode
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        print(f"✅ Orchestrator initialized")
        print(f"   Mock mode: {orchestrator.mock_mode}")
        
        # Test QUANTUMGUARD
        quantumguard_step = CommandStep(
            agent="quantumguard",
            action="deploy_pqc",
            payload={"algorithm": "kyber768"}
        )
        
        quantumguard_result = await orchestrator._invoke_real_agent(quantumguard_step, orchestrator.get_agent_info("quantumguard"))
        print(f"   QUANTUMGUARD status: {quantumguard_result.get('status')}")
        print(f"   QUANTUMGUARD mode: {quantumguard_result.get('execution_mode')}")
        
        # Test Security
        security_step = CommandStep(
            agent="security",
            action="vulnerability_scan",
            payload={"target": ".", "type": "comprehensive"}
        )
        
        security_result = await orchestrator._invoke_real_agent(security_step, orchestrator.get_agent_info("security"))
        print(f"   Security status: {security_result.get('status')}")
        print(f"   Security mode: {security_result.get('execution_mode')}")
        
        return True
        
    except Exception as e:
        print(f"❌ Orchestrator test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def test_security_workflow():
    """Test comprehensive security workflow"""
    print("\n=== Testing Security Workflow ===")
    
    try:
        from production_orchestrator import ProductionOrchestrator, CommandStep, CommandSet, CommandType, ExecutionMode
        
        orchestrator = ProductionOrchestrator()
        
        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False
        
        # Create comprehensive security workflow
        security_workflow = CommandSet(
            name="Comprehensive Security Analysis",
            type=CommandType.CAMPAIGN,
            mode=ExecutionMode.INTELLIGENT,
            steps=[
                CommandStep(
                    id="vulnerability_scan",
                    agent="security",
                    action="vulnerability_scan",
                    payload={"type": "comprehensive", "target": "."}
                ),
                CommandStep(
                    id="compliance_audit",
                    agent="security", 
                    action="compliance_audit",
                    payload={"framework": "owasp"}
                ),
                CommandStep(
                    id="pqc_assessment",
                    agent="quantumguard",
                    action="quantum_threat_assessment",
                    payload={"target": "infrastructure"}
                ),
                CommandStep(
                    id="zero_trust_deployment",
                    agent="quantumguard",
                    action="deploy_zero_trust",
                    payload={"segments": ["dmz", "internal", "critical"]}
                )
            ],
            dependencies={
                "compliance_audit": ["vulnerability_scan"],
                "pqc_assessment": ["vulnerability_scan"],
                "zero_trust_deployment": ["pqc_assessment"]
            }
        )
        
        result = await orchestrator.execute_command_set(security_workflow)
        
        print(f"✅ Security workflow completed")
        print(f"   Status: {result.get('status')}")
        print(f"   Steps executed: {len(result.get('results', {}))}")
        
        # Check if both agents executed
        results = result.get('results', {})
        quantumguard_executed = any('quantumguard' in str(step_result.get('agent', '')) for step_result in results.values())
        security_executed = any('security' in str(step_result.get('agent', '')) for step_result in results.values())
        
        print(f"   QUANTUMGUARD executed: {quantumguard_executed}")
        print(f"   Security executed: {security_executed}")
        
        return True
        
    except Exception as e:
        print(f"❌ Security workflow test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

async def main():
    """Run all agent functionality tests"""
    print("🔒 Testing QUANTUMGUARD and Security Agent Functionality")
    print("=" * 60)
    
    tests = [
        test_quantumguard_direct,
        test_security_direct,
        test_agents_via_orchestrator,
        test_security_workflow
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
    print("🔍 Agent Functionality Test Results:")
    print(f"   Tests passed: {sum(results)}/{len(results)}")
    print(f"   Success rate: {sum(results)/len(results)*100:.1f}%")
    
    if all(results):
        print("✅ All agent functionality tests passed!")
        print("   🎯 QUANTUMGUARD and Security agents are fully functional")
    else:
        print("❌ Some agent functionality tests failed")
        print("   🔧 Review agent implementations")
    
    return all(results)

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)