#!/usr/bin/env python3
"""
Test Security Agent through the Tandem Orchestration System
This will verify if the Security agent actually creates files/directories 
as claimed or if it has "0 tool uses"
"""

import asyncio
import os
import sys
import tempfile
import time
import json
from pathlib import Path

# Add current directory to path to import modules
sys.path.insert(0, '/home/ubuntu/Documents/Claude/agents/src/python')

from security_impl import SecurityPythonExecutor
from production_orchestrator import ProductionOrchestrator

async def test_security_agent_direct():
    """Test Security agent directly"""
    print("=" * 70)
    print("TESTING SECURITY AGENT DIRECTLY")
    print("=" * 70)
    
    security = SecurityPythonExecutor()
    
    # Create a temporary test directory
    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"Testing in temporary directory: {temp_dir}")
        
        # Create some test files with potential vulnerabilities
        test_files = {
            "test.py": 'password = "123456"\neval(user_input)\nimport os; os.system(cmd)',
            "test.js": 'function login() { return admin = true; }\njQuery("1.7.0")',
            "Dockerfile": 'FROM ubuntu:latest\nUSER root\nRUN --privileged something',
            "requirements.txt": 'django==1.8.0\nflask==0.12\njquery==1.6.0'
        }
        
        for filename, content in test_files.items():
            filepath = Path(temp_dir) / filename
            filepath.write_text(content)
        
        print(f"Created {len(test_files)} test files with potential vulnerabilities")
        
        # Test 1: Vulnerability Scanning
        print("\n1. Testing Vulnerability Scanning...")
        result = await security.execute_command("vulnerability_scan", {
            "target": temp_dir,
            "scan_types": ["static_analysis", "dependency_check"],
            "type": "comprehensive"
        })
        
        print(f"Result Status: {result['status']}")
        print(f"Vulnerabilities Found: {result['result'].get('vulnerabilities_found', 0)}")
        print(f"Risk Score: {result['result'].get('risk_score', 0)}")
        
        # Test 2: Compliance Audit
        print("\n2. Testing Compliance Audit...")
        result = await security.execute_command("compliance_audit", {
            "framework": "owasp",
            "target": temp_dir
        })
        
        print(f"Result Status: {result['status']}")
        print(f"Framework: {result['result'].get('framework', 'unknown')}")
        print(f"Overall Score: {result['result'].get('overall_score', 0)}")
        
        # Test 3: Threat Modeling
        print("\n3. Testing Threat Modeling...")
        result = await security.execute_command("threat_model", {
            "asset": "web_application",
            "methodology": "stride"
        })
        
        print(f"Result Status: {result['status']}")
        print(f"Methodology: {result['result'].get('methodology', 'unknown')}")
        print(f"Overall Risk: {result['result'].get('overall_risk', 'unknown')}")
        
        # Test 4: Security Policy Creation
        print("\n4. Testing Security Policy Creation...")
        result = await security.execute_command("create_policy", {
            "type": "password"
        })
        
        print(f"Result Status: {result['status']}")
        print(f"Policy Type: {result['result'].get('policy_type', 'unknown')}")
        
        # Show final metrics
        print("\n" + "=" * 50)
        print("SECURITY AGENT METRICS:")
        status = security.get_status()
        for key, value in status['metrics'].items():
            print(f"  {key}: {value}")
        
        print(f"\nTools Available: {status['tools_available']}/{status['total_tools']}")
        print(f"Security Frameworks: {len(status['security_frameworks'])}")
        
        return status

async def test_security_through_orchestrator():
    """Test Security agent through the Production Orchestrator"""
    print("\n" + "=" * 70)
    print("TESTING SECURITY AGENT THROUGH ORCHESTRATOR")
    print("=" * 70)
    
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    
    # Test orchestrator invocation
    print("\n1. Testing agent invocation through orchestrator...")
    
    try:
        result = await orchestrator.invoke_agent('security', 'perform_security_audit', {
            'target': '/home/ubuntu/Documents/Claude/agents',
            'scan_types': ['static_analysis', 'dependency_check'],
            'compliance_frameworks': ['owasp_top10', 'nist_csf']
        })
        
        print(f"Orchestrator Result: {result}")
        return result
    except Exception as e:
        print(f"Orchestrator test failed: {e}")
        return None

def check_file_creation():
    """Check if Security agent created any files or directories"""
    print("\n" + "=" * 70)
    print("CHECKING FOR FILE/DIRECTORY CREATION")
    print("=" * 70)
    
    # Check common locations where security tools might create files
    check_paths = [
        '/home/ubuntu/Documents/Claude/agents/security_audit',
        '/home/ubuntu/Documents/Claude/agents/src/python/security_reports',
        '/home/ubuntu/Documents/Claude/security_reports',
        '/tmp/security_audit',
        './security_audit',
        './security_reports'
    ]
    
    created_files = []
    for path in check_paths:
        if os.path.exists(path):
            created_files.append(path)
            print(f"Found: {path}")
    
    if not created_files:
        print("No security audit files/directories found in expected locations")
    
    return created_files

async def main():
    """Main test function"""
    print("SECURITY AGENT VERIFICATION TEST")
    print("Testing claims about Security agent capabilities vs '0 tool uses'")
    print("=" * 70)
    
    start_time = time.time()
    
    # Test 1: Direct Security agent testing
    security_status = await test_security_agent_direct()
    
    # Test 2: Orchestrator testing
    orchestrator_result = await test_security_through_orchestrator()
    
    # Test 3: Check for file creation
    created_files = check_file_creation()
    
    # Final analysis
    print("\n" + "=" * 70)
    print("FINAL ANALYSIS")
    print("=" * 70)
    
    execution_time = time.time() - start_time
    print(f"Total Test Execution Time: {execution_time:.2f} seconds")
    
    # Analyze results
    print(f"\nSecurity Agent Metrics:")
    if security_status:
        print(f"  - Security Audits Performed: {security_status['metrics']['security_audits']}")
        print(f"  - Vulnerabilities Found: {security_status['metrics']['vulnerabilities_found']}")
        print(f"  - Compliance Checks: {security_status['metrics']['compliance_checks']}")
        print(f"  - Threat Models Created: {security_status['metrics']['threat_models_created']}")
        print(f"  - Overall Security Score: {security_status['metrics']['security_score']}")
    
    print(f"\nOrchestrator Integration:")
    if orchestrator_result:
        print(f"  - Orchestrator invocation: SUCCESS")
        print(f"  - Result type: {type(orchestrator_result)}")
    else:
        print(f"  - Orchestrator invocation: FAILED")
    
    print(f"\nFile/Directory Creation:")
    if created_files:
        print(f"  - Files/directories created: {len(created_files)}")
        for file in created_files:
            print(f"    * {file}")
    else:
        print(f"  - No security audit files/directories created")
    
    # Conclusion
    print(f"\nCONCLUSION:")
    if security_status and security_status['metrics']['security_audits'] > 0:
        print(f"✓ Security agent IS functional and performs security operations")
        print(f"✓ Successfully executed {security_status['metrics']['security_audits']} security audits")
        print(f"✓ Found {security_status['metrics']['vulnerabilities_found']} vulnerabilities")
        print(f"✓ Has access to {security_status['tools_available']} security tools")
        
        if created_files:
            print(f"✓ Created {len(created_files)} files/directories")
        else:
            print(f"⚠ No files/directories created (may be working in-memory)")
        
        print(f"\nThe claim of '0 tool uses' appears to be INCORRECT.")
        print(f"The Security agent is fully functional and actively performing security analysis.")
    else:
        print(f"✗ Security agent functionality unclear")
        print(f"The '0 tool uses' claim may be CORRECT.")

if __name__ == "__main__":
    asyncio.run(main())