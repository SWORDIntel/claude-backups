#!/bin/bash
# Docker Installation Script for Hybrid Bridge Integration
# Installs Docker and Docker Compose with proper user permissions

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1" >&2; }
info() { echo -e "${BLUE}[$(date '+%H:%M:%S')] INFO:${NC} $1"; }

echo "=================================================================="
echo "         Docker Installation for Hybrid Bridge Integration"
echo "=================================================================="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Don't run this script as root - it will handle sudo automatically"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    error "Cannot detect OS version"
    exit 1
fi

log "Detected OS: $OS $VERSION"

# Install Docker based on OS
case $OS in
    ubuntu|debian)
        log "Installing Docker on Ubuntu/Debian..."
        
        # Update package index
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            apt-transport-https \
            software-properties-common
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index with new repository
        sudo apt-get update
        
        # Install Docker Engine
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Install docker-compose (standalone)
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        log "✓ Docker installed successfully"
        ;;
        
    centos|rhel|fedora)
        log "Installing Docker on CentOS/RHEL/Fedora..."
        
        # Install prerequisites
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf update -y
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        else
            sudo yum update -y
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        
        # Install docker-compose (standalone)
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        log "✓ Docker installed successfully"
        ;;
        
    arch)
        log "Installing Docker on Arch Linux..."
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm docker docker-compose
        log "✓ Docker installed successfully"
        ;;
        
    *)
        warn "Unsupported OS: $OS"
        info "Trying generic installation via snap..."
        
        if command -v snap >/dev/null 2>&1; then
            sudo snap install docker
            log "✓ Docker installed via snap"
        else
            error "Cannot install Docker automatically on this system"
            info "Please install Docker manually from https://docs.docker.com/engine/install/"
            exit 1
        fi
        ;;
esac

# Start and enable Docker service
log "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
log "Adding user to docker group..."
sudo usermod -aG docker "$USER"

# Test Docker installation
log "Testing Docker installation..."
if sudo docker run --rm hello-world >/dev/null 2>&1; then
    log "✓ Docker installation test passed"
else
    warn "Docker installation test failed, but Docker appears to be installed"
fi

# Test Docker Compose
log "Testing Docker Compose..."
if docker-compose --version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version)
    log "✓ Docker Compose available: $COMPOSE_VERSION"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    log "✓ Docker Compose plugin available: $COMPOSE_VERSION"
else
    warn "Docker Compose not available - some features may be limited"
fi

echo
log "=== Docker Installation Complete ==="
echo
info "IMPORTANT: You need to logout and login again (or run 'newgrp docker')"
info "for the docker group membership to take effect."
echo
info "Verification commands:"
echo "  docker --version"
echo "  docker-compose --version"
echo "  docker run --rm hello-world"
echo
log "Docker is now ready for Hybrid Bridge Integration!"