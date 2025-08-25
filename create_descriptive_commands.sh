#!/bin/bash
# Create Descriptive Command Names - What Am I Actually Running?

echo "🎯 Creating descriptive command names that tell you WHAT you're running..."

# Remove old vague names
rm -f start-system system-health setup integrate 2>/dev/null

# Create crystal clear descriptive names
echo "🚀 Creating descriptive commands..."

ln -sf launch_hybrid_system.sh launch-hybrid-bridge && echo "✅ ./launch-hybrid-bridge - Launch the PostgreSQL hybrid bridge integration system"

ln -sf check_system_status.sh check-hybrid-bridge-health && echo "✅ ./check-hybrid-bridge-health - Check PostgreSQL hybrid bridge system health"

ln -sf claude-installer.sh setup-claude-agents && echo "✅ ./setup-claude-agents - Setup Claude Agent Framework with 65+ specialized agents"

ln -sf integrate_hybrid_bridge.sh setup-hybrid-bridge && echo "✅ ./setup-hybrid-bridge - Setup PostgreSQL hybrid bridge (native + Docker integration)"

# Additional descriptive shortcuts for key files
ln -sf integrated_learning_setup.py setup-learning-system && echo "✅ ./setup-learning-system - Setup ML-powered PostgreSQL learning system (155K+ lines)"

ln -sf github-sync.sh sync-to-github && echo "✅ ./sync-to-github - Sync project to GitHub repository"

echo
echo "🎉 Descriptive command names created!"
echo
echo "📋 Crystal Clear Commands - You Know EXACTLY What You're Running:"
echo
echo "🚀 SYSTEM OPERATIONS:"
echo "  ./launch-hybrid-bridge        - Launch PostgreSQL hybrid bridge integration system"
echo "  ./check-hybrid-bridge-health  - Check PostgreSQL hybrid bridge system health"
echo
echo "🔧 SETUP OPERATIONS:"
echo "  ./setup-claude-agents         - Setup Claude Agent Framework (65+ agents)"
echo "  ./setup-hybrid-bridge         - Setup PostgreSQL hybrid bridge integration"
echo "  ./setup-learning-system       - Setup ML-powered learning system (155K+ lines)"
echo
echo "🌐 MAINTENANCE:"
echo "  ./sync-to-github              - Sync project to GitHub repository"
echo
echo "✨ No more guessing - each command tells you EXACTLY what system you're operating!"