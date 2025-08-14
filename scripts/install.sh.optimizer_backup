#!/bin/bash
# ============================================================================
# Claude LiveCD Installer - Main Entry Point
# ============================================================================

cat << 'ASCII'
   _____ _                 _        _      _           _____ _____  
  / ____| |               | |      | |    (_)         / ____|  __ \ 
 | |    | | __ _ _   _  __| | ___  | |     ___   _____| |    | |  | |
 | |    | |/ _` | | | |/ _` |/ _ \ | |    | \ \ / / _ \ |    | |  | |
 | |____| | (_| | |_| | (_| |  __/ | |____| |\ V /  __/ |____| |__| |
  \_____|_|\__,_|\__,_|\__,_|\___| |______|_| \_/ \___|\_____|_____/ 
                                                                      
                Intel Core Ultra 7 Optimized Edition                 
ASCII

echo ""
echo "Welcome to Claude LiveCD Installer Package"
echo "==========================================="
echo ""
echo "This installer will set up Claude CLI with agents for LiveCD usage."
echo "Optimized for Intel Core Ultra 7 165H with AVX2 acceleration."
echo ""
echo "Choose installation method:"
echo ""
echo "1) Quick Install (Recommended) - Fully automatic"
echo "2) Custom Install - With options"
echo "3) View Documentation"
echo "4) Exit"
echo ""
read -p "Enter your choice [1-4]: " choice

case $choice in
    1)
        echo "Starting quick installation..."
        cd scripts
        chmod +x claude-quick-launch-agents.sh
        exec ./claude-quick-launch-agents.sh
        ;;
    2)
        echo "Starting custom installation..."
        cd scripts
        chmod +x claude-livecd-unified-with-agents.sh
        exec ./claude-livecd-unified-with-agents.sh
        ;;
    3)
        if command -v less >/dev/null 2>&1; then
            less docs/README.md
        else
            cat docs/README.md
        fi
        echo ""
        echo "Press Enter to return to menu..."
        read
        exec "$0"
        ;;
    4)
        echo "Installation cancelled."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run again."
        exit 1
        ;;
esac