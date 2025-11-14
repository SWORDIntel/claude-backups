#!/usr/bin/env python3
"""
Security Hardening Implementation for Claude Unified Hook System
Implements all critical security fixes identified by DEBUGGER agent
"""

import asyncio
import re
import time
from functools import lru_cache
from typing import Any, Dict, Optional


class SecurityValidator:
    """Input validation and sanitization"""

    # Maximum input size to prevent DoS
    MAX_INPUT_SIZE = 10000

    # Dangerous patterns that indicate potential attacks
    DANGEROUS_PATTERNS = [
        (r"\.\./", "Path traversal attempt"),
        (r"\.\.[/\\]", "Path traversal attempt"),
        (r"[;&|].*(?:rm|del|format|drop|delete|truncate)", "Command injection attempt"),
        (r"\$\(.*\)", "Command substitution attempt"),
        (r"`.*`", "Command substitution attempt"),
        (r"<script", "XSS attempt"),
        (r"javascript:", "XSS attempt"),
        (r"on\w+\s*=", "XSS event handler"),
        (r"'\s*;\s*DROP", "SQL injection attempt"),
        (r"'\s*OR\s+'1'\s*=\s*'1", "SQL injection attempt"),
        (r"UNION\s+SELECT", "SQL injection attempt"),
        (r"INSERT\s+INTO", "SQL injection attempt"),
        (r"UPDATE\s+SET", "SQL injection attempt"),
        (r"DELETE\s+FROM", "SQL injection attempt"),
        (r"<\?php", "PHP injection attempt"),
        (r"eval\s*\(", "Code injection attempt"),
        (r"exec\s*\(", "Code injection attempt"),
        (r"system\s*\(", "System call attempt"),
        (r"file://", "File protocol attempt"),
        (r"gopher://", "Gopher protocol attempt"),
        (r"\x00", "Null byte injection"),
    ]

    @classmethod
    def validate_input(cls, input_text: str) -> tuple[bool, str, Optional[str]]:
        """
        Validate and sanitize input
        Returns: (is_valid, sanitized_text, error_message)
        """

        # Check if input is empty
        if not input_text or not input_text.strip():
            return False, "", "Input cannot be empty"

        # Check input size
        if len(input_text) > cls.MAX_INPUT_SIZE:
            return (
                False,
                "",
                f"Input exceeds maximum size of {cls.MAX_INPUT_SIZE} characters",
            )

        # Check for dangerous patterns
        input_lower = input_text.lower()
        for pattern, description in cls.DANGEROUS_PATTERNS:
            if re.search(pattern, input_lower, re.IGNORECASE):
                return False, "", f"Security violation: {description}"

        # Sanitize input
        sanitized = cls.sanitize_input(input_text)

        return True, sanitized, None

    @classmethod
    def sanitize_input(cls, input_text: str) -> str:
        """Sanitize input by removing/escaping dangerous characters"""

        # Remove null bytes
        sanitized = input_text.replace("\x00", "")

        # Remove control characters except newline
        sanitized = "".join(
            char for char in sanitized if ord(char) >= 32 or char == "\n"
        )

        # Escape HTML/XML special characters
        html_escapes = {
            "<": "&lt;",
            ">": "&gt;",
            "&": "&amp;",
            '"': "&quot;",
            "'": "&#x27;",
        }

        for char, escape in html_escapes.items():
            sanitized = sanitized.replace(char, escape)

        # Limit consecutive whitespace
        sanitized = re.sub(r"\s+", " ", sanitized)

        # Trim to reasonable length
        if len(sanitized) > cls.MAX_INPUT_SIZE:
            sanitized = sanitized[: cls.MAX_INPUT_SIZE]

        return sanitized.strip()


class ResourceLimiter:
    """Rate limiting and resource management"""

    def __init__(
        self,
        max_concurrent: int = 100,
        max_requests_per_second: int = 1000,
        max_memory_mb: int = 500,
    ):

        self.max_concurrent = max_concurrent
        self.max_rps = max_requests_per_second
        self.max_memory_mb = max_memory_mb

        # Semaphore for concurrent requests
        self.semaphore = asyncio.Semaphore(max_concurrent)

        # Rate limiting
        self.request_times = []
        self.window_size = 1.0  # 1 second window

        # Memory tracking
        self.memory_usage = 0

    async def acquire(self) -> bool:
        """Acquire permission to process request"""

        # Check memory limit
        import psutil

        process = psutil.Process()
        memory_mb = process.memory_info().rss / 1024 / 1024

        if memory_mb > self.max_memory_mb:
            raise MemoryError(
                f"Memory limit exceeded: {memory_mb:.1f}MB > {self.max_memory_mb}MB"
            )

        # Rate limiting
        current_time = time.time()

        # Remove old request times outside window
        self.request_times = [
            t for t in self.request_times if current_time - t < self.window_size
        ]

        # Check rate limit
        if len(self.request_times) >= self.max_rps:
            # Calculate wait time
            oldest_request = min(self.request_times)
            wait_time = self.window_size - (current_time - oldest_request)

            if wait_time > 0:
                await asyncio.sleep(wait_time)

        # Record this request
        self.request_times.append(current_time)

        # Acquire semaphore for concurrent limit
        await self.semaphore.acquire()

        return True

    def release(self):
        """Release resources after request completion"""
        self.semaphore.release()

    async def __aenter__(self):
        await self.acquire()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        self.release()


class SecureHookSystem:
    """Wrapper for hook system with security enhancements"""

    def __init__(self, hook_system):
        self.hooks = hook_system
        self.validator = SecurityValidator()
        self.limiter = ResourceLimiter()

        # Pattern cache for performance
        self._pattern_cache = {}

        # Security metrics
        self.blocked_requests = 0
        self.total_requests = 0

    @lru_cache(maxsize=1024)
    def _compile_pattern(self, pattern: str) -> re.Pattern:
        """Cache compiled regex patterns"""
        return re.compile(pattern, re.IGNORECASE)

    async def secure_process(self, input_text: str) -> Dict[str, Any]:
        """Process input with security validation and resource limits"""

        self.total_requests += 1

        # Validate input
        is_valid, sanitized, error = SecurityValidator.validate_input(input_text)

        if not is_valid:
            self.blocked_requests += 1
            return {
                "error": error,
                "status": "blocked",
                "reason": "security_validation_failed",
            }

        # Apply resource limits
        try:
            async with self.limiter:
                # Process with original hook system
                result = await self.hooks.process(sanitized)

                # Sanitize output
                result = self._sanitize_output(result)

                return result

        except MemoryError as e:
            return {
                "error": "Resource limit exceeded",
                "status": "rejected",
                "reason": str(e),
            }
        except asyncio.TimeoutError:
            return {
                "error": "Request timeout",
                "status": "timeout",
                "reason": "Processing took too long",
            }
        except Exception as e:
            # Sanitize error messages
            error_msg = self._sanitize_error(str(e))
            return {"error": error_msg, "status": "error", "reason": "internal_error"}

    def _sanitize_output(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """Sanitize output to prevent information disclosure"""

        # Remove sensitive paths
        if isinstance(result, dict):
            for key, value in result.items():
                if isinstance(value, str):
                    # Remove file paths
                    value = re.sub(r"/home/\w+/", "/home/***/", value)
                    value = re.sub(r"C:\\Users\\\w+\\", "C:\\Users\\***\\", value)
                    value = re.sub(r"/usr/\w+/", "/usr/***/", value)

                    # Remove stack traces
                    value = re.sub(
                        r'File ".*?", line \d+', 'File "<hidden>", line ***', value
                    )

                    result[key] = value

        return result

    def _sanitize_error(self, error_msg: str) -> str:
        """Sanitize error messages to prevent information disclosure"""

        # Remove file paths
        error_msg = re.sub(r"[/\\][\w/\\]+\.py", "<file>", error_msg)
        error_msg = re.sub(r"line \d+", "line <n>", error_msg)

        # Remove user directories
        error_msg = re.sub(r"/home/\w+", "<home>", error_msg)
        error_msg = re.sub(r"C:\\Users\\\w+", "<user>", error_msg)

        # Remove system paths
        error_msg = re.sub(r"/usr/[\w/]+", "<system>", error_msg)
        error_msg = re.sub(r"/etc/[\w/]+", "<config>", error_msg)

        return error_msg

    def get_security_stats(self) -> Dict[str, Any]:
        """Get security statistics"""

        block_rate = 0
        if self.total_requests > 0:
            block_rate = (self.blocked_requests / self.total_requests) * 100

        return {
            "total_requests": self.total_requests,
            "blocked_requests": self.blocked_requests,
            "block_rate": f"{block_rate:.2f}%",
            "concurrent_limit": self.limiter.max_concurrent,
            "rate_limit": f"{self.limiter.max_rps} req/s",
        }


# Monkey-patch for existing hook system
def apply_security_hardening(hook_system_module):
    """Apply security hardening to existing hook system"""

    # Get the ClaudeUnifiedHooks class
    ClaudeUnifiedHooks = hook_system_module.ClaudeUnifiedHooks

    # Save original process method
    original_process = ClaudeUnifiedHooks.process

    # Create security wrapper
    async def secure_process_wrapper(self, input_text: str) -> Dict[str, Any]:
        """Security-hardened process method"""

        # Create secure wrapper if not exists
        if not hasattr(self, "_secure_wrapper"):
            self._secure_wrapper = SecureHookSystem(self)

        # Use secure processing
        return await self._secure_wrapper.secure_process(input_text)

    # Replace process method
    ClaudeUnifiedHooks.process = secure_process_wrapper

    # Add security stats method
    def get_security_stats(self) -> Dict[str, Any]:
        if hasattr(self, "_secure_wrapper"):
            return self._secure_wrapper.get_security_stats()
        return {"status": "security not initialized"}

    ClaudeUnifiedHooks.get_security_stats = get_security_stats

    print("✅ Security hardening applied successfully")
    return True


# Test the security implementation
async def test_security():
    """Test security features"""

    print("=" * 70)
    print("SECURITY HARDENING TEST")
    print("=" * 70)

    # Import hook system
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).parent))

    import claude_unified_hook_system_v2

    # Apply security hardening
    apply_security_hardening(claude_unified_hook_system_v2)

    # Create instance
    hooks = claude_unified_hook_system_v2.ClaudeUnifiedHooks()

    # Test cases
    test_cases = [
        ("optimize performance", True, "Normal input"),
        ("", False, "Empty input"),
        ("../../etc/passwd", False, "Path traversal"),
        ("; rm -rf /", False, "Command injection"),
        ("' OR '1'='1", False, "SQL injection"),
        ("<script>alert('xss')</script>", False, "XSS attempt"),
        ("$(whoami)", False, "Command substitution"),
        ("a" * 20000, False, "Oversized input"),
        ("test\x00test", False, "Null byte injection"),
        ("normal task with special chars: @#$%", True, "Special chars (safe)"),
    ]

    print("\n1. INPUT VALIDATION TESTS")
    print("-" * 40)

    for input_text, should_pass, description in test_cases:
        result = await hooks.process(
            input_text[:50] if len(input_text) > 50 else input_text
        )

        if should_pass:
            if "error" not in result or result.get("status") != "blocked":
                print(f"✅ {description}: PASSED")
            else:
                print(f"❌ {description}: FAILED (should have passed)")
        else:
            if result.get("status") == "blocked":
                print(f"✅ {description}: BLOCKED correctly")
            else:
                print(f"❌ {description}: NOT BLOCKED (security failure!)")

    # Test rate limiting
    print("\n2. RATE LIMITING TEST")
    print("-" * 40)

    print("Testing concurrent requests...")
    start = time.time()

    # Try to exceed rate limit
    tasks = []
    for i in range(150):  # More than limit
        tasks.append(hooks.process(f"test {i}"))

    results = await asyncio.gather(*tasks, return_exceptions=True)

    elapsed = time.time() - start

    errors = [r for r in results if isinstance(r, Exception)]
    blocked = [
        r for r in results if isinstance(r, dict) and r.get("status") == "rejected"
    ]

    print(f"✅ Processed 150 requests in {elapsed:.2f}s")
    print(f"✅ Errors: {len(errors)}, Blocked: {len(blocked)}")

    # Get security stats
    stats = hooks.get_security_stats()

    print("\n3. SECURITY STATISTICS")
    print("-" * 40)
    for key, value in stats.items():
        print(f"  {key}: {value}")

    print("\n✅ Security hardening test complete!")


if __name__ == "__main__":
    asyncio.run(test_security())
