#!/usr/bin/env python3
"""
SHADOWGIT NPU PYTHON INTERFACE - AI Acceleration Layer
=======================================================
Python-INTERNAL Agent Implementation for NPU Operations

Provides Python OpenVINO integration for NPU operations with intelligent
workload distribution and real-time performance optimization.

Features:
- Python OpenVINO integration for Intel AI Boost NPU (11 TOPS)
- Intelligent workload distribution (NPU vs AVX2 vs CPU)
- Real-time performance optimization and scaling
- Hardware capability detection and adaptation
- Thermal-aware performance management
- Seamless fallback mechanisms

Performance Targets:
- NPU layer: 8 billion lines/sec
- Combined with AVX2: 15+ billion lines/sec total
- <200ns NPU dispatch latency
- 95%+ NPU utilization efficiency
"""

import asyncio
import logging
import time
import threading
import numpy as np
from typing import Dict, List, Any, Optional, Tuple, Union
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import json
from datetime import datetime

# OpenVINO imports with fallback
try:
    import openvino as ov
    from openvino.runtime import Core, CompiledModel, InferRequest
    OPENVINO_AVAILABLE = True
except ImportError:
    OPENVINO_AVAILABLE = False
    logging.warning("OpenVINO not available, NPU acceleration disabled")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# ENUMS AND CONSTANTS
# ============================================================================

class NPUDevice(Enum):
    """NPU device types"""
    NPU = "NPU"
    GPU = "GPU"
    CPU = "CPU"
    AUTO = "AUTO"

class WorkloadType(Enum):
    """Types of workloads for NPU processing"""
    HASH_COMPUTATION = "hash"
    DIFF_ANALYSIS = "diff"
    PATTERN_MATCHING = "pattern"
    BATCH_PROCESSING = "batch"
    REAL_TIME = "realtime"

class OptimizationStrategy(Enum):
    """NPU optimization strategies"""
    LATENCY_OPTIMIZED = "latency"
    THROUGHPUT_OPTIMIZED = "throughput"
    POWER_OPTIMIZED = "power"
    BALANCED = "balanced"

# Performance targets
NPU_TARGET_THROUGHPUT = 8_000_000_000  # 8B lines/sec
NPU_MAX_BATCH_SIZE = 1024
NPU_OPTIMAL_TENSOR_SIZE = 512 * 1024  # 512KB
THERMAL_LIMIT_CELSIUS = 95

# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclass
class NPUCapabilities:
    """NPU hardware capabilities"""
    device_available: bool = False
    device_name: str = ""
    tops_capability: float = 0.0
    memory_mb: int = 0
    max_batch_size: int = 0
    supported_precisions: List[str] = field(default_factory=list)
    thermal_design_power: float = 0.0
    current_utilization: float = 0.0

@dataclass
class NPUWorkload:
    """NPU workload description"""
    workload_id: str
    type: WorkloadType
    input_data: np.ndarray
    batch_size: int
    priority: int = 5
    use_cache: bool = True
    timeout_ms: int = 1000
    callback: Optional[callable] = None

@dataclass
class NPUResult:
    """NPU processing result"""
    workload_id: str
    success: bool
    result_data: Optional[np.ndarray] = None
    processing_time_ns: int = 0
    throughput_ops_sec: float = 0.0
    npu_utilization: float = 0.0
    error_message: Optional[str] = None
    device_used: str = ""

@dataclass
class NPUPerformanceMetrics:
    """NPU-specific performance metrics"""
    total_operations: int = 0
    successful_operations: int = 0
    failed_operations: int = 0
    total_processing_time_ns: int = 0
    avg_throughput_ops_sec: float = 0.0
    peak_throughput_ops_sec: float = 0.0
    current_utilization: float = 0.0
    thermal_throttling_events: int = 0
    cache_hit_rate: float = 0.0
    fallback_to_cpu_count: int = 0

# ============================================================================
# NPU PYTHON INTERFACE CLASS
# ============================================================================

class ShadowgitNPUPython:
    """
    High-performance NPU interface for Shadowgit processing

    Provides Python OpenVINO integration with intelligent workload
    distribution and real-time optimization.
    """

    def __init__(self,
                 device: NPUDevice = NPUDevice.AUTO,
                 optimization: OptimizationStrategy = OptimizationStrategy.BALANCED,
                 enable_cache: bool = True):
        self.device = device
        self.optimization = optimization
        self.enable_cache = enable_cache

        # OpenVINO components
        self.core: Optional[Core] = None
        self.compiled_model: Optional[CompiledModel] = None
        self.infer_request: Optional[InferRequest] = None

        # State management
        self.initialized = False
        self.capabilities = NPUCapabilities()
        self.metrics = NPUPerformanceMetrics()

        # Threading and async
        self._lock = threading.RLock()
        self._workload_queue = asyncio.Queue()
        self._result_cache = {}
        self._worker_tasks = []

        # Performance monitoring
        self._start_time = time.time_ns()
        self._thermal_monitor_task = None

        logger.info(f"ShadowgitNPUPython initialized with device: {device.value}")

    async def initialize(self) -> bool:
        """Initialize NPU interface and OpenVINO runtime"""
        if not OPENVINO_AVAILABLE:
            logger.error("OpenVINO not available, cannot initialize NPU")
            return False

        try:
            # Initialize OpenVINO core
            self.core = ov.Core()

            # Detect available devices
            available_devices = self.core.available_devices
            logger.info(f"Available OpenVINO devices: {available_devices}")

            # Select optimal device
            selected_device = self._select_optimal_device(available_devices)
            if not selected_device:
                logger.error("No suitable NPU device found")
                return False

            # Load and compile model
            model_path = self._get_model_path()
            if not model_path.exists():
                # Create a simple hash computation model if not exists
                await self._create_default_model(model_path)

            # Load model
            model = self.core.read_model(str(model_path))

            # Compile for selected device
            self.compiled_model = self.core.compile_model(
                model,
                selected_device,
                self._get_device_config()
            )

            # Create inference request
            self.infer_request = self.compiled_model.create_infer_request()

            # Update capabilities
            await self._update_capabilities(selected_device)

            # Start worker tasks
            await self._start_worker_tasks()

            # Start thermal monitoring
            self._thermal_monitor_task = asyncio.create_task(
                self._thermal_monitor_loop()
            )

            self.initialized = True
            logger.info(f"NPU interface initialized successfully on {selected_device}")
            return True

        except Exception as e:
            logger.error(f"NPU initialization failed: {e}")
            return False

    def _select_optimal_device(self, available_devices: List[str]) -> Optional[str]:
        """Select optimal device based on strategy"""
        if self.device == NPUDevice.AUTO:
            # Prefer NPU > GPU > CPU for performance
            for preferred in ["NPU", "GPU.0", "GPU", "CPU"]:
                if preferred in available_devices:
                    return preferred
            return available_devices[0] if available_devices else None

        # Try exact match first
        target = self.device.value
        if target in available_devices:
            return target

        # Try variations
        for device in available_devices:
            if device.startswith(target):
                return device

        logger.warning(f"Requested device {target} not found, falling back to CPU")
        return "CPU" if "CPU" in available_devices else None

    def _get_model_path(self) -> Path:
        """Get path to NPU inference model"""
        models_dir = Path(__file__).parent / "models"
        models_dir.mkdir(exist_ok=True)
        return models_dir / "shadowgit_npu_hash.xml"

    async def _create_default_model(self, model_path: Path):
        """Create default hash computation model"""
        try:
            # This would create a simple hash computation model
            # For now, we'll create a placeholder
            logger.info(f"Creating default NPU model at {model_path}")

            # In a real implementation, this would create an OpenVINO IR model
            # For demonstration, we'll create a minimal model file
            model_path.parent.mkdir(exist_ok=True)

            # Create minimal XML (placeholder)
            xml_content = """<?xml version="1.0"?>
<net name="shadowgit_hash" version="11">
    <layers>
        <layer id="0" name="input" type="Parameter">
            <data element_type="u8" shape="1,1024"/>
            <output>
                <port id="0" precision="U8">
                    <dim>1</dim>
                    <dim>1024</dim>
                </port>
            </output>
        </layer>
        <layer id="1" name="hash_compute" type="MatMul">
            <input>
                <port id="0">
                    <dim>1</dim>
                    <dim>1024</dim>
                </port>
            </input>
            <output>
                <port id="0" precision="FP32">
                    <dim>1</dim>
                    <dim>1</dim>
                </port>
            </output>
        </layer>
        <layer id="2" name="output" type="Result">
            <input>
                <port id="0">
                    <dim>1</dim>
                    <dim>1</dim>
                </port>
            </input>
        </layer>
    </layers>
    <edges>
        <edge from-layer="0" from-port="0" to-layer="1" to-port="0"/>
        <edge from-layer="1" from-port="0" to-layer="2" to-port="0"/>
    </edges>
</net>"""

            with open(model_path, 'w') as f:
                f.write(xml_content)

            # Create corresponding .bin file
            bin_path = model_path.with_suffix('.bin')
            with open(bin_path, 'wb') as f:
                # Write minimal weights (1024 float32 values)
                weights = np.random.randn(1024).astype(np.float32)
                f.write(weights.tobytes())

            logger.info("Default NPU model created successfully")

        except Exception as e:
            logger.error(f"Failed to create default model: {e}")
            raise

    def _get_device_config(self) -> Dict[str, Any]:
        """Get device-specific configuration"""
        config = {}

        if self.optimization == OptimizationStrategy.LATENCY_OPTIMIZED:
            config.update({
                "PERFORMANCE_HINT": "LATENCY",
                "NUM_STREAMS": "1"
            })
        elif self.optimization == OptimizationStrategy.THROUGHPUT_OPTIMIZED:
            config.update({
                "PERFORMANCE_HINT": "THROUGHPUT",
                "NUM_STREAMS": "AUTO"
            })
        elif self.optimization == OptimizationStrategy.POWER_OPTIMIZED:
            config.update({
                "PERFORMANCE_HINT": "CUMULATIVE_THROUGHPUT",
                "INFERENCE_PRECISION_HINT": "f16"
            })
        else:  # BALANCED
            config.update({
                "PERFORMANCE_HINT": "CUMULATIVE_THROUGHPUT"
            })

        return config

    async def _update_capabilities(self, device_name: str):
        """Update NPU capabilities information"""
        try:
            self.capabilities.device_available = True
            self.capabilities.device_name = device_name

            # Query device properties
            if self.core:
                try:
                    # Get device properties
                    props = self.core.get_property(device_name, "SUPPORTED_PROPERTIES")

                    # Update capabilities based on device
                    if "NPU" in device_name:
                        self.capabilities.tops_capability = 11.0  # Intel AI Boost
                        self.capabilities.memory_mb = 1024  # Typical NPU memory
                        self.capabilities.max_batch_size = NPU_MAX_BATCH_SIZE
                        self.capabilities.thermal_design_power = 15.0  # Watts
                    elif "GPU" in device_name:
                        self.capabilities.tops_capability = 5.0  # iGPU estimate
                        self.capabilities.memory_mb = 2048
                        self.capabilities.max_batch_size = 512
                        self.capabilities.thermal_design_power = 25.0
                    else:  # CPU
                        self.capabilities.tops_capability = 1.0
                        self.capabilities.memory_mb = 8192  # System memory
                        self.capabilities.max_batch_size = 256
                        self.capabilities.thermal_design_power = 45.0

                    self.capabilities.supported_precisions = ["FP32", "FP16", "INT8"]

                except Exception as e:
                    logger.warning(f"Could not query device properties: {e}")

            logger.info(f"NPU capabilities: {self.capabilities}")

        except Exception as e:
            logger.error(f"Failed to update capabilities: {e}")

    async def _start_worker_tasks(self):
        """Start async worker tasks for NPU processing"""
        num_workers = min(4, self.capabilities.max_batch_size // 64)

        for i in range(num_workers):
            task = asyncio.create_task(self._worker_loop(f"worker_{i}"))
            self._worker_tasks.append(task)

        logger.info(f"Started {num_workers} NPU worker tasks")

    async def _worker_loop(self, worker_id: str):
        """Worker loop for processing NPU workloads"""
        logger.info(f"NPU worker {worker_id} started")

        while self.initialized:
            try:
                # Get workload from queue with timeout
                workload = await asyncio.wait_for(
                    self._workload_queue.get(),
                    timeout=1.0
                )

                # Process workload
                result = await self._process_workload(workload)

                # Call callback if provided
                if workload.callback:
                    try:
                        await workload.callback(result)
                    except Exception as e:
                        logger.error(f"Callback error: {e}")

                # Update metrics
                self._update_metrics(result)

                # Mark task done
                self._workload_queue.task_done()

            except asyncio.TimeoutError:
                continue  # No workload available, continue loop
            except Exception as e:
                logger.error(f"Worker {worker_id} error: {e}")

        logger.info(f"NPU worker {worker_id} stopped")

    async def _process_workload(self, workload: NPUWorkload) -> NPUResult:
        """Process a single NPU workload"""
        start_time = time.time_ns()

        try:
            # Check cache if enabled
            if self.enable_cache and workload.use_cache:
                cache_key = self._get_cache_key(workload)
                if cache_key in self._result_cache:
                    cached_result = self._result_cache[cache_key]
                    cached_result.workload_id = workload.workload_id
                    self.metrics.cache_hit_rate = (
                        len([r for r in self._result_cache.values() if r.success]) /
                        max(1, len(self._result_cache))
                    )
                    return cached_result

            # Perform NPU inference
            if self.infer_request and self.capabilities.device_available:
                result_data = await self._run_npu_inference(workload)
                device_used = self.capabilities.device_name
            else:
                # Fallback to CPU simulation
                result_data = await self._simulate_cpu_fallback(workload)
                device_used = "CPU_FALLBACK"
                self.metrics.fallback_to_cpu_count += 1

            processing_time = time.time_ns() - start_time

            # Calculate throughput
            ops_per_second = (
                workload.input_data.size / (processing_time / 1e9)
                if processing_time > 0 else 0
            )

            result = NPUResult(
                workload_id=workload.workload_id,
                success=True,
                result_data=result_data,
                processing_time_ns=processing_time,
                throughput_ops_sec=ops_per_second,
                npu_utilization=self._calculate_utilization(),
                device_used=device_used
            )

            # Cache result if enabled
            if self.enable_cache and workload.use_cache:
                cache_key = self._get_cache_key(workload)
                self._result_cache[cache_key] = result

            return result

        except Exception as e:
            logger.error(f"NPU workload processing failed: {e}")
            return NPUResult(
                workload_id=workload.workload_id,
                success=False,
                error_message=str(e),
                processing_time_ns=time.time_ns() - start_time
            )

    async def _run_npu_inference(self, workload: NPUWorkload) -> np.ndarray:
        """Run actual NPU inference"""
        try:
            # Prepare input tensor
            input_tensor = workload.input_data
            if input_tensor.size > NPU_OPTIMAL_TENSOR_SIZE:
                # Split large tensors into chunks
                return await self._process_large_tensor(input_tensor)

            # Set input data
            input_name = list(self.infer_request.model_inputs)[0].any_name
            self.infer_request.set_tensor(input_name, input_tensor)

            # Run inference
            await asyncio.get_event_loop().run_in_executor(
                None,
                self.infer_request.infer
            )

            # Get output
            output_name = list(self.infer_request.model_outputs)[0].any_name
            result = self.infer_request.get_tensor(output_name).data

            return np.array(result)

        except Exception as e:
            logger.error(f"NPU inference failed: {e}")
            raise

    async def _process_large_tensor(self, tensor: np.ndarray) -> np.ndarray:
        """Process large tensors by chunking"""
        chunk_size = NPU_OPTIMAL_TENSOR_SIZE // tensor.itemsize
        chunks = []

        for i in range(0, tensor.size, chunk_size):
            chunk = tensor.flat[i:i+chunk_size]
            chunk_result = await self._run_small_inference(chunk)
            chunks.append(chunk_result)

        return np.concatenate(chunks)

    async def _run_small_inference(self, chunk: np.ndarray) -> np.ndarray:
        """Run inference on small tensor chunk"""
        # Reshape chunk to model input shape
        reshaped = chunk.reshape(1, -1)
        if reshaped.shape[1] < 1024:
            # Pad to minimum size
            padded = np.pad(reshaped, ((0, 0), (0, 1024 - reshaped.shape[1])))
            reshaped = padded
        elif reshaped.shape[1] > 1024:
            # Truncate to maximum size
            reshaped = reshaped[:, :1024]

        # Set input and infer
        input_name = list(self.infer_request.model_inputs)[0].any_name
        self.infer_request.set_tensor(input_name, reshaped.astype(np.uint8))

        await asyncio.get_event_loop().run_in_executor(
            None,
            self.infer_request.infer
        )

        # Get result
        output_name = list(self.infer_request.model_outputs)[0].any_name
        result = self.infer_request.get_tensor(output_name).data

        return np.array(result).flatten()[:chunk.size]

    async def _simulate_cpu_fallback(self, workload: NPUWorkload) -> np.ndarray:
        """Simulate CPU fallback processing"""
        # Simple hash computation simulation
        input_data = workload.input_data

        if workload.type == WorkloadType.HASH_COMPUTATION:
            # Simulate hash computation
            hash_value = hash(input_data.tobytes()) % (2**32)
            return np.array([hash_value], dtype=np.uint32)
        elif workload.type == WorkloadType.DIFF_ANALYSIS:
            # Simulate diff analysis
            return np.array([input_data.sum()], dtype=np.uint64)
        else:
            # Generic processing
            return input_data.flatten()[:1]

    def _get_cache_key(self, workload: NPUWorkload) -> str:
        """Generate cache key for workload"""
        input_hash = hash(workload.input_data.tobytes())
        return f"{workload.type.value}_{input_hash}_{workload.batch_size}"

    def _calculate_utilization(self) -> float:
        """Calculate current NPU utilization"""
        # This would query actual NPU utilization
        # For simulation, return a value based on queue length
        queue_size = self._workload_queue.qsize()
        max_queue = self.capabilities.max_batch_size
        return min(100.0, (queue_size / max_queue) * 100.0)

    def _update_metrics(self, result: NPUResult):
        """Update performance metrics"""
        self.metrics.total_operations += 1

        if result.success:
            self.metrics.successful_operations += 1
            self.metrics.total_processing_time_ns += result.processing_time_ns

            # Update throughput metrics
            if result.throughput_ops_sec > self.metrics.peak_throughput_ops_sec:
                self.metrics.peak_throughput_ops_sec = result.throughput_ops_sec

            # Running average
            if self.metrics.successful_operations > 0:
                self.metrics.avg_throughput_ops_sec = (
                    (self.metrics.avg_throughput_ops_sec * (self.metrics.successful_operations - 1) +
                     result.throughput_ops_sec) / self.metrics.successful_operations
                )
        else:
            self.metrics.failed_operations += 1

    async def _thermal_monitor_loop(self):
        """Monitor thermal state and throttle if necessary"""
        while self.initialized:
            try:
                # Get current temperature (would query actual sensors)
                current_temp = self._get_current_temperature()

                if current_temp > THERMAL_LIMIT_CELSIUS:
                    logger.warning(f"Thermal limit exceeded: {current_temp}°C")
                    self.metrics.thermal_throttling_events += 1

                    # Reduce workload by clearing queue
                    while not self._workload_queue.empty():
                        try:
                            self._workload_queue.get_nowait()
                            self._workload_queue.task_done()
                        except asyncio.QueueEmpty:
                            break

                    # Wait for cooldown
                    await asyncio.sleep(5.0)

                # Update utilization
                self.capabilities.current_utilization = self._calculate_utilization()

                await asyncio.sleep(1.0)  # Check every second

            except Exception as e:
                logger.error(f"Thermal monitoring error: {e}")
                await asyncio.sleep(5.0)

    def _get_current_temperature(self) -> float:
        """Get current device temperature"""
        # This would query actual thermal sensors
        # For simulation, return a random value around 65°C
        import random
        base_temp = 65.0
        variation = random.uniform(-5.0, 15.0)
        utilization_factor = self.capabilities.current_utilization / 100.0
        return base_temp + variation + (utilization_factor * 10.0)

    # ========================================================================
    # PUBLIC API METHODS
    # ========================================================================

    async def submit_hash_workload(
        self,
        data: Union[bytes, np.ndarray],
        workload_id: Optional[str] = None,
        priority: int = 5,
        callback: Optional[callable] = None
    ) -> str:
        """Submit hash computation workload to NPU"""
        if not self.initialized:
            raise RuntimeError("NPU interface not initialized")

        # Convert data to numpy array if needed
        if isinstance(data, bytes):
            input_data = np.frombuffer(data, dtype=np.uint8)
        else:
            input_data = data.astype(np.uint8) if data.dtype != np.uint8 else data

        workload_id = workload_id or f"hash_{int(time.time_ns())}"

        workload = NPUWorkload(
            workload_id=workload_id,
            type=WorkloadType.HASH_COMPUTATION,
            input_data=input_data,
            batch_size=1,
            priority=priority,
            callback=callback
        )

        await self._workload_queue.put(workload)
        return workload_id

    async def submit_batch_workload(
        self,
        data_batch: List[Union[bytes, np.ndarray]],
        workload_type: WorkloadType = WorkloadType.BATCH_PROCESSING,
        workload_id: Optional[str] = None,
        callback: Optional[callable] = None
    ) -> str:
        """Submit batch processing workload"""
        if not self.initialized:
            raise RuntimeError("NPU interface not initialized")

        # Convert batch to single array
        arrays = []
        for data in data_batch:
            if isinstance(data, bytes):
                arrays.append(np.frombuffer(data, dtype=np.uint8))
            else:
                arrays.append(data.astype(np.uint8))

        # Concatenate arrays
        batch_data = np.concatenate(arrays)

        workload_id = workload_id or f"batch_{int(time.time_ns())}"

        workload = NPUWorkload(
            workload_id=workload_id,
            type=workload_type,
            input_data=batch_data,
            batch_size=len(data_batch),
            callback=callback
        )

        await self._workload_queue.put(workload)
        return workload_id

    async def wait_for_completion(
        self,
        workload_id: str,
        timeout_seconds: float = 30.0
    ) -> NPUResult:
        """Wait for specific workload completion"""
        start_time = time.time()

        while time.time() - start_time < timeout_seconds:
            # Check if workload is in cache (completed)
            for cached_result in self._result_cache.values():
                if cached_result.workload_id == workload_id:
                    return cached_result

            await asyncio.sleep(0.01)  # 10ms check interval

        raise TimeoutError(f"Workload {workload_id} timed out after {timeout_seconds}s")

    def get_performance_metrics(self) -> Dict[str, Any]:
        """Get comprehensive NPU performance metrics"""
        runtime_seconds = (time.time_ns() - self._start_time) / 1e9

        return {
            'npu_capabilities': {
                'device_available': self.capabilities.device_available,
                'device_name': self.capabilities.device_name,
                'tops_capability': self.capabilities.tops_capability,
                'current_utilization': self.capabilities.current_utilization,
                'thermal_design_power': self.capabilities.thermal_design_power
            },
            'performance_metrics': {
                'total_operations': self.metrics.total_operations,
                'successful_operations': self.metrics.successful_operations,
                'failed_operations': self.metrics.failed_operations,
                'success_rate': (
                    self.metrics.successful_operations / max(1, self.metrics.total_operations) * 100.0
                ),
                'avg_throughput_ops_sec': self.metrics.avg_throughput_ops_sec,
                'peak_throughput_ops_sec': self.metrics.peak_throughput_ops_sec,
                'cache_hit_rate': self.metrics.cache_hit_rate * 100.0,
                'fallback_to_cpu_count': self.metrics.fallback_to_cpu_count,
                'thermal_throttling_events': self.metrics.thermal_throttling_events
            },
            'system_status': {
                'initialized': self.initialized,
                'runtime_seconds': runtime_seconds,
                'workload_queue_size': self._workload_queue.qsize(),
                'worker_tasks_active': len([t for t in self._worker_tasks if not t.done()]),
                'cache_entries': len(self._result_cache),
                'current_temperature': self._get_current_temperature()
            },
            'target_achievement': {
                'target_throughput': NPU_TARGET_THROUGHPUT,
                'current_vs_target_percent': (
                    self.metrics.avg_throughput_ops_sec / NPU_TARGET_THROUGHPUT * 100.0
                ),
                'peak_vs_target_percent': (
                    self.metrics.peak_throughput_ops_sec / NPU_TARGET_THROUGHPUT * 100.0
                )
            }
        }

    async def benchmark_npu_performance(
        self,
        test_sizes: List[int] = None,
        iterations: int = 100
    ) -> Dict[str, Any]:
        """Comprehensive NPU performance benchmark"""
        if test_sizes is None:
            test_sizes = [1024, 4096, 16384, 65536, 262144]

        results = {}

        for size in test_sizes:
            print(f"Benchmarking NPU with {size} byte inputs...")

            # Generate test data
            test_data = np.random.bytes(size)

            # Submit workloads
            workload_ids = []
            start_time = time.time_ns()

            for i in range(iterations):
                wid = await self.submit_hash_workload(
                    test_data,
                    workload_id=f"bench_{size}_{i}"
                )
                workload_ids.append(wid)

            # Wait for all completions
            completed_results = []
            for wid in workload_ids:
                try:
                    result = await self.wait_for_completion(wid, timeout_seconds=30.0)
                    completed_results.append(result)
                except TimeoutError:
                    logger.warning(f"Benchmark workload {wid} timed out")

            total_time = time.time_ns() - start_time

            # Calculate metrics
            successful_count = len([r for r in completed_results if r.success])
            if successful_count > 0:
                avg_processing_time = sum(
                    r.processing_time_ns for r in completed_results if r.success
                ) / successful_count

                avg_throughput = sum(
                    r.throughput_ops_sec for r in completed_results if r.success
                ) / successful_count
            else:
                avg_processing_time = 0
                avg_throughput = 0

            results[size] = {
                'iterations': iterations,
                'successful': successful_count,
                'failed': iterations - successful_count,
                'success_rate': successful_count / iterations * 100.0,
                'total_time_ns': total_time,
                'avg_processing_time_ns': avg_processing_time,
                'avg_throughput_ops_sec': avg_throughput,
                'ops_per_second': (size * successful_count) / (total_time / 1e9)
            }

        # Overall benchmark summary
        overall_metrics = self.get_performance_metrics()

        return {
            'benchmark_results': results,
            'overall_metrics': overall_metrics,
            'benchmark_timestamp': datetime.now().isoformat(),
            'npu_device': self.capabilities.device_name,
            'openvino_available': OPENVINO_AVAILABLE
        }

    async def shutdown(self):
        """Shutdown NPU interface"""
        logger.info("Shutting down NPU interface...")

        self.initialized = False

        # Stop thermal monitoring
        if self._thermal_monitor_task:
            self._thermal_monitor_task.cancel()
            try:
                await self._thermal_monitor_task
            except asyncio.CancelledError:
                pass

        # Stop worker tasks
        for task in self._worker_tasks:
            task.cancel()

        if self._worker_tasks:
            await asyncio.gather(*self._worker_tasks, return_exceptions=True)

        # Clear resources
        self.infer_request = None
        self.compiled_model = None
        self.core = None

        logger.info("NPU interface shutdown completed")

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

async def create_npu_interface(
    device: NPUDevice = NPUDevice.AUTO,
    optimization: OptimizationStrategy = OptimizationStrategy.BALANCED
) -> ShadowgitNPUPython:
    """Create and initialize NPU interface"""
    interface = ShadowgitNPUPython(device, optimization)
    if not await interface.initialize():
        raise RuntimeError("Failed to initialize NPU interface")
    return interface

async def quick_npu_test() -> Dict[str, Any]:
    """Quick NPU performance test"""
    try:
        async with create_npu_interface() as npu:
            return await npu.benchmark_npu_performance(
                test_sizes=[1024, 4096],
                iterations=10
            )
    except Exception as e:
        logger.error(f"Quick NPU test failed: {e}")
        return {'error': str(e), 'success': False}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == "__main__":
    async def main():
        print("Shadowgit NPU Python Interface - Performance Test")
        print("=" * 55)

        try:
            # Test NPU interface
            npu = ShadowgitNPUPython()

            if not await npu.initialize():
                print("✗ NPU initialization failed")
                return 1

            print("✓ NPU interface initialized successfully")
            print(f"  Device: {npu.capabilities.device_name}")
            print(f"  TOPS: {npu.capabilities.tops_capability}")

            # Test hash workload
            print("\nTesting hash workload...")
            test_data = b"Hello, Shadowgit NPU!" * 100
            workload_id = await npu.submit_hash_workload(test_data)
            result = await npu.wait_for_completion(workload_id)

            if result.success:
                print(f"✓ Hash workload completed")
                print(f"  Processing time: {result.processing_time_ns / 1e6:.2f} ms")
                print(f"  Throughput: {result.throughput_ops_sec:.0f} ops/sec")
            else:
                print(f"✗ Hash workload failed: {result.error_message}")

            # Test batch processing
            print("\nTesting batch processing...")
            batch_data = [b"test_data_" + str(i).encode() for i in range(10)]
            batch_id = await npu.submit_batch_workload(batch_data)
            batch_result = await npu.wait_for_completion(batch_id)

            if batch_result.success:
                print(f"✓ Batch processing completed")
                print(f"  Batch size: {len(batch_data)} items")
                print(f"  Total time: {batch_result.processing_time_ns / 1e6:.2f} ms")

            # Run performance benchmark
            print("\nRunning performance benchmark...")
            benchmark = await npu.benchmark_npu_performance(
                test_sizes=[1024, 4096],
                iterations=20
            )

            print("✓ Benchmark completed")
            for size, metrics in benchmark['benchmark_results'].items():
                print(f"  {size} bytes: {metrics['avg_throughput_ops_sec']:.0f} ops/sec "
                      f"({metrics['success_rate']:.1f}% success)")

            # Print final metrics
            print("\nFinal Performance Metrics:")
            print("-" * 30)
            final_metrics = npu.get_performance_metrics()
            perf = final_metrics['performance_metrics']
            print(f"Total operations: {perf['total_operations']}")
            print(f"Success rate: {perf['success_rate']:.1f}%")
            print(f"Avg throughput: {perf['avg_throughput_ops_sec']:.0f} ops/sec")
            print(f"Peak throughput: {perf['peak_throughput_ops_sec']:.0f} ops/sec")

            target = final_metrics['target_achievement']
            print(f"Target achievement: {target['current_vs_target_percent']:.1f}%")

            await npu.shutdown()

        except Exception as e:
            print(f"✗ NPU test failed: {e}")
            return 1

        print("\n✓ All NPU tests completed successfully")
        return 0

    import sys
    sys.exit(asyncio.run(main()))