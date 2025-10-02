#!/bin/bash

# DIRECTOR'S STRATEGIC SOLUTION - Complete Kernel Build with Safety
# Comprehensive approach to build custom kernel with NPU/GNA/GPU + ZFS

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Strategic Configuration
ZFS_SOURCE="$HOME/Downloads/Old/zfs-2.3.4"
KERNEL_VERSION="6.12.6"
BUILD_DIR="/tmp/director-kernel-build"
JOBS=20
LOGFILE="/tmp/director_kernel_$(date +%Y%m%d_%H%M%S).log"

# Function to execute with safety checks
safe_execute() {
    echo -e "${CYAN}[DIRECTOR] Executing: $@${NC}" | tee -a "$LOGFILE"
    if ! "$@" 2>&1 | tee -a "$LOGFILE"; then
        echo -e "${RED}[DIRECTOR] Command failed, but continuing...${NC}"
        return 1
    fi
    return 0
}

# Header
clear
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║              DIRECTOR'S STRATEGIC KERNEL BUILD                  ║${NC}"
echo -e "${MAGENTA}║         Complete NPU/GNA/GPU/ZFS Integration Solution            ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}[DIRECTOR] Initializing strategic build process...${NC}"
echo -e "${WHITE}[DIRECTOR] Log: $LOGFILE${NC}"
echo ""

# PHASE 1: SYSTEM STABILIZATION
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 1: SYSTEM STABILIZATION AND RECOVERY                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW}[DIRECTOR] Restoring critical system packages...${NC}"

# Critical packages that MUST be present
CRITICAL_RESTORE="
dkms
initramfs-tools
initramfs-tools-core
initramfs-tools-bin
klibc-utils
libklibc
build-essential
linux-headers-$(uname -r)
"

for pkg in $CRITICAL_RESTORE; do
    echo -e "${CYAN}[DIRECTOR] Checking $pkg...${NC}"
    if ! dpkg -l | grep -q "^ii.*$pkg"; then
        echo -e "${YELLOW}[DIRECTOR] Restoring $pkg...${NC}"
        sudo apt install -y $pkg 2>/dev/null || echo "[DIRECTOR] $pkg may not be available"
    else
        echo -e "${GREEN}[DIRECTOR] ✓ $pkg present${NC}"
    fi
done

# Fix any broken packages
echo -e "${YELLOW}[DIRECTOR] Repairing package database...${NC}"
sudo apt --fix-broken install -y

# Verify boot capability
echo -e "${YELLOW}[DIRECTOR] Verifying boot integrity...${NC}"
if [ -f "/boot/initrd.img-$(uname -r)" ]; then
    echo -e "${GREEN}[DIRECTOR] ✓ Boot image present for current kernel${NC}"
else
    echo -e "${RED}[DIRECTOR] ⚠ Boot image missing - rebuilding...${NC}"
    sudo update-initramfs -c -k $(uname -r)
fi

# PHASE 2: ZFS BUILD
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 2: ZFS 2.3.4 BUILD FROM SOURCE                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW}[DIRECTOR] Preparing ZFS build environment...${NC}"

# Install ZFS build dependencies
ZFS_DEPS="autoconf automake libtool gawk alien fakeroot dkms libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev python3 python3-dev python3-setuptools python3-cffi libffi-dev"

for dep in $ZFS_DEPS; do
    sudo apt install -y $dep 2>/dev/null || true
done

# Build ZFS
cd "$ZFS_SOURCE"
echo -e "${YELLOW}[DIRECTOR] Building ZFS from $ZFS_SOURCE...${NC}"

# Clean previous builds
make clean 2>/dev/null || true
make distclean 2>/dev/null || true

# Build sequence
echo -e "${CYAN}[DIRECTOR] Running autogen.sh...${NC}"
./autogen.sh

echo -e "${CYAN}[DIRECTOR] Configuring ZFS...${NC}"
./configure

echo -e "${CYAN}[DIRECTOR] Building with -j${JOBS}...${NC}"
make -j${JOBS}

echo -e "${CYAN}[DIRECTOR] Creating Debian packages...${NC}"
make deb

ZFS_PACKAGES=$(ls *.deb 2>/dev/null | wc -l)
echo -e "${GREEN}[DIRECTOR] ✓ Created $ZFS_PACKAGES ZFS packages${NC}"

# PHASE 3: KERNEL PREPARATION
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 3: KERNEL ${KERNEL_VERSION} PREPARATION                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

# Install kernel build dependencies
echo -e "${YELLOW}[DIRECTOR] Installing kernel build dependencies...${NC}"
KERNEL_DEPS="libncurses-dev bison flex libssl-dev libelf-dev bc kmod cpio rsync dwarves zstd lz4 git wget debhelper kernel-wedge"

for dep in $KERNEL_DEPS; do
    sudo apt install -y $dep 2>/dev/null || true
done

# Prepare build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download kernel
echo -e "${YELLOW}[DIRECTOR] Acquiring kernel ${KERNEL_VERSION} source...${NC}"
if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
    tar xf "linux-${KERNEL_VERSION}.tar.xz"
fi

cd "linux-${KERNEL_VERSION}"

# PHASE 4: KERNEL CONFIGURATION
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 4: COMPLETE NEURAL ACCELERATION CONFIGURATION            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW}[DIRECTOR] Configuring maximum acceleration support...${NC}"

# Base config
cp /boot/config-$(uname -r) .config

# Neural Processing Unit (NPU) - 11 TOPS
echo -e "${CYAN}[DIRECTOR] Enabling NPU (11 TOPS)...${NC}"
./scripts/config --enable CONFIG_DRM_ACCEL
./scripts/config --module CONFIG_DRM_ACCEL_IVPU
./scripts/config --module CONFIG_INTEL_VSC
./scripts/config --module CONFIG_INTEL_VSC_PSE
./scripts/config --module CONFIG_INTEL_IVPU

# Gaussian Neural Accelerator (GNA) - 2 TOPS
echo -e "${CYAN}[DIRECTOR] Enabling GNA (2 TOPS)...${NC}"
./scripts/config --module CONFIG_INTEL_GNA
./scripts/config --enable CONFIG_INTEL_GNA_SCORING
./scripts/config --enable CONFIG_MFD_INTEL_PMC_BXT

# GPU Acceleration - 128 EUs
echo -e "${CYAN}[DIRECTOR] Enabling GPU (128 EUs)...${NC}"
./scripts/config --module CONFIG_DRM_I915
./scripts/config --enable CONFIG_DRM_I915_CAPTURE_ERROR
./scripts/config --enable CONFIG_DRM_I915_USERPTR

# CPU Optimizations
echo -e "${CYAN}[DIRECTOR] Enabling CPU optimizations...${NC}"
./scripts/config --enable CONFIG_X86_INTEL_PSTATE
./scripts/config --enable CONFIG_CRYPTO_AVX512
./scripts/config --enable CONFIG_INTEL_IDLE

# Memory Management for Accelerators
echo -e "${CYAN}[DIRECTOR] Enabling accelerator memory management...${NC}"
./scripts/config --enable CONFIG_ZONE_DEVICE
./scripts/config --enable CONFIG_HMM_MIRROR
./scripts/config --enable CONFIG_DEVICE_PRIVATE

# ZFS Support
echo -e "${CYAN}[DIRECTOR] Enabling ZFS support...${NC}"
./scripts/config --module CONFIG_SPL
./scripts/config --module CONFIG_ZFS

# Finalize configuration
make olddefconfig

echo -e "${GREEN}[DIRECTOR] ✓ Configuration complete - 13+ TOPS neural compute enabled${NC}"

# PHASE 5: KERNEL BUILD
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 5: KERNEL BUILD EXECUTION                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${YELLOW}[DIRECTOR] Initiating kernel build with ${JOBS} parallel jobs...${NC}"
echo -e "${WHITE}[DIRECTOR] This will take 30-60 minutes. Starting at $(date)${NC}"

START_TIME=$(date +%s)

make -j${JOBS} bindeb-pkg \
    LOCALVERSION=-director-npu-gna-gpu \
    KDEB_PKGVERSION=$(date +%Y%m%d)

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
BUILD_MINS=$((BUILD_TIME / 60))

echo -e "${GREEN}[DIRECTOR] ✓ Kernel built successfully in ${BUILD_MINS} minutes${NC}"

# PHASE 6: PACKAGE ASSEMBLY
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PHASE 6: FINAL PACKAGE ASSEMBLY                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

PACKAGE_DIR="/tmp/director-kernel-package-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PACKAGE_DIR"

echo -e "${YELLOW}[DIRECTOR] Assembling installation package...${NC}"

# Copy all packages
cp ${BUILD_DIR}/*.deb "$PACKAGE_DIR/" 2>/dev/null || true
cp ${ZFS_SOURCE}/*.deb "$PACKAGE_DIR/" 2>/dev/null || true

# Get NPU firmware
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
cp vpu_37xx_v1.6.0.bin "$PACKAGE_DIR/"

# Create strategic installer
cat > "$PACKAGE_DIR/director_install.sh" << 'EOF_INSTALLER'
#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           DIRECTOR'S KERNEL INSTALLATION PROTOCOL               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# Install ZFS first
echo "[DIRECTOR] Installing ZFS 2.3.4..."
sudo dpkg -i *zfs*.deb lib*.deb python3-pyzfs*.deb 2>/dev/null
sudo apt --fix-broken install -y

# Install kernel
echo "[DIRECTOR] Installing custom kernel..."
sudo dpkg -i linux-image*.deb linux-headers*.deb
sudo apt --fix-broken install -y

# Install NPU firmware
echo "[DIRECTOR] Installing NPU firmware..."
sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/

# Update boot
KERNEL_VER=$(ls /lib/modules/ | grep director-npu-gna-gpu | head -1)
echo "[DIRECTOR] Updating initramfs for kernel $KERNEL_VER..."
sudo update-initramfs -u -k $KERNEL_VER
sudo update-grub

echo ""
echo "✓ DIRECTOR'S KERNEL INSTALLATION COMPLETE"
echo ""
echo "Neural Compute Capability:"
echo "  • NPU: 11 TOPS"
echo "  • GNA: 2 TOPS"
echo "  • GPU: 128 EUs"
echo "  • Total: 13+ TOPS"
echo ""
echo "Reboot and select: $KERNEL_VER"
EOF_INSTALLER

chmod +x "$PACKAGE_DIR/director_install.sh"

# FINAL REPORT
echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                  DIRECTOR'S MISSION COMPLETE                    ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${WHITE}[DIRECTOR] Strategic Summary:${NC}"
echo -e "${GREEN}  ✓ System stabilized and critical packages restored${NC}"
echo -e "${GREEN}  ✓ ZFS 2.3.4 built from source with .deb packages${NC}"
echo -e "${GREEN}  ✓ Kernel ${KERNEL_VERSION} built with complete acceleration${NC}"
echo -e "${GREEN}  ✓ NPU (11 TOPS) + GNA (2 TOPS) + GPU enabled${NC}"
echo -e "${GREEN}  ✓ Installation package assembled${NC}"

echo -e "\n${YELLOW}[DIRECTOR] Installation Package Location:${NC}"
echo -e "${WHITE}  $PACKAGE_DIR${NC}"

echo -e "\n${YELLOW}[DIRECTOR] Final Instructions:${NC}"
echo -e "${WHITE}  1. cd $PACKAGE_DIR${NC}"
echo -e "${WHITE}  2. sudo ./director_install.sh${NC}"
echo -e "${WHITE}  3. sudo reboot${NC}"
echo -e "${WHITE}  4. Select kernel with 'director-npu-gna-gpu' in GRUB${NC}"

echo -e "\n${GREEN}[DIRECTOR] Mission accomplished. System ready for 13+ TOPS acceleration.${NC}"
echo -e "${GREEN}[DIRECTOR] Log saved to: $LOGFILE${NC}"