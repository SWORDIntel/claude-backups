import pytest
import asyncio
from textwrap import dedent
from agents.src.python.rejection_reduction_integration import UnifiedClaudeOptimizer
from agents.src.python.claude_rejection_reducer import StrategyResult

def target_function_for_polymorphism(a: int, b: int) -> int:
    """A simple, verifiable function to test polymorphic generation."""
    if a > b:
        result = (a - b) * 2
    else:
        result = (b - a) + 1
    return result

@pytest.fixture
def optimizer_v3():
    """Provides a v3 optimizer instance for testing the polymorphic engine."""
    return UnifiedClaudeOptimizer(enable_learning=False)

@pytest.mark.asyncio
async def test_polymorphic_generation_and_validation(optimizer_v3):
    """
    This test will validate the polymorphic engine's ability to generate
    1000 unique, functionally equivalent variants of the target function.
    """
    import inspect

    source_code = inspect.getsource(target_function_for_polymorphism)

    variants = set()
    num_variants_to_generate = 1000

    for i in range(num_variants_to_generate):
        # We directly call the strategy here to isolate the polymorphic engine
        # and bypass the risk analysis in process_request.
        result = await optimizer_v3.rejection_reducer._apply_semantic_cloning(
            source_code, None
        )

        assert result.success, f"Variant {i} failed to generate."

        # Verify functional equivalence
        try:
            # Execute the generated code in a temporary scope
            temp_scope = {}
            exec(result.content, globals(), temp_scope)

            # The function name will be mangled, so we need to find it.
            # We assume the cloner generates a function, so there will be one.
            new_func_name = [name for name, obj in temp_scope.items() if callable(obj)][0]
            generated_function = temp_scope[new_func_name]

            # Test with a couple of cases
            assert generated_function(5, 2) == target_function_for_polymorphism(5, 2)
            assert generated_function(2, 5) == target_function_for_polymorphism(2, 5)

            variants.add(result.content)
        except Exception as e:
            pytest.fail(f"Variant {i} failed functional equivalence test: {e}\nCode:\n{result.content}")

    uniqueness_ratio = len(variants) / num_variants_to_generate
    print(f"Polymorphic Engine Uniqueness Ratio: {uniqueness_ratio:.2%}")

    # Success criteria: >=99% unique variants (1% collision is acceptable)
    assert len(variants) >= 990