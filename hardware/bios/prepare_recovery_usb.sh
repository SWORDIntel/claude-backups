#!/bin/bash
# Prepare Dell BIOS Recovery USB

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <usb_device> <bios_file>"
    echo "Example: $0 /dev/sdb1 Latitude_5450_1.11.2.exe"
    exit 1
fi

USB_DEVICE=$1
BIOS_FILE=$2

echo "WARNING: This will format $USB_DEVICE"
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Format USB as FAT32
sudo umount $USB_DEVICE 2>/dev/null
sudo mkfs.vfat -F 32 -n "BIOSRECOV" $USB_DEVICE

# Mount USB
MOUNT_POINT=$(mktemp -d)
sudo mount $USB_DEVICE $MOUNT_POINT

# Create EFI structure
sudo mkdir -p $MOUNT_POINT/EFI/BOOT
sudo mkdir -p $MOUNT_POINT/EFI/Dell/BIOS

# Extract BIOS if it's an exe
if [[ $BIOS_FILE == *.exe ]]; then
    # Try to extract with 7z
    7z x -o/tmp/bios_extract $BIOS_FILE
    # Find the actual BIOS binary
    find /tmp/bios_extract -name "*.bin" -o -name "*.rom" -o -name "*.cap" | while read f; do
        sudo cp "$f" $MOUNT_POINT/EFI/BOOT/BOOTX64.EFI
        sudo cp "$f" $MOUNT_POINT/BIOS.rcv
        echo "Copied: $f"
    done
else
    # Direct copy if already extracted
    sudo cp $BIOS_FILE $MOUNT_POINT/EFI/BOOT/BOOTX64.EFI
    sudo cp $BIOS_FILE $MOUNT_POINT/BIOS.rcv
fi

# Unmount
sync
sudo umount $MOUNT_POINT
rmdir $MOUNT_POINT

echo "Recovery USB prepared on $USB_DEVICE"
echo "To use: Shutdown, hold Ctrl+Esc, power on"
