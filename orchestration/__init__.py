"""Claude Agent Framework - Orchestration Module"""

# Import core orchestration components
try:
    from .agent_registry import AgentRegistry
    from .database_orchestrator import DatabaseOrchestrator
    from .orchestrator_metrics import OrchestratorMetrics
    from .production_orchestrator import ProductionOrchestrator
    from .tandem_orchestrator import TandemOrchestrator
except ImportError as e:
    # Fallback if not all modules are available
    pass

__all__ = [
    "ProductionOrchestrator",
    "TandemOrchestrator",
    "AgentRegistry",
    "DatabaseOrchestrator",
    "OrchestratorMetrics",
]
