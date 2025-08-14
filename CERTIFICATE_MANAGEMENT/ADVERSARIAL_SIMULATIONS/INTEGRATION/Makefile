# Makefile for Integration Components

CC = gcc
CFLAGS = -O3 -march=native -mtune=native -Wall -Wextra -pthread -D_GNU_SOURCE
LDFLAGS = -lpthread -lm

# Targets
TARGETS = simulation_c_bridge

# Source files
C_SOURCES = simulation_c_bridge.c

all: $(TARGETS)

simulation_c_bridge: simulation_c_bridge.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS) *.o

run-bridge: simulation_c_bridge
	./simulation_c_bridge

test: all
	@echo "Testing C bridge compilation..."
	./simulation_c_bridge &
	sleep 2
	pkill -f simulation_c_bridge
	@echo "Test passed!"

.PHONY: all clean run-bridge test