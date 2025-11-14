#!/usr/bin/env python3
"""
Claude Agent Framework v7.0 - Main Package
Hardware-aware multi-agent orchestration system optimized for Intel Meteor Lake architecture

This package provides 76 specialized agents with autonomous coordination capabilities,
production orchestration, and Claude Code integration.
"""

__version__ = "7.0"
__author__ = "Claude Agent Framework"
__description__ = (
    "Hardware-aware multi-agent orchestration system with Tandem Orchestration"
)

# Core imports for package functionality
import sys
from pathlib import Path

# Add project root to Python path for proper imports
PROJECT_ROOT = Path(__file__).parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Core components (with graceful fallback)
try:
    from agents.src.python.agent_registry import (
        EnhancedAgentRegistry,
        get_enhanced_registry,
    )
    from agents.src.python.production_orchestrator import ProductionOrchestrator

    ORCHESTRATION_AVAILABLE = True
except ImportError:
    ProductionOrchestrator = None
    EnhancedAgentRegistry = None
    get_enhanced_registry = None
    ORCHESTRATION_AVAILABLE = False

# Claude Code integration
try:
    from agents.src.python.claude_code_integration import (
        PROJECT_AGENTS,
        get_available_agents,
        invoke_project_agent,
        register_with_claude_code,
    )

    CLAUDE_CODE_INTEGRATION = True
except ImportError:
    PROJECT_AGENTS = {}
    invoke_project_agent = None
    get_available_agents = lambda: []
    register_with_claude_code = lambda: {
        "success": False,
        "error": "Integration not available",
    }
    CLAUDE_CODE_INTEGRATION = False

# Hook system
try:
    from hooks.claude_code_hook_adapter import ClaudeCodeHookAdapter

    HOOKS_AVAILABLE = True
except ImportError:
    ClaudeCodeHookAdapter = None
    HOOKS_AVAILABLE = False

# System information
SYSTEM_INFO = {
    "project_root": PROJECT_ROOT,
    "agent_count": 76,
    "orchestration_available": ORCHESTRATION_AVAILABLE,
    "claude_code_integration": CLAUDE_CODE_INTEGRATION,
    "hooks_available": HOOKS_AVAILABLE,
}


def get_system_status():
    """Get current system status and capabilities"""
    return SYSTEM_INFO.copy()


def initialize_claude_integration():
    """Initialize Claude Code integration if available"""
    if not CLAUDE_CODE_INTEGRATION:
        return {"success": False, "error": "Claude Code integration not available"}

    try:
        # Register agents with Claude Code
        result = register_with_claude_code()

        # Initialize hook system if available
        if HOOKS_AVAILABLE:
            hook_adapter = ClaudeCodeHookAdapter()
            hook_adapter.register_as_claude_hook()
            result["hooks_registered"] = True

        return result

    except Exception as e:
        return {"success": False, "error": str(e)}


def get_available_agents_list():
    """Get list of all available agents"""
    if CLAUDE_CODE_INTEGRATION:
        return get_available_agents()
    return []


def invoke_agent(agent_type, prompt):
    """Invoke a project agent"""
    if not CLAUDE_CODE_INTEGRATION:
        return {"error": "Claude Code integration not available"}

    return invoke_project_agent(agent_type, prompt)


# Package exports
__all__ = [
    # Core classes
    "ProductionOrchestrator",
    "EnhancedAgentRegistry",
    "ClaudeCodeHookAdapter",
    # Agent system
    "PROJECT_AGENTS",
    "invoke_project_agent",
    "get_available_agents",
    # Convenience functions
    "get_system_status",
    "initialize_claude_integration",
    "get_available_agents_list",
    "invoke_agent",
    # System info
    "SYSTEM_INFO",
    "PROJECT_ROOT",
]

# Auto-initialize if imported (but not if run directly)
if __name__ != "__main__":
    # Silently attempt initialization - don't spam logs
    try:
        initialize_claude_integration()
    except:
        pass  # Fail gracefully
