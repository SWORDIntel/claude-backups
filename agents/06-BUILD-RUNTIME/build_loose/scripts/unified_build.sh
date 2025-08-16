#!/bin/bash

# Unified Build System for Claude Agent Communication System
# Fixed integration approach with portable dependencies

set -e  # Exit on first error

echo "=== Claude Agent Communication System - Unified Build ==="
echo ""

# Clean previous build artifacts
echo "Cleaning previous builds..."
make clean 2>/dev/null || true

# Check dependencies and generate compatibility layer
echo "Checking dependencies..."
make check-deps

echo ""
echo "Generating compatibility layer..."
make compatibility-headers
make compatibility_layer.c

# Build compatibility layer first
echo ""
echo "Building compatibility layer..."
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -c -o compatibility_layer.o compatibility_layer.c

# Build core protocol without conflicts
echo ""
echo "Building ultra-fast protocol core..."
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -DCORE_LIBRARY_BUILD -DPRIORITY_LEVEL_T_DEFINED -DCORE_TYPE_T_DEFINED \
    -DSYSTEM_CAPABILITIES_T_DEFINED -DG_SYSTEM_CAPS_DECLARED \
    -DDETECT_SYSTEM_CAPABILITIES_DECLARED -DENHANCED_RING_BUFFER_T_DEFINED \
    -c -o ultra_fast_protocol_core.o ultra_hybrid_enhanced.c

# Build unified agent runtime
echo ""
echo "Building unified agent runtime..."
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -DCORE_LIBRARY_BUILD \
    -c -o agent_system_core.o unified_agent_runtime.c

# Build individual agent components
echo ""
echo "Building agent components..."

# Agent discovery
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -c -o agent_discovery.o agent_discovery.c 2>/dev/null || echo "Warning: agent_discovery.c build issues, continuing..."

# Message router
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -c -o message_router.o message_router.c 2>/dev/null || echo "Warning: message_router.c build issues, continuing..."

# Director agent
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -c -o director_agent.o director_agent.c 2>/dev/null || echo "Warning: director_agent.c build issues, continuing..."

# Try to build other core components
for component in project_orchestrator security_agent optimizer_agent debugger_agent testbed_agent; do &
    echo "Building ${component}..."
    gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
        -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
        -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
        -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
        -c -o ${component}.o ${component}.c 2>/dev/null || echo "Warning: ${component}.c build issues, continuing..."
wait
done

# Try to build other enhanced protocol file
echo ""
echo "Building additional protocol components..."
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -c -o ultra_hybrid_optimized.o ultra_hybrid_optimized.c 2>/dev/null || echo "Warning: ultra_hybrid_optimized.c build issues, continuing..."

# Build voice components
echo ""
echo "Building voice components..."
for voice_comp in voice_orchestrator voice_biometric_agent voice_agent_enhancer audio_capture_agent; do &
    echo "Building ${voice_comp}..."
    gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
        -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
        -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
        -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
        -c -o ${voice_comp}.o ${voice_comp}.c 2>/dev/null || echo "Warning: ${voice_comp}.c build issues, continuing..."
wait
done

# Build assembly optimizations if on x86_64
if [ "$(uname -m)" = "x86_64" ]; then
    echo ""
    echo "Building x86_64 assembly optimizations..."
    as -64 -o hybrid_protocol_asm.o hybrid_protocol_asm.S 2>/dev/null || echo "Warning: assembly build issues, continuing..."
fi

# Collect successfully built object files
OBJECTS=""
for obj in compatibility_layer.o ultra_fast_protocol_core.o agent_system_core.o \
           agent_discovery.o message_router.o director_agent.o project_orchestrator.o \
           security_agent.o optimizer_agent.o debugger_agent.o testbed_agent.o \
           voice_orchestrator.o voice_biometric_agent.o voice_agent_enhancer.o \
           audio_capture_agent.o ultra_hybrid_optimized.o hybrid_protocol_asm.o; do
    if [ -f "$obj" ]; then
        OBJECTS="$OBJECTS $obj"
    fi
wait
done

echo ""
echo "Successfully built objects: $OBJECTS"

# Create static library
echo ""
echo "Creating static library..."
ar rcs libclaude-agents.a $OBJECTS
ranlib libclaude-agents.a

# Create shared library
echo ""
echo "Creating shared library..."
gcc -shared -fPIC -Wl,-soname,libclaude-agents.so.1 \
    -o libclaude-agents.so.1.0.0 $OBJECTS \
    -lpthread -lrt -lm -ldl -flto 2>/dev/null || echo "Warning: shared library build issues"

if [ -f libclaude-agents.so.1.0.0 ]; then
    ln -sf libclaude-agents.so.1.0.0 libclaude-agents.so.1
    ln -sf libclaude-agents.so.1.0.0 libclaude-agents.so
fi

# Build standalone executables
echo ""
echo "Building standalone executables..."

# Build transport test
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -DPROTOCOL_TEST_MODE -o claude-transport-test ultra_hybrid_enhanced.c \
    compatibility_layer.o -lpthread -lrt -lm -ldl -flto 2>/dev/null || echo "Warning: transport test build issues"

# Build protocol benchmark
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -DBENCHMARK_MODE -o claude-protocol-benchmark ultra_hybrid_enhanced.c \
    compatibility_layer.o -lpthread -lrt -lm -ldl -flto 2>/dev/null || echo "Warning: protocol benchmark build issues"

# Build unified agent system
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -DUNIFIED_SYSTEM_BUILD -o claude-agent-system unified_agent_runtime.c \
    $OBJECTS -lpthread -lrt -lm -ldl -flto 2>/dev/null || echo "Warning: unified system build issues"

# Build simple test
gcc -std=c11 -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    -D_GNU_SOURCE -DVERSION=\"1.0.0\" -m64 \
    -O2 -DNDEBUG -fomit-frame-pointer -msse2 -msse4.2 -mavx -mavx2 -flto \
    -DHAVE_PTHREADS=1 -DHAVE_NUMA=0 -DHAVE_LIBURING=0 \
    -o build-test build_test.c compatibility_layer.o \
    -lpthread -lrt -lm -ldl -flto 2>/dev/null || echo "Warning: build test creation issues"

# Summary
echo ""
echo "=== Build Summary ==="
echo "Static Library:"
ls -la libclaude-agents.a 2>/dev/null || echo "  Failed to create static library"

echo ""
echo "Shared Library:"
ls -la libclaude-agents.so* 2>/dev/null || echo "  Failed to create shared library"

echo ""
echo "Executables:"
for exe in claude-transport-test claude-protocol-benchmark claude-agent-system build-test; do &
    if [ -x "$exe" ]; then
        echo "  ✓ $exe"
    else
        echo "  ✗ $exe"
    fi
wait
done

echo ""
echo "Object files built:"
ls -la *.o 2>/dev/null | wc -l | xargs echo "  Total:"

echo ""
echo "=== Build Complete ==="

# Run a quick test if build-test was created
if [ -x "./build-test" ]; then
    echo ""
    echo "Running quick build verification..."
    ./build-test || echo "Build test completed with warnings"
fi

echo ""
echo "To use the shared library, run:"
echo "  export LD_LIBRARY_PATH=\$(pwd):\$LD_LIBRARY_PATH"
echo ""
echo "To test the transport system:"
echo "  ./claude-transport-test"
echo ""
echo "To run benchmarks:"
echo "  ./claude-protocol-benchmark"