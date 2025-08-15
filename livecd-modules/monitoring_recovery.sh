#!/bin/bash
#
# monitoring_recovery.sh - LiveCD Monitoring & Recovery Tools Module
# Part of the consolidated LiveCD build system
#
# Consolidates system monitoring, recovery tools, diagnostics,
# performance analysis, and rescue utilities with optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly MONITOR_MODULE_VERSION="1.0.0"
readonly MONITOR_MODULE_NAME="Monitoring Recovery Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${INSTALL_MONITORING:=true}"
: "${INSTALL_RECOVERY:=true}"
: "${INSTALL_FORENSICS:=true}"
: "${INSTALL_BACKUP:=true}"
: "${ENABLE_SERVICES:=true}"

#==============================================================================
# System Monitoring Tools
#==============================================================================

# Install comprehensive monitoring suite
monitor_install_monitoring() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_MONITORING" != "true" ]]; then
        log_info "Monitoring tools installation skipped"
        return 0
    fi
    
    log_info "Installing system monitoring tools"
    
    # Core monitoring tools
    local monitor_packages=(
        # System monitoring
        "htop" "btop" "atop" "iotop" "iftop"
        "nethogs" "bmon" "nmon" "dstat"
        "sysstat" "procinfo" "lsof"
        
        # Performance analysis
        "perf-tools-unstable" "linux-tools-generic"
        "bpfcc-tools" "bpftrace" "systemtap"
        "strace" "ltrace" "fatrace"
        
        # Hardware monitoring
        "lm-sensors" "hddtemp" "smartmontools"
        "nvme-cli" "pciutils" "usbutils"
        "i2c-tools" "dmidecode" "hwinfo"
        
        # Network monitoring
        "tcpdump" "wireshark" "tshark"
        "nmap" "netcat-openbsd" "traceroute"
        "mtr" "iperf3" "speedtest-cli"
        
        # Log analysis
        "multitail" "logwatch" "goaccess"
        "ccze" "lnav" "journalctl"
    )
    
    monitor_mount_chroot "$chroot_dir"
    monitor_install_packages_parallel "$chroot_dir" "${monitor_packages[@]}"
    
    # Configure monitoring services
    monitor_configure_services "$chroot_dir"
    
    # Install monitoring dashboards
    monitor_install_dashboards "$chroot_dir"
    
    monitor_umount_chroot "$chroot_dir"
    
    log_info "Monitoring tools installed"
}

# Configure monitoring services
monitor_configure_services() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_SERVICES" != "true" ]]; then
        return 0
    fi
    
    log_info "Configuring monitoring services"
    
    # Configure sysstat for system activity collection
    chroot "$chroot_dir" bash -c "
        # Enable sysstat collection
        sed -i 's/ENABLED=\"false\"/ENABLED=\"true\"/' /etc/default/sysstat
        
        # Configure collection interval (every 2 minutes)
        cat > /etc/cron.d/sysstat << 'EOF'
*/2 * * * * root /usr/lib/sysstat/sa1 1 1
53 23 * * * root /usr/lib/sysstat/sa2 -A
EOF
        
        systemctl enable sysstat
    "
    
    # Configure smartd for disk monitoring
    cat > "$chroot_dir/etc/smartd.conf" << 'EOF'
# Monitor all ATA/SATA disks
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,40
EOF
    
    chroot "$chroot_dir" systemctl enable smartd 2>/dev/null || true
    
    # Setup automatic sensor detection
    chroot "$chroot_dir" bash -c "
        # Detect sensors
        yes '' | sensors-detect 2>/dev/null || true
        
        # Create sensor monitoring script
        cat > /usr/local/bin/monitor-sensors << 'SCRIPT'
#!/bin/bash
while true; do
    sensors -u >> /var/log/sensors.log
    sleep 60
done
SCRIPT
        chmod +x /usr/local/bin/monitor-sensors
    "
}

# Install monitoring dashboards
monitor_install_dashboards() {
    local chroot_dir="$1"
    
    log_info "Installing monitoring dashboards"
    
    # Install Prometheus and Grafana (lightweight monitoring)
    chroot "$chroot_dir" bash -c "
        # Install Prometheus node exporter
        apt-get install -y prometheus-node-exporter 2>/dev/null || {
            # Manual installation if package not available
            cd /tmp
            wget -q https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-*linux-amd64.tar.gz
            tar -xzf node_exporter-*.tar.gz
            cp node_exporter-*/node_exporter /usr/local/bin/
            rm -rf node_exporter-*
        }
        
        # Create systemd service for node exporter
        cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl enable node_exporter 2>/dev/null || true
    " 2>/dev/null || log_warn "Dashboard installation partially failed"
}

#==============================================================================
# Recovery and Rescue Tools
#==============================================================================

# Install recovery and rescue tools
monitor_install_recovery() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_RECOVERY" != "true" ]]; then
        log_info "Recovery tools installation skipped"
        return 0
    fi
    
    log_info "Installing recovery and rescue tools"
    
    # Recovery tool packages
    local recovery_packages=(
        # Partition recovery
        "testdisk" "gpart" "gdisk" "parted"
        "gparted" "fdisk" "sfdisk"
        
        # File recovery
        "extundelete" "ext4magic" "e2fsck-static"
        "ntfs-3g" "ntfsprogs" "dosfstools"
        "exfat-utils" "exfat-fuse"
        
        # Data recovery
        "ddrescue" "gddrescue" "safecopy"
        "foremost" "scalpel" "photorec"
        "recoverjpeg" "magicrescue"
        
        # Backup tools
        "rsync" "rdiff-backup" "duplicity"
        "borgbackup" "restic" "rclone"
        "tar" "gzip" "bzip2" "xz-utils"
        
        # System rescue
        "systemrescue" "grub-rescue-pc"
        "boot-repair" "os-prober"
        "chntpw" "ophcrack"
        
        # Disk utilities
        "hdparm" "sdparm" "nvme-cli"
        "badblocks" "e2fsprogs" "xfsprogs"
        "btrfs-progs" "zfsutils-linux"
    )
    
    monitor_mount_chroot "$chroot_dir"
    monitor_install_packages_parallel "$chroot_dir" "${recovery_packages[@]}"
    
    # Create recovery scripts
    monitor_create_recovery_scripts "$chroot_dir"
    
    monitor_umount_chroot "$chroot_dir"
    
    log_info "Recovery tools installed"
}

# Create recovery helper scripts
monitor_create_recovery_scripts() {
    local chroot_dir="$1"
    
    # Disk recovery script
    cat > "$chroot_dir/usr/local/bin/disk-recovery" << 'EOF'
#!/bin/bash
# Disk Recovery Assistant

DEVICE="${1:-}"
OUTPUT="${2:-recovered.img}"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: $0 <device> [output_file]"
    echo "Example: $0 /dev/sda recovered.img"
    exit 1
fi

echo "Starting disk recovery from $DEVICE to $OUTPUT"

# Check disk health
echo "Checking disk health..."
smartctl -H "$DEVICE"

# Use ddrescue for recovery
echo "Starting recovery with ddrescue..."
ddrescue -f -n "$DEVICE" "$OUTPUT" "$OUTPUT.log"

# Second pass for difficult areas
echo "Second pass for problematic sectors..."
ddrescue -d -f -r3 "$DEVICE" "$OUTPUT" "$OUTPUT.log"

echo "Recovery completed. Check $OUTPUT.log for details"
echo "Image saved to: $OUTPUT"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/disk-recovery"
    
    # File recovery script
    cat > "$chroot_dir/usr/local/bin/file-recovery" << 'EOF'
#!/bin/bash
# File Recovery Assistant

SOURCE="${1:-}"
DEST="${2:-/tmp/recovered}"
TYPE="${3:-all}"

if [[ -z "$SOURCE" ]]; then
    echo "Usage: $0 <source> [destination] [type]"
    echo "Types: all, jpg, pdf, doc, video"
    exit 1
fi

mkdir -p "$DEST"

echo "Starting file recovery from $SOURCE"
echo "Destination: $DEST"
echo "File type: $TYPE"

case "$TYPE" in
    jpg|jpeg)
        recoverjpeg "$SOURCE" -o "$DEST"
        ;;
    pdf|doc|office)
        foremost -t doc,pdf,xls,ppt -i "$SOURCE" -o "$DEST"
        ;;
    video)
        foremost -t avi,mpg,mp4,mov -i "$SOURCE" -o "$DEST"
        ;;
    all|*)
        photorec /d "$DEST" /cmd "$SOURCE" search
        ;;
esac

echo "Recovery completed. Files saved to: $DEST"
ls -la "$DEST" | head -20
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/file-recovery"
    
    # System rescue script
    cat > "$chroot_dir/usr/local/bin/system-rescue" << 'EOF'
#!/bin/bash
# System Rescue Assistant

ACTION="${1:-check}"

case "$ACTION" in
    check)
        echo "=== System Health Check ==="
        # Check filesystems
        echo "Filesystem check:"
        df -h
        echo ""
        echo "Mount points:"
        mount | column -t
        echo ""
        echo "Block devices:"
        lsblk
        ;;
        
    grub)
        echo "=== GRUB Repair ==="
        # Reinstall GRUB
        DISK="${2:-/dev/sda}"
        echo "Reinstalling GRUB to $DISK"
        grub-install "$DISK"
        update-grub
        ;;
        
    password)
        echo "=== Password Reset ==="
        # Reset user password
        USER="${2:-root}"
        echo "Resetting password for user: $USER"
        passwd "$USER"
        ;;
        
    network)
        echo "=== Network Repair ==="
        # Reset network configuration
        systemctl restart NetworkManager
        dhclient -r && dhclient
        ip link show
        ;;
        
    *)
        echo "Usage: $0 {check|grub|password|network}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/system-rescue"
}

#==============================================================================
# Forensics and Analysis Tools
#==============================================================================

# Install forensics tools
monitor_install_forensics() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_FORENSICS" != "true" ]]; then
        log_info "Forensics tools installation skipped"
        return 0
    fi
    
    log_info "Installing forensics and analysis tools"
    
    # Forensics packages
    local forensics_packages=(
        # Forensics frameworks
        "sleuthkit" "autopsy" "volatility3"
        "forensics-all" "forensics-extra"
        
        # File analysis
        "binwalk" "hexedit" "xxd"
        "radare2" "rizin" "cutter"
        "file" "exiftool" "mediainfo"
        
        # Memory analysis
        "volatility" "lime-forensics-dkms"
        "dumpzilla" "mem"
        
        # Network forensics
        "tcpflow" "tcpreplay" "tcpxtract"
        "netwox" "netwag" "packeth"
        "ettercap-text-only" "dsniff"
        
        # Disk forensics
        "dc3dd" "dcfldd" "ewf-tools"
        "afflib-tools" "disktype"
        
        # Log analysis
        "logparser" "lnav" "glogg"
        "splunk-forwarder" "elasticsearch"
    )
    
    monitor_mount_chroot "$chroot_dir"
    
    # Install packages (some may fail, continue anyway)
    for package in "${forensics_packages[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$package" 2>/dev/null || \
            log_warn "Package not available: $package"
    done
    
    # Create forensics scripts
    monitor_create_forensics_scripts "$chroot_dir"
    
    monitor_umount_chroot "$chroot_dir"
    
    log_info "Forensics tools installed"
}

# Create forensics helper scripts
monitor_create_forensics_scripts() {
    local chroot_dir="$1"
    
    # Memory dump script
    cat > "$chroot_dir/usr/local/bin/memory-dump" << 'EOF'
#!/bin/bash
# Memory Dump Tool

OUTPUT="${1:-memory-$(date +%Y%m%d-%H%M%S).dump}"

echo "Creating memory dump: $OUTPUT"

# Check for LiME module
if lsmod | grep -q lime; then
    echo "Using LiME for memory acquisition"
    insmod /lib/modules/$(uname -r)/extra/lime.ko "path=$OUTPUT format=lime"
else
    # Fallback to /proc/kcore
    echo "Using /proc/kcore for memory acquisition"
    dd if=/proc/kcore of="$OUTPUT" bs=1M status=progress
fi

echo "Memory dump saved to: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | cut -f1)"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/memory-dump"
    
    # Forensic analysis script
    cat > "$chroot_dir/usr/local/bin/forensic-analyze" << 'EOF'
#!/bin/bash
# Forensic Analysis Tool

TARGET="${1:-}"
TYPE="${2:-auto}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <target> [type]"
    echo "Types: auto, disk, memory, network, file"
    exit 1
fi

echo "Starting forensic analysis of: $TARGET"

case "$TYPE" in
    disk)
        echo "=== Disk Analysis ==="
        sleuthkit mmls "$TARGET"
        sleuthkit fls "$TARGET"
        ;;
        
    memory)
        echo "=== Memory Analysis ==="
        volatility3 -f "$TARGET" windows.info
        volatility3 -f "$TARGET" windows.pslist
        ;;
        
    network)
        echo "=== Network Analysis ==="
        tcpdump -r "$TARGET" -nn | head -100
        tcpflow -r "$TARGET"
        ;;
        
    file)
        echo "=== File Analysis ==="
        file "$TARGET"
        exiftool "$TARGET"
        binwalk "$TARGET"
        ;;
        
    auto|*)
        # Auto-detect type
        if file "$TARGET" | grep -q "pcap"; then
            $0 "$TARGET" network
        elif file "$TARGET" | grep -q "ELF"; then
            $0 "$TARGET" file
        else
            $0 "$TARGET" disk
        fi
        ;;
esac
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/forensic-analyze"
}

#==============================================================================
# Backup and Restore Tools
#==============================================================================

# Install backup tools
monitor_install_backup() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_BACKUP" != "true" ]]; then
        log_info "Backup tools installation skipped"
        return 0
    fi
    
    log_info "Installing backup and restore tools"
    
    # Backup packages
    local backup_packages=(
        # Backup software
        "bacula-client" "amanda-client"
        "backuppc" "rsnapshot"
        "timeshift" "backintime-common"
        
        # Cloud backup
        "rclone" "s3cmd" "aws-cli"
        "gdrive" "dropbox"
        
        # Compression
        "p7zip-full" "rar" "unrar"
        "zip" "unzip" "arj"
        "lzop" "lz4" "zstd"
        
        # Encryption
        "gnupg" "gnupg2" "openssl"
        "cryptsetup" "ecryptfs-utils"
        "veracrypt" "zuluCrypt-cli"
    )
    
    monitor_mount_chroot "$chroot_dir"
    
    # Install packages
    for package in "${backup_packages[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$package" 2>/dev/null || \
            log_warn "Package not available: $package"
    done
    
    # Create backup scripts
    monitor_create_backup_scripts "$chroot_dir"
    
    monitor_umount_chroot "$chroot_dir"
    
    log_info "Backup tools installed"
}

# Create backup helper scripts
monitor_create_backup_scripts() {
    local chroot_dir="$1"
    
    # System backup script
    cat > "$chroot_dir/usr/local/bin/system-backup" << 'EOF'
#!/bin/bash
# System Backup Tool

BACKUP_DIR="${1:-/backup}"
BACKUP_NAME="${2:-system-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$BACKUP_DIR"

echo "Creating system backup: $BACKUP_NAME"
echo "Destination: $BACKUP_DIR"

# Create backup with rsync
rsync -aAXv \
    --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
    / "$BACKUP_DIR/$BACKUP_NAME/"

# Create tarball
echo "Creating compressed archive..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    -C "$BACKUP_DIR" \
    "$BACKUP_NAME"

# Remove uncompressed backup
rm -rf "$BACKUP_DIR/$BACKUP_NAME"

echo "Backup completed: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Size: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/system-backup"
    
    # Incremental backup script
    cat > "$chroot_dir/usr/local/bin/incremental-backup" << 'EOF'
#!/bin/bash
# Incremental Backup Tool

SOURCE="${1:-/}"
DEST="${2:-/backup}"
SNAPSHOT="${3:-.snapshots}"

mkdir -p "$DEST" "$DEST/$SNAPSHOT"

echo "Creating incremental backup"
echo "Source: $SOURCE"
echo "Destination: $DEST"

# Use rsync with hard links for incremental backup
LATEST=$(ls -t "$DEST/$SNAPSHOT" 2>/dev/null | head -1)
DATE=$(date +%Y%m%d-%H%M%S)

if [[ -n "$LATEST" ]]; then
    echo "Using previous snapshot: $LATEST"
    rsync -aAXv --delete \
        --link-dest="$DEST/$SNAPSHOT/$LATEST" \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*"} \
        "$SOURCE" "$DEST/$SNAPSHOT/$DATE/"
else
    echo "Creating initial snapshot"
    rsync -aAXv \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*"} \
        "$SOURCE" "$DEST/$SNAPSHOT/$DATE/"
fi

echo "Incremental backup completed: $DEST/$SNAPSHOT/$DATE"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/incremental-backup"
}

#==============================================================================
# System Diagnostics
#==============================================================================

# Create diagnostic tools
monitor_create_diagnostics() {
    local chroot_dir="$1"
    
    log_info "Creating system diagnostic tools"
    
    # Comprehensive system diagnostic script
    cat > "$chroot_dir/usr/local/bin/system-diagnostics" << 'EOF'
#!/bin/bash
# System Diagnostics Tool

OUTPUT="${1:-diagnostics-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUTPUT"

echo "Running comprehensive system diagnostics..."
echo "Output directory: $OUTPUT"

# System information
echo "Collecting system information..."
{
    echo "=== System Information ==="
    uname -a
    echo ""
    echo "=== CPU Information ==="
    lscpu
    echo ""
    echo "=== Memory Information ==="
    free -h
    echo ""
    echo "=== Disk Information ==="
    df -h
    echo ""
    lsblk -a
} > "$OUTPUT/system-info.txt"

# Hardware information
echo "Collecting hardware information..."
{
    echo "=== PCI Devices ==="
    lspci -vvv
    echo ""
    echo "=== USB Devices ==="
    lsusb -v
    echo ""
    echo "=== DMI Information ==="
    dmidecode
} > "$OUTPUT/hardware-info.txt" 2>/dev/null

# Network information
echo "Collecting network information..."
{
    echo "=== Network Interfaces ==="
    ip addr show
    echo ""
    echo "=== Routing Table ==="
    ip route show
    echo ""
    echo "=== Network Statistics ==="
    netstat -s
    echo ""
    echo "=== Connection Status ==="
    ss -tunap
} > "$OUTPUT/network-info.txt"

# Process information
echo "Collecting process information..."
{
    echo "=== Process Tree ==="
    pstree -a
    echo ""
    echo "=== Top Processes ==="
    ps aux --sort=-%cpu | head -20
    echo ""
    echo "=== Memory Usage ==="
    ps aux --sort=-%mem | head -20
} > "$OUTPUT/process-info.txt"

# Service status
echo "Collecting service status..."
{
    echo "=== Systemd Services ==="
    systemctl list-units --all
    echo ""
    echo "=== Failed Services ==="
    systemctl list-units --failed
} > "$OUTPUT/service-info.txt"

# Log collection
echo "Collecting system logs..."
journalctl -xb > "$OUTPUT/journal.log" 2>/dev/null
dmesg > "$OUTPUT/dmesg.log"
cp /var/log/syslog "$OUTPUT/" 2>/dev/null || true

# Performance data
echo "Collecting performance data..."
{
    echo "=== I/O Statistics ==="
    iostat -x 1 5
    echo ""
    echo "=== VM Statistics ==="
    vmstat 1 5
    echo ""
    echo "=== System Activity ==="
    sar -A 2>/dev/null || echo "sysstat not available"
} > "$OUTPUT/performance-info.txt"

# Create summary
echo "Creating diagnostic summary..."
cat > "$OUTPUT/SUMMARY.txt" << SUMMARY
System Diagnostics Report
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

Key Findings:
- CPU Cores: $(nproc)
- Total Memory: $(free -h | awk '/^Mem:/{print $2}')
- Disk Usage: $(df -h / | awk 'NR==2{print $5}')
- Network Interfaces: $(ip -br link | wc -l)
- Running Processes: $(ps aux | wc -l)
- Failed Services: $(systemctl list-units --failed | grep -c "failed")

Full diagnostics available in individual files.
SUMMARY

# Compress results
echo "Compressing diagnostic data..."
tar -czf "$OUTPUT.tar.gz" "$OUTPUT"
rm -rf "$OUTPUT"

echo "Diagnostics completed: $OUTPUT.tar.gz"
echo "Size: $(du -h "$OUTPUT.tar.gz" | cut -f1)"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/system-diagnostics"
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems
monitor_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
}

# Unmount chroot filesystems
monitor_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

# Install packages in parallel
monitor_install_packages_parallel() {
    local chroot_dir="$1"
    shift
    local packages=("$@")
    
    chroot "$chroot_dir" apt-get update
    
    local batch_size=5
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

# Main entry point for monitoring and recovery
monitor_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "monitoring")
            monitor_install_monitoring "$chroot_dir"
            ;;
        "recovery")
            monitor_install_recovery "$chroot_dir"
            ;;
        "forensics")
            monitor_install_forensics "$chroot_dir"
            ;;
        "backup")
            monitor_install_backup "$chroot_dir"
            ;;
        "diagnostics")
            monitor_create_diagnostics "$chroot_dir"
            ;;
        "zfs-state")
            monitor_install_zfs_state_capture "$chroot_dir"
            ;;
        "all")
            log_info "Installing complete monitoring and recovery suite"
            monitor_install_monitoring "$chroot_dir"
            monitor_install_recovery "$chroot_dir"
            monitor_install_forensics "$chroot_dir"
            monitor_install_backup "$chroot_dir"
            monitor_create_diagnostics "$chroot_dir"
            monitor_install_zfs_state_capture "$chroot_dir"
            log_info "Monitoring and recovery installation completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {monitoring|recovery|forensics|backup|diagnostics|all}"
            return 1
            ;;
    esac
}

#==============================================================================
# ZFS State Capture and Recovery
#==============================================================================

# Install ZFS state capture tools
monitor_install_zfs_state_capture() {
    local chroot_dir="$1"
    
    log_info "Installing ZFS state capture and recovery tools"
    
    # Create state capture script
    cat > "$chroot_dir/usr/local/bin/zfs-state-capture" << 'EOF'
#!/bin/bash
# ZFS State Capture for Recovery and Analysis

STATE_DIR="${1:-/var/log/zfs-state-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$STATE_DIR"

echo "=== ZFS State Capture ==="
echo "Capturing to: $STATE_DIR"

# Capture pool status
echo "Capturing ZFS pool status..."
zpool status -v > "$STATE_DIR/zpool-status.txt" 2>&1
zpool list -v > "$STATE_DIR/zpool-list.txt" 2>&1
zpool history > "$STATE_DIR/zpool-history.txt" 2>&1
zpool get all > "$STATE_DIR/zpool-properties.txt" 2>&1

# Capture dataset information
echo "Capturing ZFS datasets..."
zfs list -t all -o all > "$STATE_DIR/zfs-datasets.txt" 2>&1
zfs get all > "$STATE_DIR/zfs-properties.txt" 2>&1

# Capture snapshots
echo "Capturing ZFS snapshots..."
zfs list -t snapshot -o name,creation,used,referenced > "$STATE_DIR/zfs-snapshots.txt" 2>&1

# Capture ZFS kernel module info
echo "Capturing ZFS kernel info..."
modinfo zfs > "$STATE_DIR/zfs-module-info.txt" 2>&1
cat /proc/spl/kstat/zfs/arcstats > "$STATE_DIR/zfs-arcstats.txt" 2>&1

# Create recovery snapshot
if [ "$2" = "--snapshot" ]; then
    echo "Creating recovery snapshot..."
    SNAPSHOT_NAME="recovery-$(date +%Y%m%d-%H%M%S)"
    for dataset in $(zfs list -H -o name -t filesystem); do
        zfs snapshot "${dataset}@${SNAPSHOT_NAME}" 2>/dev/null && \
            echo "Created snapshot: ${dataset}@${SNAPSHOT_NAME}"
    done
fi

# Create state archive
echo "Creating state archive..."
tar czf "$STATE_DIR.tar.gz" -C "$(dirname "$STATE_DIR")" "$(basename "$STATE_DIR")"

echo "✓ State captured to: $STATE_DIR.tar.gz"
echo ""
echo "To restore from snapshot:"
echo "  zfs rollback pool/dataset@recovery-YYYYMMDD-HHMMSS"
echo ""
echo "To clone for testing:"
echo "  zfs clone pool/dataset@recovery-YYYYMMDD-HHMMSS pool/test-dataset"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/zfs-state-capture"
    
    # Create ZFS emergency recovery script
    cat > "$chroot_dir/usr/local/bin/zfs-emergency-recovery" << 'EOF'
#!/bin/bash
# ZFS Emergency Recovery Tool

echo "=== ZFS Emergency Recovery ==="
echo ""
echo "WARNING: This tool performs recovery operations on ZFS pools"
echo "Press Ctrl+C to abort, Enter to continue..."
read -r

# Import all available pools
echo "Importing all available pools..."
zpool import -a -f 2>/dev/null || echo "Some pools could not be imported"

# Show pool status
echo ""
echo "Current pool status:"
zpool status

# Check for errors
if zpool status | grep -q "DEGRADED\|FAULTED\|OFFLINE"; then
    echo ""
    echo "WARNING: Pools with errors detected!"
    echo "Attempting recovery..."
    
    # Try to clear errors
    for pool in $(zpool list -H -o name); do
        echo "Clearing errors on $pool..."
        zpool clear "$pool"
    done
    
    # Scrub pools
    echo "Starting scrub on all pools..."
    for pool in $(zpool list -H -o name); do
        zpool scrub "$pool"
    done
fi

# List available snapshots for recovery
echo ""
echo "Available recovery snapshots:"
zfs list -t snapshot -o name,creation | grep recovery || echo "No recovery snapshots found"

# Offer recovery options
echo ""
echo "Recovery Options:"
echo "1. Rollback to snapshot"
echo "2. Clone snapshot for testing"
echo "3. Export and reimport pools"
echo "4. Create new recovery snapshot"
echo "5. Exit"
echo ""
echo -n "Select option (1-5): "
read -r option

case $option in
    1)
        echo -n "Enter snapshot name to rollback: "
        read -r snapshot
        zfs rollback "$snapshot" && echo "Rollback successful" || echo "Rollback failed"
        ;;
    2)
        echo -n "Enter snapshot to clone: "
        read -r snapshot
        echo -n "Enter new dataset name: "
        read -r newname
        zfs clone "$snapshot" "$newname" && echo "Clone created: $newname" || echo "Clone failed"
        ;;
    3)
        echo "Exporting all pools..."
        for pool in $(zpool list -H -o name); do
            zpool export "$pool"
        done
        echo "Reimporting pools..."
        zpool import -a
        ;;
    4)
        /usr/local/bin/zfs-state-capture /tmp/recovery --snapshot
        ;;
    5)
        exit 0
        ;;
esac
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/zfs-emergency-recovery"
    
    # Create systemd service for automatic state capture
    cat > "$chroot_dir/etc/systemd/system/zfs-state-capture.service" << 'EOF'
[Unit]
Description=ZFS State Capture Service
After=zfs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/zfs-state-capture /var/log/zfs-state-boot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Create timer for periodic capture
    cat > "$chroot_dir/etc/systemd/system/zfs-state-capture.timer" << 'EOF'
[Unit]
Description=Periodic ZFS State Capture

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    log_info "ZFS state capture and recovery tools installed"
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_main "$@"
fi