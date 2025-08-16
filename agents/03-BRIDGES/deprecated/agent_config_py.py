#!/usr/bin/env python3
"""
Agent System Configuration Module
Centralizes all configuration for the binary protocol and agent system
"""

import os
import socket
import json
from pathlib import Path
from typing import Dict, Any, Optional

class AgentConfig:
    """Central configuration for agent system"""
    
    # Base directories
    AGENTS_DIR = Path("/home/ubuntu/Documents/Claude/agents")
    RUNTIME_DIR = AGENTS_DIR / "06-BUILD-RUNTIME" / "runtime"
    BUILD_DIR = AGENTS_DIR / "06-BUILD-RUNTIME" / "build"
    CONFIG_DIR = AGENTS_DIR / "05-CONFIG"
    
    # Socket configuration (NOT in /tmp due to noexec)
    SOCKET_PATH = str(RUNTIME_DIR / "claude_agent_bridge.sock")
    
    # Alternative socket paths for fallback
    SOCKET_PATHS = [
        str(RUNTIME_DIR / "claude_agent_bridge.sock"),  # Primary
        str(AGENTS_DIR / "06-BUILD-RUNTIME" / "runtime" / "claude_agent_bridge.sock"),   # Same as primary
        str(AGENTS_DIR / "claude_agent_bridge.sock"),   # Fallback if old location
    ]
    
    # Binary protocol settings
    RING_BUFFER_SIZE = 16 * 1024 * 1024  # 16MB
    MSG_BUFFER_SIZE = 65536  # 64KB
    MAX_AGENTS = 32
    
    # Performance settings
    USE_HUGE_PAGES = True
    USE_REALTIME_SCHED = True
    CACHE_LINE_SIZE = 64
    
    @classmethod
    def get_socket_path(cls) -> str:
        """Get the active socket path, checking environment and availability"""
        
        # Check environment variable first
        env_socket = os.environ.get("AGENT_SOCKET_PATH")
        if env_socket and os.path.exists(env_socket):
            return env_socket
        
        # Check configured paths
        for socket_path in cls.SOCKET_PATHS:
            if os.path.exists(socket_path):
                # Verify it's a socket
                if os.path.stat(socket_path).st_mode & 0o170000 == 0o140000:
                    return socket_path
        
        # Return default (will be created on startup)
        return cls.SOCKET_PATH
    
    @classmethod
    def ensure_directories(cls):
        """Ensure all required directories exist"""
        for directory in [cls.RUNTIME_DIR, cls.BUILD_DIR, cls.CONFIG_DIR]:
            directory.mkdir(parents=True, exist_ok=True)
            directory.chmod(0o755)
    
    @classmethod
    def test_socket_connection(cls) -> bool:
        """Test if the binary bridge socket is responding"""
        socket_path = cls.get_socket_path()
        
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(1.0)
            sock.connect(socket_path)
            
            # Send test message
            sock.send(b"PING")
            response = sock.recv(4)
            sock.close()
            
            return response == b"PING"
        except Exception as e:
            print(f"Socket test failed: {e}")
            return False
    
    @classmethod
    def get_cpu_features(cls) -> Dict[str, Any]:
        """Detect CPU features for optimization"""
        features = {
            "avx2": False,
            "avx512": False,
            "p_cores": [],
            "e_cores": [],
            "cpu_model": "unknown"
        }
        
        try:
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()
                
            # Check AVX support
            if "avx2" in cpuinfo:
                features["avx2"] = True
            if "avx512f" in cpuinfo:
                features["avx512"] = True
            
            # Get CPU model
            import re
            model_match = re.search(r"model name\s*:\s*(.+)", cpuinfo)
            if model_match:
                features["cpu_model"] = model_match.group(1).strip()
            
            # Detect P-cores and E-cores for hybrid CPUs
            if "Ultra" in features["cpu_model"] or "Core Ultra" in features["cpu_model"]:
                # Meteor Lake detection
                features["is_meteor_lake"] = True
                
                # Try to detect core topology
                cpu_dirs = list(Path("/sys/devices/system/cpu").glob("cpu[0-9]*"))
                for cpu_dir in cpu_dirs:
                    cpu_num = int(cpu_dir.name[3:])
                    
                    # Check frequency to determine core type
                    freq_file = cpu_dir / "cpufreq/base_frequency"
                    if freq_file.exists():
                        freq = int(freq_file.read_text().strip())
                        if freq > 2000000:  # > 2GHz typically P-core
                            features["p_cores"].append(cpu_num)
                        else:
                            features["e_cores"].append(cpu_num)
                
        except Exception as e:
            print(f"CPU feature detection error: {e}")
        
        return features
    
    @classmethod
    def write_config(cls, config_file: Optional[str] = None):
        """Write current configuration to file"""
        if config_file is None:
            config_file = cls.CONFIG_DIR / "agent_system.json"
        
        config = {
            "socket_path": cls.get_socket_path(),
            "runtime_dir": str(cls.RUNTIME_DIR),
            "build_dir": str(cls.BUILD_DIR),
            "cpu_features": cls.get_cpu_features(),
            "protocol_settings": {
                "ring_buffer_size": cls.RING_BUFFER_SIZE,
                "msg_buffer_size": cls.MSG_BUFFER_SIZE,
                "max_agents": cls.MAX_AGENTS
            }
        }
        
        with open(config_file, "w") as f:
            json.dump(config, f, indent=2)
        
        print(f"Configuration written to: {config_file}")
        return config
    
    @classmethod
    def load_config(cls, config_file: Optional[str] = None) -> Dict[str, Any]:
        """Load configuration from file"""
        if config_file is None:
            config_file = cls.CONFIG_DIR / "agent_system.json"
        
        if os.path.exists(config_file):
            with open(config_file, "r") as f:
                return json.load(f)
        else:
            # Create default config
            return cls.write_config(config_file)


class BinaryBridgeConnection:
    """Helper class for connecting to the binary bridge"""
    
    def __init__(self, socket_path: Optional[str] = None):
        self.socket_path = socket_path or AgentConfig.get_socket_path()
        self.socket = None
    
    def connect(self) -> bool:
        """Connect to the binary bridge"""
        try:
            self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.socket.connect(self.socket_path)
            return True
        except Exception as e:
            print(f"Connection failed: {e}")
            return False
    
    def send_message(self, message: bytes) -> Optional[bytes]:
        """Send a message and receive response"""
        if not self.socket:
            if not self.connect():
                return None
        
        try:
            self.socket.send(message)
            response = self.socket.recv(65536)  # MSG_BUFFER_SIZE
            return response
        except Exception as e:
            print(f"Message send/receive failed: {e}")
            return None
    
    def close(self):
        """Close the connection"""
        if self.socket:
            self.socket.close()
            self.socket = None
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


def setup_agent_environment():
    """Set up the agent environment"""
    print("🔧 Setting up agent environment...")
    
    # Ensure directories exist
    AgentConfig.ensure_directories()
    
    # Set environment variables
    os.environ["AGENT_SOCKET_PATH"] = AgentConfig.SOCKET_PATH
    os.environ["AGENT_RUNTIME_DIR"] = str(AgentConfig.RUNTIME_DIR)
    os.environ["AGENT_BUILD_DIR"] = str(AgentConfig.BUILD_DIR)
    
    # Detect CPU features
    features = AgentConfig.get_cpu_features()
    print(f"  CPU: {features['cpu_model']}")
    print(f"  AVX2: {'✓' if features['avx2'] else '✗'}")
    print(f"  AVX512: {'✓' if features['avx512'] else '✗'}")
    
    if features.get("p_cores"):
        print(f"  P-cores: {features['p_cores'][:4]}...")  # Show first 4
        print(f"  E-cores: {features['e_cores'][:4]}...")
    
    # Write configuration
    config = AgentConfig.write_config()
    
    # Test socket if available
    if AgentConfig.test_socket_connection():
        print("✅ Binary bridge connected")
    else:
        print("⚠️  Binary bridge not available")
        print(f"   Socket path: {AgentConfig.get_socket_path()}")
    
    return config


def quick_test():
    """Quick test of the binary bridge connection"""
    print("🧪 Testing binary bridge connection...")
    
    with BinaryBridgeConnection() as conn:
        if conn.socket:
            # Send test message
            test_msg = b"HELLO_AGENT_SYSTEM"
            response = conn.send_message(test_msg)
            
            if response:
                print(f"✅ Response received: {response[:50]}")
            else:
                print("⚠️  No response from bridge")
        else:
            print("❌ Could not connect to bridge")
            print(f"   Expected socket: {conn.socket_path}")
            print("   Start bridge with: ./BRING_ONLINE_FIXED.sh")


if __name__ == "__main__":
    # Set up environment and run test
    setup_agent_environment()
    print()
    quick_test()
