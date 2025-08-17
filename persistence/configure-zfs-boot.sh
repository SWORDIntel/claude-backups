#!/bin/bash
# Configure ZFS-first boot with RAM pool and persistence
# Ensures ZFS stream is always loaded to RAM with optional persistence

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}         ZFS RAM BOOT WITH PERSISTENCE CONFIGURATION           ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Function to configure build for ZFS-first boot
configure_zfs_priority_boot() {
    local chroot_dir="${1:-/mnt/buildpool/livecd-builds/current/chroot}"
    local image_dir="${2:-/mnt/buildpool/livecd-builds/current/image}"
    
    echo -e "${GREEN}[+] Configuring ZFS as primary boot method${NC}"
    
    # Create initramfs hook for ZFS RAM pool creation
    cat > "$chroot_dir/usr/share/initramfs-tools/scripts/init-premount/zfs-ram-boot" << 'ZFS_BOOT_HOOK'
#!/bin/sh
# ZFS RAM pool creation hook
# Creates ZFS pool in RAM and receives stream

PREREQ=""
prereqs() {
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /scripts/functions

# Function to create RAM-based ZFS pool
create_ram_pool() {
    log_begin_msg "Creating ZFS pool in RAM"
    
    # Load ZFS modules
    modprobe zfs || true
    
    # Determine RAM size and allocate 50% for ZFS pool
    total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    pool_size_kb=$((total_ram / 2))
    pool_size_mb=$((pool_size_kb / 1024))
    
    echo "Allocating ${pool_size_mb}MB for ZFS RAM pool"
    
    # Create RAM disk using zram or tmpfs
    if modprobe zram 2>/dev/null; then
        # Use zram (compressed RAM disk)
        echo $pool_size_kb > /sys/block/zram0/disksize
        pool_device="/dev/zram0"
    else
        # Fallback to ramdisk
        modprobe brd rd_size=$pool_size_kb
        pool_device="/dev/ram0"
    fi
    
    # Create ZFS pool in RAM
    zpool create -f \
        -o ashift=12 \
        -O compression=lz4 \
        -O atime=off \
        -O devices=off \
        -O exec=on \
        -m none \
        livepool $pool_device
    
    # Create root dataset
    zfs create -o mountpoint=/ livepool/root
    
    log_end_msg 0
}

# Function to receive ZFS stream
receive_zfs_stream() {
    log_begin_msg "Receiving ZFS stream into RAM pool"
    
    # Find the ZFS stream file
    stream_file=""
    for device in $(blkid -o device); do
        mkdir -p /cdrom
        if mount -o ro $device /cdrom 2>/dev/null; then
            if [ -f /cdrom/zfs/filesystem.zfs.zst ]; then
                stream_file="/cdrom/zfs/filesystem.zfs.zst"
                break
            fi
            umount /cdrom
        fi
    done
    
    if [ -n "$stream_file" ]; then
        echo "Found ZFS stream at $stream_file"
        # Decompress and receive stream
        zstd -dc "$stream_file" | zfs receive -F livepool/root
        log_end_msg 0
        return 0
    else
        echo "No ZFS stream found"
        log_end_msg 1
        return 1
    fi
}

# Function to setup persistence
setup_zfs_persistence() {
    log_begin_msg "Setting up ZFS persistence"
    
    # Look for persistence device (labeled PERSIST or casper-rw)
    persist_device=$(blkid -L PERSIST 2>/dev/null || blkid -L casper-rw 2>/dev/null || true)
    
    if [ -n "$persist_device" ]; then
        echo "Found persistence device: $persist_device"
        
        # Import persistence pool if it exists
        if zpool import -N persist-pool 2>/dev/null; then
            echo "Imported existing persist-pool"
        else
            # Create new persistence pool
            zpool create -f \
                -o ashift=12 \
                -O compression=lz4 \
                -O atime=off \
                persist-pool $persist_device
            
            # Create datasets
            zfs create persist-pool/data
            zfs create persist-pool/home
        fi
        
        # Mount persistence datasets
        zfs mount persist-pool/data 2>/dev/null || true
        zfs mount persist-pool/home 2>/dev/null || true
        
        # Snapshot RAM pool for rollback capability
        zfs snapshot livepool/root@boot
        
        log_end_msg 0
    else
        echo "No persistence device found (optional)"
        log_end_msg 0
    fi
}

# Main execution
echo "=== ZFS RAM Boot System ==="

# Try ZFS boot first
if create_ram_pool; then
    if receive_zfs_stream; then
        setup_zfs_persistence
        echo "ZFS boot successful"
        exit 0
    fi
fi

# If we get here, ZFS boot failed - let normal boot continue
echo "ZFS boot failed, falling back to standard boot"
ZFS_BOOT_HOOK
    
    chmod +x "$chroot_dir/usr/share/initramfs-tools/scripts/init-premount/zfs-ram-boot"
    
    # Update GRUB configuration to prioritize ZFS boot
    cat > "$image_dir/boot/grub/grub.cfg" << 'GRUB_CFG'
set default=0
set timeout=5

# Load required modules
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660

menuentry "UltraThink ZFS RAM Boot (Recommended)" {
    linux /casper/vmlinuz boot=zfs toram quiet splash
    initrd /casper/initrd
}

menuentry "UltraThink ZFS RAM Boot with Persistence" {
    linux /casper/vmlinuz boot=zfs toram persistent quiet splash
    initrd /casper/initrd
}

menuentry "UltraThink ZFS Debug Mode" {
    linux /casper/vmlinuz boot=zfs toram zfs.zfs_dbgmsg_enable=1 debug
    initrd /casper/initrd
}

menuentry "UltraThink Fallback (SquashFS)" {
    linux /casper/vmlinuz boot=casper toram quiet splash
    initrd /casper/initrd
}

menuentry "System Recovery Mode" {
    linux /casper/vmlinuz boot=casper single nomodeset
    initrd /casper/initrd
}
GRUB_CFG
    
    # Create custom casper script for ZFS
    mkdir -p "$chroot_dir/usr/share/initramfs-tools/scripts/casper-bottom"
    cat > "$chroot_dir/usr/share/initramfs-tools/scripts/casper-bottom/99zfs_persistence" << 'CASPER_ZFS'
#!/bin/sh
# Casper hook for ZFS persistence

PREREQ=""
prereqs() {
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /scripts/casper-functions

# If we booted with ZFS, set up persistence overlays
if [ -d /livepool ]; then
    log_begin_msg "Configuring ZFS persistence"
    
    # Link persistence if available
    if [ -d /persist-pool/data ]; then
        # Create overlay for /var
        mkdir -p /root/var
        mount -t overlay overlay \
            -o lowerdir=/root/var,upperdir=/persist-pool/data/var,workdir=/persist-pool/data/.work \
            /root/var
        
        # Persistent /home
        if [ -d /persist-pool/home ]; then
            mount --bind /persist-pool/home /root/home
        fi
    fi
    
    log_end_msg 0
fi
CASPER_ZFS
    
    chmod +x "$chroot_dir/usr/share/initramfs-tools/scripts/casper-bottom/99zfs_persistence"
    
    echo -e "${GREEN}[+] ZFS boot configuration complete${NC}"
}

# Function to create optimal ZFS stream
create_optimal_zfs_stream() {
    local dataset="${1:-buildpool/livecd-builds/current}"
    local output_dir="${2:-/mnt/buildpool/livecd-builds/current/image/zfs}"
    
    echo -e "${BLUE}[*] Creating optimized ZFS stream for RAM loading${NC}"
    
    mkdir -p "$output_dir"
    
    # Snapshot the dataset
    zfs snapshot "${dataset}@live"
    
    # Create stream with optimal settings for RAM
    # Use -c for compressed stream, -e for all properties
    zfs send -c -e "${dataset}@live" | \
        zstd -T0 -19 --long > "$output_dir/filesystem.zfs.zst"
    
    local stream_size=$(du -sh "$output_dir/filesystem.zfs.zst" | cut -f1)
    echo -e "${GREEN}[+] ZFS stream created: $stream_size${NC}"
    
    # Calculate RAM requirements
    local stream_size_mb=$(du -sm "$output_dir/filesystem.zfs.zst" | cut -f1)
    local ram_needed=$((stream_size_mb * 2))  # Need 2x for decompression
    
    echo -e "${YELLOW}[!] Minimum RAM required: ${ram_needed}MB${NC}"
    echo -e "${YELLOW}[!] Recommended RAM: $((ram_needed + 2048))MB${NC}"
}

# Function to test ZFS boot in QEMU
test_zfs_boot() {
    local iso_file="${1:-output/ultrathink-zfs.iso}"
    local ram_size="${2:-8192}"
    
    echo -e "${CYAN}[*] Testing ZFS boot in QEMU with ${ram_size}MB RAM${NC}"
    
    qemu-system-x86_64 \
        -m "$ram_size" \
        -cdrom "$iso_file" \
        -enable-kvm \
        -cpu host \
        -smp 4 \
        -vga qxl \
        -boot d \
        -monitor stdio
}

# Main execution
main() {
    echo ""
    echo "ZFS Boot Configuration Options:"
    echo "  1. Configure build for ZFS-first boot"
    echo "  2. Create optimized ZFS stream"
    echo "  3. Test ZFS boot in QEMU"
    echo "  4. Complete setup (all of the above)"
    echo ""
    read -p "Choice (1-4): " choice
    
    case $choice in
        1)
            read -p "Chroot directory: " -e -i "/mnt/buildpool/livecd-builds/current/chroot" chroot
            read -p "Image directory: " -e -i "/mnt/buildpool/livecd-builds/current/image" image
            configure_zfs_priority_boot "$chroot" "$image"
            ;;
        2)
            read -p "ZFS dataset: " -e -i "buildpool/livecd-builds/current" dataset
            read -p "Output directory: " -e -i "/mnt/buildpool/livecd-builds/current/image/zfs" output
            create_optimal_zfs_stream "$dataset" "$output"
            ;;
        3)
            read -p "ISO file: " -e -i "output/ultrathink-zfs.iso" iso
            read -p "RAM size (MB): " -e -i "8192" ram
            test_zfs_boot "$iso" "$ram"
            ;;
        4)
            # Complete setup
            chroot_dir="/mnt/buildpool/livecd-builds/current/chroot"
            image_dir="/mnt/buildpool/livecd-builds/current/image"
            dataset="buildpool/livecd-builds/current"
            
            configure_zfs_priority_boot "$chroot_dir" "$image_dir"
            create_optimal_zfs_stream "$dataset" "$image_dir/zfs"
            
            echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}[✓] ZFS boot system configured successfully!${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
            ;;
    esac
}

# Show boot flow diagram
show_boot_flow() {
    echo ""
    echo "ZFS RAM Boot Flow:"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  1. GRUB/UEFI → Load kernel + initrd"
    echo "  ↓"
    echo "  2. Initrd → Load ZFS modules"
    echo "  ↓"
    echo "  3. Create RAM disk (zram or brd)"
    echo "  ↓"
    echo "  4. Create ZFS pool 'livepool' in RAM"
    echo "  ↓"
    echo "  5. Find and decompress filesystem.zfs.zst"
    echo "  ↓"
    echo "  6. Receive ZFS stream → livepool/root"
    echo "  ↓"
    echo "  7. Mount livepool/root as /"
    echo "  ↓"
    echo "  8. [Optional] Import persist-pool from USB"
    echo "  ↓"
    echo "  9. [Optional] Mount persistence overlays"
    echo "  ↓"
    echo "  10. Boot complete - Full ZFS in RAM!"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}

# Run main
show_boot_flow
main