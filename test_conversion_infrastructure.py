#!/usr/bin/env python3
"""
Test script for local inference conversion infrastructure
Tests quantizer and server components with a small test model
"""

import sys
import os
from pathlib import Path

# Add local models to path
sys.path.append(str(Path(__file__).parent / "local-models" / "qwen-openvino"))

def test_dependencies():
    """Test that all required dependencies are available"""
    print("🧪 Testing dependencies...")

    tests = []

    try:
        import openvino as ov
        core = ov.Core()
        devices = core.available_devices
        tests.append(("OpenVINO", True, f"Devices: {devices}"))
    except Exception as e:
        tests.append(("OpenVINO", False, str(e)))

    try:
        from optimum.intel import OVModelForCausalLM
        from optimum.intel.openvino import OVWeightQuantizationConfig
        tests.append(("Optimum Intel", True, "All classes available"))
    except Exception as e:
        tests.append(("Optimum Intel", False, str(e)))

    try:
        from transformers import AutoTokenizer, AutoConfig
        tests.append(("Transformers", True, "Core classes available"))
    except Exception as e:
        tests.append(("Transformers", False, str(e)))

    try:
        import fastapi
        import uvicorn
        tests.append(("FastAPI", True, "Server framework ready"))
    except Exception as e:
        tests.append(("FastAPI", False, str(e)))

    # Print results
    all_passed = True
    for name, passed, details in tests:
        status = "✓" if passed else "✗"
        print(f"  {status} {name}: {details}")
        if not passed:
            all_passed = False

    return all_passed

def test_quantizer_class():
    """Test that the quantizer class can be imported and initialized"""
    print("\n🧪 Testing quantizer class...")

    try:
        from qwen_quantizer import QwenQuantizer

        # Test initialization with non-existent paths (should not crash)
        quantizer = QwenQuantizer(
            raw_model_dir="/tmp/nonexistent",
            output_dir="/tmp/test_output"
        )

        print("  ✓ QwenQuantizer class loads successfully")
        print(f"  ✓ NPU available: {quantizer.npu_available}")
        print(f"  ✓ GPU available: {quantizer.gpu_available}")

        # Test config creation
        configs = quantizer.create_quantization_configs()
        print(f"  ✓ Created {len(configs)} quantization configs")

        for name, config in configs.items():
            device = config.get('device', 'unknown')
            precision = config.get('precision', 'unknown')
            print(f"    - {name}: {device} {precision}")

        return True

    except Exception as e:
        print(f"  ✗ Quantizer test failed: {e}")
        return False

def test_inference_server_class():
    """Test that the inference server class can be imported and initialized"""
    print("\n🧪 Testing inference server class...")

    try:
        from qwen_inference_server import QwenModelEngine

        # Test initialization with non-existent model directory
        engine = QwenModelEngine(models_dir="/tmp/nonexistent")

        print("  ✓ QwenModelEngine class loads successfully")
        print(f"  ✓ NPU available: {engine.npu_available}")
        print(f"  ✓ GPU available: {engine.gpu_available}")

        # Test model info
        model_info = engine.get_model_info()
        print(f"  ✓ Model info: {model_info}")

        # Test performance metrics
        metrics = engine.get_performance_metrics()
        print(f"  ✓ Performance metrics initialized")

        return True

    except Exception as e:
        print(f"  ✗ Inference server test failed: {e}")
        return False

def test_hardware_detection():
    """Test hardware detection capabilities"""
    print("\n🧪 Testing hardware detection...")

    try:
        import openvino as ov
        core = ov.Core()
        devices = core.available_devices

        print(f"  ✓ Available devices: {devices}")

        # Test NPU detection
        npu_available = 'NPU' in devices and Path("/dev/accel/accel0").exists()
        print(f"  ✓ NPU available: {npu_available}")

        if npu_available:
            print("    - NPU device found at /dev/accel/accel0")

        # Test GPU detection
        gpu_available = 'GPU' in devices
        print(f"  ✓ GPU available: {gpu_available}")

        # Test CPU (should always be available)
        cpu_available = 'CPU' in devices
        print(f"  ✓ CPU available: {cpu_available}")

        return True

    except Exception as e:
        print(f"  ✗ Hardware detection failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Testing Local Inference Infrastructure")
    print("=" * 50)

    tests = [
        ("Dependencies", test_dependencies),
        ("Quantizer Class", test_quantizer_class),
        ("Inference Server Class", test_inference_server_class),
        ("Hardware Detection", test_hardware_detection)
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n❌ {test_name} crashed: {e}")
            results.append((test_name, False))

    # Summary
    print("\n" + "=" * 50)
    print("🧪 Test Summary")
    print("=" * 50)

    passed = 0
    total = len(results)

    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        icon = "✅" if result else "❌"
        print(f"{icon} {test_name}: {status}")
        if result:
            passed += 1

    print(f"\nResults: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! Infrastructure is ready.")
        return 0
    else:
        print("⚠️ Some tests failed. Check the output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())