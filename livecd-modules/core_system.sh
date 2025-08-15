#!/bin/bash
#
# core_system.sh - LiveCD Core System Module
# Part of the consolidated LiveCD build system
#
# Consolidates base system building, package management, chroot setup,
# repository configuration, and system services with optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly CORE_MODULE_VERSION="1.0.0"
readonly CORE_MODULE_NAME="Core System Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${BASE_SYSTEM:=debian}"  # Default to Debian for better kernel development
: "${INSTALL_ENHANCED_REPOS:=true}"
: "${INSTALL_ZFS_SUPPORT:=true}"
: "${INSTALL_ZFS_BOOTMENU:=true}"
: "${INSTALL_KERNEL_BUILD:=true}"
: "${PARALLEL_JOBS:=$(nproc)}"

#==============================================================================
# Base System Installation
#==============================================================================

# Create and configure base chroot environment
core_create_base_system() {
    local chroot_dir="$1"
    local base_system="${2:-$BASE_SYSTEM}"
    
    log_info "Creating base system: $base_system"
    
    # Create directory structure
    mkdir -p "$chroot_dir" || { echo "Error: Command failed"; return 1; }
    
    # Install base system
    case "$base_system" in
        "ubuntu")
            core_install_ubuntu_base "$chroot_dir"
            ;;
        "debian")
            core_install_debian_base "$chroot_dir"
            ;;
        *)
            log_error "Unknown base system: $base_system"
            return 1
            ;;
    esac
    
    # Configure base system
    core_configure_base_system "$chroot_dir"
    
    log_info "Base system created successfully"
}

# Install Ubuntu base system
core_install_ubuntu_base() {
    local chroot_dir="$1"
    
    log_info "Installing Ubuntu base system"
    
    # Use cdebootstrap to create base Ubuntu system
    # Using standard flavour for full-featured development environment
    cdebootstrap --arch=amd64 --flavour=standard jammy "$chroot_dir" \
        http://archive.ubuntu.com/ubuntu/ || { echo "Error: Command failed"; return 1; }
    
    # Mount essential filesystems
    core_mount_chroot "$chroot_dir"
    
    # Update package lists
    chroot "$chroot_dir" apt-get update || { echo "Error: Command failed"; return 1; }
    
    # Install essential packages for full development environment
    local essential_packages=(
        "systemd" "systemd-sysv" "dbus"
        "ubuntu-standard" "ubuntu-minimal"
        "locales" "tzdata" "console-setup"
        "keyboard-configuration" "ca-certificates"
        "wget" "curl" "gnupg" "software-properties-common"
        "apt-transport-https" "lsb-release"
        "build-essential" "linux-headers-generic" "linux-tools-generic"
        "dkms" "gcc" "g++" "make" "automake" "cmake"
        "gdb" "strace" "ltrace" "valgrind"
        "libelf-dev" "libssl-dev" "libncurses-dev"
        "pkg-config" "libtool" "bison" "flex"
    )
    
    core_install_packages_parallel "$chroot_dir" "${essential_packages[@]}"
    
    core_umount_chroot "$chroot_dir"
}

# Install Debian base system
core_install_debian_base() {
    local chroot_dir="$1"
    
    log_info "Installing Debian base system"
    
    # Use cdebootstrap to create base Debian system  
    # Using standard flavour for full development & kernel compilation
    cdebootstrap --arch=amd64 --flavour=standard bookworm "$chroot_dir" \
        http://deb.debian.org/debian/ || { echo "Error: Command failed"; return 1; }
    
    # Mount essential filesystems
    core_mount_chroot "$chroot_dir"
    
    # Update package lists
    chroot "$chroot_dir" apt-get update || { echo "Error: Command failed"; return 1; }
    
    # Install essential packages for kernel development & ring access
    local essential_packages=(
        "systemd" "systemd-sysv" "dbus"
        "locales" "tzdata" "console-setup"
        "keyboard-configuration" "ca-certificates"
        "wget" "curl" "gnupg" "software-properties-common"
        "apt-transport-https" "lsb-release"
        "build-essential" "linux-headers-amd64" "linux-tools-amd64"
        "dkms" "gcc" "g++" "make" "automake" "cmake"
        "gdb" "strace" "ltrace" "valgrind" "perf-tools-unstable"
        "libelf-dev" "libssl-dev" "libncurses-dev" "libdw-dev"
        "pkg-config" "libtool" "bison" "flex" "bc"
        "kmod" "initramfs-tools" "dracut" "systemtap"
    )
    
    core_install_packages_parallel "$chroot_dir" "${essential_packages[@]}"
    
    core_umount_chroot "$chroot_dir"
}

# Configure base system settings
core_configure_base_system() {
    local chroot_dir="$1"
    
    log_info "Configuring base system"
    
    core_mount_chroot "$chroot_dir"
    
    # Configure locales
    chroot "$chroot_dir" bash -c "
        echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
        locale-gen
        echo 'LANG=en_US.UTF-8' > /etc/default/locale
    "
    
    # Configure timezone
    chroot "$chroot_dir" bash -c "
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        echo 'UTC' > /etc/timezone
    "
    
    # Configure hostname
    echo "livecd" > "$chroot_dir/etc/hostname"
    
    # Configure hosts file
    cat > "$chroot_dir/etc/hosts" << EOF
127.0.0.1   localhost livecd
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Configure network interfaces
    cat > "$chroot_dir/etc/netplan/01-netcfg.yaml" << EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    eth0:
      dhcp4: true
EOF
    
    # Configure resolv.conf
    cat > "$chroot_dir/etc/resolv.conf" << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
    
    # Enable essential services
    chroot "$chroot_dir" systemctl enable systemd-networkd
    chroot "$chroot_dir" systemctl enable systemd-resolved
    chroot "$chroot_dir" systemctl enable NetworkManager || true
    
    core_umount_chroot "$chroot_dir"
}

#==============================================================================
# Repository Management
#==============================================================================

# Setup enhanced repositories
core_setup_enhanced_repos() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_ENHANCED_REPOS" != "true" ]]; then
        log_info "Enhanced repositories setup skipped"
        return 0
    fi
    
    log_info "Setting up enhanced repositories"
    
    core_mount_chroot "$chroot_dir"
    
    # Add universe and multiverse repositories
    chroot "$chroot_dir" add-apt-repository universe -y
    chroot "$chroot_dir" add-apt-repository multiverse -y
    
    # Add Debian Trixie repository for newer packages
    cat > "$chroot_dir/etc/apt/sources.list.d/debian-trixie.list" << EOF
# Debian Trixie for newer packages
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
EOF
    
    # Add Debian Experimental for bleeding-edge kernel development
    cat > "$chroot_dir/etc/apt/sources.list.d/debian-experimental.list" << EOF
# Debian Experimental for latest kernel & tools
deb http://deb.debian.org/debian experimental main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian experimental main contrib non-free non-free-firmware
EOF
    
    # Add kernel.org repository for mainline kernels
    cat > "$chroot_dir/etc/apt/sources.list.d/kernel-ppa.list" << EOF
# Ubuntu Mainline Kernel PPA
deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.8/ ./
deb-src https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.8/ ./
EOF
    
    # Add Proxmox repository
    wget -qO- https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg | \
        chroot "$chroot_dir" tee /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg >/dev/null
    
    cat > "$chroot_dir/etc/apt/sources.list.d/proxmox.list" << EOF
# Proxmox VE repository
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    
    # Configure APT preferences for kernel development priority
    cat > "$chroot_dir/etc/apt/preferences.d/kernel-dev-priority" << EOF
Package: linux-* *-tools-* *-headers-*
Pin: release a=experimental
Pin-Priority: 150

Package: *
Pin: release o=Debian
Pin-Priority: 500

Package: *
Pin: release o=Ubuntu
Pin-Priority: 400

Package: *
Pin: release a=experimental
Pin-Priority: 100

Package: *
Pin: release o=Proxmox
Pin-Priority: 50
EOF
    
    # Update package lists
    chroot "$chroot_dir" apt-get update || { echo "Error: Command failed"; return 1; }
    
    core_umount_chroot "$chroot_dir"
    
    log_info "Enhanced repositories configured"
}

# Install ZFS support
core_install_zfs_support() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_ZFS_SUPPORT" != "true" ]]; then
        log_info "ZFS support installation skipped"
        return 0
    fi
    
    log_info "Installing ZFS support"
    
    core_mount_chroot "$chroot_dir"
    
    # Install ZFS packages
    local zfs_packages=(
        "zfsutils-linux" "zfs-dkms" "zfs-initramfs"
        "zfs-auto-snapshot" "sanoid" "syncoid"
    )
    
    core_install_packages_parallel "$chroot_dir" "${zfs_packages[@]}"
    
    # Configure ZFS
    chroot "$chroot_dir" bash -c "
        # Enable ZFS services
        systemctl enable zfs-import-cache
        systemctl enable zfs-mount
        systemctl enable zfs-import.target
        systemctl enable zfs.target
        
        # Configure ZFS parameters
        echo 'zfs' >> /etc/modules
        echo 'options zfs zfs_arc_max=1073741824' > /etc/modprobe.d/zfs.conf
    "
    
    core_umount_chroot "$chroot_dir"
    
    log_info "ZFS support installed"
}

# Install ZFS Boot Menu Recovery System
core_install_zfs_bootmenu() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_ZFS_BOOTMENU" != "true" ]]; then
        log_info "ZFS Boot Menu installation skipped"
        return 0
    fi
    
    log_info "Installing ZFS Boot Menu recovery system"
    
    core_mount_chroot "$chroot_dir"
    
    # Install ZBM dependencies
    local zbm_packages=(
        "perl" "libconfig-yaml-perl" "libsort-versions-perl"
        "libyaml-pp-perl" "libboolean-perl" "yq" "fzf"
        "kexec-tools" "mbuffer" "efibootmgr" "dracut"
        "dracut-core" "systemd-boot" "systemd-boot-efi"
    )
    
    core_install_packages_parallel "$chroot_dir" "${zbm_packages[@]}"
    
    # Create ZBM build directory
    mkdir -p "$chroot_dir/opt/zfs-bootmenu"
    
    # Check for prebuilt ZFS Boot Menu EFI
    if [ -f "/zfsbootmenu-recovery-x86_64-v3.0.1-linux6.6.EFI" ]; then
        log_info "Using prebuilt ZFS Boot Menu v3.0.1"
        cp /zfsbootmenu-recovery-x86_64-v3.0.1-linux6.6.EFI "$chroot_dir/boot/efi/EFI/zbm/zfsbootmenu.EFI"
    else
        # Build from source for final kernel
        log_info "Building ZFS Boot Menu from source for custom kernel"
        chroot "$chroot_dir" bash -c '
            cd /opt/zfs-bootmenu
            if [ ! -d "zfsbootmenu" ]; then
                git clone https://github.com/zbm-dev/zfsbootmenu.git
            fi
            cd zfsbootmenu
            
            # Get latest stable release
            LATEST_TAG=$(git describe --tags --abbrev=0)
            echo "Building ZFS Boot Menu $LATEST_TAG"
            git checkout "$LATEST_TAG"
            
            # Build UEFI executable with custom kernel support
            make generate-zbm KERNEL_VERSION="$(uname -r)"
        ' 2>/dev/null || log_warn "ZBM build failed - will use prebuilt"
    fi
    
    # Create ZBM configuration
    mkdir -p "$chroot_dir/etc/zfsbootmenu"
    cat > "$chroot_dir/etc/zfsbootmenu/config.yaml" << 'EOF'
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
  DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  PreHooksDir: /etc/zfsbootmenu/hooks.d
  PostHooksDir: /etc/zfsbootmenu/hooks.d
  
Components:
  Enabled: true
  ImageDir: /boot/efi/EFI/zbm
  Versions: 3
  Kernel: /boot/vmlinuz
  CommandLine: "ro quiet loglevel=0 zbm.show"
  
EFI:
  Enabled: true
  ImageDir: /boot/efi/EFI/zbm
  Versions: false
  Stub: /usr/lib/systemd/boot/efi/linuxx64.efi.stub
  
Kernel:
  Prefix: vmlinuz
  CommandLine: "ro quiet loglevel=0"
  
Initramfs:
  Prefix: initramfs
  Suffix: .img
EOF
    
    # Create recovery hooks
    mkdir -p "$chroot_dir/etc/zfsbootmenu/hooks.d"
    cat > "$chroot_dir/etc/zfsbootmenu/hooks.d/recovery.sh" << 'EOF'
#!/bin/bash
# ZFS Boot Menu Recovery Hooks

# Enable emergency shell
zfsbootmenu_emergency_shell() {
    echo "Entering ZFS recovery shell..."
    echo "Available commands:"
    echo "  zpool import -a     # Import all pools"
    echo "  zfs list           # List datasets"
    echo "  zfs rollback       # Rollback snapshot"
    echo "  reboot             # Restart system"
    /bin/bash
}

# Auto-import pools
zfsbootmenu_import_pools() {
    zpool import -a -N 2>/dev/null || true
}

# Mount recovery dataset
zfsbootmenu_mount_recovery() {
    if zfs list rpool/recovery >/dev/null 2>&1; then
        mount -t zfs rpool/recovery /mnt/recovery
    fi
}
EOF
    
    chmod +x "$chroot_dir/etc/zfsbootmenu/hooks.d/recovery.sh"
    
    # Create EFI boot entry
    mkdir -p "$chroot_dir/boot/efi/EFI/zbm"
    
    # Create EFI boot entry for ZFS Boot Menu
    chroot "$chroot_dir" bash -c '
        if [ -f /boot/efi/EFI/zbm/zfsbootmenu.EFI ]; then
            efibootmgr -c -d /dev/sda -p 1 -L "ZFS Boot Menu Recovery" -l "\\EFI\\zbm\\zfsbootmenu.EFI" 2>/dev/null || true
            echo "ZFS Boot Menu EFI entry created"
        fi
        
        # For final build, generate full ZBM with kernel
        if command -v generate-zbm >/dev/null; then
            generate-zbm --kernel /boot/vmlinuz --initramfs /boot/initrd.img
        fi
    ' 2>/dev/null || true
    
    # Create fallback script for manual EFI installation
    cat > "$chroot_dir/usr/local/bin/install-zbm-efi" << 'EOF'
#!/bin/bash
# Install ZFS Boot Menu EFI manually

EFI_SOURCE="/zfsbootmenu-recovery-x86_64-v3.0.1-linux6.6.EFI"
EFI_DEST="/boot/efi/EFI/zbm/zfsbootmenu.EFI"

if [ ! -f "$EFI_SOURCE" ]; then
    echo "Error: ZBM EFI not found at $EFI_SOURCE"
    exit 1
fi

echo "Installing ZFS Boot Menu EFI..."
mkdir -p "$(dirname "$EFI_DEST")"
cp "$EFI_SOURCE" "$EFI_DEST"

# Create boot entry
efibootmgr -c -d /dev/sda -p 1 -L "ZFS Boot Menu Recovery" -l "\\EFI\\zbm\\zfsbootmenu.EFI"

echo "ZFS Boot Menu EFI installed to $EFI_DEST"
echo "Boot entry created"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/install-zbm-efi"
    
    core_umount_chroot "$chroot_dir"
    
    log_info "ZFS Boot Menu recovery system installed"
}

#==============================================================================
# Kernel Build Environment
#==============================================================================

# Install kernel build environment
core_install_kernel_build() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_KERNEL_BUILD" != "true" ]]; then
        log_info "Kernel build environment installation skipped"
        return 0
    fi
    
    log_info "Installing kernel build environment"
    
    core_mount_chroot "$chroot_dir"
    
    # Install comprehensive kernel build & ring-level access tools
    local kernel_build_packages=(
        "build-essential" "libncurses-dev" "bison" "flex"
        "libssl-dev" "libelf-dev" "bc" "rsync"
        "kmod" "cpio" "xz-utils" "lz4" "zstd"
        "dwarves" "pahole" "gcc" "g++" "gcc-multilib" "g++-multilib"
        "kernel-package" "fakeroot" "dpkg-dev" "devscripts"
        "git" "wget" "curl" "axel" "aria2"
        "linux-source" "linux-headers-generic" "linux-tools-common"
        # Advanced kernel debugging & profiling
        "systemtap" "systemtap-sdt-dev" "kdump-tools"
        "crash" "makedumpfile" "kexec-tools"
        "linux-perf" "perf-tools-unstable" "bpftrace" "bcc-tools"
        # Ring-level and hardware access
        "msr-tools" "cpuid" "x86info" "cpufrequtils"
        "dmidecode" "lshw" "hwinfo" "inxi"
        "intel-microcode" "amd64-microcode" "iucode-tool"
        # Virtualization for kernel testing
        "qemu-system-x86" "qemu-kvm" "libvirt-daemon-system"
        "virt-manager" "ovmf" "swtpm" "swtpm-tools"
        # Security and forensics
        "apparmor-utils" "selinux-utils" "aide" "tripwire"
        "volatility3" "sleuthkit" "autopsy" "foremost"
    )
    
    core_install_packages_parallel "$chroot_dir" "${kernel_build_packages[@]}"
    
    # Create kernel build directories
    chroot "$chroot_dir" bash -c "
        mkdir -p /usr/src/kernels
        mkdir -p /boot/kernels
        mkdir -p /lib/modules
    "
    
    # Create kernel build helper scripts
    core_create_kernel_build_scripts "$chroot_dir"
    
    core_umount_chroot "$chroot_dir"
    
    log_info "Kernel build environment installed"
}

# Create kernel build helper scripts
core_create_kernel_build_scripts() {
    local chroot_dir="$1"
    
    # Quick kernel download script
    cat > "$chroot_dir/usr/local/bin/download-kernel" << 'EOF'
#!/bin/bash
# Download kernel source

KERNEL_VERSION="${1:-$(uname -r | cut -d- -f1)}"
DEST_DIR="${2:-/usr/src}"

echo "Downloading kernel $KERNEL_VERSION to $DEST_DIR"

cd "$DEST_DIR" || { echo "Error: Command failed"; return 1; }

# Download from kernel.org
wget -q "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz"

# Extract
tar -xf "linux-${KERNEL_VERSION}.tar.xz"
ln -sf "linux-${KERNEL_VERSION}" linux

echo "Kernel source downloaded and extracted"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/download-kernel"
    
    # Kernel config helper
    cat > "$chroot_dir/usr/local/bin/kernel-quickconfig" << 'EOF'
#!/bin/bash
# Quick kernel configuration

KERNEL_DIR="${1:-/usr/src/linux}"

if [[ ! -d "$KERNEL_DIR" ]]; then
    echo "Kernel source not found: $KERNEL_DIR"
    exit 1
fi

cd "$KERNEL_DIR" || { echo "Error: Command failed"; return 1; }

# Use current config as base
if [[ -f "/boot/config-$(uname -r)" ]]; then
    cp "/boot/config-$(uname -r)" .config
    make olddefconfig
else
    make defconfig
fi

# Enable common LiveCD features
scripts/config --enable CONFIG_SQUASHFS
scripts/config --enable CONFIG_OVERLAY_FS
scripts/config --enable CONFIG_ISO9660_FS
scripts/config --enable CONFIG_UDF_FS
scripts/config --enable CONFIG_VFAT_FS
scripts/config --enable CONFIG_NTFS_FS

echo "Kernel configured for LiveCD"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/kernel-quickconfig"
}

#==============================================================================
# Package Management
#==============================================================================

# Install packages in parallel batches
core_install_packages_parallel() {
    local chroot_dir="$1"
    shift
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing ${#packages[@]} packages in parallel"
    
    # Update package cache
    chroot "$chroot_dir" apt-get update >/dev/null 2>&1
    
    local batch_size=5
    local package_batch=()
    local pids=()
    
    for package in "${packages[@]}"; do
        package_batch+=("$package")
        
        if [[ ${#package_batch[@]} -eq $batch_size ]]; then
            # Install batch in background
            (
                chroot "$chroot_dir" apt-get install -y "${package_batch[@]}" >/dev/null 2>&1
            ) &
            pids+=($!)
            package_batch=()
            
            # Limit concurrent jobs
            while [[ ${#pids[@]} -ge 3 ]]; do
                # Wait for any job to complete
                wait "${pids[0]}"
                pids=("${pids[@]:1}")
                sleep 1
            done
        fi
    done
    
    # Install remaining packages
    if [[ ${#package_batch[@]} -gt 0 ]]; then
        chroot "$chroot_dir" apt-get install -y "${package_batch[@]}" >/dev/null 2>&1
    fi
    
    # Wait for all background jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    log_info "Package installation completed"
}

# Clean package cache and temporary files
core_cleanup_system() {
    local chroot_dir="$1"
    
    log_info "Cleaning up system"
    
    core_mount_chroot "$chroot_dir"
    
    chroot "$chroot_dir" bash -c "
        # Clean package cache
        apt-get autoremove -y
        apt-get autoclean
        apt-get clean
        
        # Clean temporary files
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        
        # Clean logs
        find /var/log -type f -name '*.log' -delete
        find /var/log -type f -name '*.gz' -delete
        
        # Clean man pages and docs (optional for LiveCD)
        rm -rf /usr/share/man/*
        rm -rf /usr/share/doc/*
        
        # Clean locales except en_US
        find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en_US' -type d -exec rm -rf {} +
    "
    
    core_umount_chroot "$chroot_dir"
    
    log_info "System cleanup completed"
}

#==============================================================================
# Chroot Management
#==============================================================================

# Mount essential filesystems for chroot
core_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /dev/pts "$chroot_dir/dev/pts" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
    mount --bind /run "$chroot_dir/run" 2>/dev/null || true
    
    # Mount resolv.conf for network access
    mount --bind /etc/resolv.conf "$chroot_dir/etc/resolv.conf" 2>/dev/null || true
}

# Unmount chroot filesystems
core_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/etc/resolv.conf" 2>/dev/null || true
    umount "$chroot_dir/run" 2>/dev/null || true
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev/pts" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

#==============================================================================
# User and Service Configuration
#==============================================================================

# Configure users and services
core_configure_users_services() {
    local chroot_dir="$1"
    
    log_info "Configuring users and services"
    
    core_mount_chroot "$chroot_dir"
    
    # Create live user
    chroot "$chroot_dir" bash -c "
        # Create liveuser
        useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev liveuser
        echo 'liveuser:live' | chpasswd
        echo 'liveuser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/liveuser
        
        # Set root password
        echo 'root:root' | chpasswd
        
        # Configure auto-login for console
        mkdir -p /etc/systemd/system/getty@tty1.service.d
        cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin liveuser --noclear %I \$TERM
EOF
    "
    
    # Enable essential services
    chroot "$chroot_dir" systemctl enable systemd-networkd || true
    chroot "$chroot_dir" systemctl enable systemd-resolved || true
    chroot "$chroot_dir" systemctl enable ssh || true
    
    core_umount_chroot "$chroot_dir"
    
    log_info "Users and services configured"
}

#==============================================================================
# Public API Functions
#==============================================================================

# Main entry point for core system
core_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "base")
            core_create_base_system "$chroot_dir"
            ;;
        "repos")
            core_setup_enhanced_repos "$chroot_dir"
            ;;
        "zfs")
            core_install_zfs_support "$chroot_dir"
            core_install_zfs_bootmenu "$chroot_dir"
            ;;
        "kernel")
            core_install_kernel_build "$chroot_dir"
            ;;
        "users")
            core_configure_users_services "$chroot_dir"
            ;;
        "cleanup")
            core_cleanup_system "$chroot_dir"
            ;;
        "all")
            log_info "Building complete core system"
            core_create_base_system "$chroot_dir"
            core_setup_enhanced_repos "$chroot_dir"
            core_install_zfs_support "$chroot_dir"
            core_install_zfs_bootmenu "$chroot_dir"
            core_install_kernel_build "$chroot_dir"
            core_configure_users_services "$chroot_dir"
            log_info "Core system build completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {base|repos|zfs|kernel|users|cleanup|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    core_main "$@"
fi