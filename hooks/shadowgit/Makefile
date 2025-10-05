# Shadowgit Phase 3 Integration Makefile
# ======================================
# Team Delta - Hardware-accelerated integration build system

# Define project root for absolute paths
PROJECT_ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Include compiler profile system
include $(PROJECT_ROOT)/Makefile.profiles

# Compiler and flags
CC = gcc
PYTHON = python3

# Compiler flags (profile provides optimization and CPU targeting)
CFLAGS = -std=c99 -Wall -Wextra $(PROD_FLAGS)
CFLAGS += -fomit-frame-pointer -ffast-math
CFLAGS += -flto -fuse-linker-plugin -funroll-loops -finline-functions
CFLAGS += -ftree-vectorize -fprefetch-loop-arrays
CFLAGS += -fno-signed-zeros -fno-trapping-math
CFLAGS += -pthread -fPIC

# SIMD flags provided by PROD_FLAGS from profile system
# (Profile auto-detects and includes -mavx2 -mfma -mavx-vnni for Meteor Lake)

# Military-grade security flags
CFLAGS += -fstack-clash-protection -fcf-protection=full
CFLAGS += -D_FORTIFY_SOURCE=2 -D_GLIBCXX_ASSERTIONS
CFLAGS += -fzero-call-used-regs=all -fzero-initialized-in-bss

$(info Building Shadowgit with Meteor Lake optimizations: AVX2+FMA+AVX-VNNI)

# Libraries
LIBS = -lm -lrt -lpthread

# Directories
SHADOWGIT_DIR = src
BUILD_DIR = ../../build/shadowgit
AGENTS_PYTHON_DIR = ../../agents/src/python

# Source files
SHADOWGIT_SOURCES = $(SHADOWGIT_DIR)/shadowgit_avx2_diff.c
INTEGRATION_SOURCES = src/phase3/integration.c
HEADERS = $(SHADOWGIT_DIR)/shadowgit_avx2_diff.h

# Targets
SHARED_LIB = shadowgit_phase3_integration.so
STANDALONE_EXE = shadowgit_phase3_test
PYTHON_SCRIPT = shadowgit_accelerator.py

# Include paths
INCLUDES = -I$(SHADOWGIT_DIR) -I.

# Default target
.PHONY: all
all: $(SHARED_LIB) $(STANDALONE_EXE)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Shared library for Python integration
$(SHARED_LIB): $(INTEGRATION_SOURCES) $(SHADOWGIT_SOURCES) $(HEADERS) | $(BUILD_DIR)
	@echo "Building shared library for Python integration..."
	$(CC) -shared $(CFLAGS) $(INCLUDES) \
		$(INTEGRATION_SOURCES) $(SHADOWGIT_SOURCES) \
		$(LIBS) -o $(SHARED_LIB)
	@echo "✓ Shared library built: $(SHARED_LIB)"

# Standalone executable for C testing
$(STANDALONE_EXE): $(INTEGRATION_SOURCES) $(SHADOWGIT_SOURCES) $(HEADERS) | $(BUILD_DIR)
	@echo "Building standalone executable..."
	$(CC) $(CFLAGS) $(INCLUDES) -DSTANDALONE_TEST \
		$(INTEGRATION_SOURCES) $(SHADOWGIT_SOURCES) \
		$(LIBS) -o $(STANDALONE_EXE)
	@echo "✓ Standalone executable built: $(STANDALONE_EXE)"

# AVX-512 optimized version (requires AVX-512 hardware)
.PHONY: avx512
avx512: CFLAGS += -DENABLE_AVX512 -mavx512f -mavx512bw -mavx512cd -mavx512dq
avx512: $(SHARED_LIB) $(STANDALONE_EXE)
	@echo "✓ AVX-512 optimized build complete"

# Debug build
.PHONY: debug
debug: CFLAGS += -g -DDEBUG -O1
debug: $(SHARED_LIB) $(STANDALONE_EXE)
	@echo "✓ Debug build complete"

# Performance optimized build
.PHONY: performance
performance: CFLAGS += -DNDEBUG -flto -ffast-math
performance: $(SHARED_LIB) $(STANDALONE_EXE)
	@echo "✓ Performance optimized build complete"

# Test targets
.PHONY: test-c
test-c: $(STANDALONE_EXE)
	@echo "Running C integration test..."
	./$(STANDALONE_EXE) 25
	@echo "✓ C integration test complete"

.PHONY: test-python
test-python: $(SHARED_LIB)
	@echo "Running Python accelerator test..."
	@echo "Setting up Python path..."
	PYTHONPATH=$(AGENTS_PYTHON_DIR):$$PYTHONPATH $(PYTHON) $(PYTHON_SCRIPT)
	@echo "✓ Python accelerator test complete"

.PHONY: test-integration
test-integration: $(SHARED_LIB) $(STANDALONE_EXE)
	@echo "Running full integration test suite..."
	@echo "1. C Library Test (25 tasks):"
	./$(STANDALONE_EXE) 25
	@echo ""
	@echo "2. Python Orchestrator Test:"
	PYTHONPATH=$(AGENTS_PYTHON_DIR):$$PYTHONPATH $(PYTHON) $(PYTHON_SCRIPT)
	@echo "✓ Full integration test suite complete"

# Performance benchmarking
.PHONY: benchmark
benchmark: performance
	@echo "Running performance benchmarks..."
	@echo "C Library Benchmark (100 tasks):"
	./$(STANDALONE_EXE) 100
	@echo ""
	@echo "Python Integration Benchmark:"
	PYTHONPATH=$(AGENTS_PYTHON_DIR):$$PYTHONPATH $(PYTHON) -c "\
import asyncio; \
import sys; \
sys.path.insert(0, '.'); \
from shadowgit_accelerator import run_shadowgit_acceleration_test; \
asyncio.run(run_shadowgit_acceleration_test())"
	@echo "✓ Performance benchmarks complete"

# Hardware capability check
.PHONY: check-hardware
check-hardware:
	@echo "Checking hardware capabilities..."
	@echo "CPU Info:"
	@grep -E "model name|flags" /proc/cpuinfo | head -2
	@echo ""
	@echo "AVX-512 Support:"
	@grep -q "avx512f" /proc/cpuinfo && echo "✓ AVX-512 Foundation supported" || echo "✗ AVX-512 not available"
	@grep -q "avx512bw" /proc/cpuinfo && echo "✓ AVX-512 Byte/Word supported" || echo "✗ AVX-512 BW not available"
	@echo ""
	@echo "NPU Support:"
	@ls /dev/accel/ 2>/dev/null && echo "✓ NPU device nodes found" || echo "✗ NPU devices not detected"
	@echo ""
	@echo "Memory Info:"
	@grep MemTotal /proc/meminfo

# Validation target
.PHONY: validate
validate: $(SHARED_LIB) $(STANDALONE_EXE) check-hardware
	@echo "Validating Shadowgit Phase 3 integration..."
	@echo ""
	@echo "1. Shared Library Check:"
	@ldd $(SHARED_LIB) | grep -E "(not found|error)" && echo "✗ Library dependency issues" || echo "✓ All dependencies resolved"
	@echo ""
	@echo "2. Executable Check:"
	@ldd $(STANDALONE_EXE) | grep -E "(not found|error)" && echo "✗ Executable dependency issues" || echo "✓ All dependencies resolved"
	@echo ""
	@echo "3. Quick Function Test:"
	@timeout 30s ./$(STANDALONE_EXE) 5 >/dev/null 2>&1 && echo "✓ Basic functionality working" || echo "✗ Functionality test failed"

# Install target (for system-wide installation)
.PHONY: install
install: $(SHARED_LIB) $(STANDALONE_EXE)
	@echo "Installing Shadowgit Phase 3 integration..."
	mkdir -p /usr/local/lib/shadowgit
	mkdir -p /usr/local/bin
	cp $(SHARED_LIB) /usr/local/lib/shadowgit/
	cp $(STANDALONE_EXE) /usr/local/bin/shadowgit-phase3
	@echo "✓ Installation complete"
	@echo "  Shared library: /usr/local/lib/shadowgit/$(SHARED_LIB)"
	@echo "  Executable: /usr/local/bin/shadowgit-phase3"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(SHARED_LIB) $(STANDALONE_EXE)
	rm -f *.o *.so *.a core.*
	rm -rf $(BUILD_DIR)
	rm -f /tmp/phase3_test_*.txt
	rm -f shadowgit-acceleration-results.json
	rm -f phase3-integration-results.json
	@echo "✓ Clean complete"

# Deep clean (including logs and test outputs)
.PHONY: distclean
distclean: clean
	@echo "Deep cleaning..."
	rm -rf /tmp/shadowgit_test/
	rm -f *.log *.json
	@echo "✓ Deep clean complete"

# Help target
.PHONY: help
help:
	@echo "Shadowgit Phase 3 Integration Build System"
	@echo "=========================================="
	@echo ""
	@echo "Build Targets:"
	@echo "  all              - Build shared library and standalone executable (default)"
	@echo "  $(SHARED_LIB)   - Build shared library for Python integration"
	@echo "  $(STANDALONE_EXE) - Build standalone C executable"
	@echo "  avx512           - Build with AVX-512 optimizations"
	@echo "  debug            - Build with debug symbols and reduced optimization"
	@echo "  performance      - Build with maximum performance optimizations"
	@echo ""
	@echo "Test Targets:"
	@echo "  test-c           - Run C library integration test"
	@echo "  test-python      - Run Python accelerator test"
	@echo "  test-integration - Run full integration test suite"
	@echo "  benchmark        - Run performance benchmarks"
	@echo ""
	@echo "Utility Targets:"
	@echo "  check-hardware   - Check hardware capabilities (AVX-512, NPU, etc.)"
	@echo "  validate         - Validate build and basic functionality"
	@echo "  install          - Install system-wide"
	@echo "  clean            - Clean build artifacts"
	@echo "  distclean        - Deep clean including test outputs"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Example Usage:"
	@echo "  make              # Basic build"
	@echo "  make avx512       # AVX-512 optimized build"
	@echo "  make test-integration  # Full test suite"
	@echo "  make benchmark    # Performance benchmarks"

# Special targets that don't correspond to files
.PHONY: all clean distclean install help validate check-hardware
.PHONY: test-c test-python test-integration benchmark
.PHONY: debug performance avx512

# Default target when no arguments provided
.DEFAULT_GOAL := all