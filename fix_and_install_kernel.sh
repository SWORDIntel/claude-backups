#!/bin/bash

# Fix dependency issues and install kernel with NPU/GNA support

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Fixing ZFS dependency conflicts...${NC}"

# Fix the ZFS library conflicts
echo "Removing conflicting ZFS packages..."
sudo dpkg --remove --force-depends libnvpair3 libuutil3 2>/dev/null || true

echo "Fixing broken packages..."
sudo apt --fix-broken install -y

echo "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

# Try to install the kernel again
echo -e "\n${YELLOW}Installing kernel 6.12.13...${NC}"
sudo apt update

# Install kernel without recommends to avoid pulling in ZFS
sudo apt install --no-install-recommends -y \
    linux-image-6.12.13-1-siduction-amd64 \
    linux-headers-6.12.13-1-siduction-amd64

# Get NPU firmware quickly
echo -e "\n${YELLOW}Installing NPU firmware...${NC}"
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/

# Configure module loading
echo -e "\n${YELLOW}Configuring modules...${NC}"
cat << 'EOF' | sudo tee /etc/modules-load.d/intel-npu.conf
intel_vpu
EOF

# Update initramfs
echo -e "\n${YELLOW}Updating initramfs...${NC}"
sudo update-initramfs -u -k 6.12.13-1-siduction-amd64

echo -e "\n${GREEN}✅ Kernel 6.12.13 installed with NPU support!${NC}"
echo -e "${GREEN}Please reboot and select the new kernel in GRUB.${NC}"
echo ""
echo "After reboot, check NPU with:"
echo "  ls /dev/accel*"
echo "  lsmod | grep vpu"
echo ""
echo "For GNA support, you can:"
echo "  1. Use OpenVINO's GNA plugin (already installed)"
echo "  2. Build GNA driver later when system is stable"