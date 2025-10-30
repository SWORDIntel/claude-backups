#!/bin/bash
# Start Local AI Inference Server
# Qwen 2.5-32B on Military NPU (26.4 TOPS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/qwen_llama_server.py"
TORCH_VENV="$SCRIPT_DIR/.torch-venv"

echo "🚀 Starting Local AI Inference Server"
echo "   Model: Qwen 2.5-32B (32.5B parameters)"
echo "   Hardware: Military NPU (26.4 TOPS)"
echo "   Server: http://localhost:8000"
echo "   API: OpenAI-compatible endpoints"
echo ""

# Check virtual environment
if [ ! -d "$TORCH_VENV" ]; then
    echo "❌ Torch environment not found: $TORCH_VENV"
    exit 1
fi

# Check server script
if [ ! -f "$SERVER_SCRIPT" ]; then
    echo "❌ Server script not found: $SERVER_SCRIPT"
    exit 1
fi

# Activate environment
source "$TORCH_VENV/bin/activate"

echo "🎯 Environment activated"
echo "📦 Python: $(python3 --version)"

# Check dependencies
python3 -c "
import sys
missing = []

try:
    import torch
    print('✓ PyTorch available')
except ImportError:
    missing.append('torch')

try:
    import transformers
    print('✓ Transformers available')
except ImportError:
    missing.append('transformers')

try:
    import fastapi
    print('✓ FastAPI available')
except ImportError:
    missing.append('fastapi')

try:
    import llama_cpp
    print('✓ llama-cpp-python available')
except ImportError:
    missing.append('llama_cpp')

if missing:
    print(f'❌ Missing dependencies: {missing}')
    sys.exit(1)
else:
    print('✅ All dependencies ready')
"

if [ $? -ne 0 ]; then
    echo "❌ Dependency check failed"
    exit 1
fi

echo ""
echo "🧠 Hardware Status:"

# Check NPU
if [ -e "/dev/accel/accel0" ]; then
    echo "✅ NPU device detected (/dev/accel/accel0)"
else
    echo "⚠️ NPU device not found"
fi

# Check memory
MEMORY_GB=$(free -g | awk 'NR==2{printf "%.1f", $2/1}')
echo "✅ System memory: ${MEMORY_GB}GB"

echo ""
echo "🚀 Starting Qwen 2.5-32B inference server..."
echo "🎯 Military NPU optimization active"
echo "📡 OpenAI API: http://localhost:8000/v1/chat/completions"
echo ""

# Start the server
python3 "$SERVER_SCRIPT" --port 8000 --host 0.0.0.0

echo "🏁 Local AI server stopped"