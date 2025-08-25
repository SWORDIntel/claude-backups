#!/bin/bash
# Network Status Checker
echo "🌐 Network Connection Status Check"
echo "=================================="

# Check if we have an IP address
HAS_IP=$(ip addr show | grep -c "inet.*scope global")
if [ "$HAS_IP" -gt 0 ]; then
    echo "✅ IP Address: ASSIGNED"
    ip addr show | grep "inet.*scope global" | head -3
else
    echo "❌ IP Address: NOT ASSIGNED"
fi

echo ""

# Check connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet: CONNECTED"
else
    echo "❌ Internet: NOT CONNECTED"
fi

echo ""

# Check NetworkManager devices
echo "📡 Network Devices:"
nmcli device status 2>/dev/null || echo "NetworkManager not responding"

echo ""

# Check ethernet interfaces
echo "🔌 Ethernet Interfaces:"
for iface in $(ls /sys/class/net/ | grep -E "(eth|enp|eno)"); do
    STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
    echo "  $iface: $STATE"
done

echo ""

# Check for connection issues in logs
echo "📋 Recent Network Issues:"
journalctl -u NetworkManager --no-pager -n 5 --since "5 minutes ago" 2>/dev/null | grep -i "error\|fail\|timeout" || echo "No recent errors found"

echo ""
echo "Run this script again if you want to recheck status"