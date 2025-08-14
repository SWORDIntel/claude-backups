#!/bin/bash
#
# BUILD SCRIPT FOR ULTRA-HYBRID ENHANCED PROTOCOL
# Automatically detects system capabilities and builds optimal version
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}Ultra-Hybrid Enhanced Protocol Build System${NC}"
echo "============================================"

# Detect system capabilities
printf "\n${YELLOW}Detecting system capabilities...${NC}"

# Check CPU features
CPU_FLAGS=""
SIMD_LEVEL="sse4.2"  # Minimum

if grep -q "avx2" /proc/cpuinfo; then
    CPU_FLAGS="$CPU_FLAGS -mavx2"
    SIMD_LEVEL="avx2"
    printf "${GREEN}✓${NC} AVX2 detected"
fi

if grep -q "avx512f" /proc/cpuinfo; then
    CPU_FLAGS="$CPU_FLAGS -mavx512f -mavx512bw -mavx512vl"
    SIMD_LEVEL="avx512"
    printf "${GREEN}✓${NC} AVX-512 detected"
fi

if grep -q "pclmul" /proc/cpuinfo; then
    CPU_FLAGS="$CPU_FLAGS -mpclmul"
    printf "${GREEN}✓${NC} PCLMUL detected (CRC acceleration)"
fi

if grep -q "aes" /proc/cpuinfo; then
    CPU_FLAGS="$CPU_FLAGS -maes"
    printf "${GREEN}✓${NC} AES-NI detected"
fi

# Check for hybrid architecture
P_CORES=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
TOTAL_CORES=$(nproc)
if [ "$TOTAL_CORES" -gt "$((P_CORES * 2))" ]; then
    printf "${GREEN}✓${NC} Hybrid architecture detected (P+E cores)"
    HYBRID=1
else
    HYBRID=0
fi

# Check for accelerators
ACCEL_FLAGS=""

# NPU check
if lspci 2>/dev/null | grep -qi "neural\|npu"; then
    printf "${GREEN}✓${NC} NPU detected"
    ACCEL_FLAGS="$ACCEL_FLAGS -DENABLE_NPU=1"
    NPU=1
else
    printf "${YELLOW}○${NC} NPU not detected"
    NPU=0
fi

# GNA check
if [ -e /dev/gna0 ] || [ -e /sys/class/misc/gna ]; then
    printf "${GREEN}✓${NC} GNA detected"
    ACCEL_FLAGS="$ACCEL_FLAGS -DENABLE_GNA=1"
    GNA=1
else
    printf "${YELLOW}○${NC} GNA not detected"
    GNA=0
fi

# GPU check
if command -v nvidia-smi &> /dev/null || [ -d /dev/dri ]; then
    printf "${GREEN}✓${NC} GPU detected"
    ACCEL_FLAGS="$ACCEL_FLAGS -DENABLE_GPU=1"
    GPU=1
else
    printf "${YELLOW}○${NC} GPU not detected"
    GPU=0
fi

# DPDK check
if [ -d /dev/hugepages ] && [ -f /usr/include/rte_config.h ]; then
    printf "${GREEN}✓${NC} DPDK available"
    ACCEL_FLAGS="$ACCEL_FLAGS -DENABLE_DPDK=1"
    DPDK=1
else
    printf "${YELLOW}○${NC} DPDK not available"
    DPDK=0
fi

# Check for dependencies
printf "\n${YELLOW}Checking dependencies...${NC}"

check_dependency() {
    if command -v $1 &> /dev/null || [ -f $2 ]; then
        printf "${GREEN}✓${NC} $3 found"
        return 0
    else
        printf "${RED}✗${NC} $3 not found"
        return 1
    fi
}

check_dependency gcc "" "GCC compiler"
check_dependency "" "/usr/include/numa.h" "NUMA library" || {
    echo "  Install with: sudo apt-get install libnuma-dev"
}
check_dependency "" "/usr/include/liburing.h" "io_uring library" || {
    echo "  Install with: sudo apt-get install liburing-dev"
}

# Select compiler
if command -v gcc-12 &> /dev/null; then
    CC=gcc-12
    printf "${GREEN}✓${NC} Using gcc-12"
elif command -v gcc-11 &> /dev/null; then
    CC=gcc-11
    printf "${YELLOW}○${NC} Using gcc-11"
else
    CC=gcc
    printf "${YELLOW}○${NC} Using default gcc"
fi

# Build configurations
printf "\n${YELLOW}Building configurations...${NC}"

# Common flags
COMMON_FLAGS="-O3 -march=native -mtune=native $CPU_FLAGS"
COMMON_FLAGS="$COMMON_FLAGS -pthread -lnuma -lrt -lm"
COMMON_FLAGS="$COMMON_FLAGS -fomit-frame-pointer -funroll-loops"
COMMON_FLAGS="$COMMON_FLAGS -fprefetch-loop-arrays"

# Build targets
TARGETS=""

# 1. Base version (CPU only)
echo -n "Building base version..."
$CC $COMMON_FLAGS \
    ultra_hybrid_protocol.c \
    -o ultra_hybrid_base \
    2>/dev/null && {
    printf " ${GREEN}✓${NC}"
    TARGETS="$TARGETS ultra_hybrid_base"
} || printf " ${RED}✗${NC}"

# 2. Optimized version
echo -n "Building optimized version..."
$CC $COMMON_FLAGS \
    ultra_hybrid_optimized.c \
    -o ultra_hybrid_optimized \
    2>/dev/null && {
    printf " ${GREEN}✓${NC}"
    TARGETS="$TARGETS ultra_hybrid_optimized"
} || printf " ${RED}✗${NC}"

# 3. Enhanced version with accelerators
if [ "$NPU" -eq 1 ] || [ "$GNA" -eq 1 ] || [ "$GPU" -eq 1 ]; then
    echo -n "Building enhanced version with accelerators..."
    
    ENHANCED_LIBS=""
    [ "$NPU" -eq 1 ] && ENHANCED_LIBS="$ENHANCED_LIBS -lopenvino_c"
    [ "$GNA" -eq 1 ] && ENHANCED_LIBS="$ENHANCED_LIBS -lgna2api"
    [ "$GPU" -eq 1 ] && ENHANCED_LIBS="$ENHANCED_LIBS -lOpenCL"
    
    # Check for io_uring
    if pkg-config --exists liburing; then
        ENHANCED_LIBS="$ENHANCED_LIBS -luring"
    fi
    
    $CC $COMMON_FLAGS $ACCEL_FLAGS \
        ultra_hybrid_enhanced.c \
        -o ultra_hybrid_enhanced \
        $ENHANCED_LIBS \
        2>/dev/null && {
        printf " ${GREEN}✓${NC}"
        TARGETS="$TARGETS ultra_hybrid_enhanced"
    } || printf " ${RED}✗${NC}"
fi

# 4. Assembly optimized version
if [ -f hybrid_protocol_asm.S ]; then
    echo -n "Building assembly optimized version..."
    $CC $COMMON_FLAGS \
        ultra_hybrid_protocol.c \
        hybrid_protocol_asm.S \
        -o ultra_hybrid_asm \
        2>/dev/null && {
        printf " ${GREEN}✓${NC}"
        TARGETS="$TARGETS ultra_hybrid_asm"
    } || printf " ${RED}✗${NC}"
fi

# 5. Profile-Guided Optimization
if [ "$1" = "--pgo" ]; then
    printf "\n${YELLOW}Building with Profile-Guided Optimization...${NC}"
    
    # Step 1: Build with profiling
    echo -n "  Stage 1: Building with profiling..."
    $CC $COMMON_FLAGS -fprofile-generate \
        ultra_hybrid_optimized.c \
        -o ultra_hybrid_pgo_train \
        2>/dev/null && printf " ${GREEN}✓${NC}" || {
        printf " ${RED}✗${NC}"
        exit 1
    }
    
    # Step 2: Run training workload
    echo -n "  Stage 2: Running training workload..."
    ./ultra_hybrid_pgo_train 100000 > /dev/null 2>&1 && \
        printf " ${GREEN}✓${NC}" || printf " ${RED}✗${NC}"
    
    # Step 3: Build with profile
    echo -n "  Stage 3: Building optimized binary..."
    $CC $COMMON_FLAGS -fprofile-use -fprofile-correction \
        ultra_hybrid_optimized.c \
        -o ultra_hybrid_pgo \
        2>/dev/null && {
        printf " ${GREEN}✓${NC}"
        TARGETS="$TARGETS ultra_hybrid_pgo"
    } || printf " ${RED}✗${NC}"
    
    # Cleanup
    rm -f ultra_hybrid_pgo_train *.gcda *.gcno
fi

# Create symlink to best version
printf "\n${YELLOW}Selecting best version...${NC}"

if [ -f ultra_hybrid_enhanced ]; then
    BEST="ultra_hybrid_enhanced"
    printf "${GREEN}✓${NC} Enhanced version with accelerators"
elif [ -f ultra_hybrid_pgo ]; then
    BEST="ultra_hybrid_pgo"
    printf "${GREEN}✓${NC} Profile-guided optimized version"
elif [ -f ultra_hybrid_optimized ]; then
    BEST="ultra_hybrid_optimized"
    printf "${GREEN}✓${NC} Optimized version"
else
    BEST="ultra_hybrid_base"
    printf "${YELLOW}○${NC} Base version"
fi

ln -sf $BEST ultra_hybrid_protocol
printf "Created symlink: ultra_hybrid_protocol -> $BEST"

# Generate configuration file
printf "\n${YELLOW}Generating configuration...${NC}"

cat > protocol_config.json << EOF
{
    "system": {
        "simd_level": "$SIMD_LEVEL",
        "hybrid_arch": $HYBRID,
        "p_cores": $P_CORES,
        "total_cores": $TOTAL_CORES,
        "accelerators": {
            "npu": $NPU,
            "gna": $GNA,
            "gpu": $GPU,
            "dpdk": $DPDK
        }
    },
    "runtime": {
        "default_binary": "$BEST",
        "available_binaries": [
$(for t in $TARGETS; do echo "            \"$t\""; done | sed '$ s/$//')
        ]
    },
    "optimization": {
        "compiler": "$CC",
        "flags": "$COMMON_FLAGS"
    }
}
EOF

printf "${GREEN}✓${NC} Configuration saved to protocol_config.json"

# Run quick benchmark
if [ "$1" != "--no-bench" ]; then
    printf "\n${YELLOW}Running quick benchmark...${NC}"
    echo "----------------------------------------"
    ./ultra_hybrid_protocol 10000 | tail -10
    echo "----------------------------------------"
fi

# Summary
printf "\n${GREEN}Build Complete!${NC}"
printf "Binaries created: $TARGETS"
printf "Default binary: ${GREEN}ultra_hybrid_protocol${NC} -> $BEST"
echo ""
echo "Usage:"
echo "  ./ultra_hybrid_protocol [iterations]"
echo ""
echo "Options:"
echo "  --pgo           Build with profile-guided optimization"
echo "  --no-bench      Skip benchmark after build"
echo ""
echo "To rebuild with different options:"
echo "  ./build_enhanced.sh --pgo"