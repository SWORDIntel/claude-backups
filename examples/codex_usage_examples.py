#!/usr/bin/env python3
"""
OpenAI Codex Integration Examples
For Claude Agent Framework v7.0

This script demonstrates various ways to use the Codex agent for AI-powered
code generation, review, and refactoring.

Prerequisites:
    pip install openai
    export OPENAI_API_KEY="your-api-key"
"""

import asyncio
import sys
from pathlib import Path

# Add project to path
sys.path.insert(0, str(Path(__file__).parent.parent / "agents/src/python"))

from claude_agents.implementations.development import CodexAgent, get_codex_agent


async def example_1_generate_function():
    """Example 1: Generate a Python function"""
    print("\n" + "=" * 70)
    print("EXAMPLE 1: Generate a Python Function")
    print("=" * 70)

    agent = get_codex_agent()
    if not agent.initialize():
        print("✗ Failed to initialize. Check OPENAI_API_KEY environment variable.")
        return

    result = await agent.generate_code(
        prompt="Create a Python function to calculate fibonacci numbers with memoization",
        language="python",
        context="For use in a performance-critical algorithm"
    )

    if result["success"]:
        print("\n✓ Generated Code:")
        print("-" * 70)
        print(result["code"])
        print("-" * 70)
        print(f"\nTokens used: {result['usage']['total_tokens']}")
    else:
        print(f"\n✗ Error: {result['error']}")


async def example_2_review_code():
    """Example 2: Review code for issues"""
    print("\n" + "=" * 70)
    print("EXAMPLE 2: Review Code for Security Issues")
    print("=" * 70)

    # Example code with security issues
    code = '''
import os

def process_user_input(user_data):
    # Dangerous: using eval()
    result = eval(user_data)

    # Dangerous: SQL injection risk
    query = f"SELECT * FROM users WHERE name = '{user_data}'"

    # Dangerous: command injection risk
    os.system(f"echo {user_data}")

    return result
'''

    agent = get_codex_agent()
    if not agent.initialized:
        agent.initialize()

    result = await agent.review_code(
        code=code,
        language="python",
        focus_areas=["security", "best_practices"]
    )

    if result["success"]:
        print("\n✓ Code Review:")
        print("-" * 70)
        print(result["review"])
        print("-" * 70)
    else:
        print(f"\n✗ Error: {result['error']}")


async def example_3_refactor_code():
    """Example 3: Refactor code for readability"""
    print("\n" + "=" * 70)
    print("EXAMPLE 3: Refactor Code for Readability")
    print("=" * 70)

    # Example code that needs refactoring
    code = '''
def f(a,b,c):
    x=a+b
    y=x*c
    z=y-a
    if z>0:
        return z
    else:
        return 0
'''

    agent = get_codex_agent()
    if not agent.initialized:
        agent.initialize()

    result = await agent.refactor_code(
        code=code,
        language="python",
        goals=["improve_readability", "add_type_hints", "add_documentation"]
    )

    if result["success"]:
        print("\n✓ Refactored Code:")
        print("-" * 70)
        print(result["result"])
        print("-" * 70)
    else:
        print(f"\n✗ Error: {result['error']}")


async def example_4_generate_agent():
    """Example 4: Generate a complete agent implementation"""
    print("\n" + "=" * 70)
    print("EXAMPLE 4: Generate Agent Implementation")
    print("=" * 70)

    agent = get_codex_agent()
    if not agent.initialized:
        agent.initialize()

    result = await agent.generate_code(
        prompt="""
        Create a Python agent class for monitoring file system changes.
        The agent should:
        - Inherit from a base agent class
        - Watch a directory for file changes
        - Log when files are created, modified, or deleted
        - Include proper error handling
        - Use async/await for I/O operations
        - Follow Google-style docstrings
        """,
        language="python",
        context="Agent for the Claude Agent Framework. Use pathlib for paths."
    )

    if result["success"]:
        print("\n✓ Generated Agent Implementation:")
        print("-" * 70)
        print(result["code"])
        print("-" * 70)
        print(f"\nTokens used: {result['usage']['total_tokens']}")

        # Optionally save to file
        save = input("\nSave to file? (y/n): ").strip().lower()
        if save == "y":
            filename = "filesystem_monitor_agent.py"
            with open(filename, "w") as f:
                f.write(result["code"])
            print(f"✓ Saved to {filename}")
    else:
        print(f"\n✗ Error: {result['error']}")


async def example_5_context_aware_generation():
    """Example 5: Generate code with project context"""
    print("\n" + "=" * 70)
    print("EXAMPLE 5: Context-Aware Code Generation")
    print("=" * 70)

    agent = get_codex_agent()
    if not agent.initialized:
        agent.initialize()

    # Provide detailed project context
    context = """
    This is for the Claude Agent Framework v7.0 agent orchestration system.
    The code will interact with EnhancedAgentRegistry for agent management.
    Use correct imports: from claude_agents.orchestration import get_agent_registry
    Follow async/await patterns for agent invocations.
    """

    result = await agent.generate_code(
        prompt="Create a function to invoke multiple agents in parallel and collect their results",
        language="python",
        context=context
    )

    if result["success"]:
        print("\n✓ Generated Context-Aware Code:")
        print("-" * 70)
        print(result["code"])
        print("-" * 70)
        print(f"\nTokens used: {result['usage']['total_tokens']}")
    else:
        print(f"\n✗ Error: {result['error']}")


async def example_6_batch_review():
    """Example 6: Review multiple files"""
    print("\n" + "=" * 70)
    print("EXAMPLE 6: Batch Code Review")
    print("=" * 70)

    # Example files to review (in a real scenario, these would be actual files)
    files_to_review = {
        "example1.py": "def unsafe_eval(x): return eval(x)",
        "example2.py": "def good_function(x: int) -> int: return x * 2",
    }

    agent = get_codex_agent()
    if not agent.initialized:
        agent.initialize()

    for filename, code in files_to_review.items():
        print(f"\nReviewing {filename}...")

        result = await agent.review_code(
            code=code,
            language="python",
            focus_areas=["security", "style"]
        )

        if result["success"]:
            print(f"✓ Review for {filename}:")
            print(result["review"][:200] + "..." if len(result["review"]) > 200 else result["review"])
        else:
            print(f"✗ Failed to review {filename}: {result['error']}")

        print("-" * 70)


def print_menu():
    """Print example menu"""
    print("\n" + "=" * 70)
    print("OpenAI Codex Integration Examples")
    print("Claude Agent Framework v7.0")
    print("=" * 70)
    print("\nAvailable Examples:")
    print("  1. Generate a Python function")
    print("  2. Review code for security issues")
    print("  3. Refactor code for readability")
    print("  4. Generate a complete agent implementation")
    print("  5. Context-aware code generation")
    print("  6. Batch code review")
    print("  0. Run all examples")
    print("  q. Quit")
    print("=" * 70)


async def main():
    """Main function"""
    # Check if OpenAI package is available
    try:
        import openai
    except ImportError:
        print("\n✗ Error: openai package not installed")
        print("Install with: pip install openai")
        return

    # Check for API key
    import os
    if not os.getenv("OPENAI_API_KEY"):
        print("\n⚠ Warning: OPENAI_API_KEY environment variable not set")
        print("Set with: export OPENAI_API_KEY='your-api-key'")
        print("\nContinuing anyway (examples will fail without valid key)...")

    examples = {
        "1": ("Generate Function", example_1_generate_function),
        "2": ("Review Code", example_2_review_code),
        "3": ("Refactor Code", example_3_refactor_code),
        "4": ("Generate Agent", example_4_generate_agent),
        "5": ("Context-Aware", example_5_context_aware_generation),
        "6": ("Batch Review", example_6_batch_review),
    }

    while True:
        print_menu()
        choice = input("\nSelect example (1-6, 0 for all, q to quit): ").strip()

        if choice.lower() == "q":
            print("\nGoodbye!")
            break

        elif choice == "0":
            # Run all examples
            for name, func in examples.values():
                print(f"\n\nRunning: {name}")
                await func()
                input("\nPress Enter to continue...")

        elif choice in examples:
            name, func = examples[choice]
            await func()
            input("\nPress Enter to continue...")

        else:
            print("\n✗ Invalid choice. Please select 1-6, 0, or q.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user. Goodbye!")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
