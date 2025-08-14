#!/bin/bash
clear
echo "=== METEOR LAKE 5.9GHz BOOST TEST ==="
echo "P-Cores (0-11) Target: 5900 MHz"
echo "E-Cores (12-21) Target: 3800 MHz"
echo "======================================="

while true; do
    echo -e "\nP-CORES:"
    for i in {0..11}; do
        FREQ=$(cat /proc/cpuinfo | grep -m $((i+1)) MHz | tail -1 | awk '{print $4}')
        printf "CPU%2d: %4.0f MHz  " $i $FREQ
        [ $((i % 4)) -eq 3 ] && echo
    done
    
    echo -e "\nE-CORES:"
    for i in {12..21}; do
        FREQ=$(cat /proc/cpuinfo | grep -m $((i+1)) MHz | tail -1 | awk '{print $4}')
        printf "CPU%2d: %4.0f MHz  " $i $FREQ
        [ $((i % 5)) -eq 4 ] && echo
    done
    
    echo -e "\n\nPackage Temp: $(sensors 2>/dev/null | grep Package | awk '{print $4}')"
    sleep 1
    clear
done
