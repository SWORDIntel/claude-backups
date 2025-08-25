#!/bin/bash
# Advanced Network Fix for Persistent Activation Failures
echo "🔧 Advanced Network Fix - Activation Failure Recovery"

# Force kill all network processes
sudo pkill -f NetworkManager
sudo pkill -f dhclient
sudo pkill -f wpa_supplicant

# Remove network manager cache and state
sudo rm -rf /var/lib/NetworkManager/*
sudo rm -rf /etc/NetworkManager/system-connections/*

# Reset network interfaces completely  
for iface in $(ls /sys/class/net/ | grep -E "(eth|enp|eno)"); do
    echo "Resetting $iface..."
    sudo ip link set $iface down
    sudo ip addr flush dev $iface
    sudo ip route flush dev $iface
done

# Reload network drivers
echo "Reloading network drivers..."
sudo modprobe -r e1000e 2>/dev/null || true
sudo modprobe -r igb 2>/dev/null || true  
sudo modprobe -r r8169 2>/dev/null || true
sudo modprobe -r atlantic 2>/dev/null || true

sleep 3

sudo modprobe e1000e 2>/dev/null || true
sudo modprobe igb 2>/dev/null || true
sudo modprobe r8169 2>/dev/null || true  
sudo modprobe atlantic 2>/dev/null || true

# Start NetworkManager fresh
sudo systemctl start NetworkManager

sleep 5

# Create simple ethernet connection
ETH_IFACE=$(ls /sys/class/net/ | grep -E "(eth|enp|eno)" | head -1)
if [ -n "$ETH_IFACE" ]; then
    echo "Creating connection for $ETH_IFACE..."
    sudo nmcli connection add type ethernet con-name "Ethernet-Fixed" ifname "$ETH_IFACE" autoconnect yes
    sudo nmcli connection up "Ethernet-Fixed"
fi

echo "Fix complete. Check connection status."