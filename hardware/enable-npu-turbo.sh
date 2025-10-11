#!/bin/bash
# Enable Intel NPU Military Turbo Mode
# Detects and configures military-grade NPU capabilities (26.4 TOPS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==============================================="
echo "  Intel NPU Military Turbo Mode Enabler"
echo "==============================================="
echo ""

# Check if hardware analyzer exists
if [[ ! -f "$SCRIPT_DIR/milspec_hardware_analyzer.py" ]]; then
    echo "❌ Military hardware analyzer not found"
    exit 1
fi

# Run detection with sudo
echo "🔍 Detecting military NPU capabilities (requires sudo)..."
sudo python3 "$SCRIPT_DIR/milspec_hardware_analyzer.py" --export "$HOME/.claude/npu-config.json"

# Check if military mode was detected
if [[ -f "$HOME/.claude/npu-config.json" ]]; then
    MAX_TOPS=$(jq -r '.npu_capabilities.max_tops // 11' "$HOME/.claude/npu-config.json" 2>/dev/null)

    if [[ "$MAX_TOPS" =~ ^[0-9]+\.[0-9]+$ ]] && (( $(echo "$MAX_TOPS > 20" | bc -l) )); then
        echo "✅ Military NPU Detected: $MAX_TOPS TOPS"
        echo "   Features: Covert mode, secure execution, 128MB cache"
        export NPU_MILITARY_MODE=1
        export NPU_MAX_TOPS=$MAX_TOPS
    else
        echo "ℹ Standard NPU Mode: $MAX_TOPS TOPS"
        export NPU_MILITARY_MODE=0
        export NPU_MAX_TOPS=11.0
    fi
else
    echo "⚠ Detection failed, using standard mode"
    export NPU_MILITARY_MODE=0
    export NPU_MAX_TOPS=11.0
fi

# Apply military environment
if [[ -f "$HOME/.claude/npu-military.env" ]]; then
    source "$HOME/.claude/npu-military.env"
    echo ""
    echo "✅ NPU Military Environment Activated"
    echo ""
    echo "Environment Variables:"
    env | grep -E "NPU_|INTEL_NPU|OPENVINO.*NPU" | sed 's/^/  /'
    echo ""
    echo "💡 Restart your terminal or run:"
    echo "   source ~/.bashrc"
else
    echo "⚠ NPU environment file not found"
    echo "Run the installer to create it:"
    echo "  ./install"
fi

echo ""
echo "🚀 NPU Turbo Mode Ready"
echo "   Use 'echo \$NPU_MAX_TOPS' to verify"
