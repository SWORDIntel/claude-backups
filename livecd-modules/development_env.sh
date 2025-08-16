#!/bin/bash
#
# development_env.sh - LiveCD Development Environment Module
# Part of the consolidated LiveCD build system
#
# Consolidates kernel building, ZFS support, development tools,
# compilers, and build environments with performance optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly DEV_MODULE_VERSION="1.0.0"
readonly DEV_MODULE_NAME="Development Environment Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${KERNEL_VERSION:=6.8.0}"
: "${ZFS_VERSION:=2.2.2}"
: "${BUILD_KERNEL:=false}"
: "${BUILD_ZFS:=true}"
: "${INSTALL_LANGUAGES:=true}"
: "${INSTALL_CONTAINERS:=true}"
: "${PARALLEL_JOBS:=$(nproc)}"

#==============================================================================
# Kernel Building Environment
#==============================================================================

# Setup kernel building environment
dev_setup_kernel_build() {
    local chroot_dir="$1"
    
    log_info "Setting up kernel build environment"
    
    # Install kernel build dependencies
    local kernel_deps=(
        "build-essential" "libncurses-dev" "bison" "flex"
        "libssl-dev" "libelf-dev" "bc" "rsync"
        "kmod" "cpio" "xz-utils" "lz4"
        "dwarves" "pahole" "gcc-12" "g++-12"
        "kernel-package" "fakeroot" "dpkg-dev"
        "libpci-dev" "libiberty-dev" "autoconf"
        "libudev-dev" "libcap-dev" "pkg-config"
        # Binary Communication System dependencies
        "liburing-dev" "libnuma-dev" "libcrypto-dev"
        # Optional acceleration libraries
        "libopencl-dev" "ocl-icd-opencl-dev"
    )
    
    dev_mount_chroot "$chroot_dir"
    dev_install_packages_parallel "$chroot_dir" "${kernel_deps[@]}"
    
    # Download kernel source if requested
    if [[ "$BUILD_KERNEL" == "true" ]]; then
        dev_download_kernel_source "$chroot_dir"
        dev_configure_kernel "$chroot_dir"
    fi
    
    # Create kernel build scripts
    dev_create_kernel_scripts "$chroot_dir"
    
    dev_umount_chroot "$chroot_dir"
    
    log_info "Kernel build environment ready"
}

# Download and prepare kernel source
dev_download_kernel_source() {
    local chroot_dir="$1"
    local kernel_ver="${2:-$KERNEL_VERSION}"
    
    log_info "Downloading kernel source v$kernel_ver"
    
    chroot "$chroot_dir" bash -c "
        cd /usr/src
        
        # Download kernel source
        if [[ ! -f linux-${kernel_ver}.tar.xz ]]; then
            wget -q https://cdn.kernel.org/pub/linux/kernel/v${kernel_ver%%.*}.x/linux-${kernel_ver}.tar.xz || {
                # Try mainline if stable fails
                wget -q https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-${kernel_ver}.tar.gz
            }
        fi
        
        # Extract source
        tar -xf linux-${kernel_ver}.tar.* 2>/dev/null || tar -xf linux-${kernel_ver}.tar.*
        ln -sf linux-${kernel_ver} linux
        
        cd linux
        
        # Clean any previous builds
        make mrproper
    "
}

# Configure kernel with optimizations
dev_configure_kernel() {
    local chroot_dir="$1"
    
    log_info "Configuring kernel with optimizations"
    
    chroot "$chroot_dir" bash -c "
        cd /usr/src/linux
        
        # Use current running kernel config as base
        if [[ -f /boot/config-$(uname -r) ]]; then
            cp /boot/config-$(uname -r) .config
        else
            # Generate default config
            make defconfig
        fi
        
        # Enable performance optimizations
        ./scripts/config --enable CONFIG_PREEMPT_VOLUNTARY
        ./scripts/config --enable CONFIG_TRANSPARENT_HUGEPAGE
        ./scripts/config --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
        ./scripts/config --enable CONFIG_ZRAM
        ./scripts/config --enable CONFIG_ZSWAP
        ./scripts/config --enable CONFIG_ZCACHE
        
        # Enable debugging features for development
        ./scripts/config --enable CONFIG_DEBUG_INFO
        ./scripts/config --enable CONFIG_DEBUG_INFO_DWARF5
        ./scripts/config --enable CONFIG_FTRACE
        ./scripts/config --enable CONFIG_KPROBES
        ./scripts/config --enable CONFIG_FRAME_POINTER
        
        # Update config for new kernel version
        make olddefconfig
    "
}

# Create kernel build helper scripts
dev_create_kernel_scripts() {
    local chroot_dir="$1"
    
    # Quick kernel build script
    cat > "$chroot_dir/usr/local/bin/build-kernel" << 'EOF'
#!/bin/bash
# Quick Kernel Build Script

KERNEL_SRC="${1:-/usr/src/linux}"
PARALLEL="${2:-$(nproc)}"

if [[ ! -d "$KERNEL_SRC" ]]; then
    echo "Kernel source not found: $KERNEL_SRC"
    exit 1
fi

cd "$KERNEL_SRC"

echo "Building kernel with $PARALLEL jobs..."
time make -j"$PARALLEL" bindeb-pkg LOCALVERSION=-custom

echo "Kernel packages built in /usr/src/"
ls -la /usr/src/*.deb
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/build-kernel"
    
    # Kernel configuration helper
    cat > "$chroot_dir/usr/local/bin/kernel-config" << 'EOF'
#!/bin/bash
# Kernel Configuration Helper

ACTION="${1:-menuconfig}"
KERNEL_SRC="${2:-/usr/src/linux}"

cd "$KERNEL_SRC"

case "$ACTION" in
    menuconfig)
        make menuconfig
        ;;
    xconfig)
        make xconfig
        ;;
    gconfig)
        make gconfig
        ;;
    oldconfig)
        make oldconfig
        ;;
    localmodconfig)
        make localmodconfig
        ;;
    *)
        echo "Usage: $0 {menuconfig|xconfig|gconfig|oldconfig|localmodconfig}"
        exit 1
        ;;
esac

echo "Configuration saved to .config"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/kernel-config"
}

#==============================================================================
# ZFS Development Support
#==============================================================================

# Setup ZFS development environment
dev_setup_zfs() {
    local chroot_dir="$1"
    
    log_info "Setting up ZFS development environment"
    
    # ZFS build dependencies
    local zfs_deps=(
        "build-essential" "autoconf" "automake" "libtool"
        "gawk" "alien" "fakeroot" "dkms"
        "libblkid-dev" "uuid-dev" "libudev-dev"
        "libssl-dev" "zlib1g-dev" "libaio-dev"
        "libattr1-dev" "libelf-dev" "python3"
        "python3-dev" "python3-setuptools"
        "python3-cffi" "libffi-dev" "python3-packaging"
        "libcurl4-openssl-dev" "debhelper" "dh-python"
        "po-debconf" "python3-all-dev" "python3-sphinx"
    )
    
    dev_mount_chroot "$chroot_dir"
    dev_install_packages_parallel "$chroot_dir" "${zfs_deps[@]}"
    
    if [[ "$BUILD_ZFS" == "true" ]]; then
        dev_build_zfs "$chroot_dir"
    fi
    
    # Create ZFS helper scripts
    dev_create_zfs_scripts "$chroot_dir"
    
    dev_umount_chroot "$chroot_dir"
    
    log_info "ZFS development environment ready"
}

# Build ZFS from source
dev_build_zfs() {
    local chroot_dir="$1"
    local zfs_ver="${2:-$ZFS_VERSION}"
    
    log_info "Building ZFS v$zfs_ver from source"
    
    chroot "$chroot_dir" bash -c "
        cd /usr/src
        
        # Download ZFS source
        if [[ ! -f zfs-${zfs_ver}.tar.gz ]]; then
            wget -q https://github.com/openzfs/zfs/releases/download/zfs-${zfs_ver}/zfs-${zfs_ver}.tar.gz
        fi
        
        # Extract and build
        tar -xzf zfs-${zfs_ver}.tar.gz
        cd zfs-${zfs_ver}
        
        # Configure with optimizations
        ./configure \
            --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --with-config=user \
            --enable-systemd \
            --enable-pyzfs \
            --with-python=python3 \
            CFLAGS='-O2 -march=native' \
            CXXFLAGS='-O2 -march=native'
        
        # Parallel build
        make -j$PARALLEL_JOBS
        make install
        
        # Build kernel modules with DKMS
        make deb-utils deb-dkms
        
        # Install packages
        dpkg -i *.deb || apt-get -f install -y
    " 2>/dev/null || log_warn "ZFS build completed with warnings"
}

# Create ZFS helper scripts
dev_create_zfs_scripts() {
    local chroot_dir="$1"
    
    # ZFS pool creation helper
    cat > "$chroot_dir/usr/local/bin/create-zfs-pool" << 'EOF'
#!/bin/bash
# ZFS Pool Creation Helper

POOL_NAME="${1:-tank}"
DEVICES="${2:-}"

if [[ -z "$DEVICES" ]]; then
    echo "Usage: $0 <pool_name> <device1> [device2] ..."
    echo "Example: $0 tank /dev/sdb /dev/sdc"
    exit 1
fi

echo "Creating ZFS pool: $POOL_NAME"
echo "Devices: $DEVICES"

# Load ZFS module
modprobe zfs

# Create pool with optimizations
zpool create \
    -o ashift=12 \
    -o autoexpand=on \
    -o autoreplace=on \
    -O atime=off \
    -O compression=lz4 \
    -O normalization=formD \
    -O xattr=sa \
    -O dnodesize=auto \
    -O recordsize=1M \
    -O mountpoint=/mnt/$POOL_NAME \
    "$POOL_NAME" $DEVICES

# Show pool status
zpool status "$POOL_NAME"
zfs list "$POOL_NAME"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/create-zfs-pool"
    
    # ZFS dataset management
    cat > "$chroot_dir/usr/local/bin/zfs-dataset" << 'EOF'
#!/bin/bash
# ZFS Dataset Management

ACTION="$1"
DATASET="$2"

case "$ACTION" in
    create)
        zfs create -o compression=lz4 -o atime=off "$DATASET"
        ;;
    snapshot)
        SNAP_NAME="${3:-$(date +%Y%m%d-%H%M%S)}"
        zfs snapshot "${DATASET}@${SNAP_NAME}"
        ;;
    clone)
        SOURCE_SNAP="$3"
        zfs clone "$SOURCE_SNAP" "$DATASET"
        ;;
    send)
        TARGET="$3"
        zfs send -R "$DATASET" | zfs receive -F "$TARGET"
        ;;
    *)
        echo "Usage: $0 {create|snapshot|clone|send} <dataset> [options]"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/zfs-dataset"
}

#==============================================================================
# Programming Languages and Tools
#==============================================================================

# Install programming languages and development tools
dev_install_languages() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_LANGUAGES" != "true" ]]; then
        log_info "Language installation skipped"
        return 0
    fi
    
    log_info "Installing programming languages and tools"
    
    dev_mount_chroot "$chroot_dir"
    
    # Install languages in parallel
    {
        dev_install_python "$chroot_dir"
    } &
    
    {
        dev_install_nodejs "$chroot_dir"
    } &
    
    {
        dev_install_golang "$chroot_dir"
    } &
    
    {
        dev_install_rust "$chroot_dir"
    } &
    
    wait
    
    # Install common development tools
    local dev_tools=(
        "git" "git-lfs" "gitk" "git-gui"
        "vim" "emacs" "nano"
        "tmux" "screen" "htop"
        "strace" "ltrace" "gdb"
        "valgrind" "perf-tools-unstable"
        "cmake" "ninja-build" "meson"
        "clang" "clang-tools" "clang-format"
        "bear" "ccache" "distcc"
    )
    
    dev_install_packages_parallel "$chroot_dir" "${dev_tools[@]}"
    
    dev_umount_chroot "$chroot_dir"
    
    log_info "Development languages and tools installed"
}

# Install Python development environment
dev_install_python() {
    local chroot_dir="$1"
    
    log_info "Installing Python environment"
    
    local python_packages=(
        "python3" "python3-dev" "python3-pip"
        "python3-venv" "python3-wheel"
        "python3-setuptools" "python3-distutils"
        "ipython3" "jupyter" "python3-notebook"
        "python3-numpy" "python3-scipy"
        "python3-pandas" "python3-matplotlib"
        "python3-sklearn" "python3-torch"
        "pylint" "black" "flake8" "mypy"
    )
    
    chroot "$chroot_dir" apt-get install -y "${python_packages[@]}" 2>/dev/null || {
        # Install essential packages only if full set fails
        chroot "$chroot_dir" apt-get install -y \
            python3 python3-dev python3-pip python3-venv
    }
    
    # Setup pip packages
    chroot "$chroot_dir" pip3 install --upgrade pip setuptools wheel
    chroot "$chroot_dir" pip3 install \
        virtualenv pipenv poetry \
        requests flask django fastapi \
        pytest pytest-cov tox \
        2>/dev/null || true
}

# Install Node.js environment
dev_install_nodejs() {
    local chroot_dir="$1"
    
    log_info "Installing Node.js environment"
    
    # Install Node.js via NodeSource repository
    chroot "$chroot_dir" bash -c "
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y nodejs
        
        # Install global npm packages
        npm install -g \
            npm@latest \
            yarn \
            pnpm \
            typescript \
            ts-node \
            nodemon \
            pm2 \
            webpack \
            vite \
            @angular/cli \
            @vue/cli \
            create-react-app \
            2>/dev/null || true
    " 2>/dev/null || {
        # Fallback to distribution Node.js
        chroot "$chroot_dir" apt-get install -y nodejs npm
    }
}

# Install Go environment
dev_install_golang() {
    local chroot_dir="$1"
    
    log_info "Installing Go environment"
    
    local go_version="1.21.5"
    
    chroot "$chroot_dir" bash -c "
        cd /tmp
        wget -q https://go.dev/dl/go${go_version}.linux-amd64.tar.gz
        tar -C /usr/local -xzf go${go_version}.linux-amd64.tar.gz
        
        # Setup Go environment
        echo 'export PATH=/usr/local/go/bin:\$PATH' >> /etc/profile.d/go.sh
        echo 'export GOPATH=/home/liveuser/go' >> /etc/profile.d/go.sh
        echo 'export PATH=\$GOPATH/bin:\$PATH' >> /etc/profile.d/go.sh
        
        # Install common Go tools
        export PATH=/usr/local/go/bin:\$PATH
        go install golang.org/x/tools/gopls@latest
        go install github.com/go-delve/delve/cmd/dlv@latest
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    " 2>/dev/null || log_warn "Go installation completed with warnings"
}

# Install Rust environment
dev_install_rust() {
    local chroot_dir="$1"
    
    log_info "Installing Rust environment"
    
    chroot "$chroot_dir" bash -c "
        # Install Rust via rustup
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
            sh -s -- -y --default-toolchain stable
        
        # Source cargo environment
        source /root/.cargo/env
        
        # Install common Rust tools
        cargo install \
            cargo-edit \
            cargo-watch \
            cargo-audit \
            cargo-outdated \
            cargo-tree \
            2>/dev/null || true
        
        # Add rust-analyzer
        rustup component add rust-analyzer
        rustup component add rustfmt
        rustup component add clippy
    " 2>/dev/null || log_warn "Rust installation completed with warnings"
}

#==============================================================================
# Binary Communication System Setup
#==============================================================================

# Install binary communication system dependencies and tools
dev_setup_binary_comms() {
    local chroot_dir="$1"
    
    log_info "Setting up Binary Communication System dependencies"
    
    # Core binary communication system libraries
    local binary_deps=(
        # High-performance I/O
        "liburing-dev"           # io_uring async I/O
        "libnuma-dev"           # NUMA memory allocation
        
        # Cryptographic libraries (already in kernel_deps)
        "libssl-dev"            # OpenSSL for encryption
        "libcrypto-dev"         # Cryptographic primitives
        
        # Development tools
        "pkg-config"            # Library configuration
        "build-essential"       # Core build tools
        
        # Optional acceleration libraries
        "libopencl-dev"         # OpenCL for GPU acceleration
        "ocl-icd-opencl-dev"    # OpenCL ICD loader
        
        # Intel specific libraries (best effort install)
        "intel-opencl-icd"      # Intel OpenCL driver (if available)
    )
    
    dev_mount_chroot "$chroot_dir"
    
    # Install core dependencies first
    log_info "Installing core binary communication dependencies"
    for dep in "${binary_deps[@]:0:6}"; do
        chroot "$chroot_dir" apt-get install -y "$dep" 2>/dev/null || {
            log_warn "Failed to install $dep (may be optional)"
        }
    done
    
    # Install optional acceleration libraries (best effort)
    log_info "Installing optional acceleration libraries"
    for dep in "${binary_deps[@]:6}"; do
        chroot "$chroot_dir" apt-get install -y "$dep" 2>/dev/null || {
            log_info "Optional library $dep not available (skipping)"
        }
    done
    
    # Verify installation
    chroot "$chroot_dir" bash -c "
        echo 'Verifying binary communication system dependencies:'
        
        # Check for pkg-config libraries
        for lib in liburing openssl; do
            if pkg-config --exists \$lib 2>/dev/null; then
                echo '  ✓ \$lib: available'
                pkg-config --modversion \$lib 2>/dev/null | sed 's/^/    version: /'
            else
                echo '  ⚠ \$lib: not found via pkg-config'
            fi
        done
        
        # Check for header files
        echo
        echo 'Checking development headers:'
        for header in linux/io_uring.h numa.h openssl/ssl.h; do
            if find /usr/include -name \"\$(basename \$header)\" 2>/dev/null | grep -q .; then
                echo \"  ✓ \$header: available\"
            else
                echo \"  ⚠ \$header: not found\"
            fi
        done
        
        # Check for compiler with AVX2 support
        echo
        echo 'Checking compiler capabilities:'
        if gcc -march=native -Q --help=target 2>/dev/null | grep -q avx2; then
            echo '  ✓ AVX2 support: available'
        else
            echo '  ⚠ AVX2 support: not detected'
        fi
        
        echo
        echo 'Binary Communication System dependencies setup complete!'
    " 2>/dev/null || log_warn "Verification completed with warnings"
    
    dev_umount_chroot "$chroot_dir"
    
    log_info "Binary Communication System dependencies installed"
}

#==============================================================================
# Container and Virtualization Support
#==============================================================================

# Setup container development environment
dev_setup_containers() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_CONTAINERS" != "true" ]]; then
        log_info "Container setup skipped"
        return 0
    fi
    
    log_info "Setting up container environment"
    
    dev_mount_chroot "$chroot_dir"
    
    # Install Docker
    dev_install_docker "$chroot_dir"
    
    # Install Podman
    dev_install_podman "$chroot_dir"
    
    # Install Kubernetes tools
    dev_install_kubernetes "$chroot_dir"
    
    dev_umount_chroot "$chroot_dir"
    
    log_info "Container environment ready"
}

# Install Docker
dev_install_docker() {
    local chroot_dir="$1"
    
    log_info "Installing Docker"
    
    chroot "$chroot_dir" bash -c "
        # Install Docker dependencies
        apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker repository
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
            https://download.docker.com/linux/ubuntu jammy stable' > \
            /etc/apt/sources.list.d/docker.list
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Enable Docker service
        systemctl enable docker
        
        # Add liveuser to docker group
        usermod -aG docker liveuser 2>/dev/null || true
    " 2>/dev/null || log_warn "Docker installation completed with warnings"
}

# Install Podman
dev_install_podman() {
    local chroot_dir="$1"
    
    log_info "Installing Podman"
    
    chroot "$chroot_dir" apt-get install -y \
        podman \
        buildah \
        skopeo \
        containernetworking-plugins \
        2>/dev/null || log_warn "Podman not available"
}

# Install Kubernetes tools
dev_install_kubernetes() {
    local chroot_dir="$1"
    
    log_info "Installing Kubernetes tools"
    
    chroot "$chroot_dir" bash -c "
        # Install kubectl
        curl -LO https://dl.k8s.io/release/stable.txt
        KUBE_VERSION=\$(cat stable.txt)
        curl -LO https://dl.k8s.io/release/\${KUBE_VERSION}/bin/linux/amd64/kubectl
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        
        # Install minikube
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        install minikube-linux-amd64 /usr/local/bin/minikube
        
        # Install helm
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        
        # Install k9s
        wget -q https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
        tar -xzf k9s_Linux_amd64.tar.gz
        mv k9s /usr/local/bin/
        
        rm -f stable.txt kubectl minikube-linux-amd64 k9s_Linux_amd64.tar.gz
    " 2>/dev/null || log_warn "Some Kubernetes tools installation failed"
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems
dev_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
}

# Unmount chroot filesystems
dev_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

# Install packages in parallel
dev_install_packages_parallel() {
    local chroot_dir="$1"
    shift
    local packages=("$@")
    
    chroot "$chroot_dir" apt-get update
    
    local batch_size=6
    local package_batch=()
    
    for package in "${packages[@]}"; do
        package_batch+=("$package")
        
        if [[ ${#package_batch[@]} -eq $batch_size ]]; then
            chroot "$chroot_dir" apt-get install -y "${package_batch[@]}" &
            package_batch=()
            
            while [[ $(jobs -r | wc -l) -ge 3 ]]; do
                sleep 1
            done
        fi
    done
    
    if [[ ${#package_batch[@]} -gt 0 ]]; then
        chroot "$chroot_dir" apt-get install -y "${package_batch[@]}"
    fi
    
    wait
}

#==============================================================================
# Public API Functions
#==============================================================================

# Main entry point for development environment
dev_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "kernel")
            dev_setup_kernel_build "$chroot_dir"
            ;;
        "zfs")
            dev_setup_zfs "$chroot_dir"
            ;;
        "languages")
            dev_install_languages "$chroot_dir"
            ;;
        "containers")
            dev_setup_containers "$chroot_dir"
            ;;
        "binary-comms")
            dev_setup_binary_comms "$chroot_dir"
            ;;
        "all")
            log_info "Setting up complete development environment"
            dev_setup_kernel_build "$chroot_dir"
            dev_setup_zfs "$chroot_dir"
            dev_install_languages "$chroot_dir"
            dev_setup_binary_comms "$chroot_dir"
            dev_setup_containers "$chroot_dir"
            log_info "Development environment setup completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {kernel|zfs|languages|containers|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    dev_main "$@"
fi