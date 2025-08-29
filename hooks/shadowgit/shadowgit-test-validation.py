#!/usr/bin/env python3
"""
Shadowgit Neural Test & Validation Suite
Comprehensive testing of NPU/GNA integration and failsafe mechanisms
Version: 2.0.0
"""

import os
import sys
import asyncio
import json
import time
import tempfile
import shutil
import subprocess
import hashlib
import numpy as np
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass
import unittest
from unittest.mock import Mock, patch, MagicMock
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ShadowgitTest')

# ============================================================================
# TEST CONFIGURATIONS
# ============================================================================

@dataclass
class TestConfig:
    """Test configuration"""
    test_dir: Path = Path("/tmp/shadowgit_test")
    shadow_repo: Path = Path("/tmp/shadowgit_test/.shadowgit.git")
    enable_hardware_tests: bool = True
    enable_performance_tests: bool = True
    enable_stress_tests: bool = False
    target_latency_ms: float = 100.0
    min_confidence: float = 0.7

# ============================================================================
# TEST FIXTURES
# ============================================================================

TEST_CODE_SAMPLES = {
    "simple_function": '''
def hello_world():
    """Simple test function"""
    return "Hello, World!"
''',
    
    "complex_class": '''
import asyncio
import numpy as np
from typing import List, Dict, Optional

class DataProcessor:
    """Complex data processing class"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.cache = {}
        self.processing_queue = asyncio.Queue()
        
    async def process_batch(self, data: List[np.ndarray]) -> List[Dict]:
        """Process a batch of data"""
        results = []
        for item in data:
            try:
                result = await self._process_single(item)
                results.append(result)
            except Exception as e:
                logger.error(f"Processing failed: {e}")
                results.append({"error": str(e)})
        return results
        
    async def _process_single(self, data: np.ndarray) -> Dict:
        """Process single data item"""
        # Complex processing logic
        mean = np.mean(data)
        std = np.std(data)
        return {
            "mean": float(mean),
            "std": float(std),
            "shape": data.shape
        }
''',
    
    "security_issue": '''
import pickle
import subprocess

def dangerous_function(user_input):
    """Function with security issues"""
    # Security issue: eval
    result = eval(user_input)
    
    # Security issue: pickle
    with open('data.pkl', 'rb') as f:
        data = pickle.load(f)
    
    # Security issue: subprocess
    subprocess.call(user_input, shell=True)
    
    return result
''',
    
    "performance_issue": '''
def fibonacci(n):
    """Inefficient recursive fibonacci"""
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

def nested_loops():
    """Highly complex nested loops"""
    result = 0
    for i in range(100):
        for j in range(100):
            for k in range(100):
                for l in range(100):
                    result += i * j * k * l
    return result
'''
}

# ============================================================================
# HARDWARE TESTS
# ============================================================================

class HardwareDetectionTests(unittest.TestCase):
    """Test hardware detection and failsafe mechanisms"""
    
    def setUp(self):
        """Setup test environment"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine, NeuralConfig
        
        self.config = NeuralConfig(
            mode="intelligent",
            power_mode="balanced",
            enable_telemetry=True
        )
        
    def test_hardware_detection(self):
        """Test hardware capability detection"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine(self.config)
        caps = engine.capabilities
        
        # Check detection completed
        self.assertIsNotNone(caps)
        self.assertGreaterEqual(caps.cpu_cores, 1)
        
        # Log detected hardware
        logger.info(f"Hardware detected:")
        logger.info(f"  NPU: {caps.npu_available}")
        logger.info(f"  GNA: {caps.gna_available}")
        logger.info(f"  GPU: {caps.gpu_available}")
        logger.info(f"  CPU cores: {caps.cpu_cores}")
        logger.info(f"  AVX-512: {caps.avx_512}")
        
    def test_npu_failsafe(self):
        """Test NPU failsafe to CPU"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine(self.config)
        
        async def test_failsafe():
            # Force NPU, but should failsafe if not available
            result = await engine.analyze_code_change(
                TEST_CODE_SAMPLES["simple_function"],
                "test.py",
                {"force_device": "NPU"}
            )
            
            self.assertIsNotNone(result)
            self.assertIn(result.device, ["NPU", "CPU"])
            
            if not engine.capabilities.npu_available:
                self.assertEqual(result.device, "CPU")
                logger.info("✓ NPU failsafe to CPU working")
                
        asyncio.run(test_failsafe())
        
    def test_gna_failsafe(self):
        """Test GNA failsafe to CPU"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine(self.config)
        
        async def test_failsafe():
            # Force GNA, but should failsafe if not available
            result = await engine.analyze_code_change(
                TEST_CODE_SAMPLES["simple_function"],
                "test.py",
                {"force_device": "GNA"}
            )
            
            self.assertIsNotNone(result)
            self.assertIn(result.device, ["GNA", "CPU"])
            
            if not engine.capabilities.gna_available:
                self.assertEqual(result.device, "CPU")
                logger.info("✓ GNA failsafe to CPU working")
                
        asyncio.run(test_failsafe())
        
    @unittest.skipUnless(os.path.exists("/dev/shm"), "Shared memory not available")
    def test_shared_memory(self):
        """Test shared memory initialization"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine(self.config)
        
        self.assertIsNotNone(engine.shared_memory)
        logger.info("✓ Shared memory initialized")

# ============================================================================
# FUNCTIONAL TESTS
# ============================================================================

class FunctionalTests(unittest.TestCase):
    """Test core functionality"""
    
    def setUp(self):
        """Setup test environment"""
        self.test_dir = Path("/tmp/shadowgit_test")
        self.test_dir.mkdir(exist_ok=True)
        
    def tearDown(self):
        """Cleanup test environment"""
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)
            
    def test_code_analysis(self):
        """Test code analysis functionality"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine()
        
        async def analyze_samples():
            results = {}
            
            for name, code in TEST_CODE_SAMPLES.items():
                result = await engine.analyze_code_change(
                    code, f"{name}.py", {}
                )
                
                self.assertIsNotNone(result)
                self.assertGreater(result.confidence, 0)
                self.assertIsNotNone(result.embeddings)
                
                results[name] = {
                    "device": result.device,
                    "confidence": result.confidence,
                    "latency_ms": result.latency_ms,
                    "patterns": result.patterns
                }
                
                logger.info(f"Analysis of {name}:")
                logger.info(f"  Device: {result.device}")
                logger.info(f"  Confidence: {result.confidence:.3f}")
                logger.info(f"  Latency: {result.latency_ms:.2f}ms")
                logger.info(f"  Patterns: {result.patterns}")
                
            return results
            
        results = asyncio.run(analyze_samples())
        
        # Verify security issues detected
        if "security_issue" in results:
            patterns = results["security_issue"]["patterns"]
            self.assertTrue(any("security" in p.lower() for p in patterns))
            
    def test_pattern_detection(self):
        """Test pattern detection capabilities"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine()
        
        async def test_patterns():
            # Test function pattern
            result = await engine.analyze_code_change(
                "def test(): pass",
                "test.py",
                {}
            )
            self.assertTrue(any("function" in p.lower() for p in result.patterns))
            
            # Test class pattern
            result = await engine.analyze_code_change(
                "class Test: pass",
                "test.py",
                {}
            )
            self.assertTrue(any("class" in p.lower() for p in result.patterns))
            
        asyncio.run(test_patterns())
        
    def test_batch_processing(self):
        """Test batch processing capability"""
        from shadowgit_watcher_enhanced import ShadowgitWatcherEnhanced, WatcherConfig
        
        config = WatcherConfig(
            watch_dirs=[str(self.test_dir)],
            batch_window_ms=100,
            max_batch_size=5
        )
        
        watcher = ShadowgitWatcherEnhanced(config)
        
        async def test_batch():
            await watcher.initialize()
            
            # Create multiple file changes
            for i in range(5):
                file_path = self.test_dir / f"test_{i}.py"
                file_path.write_text(f"# Test file {i}\ndef func_{i}(): pass")
                await watcher.handle_file_change(str(file_path), "created")
                
            # Wait for batch processing
            await asyncio.sleep(0.2)
            
            # Check statistics
            stats = watcher.get_statistics()
            self.assertGreater(stats["files_analyzed"], 0)
            
        asyncio.run(test_batch())

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

class PerformanceTests(unittest.TestCase):
    """Test performance characteristics"""
    
    def setUp(self):
        """Setup performance tests"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        self.engine = ShadowgitNeuralEngine()
        
    def test_inference_latency(self):
        """Test inference latency requirements"""
        
        async def measure_latency():
            latencies = []
            
            for _ in range(10):
                start = time.perf_counter()
                result = await self.engine.analyze_code_change(
                    TEST_CODE_SAMPLES["simple_function"],
                    "test.py",
                    {}
                )
                latency = (time.perf_counter() - start) * 1000
                latencies.append(latency)
                
            avg_latency = np.mean(latencies)
            p95_latency = np.percentile(latencies, 95)
            
            logger.info(f"Latency statistics:")
            logger.info(f"  Average: {avg_latency:.2f}ms")
            logger.info(f"  P95: {p95_latency:.2f}ms")
            logger.info(f"  Min: {np.min(latencies):.2f}ms")
            logger.info(f"  Max: {np.max(latencies):.2f}ms")
            
            # Check against target
            self.assertLess(avg_latency, 200)  # 200ms average
            self.assertLess(p95_latency, 500)  # 500ms P95
            
        asyncio.run(measure_latency())
        
    def test_throughput(self):
        """Test processing throughput"""
        
        async def measure_throughput():
            start = time.time()
            tasks = []
            
            # Process 100 files concurrently
            for i in range(100):
                task = self.engine.analyze_code_change(
                    TEST_CODE_SAMPLES["simple_function"],
                    f"test_{i}.py",
                    {}
                )
                tasks.append(task)
                
            results = await asyncio.gather(*tasks)
            
            duration = time.time() - start
            throughput = len(results) / duration
            
            logger.info(f"Throughput: {throughput:.2f} files/second")
            logger.info(f"Total time: {duration:.2f}s for {len(results)} files")
            
            self.assertGreater(throughput, 10)  # At least 10 files/second
            
        asyncio.run(measure_throughput())
        
    def test_memory_usage(self):
        """Test memory consumption"""
        import psutil
        
        process = psutil.Process()
        
        # Baseline memory
        baseline_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        async def process_files():
            for _ in range(50):
                await self.engine.analyze_code_change(
                    TEST_CODE_SAMPLES["complex_class"],
                    "test.py",
                    {}
                )
                
        asyncio.run(process_files())
        
        # Check memory after processing
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - baseline_memory
        
        logger.info(f"Memory usage:")
        logger.info(f"  Baseline: {baseline_memory:.2f}MB")
        logger.info(f"  Final: {final_memory:.2f}MB")
        logger.info(f"  Increase: {memory_increase:.2f}MB")
        
        # Should not leak more than 100MB
        self.assertLess(memory_increase, 100)

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class IntegrationTests(unittest.TestCase):
    """Test system integration"""
    
    def setUp(self):
        """Setup integration tests"""
        self.test_dir = Path("/tmp/shadowgit_integration")
        self.test_dir.mkdir(exist_ok=True)
        
        # Initialize shadow repo
        subprocess.run(
            ["git", "init", "--bare", str(self.test_dir / ".shadowgit.git")],
            capture_output=True
        )
        
    def tearDown(self):
        """Cleanup"""
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)
            
    def test_shadow_repository_integration(self):
        """Test shadow repository creation"""
        from shadowgit_watcher_enhanced import ShadowgitWatcherEnhanced, WatcherConfig
        
        config = WatcherConfig(
            shadow_repo_path=str(self.test_dir / ".shadowgit.git")
        )
        
        watcher = ShadowgitWatcherEnhanced(config)
        
        async def test_shadow_commits():
            await watcher.initialize()
            
            # Process a file
            await watcher.handle_file_change(
                str(self.test_dir / "test.py"),
                "created"
            )
            
            # Check shadow commits created
            result = subprocess.run(
                ["git", "--git-dir", str(self.test_dir / ".shadowgit.git"),
                 "log", "--oneline"],
                capture_output=True,
                text=True
            )
            
            self.assertIn("test", result.stdout.lower())
            
        asyncio.run(test_shadow_commits())
        
    def test_gna_continuous_monitoring(self):
        """Test GNA continuous monitoring (if available)"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine()
        
        if not engine.capabilities.gna_available:
            self.skipTest("GNA not available")
            
        async def test_monitoring():
            # Let GNA monitoring run
            await asyncio.sleep(2)
            
            # Check baseline established
            self.assertIsNotNone(engine.gna_baseline)
            self.assertGreater(len(engine.gna_baseline["patterns"]), 0)
            
            telemetry = engine.get_telemetry()
            self.assertGreater(telemetry["performance"]["gna_inferences"], 0)
            
        asyncio.run(test_monitoring())

# ============================================================================
# STRESS TESTS
# ============================================================================

class StressTests(unittest.TestCase):
    """Stress testing (optional)"""
    
    @unittest.skipUnless(
        TestConfig().enable_stress_tests,
        "Stress tests disabled"
    )
    def test_sustained_load(self):
        """Test sustained high load"""
        from shadowgit_neural_engine import ShadowgitNeuralEngine
        
        engine = ShadowgitNeuralEngine()
        
        async def stress_test():
            start = time.time()
            tasks = []
            
            # Create 1000 concurrent requests
            for i in range(1000):
                task = engine.analyze_code_change(
                    TEST_CODE_SAMPLES["complex_class"],
                    f"stress_{i}.py",
                    {}
                )
                tasks.append(task)
                
                # Add some delay to prevent overwhelming
                if i % 100 == 0:
                    await asyncio.sleep(0.1)
                    
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            duration = time.time() - start
            success_count = sum(1 for r in results if not isinstance(r, Exception))
            
            logger.info(f"Stress test results:")
            logger.info(f"  Total requests: {len(results)}")
            logger.info(f"  Successful: {success_count}")
            logger.info(f"  Failed: {len(results) - success_count}")
            logger.info(f"  Duration: {duration:.2f}s")
            logger.info(f"  Rate: {success_count/duration:.2f} req/s")
            
            # Should handle at least 90% successfully
            self.assertGreater(success_count / len(results), 0.9)
            
        asyncio.run(stress_test())

# ============================================================================
# TEST RUNNER
# ============================================================================

def run_tests(config: TestConfig = None):
    """Run all tests with configuration"""
    
    config = config or TestConfig()
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    test_classes = [
        HardwareDetectionTests,
        FunctionalTests,
    ]
    
    if config.enable_hardware_tests:
        test_classes.append(HardwareDetectionTests)
        
    if config.enable_performance_tests:
        test_classes.append(PerformanceTests)
        
    test_classes.append(IntegrationTests)
    
    if config.enable_stress_tests:
        test_classes.append(StressTests)
        
    for test_class in test_classes:
        suite.addTests(loader.loadTestsFromTestCase(test_class))
        
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")
    
    if result.wasSuccessful():
        print("\n✓ All tests passed!")
    else:
        print("\n✗ Some tests failed")
        
    return result.wasSuccessful()

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Shadowgit Neural Test Suite")
    parser.add_argument("--hardware", action="store_true", help="Run hardware tests")
    parser.add_argument("--performance", action="store_true", help="Run performance tests")
    parser.add_argument("--stress", action="store_true", help="Run stress tests")
    parser.add_argument("--all", action="store_true", help="Run all tests")
    
    args = parser.parse_args()
    
    config = TestConfig()
    
    if args.all:
        config.enable_hardware_tests = True
        config.enable_performance_tests = True
        config.enable_stress_tests = True
    else:
        config.enable_hardware_tests = args.hardware
        config.enable_performance_tests = args.performance
        config.enable_stress_tests = args.stress
        
    success = run_tests(config)
    sys.exit(0 if success else 1)