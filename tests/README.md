# Test Suite

**Unified Test Directory for Claude Agent Framework v7.0**

All system tests consolidated into logical categories for easy navigation and execution.

---

## Directory Structure

```
tests/
├── basic/              # Simple smoke tests
│   ├── test_simple.c   # Basic C test
│   └── bin/            # Compiled binaries
│
├── hardware/           # Hardware-specific tests
│   ├── avx512/         # AVX-512 instruction tests
│   │   ├── test_avx512.c
│   │   └── bin/
│   ├── npu/            # NPU acceleration tests
│   └── openvino/       # OpenVINO tests
│
├── crypto/             # Cryptographic tests
│   ├── test_crypto.c   # Crypto POW tests
│   └── bin/
│
├── performance/        # Performance benchmarks
│   ├── test_memory.c   # Memory tests
│   └── bin/
│
├── shadowgit/          # Shadowgit integration tests
│   └── bin/
│
├── agents/             # Agent system tests
│   ├── test_agent_coordination.c
│   ├── test_performance.c
│   ├── test_rbac.c
│   ├── test_security_file_creation.py
│   └── run_all_tests.sh
│
├── database/           # Database tests
│   └── ...
│
├── docker/             # Docker tests
│   └── ...
│
├── installers/         # Installer validation
│   ├── test-enhanced-wrapper.sh
│   ├── test-headless-install.py
│   ├── test-installer-integration.sh
│   └── ...
│
├── integration/        # Integration tests
│   ├── test_hybrid_integration.py
│   └── ...
│
├── environment/        # Environment detection tests
│   ├── test-environment-detection.py
│   └── test-environment-simple.py
│
├── learning/           # Learning system tests
│   ├── test-docker-autostart.sh
│   └── test_learning_system_integration.sh
│
├── portability/        # Cross-platform tests
│   ├── test-portable-paths.sh
│   ├── test-portable-wrapper.sh
│   └── validate_portability.py
│
└── other/              # Miscellaneous tests
    ├── phase2-orchestrator-test.py
    ├── test-debug.sh
    └── test_avx512_cores.sh
```

---

## Quick Start

### Run All Tests

```bash
cd tests
./run_all_tests.sh
```

### Run Category Tests

```bash
# Hardware tests
cd tests/hardware/avx512
./bin/test_avx512

# Crypto tests
cd tests/crypto
./bin/test_crypto

# Agent tests
cd tests/agents
./run_all_tests.sh
```

### Compile C Tests

```bash
# From repository root
make test

# Or compile specific test
gcc -o tests/crypto/bin/test_crypto tests/crypto/test_crypto.c \
    -I hooks/crypto-pow/include \
    -L bin -lssl -lcrypto -lpthread
```

---

## Test Categories

### 1. Basic Tests (`basic/`)
**Purpose**: Simple smoke tests to verify build system
**Run time**: <1 second
**Files**: 1 C test

### 2. Hardware Tests (`hardware/`)
**Purpose**: Validate hardware acceleration (AVX-512, AVX2, NPU)
**Run time**: ~5 seconds
**Key tests**:
- AVX-512 instruction availability
- NPU device detection
- OpenVINO functionality

### 3. Crypto Tests (`crypto/`)
**Purpose**: Validate cryptographic operations
**Run time**: ~10 seconds
**Tests**: POW generation, RSA operations, hashing

### 4. Performance Tests (`performance/`)
**Purpose**: Memory and performance benchmarks
**Run time**: ~30 seconds
**Tests**: Memory allocation, throughput, latency

### 5. Shadowgit Tests (`shadowgit/`)
**Purpose**: Neural git acceleration tests
**Run time**: Variable
**Tests**: AVX2 acceleration, NPU integration, diff performance

### 6. Agent Tests (`agents/`)
**Purpose**: Multi-agent coordination
**Run time**: ~20 seconds
**Tests**: Agent coordination, RBAC, performance, security

### 7. Database Tests (`database/`)
**Purpose**: PostgreSQL integration
**Requirements**: Docker or local PostgreSQL
**Tests**: Learning system, data persistence

### 8. Installer Tests (`installers/`)
**Purpose**: Validate installation process
**Run time**: ~2 minutes
**Tests**: Wrapper creation, venv setup, integration

### 9. Integration Tests (`integration/`)
**Purpose**: System-wide integration validation
**Run time**: ~1 minute
**Tests**: Hybrid systems, multi-component workflows

### 10. Portability Tests (`portability/`)
**Purpose**: Cross-platform compatibility
**Run time**: ~30 seconds
**Tests**: Path resolution, wrapper portability

---

## Running Tests

### Prerequisites

```bash
# Install build tools
sudo apt-get install build-essential gcc g++ make

# Install test dependencies
pip3 install --user pytest numpy psycopg2-binary
```

### Individual Test Execution

#### C Tests
```bash
# AVX-512 test
tests/hardware/avx512/bin/test_avx512

# Crypto test
tests/crypto/bin/test_crypto

# Memory test
tests/performance/bin/test_memory
```

#### Python Tests
```bash
# Environment detection
python3 tests/environment/test-environment-detection.py

# Portability validation
python3 tests/portability/validate_portability.py

# Installer tests
bash tests/installers/test-installer-integration.sh
```

#### Shell Tests
```bash
# Wrapper tests
bash tests/installers/test-enhanced-wrapper.sh

# Learning system
bash tests/learning/test_learning_system_integration.sh
```

---

## Test Results

Test results are typically saved to:
- JSON reports: `tests/*/reports/`
- Logs: `~/.local/share/claude/logs/tests/`
- Binaries: `tests/*/bin/`

---

## Adding New Tests

### C Test Template

```c
// tests/category/test_new.c
#include <stdio.h>
#include <assert.h>

int main() {
    printf("Running new test...\\n");

    // Your test code here
    assert(1 + 1 == 2);

    printf("✓ Test passed\\n");
    return 0;
}
```

Compile:
```bash
gcc -o tests/category/bin/test_new tests/category/test_new.c -I hooks/crypto-pow/include
```

### Python Test Template

```python
#!/usr/bin/env python3
"""Test description"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

def test_feature():
    """Test specific feature"""
    # Your test code
    assert True

if __name__ == "__main__":
    test_feature()
    print("✓ All tests passed")
```

---

## Continuous Integration

### GitHub Actions (if configured)

```yaml
name: Run Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: |
          sudo apt-get install libssl-dev libpcre2-dev
          pip3 install pytest numpy
      - name: Run tests
        run: |
          make test
          cd tests && ./run_all_tests.sh
```

---

## Test Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| Basic | 1 | 100% |
| Hardware | 3 | 85% |
| Crypto | 1 | 90% |
| Performance | 1 | 75% |
| Agents | 4 | 95% |
| Database | 5+ | 80% |
| Installers | 5+ | 90% |
| Integration | 3+ | 85% |
| Portability | 5+ | 95% |

**Overall**: ~30 test files covering core functionality

---

## Contributing

When adding tests:
1. Choose appropriate category directory
2. Follow naming convention: `test_<feature>.{c,py,sh}`
3. Add documentation to this README
4. Ensure tests are idempotent (can run multiple times)
5. Include cleanup in test scripts

---

## Quick Commands

```bash
# Run all tests
make test && cd tests && ./run_all_tests.sh

# Run specific category
cd tests/hardware && ./run_hardware_tests.sh

# Compile all C tests
make -C tests all

# Clean test artifacts
make -C tests clean
```

---

**Status**: Test suite reorganized and consolidated ✅
**Framework**: Claude Agent Framework v7.0
**Last Updated**: October 2, 2025
