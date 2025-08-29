"""Claude Agent Framework - Organized Package Structure"""

__version__ = "8.0.0"

# Import organization modules
from .orchestration import *
from .core import *
from .utils import *

# Make implementations accessible
from .implementations import get_agent, list_agents

__all__ = ['get_agent', 'list_agents']
