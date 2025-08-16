# Claude Agent System Makefile
# Builds all components with standardized names

CC = gcc
CFLAGS = -O3 -march=native -std=c11 -D_GNU_SOURCE -Wall
LDFLAGS = -lpthread -lm -lrt

# Directories
BUILD_DIR = build
BIN_DIR = binary-communications-system
SRC_DIR = src/c

# Main targets
.PHONY: all clean bridge runtime agents

all: bridge runtime agents

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Binary communication bridge
bridge: $(BUILD_DIR) $(BUILD_DIR)/binary_bridge

$(BUILD_DIR)/binary_bridge: $(BIN_DIR)/binary_bridge.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(BIN_DIR) -I$(SRC_DIR) -luring -lnuma || \
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(BIN_DIR) -I$(SRC_DIR) -lpthread -lm -lrt

# Agent runtime
runtime: $(BUILD_DIR) $(BUILD_DIR)/agent_runtime

$(BUILD_DIR)/agent_runtime: $(SRC_DIR)/agent_runtime.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(SRC_DIR)

# Individual agent binaries
agents: $(BUILD_DIR) \
	$(BUILD_DIR)/linter_agent \
	$(BUILD_DIR)/monitor_agent \
	$(BUILD_DIR)/security_agent

$(BUILD_DIR)/linter_agent: $(SRC_DIR)/linter_agent.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(SRC_DIR) -ljson-c

$(BUILD_DIR)/monitor_agent: $(SRC_DIR)/monitor_agent.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(SRC_DIR)

$(BUILD_DIR)/security_agent: $(SRC_DIR)/security_agent.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(SRC_DIR)

# Test binary to verify compilation
test: $(BUILD_DIR) $(BUILD_DIR)/test_system

$(BUILD_DIR)/test_system: $(SRC_DIR)/test_agents.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -I$(SRC_DIR)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Install binaries (optional)
install: all
	sudo cp $(BUILD_DIR)/agent_bridge /usr/local/bin/
	sudo cp $(BUILD_DIR)/agent_runtime /usr/local/bin/