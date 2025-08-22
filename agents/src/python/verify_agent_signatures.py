#!/usr/bin/env python3
"""
Verify all implemented agents have correct v9.0 signatures
"""

import asyncio
import sys
import traceback
from pathlib import Path

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

async def test_agent_signature(agent_name, agent_class):
    """Test if agent has correct v9.0 signature"""
    try:
        agent = agent_class()
        
        # Test v9.0 signature: execute_command(command_str: str, context: Dict[str, Any] = None)
        result = await agent.execute_command("test_command", {"test": "data"})
        
        # Check for required v9.0 methods
        has_get_capabilities = hasattr(agent, 'get_capabilities') and callable(getattr(agent, 'get_capabilities'))
        has_get_status = hasattr(agent, 'get_status') and callable(getattr(agent, 'get_status'))
        has_agent_name = hasattr(agent, 'agent_name')
        has_version = hasattr(agent, 'version')
        
        return {
            'agent': agent_name,
            'signature_test': 'pass' if not isinstance(result.get('error'), str) or 'takes 2 positional arguments but 3 were given' not in result.get('error', '') else 'fail',
            'has_get_capabilities': has_get_capabilities,
            'has_get_status': has_get_status,
            'has_agent_name': has_agent_name,
            'has_version': has_version,
            'v9_compliance': has_get_capabilities and has_get_status and has_agent_name and has_version
        }
        
    except Exception as e:
        return {
            'agent': agent_name,
            'signature_test': 'error',
            'error': str(e),
            'has_get_capabilities': False,
            'has_get_status': False,
            'has_agent_name': False,
            'has_version': False,
            'v9_compliance': False
        }

async def main():
    """Test all implemented agents"""
    
    # List of agents with implementations
    implemented_agents = [
        ('DATASCIENCE', 'datascience_impl', 'DATASCIENCEPythonExecutor'),
        ('MLOPS', 'mlops_impl', 'MLOPSPythonExecutor'),
        ('PYGUI', 'pygui_impl', 'PYGUIPythonExecutor'),
        ('WEB', 'web_impl', 'WEBPythonExecutor'),
        ('TESTBED', 'testbed_impl', 'TESTBEDPythonExecutor'),
        ('MONITOR', 'monitor_impl', 'MONITORPythonExecutor'),
        ('DOCGEN', 'docgen_impl', 'DOCGENPythonExecutor'),
        ('APIDESIGNER', 'apidesigner_impl', 'APIDESIGNERPythonExecutor'),
        ('PROJECTORCHESTRATOR', 'projectorchestrator_impl', 'PROJECTORCHESTRATORPythonExecutor'),
        ('DIRECTOR', 'director_impl', 'DirectorPythonExecutor'),
        ('OPTIMIZER', 'optimizer_impl', 'OPTIMIZERPythonExecutor'),
        ('QUANTUMGUARD', 'quantumguard_impl', 'QUANTUMGUARDPythonExecutor'),
        ('SECURITY', 'security_impl', 'SecurityPythonExecutor'),
        ('DATABASE', 'database_impl', 'DatabasePythonExecutor'),
        ('SECURITYCHAOSAGENT', 'securitychaosagent_impl', 'SecurityChaosAgentPythonExecutor')
    ]
    
    print("🔍 Verifying Agent Signatures v9.0 Compliance")
    print("=" * 60)
    
    results = []
    
    for agent_name, module_name, class_name in implemented_agents:
        try:
            # Import agent
            module = __import__(module_name)
            agent_class = getattr(module, class_name)
            
            # Test signature
            result = await test_agent_signature(agent_name, agent_class)
            results.append(result)
            
            # Print result
            compliance_status = "✅" if result['v9_compliance'] else "❌"
            signature_status = "✅" if result['signature_test'] == 'pass' else "❌"
            
            print(f"{compliance_status} {agent_name:20} | Signature: {signature_status} | v9.0: {result['v9_compliance']}")
            
            if result['signature_test'] == 'fail':
                print(f"   ⚠️  Signature issue detected")
            if not result['v9_compliance']:
                missing = []
                if not result['has_get_capabilities']: missing.append('get_capabilities')
                if not result['has_get_status']: missing.append('get_status')
                if not result['has_agent_name']: missing.append('agent_name')
                if not result['has_version']: missing.append('version')
                print(f"   🔧 Missing: {', '.join(missing)}")
                
        except ImportError as e:
            # Check if it's missing dependencies or missing implementation
            import_error = str(e)
            if "No module named" in import_error:
                dependency = import_error.split("'")[1]
                results.append({
                    'agent': agent_name,
                    'signature_test': 'missing_dependency',
                    'dependency': dependency,
                    'error': str(e),
                    'v9_compliance': False
                })
                print(f"🔧 {agent_name:20} | Missing Dependency: {dependency}")
            else:
                results.append({
                    'agent': agent_name,
                    'signature_test': 'import_error',
                    'error': str(e),
                    'v9_compliance': False
                })
                print(f"❌ {agent_name:20} | Import Error: {str(e)[:50]}...")
        except Exception as e:
            results.append({
                'agent': agent_name,
                'signature_test': 'import_error',
                'error': str(e),
                'v9_compliance': False
            })
            print(f"❌ {agent_name:20} | Import Error: {str(e)[:50]}...")
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Summary:")
    
    total = len(results)
    signature_pass = sum(1 for r in results if r['signature_test'] == 'pass')
    v9_compliant = sum(1 for r in results if r['v9_compliance'])
    
    print(f"   Total agents tested: {total}")
    print(f"   Signature tests passed: {signature_pass}/{total}")
    print(f"   v9.0 compliant: {v9_compliant}/{total}")
    print(f"   Success rate: {v9_compliant/total*100:.1f}%")
    
    # Identify issues
    signature_issues = [r for r in results if r['signature_test'] == 'fail']
    compliance_issues = [r for r in results if not r['v9_compliance']]
    
    if signature_issues:
        print(f"\n🔧 Agents needing signature fixes:")
        for result in signature_issues:
            print(f"   - {result['agent']}")
    
    if compliance_issues:
        print(f"\n🔧 Agents needing v9.0 compliance updates:")
        for result in compliance_issues:
            print(f"   - {result['agent']}")
    
    if v9_compliant == total:
        print("\n🎉 All agents are v9.0 compliant!")
        return True
    else:
        print(f"\n⚠️  {total - v9_compliant} agents need updates")
        return False

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)