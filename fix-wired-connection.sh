#!/bin/bash
# Wired Connection Diagnostics and Fix Script
# Diagnoses and fixes common wired ethernet connection issues

echo "🔧 Wired Connection Diagnostic & Fix Tool"
echo "========================================"

# Function to run command and capture output
run_cmd() {
    local cmd="$1"
    local desc="$2"
    echo -e "\n📋 $desc"
    echo "Command: $cmd"
    echo "Output:"
    eval "$cmd" 2>&1 || echo "Command failed or returned non-zero exit code"
    echo ""
}

# Basic network diagnostics
echo "🔍 Network Interface Diagnostics"
run_cmd "ip addr show" "Network interfaces and IP addresses"
run_cmd "ip route show" "Routing table"
run_cmd "nmcli device status" "NetworkManager device status"

# Check for ethernet interfaces
echo "🌐 Ethernet Interface Detection"
run_cmd "ls /sys/class/net/" "Available network interfaces"
run_cmd "nmcli device show" "Detailed device information"

# Check NetworkManager service
echo "⚙️ NetworkManager Service Status"
run_cmd "systemctl is-active NetworkManager" "NetworkManager active status"
run_cmd "systemctl is-enabled NetworkManager" "NetworkManager enabled status"

# Check for common issues
echo "🔍 Common Issue Detection"
run_cmd "dmesg | grep -i eth | tail -10" "Recent ethernet kernel messages"
run_cmd "journalctl -u NetworkManager --no-pager -n 20" "Recent NetworkManager logs"

# Try to identify the ethernet interface
ETH_INTERFACE=$(ip link show | grep -E "^[0-9]+: (eth|enp|eno)" | head -1 | cut -d: -f2 | tr -d ' ')

if [ -n "$ETH_INTERFACE" ]; then
    echo "🔌 Found ethernet interface: $ETH_INTERFACE"
    run_cmd "ethtool $ETH_INTERFACE" "Ethernet interface details"
    run_cmd "nmcli device show $ETH_INTERFACE" "NetworkManager device details"
else
    echo "❌ No ethernet interface found"
fi

# Suggested fixes
echo "🛠️ Suggested Fixes"
echo ""

echo "1. Restart NetworkManager:"
echo "   sudo systemctl restart NetworkManager"
echo ""

echo "2. Bring interface up manually (replace eth0 with your interface):"
echo "   sudo ip link set eth0 up"
echo "   sudo dhclient eth0"
echo ""

echo "3. Reset network configuration:"
echo "   sudo nmcli networking off && sleep 5 && sudo nmcli networking on"
echo ""

echo "4. Check cable connection and try different ethernet port"
echo ""

echo "5. Disable power management on ethernet (if interface keeps going down):"
if [ -n "$ETH_INTERFACE" ]; then
    echo "   sudo ethtool -s $ETH_INTERFACE wol d"
    echo "   echo 'ACTION==\"add\", SUBSYSTEM==\"net\", NAME==\"$ETH_INTERFACE\", RUN+=\"/sbin/ethtool -s %k wol d\"' | sudo tee /etc/udev/rules.d/81-ethernet-wol.rules"
else
    echo "   sudo ethtool -s [interface] wol d"
fi
echo ""

echo "6. If using USB-C dock or adapter, try direct connection to built-in ethernet"
echo ""

# Quick fix attempts
echo "🚀 Quick Fix Attempts"
echo ""

if [ "$1" = "--fix" ]; then
    echo "Attempting automatic fixes..."
    
    # Restart NetworkManager
    echo "Restarting NetworkManager..."
    sudo systemctl restart NetworkManager
    sleep 3
    
    # Reset networking
    echo "Resetting networking..."
    sudo nmcli networking off
    sleep 3
    sudo nmcli networking on
    sleep 3
    
    # Try to bring up ethernet interface
    if [ -n "$ETH_INTERFACE" ]; then
        echo "Bringing up $ETH_INTERFACE..."
        sudo ip link set "$ETH_INTERFACE" up
        sudo dhclient "$ETH_INTERFACE"
    fi
    
    echo "Fix attempts completed. Check connection status."
else
    echo "Run with --fix to attempt automatic repairs"
fi

echo ""
echo "✅ Diagnostic complete. If connection still unstable:"
echo "   • Check physical cable and connections"
echo "   • Try different ethernet port"
echo "   • Check if using dock/adapter causing issues"
echo "   • Consider network driver issues"