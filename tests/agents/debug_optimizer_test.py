#!/usr/bin/env python3
"""
Debug OPTIMIZER agent routing
"""

import asyncio
import sys
from pathlib import Path

# Add current directory to path for imports
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))


async def debug_optimizer_routing():
    """Debug OPTIMIZER agent routing in production orchestrator"""
    print("=== Debug OPTIMIZER Agent Routing ===")

    try:
        from production_orchestrator import (
            CommandSet,
            CommandStep,
            CommandType,
            ExecutionMode,
            ProductionOrchestrator,
        )

        orchestrator = ProductionOrchestrator()

        if not await orchestrator.initialize():
            print("❌ Failed to initialize orchestrator")
            return False

        print(f"✅ Orchestrator initialized")
        print(f"   Mock mode: {orchestrator.mock_mode}")
        print(f"   Available agents: {len(orchestrator.agent_registry.agents)}")

        # Test direct OPTIMIZER invocation
        step = CommandStep(
            agent="optimizer",
            action="analyze_performance",
            payload={"target_file": "/tmp/test.py"},
        )

        # Get agent info
        agent_info = orchestrator.get_agent_info("optimizer")
        if agent_info:
            print(f"   OPTIMIZER found: {agent_info.name} v{agent_info.version}")
        else:
            print("   ❌ OPTIMIZER not found in registry")
            return False

        # Test _invoke_real_agent directly
        print("\n=== Testing _invoke_real_agent ===")
        result = await orchestrator._invoke_real_agent(step, agent_info)
        print(f"   Result status: {result.get('status')}")
        print(f"   Execution mode: {result.get('execution_mode')}")
        print(f"   Agent: {result.get('agent')}")

        # Test if _invoke_optimizer_python exists
        if hasattr(orchestrator, "_invoke_optimizer_python"):
            print("   ✅ _invoke_optimizer_python method exists")

            try:
                optimizer_result = await orchestrator._invoke_optimizer_python(step)
                print(f"   Direct call status: {optimizer_result.get('status')}")
                print(f"   Direct call mode: {optimizer_result.get('execution_mode')}")
            except Exception as e:
                print(f"   ❌ Direct call failed: {e}")
        else:
            print("   ❌ _invoke_optimizer_python method missing")

        return True

    except Exception as e:
        print(f"❌ Debug failed: {e}")
        import traceback

        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = asyncio.run(debug_optimizer_routing())
    sys.exit(0 if success else 1)
