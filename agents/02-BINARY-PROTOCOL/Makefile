# ULTRA-HYBRID PROTOCOL MAKEFILE
# Manual build configuration for the agent communication system

# Compiler settings
CC := gcc
CXX := g++
AS := gcc
NASM := nasm

# Output directory and targets
BUILD_DIR := build
TARGET_ENHANCED := $(BUILD_DIR)/ultra_hybrid_enhanced
TARGET_TEST := $(BUILD_DIR)/protocol_test

# Source files
SRC_ENHANCED := ultra_hybrid_enhanced.c
SRC_MISSING := missing_functions.c
ASM_SRC := hybrid_protocol_asm.S

# Object files
OBJ_MISSING := $(BUILD_DIR)/missing_functions.o
OBJ_ASM := $(BUILD_DIR)/hybrid_protocol_asm.o

# Base flags
CFLAGS_BASE := -O3 -Wall -Wextra -std=gnu11
LDFLAGS_BASE := -pthread -lm -lrt -ldl

# CPU feature detection
CPU_FLAGS := -march=native -mtune=native

# Feature toggles (can override from command line)
ENABLE_NPU ?= 0
ENABLE_GNA ?= 0
ENABLE_GPU ?= 0
ENABLE_DPDK ?= 0
ENABLE_DEBUG ?= 0
ENABLE_ASAN ?= 0
ENABLE_LTO ?= 1

# Detect available features
HAVE_AVX2 := $(shell grep -q avx2 /proc/cpuinfo && echo 1 || echo 0)
HAVE_AVX512 := $(shell grep -q avx512f /proc/cpuinfo && echo 1 || echo 0)
HAVE_NUMA := $(shell ldconfig -p | grep -q libnuma && echo 1 || echo 0)
HAVE_LIBURING := $(shell pkg-config --exists liburing 2>/dev/null && echo 1 || echo 0)

# Build CPU flags based on detection
ifeq ($(HAVE_AVX2),1)
    CPU_FLAGS += -mavx2
endif

ifeq ($(HAVE_AVX512),1)
    CPU_FLAGS += -mavx512f -mavx512bw -mavx512vl
endif

# Always try to enable these if supported
CPU_FLAGS += -mpclmul -maes

# NUMA support
ifeq ($(HAVE_NUMA),1)
    CFLAGS_BASE += -DHAVE_NUMA=1
    LDFLAGS_BASE += -lnuma
else
    CFLAGS_BASE += -DHAVE_NUMA=0
endif

# io_uring support
ifeq ($(HAVE_LIBURING),1)
    CFLAGS_BASE += $(shell pkg-config --cflags liburing) -DHAVE_LIBURING=1
    LDFLAGS_BASE += $(shell pkg-config --libs liburing)
else
    CFLAGS_BASE += -DHAVE_LIBURING=0
endif

# OpenMP support
CFLAGS_BASE += -fopenmp
LDFLAGS_BASE += -fopenmp

# Feature flags
CFLAGS_BASE += -DENABLE_NPU=$(ENABLE_NPU)
CFLAGS_BASE += -DENABLE_GNA=$(ENABLE_GNA)
CFLAGS_BASE += -DENABLE_GPU=$(ENABLE_GPU)
CFLAGS_BASE += -DENABLE_DPDK=$(ENABLE_DPDK)

# NPU support (OpenVINO)
ifeq ($(ENABLE_NPU),1)
    OPENVINO_ROOT ?= /opt/intel/openvino
    ifneq (,$(wildcard $(OPENVINO_ROOT)/runtime/include))
        CFLAGS_BASE += -I$(OPENVINO_ROOT)/runtime/include
        LDFLAGS_BASE += -L$(OPENVINO_ROOT)/runtime/lib/intel64 -lopenvino
    endif
endif

# GPU support (OpenCL)
ifeq ($(ENABLE_GPU),1)
    OPENCL_FLAGS := $(shell pkg-config --cflags --libs OpenCL 2>/dev/null)
    ifneq ($(OPENCL_FLAGS),)
        CFLAGS_BASE += $(shell pkg-config --cflags OpenCL)
        LDFLAGS_BASE += $(shell pkg-config --libs OpenCL)
    endif
endif

# DPDK support
ifeq ($(ENABLE_DPDK),1)
    DPDK_FLAGS := $(shell pkg-config --cflags --libs libdpdk 2>/dev/null)
    ifneq ($(DPDK_FLAGS),)
        CFLAGS_BASE += $(shell pkg-config --cflags libdpdk)
        LDFLAGS_BASE += $(shell pkg-config --libs libdpdk)
    endif
endif

# Debug build
ifeq ($(ENABLE_DEBUG),1)
    CFLAGS_BASE := -O0 -g3 -DDEBUG -Wall -Wextra -std=gnu11
else
    # Release optimizations
    ifeq ($(ENABLE_LTO),1)
        CFLAGS_BASE += -flto=auto
        LDFLAGS_BASE += -flto=auto
    endif
endif

# Address Sanitizer
ifeq ($(ENABLE_ASAN),1)
    CFLAGS_BASE += -fsanitize=address -fno-omit-frame-pointer
    LDFLAGS_BASE += -fsanitize=address
endif

# Final flags
CFLAGS := $(CFLAGS_BASE) $(CPU_FLAGS)
LDFLAGS := $(LDFLAGS_BASE)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
.PHONY: all
all: $(TARGET_ENHANCED)
	@echo -e "$(GREEN)Build complete!$(NC)"
	@echo "Binaries:"
	@echo "  - $(TARGET_ENHANCED)"

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Build missing functions object
$(OBJ_MISSING): $(SRC_MISSING) | $(BUILD_DIR)
	@echo -e "$(BLUE)Compiling missing functions...$(NC)"
	$(CC) $(CFLAGS) -c $< -o $@

# Build assembly object
$(OBJ_ASM): $(ASM_SRC) | $(BUILD_DIR)
	@echo -e "$(BLUE)Assembling optimized routines...$(NC)"
	$(AS) -c $< -o $@

# Build enhanced version
$(TARGET_ENHANCED): $(SRC_ENHANCED) $(OBJ_MISSING) $(OBJ_ASM) | $(BUILD_DIR)
	@echo -e "$(BLUE)Building enhanced version...$(NC)"
	$(CC) $(CFLAGS) $< $(OBJ_MISSING) $(OBJ_ASM) $(LDFLAGS) -o $@
	@if [ "$(ENABLE_DEBUG)" = "0" ]; then \
		echo -e "$(BLUE)Stripping symbols...$(NC)"; \
		strip $@; \
	fi


# Profile-Guided Optimization build
.PHONY: pgo
pgo: | $(BUILD_DIR)
	@echo -e "$(YELLOW)Building with Profile-Guided Optimization...$(NC)"
	@echo -e "$(BLUE)Step 1: Building profiling version...$(NC)"
	$(CC) $(CFLAGS) -fprofile-generate=$(BUILD_DIR)/pgo \
		$(SRC_ENHANCED) $(OBJ_MISSING) $(OBJ_ASM) $(LDFLAGS) \
		-o $(BUILD_DIR)/ultra_hybrid_prof
	@echo -e "$(BLUE)Step 2: Running profiling workload...$(NC)"
	$(BUILD_DIR)/ultra_hybrid_prof 5 > /dev/null 2>&1
	@echo -e "$(BLUE)Step 3: Building optimized version...$(NC)"
	$(CC) $(CFLAGS) -fprofile-use=$(BUILD_DIR)/pgo -fprofile-correction \
		$(SRC_ENHANCED) $(OBJ_MISSING) $(OBJ_ASM) $(LDFLAGS) \
		-o $(TARGET_ENHANCED)_pgo
	@strip $(TARGET_ENHANCED)_pgo
	@echo -e "$(GREEN)PGO build complete: $(TARGET_ENHANCED)_pgo$(NC)"

# Run tests
.PHONY: test
test: $(TARGET_ENHANCED)
	@echo -e "$(YELLOW)Running tests...$(NC)"
	$(TARGET_ENHANCED) 5

# Benchmark
.PHONY: benchmark
benchmark: $(TARGET_ENHANCED)
	@echo -e "$(YELLOW)Running benchmarks...$(NC)"
	@echo -e "\n$(BLUE)Enhanced version:$(NC)"
	$(TARGET_ENHANCED) 10

# Clean build artifacts
.PHONY: clean
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR)

# Show configuration
.PHONY: info
info:
	@echo -e "$(YELLOW)Build Configuration:$(NC)"
	@echo "  CC: $(CC)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo ""
	@echo -e "$(YELLOW)Detected Features:$(NC)"
	@echo "  AVX2: $(HAVE_AVX2)"
	@echo "  AVX-512: $(HAVE_AVX512)"
	@echo "  NUMA: $(HAVE_NUMA)"
	@echo "  io_uring: $(HAVE_LIBURING)"
	@echo ""
	@echo -e "$(YELLOW)Enabled Features:$(NC)"
	@echo "  NPU: $(ENABLE_NPU)"
	@echo "  GNA: $(ENABLE_GNA)"
	@echo "  GPU: $(ENABLE_GPU)"
	@echo "  DPDK: $(ENABLE_DPDK)"
	@echo "  LTO: $(ENABLE_LTO)"
	@echo "  Debug: $(ENABLE_DEBUG)"
	@echo "  ASAN: $(ENABLE_ASAN)"

# Install (copy to system location)
.PHONY: install
PREFIX ?= /usr/local
install: all
	@echo -e "$(BLUE)Installing to $(PREFIX)/bin...$(NC)"
	install -d $(PREFIX)/bin
	install -m 755 $(TARGET_ENHANCED) $(PREFIX)/bin/
	@echo -e "$(GREEN)Installation complete!$(NC)"

# Uninstall
.PHONY: uninstall
uninstall:
	@echo -e "$(YELLOW)Removing from $(PREFIX)/bin...$(NC)"
	rm -f $(PREFIX)/bin/$(notdir $(TARGET_ENHANCED))

# Help
.PHONY: help
help:
	@echo "Ultra-Hybrid Protocol Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build all versions (default)"
	@echo "  pgo        - Build with Profile-Guided Optimization"
	@echo "  test       - Run tests"
	@echo "  benchmark  - Run benchmarks"
	@echo "  clean      - Remove build artifacts"
	@echo "  info       - Show build configuration"
	@echo "  install    - Install binaries to system"
	@echo "  uninstall  - Remove installed binaries"
	@echo ""
	@echo "Options (set with make OPTION=value):"
	@echo "  ENABLE_NPU=1   - Enable NPU support"
	@echo "  ENABLE_GNA=1   - Enable GNA support"
	@echo "  ENABLE_GPU=1   - Enable GPU support"
	@echo "  ENABLE_DPDK=1  - Enable DPDK support"
	@echo "  ENABLE_DEBUG=1 - Build debug version"
	@echo "  ENABLE_ASAN=1  - Enable Address Sanitizer"
	@echo "  ENABLE_LTO=0   - Disable Link-Time Optimization"
	@echo ""
	@echo "Examples:"
	@echo "  make                     # Build all"
	@echo "  make ENABLE_GPU=1       # Build with GPU support"
	@echo "  make pgo                # Build with PGO"
	@echo "  make clean && make      # Clean rebuild"