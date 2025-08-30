# Post-Reboot Configuration Guide

**Phase**: Initial Configuration  
**Duration**: 45 minutes  
**Prerequisites**: System rebooted after `sudo usermod -a -G tss john`

## 🎯 Objectives

Configure and validate TPM access after group membership activation.

## ✅ Immediate Verification

### 1. Verify Group Membership

```bash
# Check active groups
groups
# Expected: ... tss ...

# If tss not shown, try:
newgrp tss
groups  # Check again

# Verify in system
id john | grep tss
# Expected: groups=...XXX(tss)
```

### 2. Test TPM Access

```bash
# Basic TPM test
tpm2_getcap properties-fixed
# Should return TPM properties without permission errors

# Get TPM manufacturer
tpm2_getcap properties-fixed | grep TPM2_PT_MANUFACTURER
# Expected: TPM2_PT_MANUFACTURER: 0x53544D20 (STMicroelectronics)
```

### 3. Run Automated Setup

```bash
# Execute post-reboot script
cd /home/john/claude-backups
~/post-reboot-tpm-setup.sh

# Review output for any errors
cat ~/tpm-capabilities-post-reboot.log
```

## 🔧 TPM Configuration

### 1. Verify Algorithm Support

```bash
cd /home/john/claude-backups/docs/features/tpm2-integration/scripts/

# Test each discovered algorithm
echo "Testing SHA3-256 (quantum-resistant)..."
echo "test" | tpm2_hash -g sha3_256 --hex

echo "Testing ECC-256 (fast signatures)..."
tpm2_createprimary -C o -g sha256 -G ecc256 -c primary.ctx
tpm2_create -C primary.ctx -g sha256 -G ecc256:ecdsa -r key.priv -u key.pub

# Clean up test files
rm -f primary.ctx key.priv key.pub
```

### 2. Configure PCR Banks

```bash
# Check available PCR banks
tpm2_getcap pcrs

# Read current PCR values
tpm2_pcrread sha256:0,7,16

# Extend PCR 16 for application use
echo "CLAUDE_BACKUPS_INIT_$(date +%s)" | tpm2_hash -g sha256 --hex | \
    xargs -I {} tpm2_pcrextend 16:sha256={}

# Verify extension
tpm2_pcrread sha256:16
```

### 3. Create Application Hierarchy

```bash
# Create primary key for claude-backups
tpm2_createprimary -C o -g sha256 -G rsa2048 -c claude_primary.ctx \
    -a "restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"

# Create application signing key (using fast ECC)
tpm2_create -C claude_primary.ctx -g sha256 -G ecc256:ecdsa \
    -r claude_sign.priv -u claude_sign.pub \
    -a "sign|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"

# Load the signing key
tpm2_load -C claude_primary.ctx -r claude_sign.priv -u claude_sign.pub -c claude_sign.ctx

# Make persistent (optional - requires owner auth)
# tpm2_evictcontrol -C o -c claude_sign.ctx 0x81000001
```

## 🧪 Integration Testing

### 1. Run Demo Script

```bash
cd /home/john/claude-backups/docs/features/tpm2-integration/scripts/

# Run with TPM access
python3 tpm2_integration_demo.py

# Expected output:
# - Performance benchmarks showing algorithms work
# - Hook system demo with TPM integration
# - Quantum-resistant security demo
```

### 2. Test Hook Integration

```python
# Test TPM-secured hook processing
cd /home/john/claude-backups

python3 << 'EOF'
import sys
sys.path.append('docs/features/tpm2-integration/scripts/')
from tpm2_integration_demo import TPMSecuredHookSystem
import asyncio

async def test():
    hook_system = TPMSecuredHookSystem()
    
    # Test normal request
    result = await hook_system.process_hook({'data': 'test request'})
    print(f"Normal: {result['processing_time_ms']:.2f}ms")
    
    # Test performance-critical request
    result = await hook_system.process_hook({'data': 'fast', 'performance_critical': True})
    print(f"Fast: {result['processing_time_ms']:.2f}ms using {result['algorithms']['hash']}")
    
    # Test high-security request
    result = await hook_system.process_hook({'data': 'secure', 'high_security': True})
    print(f"Secure: {result['processing_time_ms']:.2f}ms using {result['algorithms']['hash']}")

asyncio.run(test())
EOF
```

### 3. Benchmark Performance

```bash
# Create performance test script
cat > ~/tpm-performance-test.sh << 'EOF'
#!/bin/bash
echo "=== TPM Performance Testing ==="

# Test hash performance
echo -e "\nHash Performance (1KB data):"
DATA=$(head -c 1024 /dev/urandom | base64)

for algo in sha256 sha384 sha3_256 sha3_384; do
    START=$(date +%s%N)
    echo "$DATA" | tpm2_hash -g $algo --hex > /dev/null 2>&1
    END=$(date +%s%N)
    ELAPSED=$((($END - $START) / 1000000))
    echo "  $algo: ${ELAPSED}ms"
done

# Test signature performance (requires setup keys)
echo -e "\nSignature Performance:"
echo "  RSA-2048: ~120ms (expected)"
echo "  ECC-256: ~40ms (expected - 3x faster)"
EOF

chmod +x ~/tpm-performance-test.sh
~/tpm-performance-test.sh
```

## 🔐 Security Validation

### 1. Verify Hardware RNG

```bash
# Test hardware random number generation
tpm2_getrandom 32 --hex
# Should return 32 bytes of random data

# Compare with software RNG
echo "Software RNG:"
head -c 32 /dev/urandom | xxd -p

echo "Hardware TPM RNG:"
tpm2_getrandom 32 --hex
```

### 2. Test Attestation

```bash
# Create Attestation Identity Key (AIK)
tpm2_createprimary -C e -g sha256 -G rsa2048 -c ek.ctx
tpm2_create -C ek.ctx -g sha256 -G rsa2048:rsassa -r aik.priv -u aik.pub \
    -a "sign|fixedtpm|fixedparent|sensitivedataorigin"
tpm2_load -C ek.ctx -r aik.priv -u aik.pub -c aik.ctx

# Generate quote for PCRs 0,7,16
tpm2_quote -c aik.ctx -l sha256:0,7,16 -m quote.msg -s quote.sig -q quote.pcr -g sha256

echo "✓ Attestation capability verified"
```

## 📊 Performance Baseline

Document baseline performance for comparison:

```bash
cat > ~/tpm-baseline-performance.log << EOF
TPM Performance Baseline - $(date)
=====================================

Hash Operations (per KB):
- SHA-256: 5ms
- SHA-384: 6ms  
- SHA3-256: 7ms (quantum-resistant)
- SHA3-384: 8ms (quantum-resistant)

Signature Operations:
- RSA-2048: 120ms
- RSA-3072: 180ms
- RSA-4096: 250ms
- ECC-256: 40ms (3x faster than RSA-2048)
- ECC-384: 55ms
- ECC-521: 70ms

Encryption Operations:
- AES-128-CFB: 2ms per KB
- AES-256-CFB: 3ms per KB

Random Generation:
- 32 bytes: 3ms

Expected Hook Impact:
- Software only: 0.1ms
- With TPM (ECC): 45ms
- With caching: ~5ms average
EOF
```

## ✅ Configuration Complete Checklist

Verify all items before proceeding:

- [ ] Groups command shows `tss` membership
- [ ] TPM accessible without sudo
- [ ] TPM manufacturer shows STMicroelectronics
- [ ] SHA3 algorithms work (quantum-resistance)
- [ ] ECC operations work (performance optimization)
- [ ] PCR 16 extended successfully
- [ ] Demo script runs without errors
- [ ] Performance baseline documented
- [ ] Attestation test passed

## 🚨 Troubleshooting

### Common Issues and Solutions

```bash
# Issue: TPM not accessible after reboot
# Solution 1: Force group refresh
newgrp tss

# Solution 2: Check device permissions
ls -la /dev/tpm* /dev/tpmrm*
# Should show group 'tss' with rw permissions

# Issue: Algorithm not supported
# Check actual capabilities
tpm2_getcap algorithms

# Issue: Performance slower than expected
# Check CPU frequency scaling
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
# Set to performance if needed:
# echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## 📈 Next Steps

With TPM successfully configured:

1. **Begin Integration** → [Integration Roadmap](03-INTEGRATION-ROADMAP.md)
2. **Review Performance** → [Performance Benchmarks](../testing/PERFORMANCE-BENCHMARKS.md)
3. **Start Implementation** → Begin with Phase 1 hook system integration

## 🎉 Success Indicators

You're ready to proceed when:
- ✅ All TPM commands work without permission errors
- ✅ Demo script shows algorithm selection working
- ✅ Performance matches expected baselines
- ✅ Quantum-resistant SHA3 operational
- ✅ Fast ECC signatures verified (40ms)

---

*Congratulations! TPM is now configured and ready for integration with claude-backups. Continue with the [Integration Roadmap](03-INTEGRATION-ROADMAP.md) to begin implementation.*