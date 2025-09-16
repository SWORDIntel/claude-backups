#!/bin/bash

# Build ZFS from your source + Install kernel 6.12.13 with NPU support

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Custom ZFS Build + Kernel 6.12.13 Upgrade${NC}"
echo -e "${GREEN}============================================${NC}"

# Step 1: Clean up the package conflicts first
echo -e "\n${YELLOW}Step 1: Cleaning package conflicts${NC}"
sudo dpkg --remove --force-depends libnvpair3 libuutil3 2>/dev/null || true
sudo apt --fix-broken install -y
sudo apt autoremove -y

# Step 2: Install the new kernel
echo -e "\n${YELLOW}Step 2: Installing kernel 6.12.13${NC}"
sudo apt update
sudo apt install --no-install-recommends -y \
    linux-image-6.12.13-1-siduction-amd64 \
    linux-headers-6.12.13-1-siduction-amd64 \
    build-essential \
    autoconf \
    automake \
    libtool \
    gawk \
    alien \
    fakeroot \
    dkms \
    libblkid-dev \
    uuid-dev \
    libudev-dev \
    libssl-dev \
    zlib1g-dev \
    libaio-dev \
    libattr1-dev \
    libelf-dev \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-cffi \
    libffi-dev

# Step 3: Build ZFS from your source
echo -e "\n${YELLOW}Step 3: Building ZFS 2.3.4 from source${NC}"
cd ~/Downloads/old/zfs.24.4

# Clean any previous build
echo "Cleaning previous build..."
make clean 2>/dev/null || true
make distclean 2>/dev/null || true

# Configure for the new kernel
echo "Configuring ZFS for kernel 6.12.13..."
./autogen.sh 2>/dev/null || {
    echo "No autogen.sh, trying configure directly..."
}

./configure \
    --prefix=/usr \
    --with-linux=/lib/modules/6.12.13-1-siduction-amd64/build \
    --with-linux-obj=/lib/modules/6.12.13-1-siduction-amd64/build \
    --disable-systemd \
    --enable-linux-builtin=no \
    || {
        echo -e "${YELLOW}Configure failed, trying simpler options...${NC}"
        ./configure --with-linux=/lib/modules/6.12.13-1-siduction-amd64/build
    }

# Build ZFS
echo "Building ZFS modules (this will take 5-10 minutes)..."
make -j$(nproc)

# Install ZFS
echo "Installing ZFS modules..."
sudo make install

# Update module dependencies
sudo depmod 6.12.13-1-siduction-amd64

# Step 4: Install NPU firmware
echo -e "\n${YELLOW}Step 4: Installing NPU firmware${NC}"
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/

# Step 5: Configure modules to load
echo -e "\n${YELLOW}Step 5: Configuring modules${NC}"
cat << 'EOF' | sudo tee /etc/modules-load.d/zfs-npu.conf
# ZFS filesystem
zfs

# Intel NPU
intel_vpu
EOF

# Step 6: Update initramfs with ZFS + NPU
echo -e "\n${YELLOW}Step 6: Updating initramfs${NC}"
sudo update-initramfs -u -k 6.12.13-1-siduction-amd64

# Step 7: Create verification script
cat << 'EOF' > /tmp/verify_zfs_npu.sh
#!/bin/bash
echo "=== System Verification ==="
echo ""
echo "Kernel: $(uname -r)"
echo ""
echo "ZFS Status:"
if lsmod | grep -q zfs; then
    echo "  ✓ ZFS module loaded"
    modinfo zfs | grep version | head -1
    echo ""
    echo "ZFS Pools:"
    sudo zpool list 2>/dev/null || echo "  No pools imported"
else
    echo "  ✗ ZFS not loaded"
    echo "  Run: sudo modprobe zfs"
fi
echo ""
echo "NPU Status:"
if [ -e /dev/accel/accel0 ] || [ -e /dev/accel0 ]; then
    echo "  ✓ NPU device found"
    ls -la /dev/accel* 2>/dev/null
else
    echo "  ✗ NPU not found"
fi
if lsmod | grep -q intel_vpu; then
    echo "  ✓ VPU module loaded"
fi
echo ""
echo "To import ZFS pools: sudo zpool import -a"
EOF

chmod +x /tmp/verify_zfs_npu.sh
sudo cp /tmp/verify_zfs_npu.sh /usr/local/bin/verify_zfs_npu

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}What's Done:${NC}"
echo "  ✓ Kernel 6.12.13 installed"
echo "  ✓ ZFS 2.3.4 built from your source"
echo "  ✓ ZFS modules installed for new kernel"
echo "  ✓ NPU firmware installed"
echo "  ✓ Initramfs updated"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  1. Reboot: sudo reboot"
echo "  2. Select kernel 6.12.13 in GRUB"
echo "  3. Run: verify_zfs_npu"

echo -e "\n${YELLOW}After Reboot:${NC}"
echo "  • ZFS: sudo modprobe zfs && sudo zpool import -a"
echo "  • NPU: Check /dev/accel0"
echo "  • GNA: Use OpenVINO plugin"

echo -e "\n${GREEN}Ready for 13+ TOPS neural compute with ZFS!${NC}"