import json
import os
import sys
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


# Add project root to the Python path to allow for imports
@pytest.fixture(scope="module", autouse=True)
def setup_sys_path():
    """Prepares the sys.path for module imports during testing."""
    project_root = Path(__file__).parent.parent
    # Prepend project paths to allow for imports
    sys.path.insert(0, str(project_root))
    # This path is crucial for importing agent implementations
    python_agents_path = str(project_root / "agents" / "src" / "python")
    sys.path.insert(0, python_agents_path)
    # Set an environment variable to simulate being outside the Claude Code env
    os.environ["IS_TESTING_MODE"] = "true"
    yield
    del os.environ["IS_TESTING_MODE"]
    # Clean up sys.path
    sys.path.remove(python_agents_path)
    sys.path.remove(str(project_root))


# Now we can import the module
from integration.claude_unified_integration import (
    AgentInvocationMethod,
    UnifiedAgentRegistry,
    UnifiedClaudeCodeIntegration,
)


@pytest.fixture
def mock_project_root(tmp_path):
    """Creates a mock project structure for isolated testing."""
    # Create a marker file to identify the root
    (tmp_path / ".claude").touch()

    # Agents directory with Markdown definitions
    agents_dir = tmp_path / "agents"
    agents_dir.mkdir()

    # Mock CONSTRUCTOR.md: An agent defined purely by Markdown
    constructor_md_content = textwrap.dedent(
        """\
    ---
    uuid: "123-abc"
    category: "CODE_GENERATION"
    priority: "HIGH"
    tools:
      - "file-io"
      - "code-execution"
    proactive_triggers:
      - "create a new file"
      - "implement a function"
    ---
    # CONSTRUCTOR Agent
    This agent is responsible for building things.
    """
    )
    (agents_dir / "CONSTRUCTOR.md").write_text(constructor_md_content)

    # Mock LINTER.md: An agent that also has a Python implementation
    linter_md_content = textwrap.dedent(
        """\
    ---
    uuid: "456-def"
    category: "CODE_QUALITY"
    description: "A linter agent."
    ---
    # LINTER Agent
    This agent lints code.
    """
    )
    (agents_dir / "LINTER.md").write_text(linter_md_content)

    # Python implementations directory
    python_impl_dir = agents_dir / "src" / "python"
    python_impl_dir.mkdir(parents=True)

    # Mock linter_impl.py: Python implementation for the Linter agent
    linter_impl_content = """
class LinterPythonExecutor:
    def execute_command(self, command, params):
        return f"Linter executed with {command}"
"""
    (python_impl_dir / "linter_impl.py").write_text(linter_impl_content)

    # Mock claude_code_integration.py for command-based agents
    claude_integration_content = """
PROJECT_AGENTS = {
    "DEBUGGER": {
        "name": "Debugger",
        "command": "claude-agent debugger",
        "description": "A command-line debugger.",
        "tools": ["debugger-tool"]
    }
}
"""
    (python_impl_dir / "claude_code_integration.py").write_text(
        claude_integration_content
    )

    # No patching needed here anymore, just yield the path.
    yield tmp_path


def test_agent_registry_discovery(mock_project_root):
    """Test if the UnifiedAgentRegistry correctly discovers agents from all sources."""
    # Instantiate the top-level integration class with the mock paths.
    integration = UnifiedClaudeCodeIntegration(
        project_root=mock_project_root, agents_dir=mock_project_root / "agents"
    )
    registry = integration.registry

    # Check total number of agents found
    assert (
        len(registry.agents) == 3
    ), f"Should discover exactly three agents, but found {len(registry.agents)}: {list(registry.agents.keys())}"
    assert sorted(registry.list_agents()) == ["constructor", "debugger", "linter"]

    # --- Validate CONSTRUCTOR agent (from .md) ---
    constructor = registry.get_agent("constructor")
    assert constructor is not None
    assert constructor.name == "CONSTRUCTOR"
    assert constructor.category == "CODE_GENERATION"
    assert constructor.uuid == "123-abc"
    assert "building things" in constructor.description
    assert (
        constructor.python_impl_path is None
    ), "Constructor should not have a Python impl"
    assert AgentInvocationMethod.PYTHON_DIRECT not in constructor.invocation_methods

    # --- Validate LINTER agent (from .md and _impl.py) ---
    linter = registry.get_agent("linter")
    assert linter is not None
    assert linter.name == "LINTER"
    assert linter.category == "CODE_QUALITY"
    assert linter.python_impl_path is not None, "Linter should have a Python impl"
    assert "linter_impl.py" in linter.python_impl_path
    assert AgentInvocationMethod.PYTHON_DIRECT in linter.invocation_methods

    # --- Validate DEBUGGER agent (from claude_code_integration.py) ---
    debugger = registry.get_agent("debugger")
    assert debugger is not None
    assert debugger.name == "Debugger"
    assert (
        debugger.category == "EXTERNAL"
    ), "Category should be EXTERNAL for command-only agents"
    assert debugger.command == "claude-agent debugger"
    assert "debugger-tool" in debugger.tools
    assert AgentInvocationMethod.CLAUDE_AGENT_COMMAND in debugger.invocation_methods


def test_system_status_standalone(mock_project_root):
    """Test the get_system_status method in a controlled standalone mode."""
    # Instantiate with mock paths to ensure no accidental reading from real project
    integration = UnifiedClaudeCodeIntegration(
        project_root=mock_project_root, agents_dir=mock_project_root / "agents"
    )
    status = integration.get_system_status()

    assert status["integration_active"] is True
    assert (
        status["claude_code_detected"] is False
    ), "Should not detect Claude env during tests"
    assert (
        status["hooks_setup"] is False
    ), "Hooks should not be set up in standalone mode"
    assert status["agents_loaded"] > 0, "Should load agents from the actual project"
    assert (
        status["orchestrator_available"] is not None
    )  # Check if it's present, regardless of value
