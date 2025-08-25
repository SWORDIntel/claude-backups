#!/usr/bin/env python3
"""
Claude Global Agents Bridge v10.0 - Enhanced Registration System
Unified coordination between Task tool, Tandem orchestrator, and C-system
Provides seamless agent discovery, invocation, and performance optimization

FIXED VERSION: No absolute paths - uses relative paths and environment variables
"""

import os
import sys
import json
import yaml
import time
import psutil
import hashlib
import threading
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
from enum import Enum
import glob
import re

# ==============================================================================
# PATH CONFIGURATION - No absolute paths!
# ==============================================================================

def get_project_root() -> Path:
    """
    Find the project root by looking for key directories and files.
    Searches upward from current location or script location.
    """
    # Start from script location
    search_start = Path(__file__).resolve().parent
    
    # Also check current working directory
    cwd = Path.cwd()
    
    # Look for project markers
    markers = [
        'agents',  # agents directory
        'README.md',  # Root readme
        'src',  # Source directory
        '.git',  # Git repository
        'binary-communications-system',  # Binary system directory
    ]
    
    # Search from script location upward
    current = search_start
    for _ in range(5):  # Max 5 levels up
        # Check if this looks like project root
        found_markers = sum(1 for marker in markers if (current / marker).exists())
        if found_markers >= 2:  # At least 2 markers found
            return current
        
        # Check if agents dir exists here
        if (current / 'agents').exists() and (current / 'agents').is_dir():
            return current
            
        parent = current.parent
        if parent == current:  # Reached filesystem root
            break
        current = parent
    
    # Try from cwd
    current = cwd
    for _ in range(5):
        found_markers = sum(1 for marker in markers if (current / marker).exists())
        if found_markers >= 2:
            return current
        
        if (current / 'agents').exists() and (current / 'agents').is_dir():
            return current
            
        parent = current.parent
        if parent == current:
            break
        current = parent
    
    # Default to current directory if nothing found
    print("⚠️ Could not auto-detect project root, using current directory")
    return cwd


def get_agents_directory() -> Path:
    """Get the agents directory path from environment or auto-detect."""
    # 1. Check environment variable
    if os.environ.get('CLAUDE_AGENTS_ROOT'):
        agents_dir = Path(os.environ['CLAUDE_AGENTS_ROOT'])
        if agents_dir.exists():
            return agents_dir
    
    # 2. Check common relative paths
    project_root = get_project_root()
    
    # Common paths to check
    possible_paths = [
        project_root / 'agents',
        project_root / 'claude-backups' / 'agents',
        project_root / 'Documents' / 'claude-backups' / 'agents',
        project_root / 'Documents' / 'Claude' / 'agents',
    ]
    
    for path in possible_paths:
        if path.exists() and path.is_dir():
            return path
    
    # 3. Ask user if we can't find it
    print("⚠️ Could not find agents directory automatically")
    print("Please set CLAUDE_AGENTS_ROOT environment variable or ensure agents/ exists")
    
    # Default to expected location
    default_path = project_root / 'agents'
    print(f"Using default: {default_path}")
    return default_path


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
            # Check for actual C binary processes (not Python scripts with similar names)
            result = subprocess.run(['ps', 'auxww'], capture_output=True, text=True)
            # Look for actual binary processes, not Python scripts
            lines = result.stdout.split('\n')
            c_processes = [line for line in lines if ('agent_bridge' in line or 'ultra_hybrid' in line) and 'python' not in line]
            c_available = len(c_processes) > 0
            
            # Check for compiled binary file (relative path)
            agents_dir = get_agents_directory()
            binary_path = agents_dir / "binary-communications-system" / "ultra_hybrid_enhanced"
            binary_exists = binary_path.exists() and binary_path.is_file() and not str(binary_path).endswith('.c')
            
            # C bridge should only be available if we have AVX-512 support
            avx512_available = self._check_avx512()
            
            return {
                'available': c_available and avx512_available,
                'process_running': c_available,
                'binary_exists': binary_exists,
                'avx512_required': not avx512_available,
                'status_file': Path('/tmp/binary_bridge_status').exists()
            }
        except:
            return {'available': False, 'error': 'Check failed'}
    
    def _check_tandem(self) -> Dict[str, Any]:
        """Check if Tandem orchestrator is available"""
        agents_dir = get_agents_directory()
        tandem_path = agents_dir / "src" / "python" / "production_orchestrator.py"
        orchestrator_path = agents_dir / "src" / "python" / "production_orchestrator.py"
        
        return {
            'available': tandem_path.exists() and orchestrator_path.exists(),
            'tandem_path': str(tandem_path) if tandem_path.exists() else None,
            'orchestrator_path': str(orchestrator_path) if orchestrator_path.exists() else None
        }
    
    def _check_avx512(self) -> bool:
        """Check for AVX-512 support via microcode version"""
        try:
            # Check microcode version - AVX-512 available if microcode < 0x20
            cpuinfo = Path('/proc/cpuinfo').read_text()
            
            # Look for microcode line
            for line in cpuinfo.split('\n'):
                if 'microcode' in line.lower():
                    # Extract microcode value
                    # Format is usually "microcode : 0x1a" or similar
                    parts = line.split(':')
                    if len(parts) >= 2:
                        microcode_str = parts[1].strip()
                        
                        # Parse hex value
                        if microcode_str.startswith('0x'):
                            microcode_val = int(microcode_str, 16)
                        else:
                            microcode_val = int(microcode_str)
                        
                        # AVX-512 is supported if microcode < 0x20 (32 decimal)
                        return microcode_val < 0x20
            
            # If no microcode found, check alternative method
            # Some systems report it differently
            try:
                with open('/sys/devices/system/cpu/cpu0/microcode/version', 'r') as f:
                    microcode_val = int(f.read().strip(), 16)
                    return microcode_val < 0x20
            except:
                pass
            
            # Fallback: assume no AVX-512 if we can't determine microcode
            return False
            
        except Exception as e:
            print(f"  ⚠️ Could not check AVX-512 support: {e}")
            return False
    
    def _check_thermal(self) -> Dict[str, Any]:
        """Check thermal state of system"""
        try:
            temps = psutil.sensors_temperatures()
            if temps:
                max_temp = max([t.current for sensors in temps.values() for t in sensors])
                state = "HOT" if max_temp > 80 else "WARM" if max_temp > 60 else "NORMAL"
            else:
                state = "UNKNOWN"
            
            return {'state': state, 'sensors_available': bool(temps)}
        except:
            return {'state': 'UNKNOWN', 'sensors_available': False}


class GlobalAgentCoordinator:
    """
    Global coordination system for all agents
    Manages discovery, routing, and execution across multiple layers
    """
    
    def __init__(self):
        # Base paths - use relative paths
        self.agents_dir = get_agents_directory()
        self.project_root = get_project_root()
        
        # Configuration directories
        self.claude_config_dir = Path.home() / ".config" / "claude"
        self.claude_config_dir.mkdir(parents=True, exist_ok=True)
        
        # Cache and configuration
        self.cache_dir = Path.home() / '.cache' / 'claude-agents'
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.cache_file = self.cache_dir / 'agent_cache.json'
        self.config_file = self.cache_dir / 'coordination_config.json'
        
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
        
        # Monitoring
        self.monitoring = False
        self.monitor_thread = None
        
    def initialize(self):
        """Initialize the coordination system"""
        print("🚀 Initializing Claude Global Agents Bridge v10.0")
        print("=" * 60)
        
        # Display detected paths
        print(f"📁 Project root: {self.project_root}")
        print(f"📁 Agents directory: {self.agents_dir}")
        
        # Set environment variable
        os.environ['CLAUDE_AGENTS_ROOT'] = str(self.agents_dir)
        
        # Check system capabilities
        print("\n🔍 Checking system capabilities...")
        caps = self.capabilities.check_capabilities()
        self._display_capabilities(caps)
        
        # Discover agents
        print("\n📡 Discovering agents...")
        self.agents = self.scan_for_agents()
        print(f"✔ Found {len(self.agents)} agents")
        
        # Initialize components
        print("\n🔧 Initializing components...")
        self._initialize_components()
        
        # Save configuration
        self._save_configuration()
        
        print("\n✅ Coordination system ready!")
        return True
    
    def _display_capabilities(self, caps: Dict[str, Any]):
        """Display system capabilities"""
        print(f"  • Task Tool: ✔ Available (Primary interface)")
        print(f"  • Tandem Orchestrator: {'✔' if caps['tandem']['available'] else '✗'} "
              f"{'Available' if caps['tandem']['available'] else 'Not found'}")
        print(f"  • C Binary Layer: {'✔' if caps['c_layer']['available'] else '✗'} "
              f"{'Running' if caps['c_layer']['available'] else 'Offline (Python fallback)'}")
        print(f"  • AVX-512: {'✔' if caps['avx512'] else '✗'} "
              f"{'Supported (microcode < 0x20)' if caps['avx512'] else 'Not available (microcode >= 0x20)'}")
        print(f"  • CPU Cores: {caps['cpu_cores']} (P+E cores)")
        print(f"  • Thermal State: {caps['thermal']['state']}")
    
    def _initialize_components(self):
        """Initialize coordination components"""
        components_initialized = []
        
        # 1. Task tool wrapper
        print("  • Setting up Task tool integration...")
        self._setup_task_tool_integration()
        components_initialized.append("Task tool")
        
        # 2. Tandem orchestrator
        if self.capabilities.tandem_available:
            print("  • Initializing Tandem orchestrator...")
            self._initialize_tandem()
            components_initialized.append("Tandem")
        
        # 3. C binary bridge
        if self.capabilities.c_layer_available:
            print("  • Connecting to C binary bridge...")
            self._connect_c_bridge()
            components_initialized.append("C bridge")
        
        # 4. Create unified launcher
        print("  • Creating global launcher...")
        self._create_global_launcher()
        
        print(f"\n  ✔ Initialized: {', '.join(components_initialized)}")
    
    def scan_for_agents(self) -> Dict[str, Any]:
        """Scan all agent .md files and extract metadata"""
        agents = {}
        
        # Only scan .md files in the agents/ root directory
        for agent_file in self.agents_dir.glob("*.md"):
            if agent_file.stem in ['README', 'Template', 'TEMPLATE', 'WHERE_I_AM', 'STATUSLINE_INTEGRATION']:
                continue
                
            agent_name = agent_file.stem  # Keep original case (DOCGEN, DIRECTOR, etc.)
            agent_data = self._parse_agent_file(agent_file)
            
            if agent_data:
                agent_info = {
                    'name': agent_file.stem,
                    'file': str(agent_file),
                    'metadata': agent_data,
                    'tools': self._extract_tools(agent_data),
                    'description': self._extract_description(agent_data),
                    'execution_modes': self._extract_execution_modes(agent_data),
                    'priority': self._extract_priority(agent_data)
                }
                
                # Store with both original case and lowercase for compatibility
                agents[agent_name] = agent_info
                if agent_name.lower() != agent_name:
                    agents[agent_name.lower()] = agent_info
                    
        return agents
    
    def _parse_agent_file(self, file_path: Path) -> Dict:
        """Parse agent .md file to extract YAML frontmatter"""
        try:
            content = file_path.read_text()
            
            if content.startswith('---'):
                yaml_end = content.find('---', 3)
                if yaml_end > 0:
                    yaml_content = content[3:yaml_end]
                    return yaml.safe_load(yaml_content)
        except Exception as e:
            print(f"  ⚠ Error parsing {file_path.name}: {e}")
            
        return None
    
    def _extract_tools(self, agent_data: Dict) -> List[str]:
        """Extract tools from agent data"""
        tools = agent_data.get('tools', [])
        return [tool for tool in tools if tool != 'Task'] if tools else ['*']
    
    def _extract_description(self, agent_data: Dict) -> str:
        """Extract description from agent data"""
        metadata = agent_data.get('metadata', {})
        
        for field in ['role', 'expertise', 'focus', 'description']:
            if field in metadata:
                return metadata[field]
                
        return "Specialized project agent"
    
    def _extract_execution_modes(self, agent_data: Dict) -> List[str]:
        """Extract supported execution modes"""
        modes = ['PYTHON_ONLY']  # Always supported
        
        # Check for tandem support
        if 'tandem_system' in str(agent_data):
            modes.extend(['INTELLIGENT', 'REDUNDANT'])
        
        # Check for performance critical
        if agent_data.get('metadata', {}).get('performance_critical'):
            modes.append('SPEED_CRITICAL')
        
        return list(set(modes))
    
    def _extract_priority(self, agent_data: Dict) -> str:
        """Extract agent priority"""
        metadata = agent_data.get('metadata', {})
        
        if metadata.get('category') in ['CRITICAL', 'SECURITY']:
            return 'HIGH'
        elif metadata.get('category') in ['ORCHESTRATION', 'MANAGEMENT']:
            return 'MEDIUM'
        else:
            return 'NORMAL'
    
    def _setup_task_tool_integration(self):
        """Set up Task tool integration for Claude Code"""
        # Create Task tool extension
        extension = self._create_task_extension()
        extension_file = self.claude_config_dir / "task_extension.py"
        extension_file.write_text(extension)
        extension_file.chmod(0o755)
        
        # Create Task tool bridge wrapper
        wrapper_file = Path.home() / '.local' / 'share' / 'claude-agents' / 'task_tool_bridge.py'
        wrapper_file.parent.mkdir(parents=True, exist_ok=True)
        
        wrapper_content = f'''#!/usr/bin/env python3
"""Task Tool Bridge for Claude Code Integration"""
import sys
import os
import json
from pathlib import Path

# Auto-detect agents root
def find_agents_root():
    # Check environment first
    if os.environ.get('CLAUDE_AGENTS_ROOT'):
        return Path(os.environ['CLAUDE_AGENTS_ROOT'])
    
    # Search from script location
    current = Path(__file__).resolve().parent
    for _ in range(5):
        if (current / 'agents').exists():
            return current / 'agents'
        current = current.parent
        if current == current.parent:
            break
    
    # Default
    return Path.home() / 'Documents' / 'claude-backups' / 'agents'

AGENTS_ROOT = find_agents_root()
os.environ['CLAUDE_AGENTS_ROOT'] = str(AGENTS_ROOT)
sys.path.insert(0, str(AGENTS_ROOT.parent))

from register_custom_agents_v10 import GlobalAgentCoordinator, ExecutionMode

coordinator = GlobalAgentCoordinator()
coordinator.initialize()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: task_tool_bridge.py <agent> <prompt>")
        print(f"Available agents: {{list(coordinator.agents.keys())}}")
        sys.exit(1)
    
    agent = sys.argv[1]
    prompt = " ".join(sys.argv[2:])
    
    # Determine execution mode based on complexity
    mode = ExecutionMode.INTELLIGENT  # Default
    
    result = coordinator.invoke_agent(agent, prompt, mode)
    
    if result.get("success"):
        print(result["output"])
    else:
        print(f"Error: {{result.get('error')}}", file=sys.stderr)
        sys.exit(1)
'''
        wrapper_file.write_text(wrapper_content)
        wrapper_file.chmod(0o755)
