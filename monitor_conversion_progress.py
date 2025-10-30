#!/usr/bin/env python3
"""
Monitor Local Inference Implementation Progress
Real-time tracking of model download and conversion
"""

import os
import sys
import time
from pathlib import Path
from datetime import datetime

def check_download_progress():
    """Check Qwen model download progress"""
    raw_dir = Path("/home/john/claude-backups/local-models/qwen-raw")

    if not raw_dir.exists():
        return "Not started", 0, 0

    # Count total files and size
    try:
        total_size = sum(f.stat().st_size for f in raw_dir.rglob('*') if f.is_file())
        safetensors_files = list(raw_dir.glob("*.safetensors"))
        config_files = ["config.json", "tokenizer.json", "tokenizer_config.json"]

        total_files = len(safetensors_files)
        config_complete = sum(1 for cf in config_files if (raw_dir / cf).exists())

        # Estimate progress (Qwen-32B is ~60GB total)
        estimated_total = 60 * 1024**3  # 60GB
        progress_pct = min((total_size / estimated_total) * 100, 100)

        if total_files >= 17 and config_complete >= 2:  # 17 model shards expected
            return "Complete", progress_pct, total_size
        elif total_files > 0:
            return "In Progress", progress_pct, total_size
        else:
            return "Starting", progress_pct, total_size

    except Exception as e:
        return f"Error: {e}", 0, 0

def check_conversion_readiness():
    """Check if conversion infrastructure is ready"""
    checks = {
        "OpenVINO": False,
        "Optimum Intel": False,
        "NPU Detection": False,
        "Quantizer": False,
        "Inference Server": False
    }

    try:
        # Test OpenVINO
        import openvino as ov
        core = ov.Core()
        if 'NPU' in core.available_devices:
            checks["OpenVINO"] = True
            checks["NPU Detection"] = True
    except:
        pass

    try:
        # Test Optimum Intel
        from optimum.intel import OVModelForCausalLM
        checks["Optimum Intel"] = True
    except:
        pass

    try:
        # Test Quantizer
        sys.path.append("/home/john/claude-backups/local-models/qwen-openvino")
        from qwen_quantizer import QwenQuantizer
        checks["Quantizer"] = True
    except:
        pass

    try:
        # Test Inference Server
        from qwen_inference_server import QwenModelEngine
        checks["Inference Server"] = True
    except:
        pass

    return checks

def estimate_completion_time(progress_pct, start_time=None):
    """Estimate completion time based on progress"""
    if progress_pct <= 0:
        return "Unknown"

    if start_time is None:
        # Assume download started 30 minutes ago (rough estimate)
        elapsed_minutes = 30
    else:
        elapsed_minutes = (time.time() - start_time) / 60

    if progress_pct >= 100:
        return "Complete"

    total_time = elapsed_minutes / (progress_pct / 100)
    remaining_time = total_time - elapsed_minutes

    if remaining_time < 60:
        return f"{remaining_time:.0f} minutes"
    else:
        hours = remaining_time / 60
        return f"{hours:.1f} hours"

def main():
    """Main monitoring function"""
    print("🚀 Local Inference Implementation Monitor")
    print("=" * 50)

    while True:
        os.system('clear' if os.name == 'posix' else 'cls')

        print("🚀 Local Inference Implementation Monitor")
        print("=" * 50)
        print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()

        # Check download progress
        status, progress, size_bytes = check_download_progress()
        size_gb = size_bytes / (1024**3)

        print("📥 Model Download Progress:")
        print(f"   Status: {status}")
        print(f"   Progress: {progress:.1f}%")
        print(f"   Downloaded: {size_gb:.1f} GB")
        print(f"   Estimated completion: {estimate_completion_time(progress)}")

        # Progress bar
        bar_width = 40
        filled = int(bar_width * progress / 100)
        bar = "█" * filled + "░" * (bar_width - filled)
        print(f"   [{bar}] {progress:.1f}%")
        print()

        # Check infrastructure readiness
        readiness = check_conversion_readiness()
        print("🔧 Conversion Infrastructure:")
        for component, ready in readiness.items():
            status_icon = "✅" if ready else "❌"
            print(f"   {status_icon} {component}")

        ready_count = sum(readiness.values())
        total_count = len(readiness)
        print(f"   Overall: {ready_count}/{total_count} components ready")
        print()

        # Next steps
        if progress >= 100:
            print("🎯 Ready for Conversion!")
            print("   Next: Run model conversion to OpenVINO INT4")
            print("   Command: python3 local-models/qwen-openvino/qwen_quantizer.py")
        elif progress >= 50:
            print("🕐 Download in progress...")
            print("   Conversion will start automatically when download completes")
        else:
            print("⏳ Download starting...")
            print("   Please wait for model download to progress")

        print()
        print("Press Ctrl+C to exit monitor")

        try:
            time.sleep(10)  # Update every 10 seconds
        except KeyboardInterrupt:
            print("\n👋 Monitor stopped")
            break

if __name__ == "__main__":
    main()