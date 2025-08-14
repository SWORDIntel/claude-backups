#!/bin/bash
#
# MASTER OPTIMIZATION DEPLOYMENT SCRIPT
# Deploys all optimization engines across the entire codebase
#

set -euo pipefail

echo "🚀 DEPLOYING ALL OPTIMIZATION ENGINES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Source optimization engines
OPTIMIZER_SCRIPT="/home/ubuntu/Documents/Claude/OPTIMIZER_COMPREHENSIVE_DEPLOYMENT.sh"

if [[ -f "$OPTIMIZER_SCRIPT" ]]; then
    echo "✅ Executing comprehensive optimization deployment..."
    bash "$OPTIMIZER_SCRIPT"
else
    echo "❌ Optimization script not found at $OPTIMIZER_SCRIPT"
    exit 1
fi

echo ""
echo "🎯 OPTIMIZATION DEPLOYMENT COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All optimization engines have been deployed across the codebase."
echo "Performance improvements are now active."
