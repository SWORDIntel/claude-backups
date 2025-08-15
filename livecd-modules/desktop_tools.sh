#!/bin/bash
#
# desktop_tools.sh - LiveCD Desktop & User Tools Module
# Part of the consolidated LiveCD build system
#
# Consolidates desktop environment, GUI applications, documentation,
# and user productivity tools with performance optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly DESKTOP_MODULE_VERSION="1.0.0"
readonly DESKTOP_MODULE_NAME="Desktop Tools Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${DESKTOP_ENV:=gnome}"  # gnome, kde, xfce, lxde, mate
: "${INSTALL_OFFICE:=true}"
: "${INSTALL_MULTIMEDIA:=true}"
: "${INSTALL_DEVELOPMENT:=false}"
: "${PARALLEL_JOBS:=$(nproc)}"

#==============================================================================
# Desktop Environment Installation
#==============================================================================

# Install desktop environment with optimizations
desktop_install_environment() {
    local chroot_dir="$1"
    local desktop="${2:-$DESKTOP_ENV}"
    
    log_info "Installing $desktop desktop environment"
    
    # Mount required filesystems
    desktop_mount_chroot "$chroot_dir"
    
    # Base X11 packages (common to all desktops)
    local x11_packages=(
        "xorg" "xserver-xorg-video-all" "xserver-xorg-input-all"
        "mesa-utils" "mesa-va-drivers" "mesa-vdpau-drivers"
        "fonts-liberation" "fonts-dejavu" "fonts-noto"
        "pulseaudio" "pavucontrol" "alsa-utils"
        "network-manager-gnome" "blueman"
    )
    
    # Install X11 base in parallel batches
    log_info "Installing X11 base packages"
    desktop_install_packages_batch "$chroot_dir" "${x11_packages[@]}"
    
    # Install desktop-specific packages
    case "$desktop" in
        "gnome")
            desktop_install_gnome "$chroot_dir"
            ;;
        "kde")
            desktop_install_kde "$chroot_dir"
            ;;
        "xfce")
            desktop_install_xfce "$chroot_dir"
            ;;
        "lxde")
            desktop_install_lxde "$chroot_dir"
            ;;
        "mate")
            desktop_install_mate "$chroot_dir"
            ;;
        *)
            log_error "Unknown desktop environment: $desktop"
            return 1
            ;;
    esac
    
    # Configure display manager
    desktop_configure_display_manager "$chroot_dir" "$desktop"
    
    # Unmount filesystems
    desktop_umount_chroot "$chroot_dir"
    
    log_info "Desktop environment installation completed"
}

# Install GNOME desktop
desktop_install_gnome() {
    local chroot_dir="$1"
    
    log_info "Installing GNOME desktop"
    
    local gnome_packages=(
        "gnome-core" "gnome-shell" "gnome-terminal"
        "nautilus" "gedit" "gnome-calculator"
        "gnome-system-monitor" "gnome-screenshot"
        "gnome-tweaks" "chrome-gnome-shell"
        "gdm3" "gnome-control-center"
    )
    
    desktop_install_packages_batch "$chroot_dir" "${gnome_packages[@]}"
    
    # Configure GNOME settings
    chroot "$chroot_dir" bash -c "
        # Set default session
        update-alternatives --set gdm3-theme.gresource \
            /usr/share/gnome-shell/gnome-shell-theme.gresource
        
        # Configure GDM for auto-login
        sed -i 's/#  AutomaticLoginEnable/AutomaticLoginEnable/' /etc/gdm3/daemon.conf
        sed -i 's/#  AutomaticLogin = user1/AutomaticLogin = liveuser/' /etc/gdm3/daemon.conf
    "
}

# Install KDE Plasma desktop
desktop_install_kde() {
    local chroot_dir="$1"
    
    log_info "Installing KDE Plasma desktop"
    
    local kde_packages=(
        "kde-plasma-desktop" "plasma-nm" "plasma-pa"
        "dolphin" "konsole" "kate" "okular"
        "ark" "kcalc" "spectacle"
        "sddm" "kde-config-sddm"
        "breeze-gtk-theme" "kde-config-gtk-style"
    )
    
    desktop_install_packages_batch "$chroot_dir" "${kde_packages[@]}"
    
    # Configure SDDM for auto-login
    chroot "$chroot_dir" bash -c "
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma
EOF
    "
}

# Install XFCE desktop
desktop_install_xfce() {
    local chroot_dir="$1"
    
    log_info "Installing XFCE desktop"
    
    local xfce_packages=(
        "xfce4" "xfce4-goodies" "xfce4-terminal"
        "thunar" "thunar-archive-plugin"
        "mousepad" "ristretto" "xfce4-screenshooter"
        "lightdm" "lightdm-gtk-greeter"
    )
    
    desktop_install_packages_batch "$chroot_dir" "${xfce_packages[@]}"
    
    # Configure LightDM for auto-login
    chroot "$chroot_dir" bash -c "
        sed -i 's/^#autologin-user=/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
        sed -i 's/^#autologin-user-timeout=0/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
    "
}

# Install LXDE desktop
desktop_install_lxde() {
    local chroot_dir="$1"
    
    log_info "Installing LXDE desktop"
    
    local lxde_packages=(
        "lxde-core" "lxde-common" "lxsession"
        "pcmanfm" "lxterminal" "leafpad"
        "gpicview" "lxappearance"
        "lightdm" "lightdm-gtk-greeter"
    )
    
    desktop_install_packages_batch "$chroot_dir" "${lxde_packages[@]}"
}

# Install MATE desktop
desktop_install_mate() {
    local chroot_dir="$1"
    
    log_info "Installing MATE desktop"
    
    local mate_packages=(
        "mate-desktop-environment-core"
        "mate-terminal" "caja" "pluma"
        "atril" "eom" "mate-calc"
        "lightdm" "lightdm-gtk-greeter"
    )
    
    desktop_install_packages_batch "$chroot_dir" "${mate_packages[@]}"
}

#==============================================================================
# Application Installation
#==============================================================================

# Install office and productivity applications
desktop_install_office() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_OFFICE" != "true" ]]; then
        log_info "Office suite installation skipped"
        return 0
    fi
    
    log_info "Installing office and productivity applications"
    
    local office_packages=(
        "libreoffice" "libreoffice-gtk3"
        "thunderbird" "firefox-esr"
        "evince" "calibre"
        "gnome-calendar" "gnome-contacts"
        "simple-scan" "cheese"
    )
    
    desktop_mount_chroot "$chroot_dir"
    desktop_install_packages_batch "$chroot_dir" "${office_packages[@]}"
    desktop_umount_chroot "$chroot_dir"
    
    log_info "Office applications installed"
}

# Install multimedia applications
desktop_install_multimedia() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_MULTIMEDIA" != "true" ]]; then
        log_info "Multimedia installation skipped"
        return 0
    fi
    
    log_info "Installing multimedia applications"
    
    local multimedia_packages=(
        "vlc" "mpv" "audacity"
        "gimp" "inkscape" "blender"
        "obs-studio" "kdenlive"
        "rhythmbox" "shotwell"
        "gstreamer1.0-plugins-base"
        "gstreamer1.0-plugins-good"
        "gstreamer1.0-plugins-bad"
        "gstreamer1.0-plugins-ugly"
        "gstreamer1.0-libav"
    )
    
    desktop_mount_chroot "$chroot_dir"
    
    # Enable non-free repositories for codecs
    chroot "$chroot_dir" bash -c "
        sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list
        apt-get update
    "
    
    desktop_install_packages_batch "$chroot_dir" "${multimedia_packages[@]}"
    desktop_umount_chroot "$chroot_dir"
    
    log_info "Multimedia applications installed"
}

# Install development tools
desktop_install_development() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_DEVELOPMENT" != "true" ]]; then
        log_info "Development tools installation skipped"
        return 0
    fi
    
    log_info "Installing development tools"
    
    local dev_packages=(
        "code" "vim-gtk3" "emacs"
        "git" "gitk" "git-gui"
        "build-essential" "cmake" "automake"
        "python3" "python3-pip" "python3-venv"
        "nodejs" "npm" "yarn"
        "docker.io" "docker-compose"
        "virtualbox" "vagrant"
    )
    
    desktop_mount_chroot "$chroot_dir"
    
    # Add VSCode repository
    chroot "$chroot_dir" bash -c "
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
        echo 'deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/repos/code stable main' > \
            /etc/apt/sources.list.d/vscode.list
        apt-get update
    " 2>/dev/null || true
    
    desktop_install_packages_batch "$chroot_dir" "${dev_packages[@]}"
    desktop_umount_chroot "$chroot_dir"
    
    log_info "Development tools installed"
}

#==============================================================================
# Desktop Configuration
#==============================================================================

# Configure display manager
desktop_configure_display_manager() {
    local chroot_dir="$1"
    local desktop="$2"
    
    log_info "Configuring display manager for $desktop"
    
    case "$desktop" in
        "gnome")
            chroot "$chroot_dir" systemctl set-default graphical.target
            chroot "$chroot_dir" systemctl enable gdm3
            ;;
        "kde")
            chroot "$chroot_dir" systemctl set-default graphical.target
            chroot "$chroot_dir" systemctl enable sddm
            ;;
        "xfce"|"lxde"|"mate")
            chroot "$chroot_dir" systemctl set-default graphical.target
            chroot "$chroot_dir" systemctl enable lightdm
            ;;
    esac
    
    # Configure auto-login for live user
    desktop_configure_autologin "$chroot_dir" "$desktop"
}

# Configure auto-login for live session
desktop_configure_autologin() {
    local chroot_dir="$1"
    local desktop="$2"
    
    log_info "Configuring auto-login for liveuser"
    
    # Create liveuser if not exists
    chroot "$chroot_dir" bash -c "
        if ! id -u liveuser >/dev/null 2>&1; then
            useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev liveuser
            echo 'liveuser:live' | chpasswd
            echo 'liveuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/liveuser
        fi
    "
    
    # Configure desktop-specific auto-login
    case "$desktop" in
        "gnome")
            echo "[daemon]
AutomaticLoginEnable=true
AutomaticLogin=liveuser" > "$chroot_dir/etc/gdm3/daemon.conf"
            ;;
        "kde")
            echo "[Autologin]
User=liveuser
Session=plasma" > "$chroot_dir/etc/sddm.conf.d/autologin.conf"
            ;;
        *)
            echo "[Seat:*]
autologin-user=liveuser
autologin-user-timeout=0" > "$chroot_dir/etc/lightdm/lightdm.conf.d/50-autologin.conf"
            ;;
    esac
}

# Create desktop documentation
desktop_create_documentation() {
    local chroot_dir="$1"
    
    log_info "Creating desktop documentation"
    
    # Create welcome document
    cat > "$chroot_dir/home/liveuser/Desktop/Welcome.md" << 'EOF'
# Welcome to LiveCD System

This is your LiveCD environment with a fully functional desktop.

## Quick Start
- This is a live session - changes are not persistent
- Default username: liveuser
- Default password: live
- You have full sudo access

## Installed Software
- Office Suite: LibreOffice
- Web Browser: Firefox
- Media Player: VLC
- Image Editor: GIMP
- And much more...

## System Information
- Press Super key to open activities overview
- Right-click desktop for context menu
- System settings available in the menu

## Getting Help
- Press F1 for help in most applications
- Check /usr/share/doc for documentation
- System logs in /var/log

Enjoy your LiveCD experience!
EOF
    
    chown 1000:1000 "$chroot_dir/home/liveuser/Desktop/Welcome.md" 2>/dev/null || true
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems for desktop operations
desktop_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /dev/pts "$chroot_dir/dev/pts" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
    mount --bind /run "$chroot_dir/run" 2>/dev/null || true
}

# Unmount chroot filesystems
desktop_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/run" 2>/dev/null || true
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev/pts" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

# Install packages in optimized batches
desktop_install_packages_batch() {
    local chroot_dir="$1"
    shift
    local packages=("$@")
    
    # Install in parallel batches
    local batch_size=5
    local package_batch=()
    
    for package in "${packages[@]}"; do
        package_batch+=("$package")
        
        if [[ ${#package_batch[@]} -eq $batch_size ]]; then
            log_info "Installing batch: ${package_batch[*]}"
            chroot "$chroot_dir" apt-get install -y "${package_batch[@]}" &
            package_batch=()
            
            # Limit concurrent jobs
            while [[ $(jobs -r | wc -l) -ge 3 ]]; do
                sleep 2
            done
        fi
    done
    
    # Install remaining packages
    if [[ ${#package_batch[@]} -gt 0 ]]; then
        chroot "$chroot_dir" apt-get install -y "${package_batch[@]}"
    fi
    
    wait  # Wait for all background jobs
}

#==============================================================================
# Public API Functions
#==============================================================================

# Main entry point for desktop tools installation
desktop_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "environment")
            desktop_install_environment "$chroot_dir"
            ;;
        "office")
            desktop_install_office "$chroot_dir"
            ;;
        "multimedia")
            desktop_install_multimedia "$chroot_dir"
            ;;
        "development")
            desktop_install_development "$chroot_dir"
            ;;
        "configure")
            desktop_configure_display_manager "$chroot_dir" "$DESKTOP_ENV"
            desktop_create_documentation "$chroot_dir"
            ;;
        "all")
            log_info "Installing complete desktop environment"
            desktop_install_environment "$chroot_dir"
            desktop_install_office "$chroot_dir"
            desktop_install_multimedia "$chroot_dir"
            desktop_install_development "$chroot_dir"
            desktop_create_documentation "$chroot_dir"
            log_info "Desktop installation completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {environment|office|multimedia|development|configure|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    desktop_main "$@"
fi