#!/bin/bash
# Test script for Docker auto-restart configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Docker Container Auto-Restart Configuration ===${NC}"
echo ""

# Source the installer functions
source ./claude-installer.sh 2>/dev/null || {
    echo -e "${RED}Error: Could not source claude-installer.sh${NC}"
    exit 1
}

# Test the configure_docker_autostart function
echo -e "${YELLOW}1. Testing configure_docker_autostart function...${NC}"
configure_docker_autostart

echo ""
echo -e "${YELLOW}2. Current container restart policies:${NC}"
for container in claude-postgres claude-learning claude-bridge claude-prometheus; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$" 2>/dev/null; then
        policy=$(docker inspect "$container" --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null || echo "not found")
        if [[ "$policy" == "unless-stopped" ]]; then
            echo -e "  ${GREEN}✓${NC} $container: $policy"
        else
            echo -e "  ${RED}✗${NC} $container: $policy"
        fi
    else
        echo -e "  ${YELLOW}-${NC} $container: not found"
    fi
done

echo ""
echo -e "${YELLOW}3. Testing idempotency (running function again)...${NC}"
configure_docker_autostart

echo ""
echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "To verify auto-restart will work on reboot:"
echo "1. Stop Docker service: sudo systemctl stop docker"
echo "2. Start Docker service: sudo systemctl start docker"
echo "3. Check if containers auto-started: docker ps"