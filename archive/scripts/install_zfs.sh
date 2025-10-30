#!/bin/bash
# ZFS Installation Script for Debian/Ubuntu
# Military-grade ZFS setup with encryption

echo "🔒 ZFS INSTALLATION FOR MILITARY SYSTEM"
echo "======================================"

# Update package list
echo "📦 Updating package lists..."
sudo apt update

# Install ZFS utilities
echo "📦 Installing ZFS utilities..."
sudo apt install -y zfsutils-linux zfs-dkms

# Load ZFS module
echo "🔧 Loading ZFS kernel module..."
sudo modprobe zfs

# Verify ZFS installation
echo "✅ Verifying ZFS installation..."
zpool version
zfs version

# Create ZFS configuration directory
sudo mkdir -p /etc/zfs
sudo mkdir -p /var/cache/zfs

echo "✅ ZFS installation complete"
echo "🎯 Ready for pool creation"
