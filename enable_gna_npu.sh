#!/bin/bash

# Enable GNA and NPU for Intel Core Ultra 7 155H
# The GNA driver is NOT in mainline kernels yet - needs out-of-tree driver

set -e

echo "============================================"
echo "GNA + NPU Enabler for Meteor Lake"
echo "============================================"

# Install kernel 6.12.13 from siduction
echo "📦 Installing kernel 6.12.13 (has NPU, GNA needs manual add)..."
sudo apt update
sudo apt install -y linux-image-6.12.13-1-siduction-amd64 linux-headers-6.12.13-1-siduction-amd64

# Get NPU firmware
echo "📥 Downloading NPU firmware..."
cd /tmp
wget -q https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
sudo mkdir -p /lib/firmware/intel/vpu /lib/firmware/intel/ivpu
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/ivpu/

# Build GNA driver from Intel's out-of-tree source
echo "🔧 Building Intel GNA driver (out-of-tree)..."
cd /tmp
git clone https://github.com/intel/gna-driver.git
cd gna-driver

# Check if we have the kernel headers
if [ ! -d "/lib/modules/6.12.13-1-siduction-amd64/build" ]; then
    echo "❌ Kernel headers not found. Installing..."
    sudo apt install -y linux-headers-6.12.13-1-siduction-amd64
fi

# Build the GNA module
echo "🔨 Compiling GNA module..."
make -C /lib/modules/6.12.13-1-siduction-amd64/build M=$PWD modules

# Install the module
echo "📦 Installing GNA module..."
sudo make -C /lib/modules/6.12.13-1-siduction-amd64/build M=$PWD modules_install
sudo depmod 6.12.13-1-siduction-amd64

# Create modprobe config for auto-loading
echo "⚙️ Configuring module auto-loading..."
cat << EOF | sudo tee /etc/modprobe.d/intel-neural.conf
# Intel NPU (Neural Processing Unit)
options intel_vpu enable_debugfs=1

# Intel GNA (Gaussian Neural Accelerator)
# No special options needed
EOF

cat << EOF | sudo tee /etc/modules-load.d/intel-neural.conf
# Load Intel Neural Accelerators at boot
intel_vpu
intel_gna
EOF

# Alternative: Try the DKMS approach for GNA
echo "🔄 Setting up DKMS for automatic rebuilds..."
sudo apt install -y dkms
cd /tmp/gna-driver
sudo mkdir -p /usr/src/intel-gna-1.0.0
sudo cp -r * /usr/src/intel-gna-1.0.0/

cat << EOF | sudo tee /usr/src/intel-gna-1.0.0/dkms.conf
PACKAGE_NAME="intel-gna"
PACKAGE_VERSION="1.0.0"
BUILT_MODULE_NAME[0]="intel_gna"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
REMAKE_INITRD="yes"
EOF

sudo dkms add -m intel-gna -v 1.0.0
sudo dkms build -m intel-gna -v 1.0.0 -k 6.12.13-1-siduction-amd64
sudo dkms install -m intel-gna -v 1.0.0 -k 6.12.13-1-siduction-amd64

# Update initramfs
echo "🔄 Updating initramfs..."
sudo update-initramfs -u -k 6.12.13-1-siduction-amd64

echo ""
echo "✅ Installation Complete!"
echo ""
echo "The GNA driver situation:"
echo "  - GNA 3.0 support is NOT in mainline Linux yet"
echo "  - Intel provides an out-of-tree driver (built above)"
echo "  - Alternative: Use OpenVINO's GNA plugin (userspace)"
echo ""
echo "NPU status:"
echo "  - NPU driver (intel_vpu) IS in kernel 6.12+"
echo "  - Should work after reboot"
echo ""
echo "Next steps:"
echo "  1. Reboot and select kernel 6.12.13 in GRUB"
echo "  2. Check: ls /dev/accel* (for NPU)"
echo "  3. Check: ls /dev/gna* (for GNA if driver loads)"
echo "  4. Check: lsmod | grep -E 'vpu|gna'"
echo ""
echo "If GNA doesn't show up, use OpenVINO's userspace GNA:"
echo "  - OpenVINO includes GNA support without kernel driver"
echo "  - Located at: /opt/intel/openvino/runtime/lib/intel64/libopenvino_intel_gna_plugin.so"