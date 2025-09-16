#!/bin/bash

# EMERGENCY: Reinstall critical packages that were removed

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}==================================${NC}"
echo -e "${RED}  EMERGENCY PACKAGE RESTORATION${NC}"
echo -e "${RED}==================================${NC}"
echo ""

echo -e "${YELLOW}Reinstalling CRITICAL boot packages...${NC}"

# Critical packages for booting
CRITICAL_PACKAGES="
dkms
initramfs-tools
initramfs-tools-core
initramfs-tools-bin
klibc-utils
libklibc
"

# Additional important packages
IMPORTANT_PACKAGES="
fio
ipset
libipset13t64
build-essential
linux-headers-$(uname -r)
"

echo -e "${YELLOW}Step 1: Reinstalling critical boot packages${NC}"
for pkg in $CRITICAL_PACKAGES; do
    echo "Installing $pkg..."
    sudo apt install -y $pkg 2>/dev/null || echo "  Warning: $pkg failed"
done

echo -e "${YELLOW}Step 2: Reinstalling important packages${NC}"
for pkg in $IMPORTANT_PACKAGES; do
    echo "Installing $pkg..."
    sudo apt install -y $pkg 2>/dev/null || true
done

echo -e "${YELLOW}Step 3: Fixing broken dependencies${NC}"
sudo apt --fix-broken install -y

echo -e "${YELLOW}Step 4: Rebuilding initramfs for current kernel${NC}"
sudo update-initramfs -u -k $(uname -r)

echo -e "${YELLOW}Step 5: Updating GRUB${NC}"
sudo update-grub

# Check what's installed
echo ""
echo -e "${GREEN}Verification:${NC}"
echo -n "DKMS: "
if dpkg -l | grep -q "^ii.*dkms"; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ MISSING${NC}"
fi

echo -n "initramfs-tools: "
if dpkg -l | grep -q "^ii.*initramfs-tools "; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ MISSING${NC}"
fi

echo -n "klibc-utils: "
if dpkg -l | grep -q "^ii.*klibc-utils"; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ MISSING${NC}"
fi

echo ""
echo -e "${GREEN}Boot files check:${NC}"
ls -la /boot/initrd.img-$(uname -r) 2>/dev/null && echo "  ✓ Initrd exists" || echo "  ✗ Initrd MISSING!"

echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  1. DO NOT REBOOT until initramfs is verified!"
echo "  2. Check /boot/ has initrd.img files"
echo "  3. If initrd is missing, run: sudo update-initramfs -c -k $(uname -r)"
echo ""
echo -e "${GREEN}Emergency fix complete!${NC}"