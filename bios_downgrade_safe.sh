#!/bin/bash
# SAFE BIOS Downgrade Script - Dell Latitude 5450
# Target: Version 1.11.2 (December 19, 2024)
# Version: 2.0 - With comprehensive safety checks

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TARGET_BIOS="1.11.2"
BACKUP_DIR="$HOME/bios_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$BACKUP_DIR/downgrade.log"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

check_hardware() {
    log "Checking hardware compatibility..."
    
    # Verify Dell Latitude 5450
    local product_name=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
    if [[ "$product_name" != *"Latitude 5450"* ]]; then
        error_exit "This script is only for Dell Latitude 5450 (found: $product_name)"
    fi
    success "Hardware verified: $product_name"
}

check_dependencies() {
    log "Checking required tools..."
    
    local deps=("fwupdmgr" "dmidecode" "grep" "awk")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "Required command '$cmd' not found. Please install it."
        fi
    done
    success "All required tools found"
}

check_power() {
    log "Checking power status..."
    
    # Check if on AC power
    local ac_status="/sys/class/power_supply/AC*/online"
    if [[ -e $ac_status ]]; then
        if [[ $(cat $ac_status 2>/dev/null) != "1" ]]; then
            error_exit "AC adapter not connected! BIOS update requires AC power."
        fi
    else
        warning "Could not verify AC power status. Ensure AC adapter is connected!"
        read -p "Is AC adapter connected? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && error_exit "AC power required for BIOS update"
    fi
    
    # Check battery level
    local battery_level=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo "0")
    if [[ $battery_level -lt 25 ]]; then
        error_exit "Battery level too low ($battery_level%). Need at least 25%."
    fi
    success "Power status OK (Battery: $battery_level%, AC connected)"
}

backup_current_state() {
    log "Creating backup directory..."
    mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"
    
    log "Backing up current BIOS information..."
    dmidecode > "$BACKUP_DIR/dmidecode_full.txt" 2>/dev/null || warning "dmidecode backup failed"
    
    # Save current BIOS version
    local current_bios=$(dmidecode -s bios-version 2>/dev/null || echo "Unknown")
    echo "$current_bios" > "$BACKUP_DIR/current_bios_version.txt"
    log "Current BIOS version: $current_bios"
    
    # Save firmware device info
    fwupdmgr get-devices > "$BACKUP_DIR/fwupd_devices.txt" 2>/dev/null || warning "fwupd device backup failed"
    
    success "Backup created in $BACKUP_DIR"
}

verify_target_available() {
    log "Checking if BIOS $TARGET_BIOS is available..."
    
    # Get available versions
    local available_versions=$(fwupdmgr get-releases 2>/dev/null | grep "New version:" | awk '{print $3}' || echo "")
    
    if [[ -z "$available_versions" ]]; then
        error_exit "Could not retrieve available BIOS versions"
    fi
    
    if ! echo "$available_versions" | grep -q "^${TARGET_BIOS}$"; then
        error_exit "Target BIOS version $TARGET_BIOS not available. Available versions: $(echo $available_versions | tr '\n' ' ')"
    fi
    
    success "BIOS version $TARGET_BIOS is available for downgrade"
}

get_target_option_number() {
    log "Finding option number for BIOS $TARGET_BIOS..."
    
    # This would need to parse fwupdmgr output to find the right option
    # For now, we'll inform the user
    warning "You will need to manually select the option for version $TARGET_BIOS"
    echo ""
    echo "When prompted, look for version $TARGET_BIOS in the list"
    echo "It should be option 3 based on previous analysis"
    echo ""
}

confirm_action() {
    echo ""
    echo "========================================"
    echo "BIOS DOWNGRADE CONFIRMATION"
    echo "========================================"
    echo "Target Version: $TARGET_BIOS"
    echo "Backup Location: $BACKUP_DIR"
    echo ""
    echo -e "${YELLOW}WARNING: This will modify system firmware!${NC}"
    echo "- System will reboot automatically"
    echo "- Process takes ~10 minutes"
    echo "- Do NOT interrupt the process"
    echo "- Ensure AC power remains connected"
    echo ""
    read -p "Type 'DOWNGRADE' to proceed or anything else to cancel: " confirm
    
    if [[ "$confirm" != "DOWNGRADE" ]]; then
        log "User cancelled downgrade"
        echo "Downgrade cancelled."
        exit 0
    fi
}

perform_downgrade() {
    log "Starting BIOS downgrade process..."
    
    echo ""
    echo "Launching fwupdmgr downgrade..."
    echo -e "${YELLOW}IMPORTANT: Select version $TARGET_BIOS when prompted!${NC}"
    echo ""
    
    # Execute downgrade with error handling
    if ! fwupdmgr downgrade 2>&1 | tee -a "$LOG_FILE"; then
        error_exit "BIOS downgrade failed! Check $LOG_FILE for details"
    fi
    
    success "BIOS downgrade initiated successfully"
}

post_downgrade_instructions() {
    echo ""
    echo "========================================"
    echo "POST-DOWNGRADE INSTRUCTIONS"
    echo "========================================"
    echo ""
    echo "After reboot, run these verification commands:"
    echo ""
    echo "1. Check new BIOS version:"
    echo "   sudo dmidecode -s bios-version"
    echo ""
    echo "2. Check microcode version:"
    echo "   grep microcode /proc/cpuinfo | head -1"
    echo ""
    echo "3. Test AVX-512 support:"
    echo "   sudo rdmsr -p 0 0x771"
    echo "   (Check if bit 1 is cleared)"
    echo ""
    echo "4. Verify system stability:"
    echo "   dmesg | grep -i error"
    echo ""
    echo "Log file saved to: $LOG_FILE"
}

# Main execution
main() {
    echo "========================================"
    echo "SAFE BIOS DOWNGRADE SCRIPT v2.0"
    echo "========================================"
    echo ""
    
    # Create backup directory first for logging
    mkdir -p "$BACKUP_DIR" 2>/dev/null || error_exit "Cannot create backup directory"
    
    log "Starting BIOS downgrade safety checks..."
    
    # Run all safety checks
    check_root
    check_hardware
    check_dependencies
    check_power
    backup_current_state
    verify_target_available
    get_target_option_number
    
    # Get user confirmation
    confirm_action
    
    # Perform the downgrade
    perform_downgrade
    
    # Show post-downgrade instructions
    post_downgrade_instructions
    
    log "Script completed successfully"
}

# Run main function
main "$@"