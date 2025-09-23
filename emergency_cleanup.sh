#!/bin/bash
# Emergency Repository Cleanup Script
# PATCHER - Emergency Surgical Intervention Tool

set -e

echo "🚨 EMERGENCY CLEANUP INITIATED 🚨"

# Check disk space
DISK_USAGE=$(df /home/john | tail -1 | awk '{print $5}' | sed 's/%//')
echo "Current disk usage: ${DISK_USAGE}%"

if [ "$DISK_USAGE" -gt 90 ]; then
    echo "⚠️  CRITICAL: Disk usage above 90%"

    # Remove core dumps
    echo "Removing core dumps..."
    find /home/john -name "core.*" -size +10M -delete 2>/dev/null || true

    # Remove large ISO files
    echo "Removing large ISO files..."
    find /home/john -name "*.iso" -size +1G -delete 2>/dev/null || true

    # Clean build artifacts
    echo "Cleaning build artifacts..."
    find /home/john -name "*.o" -delete 2>/dev/null || true
    find /home/john -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home/john -name "*.pyc" -delete 2>/dev/null || true
    find /home/john -name "*.pyo" -delete 2>/dev/null || true

    # Clean logs
    echo "Cleaning large log files..."
    find /home/john -name "*.log" -size +50M -delete 2>/dev/null || true

    # Git cleanup
    if [ -d ".git" ]; then
        echo "Git cleanup..."
        git gc --aggressive --prune=now 2>/dev/null || true
    fi

    echo "✅ Emergency cleanup completed"
else
    echo "✅ Disk usage acceptable (${DISK_USAGE}%)"
fi

# Check final disk space
FINAL_USAGE=$(df /home/john | tail -1 | awk '{print $5}' | sed 's/%//')
echo "Final disk usage: ${FINAL_USAGE}%"

if [ "$FINAL_USAGE" -gt 95 ]; then
    echo "🚨 CRITICAL: Still above 95% - manual intervention required"
    exit 1
else
    echo "✅ Disk space recovery successful"
fi