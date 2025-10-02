#!/bin/bash
set -e

echo "=== Installing Intel Compute Runtime for OpenCL/Level Zero ==="

# Add Intel repository
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
  sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list

sudo apt-get update

# Install Intel Compute Runtime (OpenCL + Level Zero)
sudo apt-get install -y \
  intel-opencl-icd \
  intel-level-zero-gpu \
  level-zero \
  intel-media-va-driver-non-free \
  libmfx1 \
  libmfxgen1 \
  libvpl2 \
  libegl-mesa0 \
  libegl1-mesa \
  libegl1-mesa-dev \
  libgbm1 \
  libgl1-mesa-dev \
  libgl1-mesa-dri \
  libglapi-mesa \
  libgles2-mesa-dev \
  libglx-mesa0 \
  libigdgmm12 \
  libxatracker2 \
  mesa-va-drivers \
  mesa-vdpau-drivers \
  mesa-vulkan-drivers \
  va-driver-all \
  vainfo \
  clinfo

echo ""
echo "=== Verification ==="
echo "OpenCL devices:"
clinfo -l 2>&1 || echo "No OpenCL devices (check above errors)"

echo ""
echo "Level Zero devices:"
ls -la /dev/dri/

echo ""
echo "NPU device:"
ls -la /dev/accel/

echo "=== Installation Complete ==="
