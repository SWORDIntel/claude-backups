#!/usr/bin/env python3
"""
OpenVINO Demo Inference Script
Demonstrates GPU and CPU inference on Meteor Lake
Intel Core Ultra 7 165H with Arc Graphics
"""

import numpy as np
import time
from openvino import Core, Model
from openvino.runtime import opset10

def create_test_model():
    """Create a simple test model"""
    # Input: 1x3x224x224 (typical image input)
    param = opset10.parameter([1, 3, 224, 224], np.float32, name="input")

    # Simple operations chain
    relu1 = opset10.relu(param)

    # Add operation (with constant)
    const = opset10.constant(np.ones((1, 3, 224, 224), dtype=np.float32))
    add = opset10.add(relu1, const)

    # Another ReLU
    relu2 = opset10.relu(add)

    # Reduce mean across spatial dimensions
    axes = opset10.constant(np.array([2, 3]), dtype=np.int64)
    reduce = opset10.reduce_mean(relu2, axes, keep_dims=False)

    # Final ReLU
    output = opset10.relu(reduce)

    return Model([output], [param], "test_model")

def benchmark_device(core, model, device_name, num_iterations=50):
    """Benchmark inference on a specific device"""
    print(f"\n{'='*60}")
    print(f"Benchmarking: {device_name}")
    print(f"{'='*60}")

    try:
        # Get device full name
        if device_name in core.available_devices:
            full_name = core.get_property(device_name, "FULL_DEVICE_NAME")
            print(f"Device: {full_name}")

        # Compile model
        print(f"Compiling model for {device_name}...")
        start = time.time()
        compiled_model = core.compile_model(model, device_name)
        compile_time = time.time() - start
        print(f"✅ Compilation time: {compile_time:.3f}s")

        # Create input data
        input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)

        # Warmup
        print(f"Warming up ({5} iterations)...")
        for _ in range(5):
            _ = compiled_model([input_data])

        # Benchmark
        print(f"Running benchmark ({num_iterations} iterations)...")
        times = []

        for i in range(num_iterations):
            start = time.time()
            result = compiled_model([input_data])
            elapsed = time.time() - start
            times.append(elapsed)

            if (i + 1) % 10 == 0:
                print(f"  Progress: {i+1}/{num_iterations} iterations")

        # Statistics
        times = np.array(times)
        avg_time = np.mean(times) * 1000  # Convert to ms
        std_time = np.std(times) * 1000
        min_time = np.min(times) * 1000
        max_time = np.max(times) * 1000
        fps = 1000 / avg_time

        print(f"\n📊 Results for {device_name}:")
        print(f"  Average: {avg_time:.2f}ms (±{std_time:.2f}ms)")
        print(f"  Min: {min_time:.2f}ms")
        print(f"  Max: {max_time:.2f}ms")
        print(f"  Throughput: {fps:.1f} FPS")

        return {
            'device': device_name,
            'avg_ms': avg_time,
            'std_ms': std_time,
            'min_ms': min_time,
            'max_ms': max_time,
            'fps': fps,
            'compile_time': compile_time
        }

    except Exception as e:
        print(f"❌ Error benchmarking {device_name}: {e}")
        return None

def main():
    print("=" * 60)
    print("OpenVINO Inference Demo - Meteor Lake")
    print("Intel Core Ultra 7 165H + Arc Graphics")
    print("=" * 60)

    # Initialize OpenVINO
    print("\n1️⃣  Initializing OpenVINO Runtime...")
    core = Core()

    # Show version
    from openvino import __version__
    print(f"OpenVINO Version: {__version__}")

    # List devices
    print(f"\n2️⃣  Available Devices:")
    devices = core.available_devices
    for device in devices:
        try:
            full_name = core.get_property(device, "FULL_DEVICE_NAME")
            print(f"  • {device}: {full_name}")
        except:
            print(f"  • {device}")

    # Create test model
    print(f"\n3️⃣  Creating Test Model...")
    model = create_test_model()
    print(f"Model: {model.get_name()}")
    print(f"Input shape: {model.input().get_shape()}")
    print(f"Output shape: {model.output().get_shape()}")

    # Benchmark devices
    print(f"\n4️⃣  Running Benchmarks...")
    results = []

    # Test CPU
    if "CPU" in devices:
        result = benchmark_device(core, model, "CPU", num_iterations=50)
        if result:
            results.append(result)

    # Test GPU (recommended per CLAUDE.md)
    if "GPU" in devices:
        result = benchmark_device(core, model, "GPU", num_iterations=50)
        if result:
            results.append(result)

    # Skip NPU (95% non-functional per CLAUDE.md)
    if "NPU" in devices:
        print(f"\n{'='*60}")
        print(f"Skipping NPU (per CLAUDE.md: 95% non-functional on Meteor Lake)")
        print(f"{'='*60}")

    # Summary
    print(f"\n{'='*60}")
    print(f"5️⃣  BENCHMARK SUMMARY")
    print(f"{'='*60}")

    if results:
        print(f"\n{'Device':<10} {'Avg (ms)':<12} {'FPS':<10} {'Compile (s)':<12}")
        print(f"{'-'*60}")

        for r in results:
            print(f"{r['device']:<10} {r['avg_ms']:>8.2f}ms   {r['fps']:>7.1f}    {r['compile_time']:>8.3f}s")

        # Find best device
        best = min(results, key=lambda x: x['avg_ms'])
        print(f"\n🏆 Best Performance: {best['device']} ({best['avg_ms']:.2f}ms / {best['fps']:.1f} FPS)")

        # Recommendations
        print(f"\n💡 Recommendations (per CLAUDE.md):")
        print(f"   1. Use GPU for best inference performance")
        print(f"   2. Use CPU for parallel/multi-model workloads")
        print(f"   3. Avoid NPU on Meteor Lake (driver limitations)")

    print(f"\n{'='*60}")
    print(f"✅ Demo Complete!")
    print(f"{'='*60}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
