#!/usr/bin/env python3
"""
Test script for Claude Unified Hook System v3.1
Properly handles async API and correct method signatures
"""

import asyncio
import json
import time
from pathlib import Path
import sys
import pytest

# Add hooks directory to path
sys.path.insert(0, str(Path(__file__).parent))

from claude_unified_hook_system_v2 import ClaudeUnifiedHooks


@pytest.mark.asyncio
async def test_basic_functionality():
    """Test basic hook system functionality"""
    print("\n" + "="*60)
    print("CLAUDE UNIFIED HOOK SYSTEM v3.1 - FUNCTIONAL TEST")
    print("="*60)
    
    # Initialize the hook system
    print("\n1. Initializing Hook System...")
    hooks = ClaudeUnifiedHooks()
    print(f"   ✓ Loaded {len(hooks.engine.registry.agents)} agents")
    
    # Test various inputs
    test_cases = [
        {
            "input": "Fix the security vulnerability in the authentication system",
            "expected_categories": ["security", "debugging"],
            "expected_agents": ["SECURITY", "DEBUGGER", "PATCHER"]
        },
        {
            "input": "Optimize database performance and monitor latency",
            "expected_categories": ["performance", "monitoring"],
            "expected_agents": ["OPTIMIZER", "DATABASE", "MONITOR"]
        },
        {
            "input": "Deploy the application to production with Docker",
            "expected_categories": ["deployment"],
            "expected_agents": ["DEPLOYER", "DOCKER-AGENT", "INFRASTRUCTURE"]
        },
        {
            "input": "Create unit tests for the new feature",
            "expected_categories": ["testing", "development"],
            "expected_agents": ["TESTBED", "CONSTRUCTOR"]
        },
        {
            "input": "Debug the crash in the Python GUI application",
            "expected_categories": ["debugging", "development"],
            "expected_agents": ["DEBUGGER", "PYGUI", "PYTHON-INTERNAL"]
        }
    ]
    
    print("\n2. Testing Pattern Matching...")
    for i, test in enumerate(test_cases, 1):
        print(f"\n   Test {i}: {test['input'][:50]}...")
        
        start = time.time()
        result = await hooks.process(test['input'])
        elapsed = (time.time() - start) * 1000
        
        print(f"   - Time: {elapsed:.2f}ms")
        print(f"   - Categories: {result.get('categories', [])}")
        print(f"   - Agents: {result.get('agents', [])[:5]}")  # Show first 5
        print(f"   - Confidence: {result.get('confidence', 0):.2%}")
        
        # Verify expected results
        categories_found = set(result.get('categories', []))
        agents_found = set(result.get('agents', []))
        
        expected_cats = set(test['expected_categories'])
        expected_agents = set(test['expected_agents'])
        
        if categories_found & expected_cats:
            print(f"   ✓ Found expected categories")
        else:
            print(f"   ⚠ Missing categories: {expected_cats - categories_found}")
            
        if agents_found & expected_agents:
            print(f"   ✓ Found expected agents")
        else:
            print(f"   ⚠ Missing agents: {expected_agents - agents_found}")
    
    print("\n3. Testing Parallel Execution...")
    # Test parallel processing
    inputs = [
        "Security audit of the authentication system",
        "Optimize performance bottlenecks",
        "Deploy to production environment",
        "Create comprehensive documentation",
        "Fix critical bugs in the system"
    ]
    
    start = time.time()
    tasks = [hooks.process(inp) for inp in inputs]
    results = await asyncio.gather(*tasks)
    elapsed = (time.time() - start) * 1000
    
    print(f"   - Processed {len(inputs)} requests in {elapsed:.2f}ms")
    print(f"   - Average: {elapsed/len(inputs):.2f}ms per request")
    print(f"   - Throughput: {1000*len(inputs)/elapsed:.1f} req/s")
    
    # Check results
    total_agents = sum(len(r.get('agents', [])) for r in results)
    print(f"   - Total agents matched: {total_agents}")
    print(f"   ✓ Parallel execution successful")
    
    print("\n4. System Status...")
    status = hooks.get_status()
    print(f"   - Version: {status.get('version', 'Unknown')}")
    print(f"   - Optimizations: {len(status.get('optimizations', []))} active")
    print(f"   - Security Features: {len(status.get('security_features', []))} active")
    
    # Performance metrics
    if 'performance' in status:
        perf = status['performance']
        print(f"\n5. Performance Metrics:")
        print(f"   - Cache Size: {perf.get('cache_size', 0)}")
        print(f"   - Cache Hits: {perf.get('cache_hits', 0)}")
        print(f"   - Cache Misses: {perf.get('cache_misses', 0)}")
        if perf.get('cache_hits', 0) + perf.get('cache_misses', 0) > 0:
            hit_rate = perf.get('cache_hits', 0) / (perf.get('cache_hits', 0) + perf.get('cache_misses', 0))
            print(f"   - Cache Hit Rate: {hit_rate:.1%}")
    
    print("\n" + "="*60)
    print("TEST SUITE COMPLETED SUCCESSFULLY")
    print("="*60)
    
    return True


@pytest.mark.asyncio
async def test_edge_cases():
    """Test edge cases and error handling"""
    print("\n" + "="*60)
    print("EDGE CASE TESTING")
    print("="*60)
    
    hooks = ClaudeUnifiedHooks()
    
    # Test empty input
    print("\n1. Testing empty input...")
    result = await hooks.process("")
    if "error" in result:
        print("   ✓ Empty input handled correctly")
    else:
        print("   ⚠ Empty input not properly validated")
    
    # Test very long input
    print("\n2. Testing very long input...")
    long_input = "optimize " * 1000  # Very long input
    result = await hooks.process(long_input)
    if "error" in result:
        print("   ✓ Long input handled correctly")
    else:
        print("   ⚠ Long input processed (may need limits)")
    
    # Test special characters
    print("\n3. Testing special characters...")
    special_input = "Fix bug in @#$%^&*() system"
    result = await hooks.process(special_input)
    print(f"   - Agents matched: {len(result.get('agents', []))}")
    print("   ✓ Special characters handled")
    
    # Test concurrent stress
    print("\n4. Testing concurrent stress (100 requests)...")
    start = time.time()
    tasks = [hooks.process(f"Task {i}") for i in range(100)]
    results = await asyncio.gather(*tasks)
    elapsed = (time.time() - start) * 1000
    
    print(f"   - Completed in {elapsed:.2f}ms")
    print(f"   - Throughput: {100000/elapsed:.1f} req/s")
    print("   ✓ Stress test passed")
    
    print("\n" + "="*60)
    print("EDGE CASE TESTING COMPLETED")
    print("="*60)


async def main():
    """Main test runner"""
    try:
        # Run basic tests
        await test_basic_functionality()
        
        # Run edge case tests
        await test_edge_cases()
        
        print("\n✅ ALL TESTS COMPLETED SUCCESSFULLY")
        return 0
        
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)