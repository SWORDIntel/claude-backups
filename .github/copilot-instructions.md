# GitHub Copilot Instructions for Claude Agent Framework v7.0

## Project Overview

This is the Claude Agent Framework v7.0 - a multi-agent AI orchestration system with hardware acceleration (Intel NPU, AVX2/AVX-512) for high-performance git analysis and agent coordination.

## Architecture (3-Tier)

```
Agent Layer (Python) → Hook Layer (Python/C) → Binary Layer (C/Rust)
```

- **Agent Layer**: 68 specialized agents in `agents/src/python/claude_agents/`
- **Hook Layer**: ShadowGit (git intelligence) in `hooks/shadowgit/python/`
- **Binary Layer**: C/Rust binaries in `hooks/shadowgit/src/`, `hooks/crypto-pow/`

## Import Guidelines

### ✅ CORRECT Imports

```python
# Agent system
from claude_agents.orchestration import get_agent_registry, EnhancedAgentRegistry
from claude_agents import get_agent, list_agents
from claude_agents.git.conflict_predictor import ConflictPredictor
from claude_agents.utils.agent_path_resolver import AgentPathResolver

# ShadowGit
from hooks.shadowgit.python import Phase3Unified, ShadowGitAVX2
from hooks.shadowgit.python.integration_hub import *

# Always add to sys.path if importing agents
import sys
sys.path.insert(0, 'agents/src/python')
```

### ❌ INCORRECT Imports (Legacy - Don't Use)

```python
# DON'T use these old paths
from agents.src.python.agent_registry import get_agent_registry  # ❌ Old
from shadowgit_python_bridge import *  # ❌ Deprecated
from crypto_pow_core import *  # ❌ Deprecated
```

## Coding Standards

### Python Style
- **Formatter**: black (line length: 100)
- **Import Order**: isort with black profile
- **Type Hints**: Required for ALL public functions
- **Docstrings**: Google style for all classes/public methods
- **Python Version**: 3.11+ (use modern syntax)

### Example Function

```python
from typing import Dict, List, Optional, Any
from pathlib import Path

def process_git_diff(
    diff_path: Path,
    use_npu: bool = True,
    confidence_threshold: float = 0.7
) -> Dict[str, Any]:
    """Process git diff with NPU acceleration.

    Args:
        diff_path: Path to diff file
        use_npu: Enable NPU acceleration if available
        confidence_threshold: Minimum confidence for predictions

    Returns:
        Dictionary containing analysis results with keys:
        - 'conflicts': List of predicted conflicts
        - 'acceleration': 'npu' or 'cpu'
        - 'execution_time': Time in milliseconds

    Raises:
        ValueError: If diff_path doesn't exist
        RuntimeError: If NPU initialization fails
    """
    if not diff_path.exists():
        raise ValueError(f"Diff file not found: {diff_path}")

    # Implementation here
    pass
```

## Hardware Acceleration

### Using NPU (Intel AI Boost)

```python
from hooks.shadowgit.python.shadowgit_avx2 import ShadowGitAVX2

# Auto-detects and uses NPU if available
sg = ShadowGitAVX2()

# Batch operations (7-10x faster with NPU)
hashes = sg.hash_files_batch(['file1.py', 'file2.py'])

# Check if NPU is active
status = sg.get_acceleration_status()
if status['npu']['available']:
    print(f"Using NPU: {status['npu']['info']['name']}")
```

### Core Affinity (Intel Meteor Lake)
- **P-cores** (0-11): Use for compute-intensive tasks (AVX-512 capable)
- **E-cores** (12-21): Use for I/O and background tasks
- **LP E-core** (20): Low power core for monitoring

## Testing Requirements

### Every Feature Needs Tests

```python
# tests/test_my_feature.py
import pytest
from claude_agents.orchestration import get_agent_registry

def test_agent_registry_initialization():
    """Test agent registry can be initialized"""
    registry = get_agent_registry()
    assert registry is not None
    assert len(registry.agents) > 0

@pytest.mark.asyncio
async def test_async_agent_invocation():
    """Test async agent execution"""
    registry = get_agent_registry()
    result = await registry.invoke_agent('director', 'test task', {})
    assert result['status'] == 'success'
```

### Coverage Requirements
- **Minimum**: 80% coverage for all new code
- **Run**: `pytest --cov=claude_agents --cov-report=html`
- **Integration tests**: `integration/test_unified_integration.py`

## Security Guidelines

### ✅ DO

```python
import os
from pathlib import Path

# Use environment variables
db_password = os.getenv('POSTGRES_PASSWORD', 'default_dev_password')

# Use pathlib for paths
project_root = Path(__file__).parent.parent
config_file = project_root / 'config' / 'settings.json'

# Validate inputs
def process_user_input(data: str) -> str:
    if not data or len(data) > 10000:
        raise ValueError("Invalid input length")
    # Sanitize and process
    return data.strip()
```

### ❌ DON'T

```python
# DON'T hardcode credentials
password = "mysecretpassword"  # ❌

# DON'T use hardcoded paths
config = "/home/ubuntu/Documents/Claude/config.json"  # ❌

# DON'T use shell=True
subprocess.run(f"rm -rf {user_input}", shell=True)  # ❌ DANGEROUS

# DON'T use eval/exec
eval(user_code)  # ❌ NEVER
```

## Performance Best Practices

### Use NPU for Batch Operations

```python
# ✅ Good - Batch operation with NPU
files = [f'file{i}.py' for i in range(100)]
hashes = sg.hash_files_batch(files)  # 7x faster

# ❌ Slow - Sequential processing
hashes = [sg.hash_file(f) for f in files]  # CPU only
```

### Use Async for I/O

```python
# ✅ Good - Async I/O
async def fetch_multiple_agents():
    tasks = [fetch_agent(name) for name in agent_names]
    return await asyncio.gather(*tasks)

# ❌ Slow - Synchronous I/O
def fetch_multiple_agents():
    return [fetch_agent(name) for name in agent_names]
```

## Common Patterns

### Agent Invocation

```python
from claude_agents.orchestration import get_agent_registry

registry = get_agent_registry()

# Invoke agent with parameters
result = registry.invoke_agent(
    agent_name='director',
    task='Create project plan',
    parameters={'priority': 'high', 'deadline': '2025-12-01'}
)

# Check result
if result['success']:
    print(f"Task completed: {result['output']}")
else:
    print(f"Task failed: {result['error']}")
```

### ShadowGit Analysis

```python
from hooks.shadowgit.python import Phase3Unified

phase3 = Phase3Unified()
phase3.initialize()

# Analyze diff
result = phase3.process_diff('/path/to/diff.txt')
print(f"Execution: {result['execution_path']}")  # 'npu' or 'cpu'
print(f"Conflicts: {result.get('conflicts', [])}")
```

### Database Connections

```python
import asyncpg
import os

async def get_db_connection():
    """Get PostgreSQL connection with environment config"""
    return await asyncpg.connect(
        host=os.getenv('POSTGRES_HOST', 'localhost'),
        port=int(os.getenv('POSTGRES_PORT', '5433')),
        database=os.getenv('POSTGRES_DB', 'claude_auth'),
        user=os.getenv('POSTGRES_USER', 'claude_auth'),
        password=os.getenv('POSTGRES_PASSWORD')
    )
```

## File Organization

When creating new files, follow this structure:

```
agents/src/python/claude_agents/
├── implementations/
│   ├── core/           # Core agents (director, architect, etc.)
│   ├── development/    # Dev agents (debugger, linter, etc.)
│   ├── infrastructure/ # Infra agents (deployer, monitor, etc.)
│   ├── security/       # Security agents
│   └── specialized/    # Task-specific agents
├── orchestration/      # Agent registry and coordination
├── git/                # Git-related utilities
├── utils/              # General utilities
└── [category]/         # Other categorized modules
```

## Error Handling

```python
from typing import Optional
import logging

logger = logging.getLogger(__name__)

def risky_operation(data: str) -> Optional[dict]:
    """Perform operation with proper error handling"""
    try:
        # Validate input
        if not data:
            raise ValueError("Data cannot be empty")

        # Process
        result = process_data(data)
        return {"success": True, "data": result}

    except ValueError as e:
        logger.error(f"Validation error: {e}")
        return {"success": False, "error": str(e)}

    except Exception as e:
        logger.exception("Unexpected error in risky_operation")
        return {"success": False, "error": "Internal error occurred"}
```

## Git Commit Messages

Follow this format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: feat, fix, docs, style, refactor, perf, test, chore

**Examples**:
```
feat(shadowgit): add NPU batch hashing support

Implement batch hash operations using NPU acceleration.
Performance improvement: 7x faster for 100+ files.

Closes #123

---

fix(agents): resolve import error in agent_registry

Update imports to use new claude_agents.orchestration path.

---

perf(npu): optimize memory allocation for large batches

Reduce memory footprint by 40% for batches > 1000 items.
```

## Documentation Standards

Every module needs a docstring:

```python
"""Module for [purpose].

This module provides [functionality] for the Claude Agent Framework.
It integrates with [other components] to enable [feature].

Typical usage example:

  from claude_agents.module import Feature

  feature = Feature()
  result = feature.process(data)

Performance notes:
  - Uses NPU acceleration when available
  - Recommended batch size: 100-1000 items
  - Memory usage: O(n) where n is batch size
"""
```

## When to Use Which Components

| Task | Component | Import |
|------|-----------|--------|
| Agent coordination | EnhancedAgentRegistry | `from claude_agents.orchestration import get_agent_registry` |
| Git analysis | Phase3Unified | `from hooks.shadowgit.python import Phase3Unified` |
| NPU operations | ShadowGitAVX2 | `from hooks.shadowgit.python import ShadowGitAVX2` |
| Path resolution | AgentPathResolver | `from claude_agents.utils import AgentPathResolver` |
| Conflict prediction | ConflictPredictor | `from claude_agents.git import ConflictPredictor` |

## Debugging

```python
import logging

# Set up logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Use logging instead of print
logger.debug("Debug information")
logger.info("Informational message")
logger.warning("Warning message")
logger.error("Error message")
logger.exception("Exception with traceback")
```

## Final Checklist for Pull Requests

- [ ] All imports use new `claude_agents.*` paths
- [ ] Type hints on all public functions
- [ ] Docstrings in Google style
- [ ] Tests added with 80%+ coverage
- [ ] Code formatted with black + isort
- [ ] No hardcoded paths or credentials
- [ ] Error handling with specific exceptions
- [ ] Logging instead of print statements
- [ ] Security review (no SQL injection, command injection, etc.)
- [ ] Performance tested (use NPU where applicable)

---

**Remember**: This is a production system with Intel Meteor Lake hardware optimization. Code should be efficient, type-safe, and well-documented.
