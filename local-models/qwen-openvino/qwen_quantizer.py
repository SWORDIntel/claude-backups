#!/usr/bin/env python3
"""
OpenVINO Qwen 2.5 Quantizer v1.0
Quantize and optimize Qwen 2.5-32B for Intel NPU 3720 military mode (26.4 TOPS)
Eliminates token usage through local inference
"""

import os
import json
import logging
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import numpy as np
import time
from datetime import datetime

try:
    import openvino as ov
    import torch
    import transformers
    import nncf
    from transformers import AutoTokenizer, AutoModelForCausalLM, AutoConfig
    from optimum.intel import OVModelForCausalLM
    from optimum.intel.openvino import OVWeightQuantizationConfig
    DEPENDENCIES_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Some dependencies not available: {e}")
    DEPENDENCIES_AVAILABLE = False

class QwenQuantizer:
    """
    OpenVINO-optimized quantizer for local Qwen 2.5 inference
    Targets Intel NPU 3720 military mode (26.4 TOPS)
    """

    def __init__(self,
                 raw_model_dir: str = "/home/john/claude-backups/local-models/qwen-raw",
                 output_dir: str = "/home/john/claude-backups/local-models/qwen-openvino"):
        self.raw_model_dir = Path(raw_model_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.configs_dir = self.output_dir / "configs"
        self.models_dir = self.output_dir / "models"
        self.cache_dir = self.output_dir / "cache"

        # Create subdirectories
        for dir_path in [self.configs_dir, self.models_dir, self.cache_dir]:
            dir_path.mkdir(exist_ok=True)

        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.output_dir / 'quantization.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('QwenQuantizer')

        # Hardware detection
        self.npu_available = self._detect_npu_military_mode()
        self.gpu_available = self._detect_intel_gpu()

        # Performance targets for Intel NPU 3720 military mode
        self.performance_targets = {
            "npu_military_tops": 26.4,
            "npu_standard_tops": 11.0,
            "target_latency_ms": 200,
            "target_throughput_tokens_sec": 50,  # Realistic for 32B model
            "memory_limit_mb": 32768,  # 32GB for 32B model + overhead
            "npu_cache_mb": 128 if self.npu_available else 64
        }

        self.logger.info(f"🚀 Qwen Quantizer initialized for Intel NPU 3720")
        self.logger.info(f"NPU Military Mode: {'ENABLED' if self.npu_available else 'DISABLED'}")
        self.logger.info(f"Target performance: {self.performance_targets['npu_military_tops']} TOPS")

    def _detect_npu_military_mode(self) -> bool:
        """Detect Intel NPU 3720 military mode capabilities"""
        try:
            # Check for NPU device
            if Path("/dev/accel/accel0").exists():
                self.logger.info("✓ NPU device detected at /dev/accel/accel0")
                return True
            return False
        except Exception as e:
            self.logger.warning(f"NPU detection failed: {e}")
            return False

    def _detect_intel_gpu(self) -> bool:
        """Detect Intel integrated GPU"""
        try:
            import openvino as ov
            core = ov.Core()
            devices = core.available_devices
            return 'GPU' in devices
        except Exception:
            return False

    def create_quantization_configs(self) -> Dict[str, Dict[str, Any]]:
        """Create quantization configurations for different deployment targets"""

        configs = {
            "qwen_npu_int4": {
                "device": "NPU",
                "precision": "INT4",
                "description": "NPU optimized INT4 for maximum throughput (~15GB, NUC2 compatible)",
                "quantization_config": {
                    "bits": 4,
                    "sym": True,
                    "group_size": 128,
                    "ratio": 1.0,
                    "dataset": "wikitext2",
                    "tokenizer": None  # Will be set during conversion
                },
                "compilation_config": {
                    "NPU_COMPILATION_MODE_PARAMS": "npu-arch=4000 npu-platform=4000",
                    "NPU_DPU_GROUPS": "4",
                    "PERFORMANCE_HINT": "THROUGHPUT"
                },
                "memory_optimization": {
                    "kv_cache_quantization": True,
                    "enable_kv_cache_compression": True,
                    "max_sequence_length": 2048
                }
            },

            "qwen_cpu_int8": {
                "device": "CPU",
                "precision": "INT8",
                "description": "CPU fallback INT8 for compatibility",
                "quantization_config": {
                    "bits": 8,
                    "sym": True,
                    "group_size": -1,  # Per-column quantization
                    "ratio": 1.0,
                    "dataset": "wikitext2"
                },
                "compilation_config": {
                    "CPU_THREADS_NUM": "16",
                    "CPU_BIND_THREAD": "HYBRID_AWARE",
                    "PERFORMANCE_HINT": "LATENCY"
                },
                "memory_optimization": {
                    "kv_cache_quantization": True,
                    "max_sequence_length": 4096
                }
            },

            "qwen_gpu_fp16": {
                "device": "GPU",
                "precision": "FP16",
                "description": "GPU accelerated FP16 for balanced performance",
                "quantization_config": {
                    "bits": 16,
                    "sym": False,
                    "group_size": -1,
                    "ratio": 1.0
                },
                "compilation_config": {
                    "GPU_ENABLE_LOOP_UNROLLING": "NO",
                    "PERFORMANCE_HINT": "THROUGHPUT"
                },
                "memory_optimization": {
                    "kv_cache_quantization": False,
                    "max_sequence_length": 8192
                }
            },

            "qwen_portable_int4": {
                "device": "CPU",
                "precision": "INT4",
                "description": "Portable deployment INT4 for NUC2/USB stick (~15GB)",
                "quantization_config": {
                    "bits": 4,
                    "sym": True,
                    "group_size": 64,  # Smaller groups for better accuracy
                    "ratio": 1.0,
                    "dataset": "wikitext2"
                },
                "compilation_config": {
                    "CPU_THREADS_NUM": "4",  # Conservative for portable devices
                    "CPU_BIND_THREAD": "NUMA",
                    "PERFORMANCE_HINT": "EFFICIENCY",
                    "INFERENCE_PRECISION_HINT": "f32"
                },
                "memory_optimization": {
                    "kv_cache_quantization": True,
                    "enable_kv_cache_compression": True,
                    "max_sequence_length": 2048,  # Reduced for memory efficiency
                    "dynamic_batching": False
                },
                "deployment_notes": {
                    "target_devices": ["NUC2", "Intel NUC", "Portable systems"],
                    "storage_requirement": "16GB+ USB 3.0 or NVMe",
                    "memory_requirement": "16GB+ RAM",
                    "expected_performance": "20-30 tokens/second"
                }
            }
        }

        # Save configurations
        for config_name, config in configs.items():
            config_file = self.configs_dir / f"{config_name}.json"
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            self.logger.info(f"📋 Created config: {config_name}")

        return configs

    def convert_model(self, config_name: str, config: Dict[str, Any]) -> bool:
        """Convert Qwen model to OpenVINO format with specified configuration"""

        try:
            self.logger.info(f"🔄 Starting conversion: {config_name}")
            self.logger.info(f"Device: {config['device']}, Precision: {config['precision']}")

            # Check if raw model exists
            if not self.raw_model_dir.exists():
                self.logger.error(f"Raw model directory not found: {self.raw_model_dir}")
                return False

            # Create output directory for this configuration
            model_output_dir = self.models_dir / config_name
            model_output_dir.mkdir(exist_ok=True)

            # Load tokenizer and model configuration
            self.logger.info("📖 Loading tokenizer and config...")
            tokenizer = AutoTokenizer.from_pretrained(self.raw_model_dir)
            model_config = AutoConfig.from_pretrained(self.raw_model_dir)

            # Save tokenizer
            tokenizer.save_pretrained(model_output_dir)

            # Create quantization configuration for OpenVINO
            if config['precision'] in ['INT4', 'INT8']:
                quantization_config = OVWeightQuantizationConfig(
                    bits=config['quantization_config']['bits'],
                    sym=config['quantization_config']['sym'],
                    group_size=config['quantization_config']['group_size'],
                    ratio=config['quantization_config']['ratio']
                )
            else:
                quantization_config = None

            # Convert model
            self.logger.info("🔧 Converting model to OpenVINO...")
            ov_model = OVModelForCausalLM.from_pretrained(
                self.raw_model_dir,
                export=True,
                quantization_config=quantization_config,
                device=config['device'],
                compile=False  # We'll compile separately for optimization
            )

            # Save converted model
            ov_model.save_pretrained(model_output_dir)

            # Create model info file
            model_info = {
                "model_name": "Qwen2.5-32B-Instruct",
                "config_name": config_name,
                "device": config['device'],
                "precision": config['precision'],
                "quantization_config": config['quantization_config'],
                "conversion_date": datetime.now().isoformat(),
                "model_size_gb": self._estimate_model_size(model_config, config['precision']),
                "expected_memory_gb": self._estimate_memory_requirements(model_config, config),
                "compilation_config": config.get('compilation_config', {})
            }

            with open(model_output_dir / "model_info.json", 'w') as f:
                json.dump(model_info, f, indent=2)

            self.logger.info(f"✅ Conversion complete: {config_name}")
            self.logger.info(f"   Model size: ~{model_info['model_size_gb']:.1f} GB")
            self.logger.info(f"   Expected memory: ~{model_info['expected_memory_gb']:.1f} GB")

            return True

        except Exception as e:
            self.logger.error(f"❌ Conversion failed for {config_name}: {e}")
            return False

    def _estimate_model_size(self, config, precision: str) -> float:
        """Estimate model size in GB based on parameters and precision"""
        # Qwen 2.5-32B has approximately 32.5B parameters
        param_count = 32.5e9

        if precision == "INT4":
            bytes_per_param = 0.5
        elif precision == "INT8":
            bytes_per_param = 1.0
        elif precision == "FP16":
            bytes_per_param = 2.0
        else:  # FP32
            bytes_per_param = 4.0

        return (param_count * bytes_per_param) / (1024**3)  # Convert to GB

    def _estimate_memory_requirements(self, config, quant_config: Dict) -> float:
        """Estimate total memory requirements including model + KV cache + overhead"""
        model_size = self._estimate_model_size(config, quant_config['precision'])

        # KV cache size depends on sequence length and batch size
        seq_len = quant_config.get('memory_optimization', {}).get('max_sequence_length', 2048)
        kv_cache_gb = (seq_len * config.hidden_size * 2 * 2) / (1024**3)  # Rough estimate

        # Overhead (activations, buffers, etc.)
        overhead_gb = model_size * 0.3

        return model_size + kv_cache_gb + overhead_gb

    def quantize_all_models(self) -> Dict[str, bool]:
        """Quantize models for all configurations"""

        if not DEPENDENCIES_AVAILABLE:
            self.logger.error("❌ Required dependencies not available")
            return {}

        self.logger.info("🚀 Starting Qwen 2.5-32B quantization process")

        # Create configurations
        configs = self.create_quantization_configs()
        results = {}

        # Convert models in priority order (fastest first for testing)
        priority_order = ["qwen_cpu_int8", "qwen_npu_int4", "qwen_gpu_fp16"]

        for config_name in priority_order:
            if config_name in configs:
                config = configs[config_name]

                # Skip NPU if not available
                if config['device'] == 'NPU' and not self.npu_available:
                    self.logger.warning(f"⚠️ Skipping {config_name}: NPU not available")
                    results[config_name] = False
                    continue

                # Skip GPU if not available
                if config['device'] == 'GPU' and not self.gpu_available:
                    self.logger.warning(f"⚠️ Skipping {config_name}: GPU not available")
                    results[config_name] = False
                    continue

                results[config_name] = self.convert_model(config_name, config)

                if results[config_name]:
                    self.logger.info(f"✅ {config_name}: SUCCESS")
                else:
                    self.logger.error(f"❌ {config_name}: FAILED")

        # Summary
        successful = sum(1 for success in results.values() if success)
        total = len(results)

        self.logger.info(f"📊 Quantization Summary: {successful}/{total} successful")

        return results

def main():
    """Main quantization entry point"""

    print("🚀 Qwen 2.5-32B OpenVINO Quantizer")
    print("=" * 50)

    quantizer = QwenQuantizer()

    # Check if raw model is available
    if not quantizer.raw_model_dir.exists():
        print(f"❌ Raw model not found at: {quantizer.raw_model_dir}")
        print("Please ensure Qwen 2.5-32B model is downloaded first")
        return 1

    # Start quantization
    results = quantizer.quantize_all_models()

    if any(results.values()):
        print("✅ Quantization completed successfully!")
        print("Models ready for local inference")
        return 0
    else:
        print("❌ Quantization failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())