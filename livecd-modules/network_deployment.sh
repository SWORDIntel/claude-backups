#!/bin/bash
#
# network_deployment.sh - LiveCD Network & Mass Deployment Module
# Part of the consolidated LiveCD build system
#
# Consolidates PXE boot, network deployment, mass provisioning,
# and remote management capabilities with performance optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly NETWORK_MODULE_VERSION="1.0.0"
readonly NETWORK_MODULE_NAME="Network Deployment Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${PXE_SERVER_IP:=192.168.1.1}"
: "${DHCP_RANGE_START:=192.168.1.100}"
: "${DHCP_RANGE_END:=192.168.1.200}"
: "${TFTP_ROOT:=/srv/tftp}"
: "${HTTP_ROOT:=/srv/http}"
: "${NFS_ROOT:=/srv/nfs}"
: "${DEPLOYMENT_METHOD:=ipxe}"  # pxe, ipxe, http, nfs

#==============================================================================
# PXE Boot Server Setup
#==============================================================================

# Configure PXE boot server
network_setup_pxe_server() {
    local chroot_dir="$1"
    
    log_info "Setting up PXE boot server"
    
    # Install PXE server packages
    local pxe_packages=(
        "dnsmasq" "tftpd-hpa" "syslinux"
        "pxelinux" "syslinux-efi"
        "apache2" "nginx-light"
        "nfs-kernel-server" "isc-dhcp-server"
    )
    
    network_mount_chroot "$chroot_dir"
    network_install_packages_parallel "$chroot_dir" "${pxe_packages[@]}"
    
    # Configure TFTP server
    network_configure_tftp "$chroot_dir"
    
    # Configure DHCP/DNS with dnsmasq
    network_configure_dnsmasq "$chroot_dir"
    
    # Setup PXE boot files
    network_setup_pxe_files "$chroot_dir"
    
    network_umount_chroot "$chroot_dir"
    
    log_info "PXE boot server configured"
}

# Configure TFTP server
network_configure_tftp() {
    local chroot_dir="$1"
    
    log_info "Configuring TFTP server"
    
    # Create TFTP root directory
    mkdir -p "$chroot_dir$TFTP_ROOT"
    
    # Configure tftpd-hpa
    cat > "$chroot_dir/etc/default/tftpd-hpa" << EOF
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$TFTP_ROOT"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --create --listen --verbose"
EOF
    
    # Copy PXE boot files
    cp "$chroot_dir/usr/lib/PXELINUX/pxelinux.0" "$chroot_dir$TFTP_ROOT/" 2>/dev/null || true
    cp "$chroot_dir/usr/lib/syslinux/modules/bios/"*.c32 "$chroot_dir$TFTP_ROOT/" 2>/dev/null || true
    
    chroot "$chroot_dir" systemctl enable tftpd-hpa
}

# Configure dnsmasq for DHCP and DNS
network_configure_dnsmasq() {
    local chroot_dir="$1"
    
    log_info "Configuring dnsmasq for DHCP/DNS"
    
    cat > "$chroot_dir/etc/dnsmasq.d/pxe.conf" << EOF
# PXE Boot Configuration
interface=eth0
bind-interfaces

# DHCP range
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,12h

# PXE boot options
dhcp-boot=pxelinux.0,$PXE_SERVER_IP

# UEFI boot options
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,bootx64.efi

# Enable TFTP
enable-tftp
tftp-root=$TFTP_ROOT

# DNS settings
server=8.8.8.8
server=8.8.4.4
cache-size=1000

# Logging
log-queries
log-dhcp
EOF
    
    chroot "$chroot_dir" systemctl enable dnsmasq
}

# Setup PXE boot files and menu
network_setup_pxe_files() {
    local chroot_dir="$1"
    
    log_info "Setting up PXE boot files"
    
    # Create PXE configuration directory
    mkdir -p "$chroot_dir$TFTP_ROOT/pxelinux.cfg"
    
    # Create default PXE menu
    cat > "$chroot_dir$TFTP_ROOT/pxelinux.cfg/default" << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
MENU TITLE LiveCD Network Boot Menu

LABEL live
    MENU LABEL Boot LiveCD System
    KERNEL vmlinuz
    APPEND initrd=initrd.img boot=live components quiet splash fetch=http://PXE_SERVER_IP/live/filesystem.squashfs

LABEL live-installer
    MENU LABEL LiveCD with Installer
    KERNEL vmlinuz
    APPEND initrd=initrd.img boot=live components quiet splash fetch=http://PXE_SERVER_IP/live/filesystem.squashfs installer

LABEL memtest
    MENU LABEL Memory Test
    KERNEL memtest86+

LABEL local
    MENU LABEL Boot from Local Disk
    LOCALBOOT 0
EOF
    
    # Replace server IP placeholder
    sed -i "s/PXE_SERVER_IP/$PXE_SERVER_IP/g" "$chroot_dir$TFTP_ROOT/pxelinux.cfg/default"
}

#==============================================================================
# iPXE Advanced Boot
#==============================================================================

# Setup iPXE for advanced network booting
network_setup_ipxe() {
    local chroot_dir="$1"
    
    log_info "Setting up iPXE advanced boot"
    
    network_mount_chroot "$chroot_dir"
    
    # Install iPXE build dependencies
    local ipxe_packages=(
        "git" "gcc" "make" "liblzma-dev"
        "mkisofs" "isolinux" "mtools"
    )
    
    network_install_packages_parallel "$chroot_dir" "${ipxe_packages[@]}"
    
    # Build iPXE
    chroot "$chroot_dir" bash -c "
        cd /tmp
        git clone https://github.com/ipxe/ipxe.git
        cd ipxe/src
        
        # Create embedded script
        cat > boot.ipxe << 'IPXE'
#!ipxe
dhcp
chain http://$PXE_SERVER_IP/boot.ipxe
IPXE
        
        # Build iPXE with embedded script
        make bin/undionly.kpxe EMBED=boot.ipxe
        make bin-x86_64-efi/ipxe.efi EMBED=boot.ipxe
        
        # Copy to TFTP root
        cp bin/undionly.kpxe $TFTP_ROOT/
        cp bin-x86_64-efi/ipxe.efi $TFTP_ROOT/
    " 2>/dev/null || log_warn "iPXE build failed, using prebuilt"
    
    # Create iPXE boot menu
    network_create_ipxe_menu "$chroot_dir"
    
    network_umount_chroot "$chroot_dir"
    
    log_info "iPXE setup completed"
}

# Create iPXE boot menu
network_create_ipxe_menu() {
    local chroot_dir="$1"
    
    cat > "$chroot_dir$HTTP_ROOT/boot.ipxe" << 'EOF'
#!ipxe

# iPXE Advanced Boot Menu
set server-ip PXE_SERVER_IP
set base-url http://${server-ip}

# Boot menu
:start
menu iPXE Network Boot Menu
item --gap -- ------------------------- Live Systems -------------------------
item live       Boot LiveCD System
item live-ram   Boot LiveCD (RAM mode)
item live-debug Boot LiveCD (Debug mode)
item --gap -- ------------------------- Installation -------------------------
item install    Network Installation
item rescue     Rescue Mode
item --gap -- ------------------------- Utilities -------------------------
item memtest    Memory Test
item shell      iPXE Shell
item reboot     Reboot
item exit       Exit to BIOS
choose --timeout 30000 --default live selected || goto cancel
goto ${selected}

:live
kernel ${base-url}/vmlinuz
initrd ${base-url}/initrd.img
imgargs vmlinuz boot=live components quiet splash fetch=${base-url}/live/filesystem.squashfs
boot || goto failed

:live-ram
kernel ${base-url}/vmlinuz
initrd ${base-url}/initrd.img
imgargs vmlinuz boot=live components quiet splash toram fetch=${base-url}/live/filesystem.squashfs
boot || goto failed

:live-debug
kernel ${base-url}/vmlinuz
initrd ${base-url}/initrd.img
imgargs vmlinuz boot=live components debug fetch=${base-url}/live/filesystem.squashfs
boot || goto failed

:install
kernel ${base-url}/vmlinuz
initrd ${base-url}/initrd.img
imgargs vmlinuz auto=true priority=critical url=${base-url}/preseed.cfg
boot || goto failed

:rescue
kernel ${base-url}/vmlinuz
initrd ${base-url}/initrd.img
imgargs vmlinuz rescue/enable=true
boot || goto failed

:memtest
kernel ${base-url}/memtest86+
boot || goto failed

:shell
echo Entering iPXE shell...
shell

:reboot
reboot

:exit
exit

:cancel
echo Boot cancelled
goto start

:failed
echo Boot failed, returning to menu
goto start
EOF
    
    # Replace server IP
    sed -i "s/PXE_SERVER_IP/$PXE_SERVER_IP/g" "$chroot_dir$HTTP_ROOT/boot.ipxe"
}

#==============================================================================
# Mass Deployment System
#==============================================================================

# Setup mass deployment infrastructure
network_setup_mass_deployment() {
    local chroot_dir="$1"
    
    log_info "Setting up mass deployment system"
    
    network_mount_chroot "$chroot_dir"
    
    # Install deployment tools
    local deploy_packages=(
        "ansible" "puppet" "salt-minion"
        "clusterssh" "pdsh" "pssh"
        "clonezilla" "partclone"
        "rsync" "lsyncd"
    )
    
    network_install_packages_parallel "$chroot_dir" "${deploy_packages[@]}"
    
    # Setup deployment scripts
    network_create_deployment_scripts "$chroot_dir"
    
    # Configure multicast deployment
    network_configure_multicast "$chroot_dir"
    
    # Setup automated provisioning
    network_setup_provisioning "$chroot_dir"
    
    network_umount_chroot "$chroot_dir"
    
    log_info "Mass deployment system configured"
}

# Create deployment scripts
network_create_deployment_scripts() {
    local chroot_dir="$1"
    
    # Parallel deployment script
    cat > "$chroot_dir/usr/local/bin/deploy-parallel" << 'EOF'
#!/bin/bash
# Parallel Deployment Script

HOSTS_FILE="${1:-/etc/deploy-hosts}"
IMAGE_URL="${2:-http://PXE_SERVER_IP/images/latest.img}"
PARALLEL_JOBS="${3:-10}"

if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "Hosts file not found: $HOSTS_FILE"
    exit 1
fi

echo "Starting parallel deployment to $(wc -l < "$HOSTS_FILE") hosts"
echo "Image: $IMAGE_URL"
echo "Parallel jobs: $PARALLEL_JOBS"

# Deploy function
deploy_host() {
    local host="$1"
    echo "[$(date +%H:%M:%S)] Deploying to $host..."
    
    ssh -o StrictHostKeyChecking=no "root@$host" << 'REMOTE'
        wget -O - "$IMAGE_URL" | dd of=/dev/sda bs=4M status=progress
        sync
        reboot
REMOTE
    
    if [[ $? -eq 0 ]]; then
        echo "[$(date +%H:%M:%S)] $host: SUCCESS"
    else
        echo "[$(date +%H:%M:%S)] $host: FAILED"
    fi
}

export -f deploy_host
export IMAGE_URL

# Run parallel deployment
cat "$HOSTS_FILE" | xargs -P "$PARALLEL_JOBS" -I {} bash -c 'deploy_host {}'

echo "Deployment completed"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/deploy-parallel"
    
    # Network scanner for discovery
    cat > "$chroot_dir/usr/local/bin/scan-deploy-targets" << 'EOF'
#!/bin/bash
# Scan network for deployment targets

NETWORK="${1:-192.168.1.0/24}"
OUTPUT_FILE="${2:-/etc/deploy-hosts}"

echo "Scanning network: $NETWORK"

# Scan for systems with SSH open
nmap -p 22 --open -oG - "$NETWORK" | \
    awk '/22\/open/ {print $2}' | \
    grep -v "^#" > "$OUTPUT_FILE"

echo "Found $(wc -l < "$OUTPUT_FILE") deployment targets"
echo "Hosts saved to: $OUTPUT_FILE"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/scan-deploy-targets"
}

# Configure multicast deployment
network_configure_multicast() {
    local chroot_dir="$1"
    
    log_info "Configuring multicast deployment"
    
    # Install udpcast for multicast
    chroot "$chroot_dir" apt-get install -y udpcast || true
    
    # Create multicast sender script
    cat > "$chroot_dir/usr/local/bin/multicast-send" << 'EOF'
#!/bin/bash
# Multicast Image Sender

IMAGE="${1:-/srv/images/livecd.img}"
INTERFACE="${2:-eth0}"
PORT="${3:-9000}"

if [[ ! -f "$IMAGE" ]]; then
    echo "Image not found: $IMAGE"
    exit 1
fi

echo "Starting multicast transmission"
echo "Image: $IMAGE ($(du -h "$IMAGE" | cut -f1))"
echo "Interface: $INTERFACE"
echo "Port: $PORT"

udp-sender --file "$IMAGE" --interface "$INTERFACE" --portbase "$PORT" \
    --min-receivers 1 --max-wait 60 --nokbd --async --fec 8x8/64
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/multicast-send"
    
    # Create multicast receiver script
    cat > "$chroot_dir/usr/local/bin/multicast-receive" << 'EOF'
#!/bin/bash
# Multicast Image Receiver

TARGET="${1:-/dev/sda}"
SERVER="${2:-PXE_SERVER_IP}"
PORT="${3:-9000}"

echo "Starting multicast reception"
echo "Target: $TARGET"
echo "Server: $SERVER"
echo "Port: $PORT"

udp-receiver --interface eth0 --portbase "$PORT" --nokbd | \
    dd of="$TARGET" bs=4M status=progress

sync
echo "Reception completed"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/multicast-receive"
}

# Setup automated provisioning
network_setup_provisioning() {
    local chroot_dir="$1"
    
    log_info "Setting up automated provisioning"
    
    # Create Ansible playbook for provisioning
    mkdir -p "$chroot_dir/etc/ansible"
    
    cat > "$chroot_dir/etc/ansible/provision-livecd.yml" << 'EOF'
---
- name: Provision LiveCD Systems
  hosts: all
  become: yes
  parallel: 10
  
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        upgrade: dist
      async: 3600
      poll: 30
    
    - name: Install essential packages
      apt:
        name:
          - htop
          - vim
          - git
          - curl
          - wget
        state: present
    
    - name: Configure network
      template:
        src: network.j2
        dest: /etc/network/interfaces
      notify: restart networking
    
    - name: Set hostname
      hostname:
        name: "{{ inventory_hostname }}"
    
    - name: Configure SSH
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
      with_items:
        - { regexp: '^PermitRootLogin', line: 'PermitRootLogin no' }
        - { regexp: '^PasswordAuthentication', line: 'PasswordAuthentication no' }
      notify: restart ssh
  
  handlers:
    - name: restart networking
      service:
        name: networking
        state: restarted
    
    - name: restart ssh
      service:
        name: ssh
        state: restarted
EOF
}

#==============================================================================
# Network Services
#==============================================================================

# Configure HTTP server for network boot
network_configure_http_server() {
    local chroot_dir="$1"
    
    log_info "Configuring HTTP server for network boot"
    
    # Create HTTP root directory
    mkdir -p "$chroot_dir$HTTP_ROOT/live"
    
    # Configure Apache for serving boot files
    cat > "$chroot_dir/etc/apache2/sites-available/pxe-boot.conf" << EOF
<VirtualHost *:80>
    DocumentRoot $HTTP_ROOT
    
    <Directory $HTTP_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    # Optimize for large file transfers
    SendBufferSize 262144
    EnableSendfile On
    EnableMMAP On
    
    # Compression for faster transfers
    <IfModule mod_deflate.c>
        SetOutputFilter DEFLATE
        SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png|iso|squashfs)$ no-gzip
    </IfModule>
</VirtualHost>
EOF
    
    chroot "$chroot_dir" a2ensite pxe-boot
    chroot "$chroot_dir" a2enmod deflate sendfile
    chroot "$chroot_dir" systemctl enable apache2
}

# Configure NFS for network boot
network_configure_nfs() {
    local chroot_dir="$1"
    
    log_info "Configuring NFS for network boot"
    
    # Create NFS export directory
    mkdir -p "$chroot_dir$NFS_ROOT"
    
    # Configure NFS exports
    cat >> "$chroot_dir/etc/exports" << EOF
# LiveCD NFS exports
$NFS_ROOT *(ro,sync,no_subtree_check,no_root_squash)
$NFS_ROOT/rw *(rw,sync,no_subtree_check,no_root_squash)
EOF
    
    chroot "$chroot_dir" systemctl enable nfs-kernel-server
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems
network_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
}

# Unmount chroot filesystems
network_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

# Install packages in parallel
network_install_packages_parallel() {
    local chroot_dir="$1"
    shift
    local packages=("$@")
    
    chroot "$chroot_dir" apt-get update
    
    # Install in parallel batches
    local batch_size=4
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

# Main entry point for network deployment
network_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "pxe")
            network_setup_pxe_server "$chroot_dir"
            ;;
        "ipxe")
            network_setup_ipxe "$chroot_dir"
            ;;
        "deployment")
            network_setup_mass_deployment "$chroot_dir"
            ;;
        "http")
            network_configure_http_server "$chroot_dir"
            ;;
        "nfs")
            network_configure_nfs "$chroot_dir"
            ;;
        "all")
            log_info "Setting up complete network deployment"
            network_setup_pxe_server "$chroot_dir"
            network_setup_ipxe "$chroot_dir"
            network_setup_mass_deployment "$chroot_dir"
            network_configure_http_server "$chroot_dir"
            network_configure_nfs "$chroot_dir"
            log_info "Network deployment setup completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {pxe|ipxe|deployment|http|nfs|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    network_main "$@"
fi