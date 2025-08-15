#!/usr/bin/env python3
# Bridge System Monitor
import time
import json
import sys
sys.path.append('/home/ubuntu/Documents/Claude/agents')

from claude_agent_bridge import bridge

class BridgeMonitor:
    def __init__(self):
        self.metrics = {}
        self.start_time = time.time()
    
    def log_metric(self, metric_name, value):
        timestamp = time.time()
        if metric_name not in self.metrics:
            self.metrics[metric_name] = []
        self.metrics[metric_name].append({"timestamp": timestamp, "value": value})
    
    def get_summary(self):
        return {
            "uptime": time.time() - self.start_time,
            "total_metrics": len(self.metrics),
            "status": "healthy"
        }

monitor = BridgeMonitor()
