# SECURITY HARDENING PATCH - Applied by DEBUGGER recommendations

import re
from functools import lru_cache

# Maximum input size to prevent DoS
MAX_INPUT_SIZE = 10000

def validate_and_sanitize_input(input_text):
    """Security-hardened input validation"""
    
    # Check empty
    if not input_text or not input_text.strip():
        raise ValueError("Input cannot be empty")
    
    # Size limit
    if len(input_text) > MAX_INPUT_SIZE:
        raise ValueError(f"Input exceeds {MAX_INPUT_SIZE} characters")
    
    # Dangerous patterns
    dangerous_patterns = [
        r'\.\./',           # Path traversal
        r'\$\(',            # Command substitution
        r';\s*DROP',        # SQL injection
        r'<script',         # XSS
        r'\x00',            # Null bytes
        r'`.*`',            # Command substitution
        r';\s*rm\s',        # Command deletion
        r'file://',         # File protocol
    ]
    
    for pattern in dangerous_patterns:
        if re.search(pattern, input_text, re.IGNORECASE):
            raise ValueError(f"Potentially malicious input detected")
    
    # Sanitize
    input_text = input_text.replace('\x00', '')
    input_text = ''.join(c for c in input_text if ord(c) >= 32 or c == '\n')
    
    return input_text.strip()

@lru_cache(maxsize=1024)
def compile_pattern_cached(pattern):
    """Cache compiled regex patterns for performance"""
    return re.compile(pattern, re.IGNORECASE)

# Import limiter
import asyncio

class RateLimiter:
    """Simple rate limiter"""
    def __init__(self, max_requests=1000):
        self.semaphore = asyncio.Semaphore(100)  # Max 100 concurrent
        self.max_requests = max_requests
        
    async def acquire(self):
        await self.semaphore.acquire()
        
    def release(self):
        self.semaphore.release()

# Global limiter instance
rate_limiter = RateLimiter()
