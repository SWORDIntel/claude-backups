#!/usr/bin/env python3
"""
Claude Agent Communication Server
Runs continuously to handle inter-agent communication
"""

import asyncio
import json
import time
import socket
import threading
from datetime import datetime


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
class AgentServer:
    def __init__(self, host='127.0.0.1', port=9999):
        self.host = host
        self.port = port
        self.agents = {}
        self.running = True
        self.message_count = 0
        self.start_time = time.time()
        
    def register_agent(self, agent_name, agent_type="CORE"):
        """Register an agent with the server"""
        self.agents[agent_name] = {
            'type': agent_type,
            'registered': datetime.now().isoformat(),
            'status': 'active'
        }
        return True
        
    def handle_message(self, data):
        """Process incoming agent messages"""
        try:
            message = json.loads(data)
            self.message_count += 1
            
            # Route message to appropriate handler
            if message.get('action') == 'register':
                return self.register_agent(message['agent'], message.get('type', 'CORE'))
            elif message.get('action') == 'status':
                return self.get_status()
            elif message.get('action') == 'send':
                # Forward message to target agent
                return {'status': 'forwarded', 'target': message.get('target')}
            else:
                return {'status': 'processed', 'id': self.message_count}
        except Exception as e:
            return {'error': str(e)}
    
    def get_status(self):
        """Return server status"""
        uptime = time.time() - self.start_time
        return {
            'status': 'running',
            'agents': len(self.agents),
            'messages_processed': self.message_count,
            'uptime_seconds': int(uptime),
            'throughput': self.message_count / max(uptime, 1)
        }
    
    def connection_handler(self, client_socket, address):
        """Handle individual client connections"""
        print(f"Connection from {address}")
        try:
            while self.running:
                data = client_socket.recv(4096)
                if not data:
                    break
                    
                response = self.handle_message(data.decode())
                client_socket.send(json.dumps(response).encode())
        except Exception as e:
            print(f"Connection error: {e}")
        finally:
            client_socket.close()
    
    def run(self):
        """Main server loop"""
        # Register default agents
        default_agents = [
            "director", "project_orchestrator", "architect", "security",
            "constructor", "testbed", "optimizer", "debugger", "deployer",
            "monitor", "database", "ml_ops", "patcher", "linter", "docgen",
            "infrastructure", "api_designer", "web", "mobile", "pygui", "tui",
            "data_science", "c_internal", "python_internal", "security_chaos",
            "bastion", "oversight", "researcher", "gnu", "npu", "planner"
        ]
        
        for agent in default_agents:
            self.register_agent(agent)
        
        print(f"═══════════════════════════════════════════════════════════════")
        print(f"   Claude Agent Server v1.0 - RUNNING on {self.host}:{self.port}")
        print(f"═══════════════════════════════════════════════════════════════")
        print(f"✓ {len(self.agents)} agents registered")
        print(f"✓ Ready to handle communication")
        print(f"═══════════════════════════════════════════════════════════════")
        
        # Create server socket
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((self.host, self.port))
        server_socket.listen(10)
        server_socket.settimeout(1.0)  # Allow checking self.running
        
        try:
            while self.running:
                try:
                    client_socket, address = server_socket.accept()
                    # Handle each client in a separate thread
                    thread = threading.Thread(
                        target=self.connection_handler,
                        args=(client_socket, address)
                    )
                    thread.daemon = True
                    thread.start()
                except socket.timeout:
                    continue  # Check self.running and continue
                except Exception as e:
                    print(f"Server error: {e}")
                    
                # Print status every 100 messages
                if self.message_count > 0 and self.message_count % 100 == 0:
                    status = self.get_status()
                    print(f"Status: {status['messages_processed']} messages, "
                          f"{status['throughput']:.1f} msg/sec")
        finally:
            server_socket.close()
            print("Server stopped")

if __name__ == "__main__":
    import signal
    import sys
    import os
from pathlib import Path
    
    server = AgentServer()
    
    def signal_handler(sig, frame):
        print("\nShutting down server...")
        server.running = False
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create a flag file to indicate server is running
    with open('/home/ubuntu/Documents/Claude/agents/.server_running', 'w') as f:
        f.write(str(os.getpid()))
    
    try:
        server.run()
    finally:
        # Clean up flag file
        if os.path.exists('/home/ubuntu/Documents/Claude/agents/.server_running'):
            os.remove('/home/ubuntu/Documents/Claude/agents/.server_running')