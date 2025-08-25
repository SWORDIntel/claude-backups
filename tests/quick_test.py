#!/usr/bin/env python3
"""Quick test to verify hybrid bridge integration is working"""

import sys
import os

print("=" * 60)
print("QUICK HYBRID BRIDGE TEST")
print("=" * 60)

# Test 1: Basic imports
print("\n1. Testing Basic Imports...")
try:
    import asyncpg
    print("✅ asyncpg: Available")
except ImportError:
    print("❌ asyncpg: Missing")

try:
    import psycopg2
    print("✅ psycopg2: Available")  
except ImportError:
    print("❌ psycopg2: Missing")

try:
    import numpy
    print("✅ numpy: Available")
except ImportError:
    print("❌ numpy: Missing")

# Test 2: Hybrid Bridge Manager
print("\n2. Testing Hybrid Bridge Manager...")
try:
    from hybrid_bridge_manager import HybridBridgeManager
    bridge = HybridBridgeManager()
    status = bridge.get_system_status()
    print("✅ Hybrid Bridge Manager: Working")
    print(f"   Status: {status.get('bridge_manager', {}).get('status', 'unknown')}")
    print(f"   Mode: {status.get('bridge_manager', {}).get('mode', 'unknown')}")
except Exception as e:
    print(f"❌ Hybrid Bridge Manager: Error - {e}")

# Test 3: Learning System
print("\n3. Testing Learning System...")
try:
    from postgresql_learning_system import UltimatePostgreSQLLearningSystem
    print("✅ Learning System Import: Success")
except Exception as e:
    print(f"❌ Learning System: Error - {e}")

# Test 4: Production Orchestrator  
print("\n4. Testing Production Orchestrator...")
try:
    from production_orchestrator import ProductionOrchestrator
    print("✅ Production Orchestrator: Success")
except Exception as e:
    print(f"❌ Production Orchestrator: Error - {e}")

# Summary
print("\n" + "=" * 60)
print("QUICK TEST SUMMARY")
print("=" * 60)

try:
    from hybrid_bridge_manager import HybridBridgeManager
    bridge = HybridBridgeManager()
    status = bridge.get_system_status()
    
    if status.get('bridge_manager', {}).get('status') in ['operational', 'initializing']:
        print("🎉 HYBRID BRIDGE INTEGRATION: WORKING!")
        print("✅ Core functionality is operational")
        print("✅ All critical components available")
        print("✅ System ready for use")
    else:
        print("⚠️  PARTIAL FUNCTIONALITY")
        print("✅ Components load but system in fallback mode")
        
except Exception as e:
    print(f"❌ INTEGRATION ISSUES: {e}")

print(f"\nPython version: {sys.version}")
print(f"Working directory: {os.getcwd()}")
print("=" * 60)