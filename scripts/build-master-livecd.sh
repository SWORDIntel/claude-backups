#!/bin/bash
#
# Master LiveCD Build Script
# Builds complete LiveCD with all modules and ZFS Boot Menu recovery
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROOT_DIR="${CHROOT_DIR:-/tmp/livecd-chroot}"
ISO_NAME="${ISO_NAME:-livecd-meteor-lake-$(date +%Y%m%d).iso}"
WORK_DIR="${WORK_DIR:-/tmp/livecd-work}"
ZBM_EFI="${SCRIPT_DIR}/zfsbootmenu-recovery-x86_64-v3.0.1-linux6.6.EFI"

# Source common library
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
}

echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║          MASTER LIVECD BUILD WITH ZFS BOOT MENU               ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verify prerequisites
check_prerequisites() {
    echo -e "${CYAN}[1/10] Checking prerequisites...${NC}"
    
    local required_tools=(
        "cdebootstrap"
        "xorriso"
        "squashfs-tools"
        "grub-pc-bin"
        "grub-efi-amd64-bin"
        "mtools"
        "dosfstools"
    )
    
    for tool in "${required_tools[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$tool"; then
            log_warn "Installing $tool..."
            apt-get install -y "$tool"
        fi
    done
    
    # Check for ZFS Boot Menu EFI
    if [ -f "$ZBM_EFI" ]; then
        echo -e "${GREEN}✓ ZFS Boot Menu EFI found: $ZBM_EFI${NC}"
    else
        echo -e "${YELLOW}⚠ ZFS Boot Menu EFI not found, will build from source${NC}"
    fi
}

# Create base system
create_base_system() {
    echo -e "${CYAN}[2/10] Creating base system...${NC}"
    
    # Clean up previous build
    if [ -d "$CHROOT_DIR" ]; then
        log_warn "Removing previous build..."
        umount -R "$CHROOT_DIR"/{dev,proc,sys,run} 2>/dev/null || true
        rm -rf "$CHROOT_DIR"
    fi
    
    mkdir -p "$CHROOT_DIR"
    
    # Run core_system module
    "${SCRIPT_DIR}/modules/core_system.sh" "$CHROOT_DIR" all
}

# Install all modules
install_modules() {
    echo -e "${CYAN}[3/10] Installing all modules...${NC}"
    
    local modules=(
        "hardware_security.sh:all"
        "desktop_tools.sh:all"
        "development_env.sh:all"
        "monitoring_recovery.sh:all"
        "network_deployment.sh:all"
        "military_intel.sh:all"
    )
    
    for module_spec in "${modules[@]}"; do
        local module="${module_spec%:*}"
        local action="${module_spec#*:}"
        
        if [ -f "${SCRIPT_DIR}/modules/${module}" ]; then
            echo -e "${BLUE}Installing ${module}...${NC}"
            "${SCRIPT_DIR}/modules/${module}" "$CHROOT_DIR" "$action"
        else
            log_warn "Module not found: ${module}"
        fi
    done
}

# Install ZFS Boot Menu EFI
install_zbm_efi() {
    echo -e "${CYAN}[4/10] Installing ZFS Boot Menu EFI...${NC}"
    
    # Create EFI directory structure
    mkdir -p "$CHROOT_DIR/boot/efi/EFI/zbm"
    mkdir -p "$CHROOT_DIR/boot/efi/EFI/BOOT"
    
    if [ -f "$ZBM_EFI" ]; then
        # Copy prebuilt ZBM EFI
        cp "$ZBM_EFI" "$CHROOT_DIR/boot/efi/EFI/zbm/zfsbootmenu.EFI"
        
        # Also copy as fallback boot option
        cp "$ZBM_EFI" "$CHROOT_DIR/boot/efi/EFI/BOOT/BOOTX64.EFI"
        
        echo -e "${GREEN}✓ ZFS Boot Menu EFI installed${NC}"
        
        # Create refind_linux.conf for ZBM
        cat > "$CHROOT_DIR/boot/efi/EFI/zbm/refind_linux.conf" << 'EOF'
"Boot ZFS Boot Menu"         "ro quiet loglevel=0 zbm.show zbm.timeout=30"
"Boot ZFS Boot Menu (Debug)" "ro loglevel=7 zbm.show zbm.timeout=30 zbm.debug"
"Boot ZFS Recovery Shell"    "ro loglevel=7 zbm.show zbm.timeout=30 zbm.emergency"
EOF
    else
        log_warn "ZBM EFI not found, building from source..."
        # This will be handled by core_system module
    fi
}

# Configure boot loader
configure_bootloader() {
    echo -e "${CYAN}[5/10] Configuring bootloader...${NC}"
    
    # Mount necessary filesystems
    mount --bind /dev "$CHROOT_DIR/dev"
    mount --bind /proc "$CHROOT_DIR/proc"
    mount --bind /sys "$CHROOT_DIR/sys"
    mount --bind /run "$CHROOT_DIR/run"
    
    # Install GRUB for both BIOS and UEFI
    chroot "$CHROOT_DIR" bash -c '
        # Install GRUB packages
        apt-get install -y grub-pc grub-efi-amd64 grub-efi-amd64-signed shim-signed
        
        # Update GRUB configuration
        cat >> /etc/default/grub << EOF

# ZFS Boot Menu Integration
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX="ro quiet splash"
EOF
        
        # Create custom GRUB entry for ZFS Boot Menu
        cat > /etc/grub.d/15_zfsbootmenu << "GRUB"
#!/bin/sh
exec tail -n +3 $0

menuentry "ZFS Boot Menu Recovery" {
    search --set=root --file /EFI/zbm/zfsbootmenu.EFI
    chainloader /EFI/zbm/zfsbootmenu.EFI
}

menuentry "ZFS Boot Menu (Emergency Shell)" {
    search --set=root --file /EFI/zbm/zfsbootmenu.EFI
    chainloader /EFI/zbm/zfsbootmenu.EFI zbm.emergency
}
GRUB
        chmod +x /etc/grub.d/15_zfsbootmenu
        
        # Update GRUB
        update-grub
    '
    
    # Unmount filesystems
    umount "$CHROOT_DIR"/{run,sys,proc,dev}
}

# Build custom kernel (optional)
build_custom_kernel() {
    echo -e "${CYAN}[6/10] Building custom kernel...${NC}"
    
    if [ "${BUILD_KERNEL:-false}" = "true" ]; then
        chroot "$CHROOT_DIR" bash -c '
            cd /usr/src
            
            # Download latest stable kernel
            KERNEL_VERSION="6.6.12"
            wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
            tar -xf "linux-${KERNEL_VERSION}.tar.xz"
            cd "linux-${KERNEL_VERSION}"
            
            # Configure for LiveCD with ZFS support
            make defconfig
            scripts/config --enable CONFIG_ZFS
            scripts/config --enable CONFIG_SQUASHFS
            scripts/config --enable CONFIG_OVERLAY_FS
            scripts/config --enable CONFIG_EFI_STUB
            
            # Build kernel
            make -j$(nproc) bzImage modules
            make modules_install
            make install
            
            # Build ZFS Boot Menu with new kernel
            cd /opt/zfs-bootmenu/zfsbootmenu
            make generate-zbm KERNEL_VERSION="${KERNEL_VERSION}"
        '
        echo -e "${GREEN}✓ Custom kernel built with ZFS support${NC}"
    else
        echo -e "${YELLOW}Skipping custom kernel build (set BUILD_KERNEL=true to enable)${NC}"
    fi
}

# Create squashfs filesystem
create_squashfs() {
    echo -e "${CYAN}[7/10] Creating squashfs filesystem...${NC}"
    
    # Clean up
    rm -f "$WORK_DIR/filesystem.squashfs"
    mkdir -p "$WORK_DIR"
    
    # Create squashfs
    mksquashfs "$CHROOT_DIR" "$WORK_DIR/filesystem.squashfs" \
        -comp xz \
        -b 1M \
        -no-xattrs \
        -e boot/efi \
        -e proc \
        -e sys \
        -e dev \
        -e run \
        -e tmp
    
    echo -e "${GREEN}✓ Squashfs created${NC}"
}

# Create ISO structure
create_iso_structure() {
    echo -e "${CYAN}[8/10] Creating ISO structure...${NC}"
    
    # Create ISO directory structure
    ISO_DIR="$WORK_DIR/iso"
    rm -rf "$ISO_DIR"
    mkdir -p "$ISO_DIR"/{boot,EFI,live,isolinux,.disk}
    
    # Copy kernel and initrd
    cp "$CHROOT_DIR"/boot/vmlinuz* "$ISO_DIR/live/vmlinuz" || \
        cp "$CHROOT_DIR"/vmlinuz "$ISO_DIR/live/vmlinuz"
    cp "$CHROOT_DIR"/boot/initrd* "$ISO_DIR/live/initrd" || \
        cp "$CHROOT_DIR"/initrd.img "$ISO_DIR/live/initrd"
    
    # Copy squashfs
    cp "$WORK_DIR/filesystem.squashfs" "$ISO_DIR/live/"
    
    # Copy ZFS Boot Menu EFI
    mkdir -p "$ISO_DIR/EFI/zbm"
    if [ -f "$CHROOT_DIR/boot/efi/EFI/zbm/zfsbootmenu.EFI" ]; then
        cp "$CHROOT_DIR/boot/efi/EFI/zbm/zfsbootmenu.EFI" "$ISO_DIR/EFI/zbm/"
    fi
    
    # Create GRUB configuration for ISO
    mkdir -p "$ISO_DIR/boot/grub"
    cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Boot LiveCD with ZFS Support" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "Boot LiveCD (Debug Mode)" {
    linux /live/vmlinuz boot=live debug nosplash
    initrd /live/initrd
}

menuentry "ZFS Boot Menu Recovery" {
    chainloader /EFI/zbm/zfsbootmenu.EFI
}

menuentry "System Recovery Shell" {
    linux /live/vmlinuz boot=live single
    initrd /live/initrd
}

menuentry "Memory Test" {
    linux16 /boot/memtest86+.bin
}
EOF
    
    # Create disk info
    echo "Military-Grade LiveCD with ZFS Boot Menu" > "$ISO_DIR/.disk/info"
    echo "Built on $(date)" >> "$ISO_DIR/.disk/info"
}

# Create EFI boot image
create_efi_image() {
    echo -e "${CYAN}[9/10] Creating EFI boot image...${NC}"
    
    # Create EFI image
    EFI_IMG="$WORK_DIR/efiboot.img"
    dd if=/dev/zero of="$EFI_IMG" bs=1M count=50
    mkfs.vfat -F 32 "$EFI_IMG"
    
    # Mount and populate EFI image
    EFI_MOUNT="$WORK_DIR/efi_mount"
    mkdir -p "$EFI_MOUNT"
    mount -o loop "$EFI_IMG" "$EFI_MOUNT"
    
    # Create EFI structure
    mkdir -p "$EFI_MOUNT/EFI/BOOT"
    mkdir -p "$EFI_MOUNT/EFI/zbm"
    
    # Copy GRUB EFI
    if [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
        cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$EFI_MOUNT/EFI/BOOT/BOOTX64.EFI"
    fi
    
    # Copy ZFS Boot Menu EFI
    if [ -f "$ISO_DIR/EFI/zbm/zfsbootmenu.EFI" ]; then
        cp "$ISO_DIR/EFI/zbm/zfsbootmenu.EFI" "$EFI_MOUNT/EFI/zbm/"
        # Also as secondary boot option
        cp "$ISO_DIR/EFI/zbm/zfsbootmenu.EFI" "$EFI_MOUNT/EFI/BOOT/BOOTZBM.EFI"
    fi
    
    # Create startup script
    cat > "$EFI_MOUNT/startup.nsh" << 'EOF'
@echo -off
echo "Military-Grade LiveCD with ZFS Boot Menu"
echo "Press any key to boot, or wait 5 seconds..."
pause 5
\EFI\zbm\zfsbootmenu.EFI
EOF
    
    umount "$EFI_MOUNT"
    
    echo -e "${GREEN}✓ EFI boot image created${NC}"
}

# Build final ISO
build_iso() {
    echo -e "${CYAN}[10/10] Building final ISO...${NC}"
    
    # Build hybrid ISO with both BIOS and UEFI support
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "LIVECD_ZFS" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -eltorito-alt-boot \
        -e efiboot.img \
        -no-emul-boot \
        -append_partition 2 0xef "$WORK_DIR/efiboot.img" \
        -output "$ISO_NAME" \
        "$ISO_DIR"
    
    # Make ISO bootable on USB
    isohybrid --uefi "$ISO_NAME" 2>/dev/null || true
    
    echo -e "${GREEN}✓ ISO created: $ISO_NAME${NC}"
    echo -e "${GREEN}Size: $(du -h "$ISO_NAME" | cut -f1)${NC}"
}

# Main build process
main() {
    echo "Starting build at $(date)"
    echo "Build directory: $CHROOT_DIR"
    echo "Output ISO: $ISO_NAME"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Run build steps
    check_prerequisites
    create_base_system
    install_modules
    install_zbm_efi
    configure_bootloader
    build_custom_kernel
    create_squashfs
    create_iso_structure
    create_efi_image
    build_iso
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    BUILD COMPLETE!                             ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}ISO created successfully: $ISO_NAME${NC}"
    echo ""
    echo "To test the ISO:"
    echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom $ISO_NAME"
    echo ""
    echo "To write to USB:"
    echo "  dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "ZFS Boot Menu will be available as:"
    echo "  - Primary EFI boot option"
    echo "  - GRUB menu entry"
    echo "  - Direct EFI file at \\EFI\\zbm\\zfsbootmenu.EFI"
}

# Run main function
main "$@"