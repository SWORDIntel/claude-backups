#!/bin/bash
# Complete Docker Learning System Fix
# Addresses all Docker permission and auto-start issues

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}${CYAN}Complete Docker Learning System Fix${RESET}"
echo "==========================================="
echo

# Function to check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ Do not run this script as root${RESET}"
        echo "Run as regular user - the script will prompt for sudo when needed"
        exit 1
    fi
}

# Function to check Docker group membership
check_docker_group() {
    if groups $USER | grep -q docker; then
        echo -e "${GREEN}✅ User $USER is in docker group${RESET}"
        return 0
    else
        echo -e "${YELLOW}⚠️  User $USER is NOT in docker group${RESET}"
        return 1
    fi
}

# Function to test Docker access
test_docker_access() {
    if docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker access working${RESET}"
        return 0
    else
        echo -e "${RED}❌ Docker access failed${RESET}"
        return 1
    fi
}

# Main fix process
main() {
    check_not_root

    echo -e "${CYAN}Step 1: Checking current Docker configuration...${RESET}"

    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not installed${RESET}"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}⚠️  Docker daemon is not running${RESET}"
        echo "Starting Docker daemon..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi

    echo -e "${CYAN}Step 2: Fixing Docker permissions...${RESET}"

    # Check current group membership
    if ! check_docker_group; then
        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✅ User added to docker group${RESET}"
        echo -e "${YELLOW}⚠️  You need to log out and log back in for group changes to take effect${RESET}"
        echo "Or run: newgrp docker"
        echo
    fi

    # Test current Docker access
    if ! test_docker_access; then
        echo -e "${YELLOW}Attempting to activate new group membership...${RESET}"

        # Try newgrp approach
        echo "Attempting to activate docker group..."
        if newgrp docker <<< 'docker ps >/dev/null 2>&1 && echo "Docker access working"' | grep -q "Docker access working"; then
            echo -e "${GREEN}✅ Docker access activated via newgrp${RESET}"
        else
            echo -e "${YELLOW}⚠️  Docker permissions still need manual activation${RESET}"
            echo "Please run one of the following:"
            echo "  1. newgrp docker"
            echo "  2. Log out and log back in"
            echo "  3. Restart your terminal session"
            echo
            echo "Then re-run this script to continue setup."
        fi
    fi

    echo -e "${CYAN}Step 3: Setting up learning system auto-start...${RESET}"

    # Ensure configuration exists
    CONFIG_DIR="$HOME/.config/claude"
    if [[ ! -f "$CONFIG_DIR/.env" ]]; then
        echo "Learning system configuration missing - running setup..."
        if [[ -f "/home/john/claude-backups/configure_docker_learning_autostart.sh" ]]; then
            /home/john/claude-backups/configure_docker_learning_autostart.sh
        else
            echo -e "${RED}❌ Configuration script not found${RESET}"
            exit 1
        fi
    fi

    echo -e "${CYAN}Step 4: Testing learning system startup...${RESET}"

    # Source the environment
    if [[ -f "$CONFIG_DIR/.env" ]]; then
        source "$CONFIG_DIR/.env"
    fi

    # Try to start the learning system if Docker access works
    if test_docker_access; then
        echo "Testing learning system startup..."
        if [[ -f "$CONFIG_DIR/start_learning_system.sh" ]]; then
            if "$CONFIG_DIR/start_learning_system.sh"; then
                echo -e "${GREEN}✅ Learning system started successfully${RESET}"
            else
                echo -e "${YELLOW}⚠️  Learning system startup had issues${RESET}"
            fi
        fi
    fi

    echo -e "${CYAN}Step 5: Adding shell integration...${RESET}"

    # Add shell integration to bashrc if not already present
    SHELL_INTEGRATION="$CONFIG_DIR/shell_integration.sh"
    if [[ -f "$SHELL_INTEGRATION" ]]; then
        BASHRC="$HOME/.bashrc"
        if [[ -f "$BASHRC" ]] && ! grep -q "shell_integration.sh" "$BASHRC"; then
            echo "Adding shell integration to ~/.bashrc..."
            echo "" >> "$BASHRC"
            echo "# Claude Learning System Integration" >> "$BASHRC"
            echo "source \"$SHELL_INTEGRATION\"" >> "$BASHRC"
            echo -e "${GREEN}✅ Shell integration added to ~/.bashrc${RESET}"
            echo -e "${YELLOW}Source your bashrc or restart terminal: source ~/.bashrc${RESET}"
        else
            echo -e "${GREEN}✅ Shell integration already configured${RESET}"
        fi
    fi

    echo
    echo -e "${BOLD}${GREEN}Fix Process Complete!${RESET}"
    echo
    echo -e "${CYAN}Summary of changes:${RESET}"
    echo "  • User added to docker group"
    echo "  • Docker daemon started and enabled"
    echo "  • Learning system auto-start configured"
    echo "  • Shell integration added"
    echo
    echo -e "${CYAN}Next steps:${RESET}"
    echo "  1. If Docker access still fails, log out and log back in"
    echo "  2. Test Docker access: docker ps"
    echo "  3. Start learning system: claude-learning-start"
    echo "  4. Check system health: claude-learning-health"
    echo "  5. Test NPU system: claude-npu-test"
    echo
    echo -e "${CYAN}Validation:${RESET}"
    echo "  Run the validation script to check everything:"
    echo "  /home/john/claude-backups/validate_docker_learning_integration.sh"
}

# Run main function
main "$@"