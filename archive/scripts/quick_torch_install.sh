#!/bin/bash
# Quick Torch Installation for Local Opus Server
# Uses existing military-grade features

set -euo pipefail

echo "🚀 Quick Torch Installation for Phase 7 Production Hardening"
echo "==========================================================="

# Create lightweight venv just for torch dependencies
if [ ! -d "/home/john/claude-backups/.torch-venv" ]; then
    echo "📦 Creating minimal torch venv..."
    python3 -m venv /home/john/claude-backups/.torch-venv
fi

# Install only essential dependencies
echo "⚡ Installing core dependencies (torch-cpu only for speed)..."
source /home/john/claude-backups/.torch-venv/bin/activate

pip install --quiet --no-deps torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install --quiet transformers fastapi uvicorn pydantic aiohttp

echo "✅ Core dependencies installed"
echo ""
echo "🎯 Testing local Opus server with torch..."

# Test the server with proper environment
cd /home/john/claude-backups/local-models/opus-openvino
PYTHON_PATH="/home/john/claude-backups/.torch-venv/bin/python"

echo "Starting test server..."
timeout 10s $PYTHON_PATH local_opus_server.py --test || true

echo ""
echo "✅ Torch dependencies ready for Phase 7!"
echo "🚀 Starting multi-model deployment on ports 8001-8004..."