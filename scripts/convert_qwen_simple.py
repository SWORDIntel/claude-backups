#!/usr/bin/env python3
"""
Simple Qwen GGUF Conversion
Direct approach without complex dependencies
"""

import os
import subprocess
import sys
from pathlib import Path


def simple_gguf_conversion():
    """Use the most direct conversion method available"""

    raw_model = "/home/john/claude-backups/local-models/qwen-raw"
    output_dir = "/home/john/claude-backups/local-models/qwen-gguf"

    Path(output_dir).mkdir(exist_ok=True)

    print("🚀 Simple Qwen GGUF Conversion")
    print("=" * 50)
    print(f"Input: {raw_model}")
    print(f"Output: {output_dir}")

    # Method 1: Try using llama.cpp convert script if available
    llama_convert_script = None
    possible_locations = [
        "/usr/local/bin/convert.py",
        "/opt/llama.cpp/convert.py",
        "~/.local/bin/convert.py",
    ]

    for loc in possible_locations:
        if Path(loc).expanduser().exists():
            llama_convert_script = loc
            break

    # Method 2: Use transformers + manual GGUF creation
    if not llama_convert_script:
        print("📦 Using transformers-based conversion...")

        try:
            # Load and re-save model in a cleaner format
            cmd = [
                sys.executable,
                "-c",
                f"""
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

print("🔧 Loading Qwen model...")

# Load with minimal memory usage
model = AutoModelForCausalLM.from_pretrained(
    "{raw_model}",
    torch_dtype=torch.float16,
    device_map="cpu",
    trust_remote_code=True,
    low_cpu_mem_usage=True
)

tokenizer = AutoTokenizer.from_pretrained("{raw_model}")

print("💾 Saving optimized model...")

# Save in a format more compatible with conversion
model.save_pretrained(
    "{output_dir}/qwen-optimized",
    safe_serialization=True,
    max_shard_size="2GB"
)

tokenizer.save_pretrained("{output_dir}/qwen-optimized")

print("✅ Model optimization complete!")
print(f"📁 Saved to: {output_dir}/qwen-optimized")

# Calculate approximate GGUF sizes
param_count = sum(p.numel() for p in model.parameters())
print(f"📊 Parameters: {{param_count/1e9:.1f}}B")

gguf_sizes = {{
    "Q4_0": param_count * 0.5 / (1024**3),
    "Q4_1": param_count * 0.55 / (1024**3),
    "Q5_0": param_count * 0.625 / (1024**3),
    "Q8_0": param_count * 1.0 / (1024**3)
}}

print("🎯 Expected GGUF sizes:")
for fmt, size in gguf_sizes.items():
    npu_compat = "NPU compatible" if size < 20 else "CPU only"
    print(f"  {{fmt}}: {{size:.1f}}GB ({{npu_compat}})")
""",
            ]

            print("⏳ Starting conversion (this may take 15-30 minutes)...")
            result = subprocess.run(cmd, timeout=3600)  # 1 hour timeout

            if result.returncode == 0:
                print("✅ Basic model conversion successful!")
                return True
            else:
                print("❌ Conversion failed")
                return False

        except subprocess.TimeoutExpired:
            print("⏱️ Conversion timed out - model may be too large")
            return False
        except Exception as e:
            print(f"❌ Conversion error: {e}")
            return False

    return False


if __name__ == "__main__":
    success = simple_gguf_conversion()
    sys.exit(0 if success else 1)
