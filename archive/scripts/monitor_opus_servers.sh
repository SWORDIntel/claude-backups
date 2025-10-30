#!/bin/bash
echo "🔍 Opus Server Status - $(date)"
echo "=================================="

for port in 3451 3452 3453 3454; do
    echo -n "Port $port: "
    if curl -s "http://localhost:$port/health" > /dev/null 2>&1; then
        response=$(curl -s "http://localhost:$port/health" | jq -r '.status // "unknown"')
        echo "✅ $response"
    else
        echo "❌ Down"
    fi
done

echo ""
echo "Process Status:"
pgrep -f "local_opus_server.py" | while read pid; do
    port=$(ps -p $pid -o args= | grep -o '\--port [0-9]*' | cut -d' ' -f2 || echo "unknown")
    echo "  PID $pid: Port $port"
done
