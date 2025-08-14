"""
Dual Accelerator Manager for Intel Core Ultra (Meteor Lake)
Manages GNA and NPU coordination for optimal voice processing
"""

import openvino as ov
import numpy as np
from typing import Optional, Dict, Any, Tuple
from enum import Enum
import logging
from pathlib import Path
import threading
from queue import Queue
import time

logger = logging.getLogger(__name__)


class AcceleratorType(Enum):
    GNA = "GNA"
    NPU = "NPU"
    CPU = "CPU"
    AUTO = "AUTO"


class DualAcceleratorManager:
    """
    Manages both GNA and NPU for optimal task distribution
    GNA: Voice/audio processing (low power, continuous)
    NPU: Complex AI tasks, vision, large models
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.core = ov.Core()
        self.config = config or {}
        self.available_devices = self.core.available_devices
        
        # Check for our unique dual-accelerator setup
        self.has_gna = "GNA" in self.available_devices
        self.has_npu = "NPU" in self.available_devices
        
        if not self.has_gna or not self.has_npu:
            logger.warning(f"Missing accelerators! GNA: {self.has_gna}, NPU: {self.has_npu}")
        else:
            logger.info("Dual accelerator mode active: GNA + NPU available")
        
        # Model cache for each accelerator
        self.gna_models = {}
        self.npu_models = {}
        self.cpu_models = {}
        
        # Performance metrics
        self.metrics = {
            "gna_inferences": 0,
            "npu_inferences": 0,
            "gna_total_time": 0.0,
            "npu_total_time": 0.0,
            "power_savings_estimate": 0.0
        }
        
        # Thread-safe queues for async processing
        self.gna_queue = Queue()
        self.npu_queue = Queue()
        
        self._init_accelerator_properties()
    
    def _init_accelerator_properties(self):
        """Configure accelerator-specific optimizations"""
        
        # GNA optimizations for audio
        self.gna_config = {
            "GNA_DEVICE_MODE": "GNA_SW_EXACT",  # Can switch to GNA_HW for hardware
            "GNA_PRECISION": "I16",  # 16-bit integer for audio
            "GNA_PERFORMANCE_HINT": "LATENCY",  # Optimize for real-time
            "GNA_COMPILE_TARGET": "GNA_TARGET_3_0",  # For Meteor Lake
            "GNA_SCALE_FACTOR": "1.0",
            "GNA_FIRMWARE_MODEL_IMAGE": "",  # Path to firmware if needed
        }
        
        # NPU optimizations for complex models
        self.npu_config = {
            "PERFORMANCE_HINT": "THROUGHPUT",  # Batch processing
            "CACHE_DIR": str(Path.home() / ".cache" / "openvino_npu"),
            "ENABLE_PROFILING": "NO",  # Enable for debugging
        }
        
        # Update configs from init parameters
        if "gna_config" in self.config:
            self.gna_config.update(self.config["gna_config"])
        if "npu_config" in self.config:
            self.npu_config.update(self.config["npu_config"])
    
    def load_model(self, 
                   model_path: str, 
                   model_name: str,
                   accelerator: AcceleratorType = AcceleratorType.AUTO,
                   model_type: str = "audio") -> Any:
        """
        Load model onto specified accelerator
        
        Args:
            model_path: Path to OpenVINO IR model (.xml)
            model_name: Unique identifier for the model
            accelerator: Target accelerator or AUTO for smart routing
            model_type: "audio", "vision", "language", "biometric"
        """
        
        # Auto-select best accelerator based on model type
        if accelerator == AcceleratorType.AUTO:
            if model_type in ["audio", "acoustic", "speech"]:
                accelerator = AcceleratorType.GNA if self.has_gna else AcceleratorType.NPU
            elif model_type in ["vision", "large_language", "transformer"]:
                accelerator = AcceleratorType.NPU if self.has_npu else AcceleratorType.CPU
            elif model_type == "biometric":
                # Voice biometrics on GNA, face on NPU
                accelerator = AcceleratorType.GNA if self.has_gna else AcceleratorType.NPU
            else:
                accelerator = AcceleratorType.NPU if self.has_npu else AcceleratorType.CPU
        
        # Load the model
        model = self.core.read_model(model_path)
        
        # Compile based on target accelerator
        if accelerator == AcceleratorType.GNA and self.has_gna:
            compiled = self.core.compile_model(model, "GNA", self.gna_config)
            self.gna_models[model_name] = compiled
            logger.info(f"Model '{model_name}' loaded on GNA")
            
        elif accelerator == AcceleratorType.NPU and self.has_npu:
            compiled = self.core.compile_model(model, "NPU", self.npu_config)
            self.npu_models[model_name] = compiled
            logger.info(f"Model '{model_name}' loaded on NPU")
            
        else:
            # Fallback to CPU
            compiled = self.core.compile_model(model, "CPU")
            self.cpu_models[model_name] = compiled
            logger.info(f"Model '{model_name}' loaded on CPU (fallback)")
        
        return compiled
    
    def infer(self, 
              model_name: str, 
              input_data: np.ndarray,
              async_mode: bool = False) -> Any:
        """
        Run inference on the appropriate accelerator
        """
        
        start_time = time.time()
        
        # Find which accelerator has this model
        if model_name in self.gna_models:
            model = self.gna_models[model_name]
            accel_type = "gna"
        elif model_name in self.npu_models:
            model = self.npu_models[model_name]
            accel_type = "npu"
        elif model_name in self.cpu_models:
            model = self.cpu_models[model_name]
            accel_type = "cpu"
        else:
            raise ValueError(f"Model '{model_name}' not loaded")
        
        # Create inference request
        infer_request = model.create_infer_request()
        
        if async_mode:
            # Async inference for continuous processing
            infer_request.start_async({0: input_data})
            return infer_request
        else:
            # Sync inference
            result = infer_request.infer({0: input_data})
            
            # Update metrics
            inference_time = time.time() - start_time
            if accel_type == "gna":
                self.metrics["gna_inferences"] += 1
                self.metrics["gna_total_time"] += inference_time
                # GNA uses ~6x less power than CPU
                self.metrics["power_savings_estimate"] += inference_time * 0.83
            elif accel_type == "npu":
                self.metrics["npu_inferences"] += 1
                self.metrics["npu_total_time"] += inference_time
                # NPU uses ~4x less power than CPU
                self.metrics["power_savings_estimate"] += inference_time * .75
            
            return result
    
    def parallel_inference(self,
                          gna_model: str,
                          npu_model: str,
                          gna_input: np.ndarray,
                          npu_input: np.ndarray) -> Tuple[Any, Any]:
        """
        Run inference on both accelerators simultaneously
        Perfect for audio + vision or dual-stream processing
        """
        
        gna_request = self.gna_models[gna_model].create_infer_request()
        npu_request = self.npu_models[npu_model].create_infer_request()
        
        # Start both in parallel
        gna_request.start_async({0: gna_input})
        npu_request.start_async({0: npu_input})
        
        # Wait for both to complete
        gna_request.wait()
        npu_request.wait()
        
        return gna_request.get_output_tensor(0).data, npu_request.get_output_tensor(0).data
    
    def optimize_for_voice(self):
        """
        Special optimizations for voice-to-text pipeline
        Prioritizes accuracy over latency
        """
        
        # Update GNA for maximum accuracy
        self.gna_config.update({
            "GNA_DEVICE_MODE": "GNA_HW",  # Use hardware mode
            "GNA_PRECISION": "I16",  # Best precision for voice
            "GNA_PERFORMANCE_HINT": "CUMULATIVE_THROUGHPUT",  # Accuracy over speed
            "GNA_SCALE_FACTOR": "2048.0",  # Optimal for 16-bit audio
        })
        
        # Set NPU for language model post-processing
        self.npu_config.update({
            "PERFORMANCE_HINT": "LATENCY",  # Quick corrections
            "ENABLE_PROFILING": "YES",  # Monitor for self-improvement
        })
        
        logger.info("Optimized for voice recognition with accuracy priority")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Return performance metrics"""
        
        metrics = self.metrics.copy()
        
        # Calculate averages
        if metrics["gna_inferences"] > 0:
            metrics["gna_avg_latency"] = metrics["gna_total_time"] / metrics["gna_inferences"]
        if metrics["npu_inferences"] > 0:
            metrics["npu_avg_latency"] = metrics["npu_total_time"] / metrics["npu_inferences"]
        
        # Estimate power savings in mWh
        metrics["power_saved_mwh"] = metrics["power_savings_estimate"] * 10  # ~10mW saved per second
        
        return metrics
    
    def export_compiled_model(self, model_name: str, export_path: str):
        """
        Export compiled model for faster loading
        Meteor Lake specific optimization
        """
        
        if model_name in self.gna_models:
            self.gna_models[model_name].export_model(export_path)
            logger.info(f"Exported GNA model to {export_path}")
        elif model_name in self.npu_models:
            self.npu_models[model_name].export_model(export_path)
            logger.info(f"Exported NPU model to {export_path}")
        else:
            raise ValueError(f"Model '{model_name}' not found")
    
    def benchmark_dual_acceleration(self, audio_samples: np.ndarray, iterations: int = 100):
        """
        Benchmark the unique dual-accelerator advantage
        """
        
        results = {
            "gna_only": 0,
            "npu_only": 0,
            "dual_parallel": 0,
            "cpu_baseline": 0
        }
        
        logger.info(f"Running benchmark with {iterations} iterations...")
        
        # This would need actual models loaded to work
        # Placeholder for benchmark logic
        
        return results


class ModelScheduler:
    """
    Intelligent scheduler for routing tasks between GNA and NPU
    Learns from usage patterns to optimize routing
    """
    
    def __init__(self, manager: DualAcceleratorManager):
        self.manager = manager
        self.routing_history = []
        self.performance_map = {}
    
    def route_task(self, task_type: str, input_data: np.ndarray) -> AcceleratorType:
        """
        Intelligently route task to best accelerator based on:
        - Task type
        - Current load
        - Historical performance
        - Power state
        """
        
        # Simple routing for now, can be enhanced with ML
        if task_type in ["voice", "audio", "acoustic"]:
            return AcceleratorType.GNA
        elif task_type in ["vision", "nlp", "transformer"]:
            return AcceleratorType.NPU
        else:
            # Check historical performance
            if task_type in self.performance_map:
                return self.performance_map[task_type]
            
            # Default routing
            return AcceleratorType.NPU if self.manager.has_npu else AcceleratorType.CPU
    
    def update_performance(self, task_type: str, accelerator: AcceleratorType, latency: float):
        """Learn from performance data"""
        
        self.routing_history.append({
            "task": task_type,
            "accelerator": accelerator,
            "latency": latency,
            "timestamp": time.time()
        })
        
        # Simple performance tracking
        if task_type not in self.performance_map or latency < self.performance_map.get(f"{task_type}_latency", float('inf')):
            self.performance_map[task_type] = accelerator
            self.performance_map[f"{task_type}_latency"] = latency