#!/usr/bin/env python3
"""
Shadowgit Phase 3 Acceleration Orchestrator
===========================================
Team Delta - Python orchestrator for Phase 3 acceleration

Integrates:
- Shadowgit AVX2 (930M lines/sec) via C bridge
- Phase 3 async pipeline components
- Intel NPU processing (11 TOPS)
- io_uring async I/O acceleration
- AVX-512 upgrade path coordination

Target: 3.8x improvement (930M → 3.5B lines/sec)
Ultimate goal: 10B+ lines/sec with full hardware utilization
"""

import asyncio
import os
import sys
import time
import json
import logging
import subprocess
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, asdict
from pathlib import Path
import threading
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict, deque
import ctypes
from ctypes import Structure, c_char, c_char_p, c_int, c_uint64, c_double, c_bool

# Add agents/src/python to path for Phase 3 components
sys.path.insert(0, '/home/john/claude-backups/agents/src/python')

# Import Phase 3 components
try:
    from intel_npu_async_pipeline import AsyncPipelineOrchestrator, AsyncTask, ProcessingResult
    from io_uring_bridge import AsyncIOAccelerator, IORequest
    from avx512_vectorizer import VectorizedPipelineProcessor, VectorTask
    PHASE3_COMPONENTS_AVAILABLE = True
except ImportError as e:
    PHASE3_COMPONENTS_AVAILABLE = False
    print(f"Phase 3 components not available: {e}")

# Import existing integration components
try:
    from phase3_async_integration import IntegratedAsyncPipeline, IntegratedTask, IntegratedResult
    INTEGRATION_AVAILABLE = True
except ImportError:
    INTEGRATION_AVAILABLE = False
    print("Phase 3 integration not available - running in standalone mode")

# C library integration
SHADOWGIT_LIB_PATH = "/home/john/claude-backups/shadowgit_phase3_integration.so"

# C structures (matching the C code)
class DiffResult(Structure):
    _fields_ = [
        ("total_lines_old", c_uint64),
        ("total_lines_new", c_uint64),
        ("additions", c_uint64),
        ("deletions", c_uint64),
        ("modifications", c_uint64),
        ("processing_time_ns", c_uint64),
        ("similarity_score", c_double)
    ]

class Phase3Metrics(Structure):
    _fields_ = [
        ("total_tasks", c_uint64),
        ("completed_tasks", c_uint64),
        ("lines_processed", c_uint64),
        ("total_processing_time", c_double),
        ("avx512_accelerated", c_uint64),
        ("npu_accelerated", c_uint64),
        ("io_uring_operations", c_uint64),
        ("peak_lines_per_second", c_double),
        ("avg_lines_per_second", c_double),
        ("current_speedup", c_double),
        ("hardware_flags", c_uint64)
    ]

@dataclass
class ShadowgitTask:
    """Shadowgit-specific diff task"""
    task_id: str
    file1_path: str
    file2_path: str
    priority: int = 1
    use_phase3_acceleration: bool = True
    use_npu_boost: bool = False
    created_at: float = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = time.time()

@dataclass
class ShadowgitResult:
    """Result from Shadowgit processing"""
    task_id: str
    diff_result: Optional[DiffResult]
    processing_time_ms: float
    lines_per_second: float
    speedup_vs_baseline: float
    hardware_used: Dict[str, bool]
    error: Optional[str] = None

class ShadowgitC:
    """C library interface for Phase 3 integration"""
    
    def __init__(self):
        self.lib = None
        self.available = False
        self._load_library()
    
    def _load_library(self):
        """Load the C library"""
        try:
            # Compile if needed
            if not os.path.exists(SHADOWGIT_LIB_PATH):
                self._compile_library()
            
            # Load library
            self.lib = ctypes.CDLL(SHADOWGIT_LIB_PATH)
            self._setup_function_signatures()
            self.available = True
            logging.info("Shadowgit C library loaded successfully")
            
        except Exception as e:
            logging.error(f"Failed to load Shadowgit C library: {e}")
            self.available = False
    
    def _compile_library(self):
        """Compile the C integration library"""
        try:
            source_file = "/home/john/claude-backups/shadowgit_phase3_integration.c"
            
            # Compilation command
            compile_cmd = [
                "gcc", "-shared", "-fPIC", "-O3", "-march=native",
                "-mavx2", "-mfma", "-mbmi2",  # Enable AVX2 optimizations
                "-pthread", "-lm", "-lrt",
                "-I/home/john/shadowgit/c_src_avx2",  # Include Shadowgit headers
                source_file,
                "/home/john/shadowgit/c_src_avx2/shadowgit_avx2_diff.c",  # Link Shadowgit
                "-o", SHADOWGIT_LIB_PATH
            ]
            
            logging.info("Compiling Shadowgit Phase 3 integration...")
            result = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                raise Exception(f"Compilation failed: {result.stderr}")
            
            logging.info("Shadowgit C library compiled successfully")
            
        except subprocess.TimeoutExpired:
            raise Exception("Compilation timed out")
        except Exception as e:
            raise Exception(f"Compilation error: {e}")
    
    def _setup_function_signatures(self):
        """Setup C function signatures"""
        # Initialize function
        self.lib.phase3_initialize.argtypes = []
        self.lib.phase3_initialize.restype = c_int
        
        # Shutdown function
        self.lib.phase3_shutdown.argtypes = []
        self.lib.phase3_shutdown.restype = None
        
        # Submit task function
        self.lib.phase3_submit_diff_task.argtypes = [c_char_p, c_char_p, c_char_p, c_int]
        self.lib.phase3_submit_diff_task.restype = c_int
        
        # Get metrics function
        self.lib.phase3_get_metrics.argtypes = []
        self.lib.phase3_get_metrics.restype = Phase3Metrics
        
        # Print report function
        self.lib.phase3_print_performance_report.argtypes = []
        self.lib.phase3_print_performance_report.restype = None
    
    def initialize(self) -> bool:
        """Initialize Phase 3 system"""
        if not self.available:
            return False
        return self.lib.phase3_initialize() == 0
    
    def shutdown(self):
        """Shutdown Phase 3 system"""
        if self.available:
            self.lib.phase3_shutdown()
    
    def submit_diff_task(self, task_id: str, file1: str, file2: str, priority: int = 1) -> bool:
        """Submit diff task for processing"""
        if not self.available:
            return False
        
        return self.lib.phase3_submit_diff_task(
            task_id.encode('utf-8'),
            file1.encode('utf-8'),
            file2.encode('utf-8'),
            priority
        ) == 0
    
    def get_metrics(self) -> Optional[Phase3Metrics]:
        """Get performance metrics"""
        if not self.available:
            return None
        return self.lib.phase3_get_metrics()
    
    def print_performance_report(self):
        """Print performance report"""
        if self.available:
            self.lib.phase3_print_performance_report()

class ShadowgitAccelerator:
    """
    Main orchestrator for Shadowgit Phase 3 acceleration
    Coordinates C library, Phase 3 components, and performance monitoring
    """
    
    def __init__(self):
        # Core components
        self.c_lib = ShadowgitC()
        self.integrated_pipeline = None
        self.phase3_orchestrator = None
        
        # Phase 3 component integration
        if PHASE3_COMPONENTS_AVAILABLE:
            self._initialize_phase3_components()
        
        # Performance tracking
        self.performance_history = deque(maxlen=1000)
        self.baseline_performance = 930000000.0  # 930M lines/sec from Shadowgit AVX2
        self.target_performance = 3500000000.0   # 3.5B lines/sec target
        
        # Task tracking
        self.submitted_tasks = {}
        self.completed_tasks = {}
        self.task_counter = 0
        self.start_time = None
        
        # Threading
        self._running = False
        self.monitor_thread = None
        
        # Metrics aggregation
        self.cumulative_metrics = {
            "total_tasks": 0,
            "completed_tasks": 0,
            "total_lines": 0,
            "total_time_ms": 0.0,
            "avg_lines_per_sec": 0.0,
            "peak_lines_per_sec": 0.0,
            "speedup_achieved": 0.0,
            "hardware_utilization": {
                "avx512_tasks": 0,
                "npu_tasks": 0,
                "io_uring_operations": 0
            }
        }
    
    def _initialize_phase3_components(self):
        """Initialize Phase 3 async components"""
        try:
            if INTEGRATION_AVAILABLE:
                self.integrated_pipeline = IntegratedAsyncPipeline()
            else:
                # Initialize individual components
                self.phase3_orchestrator = AsyncPipelineOrchestrator()
            
            logging.info("Phase 3 components initialized")
            
        except Exception as e:
            logging.error(f"Failed to initialize Phase 3 components: {e}")
    
    async def start(self):
        """Start the Shadowgit accelerator"""
        if self._running:
            return
        
        self._running = True
        self.start_time = time.time()
        
        # Initialize C library
        if self.c_lib.available:
            if not self.c_lib.initialize():
                logging.error("Failed to initialize C library")
                return
        
        # Start Phase 3 components
        if self.integrated_pipeline:
            await self.integrated_pipeline.start()
        elif self.phase3_orchestrator:
            await self.phase3_orchestrator.start()
        
        # Start monitoring
        self.monitor_thread = threading.Thread(target=self._monitor_performance, daemon=True)
        self.monitor_thread.start()
        
        logging.info("Shadowgit accelerator started - All systems operational")
    
    async def stop(self):
        """Stop the accelerator"""
        if not self._running:
            return
        
        self._running = False
        
        # Stop Phase 3 components
        if self.integrated_pipeline:
            await self.integrated_pipeline.stop()
        elif self.phase3_orchestrator:
            await self.phase3_orchestrator.stop()
        
        # Stop C library
        if self.c_lib.available:
            self.c_lib.shutdown()
        
        # Wait for monitor thread
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=2.0)
        
        logging.info("Shadowgit accelerator stopped")
    
    async def submit_diff_task(self, task: ShadowgitTask) -> str:
        """Submit diff task for accelerated processing"""
        if not self._running:
            raise RuntimeError("Accelerator not started")
        
        self.task_counter += 1
        unique_task_id = f"{task.task_id}_{self.task_counter:06d}"
        
        # Track task
        self.submitted_tasks[unique_task_id] = {
            "task": task,
            "submitted_at": time.time(),
            "status": "submitted"
        }
        
        # Submit to C library (primary path)
        c_success = False
        if self.c_lib.available:
            c_success = self.c_lib.submit_diff_task(
                unique_task_id, 
                task.file1_path, 
                task.file2_path, 
                task.priority
            )
        
        # Submit to Phase 3 pipeline (parallel acceleration)
        phase3_success = False
        if task.use_phase3_acceleration and self.integrated_pipeline:
            try:
                integrated_task = IntegratedTask(
                    task_id=f"phase3_{unique_task_id}",
                    prompt=f"diff {task.file1_path} {task.file2_path}",
                    agent_type="optimizer",
                    priority=task.priority,
                    use_npu=task.use_npu_boost,
                    use_vectorization=True,
                    use_async_io=True
                )
                
                phase3_task_id = await self.integrated_pipeline.submit_task(integrated_task)
                phase3_success = bool(phase3_task_id)
                
            except Exception as e:
                logging.error(f"Phase 3 submission failed: {e}")
        
        # Update task status
        self.submitted_tasks[unique_task_id]["c_submitted"] = c_success
        self.submitted_tasks[unique_task_id]["phase3_submitted"] = phase3_success
        
        if c_success or phase3_success:
            return unique_task_id
        else:
            raise RuntimeError("Failed to submit to any processing system")
    
    def _monitor_performance(self):
        """Background performance monitoring"""
        while self._running:
            try:
                time.sleep(2.0)  # Update every 2 seconds
                
                # Get C library metrics
                if self.c_lib.available:
                    c_metrics = self.c_lib.get_metrics()
                    if c_metrics:
                        self._update_metrics_from_c(c_metrics)
                
                # Get Phase 3 metrics
                if self.integrated_pipeline:
                    try:
                        phase3_metrics = self.integrated_pipeline.get_comprehensive_metrics()
                        self._update_metrics_from_phase3(phase3_metrics)
                    except Exception as e:
                        logging.debug(f"Phase 3 metrics error: {e}")
                
                # Calculate overall performance
                self._calculate_overall_performance()
                
            except Exception as e:
                logging.error(f"Performance monitoring error: {e}")
    
    def _update_metrics_from_c(self, c_metrics: Phase3Metrics):
        """Update metrics from C library"""
        self.cumulative_metrics["total_tasks"] = max(
            self.cumulative_metrics["total_tasks"], 
            c_metrics.total_tasks
        )
        self.cumulative_metrics["completed_tasks"] = max(
            self.cumulative_metrics["completed_tasks"],
            c_metrics.completed_tasks
        )
        
        if c_metrics.avg_lines_per_second > 0:
            self.cumulative_metrics["avg_lines_per_sec"] = c_metrics.avg_lines_per_second
            self.cumulative_metrics["speedup_achieved"] = c_metrics.current_speedup
        
        if c_metrics.peak_lines_per_second > self.cumulative_metrics["peak_lines_per_sec"]:
            self.cumulative_metrics["peak_lines_per_sec"] = c_metrics.peak_lines_per_second
        
        # Hardware utilization
        self.cumulative_metrics["hardware_utilization"]["avx512_tasks"] = c_metrics.avx512_accelerated
        self.cumulative_metrics["hardware_utilization"]["npu_tasks"] = c_metrics.npu_accelerated
        self.cumulative_metrics["hardware_utilization"]["io_uring_operations"] = c_metrics.io_uring_operations
    
    def _update_metrics_from_phase3(self, phase3_metrics: Dict[str, Any]):
        """Update metrics from Phase 3 pipeline"""
        try:
            summary = phase3_metrics.get("integration_summary", {})
            
            # Add Phase 3 tasks to totals
            phase3_completed = summary.get("completed_tasks", 0)
            self.cumulative_metrics["completed_tasks"] += phase3_completed
            
            # Consider Phase 3 speedup contribution
            phase3_speedup = summary.get("current_speedup", 0)
            if phase3_speedup > 0:
                # Weighted average of C and Phase 3 performance
                c_weight = 0.7  # C library is primary
                phase3_weight = 0.3  # Phase 3 is supplementary
                
                current_speedup = self.cumulative_metrics.get("speedup_achieved", 1.0)
                blended_speedup = (c_weight * current_speedup) + (phase3_weight * phase3_speedup)
                self.cumulative_metrics["speedup_achieved"] = blended_speedup
                
        except Exception as e:
            logging.debug(f"Phase 3 metrics processing error: {e}")
    
    def _calculate_overall_performance(self):
        """Calculate overall system performance"""
        if self.cumulative_metrics["speedup_achieved"] > 0:
            estimated_lines_per_sec = self.baseline_performance * self.cumulative_metrics["speedup_achieved"]
            self.cumulative_metrics["avg_lines_per_sec"] = estimated_lines_per_sec
            
            # Track performance history
            self.performance_history.append({
                "timestamp": time.time(),
                "lines_per_sec": estimated_lines_per_sec,
                "speedup": self.cumulative_metrics["speedup_achieved"],
                "completed_tasks": self.cumulative_metrics["completed_tasks"]
            })
    
    def get_comprehensive_metrics(self) -> Dict[str, Any]:
        """Get comprehensive performance metrics"""
        runtime = time.time() - self.start_time if self.start_time else 0
        
        # Target achievement calculation
        target_achievement = 0
        if self.target_performance > 0 and self.cumulative_metrics["avg_lines_per_sec"] > 0:
            target_achievement = (self.cumulative_metrics["avg_lines_per_sec"] / self.target_performance) * 100
        
        return {
            "shadowgit_summary": {
                "total_tasks": self.cumulative_metrics["total_tasks"],
                "completed_tasks": self.cumulative_metrics["completed_tasks"],
                "runtime_seconds": runtime,
                "tasks_per_second": self.cumulative_metrics["completed_tasks"] / max(1, runtime)
            },
            "performance_metrics": {
                "baseline_lines_per_sec": self.baseline_performance,
                "current_lines_per_sec": self.cumulative_metrics["avg_lines_per_sec"],
                "peak_lines_per_sec": self.cumulative_metrics["peak_lines_per_sec"],
                "target_lines_per_sec": self.target_performance,
                "speedup_achieved": self.cumulative_metrics["speedup_achieved"],
                "target_achievement_percent": target_achievement
            },
            "hardware_utilization": {
                **self.cumulative_metrics["hardware_utilization"],
                "c_library_available": self.c_lib.available,
                "phase3_components_available": PHASE3_COMPONENTS_AVAILABLE,
                "integration_available": INTEGRATION_AVAILABLE
            },
            "system_status": {
                "shadowgit_c_active": self.c_lib.available,
                "phase3_pipeline_active": self.integrated_pipeline is not None,
                "monitoring_active": self._running and self.monitor_thread and self.monitor_thread.is_alive(),
                "target_met": target_achievement >= 100.0
            }
        }
    
    def print_performance_report(self):
        """Print comprehensive performance report"""
        print("\n" + "=" * 80)
        print("TEAM DELTA - SHADOWGIT PHASE 3 ACCELERATION REPORT")
        print("Hardware-accelerated Git diff processing with 3.8x target improvement")
        print("=" * 80)
        
        metrics = self.get_comprehensive_metrics()
        
        # Summary
        summary = metrics["shadowgit_summary"]
        print(f"\nExecution Summary:")
        print(f"  Total Tasks: {summary['total_tasks']}")
        print(f"  Completed Tasks: {summary['completed_tasks']}")
        print(f"  Runtime: {summary['runtime_seconds']:.1f}s")
        print(f"  Throughput: {summary['tasks_per_second']:.1f} tasks/sec")
        
        # Performance
        perf = metrics["performance_metrics"]
        print(f"\nPerformance Metrics:")
        print(f"  Shadowgit AVX2 Baseline: {perf['baseline_lines_per_sec']:,.0f} lines/sec")
        print(f"  Current Performance: {perf['current_lines_per_sec']:,.0f} lines/sec")
        print(f"  Peak Performance: {perf['peak_lines_per_sec']:,.0f} lines/sec")
        print(f"  Target Performance: {perf['target_lines_per_sec']:,.0f} lines/sec")
        print(f"  Speedup Achieved: {perf['speedup_achieved']:.2f}x")
        print(f"  Target Achievement: {perf['target_achievement_percent']:.1f}%")
        print(f"  Target Met: {'✓ YES' if metrics['system_status']['target_met'] else '✗ NO'}")
        
        # Hardware utilization
        hw = metrics["hardware_utilization"]
        print(f"\nHardware Acceleration:")
        print(f"  AVX-512 Accelerated Tasks: {hw['avx512_tasks']}")
        print(f"  NPU Accelerated Tasks: {hw['npu_tasks']}")
        print(f"  io_uring Operations: {hw['io_uring_operations']}")
        print(f"  C Library Available: {'✓' if hw['c_library_available'] else '✗'}")
        print(f"  Phase 3 Components: {'✓' if hw['phase3_components_available'] else '✗'}")
        
        # System status
        status = metrics["system_status"]
        print(f"\nSystem Status:")
        print(f"  Shadowgit C Integration: {'✓ Active' if status['shadowgit_c_active'] else '✗ Inactive'}")
        print(f"  Phase 3 Pipeline: {'✓ Active' if status['phase3_pipeline_active'] else '✗ Inactive'}")
        print(f"  Performance Monitoring: {'✓ Active' if status['monitoring_active'] else '✗ Inactive'}")
        
        # Print C library report if available
        if self.c_lib.available:
            print(f"\nDetailed C Library Metrics:")
            self.c_lib.print_performance_report()
        
        print("=" * 80)

# Testing and validation functions
async def create_test_repository_files(base_path: Path, num_files: int = 6) -> List[Tuple[str, str]]:
    """Create test git repository files for performance testing"""
    test_pairs = []
    
    base_path.mkdir(exist_ok=True)
    
    # Different file types for comprehensive testing
    file_configs = [
        ("small", 100, "Small file with 100 lines"),
        ("medium", 1000, "Medium file with 1000 lines"),
        ("large", 10000, "Large file with 10000 lines"),
        ("huge", 50000, "Huge file with 50000 lines"),
        ("code", 2500, "Code file with functions and classes"),
        ("data", 5000, "Data file with structured content")
    ]
    
    for i, (file_type, line_count, description) in enumerate(file_configs[:num_files]):
        file1_path = base_path / f"{file_type}_v1.txt"
        file2_path = base_path / f"{file_type}_v2.txt"
        
        # Create file 1
        with open(file1_path, 'w') as f:
            for line_num in range(line_count):
                if file_type == "code":
                    if line_num % 50 == 0:
                        f.write(f"def function_{line_num // 50}():\n")
                    elif line_num % 10 == 0:
                        f.write(f"    # Comment for line {line_num}\n")
                    else:
                        f.write(f"    return 'value_{line_num}' + str({line_num})\n")
                elif file_type == "data":
                    f.write(f"data_record_{line_num:06d}: value={line_num * 1.5:.2f}, hash={hash(line_num)}\n")
                else:
                    f.write(f"Line {line_num:06d} in {description} - content data here\n")
        
        # Create file 2 (with modifications)
        with open(file2_path, 'w') as f:
            for line_num in range(line_count):
                # Introduce changes in ~20% of lines
                if line_num % 5 == 0:
                    if file_type == "code":
                        if line_num % 50 == 0:
                            f.write(f"def function_{line_num // 50}_modified():\n")
                        elif line_num % 10 == 0:
                            f.write(f"    # MODIFIED Comment for line {line_num}\n")
                        else:
                            f.write(f"    return 'MODIFIED_value_{line_num}' + str({line_num * 2})\n")
                    elif file_type == "data":
                        f.write(f"MODIFIED_data_record_{line_num:06d}: value={line_num * 2.0:.2f}, hash={hash(line_num * 2)}\n")
                    else:
                        f.write(f"MODIFIED Line {line_num:06d} in {description} - updated content here\n")
                else:
                    # Keep original content
                    if file_type == "code":
                        if line_num % 50 == 0:
                            f.write(f"def function_{line_num // 50}():\n")
                        elif line_num % 10 == 0:
                            f.write(f"    # Comment for line {line_num}\n")
                        else:
                            f.write(f"    return 'value_{line_num}' + str({line_num})\n")
                    elif file_type == "data":
                        f.write(f"data_record_{line_num:06d}: value={line_num * 1.5:.2f}, hash={hash(line_num)}\n")
                    else:
                        f.write(f"Line {line_num:06d} in {description} - content data here\n")
        
        test_pairs.append((str(file1_path), str(file2_path)))
    
    return test_pairs

async def run_shadowgit_acceleration_test():
    """Run comprehensive Shadowgit acceleration test"""
    print("=" * 80)
    print("TEAM DELTA - SHADOWGIT PHASE 3 ACCELERATION TEST")
    print("Target: 3.8x improvement (930M → 3.5B lines/sec)")
    print("=" * 80)
    
    # Initialize accelerator
    accelerator = ShadowgitAccelerator()
    await accelerator.start()
    
    # Create test files
    test_base_path = Path("/tmp/shadowgit_test")
    test_file_pairs = await create_test_repository_files(test_base_path, num_files=6)
    
    print(f"Created {len(test_file_pairs)} test file pairs")
    
    # Create diverse test tasks
    test_tasks = []
    
    # High-priority tasks (should get NPU acceleration)
    for i, (file1, file2) in enumerate(test_file_pairs[:3]):
        task = ShadowgitTask(
            task_id=f"priority_diff_{i:03d}",
            file1_path=file1,
            file2_path=file2,
            priority=8,  # High priority for NPU
            use_phase3_acceleration=True,
            use_npu_boost=True
        )
        test_tasks.append(task)
    
    # Normal priority tasks
    for i, (file1, file2) in enumerate(test_file_pairs):
        for repeat in range(3):  # 3x each file pair
            task = ShadowgitTask(
                task_id=f"normal_diff_{i:03d}_{repeat}",
                file1_path=file1,
                file2_path=file2,
                priority=1 + (repeat * 2),  # Priorities 1, 3, 5
                use_phase3_acceleration=True,
                use_npu_boost=False
            )
            test_tasks.append(task)
    
    print(f"Generated {len(test_tasks)} diff tasks")
    
    # Submit all tasks
    start_time = time.time()
    submitted_task_ids = []
    
    for task in test_tasks:
        try:
            task_id = await accelerator.submit_diff_task(task)
            submitted_task_ids.append(task_id)
        except Exception as e:
            print(f"Failed to submit task {task.task_id}: {e}")
    
    print(f"Submitted {len(submitted_task_ids)} tasks for processing")
    
    # Monitor progress
    max_wait_time = 120.0  # 2 minutes max
    wait_start = time.time()
    
    while time.time() - wait_start < max_wait_time:
        metrics = accelerator.get_comprehensive_metrics()
        completed = metrics["shadowgit_summary"]["completed_tasks"]
        
        if completed >= len(submitted_task_ids):
            break
        
        print(f"Progress: {completed}/{len(submitted_task_ids)} tasks completed "
              f"({metrics['performance_metrics']['current_lines_per_sec']:,.0f} lines/sec)")
        
        await asyncio.sleep(3.0)
    
    total_time = time.time() - start_time
    
    # Get final results
    final_metrics = accelerator.get_comprehensive_metrics()
    
    # Display comprehensive results
    print(f"\n" + "=" * 80)
    print("SHADOWGIT ACCELERATION TEST RESULTS")
    print("=" * 80)
    
    accelerator.print_performance_report()
    
    print(f"\nTest Execution Summary:")
    print(f"Total Test Time: {total_time:.2f}s")
    print(f"Tasks Submitted: {len(submitted_task_ids)}")
    print(f"Tasks Completed: {final_metrics['shadowgit_summary']['completed_tasks']}")
    
    # Achievement analysis
    perf = final_metrics["performance_metrics"]
    baseline_improvement = perf["speedup_achieved"]
    target_achievement = perf["target_achievement_percent"]
    
    print(f"\nPerformance Achievement:")
    print(f"Baseline Improvement: {baseline_improvement:.2f}x (Target: 3.8x)")
    print(f"Target Achievement: {target_achievement:.1f}% (Target: 100%)")
    
    if baseline_improvement >= 3.8:
        print("✓ SUCCESS: 3.8x improvement target ACHIEVED!")
    elif baseline_improvement >= 2.0:
        print("⚠ PARTIAL: Significant improvement achieved, approaching target")
    else:
        print("✗ NEEDS WORK: Further optimization required")
    
    await accelerator.stop()
    
    # Cleanup test files
    for file1, file2 in test_file_pairs:
        try:
            os.unlink(file1)
            os.unlink(file2)
        except:
            pass
    
    try:
        test_base_path.rmdir()
    except:
        pass
    
    return {
        "total_time": total_time,
        "tasks_submitted": len(submitted_task_ids),
        "final_metrics": final_metrics,
        "success": baseline_improvement >= 3.8
    }

# Main execution
async def main():
    """Main execution function"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    try:
        results = await run_shadowgit_acceleration_test()
        
        # Save results
        output_file = "/home/john/claude-backups/shadowgit-acceleration-results.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\nResults saved to: {output_file}")
        return results
        
    except Exception as e:
        logging.error(f"Main execution error: {e}")
        raise

if __name__ == "__main__":
    results = asyncio.run(main())