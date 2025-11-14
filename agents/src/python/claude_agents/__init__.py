"""Claude Agent Framework - Organized Package Structure"""

__version__ = "8.0.0"

from .core import *

# Make implementations accessible
from .implementations import get_agent, list_agents

# Import organization modules
from .orchestration import *
from .utils import *

__all__ = ["get_agent", "list_agents"]
