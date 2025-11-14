#!/usr/bin/env python3
"""
DEBUGGER Agent Analysis - Bug Detection and Error Handling
Identifies bugs, edge cases, and security vulnerabilities
"""

import asyncio
import gc
import random
import resource
import string
import sys
import threading
import time
import traceback
from pathlib import Path
from typing import Any, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).parent))
from claude_unified_hook_system_v2 import ClaudeUnifiedHooks


class DebuggerAnalysis:
    """DEBUGGER agent analyzing hook system for bugs and vulnerabilities"""

    def __init__(self):
        self.bugs_found = []
        self.security_issues = []
        self.edge_cases = []
        self.fixes = []

    async def analyze_system(self) -> Dict[str, Any]:
        """Comprehensive debugging analysis"""
        print("=" * 70)
        print("DEBUGGER AGENT - BUG & VULNERABILITY ANALYSIS")
        print("=" * 70)

        # Test for various issues
        await self.test_edge_cases()
        await self.test_error_handling()
        await self.test_security()
        await self.test_resource_management()
        await self.test_race_conditions()

        # Generate fixes
        self.generate_fixes()

        return {
            "bugs": self.bugs_found,
            "security_issues": self.security_issues,
            "edge_cases": self.edge_cases,
            "fixes": self.fixes,
        }

    async def test_edge_cases(self):
        """Test edge cases and boundary conditions"""
        print("\n1. TESTING EDGE CASES")
        print("-" * 40)

        hooks = ClaudeUnifiedHooks()
        edge_cases = []

        # Test 1: Empty input
        try:
            result = await hooks.process("")
            if "error" not in result:
                edge_cases.append(
                    {
                        "case": "Empty input not rejected",
                        "severity": "MEDIUM",
                        "issue": "Should return error for empty input",
                    }
                )
        except:
            pass

        # Test 2: Extremely long input
        long_input = "a" * 1000000
        try:
            result = await hooks.process(long_input)
            edge_cases.append(
                {
                    "case": "No input size limit",
                    "severity": "HIGH",
                    "issue": "Can cause memory exhaustion",
                }
            )
        except:
            pass

        # Test 3: Special characters
        special_inputs = [
            "'; DROP TABLE agents; --",
            "../../../etc/passwd",
            "$(rm -rf /)",
            "\x00\x01\x02",
            "\\x00\\x01\\x02",
        ]

        for special in special_inputs:
            try:
                result = await hooks.process(special)
                if not result.get("sanitized"):
                    edge_cases.append(
                        {
                            "case": f"Special chars not sanitized: {special[:20]}",
                            "severity": "CRITICAL",
                            "issue": "Potential injection vulnerability",
                        }
                    )
            except:
                pass

        # Test 4: Unicode edge cases
        unicode_inputs = [
            "🔥" * 1000,
            "\u202e\u202d\u202c",  # Right-to-left override
            "\ufeff" * 100,  # Zero-width no-break space
        ]

        for unicode_input in unicode_inputs:
            try:
                result = await hooks.process(unicode_input)
            except Exception as e:
                edge_cases.append(
                    {
                        "case": f"Unicode handling error",
                        "severity": "LOW",
                        "issue": f"Failed on: {unicode_input[:20]}",
                    }
                )

        # Test 5: Null bytes
        try:
            result = await hooks.process("test\x00test")
            if "\x00" in str(result):
                edge_cases.append(
                    {
                        "case": "Null bytes not filtered",
                        "severity": "MEDIUM",
                        "issue": "Can cause string termination issues",
                    }
                )
        except:
            pass

        for case in edge_cases:
            print(f"⚠️ {case['case']}")
            print(f"   Severity: {case['severity']}")
            print(f"   Issue: {case['issue']}")

        if not edge_cases:
            print("✅ No edge case issues found")

        self.edge_cases = edge_cases

    async def test_error_handling(self):
        """Test error handling robustness"""
        print("\n2. TESTING ERROR HANDLING")
        print("-" * 40)

        bugs = []

        # Test 1: File system errors
        try:
            # Temporarily break agent loading
            import os

            old_dir = os.getcwd()
            os.chdir("/nonexistent")
            hooks = ClaudeUnifiedHooks()
            os.chdir(old_dir)

            bugs.append(
                {
                    "bug": "No error handling for missing directory",
                    "severity": "MEDIUM",
                    "location": "__init__ method",
                }
            )
        except:
            pass

        # Test 2: Concurrent access
        hooks = ClaudeUnifiedHooks()

        async def stress_test():
            tasks = []
            for i in range(1000):
                tasks.append(hooks.process(f"test {i}"))

            try:
                results = await asyncio.gather(*tasks, return_exceptions=True)
                exceptions = [r for r in results if isinstance(r, Exception)]
                if exceptions:
                    bugs.append(
                        {
                            "bug": f"Concurrent access errors: {len(exceptions)}",
                            "severity": "HIGH",
                            "location": "Worker pool management",
                        }
                    )
            except:
                bugs.append(
                    {
                        "bug": "System crashes under load",
                        "severity": "CRITICAL",
                        "location": "process() method",
                    }
                )

        await stress_test()

        # Test 3: Memory pressure
        try:
            # Create many instances
            instances = []
            for i in range(100):
                instances.append(ClaudeUnifiedHooks())

            # Check memory usage
            import psutil

            process = psutil.Process()
            memory_mb = process.memory_info().rss / 1024 / 1024

            if memory_mb > 500:  # More than 500MB for 100 instances
                bugs.append(
                    {
                        "bug": "Excessive memory usage",
                        "severity": "MEDIUM",
                        "location": "Instance initialization",
                        "details": f"{memory_mb:.1f}MB for 100 instances",
                    }
                )
        except:
            pass

        # Test 4: Timeout handling
        async def slow_process():
            hooks = ClaudeUnifiedHooks()
            # Simulate slow pattern matching
            input_text = "test " * 10000

            try:
                result = await asyncio.wait_for(
                    hooks.process(input_text), timeout=0.001  # 1ms timeout
                )
                bugs.append(
                    {
                        "bug": "No timeout protection",
                        "severity": "MEDIUM",
                        "location": "process() method",
                    }
                )
            except asyncio.TimeoutError:
                pass  # Good - timeout worked

        await slow_process()

        for bug in bugs:
            print(f"🐛 {bug['bug']}")
            print(f"   Severity: {bug['severity']}")
            print(f"   Location: {bug['location']}")

        if not bugs:
            print("✅ No error handling issues found")

        self.bugs_found = bugs

    async def test_security(self):
        """Test for security vulnerabilities"""
        print("\n3. TESTING SECURITY")
        print("-" * 40)

        security_issues = []
        hooks = ClaudeUnifiedHooks()

        # Test 1: Path traversal
        path_traversal_inputs = [
            "../../../../etc/passwd",
            "..\\..\\..\\windows\\system32",
            "file:///etc/passwd",
        ]

        for path_input in path_traversal_inputs:
            result = await hooks.process(path_input)
            if "../" in str(result) or "..\\" in str(result):
                security_issues.append(
                    {
                        "issue": "Path traversal not sanitized",
                        "severity": "CRITICAL",
                        "input": path_input,
                    }
                )

        # Test 2: Command injection
        command_inputs = ["; ls -la", "| cat /etc/passwd", "$(whoami)", "`id`"]

        for cmd_input in command_inputs:
            result = await hooks.process(cmd_input)
            # Check if commands are escaped
            if any(char in str(result) for char in ["|", ";", "$", "`"]):
                security_issues.append(
                    {
                        "issue": "Command injection characters not escaped",
                        "severity": "CRITICAL",
                        "input": cmd_input,
                    }
                )

        # Test 3: Resource exhaustion
        try:
            # Attempt to exhaust resources
            massive_tasks = []
            for i in range(10000):
                massive_tasks.append(hooks.process(f"test{i}"))

            # Should have resource limits
            await asyncio.gather(*massive_tasks)

            security_issues.append(
                {
                    "issue": "No resource limits",
                    "severity": "HIGH",
                    "details": "Can be DoS attacked",
                }
            )
        except:
            pass  # Good - resource limits in place

        # Test 4: Information disclosure
        error_input = "\x00\x01\x02\x03"
        try:
            result = await hooks.process(error_input)
        except Exception as e:
            error_msg = str(e)
            if "/home/" in error_msg or "C:\\" in error_msg:
                security_issues.append(
                    {
                        "issue": "Path disclosure in errors",
                        "severity": "MEDIUM",
                        "details": "Exposes system paths",
                    }
                )

        for issue in security_issues:
            print(f"🔒 {issue['issue']}")
            print(f"   Severity: {issue['severity']}")
            if "details" in issue:
                print(f"   Details: {issue['details']}")

        if not security_issues:
            print("✅ No security issues found")

        self.security_issues = security_issues

    async def test_resource_management(self):
        """Test resource management and cleanup"""
        print("\n4. TESTING RESOURCE MANAGEMENT")
        print("-" * 40)

        issues = []

        # Test 1: File handle leaks
        initial_fds = (
            len(os.listdir("/proc/self/fd")) if Path("/proc/self/fd").exists() else 0
        )

        for i in range(100):
            hooks = ClaudeUnifiedHooks()
            await hooks.process("test")
            del hooks

        gc.collect()

        if Path("/proc/self/fd").exists():
            final_fds = len(os.listdir("/proc/self/fd"))
            if final_fds > initial_fds + 10:
                issues.append(
                    {
                        "issue": "File descriptor leak",
                        "severity": "HIGH",
                        "details": f"{final_fds - initial_fds} FDs leaked",
                    }
                )

        # Test 2: Memory leaks
        import tracemalloc

        tracemalloc.start()

        snapshot1 = tracemalloc.take_snapshot()

        for i in range(100):
            hooks = ClaudeUnifiedHooks()
            await hooks.process("memory test")

        snapshot2 = tracemalloc.take_snapshot()
        top_stats = snapshot2.compare_to(snapshot1, "lineno")

        for stat in top_stats[:3]:
            if stat.size_diff > 1024 * 1024:  # More than 1MB
                issues.append(
                    {
                        "issue": "Memory leak detected",
                        "severity": "MEDIUM",
                        "location": str(stat),
                        "size": f"{stat.size_diff / 1024 / 1024:.1f}MB",
                    }
                )

        tracemalloc.stop()

        # Test 3: Thread leaks
        initial_threads = threading.active_count()

        for i in range(10):
            hooks = ClaudeUnifiedHooks()
            tasks = [hooks.process(f"thread test {j}") for j in range(10)]
            await asyncio.gather(*tasks)

        final_threads = threading.active_count()

        if final_threads > initial_threads + 5:
            issues.append(
                {
                    "issue": "Thread leak",
                    "severity": "HIGH",
                    "details": f"{final_threads - initial_threads} threads leaked",
                }
            )

        for issue in issues:
            print(f"⚠️ {issue['issue']}")
            print(f"   Severity: {issue['severity']}")
            if "details" in issue:
                print(f"   Details: {issue['details']}")

        if not issues:
            print("✅ No resource management issues found")

        self.bugs_found.extend(issues)

    async def test_race_conditions(self):
        """Test for race conditions and concurrency issues"""
        print("\n5. TESTING RACE CONDITIONS")
        print("-" * 40)

        race_conditions = []
        hooks = ClaudeUnifiedHooks()

        # Test 1: Concurrent cache access
        shared_counter = {"count": 0}

        async def increment_counter():
            for _ in range(100):
                shared_counter["count"] += 1
                await hooks.process("cache test")

        tasks = [increment_counter() for _ in range(10)]
        await asyncio.gather(*tasks)

        expected = 1000
        actual = shared_counter["count"]

        if actual != expected:
            race_conditions.append(
                {
                    "issue": "Race condition in shared state",
                    "severity": "HIGH",
                    "details": f"Expected {expected}, got {actual}",
                }
            )

        # Test 2: Worker pool race
        results = []

        async def worker_test(id):
            result = await hooks.process(f"worker {id}")
            results.append(result)

        tasks = [worker_test(i) for i in range(100)]
        await asyncio.gather(*tasks)

        # Check for duplicate or missing results
        if len(results) != len(set(id(r) for r in results)):
            race_conditions.append(
                {
                    "issue": "Worker pool race condition",
                    "severity": "MEDIUM",
                    "details": "Duplicate result objects",
                }
            )

        for condition in race_conditions:
            print(f"🏁 {condition['issue']}")
            print(f"   Severity: {condition['severity']}")
            print(f"   Details: {condition['details']}")

        if not race_conditions:
            print("✅ No race conditions found")

        self.bugs_found.extend(race_conditions)

    def generate_fixes(self):
        """Generate fixes for identified issues"""
        print("\n6. RECOMMENDED FIXES")
        print("-" * 40)

        fixes = []

        # Fix 1: Input validation
        fixes.append(
            {
                "name": "Enhanced Input Validation",
                "fixes": ["Empty input", "Size limits", "Special characters"],
                "code": '''
def validate_input(self, input_text: str) -> str:
    """Validate and sanitize input"""
    if not input_text or not input_text.strip():
        raise ValueError("Input cannot be empty")
    
    # Size limit
    MAX_INPUT_SIZE = 10000
    if len(input_text) > MAX_INPUT_SIZE:
        raise ValueError(f"Input exceeds {MAX_INPUT_SIZE} characters")
    
    # Remove null bytes and control characters
    input_text = input_text.replace('\\x00', '')
    input_text = ''.join(char for char in input_text if ord(char) >= 32 or char == '\\n')
    
    # Escape potentially dangerous characters
    dangerous_chars = ['$', '`', ';', '|', '&', '>', '<', '(', ')']
    for char in dangerous_chars:
        input_text = input_text.replace(char, f'\\{char}')
    
    return input_text.strip()
''',
            }
        )

        # Fix 2: Resource limits
        fixes.append(
            {
                "name": "Resource Limitation",
                "fixes": [
                    "Memory limits",
                    "Concurrent request limits",
                    "Timeout protection",
                ],
                "code": """
class ResourceLimiter:
    def __init__(self):
        self.semaphore = asyncio.Semaphore(100)  # Max 100 concurrent
        self.request_count = 0
        self.MAX_REQUESTS_PER_SECOND = 1000
        
    async def acquire(self):
        async with self.semaphore:
            # Rate limiting
            if self.request_count > self.MAX_REQUESTS_PER_SECOND:
                await asyncio.sleep(0.001)
            self.request_count += 1
            
    async def __aenter__(self):
        await self.acquire()
        return self
        
    async def __aexit__(self, *args):
        self.request_count -= 1
""",
            }
        )

        # Fix 3: Error message sanitization
        fixes.append(
            {
                "name": "Error Message Sanitization",
                "fixes": ["Path disclosure", "Stack trace leaks"],
                "code": '''
def sanitize_error(self, error: Exception) -> str:
    """Sanitize error messages"""
    error_msg = str(error)
    
    # Remove file paths
    import re
    error_msg = re.sub(r'[/\\\\][\w/\\\\]+\\.py', '<file>', error_msg)
    error_msg = re.sub(r'line \\d+', 'line <n>', error_msg)
    
    # Remove sensitive information
    error_msg = re.sub(r'/home/\\w+', '<home>', error_msg)
    error_msg = re.sub(r'C:\\\\Users\\\\\\w+', '<user>', error_msg)
    
    return error_msg
''',
            }
        )

        # Fix 4: Proper cleanup
        fixes.append(
            {
                "name": "Resource Cleanup",
                "fixes": ["Memory leaks", "File handle leaks", "Thread cleanup"],
                "code": '''
async def cleanup(self):
    """Proper resource cleanup"""
    try:
        # Cancel all worker tasks
        for worker in self.workers:
            worker.cancel()
        
        # Wait for cancellation
        await asyncio.gather(*self.workers, return_exceptions=True)
        
        # Clear caches
        self.cache.clear()
        self._pattern_cache.clear()
        
        # Close file handles
        if hasattr(self, '_log_file'):
            self._log_file.close()
        
        # Garbage collection
        import gc
        gc.collect()
        
    except Exception as e:
        self.logger.error(f"Cleanup error: {e}")
''',
            }
        )

        for fix in fixes:
            print(f"\n📝 {fix['name']}")
            print(f"   Fixes: {', '.join(fix['fixes'])}")

        self.fixes = fixes

        return fixes


import os


async def main():
    """Run DEBUGGER analysis"""
    debugger = DebuggerAnalysis()

    # Perform analysis
    results = await debugger.analyze_system()

    # Summary
    print("\n" + "=" * 70)
    print("ANALYSIS SUMMARY")
    print("=" * 70)

    total_issues = (
        len(results["bugs"])
        + len(results["security_issues"])
        + len(results["edge_cases"])
    )

    print(f"\nTotal Issues Found: {total_issues}")
    print(f"  - Bugs: {len(results['bugs'])}")
    print(f"  - Security Issues: {len(results['security_issues'])}")
    print(f"  - Edge Cases: {len(results['edge_cases'])}")
    print(f"  - Fixes Recommended: {len(results['fixes'])}")

    # Priority fixes
    print("\nPRIORITY FIXES:")
    print("1. Add input validation and sanitization")
    print("2. Implement resource limits")
    print("3. Fix error message disclosure")
    print("4. Add proper cleanup methods")

    print("\n✅ Debugger analysis complete!")

    return results


if __name__ == "__main__":
    asyncio.run(main())
