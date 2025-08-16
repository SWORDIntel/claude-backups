# Claude Agent Binary Communication System - CORE Makefile
# Builds ONLY the core binary communication infrastructure
# Agents are modular and loaded separately
# Single unified source directory: src/c/

CC := gcc
AR := ar
STRIP := strip

# Compiler flags
CFLAGS := -std=c11 -D_GNU_SOURCE -Wall -Wextra
CFLAGS += -march=native -mtune=native -pthread
CFLAGS += -I.
# Add json-c includes if available
CFLAGS += $(shell pkg-config --cflags json-c 2>/dev/null || echo "")

# Optimization
ifdef DEBUG
    CFLAGS += -g3 -O0 -DDEBUG
else
    CFLAGS += -O2 -DNDEBUG -fomit-frame-pointer -flto
endif

# AVX detection
HAVE_AVX2 := $(shell grep -q avx2 /proc/cpuinfo && echo 1 || echo 0)
ifeq ($(HAVE_AVX2),1)
    CFLAGS += -mavx2 -mfma
endif

# Linker flags
LDFLAGS := -pthread -lm -lrt -ldl -lssl -lcrypto -lnuma -lrdkafka
# Add liburing if available
LDFLAGS += $(shell pkg-config --libs liburing 2>/dev/null || echo "")
# Add json-c if available
LDFLAGS += $(shell pkg-config --libs json-c 2>/dev/null || echo "")
ifndef DEBUG
    LDFLAGS += -Wl,--gc-sections -Wl,-s
endif

# Directories
BUILD_DIR := ../../build
BIN_DIR := $(BUILD_DIR)/bin
OBJ_DIR := $(BUILD_DIR)/obj

# Create directories
$(shell mkdir -p $(BIN_DIR) $(OBJ_DIR))

# ==============================================================================
# CORE BINARY COMMUNICATION SYSTEM
# ==============================================================================

# Core binary communication files (NO agent implementations)
CORE_SRCS := agent_bridge.c \
             compatibility_layer.c \
             ring_buffer_adapter.c \
             message_router.c \
             agent_discovery.c

# Support/Utility modules (linked into binary for full functionality)
SUPPORT_SRCS := auth_security.c \
                tls_manager.c \
                memory_optimizer.c \
                health_check_endpoints.c \
                prometheus_exporter.c

# Advanced features (optional) - all excluded for LiveCD build
# ADVANCED_SRCS := digital_twin.c neural_architecture_search.c
# Excluded: All advanced modules have issues (AVX-512, main() conflicts, etc)

# Distributed/network components (optional)
NETWORK_SRCS := distributed_network.c \
                distributed_load_balancer.c \
                distributed_service_discovery.c

# Assembly optimization
ASM_SRCS := protocol_asm.S

# AI router infrastructure (optional)
AI_SRCS := ai_router_integration.c \
           ai_enhanced_router.c

# Minimal stub implementations (for linking without full features)
STUB_SRCS := stubs.c

# Convert to object files
CORE_OBJS := $(CORE_SRCS:%.c=$(OBJ_DIR)/%.o)
SUPPORT_OBJS := $(SUPPORT_SRCS:%.c=$(OBJ_DIR)/%.o)
ADVANCED_OBJS := $(ADVANCED_SRCS:%.c=$(OBJ_DIR)/%.o)
NETWORK_OBJS := $(NETWORK_SRCS:%.c=$(OBJ_DIR)/%.o)
ASM_OBJS := $(ASM_SRCS:%.S=$(OBJ_DIR)/%.o)
AI_OBJS := $(AI_SRCS:%.c=$(OBJ_DIR)/%.o)
STUB_OBJS := $(STUB_SRCS:%.c=$(OBJ_DIR)/%.o)

# ==============================================================================
# TARGETS
# ==============================================================================

# Default target - just the core binary
all: agent_bridge

# Main binary communication bridge
agent_bridge: $(BIN_DIR)/agent_bridge
	@echo "[OK] Core binary system built: $<"
	@echo "     Size: $$(du -h $< | cut -f1)"

$(BIN_DIR)/agent_bridge: $(CORE_OBJS) $(SUPPORT_OBJS) $(ASM_OBJS)
	@echo "[LD] Linking agent_bridge with support modules..."
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@
ifndef DEBUG
	@$(STRIP) $@
endif

# Optional: Build with AI router integration
agent_bridge_ai: $(BIN_DIR)/agent_bridge_ai
	@echo "[OK] AI-enhanced binary built"

$(BIN_DIR)/agent_bridge_ai: $(CORE_OBJS) $(SUPPORT_OBJS) $(ASM_OBJS) $(AI_OBJS)
	@echo "[LD] Linking agent_bridge with AI router (no network)..."
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

# Build with ALL optional modules (except Rust and broken network)
agent_bridge_complete: $(BIN_DIR)/agent_bridge_complete
	@echo "[OK] Complete binary system built with all modules"

$(BIN_DIR)/agent_bridge_complete: $(CORE_OBJS) $(SUPPORT_OBJS) $(ASM_OBJS) $(AI_OBJS)
	@echo "[LD] Linking complete agent_bridge (same as AI version on LiveCD)..."
	@$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

# ==============================================================================
# RUST VECTOR ROUTER (Optional)
# ==============================================================================

RUST_LIB := ../rust/target/release/libvector_router.a

rust_vector: $(RUST_LIB)

$(RUST_LIB):
	@echo "[CARGO] Building Rust vector router..."
	@cd ../.. && cargo build --release --manifest-path agents/05-CONFIG/Cargo.toml
	@echo "[OK] Rust vector router built"

# Build with Rust integration
agent_bridge_full: $(CORE_OBJS) $(SUPPORT_OBJS) $(ASM_OBJS) $(AI_OBJS) $(RUST_LIB)
	@echo "[LD] Linking full agent_bridge with Rust vector router..."
	@$(CC) $(CFLAGS) $(CORE_OBJS) $(SUPPORT_OBJS) $(ASM_OBJS) $(AI_OBJS) $(RUST_LIB) $(LDFLAGS) -o $(BIN_DIR)/agent_bridge_full
	@echo "[OK] Full system built with vector router"

# ==============================================================================
# COMPILATION RULES
# ==============================================================================

# C files
$(OBJ_DIR)/%.o: %.c
	@echo "[CC] $<"
	@$(CC) $(CFLAGS) -c $< -o $@

# Assembly files
$(OBJ_DIR)/%.o: %.S
	@echo "[AS] $<"
	@$(CC) $(CFLAGS) -c $< -o $@

# ==============================================================================
# UTILITY TARGETS
# ==============================================================================

clean:
	@echo "[CLEAN] Removing build artifacts..."
	@rm -rf $(BUILD_DIR)

# Test the binary
test: agent_bridge
	@echo "[TEST] Testing agent_bridge..."
	@$(BIN_DIR)/agent_bridge --version || true
	@echo "[TEST] Checking symbols..."
	@nm $(BIN_DIR)/agent_bridge | grep -E "agent_|message_|discovery" | head -5

# Install to system (optional)
install: agent_bridge
	@echo "[INSTALL] Installing to /usr/local/bin..."
	@sudo install -m 755 $(BIN_DIR)/agent_bridge /usr/local/bin/claude-agent-bridge
	@echo "[OK] Installed as claude-agent-bridge"

# Show what would be built
info:
	@echo "=== Build Configuration ==="
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "LDFLAGS: $(LDFLAGS)"
	@echo ""
	@echo "=== Core Files ==="
	@echo "$(CORE_SRCS)" | tr ' ' '\n' | sed 's/^/  - /'
	@echo ""
	@echo "=== Build Targets ==="
	@echo "  agent_bridge      - Core binary communication system"
	@echo "  agent_bridge_ai   - With AI router integration"
	@echo "  agent_bridge_full - With Rust vector router"
	@echo "  clean            - Remove build artifacts"
	@echo "  test             - Test the binary"
	@echo "  info             - Show this information"

# Quick rebuild
rebuild: clean all

.PHONY: all clean test install info rebuild agent_bridge agent_bridge_ai agent_bridge_full rust_vector

# ==============================================================================
# MODULAR AGENT LOADING (Documentation)
# ==============================================================================
# Agents are NOT compiled into the main binary. They are:
# 1. Loaded dynamically at runtime via dlopen() if compiled as .so files
# 2. Communicated with via the binary protocol over sockets/shared memory
# 3. Invoked through the Task tool in Claude Code
#
# To compile an individual agent as a shared library:
#   gcc -shared -fPIC -o agent_name.so agent_name.c
#
# The core binary provides the communication infrastructure that agents use.