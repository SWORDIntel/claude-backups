#!/usr/bin/env python3
# Bridge System Monitor
import time
import json
import sys

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
