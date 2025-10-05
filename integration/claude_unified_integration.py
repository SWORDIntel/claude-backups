#!/usr/bin/env python3
"""
UNIFIED CLAUDE CODE INTEGRATION SYSTEM v1.0
Multi-Agent Coordination: DIRECTOR, PROJECTORCHESTRATOR, ARCHITECT, CONSTRUCTOR

Comprehensive integration system that bypasses Claude Code Task tool limitations
through multi-layer integration approach:
- Environment detection and agent capability injection
- Hook-based integration for pre/post task actions  
- Command interception and intelligent routing
- Unified agent bridge with orchestration support

Integrates all existing components:
- Hook Adapter (hooks/claude_code_hook_adapter.py)
- Code Integration (agents/src/python/claude_code_integration.py)
- Agent Registry (agents/src/python/agent_registry.py)
- Production Orchestrator (agents/src/python/production_orchestrator.py)
"""

import os
import sys
import json
import time
import asyncio
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Callable, Set
from dataclasses import dataclass, field
from enum import Enum
import threading
from collections import defaultdict
import re
import importlib.util

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ============================================================================
# UNIFIED INTEGRATION CONSTANTS
# ============================================================================

class IntegrationLayer(Enum):
    """Integration layers in order of priority"""
    ENVIRONMENT = "environment"     # Environmental injection  
    HOOKS = "hooks"                # Claude Code hooks
    COMMAND = "command"            # Command interception
    BRIDGE = "bridge"              # Agent bridge
    ORCHESTRATION = "orchestration" # Full orchestration

class AgentInvocationMethod(Enum):
    """Methods for invoking agents"""
    CLAUDE_AGENT_COMMAND = "claude_agent_command"  # External claude-agent command
    PYTHON_DIRECT = "python_direct"                # Direct Python import
    ORCHESTRATOR = "orchestrator"                  # Through orchestrator  
    HOOK_TRIGGER = "hook_trigger"                  # Through hooks

# ============================================================================
# DYNAMIC PROJECT ROOT DETECTION
# ============================================================================

def find_project_root() -> Path:
    """Dynamically find project root - no hardcoded paths"""
    current = Path.cwd()
    markers = ['.claude', 'agents', 'CLAUDE.md', '.git', 'claude-wrapper-ultimate.sh']
    
    while current != current.parent:
        for marker in markers:
            if (current / marker).exists():
                return current
        current = current.parent
    
    return Path.cwd()

PROJECT_ROOT = find_project_root()
AGENTS_DIR = PROJECT_ROOT / 'agents'

# Add project paths dynamically
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(AGENTS_DIR))
sys.path.insert(0, str(AGENTS_DIR / 'src' / 'python'))

# ============================================================================
# UNIFIED AGENT REGISTRY
# ============================================================================

@dataclass
class UnifiedAgentMetadata:
    """Unified agent metadata from all sources"""
    name: str
    category: str
    description: str
    uuid: str = ""
    priority: str = "MEDIUM"
    status: str = "PRODUCTION"
    tools: List[str] = field(default_factory=list)
    command: str = ""
    invocation_methods: List[AgentInvocationMethod] = field(default_factory=list)
    python_impl_path: Optional[str] = None
    file_path: Optional[str] = None
    proactive_triggers: List[str] = field(default_factory=list)
    performance_metrics: Dict[str, Any] = field(default_factory=dict)

class UnifiedAgentRegistry:
    """Unified registry combining all agent sources"""
    
    def __init__(self, project_root: Optional[Path] = None, agents_dir: Optional[Path] = None):
        self.agents: Dict[str, UnifiedAgentMetadata] = {}
        self.project_root = project_root or PROJECT_ROOT
        self.agents_dir = agents_dir or AGENTS_DIR
        self._load_all_agents()
    
    def _load_all_agents(self):
        """Load agents from all sources"""
        logger.info(f"Loading agents from {self.agents_dir}")
        
        # Load from .md files
        self._load_from_md_files()
        
        # Load from existing integration
        self._load_from_claude_code_integration()
        
        # Load from Python implementations
        self._load_python_implementations()
        
        # Update invocation methods
        self._update_invocation_methods()
        
        logger.info(f"Loaded {len(self.agents)} unified agents")
    
    def _load_from_md_files(self):
        """Load agents from .md agent files"""
        if not self.agents_dir.exists():
            logger.warning(f"Agents directory not found: {self.agents_dir}")
            return
        
        for md_file in self.agents_dir.glob("*.md"):
            if md_file.name.upper() in ['TEMPLATE.MD', 'README.MD', 'WHERE_I_AM.MD']:
                continue
                
            try:
                content = md_file.read_text(encoding='utf-8')
                agent_name = md_file.stem.upper()
                
                # Extract YAML frontmatter
                if content.startswith('---\n'):
                    end_idx = content.find('\n---\n', 4)
                    if end_idx != -1:
                        yaml_content = content[4:end_idx]
                        
                        # Parse basic metadata
                        metadata = self._parse_yaml_metadata(yaml_content)
                        
                        # Extract description from markdown content
                        description = self._extract_description(content[end_idx+5:])
                        
                        agent = UnifiedAgentMetadata(
                            name=agent_name,
                            category=metadata.get('category', 'GENERAL'),
                            description=description or metadata.get('description', ''),
                            uuid=metadata.get('uuid', ''),
                            priority=metadata.get('priority', 'MEDIUM'),
                            status=metadata.get('status', 'PRODUCTION'),
                            tools=metadata.get('tools', []),
                            file_path=str(md_file),
                            proactive_triggers=metadata.get('proactive_triggers', [])
                        )
                        
                        self.agents[agent_name.lower()] = agent
                        
            except Exception as e:
                logger.warning(f"Failed to parse {md_file}: {e}")
    
    def _load_from_claude_code_integration(self):
        """Load agents from existing claude_code_integration.py"""
        try:
            integration_file = self.agents_dir / 'src' / 'python' / 'claude_code_integration.py'
            if not integration_file.exists():
                return
                
            # Import the PROJECT_AGENTS dictionary
            spec = importlib.util.spec_from_file_location("claude_code_integration", integration_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            if hasattr(module, 'PROJECT_AGENTS'):
                for agent_id, agent_info in module.PROJECT_AGENTS.items():
                    agent_name = agent_id.lower()
                    
                    if agent_name in self.agents:
                        # Update existing agent with command info
                        self.agents[agent_name].command = agent_info.get('command', '')
                    else:
                        # Create new agent
                        self.agents[agent_name] = UnifiedAgentMetadata(
                            name=agent_info.get('name', agent_id.upper()),
                            category='EXTERNAL',
                            description=agent_info.get('description', ''),
                            command=agent_info.get('command', ''),
                            tools=agent_info.get('tools', [])
                        )
                        
        except Exception as e:
            logger.warning(f"Failed to load claude_code_integration: {e}")
    
    def _load_python_implementations(self):
        """Load Python implementation paths"""
        python_dir = self.agents_dir / 'src' / 'python'
        if not python_dir.exists():
            return
            
        for py_file in python_dir.glob("*_impl.py"):
            agent_name = py_file.stem.replace('_impl', '').lower()
            if agent_name in self.agents:
                self.agents[agent_name].python_impl_path = str(py_file)
    
    def _update_invocation_methods(self):
        """Update invocation methods for each agent"""
        for agent in self.agents.values():
            methods = []
            
            # Check for claude-agent command
            if agent.command and 'claude-agent' in agent.command:
                methods.append(AgentInvocationMethod.CLAUDE_AGENT_COMMAND)
            
            # Check for Python implementation
            if agent.python_impl_path:
                methods.append(AgentInvocationMethod.PYTHON_DIRECT)
            
            # All agents can use orchestrator if available
            methods.append(AgentInvocationMethod.ORCHESTRATOR)
            
            # All agents can be triggered through hooks
            methods.append(AgentInvocationMethod.HOOK_TRIGGER)
            
            agent.invocation_methods = methods
    
    def _parse_yaml_metadata(self, yaml_content: str) -> Dict[str, Any]:
        """Parse YAML metadata (simplified parser)"""
        metadata = {}
        lines = yaml_content.split('\n')
        current_key = None
        current_list = None
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            if ':' in line and not line.startswith('-'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()
                
                if key == 'metadata':
                    continue
                elif key in ['tools', 'proactive_triggers']:
                    current_key = key
                    current_list = []
                    metadata[key] = current_list
                else:
                    metadata[key] = value.strip('"\'')
                    current_key = None
                    current_list = None
            elif line.startswith('-') and current_list is not None:
                item = line[1:].strip().strip('"\'')
                current_list.append(item)
        
        return metadata
    
    def _extract_description(self, content: str) -> str:
        """Extract description from markdown content"""
        lines = content.split('\n')
        description_lines = []
        
        for line in lines:
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('```'):
                description_lines.append(line)
            elif description_lines:  # Stop at first empty line after content
                break
        
        return ' '.join(description_lines)[:500]  # Limit to 500 chars
    
    def get_agent(self, name: str) -> Optional[UnifiedAgentMetadata]:
        """Get agent by name (case insensitive)"""
        return self.agents.get(name.lower())
    
    def list_agents(self) -> List[str]:
        """List all available agents"""
        return sorted(self.agents.keys())
    
    def get_agents_by_category(self, category: str) -> List[UnifiedAgentMetadata]:
        """Get agents by category"""
        return [agent for agent in self.agents.values() if agent.category.upper() == category.upper()]
    
    def find_agents_by_pattern(self, pattern: str) -> List[str]:
        """Find agents matching a pattern in name or description"""
        pattern = pattern.lower()
        matches = []
        
        for name, agent in self.agents.items():
            if (pattern in name.lower() or 
                pattern in agent.description.lower() or
                any(pattern in trigger.lower() for trigger in agent.proactive_triggers)):
                matches.append(name)
        
        return matches

# ============================================================================
# CLAUDE CODE ENVIRONMENT DETECTOR
# ============================================================================

class ClaudeCodeEnvironmentDetector:
    """Detects if running in Claude Code environment and injects capabilities"""
    
    def __init__(self):
        self.is_claude_code = self._detect_claude_code()
        self.context = self._extract_context()
    
    def _detect_claude_code(self) -> bool:
        """Detect if running in Claude Code environment"""
        indicators = [
            'CLAUDE_TASK_ID' in os.environ,
            'CLAUDE_AGENT_NAME' in os.environ,
            'CLAUDE_CONTEXT_FILE' in os.environ,
            any('claude' in env.lower() for env in os.environ.keys()),
            Path.cwd().name == 'claude-backups'  # Common project name
        ]
        
        return any(indicators)
    
    def _extract_context(self) -> Dict[str, Any]:
        """Extract Claude Code context from environment"""
        context = {
            'timestamp': time.time(),
            'cwd': str(Path.cwd()),
            'project_root': str(PROJECT_ROOT)
        }
        
        # Extract Claude-specific environment variables
        claude_vars = [
            'CLAUDE_TASK_ID', 'CLAUDE_AGENT_NAME', 'CLAUDE_TASK_CONTEXT',
            'CLAUDE_EDITED_FILES', 'CLAUDE_CURRENT_FILE', 'CLAUDE_HOOK_PHASE'
        ]
        
        for var in claude_vars:
            if var in os.environ:
                context[var.lower()] = os.environ[var]
        
        return context
    
    def inject_agent_capabilities(self):
        """Inject agent capabilities into environment"""
        if not self.is_claude_code:
            return
        
        # Set environment variables for agent access
        os.environ['CLAUDE_AGENTS_AVAILABLE'] = 'true'
        os.environ['CLAUDE_AGENTS_ROOT'] = str(PROJECT_ROOT / 'agents')
        os.environ['CLAUDE_UNIFIED_INTEGRATION'] = 'active'
        
        logger.info("Injected agent capabilities into Claude Code environment")

# ============================================================================
# UNIFIED HOOK SYSTEM
# ============================================================================

class UnifiedHookSystem:
    """Unified hook system combining existing hook adapter functionality"""
    
    def __init__(self, registry: UnifiedAgentRegistry):
        self.registry = registry
        self.context = {}
        self.hook_dir = Path.home() / '.claude' / 'hooks'
    
    def setup_hooks(self):
        """Setup Claude Code hooks"""
        self.hook_dir.mkdir(parents=True, exist_ok=True)
        
        # Create hook wrapper script
        wrapper_script = self.hook_dir / 'unified_hook_wrapper.sh'
        wrapper_content = f'''#!/bin/bash
# Unified Claude Code Hook Wrapper
HOOK_PHASE="$1"
CONTEXT_FILE="$2"

export CLAUDE_HOOK_PHASE="$HOOK_PHASE"
export CLAUDE_CONTEXT_FILE="$CONTEXT_FILE"

# Call unified Python hook system
python3 "{__file__}" --trigger "$HOOK_PHASE"
'''
        wrapper_script.write_text(wrapper_content)
        wrapper_script.chmod(0o755)
        
        # Create .claude-hooks configuration
        claude_hooks_file = Path.home() / '.claude-hooks'
        hooks_config = {
            "version": "1.0",
            "provider": "claude-unified-integration",
            "hooks": {
                "pre-task": f"{wrapper_script} pre-task",
                "post-edit": f"{wrapper_script} post-edit", 
                "post-task": f"{wrapper_script} post-task"
            }
        }
        
        with open(claude_hooks_file, 'w') as f:
            json.dump(hooks_config, f, indent=2)
        
        logger.info(f"Setup unified hooks: {claude_hooks_file}")
    
    def trigger_hook(self, phase: str) -> Dict[str, Any]:
        """Trigger a hook phase with unified agent selection"""
        result = {
            'phase': phase,
            'success': True,
            'timestamp': time.time(),
            'agents_triggered': []
        }
        
        if phase == 'pre-task':
            result['actions'] = self._handle_pre_task()
        elif phase == 'post-edit':
            result['actions'] = self._handle_post_edit()
        elif phase == 'post-task':
            result['actions'] = self._handle_post_task()
        
        return result
    
    def _handle_pre_task(self) -> List[Dict[str, Any]]:
        """Handle pre-task phase - select appropriate agents"""
        actions = []
        
        # Extract task context
        task_context = os.environ.get('CLAUDE_TASK_CONTEXT', '')
        
        # Select agents using improved pattern matching
        selected_agents = self._select_agents_for_task(task_context)
        
        actions.append({
            'type': 'agent_selection',
            'status': 'success',
            'agents': selected_agents,
            'context': task_context
        })
        
        return actions
    
    def _handle_post_edit(self) -> List[Dict[str, Any]]:
        """Handle post-edit phase - validation and enhancement"""
        actions = []
        
        edited_files = os.environ.get('CLAUDE_EDITED_FILES', '').split(',')
        edited_files = [f.strip() for f in edited_files if f.strip()]
        
        if edited_files:
            # Run validation with appropriate agents
            if self._is_agent_available('linter'):
                actions.append({
                    'type': 'validation',
                    'agent': 'linter',
                    'files': edited_files,
                    'status': 'triggered'
                })
        
        return actions
    
    def _handle_post_task(self) -> List[Dict[str, Any]]:
        """Handle post-task phase - cleanup and learning"""
        actions = []
        
        actions.append({
            'type': 'learning_update',
            'status': 'success',
            'task_completed': True
        })
        
        return actions
    
    def _select_agents_for_task(self, task_context: str) -> List[str]:
        """Enhanced agent selection using unified registry"""
        if not task_context:
            return ['director']
        
        # Use registry's pattern matching
        matched_agents = self.registry.find_agents_by_pattern(task_context)
        
        if not matched_agents:
            # Fallback to basic pattern matching
            patterns = {
                'debug': ['debugger', 'linter'],
                'test': ['testbed', 'qadirector'],
                'security': ['security', 'securityauditor'],
                'deploy': ['deployer', 'infrastructure'],
                'api': ['apidesigner'],
                'database': ['database'],
                'documentation': ['docgen'],
                'plan': ['planner', 'director']
            }
            
            task_lower = task_context.lower()
            selected = []
            
            for pattern, agents in patterns.items():
                if pattern in task_lower:
                    selected.extend(agents)
            
            return list(set(selected)) if selected else ['director']
        
        return matched_agents[:3]  # Limit to top 3 matches
    
    def _is_agent_available(self, agent_name: str) -> bool:
        """Check if agent is available in unified registry"""
        return self.registry.get_agent(agent_name) is not None

# ============================================================================
# AGENT INVOCATION ENGINE
# ============================================================================

class UnifiedAgentInvoker:
    """Unified agent invocation engine supporting multiple methods"""
    
    def __init__(self, registry: UnifiedAgentRegistry):
        self.registry = registry
        self.orchestrator = None
        self._load_orchestrator()
    
    def _load_orchestrator(self):
        """Load production orchestrator if available"""
        try:
            orchestrator_file = AGENTS_DIR / 'src' / 'python' / 'production_orchestrator.py'
            if orchestrator_file.exists():
                spec = importlib.util.spec_from_file_location("production_orchestrator", orchestrator_file)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                # Try to get orchestrator class
                if hasattr(module, 'ProductionOrchestrator'):
                    self.orchestrator = module.ProductionOrchestrator()
                    logger.info("Loaded production orchestrator")
        except Exception as e:
            logger.warning(f"Failed to load orchestrator: {e}")
    
    def invoke_agent(self, agent_name: str, prompt: str, method: Optional[AgentInvocationMethod] = None) -> Dict[str, Any]:
        """Invoke agent using best available method"""
        agent = self.registry.get_agent(agent_name)
        if not agent:
            return {
                'error': f"Agent '{agent_name}' not found",
                'available': self.registry.list_agents()[:10]
            }
        
        # Select best invocation method
        if method is None:
            method = self._select_best_method(agent)
        
        try:
            if method == AgentInvocationMethod.CLAUDE_AGENT_COMMAND:
                return self._invoke_via_command(agent, prompt)
            elif method == AgentInvocationMethod.PYTHON_DIRECT:
                return self._invoke_via_python(agent, prompt)
            elif method == AgentInvocationMethod.ORCHESTRATOR:
                return self._invoke_via_orchestrator(agent, prompt)
            else:
                return self._invoke_via_fallback(agent, prompt)
                
        except Exception as e:
            return {
                'error': f"Failed to invoke {agent_name}: {str(e)}",
                'agent': agent.name,
                'method': method.value
            }
    
    def _select_best_method(self, agent: UnifiedAgentMetadata) -> AgentInvocationMethod:
        """Select best invocation method for agent"""
        methods = agent.invocation_methods
        
        # Priority order
        if AgentInvocationMethod.ORCHESTRATOR in methods and self.orchestrator:
            return AgentInvocationMethod.ORCHESTRATOR
        elif AgentInvocationMethod.CLAUDE_AGENT_COMMAND in methods:
            return AgentInvocationMethod.CLAUDE_AGENT_COMMAND
        elif AgentInvocationMethod.PYTHON_DIRECT in methods:
            return AgentInvocationMethod.PYTHON_DIRECT
        else:
            return AgentInvocationMethod.HOOK_TRIGGER
    
    def _invoke_via_command(self, agent: UnifiedAgentMetadata, prompt: str) -> Dict[str, Any]:
        """Invoke via claude-agent command"""
        if not agent.command:
            raise ValueError("No command available")
        
        # Prepare environment
        env = os.environ.copy()
        env['CLAUDE_AGENTS_ROOT'] = str(AGENTS_DIR)
        
        # Execute command
        cmd = agent.command.split() + [prompt]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,
            env=env,
            cwd=str(PROJECT_ROOT)
        )
        
        return {
            'success': result.returncode == 0,
            'output': result.stdout.strip(),
            'error': result.stderr.strip() if result.returncode != 0 else None,
            'agent': agent.name,
            'method': 'command',
            'returncode': result.returncode
        }
    
    def _invoke_via_python(self, agent: UnifiedAgentMetadata, prompt: str) -> Dict[str, Any]:
        """Invoke via Python implementation"""
        if not agent.python_impl_path:
            raise ValueError("No Python implementation available")

        try:
            command_data = json.loads(prompt)
            command = command_data.get('command')
            params = command_data.get('params', {})
            if not command:
                raise ValueError("JSON prompt must have a 'command' key")
        except (json.JSONDecodeError, ValueError):
            command = prompt
            params = {}

        try:
            spec = importlib.util.spec_from_file_location(agent.name, agent.python_impl_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            class_name = f"{agent.name}PythonExecutor"
            AgentClass = getattr(module, class_name, None)

            if not AgentClass:
                # Fallback for different capitalization, e.g. "Constructor" -> "CONSTRUCTOR"
                class_name_upper = f"{agent.name.upper()}PythonExecutor"
                if hasattr(module, class_name_upper):
                    AgentClass = getattr(module, class_name_upper)
                else:
                    raise ImportError(f"Could not find {class_name} or {class_name_upper} in {agent.python_impl_path}")

            instance = AgentClass()

            if not hasattr(instance, 'execute_command'):
                raise NotImplementedError(f"'execute_command' not found in {AgentClass.__name__}")

            if asyncio.iscoroutinefunction(instance.execute_command):
                result = asyncio.run(instance.execute_command(command, params))
            else:
                result = instance.execute_command(command, params)

            return {
                'success': True,
                'output': result,
                'agent': agent.name,
                'method': 'python_direct'
            }
        except Exception as e:
            logger.error(f"Python direct invocation failed for {agent.name}: {e}")
            return {
                'success': False,
                'error': str(e),
                'agent': agent.name,
                'method': 'python_direct'
            }
    
    def _invoke_via_orchestrator(self, agent: UnifiedAgentMetadata, prompt: str) -> Dict[str, Any]:
        """Invoke via production orchestrator"""
        if not self.orchestrator:
            raise ValueError("Orchestrator not available")

        try:
            # The orchestrator is expected to have a method to schedule tasks
            # Assuming a 'schedule_task' method for this example
            if hasattr(self.orchestrator, 'schedule_task'):
                task_result = self.orchestrator.schedule_task(agent.name, prompt)
                return {
                    'success': True,
                    'output': task_result,
                    'agent': agent.name,
                    'method': 'orchestrator'
                }
            else:
                raise NotImplementedError("Orchestrator does not have a 'schedule_task' method")

        except Exception as e:
            logger.error(f"Orchestrator invocation failed for {agent.name}: {e}")
            return {
                'success': False,
                'error': str(e),
                'agent': agent.name,
                'method': 'orchestrator'
            }
    
    def _invoke_via_fallback(self, agent: UnifiedAgentMetadata, prompt: str) -> Dict[str, Any]:
        """Fallback invocation method"""
        return {
            'success': False,
            'error': 'No suitable invocation method available',
            'agent': agent.name,
            'method': 'fallback',
            'suggestion': f'Try: claude-agent {agent.name.lower()} "{prompt}"'
        }

# ============================================================================
# MAIN UNIFIED INTEGRATION SYSTEM
# ============================================================================

class UnifiedClaudeCodeIntegration:
    """Main unified integration system"""

    def __init__(self, project_root: Optional[Path] = None, agents_dir: Optional[Path] = None):
        logger.info("Initializing Unified Claude Code Integration System")

        # Initialize components, passing down the paths to ensure testability
        self.registry = UnifiedAgentRegistry(project_root=project_root, agents_dir=agents_dir)
        self.detector = ClaudeCodeEnvironmentDetector()
        self.hooks = UnifiedHookSystem(self.registry)
        self.invoker = UnifiedAgentInvoker(self.registry)

        # Setup integration
        self._setup_integration()
    
    def _setup_integration(self):
        """Setup full integration"""
        # Inject capabilities if in Claude Code
        if self.detector.is_claude_code:
            self.detector.inject_agent_capabilities()
            self.hooks.setup_hooks()
            logger.info("Claude Code environment detected - full integration active")
        else:
            logger.info("Standalone mode - agent registry and invocation available")
    
    def get_agent_info(self, agent_name: str) -> Optional[UnifiedAgentMetadata]:
        """Get detailed agent information"""
        return self.registry.get_agent(agent_name)
    
    def list_agents(self, category: Optional[str] = None) -> List[str]:
        """List available agents"""
        if category:
            agents = self.registry.get_agents_by_category(category)
            return [agent.name.lower() for agent in agents]
        else:
            return self.registry.list_agents()
    
    def invoke_agent(self, agent_name: str, prompt: str) -> Dict[str, Any]:
        """Invoke an agent with given prompt"""
        return self.invoker.invoke_agent(agent_name, prompt)
    
    def trigger_hook(self, phase: str) -> Dict[str, Any]:
        """Trigger a hook phase"""
        return self.hooks.trigger_hook(phase)
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get system status"""
        return {
            'integration_active': True,
            'claude_code_detected': self.detector.is_claude_code,
            'agents_loaded': len(self.registry.agents),
            'hooks_setup': self.detector.is_claude_code,
            'orchestrator_available': self.invoker.orchestrator is not None,
            'project_root': str(PROJECT_ROOT),
            'timestamp': time.time()
        }

# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """Main CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Unified Claude Code Integration System')
    parser.add_argument('--trigger', help='Trigger a hook phase')
    parser.add_argument('--invoke', help='Invoke an agent', nargs=2, metavar=('AGENT', 'PROMPT'))
    parser.add_argument('--list', action='store_true', help='List all agents')
    parser.add_argument('--status', action='store_true', help='Show system status')
    parser.add_argument('--info', help='Show agent info')
    parser.add_argument('--setup', action='store_true', help='Setup integration')
    
    args = parser.parse_args()
    
    # Initialize system
    integration = UnifiedClaudeCodeIntegration()
    
    if args.trigger:
        result = integration.trigger_hook(args.trigger)
        print(json.dumps(result, indent=2))
    elif args.invoke:
        agent_name, prompt = args.invoke
        result = integration.invoke_agent(agent_name, prompt)
        print(json.dumps(result, indent=2))
    elif args.list:
        agents = integration.list_agents()
        print(f"Available agents ({len(agents)}):")
        for agent in agents:
            print(f"  - {agent}")
    elif args.info:
        agent = integration.get_agent_info(args.info)
        if agent:
            print(f"Agent: {agent.name}")
            print(f"Category: {agent.category}")
            print(f"Status: {agent.status}")
            print(f"Description: {agent.description[:200]}...")
            print(f"Methods: {[m.value for m in agent.invocation_methods]}")
        else:
            print(f"Agent '{args.info}' not found")
    elif args.status:
        status = integration.get_system_status()
        print("Unified Integration Status:")
        for key, value in status.items():
            print(f"  {key}: {value}")
    elif args.setup:
        integration._setup_integration()
        print("Integration setup completed")
    else:
        print("Unified Claude Code Integration System")
        status = integration.get_system_status()
        print(f"Agents loaded: {status['agents_loaded']}")
        print(f"Claude Code detected: {status['claude_code_detected']}")
        print("Use --help for available commands")

if __name__ == "__main__":
    main()