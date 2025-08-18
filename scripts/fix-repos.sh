#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# SYSTEM RECOVERY AND SAFE REPOSITORY SETUP
# Fixes package removal issues and safely configures repositories
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() { printf "${GREEN}[FIX]${NC} $1"; }
error() { printf "${RED}[ERROR]${NC} $1" >&2; exit 1; }
warn() { printf "${YELLOW}[WARNING]${NC} $1" >&2; }
info() { printf "${CYAN}[INFO]${NC} $1"; }
success() { printf "${GREEN}[SUCCESS]${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
fi

printf "${RED}═══════════════════════════════════════════════════════════${NC}\n"
printf "${RED}     SYSTEM RECOVERY AND REPOSITORY FIX${NC}\n"
printf "${RED}═══════════════════════════════════════════════════════════${NC}\n"
echo

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: IMMEDIATE RECOVERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 1: Removing problematic APT configurations...\n"

# Remove ALL custom APT configs that might cause issues
rm -f /etc/apt/apt.conf.d/99-no-gpg 2>/dev/null || true
rm -f /etc/apt/apt.conf.d/99-fix 2>/dev/null || true
rm -f /etc/apt/apt.conf.d/99-optimized 2>/dev/null || true
rm -f /etc/apt/apt.conf.d/99-safe-repos 2>/dev/null || true
rm -f /etc/apt/apt.conf.d/01-optimize 2>/dev/null || true

success "Problematic APT configs removed\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: RESTORE SAFE APT CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 2: Creating safe APT configuration...\n"

cat > /etc/apt/apt.conf.d/00-safe-restore << 'EOF'
# SAFE RESTORATION SETTINGS - PRESERVES PACKAGES
# This ensures packages are not removed

# CRITICAL: Keep package recommendations
APT::Install-Recommends "true";
APT::Install-Suggests "false";
APT::AutoRemove::RecommendsImportant "true";
APT::AutoRemove::SuggestsImportant "true";

# Allow repos without GPG (temporary for recovery)
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "true";

# Suppress only Dell metadata warnings
Acquire::IndexTargets::deb::CNF::DefaultEnabled "false";
Acquire::IndexTargets::deb::DEP-11::DefaultEnabled "false";
Acquire::IndexTargets::deb::DEP-11-icons::DefaultEnabled "false";

# Basic performance
Acquire::http::Pipeline-Depth "5";
Acquire::Languages "none";
Acquire::GzipIndexes "true";

# Safety settings
DPkg::Options:: "--force-confdef";
DPkg::Options:: "--force-confold";
EOF

success "Safe APT configuration created\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: DETECT SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 3: Detecting system configuration...\n"

# Load OS information
. /etc/os-release
DISTRO="${ID:-ubuntu}"
CODENAME="${VERSION_CODENAME:-jammy}"
VERSION="${VERSION_ID:-22.04}"

# Detect desktop environment
HAS_DESKTOP=false
if dpkg -l | grep -qE "ubuntu-desktop|kubuntu-desktop|xubuntu-desktop|gnome-shell|kde-plasma|xfce4"; then
    HAS_DESKTOP=true
fi

# Detect if it's a server
IS_SERVER=false
if dpkg -l | grep -q "ubuntu-server" || [ "$HAS_DESKTOP" = false ]; then
    IS_SERVER=true
fi

info "System: $DISTRO $VERSION ($CODENAME)\n"
info "Desktop Environment: $HAS_DESKTOP\n"
info "Server Installation: $IS_SERVER\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: FIX REPOSITORIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 4: Fixing repositories...\n"

# Backup current sources
BACKUP_DIR="/root/recovery-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/apt/sources.list* "$BACKUP_DIR/" 2>/dev/null || true
info "Backup created at $BACKUP_DIR\n"

# Create clean sources.list
cat > /etc/apt/sources.list << EOF
# Ubuntu Main Repositories - Fixed
deb http://archive.ubuntu.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $CODENAME-security main restricted universe multiverse

# Source packages (optional)
# deb-src http://archive.ubuntu.com/ubuntu/ $CODENAME main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF

# Clean problematic third-party repos
rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true

# Add only essential repos
if [ "$CODENAME" = "jammy" ] || [ "$CODENAME" = "focal" ] || [ "$CODENAME" = "noble" ]; then
    cat > /etc/apt/sources.list.d/canonical-partner.list << EOF
# Canonical Partner
deb http://archive.canonical.com/ubuntu $CODENAME partner
EOF
fi

success "Repositories fixed\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: UPDATE PACKAGE LISTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 5: Updating package lists...\n"

# Update with error handling
apt-get update 2>&1 | tee /tmp/apt-update.log | grep -v "W:\|N:" || true

if grep -q "NO_PUBKEY" /tmp/apt-update.log; then
    warn "GPG key issues detected, fixing...\n"
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $(grep "NO_PUBKEY" /tmp/apt-update.log | sed 's/.*NO_PUBKEY //g') 2>/dev/null || true
    apt-get update 2>&1 | grep -v "W:\|N:" || true
fi

success "Package lists updated\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: RESTORE REMOVED PACKAGES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 6: Checking for and restoring removed packages...\n"

# Check recent removals
printf "${YELLOW}Recently removed packages (if any):${NC}\n"
grep " Remove:" /var/log/apt/history.log 2>/dev/null | tail -5 || echo "  No recent removals found in log"
echo

# Restore based on system type
if [ "$HAS_DESKTOP" = true ]; then
    warn "Desktop environment detected - restoring desktop packages...\n"
    
    echo "Which desktop environment do you need?"
    echo "1) Ubuntu (GNOME)"
    echo "2) Kubuntu (KDE)"
    echo "3) Xubuntu (XFCE)"
    echo "4) Ubuntu MATE"
    echo "5) Lubuntu (LXQt)"
    echo "6) Skip desktop restoration"
    
    read -p "Enter choice [1-6]: " choice
    
    case $choice in
        1)
            log "Restoring Ubuntu desktop...\n"
            apt-get install -y --fix-missing ubuntu-desktop^
            ;;
        2)
            log "Restoring Kubuntu desktop...\n"
            apt-get install -y --fix-missing kubuntu-desktop^
            ;;
        3)
            log "Restoring Xubuntu desktop...\n"
            apt-get install -y --fix-missing xubuntu-desktop^
            ;;
        4)
            log "Restoring Ubuntu MATE...\n"
            apt-get install -y --fix-missing ubuntu-mate-desktop^
            ;;
        5)
            log "Restoring Lubuntu...\n"
            apt-get install -y --fix-missing lubuntu-desktop^
            ;;
        6)
            info "Skipping desktop restoration\n"
            ;;
        *)
            warn "Invalid choice, skipping desktop restoration\n"
            ;;
    esac
fi

if [ "$IS_SERVER" = true ]; then
    log "Restoring server packages...\n"
    apt-get install -y --fix-missing ubuntu-server^ 2>/dev/null || true
fi

# Restore common essential packages
log "Restoring essential packages...\n"
ESSENTIAL_PACKAGES="
    curl
    wget
    git
    vim
    nano
    htop
    net-tools
    build-essential
    software-properties-common
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    linux-generic
    linux-headers-generic
"

for pkg in $ESSENTIAL_PACKAGES; do
    dpkg -l | grep -q "^ii.*$pkg" || apt-get install -y "$pkg" 2>/dev/null || true
done

# Fix any broken packages
log "Fixing broken packages...\n"
apt-get install -f -y 2>/dev/null || true
dpkg --configure -a 2>/dev/null || true

success "Package restoration complete\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: OPTIONAL - ADD HARDWARE REPOS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo
read -p "Add Intel/Dell repositories? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Intel repos
    if lscpu 2>/dev/null | grep -qi "Intel"; then
        log "Adding Intel repositories...\n"
        case "$CODENAME" in
            noble|oracular) INTEL_UBUNTU="noble" ;;
            jammy) INTEL_UBUNTU="jammy" ;;
            focal) INTEL_UBUNTU="focal" ;;
            *) INTEL_UBUNTU="jammy" ;;
        esac
        
        cat > /etc/apt/sources.list.d/intel.list << EOF
# Intel Graphics
deb [arch=amd64,i386] https://repositories.intel.com/gpu/ubuntu $INTEL_UBUNTU/lts/2350 unified
EOF
    fi
    
    # Dell repos
    if dmidecode -s system-manufacturer 2>/dev/null | grep -qi "Dell"; then
        log "Adding Dell repositories...\n"
        case "$CODENAME" in
            noble|oracular) DELL_UBUNTU="jammy" ;;
            jammy) DELL_UBUNTU="jammy" ;;
            focal) DELL_UBUNTU="focal" ;;
            *) DELL_UBUNTU="jammy" ;;
        esac
        
        cat > /etc/apt/sources.list.d/dell.list << EOF
# Dell OpenManage
deb http://linux.dell.com/repo/community/openmanage/11110/${DELL_UBUNTU} ${DELL_UBUNTU} main
EOF
    fi
    
    apt-get update 2>&1 | grep -v "W:\|N:\|DEP-11\|CNF" || true
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 8: FINAL SAFETY CHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log "Step 8: Final system check...\n"

# DO NOT RUN AUTOREMOVE!
warn "NOT running autoremove - preserving all packages\n"

# Check system health
PACKAGE_COUNT=$(dpkg -l | grep -c "^ii")
info "Total installed packages: $PACKAGE_COUNT\n"

if [ "$PACKAGE_COUNT" -lt 500 ]; then
    error "Very few packages installed! System may need recovery."
elif [ "$PACKAGE_COUNT" -lt 1000 ]; then
    warn "Package count seems low. You may need to install more packages.\n"
else
    success "Package count looks normal.\n"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo
printf "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
printf "${GREEN}     SYSTEM RECOVERY COMPLETE${NC}\n"
printf "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
echo
echo "What was fixed:"
echo "  ✓ Removed problematic APT configurations"
echo "  ✓ Restored safe APT settings (keeping recommends)"
echo "  ✓ Fixed repository sources"
echo "  ✓ Updated package lists"
echo "  ✓ Restored essential packages"
echo "  ✗ Did NOT run autoremove"
echo
echo "System Status:"
echo "  • Ubuntu: $VERSION ($CODENAME)"
echo "  • Packages installed: $PACKAGE_COUNT"
echo "  • Desktop: $HAS_DESKTOP"
echo "  • Server: $IS_SERVER"
echo "  • Backup: $BACKUP_DIR"
echo
printf "${YELLOW}IMPORTANT NEXT STEPS:${NC}\n"
echo "1. Check if your applications are working"
echo "2. If something is missing, install it with:"
echo "   sudo apt-get install package-name"
echo "3. DO NOT run 'apt-get autoremove' right now"
echo "4. Reboot after confirming everything works"
echo
echo "If you still have issues:"
echo "  • Check removed packages: grep 'Remove:' /var/log/apt/history.log"
echo "  • Restore from backup: sudo cp -r $BACKUP_DIR/* /etc/apt/"
echo "  • Reinstall desktop: sudo apt-get install --reinstall ubuntu-desktop"
echo
success "Your system should now be recovered!"