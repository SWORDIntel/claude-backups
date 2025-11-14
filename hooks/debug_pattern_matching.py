#!/usr/bin/env python3
"""Debug script to identify pattern matching issue"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from claude_unified_hook_system_v2 import ClaudeUnifiedHooks


async def debug_pattern_matching():
    """Debug why patterns aren't matching"""

    print("=== PATTERN MATCHING DEBUG ===\n")

    # Initialize hooks
    hooks = ClaudeUnifiedHooks()

    # Check if patterns are compiled
    print(f"1. Number of agents loaded: {len(hooks.engine.registry.agents)}")
    print(f"2. Agent triggers defined: {len(hooks.engine.matcher.agent_triggers)}")
    print(f"3. Compiled patterns: {len(hooks.engine.matcher._compiled_patterns)}")

    # Show first few patterns
    print("\n4. Sample agent triggers:")
    for agent, triggers in list(hooks.engine.matcher.agent_triggers.items())[:3]:
        print(f"   {agent}: {triggers}")

    print("\n5. Sample compiled patterns:")
    for agent, patterns in list(hooks.engine.matcher._compiled_patterns.items())[:3]:
        print(f"   {agent}: {len(patterns)} patterns compiled")
        if patterns:
            print(f"      First pattern: {patterns[0].pattern}")

    # Test matching
    print("\n6. Testing pattern matching:")
    test_inputs = [
        "Fix the security vulnerability",
        "Optimize performance",
        "Deploy to production",
        "Debug the error",
    ]

    for test_input in test_inputs:
        result = await hooks.process(test_input)
        print(f"\n   Input: '{test_input}'")
        print(f"   Categories: {result.get('categories', [])}")
        print(f"   Agents matched: {result.get('agents', [])[:3]}")
        print(f"   Confidence: {result.get('confidence', 0):.2%}")

        # Test direct pattern matching
        input_lower = test_input.lower()
        direct_matches = []
        for agent, patterns in hooks.engine.matcher._compiled_patterns.items():
            for pattern in patterns:
                if pattern.search(input_lower):
                    direct_matches.append(agent)
                    break
        print(f"   Direct pattern matches: {direct_matches}")

    # Check trie structure
    print("\n7. Keyword trie structure:")
    print(f"   Trie root keys: {list(hooks.engine.matcher._keyword_trie.keys())[:10]}")

    # Test trie search
    print("\n8. Testing trie search:")
    for test_input in test_inputs:
        categories = hooks.engine.matcher._search_trie(test_input)
        print(f"   '{test_input}' -> Categories: {categories}")


if __name__ == "__main__":
    asyncio.run(debug_pattern_matching())
