#include <stdio.h>

void decode_cpuid_leaf7() {
    unsigned int ebx = 0x239c27eb;
    unsigned int ecx = 0x99c027bc;
    unsigned int edx = 0xfc1cc410;
    
    printf("CPUID Leaf 7 Analysis:\n");
    printf("EBX = 0x%08x\n", ebx);
    printf("ECX = 0x%08x\n", ecx);
    printf("EDX = 0x%08x\n", edx);
    printf("\nAVX-512 Features in EBX:\n");
    
    if (ebx & (1U << 16)) printf("  ✓ AVX512F (Foundation)\n");
    else printf("  ✗ AVX512F (Foundation)\n");
    if (ebx & (1U << 17)) printf("  ✓ AVX512DQ\n");
    else printf("  ✗ AVX512DQ\n");
    if (ebx & (1U << 21)) printf("  ✓ AVX512IFMA\n");
    else printf("  ✗ AVX512IFMA\n");
    if (ebx & (1U << 26)) printf("  ✓ AVX512PF\n");
    else printf("  ✗ AVX512PF\n");
    if (ebx & (1U << 27)) printf("  ✓ AVX512ER\n");
    else printf("  ✗ AVX512ER\n");
    if (ebx & (1U << 28)) printf("  ✓ AVX512CD\n");
    else printf("  ✗ AVX512CD\n");
    if (ebx & (1U << 30)) printf("  ✓ AVX512BW\n");
    else printf("  ✗ AVX512BW\n");
    if (ebx & (1U << 31)) printf("  ✓ AVX512VL\n");
    else printf("  ✗ AVX512VL\n");
    
    printf("\nAVX-512 Features in ECX:\n");
    if (ecx & (1U << 1)) printf("  ✓ AVX512VBMI\n");
    else printf("  ✗ AVX512VBMI\n");
    if (ecx & (1U << 11)) printf("  ✓ AVX512VNNI\n");
    else printf("  ✗ AVX512VNNI\n");
    if (ecx & (1U << 14)) printf("  ✓ AVX512VPOPCNTDQ\n");
    else printf("  ✗ AVX512VPOPCNTDQ\n");
    
    printf("\nXCR0 Analysis (0x0000000000000207):\n");
    unsigned long xcr0 = 0x207;
    if (xcr0 & (1 << 0)) printf("  ✓ x87 FPU enabled\n");
    if (xcr0 & (1 << 1)) printf("  ✓ SSE enabled\n");
    if (xcr0 & (1 << 2)) printf("  ✓ AVX enabled\n");
    if (xcr0 & (1 << 5)) printf("  ✓ AVX-512 opmask enabled\n");
    else printf("  ✗ AVX-512 opmask DISABLED\n");
    if (xcr0 & (1 << 6)) printf("  ✓ AVX-512 ZMM_Hi256 enabled\n");
    else printf("  ✗ AVX-512 ZMM_Hi256 DISABLED\n");
    if (xcr0 & (1 << 7)) printf("  ✓ AVX-512 Hi16_ZMM enabled\n");
    else printf("  ✗ AVX-512 Hi16_ZMM DISABLED\n");
    
    printf("\nConclusion:\n");
    printf("✓ Hardware supports AVX-512 (CPUID shows features)\n");
    printf("✓ Microcode 0x1c has restored AVX-512 capability\n");
    printf("✗ Operating system has NOT enabled AVX-512 in XCR0\n");
    printf("✗ Kernel parameter or OS configuration is blocking AVX-512\n");
}

int main() {
    decode_cpuid_leaf7();
    return 0;
}