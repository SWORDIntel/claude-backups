# Custom Kernel 6.12.6 Installation Guide

## Complete NPU/GNA/GPU/ZFS Integration

### Quick Start

```bash
cd /home/john/claude-backups
./director_solution.sh
# Password when prompted: 1786
```

## System Requirements

- **CPU**: Intel Core Ultra 7 155H (Meteor Lake)
- **RAM**: 64GB DDR5
- **OS**: siduction (Debian-based)
- **Current Kernel**: 6.16.7-1-siduction-amd64
- **ZFS Source**: ~/Downloads/Old/zfs-2.3.4

## What This Builds

### Neural Acceleration (13+ TOPS Total)
- **NPU**: Intel Neural Processing Unit - 11 TOPS
- **GNA**: Gaussian Neural Accelerator - 2 TOPS
- **GPU**: Intel Graphics 128 EUs - 2 TFLOPS
- **CPU**: AVX-512 optimizations

### Software Stack
- **Kernel**: 6.12.6 with custom patches
- **ZFS**: 2.3.4 built from source
- **Firmware**: Intel VPU v1.6.0

## Installation Scripts

### 1. DIRECTOR Solution (Recommended)
```bash
./director_solution.sh
```
Complete 6-phase strategic build with safety checks.

### 2. Master Builder
```bash
./master_kernel_builder.sh
```
Automated build with logging.

### 3. Safe Kernel Build
```bash
./safe_kernel_build.sh
```
Conservative approach without autoremove.

### 4. Emergency Fix (if needed)
```bash
./emergency_fix_packages.sh
```
Restores critical packages if removed.

## Build Process

### Phase 1: System Preparation
- Restore critical packages (dkms, initramfs-tools)
- Fix package conflicts
- Verify boot integrity

### Phase 2: ZFS Build
```bash
cd ~/Downloads/Old/zfs-2.3.4
./autogen.sh
./configure
make -j20
make deb
```

### Phase 3: Kernel Configuration
- Enable CONFIG_DRM_ACCEL_IVPU (NPU)
- Enable CONFIG_INTEL_GNA (GNA)
- Enable CONFIG_DRM_I915 (GPU)
- Enable CONFIG_CRYPTO_AVX512 (CPU)

### Phase 4: Build Execution
```bash
make -j20 bindeb-pkg \
    LOCALVERSION=-director-npu-gna-gpu \
    KDEB_PKGVERSION=$(date +%Y%m%d)
```

### Phase 5: Installation
```bash
cd /tmp/director-kernel-package-[timestamp]/
sudo ./director_install.sh
```

## Post-Installation

### Verification
```bash
# Check NPU
ls /dev/accel*

# Check GNA
lsmod | grep gna

# Check ZFS
zpool status

# Check GPU
ls /dev/dri/render*
```

### Performance Testing
```bash
# NPU benchmark
/opt/intel/openvino/samples/benchmark_app -d CPU
/opt/intel/openvino/samples/benchmark_app -d GPU

# Check accelerator status
check_accelerators
```

## Troubleshooting

### Boot Issues
```bash
# Rebuild initramfs
sudo update-initramfs -u -k $(uname -r)

# Update GRUB
sudo update-grub
```

### Package Conflicts
```bash
# Fix ZFS conflicts
sudo dpkg --remove --force-depends libnvpair3 libuutil3
sudo apt --fix-broken install
```

### Missing Firmware
```bash
# Download NPU firmware
wget https://github.com/intel/ivpu-driver/releases/download/v1.6.0/vpu_37xx_v1.6.0.bin
sudo cp vpu_37xx_v1.6.0.bin /lib/firmware/intel/vpu/
```

## Expected Results

After successful installation:
- `/dev/accel/accel0` - NPU device
- `/dev/gna0` - GNA device (if driver loads)
- `/dev/dri/renderD128` - GPU render node
- 13+ TOPS neural compute capability
- ZFS pools accessible

## Build Time

- ZFS build: ~10-15 minutes
- Kernel download: ~5 minutes
- Kernel build: ~30-45 minutes
- Total: ~45-60 minutes

## Support Files

- Build log: `/tmp/director_kernel_*.log`
- Installation packages: `/tmp/director-kernel-package-*/`
- Kernel config: `.config` in build directory

## Important Notes

1. **DO NOT** use `apt autoremove` during build
2. **ALWAYS** verify initramfs before rebooting
3. **KEEP** sudo password ready: 1786
4. **BACKUP** important data before kernel changes

## Repository

https://github.com/SWORDIntel/claude-backups

---

*Last Updated: 2025-09-16*
*Kernel Version: 6.12.6*
*ZFS Version: 2.3.4*
*Neural Compute: 13+ TOPS*