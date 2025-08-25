#!/bin/bash
# Switch to systemd-networkd (alternative to NetworkManager)
echo "🔄 Switching to systemd-networkd as NetworkManager alternative"

# Disable NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager

# Enable systemd-networkd
sudo systemctl enable systemd-networkd
sudo systemctl enable systemd-resolved

# Create simple ethernet config
ETH_IFACE=$(ls /sys/class/net/ | grep -E "(eth|enp|eno)" | head -1)

if [ -n "$ETH_IFACE" ]; then
    sudo tee /etc/systemd/network/20-ethernet.network << EOF
[Match]
Name=$ETH_IFACE

[Network]
DHCP=yes
IPForward=no

[DHCP]
UseHostname=yes
EOF
fi

# Start services
sudo systemctl start systemd-networkd
sudo systemctl start systemd-resolved

echo "Switched to systemd-networkd. Connection should be more stable."
echo "To switch back to NetworkManager later:"
echo "  sudo systemctl disable systemd-networkd systemd-resolved"  
echo "  sudo systemctl enable NetworkManager && sudo systemctl start NetworkManager"