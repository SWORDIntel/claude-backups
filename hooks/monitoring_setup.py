#!/usr/bin/env python3
"""
Production Monitoring Setup for Claude Unified Hook System v3.1
Provides metrics collection, health checks, and alerting integration
"""

import asyncio
import json
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional
from collections import defaultdict, deque
import psutil
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('HookMonitoring')


class MetricsCollector:
    """Collects and aggregates system metrics"""
    
    def __init__(self, window_size: int = 300):  # 5-minute window
        self.window_size = window_size
        self.metrics = defaultdict(lambda: deque(maxlen=window_size))
        self.start_time = time.time()
        
    def record(self, metric: str, value: float, tags: Optional[Dict] = None):
        """Record a metric value"""
        timestamp = time.time()
        self.metrics[metric].append({
            'timestamp': timestamp,
            'value': value,
            'tags': tags or {}
        })
    
    def get_stats(self, metric: str) -> Dict[str, float]:
        """Get statistics for a metric"""
        if metric not in self.metrics or not self.metrics[metric]:
            return {}
        
        values = [m['value'] for m in self.metrics[metric]]
        return {
            'min': min(values),
            'max': max(values),
            'avg': sum(values) / len(values),
            'count': len(values),
            'last': values[-1] if values else 0
        }
    
    def get_rate(self, metric: str) -> float:
        """Calculate rate per second for a counter metric"""
        if metric not in self.metrics or len(self.metrics[metric]) < 2:
            return 0.0
        
        data = list(self.metrics[metric])
        time_diff = data[-1]['timestamp'] - data[0]['timestamp']
        if time_diff == 0:
            return 0.0
        
        value_diff = data[-1]['value'] - data[0]['value']
        return value_diff / time_diff


class HealthChecker:
    """Performs health checks on the hook system"""
    
    def __init__(self, hooks_system):
        self.hooks = hooks_system
        self.checks = {
            'system': self.check_system_resources,
            'agents': self.check_agent_loading,
            'patterns': self.check_pattern_matching,
            'performance': self.check_performance,
            'errors': self.check_error_rate
        }
        self.last_results = {}
        
    async def check_system_resources(self) -> Dict[str, Any]:
        """Check system resource utilization"""
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            'healthy': cpu_percent < 80 and memory.percent < 90,
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_available_gb': memory.available / (1024**3),
            'disk_percent': disk.percent
        }
    
    async def check_agent_loading(self) -> Dict[str, Any]:
        """Check if agents are loaded correctly"""
        agent_count = len(self.hooks.engine.registry.agents)
        expected_count = 80  # Expected number of agents
        
        return {
            'healthy': agent_count >= expected_count * 0.9,  # 90% threshold
            'loaded': agent_count,
            'expected': expected_count,
            'percentage': (agent_count / expected_count) * 100
        }
    
    async def check_pattern_matching(self) -> Dict[str, Any]:
        """Test pattern matching functionality"""
        test_inputs = [
            "Fix security vulnerability",
            "Optimize performance",
            "Deploy to production"
        ]
        
        success_count = 0
        total_time = 0
        
        for test_input in test_inputs:
            start = time.time()
            result = await self.hooks.process(test_input)
            elapsed = time.time() - start
            total_time += elapsed
            
            if result.get('agents'):
                success_count += 1
        
        return {
            'healthy': success_count == len(test_inputs),
            'success_rate': (success_count / len(test_inputs)) * 100,
            'avg_response_ms': (total_time / len(test_inputs)) * 1000
        }
    
    async def check_performance(self) -> Dict[str, Any]:
        """Check system performance metrics"""
        # Run a quick performance test
        test_count = 100
        start = time.time()
        
        tasks = [
            self.hooks.process(f"Test input {i}")
            for i in range(test_count)
        ]
        await asyncio.gather(*tasks)
        
        elapsed = time.time() - start
        throughput = test_count / elapsed
        
        return {
            'healthy': throughput > 1000,  # Minimum 1000 req/s
            'throughput': throughput,
            'avg_latency_ms': (elapsed / test_count) * 1000
        }
    
    async def check_error_rate(self) -> Dict[str, Any]:
        """Check system error rate"""
        # This would integrate with actual error tracking
        # For now, return mock healthy status
        return {
            'healthy': True,
            'error_rate': 0.0,
            'errors_last_5min': 0
        }
    
    async def run_all_checks(self) -> Dict[str, Any]:
        """Run all health checks"""
        results = {}
        overall_healthy = True
        
        for name, check_func in self.checks.items():
            try:
                result = await check_func()
                results[name] = result
                if not result.get('healthy', False):
                    overall_healthy = False
            except Exception as e:
                logger.error(f"Health check {name} failed: {e}")
                results[name] = {'healthy': False, 'error': str(e)}
                overall_healthy = False
        
        self.last_results = results
        results['overall_healthy'] = overall_healthy
        results['timestamp'] = datetime.now().isoformat()
        
        return results


class AlertManager:
    """Manages alerts based on metrics and health checks"""
    
    def __init__(self, webhook_url: Optional[str] = None):
        self.webhook_url = webhook_url
        self.alert_history = deque(maxlen=100)
        self.alert_thresholds = {
            'cpu_percent': 80,
            'memory_percent': 90,
            'error_rate': 5,  # 5% error rate
            'throughput_min': 1000,  # req/s
            'response_time_max': 100  # ms
        }
    
    def check_thresholds(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Check if any metrics exceed thresholds"""
        alerts = []
        
        # Check CPU
        if 'cpu_percent' in metrics and metrics['cpu_percent'] > self.alert_thresholds['cpu_percent']:
            alerts.append({
                'severity': 'warning',
                'metric': 'cpu_percent',
                'value': metrics['cpu_percent'],
                'threshold': self.alert_thresholds['cpu_percent'],
                'message': f"High CPU usage: {metrics['cpu_percent']:.1f}%"
            })
        
        # Check Memory
        if 'memory_percent' in metrics and metrics['memory_percent'] > self.alert_thresholds['memory_percent']:
            alerts.append({
                'severity': 'critical',
                'metric': 'memory_percent',
                'value': metrics['memory_percent'],
                'threshold': self.alert_thresholds['memory_percent'],
                'message': f"High memory usage: {metrics['memory_percent']:.1f}%"
            })
        
        # Check throughput
        if 'throughput' in metrics and metrics['throughput'] < self.alert_thresholds['throughput_min']:
            alerts.append({
                'severity': 'warning',
                'metric': 'throughput',
                'value': metrics['throughput'],
                'threshold': self.alert_thresholds['throughput_min'],
                'message': f"Low throughput: {metrics['throughput']:.1f} req/s"
            })
        
        return alerts
    
    async def send_alert(self, alert: Dict[str, Any]):
        """Send alert to configured webhook"""
        alert['timestamp'] = datetime.now().isoformat()
        self.alert_history.append(alert)
        
        if self.webhook_url:
            # Would send to actual webhook
            logger.warning(f"ALERT: {alert['message']}")
        else:
            logger.info(f"Alert (no webhook): {alert['message']}")


class MonitoringDashboard:
    """Simple monitoring dashboard"""
    
    def __init__(self, metrics: MetricsCollector, health: HealthChecker, alerts: AlertManager):
        self.metrics = metrics
        self.health = health
        self.alerts = alerts
    
    def generate_report(self) -> str:
        """Generate a monitoring report"""
        report = []
        report.append("=" * 60)
        report.append("CLAUDE UNIFIED HOOK SYSTEM - MONITORING DASHBOARD")
        report.append("=" * 60)
        report.append(f"Report Time: {datetime.now().isoformat()}")
        report.append("")
        
        # Health Status
        if self.health.last_results:
            overall = self.health.last_results.get('overall_healthy', False)
            status = "✅ HEALTHY" if overall else "❌ UNHEALTHY"
            report.append(f"Overall Status: {status}")
            report.append("")
            
            # Individual health checks
            report.append("Health Checks:")
            for check_name, result in self.health.last_results.items():
                if check_name in ['overall_healthy', 'timestamp']:
                    continue
                status = "✅" if result.get('healthy', False) else "❌"
                report.append(f"  {status} {check_name}: {result}")
        
        report.append("")
        
        # Performance Metrics
        report.append("Performance Metrics:")
        for metric in ['request_count', 'response_time', 'error_count']:
            stats = self.metrics.get_stats(metric)
            if stats:
                report.append(f"  {metric}:")
                report.append(f"    Min: {stats['min']:.2f}")
                report.append(f"    Max: {stats['max']:.2f}")
                report.append(f"    Avg: {stats['avg']:.2f}")
                report.append(f"    Last: {stats['last']:.2f}")
        
        report.append("")
        
        # Recent Alerts
        report.append("Recent Alerts:")
        if self.alerts.alert_history:
            for alert in list(self.alerts.alert_history)[-5:]:  # Last 5 alerts
                report.append(f"  [{alert.get('severity', 'info').upper()}] {alert.get('message', 'Unknown alert')}")
        else:
            report.append("  No recent alerts")
        
        report.append("")
        report.append("=" * 60)
        
        return "\n".join(report)


async def setup_monitoring(hooks_system):
    """Set up production monitoring for the hook system"""
    
    # Initialize components
    metrics = MetricsCollector()
    health = HealthChecker(hooks_system)
    alerts = AlertManager()
    dashboard = MonitoringDashboard(metrics, health, alerts)
    
    logger.info("Production monitoring initialized")
    
    # Run initial health check
    health_results = await health.run_all_checks()
    logger.info(f"Initial health check: {'PASSED' if health_results['overall_healthy'] else 'FAILED'}")
    
    # Check for alerts
    flat_metrics = {}
    for check_results in health_results.values():
        if isinstance(check_results, dict):
            flat_metrics.update(check_results)
    
    alert_list = alerts.check_thresholds(flat_metrics)
    for alert in alert_list:
        await alerts.send_alert(alert)
    
    # Generate initial report
    report = dashboard.generate_report()
    print(report)
    
    return {
        'metrics': metrics,
        'health': health,
        'alerts': alerts,
        'dashboard': dashboard
    }


async def monitoring_loop(hooks_system, interval: int = 60):
    """Continuous monitoring loop"""
    monitoring = await setup_monitoring(hooks_system)
    
    while True:
        try:
            # Run health checks
            health_results = await monitoring['health'].run_all_checks()
            
            # Record metrics
            monitoring['metrics'].record('health_check_run', 1)
            
            # Check for alerts
            flat_metrics = {}
            for check_results in health_results.values():
                if isinstance(check_results, dict):
                    flat_metrics.update(check_results)
            
            alert_list = monitoring['alerts'].check_thresholds(flat_metrics)
            for alert in alert_list:
                await monitoring['alerts'].send_alert(alert)
            
            # Log status
            status = "HEALTHY" if health_results['overall_healthy'] else "UNHEALTHY"
            logger.info(f"Monitoring cycle complete - Status: {status}")
            
            # Wait for next cycle
            await asyncio.sleep(interval)
            
        except Exception as e:
            logger.error(f"Monitoring error: {e}")
            await asyncio.sleep(interval)


async def main():
    """Test monitoring setup"""
    # Import the hook system
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from claude_unified_hook_system_v2 import ClaudeUnifiedHooks
    
    # Initialize hook system
    hooks = ClaudeUnifiedHooks()
    
    # Set up monitoring
    monitoring = await setup_monitoring(hooks)
    
    # Run some test operations
    test_inputs = [
        "Fix the security vulnerability",
        "Optimize database performance",
        "Deploy to production",
        "Debug the application",
        "Monitor system metrics"
    ]
    
    for test_input in test_inputs:
        start = time.time()
        result = await hooks.process(test_input)
        elapsed = (time.time() - start) * 1000
        
        # Record metrics
        monitoring['metrics'].record('request_count', 1)
        monitoring['metrics'].record('response_time', elapsed)
        if 'error' in result:
            monitoring['metrics'].record('error_count', 1)
    
    # Run health check
    health_results = await monitoring['health'].run_all_checks()
    
    # Generate report
    report = monitoring['dashboard'].generate_report()
    print(report)
    
    # Save monitoring config
    config = {
        'monitoring_enabled': True,
        'health_check_interval': 60,
        'metrics_retention': 300,
        'alert_thresholds': monitoring['alerts'].alert_thresholds,
        'webhook_url': None  # Set this for production
    }
    
    config_path = Path(__file__).parent / 'monitoring_config.json'
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    logger.info(f"Monitoring configuration saved to {config_path}")


if __name__ == "__main__":
    asyncio.run(main())