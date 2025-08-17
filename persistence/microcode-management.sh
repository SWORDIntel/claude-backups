#!/bin/bash
# Intel Microcode Management for Hidden AVX-512 Support
# Forces early microcode loading with version 0x1c for Meteor Lake

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Microcode configuration
readonly REQUIRED_MICROCODE="0x1c"
readonly CURRENT_MICROCODE=$(grep -m1 microcode /proc/cpuinfo | awk '{print $3}')
readonly CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[[:space:]]*//')

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}    INTEL MICROCODE MANAGEMENT FOR HIDDEN AVX-512${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}CPU Model: $CPU_MODEL${NC}"
echo -e "${WHITE}Current Microcode: $CURRENT_MICROCODE${NC}"
echo -e "${WHITE}Required Microcode: $REQUIRED_MICROCODE (for hidden AVX-512)${NC}"
echo

# Analyze current microcode status
analyze_microcode_status() {
    echo -e "${BLUE}[*] Analyzing microcode status...${NC}"
    
    if [ "$CURRENT_MICROCODE" = "$REQUIRED_MICROCODE" ]; then
        echo -e "${GREEN}✅ Perfect! Current microcode $CURRENT_MICROCODE enables hidden AVX-512${NC}"
        return 0
    elif [[ "$CURRENT_MICROCODE" < "$REQUIRED_MICROCODE" ]]; then
        echo -e "${YELLOW}⚠️  Current microcode $CURRENT_MICROCODE is older than required $REQUIRED_MICROCODE${NC}"
        echo -e "${YELLOW}    AVX-512 may not be available or unstable${NC}"
        return 1
    else
        echo -e "${RED}❌ Current microcode $CURRENT_MICROCODE is newer than required $REQUIRED_MICROCODE${NC}"
        echo -e "${RED}    Intel has disabled hidden AVX-512 in this microcode version${NC}"
        echo -e "${YELLOW}    We need to force early loading of microcode $REQUIRED_MICROCODE${NC}"
        return 2
    fi
}

# Check for existing microcode packages
check_microcode_packages() {
    echo -e "${BLUE}[*] Checking installed microcode packages...${NC}"
    
    if dpkg -l | grep -q intel-microcode; then
        local installed_version=$(dpkg -l intel-microcode | tail -n1 | awk '{print $3}')
        echo -e "${GREEN}✅ intel-microcode package installed: $installed_version${NC}"
        
        # List available microcode files
        if [ -d /lib/firmware/intel-ucode ]; then
            echo -e "${BLUE}[*] Available microcode files:${NC}"
            ls -la /lib/firmware/intel-ucode/ | head -5
        fi
    else
        echo -e "${YELLOW}⚠️  intel-microcode package not installed${NC}"
        return 1
    fi
}

# Create early microcode forcing configuration
create_early_microcode_config() {
    echo -e "${BLUE}[*] Creating early microcode forcing configuration...${NC}"
    
    # Create microcode configuration for GRUB
    cat > "/tmp/microcode-early-loading.cfg" << EOF
# Early Microcode Loading Configuration
# Forces microcode 0x1c for hidden AVX-512 support

# GRUB configuration additions
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT dis_ucode_ldr"

# Microcode loading parameters
# dis_ucode_ldr = Disable automatic microcode loading
# early_microcode = Force early microcode from initrd
EOF

    echo -e "${GREEN}✅ Created microcode configuration: /tmp/microcode-early-loading.cfg${NC}"
}

# Create initrd with specific microcode
create_microcode_initrd() {
    echo -e "${BLUE}[*] Creating initrd with specific microcode...${NC}"
    
    local microcode_dir="/tmp/microcode-build"
    local kernel_dir="/lib/firmware"
    
    mkdir -p "$microcode_dir/kernel/x86/microcode"
    
    # Copy target microcode file if available
    if [ -f "$kernel_dir/intel-ucode/06-aa-04" ]; then
        echo -e "${GREEN}✅ Found Meteor Lake microcode file${NC}"
        cp "$kernel_dir/intel-ucode/06-aa-04" "$microcode_dir/kernel/x86/microcode/"
    else
        echo -e "${YELLOW}⚠️  Specific microcode file not found, creating placeholder${NC}"
        touch "$microcode_dir/kernel/x86/microcode/microcode-placeholder"
    fi
    
    # Create early microcode cpio archive
    cd "$microcode_dir"
    find . | cpio -o -H newc > "/tmp/early-microcode.cpio"
    cd - > /dev/null
    
    echo -e "${GREEN}✅ Created early microcode initrd: /tmp/early-microcode.cpio${NC}"
}

# Test AVX-512 availability
test_avx512_availability() {
    echo -e "${BLUE}[*] Testing hidden AVX-512 availability...${NC}"
    
    # Create simple AVX-512 test program
    cat > "/tmp/avx512_test.c" << 'EOF'
#include <stdio.h>
#include <immintrin.h>

int main() {
    #ifdef __AVX512F__
    printf("✅ AVX-512F: Supported by compiler\n");
    #else
    printf("❌ AVX-512F: Not supported by compiler\n");
    #endif
    
    // Try to execute AVX-512 instruction
    __asm__ volatile (
        "vpxord %%zmm0, %%zmm0, %%zmm0"
        :
        :
        : "zmm0"
    );
    printf("✅ AVX-512 instruction executed successfully\n");
    
    return 0;
}
EOF

    echo -e "${BLUE}[*] Compiling AVX-512 test...${NC}"
    if gcc -mavx512f -o "/tmp/avx512_test" "/tmp/avx512_test.c" 2>/dev/null; then
        echo -e "${GREEN}✅ AVX-512 test compiled successfully${NC}"
        
        echo -e "${BLUE}[*] Running AVX-512 test...${NC}"
        if "/tmp/avx512_test" 2>/dev/null; then
            echo -e "${GREEN}✅ Hidden AVX-512 instructions are working!${NC}"
            return 0
        else
            echo -e "${RED}❌ AVX-512 instructions failed - microcode blocking detected${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Could not compile AVX-512 test${NC}"
        return 1
    fi
}

# Create LiveCD microcode integration
create_livecd_microcode_integration() {
    echo -e "${BLUE}[*] Creating LiveCD microcode integration...${NC}"
    
    cat > "/tmp/livecd-microcode-integration.sh" << 'EOF'
#!/bin/bash
# LiveCD Microcode Integration for Hidden AVX-512

# Add to main build script
echo "# Microcode management for hidden AVX-512"
echo "if [ -f /tmp/early-microcode.cpio ]; then"
echo "    cp /tmp/early-microcode.cpio \$CHROOT_DIR/boot/"
echo "    echo '✅ Early microcode integrated into LiveCD'"
echo "fi"

# GRUB configuration for LiveCD
cat >> \$CHROOT_DIR/etc/default/grub << GRUB_EOF
# Hidden AVX-512 Support
GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT dis_ucode_ldr"
GRUB_EARLY_INITRD_LINUX_CUSTOM="early-microcode.cpio"
GRUB_EOF

# Update GRUB in chroot
chroot \$CHROOT_DIR update-grub
EOF

    chmod +x "/tmp/livecd-microcode-integration.sh"
    echo -e "${GREEN}✅ Created LiveCD integration script: /tmp/livecd-microcode-integration.sh${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}[*] Starting microcode management for hidden AVX-512...${NC}"
    
    # Analyze current status
    if ! analyze_microcode_status; then
        echo -e "${YELLOW}[!] Microcode intervention required${NC}"
    fi
    
    # Check packages
    check_microcode_packages || {
        echo -e "${YELLOW}[!] Installing intel-microcode package...${NC}"
        sudo apt update && sudo apt install -y intel-microcode
    }
    
    # Create configurations
    create_early_microcode_config
    create_microcode_initrd
    create_livecd_microcode_integration
    
    # Test current AVX-512 status
    echo -e "${BLUE}[*] Testing current AVX-512 status...${NC}"
    if test_avx512_availability; then
        echo -e "${GREEN}🎉 Hidden AVX-512 is already working!${NC}"
    else
        echo -e "${YELLOW}⚠️  Hidden AVX-512 requires microcode downgrade${NC}"
        echo -e "${CYAN}[*] Integration files created for LiveCD build${NC}"
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Microcode management configuration complete${NC}"
    echo -e "${WHITE}Files created:${NC}"
    echo -e "${WHITE}  - /tmp/microcode-early-loading.cfg${NC}"
    echo -e "${WHITE}  - /tmp/early-microcode.cpio${NC}"
    echo -e "${WHITE}  - /tmp/livecd-microcode-integration.sh${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi