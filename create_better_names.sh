#!/bin/bash
# Create Better Named Command Shortcuts

echo "🎯 Creating better named command shortcuts..."

# Remove old generic names
rm -f launch status-check install 2>/dev/null

# Create descriptive, professional names
ln -sf launch_hybrid_system.sh start-system && echo "✅ ./start-system - Launch the hybrid bridge integration system"
ln -sf check_system_status.sh system-health && echo "✅ ./system-health - Check comprehensive system health"
ln -sf claude-installer.sh setup && echo "✅ ./setup - Install and configure the system"

# Additional useful shortcuts
ln -sf integrate_hybrid_bridge.sh integrate && echo "✅ ./integrate - Run hybrid bridge integration"

echo
echo "🎉 Professional command shortcuts created!"
echo
echo "📋 Usage:"
echo "  ./start-system  - Launch hybrid bridge integration system"
echo "  ./system-health - Comprehensive system health check"
echo "  ./setup         - Install and configure system"
echo "  ./integrate     - Run hybrid bridge integration"
echo
echo "🚀 These names are much clearer and professional!"