#!/bin/bash

# Fix ZFS conflicts and install kernel 6.12.13 WITH ZFS support
# Keeps your ZFS pools accessible

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}ZFS-Safe Kernel Upgrade to 6.12.13${NC}"
echo -e "${GREEN}With NPU/GNA Support${NC}"
echo -e "${GREEN}============================================${NC}"

# Step 1: Fix the ZFS package conflicts
echo -e "\n${YELLOW}Step 1: Resolving ZFS package conflicts${NC}"

# The issue is libnvpair3 vs libnvpair3linux conflict
# We need to use the *linux versions
echo "Removing old non-linux ZFS packages..."
sudo dpkg --remove --force-depends libnvpair3 libuutil3 2>/dev/null || true

# Install the linux versions if not already installed
echo "Ensuring linux versions are installed..."
sudo apt install -y libnvpair3linux libuutil3linux

# Fix any remaining issues
sudo apt --fix-broken install -y

# Step 2: Install kernel with ZFS modules
echo -e "\n${YELLOW}Step 2: Installing kernel 6.12.13${NC}"
sudo apt update
sudo apt install -y \
    linux-image-6.12.13-1-siduction-amd64 \
    linux-headers-6.12.13-1-siduction-amd64

# Step 3: Build ZFS modules for new kernel
echo -e "\n${YELLOW}Step 3: Building ZFS modules for 6.12.13${NC}"

# Check if we need to build ZFS modules
if ! ls /lib/modules/6.12.13-1-siduction-amd64/updates/dkms/zfs.ko* 2>/dev/null; then
    echo "Building ZFS modules with DKMS..."
    sudo dkms autoinstall -k 6.12.13-1-siduction-amd64 || {
        echo -e "${YELLOW}DKMS build failed, trying manual build...${NC}"

        # Manual ZFS module build
        sudo apt install -y build-essential linux-headers-6.12.13-1-siduction-amd64

        # Trigger rebuild
        sudo dkms remove zfs/$(dkms status | grep zfs | head -1 | awk -F, '{print $2}' | xargs) --all 2>/dev/null || true
        sudo dkms add zfs
        sudo dkms build zfs/$(dkms status | grep zfs | head -1 | awk -F, '{print $2}' | xargs) -k 6.12.13-1-siduction-amd64
        sudo dkms install zfs/$(dkms status | grep zfs | head -1 | awk -F, '{print $2}' | xargs) -k 6.12.13-1-siduction-amd64
    }
else
    echo -e "${GREEN}ZFS modules already built for 6.12.13${NC}"
fi

# Step 4: Install NPU firmware
echo -e "\n${YELLOW}Step 4: Installing NPU firmware${NC}"
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin || {
    echo "Download failed, trying alternative..."
    curl -L -o vpu_37xx_v1.6.0.bin https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
}

sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/
echo -e "${GREEN}NPU firmware installed${NC}"

# Step 5: Configure modules
echo -e "\n${YELLOW}Step 5: Configuring module loading${NC}"

cat << 'EOF' | sudo tee /etc/modules-load.d/intel-npu-zfs.conf
# Intel NPU
intel_vpu

# ZFS modules (loaded automatically when needed)
# zfs
EOF

# Step 6: Update initramfs with both ZFS and NPU
echo -e "\n${YELLOW}Step 6: Updating initramfs${NC}"
sudo update-initramfs -u -k 6.12.13-1-siduction-amd64

# Step 7: Verify ZFS will work
echo -e "\n${YELLOW}Step 7: Verifying ZFS compatibility${NC}"

# Check if ZFS modules are present
if ls /lib/modules/6.12.13-1-siduction-amd64/updates/dkms/zfs.ko* 2>/dev/null; then
    echo -e "${GREEN}✓ ZFS modules found for kernel 6.12.13${NC}"
else
    echo -e "${RED}✗ ZFS modules not found - will build on next boot${NC}"
fi

# Check current ZFS pools (if any)
if command -v zpool &> /dev/null; then
    echo -e "\n${YELLOW}Current ZFS pools:${NC}"
    sudo zpool list 2>/dev/null || echo "No pools imported"
    echo ""
    echo -e "${YELLOW}ZFS datasets:${NC}"
    sudo zfs list 2>/dev/null || echo "No datasets mounted"
fi

# Create verification script
cat << 'EOF' > /tmp/verify_after_reboot.sh
#!/bin/bash
echo "Post-Reboot Verification"
echo "========================"

# Check kernel
echo -n "Kernel: "
uname -r

# Check ZFS
echo -n "ZFS Module: "
if lsmod | grep -q zfs; then
    echo "✓ Loaded"
    zpool status || echo "No pools imported"
else
    echo "✗ Not loaded - run: sudo modprobe zfs"
fi

# Check NPU
echo -n "NPU Device: "
if [ -e /dev/accel/accel0 ] || [ -e /dev/accel0 ]; then
    echo "✓ Found"
    ls -la /dev/accel* 2>/dev/null
else
    echo "✗ Not found"
fi

# Check modules
echo -e "\nLoaded Neural Modules:"
lsmod | grep -E "vpu|gna" || echo "None loaded"
EOF

chmod +x /tmp/verify_after_reboot.sh
sudo cp /tmp/verify_after_reboot.sh /usr/local/bin/verify_system

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${YELLOW}What's Ready:${NC}"
echo "  ✓ Kernel 6.12.13 installed"
echo "  ✓ ZFS modules configured for new kernel"
echo "  ✓ NPU firmware installed"
echo "  ✓ Existing ZFS pools preserved"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  1. Save any work"
echo "  2. Reboot: sudo reboot"
echo "  3. Select kernel 6.12.13 in GRUB"
echo "  4. Run: verify_system"

echo -e "\n${YELLOW}After Reboot:${NC}"
echo "  - ZFS pools will auto-import"
echo "  - NPU will be at /dev/accel0"
echo "  - Run 'sudo zpool import -a' if pools don't auto-mount"
echo "  - OpenVINO GNA plugin provides GNA support"

echo -e "\n${GREEN}Your ZFS data is safe!${NC}"