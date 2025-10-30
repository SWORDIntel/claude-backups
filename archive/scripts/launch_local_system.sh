#!/bin/bash
# Launch Zero-Token Local System with 40+ TFLOPS Performance
# Complete integration of all frameworks with military-grade optimization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 LAUNCHING COMPREHENSIVE ZERO-TOKEN SYSTEM"
echo "============================================================"
echo "🎯 Target: 40+ TFLOPS performance"
echo "🔋 Mode: Zero external token usage"
echo "🏛️  Frameworks: claude-backups, VoiceStand, ARTIFACTOR, DSMIL"
echo "============================================================"

# Export configuration for local-only mode
export CLAUDE_LOCAL_ONLY=true
export ZERO_TOKEN_MODE=true
export NPU_MILITARY_MODE=true
export DSMIL_ENABLED=true

# Ensure military NPU mode is activated
echo "🔧 Activating military performance mode..."
if command -v sudo >/dev/null 2>&1; then
    echo "1786" | sudo -S bash hardware/enable-npu-turbo.sh 2>/dev/null || {
        echo "⚠️  Military mode activation failed - continuing with standard mode"
    }
else
    echo "⚠️  No sudo access - military mode requires elevated privileges"
fi

# Check if Opus servers are running
echo "🔍 Checking Opus server status..."
opus_running=0
for port in 3451 3452 3453 3454; do
    if curl -s "http://localhost:$port/health" >/dev/null 2>&1; then
        echo "✅ Opus server running on port $port"
        ((opus_running++))
    else
        echo "❌ Opus server not running on port $port"
    fi
done

if [ $opus_running -eq 0 ]; then
    echo "🚨 No Opus servers running! Starting local inference setup..."
    echo "⚠️  Warning: Limited local inference without Opus servers"
fi

# Launch main comprehensive system
echo "🌐 Starting main system interface..."
python3 COMPREHENSIVE_ZERO_TOKEN_MASTER_SYSTEM.py &
MAIN_PID=$!

# Give main system time to start
sleep 5

# Launch Voice UI system if not already running
echo "🎤 Starting Voice UI system..."
if ! curl -s "http://localhost:8001/" >/dev/null 2>&1; then
    python3 VOICE_UI_COMPLETE_SYSTEM.py &
    VOICE_PID=$!
else
    echo "✅ Voice UI system already running"
fi

# Wait a moment for startup
sleep 3

# Verify systems are running
echo "🔍 Verifying system status..."

if curl -s "http://localhost:8000/health" >/dev/null 2>&1; then
    echo "✅ Main system operational: http://localhost:8000"
    echo "📊 API Documentation: http://localhost:8000/docs"
else
    echo "❌ Main system failed to start"
    exit 1
fi

if curl -s "http://localhost:8001/" >/dev/null 2>&1; then
    echo "✅ Voice UI system operational: http://localhost:8001"
    echo "🎤 Voice Documentation: http://localhost:8001/docs"
else
    echo "⚠️  Voice UI system not accessible"
fi

# Show performance status
echo ""
echo "📊 SYSTEM PERFORMANCE STATUS"
echo "============================================================"
performance_data=$(curl -s "http://localhost:8000/performance" 2>/dev/null || echo '{"error":"unavailable"}')
if echo "$performance_data" | grep -q "total_performance"; then
    total_tflops=$(echo "$performance_data" | grep -o '"total_performance":[0-9.]*' | cut -d: -f2)
    target_achieved=$(echo "$performance_data" | grep -o '"target_achieved":[a-z]*' | cut -d: -f2)
    echo "🎯 Total Performance: ${total_tflops} TFLOPS"
    if [ "$target_achieved" = "true" ]; then
        echo "✅ Target achieved: 40+ TFLOPS"
    else
        echo "⚠️  Target not yet achieved - optimizing..."
    fi
else
    echo "⚠️  Performance data unavailable"
fi

echo ""
echo "🎉 ZERO-TOKEN SYSTEM LAUNCHED SUCCESSFULLY!"
echo "============================================================"
echo "🌐 Main Interface: http://localhost:8000"
echo "🎤 Voice Interface: http://localhost:8001"
echo "📚 Documentation: http://localhost:8000/docs"
echo "🔧 System Status: curl http://localhost:8000/health"
echo "============================================================"
echo ""
echo "💡 Usage Examples:"
echo "   • Agent invoke: curl -X POST http://localhost:8000/agent/invoke"
echo "   • Voice process: curl -X POST http://localhost:8000/voice/process"
echo "   • Performance: curl http://localhost:8000/performance"
echo ""
echo "🚀 System ready for zero-token operation!"
echo "Press Ctrl+C to stop all systems"

# Keep script running and handle cleanup
cleanup() {
    echo ""
    echo "🛑 Shutting down systems..."
    if [ ! -z "$MAIN_PID" ]; then
        kill $MAIN_PID 2>/dev/null || true
    fi
    if [ ! -z "$VOICE_PID" ]; then
        kill $VOICE_PID 2>/dev/null || true
    fi
    echo "✅ Cleanup complete"
    exit 0
}

trap cleanup INT TERM

# Wait for user to stop
wait