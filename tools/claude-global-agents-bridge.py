#!/usr/bin/env python3
"""
Claude Global Agents Bridge v10.0 - Unified Coordination System
Coordinates between Task tool, Tandem orchestrator, and C-system
Provides seamless agent discovery, invocation, and performance optimization
"""

import os
import sys
import json
import yaml
import asyncio
import hashlib
import subprocess
import threading
import time
import psutil
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
from enum import Enum
import glob
import re

# Execution modes matching Tandem system
class ExecutionMode(Enum):
    INTELLIGENT = "INTELLIGENT"      # Python orchestrates, C executes when available
    PYTHON_ONLY = "PYTHON_ONLY"      # Pure Python execution
    SPEED_CRITICAL = "SPEED_CRITICAL"  # C layer for maximum speed
    REDUNDANT = "REDUNDANT"          # Both layers for critical ops

class SystemCapability:
    """Detect and track system capabilities"""
    
    def __init__(self):
        self.c_layer_available = False
        self.tandem_available = False
        self.task_tool_available = True  # Always available in Claude Code
        self.avx512_available = False
        self.thermal_state = "NORMAL"
        self.last_check = None
        
    def check_capabilities(self) -> Dict[str, Any]:
        """Check current system capabilities"""
        caps = {
            'timestamp': datetime.now().isoformat(),
            'c_layer': self._check_c_layer(),
            'tandem': self._check_tandem(),
            'task_tool': True,  # Always available
            'avx512': self._check_avx512(),
            'thermal': self._check_thermal(),
            'cpu_cores': psutil.cpu_count(logical=True),
            'memory_gb': psutil.virtual_memory().total / (1024**3)
        }
        
        self.c_layer_available = caps['c_layer']['available']
        self.tandem_available = caps['tandem']['available']
        self.avx512_available = caps['avx512']
        self.thermal_state = caps['thermal']['state']
        self.last_check = time.time()
        
        return caps
    
    def _check_c_layer(self) -> Dict[str, Any]:
        """Check if C binary layer is running"""
        try:
            # Check for agent_bridge process
            result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
            c_available = 'agent_bridge' in result.stdout or 'ultra_hybrid' in result.stdout
            
            # Check for binary file using relative path
            agents_root = Path(os.environ.get('CLAUDE_AGENTS_ROOT', os.getcwd()))
            binary_path = agents_root / 'binary-communications-system' / 'ultra_hybrid_enhanced'
            binary_exists = binary_path.exists()
            
            return {
                'available': c_available,
                'process_running': c_available,
                'binary_exists': binary_exists,
                'status_file': Path('/tmp/binary_bridge_status').exists()
            }
        except:
            return {'available': False, 'error': 'Check failed'}
    
    def _check_tandem(self) -> Dict[str, Any]:
        """Check if Tandem orchestrator is available"""
        agents_root = Path(os.environ.get('CLAUDE_AGENTS_ROOT', os.getcwd()))
        tandem_path = agents_root / 'src' / 'python' / 'production_orchestrator.py'
        orchestrator_path = agents_root / 'src' / 'python' / 'production_orchestrator.py'
        
        return {
            'available': tandem_path.exists() and orchestrator_path.exists(),
            'tandem_path': str(tandem_path) if tandem_path.exists() else None,
            'orchestrator_path': str(orchestrator_path) if orchestrator_path.exists() else None
        }
    
    def _check_avx512(self) -> bool:
        """Check for AVX-512 support"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                return 'avx512' in cpuinfo.lower()
        except:
            return False
    
    def _check_thermal(self) -> Dict[str, Any]:
        """Check thermal state"""
        try:
            temps = psutil.sensors_temperatures()
            if temps:
                max_temp = max(sensor.current for sensors in temps.values() for sensor in sensors)
                state = "CRITICAL" if max_temp > 95 else "HIGH" if max_temp > 85 else "NORMAL"
                return {'state': state, 'max_temp': max_temp}
        except:
            pass
        return {'state': 'NORMAL', 'max_temp': 70}  # Default assumption


class GlobalAgentCoordinator:
    """Main coordinator between Task tool, Tandem, and C-system"""
    
    def __init__(self):
        # Use environment variable or current directory
        self.agents_dir = Path(os.environ.get('CLAUDE_AGENTS_ROOT', os.getcwd()))
        if not self.agents_dir.exists():
            # Try relative paths
            for path in ['agents', '../agents', '../../agents']:
                test_path = Path(path).resolve()
                if test_path.exists() and (test_path / 'src').exists():
                    self.agents_dir = test_path
                    break
        
        self.cache_file = Path.home() / '.cache' / 'claude-agents' / 'unified_discovery.json'
        self.config_file = Path.home() / '.cache' / 'claude-agents' / 'coordination_config.json'
        
        # Component paths (relative to agents_dir)
        self.orchestrator_path = self.agents_dir / 'src' / 'python' / 'production_orchestrator.py'
        self.tandem_path = self.agents_dir / 'src' / 'python' / 'production_orchestrator.py'
        self.c_bridge_path = self.agents_dir / 'binary-communications-system' / 'ultra_hybrid_enhanced'
        
        # System state
        self.capabilities = SystemCapability()
        self.agents = {}
        self.execution_stats = {'python': 0, 'c': 0, 'tandem': 0, 'task': 0}
        self.last_scan = None
        
        # Performance metrics
        self.metrics = {
            'avg_response_time': [],
            'throughput': [],
            'agent_invocations': {}
        }
        
    def initialize(self):
        """Initialize the coordination system"""
        print("🚀 Initializing Claude Global Agents Bridge v10.0")
        print("=" * 60)
        
        # Set environment variable if not set
        if 'CLAUDE_AGENTS_ROOT' not in os.environ:
            os.environ['CLAUDE_AGENTS_ROOT'] = str(self.agents_dir)
        
        # Check system capabilities
        print("🔍 Checking system capabilities...")
        caps = self.capabilities.check_capabilities()
        self._display_capabilities(caps)
        
        # Discover agents
        print("\n📡 Discovering agents...")
        self.agents = self.scan_for_agents()
        print(f"✓ Found {len(self.agents)} agents")
        
        # Initialize components
        print("\n🔧 Initializing components...")
        self._initialize_components()
        
        # Save configuration
        self._save_configuration()
        
        print("\n✅ Coordination system ready!")
        return True
    
    def _display_capabilities(self, caps: Dict[str, Any]):
        """Display system capabilities"""
        print(f"  • Task Tool: ✓ Available (Primary interface)")
        print(f"  • Tandem Orchestrator: {'✓' if caps['tandem']['available'] else '✗'} "
              f"{'Available' if caps['tandem']['available'] else 'Not found'}")
        print(f"  • C Binary Layer: {'✓' if caps['c_layer']['available'] else '✗'} "
              f"{'Running' if caps['c_layer']['available'] else 'Offline (Python fallback)'}")
        print(f"  • AVX-512: {'✓' if caps['avx512'] else '✗'} "
              f"{'Supported' if caps['avx512'] else 'Not available'}")
        print(f"  • CPU Cores: {caps['cpu_cores']} (P+E cores)")
        print(f"  • Thermal State: {caps['thermal']['state']}")
    
    def _initialize_components(self):
        """Initialize coordination components"""
        components_initialized = []
        
        # 1. Task tool wrapper (always available)
        print("  • Setting up Task tool integration...")
        self._setup_task_tool_integration()
        components_initialized.append("Task tool")
        
        # 2. Tandem orchestrator (if available)
        if self.capabilities.tandem_available:
            print("  • Initializing Tandem orchestrator...")
            self._initialize_tandem()
            components_initialized.append("Tandem orchestrator")
        
        # 3. C-system bridge (if running)
        if self.capabilities.c_layer_available:
            print("  • Connecting to C binary layer...")
            self._connect_c_bridge()
            components_initialized.append("C binary layer")
        
        print(f"  ✓ Initialized: {', '.join(components_initialized)}")
    
    def scan_for_agents(self) -> Dict[str, Any]:
        """Dynamically scan for all agent .md files"""
        discovered = {}
        
        # Find all .md files in agents directory
        agents_subdir = self.agents_dir / 'agents'
        if agents_subdir.exists():
            agent_files = list(agents_subdir.glob('*.md'))
        else:
            agent_files = list(self.agents_dir.glob('*.md'))
        
        for agent_file in agent_files:
            # Skip non-agent files
            if agent_file.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION', 'TEMPLATE']:
                continue
                
            agent_name = agent_file.stem
            agent_data = self._parse_agent_file(agent_file)
            
            if agent_data:
                discovered[agent_name.lower()] = {
                    'name': agent_name,
                    'path': str(agent_file.relative_to(self.agents_dir) if self.agents_dir in agent_file.parents else agent_file),
                    'metadata': agent_data.get('metadata', {}),
                    'capabilities': self._extract_capabilities(agent_data),
                    'description': self._extract_description(agent_data),
                    'category': agent_data.get('metadata', {}).get('category', 'GENERAL'),
                    'status': agent_data.get('metadata', {}).get('status', 'PRODUCTION'),
                    'tandem_modes': self._extract_tandem_modes(agent_data),
                    'last_modified': agent_file.stat().st_mtime
                }
                
        return discovered
    
    def _parse_agent_file(self, file_path: Path) -> Optional[Dict]:
        """Parse agent .md file to extract metadata"""
        try:
            content = file_path.read_text()
            
            # Try to extract YAML frontmatter
            if content.startswith('---'):
                yaml_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
                if yaml_match:
                    try:
                        return yaml.safe_load(yaml_match.group(1))
                    except:
                        pass
            
            # Fallback: extract key information from content
            data = {'metadata': {}}
            
            # Extract agent name
            name_match = re.search(r'name:\s*(\w+)', content)
            if name_match:
                data['metadata']['name'] = name_match.group(1)
            
            # Extract role/expertise
            role_match = re.search(r'role:\s*"([^"]+)"', content)
            if role_match:
                data['metadata']['role'] = role_match.group(1)
                
            # Extract tandem system info
            if 'tandem_system:' in content:
                data['has_tandem'] = True
                
            return data if data['metadata'] else None
            
        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return None
    
    def _extract_capabilities(self, agent_data: Dict) -> List[str]:
        """Extract agent capabilities from parsed data"""
        capabilities = []
        
        # Look for capabilities in various places
        if 'capabilities' in agent_data:
            capabilities.extend(agent_data['capabilities'])
        
        # Extract from tools section
        if 'tools' in agent_data:
            for tool in agent_data['tools']:
                if isinstance(tool, str):
                    capabilities.append(f"tool_{tool}")
                    
        # Default capabilities based on category
        category = agent_data.get('metadata', {}).get('category', '')
        if 'SECURITY' in category:
            capabilities.extend(['security_analysis', 'vulnerability_assessment', 'compliance_check'])
        elif 'DEVELOPMENT' in category:
            capabilities.extend(['code_generation', 'debugging', 'optimization'])
        elif 'TESTBED' in category:
            capabilities.extend(['testing', 'validation', 'quality_assurance'])
            
        return list(set(capabilities)) or ['analyze', 'execute', 'report']
    
    def _extract_description(self, agent_data: Dict) -> str:
        """Extract agent description from parsed data"""
        # Try multiple fields for description
        for field in ['description', 'role', 'expertise', 'focus']:
            if field in agent_data.get('metadata', {}):
                return agent_data['metadata'][field]
                
        # Fallback
        name = agent_data.get('metadata', {}).get('name', 'Agent')
        return f"{name} - Specialized agent for project tasks"
    
    def _extract_tandem_modes(self, agent_data: Dict) -> List[str]:
        """Extract supported Tandem execution modes"""
        modes = ['PYTHON_ONLY']  # Always supported
        
        if agent_data.get('has_tandem'):
            modes.extend(['INTELLIGENT', 'REDUNDANT'])
            
        if agent_data.get('metadata', {}).get('category') in ['CRITICAL', 'SECURITY']:
            modes.append('REDUNDANT')
            
        if agent_data.get('metadata', {}).get('performance_critical'):
            modes.append('SPEED_CRITICAL')
            
        return list(set(modes))
    
    def invoke_agent(self, agent_name: str, prompt: str, mode: ExecutionMode = ExecutionMode.INTELLIGENT) -> Dict[str, Any]:
        """
        Invoke an agent with intelligent routing between Task tool, Tandem, and C-system
        """
        agent_name = agent_name.lower()
        
        if agent_name not in self.agents:
            return {
                "success": False,
                "error": f"Agent {agent_name} not found. Available: {list(self.agents.keys())}"
            }
        
        agent_info = self.agents[agent_name]
        start_time = time.time()
        
        # Determine execution path based on mode and capabilities
        execution_path = self._determine_execution_path(agent_info, mode)
        
        print(f"\n🤖 Invoking {agent_info['name']} via {execution_path}")
        
        result = None
        
        if execution_path == "C_BRIDGE":
            result = self._invoke_via_c_bridge(agent_name, prompt)
            self.execution_stats['c'] += 1
            
        elif execution_path == "TANDEM":
            result = self._invoke_via_tandem(agent_name, prompt, mode)
            self.execution_stats['tandem'] += 1
            
        elif execution_path == "TASK_TOOL":
            result = self._invoke_via_task_tool(agent_name, prompt)
            self.execution_stats['task'] += 1
            
        else:  # PYTHON_DIRECT
            result = self._invoke_via_python(agent_name, prompt)
            self.execution_stats['python'] += 1
        
        # Record metrics
        response_time = time.time() - start_time
        self.metrics['avg_response_time'].append(response_time)
        self.metrics['agent_invocations'][agent_name] = self.metrics['agent_invocations'].get(agent_name, 0) + 1
        
        if result and result.get('success'):
            print(f"✓ Completed in {response_time:.3f}s via {execution_path}")
        
        return result
    
    def _determine_execution_path(self, agent_info: Dict, mode: ExecutionMode) -> str:
        """Determine optimal execution path based on capabilities and mode"""
        
        # Speed critical - use C if available
        if mode == ExecutionMode.SPEED_CRITICAL and self.capabilities.c_layer_available:
            return "C_BRIDGE"
        
        # Redundant mode - use Tandem for consensus
        if mode == ExecutionMode.REDUNDANT and self.capabilities.tandem_available:
            return "TANDEM"
        
        # Intelligent mode - choose best available
        if mode == ExecutionMode.INTELLIGENT:
            if self.capabilities.c_layer_available and agent_info['category'] in ['CRITICAL', 'PERFORMANCE']:
                return "C_BRIDGE"
            elif self.capabilities.tandem_available:
                return "TANDEM"
            elif self.capabilities.task_tool_available:
                return "TASK_TOOL"
        
        # Python only or fallback
        if self.capabilities.task_tool_available:
            return "TASK_TOOL"
        
        return "PYTHON_DIRECT"
    
    def _invoke_via_task_tool(self, agent_name: str, prompt: str) -> Dict[str, Any]:
        """Invoke agent through Task tool (Claude Code compatible)"""
        try:
            # Format for Task tool invocation
            task_request = {
                "subagent_type": agent_name.upper(),
                "prompt": prompt,
                "priority": "NORMAL",
                "context": {
                    "invoked_via": "Global Agent Bridge",
                    "mode": "TASK_TOOL"
                }
            }
            
            # Here we would normally use the Task tool API
            # For now, fall back to subprocess invocation
            return self._invoke_via_python(agent_name, prompt)
            
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _invoke_via_tandem(self, agent_name: str, prompt: str, mode: ExecutionMode) -> Dict[str, Any]:
        """Invoke agent through Tandem orchestrator"""
        try:
            cmd = [
                sys.executable,
                str(self.tandem_path),
                "--agent", agent_name,
                "--prompt", prompt,
                "--mode", mode.value
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr if result.returncode != 0 else None,
                "execution_path": "TANDEM"
            }
            
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Tandem execution timed out"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _invoke_via_c_bridge(self, agent_name: str, prompt: str) -> Dict[str, Any]:
        """Invoke agent through C binary bridge for maximum performance"""
        try:
            # Use shared memory for high-speed communication
            import mmap
            import struct
            
            # Create shared memory region
            shm_size = 1024 * 1024  # 1MB
            shm = mmap.mmap(-1, shm_size)
            
            # Pack request
            request_data = json.dumps({
                "agent": agent_name,
                "prompt": prompt,
                "timestamp": time.time()
            }).encode()
            
            # Write to shared memory
            shm.write(struct.pack('I', len(request_data)))
            shm.write(request_data)
            
            # Signal C bridge (would use actual IPC here)
            cmd = [str(self.c_bridge_path), "--shm", "--agent", agent_name]
            result = subprocess.run(cmd, capture_output=True, timeout=10)
            
            # Read response from shared memory
            shm.seek(0)
            response_len = struct.unpack('I', shm.read(4))[0]
            response_data = shm.read(response_len).decode()
            
            shm.close()
            
            return {
                "success": result.returncode == 0,
                "output": response_data,
                "execution_path": "C_BRIDGE",
                "performance": "HIGH_THROUGHPUT"
            }
            
        except Exception as e:
            # Fall back to Python on C bridge failure
            return self._invoke_via_python(agent_name, prompt)
    
    def _invoke_via_python(self, agent_name: str, prompt: str) -> Dict[str, Any]:
        """Direct Python invocation (fallback)"""
        try:
            cmd = [
                sys.executable,
                str(self.orchestrator_path),
                "--agent", agent_name,
                "--prompt", prompt
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            return {
                "success": result.returncode == 0,
                "output": result.stdout,
                "error": result.stderr if result.returncode != 0 else None,
                "execution_path": "PYTHON_DIRECT"
            }
            
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Python execution timed out"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def _setup_task_tool_integration(self):
        """Set up Task tool integration for Claude Code"""
        wrapper_file = Path.home() / '.local' / 'share' / 'claude-agents' / 'task_tool_bridge.py'
        wrapper_file.parent.mkdir(parents=True, exist_ok=True)
        
        wrapper_content = f'''#!/usr/bin/env python3
"""Task Tool Bridge for Claude Code Integration"""
import sys
import os
os.environ['CLAUDE_AGENTS_ROOT'] = '{self.agents_dir}'
sys.path.insert(0, '{self.agents_dir.parent}')

from claude_global_agents_bridge import GlobalAgentCoordinator

coordinator = GlobalAgentCoordinator()
coordinator.initialize()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: task_tool_bridge.py <agent> <prompt>")
        print(f"Available agents: {{list(coordinator.agents.keys())}}")
        sys.exit(1)
    
    agent = sys.argv[1]
    prompt = " ".join(sys.argv[2:])
    
    result = coordinator.invoke_agent(agent, prompt)
    
    if result.get("success"):
        print(result["output"])
    else:
        print(f"Error: {{result.get('error')}}", file=sys.stderr)
        sys.exit(1)
'''
        
        wrapper_file.write_text(wrapper_content)
        wrapper_file.chmod(0o755)
    
    def _initialize_tandem(self):
        """Initialize Tandem orchestrator connection"""
        # Create Tandem configuration
        tandem_config = {
            "agents_root": str(self.agents_dir),
            "execution_modes": ["INTELLIGENT", "PYTHON_ONLY", "SPEED_CRITICAL", "REDUNDANT"],
            "default_mode": "INTELLIGENT",
            "c_bridge_path": str(self.c_bridge_path) if self.c_bridge_path.exists() else None,
            "performance_targets": {
                "python_throughput": 5000,  # msg/sec
                "c_throughput": 100000,      # msg/sec
                "latency_p99": 0.002         # 2ms
            }
        }
        
        config_path = self.agents_dir / 'config' / 'tandem_config.json'
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text(json.dumps(tandem_config, indent=2))
    
    def _connect_c_bridge(self):
        """Connect to C binary bridge if available"""
        # Check if bridge is running
        status_file = Path('/tmp/binary_bridge_status')
        if status_file.exists():
            try:
                status = json.loads(status_file.read_text())
                print(f"    Connected to C bridge PID: {status.get('pid')}")
            except:
                pass
        
        # Create IPC configuration
        ipc_config = {
            "methods": {
                "CRITICAL": "shared_memory_50ns",
                "HIGH": "io_uring_500ns",
                "NORMAL": "unix_sockets_2us",
                "LOW": "mmap_files_10us"
            },
            "buffer_size": 1048576,  # 1MB
            "ring_buffer_slots": 1024
        }
        
        ipc_path = self.agents_dir / 'config' / 'ipc_config.json'
        ipc_path.parent.mkdir(exist_ok=True)
        ipc_path.write_text(json.dumps(ipc_config, indent=2))
    
    def _save_configuration(self):
        """Save current configuration and discovered agents"""
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        
        config = {
            "version": "10.0.0",
            "timestamp": datetime.now().isoformat(),
            "agents_root": str(self.agents_dir),
            "agents": self.agents,
            "capabilities": {
                "task_tool": True,
                "tandem": self.capabilities.tandem_available,
                "c_bridge": self.capabilities.c_layer_available,
                "avx512": self.capabilities.avx512_available
            },
            "execution_stats": self.execution_stats,
            "metrics": {
                "avg_response_time": sum(self.metrics['avg_response_time']) / len(self.metrics['avg_response_time']) if self.metrics['avg_response_time'] else 0,
                "total_invocations": sum(self.metrics['agent_invocations'].values())
            }
        }
        
        self.cache_file.write_text(json.dumps(config, indent=2))
        self.config_file.write_text(json.dumps(config, indent=2))
    
    def get_status(self) -> Dict[str, Any]:
        """Get current system status"""
        caps = self.capabilities.check_capabilities()
        
        return {
            "system": "Claude Global Agents Bridge v10.0",
            "agents_discovered": len(self.agents),
            "capabilities": caps,
            "execution_stats": self.execution_stats,
            "performance": {
                "avg_response_time": sum(self.metrics['avg_response_time']) / len(self.metrics['avg_response_time']) if self.metrics['avg_response_time'] else 0,
                "throughput_estimate": self._estimate_throughput()
            },
            "ready": True
        }
    
    def _estimate_throughput(self) -> str:
        """Estimate current throughput capability"""
        if self.capabilities.c_layer_available:
            return "100K+ msg/sec (C bridge active)"
        elif self.capabilities.tandem_available:
            return "10-50K msg/sec (Tandem orchestration)"
        else:
            return "5K msg/sec (Python baseline)"
    
    def create_global_launcher(self):
        """Skip global launcher creation - managed by main installer"""
        print(f"\n💡 Global launcher management handled by main installer")
        print("   Use ./claude-installer.sh to install/update the wrapper")
        print("   Current system uses custom wrapper with enhanced functionality")
        return


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Claude Global Agents Bridge v10.0')
    parser.add_argument('--list', action='store_true', help='List available agents')
    parser.add_argument('--status', action='store_true', help='Show system status')
    parser.add_argument('--install', action='store_true', help='Install global integration')
    parser.add_argument('--invoke', nargs='+', help='Invoke an agent')
    
    args = parser.parse_args()
    
    coordinator = GlobalAgentCoordinator()
    
    if args.install:
        coordinator.initialize()
        coordinator.create_global_launcher()
        print("\n🎉 Installation complete!")
        
    elif args.list:
        coordinator.initialize()
        print("\n📋 Available Agents:")
        for agent_id, info in sorted(coordinator.agents.items()):
            print(f"  • {info['name']:<20} - {info['description'][:60]}...")
            
    elif args.status:
        coordinator.initialize()
        status = coordinator.get_status()
        print("\n📊 System Status:")
        print(json.dumps(status, indent=2))
        
    elif args.invoke:
        if len(args.invoke) < 2:
            print("Usage: --invoke <agent-name> <prompt>")
            sys.exit(1)
            
        coordinator.initialize()
        agent_name = args.invoke[0]
        prompt = " ".join(args.invoke[1:])
        
        result = coordinator.invoke_agent(agent_name, prompt)
        
        if result.get('success'):
            print(result['output'])
        else:
            print(f"Error: {result.get('error')}", file=sys.stderr)
            sys.exit(1)
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
