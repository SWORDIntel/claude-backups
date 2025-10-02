#!/bin/bash
# Launch Interactive System Map in Browser

HTML_FILE="/home/john/Downloads/claude-backups/docs/INTERACTIVE_SYSTEM_MAP.html"

echo "🚀 Opening Claude Portable Agent System Interactive Map..."

# Try different browsers
if command -v xdg-open &> /dev/null; then
    xdg-open "$HTML_FILE"
elif command -v firefox &> /dev/null; then
    firefox "$HTML_FILE" &
elif command -v google-chrome &> /dev/null; then
    google-chrome "$HTML_FILE" &
elif command -v chromium &> /dev/null; then
    chromium "$HTML_FILE" &
else
    echo "No browser found. Please open this file manually:"
    echo "$HTML_FILE"
fi

echo "✅ Interactive map should open in your browser"
echo ""
echo "Features:"
echo "  🏗️  System Overview - Architecture diagrams"
echo "  📦 Modules - All subsystems with details"
echo "  🤖 Agents - 25+ specialized agents"
echo "  🔗 Interactions - Message flows"
echo "  ⚡ Parallelism - Parallel execution charts"
echo "  📊 Performance - Metrics and benchmarks"
echo ""
echo "Click on any module or agent for detailed information!"
