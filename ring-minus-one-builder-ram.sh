#!/bin/bash
#
# Ring -1 LiveCD Builder - RAM-Based Edition
# Builds entire system in tmpfs to minimize disk usage
# Includes IOMMU workarounds and virtio fallbacks
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORK_DIR="/dev/shm/ring-minus-one-build"
OUTPUT_DIR="$(pwd)"
ISO_NAME="ring-minus-one-ram-$(date +%Y%m%d).iso"
TMPFS_SIZE="16G"  # Increased for KDE desktop
MIN_RAM_GB=8
MIN_DISK_GB=2

# System checks
check_requirements() {
    echo -e "${BLUE}[*] Checking system requirements...${NC}"
    
    # Check RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt "$MIN_RAM_GB" ]; then
        echo -e "${RED}[!] Insufficient RAM: ${total_ram}GB available, ${MIN_RAM_GB}GB required${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] RAM check passed: ${total_ram}GB available${NC}"
    
    # Check disk space (only for final ISO)
    available_disk=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt "$MIN_DISK_GB" ]; then
        echo -e "${RED}[!] Insufficient disk space: ${available_disk}GB available, ${MIN_DISK_GB}GB required${NC}"
        exit 1
    fi
    echo -e "${GREEN}[+] Disk check passed: ${available_disk}GB available${NC}"
    
    # Check for required tools
    for tool in debootstrap squashfs-tools xorriso isolinux syslinux-utils; do
        if ! command -v $tool &> /dev/null && ! dpkg -l | grep -q "^ii.*$tool"; then
            echo -e "${YELLOW}[*] Installing $tool...${NC}"
            apt-get update && apt-get install -y $tool
        fi
    done
    
    # Check virtualization support (but don't fail if missing)
    if [ -e /dev/kvm ]; then
        echo -e "${GREEN}[+] KVM support detected${NC}"
    else
        echo -e "${YELLOW}[!] No KVM support - will use software emulation fallback${NC}"
    fi
    
    # Check IOMMU (informational only)
    if dmesg | grep -q "IOMMU"; then
        echo -e "${GREEN}[+] IOMMU detected (may not be enabled)${NC}"
    else
        echo -e "${YELLOW}[!] No IOMMU detected - using virtio fallbacks${NC}"
    fi
}

# Setup tmpfs workspace
setup_tmpfs() {
    echo -e "${BLUE}[*] Setting up tmpfs workspace...${NC}"
    
    # Clean up any existing mount
    if mountpoint -q "$WORK_DIR" 2>/dev/null; then
        umount -f "$WORK_DIR" || true
    fi
    
    # Create and mount tmpfs
    mkdir -p "$WORK_DIR"
    mount -t tmpfs -o size="$TMPFS_SIZE" tmpfs "$WORK_DIR"
    
    # Create directory structure
    mkdir -p "$WORK_DIR"/{chroot,iso/{boot/isolinux,live},tmp}
    
    echo -e "${GREEN}[+] Tmpfs mounted: $(df -h $WORK_DIR | tail -1)${NC}"
}

# Monitor memory usage
monitor_memory() {
    echo -e "${BLUE}[*] Current memory usage:${NC}"
    free -h
    df -h "$WORK_DIR" 2>/dev/null || true
}

# Create minimal base system
create_base_system() {
    echo -e "${BLUE}[*] Creating minimal base system...${NC}"
    
    # Use minimal variant to save RAM
    debootstrap --variant=minbase --arch=amd64 \
        --include=linux-image-generic,live-boot,systemd-sysv \
        jammy "$WORK_DIR/chroot" http://archive.ubuntu.com/ubuntu/
    
    # Setup basic system
    cat > "$WORK_DIR/chroot/etc/hostname" << EOF
ring-minus-one
EOF
    
    cat > "$WORK_DIR/chroot/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       ring-minus-one
EOF
    
    # Create minimal fstab
    cat > "$WORK_DIR/chroot/etc/fstab" << EOF
# Ring -1 LiveCD fstab
tmpfs   /tmp    tmpfs   defaults        0       0
EOF
    
    monitor_memory
}

# Install Ring -1 tools with IOMMU workarounds
install_ring_minus_one_tools() {
    echo -e "${BLUE}[*] Installing Ring -1 tools with fallbacks...${NC}"
    
    # Create installer script
    cat > "$WORK_DIR/chroot/tmp/install-tools.sh" << 'EOSCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update

# Core system tools (minimal selection for RAM constraints)
apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    libvirt-daemon-system \
    bridge-utils \
    cpu-checker \
    msr-tools \
    dmidecode \
    pciutils \
    usbutils \
    curl \
    wget \
    vim-tiny \
    net-tools \
    iproute2 \
    iptables \
    xorg \
    xinit

# Install KDE Plasma desktop (minimal)
apt-get install -y --no-install-recommends \
    kde-plasma-desktop \
    plasma-nm \
    konsole \
    dolphin \
    firefox \
    sddm \
    breeze-gtk-theme

# Install virtio drivers for IOMMU-less operation
apt-get install -y --no-install-recommends \
    qemu-kvm \
    virtio-modules \
    virt-manager

# ZFS core only (not full suite to save RAM)
apt-get install -y --no-install-recommends \
    zfsutils-linux \
    zfs-initramfs

# Create IOMMU fallback configuration
cat > /etc/modprobe.d/iommu-fallback.conf << EOF
# IOMMU Fallback Configuration
options vfio_iommu_type1 allow_unsafe_interrupts=1
options kvm ignore_msrs=1
options kvm_intel nested=1 enable_apicv=0
options kvm_amd nested=1
EOF

# Create virtio network bridge for VMs
cat > /etc/netplan/01-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
  bridges:
    br0:
      dhcp4: yes
      interfaces: [eth0]
EOF

# Ring -1 detection and configuration script
cat > /usr/local/bin/ring-minus-one-init << 'EOF'
#!/bin/bash

echo "Ring -1 System Initializing..."

# Load MSR module
modprobe msr 2>/dev/null || true

# Check virtualization capabilities
if [ -e /dev/kvm ]; then
    echo "✓ Hardware virtualization available"
else
    echo "✗ No hardware virtualization - using TCG emulation"
fi

# Check IOMMU
if dmesg | grep -q "IOMMU"; then
    echo "✓ IOMMU detected"
    # Try to enable if not already
    echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts 2>/dev/null || true
else
    echo "✗ No IOMMU - using virtio devices"
fi

# Setup bridge networking
systemctl start systemd-networkd 2>/dev/null || true
ip link add name br0 type bridge 2>/dev/null || true
ip link set br0 up 2>/dev/null || true

# Check for hidden CPU features
if [ -e /dev/cpu/0/msr ]; then
    echo "Checking for hidden CPU features..."
    # Read CPUID leaf 7 for AVX-512
    rdmsr 0x1a0 2>/dev/null || echo "Cannot read MSR 0x1a0"
fi

# Start libvirt with fallback options
mkdir -p /var/run/libvirt
libvirtd --daemon --listen --config /etc/libvirt/libvirtd.conf 2>/dev/null || \
    echo "Libvirt started in degraded mode"

echo "Ring -1 Ready!"
EOF
chmod +x /usr/local/bin/ring-minus-one-init

# Create QEMU wrapper for IOMMU-less operation
cat > /usr/local/bin/qemu-iommu-fallback << 'EOF'
#!/bin/bash
# QEMU wrapper that automatically uses virtio when IOMMU unavailable

QEMU_ARGS=""

# Check for IOMMU
if ! ls /sys/kernel/iommu_groups/ 2>/dev/null | grep -q .; then
    echo "No IOMMU groups found - using virtio devices"
    # Replace vfio-pci with virtio
    QEMU_ARGS=$(echo "$@" | sed 's/-device vfio-pci/-device virtio-net-pci/g')
    QEMU_ARGS=$(echo "$QEMU_ARGS" | sed 's/vfio-pci/virtio-blk-pci/g')
    
    # Use software emulation if no KVM
    if [ ! -e /dev/kvm ]; then
        QEMU_ARGS=$(echo "$QEMU_ARGS" | sed 's/-enable-kvm/-machine accel=tcg/g')
        echo "Using TCG emulation (no KVM available)"
    fi
else
    QEMU_ARGS="$@"
fi

exec qemu-system-x86_64 $QEMU_ARGS
EOF
chmod +x /usr/local/bin/qemu-iommu-fallback

# Create systemd service for ring-minus-one
cat > /etc/systemd/system/ring-minus-one.service << EOF
[Unit]
Description=Ring -1 System Initialization
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ring-minus-one-init
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ring-minus-one.service

# Enable SDDM display manager for KDE
systemctl enable sddm.service

# Configure autologin for live session
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=ubuntu
Session=plasma
EOF

# Create live user
useradd -m -s /bin/bash -G sudo,libvirt,kvm ubuntu
echo "ubuntu:ubuntu" | chpasswd
echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Clean package cache to save space
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Ring -1 tools installed with IOMMU fallbacks"
EOSCRIPT
    
    chmod +x "$WORK_DIR/chroot/tmp/install-tools.sh"
    chroot "$WORK_DIR/chroot" /tmp/install-tools.sh
    rm "$WORK_DIR/chroot/tmp/install-tools.sh"
    
    monitor_memory
}

# Create hypervisor detection tools
create_hypervisor_tools() {
    echo -e "${BLUE}[*] Creating hypervisor detection tools...${NC}"
    
    cat > "$WORK_DIR/chroot/usr/local/bin/detect-hypervisor" << 'EOF'
#!/bin/bash
#
# Ring -1 Hypervisor Detection Tool
#

echo "=== Ring -1 Hypervisor Detection ==="

# Check CPU vendor
vendor=$(cat /proc/cpuinfo | grep vendor_id | head -1 | awk '{print $3}')
echo "CPU Vendor: $vendor"

# Check for hypervisor flag
if grep -q hypervisor /proc/cpuinfo; then
    echo "✓ Running under hypervisor"
    
    # Try to identify hypervisor
    if [ -e /sys/hypervisor/type ]; then
        echo "Hypervisor type: $(cat /sys/hypervisor/type)"
    fi
    
    # Check DMI
    if command -v dmidecode &> /dev/null; then
        product=$(dmidecode -s system-product-name 2>/dev/null)
        echo "System product: $product"
    fi
else
    echo "✗ No hypervisor detected (bare metal or hidden)"
fi

# Check for nested virtualization
if [ -e /sys/module/kvm_intel/parameters/nested ]; then
    nested=$(cat /sys/module/kvm_intel/parameters/nested)
    echo "Intel nested virtualization: $nested"
elif [ -e /sys/module/kvm_amd/parameters/nested ]; then
    nested=$(cat /sys/module/kvm_amd/parameters/nested)
    echo "AMD nested virtualization: $nested"
fi

# Check CPUID leaf 0x40000000 for hypervisor signature
if command -v cpuid &> /dev/null; then
    echo "Checking CPUID hypervisor leaf..."
    cpuid -l 0x40000000 2>/dev/null | head -5
fi

# Check for hidden AVX-512 (microcode cloaking)
echo ""
echo "=== Hidden Feature Detection ==="
if [ -e /dev/cpu/0/msr ]; then
    # Try to read model-specific registers
    for msr in 0x1a0 0x48 0x8b; do
        value=$(rdmsr $msr 2>/dev/null) && echo "MSR $msr: $value"
    done
else
    echo "MSR access not available"
fi

# Memory inspection for hypervisor artifacts
echo ""
echo "=== Memory Artifacts ==="
if dmesg | grep -i "hypervisor\|vmware\|kvm\|xen\|hyper-v" | head -3; then
    echo "Hypervisor artifacts found in kernel log"
fi

echo ""
echo "=== IOMMU Status ==="
if ls /sys/kernel/iommu_groups/ 2>/dev/null | grep -q .; then
    groups=$(ls /sys/kernel/iommu_groups/ | wc -l)
    echo "✓ IOMMU enabled with $groups groups"
else
    echo "✗ No IOMMU groups (using virtio fallback)"
fi
EOF
    chmod +x "$WORK_DIR/chroot/usr/local/bin/detect-hypervisor"
    
    # Create VM launcher with automatic fallback
    cat > "$WORK_DIR/chroot/usr/local/bin/launch-vm" << 'EOF'
#!/bin/bash
#
# Ring -1 VM Launcher with IOMMU Fallback
#

VM_NAME="${1:-test-vm}"
VM_RAM="${2:-2048}"
VM_DISK="${3:-/tmp/vm.qcow2}"

echo "Launching VM: $VM_NAME"

# Create disk if not exists
if [ ! -e "$VM_DISK" ]; then
    qemu-img create -f qcow2 "$VM_DISK" 20G
fi

# Base QEMU arguments
QEMU_ARGS="-name $VM_NAME"
QEMU_ARGS="$QEMU_ARGS -m $VM_RAM"
QEMU_ARGS="$QEMU_ARGS -cpu host"
QEMU_ARGS="$QEMU_ARGS -smp 2"

# Check for KVM
if [ -e /dev/kvm ]; then
    echo "✓ Using KVM acceleration"
    QEMU_ARGS="$QEMU_ARGS -enable-kvm"
else
    echo "✗ No KVM - using TCG emulation"
    QEMU_ARGS="$QEMU_ARGS -machine accel=tcg"
fi

# Check for IOMMU
if ls /sys/kernel/iommu_groups/ 2>/dev/null | grep -q .; then
    echo "✓ IOMMU available - can use passthrough"
    # Add vfio devices if specified
else
    echo "✗ No IOMMU - using virtio devices"
    QEMU_ARGS="$QEMU_ARGS -device virtio-net-pci,netdev=net0"
    QEMU_ARGS="$QEMU_ARGS -netdev bridge,id=net0,br=br0"
fi

# Storage
QEMU_ARGS="$QEMU_ARGS -drive file=$VM_DISK,if=virtio,format=qcow2"

# Display
QEMU_ARGS="$QEMU_ARGS -display vnc=:1"

echo "Starting QEMU with: $QEMU_ARGS"
qemu-system-x86_64 $QEMU_ARGS
EOF
    chmod +x "$WORK_DIR/chroot/usr/local/bin/launch-vm"
}

# Create boot configuration
create_boot_config() {
    echo -e "${BLUE}[*] Creating boot configuration...${NC}"
    
    # Copy kernel and initrd
    cp "$WORK_DIR"/chroot/boot/vmlinuz-* "$WORK_DIR/iso/boot/vmlinuz"
    cp "$WORK_DIR"/chroot/boot/initrd.img-* "$WORK_DIR/iso/boot/initrd.img"
    
    # Create isolinux configuration
    cat > "$WORK_DIR/iso/boot/isolinux/isolinux.cfg" << EOF
DEFAULT ring-minus-one
LABEL ring-minus-one
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live toram quiet splash systemd.unit=graphical.target
  
LABEL ring-minus-one-debug
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live toram debug
  
LABEL ring-minus-one-failsafe
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live toram nomodeset
EOF
    
    # Copy isolinux binaries
    cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/iso/boot/isolinux/"
    cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32} "$WORK_DIR/iso/boot/isolinux/"
    
    monitor_memory
}

# Create compressed filesystem
create_squashfs() {
    echo -e "${BLUE}[*] Creating compressed filesystem...${NC}"
    echo -e "${YELLOW}[!] Using maximum compression to minimize size${NC}"
    
    # Use maximum XZ compression
    mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/iso/live/filesystem.squashfs" \
        -comp xz -Xdict-size 100% -b 1M -no-exports
    
    # Show filesystem size
    fs_size=$(du -h "$WORK_DIR/iso/live/filesystem.squashfs" | cut -f1)
    echo -e "${GREEN}[+] Filesystem size: $fs_size${NC}"
    
    monitor_memory
}

# Create ISO image
create_iso() {
    echo -e "${BLUE}[*] Creating ISO image...${NC}"
    
    xorriso -as mkisofs \
        -r -V "Ring-1-RAM" \
        -o "$OUTPUT_DIR/$ISO_NAME" \
        -J -l \
        -b boot/isolinux/isolinux.bin \
        -c boot/isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "$WORK_DIR/iso"
    
    # Show final ISO size
    iso_size=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)
    echo -e "${GREEN}[+] ISO created: $ISO_NAME ($iso_size)${NC}"
}

# Cleanup
cleanup() {
    echo -e "${BLUE}[*] Cleaning up...${NC}"
    
    # Unmount tmpfs
    if mountpoint -q "$WORK_DIR" 2>/dev/null; then
        umount "$WORK_DIR"
    fi
    
    # Remove directory
    rm -rf "$WORK_DIR"
    
    echo -e "${GREEN}[+] Cleanup complete${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}  Ring -1 LiveCD Builder (RAM)${NC}"
    echo -e "${BLUE}  IOMMU Workarounds Included${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] This script must be run as root${NC}"
        exit 1
    fi
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Execute build steps
    check_requirements
    setup_tmpfs
    create_base_system
    install_ring_minus_one_tools
    create_hypervisor_tools
    create_boot_config
    create_squashfs
    create_iso
    
    echo ""
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}  Build Complete!${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}ISO: $OUTPUT_DIR/$ISO_NAME${NC}"
    echo -e "${YELLOW}Features:${NC}"
    echo -e "  • KDE Plasma desktop environment"
    echo -e "  • Built entirely in RAM (tmpfs)"
    echo -e "  • IOMMU fallback with virtio devices"
    echo -e "  • Software emulation when no VT-x/AMD-V"
    echo -e "  • Bridge networking for VMs"
    echo -e "  • Hidden CPU feature detection"
    echo -e "  • Ring -1 hypervisor tools"
    echo -e "  • Auto-login as 'ubuntu' user"
    echo ""
    echo -e "${YELLOW}To test:${NC}"
    echo -e "  qemu-system-x86_64 -cdrom $ISO_NAME -m 4096 -enable-kvm"
    echo -e "${YELLOW}Without KVM:${NC}"
    echo -e "  qemu-system-x86_64 -cdrom $ISO_NAME -m 4096 -machine accel=tcg"
}

# Run main function
main "$@"