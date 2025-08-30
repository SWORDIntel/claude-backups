#!/bin/bash
# BIOS Downgrade Script - Dell Latitude 5450
# Target: Version 1.11.2 (December 19, 2024)
# Current: Version 1.14.1 (April 10, 2025)

echo "========================================"
echo "BIOS DOWNGRADE TO 1.11.2"
echo "========================================"
echo ""
echo "Current BIOS: 1.14.1"
echo "Target BIOS: 1.11.2"
echo "Reason: Potential AVX-512 restoration"
echo ""
echo "This script will guide you through the downgrade process."
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check current BIOS version
echo "Checking current BIOS version..."
sudo dmidecode -s bios-version

# Start the downgrade
echo ""
echo "Starting fwupdmgr downgrade..."
echo "SELECT OPTION 3 (1.11.2) when prompted!"
echo ""
sudo fwupdmgr downgrade

echo ""
echo "After reboot, run these tests:"
echo "1. Check new BIOS: sudo dmidecode -s bios-version"
echo "2. Check microcode: grep microcode /proc/cpuinfo | head -1"
echo "3. Test AVX-512: taskset -c 0 ./test_avx512"
echo "4. Check MSR 0x771: sudo rdmsr -p 0 0x771"