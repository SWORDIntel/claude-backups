#!/bin/bash
# Add persistence support to LiveUSB
# Creates persistent partition and configures casper-rw or ZFS persistence

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           LIVEUSB PERSISTENCE CONFIGURATION                    ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

# Function to add persistence to ISO build
add_persistence_to_build() {
    local chroot_dir="${1:-/mnt/buildpool/livecd-builds/current/chroot}"
    local image_dir="${2:-/mnt/buildpool/livecd-builds/current/image}"
    
    echo -e "${GREEN}[+] Adding persistence support to build${NC}"
    
    # Create casper configuration for persistence
    mkdir -p "$image_dir/casper"
    
    # Create persistence configuration file
    cat > "$image_dir/casper/persistence.conf" << 'EOF'
# Persistence configuration
/ union
/home union
EOF
    
    # Add persistence boot options to grub
    cat >> "$image_dir/boot/grub/grub.cfg" << 'EOF'

menuentry "UltraThink with Persistence" {
    linux /casper/vmlinuz boot=casper persistent quiet splash
    initrd /casper/initrd
}

menuentry "UltraThink with ZFS Persistence" {
    linux /casper/vmlinuz boot=casper persistent persistent-media=removable-usb quiet splash zfs=livepool/root
    initrd /casper/initrd
}
EOF
    
    echo -e "${GREEN}[+] Persistence configuration added to ISO${NC}"
}

# Function to create persistence partition on USB after writing ISO
create_usb_persistence() {
    local usb_device="${1:-/dev/sdb}"
    local persistence_size="${2:-4G}"
    local persistence_type="${3:-ext4}"  # ext4, zfs, or btrfs
    
    echo -e "${YELLOW}[!] This will modify $usb_device${NC}"
    echo -e "${YELLOW}[!] Make sure this is the correct USB device!${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
    
    # Find the end of the ISO image
    local iso_end=$(sudo fdisk -l "$usb_device" | grep "$usb_device" | tail -1 | awk '{print $3}')
    
    echo -e "${BLUE}[*] Creating persistence partition after sector $iso_end${NC}"
    
    # Create new partition for persistence
    sudo parted "$usb_device" --script -- \
        mkpart primary "$persistence_type" "${iso_end}s" 100%
    
    # Get the new partition number (usually 3)
    local persist_part="${usb_device}3"
    
    case "$persistence_type" in
        ext4)
            echo -e "${BLUE}[*] Creating ext4 persistence partition${NC}"
            sudo mkfs.ext4 -L casper-rw "$persist_part"
            
            # Mount and create persistence structure
            sudo mkdir -p /mnt/persist
            sudo mount "$persist_part" /mnt/persist
            
            # Create persistence.conf
            echo "/ union" | sudo tee /mnt/persist/persistence.conf
            
            sudo umount /mnt/persist
            ;;
            
        zfs)
            echo -e "${BLUE}[*] Creating ZFS persistence pool${NC}"
            # Create ZFS pool on partition
            sudo zpool create -f \
                -o ashift=12 \
                -O compression=lz4 \
                -O atime=off \
                -O normalization=formD \
                -m none \
                persist-pool "$persist_part"
            
            # Create datasets
            sudo zfs create -o mountpoint=/mnt/persist persist-pool/root
            sudo zfs create -o mountpoint=/mnt/persist/home persist-pool/home
            
            # Create persistence.conf
            echo "/ union" | sudo tee /mnt/persist/persistence.conf
            echo "/home union" | sudo tee -a /mnt/persist/persistence.conf
            
            # Export pool (will be imported on boot)
            sudo zpool export persist-pool
            ;;
            
        btrfs)
            echo -e "${BLUE}[*] Creating btrfs persistence partition${NC}"
            sudo mkfs.btrfs -L casper-rw "$persist_part"
            
            # Mount and create subvolumes
            sudo mkdir -p /mnt/persist
            sudo mount "$persist_part" /mnt/persist
            
            # Create subvolumes
            sudo btrfs subvolume create /mnt/persist/@
            sudo btrfs subvolume create /mnt/persist/@home
            
            # Create persistence.conf
            echo "/ union" | sudo tee /mnt/persist/persistence.conf
            
            sudo umount /mnt/persist
            ;;
    esac
    
    echo -e "${GREEN}[✓] Persistence partition created successfully${NC}"
}

# Function to show USB structure after setup
show_usb_structure() {
    local usb_device="${1:-/dev/sdb}"
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 USB STRUCTURE WITH PERSISTENCE                 ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    sudo fdisk -l "$usb_device"
    
    echo ""
    echo "Filesystem structure when booted:"
    echo ""
    echo "  / (root) = OverlayFS with persistence"
    echo "  ├── Lower: SquashFS or ZFS from ISO (read-only)"
    echo "  ├── Upper: Persistence partition (read-write, survives reboot)"
    echo "  └── Work: Persistence partition"
    echo ""
    echo "Changes are saved to persistence partition and survive reboots!"
    echo ""
    echo "Boot options:"
    echo "  1. Normal boot (RAM only, no persistence)"
    echo "  2. Persistent boot (saves changes)"
    echo "  3. ZFS persistent (if ZFS partition created)"
    echo ""
}

# Main menu
main() {
    echo ""
    echo "Choose operation:"
    echo "  1. Add persistence support to ISO build"
    echo "  2. Create persistence partition on existing USB"
    echo "  3. Show USB structure"
    echo ""
    read -p "Choice (1-3): " choice
    
    case $choice in
        1)
            read -p "Chroot directory: " -e -i "/mnt/buildpool/livecd-builds/current/chroot" chroot
            read -p "Image directory: " -e -i "/mnt/buildpool/livecd-builds/current/image" image
            add_persistence_to_build "$chroot" "$image"
            ;;
        2)
            read -p "USB device (BE CAREFUL!): " -e -i "/dev/sdb" device
            read -p "Persistence size: " -e -i "4G" size
            echo "Filesystem type:"
            echo "  1. ext4 (traditional, compatible)"
            echo "  2. zfs (advanced features, snapshots)"
            echo "  3. btrfs (snapshots, compression)"
            read -p "Choice (1-3): " fs_choice
            
            case $fs_choice in
                1) fs_type="ext4" ;;
                2) fs_type="zfs" ;;
                3) fs_type="btrfs" ;;
                *) fs_type="ext4" ;;
            esac
            
            create_usb_persistence "$device" "$size" "$fs_type"
            show_usb_structure "$device"
            ;;
        3)
            read -p "USB device: " -e -i "/dev/sdb" device
            show_usb_structure "$device"
            ;;
    esac
}

# Run main function
main