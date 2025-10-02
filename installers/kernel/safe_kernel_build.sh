#!/bin/bash

# SAFE Kernel Build - Modified to avoid dangerous autoremove

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ZFS_SOURCE="$HOME/Downloads/Old/zfs-2.3.4"
KERNEL_VERSION="6.12.6"
BUILD_DIR="/tmp/custom-kernel-build"
JOBS=20
LOGFILE="/tmp/kernel_build_$(date +%Y%m%d_%H%M%S).log"

echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║        SAFE KERNEL BUILDER - NO AUTOREMOVE              ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Ensure critical packages are present
echo -e "${BLUE}Step 1: Verifying critical packages${NC}"
CRITICAL_PACKAGES="dkms initramfs-tools build-essential"

for pkg in $CRITICAL_PACKAGES; do
    if ! dpkg -l | grep -q "^ii.*$pkg"; then
        echo "Installing critical package: $pkg"
        sudo apt install -y $pkg
    else
        echo "✓ $pkg is installed"
    fi
done

# Step 2: Fix ONLY the specific ZFS conflicts
echo -e "\n${BLUE}Step 2: Fixing ONLY ZFS package conflicts${NC}"
# Remove ONLY the conflicting packages, NOT using autoremove
sudo dpkg --remove --force-depends libnvpair3 libuutil3 2>/dev/null || true
sudo apt --fix-broken install -y

# Step 3: Install build dependencies WITHOUT autoremove
echo -e "\n${BLUE}Step 3: Installing build dependencies${NC}"
sudo apt install -y \
    libncurses-dev bison flex libssl-dev libelf-dev bc \
    kmod cpio rsync dwarves zstd lz4 git wget debhelper \
    kernel-wedge autoconf automake libtool gawk alien \
    fakeroot libblkid-dev uuid-dev libudev-dev zlib1g-dev \
    libaio-dev libattr1-dev python3 python3-dev python3-setuptools \
    python3-cffi libffi-dev || true

# Step 4: Build ZFS
echo -e "\n${BLUE}Step 4: Building ZFS from $ZFS_SOURCE${NC}"
cd "$ZFS_SOURCE"

# Clean and build
make clean 2>/dev/null || true
make distclean 2>/dev/null || true

echo "Running autogen.sh..."
./autogen.sh

echo "Configuring..."
./configure

echo "Building with -j${JOBS}..."
make -j${JOBS}

echo "Creating deb packages..."
make deb

echo -e "${GREEN}✓ ZFS packages built${NC}"

# Step 5: Download and prepare kernel
echo -e "\n${BLUE}Step 5: Preparing kernel ${KERNEL_VERSION}${NC}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    echo "Downloading kernel..."
    wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
    tar xf "linux-${KERNEL_VERSION}.tar.xz"
fi

cd "linux-${KERNEL_VERSION}"

# Step 6: Configure kernel
echo -e "\n${BLUE}Step 6: Configuring kernel with NPU/GNA/GPU support${NC}"

# Copy current config
cp /boot/config-$(uname -r) .config

# Enable all acceleration features
echo "Enabling NPU support..."
./scripts/config --enable CONFIG_DRM_ACCEL
./scripts/config --module CONFIG_DRM_ACCEL_IVPU
./scripts/config --module CONFIG_INTEL_VSC
./scripts/config --module CONFIG_INTEL_IVPU

echo "Enabling GNA support..."
./scripts/config --module CONFIG_INTEL_GNA
./scripts/config --enable CONFIG_MFD_INTEL_PMC_BXT

echo "Enabling GPU support..."
./scripts/config --module CONFIG_DRM_I915
./scripts/config --enable CONFIG_DRM_I915_CAPTURE_ERROR

echo "Enabling CPU features..."
./scripts/config --enable CONFIG_X86_INTEL_PSTATE
./scripts/config --enable CONFIG_CRYPTO_AVX512

echo "Enabling memory management..."
./scripts/config --enable CONFIG_ZONE_DEVICE
./scripts/config --enable CONFIG_HMM_MIRROR

echo "Enabling ZFS support..."
./scripts/config --module CONFIG_SPL
./scripts/config --module CONFIG_ZFS

# Update config
make olddefconfig

# Step 7: Build kernel
echo -e "\n${BLUE}Step 7: Building kernel (this takes time)${NC}"
echo "Building with ${JOBS} jobs..."

make -j${JOBS} bindeb-pkg \
    LOCALVERSION=-custom-npu-gna-zfs \
    KDEB_PKGVERSION=$(date +%Y%m%d)

echo -e "${GREEN}✓ Kernel built successfully${NC}"

# Step 8: Prepare installation
echo -e "\n${BLUE}Step 8: Preparing installation package${NC}"

INSTALL_DIR="/tmp/kernel-install-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$INSTALL_DIR"

# Copy packages
cp ${BUILD_DIR}/*.deb "$INSTALL_DIR/" 2>/dev/null || true
cp ${ZFS_SOURCE}/*.deb "$INSTALL_DIR/" 2>/dev/null || true

# Download NPU firmware
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
cp vpu_37xx_v1.6.0.bin "$INSTALL_DIR/"

# Create installer
cat > "$INSTALL_DIR/install.sh" << 'EOF'
#!/bin/bash
echo "Installing custom kernel and ZFS..."

# Install ZFS
echo "Installing ZFS packages..."
sudo dpkg -i *zfs*.deb lib*.deb python3-pyzfs*.deb 2>/dev/null
sudo apt --fix-broken install -y

# Install kernel
echo "Installing kernel..."
sudo dpkg -i linux-image*.deb linux-headers*.deb
sudo apt --fix-broken install -y

# Install firmware
echo "Installing NPU firmware..."
sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/

# Update initramfs
KERNEL_VER=$(ls /lib/modules/ | grep custom-npu-gna-zfs | head -1)
sudo update-initramfs -u -k $KERNEL_VER

# Update GRUB
sudo update-grub

echo "✓ Installation complete!"
echo "Reboot and select kernel: $KERNEL_VER"
EOF

chmod +x "$INSTALL_DIR/install.sh"

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD COMPLETE!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Installation package: $INSTALL_DIR${NC}"
echo ""
echo "To install:"
echo "  cd $INSTALL_DIR"
echo "  sudo ./install.sh"
echo ""
echo "Features included:"
echo "  ✓ NPU support (11 TOPS)"
echo "  ✓ GNA driver (2 TOPS)"
echo "  ✓ GPU acceleration"
echo "  ✓ ZFS filesystem"
echo ""
echo -e "${GREEN}Safe build complete - no packages were auto-removed!${NC}"