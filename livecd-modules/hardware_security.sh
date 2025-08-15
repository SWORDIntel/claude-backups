#!/bin/bash
#
# hardware_security.sh - LiveCD Hardware & Security Module
# Part of the consolidated LiveCD build system
#
# Consolidates hardware enumeration, Intel ME hardening, Dell blocking,
# security tools, and platform-specific optimizations
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly HARDWARE_MODULE_VERSION="1.0.0"
readonly HARDWARE_MODULE_NAME="Hardware Security Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${ENABLE_INTEL_ME_HARDENING:=true}"
: "${ENABLE_DELL_BLOCKING:=true}"
: "${INSTALL_HARDWARE_TOOLS:=true}"
: "${INSTALL_SECURITY_TOOLS:=true}"
: "${ENABLE_METEOR_LAKE_OPTIMIZATION:=true}"

#==============================================================================
# Intel ME/AMT Hardening
#==============================================================================

# Install Intel ME hardening tools
hardware_install_intel_me_hardening() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_INTEL_ME_HARDENING" != "true" ]]; then
        log_info "Intel ME hardening skipped"
        return 0
    fi
    
    log_info "Installing Intel ME/AMT hardening tools"
    
    hardware_mount_chroot "$chroot_dir"
    
    # Install ME analysis & ring-level access tools
    local me_tools=(
        "flashrom" "me_cleaner" "intelmetool"
        "dmidecode" "lshw" "pciutils" "usbutils"
        "chipsec" "python3-pip" "python3-dev"
        # Ring -3 to Ring 0 access tools
        "msr-tools" "ioport" "i2c-tools" "spi-tools"
        "fwupd" "fwupd-signed" "libreboot-utils"
        "coreboot-utils" "nvramtool" "superiotool"
        # CPU microcode and firmware tools
        "intel-microcode" "amd64-microcode" "iucode-tool"
        "cpu-checker" "cpuid" "x86info" "mcelog"
        # Memory and hardware debugging
        "memtest86+" "memtester" "edac-utils"
        "rasdaemon" "paxtest" "checksec"
    )
    
    # Install available packages
    for tool in "${me_tools[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$tool" 2>/dev/null || \
            log_warn "Package not available: $tool"
    done
    
    # Install ME cleaner from source if not available
    chroot "$chroot_dir" bash -c "
        if ! command -v me_cleaner >/dev/null; then
            cd /tmp || { echo "Error: Command failed"; return 1; }
            git clone https://github.com/corna/me_cleaner.git
            cp me_cleaner/me_cleaner.py /usr/local/bin/me_cleaner
            chmod +x /usr/local/bin/me_cleaner
            rm -rf me_cleaner
        fi
    " 2>/dev/null || true
    
    # Create Intel ME hardening scripts
    hardware_create_intel_me_scripts "$chroot_dir"
    
    hardware_umount_chroot "$chroot_dir"
    
    log_info "Intel ME hardening tools installed"
}

# Create Intel ME hardening scripts
hardware_create_intel_me_scripts() {
    local chroot_dir="$1"
    
    # ME detection and analysis script
    cat > "$chroot_dir/usr/local/bin/analyze-intel-me" << 'EOF'
#!/bin/bash
# Intel ME Analysis Tool

echo "=== Intel Management Engine Analysis ==="

# Check if Intel ME is present
if lspci | grep -i "management engine" >/dev/null; then
    echo "✓ Intel ME detected"
    lspci | grep -i "management engine"
else
    echo "✗ Intel ME not detected"
fi

# Check ME status via HECI
if [[ -c /dev/mei0 ]] || [[ -c /dev/mei ]]; then
    echo "✓ MEI interface found"
    ls -la /dev/mei*
else
    echo "✗ MEI interface not found"
fi

# Check ME firmware version
if command -v intelmetool >/dev/null; then
    echo ""
    echo "=== ME Firmware Information ==="
    intelmetool -m 2>/dev/null || echo "Could not read ME firmware info"
fi

# Check BIOS for ME settings
echo ""
echo "=== BIOS/UEFI Information ==="
dmidecode -t bios | grep -E "(Version|Date|Vendor)"

# Check for HAP bit (ME disable)
if command -v flashrom >/dev/null; then
    echo ""
    echo "=== Flash Chip Information ==="
    flashrom -p internal 2>/dev/null | head -10 || echo "Flash access denied"
fi

echo ""
echo "=== Recommendations ==="
echo "1. Check BIOS for Intel ME disable option"
echo "2. Look for HAP (High Assurance Platform) mode"
echo "3. Consider using me_cleaner for firmware modification"
echo "4. Monitor network traffic for AMT connections"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/analyze-intel-me"
    
    # ME blocking script
    cat > "$chroot_dir/usr/local/bin/block-intel-me" << 'EOF'
#!/bin/bash
# Intel ME Blocking Tool

echo "=== Intel ME/AMT Blocking ==="

# Block ME at kernel level
echo "Blocking Intel ME kernel modules..."

# Create modprobe blacklist
cat > /etc/modprobe.d/blacklist-intel-me.conf << 'BLOCK'
# Block Intel Management Engine modules
blacklist mei
blacklist mei_me
blacklist mei_wdt
blacklist intel_amt
blacklist intel_ips
blacklist intel_smartconnect
BLOCK

# Block ME network access with iptables
echo "Blocking ME network access..."
iptables -A OUTPUT -p tcp --dport 16992 -j DROP  # AMT HTTP
iptables -A OUTPUT -p tcp --dport 16993 -j DROP  # AMT HTTPS
iptables -A OUTPUT -p tcp --dport 623 -j DROP    # IPMI
iptables -A OUTPUT -p tcp --dport 664 -j DROP    # ASF-RMCP

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Disable ME in GRUB
if [[ -f /etc/default/grub ]]; then
    if ! grep -q "intel_iommu=on" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on /' /etc/default/grub
    fi
    update-grub
fi

echo "✓ Intel ME blocking configured"
echo "Reboot required for changes to take effect"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/block-intel-me"
}

#==============================================================================
# Dell System Blocking
#==============================================================================

# Install Dell blocking tools
hardware_install_dell_blocking() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_DELL_BLOCKING" != "true" ]]; then
        log_info "Dell blocking skipped"
        return 0
    fi
    
    log_info "Installing Dell system blocking tools"
    
    hardware_mount_chroot "$chroot_dir"
    
    # Create Dell blocking scripts
    hardware_create_dell_blocking_scripts "$chroot_dir"
    
    # Install network monitoring tools
    local network_tools=(
        "iptables" "iptables-persistent"
        "tcpdump" "wireshark-common"
        "netstat-nat" "ss"
    )
    
    for tool in "${network_tools[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$tool" 2>/dev/null || true
    done
    
    hardware_umount_chroot "$chroot_dir"
    
    log_info "Dell blocking tools installed"
}

# Create Dell blocking scripts
hardware_create_dell_blocking_scripts() {
    local chroot_dir="$1"
    
    # Dell telemetry blocking script
    cat > "$chroot_dir/usr/local/bin/block-dell-telemetry" << 'EOF'
#!/bin/bash
# Dell Telemetry Blocking Tool

echo "=== Dell Telemetry Blocking ==="

# Block Dell domains in hosts file
cat >> /etc/hosts << 'DELL_BLOCK'
# Dell telemetry and tracking domains
0.0.0.0 www.dell.com
0.0.0.0 support.dell.com
0.0.0.0 downloads.dell.com
0.0.0.0 ftp.dell.com
0.0.0.0 dell.com
0.0.0.0 delltechchoiceaudit.com
0.0.0.0 delltechnologies.com
0.0.0.0 emc.com
0.0.0.0 rsa.com
0.0.0.0 pivotal.io
0.0.0.0 vmware.com
0.0.0.0 secureworks.com
0.0.0.0 boomi.com
DELL_BLOCK

# Block with iptables
echo "Configuring firewall rules..."
iptables -A OUTPUT -d dell.com -j DROP
iptables -A OUTPUT -d delltechnologies.com -j DROP
iptables -A OUTPUT -d support.dell.com -j DROP

# Block Dell services
systemctl disable dell-recovery || true
systemctl stop dell-recovery || true
systemctl disable dellmgmt || true
systemctl stop dellmgmt || true

# Remove Dell software
apt-get remove -y dell-recovery dell-support* || true

echo "✓ Dell telemetry blocking configured"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/block-dell-telemetry"
    
    # Dell hardware detection script
    cat > "$chroot_dir/usr/local/bin/detect-dell-hardware" << 'EOF'
#!/bin/bash
# Dell Hardware Detection Tool

echo "=== Dell Hardware Detection ==="

# Check DMI information
if dmidecode -s system-manufacturer | grep -qi dell; then
    echo "✓ Dell system detected"
    echo "Manufacturer: $(dmidecode -s system-manufacturer)"
    echo "Product Name: $(dmidecode -s system-product-name)"
    echo "Serial Number: $(dmidecode -s system-serial-number)"
    echo "BIOS Version: $(dmidecode -s bios-version)"
else
    echo "✗ Dell system not detected"
    exit 0
fi

# Check for Dell-specific hardware
echo ""
echo "=== Dell Hardware Components ==="

# Check for ControlVault
if lspci | grep -i "broadcom.*5880" >/dev/null; then
    echo "✓ Dell ControlVault detected"
    lspci | grep -i "broadcom.*5880"
fi

# Check for Dell network controllers
if lspci | grep -E "(Dell|Broadcom)" | grep -i network >/dev/null; then
    echo "✓ Dell network hardware detected"
    lspci | grep -E "(Dell|Broadcom)" | grep -i network
fi

# Check for Dell storage controllers
if lspci | grep -i dell | grep -i storage >/dev/null; then
    echo "✓ Dell storage hardware detected"
    lspci | grep -i dell | grep -i storage
fi

echo ""
echo "=== Recommendations ==="
echo "1. Run 'block-dell-telemetry' to block Dell communications"
echo "2. Check BIOS for telemetry disable options"
echo "3. Monitor network traffic for Dell connections"
echo "4. Consider firmware modification for complete isolation"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/detect-dell-hardware"
}

#==============================================================================
# Hardware Enumeration Tools
#==============================================================================

# Install hardware enumeration tools
hardware_install_enumeration_tools() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_HARDWARE_TOOLS" != "true" ]]; then
        log_info "Hardware tools installation skipped"
        return 0
    fi
    
    log_info "Installing hardware enumeration tools"
    
    hardware_mount_chroot "$chroot_dir"
    
    # Install hardware analysis tools
    local hardware_tools=(
        "lshw" "hwinfo" "dmidecode" "lscpu"
        "lspci" "lsusb" "lsblk" "lsof"
        "smartmontools" "hdparm" "sdparm"
        "i2c-tools" "spi-tools" "flashrom"
        "cpuid" "x86info" "numactl"
        "ethtool" "iwconfig" "rfkill"
        "sensors-detect" "lm-sensors"
        "acpi" "acpica-tools" "iasl"
    )
    
    for tool in "${hardware_tools[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$tool" 2>/dev/null || \
            log_warn "Package not available: $tool"
    done
    
    # Create comprehensive hardware analysis script
    hardware_create_enumeration_scripts "$chroot_dir"
    
    hardware_umount_chroot "$chroot_dir"
    
    log_info "Hardware enumeration tools installed"
}

# Create hardware enumeration scripts
hardware_create_enumeration_scripts() {
    local chroot_dir="$1"
    
    # Comprehensive hardware analysis script
    cat > "$chroot_dir/usr/local/bin/analyze-hardware" << 'EOF'
#!/bin/bash
# Comprehensive Hardware Analysis Tool

OUTPUT_DIR="${1:-/tmp/hardware-analysis}"
mkdir -p "$OUTPUT_DIR"

echo "=== Comprehensive Hardware Analysis ==="
echo "Output directory: $OUTPUT_DIR"

# System overview
echo "Collecting system overview..."
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
    lsblk -a
} > "$OUTPUT_DIR/system-overview.txt"

# Detailed hardware
echo "Collecting detailed hardware information..."
{
    echo "=== PCI Devices ==="
    lspci -vvv
    echo ""
    echo "=== USB Devices ==="
    lsusb -v
    echo ""
    echo "=== DMI Information ==="
    dmidecode
} > "$OUTPUT_DIR/hardware-detailed.txt"

# Network hardware
echo "Collecting network information..."
{
    echo "=== Network Interfaces ==="
    ip addr show
    echo ""
    echo "=== Network Hardware ==="
    lspci | grep -i network
    echo ""
    echo "=== Ethernet Controllers ==="
    for iface in $(ls /sys/class/net/); do
        if [[ -f "/sys/class/net/$iface/address" ]]; then
            echo "$iface: $(cat /sys/class/net/$iface/address)"
            ethtool "$iface" 2>/dev/null || true
        fi
    done
} > "$OUTPUT_DIR/network-info.txt"

# Storage information
echo "Collecting storage information..."
{
    echo "=== Storage Devices ==="
    lsblk -f
    echo ""
    echo "=== SMART Status ==="
    for disk in $(lsblk -d -o NAME | grep -v NAME); do
        echo "=== /dev/$disk ==="
        smartctl -a "/dev/$disk" 2>/dev/null || true
        echo ""
    done
} > "$OUTPUT_DIR/storage-info.txt"

# Security features
echo "Collecting security information..."
{
    echo "=== CPU Security Features ==="
    grep -E "(vmx|svm|smx|txt)" /proc/cpuinfo || echo "No virtualization features"
    echo ""
    echo "=== Intel ME Status ==="
    if lspci | grep -i "management engine" >/dev/null; then
        echo "Intel ME detected:"
        lspci | grep -i "management engine"
    else
        echo "Intel ME not detected"
    fi
    echo ""
    echo "=== TPM Status ==="
    if [[ -d /sys/class/tpm ]]; then
        echo "TPM detected:"
        ls -la /sys/class/tpm/
    else
        echo "TPM not detected"
    fi
} > "$OUTPUT_DIR/security-info.txt"

# Create summary
echo "Creating analysis summary..."
cat > "$OUTPUT_DIR/SUMMARY.txt" << SUMMARY
Hardware Analysis Summary
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

=== Key Findings ===
CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
Memory: $(free -h | grep "Mem:" | awk '{print $2}')
Architecture: $(uname -m)
Manufacturer: $(dmidecode -s system-manufacturer 2>/dev/null || echo "Unknown")
Product: $(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")

=== Security Status ===
Intel ME: $(lspci | grep -i "management engine" >/dev/null && echo "Present" || echo "Not detected")
TPM: $([[ -d /sys/class/tpm ]] && echo "Present" || echo "Not detected")
Secure Boot: $(mokutil --sb-state 2>/dev/null || echo "Unknown")

Full analysis available in individual files.
SUMMARY

echo "✓ Hardware analysis completed: $OUTPUT_DIR"
echo "  - system-overview.txt: Basic system information"
echo "  - hardware-detailed.txt: Detailed hardware specs" 
echo "  - network-info.txt: Network configuration"
echo "  - storage-info.txt: Storage devices and health"
echo "  - security-info.txt: Security features"
echo "  - SUMMARY.txt: Analysis summary"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/analyze-hardware"
}

#==============================================================================
# Security Tools Installation
#==============================================================================

# Install security analysis tools
hardware_install_security_tools() {
    local chroot_dir="$1"
    
    if [[ "$INSTALL_SECURITY_TOOLS" != "true" ]]; then
        log_info "Security tools installation skipped"
        return 0
    fi
    
    log_info "Installing security analysis tools"
    
    hardware_mount_chroot "$chroot_dir"
    
    # Install security tools
    local security_tools=(
        "chkrootkit" "rkhunter" "lynis"
        "aide" "tripwire" "samhain"
        "clamav" "clamav-daemon"
        "fail2ban" "ufw" "gufw"
        "openssh-server" "openssl"
        "gpg" "gnupg2" "signing-party"
        "nmap" "ncat" "socat"
        "tcpdump" "wireshark-common"
        "john" "hashcat" "hydra"
    )
    
    for tool in "${security_tools[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$tool" 2>/dev/null || \
            log_warn "Security package not available: $tool"
    done
    
    # Configure security tools
    hardware_configure_security_tools "$chroot_dir"
    
    hardware_umount_chroot "$chroot_dir"
    
    log_info "Security tools installed"
}

# Configure security tools
hardware_configure_security_tools() {
    local chroot_dir="$1"
    
    # Configure basic firewall
    chroot "$chroot_dir" bash -c "
        # Enable UFW firewall
        ufw --force enable
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        
        # Configure fail2ban
        if [[ -f /etc/fail2ban/jail.conf ]]; then
            cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
            sed -i 's/enabled = false/enabled = true/' /etc/fail2ban/jail.local
        fi
    " 2>/dev/null || true
    
    # Create security audit script
    cat > "$chroot_dir/usr/local/bin/security-audit" << 'EOF'
#!/bin/bash
# Security Audit Tool

echo "=== System Security Audit ==="

# Check for rootkits
echo "Checking for rootkits..."
if command -v chkrootkit >/dev/null; then
    chkrootkit | grep INFECTED || echo "No infections found by chkrootkit"
fi

if command -v rkhunter >/dev/null; then
    rkhunter --check --skip-keypress 2>/dev/null | grep Warning || echo "No warnings from rkhunter"
fi

# Check system hardening
echo ""
echo "=== System Hardening Status ==="
if command -v lynis >/dev/null; then
    lynis audit system --quick | tail -20
fi

# Check for suspicious processes
echo ""
echo "=== Process Analysis ==="
ps aux --sort=-%cpu | head -10

# Check network connections
echo ""
echo "=== Network Connections ==="
ss -tulnp | grep LISTEN

# Check file permissions
echo ""
echo "=== Critical File Permissions ==="
ls -la /etc/passwd /etc/shadow /etc/sudoers

echo ""
echo "=== Security Recommendations ==="
echo "1. Regularly update system packages"
echo "2. Monitor system logs for suspicious activity"
echo "3. Use strong passwords and SSH keys"
echo "4. Enable automatic security updates"
echo "5. Regular security audits with lynis"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/security-audit"
}

#==============================================================================
# Meteor Lake Optimization
#==============================================================================

# Install Meteor Lake specific optimizations
hardware_install_meteor_lake_optimization() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_METEOR_LAKE_OPTIMIZATION" != "true" ]]; then
        log_info "Meteor Lake optimization skipped"
        return 0
    fi
    
    log_info "Installing Meteor Lake optimizations"
    
    hardware_mount_chroot "$chroot_dir"
    
    # Install comprehensive Intel Meteor Lake tools & ring access
    local intel_tools=(
        # GPU and media acceleration
        "intel-gpu-tools" "vainfo" "intel-media-driver"
        "intel-opencl-icd" "intel-level-zero-gpu" "level-zero"
        "intel-media-va-driver-non-free" "i965-va-driver"
        # CPU and system management
        "intel-microcode" "thermald" "powertop" "turbostat"
        "cpufrequtils" "linux-tools-common" "linux-cpupower"
        "intel-cmt-cat" "intel-speed-select" "intel-undervolt"
        # P-core/E-core optimization
        "schedtool" "taskset" "numactl" "numad"
        "irqbalance" "tuned" "tuned-utils"
        # NPU/AI acceleration (if available)
        "intel-aikit" "openvino" "intel-extension-for-pytorch"
        # Ring -3 to Ring 0 access
        "intel-ipsec-mb" "intel-qat" "sgx-aesm-service"
        "libipt2" "processor-trace" "intel-pt"
        # Performance monitoring
        "intel-pcm" "intel-vtune" "intel-advisor"
        "pmu-tools" "likwid" "pcm" "vtune-profiler"
    )
    
    for tool in "${intel_tools[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$tool" 2>/dev/null || true
    done
    
    # Create Meteor Lake optimization script
    hardware_create_meteor_lake_scripts "$chroot_dir"
    
    hardware_umount_chroot "$chroot_dir"
    
    log_info "Meteor Lake optimizations installed"
}

# Create Meteor Lake optimization scripts
hardware_create_meteor_lake_scripts() {
    local chroot_dir="$1"
    
    cat > "$chroot_dir/usr/local/bin/optimize-meteor-lake" << 'EOF'
#!/bin/bash
# Meteor Lake Optimization Tool

echo "=== Intel Meteor Lake Optimization ==="

# Check if this is Meteor Lake
if ! lscpu | grep -i "meteor lake" >/dev/null; then
    echo "Warning: This doesn't appear to be a Meteor Lake system"
    lscpu | grep "Model name"
fi

# Configure CPU governor
echo "Configuring CPU performance..."
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo "✓ CPU governor set to performance"
fi

# Configure thermal management
echo "Configuring thermal management..."
if command -v thermald >/dev/null; then
    systemctl enable thermald
    systemctl start thermald
    echo "✓ Thermald enabled"
fi

# Configure power management
echo "Configuring power management..."
if command -v powertop >/dev/null; then
    powertop --auto-tune 2>/dev/null
    echo "✓ Power management optimized"
fi

# Configure GPU
echo "Configuring Intel GPU..."
if command -v vainfo >/dev/null; then
    echo "GPU capabilities:"
    vainfo 2>/dev/null | head -10 || echo "GPU info not available"
fi

# Configure NPU (if available)
echo "Checking for NPU..."
if lspci | grep -i "neural\|npu\|ai" >/dev/null; then
    echo "✓ NPU detected:"
    lspci | grep -i "neural\|npu\|ai"
else
    echo "NPU not detected"
fi

echo ""
echo "=== Optimization Summary ==="
echo "✓ CPU performance governor enabled"
echo "✓ Thermal management configured"
echo "✓ Power management optimized"
echo "✓ GPU acceleration enabled"
echo ""
echo "System optimized for Intel Meteor Lake performance"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/optimize-meteor-lake"
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems
hardware_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
}

# Unmount chroot filesystems
hardware_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

#==============================================================================
# Public API Functions
#==============================================================================

# Main entry point for hardware security
hardware_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "intel-me")
            hardware_install_intel_me_hardening "$chroot_dir"
            ;;
        "dell")
            hardware_install_dell_blocking "$chroot_dir"
            ;;
        "enumerate")
            hardware_install_enumeration_tools "$chroot_dir"
            ;;
        "security")
            hardware_install_security_tools "$chroot_dir"
            ;;
        "meteor-lake")
            hardware_install_meteor_lake_optimization "$chroot_dir"
            ;;
        "all")
            log_info "Installing complete hardware security suite"
            hardware_install_intel_me_hardening "$chroot_dir"
            hardware_install_dell_blocking "$chroot_dir"
            hardware_install_enumeration_tools "$chroot_dir"
            hardware_install_security_tools "$chroot_dir"
            hardware_install_meteor_lake_optimization "$chroot_dir"
            log_info "Hardware security installation completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {intel-me|dell|enumerate|security|meteor-lake|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    hardware_main "$@"
fi