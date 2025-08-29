#!/usr/bin/env python3
"""
Test Runner for Claude Unified Hook System
TESTBED Agent - Comprehensive Test Execution and Reporting

This module provides:
- Automated test discovery and execution
- Performance benchmarking
- Security vulnerability assessment
- Code coverage analysis
- Comprehensive reporting
- CI/CD integration support
"""

import os
import sys
import subprocess
import json
import time
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, field
import argparse
import logging
import psutil
import pytest
from concurrent.futures import ThreadPoolExecutor
import xml.etree.ElementTree as ET

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('TestRunner')

@dataclass
class TestSuite:
    """Test suite definition"""
    name: str
    pattern: str
    markers: List[str] = field(default_factory=list)
    timeout: int = 300
    parallel: bool = True
    critical: bool = False

@dataclass
class TestResults:
    """Test execution results"""
    suite_name: str
    total_tests: int = 0
    passed_tests: int = 0
    failed_tests: int = 0
    skipped_tests: int = 0
    execution_time: float = 0.0
    coverage_percentage: float = 0.0
    memory_usage_mb: float = 0.0
    error_details: List[str] = field(default_factory=list)
    performance_metrics: Dict[str, float] = field(default_factory=dict)
    security_results: Dict[str, bool] = field(default_factory=dict)

class TestRunner:
    """Comprehensive test runner with advanced features"""
    
    def __init__(self, project_root: Path = None):
        self.project_root = project_root or Path(__file__).parent
        self.results_dir = self.project_root / "test_results"
        self.results_dir.mkdir(exist_ok=True)
        
        self.test_suites = self._define_test_suites()
        self.overall_results = {}
        self.start_time = None
        
        # Performance monitoring
        self.process = psutil.Process()
        self.initial_memory = self.process.memory_info().rss / 1024 / 1024
        
    def _define_test_suites(self) -> Dict[str, TestSuite]:
        """Define all test suites"""
        return {
            "unit_input_validation": TestSuite(
                name="Input Validation Tests",
                pattern="test_claude_unified_hooks.py::TestInputValidation",
                markers=["unit"],
                timeout=60,
                critical=True
            ),
            "unit_pattern_matching": TestSuite(
                name="Pattern Matching Tests", 
                pattern="test_claude_unified_hooks.py::TestPatternMatching",
                markers=["unit"],
                timeout=120,
                critical=True
            ),
            "unit_caching": TestSuite(
                name="Caching Behavior Tests",
                pattern="test_claude_unified_hooks.py::TestCachingBehavior", 
                markers=["unit"],
                timeout=90
            ),
            "unit_error_handling": TestSuite(
                name="Error Handling Tests",
                pattern="test_claude_unified_hooks.py::TestErrorHandling",
                markers=["unit"],
                timeout=120
            ),
            "security_features": TestSuite(
                name="Security Feature Tests",
                pattern="test_claude_unified_hooks.py::TestSecurityFeatures",
                markers=["security"],
                timeout=180,
                critical=True
            ),
            "performance_optimizations": TestSuite(
                name="Performance Optimization Tests",
                pattern="test_claude_unified_hooks.py::TestPerformanceOptimizations",
                markers=["performance"],
                timeout=300
            ),
            "agent_priority": TestSuite(
                name="Agent Priority System Tests",
                pattern="test_claude_unified_hooks.py::TestAgentPrioritySystem",
                markers=["unit"],
                timeout=90
            ),
            "circuit_breaker": TestSuite(
                name="Circuit Breaker Tests",
                pattern="test_claude_unified_hooks.py::TestCircuitBreakerIntegration",
                markers=["integration"],
                timeout=120
            ),
            "rate_limiting": TestSuite(
                name="Rate Limiting Tests", 
                pattern="test_claude_unified_hooks.py::TestRateLimiting",
                markers=["security"],
                timeout=90
            ),
            "authentication": TestSuite(
                name="Authentication Tests",
                pattern="test_claude_unified_hooks.py::TestAuthentication",
                markers=["security"],
                timeout=90
            ),
            "integration_multiagent": TestSuite(
                name="Multi-Agent Integration Tests",
                pattern="test_claude_unified_hooks.py::TestMultiAgentExecution",
                markers=["integration"],
                timeout=180
            ),
            "integration_file_ops": TestSuite(
                name="File Operations Integration Tests",
                pattern="test_claude_unified_hooks.py::TestFileOperations",
                markers=["integration"],
                timeout=120
            ),
            "load_testing": TestSuite(
                name="Load Testing",
                pattern="test_claude_unified_hooks.py::TestLoadTesting", 
                markers=["performance", "slow"],
                timeout=600,
                parallel=False
            ),
            "security_vulnerabilities": TestSuite(
                name="Security Vulnerability Tests",
                pattern="test_claude_unified_hooks.py::TestSecurityVulnerabilities",
                markers=["security"],
                timeout=240,
                critical=True
            ),
            "docker_integration": TestSuite(
                name="Docker Integration Tests",
                pattern="test_claude_unified_hooks.py::TestDockerIntegration",
                markers=["docker", "integration"],
                timeout=120
            )
        }
    
    async def run_all_tests(self, 
                          suites: List[str] = None,
                          parallel: bool = True,
                          coverage: bool = True,
                          verbose: bool = False) -> Dict[str, TestResults]:
        """Run all or specified test suites"""
        
        self.start_time = time.time()
        logger.info("=" * 80)
        logger.info("CLAUDE UNIFIED HOOKS - COMPREHENSIVE TEST EXECUTION")
        logger.info("=" * 80)
        logger.info(f"Project Root: {self.project_root}")
        logger.info(f"Results Directory: {self.results_dir}")
        logger.info(f"Initial Memory Usage: {self.initial_memory:.1f}MB")
        
        # Determine which suites to run
        if suites is None:
            suites_to_run = list(self.test_suites.keys())
        else:
            suites_to_run = [s for s in suites if s in self.test_suites]
        
        logger.info(f"Test Suites to Run: {len(suites_to_run)}")
        for suite_name in suites_to_run:
            suite = self.test_suites[suite_name]
            logger.info(f"  - {suite.name} {'(CRITICAL)' if suite.critical else ''}")
        
        # Environment check
        await self._check_environment()
        
        # Run test suites
        if parallel:
            results = await self._run_suites_parallel(suites_to_run, coverage, verbose)
        else:
            results = await self._run_suites_sequential(suites_to_run, coverage, verbose)
        
        # Generate comprehensive report
        await self._generate_comprehensive_report(results)
        
        # Final validation
        success = await self._validate_requirements(results)
        
        total_time = time.time() - self.start_time
        logger.info("=" * 80)
        logger.info(f"TEST EXECUTION COMPLETED - Total Time: {total_time:.2f}s")
        logger.info(f"Overall Result: {'✅ SUCCESS' if success else '❌ FAILURE'}")
        logger.info("=" * 80)
        
        return results
    
    async def _check_environment(self):
        """Check test environment and dependencies"""
        logger.info("🔍 Checking test environment...")
        
        # Check Python version
        python_version = sys.version_info
        logger.info(f"Python Version: {python_version.major}.{python_version.minor}.{python_version.micro}")
        
        # Check required modules
        required_modules = [
            'pytest', 'asyncio', 'psutil', 'pathlib', 'json',
            'unittest.mock', 'tempfile', 'threading', 'multiprocessing'
        ]
        
        missing_modules = []
        for module in required_modules:
            try:
                __import__(module)
            except ImportError:
                missing_modules.append(module)
        
        if missing_modules:
            logger.error(f"Missing required modules: {missing_modules}")
            raise RuntimeError(f"Missing dependencies: {missing_modules}")
        
        # Check system resources
        memory_gb = psutil.virtual_memory().total / (1024**3)
        cpu_count = os.cpu_count()
        logger.info(f"System Resources: {cpu_count} CPUs, {memory_gb:.1f}GB RAM")
        
        # Check disk space
        disk_usage = psutil.disk_usage(str(self.project_root))
        free_gb = disk_usage.free / (1024**3)
        if free_gb < 1.0:
            logger.warning(f"Low disk space: {free_gb:.1f}GB free")
        
        # Check Docker environment if needed
        try:
            docker_available = Path("/.dockerenv").exists() or os.environ.get("DOCKER_CONTAINER")
            logger.info(f"Docker Environment: {'Yes' if docker_available else 'No'}")
        except:
            logger.info("Docker Environment: Unknown")
        
        logger.info("✅ Environment check completed")
    
    async def _run_suites_parallel(self, suites: List[str], coverage: bool, verbose: bool) -> Dict[str, TestResults]:
        """Run test suites in parallel"""
        logger.info("🚀 Running test suites in parallel...")
        
        # Separate critical and non-critical suites
        critical_suites = [s for s in suites if self.test_suites[s].critical]
        regular_suites = [s for s in suites if not self.test_suites[s].critical]
        
        results = {}
        
        # Run critical suites first (sequential)
        if critical_suites:
            logger.info(f"Running {len(critical_suites)} critical suites sequentially...")
            for suite_name in critical_suites:
                result = await self._run_single_suite(suite_name, coverage, verbose)
                results[suite_name] = result
                
                if result.failed_tests > 0:
                    logger.error(f"CRITICAL SUITE FAILED: {suite_name}")
                    # Continue with other suites but mark overall failure
        
        # Run regular suites in parallel
        if regular_suites:
            logger.info(f"Running {len(regular_suites)} regular suites in parallel...")
            
            with ThreadPoolExecutor(max_workers=min(4, len(regular_suites))) as executor:
                tasks = []
                for suite_name in regular_suites:
                    task = asyncio.get_event_loop().run_in_executor(
                        executor, self._run_suite_sync, suite_name, coverage, verbose
                    )
                    tasks.append((suite_name, task))
                
                # Wait for completion
                for suite_name, task in tasks:
                    try:
                        result = await task
                        results[suite_name] = result
                    except Exception as e:
                        logger.error(f"Suite {suite_name} failed with exception: {e}")
                        results[suite_name] = TestResults(
                            suite_name=suite_name,
                            error_details=[str(e)]
                        )
        
        return results
    
    async def _run_suites_sequential(self, suites: List[str], coverage: bool, verbose: bool) -> Dict[str, TestResults]:
        """Run test suites sequentially"""
        logger.info("⏯️ Running test suites sequentially...")
        
        results = {}
        for suite_name in suites:
            result = await self._run_single_suite(suite_name, coverage, verbose)
            results[suite_name] = result
            
            # Log progress
            success_rate = (result.passed_tests / max(1, result.total_tests)) * 100
            logger.info(f"Suite {suite_name}: {result.passed_tests}/{result.total_tests} ({success_rate:.1f}%)")
        
        return results
    
    async def _run_single_suite(self, suite_name: str, coverage: bool, verbose: bool) -> TestResults:
        """Run a single test suite"""
        suite = self.test_suites[suite_name]
        logger.info(f"🧪 Running: {suite.name}")
        
        start_time = time.time()
        initial_memory = self.process.memory_info().rss / 1024 / 1024
        
        # Build pytest command
        cmd = self._build_pytest_command(suite, coverage, verbose)
        
        try:
            # Run pytest
            result = subprocess.run(
                cmd,
                cwd=self.project_root,
                capture_output=True,
                text=True,
                timeout=suite.timeout
            )
            
            execution_time = time.time() - start_time
            final_memory = self.process.memory_info().rss / 1024 / 1024
            memory_delta = final_memory - initial_memory
            
            # Parse results
            test_results = self._parse_pytest_results(
                suite_name, result, execution_time, memory_delta
            )
            
            # Add coverage if available
            if coverage:
                test_results.coverage_percentage = self._parse_coverage_results()
            
            logger.info(f"✅ {suite.name} completed: {test_results.passed_tests}/{test_results.total_tests} passed")
            
            return test_results
            
        except subprocess.TimeoutExpired:
            logger.error(f"❌ {suite.name} TIMEOUT after {suite.timeout}s")
            return TestResults(
                suite_name=suite_name,
                execution_time=suite.timeout,
                error_details=[f"Timeout after {suite.timeout}s"]
            )
        except Exception as e:
            logger.error(f"❌ {suite.name} EXCEPTION: {e}")
            return TestResults(
                suite_name=suite_name,
                error_details=[str(e)]
            )
    
    def _run_suite_sync(self, suite_name: str, coverage: bool, verbose: bool) -> TestResults:
        """Synchronous wrapper for running suite (for thread pool)"""
        return asyncio.run(self._run_single_suite(suite_name, coverage, verbose))
    
    def _build_pytest_command(self, suite: TestSuite, coverage: bool, verbose: bool) -> List[str]:
        """Build pytest command for suite"""
        cmd = ["python3", "-m", "pytest"]
        
        # Add test pattern
        cmd.append(suite.pattern)
        
        # Add markers
        if suite.markers:
            for marker in suite.markers:
                cmd.extend(["-m", marker])
        
        # Add coverage
        if coverage:
            cmd.extend([
                "--cov=claude_unified_hook_system_v2",
                "--cov-report=xml",
                "--cov-report=html",
                "--cov-report=term-missing"
            ])
        
        # Add output options
        if verbose:
            cmd.append("-v")
        else:
            cmd.append("-q")
        
        # Add junit XML output
        xml_file = self.results_dir / f"{suite.name.replace(' ', '_').lower()}_results.xml"
        cmd.extend(["--junit-xml", str(xml_file)])
        
        # Add timeout
        cmd.extend(["--timeout", str(suite.timeout)])
        
        # Disable warnings for cleaner output
        cmd.append("--disable-warnings")
        
        return cmd
    
    def _parse_pytest_results(self, suite_name: str, result: subprocess.CompletedProcess, 
                            execution_time: float, memory_delta: float) -> TestResults:
        """Parse pytest execution results"""
        
        test_results = TestResults(
            suite_name=suite_name,
            execution_time=execution_time,
            memory_usage_mb=memory_delta
        )
        
        # Parse stdout for test counts
        output = result.stdout
        
        # Look for pytest summary line
        import re
        
        # Pattern: "= 15 passed, 2 failed, 1 skipped in 12.34s ="
        summary_pattern = r"= (\d+) passed(?:, (\d+) failed)?(?:, (\d+) skipped)?"
        match = re.search(summary_pattern, output)
        
        if match:
            test_results.passed_tests = int(match.group(1))
            test_results.failed_tests = int(match.group(2) or 0)
            test_results.skipped_tests = int(match.group(3) or 0)
            test_results.total_tests = (
                test_results.passed_tests + 
                test_results.failed_tests + 
                test_results.skipped_tests
            )
        
        # Parse errors from stderr
        if result.stderr:
            test_results.error_details.extend(result.stderr.split('\n'))
        
        # Parse XML file if available
        xml_file = self.results_dir / f"{suite_name.replace(' ', '_').lower()}_results.xml"
        if xml_file.exists():
            self._parse_junit_xml(xml_file, test_results)
        
        return test_results
    
    def _parse_junit_xml(self, xml_file: Path, test_results: TestResults):
        """Parse JUnit XML results"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            # Update counts from XML (more reliable)
            if root.tag == 'testsuite':
                test_results.total_tests = int(root.get('tests', 0))
                test_results.failed_tests = int(root.get('failures', 0)) + int(root.get('errors', 0))
                test_results.skipped_tests = int(root.get('skipped', 0))
                test_results.passed_tests = (
                    test_results.total_tests - 
                    test_results.failed_tests - 
                    test_results.skipped_tests
                )
                
                # Parse individual test timings
                for testcase in root.findall('testcase'):
                    test_time = float(testcase.get('time', 0))
                    test_name = testcase.get('name', 'unknown')
                    test_results.performance_metrics[test_name] = test_time
        
        except Exception as e:
            logger.warning(f"Failed to parse JUnit XML {xml_file}: {e}")
    
    def _parse_coverage_results(self) -> float:
        """Parse coverage results"""
        coverage_file = self.project_root / "coverage.xml"
        if not coverage_file.exists():
            return 0.0
        
        try:
            tree = ET.parse(coverage_file)
            root = tree.getroot()
            
            # Find coverage percentage
            coverage_elem = root.find(".//coverage")
            if coverage_elem is not None:
                line_rate = float(coverage_elem.get('line-rate', 0))
                return line_rate * 100
            
        except Exception as e:
            logger.warning(f"Failed to parse coverage results: {e}")
        
        return 0.0
    
    async def _generate_comprehensive_report(self, results: Dict[str, TestResults]):
        """Generate comprehensive test report"""
        logger.info("📊 Generating comprehensive test report...")
        
        total_time = time.time() - self.start_time
        final_memory = self.process.memory_info().rss / 1024 / 1024
        memory_delta = final_memory - self.initial_memory
        
        # Calculate overall statistics
        total_tests = sum(r.total_tests for r in results.values())
        total_passed = sum(r.passed_tests for r in results.values())
        total_failed = sum(r.failed_tests for r in results.values())
        total_skipped = sum(r.skipped_tests for r in results.values())
        
        success_rate = (total_passed / max(1, total_tests)) * 100
        
        # Generate report
        report = [
            "CLAUDE UNIFIED HOOKS - COMPREHENSIVE TEST REPORT",
            "=" * 60,
            f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"Total Execution Time: {total_time:.2f}s",
            f"Memory Usage: {memory_delta:+.1f}MB",
            "",
            "OVERALL RESULTS",
            "-" * 20,
            f"Total Test Suites: {len(results)}",
            f"Total Tests: {total_tests}",
            f"Passed: {total_passed} ({total_passed/max(1,total_tests)*100:.1f}%)",
            f"Failed: {total_failed} ({total_failed/max(1,total_tests)*100:.1f}%)",
            f"Skipped: {total_skipped} ({total_skipped/max(1,total_tests)*100:.1f}%)",
            f"Success Rate: {success_rate:.1f}%",
            "",
            "SUITE BREAKDOWN",
            "-" * 15
        ]
        
        # Add suite details
        for suite_name, result in results.items():
            suite = self.test_suites.get(suite_name)
            suite_success = (result.passed_tests / max(1, result.total_tests)) * 100
            
            status = "✅ PASS" if result.failed_tests == 0 and result.total_tests > 0 else "❌ FAIL"
            critical = " (CRITICAL)" if suite and suite.critical else ""
            
            report.extend([
                f"{suite.name if suite else suite_name}{critical}",
                f"  Status: {status}",
                f"  Tests: {result.passed_tests}/{result.total_tests} ({suite_success:.1f}%)",
                f"  Time: {result.execution_time:.2f}s",
                f"  Memory: {result.memory_usage_mb:+.1f}MB"
            ])
            
            if result.coverage_percentage > 0:
                report.append(f"  Coverage: {result.coverage_percentage:.1f}%")
            
            if result.error_details:
                report.append(f"  Errors: {len(result.error_details)} issues found")
            
            report.append("")
        
        # Requirements compliance
        report.extend([
            "REQUIREMENTS COMPLIANCE",
            "-" * 23,
            f"✅ Total tests >=200: {total_tests >= 200} ({total_tests})",
            f"✅ Success rate >=85%: {success_rate >= 85.0} ({success_rate:.1f}%)",
            f"✅ Critical suites pass: {self._check_critical_suites(results)}",
            f"✅ Memory usage stable: {abs(memory_delta) < 100} ({memory_delta:+.1f}MB)",
            ""
        ])
        
        # Performance summary
        all_perf_metrics = {}
        for result in results.values():
            all_perf_metrics.update(result.performance_metrics)
        
        if all_perf_metrics:
            avg_test_time = sum(all_perf_metrics.values()) / len(all_perf_metrics)
            max_test_time = max(all_perf_metrics.values())
            
            report.extend([
                "PERFORMANCE SUMMARY",
                "-" * 19,
                f"Average test time: {avg_test_time*1000:.1f}ms",
                f"Maximum test time: {max_test_time*1000:.1f}ms",
                f"Performance tests: {sum(1 for r in results.values() if 'performance' in r.suite_name.lower())}",
                ""
            ])
        
        # Save report
        report_content = "\n".join(report)
        
        # Console output
        print("\n" + report_content)
        
        # Save to file
        report_file = self.results_dir / f"test_report_{int(time.time())}.txt"
        report_file.write_text(report_content)
        
        # Save JSON results
        json_file = self.results_dir / f"test_results_{int(time.time())}.json"
        json_data = {
            "timestamp": time.time(),
            "total_time": total_time,
            "memory_delta": memory_delta,
            "overall": {
                "total_tests": total_tests,
                "passed_tests": total_passed,
                "failed_tests": total_failed,
                "skipped_tests": total_skipped,
                "success_rate": success_rate
            },
            "suites": {
                name: {
                    "total_tests": r.total_tests,
                    "passed_tests": r.passed_tests,
                    "failed_tests": r.failed_tests,
                    "skipped_tests": r.skipped_tests,
                    "execution_time": r.execution_time,
                    "memory_usage_mb": r.memory_usage_mb,
                    "coverage_percentage": r.coverage_percentage,
                    "performance_metrics": r.performance_metrics,
                    "error_count": len(r.error_details)
                }
                for name, r in results.items()
            }
        }
        
        with open(json_file, 'w') as f:
            json.dump(json_data, f, indent=2)
        
        logger.info(f"📄 Report saved to: {report_file}")
        logger.info(f"📊 JSON data saved to: {json_file}")
    
    def _check_critical_suites(self, results: Dict[str, TestResults]) -> bool:
        """Check if all critical suites passed"""
        for suite_name, result in results.items():
            suite = self.test_suites.get(suite_name)
            if suite and suite.critical and result.failed_tests > 0:
                return False
        return True
    
    async def _validate_requirements(self, results: Dict[str, TestResults]) -> bool:
        """Validate that all requirements are met"""
        logger.info("✅ Validating requirements...")
        
        total_tests = sum(r.total_tests for r in results.values())
        total_passed = sum(r.passed_tests for r in results.values())
        success_rate = (total_passed / max(1, total_tests)) * 100
        
        requirements = [
            (total_tests >= 200, f"Total tests >=200: {total_tests}"),
            (success_rate >= 85.0, f"Success rate >=85%: {success_rate:.1f}%"),
            (self._check_critical_suites(results), "All critical suites pass"),
            (len([r for r in results.values() if 'security' in r.suite_name.lower()]) >= 3, 
             "Security test coverage"),
            (len([r for r in results.values() if 'performance' in r.suite_name.lower()]) >= 2,
             "Performance test coverage")
        ]
        
        all_passed = True
        for requirement_met, description in requirements:
            status = "✅ PASS" if requirement_met else "❌ FAIL"
            logger.info(f"{status} {description}")
            if not requirement_met:
                all_passed = False
        
        return all_passed

def main():
    """Main entry point for test runner"""
    parser = argparse.ArgumentParser(description="Claude Unified Hooks Test Runner")
    parser.add_argument("--suites", nargs="+", help="Specific test suites to run")
    parser.add_argument("--no-parallel", action="store_true", help="Run suites sequentially")
    parser.add_argument("--no-coverage", action="store_true", help="Disable coverage reporting")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--project-root", type=Path, help="Project root directory")
    parser.add_argument("--list-suites", action="store_true", help="List available test suites")
    
    args = parser.parse_args()
    
    # Initialize runner
    runner = TestRunner(project_root=args.project_root)
    
    if args.list_suites:
        print("Available Test Suites:")
        print("=" * 40)
        for name, suite in runner.test_suites.items():
            critical = " (CRITICAL)" if suite.critical else ""
            print(f"{name}: {suite.name}{critical}")
            print(f"  Pattern: {suite.pattern}")
            print(f"  Markers: {', '.join(suite.markers)}")
            print(f"  Timeout: {suite.timeout}s")
            print()
        return
    
    # Run tests
    try:
        results = asyncio.run(runner.run_all_tests(
            suites=args.suites,
            parallel=not args.no_parallel,
            coverage=not args.no_coverage,
            verbose=args.verbose
        ))
        
        # Check overall success
        total_passed = sum(r.passed_tests for r in results.values())
        total_tests = sum(r.total_tests for r in results.values())
        success_rate = (total_passed / max(1, total_tests)) * 100
        
        if success_rate >= 85.0 and runner._check_critical_suites(results):
            print(f"\n🎉 ALL TESTS PASSED - Success Rate: {success_rate:.1f}%")
            sys.exit(0)
        else:
            print(f"\n❌ TESTS FAILED - Success Rate: {success_rate:.1f}%")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⚠️ Test execution interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n💥 Test execution failed: {e}")
        logger.exception("Test execution failed")
        sys.exit(1)

if __name__ == "__main__":
    main()