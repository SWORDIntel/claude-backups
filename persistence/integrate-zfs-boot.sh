#!/bin/bash
# Integration functions for ZFS boot with persistence
# Add these to your build-ultrathink-zfs-native.sh script

# Function to configure ZFS-first boot with persistence support
configure_zfs_boot_system() {
    local chroot_dir="$1"
    local image_dir="$2"
    
    log "Configuring ZFS-first boot system with persistence..."
    
    # 1. Install required packages for ZFS boot
    systemd-nspawn --directory="$chroot_dir" apt-get install -y \
        zfs-initramfs \
        zfs-dracut \
        busybox-initramfs \
        casper \
        lupin-casper || log_warn "Some packages failed to install"
    
    # 2. Create initramfs hook for ZFS RAM boot
    cat > "$chroot_dir/etc/initramfs-tools/hooks/zfs-ram-boot" << 'HOOK'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0 ;; esac

. /usr/share/initramfs-tools/hook-functions

# Copy ZFS utilities
copy_exec /sbin/zpool
copy_exec /sbin/zfs
copy_exec /sbin/mount.zfs
copy_exec /usr/bin/zstd

# Add kernel modules for RAM disk
manual_add_modules brd
manual_add_modules zram

exit 0
HOOK
    chmod +x "$chroot_dir/etc/initramfs-tools/hooks/zfs-ram-boot"
    
    # 3. Create initramfs script for ZFS RAM pool creation
    cat > "$chroot_dir/etc/initramfs-tools/scripts/init-premount/create-zfs-ram-pool" << 'SCRIPT'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0 ;; esac

. /scripts/functions

# Check if boot=zfs parameter is set
if grep -q "boot=zfs" /proc/cmdline; then
    log_begin_msg "Creating ZFS RAM pool"
    
    # Load modules
    modprobe zfs 2>/dev/null || true
    modprobe zram 2>/dev/null || modprobe brd rd_size=8388608
    
    # Wait for devices
    sleep 2
    
    # Create pool device (prefer zram for compression)
    if [ -b /dev/zram0 ]; then
        echo 8589934592 > /sys/block/zram0/disksize  # 8GB
        POOL_DEV="/dev/zram0"
    elif [ -b /dev/ram0 ]; then
        POOL_DEV="/dev/ram0"
    else
        log_failure_msg "No RAM disk available"
        exit 1
    fi
    
    # Create ZFS pool
    zpool create -f -o ashift=12 -O compression=lz4 \
        -O atime=off -O devices=off -m none \
        livepool $POOL_DEV 2>/dev/null || true
    
    log_end_msg 0
fi
SCRIPT
    chmod +x "$chroot_dir/etc/initramfs-tools/scripts/init-premount/create-zfs-ram-pool"
    
    # 4. Configure Dracut for ZFS if USE_DRACUT is true
    if [ "$USE_DRACUT" = "true" ]; then
        cat > "$chroot_dir/etc/dracut.conf.d/20-zfs-live.conf" << 'DRACUT_ZFS'
# ZFS Live boot configuration
add_dracutmodules+=" zfs dmsquash-live livenet "
add_drivers+=" zfs brd zram squashfs overlay "
filesystems+=" zfs squashfs overlay "
compress="lz4"
hostonly="no"
show_modules="yes"
# Kernel parameters for ZFS boot
kernel_cmdline="boot=zfs rd.zfs.pool.import=livepool"
DRACUT_ZFS
    fi
    
    # 5. Update initramfs
    systemd-nspawn --directory="$chroot_dir" bash -c "
        if command -v dracut >/dev/null; then
            dracut --force --kver \$(ls /lib/modules | tail -1)
        else
            update-initramfs -u -k all
        fi
    "
    
    log "ZFS boot system configured"
}

# Function to create optimized GRUB configuration
create_zfs_grub_config() {
    local image_dir="$1"
    
    log "Creating ZFS-optimized GRUB configuration..."
    
    mkdir -p "$image_dir/boot/grub"
    cat > "$image_dir/boot/grub/grub.cfg" << 'GRUB'
# ZFS-first GRUB configuration
set default=0
set timeout=5
set gfxpayload=keep

insmod all_video
insmod gfxterm
insmod png
insmod part_gpt
insmod part_msdos

menuentry "UltraThink ZFS RAM Boot (Recommended)" --class ubuntu {
    echo "Loading ZFS RAM boot system..."
    linux /casper/vmlinuz boot=zfs toram quiet splash
    initrd /casper/initrd
}

menuentry "UltraThink ZFS + Persistence" --class ubuntu {
    echo "Loading ZFS with persistence..."
    linux /casper/vmlinuz boot=zfs toram persistent persistent-media=removable quiet splash
    initrd /casper/initrd
}

menuentry "UltraThink ZFS Debug Mode" --class ubuntu {
    echo "Loading ZFS debug mode..."
    linux /casper/vmlinuz boot=zfs toram debug nosplash zfs.zfs_dbgmsg_enable=1
    initrd /casper/initrd
}

menuentry "Classic LiveCD Mode (SquashFS)" --class ubuntu {
    echo "Loading classic mode..."
    linux /casper/vmlinuz boot=casper toram quiet splash
    initrd /casper/initrd
}

menuentry "System Recovery" --class ubuntu {
    echo "Loading recovery mode..."
    linux /casper/vmlinuz boot=casper single nomodeset
    initrd /casper/initrd
}

menuentry "Memory Test" --class memtest {
    linux16 /boot/memtest86+.bin
}
GRUB
}

# Function to create persistence configuration
create_persistence_config() {
    local image_dir="$1"
    
    log "Adding persistence configuration..."
    
    # Create casper directory if not exists
    mkdir -p "$image_dir/casper"
    
    # Create persistence.conf for union mounts
    cat > "$image_dir/casper/persistence.conf" << 'PERSIST'
# Persistence configuration
/ union
/home union
PERSIST
    
    # Create script to set up persistence on first boot
    cat > "$image_dir/casper/setup-persistence.sh" << 'SETUP'
#!/bin/bash
# Setup persistence partition on USB

echo "Setting up persistence partition..."

# Find USB device
USB_DEV=$(mount | grep -E "\/cdrom|\/isodevice" | cut -d' ' -f1 | sed 's/[0-9]*$//')

if [ -z "$USB_DEV" ]; then
    echo "USB device not found"
    exit 1
fi

# Check for free space
LAST_PART=$(fdisk -l $USB_DEV | grep "^$USB_DEV" | tail -1 | awk '{print $1}')
LAST_SECTOR=$(fdisk -l $USB_DEV | grep "^$LAST_PART" | awk '{print $3}')

# Create persistence partition
echo "Creating persistence partition..."
parted $USB_DEV --script mkpart primary ext4 ${LAST_SECTOR}s 100%

# Get new partition
PERSIST_PART="${USB_DEV}3"

# Format as ZFS or ext4
if command -v zpool >/dev/null; then
    echo "Creating ZFS persistence pool..."
    zpool create -f persist-pool $PERSIST_PART
    zfs create persist-pool/data
    zfs create persist-pool/home
else
    echo "Creating ext4 persistence..."
    mkfs.ext4 -L casper-rw $PERSIST_PART
fi

echo "Persistence setup complete!"
SETUP
    chmod +x "$image_dir/casper/setup-persistence.sh"
}

# Function to update create_zfs_stream for optimal RAM loading
create_optimized_zfs_stream() {
    local chroot_dir="$1"
    local image_dir="$2"
    
    log "Creating optimized ZFS stream for RAM loading..."
    
    # Create ZFS directory
    mkdir -p "$image_dir/zfs"
    
    # Snapshot the chroot dataset
    local dataset="${ZFS_BUILD_DATASET}/chroot"
    zfs snapshot "${dataset}@live" || log_warn "Snapshot may already exist"
    
    # Create compressed stream optimized for RAM
    # -c = use compressed blocks, -e = include properties
    log "Generating ZFS send stream (this may take a while)..."
    zfs send -c -e "${dataset}@live" | \
        zstd -T0 -19 --long > "$image_dir/zfs/filesystem.zfs.zst"
    
    # Get sizes
    local stream_size=$(du -sh "$image_dir/zfs/filesystem.zfs.zst" | cut -f1)
    local stream_mb=$(du -sm "$image_dir/zfs/filesystem.zfs.zst" | cut -f1)
    local ram_needed=$((stream_mb * 2))
    
    log_info "ZFS stream size: $stream_size"
    log_info "RAM required: ${ram_needed}MB minimum"
    log_info "Recommended: $((ram_needed + 2048))MB"
    
    # Also create squashfs as fallback
    log "Creating squashfs fallback..."
    mksquashfs "$chroot_dir" "$image_dir/casper/filesystem.squashfs" \
        -comp xz -b 1M -no-recovery
    
    local squash_size=$(du -sh "$image_dir/casper/filesystem.squashfs" | cut -f1)
    log_info "SquashFS size: $squash_size"
}

# Main integration function - call this from your build script
integrate_zfs_boot() {
    local chroot_dir="${CHROOT_DIR:-/mnt/zfs-build-${BUILD_TIMESTAMP}/chroot}"
    local image_dir="${IMAGE_DIR:-/mnt/zfs-build-${BUILD_TIMESTAMP}/image}"
    
    log "════════════════════════════════════════════════════════════════"
    log "         INTEGRATING ZFS BOOT WITH PERSISTENCE                  "
    log "════════════════════════════════════════════════════════════════"
    
    # Configure boot system
    configure_zfs_boot_system "$chroot_dir" "$image_dir"
    
    # Create GRUB config
    create_zfs_grub_config "$image_dir"
    
    # Add persistence support
    create_persistence_config "$image_dir"
    
    # Create optimized streams
    create_optimized_zfs_stream "$chroot_dir" "$image_dir"
    
    log "════════════════════════════════════════════════════════════════"
    log "[✓] ZFS boot integration complete!"
    log "════════════════════════════════════════════════════════════════"
}

# Export functions if sourced
export -f configure_zfs_boot_system
export -f create_zfs_grub_config
export -f create_persistence_config
export -f create_optimized_zfs_stream
export -f integrate_zfs_boot