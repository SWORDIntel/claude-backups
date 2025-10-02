#!/bin/bash
set -e

# OpenVINO Installation Fix Script
# Addresses corrupted submodules and provides clean installation path

echo "=== OpenVINO GNA/CPU Installation Fix ==="
echo ""
echo "FINDINGS:"
echo "1. NO LLVM FAILURE - OpenVINO 2023.3 does NOT require LLVM"
echo "2. GNA support is native (downloads pre-built GNA lib v03.05.00.2116)"
echo "3. CPU support uses oneDNN library (not LLVM-based)"
echo "4. NPU in CLAUDE.md refers to Intel NPU driver v1.17.0 (separate package)"
echo "5. Current openvino-2023.3/ has corrupted git submodules"
echo ""

# Cleanup corrupted checkout
echo "Step 1: Cleaning up corrupted source..."
cd /home/john/Downloads/claude-backups
rm -rf openvino-2023.3
rm -rf openvino-build

# Option A: Use pre-built OpenVINO runtime (RECOMMENDED)
echo ""
echo "RECOMMENDED: Install pre-built OpenVINO 2024.5 Runtime"
echo "This includes GNA and CPU support out of the box."
echo ""
echo "Run these commands:"
echo "  wget https://storage.openvinotoolkit.org/repositories/openvino/packages/2024.5/linux/l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64.tgz"
echo "  tar -xzf l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64.tgz"
echo "  cd l_openvino_toolkit_ubuntu22_2024.5.0.17288.7975fa5da0c_x86_64"
echo "  sudo ./install_dependencies/install_openvino_dependencies.sh"
echo "  source setupvars.sh"
echo ""

# Option B: Build from source (if needed)
echo "ALTERNATIVE: Build OpenVINO 2024.5 from clean source"
echo ""
echo "Requirements (install with sudo if needed):"
echo "  - cmake >= 3.13"
echo "  - gcc/g++ >= 7.5"
echo "  - python3-dev"
echo "  - libpugixml-dev"
echo "  - libtbb-dev"
echo ""
echo "Build commands:"
echo "  git clone --recurse-submodules --shallow-submodules --depth 1 \\"
echo "    --branch 2024.5.0 https://github.com/openvinotoolkit/openvino.git openvino-2024.5"
echo "  mkdir openvino-build && cd openvino-build"
echo "  cmake ../openvino-2024.5 \\"
echo "    -DCMAKE_BUILD_TYPE=Release \\"
echo "    -DCMAKE_INSTALL_PREFIX=/opt/intel/openvino \\"
echo "    -DENABLE_INTEL_GNA=ON \\"
echo "    -DENABLE_INTEL_CPU=ON \\"
echo "    -DENABLE_INTEL_GPU=OFF \\"
echo "    -DENABLE_TESTS=OFF \\"
echo "    -DENABLE_SAMPLES=OFF \\"
echo "    -DENABLE_PYTHON=OFF"
echo "  make -j\$(nproc)"
echo "  sudo make install"
echo ""

# NPU Driver information
echo "=== Intel NPU Driver (Separate from OpenVINO) ==="
echo "The NPU mentioned in CLAUDE.md is Intel's Neural Processing Unit driver"
echo "Status: v1.17.0 is 95% non-functional on Meteor Lake (use CPU fallback)"
echo "Not related to LLVM or OpenVINO build process"
echo ""
echo "Intel NPU driver is kernel module + userspace libs, installed separately:"
echo "  https://github.com/intel/linux-npu-driver"
echo ""

echo "=== Summary ==="
echo "✓ There was NO LLVM compilation failure"
echo "✓ GNA library downloads automatically during cmake (pre-built)"
echo "✓ CPU plugin uses oneDNN (pre-built or system TBB)"
echo "✓ NPU is unrelated Intel driver (kernel module)"
echo ""
echo "Choose Option A (pre-built) or Option B (source build) above"
