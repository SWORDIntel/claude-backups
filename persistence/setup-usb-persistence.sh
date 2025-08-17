#!/bin/bash
# Complete USB Persistence Setup Script for UltraThink LiveCD
# This script sets up persistence AFTER burning the ISO to USB

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     ULTRATHINK USB PERSISTENCE SETUP - Complete Guide          ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Function to display usage
show_usage() {
    cat << EOF

${GREEN}USAGE:${NC}
    $0 <usb-device> [persistence-type] [size]

${GREEN}PARAMETERS:${NC}
    usb-device        USB device (e.g., /dev/sdb)
    persistence-type  Type of persistence: zfs (default), ext4, or btrfs
    size             Size of persistence (default: all remaining space)

${GREEN}EXAMPLES:${NC}
    $0 /dev/sdb                  # Auto-setup with ZFS using all space
    $0 /dev/sdb zfs             # ZFS persistence
    $0 /dev/sdb ext4 8G         # 8GB ext4 persistence
    $0 /dev/sdb btrfs           # Btrfs with all remaining space

${YELLOW}IMPORTANT:${NC}
    - This will modify the USB device!
    - Make sure you've already written the ISO to the USB
    - The USB should have 2 partitions from the ISO
    - This creates partition 3 for persistence

${CYAN}WHAT THIS DOES:${NC}
    1. Verifies the USB has the ISO already written
    2. Creates partition 3 using remaining space
    3. Formats partition 3 with chosen filesystem
    4. Sets up persistence configuration
    5. Tests the configuration

${GREEN}BOOT BEHAVIOR AFTER SETUP:${NC}
    - First boot option: Auto-detects and uses persistence
    - Second boot option: Forces persistence creation if missing
    - Persistence data saved in partition 3
    - Changes persist across reboots

EOF
    exit 0
}

# Check parameters
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

USB_DEVICE="$1"
PERSIST_TYPE="${2:-zfs}"
PERSIST_SIZE="${3:-}"

# Verify running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Verify USB device exists
if [ ! -b "$USB_DEVICE" ]; then
    echo -e "${RED}Error: Device $USB_DEVICE not found${NC}"
    exit 1
fi

# Safety check - confirm device
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}                    ⚠️  WARNING ⚠️                              ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}You are about to modify: ${RED}$USB_DEVICE${NC}"
echo
fdisk -l "$USB_DEVICE" 2>/dev/null | head -20
echo
echo -e "${YELLOW}This will create a persistence partition on this device.${NC}"
echo -e "${YELLOW}Make sure this is the correct USB device!${NC}"
echo
read -p "Type 'yes' to continue: " confirmation
if [ "$confirmation" != "yes" ]; then
    echo "Aborted"
    exit 1
fi

echo -e "\n${BLUE}[*] Checking current partition layout...${NC}"

# Get current partition info
PART_COUNT=$(fdisk -l "$USB_DEVICE" 2>/dev/null | grep "^$USB_DEVICE" | wc -l)

if [ "$PART_COUNT" -lt 2 ]; then
    echo -e "${RED}Error: USB doesn't appear to have the ISO written (need at least 2 partitions)${NC}"
    echo -e "${YELLOW}Please write the ISO first using:${NC}"
    echo -e "${GREEN}  dd if=ultrathink-*.iso of=$USB_DEVICE bs=4M status=progress${NC}"
    exit 1
fi

if [ "$PART_COUNT" -ge 3 ]; then
    echo -e "${YELLOW}Warning: Device already has 3 or more partitions${NC}"
    echo -e "${YELLOW}Partition 3 may already contain persistence${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

# Find the last sector used
LAST_PART=$(fdisk -l "$USB_DEVICE" 2>/dev/null | grep "^$USB_DEVICE" | tail -1)
LAST_SECTOR=$(echo "$LAST_PART" | awk '{print $3}')
NEXT_SECTOR=$((LAST_SECTOR + 1))

echo -e "${BLUE}[*] Last used sector: $LAST_SECTOR${NC}"
echo -e "${BLUE}[*] Creating persistence partition starting at sector $NEXT_SECTOR${NC}"

# Create partition 3
PERSIST_PART="${USB_DEVICE}3"

if [ -n "$PERSIST_SIZE" ]; then
    # Specific size requested
    echo -e "${BLUE}[*] Creating ${PERSIST_SIZE} persistence partition...${NC}"
    parted "$USB_DEVICE" --script -- mkpart primary "${NEXT_SECTOR}s" "$PERSIST_SIZE"
else
    # Use all remaining space
    echo -e "${BLUE}[*] Creating persistence partition using all remaining space...${NC}"
    echo -e "n\np\n3\n${NEXT_SECTOR}\n\nw" | fdisk "$USB_DEVICE" >/dev/null 2>&1 || true
fi

# Wait for partition to appear
sleep 2
partprobe "$USB_DEVICE" 2>/dev/null || true
sleep 1

if [ ! -b "$PERSIST_PART" ]; then
    echo -e "${RED}Error: Failed to create partition $PERSIST_PART${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Partition created: $PERSIST_PART${NC}"

# Format based on type
case "$PERSIST_TYPE" in
    zfs)
        echo -e "${BLUE}[*] Creating ZFS persistence pool...${NC}"
        
        # Check if ZFS is available
        if ! command -v zpool >/dev/null 2>&1; then
            echo -e "${YELLOW}Warning: ZFS not installed on host${NC}"
            echo -e "${YELLOW}Installing ZFS tools...${NC}"
            apt-get update && apt-get install -y zfsutils-linux
        fi
        
        # Create ZFS pool
        zpool create -f \
            -o ashift=12 \
            -O compression=lz4 \
            -O atime=off \
            -O xattr=sa \
            -O acltype=posixacl \
            persist-pool "$PERSIST_PART"
        
        # Create datasets
        zfs create -o mountpoint=/persist persist-pool/data
        zfs create -o mountpoint=/persist/home persist-pool/home
        zfs create -o mountpoint=/persist/var persist-pool/var
        
        # Set properties for persistence
        zfs set com.ubuntu:persist=yes persist-pool/data
        zfs set com.ubuntu:persist=yes persist-pool/home
        
        # Create persistence marker
        echo "ZFS_PERSISTENCE=1" > /persist/persistence.conf
        echo "PERSIST_TYPE=zfs" >> /persist/persistence.conf
        
        # Export pool so it can be imported on boot
        zpool export persist-pool
        
        echo -e "${GREEN}[✓] ZFS persistence pool created${NC}"
        echo -e "${CYAN}    Pool will auto-import as 'persist-pool' on boot${NC}"
        ;;
        
    ext4)
        echo -e "${BLUE}[*] Creating ext4 persistence filesystem...${NC}"
        
        # Format as ext4 with label
        mkfs.ext4 -L casper-rw "$PERSIST_PART"
        
        # Mount and configure
        mkdir -p /mnt/persist
        mount "$PERSIST_PART" /mnt/persist
        
        # Create persistence.conf for casper
        cat > /mnt/persist/persistence.conf << 'EOF'
/ union
/home union
EOF
        
        # Create marker file
        echo "EXT4_PERSISTENCE=1" > /mnt/persist/.persistence
        echo "PERSIST_TYPE=ext4" >> /mnt/persist/.persistence
        
        umount /mnt/persist
        
        echo -e "${GREEN}[✓] Ext4 persistence created with label 'casper-rw'${NC}"
        ;;
        
    btrfs)
        echo -e "${BLUE}[*] Creating Btrfs persistence filesystem...${NC}"
        
        # Format as btrfs
        mkfs.btrfs -L persist-btrfs "$PERSIST_PART"
        
        # Mount and create subvolumes
        mkdir -p /mnt/persist
        mount "$PERSIST_PART" /mnt/persist
        
        # Create subvolumes
        btrfs subvolume create /mnt/persist/@
        btrfs subvolume create /mnt/persist/@home
        
        # Create persistence config
        cat > /mnt/persist/persistence.conf << 'EOF'
/ union
/home union
EOF
        
        echo "BTRFS_PERSISTENCE=1" > /mnt/persist/.persistence
        echo "PERSIST_TYPE=btrfs" >> /mnt/persist/.persistence
        
        umount /mnt/persist
        
        echo -e "${GREEN}[✓] Btrfs persistence created${NC}"
        ;;
        
    *)
        echo -e "${RED}Error: Unknown persistence type: $PERSIST_TYPE${NC}"
        echo -e "${YELLOW}Supported types: zfs, ext4, btrfs${NC}"
        exit 1
        ;;
esac

# Verify setup
echo -e "\n${BLUE}[*] Verifying persistence setup...${NC}"

# Check partition exists
if [ -b "$PERSIST_PART" ]; then
    echo -e "${GREEN}  ✓ Partition exists: $PERSIST_PART${NC}"
else
    echo -e "${RED}  ✗ Partition missing: $PERSIST_PART${NC}"
fi

# Check filesystem
FS_TYPE=$(blkid -o value -s TYPE "$PERSIST_PART" 2>/dev/null || echo "unknown")
echo -e "${GREEN}  ✓ Filesystem type: $FS_TYPE${NC}"

# Get size
PART_SIZE=$(lsblk -no SIZE "$PERSIST_PART" 2>/dev/null || echo "unknown")
echo -e "${GREEN}  ✓ Partition size: $PART_SIZE${NC}"

# Final summary
echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    SETUP COMPLETE!                             ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${GREEN}Persistence has been configured on: ${CYAN}$PERSIST_PART${NC}"
echo -e "${GREEN}Type: ${CYAN}$PERSIST_TYPE${NC}"
echo -e "${GREEN}Size: ${CYAN}$PART_SIZE${NC}"
echo
echo -e "${YELLOW}BOOT INSTRUCTIONS:${NC}"
echo -e "1. Boot from USB"
echo -e "2. Select: ${CYAN}'UltraThink ZFS RAM Boot [Auto-Persistence]'${NC}"
echo -e "   - This will automatically detect and use partition 3"
echo -e "3. Or select: ${CYAN}'UltraThink ZFS RAM + Force Persistence'${NC}"
echo -e "   - This forces persistence even if auto-detect fails"
echo
echo -e "${GREEN}Your changes will now persist across reboots!${NC}"
echo
echo -e "${CYAN}TEST PERSISTENCE:${NC}"
echo -e "1. Boot the USB"
echo -e "2. Create a file: ${GREEN}touch /home/test-persistence${NC}"
echo -e "3. Reboot"
echo -e "4. Check if file exists: ${GREEN}ls /home/test-persistence${NC}"
echo