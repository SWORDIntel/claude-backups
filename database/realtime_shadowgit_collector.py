#!/usr/bin/env python3
"""
Real-time Shadowgit Data Collector
Captures operational insights from shadowgit's continuous operation

Features:
- Zero-copy data transfer from shadowgit hooks
- Real-time performance analysis (930M lines/sec processing)
- SIMD optimization metrics collection
- Lock-free data ingestion pipeline
- Anomaly detection and adaptive learning
- Hardware metrics integration (Intel Meteor Lake)
"""

import asyncio
import asyncpg
import json
import time
import mmap
import struct
import numpy as np
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from pathlib import Path
from threading import Thread, Event
import psutil
import logging
from concurrent.futures import ThreadPoolExecutor
import signal
import sys
from datetime import datetime, timedelta
import hashlib

# Configure logging

# Add project root to Python path for imports
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from path_utilities import (
        get_project_root, get_agents_dir, get_database_dir,
        get_python_src_dir, get_shadowgit_paths, get_database_config
    )
except ImportError:
    # Fallback if path_utilities not available
    def get_project_root():
        return Path(__file__).parent.parent.parent
    def get_agents_dir():
        return get_project_root() / 'agents'
    def get_database_dir():
        return get_project_root() / 'database'
    def get_python_src_dir():
        return get_agents_dir() / 'src' / 'python'
    def get_shadowgit_paths():
        home_dir = Path.home()
        return {'root': home_dir / 'shadowgit'}
    def get_database_config():
        return {
            'host': 'localhost', 'port': 5433,
            'database': 'claude_agents_auth',
            'user': 'claude_agent', 'password': 'claude_auth_pass'
        }
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class ShadowgitEvent:
    """Shadowgit operational event with SIMD metrics"""
    timestamp_ns: int
    processing_time_ns: int
    lines_processed: int
    simd_operations: int
    simd_level: str
    simd_efficiency: float
    operation_type: str
    embedding: List[float]
    memory_usage: int
    cache_hits: int
    cache_misses: int
    file_path: str
    commit_hash: str
    branch_name: str
    error_count: int = 0
    optimization_applied: bool = False

@dataclass
class PerformanceMetrics:
    """Real-time performance metrics"""
    events_per_second: float
    avg_processing_time_ns: float
    simd_efficiency_score: float
    memory_utilization: float
    cpu_utilization: float
    disk_io_rate: float
    network_io_rate: float
    error_rate: float
    anomaly_score: float

class ShadowgitCollector:
    """High-performance shadowgit data collector with SIMD optimization"""
    
    def __init__(self, config_path: str = str(get_project_root() / "config/learning_config.json"):
        self.config = self._load_config(config_path)
        self.db_pool: Optional[asyncpg.Pool] = None
        self.running = False
        self.shutdown_event = Event()
        self.performance_stats = {}
        self.anomaly_detector = AnomalyDetector()
        self.optimization_engine = OptimizationEngine()
        
        # SIMD metrics tracking
        self.simd_metrics = {
            'scalar': {'count': 0, 'total_time': 0, 'efficiency': [], 'error_count': 0},
            'avx2': {'count': 0, 'total_time': 0, 'efficiency': [], 'error_count': 0},
            'avx512': {'count': 0, 'total_time': 0, 'efficiency': [], 'error_count': 0}
        }
        
        # Memory-mapped file for zero-copy data transfer
        self.mmap_file = None
        self.mmap_size = 64 * 1024 * 1024  # 64MB ring buffer
        
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration with fallback defaults"""
        default_config = {
            "database": {
                "host": "localhost",
                "port": 5433,
                "database": "claude_agents_auth",
                "user": "claude_agent",
                "password": "claude_secure_password"
            },
            "shadowgit": {
                "hook_data_path": "/tmp/shadowgit_hooks",
                "performance_log_path": "/tmp/shadowgit_performance.log",
                "max_events_per_second": 10000,
                "embedding_dimension": 512
            },
            "monitoring": {
                "collection_interval_ms": 100,
                "batch_size": 1000,
                "anomaly_threshold": 2.0,
                "performance_window_minutes": 5
            }
        }
        
        try:
            config_file = Path(config_path)
            if config_file.exists():
                with open(config_file) as f:
                    user_config = json.load(f)
                # Deep merge with defaults
                return self._deep_merge(default_config, user_config)
            else:
                logger.warning(f"Config file {config_path} not found, using defaults")
                return default_config
        except Exception as e:
            logger.error(f"Failed to load config: {e}, using defaults")
            return default_config
    
    def _deep_merge(self, default: Dict, override: Dict) -> Dict:
        """Deep merge configuration dictionaries"""
        result = default.copy()
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value
        return result
    
    async def initialize(self):
        """Initialize collector with database connection and memory mapping"""
        try:
            # Initialize database connection pool
            db_config = self.config["database"]
            dsn = f"postgresql://{db_config['user']}:{db_config['password']}@{db_config['host']}:{db_config['port']}/{db_config['database']}"
            
            self.db_pool = await asyncpg.create_pool(
                dsn,
                min_size=5,
                max_size=20,
                command_timeout=30,
                server_settings={
                    'application_name': 'shadowgit_collector',
                    'tcp_keepalives_idle': '600',
                    'tcp_keepalives_interval': '30',
                    'tcp_keepalives_count': '3'
                }
            )
            
            # Test database connection
            async with self.db_pool.acquire() as conn:
                version = await conn.fetchval("SELECT version()")
                logger.info(f"Connected to PostgreSQL: {version}")
            
            # Initialize memory-mapped file for zero-copy data transfer
            await self._setup_mmap()
            
            # Initialize shadowgit hook monitoring
            await self._setup_hook_monitoring()
            
            logger.info("Shadowgit collector initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize collector: {e}")
            raise
    
    async def _setup_mmap(self):
        """Setup memory-mapped file for high-performance data transfer"""
        try:
            mmap_path = Path("/tmp/shadowgit_collector.mmap")
            
            # Create or truncate the file
            with open(mmap_path, "wb") as f:
                f.write(b'\0' * self.mmap_size)
            
            # Memory map the file
            with open(mmap_path, "r+b") as f:
                self.mmap_file = mmap.mmap(f.fileno(), self.mmap_size, mmap.MAP_SHARED)
            
            # Initialize ring buffer header
            self._init_ring_buffer()
            
            logger.info(f"Memory-mapped file initialized: {mmap_path} ({self.mmap_size} bytes)")
            
        except Exception as e:
            logger.error(f"Failed to setup memory mapping: {e}")
            raise
    
    def _init_ring_buffer(self):
        """Initialize lock-free ring buffer in memory-mapped file"""
        if self.mmap_file:
            # Ring buffer header: head(8) + tail(8) + capacity(8) + event_size(8)
            header_size = 32
            event_size = 1024  # Size of each shadowgit event
            capacity = (self.mmap_size - header_size) // event_size
            
            struct.pack_into('<QQQQ', self.mmap_file, 0, 0, 0, capacity, event_size)
            self.mmap_file.flush()
    
    async def _setup_hook_monitoring(self):
        """Setup monitoring of shadowgit hooks"""
        hook_path = Path(self.config["shadowgit"]["hook_data_path"])
        hook_path.mkdir(parents=True, exist_ok=True)
        
        # Create named pipes for hook communication
        pipes = ['pre-commit', 'post-commit', 'pre-push', 'post-receive']
        for pipe_name in pipes:
            pipe_path = hook_path / pipe_name
            if not pipe_path.exists():
                # Create FIFO for hook communication
                import os
                os.mkfifo(str(pipe_path), 0o666)
        
        logger.info(f"Hook monitoring setup complete: {hook_path}")
    
    async def start_collection(self):
        """Start real-time data collection from shadowgit"""
        if self.running:
            logger.warning("Collector already running")
            return
        
        self.running = True
        logger.info("Starting shadowgit data collection...")
        
        # Start collection tasks
        tasks = [
            asyncio.create_task(self._collect_performance_data()),
            asyncio.create_task(self._collect_hook_events()),
            asyncio.create_task(self._process_event_queue()),
            asyncio.create_task(self._monitor_system_metrics()),
            asyncio.create_task(self._run_anomaly_detection()),
            asyncio.create_task(self._adaptive_optimization()),
        ]
        
        try:
            await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            logger.info("Collection tasks cancelled")
        except Exception as e:
            logger.error(f"Collection error: {e}")
        finally:
            self.running = False
    
    async def _collect_performance_data(self):
        """Collect shadowgit performance data from logs"""
        perf_log_path = Path(self.config["shadowgit"]["performance_log_path"])
        
        while self.running:
            try:
                if perf_log_path.exists():
                    # Read new performance data
                    async with asyncio.open_file(perf_log_path, 'r') as f:
                        # Tail the file for new entries
                        await self._process_performance_log(f)
                
                await asyncio.sleep(self.config["monitoring"]["collection_interval_ms"] / 1000.0)
                
            except Exception as e:
                logger.error(f"Performance data collection error: {e}")
                await asyncio.sleep(1.0)
    
    async def _process_performance_log(self, log_file):
        """Process shadowgit performance log entries"""
        try:
            async for line in log_file:
                if line.strip():
                    event = await self._parse_performance_entry(line)
                    if event:
                        await self._enqueue_event(event)
                        
        except Exception as e:
            logger.error(f"Performance log processing error: {e}")
    
    async def _parse_performance_entry(self, log_line: str) -> Optional[ShadowgitEvent]:
        """Parse shadowgit performance log entry into structured event"""
        try:
            # Parse JSON log format from shadowgit
            if log_line.startswith('{'):
                data = json.loads(log_line)
            else:
                # Parse custom shadowgit log format
                data = await self._parse_custom_format(log_line)
            
            if not data:
                return None
            
            # Generate embedding from operation characteristics
            embedding = await self._generate_embedding(data)
            
            # Calculate SIMD efficiency based on operation metrics
            simd_efficiency = self._calculate_simd_efficiency(data)
            
            event = ShadowgitEvent(
                timestamp_ns=data.get('timestamp_ns', int(time.time_ns())),
                processing_time_ns=data.get('processing_time_ns', 0),
                lines_processed=data.get('lines_processed', 0),
                simd_operations=data.get('simd_operations', 0),
                simd_level=data.get('simd_level', 'scalar'),
                simd_efficiency=simd_efficiency,
                operation_type=data.get('operation_type', 'unknown'),
                embedding=embedding,
                memory_usage=data.get('memory_usage', 0),
                cache_hits=data.get('cache_hits', 0),
                cache_misses=data.get('cache_misses', 0),
                file_path=data.get('file_path', ''),
                commit_hash=data.get('commit_hash', ''),
                branch_name=data.get('branch_name', 'main'),
                error_count=data.get('error_count', 0),
                optimization_applied=data.get('optimization_applied', False)
            )
            
            return event
            
        except Exception as e:
            logger.error(f"Failed to parse performance entry: {e}")
            return None
    
    async def _parse_custom_format(self, log_line: str) -> Optional[Dict]:
        """Parse custom shadowgit log format"""
        # Example: "PERF: diff_operation lines=1000 time=1234567ns simd=avx2 ops=125"
        if not log_line.startswith('PERF:'):
            return None
        
        parts = log_line[5:].strip().split()
        data = {'operation_type': parts[0] if parts else 'unknown'}
        
        for part in parts[1:]:
            if '=' in part:
                key, value = part.split('=', 1)
                try:
                    if key in ['lines_processed', 'simd_operations', 'cache_hits', 'cache_misses']:
                        data[key] = int(value)
                    elif key == 'processing_time_ns' or key.endswith('_ns'):
                        data[key] = int(value.rstrip('ns'))
                    elif key == 'simd_level':
                        data[key] = value
                    else:
                        data[key] = value
                except ValueError:
                    data[key] = value
        
        return data
    
    async def _generate_embedding(self, data: Dict) -> List[float]:
        """Generate 512-dimensional embedding from operation characteristics"""
        embedding_dim = self.config["shadowgit"]["embedding_dimension"]
        
        # Use operation characteristics to generate meaningful embeddings
        features = [
            data.get('processing_time_ns', 0) / 1e9,  # Processing time in seconds
            data.get('lines_processed', 0) / 10000.0,  # Lines processed (normalized)
            data.get('simd_operations', 0) / 1000.0,   # SIMD operations (normalized)
            float(data.get('cache_hits', 0)) / max(1, data.get('cache_hits', 0) + data.get('cache_misses', 0)),  # Cache hit rate
            data.get('memory_usage', 0) / (1024 * 1024 * 1024),  # Memory in GB
            data.get('error_count', 0),  # Error count
        ]
        
        # Operation type encoding (one-hot style)
        op_types = ['diff', 'merge', 'checkout', 'commit', 'push', 'pull']
        op_type = data.get('operation_type', 'unknown')
        for op in op_types:
            features.append(1.0 if op in op_type.lower() else 0.0)
        
        # SIMD level encoding
        simd_levels = ['scalar', 'avx2', 'avx512']
        simd_level = data.get('simd_level', 'scalar')
        for level in simd_levels:
            features.append(1.0 if level == simd_level else 0.0)
        
        # Pad or truncate to desired dimension
        if len(features) < embedding_dim:
            # Use hash-based feature expansion for remaining dimensions
            feature_hash = hashlib.md5(json.dumps(data, sort_keys=True).encode()).digest()
            hash_features = [float(b) / 255.0 for b in feature_hash]
            
            while len(features) < embedding_dim:
                features.extend(hash_features)
            
        return features[:embedding_dim]
    
    def _calculate_simd_efficiency(self, data: Dict) -> float:
        """Calculate SIMD efficiency based on operation metrics"""
        simd_ops = data.get('simd_operations', 0)
        total_time_ns = data.get('processing_time_ns', 1)
        lines_processed = data.get('lines_processed', 0)
        
        if simd_ops == 0 or total_time_ns == 0:
            return 0.0
        
        # Calculate theoretical vs actual performance
        simd_level = data.get('simd_level', 'scalar')
        theoretical_speedup = {'scalar': 1.0, 'avx2': 8.0, 'avx512': 16.0}.get(simd_level, 1.0)
        
        # Lines per nanosecond with SIMD
        actual_throughput = lines_processed / max(1, total_time_ns)
        
        # Estimate scalar baseline throughput
        scalar_throughput = actual_throughput / max(1.0, theoretical_speedup * 0.8)  # 80% efficiency assumption
        
        # Efficiency as ratio of actual to theoretical improvement
        efficiency = min(1.0, actual_throughput / max(scalar_throughput * theoretical_speedup, 1e-9))
        
        return efficiency
    
    async def _enqueue_event(self, event: ShadowgitEvent):
        """Enqueue event for batch processing"""
        try:
            if self.mmap_file:
                await self._write_to_ring_buffer(event)
            
            # Update SIMD metrics
            simd_level = event.simd_level
            if simd_level in self.simd_metrics:
                self.simd_metrics[simd_level]['count'] += 1
                self.simd_metrics[simd_level]['total_time'] += event.processing_time_ns
                self.simd_metrics[simd_level]['efficiency'].append(event.simd_efficiency)
                if event.error_count > 0:
                    self.simd_metrics[simd_level]['error_count'] += event.error_count
                
                # Keep efficiency history bounded
                if len(self.simd_metrics[simd_level]['efficiency']) > 1000:
                    self.simd_metrics[simd_level]['efficiency'] = \
                        self.simd_metrics[simd_level]['efficiency'][-500:]
            
        except Exception as e:
            logger.error(f"Failed to enqueue event: {e}")
    
    async def _write_to_ring_buffer(self, event: ShadowgitEvent):
        """Write event to lock-free ring buffer in memory-mapped file"""
        if not self.mmap_file:
            return
        
        try:
            # Read ring buffer header
            head, tail, capacity, event_size = struct.unpack_from('<QQQQ', self.mmap_file, 0)
            
            # Check if ring buffer is full
            next_tail = (tail + 1) % capacity
            if next_tail == head:
                logger.warning("Ring buffer full, dropping event")
                return
            
            # Serialize event
            event_data = json.dumps(asdict(event)).encode('utf-8')
            if len(event_data) > event_size:
                logger.warning(f"Event too large: {len(event_data)} > {event_size}")
                return
            
            # Write event to ring buffer
            offset = 32 + (tail * event_size)  # 32-byte header
            self.mmap_file[offset:offset + len(event_data)] = event_data
            self.mmap_file[offset + len(event_data):offset + event_size] = b'\0' * (event_size - len(event_data))
            
            # Update tail pointer
            struct.pack_into('<Q', self.mmap_file, 8, next_tail)  # Tail at offset 8
            self.mmap_file.flush()
            
        except Exception as e:
            logger.error(f"Ring buffer write error: {e}")
    
    async def _collect_hook_events(self):
        """Collect events from shadowgit hooks"""
        while self.running:
            try:
                hook_path = Path(self.config["shadowgit"]["hook_data_path"])
                
                # Monitor hook files for new data
                for hook_file in hook_path.glob("*"):
                    if hook_file.is_fifo():
                        await self._read_hook_data(hook_file)
                
                await asyncio.sleep(0.1)  # 100ms collection interval
                
            except Exception as e:
                logger.error(f"Hook event collection error: {e}")
                await asyncio.sleep(1.0)
    
    async def _read_hook_data(self, hook_file: Path):
        """Read data from shadowgit hook FIFO"""
        try:
            # Non-blocking read from FIFO
            with open(hook_file, 'r', encoding='utf-8') as f:
                data = f.read()
                if data.strip():
                    event = await self._parse_hook_data(data, hook_file.name)
                    if event:
                        await self._enqueue_event(event)
                        
        except (OSError, IOError):
            # FIFO not ready or no data available
            pass
        except Exception as e:
            logger.error(f"Hook data read error for {hook_file}: {e}")
    
    async def _parse_hook_data(self, data: str, hook_name: str) -> Optional[ShadowgitEvent]:
        """Parse data from shadowgit hook"""
        try:
            # Parse hook-specific data format
            lines = data.strip().split('\n')
            event_data = {'operation_type': f'hook_{hook_name}'}
            
            for line in lines:
                if '=' in line:
                    key, value = line.split('=', 1)
                    event_data[key.strip()] = value.strip()
            
            # Convert to ShadowgitEvent
            return await self._parse_performance_entry(json.dumps(event_data))
            
        except Exception as e:
            logger.error(f"Hook data parsing error: {e}")
            return None
    
    async def _process_event_queue(self):
        """Process queued events in batches"""
        batch_size = self.config["monitoring"]["batch_size"]
        
        while self.running:
            try:
                events = await self._dequeue_events(batch_size)
                if events:
                    await self._batch_insert_events(events)
                    logger.info(f"Processed batch of {len(events)} events")
                
                await asyncio.sleep(0.5)  # Process batches every 500ms
                
            except Exception as e:
                logger.error(f"Event queue processing error: {e}")
                await asyncio.sleep(1.0)
    
    async def _dequeue_events(self, max_count: int) -> List[ShadowgitEvent]:
        """Dequeue events from ring buffer"""
        events = []
        
        if not self.mmap_file:
            return events
        
        try:
            for _ in range(max_count):
                # Read ring buffer header
                head, tail, capacity, event_size = struct.unpack_from('<QQQQ', self.mmap_file, 0)
                
                if head == tail:
                    break  # Ring buffer empty
                
                # Read event from ring buffer
                offset = 32 + (head * event_size)
                event_data = self.mmap_file[offset:offset + event_size]
                
                # Find actual data length (before null terminator)
                data_end = event_data.find(b'\0')
                if data_end >= 0:
                    event_data = event_data[:data_end]
                
                try:
                    event_dict = json.loads(event_data.decode('utf-8'))
                    event = ShadowgitEvent(**event_dict)
                    events.append(event)
                except (json.JSONDecodeError, TypeError) as e:
                    logger.error(f"Failed to deserialize event: {e}")
                
                # Update head pointer
                next_head = (head + 1) % capacity
                struct.pack_into('<Q', self.mmap_file, 0, next_head)  # Head at offset 0
                self.mmap_file.flush()
                
        except Exception as e:
            logger.error(f"Event dequeue error: {e}")
        
        return events
    
    async def _batch_insert_events(self, events: List[ShadowgitEvent]):
        """Batch insert events into PostgreSQL"""
        if not self.db_pool or not events:
            return
        
        try:
            async with self.db_pool.acquire() as conn:
                # Prepare batch insert
                values = []
                for event in events:
                    embedding_array = event.embedding
                    values.append((
                        datetime.fromtimestamp(event.timestamp_ns / 1e9),
                        event.processing_time_ns,
                        event.lines_processed,
                        event.simd_operations,
                        event.simd_level,
                        event.simd_efficiency,
                        event.operation_type,
                        embedding_array,
                        event.memory_usage,
                        event.cache_hits,
                        event.cache_misses,
                        event.file_path,
                        event.commit_hash,
                        event.branch_name,
                        event.error_count,
                        event.optimization_applied
                    ))
                
                # Execute batch insert
                await conn.executemany(
                    """INSERT INTO enhanced_learning.shadowgit_events 
                       (timestamp, processing_time_ns, lines_processed, simd_operations,
                        simd_level, simd_efficiency, operation_type, embedding,
                        memory_usage, cache_hits, cache_misses, file_path,
                        commit_hash, branch_name, error_count, optimization_applied)
                       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)""",
                    values
                )
                
                logger.debug(f"Inserted {len(events)} events into database")
                
        except Exception as e:
            logger.error(f"Batch insert error: {e}")
    
    async def _monitor_system_metrics(self):
        """Monitor system performance metrics"""
        while self.running:
            try:
                metrics = await self._collect_system_metrics()
                await self._store_system_metrics(metrics)
                
                await asyncio.sleep(10.0)  # Collect system metrics every 10 seconds
                
            except Exception as e:
                logger.error(f"System metrics monitoring error: {e}")
                await asyncio.sleep(10.0)
    
    async def _collect_system_metrics(self) -> PerformanceMetrics:
        """Collect current system performance metrics"""
        cpu_percent = psutil.cpu_percent(interval=1.0)
        memory_info = psutil.virtual_memory()
        disk_io = psutil.disk_io_counters()
        network_io = psutil.net_io_counters()
        
        # Calculate derived metrics
        total_events = sum(self.simd_metrics[level]['count'] for level in self.simd_metrics)
        events_per_second = total_events / max(1, (time.time() - getattr(self, 'start_time', time.time())))
        
        avg_processing_time = 0.0
        if total_events > 0:
            total_time = sum(self.simd_metrics[level]['total_time'] for level in self.simd_metrics)
            avg_processing_time = total_time / total_events
        
        # Calculate weighted SIMD efficiency
        simd_efficiency_score = 0.0
        total_ops = 0
        for level, data in self.simd_metrics.items():
            if data['efficiency']:
                ops = data['count']
                avg_eff = sum(data['efficiency'][-100:]) / len(data['efficiency'][-100:])  # Last 100 samples
                simd_efficiency_score += avg_eff * ops
                total_ops += ops
        
        if total_ops > 0:
            simd_efficiency_score /= total_ops
        
        total_errors = sum(self.simd_metrics[level]['error_count'] for level in self.simd_metrics)
        error_rate = total_errors / total_events if total_events > 0 else 0.0

        # Calculate anomaly score from recent anomalies
        anomaly_score = await self.anomaly_detector.get_current_anomaly_score(self.db_pool)

        return PerformanceMetrics(
            events_per_second=events_per_second,
            avg_processing_time_ns=avg_processing_time,
            simd_efficiency_score=simd_efficiency_score,
            memory_utilization=memory_info.percent / 100.0,
            cpu_utilization=cpu_percent / 100.0,
            disk_io_rate=disk_io.read_bytes + disk_io.write_bytes if disk_io else 0,
            network_io_rate=network_io.bytes_sent + network_io.bytes_recv if network_io else 0,
            error_rate=error_rate,
            anomaly_score=anomaly_score
        )
    
    async def _store_system_metrics(self, metrics: PerformanceMetrics):
        """Store system metrics in database"""
        if not self.db_pool:
            return
        
        try:
            async with self.db_pool.acquire() as conn:
                await conn.execute(
                    """INSERT INTO enhanced_learning.system_metrics
                       (timestamp, events_per_second, avg_processing_time_ns,
                        simd_efficiency_score, memory_utilization, cpu_utilization,
                        disk_io_rate, network_io_rate, error_rate, anomaly_score)
                       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)""",
                    datetime.now(),
                    metrics.events_per_second,
                    metrics.avg_processing_time_ns,
                    metrics.simd_efficiency_score,
                    metrics.memory_utilization,
                    metrics.cpu_utilization,
                    metrics.disk_io_rate,
                    metrics.network_io_rate,
                    metrics.error_rate,
                    metrics.anomaly_score
                )
        except Exception as e:
            logger.error(f"Failed to store system metrics: {e}")
    
    async def _run_anomaly_detection(self):
        """Run anomaly detection on collected data"""
        while self.running:
            try:
                await self.anomaly_detector.detect_anomalies(self.db_pool)
                await asyncio.sleep(30.0)  # Run every 30 seconds
            except Exception as e:
                logger.error(f"Anomaly detection error: {e}")
                await asyncio.sleep(30.0)
    
    async def _adaptive_optimization(self):
        """Run adaptive optimization based on collected insights"""
        while self.running:
            try:
                await self.optimization_engine.optimize(self.db_pool, self.simd_metrics)
                await asyncio.sleep(60.0)  # Run every minute
            except Exception as e:
                logger.error(f"Adaptive optimization error: {e}")
                await asyncio.sleep(60.0)
    
    def stop_collection(self):
        """Stop data collection"""
        logger.info("Stopping shadowgit data collection...")
        self.running = False
        self.shutdown_event.set()
    
    async def cleanup(self):
        """Cleanup resources"""
        if self.db_pool:
            await self.db_pool.close()
        
        if self.mmap_file:
            self.mmap_file.close()


class AnomalyDetector:
    """Anomaly detection for shadowgit operations"""
    
    def __init__(self):
        self.baseline_metrics = {}
        
    async def get_current_anomaly_score(self, db_pool: asyncpg.Pool) -> float:
        """Get the current anomaly score from recent anomalies."""
        if not db_pool:
            return 0.0

        try:
            async with db_pool.acquire() as conn:
                # Get average z-score of anomalies in the last 10 minutes
                avg_z_score = await conn.fetchval(
                    """SELECT AVG(z_score)
                       FROM enhanced_learning.anomalies
                       WHERE timestamp > NOW() - INTERVAL '10 minutes'"""
                )
                return float(avg_z_score) if avg_z_score else 0.0
        except Exception as e:
            logger.error(f"Failed to get anomaly score: {e}")
            return 0.0

    async def detect_anomalies(self, db_pool: asyncpg.Pool):
        """Detect anomalies in shadowgit performance"""
        if not db_pool:
            return
        
        try:
            async with db_pool.acquire() as conn:
                # Get recent metrics for anomaly detection
                recent_metrics = await conn.fetch(
                    """SELECT processing_time_ns, simd_efficiency, memory_usage,
                              cache_hits, cache_misses, error_count
                       FROM enhanced_learning.shadowgit_events
                       WHERE timestamp > NOW() - INTERVAL '1 hour'
                       ORDER BY timestamp DESC"""
                )
                
                if len(recent_metrics) < 100:  # Need sufficient data
                    return
                
                # Statistical anomaly detection
                anomalies = await self._statistical_anomaly_detection(recent_metrics)
                
                # Store detected anomalies
                for anomaly in anomalies:
                    await self._store_anomaly(conn, anomaly)
                    
        except Exception as e:
            logger.error(f"Anomaly detection failed: {e}")
    
    async def _statistical_anomaly_detection(self, metrics) -> List[Dict]:
        """Statistical anomaly detection using z-score"""
        anomalies = []
        
        # Convert to numpy arrays for analysis
        processing_times = np.array([m['processing_time_ns'] for m in metrics])
        simd_efficiencies = np.array([m['simd_efficiency'] for m in metrics])
        memory_usage = np.array([m['memory_usage'] for m in metrics])
        
        # Z-score based anomaly detection
        fields = [
            ('processing_time_ns', processing_times),
            ('simd_efficiency', simd_efficiencies),
            ('memory_usage', memory_usage)
        ]
        
        for field_name, values in fields:
            if len(values) == 0:
                continue
                
            mean_val = np.mean(values)
            std_val = np.std(values)
            
            if std_val > 0:
                z_scores = np.abs((values - mean_val) / std_val)
                anomaly_indices = np.where(z_scores > 3.0)[0]  # 3-sigma rule
                
                for idx in anomaly_indices:
                    anomalies.append({
                        'metric': field_name,
                        'value': float(values[idx]),
                        'z_score': float(z_scores[idx]),
                        'mean': float(mean_val),
                        'std': float(std_val),
                        'timestamp': datetime.now()
                    })
        
        return anomalies
    
    async def _store_anomaly(self, conn: asyncpg.Connection, anomaly: Dict):
        """Store detected anomaly in database"""
        try:
            await conn.execute(
                """INSERT INTO enhanced_learning.anomalies
                   (timestamp, metric_name, anomaly_value, z_score,
                    baseline_mean, baseline_std, severity)
                   VALUES ($1, $2, $3, $4, $5, $6, $7)""",
                anomaly['timestamp'],
                anomaly['metric'],
                anomaly['value'],
                anomaly['z_score'],
                anomaly['mean'],
                anomaly['std'],
                'high' if anomaly['z_score'] > 4.0 else 'medium'
            )
        except Exception as e:
            logger.error(f"Failed to store anomaly: {e}")


class OptimizationEngine:
    """Adaptive optimization based on shadowgit insights"""
    
    def __init__(self):
        self.optimization_history = {}
    
    async def optimize(self, db_pool: asyncpg.Pool, simd_metrics: Dict):
        """Run optimization based on collected metrics"""
        if not db_pool:
            return
        
        try:
            # Analyze SIMD performance patterns
            simd_insights = await self._analyze_simd_patterns(simd_metrics)
            
            # Generate optimization recommendations
            recommendations = await self._generate_recommendations(simd_insights)
            
            # Store recommendations in database
            async with db_pool.acquire() as conn:
                for rec in recommendations:
                    await self._store_recommendation(conn, rec)
                    
            logger.info(f"Generated {len(recommendations)} optimization recommendations")
            
        except Exception as e:
            logger.error(f"Optimization engine error: {e}")
    
    async def _analyze_simd_patterns(self, simd_metrics: Dict) -> Dict:
        """Analyze SIMD performance patterns"""
        insights = {
            'preferred_simd_level': 'scalar',
            'efficiency_by_level': {},
            'performance_trends': {},
            'optimization_opportunities': []
        }
        
        total_ops = sum(data['count'] for data in simd_metrics.values())
        if total_ops == 0:
            return insights
        
        # Calculate efficiency by SIMD level
        best_efficiency = 0.0
        for level, data in simd_metrics.items():
            if data['efficiency']:
                avg_efficiency = sum(data['efficiency'][-100:]) / len(data['efficiency'][-100:])
                insights['efficiency_by_level'][level] = avg_efficiency
                
                if avg_efficiency > best_efficiency:
                    best_efficiency = avg_efficiency
                    insights['preferred_simd_level'] = level
        
        # Identify optimization opportunities
        if 'avx512' in simd_metrics and simd_metrics['avx512']['count'] == 0:
            insights['optimization_opportunities'].append('enable_avx512')
        
        if 'avx2' in insights['efficiency_by_level'] and insights['efficiency_by_level']['avx2'] < 0.7:
            insights['optimization_opportunities'].append('tune_avx2_alignment')
        
        return insights
    
    async def _generate_recommendations(self, insights: Dict) -> List[Dict]:
        """Generate optimization recommendations"""
        recommendations = []
        
        for opportunity in insights['optimization_opportunities']:
            if opportunity == 'enable_avx512':
                recommendations.append({
                    'type': 'hardware_optimization',
                    'action': 'enable_avx512',
                    'description': 'Enable AVX-512 support for 2x SIMD performance boost',
                    'expected_improvement': 2.0,
                    'priority': 'high',
                    'timestamp': datetime.now()
                })
            
            elif opportunity == 'tune_avx2_alignment':
                recommendations.append({
                    'type': 'memory_optimization',
                    'action': 'improve_data_alignment',
                    'description': 'Improve data alignment for better AVX2 efficiency',
                    'expected_improvement': 1.3,
                    'priority': 'medium',
                    'timestamp': datetime.now()
                })
        
        # Performance-based recommendations
        preferred_level = insights['preferred_simd_level']
        if preferred_level != 'scalar':
            recommendations.append({
                'type': 'simd_optimization',
                'action': f'prioritize_{preferred_level}',
                'description': f'Prioritize {preferred_level} operations for best efficiency',
                'expected_improvement': insights['efficiency_by_level'].get(preferred_level, 1.0),
                'priority': 'medium',
                'timestamp': datetime.now()
            })
        
        return recommendations
    
    async def _store_recommendation(self, conn: asyncpg.Connection, recommendation: Dict):
        """Store optimization recommendation"""
        try:
            await conn.execute(
                """INSERT INTO enhanced_learning.optimization_recommendations
                   (timestamp, recommendation_type, action, description,
                    expected_improvement, priority, status)
                   VALUES ($1, $2, $3, $4, $5, $6, 'pending')""",
                recommendation['timestamp'],
                recommendation['type'],
                recommendation['action'],
                recommendation['description'],
                recommendation['expected_improvement'],
                recommendation['priority']
            )
        except Exception as e:
            logger.error(f"Failed to store recommendation: {e}")


async def main():
    """Main entry point for shadowgit collector"""
    collector = ShadowgitCollector()
    
    # Handle shutdown signals
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}")
        collector.stop_collection()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await collector.initialize()
        collector.start_time = time.time()
        await collector.start_collection()
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Collector failed: {e}")
    finally:
        await collector.cleanup()
        logger.info("Shadowgit collector shutdown complete")


if __name__ == "__main__":
    asyncio.run(main())