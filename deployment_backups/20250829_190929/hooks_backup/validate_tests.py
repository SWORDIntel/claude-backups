#!/usr/bin/env python3
"""
Quick validation script for specialized test infrastructure
Tests basic functionality without running full test suites
"""

import sys
import traceback
from pathlib import Path

def test_imports():
    """Test that all required imports work"""
    print("🧪 Testing imports...")
    
    try:
        # Test basic test infrastructure
        from test_fixtures import TestFixtures, MockExecutionResult, MockTaskTool
        print("  ✅ test_fixtures imports successful")
        
        # Test that we can create temp projects
        temp_project = TestFixtures.create_temp_project()
        if temp_project.exists():
            print("  ✅ Temp project creation successful")
            import shutil
            shutil.rmtree(temp_project, ignore_errors=True)
        
        # Test data generation
        test_inputs = TestFixtures.generate_test_inputs(10)
        if len(test_inputs) == 10:
            print("  ✅ Test input generation successful")
        
        malicious_inputs = TestFixtures.create_malicious_inputs()
        if len(malicious_inputs) > 10:
            print("  ✅ Malicious input generation successful")
            
        return True
        
    except Exception as e:
        print(f"  ❌ Import test failed: {e}")
        traceback.print_exc()
        return False

def test_integration_structure():
    """Test integration test structure"""
    print("🔗 Testing integration test structure...")
    
    try:
        # Import integration test classes (don't run them)
        import test_integration
        
        # Check that key test classes exist
        required_classes = [
            "TestMultiAgentCoordination",
            "TestFileSystemIntegration", 
            "TestCircuitBreakerIntegration",
            "TestResourceLimits",
            "TestAgentRegistryIntegration",
            "TestPatternMatchingIntegration",
            "TestShadowgitIntegration"
        ]
        
        for class_name in required_classes:
            if hasattr(test_integration, class_name):
                print(f"  ✅ {class_name} class found")
            else:
                print(f"  ❌ {class_name} class missing")
                return False
        
        return True
        
    except Exception as e:
        print(f"  ❌ Integration structure test failed: {e}")
        traceback.print_exc()
        return False

def test_performance_structure():
    """Test performance test structure"""
    print("⚡ Testing performance test structure...")
    
    try:
        # Import performance test classes (don't run them)
        import test_performance
        
        # Check that key test classes exist
        required_classes = [
            "TestThroughputBenchmarks",
            "TestParallelExecutionBenchmarks",
            "TestCachePerformanceBenchmarks", 
            "TestPatternMatchingBenchmarks",
            "TestMemoryResourceBenchmarks"
        ]
        
        for class_name in required_classes:
            if hasattr(test_performance, class_name):
                print(f"  ✅ {class_name} class found")
            else:
                print(f"  ❌ {class_name} class missing")
                return False
        
        # Check performance metrics class
        metrics_class = getattr(test_performance, 'PerformanceMetrics', None)
        if metrics_class:
            print("  ✅ PerformanceMetrics class found")
        else:
            print("  ❌ PerformanceMetrics class missing")
            return False
        
        return True
        
    except Exception as e:
        print(f"  ❌ Performance structure test failed: {e}")
        traceback.print_exc()
        return False

def test_hook_system_availability():
    """Test that the hook system can be imported"""
    print("🎣 Testing hook system availability...")
    
    try:
        # Import main hook system components
        from claude_unified_hook_system_v2 import (
            ClaudeUnifiedHooks, UnifiedConfig, UnifiedAgentRegistry,
            UnifiedMatcher, UnifiedHookEngine
        )
        print("  ✅ Hook system imports successful")
        
        # Test basic configuration
        config = UnifiedConfig()
        if config.project_root:
            print("  ✅ Configuration initialization successful")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Hook system test failed: {e}")
        traceback.print_exc()
        return False

def test_required_dependencies():
    """Test that required dependencies are available"""
    print("📦 Testing required dependencies...")
    
    dependencies = [
        ("asyncio", "Async I/O support"),
        ("pathlib", "Path operations"),
        ("tempfile", "Temporary files"),
        ("multiprocessing", "Multi-processing"),
        ("time", "Timing operations"),
        ("json", "JSON operations"),
        ("dataclasses", "Data classes"),
    ]
    
    optional_dependencies = [
        ("psutil", "System metrics"),
        ("pytest", "Test framework"),
    ]
    
    success = True
    
    # Test required dependencies
    for dep, desc in dependencies:
        try:
            __import__(dep)
            print(f"  ✅ {dep} ({desc})")
        except ImportError:
            print(f"  ❌ {dep} missing ({desc})")
            success = False
    
    # Test optional dependencies
    for dep, desc in optional_dependencies:
        try:
            __import__(dep)
            print(f"  ✅ {dep} ({desc}) - optional")
        except ImportError:
            print(f"  ⚠️  {dep} missing ({desc}) - optional, tests may be limited")
    
    return success

def main():
    """Main validation function"""
    print("=" * 60)
    print("SPECIALIZED TEST INFRASTRUCTURE VALIDATION")
    print("=" * 60)
    
    tests = [
        ("Dependency Check", test_required_dependencies),
        ("Import Test", test_imports),
        ("Hook System Test", test_hook_system_availability),
        ("Integration Structure", test_integration_structure),
        ("Performance Structure", test_performance_structure),
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n{test_name}:")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"  ❌ {test_name} crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("VALIDATION SUMMARY")
    print("=" * 60)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    success_rate = (passed / total) * 100 if total > 0 else 0
    print(f"\nOverall: {passed}/{total} tests passed ({success_rate:.0f}%)")
    
    if success_rate >= 100:
        print("🎉 All validation tests passed! Test infrastructure is ready.")
        print("\nReady to run:")
        print("  ./run_specialized_tests.py")
        print("  python3 -m pytest test_integration.py -v")
        print("  python3 -m pytest test_performance.py -v")
    elif success_rate >= 80:
        print("✅ Most validation tests passed. Test infrastructure is mostly ready.")
        print("⚠️  Some optional components missing but core functionality available.")
    else:
        print("❌ Validation failed. Please fix missing dependencies and components.")
        print("\nTo fix issues:")
        print("  pip3 install pytest pytest-asyncio psutil")
        print("  Ensure claude_unified_hook_system_v2.py is available")
    
    return success_rate >= 80

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)