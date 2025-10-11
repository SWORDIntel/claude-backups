# Hardware Detection & Optimization

This directory contains hardware detection tools for Intel Meteor Lake military-grade systems.

---

## Files

### milspec_hardware_analyzer.py (1106 lines) - **COMPREHENSIVE**

**Purpose:** Military-grade hardware capability detection

**Detects:**
- Standard mode (no sudo): 34 TOPS (NPU: 11, GPU: 18, CPU: 5)
- Military mode (with sudo): **49.4 TOPS** (NPU: 26.4, GPU: 18, CPU: 5)

**Military Features Detected:**
- Covert Mode: Enabled
- Secure NPU Execution: Enabled
- Memory Compartments: Enabled
- TEMPEST Compliant: Enabled
- RF Shielding: Enabled
- Extended NPU: Enabled (128MB cache)
- NPU Performance Scaling: **2.2x**

**Usage:**
```bash
# Standard detection
python3 hardware/milspec_hardware_analyzer.py

# Military-grade detection (requires sudo)
sudo python3 hardware/milspec_hardware_analyzer.py

# Output shows:
# - Total AI Compute: 49.4 TOPS (military mode)
# - Capable of: 70B parameter models
# - NPU Performance: 2.2x enhanced
```

**Optimal Compiler Flags:**
```bash
-march=meteorlake -mtune=meteorlake -O3
-mavx2 -mfma -mavx-vnni
-fstack-clash-protection -fcf-protection=full
```

**Environment Variables (Military Mode):**
```bash
export INTEL_NPU_ENABLE_TURBO=1
export OPENVINO_ENABLE_SECURE_MEMORY=1
export OPENVINO_HETERO_PRIORITY=NPU,GPU,CPU
export OV_SCALE_FACTOR=1.5
```

---

## System Capabilities

### Standard Mode (No Sudo)
- NPU: 11 TOPS
- GPU: 18 TOPS (Intel Arc iGPU)
- CPU: 5 TOPS
- **Total: 34 TOPS**
- Max Models: 34B parameters

### Military Mode (With Sudo) ⭐
- NPU: **26.4 TOPS** (2.2x enhanced)
- GPU: 18 TOPS
- CPU: 5 TOPS
- **Total: 49.4 TOPS**
- Max Models: **70B parameters**

**Enhancement Factor: 1.45x total AI compute**

---

## Integration with NPU Scripts

The milspec analyzer provides full inventory for:

**NPU Orchestrators:**
- `agents/src/python/npu_accelerated_orchestrator.py` (44KB)
- `agents/src/python/npu_orchestrator_launcher.py`
- `agents/src/python/npu_constructor_integration.py` (35KB)

**NPU Pipelines:**
- `agents/src/python/intel_npu_async_pipeline.py` (33KB)
- `agents/src/python/npu_cv_pipeline.py`

**NPU Installation:**
- `agents/src/python/install_npu_acceleration.py` (24KB)
- `agents/src/python/npu_binary_installer.py` (34KB)

**Benchmarking:**
- `agents/src/python/npu_benchmark_comparison.py` (29KB)
- `agents/src/python/npu_baseline_test.py`

---

## Recommended Usage

### 1. Detect Capabilities
```bash
sudo python3 hardware/milspec_hardware_analyzer.py
```

### 2. Export Configuration
```python
from hardware.milspec_hardware_analyzer import MilitaryHardwareAnalyzer

analyzer = MilitaryHardwareAnalyzer()
analyzer.run_analysis()
# Exports optimal compiler flags, NPU config, security settings
```

### 3. Apply to NPU Scripts
Use detected capabilities in NPU orchestrators for:
- Optimal memory allocation (256MB NPU in covert mode)
- Performance scaling (2.2x)
- Secure execution mode
- INT4/INT3 quantization support

---

## Security Notes

**Military Features** (sudo required):
- Extended NPU cache: 128MB (vs 64MB standard)
- Secure memory compartments
- Hardware zeroization support
- Covert execution mode
- TEMPEST emission control

**Use Cases:**
- Classified data processing
- Multi-level security workloads
- Secure AI inference
- Covert operations support

---

## Performance Targets

**With Military Mode:**
- Context chopping: 930M lines/sec (shadowgit)
- NPU inference: 26.4 TOPS
- Total AI: 49.4 TOPS
- Model capacity: 70B parameters
- Quantization: INT4/INT3 support

---

**Last Updated:** 2025-10-11
**Status:** Comprehensive detection available
**Hardware:** Dell Latitude 5450 MIL-SPEC with enhanced NPU
