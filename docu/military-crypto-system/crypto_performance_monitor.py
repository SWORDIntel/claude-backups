#!/usr/bin/env python3
"""
Optimized Cryptographic PoW Performance Monitor
Advanced ML-powered analytics with real-time feedback
"""

import asyncio
import asyncpg
import numpy as np
import time
import psutil
import subprocess
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import signal
import sys
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor
import sqlite3
import pickle

# Configuration
POSTGRES_CONFIG = {
    "host": "localhost",
    "port": 5433,
    "database": "claude_agents_auth",
    "user": "claude_agent"
}

CRYPTO_BINARY = "/home/john/claude-backups/crypto_pow_demo"
PERFORMANCE_TARGET = 100
MONITORING_INTERVAL = 3  # Optimized interval
BATCH_SIZE = 50  # Batch processing for efficiency

@dataclass
class PerformanceMetrics:
    timestamp: datetime
    vps: float
    cpu_usage: float
    memory_mb: float
    success_rate: float
    queue_depth: int
    prediction: float

class OptimizedCryptoMonitor:
    def __init__(self):
        self.pool = None
        self.running = True
        self.metrics_cache = []
        self.ml_model = None
        self.executor = ThreadPoolExecutor(max_workers=4)
        
        # Setup logging
        logging.basicConfig(level=logging.INFO, 
                          format="%(asctime)s - %(levelname)s - %(message)s")
        self.logger = logging.getLogger(__name__)
        
        # Signal handlers
        signal.signal(signal.SIGINT, self.shutdown)
        signal.signal(signal.SIGTERM, self.shutdown)
    
    async def initialize(self):
        """Initialize optimized connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                **POSTGRES_CONFIG,
                min_size=5,
                max_size=20,
                command_timeout=5,
                server_settings={"application_name": "crypto_monitor_optimized"}
            )
            self.logger.info("Database pool initialized")
            await self.init_ml_model()
            return True
        except Exception as e:
            self.logger.error(f"Initialization failed: {e}")
            return False
    
    async def init_ml_model(self):
        """Initialize ML prediction model"""
        try:
            # Simple linear regression for performance prediction
            self.ml_model = {"weights": np.array([1.0, -0.01, -0.005]), "bias": 0}
            self.logger.info("ML model initialized")
        except Exception as e:
            self.logger.error(f"ML model init failed: {e}")
    
    def predict_performance(self, cpu: float, memory: float, queue: int) -> float:
        """Predict performance using ML model"""
        if not self.ml_model:
            return PERFORMANCE_TARGET
        
        features = np.array([1.0, cpu, memory/1000])
        return max(0, np.dot(features, self.ml_model["weights"]) + self.ml_model["bias"])
    
    async def collect_metrics(self) -> PerformanceMetrics:
        """Optimized metrics collection"""
        try:
            # Parallel collection
            tasks = [
                self.executor.submit(self.get_system_metrics),
                self.executor.submit(self.measure_crypto_performance)
            ]
            
            results = await asyncio.gather(*[
                asyncio.get_event_loop().run_in_executor(None, task.result)
                for task in tasks
            ])
            
            system_metrics, crypto_metrics = results
            
            prediction = self.predict_performance(
                system_metrics["cpu"], 
                system_metrics["memory"], 
                crypto_metrics.get("queue_depth", 0)
            )
            
            return PerformanceMetrics(
                timestamp=datetime.now(),
                vps=crypto_metrics.get("vps", 0),
                cpu_usage=system_metrics["cpu"],
                memory_mb=system_metrics["memory"],
                success_rate=crypto_metrics.get("success_rate", 0),
                queue_depth=crypto_metrics.get("queue_depth", 0),
                prediction=prediction
            )
        except Exception as e:
            self.logger.error(f"Metrics collection failed: {e}")
            return PerformanceMetrics(
                datetime.now(), 0, 0, 0, 0, 0, 0
            )
    
    def get_system_metrics(self) -> Dict:
        """Get system metrics efficiently"""
        cpu = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory().used / (1024 * 1024)
        return {"cpu": cpu, "memory": memory}
    
    def measure_crypto_performance(self) -> Dict:
        """Measure crypto performance efficiently"""
        try:
            start = time.time()
            result = subprocess.run([CRYPTO_BINARY], timeout=2, capture_output=True)
            elapsed = time.time() - start
            
            if result.returncode == 0:
                vps = 1.0 / elapsed if elapsed > 0 else 0
                return {"vps": vps, "success_rate": 100.0, "queue_depth": 0}
            else:
                return {"vps": 0, "success_rate": 0, "queue_depth": 1}
        except Exception:
            return {"vps": 0, "success_rate": 0, "queue_depth": 1}
    
    async def store_metrics_batch(self, metrics_list: List[PerformanceMetrics]):
        """Optimized batch storage"""
        if not self.pool or not metrics_list:
            return
        
        try:
            async with self.pool.acquire() as conn:
                await conn.executemany(
                    """INSERT INTO crypto_learning.verification_performance 
                       (verifications_per_second, cpu_usage, memory_usage_mb, 
                        success_rate, difficulty_level, hash_algorithm) 
                       VALUES (, , , , , )""",
                    [(m.vps, m.cpu_usage, m.memory_mb, m.success_rate, 4, "SHA256") 
                     for m in metrics_list]
                )
            self.logger.info(f"Stored {len(metrics_list)} metrics in batch")
        except Exception as e:
            self.logger.error(f"Batch storage failed: {e}")
    
    async def generate_optimization_report(self) -> Dict:
        """Generate optimization recommendations"""
        if not self.pool:
            return {}
        
        try:
            async with self.pool.acquire() as conn:
                # Get recent performance data
                rows = await conn.fetch(
                    """SELECT verifications_per_second, cpu_usage, memory_usage_mb
                       FROM crypto_learning.verification_performance 
                       WHERE timestamp >= NOW() - INTERVAL '1 hour'
                       ORDER BY timestamp DESC LIMIT 100"""
                )
                
                if not rows:
                    return {"status": "insufficient_data"}
                
                vps_values = [row[0] for row in rows]
                cpu_values = [row[1] for row in rows]
                memory_values = [row[2] for row in rows]
                
                avg_vps = np.mean(vps_values)
                avg_cpu = np.mean(cpu_values)
                avg_memory = np.mean(memory_values)
                
                recommendations = []
                if avg_vps < PERFORMANCE_TARGET * 0.8:
                    recommendations.append("Performance below 80% of target - consider optimization")
                if avg_cpu > 80:
                    recommendations.append("High CPU usage - consider load balancing")
                if avg_memory > 500:
                    recommendations.append("High memory usage - review buffer sizes")
                
                return {
                    "status": "success",
                    "current_performance": {
                        "avg_vps": avg_vps,
                        "avg_cpu": avg_cpu,
                        "avg_memory": avg_memory
                    },
                    "target_vps": PERFORMANCE_TARGET,
                    "efficiency": (avg_vps / PERFORMANCE_TARGET) * 100,
                    "recommendations": recommendations
                }
        except Exception as e:
            self.logger.error(f"Optimization report failed: {e}")
            return {"status": "error", "message": str(e)}
    
    async def run_monitoring_loop(self):
        """Optimized main monitoring loop"""
        self.logger.info("Starting optimized monitoring loop")
        
        while self.running:
            try:
                # Collect metrics
                metrics = await self.collect_metrics()
                self.metrics_cache.append(metrics)
                
                # Batch storage when cache is full
                if len(self.metrics_cache) >= BATCH_SIZE:
                    await self.store_metrics_batch(self.metrics_cache)
                    self.metrics_cache.clear()
                
                # Log performance
                self.logger.info(
                    f"Performance: {metrics.vps:.1f} vps (pred: {metrics.prediction:.1f}), "
                    f"CPU: {metrics.cpu_usage:.1f}%, Memory: {metrics.memory_mb:.0f}MB"
                )
                
                # Generate reports every 10 minutes
                if int(time.time()) % 600 == 0:
                    report = await self.generate_optimization_report()
                    if report.get("status") == "success":
                        self.logger.info(f"Efficiency: {report['efficiency']:.1f}%")
                
                await asyncio.sleep(MONITORING_INTERVAL)
                
            except Exception as e:
                self.logger.error(f"Monitoring loop error: {e}")
                await asyncio.sleep(MONITORING_INTERVAL)
    
    def shutdown(self, signum=None, frame=None):
        """Graceful shutdown"""
        self.logger.info("Shutting down monitor...")
        self.running = False
        
        # Store remaining cached metrics
        if self.metrics_cache and self.pool:
            asyncio.create_task(self.store_metrics_batch(self.metrics_cache))
        
        if self.pool:
            asyncio.create_task(self.pool.close())
        
        self.executor.shutdown(wait=True)

async def main():
    monitor = OptimizedCryptoMonitor()
    
    if await monitor.initialize():
        await monitor.run_monitoring_loop()
    else:
        print("Failed to initialize crypto monitor")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(asyncio.run(main()))
