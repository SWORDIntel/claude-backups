#!/bin/bash

# Build Custom Kernel with GNA and NPU Support for siduction
# For Intel Core Ultra 7 155H (Meteor Lake)

set -e

KERNEL_VERSION="6.12.6"  # Latest stable with full Meteor Lake support
BUILD_DIR="/tmp/kernel-build"
JOBS=$(nproc)

echo "=========================================="
echo "Custom Kernel Builder for GNA/NPU Support"
echo "Target: Intel Core Ultra 7 155H (Meteor Lake)"
echo "=========================================="

# Install build dependencies
echo "📦 Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    kmod \
    cpio \
    rsync \
    dwarves \
    zstd \
    lz4 \
    git \
    wget

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download kernel source
echo "📥 Downloading kernel $KERNEL_VERSION..."
if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
    tar xf "linux-${KERNEL_VERSION}.tar.xz"
fi

cd "linux-${KERNEL_VERSION}"

# Copy current kernel config as base
echo "📋 Copying current kernel config..."
cp /boot/config-$(uname -r) .config

# Create custom config for GNA/NPU support
cat >> .config << 'EOF'

# Intel Neural Processing Unit (NPU) Support
CONFIG_DRM_ACCEL=y
CONFIG_DRM_ACCEL_IVPU=m
CONFIG_INTEL_VSC=m
CONFIG_INTEL_VSC_PSE=m
CONFIG_INTEL_IVPU=m

# Intel GNA (Gaussian & Neural Accelerator) 3.0
CONFIG_INTEL_GNA=m
CONFIG_MFD_INTEL_PMC_BXT=y

# Intel MEI drivers for NPU communication
CONFIG_INTEL_MEI=m
CONFIG_INTEL_MEI_ME=m
CONFIG_INTEL_MEI_TXE=m
CONFIG_INTEL_MEI_GSC=m
CONFIG_INTEL_MEI_VSC_HW=m
CONFIG_INTEL_MEI_PXP=m

# DRM acceleration framework
CONFIG_DRM=y
CONFIG_DRM_DISPLAY_HELPER=y
CONFIG_DRM_SHMEM_HELPER=y
CONFIG_DRM_GEM_SHMEM_HELPER=y

# ACPI support for neural devices
CONFIG_ACPI_PROCESSOR_AGGREGATOR=m
CONFIG_ACPI_THERMAL_REL=m

# Power management for NPU
CONFIG_INTEL_RAPL_CORE=m
CONFIG_INTEL_IDLE=y
CONFIG_INTEL_HFI_THERMAL=y
CONFIG_INTEL_POWERCLAMP=m
CONFIG_INTEL_UNCORE_FREQ_CONTROL=m

# PCIe support for NPU
CONFIG_PCI_MSI=y
CONFIG_PCI_ATS=y
CONFIG_PCI_IOV=y
CONFIG_PCI_PRI=y
CONFIG_PCI_PASID=y

# Memory management for NPU
CONFIG_ZONE_DEVICE=y
CONFIG_HMM_MIRROR=y
CONFIG_DEVICE_PRIVATE=y

# Intel ISH (Integrated Sensor Hub) for NPU
CONFIG_INTEL_ISH_HID=m
CONFIG_INTEL_ISH_FIRMWARE_DOWNLOADER=m

# Intel PUNIT IPC for NPU control
CONFIG_INTEL_PUNIT_IPC=m
CONFIG_INTEL_PMC_CORE=y

# Meteor Lake specific
CONFIG_X86_INTEL_LPSS=y
CONFIG_INTEL_LPSS_ACPI=y
CONFIG_INTEL_LPSS_PCI=y

# Enable Intel Speed Select for NPU
CONFIG_INTEL_SPEED_SELECT_INTERFACE=m

# Debug options (disable for production)
# CONFIG_DRM_ACCEL_IVPU_DEBUG=y
# CONFIG_INTEL_GNA_DEBUG=y

EOF

# Update config with new options
echo "🔧 Updating kernel configuration..."
make olddefconfig

# Enable specific options interactively if needed
echo "⚙️ Enabling GNA/NPU specific options..."
./scripts/config --module CONFIG_DRM_ACCEL_IVPU
./scripts/config --module CONFIG_INTEL_GNA
./scripts/config --module CONFIG_INTEL_VSC
./scripts/config --module CONFIG_INTEL_MEI_VSC_HW
./scripts/config --enable CONFIG_DRM_ACCEL
./scripts/config --enable CONFIG_ZONE_DEVICE
./scripts/config --enable CONFIG_HMM_MIRROR

# Build kernel
echo "🔨 Building kernel (this will take 30-60 minutes)..."
make -j${JOBS} bindeb-pkg LOCALVERSION=-gna-npu-meteor-lake KDEB_PKGVERSION=$(date +%Y%m%d)

echo ""
echo "✅ Kernel build complete!"
echo ""
echo "📦 Debian packages created in: $BUILD_DIR"
echo ""
echo "To install the new kernel:"
echo "  cd $BUILD_DIR"
echo "  sudo dpkg -i linux-image-*.deb linux-headers-*.deb"
echo ""
echo "After installation:"
echo "  1. Reboot into new kernel"
echo "  2. Check devices: ls /dev/accel*"
echo "  3. Check modules: lsmod | grep -E 'ivpu|gna|vsc'"
echo "  4. Verify NPU: sudo dmesg | grep -i accel"
echo ""
echo "Expected devices after reboot:"
echo "  /dev/accel/accel0 - Intel NPU"
echo "  /dev/gna0 - Intel GNA 3.0"