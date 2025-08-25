#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║ FAST SYSTEM RECOVERY SCRIPT - POST-REBOOT RESTORATION                        ║
# ║ Quick system setup for immediate productivity                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

log "Starting Fast System Recovery..."

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 1: UPDATE AND UPGRADE SYSTEM                                            │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Updating package lists..."
sudo apt update

log "Upgrading system packages..."
sudo apt upgrade -y

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 2: INSTALL ESSENTIAL DEVELOPMENT PACKAGES                               │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Installing essential development packages..."

# Core development tools
sudo apt install -y \
    git \
    gh \
    docker.io \
    docker-compose \
    python3-full \
    python3-pip \
    autoconf \
    make \
    gcc \
    build-essential \
    golang \
    rustc \
    cargo \
    nodejs \
    npm \
    curl \
    wget \
    firefox \
    snapd

# Additional useful packages
sudo apt install -y \
    vim \
    neovim \
    htop \
    tree \
    jq \
    zip \
    unzip \
    git-lfs \
    cmake \
    pkg-config \
    libssl-dev \
    zsh \
    tmux \
    rsync \
    net-tools \
    openssh-client \
    libc6-dev \
    pkg-config \
    libssl-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    lzma-dev \
    liblzma-dev

success "Essential packages installed"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 3: INSTALL SNAP PACKAGES                                                │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Installing Sublime Text via snap..."
sudo snap install sublime-text --classic

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 4: CONFIGURE DOCKER                                                     │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Configuring Docker for current user..."
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 5: OPEN REQUIRED WEBSITES                                               │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Opening required websites in Firefox..."

# Wait a moment for Firefox to be ready
sleep 2

# Open websites in Firefox tabs
firefox \
    https://claude.ai \
    https://proton.me \
    https://github.com &

success "Firefox opened with Claude.ai, Proton.me, and GitHub"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ STEP 6: GITHUB CLI AUTHENTICATION                                            │
# └──────────────────────────────────────────────────────────────────────────────┘

log "Setting up GitHub CLI authentication..."
info "Configuring Git with username SWORDIntel..."

# Configure Git username
git config --global user.name "SWORDIntel"
git config --global init.defaultBranch main

info "Run 'gh auth login' manually after this script completes"
info "Or run it now in a new terminal while websites load"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ COMPLETION                                                                    │
# └──────────────────────────────────────────────────────────────────────────────┘

success "Fast System Recovery Complete!"
echo
echo "═══════════════════════════════════════════════════════════════"
echo "POST-SCRIPT ACTIONS REQUIRED:"
echo "1. Log out and back in (or reboot) to activate Docker group"
echo "2. Run: gh auth login (Git already configured for SWORDIntel)"
echo "3. Configure Git email if needed: git config --global user.email <email>"
echo "═══════════════════════════════════════════════════════════════"
echo
info "System ready for development work!"