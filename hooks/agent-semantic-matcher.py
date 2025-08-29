#!/usr/bin/env python3
"""
Compatibility wrapper - redirects to unified hook system
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from claude_unified_hook_system import *

print(f"Note: {__file__} is deprecated. Using unified hook system.")

# Maintain backward compatibility
if __name__ == "__main__":
    import asyncio
    
    config = UnifiedConfig()
    hooks = ClaudeUnifiedHooks(config)
    
    if len(sys.argv) > 1:
        input_text = " ".join(sys.argv[1:])
        result = asyncio.run(hooks.process(input_text))
        print(result)
    else:
        status = hooks.get_status()
        print(f"Unified Hook System Status: {status}")
