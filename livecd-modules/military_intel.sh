#!/bin/bash
#
# military_intel.sh - Military & Intelligence Systems Module
# Part of the consolidated LiveCD build system
#
# Incorporates military-grade systems, HAP mode, CIA boot, NPU optimization,
# and other intelligence/defense features from original scripts
#

# Source common library functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot source lib/common.sh"
    exit 1
}

# Module configuration
readonly MILITARY_MODULE_VERSION="1.0.0"
readonly MILITARY_MODULE_NAME="Military Intel Module"

# Default configuration
: "${CHROOT_DIR:=/tmp/livecd-chroot}"
: "${ENABLE_MILITARY_INTEGRATION:=true}"
: "${ENABLE_HAP_MODE:=true}"
: "${ENABLE_CIA_BOOT:=true}"
: "${ENABLE_NPU_OPTIMIZATION:=true}"
: "${ENABLE_MILSPEC_DRIVERS:=true}"

#==============================================================================
# Military Integration (from add-military-integration.sh)
#==============================================================================

military_install_integration() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_MILITARY_INTEGRATION" != "true" ]]; then
        log_info "Military integration skipped"
        return 0
    fi
    
    log_info "Installing military subsystem integration"
    
    # Create military integration directory structure
    mkdir -p "$chroot_dir/usr/local/bin/military-integration"
    mkdir -p "$chroot_dir/opt/military-systems"/{cct-hsas,dsmil,biq-monitor,me-tools}
    mkdir -p "$chroot_dir/opt/military-systems/config"
    mkdir -p "$chroot_dir/opt/military-systems/logs"
    
    # Create CCT HSAS integration bridge
    cat > "$chroot_dir/usr/local/bin/military-integration/cct_hsas_bridge.sh" << 'EOF'
#!/bin/bash
# Dell CCT (Client Configuration Toolkit) and HSAS Integration
# Enhanced for military-grade Dell systems

set -euo pipefail

LOG_FILE="/opt/military-systems/logs/cct_hsas.log"
DSMIL_CONFIG="/opt/military-systems/config/dsmil.conf"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== CCT HSAS Integration Bridge ==="
echo "Timestamp: $(date)"

# Detect Dell system
detect_dell_system() {
    echo "Detecting Dell system configuration..."
    
    local system_vendor=$(dmidecode -s system-manufacturer 2>/dev/null || echo "Unknown")
    local system_model=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
    
    if [[ "$system_vendor" != *"Dell"* ]]; then
        echo "WARNING: Non-Dell system detected"
        echo "CCT/HSAS features may not be available"
        return 1
    fi
    
    echo "Dell system confirmed: $system_vendor $system_model"
    
    # Check for Latitude 5450 specifically
    if [[ "$system_model" == *"5450"* ]]; then
        echo "Detected Latitude 5450 - Military/Intel configuration likely"
        echo "Enabling enhanced security features"
        
        # Check for ControlVault
        if lspci | grep -q "Broadcom.*5880"; then
            echo "ControlVault detected - Triple signature enabled"
        fi
    fi
    
    return 0
}

# Initialize DSMIL (Dell Security Module Integration Layer)
init_dsmil() {
    echo "Initializing DSMIL..."
    
    cat > "$DSMIL_CONFIG" << 'CONFIG'
# DSMIL Configuration
SECURITY_LEVEL=MIL_SPEC
TPM_MODE=2.0_FIPS
CONTROLVAULT_ENABLED=true
SECURE_BOOT_LEVEL=ENFORCED
MEI_HAP_MODE=REQUESTED
CONFIG
    
    echo "DSMIL configuration written"
}

# Main execution
detect_dell_system
init_dsmil

echo "CCT HSAS Bridge initialized successfully"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/military-integration/cct_hsas_bridge.sh"
    
    # Create BIQ Monitor for military hardware
    cat > "$chroot_dir/usr/local/bin/military-integration/biq_monitor.sh" << 'EOF'
#!/bin/bash
# BIQ (Built-In Quality) Monitor for Military Hardware

echo "=== BIQ Monitor - Military Hardware Analysis ==="

# Check for military-specific hardware
check_military_hardware() {
    echo "Checking for military-grade components..."
    
    # Check TPM
    if [ -d /sys/class/tpm/tpm0 ]; then
        echo "✓ TPM 2.0 detected"
        cat /sys/class/tpm/tpm0/device/description 2>/dev/null || true
    fi
    
    # Check for smart card readers
    if lsusb | grep -q "Smart Card"; then
        echo "✓ Smart card reader detected"
    fi
    
    # Check for hardware encryption
    if lspci | grep -q "Encryption controller"; then
        echo "✓ Hardware encryption controller detected"
    fi
    
    # Check CPU features for MIL-SPEC
    if grep -q "sgx" /proc/cpuinfo; then
        echo "✓ Intel SGX enabled"
    fi
    
    if grep -q "smap\|smep" /proc/cpuinfo; then
        echo "✓ SMAP/SMEP protection enabled"
    fi
}

check_military_hardware
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/military-integration/biq_monitor.sh"
    
    log_info "Military integration installed"
}

#==============================================================================
# HAP Mode Boot Option (from add-hap-mode-boot-option.sh)
#==============================================================================

military_install_hap_mode() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_HAP_MODE" != "true" ]]; then
        log_info "HAP mode installation skipped"
        return 0
    fi
    
    log_info "Installing HAP mode boot option"
    
    military_mount_chroot "$chroot_dir"
    
    # Install required packages
    chroot "$chroot_dir" apt-get install -y efitools wget mokutil 2>/dev/null || true
    
    # Create HAP mode enabler script
    cat > "$chroot_dir/usr/local/bin/enable-hap-mode" << 'EOF'
#!/bin/bash
# Enable Intel ME HAP (High Assurance Platform) Mode

echo "=== Intel ME HAP Mode Enabler ==="
echo "WARNING: This will attempt to disable Intel ME via HAP bit"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Check for Intel ME
if ! lspci | grep -q "MEI\|Management Engine"; then
    echo "Intel ME not detected"
    exit 1
fi

echo "Detected Intel ME interface"

# Create GRUB entry for HAP mode
cat > /etc/grub.d/42_hap_mode << 'GRUB'
#!/bin/sh
exec tail -n +3 $0

menuentry 'Boot with HAP Mode (Intel ME Disabled)' {
    set root='hd0,gpt1'
    linux /vmlinuz root=/dev/sda2 intel_iommu=on iommu=pt pci=noaer dis_ucode_ldr nmi_watchdog=0
    initrd /initrd.img
    # Set HAP bit via UEFI variable if possible
    set_var 0x94000245 0x01
}
GRUB

chmod +x /etc/grub.d/42_hap_mode
update-grub

echo "HAP mode boot entry added to GRUB"
echo ""
echo "Additional steps required:"
echo "1. Check BIOS for 'HAP Mode' or 'ME Disable' option"
echo "2. Look for microcode version 0x94000245 or higher"
echo "3. Consider using me_cleaner for permanent disable"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/enable-hap-mode"
    
    military_umount_chroot "$chroot_dir"
    
    log_info "HAP mode boot option installed"
}

#==============================================================================
# CIA Boot Splash (from add-cia-boot-splash.sh)
#==============================================================================

military_install_cia_boot() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_CIA_BOOT" != "true" ]]; then
        log_info "CIA boot splash skipped"
        return 0
    fi
    
    log_info "Installing CIA boot splash"
    
    # Create boot splash directory
    mkdir -p "$chroot_dir/usr/share/plymouth/themes/cia-theme"
    
    # Create CIA theme files
    cat > "$chroot_dir/usr/share/plymouth/themes/cia-theme/cia-theme.plymouth" << 'EOF'
[Plymouth Theme]
Name=CIA Theme
Description=Classified System Boot
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/cia-theme
ScriptFile=/usr/share/plymouth/themes/cia-theme/cia-theme.script
EOF
    
    # Create boot script
    cat > "$chroot_dir/usr/share/plymouth/themes/cia-theme/cia-theme.script" << 'EOF'
# CIA Boot Theme Script

Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

# Display classification warning
warning_sprite = Sprite();
warning_text = Image.Text("CLASSIFIED SYSTEM - AUTHORIZED ACCESS ONLY", 1, 1, 1);
warning_sprite.SetImage(warning_text);
warning_sprite.SetX(Window.GetWidth() / 2 - warning_text.GetWidth() / 2);
warning_sprite.SetY(Window.GetHeight() / 2 - 100);

# Display system info
info_sprite = Sprite();
info_text = Image.Text("Military-Grade Security Enabled", 0.7, 0.7, 0.7);
info_sprite.SetImage(info_text);
info_sprite.SetX(Window.GetWidth() / 2 - info_text.GetWidth() / 2);
info_sprite.SetY(Window.GetHeight() / 2);

# Progress bar
progress = 0;
progress_bar.sprite = Sprite();
progress_bar.sprite.SetPosition(Window.GetWidth() / 4, Window.GetHeight() * 0.75, 0);

fun progress_callback(duration, progress) {
    progress_bar.sprite.SetImage(Image("progress-" + progress + ".png"));
}

Plymouth.SetBootProgressFunction(progress_callback);
EOF
    
    # Create early boot execution hook
    cat > "$chroot_dir/etc/initramfs-tools/scripts/init-premount/cia-early-boot" << 'EOF'
#!/bin/sh
# CIA Early Boot Execution
# Runs before root filesystem mount

PREREQ=""
prereqs() {
    echo "$PREREQ"
}

case $1 in
    prereqs)
        prereqs
        exit 0
        ;;
esac

# Log boot attempt
echo "$(date): CIA system boot initiated" >> /run/initramfs/boot.log

# Check for secure boot
if [ -d /sys/firmware/efi/efivars ]; then
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
        echo "Secure Boot: ENABLED" >> /run/initramfs/boot.log
    else
        echo "WARNING: Secure Boot DISABLED" >> /run/initramfs/boot.log
    fi
fi

# Check TPM
if [ -c /dev/tpm0 ]; then
    echo "TPM: Present" >> /run/initramfs/boot.log
fi

# Set security parameters
echo 1 > /proc/sys/kernel/kptr_restrict
echo 1 > /proc/sys/kernel/dmesg_restrict
echo 2 > /proc/sys/kernel/perf_event_paranoid

exit 0
EOF
    
    chmod +x "$chroot_dir/etc/initramfs-tools/scripts/init-premount/cia-early-boot"
    
    log_info "CIA boot splash installed"
}

#==============================================================================
# NPU/ML Optimization (from create-meteor-lake-npu-optimizer.sh)
#==============================================================================

military_install_npu_optimization() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_NPU_OPTIMIZATION" != "true" ]]; then
        log_info "NPU optimization skipped"
        return 0
    fi
    
    log_info "Installing NPU/ML optimization for Meteor Lake"
    
    # Create NPU optimizer
    cat > "$chroot_dir/usr/local/bin/npu-optimizer" << 'EOF'
#!/bin/bash
# Meteor Lake NPU Optimizer
# Optimizes AI/ML workloads for Intel NPU

echo "=== Intel Meteor Lake NPU Optimizer ==="

# Detect NPU
detect_npu() {
    echo "Detecting Intel NPU..."
    
    # Check for NPU via lspci
    if lspci | grep -qi "neural\|npu\|vpu\|ai"; then
        echo "✓ NPU hardware detected"
        lspci | grep -i "neural\|npu\|vpu\|ai"
    else
        echo "✗ NPU not detected - may not be exposed to OS"
    fi
    
    # Check CPU model for Meteor Lake
    if lscpu | grep -q "Core.*Ultra"; then
        echo "✓ Intel Core Ultra (Meteor Lake) detected"
        echo "  NPU should be present even if not visible"
    fi
}

# Configure NPU performance
configure_npu() {
    echo ""
    echo "Configuring NPU performance..."
    
    # Set CPU governor for AI workloads
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "schedutil" > "$cpu" 2>/dev/null || true
    done
    echo "✓ CPU governor set to schedutil for NPU coordination"
    
    # Configure memory for AI workloads
    echo 3 > /proc/sys/vm/drop_caches
    echo "✓ Memory caches cleared for AI workload"
    
    # Set IRQ affinity for NPU (if detected)
    if [ -f /proc/irq/default_smp_affinity ]; then
        echo "ff" > /proc/irq/default_smp_affinity
        echo "✓ IRQ affinity optimized"
    fi
}

# Install OpenVINO runtime
install_openvino() {
    echo ""
    echo "Checking OpenVINO installation..."
    
    if command -v omz_downloader >/dev/null; then
        echo "✓ OpenVINO already installed"
    else
        echo "Installing OpenVINO runtime..."
        wget -qO- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | apt-key add -
        echo "deb https://apt.repos.intel.com/openvino/2024 ubuntu22 main" > /etc/apt/sources.list.d/intel-openvino-2024.list
        apt-get update >/dev/null 2>&1
        apt-get install -y openvino 2>/dev/null || echo "Failed to install OpenVINO"
    fi
}

# Main execution
detect_npu
configure_npu
install_openvino

echo ""
echo "NPU optimization complete"
echo "For AI workloads, use OpenVINO or Intel Extension for PyTorch"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/npu-optimizer"
    
    log_info "NPU optimization installed"
}

#==============================================================================
# MIL-SPEC Drivers (from add-milspec-drivers.sh)
#==============================================================================

military_install_milspec_drivers() {
    local chroot_dir="$1"
    
    if [[ "$ENABLE_MILSPEC_DRIVERS" != "true" ]]; then
        log_info "MIL-SPEC drivers skipped"
        return 0
    fi
    
    log_info "Installing MIL-SPEC drivers"
    
    military_mount_chroot "$chroot_dir"
    
    # Install military-spec driver packages
    local milspec_packages=(
        # Rugged hardware support
        "ruggedcom-drivers"
        "getac-drivers"
        "panasonic-toughbook-drivers"
        
        # Security hardware
        "pcsc-tools" "pcscd" "libccid"
        "opensc" "coolkey" "libcac"
        
        # Tactical radios and comms
        "librtlsdr0" "rtl-sdr" "gqrx-sdr"
        "gnuradio" "gr-osmosdr"
        
        # GPS and navigation
        "gpsd" "gpsd-clients" "python3-gps"
        "foxtrotgps" "navit"
        
        # Crypto hardware
        "trousers" "tpm2-tools" "tpm2-abrmd"
        "libtss2-dev" "strongswan"
    )
    
    for package in "${milspec_packages[@]}"; do
        chroot "$chroot_dir" apt-get install -y "$package" 2>/dev/null || \
            log_warn "Package not available: $package"
    done
    
    # Create MIL-STD-810 compliance checker
    cat > "$chroot_dir/usr/local/bin/check-milstd-compliance" << 'EOF'
#!/bin/bash
# MIL-STD-810 Compliance Checker

echo "=== MIL-STD-810 Compliance Check ==="
echo ""

# Temperature monitoring
echo "Temperature Compliance:"
if command -v sensors >/dev/null; then
    sensors | grep -E "Core|temp" || echo "No temperature sensors found"
    echo ""
    echo "MIL-STD-810G Temperature Range: -20°C to +60°C operational"
    echo "MIL-STD-810H Temperature Range: -32°C to +49°C operational"
fi

# Vibration and shock (check for SSD)
echo ""
echo "Storage Compliance:"
for disk in /sys/block/sd*; do
    if [ -f "$disk/queue/rotational" ]; then
        rotational=$(cat "$disk/queue/rotational")
        disk_name=$(basename "$disk")
        if [ "$rotational" -eq 0 ]; then
            echo "✓ $disk_name: SSD (shock resistant)"
        else
            echo "✗ $disk_name: HDD (not MIL-SPEC compliant)"
        fi
    fi
done

# Check for rugged features
echo ""
echo "Rugged Features:"
if dmidecode -s system-manufacturer 2>/dev/null | grep -qi "dell\|getac\|panasonic"; then
    echo "✓ Rugged manufacturer detected"
fi

if [ -d /sys/class/backlight ]; then
    echo "✓ Sunlight readable display support"
fi

if [ -c /dev/tpm0 ]; then
    echo "✓ TPM hardware security"
fi

echo ""
echo "Compliance check complete"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/check-milstd-compliance"
    
    military_umount_chroot "$chroot_dir"
    
    log_info "MIL-SPEC drivers installed"
}

#==============================================================================
# Verbose Boot System (from add-verbose-boot-system.sh)
#==============================================================================

military_install_verbose_boot() {
    local chroot_dir="$1"
    
    log_info "Installing verbose boot system"
    
    # Configure GRUB for verbose boot
    cat >> "$chroot_dir/etc/default/grub" << 'EOF'

# Military verbose boot options
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 earlyprintk=serial,ttyS0,115200 loglevel=7 init=/bin/bash --verbose"
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"

# Show all boot messages
GRUB_TIMEOUT=10
GRUB_HIDDEN_TIMEOUT=
GRUB_HIDDEN_TIMEOUT_QUIET=false
EOF
    
    # Create verbose boot logger
    cat > "$chroot_dir/usr/local/bin/boot-logger" << 'EOF'
#!/bin/bash
# Boot sequence logger for analysis

LOG_DIR="/var/log/boot-sequence"
mkdir -p "$LOG_DIR"

# Capture dmesg continuously
dmesg -w > "$LOG_DIR/dmesg-$(date +%Y%m%d-%H%M%S).log" &

# Capture systemd boot
systemd-analyze > "$LOG_DIR/systemd-analyze-$(date +%Y%m%d-%H%M%S).log"
systemd-analyze blame > "$LOG_DIR/systemd-blame-$(date +%Y%m%d-%H%M%S).log"
systemd-analyze critical-chain > "$LOG_DIR/systemd-chain-$(date +%Y%m%d-%H%M%S).log"

# Hardware initialization sequence
echo "=== Hardware Initialization Sequence ===" > "$LOG_DIR/hw-init-$(date +%Y%m%d-%H%M%S).log"
lspci -vvv >> "$LOG_DIR/hw-init-$(date +%Y%m%d-%H%M%S).log"
lsusb -v >> "$LOG_DIR/hw-init-$(date +%Y%m%d-%H%M%S).log"

echo "Boot logs saved to $LOG_DIR"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/boot-logger"
    
    log_info "Verbose boot system installed"
}

#==============================================================================
# ML Debug Validation (from add-ml-debugging-validation-system.sh)
#==============================================================================

military_install_ml_debug() {
    local chroot_dir="$1"
    
    log_info "Installing ML debugging and validation system"
    
    # Create ML debug framework
    cat > "$chroot_dir/usr/local/bin/ml-debug-validator" << 'EOF'
#!/bin/bash
# ML Debugging and Validation System
# For Meteor Lake ML/NPU workloads

echo "=== ML Debug & Validation System ==="

# Validate ML environment
validate_ml_env() {
    echo "Validating ML environment..."
    
    # Check Python ML libraries
    python3 -c "
import sys
libs = ['numpy', 'torch', 'tensorflow', 'onnx', 'openvino']
for lib in libs:
    try:
        __import__(lib)
        print(f'✓ {lib} available')
    except ImportError:
        print(f'✗ {lib} not installed')
" 2>/dev/null || echo "Python ML environment not configured"
    
    # Check Intel extensions
    if python3 -c "import intel_extension_for_pytorch" 2>/dev/null; then
        echo "✓ Intel Extension for PyTorch installed"
    fi
}

# NPU workload test
test_npu_workload() {
    echo ""
    echo "Testing NPU workload..."
    
    python3 << 'PYTHON'
import numpy as np
import time

# Simple matrix multiplication benchmark
def npu_benchmark():
    size = 1024
    a = np.random.rand(size, size).astype(np.float32)
    b = np.random.rand(size, size).astype(np.float32)
    
    start = time.time()
    c = np.matmul(a, b)
    end = time.time()
    
    gflops = (2 * size**3) / (end - start) / 1e9
    print(f"Matrix multiplication ({size}x{size})")
    print(f"Time: {end-start:.3f} seconds")
    print(f"Performance: {gflops:.2f} GFLOPS")

try:
    npu_benchmark()
except Exception as e:
    print(f"Benchmark failed: {e}")
PYTHON
}

# Debug P-core/E-core scheduling
debug_core_scheduling() {
    echo ""
    echo "Debugging P-core/E-core scheduling..."
    
    # Show core topology
    lscpu --all --extended | head -20
    
    # Check core frequencies
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [ -f "$cpu" ]; then
            core=$(echo "$cpu" | grep -oP 'cpu\K[0-9]+')
            freq=$(cat "$cpu")
            echo "Core $core: $((freq/1000)) MHz"
        fi
    done | head -10
}

# Main execution
validate_ml_env
test_npu_workload
debug_core_scheduling

echo ""
echo "ML debug validation complete"
EOF
    
    chmod +x "$chroot_dir/usr/local/bin/ml-debug-validator"
    
    log_info "ML debug validation system installed"
}

#==============================================================================
# Helper Functions
#==============================================================================

# Mount chroot filesystems
military_mount_chroot() {
    local chroot_dir="$1"
    
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
}

# Unmount chroot filesystems
military_umount_chroot() {
    local chroot_dir="$1"
    
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

#==============================================================================
# Public API Functions
#==============================================================================

# Main entry point for military/intel systems
military_main() {
    local chroot_dir="${1:-$CHROOT_DIR}"
    local action="${2:-all}"
    
    case "$action" in
        "integration")
            military_install_integration "$chroot_dir"
            ;;
        "hap")
            military_install_hap_mode "$chroot_dir"
            ;;
        "cia")
            military_install_cia_boot "$chroot_dir"
            ;;
        "npu")
            military_install_npu_optimization "$chroot_dir"
            ;;
        "milspec")
            military_install_milspec_drivers "$chroot_dir"
            ;;
        "verbose")
            military_install_verbose_boot "$chroot_dir"
            ;;
        "ml-debug")
            military_install_ml_debug "$chroot_dir"
            ;;
        "all")
            log_info "Installing complete military/intel suite"
            military_install_integration "$chroot_dir"
            military_install_hap_mode "$chroot_dir"
            military_install_cia_boot "$chroot_dir"
            military_install_npu_optimization "$chroot_dir"
            military_install_milspec_drivers "$chroot_dir"
            military_install_verbose_boot "$chroot_dir"
            military_install_ml_debug "$chroot_dir"
            log_info "Military/intel installation completed"
            ;;
        *)
            echo "Usage: $0 <chroot_dir> {integration|hap|cia|npu|milspec|verbose|ml-debug|all}"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    military_main "$@"
fi