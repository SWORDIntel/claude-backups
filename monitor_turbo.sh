#!/bin/bash

echo "=== METEOR LAKE TURBO MONITOR ==="
echo "Target: 5.9GHz on P-cores"
echo ""

while true; do
    # Current frequency
    echo -n "Freq: "
    grep MHz /proc/cpuinfo | head -1 | awk '{print $4}'
    
    # Temperature
    echo -n "Temp: "
    sensors | grep Package | awk '{print $4}'
    
    # Power
    echo -n "Power: "
    sudo turbostat --Summary --quiet --interval 1 --num_iterations 1 2>/dev/null | grep Package | awk '{print $4}' | head -1
    
    # HWP request
    echo -n "HWP: "
    sudo rdmsr 0x774 -f 15:8 -d
    
    echo "---"
    sleep 2
done
