#!/usr/bin/env python3
"""
Shadowgit Performance Integration v1.0
Integrates Shadowgit performance monitoring with NPU acceleration and learning database
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import psycopg2
from psycopg2.extras import RealDictCursor

# Import existing components

# Add project root to Python path for imports
# We're now in hooks/shadowgit/python/, so project root is 3 levels up
project_root = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "agents" / "src" / "python"))

try:
    from agent_path_resolver import (
        get_agents_root,
        get_project_root,
        get_shadowgit_root,
    )
except ImportError:
    # Fallback if agent_path_resolver not available
    def get_project_root():
        return Path(__file__).parent.parent.parent.parent

    def get_agents_root():
        return get_project_root() / "agents"

    def get_shadowgit_root():
        return get_project_root() / "hooks" / "shadowgit"


def get_database_dir():
    return get_project_root() / "database"


def get_python_src_dir():
    return get_agents_root() / "src" / "python"


def get_database_config():
    return {
        "host": "localhost",
        "port": 5433,
        "database": "claude_agents_auth",
        "user": "claude_agent",
        "password": "claude_auth_pass",
    }


# Import analyzer from current directory
try:
    from analyze_performance import PerformanceAnalysis

    PERFORMANCE_ANALYZER_AVAILABLE = True
except ImportError:
    PERFORMANCE_ANALYZER_AVAILABLE = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class GitOperation:
    """Git operation performance data"""

    operation_id: str
    operation_type: str  # diff, hash, index, merge, etc.
    file_count: int
    lines_processed: int
    execution_time_ms: float
    throughput_lines_per_sec: float
    hardware_used: str  # NPU, AVX2, CPU
    repository_path: str
    timestamp: float


@dataclass
class PerformanceMetrics:
    """Shadowgit performance metrics"""

    current_baseline: float
    target_performance: float
    achievement_percentage: float
    npu_utilization: float
    avx2_utilization: float
    cpu_utilization: float
    bottlenecks: List[str]
    optimization_recommendations: List[str]


class ShadowgitPerformanceMonitor:
    """Real-time Shadowgit performance monitoring and optimization"""

    def __init__(self):
        self.db_connection = None
        self.performance_history = []
        self.current_metrics = None
        self.baseline_performance = 3040000  # 3.04M lines/sec
        self.target_performance = 11500000  # 11.5M lines/sec (3.8x improvement)

        # NPU integration
        self.npu_available = False
        self.openvino_available = False

        # Performance tracking
        self.operation_queue = asyncio.Queue()
        self.is_monitoring = False

    async def initialize(self):
        """Initialize performance monitoring system"""
        logger.info("🚀 Initializing Shadowgit Performance Monitor")

        # Initialize database connection
        await self.initialize_database()

        # Check NPU availability
        await self.check_npu_availability()

        # Create performance tables
        await self.create_performance_tables()

        # Start monitoring
        await self.start_monitoring()

        logger.info("✅ Shadowgit Performance Monitor initialized")

    async def initialize_database(self):
        """Initialize PostgreSQL connection"""
        try:
            self.db_connection = psycopg2.connect(
                host="localhost",
                port=5433,
                database="claude_agents_auth",
                user="claude_agent",
                password="",
                cursor_factory=RealDictCursor,
            )
            logger.info("✅ Database connection established")
        except Exception as e:
            logger.warning(f"Database connection failed: {e}")
            self.db_connection = None

    async def check_npu_availability(self):
        """Check if NPU acceleration is available"""
        try:
            # Check if we're in the NPU virtual environment
            venv_python = Path(
                '${CLAUDE_AGENTS_ROOT:-$(dirname "$0")}/../src/python/.venv/bin/python'
            )
            if venv_python.exists():
                result = subprocess.run(
                    [
                        str(venv_python),
                        "-c",
                        'import openvino as ov; core = ov.Core(); print("NPU" in core.available_devices)',
                    ],
                    capture_output=True,
                    text=True,
                )

                if result.returncode == 0 and "True" in result.stdout:
                    self.npu_available = True
                    self.openvino_available = True
                    logger.info("✅ NPU acceleration available")
                else:
                    logger.info("⚠️ NPU not available, using CPU optimization")
            else:
                logger.info("⚠️ NPU virtual environment not found")

        except Exception as e:
            logger.warning(f"NPU availability check failed: {e}")

    async def create_performance_tables(self):
        """Create database tables for performance tracking"""
        if not self.db_connection:
            return

        try:
            cursor = self.db_connection.cursor()

            # Git operations table
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS shadowgit_operations (
                    operation_id VARCHAR(64) PRIMARY KEY,
                    operation_type VARCHAR(32) NOT NULL,
                    file_count INTEGER NOT NULL,
                    lines_processed BIGINT NOT NULL,
                    execution_time_ms FLOAT NOT NULL,
                    throughput_lines_per_sec FLOAT NOT NULL,
                    hardware_used VARCHAR(16) NOT NULL,
                    repository_path TEXT NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """
            )

            # Performance metrics table
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS shadowgit_metrics (
                    id SERIAL PRIMARY KEY,
                    baseline_performance FLOAT NOT NULL,
                    current_performance FLOAT NOT NULL,
                    target_performance FLOAT NOT NULL,
                    achievement_percentage FLOAT NOT NULL,
                    npu_utilization FLOAT DEFAULT 0,
                    avx2_utilization FLOAT DEFAULT 0,
                    cpu_utilization FLOAT DEFAULT 0,
                    bottlenecks TEXT[],
                    recommendations TEXT[],
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """
            )

            # Performance optimization log
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS shadowgit_optimizations (
                    id SERIAL PRIMARY KEY,
                    optimization_type VARCHAR(64) NOT NULL,
                    description TEXT NOT NULL,
                    performance_before FLOAT NOT NULL,
                    performance_after FLOAT NOT NULL,
                    improvement_percentage FLOAT NOT NULL,
                    hardware_config VARCHAR(32) NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """
            )

            self.db_connection.commit()
            logger.info("✅ Performance tables created/verified")

        except Exception as e:
            logger.error(f"Failed to create performance tables: {e}")
            if self.db_connection:
                self.db_connection.rollback()

    async def start_monitoring(self):
        """Start real-time performance monitoring"""
        if self.is_monitoring:
            return

        self.is_monitoring = True

        # Start background monitoring task
        asyncio.create_task(self.monitor_git_operations())

        logger.info("✅ Real-time monitoring started")

    async def monitor_git_operations(self):
        """Monitor Git operations in the background"""
        while self.is_monitoring:
            try:
                # Check for new Git operations to monitor
                # In a real implementation, this would hook into Git operations
                await asyncio.sleep(1)

                # Process any queued operations
                while not self.operation_queue.empty():
                    try:
                        operation = await self.operation_queue.get()
                        await self.process_git_operation(operation)
                    except Exception as e:
                        logger.error(f"Error processing Git operation: {e}")

            except Exception as e:
                logger.error(f"Monitoring error: {e}")
                await asyncio.sleep(5)

    async def record_git_operation(
        self,
        operation_type: str,
        file_count: int,
        lines_processed: int,
        execution_time_ms: float,
        repository_path: str,
        hardware_used: str = "CPU",
    ):
        """Record a Git operation for performance analysis"""

        throughput = (
            lines_processed / (execution_time_ms / 1000) if execution_time_ms > 0 else 0
        )

        operation = GitOperation(
            operation_id=f"git_{operation_type}_{int(time.time() * 1000)}",
            operation_type=operation_type,
            file_count=file_count,
            lines_processed=lines_processed,
            execution_time_ms=execution_time_ms,
            throughput_lines_per_sec=throughput,
            hardware_used=hardware_used,
            repository_path=repository_path,
            timestamp=time.time(),
        )

        # Queue for background processing
        await self.operation_queue.put(operation)

        return operation

    async def process_git_operation(self, operation: GitOperation):
        """Process and store Git operation data"""
        self.performance_history.append(operation)

        # Store in database
        if self.db_connection:
            try:
                cursor = self.db_connection.cursor()
                cursor.execute(
                    """
                    INSERT INTO shadowgit_operations
                    (operation_id, operation_type, file_count, lines_processed,
                     execution_time_ms, throughput_lines_per_sec, hardware_used, repository_path)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                    (
                        operation.operation_id,
                        operation.operation_type,
                        operation.file_count,
                        operation.lines_processed,
                        operation.execution_time_ms,
                        operation.throughput_lines_per_sec,
                        operation.hardware_used,
                        operation.repository_path,
                    ),
                )
                self.db_connection.commit()
            except Exception as e:
                logger.error(f"Failed to store operation data: {e}")

        # Update performance metrics
        await self.update_performance_metrics()

    async def update_performance_metrics(self):
        """Update current performance metrics"""
        if not self.performance_history:
            return

        # Calculate current performance
        recent_operations = self.performance_history[-10:]  # Last 10 operations
        current_performance = np.mean(
            [op.throughput_lines_per_sec for op in recent_operations]
        )

        # Calculate achievement percentage
        achievement_percentage = (current_performance / self.target_performance) * 100

        # Calculate hardware utilization
        npu_ops = [op for op in recent_operations if op.hardware_used == "NPU"]
        avx2_ops = [op for op in recent_operations if op.hardware_used == "AVX2"]
        cpu_ops = [op for op in recent_operations if op.hardware_used == "CPU"]

        total_ops = len(recent_operations)
        npu_utilization = len(npu_ops) / total_ops * 100 if total_ops > 0 else 0
        avx2_utilization = len(avx2_ops) / total_ops * 100 if total_ops > 0 else 0
        cpu_utilization = len(cpu_ops) / total_ops * 100 if total_ops > 0 else 0

        # Identify bottlenecks
        bottlenecks = self.identify_bottlenecks(recent_operations)

        # Generate optimization recommendations
        recommendations = self.generate_optimization_recommendations(
            current_performance, npu_utilization, avx2_utilization, bottlenecks
        )

        self.current_metrics = PerformanceMetrics(
            current_baseline=self.baseline_performance,
            target_performance=self.target_performance,
            achievement_percentage=achievement_percentage,
            npu_utilization=npu_utilization,
            avx2_utilization=avx2_utilization,
            cpu_utilization=cpu_utilization,
            bottlenecks=bottlenecks,
            optimization_recommendations=recommendations,
        )

        # Store metrics in database
        await self.store_performance_metrics()

    def identify_bottlenecks(self, operations: List[GitOperation]) -> List[str]:
        """Identify performance bottlenecks"""
        bottlenecks = []

        if not operations:
            return bottlenecks

        avg_throughput = np.mean([op.throughput_lines_per_sec for op in operations])

        # Check for low NPU utilization
        npu_ops = [op for op in operations if op.hardware_used == "NPU"]
        if len(npu_ops) / len(operations) < 0.3:
            bottlenecks.append("Low NPU utilization")

        # Check for performance below baseline
        if avg_throughput < self.baseline_performance * 0.8:
            bottlenecks.append("Performance below baseline")

        # Check for excessive CPU usage
        cpu_ops = [op for op in operations if op.hardware_used == "CPU"]
        if len(cpu_ops) / len(operations) > 0.7:
            bottlenecks.append("Excessive CPU usage")

        # Check for large file processing inefficiency
        large_file_ops = [op for op in operations if op.lines_processed > 100000]
        if large_file_ops:
            avg_large_throughput = np.mean(
                [op.throughput_lines_per_sec for op in large_file_ops]
            )
            if avg_large_throughput < avg_throughput * 0.5:
                bottlenecks.append("Large file processing inefficiency")

        return bottlenecks

    def generate_optimization_recommendations(
        self,
        current_performance: float,
        npu_utilization: float,
        avx2_utilization: float,
        bottlenecks: List[str],
    ) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []

        # NPU optimization
        if npu_utilization < 30 and self.npu_available:
            recommendations.append("Increase NPU utilization for hash operations")

        # AVX2 optimization
        if avx2_utilization < 50:
            recommendations.append("Optimize AVX2 usage for diff operations")

        # Performance-specific recommendations
        if current_performance < self.baseline_performance:
            recommendations.append("Investigate performance regression")

        # Bottleneck-specific recommendations
        for bottleneck in bottlenecks:
            if "Large file" in bottleneck:
                recommendations.append("Implement streaming processing for large files")
            elif "CPU usage" in bottleneck:
                recommendations.append("Migrate operations to NPU/AVX2 acceleration")
            elif "NPU utilization" in bottleneck:
                recommendations.append(
                    "Enable NPU acceleration for appropriate operations"
                )

        # Target achievement recommendations
        achievement = (current_performance / self.target_performance) * 100
        if achievement < 50:
            recommendations.append("Enable all acceleration modes (NPU + AVX2)")
        elif achievement < 80:
            recommendations.append("Fine-tune algorithm selection")

        return recommendations

    async def store_performance_metrics(self):
        """Store performance metrics in database"""
        if not self.db_connection or not self.current_metrics:
            return

        try:
            cursor = self.db_connection.cursor()

            # Calculate current performance
            recent_ops = self.performance_history[-10:]
            current_performance = (
                np.mean([op.throughput_lines_per_sec for op in recent_ops])
                if recent_ops
                else 0
            )

            cursor.execute(
                """
                INSERT INTO shadowgit_metrics
                (baseline_performance, current_performance, target_performance, achievement_percentage,
                 npu_utilization, avx2_utilization, cpu_utilization, bottlenecks, recommendations)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
                (
                    self.current_metrics.current_baseline,
                    current_performance,
                    self.current_metrics.target_performance,
                    self.current_metrics.achievement_percentage,
                    self.current_metrics.npu_utilization,
                    self.current_metrics.avx2_utilization,
                    self.current_metrics.cpu_utilization,
                    self.current_metrics.bottlenecks,
                    self.current_metrics.optimization_recommendations,
                ),
            )

            self.db_connection.commit()

        except Exception as e:
            logger.error(f"Failed to store performance metrics: {e}")

    async def run_performance_test(self) -> Dict[str, Any]:
        """Run comprehensive performance test"""
        logger.info("🚀 Running Shadowgit Performance Test")

        # Simulate different Git operations
        test_results = {}

        # Test 1: Small file diff operation
        await self.record_git_operation("diff", 10, 1000, 50, "/test/repo", "CPU")

        # Test 2: Large file hash operation
        await self.record_git_operation("hash", 100, 50000, 150, "/test/repo", "AVX2")

        # Test 3: NPU-accelerated operation (if available)
        if self.npu_available:
            await self.record_git_operation(
                "index", 500, 200000, 80, "/test/repo", "NPU"
            )

        # Test 4: Massive repository operation
        await self.record_git_operation(
            "diff", 5000, 2000000, 800, "/large/repo", "AVX2"
        )

        # Wait for processing
        await asyncio.sleep(1)

        # Calculate results
        if self.current_metrics:
            current_throughput = 0
            if self.performance_history:
                recent_ops = self.performance_history[-5:]
                current_throughput = np.mean(
                    [op.throughput_lines_per_sec for op in recent_ops]
                )

            test_results = {
                "current_throughput_lines_per_sec": current_throughput,
                "baseline_throughput": self.baseline_performance,
                "target_throughput": self.target_performance,
                "achievement_percentage": self.current_metrics.achievement_percentage,
                "npu_utilization": self.current_metrics.npu_utilization,
                "avx2_utilization": self.current_metrics.avx2_utilization,
                "bottlenecks": self.current_metrics.bottlenecks,
                "recommendations": self.current_metrics.optimization_recommendations,
                "operations_tested": len(self.performance_history),
                "npu_available": self.npu_available,
            }

        return test_results

    def get_performance_dashboard(self) -> Dict[str, Any]:
        """Get performance dashboard data"""
        if not self.current_metrics or not self.performance_history:
            return {"status": "No data available"}

        recent_ops = self.performance_history[-20:]
        current_throughput = np.mean([op.throughput_lines_per_sec for op in recent_ops])

        return {
            "current_performance": {
                "throughput_lines_per_sec": current_throughput,
                "vs_baseline": (current_throughput / self.baseline_performance) * 100,
                "vs_target": (current_throughput / self.target_performance) * 100,
            },
            "hardware_utilization": {
                "npu_utilization": self.current_metrics.npu_utilization,
                "avx2_utilization": self.current_metrics.avx2_utilization,
                "cpu_utilization": self.current_metrics.cpu_utilization,
            },
            "analysis": {
                "bottlenecks": self.current_metrics.bottlenecks,
                "recommendations": self.current_metrics.optimization_recommendations,
            },
            "system_status": {
                "npu_available": self.npu_available,
                "monitoring_active": self.is_monitoring,
                "operations_recorded": len(self.performance_history),
                "database_connected": self.db_connection is not None,
            },
        }


async def performance_test():
    """Test Shadowgit Performance Integration"""
    print("🚀 Shadowgit Performance Integration Test")
    print("=" * 60)

    # Initialize monitor
    monitor = ShadowgitPerformanceMonitor()
    await monitor.initialize()

    # Run performance test
    results = await monitor.run_performance_test()

    print(f"\n📊 Performance Test Results:")
    print(
        f"   Current throughput: {results.get('current_throughput_lines_per_sec', 0):.0f} lines/sec"
    )
    print(f"   Baseline: {results.get('baseline_throughput', 0):.0f} lines/sec")
    print(f"   Target: {results.get('target_throughput', 0):.0f} lines/sec")
    print(f"   Achievement: {results.get('achievement_percentage', 0):.1f}%")

    print(f"\n🔧 Hardware Utilization:")
    print(f"   NPU: {results.get('npu_utilization', 0):.1f}%")
    print(f"   AVX2: {results.get('avx2_utilization', 0):.1f}%")
    print(f"   NPU Available: {results.get('npu_available', False)}")

    bottlenecks = results.get("bottlenecks", [])
    if bottlenecks:
        print(f"\n⚠️ Bottlenecks:")
        for bottleneck in bottlenecks:
            print(f"   • {bottleneck}")

    recommendations = results.get("recommendations", [])
    if recommendations:
        print(f"\n💡 Recommendations:")
        for rec in recommendations:
            print(f"   • {rec}")

    # Dashboard
    dashboard = monitor.get_performance_dashboard()
    print(f"\n📈 System Status:")
    status = dashboard.get("system_status", {})
    print(f"   Monitoring: {status.get('monitoring_active', False)}")
    print(f"   Database: {status.get('database_connected', False)}")
    print(f"   Operations: {status.get('operations_recorded', 0)}")

    target_achievement = results.get("achievement_percentage", 0)
    if target_achievement >= 100:
        print(
            f"\n🎯 TARGET ACHIEVED: {target_achievement:.1f}% of 11.5M lines/sec target"
        )
    else:
        print(
            f"\n📈 TARGET PROGRESS: {target_achievement:.1f}% toward 11.5M lines/sec target"
        )


if __name__ == "__main__":
    asyncio.run(performance_test())
