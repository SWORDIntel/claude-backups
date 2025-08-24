#!/bin/bash
# Test script for wrapper functions
source ./claude-wrapper-ultimate.sh 2>/dev/null

echo "Testing log_debug..."
DEBUG_MODE=true
log_debug "Test debug message"
echo "✓ log_debug works"

