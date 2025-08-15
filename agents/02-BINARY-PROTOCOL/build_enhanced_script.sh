#!/bin/bash

# ULTRA-HYBRID PROTOCOL BUILD SCRIPT
# Automatic capability detection and optimization

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build configuration
BUILD_DIR="build"
OUTPUT_NAME="ultra_hybrid_protocol"
CC="${CC:-gcc}"
CXX="${CXX:-g++}"
NASM="${NASM:-nasm}"

# Default flags
CFLAGS="-O3 -march=native -mtune=native -Wall -Wextra"
LDFLAGS="-pthread -lm -lrt -ldl"

# Feature flags
ENABLE_NPU=0
ENABLE_GNA=0
ENABLE_GPU=0
ENABLE_DPDK=0
ENABLE_PGO=0
ENABLE_LTO=1
ENABLE_ASAN=0
ENABLE_DEBUG=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --enable-npu)
            ENABLE_NPU=1
            shift
            ;;
        --enable-gna)
            ENABLE_GNA=1
            shift
            ;;
        --enable-gpu)
            ENABLE_GPU=1
            shift
            ;;
        --enable-dpdk)
            ENABLE_DPDK=1
            shift
            ;;
        --pgo)
            ENABLE_PGO=1
            shift
            ;;
        --debug)
            ENABLE_DEBUG=1
            CFLAGS="-O0 -g3 -DDEBUG"
            shift
            ;;
        --asan)
            ENABLE_ASAN=1
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --enable-npu    Enable NPU acceleration (requires OpenVINO)"
            echo "  --enable-gna    Enable GNA support"
            echo "  --enable-gpu    Enable GPU offload (requires OpenCL)"
            echo "  --enable-dpdk   Enable DPDK support"
            echo "  --pgo           Build with Profile-Guided Optimization"
            echo "  --debug         Build debug version"
            echo "  --asan          Enable Address Sanitizer"
            echo "  --help          Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  ULTRA-HYBRID PROTOCOL BUILD${NC}"
echo -e "${BLUE}====================================${NC}"

# Create build directory
mkdir -p $BUILD_DIR

# Detect system capabilities
echo -e "\n${YELLOW}Detecting system capabilities...${NC}"

# Check CPU features with microcode awareness
detect_cpu_features() {
    local features=""
    local microcode_version=0
    local avx512_available=false
    
    # Get microcode version
    if [ -r /proc/cpuinfo ]; then
        microcode_version=$(grep "microcode" /proc/cpuinfo | head -1 | awk '{print $3}')
        if [ -n "$microcode_version" ]; then
            # Convert to hex if needed
            microcode_hex=$(printf "0x%x" $microcode_version 2>/dev/null || echo $microcode_version)
            echo -e "  ${BLUE}ℹ${NC} Microcode version: $microcode_hex"
        fi
    fi
    
    if grep -q "avx2" /proc/cpuinfo; then
        features="$features -mavx2"
        echo -e "  ${GREEN}✓${NC} AVX2 detected"
    fi
    
    # Check AVX-512 with microcode awareness
    if grep -q "avx512f" /proc/cpuinfo; then
        # Check if microcode has disabled AVX-512
        if [ -n "$microcode_version" ]; then
            # Convert microcode to decimal for comparison
            mc_dec=$(printf "%d" $microcode_version 2>/dev/null || echo 0)
            
            # Check if microcode is >= 0x20 (32 in decimal)
            if [ $mc_dec -ge 32 ]; then
                echo -e "  ${YELLOW}⚠${NC} AVX-512 disabled by microcode (>= 0x20)"
                echo -e "    ${YELLOW}→${NC} P-cores will use AVX2 instead"
                avx512_available=false
            else
                features="$features -mavx512f -mavx512bw -mavx512vl"
                echo -e "  ${GREEN}✓${NC} AVX-512 available (microcode < 0x20)"
                avx512_available=true
            fi
        else
            # Can't determine microcode, be conservative
            echo -e "  ${YELLOW}⚠${NC} AVX-512 detected but microcode unknown"
            echo -e "    ${YELLOW}→${NC} Disabling AVX-512 for safety"
            avx512_available=false
        fi
        
        # Define a flag for the code to know AVX-512 status
        if [ "$avx512_available" = true ]; then
            features="$features -DAVX512_ENABLED=1"
        else
            features="$features -DAVX512_ENABLED=0"
        fi
    fi
    
    if grep -q "pclmulqdq" /proc/cpuinfo; then
        features="$features -mpclmul"
        echo -e "  ${GREEN}✓${NC} PCLMULQDQ detected"
    fi
    
    if grep -q "aes" /proc/cpuinfo; then
        features="$features -maes"
        echo -e "  ${GREEN}✓${NC} AES-NI detected"
    fi
    
    echo "$features"
}

CPU_FLAGS=$(detect_cpu_features)
CFLAGS="$CFLAGS $CPU_FLAGS"

# Check for NUMA support
if command -v numactl &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} NUMA support detected"
    LDFLAGS="$LDFLAGS -lnuma"
    CFLAGS="$CFLAGS -DHAVE_NUMA=1"
else
    echo -e "  ${YELLOW}⚠${NC} NUMA not available"
    CFLAGS="$CFLAGS -DHAVE_NUMA=0"
fi

# Check for io_uring
if pkg-config --exists liburing 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} io_uring detected"
    CFLAGS="$CFLAGS $(pkg-config --cflags liburing) -DHAVE_LIBURING=1"
    LDFLAGS="$LDFLAGS $(pkg-config --libs liburing)"
else
    echo -e "  ${YELLOW}⚠${NC} io_uring not available (install liburing-dev)"
    CFLAGS="$CFLAGS -DHAVE_LIBURING=0"
fi

# Check for OpenMP
if echo | $CC -fopenmp -E - &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} OpenMP support detected"
    CFLAGS="$CFLAGS -fopenmp"
    LDFLAGS="$LDFLAGS -fopenmp"
fi

# Check for NPU (OpenVINO)
if [ $ENABLE_NPU -eq 1 ]; then
    if [ -d "/opt/intel/openvino" ]; then
        echo -e "  ${GREEN}✓${NC} OpenVINO detected"
        source /opt/intel/openvino/bin/setupvars.sh
        CFLAGS="$CFLAGS -DENABLE_NPU=1"
        LDFLAGS="$LDFLAGS -lopenvino"
    else
        echo -e "  ${YELLOW}⚠${NC} OpenVINO not found"
        ENABLE_NPU=0
    fi
fi

# Check for GPU (OpenCL)
if [ $ENABLE_GPU -eq 1 ]; then
    if pkg-config --exists OpenCL 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} OpenCL detected"
        CFLAGS="$CFLAGS $(pkg-config --cflags OpenCL) -DENABLE_GPU=1"
        LDFLAGS="$LDFLAGS $(pkg-config --libs OpenCL)"
    else
        echo -e "  ${YELLOW}⚠${NC} OpenCL not available"
        ENABLE_GPU=0
    fi
fi

# Check for DPDK
if [ $ENABLE_DPDK -eq 1 ]; then
    if pkg-config --exists libdpdk 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} DPDK detected"
        CFLAGS="$CFLAGS $(pkg-config --cflags libdpdk) -DENABLE_DPDK=1"
        LDFLAGS="$LDFLAGS $(pkg-config --libs libdpdk)"
    else
        echo -e "  ${YELLOW}⚠${NC} DPDK not available"
        ENABLE_DPDK=0
    fi
fi

# Enable LTO if supported
if [ $ENABLE_LTO -eq 1 ]; then
    if echo | $CC -flto -E - &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} LTO enabled"
        CFLAGS="$CFLAGS -flto=auto"
        LDFLAGS="$LDFLAGS -flto=auto"
    fi
fi

# Enable Address Sanitizer
if [ $ENABLE_ASAN -eq 1 ]; then
    echo -e "  ${GREEN}✓${NC} Address Sanitizer enabled"
    CFLAGS="$CFLAGS -fsanitize=address -fno-omit-frame-pointer"
    LDFLAGS="$LDFLAGS -fsanitize=address"
fi

# Feature summary
echo -e "\n${YELLOW}Build configuration:${NC}"
echo "  Compiler: $CC"
echo "  NPU: $([ $ENABLE_NPU -eq 1 ] && echo "Enabled" || echo "Disabled")"
echo "  GNA: $([ $ENABLE_GNA -eq 1 ] && echo "Enabled" || echo "Disabled")"
echo "  GPU: $([ $ENABLE_GPU -eq 1 ] && echo "Enabled" || echo "Disabled")"
echo "  DPDK: $([ $ENABLE_DPDK -eq 1 ] && echo "Enabled" || echo "Disabled")"
echo "  PGO: $([ $ENABLE_PGO -eq 1 ] && echo "Enabled" || echo "Disabled")"

# Add feature flags
CFLAGS="$CFLAGS -DENABLE_NPU=$ENABLE_NPU -DENABLE_GNA=$ENABLE_GNA"
CFLAGS="$CFLAGS -DENABLE_GPU=$ENABLE_GPU -DENABLE_DPDK=$ENABLE_DPDK"

# Compile assembly if NASM is available
echo -e "\n${YELLOW}Building components...${NC}"

if command -v $NASM &> /dev/null; then
    echo -e "  ${BLUE}→${NC} Assembling hybrid_protocol_asm.S..."
    $CC -c hybrid_protocol_asm.S -o $BUILD_DIR/hybrid_protocol_asm.o
    ASM_OBJ="$BUILD_DIR/hybrid_protocol_asm.o"
else
    echo -e "  ${YELLOW}⚠${NC} NASM not found, skipping assembly optimization"
    ASM_OBJ=""
fi

# Compile missing functions
echo -e "  ${BLUE}→${NC} Compiling missing_functions.c..."
$CC $CFLAGS -c missing_functions.c -o $BUILD_DIR/missing_functions.o

# Profile-Guided Optimization
if [ $ENABLE_PGO -eq 1 ]; then
    echo -e "\n${YELLOW}Building with Profile-Guided Optimization...${NC}"
    
    # Step 1: Build with profiling
    echo -e "  ${BLUE}→${NC} Building profiling version..."
    $CC $CFLAGS -fprofile-generate=$BUILD_DIR/pgo \
        ultra_hybrid_enhanced.c \
        $BUILD_DIR/missing_functions.o \
        $ASM_OBJ \
        $LDFLAGS \
        -o $BUILD_DIR/${OUTPUT_NAME}_prof
    
    # Step 2: Run profiling workload
    echo -e "  ${BLUE}→${NC} Running profiling workload..."
    $BUILD_DIR/${OUTPUT_NAME}_prof 5 > /dev/null 2>&1
    
    # Step 3: Build with profile data
    echo -e "  ${BLUE}→${NC} Building optimized version..."
    $CC $CFLAGS -fprofile-use=$BUILD_DIR/pgo -fprofile-correction \
        ultra_hybrid_enhanced.c \
        $BUILD_DIR/missing_functions.o \
        $ASM_OBJ \
        $LDFLAGS \
        -o $BUILD_DIR/${OUTPUT_NAME}
else
    # Regular build
    echo -e "  ${BLUE}→${NC} Compiling ultra_hybrid_enhanced.c..."
    $CC $CFLAGS \
        ultra_hybrid_enhanced.c \
        $BUILD_DIR/missing_functions.o \
        $ASM_OBJ \
        $LDFLAGS \
        -o $BUILD_DIR/${OUTPUT_NAME}
fi

# Build optimized version as well
echo -e "  ${BLUE}→${NC} Compiling ultra_hybrid_optimized.c..."
$CC $CFLAGS \
    ultra_hybrid_optimized.c \
    $BUILD_DIR/missing_functions.o \
    $ASM_OBJ \
    $LDFLAGS \
    -o $BUILD_DIR/${OUTPUT_NAME}_optimized

# Strip symbols for release build
if [ $ENABLE_DEBUG -eq 0 ]; then
    echo -e "  ${BLUE}→${NC} Stripping symbols..."
    strip $BUILD_DIR/${OUTPUT_NAME}
    strip $BUILD_DIR/${OUTPUT_NAME}_optimized
fi

# Generate performance report
echo -e "\n${YELLOW}Generating performance report...${NC}"
cat > $BUILD_DIR/build_info.txt << EOF
Build Information
=================
Date: $(date)
Compiler: $($CC --version | head -1)
CFLAGS: $CFLAGS
LDFLAGS: $LDFLAGS

Features:
- NPU: $([ $ENABLE_NPU -eq 1 ] && echo "Enabled" || echo "Disabled")
- GNA: $([ $ENABLE_GNA -eq 1 ] && echo "Enabled" || echo "Disabled")  
- GPU: $([ $ENABLE_GPU -eq 1 ] && echo "Enabled" || echo "Disabled")
- DPDK: $([ $ENABLE_DPDK -eq 1 ] && echo "Enabled" || echo "Disabled")
- PGO: $([ $ENABLE_PGO -eq 1 ] && echo "Enabled" || echo "Disabled")
- LTO: $([ $ENABLE_LTO -eq 1 ] && echo "Enabled" || echo "Disabled")

CPU Features Detected:
$CPU_FLAGS

Binary Sizes:
- Enhanced: $(ls -lh $BUILD_DIR/${OUTPUT_NAME} | awk '{print $5}')
- Optimized: $(ls -lh $BUILD_DIR/${OUTPUT_NAME}_optimized | awk '{print $5}')
EOF

# Success message
echo -e "\n${GREEN}====================================${NC}"
echo -e "${GREEN}  BUILD SUCCESSFUL${NC}"
echo -e "${GREEN}====================================${NC}"
echo -e "\nBinaries created:"
echo -e "  ${GREEN}✓${NC} $BUILD_DIR/${OUTPUT_NAME}"
echo -e "  ${GREEN}✓${NC} $BUILD_DIR/${OUTPUT_NAME}_optimized"
echo -e "\nRun with:"
echo -e "  ${BLUE}./$BUILD_DIR/${OUTPUT_NAME} [duration_seconds]${NC}"
echo -e "\nBuild details saved to: $BUILD_DIR/build_info.txt"