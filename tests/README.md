# Tests Directory

This directory contains all test files for the Claude Agent Framework project.

## Structure

- **agents/** - Agent-related tests (Python and C)
  - Python orchestration tests
  - Agent communication tests
  - Integration tests
  - Performance tests

- **database/** - Database-related tests
  - PostgreSQL compatibility tests
  - Performance benchmarks
  - Connection tests

- **installers/** - Installer tests
  - Installation validation
  - Component verification

- **integration/** - Integration tests
  - System-wide integration tests
  - Critical optimization tests
  - Learning system integration

- **tools/** - Tool-specific tests
  - Sync integration tests
  - Utility validation

## Running Tests

### Agent Tests
```bash
cd tests/agents
python3 test_tandem_system.py
./run_all_tests.sh
```

### Database Tests
```bash
cd tests/database
python3 test_postgresql_compatibility.py
python3 auth_db_performance_test.py
```

### Integration Tests
```bash
cd tests/integration
./test-installer-integration.sh
./test_learning_system_integration.sh
```

## Import Guidelines

Test files use relative imports from the project root. For Python tests:

```python
from pathlib import Path
import sys

# Add project root to path 
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.append(str(project_root))

# Now import project modules
from production_orchestrator import ProductionOrchestrator
```

## Notes

- All test files have been consolidated from their original scattered locations
- Import paths have been updated to work from the new test directory structure
- Tests maintain full functionality with proper path resolution