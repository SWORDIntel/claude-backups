#!/usr/bin/env python3
"""
Performance monitoring for Claude Unified Hook System v3.1
Real-time metrics collection and reporting
"""

import asyncio
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List


class HookPerformanceMonitor:
    """Real-time performance monitoring for hook system"""

    def __init__(self, cache_dir: Path = None):
        self.cache_dir = cache_dir or Path.home() / ".cache" / "claude-agents"
        self.metrics_file = self.cache_dir / "hook_performance.json"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.start_time = time.time()
        self.execution_times = []
        self.error_counts = 0
        self.cache_stats = {"hits": 0, "misses": 0}

    def record_execution(
        self,
        execution_time_ms: float,
        success: bool = True,
        cache_hit: bool = False,
        agent_count: int = 1,
    ):
        """Record execution metrics"""
        self.execution_times.append(
            {
                "timestamp": datetime.now().isoformat(),
                "execution_time_ms": execution_time_ms,
                "success": success,
                "cache_hit": cache_hit,
                "agent_count": agent_count,
            }
        )

        if cache_hit:
            self.cache_stats["hits"] += 1
        else:
            self.cache_stats["misses"] += 1

        if not success:
            self.error_counts += 1

        # Keep only last 1000 records
        if len(self.execution_times) > 1000:
            self.execution_times = self.execution_times[-1000:]

    def get_performance_summary(self) -> Dict[str, Any]:
        """Generate performance summary"""
        if not self.execution_times:
            return {
                "status": "no_data",
                "uptime_seconds": time.time() - self.start_time,
            }

        recent_times = [e["execution_time_ms"] for e in self.execution_times[-100:]]
        total_execs = len(self.execution_times)
        successful_execs = sum(1 for e in self.execution_times if e["success"])

        cache_total = self.cache_stats["hits"] + self.cache_stats["misses"]
        cache_hit_rate = (
            (self.cache_stats["hits"] / cache_total * 100) if cache_total > 0 else 0
        )

        return {
            "status": "active",
            "uptime_seconds": time.time() - self.start_time,
            "total_executions": total_execs,
            "success_rate": (
                (successful_execs / total_execs * 100) if total_execs > 0 else 0
            ),
            "error_count": self.error_counts,
            "performance": {
                "avg_execution_time_ms": (
                    sum(recent_times) / len(recent_times) if recent_times else 0
                ),
                "min_execution_time_ms": min(recent_times) if recent_times else 0,
                "max_execution_time_ms": max(recent_times) if recent_times else 0,
                "p95_execution_time_ms": (
                    sorted(recent_times)[int(len(recent_times) * 0.95)]
                    if len(recent_times) > 5
                    else 0
                ),
            },
            "cache_performance": {
                "hit_rate_percent": cache_hit_rate,
                "total_hits": self.cache_stats["hits"],
                "total_misses": self.cache_stats["misses"],
            },
            "recent_executions": self.execution_times[-10:],  # Last 10 for debugging
        }

    def save_metrics(self):
        """Persist metrics to disk"""
        try:
            metrics = self.get_performance_summary()
            with open(self.metrics_file, "w") as f:
                json.dump(metrics, f, indent=2)
        except Exception as e:
            print(f"Failed to save metrics: {e}")

    def load_metrics(self) -> Dict[str, Any]:
        """Load persisted metrics"""
        try:
            if self.metrics_file.exists():
                with open(self.metrics_file, "r") as f:
                    return json.load(f)
        except Exception as e:
            print(f"Failed to load metrics: {e}")
        return {}


if __name__ == "__main__":
    # Test monitoring
    monitor = HookPerformanceMonitor()

    # Simulate some executions
    monitor.record_execution(45.2, True, False, 3)
    monitor.record_execution(23.1, True, True, 1)
    monitor.record_execution(67.8, False, False, 5)

    summary = monitor.get_performance_summary()
    print("Performance Monitor Test:")
    print(json.dumps(summary, indent=2))

    monitor.save_metrics()
    print(f"Metrics saved to: {monitor.metrics_file}")
