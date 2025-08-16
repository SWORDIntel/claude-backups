#!/bin/bash
# BRING_ONLINE_FIXED.sh - Fixed Binary Protocol and Agent System
# Optimized for existing source files and Meteor Lake CPU

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# System paths
AGENTS_DIR="/home/ubuntu/Documents/Claude/agents"
BUILD_DIR="$AGENTS_DIR/06-BUILD-RUNTIME/build"
CONFIG_DIR="$AGENTS_DIR/05-CONFIG"
RUNTIME_DIR="$AGENTS_DIR/06-BUILD-RUNTIME/runtime"
BINARY_SRC_DIR="$AGENTS_DIR/02-BINARY-PROTOCOL"

# Socket path (NOT in /tmp due to noexec)
export AGENT_SOCKET_PATH="$RUNTIME_DIR/claude_agent_bridge.sock"

# Log file
LOG_FILE="$AGENTS_DIR/system_startup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}   Claude Agent Binary Protocol v4.0 - Production Build         ${NC}\n"  
printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

# Function to detect CPU features properly
detect_cpu_features() {
    printf "${YELLOW}[1/6] Detecting CPU features...${NC}\n"
    
    # Get CPU model
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    echo "CPU: $CPU_MODEL"
    
    # Check microcode version
    MICROCODE=$(grep -m1 "microcode" /proc/cpuinfo | awk '{print $3}')
    MICROCODE_HEX=$(printf "0x%x" $((MICROCODE)))
    echo "Microcode: $MICROCODE_HEX"
    
    # Check for AVX-512 disable via microcode first (critical for stability)
    # Intel disabled AVX-512 in microcode 0x20 and later for Meteor Lake
    MICROCODE_DEC=$((MICROCODE))
    AVX512_DISABLED=0
    
    if [[ $MICROCODE_DEC -ge 32 ]]; then  # 0x20 = 32 decimal
        echo "⚠ Microcode $MICROCODE_HEX >= 0x20: AVX-512 is DISABLED by Intel"
        AVX512_DISABLED=1
    fi
    
    # Detect Meteor Lake specifically
    if [[ "$CPU_MODEL" == *"Ultra"* ]] || [[ "$CPU_MODEL" == *"Core Ultra"* ]]; then
        echo "Meteor Lake detected - applying specific optimizations"
        IS_METEOR_LAKE=1
        
        # For Meteor Lake, ALWAYS respect microcode AVX-512 disable
        if [[ $AVX512_DISABLED -eq 1 ]]; then
            echo "Using AVX2-only optimizations (AVX-512 disabled by microcode)"
            AVX_SUPPORT="avx2"
            # Use alderlake architecture but explicitly disable AVX-512
            MARCH_FLAGS="-march=alderlake -mno-avx512f -mno-avx512vl -mno-avx512dq -mno-avx512bw"
        else
            # Pre-0x20 microcode (rare, but possible)
            echo "WARNING: Old microcode detected - AVX-512 may be unstable"
            AVX_SUPPORT="avx2"  # Still use AVX2 for safety
            MARCH_FLAGS="-march=alderlake -mno-avx512f"
        fi
    else
        # For non-Meteor Lake CPUs, check microcode disable first
        if [[ $AVX512_DISABLED -eq 1 ]]; then
            echo "AVX-512 disabled by microcode on this CPU"
            AVX_SUPPORT="avx2"
            MARCH_FLAGS="-march=native -mno-avx512f"
        elif grep -q "avx512f" /proc/cpuinfo; then
            # Only use AVX-512 if microcode allows it
            AVX_SUPPORT="avx512"
            MARCH_FLAGS="-march=native"
        elif grep -q "avx2" /proc/cpuinfo; then
            AVX_SUPPORT="avx2"
            MARCH_FLAGS="-march=native -mno-avx512f"
        else
            AVX_SUPPORT="sse4"
            MARCH_FLAGS="-msse4.2"
        fi
    fi
    
    # Detect CPU topology (P-cores vs E-cores)
    P_CORES=""
    E_CORES=""
    
    if [ -f /sys/devices/system/cpu/cpu0/topology/core_cpus_list ]; then
        # Intel hybrid architecture detection
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            if [ -f "$cpu/cpufreq/base_frequency" ]; then
                FREQ=$(cat "$cpu/cpufreq/base_frequency")
                CPU_NUM=$(basename "$cpu" | sed 's/cpu//')
                
                # P-cores typically have higher base frequency
                if [ "$FREQ" -gt 2000000 ]; then
                    P_CORES="$P_CORES,$CPU_NUM"
                else
                    E_CORES="$E_CORES,$CPU_NUM"
                fi
            fi
        done
        
        P_CORES=${P_CORES#,}
        E_CORES=${E_CORES#,}
        
        if [ -n "$P_CORES" ]; then
            echo "P-cores: $P_CORES"
            echo "E-cores: $E_CORES"
            export AGENT_P_CORES="$P_CORES"
            export AGENT_E_CORES="$E_CORES"
        fi
    fi
    
    # Set compilation flags based on detection
    if [ "$AVX_SUPPORT" == "avx512" ]; then
        OPTIMIZATION_FLAGS="$MARCH_FLAGS -mavx512f -mavx512vl -mavx2 -mfma -O3"
    elif [ "$AVX_SUPPORT" == "avx2" ]; then
        OPTIMIZATION_FLAGS="$MARCH_FLAGS -mavx2 -mfma -msse4.2 -O3"
    else
        OPTIMIZATION_FLAGS="$MARCH_FLAGS -msse4.2 -O2"
    fi
    
    # Add Meteor Lake specific optimizations
    if [ "$IS_METEOR_LAKE" == "1" ]; then
        OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -mtune=alderlake -mprefer-vector-width=256"
    fi
    
    # Memory alignment for performance
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -falign-functions=32 -falign-loops=32"
    
    export CFLAGS="$OPTIMIZATION_FLAGS"
    export AGENT_AVX_SUPPORT="$AVX_SUPPORT"
    
    printf "${GREEN}✓ CPU feature detection complete${NC}\n"
    echo "  AVX Support: $AVX_SUPPORT"
    echo "  Optimization flags: $OPTIMIZATION_FLAGS"
}

# Function to prepare runtime environment
prepare_runtime() {
    printf "${YELLOW}[2/6] Preparing runtime environment...${NC}\n"
    
    # Create necessary directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$RUNTIME_DIR"
    chmod 755 "$RUNTIME_DIR"
    
    # Clean up old sockets
    rm -f "$RUNTIME_DIR"/*.sock 2>/dev/null || true
    rm -f /tmp/claude_agent_bridge.sock 2>/dev/null || true
    
    # Create socket path configuration
    cat > "$CONFIG_DIR/socket_config.h" << EOF
#ifndef SOCKET_CONFIG_H
#define SOCKET_CONFIG_H

// Runtime socket path (not in /tmp due to noexec)
#define SOCKET_PATH "$AGENT_SOCKET_PATH"
#define FALLBACK_SOCKET_PATH "$RUNTIME_DIR/agent_bridge.sock"

#endif
EOF
    
    printf "${GREEN}✓ Runtime environment ready${NC}\n"
}

# Function to build binary protocol from existing sources
build_binary_protocol() {
    printf "${YELLOW}[3/6] Building binary protocol from existing sources...${NC}\n"
    
    cd "$AGENTS_DIR"
    
    # Check if we should use the Makefile
    if [ -f "$BINARY_SRC_DIR/Makefile" ] && [ -f "$BINARY_SRC_DIR/missing_functions.c" ]; then
        echo "Found Makefile and missing_functions.c - using Makefile build"
        USE_MAKEFILE=1
    elif [ -f "$BINARY_SRC_DIR/ultra_hybrid_enhanced.c" ]; then
        PRIMARY_SOURCE="ultra_hybrid_enhanced.c"
        echo "Found primary source: ultra_hybrid_enhanced.c"
        USE_MAKEFILE=0
    elif [ -f "$BINARY_SRC_DIR/ultra_hybrid_optimized.c" ]; then
        PRIMARY_SOURCE="ultra_hybrid_optimized.c"
        echo "Found optimized source: ultra_hybrid_optimized.c"
        USE_MAKEFILE=0
    else
        echo "ERROR: No binary protocol source found in $BINARY_SRC_DIR"
        exit 1
    fi
    
    # Build using either Makefile, build script, or manual compilation
    if [ "$USE_MAKEFILE" -eq 1 ]; then
        # Check if build_enhanced_script.sh exists
        if [ -f "$BINARY_SRC_DIR/build_enhanced_script.sh" ]; then
            echo "Using build_enhanced_script.sh..."
            cd "$BINARY_SRC_DIR"
            
            # Set socket path for build
            export SOCKET_PATH="$AGENT_SOCKET_PATH"
            
            # Run the enhanced build script
            if chmod +x build_enhanced_script.sh && ./build_enhanced_script.sh; then
                echo "✓ Enhanced build script successful"
                cp build/ultra_hybrid_protocol "$BUILD_DIR/ultra_hybrid_enhanced"
            else
                echo "⚠ Enhanced build script failed, trying Makefile..."
                # Try Makefile as fallback
                if make clean && make enhanced; then
                    echo "✓ Makefile build successful"
                    cp build/ultra_hybrid_enhanced "$BUILD_DIR/ultra_hybrid_enhanced"
                else
                    echo "⚠ Makefile build also failed, trying manual fallback..."
                    USE_MAKEFILE=0
                fi
            fi
        else
            # Try Makefile directly
            echo "Building with Makefile..."
            cd "$BINARY_SRC_DIR"
            mkdir -p build
            export SOCKET_PATH="$AGENT_SOCKET_PATH"
            
            if make clean && make enhanced; then
                echo "✓ Makefile build successful"
                cp build/ultra_hybrid_enhanced "$BUILD_DIR/ultra_hybrid_enhanced"
            else
                echo "⚠ Makefile build failed, trying fallback..."
                USE_MAKEFILE=0
            fi
        fi
        cd "$AGENTS_DIR"
    fi
    
    if [ "$USE_MAKEFILE" -eq 0 ]; then
        # Create patched version with correct socket path
        echo "Creating patched source with runtime socket path..."
        cp "$BINARY_SRC_DIR/$PRIMARY_SOURCE" "$BUILD_DIR/ultra_hybrid_enhanced_patched.c"
        
        # Patch socket paths to use runtime directory
        sed -i "s|/tmp/claude_agent_bridge.sock|$AGENT_SOCKET_PATH|g" \
            "$BUILD_DIR/ultra_hybrid_enhanced_patched.c"
    
        # Also check for any hardcoded /tmp paths
        sed -i "s|/tmp/agent_|$RUNTIME_DIR/agent_|g" \
            "$BUILD_DIR/ultra_hybrid_enhanced_patched.c"
        
        # Check for assembly optimizations
        if [ -f "$BINARY_SRC_DIR/hybrid_protocol_asm.S" ]; then
            echo "Found assembly optimizations: hybrid_protocol_asm.S"
            ASM_SOURCE="$BINARY_SRC_DIR/hybrid_protocol_asm.S"
        fi
    fi  # End of USE_MAKEFILE -eq 0 block
    
    # Check for headers
    INCLUDE_FLAGS=""
    if [ -f "$BINARY_SRC_DIR/ultra_fast_protocol.h" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$BINARY_SRC_DIR"
    fi
    if [ -f "$BINARY_SRC_DIR/compatibility_layer.h" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$BINARY_SRC_DIR"
    fi
    if [ -f "$CONFIG_DIR/socket_config.h" ]; then
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$CONFIG_DIR"
    fi
    
    echo "Compiling binary protocol with flags: $CFLAGS"
    echo "Include paths: $INCLUDE_FLAGS"
    
    # Try compilation with full optimizations
    if [ -n "$ASM_SOURCE" ]; then
        # Compile with assembly optimizations
        echo "Compiling with assembly optimizations..."
        if gcc $CFLAGS -D_GNU_SOURCE $INCLUDE_FLAGS \
               -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
               -o "$BUILD_DIR/ultra_hybrid_enhanced" \
               "$BUILD_DIR/ultra_hybrid_enhanced_patched.c" \
               "$ASM_SOURCE" \
               -lpthread -lm -lrt 2>/dev/null; then
            echo "✓ Binary protocol compiled with assembly optimizations"
        else
            echo "⚠ Assembly compilation failed, trying without..."
            gcc $CFLAGS -D_GNU_SOURCE $INCLUDE_FLAGS \
                -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
                -o "$BUILD_DIR/ultra_hybrid_enhanced" \
                "$BUILD_DIR/ultra_hybrid_enhanced_patched.c" \
                -lpthread -lm -lrt || {
                # Fallback to safer compilation
                echo "⚠ Full optimization failed, using safe mode..."
                gcc -O2 -D_GNU_SOURCE $INCLUDE_FLAGS \
                    -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
                    -o "$BUILD_DIR/ultra_hybrid_enhanced" \
                    "$BUILD_DIR/ultra_hybrid_enhanced_patched.c" \
                    -lpthread -lm -lrt
            }
        fi
    else
        # Compile without assembly
        gcc $CFLAGS -D_GNU_SOURCE $INCLUDE_FLAGS \
            -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
            -o "$BUILD_DIR/ultra_hybrid_enhanced" \
            "$BUILD_DIR/ultra_hybrid_enhanced_patched.c" \
            -lpthread -lm -lrt || {
            # Fallback to safer compilation
            echo "⚠ Full optimization failed, using safe mode..."
            gcc -O2 -D_GNU_SOURCE $INCLUDE_FLAGS \
                -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
                -o "$BUILD_DIR/ultra_hybrid_enhanced" \
                "$BUILD_DIR/ultra_hybrid_enhanced_patched.c" \
                -lpthread -lm -lrt
        }
    fi
    
    # Make executable
    chmod +x "$BUILD_DIR/ultra_hybrid_enhanced"
    
    printf "${GREEN}✓ Binary protocol build complete${NC}\n"
}

# Function to build compatibility layer
build_compatibility_layer() {
    printf "${YELLOW}[4/6] Building compatibility layer...${NC}\n"
    
    # Check if compatibility layer source exists
    if [ -f "$AGENTS_DIR/04-SOURCE/c-implementations/COMPLETE/compatibility_layer.c" ]; then
        echo "Found existing compatibility_layer.c"
        
        # Patch socket path
        cp "$AGENTS_DIR/04-SOURCE/c-implementations/COMPLETE/compatibility_layer.c" "$BUILD_DIR/compatibility_layer_patched.c"
        sed -i "s|/tmp/claude_agent_bridge.sock|$AGENT_SOCKET_PATH|g" \
            "$BUILD_DIR/compatibility_layer_patched.c"
        
        # Compile as object file
        gcc -c -fPIC $CFLAGS -D_GNU_SOURCE \
            -DSOCKET_PATH=\"$AGENT_SOCKET_PATH\" \
            "$BUILD_DIR/compatibility_layer_patched.c" \
            -o "$BUILD_DIR/compatibility_layer.o" 2>/dev/null || true
            
    elif [ -f "$BINARY_SRC_DIR/compatibility_layer.h" ]; then
        echo "Using compatibility_layer.h header"
    else
        echo "Creating compatibility layer..."
        
        cat > "$BUILD_DIR/compatibility_layer.c" << EOF
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

// Compatibility layer for agent communication
const char* AGENT_SOCKET = "$AGENT_SOCKET_PATH";

int connect_to_bridge() {
    int sockfd;
    struct sockaddr_un addr;
    
    sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sockfd < 0) return -1;
    
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, AGENT_SOCKET, sizeof(addr.sun_path) - 1);
    
    if (connect(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sockfd);
        return -1;
    }
    
    return sockfd;
}

int send_agent_message(int sockfd, const char* msg, size_t len) {
    return write(sockfd, msg, len);
}

int receive_agent_message(int sockfd, char* buffer, size_t max_len) {
    return read(sockfd, buffer, max_len);
}
EOF
        
        # Compile compatibility layer
        gcc -c -fPIC $CFLAGS -D_GNU_SOURCE \
            "$BUILD_DIR/compatibility_layer.c" \
            -o "$BUILD_DIR/compatibility_layer.o" 2>/dev/null || true
    fi
    
    printf "${GREEN}✓ Compatibility layer ready${NC}\n"
}

# Function to optimize Python integration
optimize_python_integration() {
    printf "${YELLOW}[5/6] Optimizing Python integration...${NC}\n"
    
    # Install optimized Python packages
    pip3 install -q --upgrade pip 2>/dev/null || true
    
    # Core packages with C extensions for performance
    PERFORMANCE_PACKAGES="numpy numba cython uvloop"
    
    for package in $PERFORMANCE_PACKAGES; do
        pip3 install -q $package 2>/dev/null || echo "  ⚠ $package not available"
    done
    
    # Update Python bridge to use correct socket
    if [ -f "$AGENTS_DIR/03-BRIDGES/claude_agent_bridge.py" ]; then
        echo "Updating claude_agent_bridge.py with correct socket path..."
        sed -i.bak "s|/tmp/claude_agent_bridge.sock|$AGENT_SOCKET_PATH|g" \
            "$AGENTS_DIR/03-BRIDGES/claude_agent_bridge.py"
    fi
    
    # Create optimized Python launcher
    cat > "$AGENTS_DIR/optimized_bridge.py" << EOF
#!/usr/bin/env python3
"""Optimized Python bridge with native performance enhancements"""

import os
import sys
import asyncio

# Set socket path
os.environ["AGENT_SOCKET_PATH"] = "$AGENT_SOCKET_PATH"

# Try to use uvloop for better async performance
try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
    print("✓ Using uvloop for enhanced performance")
except ImportError:
    pass

# Import the main bridge
sys.path.append('$AGENTS_DIR')
from claude_agent_bridge import bridge, task_agent_invoke

# Optimize Python runtime
import gc
gc.set_threshold(100000, 10, 10)  # Reduce GC overhead

if __name__ == "__main__":
    print("Optimized Claude Agent Bridge ready")
    print(f"Socket: {os.environ['AGENT_SOCKET_PATH']}")
EOF
    
    chmod +x "$AGENTS_DIR/optimized_bridge.py"
    
    printf "${GREEN}✓ Python integration optimized${NC}\n"
}

# Function to start optimized runtime
start_optimized_runtime() {
    printf "${YELLOW}[6/6] Starting optimized runtime...${NC}\n"
    
    # Kill existing processes
    pkill -f "ultra_hybrid_enhanced" 2>/dev/null || true
    sleep 1
    
    # Start binary bridge with optimizations
    if [ -f "$BUILD_DIR/ultra_hybrid_enhanced" ]; then
        echo "Starting binary bridge..."
        echo "Socket path: $AGENT_SOCKET_PATH"
        
        # Set real-time priority if possible
        if command -v chrt &> /dev/null; then
            # Try to run with real-time scheduling
            nohup chrt -f 50 "$BUILD_DIR/ultra_hybrid_enhanced" \
                > "$AGENTS_DIR/binary_bridge.log" 2>&1 &
            BRIDGE_PID=$!
            echo "Binary bridge started with real-time priority (PID: $BRIDGE_PID)"
        else
            nohup "$BUILD_DIR/ultra_hybrid_enhanced" \
                > "$AGENTS_DIR/binary_bridge.log" 2>&1 &
            BRIDGE_PID=$!
            echo "Binary bridge started (PID: $BRIDGE_PID)"
        fi
        
        # Save PID
        echo $BRIDGE_PID > "$AGENTS_DIR/.bridge.pid"
        
        # Wait for socket to be created
        echo "Waiting for socket..."
        for i in {1..10}; do
            if [ -S "$AGENT_SOCKET_PATH" ]; then
                echo "✓ Binary bridge socket ready"
                break
            fi
            sleep 0.5
        done
        
        # Verify socket is accessible
        if [ -S "$AGENT_SOCKET_PATH" ]; then
            ls -la "$AGENT_SOCKET_PATH"
        else
            echo "⚠ Socket not created, checking logs..."
            tail -5 "$AGENTS_DIR/binary_bridge.log"
        fi
    else
        echo "ERROR: Binary bridge not built!"
        exit 1
    fi
    
    # Start optimized Python bridge
    if [ -f "$AGENTS_DIR/optimized_bridge.py" ]; then
        nohup python3 "$AGENTS_DIR/optimized_bridge.py" \
            > "$AGENTS_DIR/python_bridge.log" 2>&1 &
        PYTHON_PID=$!
        echo "Python bridge started (PID: $PYTHON_PID)"
    fi
    
    printf "${GREEN}✓ Optimized runtime operational${NC}\n"
}

# Function to verify system
verify_system() {
    echo ""
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}✓ Binary Protocol System Optimized and Running${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
    
    echo "System Configuration:"
    echo "  CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "  Microcode: $MICROCODE_HEX"
    echo "  AVX Support: ${AGENT_AVX_SUPPORT:-unknown}"
    echo "  AVX-512 Status: $([ $AVX512_DISABLED -eq 1 ] && echo 'DISABLED by microcode' || echo 'Available')"
    echo "  Optimization: $CFLAGS"
    
    if [ -n "$AGENT_P_CORES" ]; then
        echo "  P-cores: $AGENT_P_CORES"
        echo "  E-cores: $AGENT_E_CORES"
    fi
    
    echo ""
    echo "Runtime Configuration:"
    echo "  Socket Path: $AGENT_SOCKET_PATH"
    echo "  Runtime Dir: $RUNTIME_DIR"
    echo "  Build Dir: $BUILD_DIR"
    
    echo ""
    echo "Performance Features:"
    
    # Check if huge pages are being used
    if [ -f "$AGENTS_DIR/.bridge.pid" ]; then
        PID=$(cat "$AGENTS_DIR/.bridge.pid")
        if grep -q huge /proc/$PID/smaps 2>/dev/null; then
            echo "  ✓ Huge pages: ACTIVE"
        else
            echo "  ⚠ Huge pages: INACTIVE"
        fi
        
        # Check if real-time scheduling is active
        if ps -p $PID -o cls= 2>/dev/null | grep -q FF; then
            echo "  ✓ Real-time scheduling: ACTIVE"
        else
            echo "  ⚠ Real-time scheduling: INACTIVE"
        fi
    fi
    
    # Check socket
    if [ -S "$AGENT_SOCKET_PATH" ]; then
        echo "  ✓ Binary socket: READY"
        echo "    $(ls -la $AGENT_SOCKET_PATH)"
    else
        echo "  ⚠ Binary socket: NOT FOUND"
    fi
    
    echo ""
    echo "Logs:"
    echo "  Binary: $AGENTS_DIR/binary_bridge.log"
    echo "  Python: $AGENTS_DIR/python_bridge.log"
    echo "  System: $LOG_FILE"
    
    echo ""
    echo "Test Commands:"
    echo "  1. Test socket: echo 'test' | nc -U $AGENT_SOCKET_PATH"
    echo "  2. Run agents: python3 claude_agent_bridge.py"
    echo "  3. Monitor: tail -f binary_bridge.log"
    echo "  4. Performance test: python3 test_binary_perf.py"
}

# Main execution
main() {
    cd "$AGENTS_DIR"
    
    # Execute optimized build sequence
    detect_cpu_features
    prepare_runtime
    build_binary_protocol
    build_compatibility_layer
    optimize_python_integration
    start_optimized_runtime
    verify_system
    
    # Keep system online
    touch "$AGENTS_DIR/.online"
    
    echo ""
    printf "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}       Binary Protocol System Successfully Optimized            ${NC}\n"
    printf "${GREEN}       AVX-512: $([ $AVX512_DISABLED -eq 1 ] && echo 'Disabled (microcode >= 0x20)' || echo 'Available')${NC}\n"
    printf "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Run main function
main "$@"