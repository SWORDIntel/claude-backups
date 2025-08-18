#!/usr/bin/env python3
"""
TANDEM ORCHESTRATION SYSTEM
Dual-layer architecture where Python and C work in perfect harmony
Python handles strategic orchestration while C handles tactical execution
"""

import asyncio
import json
import hashlib
import time
import threading
import multiprocessing as mp
from typing import Dict, List, Any, Optional, Callable, Set, Tuple
from dataclasses import dataclass, field
from enum import Enum, IntEnum
from datetime import datetime, timedelta
import numpy as np
from collections import defaultdict, deque
import pickle
import struct
import socket
import ctypes
from abc import ABC, abstractmethod
import logging
from pathlib import Path

# Import existing components
from ENHANCED_AGENT_INTEGRATION import (
    EnhancedAgentOrchestrator, EnhancedAgentMessage, Priority, 
    HardwareAffinity, MeteorLakeTopology, AgentStatus, EnhancedAgentRegistry
)
from binary_bridge_connector import BinaryBridge
from intelligent_cache import IntelligentCache
from async_io_optimizer import AsyncIOOptimizer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ============================================================================
# COMMAND INTELLIGENCE LAYER
# ============================================================================

class CommandType(Enum):
    """Command abstraction levels"""
    ATOMIC = "atomic"           # Single instruction (C layer)
    SEQUENCE = "sequence"       # Multiple atomics (C layer)
    WORKFLOW = "workflow"       # Complex flow (Python layer)
    ORCHESTRATION = "orchestration"  # Multi-workflow (Python layer)
    CAMPAIGN = "campaign"       # Strategic multi-agent (Python layer)


class ExecutionMode(Enum):
    """How commands should be executed"""
    SPEED_CRITICAL = "speed"    # C layer only
    REDUNDANT = "redundant"     # Both layers for reliability
    INTELLIGENT = "intelligent" # Python decides, C executes
    PYTHON_ONLY = "python_only" # For Python library integration
    CONSENSUS = "consensus"     # Both must agree


@dataclass
class CommandSet:
    """High-level command abstraction"""
    id: str = field(default_factory=lambda: hashlib.sha256(str(time.time()).encode()).hexdigest()[:16])
    name: str = ""
    type: CommandType = CommandType.WORKFLOW
    mode: ExecutionMode = ExecutionMode.INTELLIGENT
    priority: Priority = Priority.MEDIUM
    
    # Command hierarchy
    steps: List['CommandStep'] = field(default_factory=list)
    dependencies: Dict[str, List[str]] = field(default_factory=dict)  # step_id -> [prerequisite_ids]
    
    # Execution control
    parallel_allowed: bool = True
    timeout: float = 300.0
    retry_policy: Dict[str, Any] = field(default_factory=lambda: {"max_retries": 3, "backoff": 1.5})
    
    # Python-specific
    python_handler: Optional[Callable] = None
    requires_libraries: List[str] = field(default_factory=list)  # e.g., ["pandas", "torch"]
    
    # C-specific
    c_optimized: bool = False
    hardware_affinity: HardwareAffinity = HardwareAffinity.AUTO
    
    def to_dag(self) -> Dict[str, Any]:
        """Convert to directed acyclic graph for execution planning"""
        dag = {
            "nodes": [{"id": step.id, "data": step} for step in self.steps],
            "edges": []
        }
        for step_id, deps in self.dependencies.items():
            for dep in deps:
                dag["edges"].append({"from": dep, "to": step_id})
        return dag


@dataclass
class CommandStep:
    """Individual command step"""
    id: str = field(default_factory=lambda: hashlib.sha256(str(time.time()).encode()).hexdigest()[:8])
    action: str = ""
    agent: str = ""
    payload: Dict[str, Any] = field(default_factory=dict)
    expected_output: Optional[Dict[str, Any]] = None
    validation_fn: Optional[Callable] = None
    can_fail: bool = False  # If True, failure doesn't stop workflow


# ============================================================================
# TANDEM ORCHESTRATOR
# ============================================================================

class TandemOrchestrator:
    """
    Dual-layer orchestration system that runs Python and C in perfect tandem
    """
    
    def __init__(self):
        # Layer components
        self.python_orchestrator = EnhancedAgentOrchestrator()
        self.binary_bridge = BinaryBridge()
        self.cache = IntelligentCache(max_size=10000)
        self.async_io = AsyncIOOptimizer()
        
        # Agent registry and discovery
        self.registry = EnhancedAgentRegistry()
        
        # Hardware topology
        self.topology = MeteorLakeTopology()
        
        # Command management
        self.active_campaigns: Dict[str, CommandSet] = {}
        self.command_history: deque = deque(maxlen=1000)
        self.execution_stats: Dict[str, Any] = defaultdict(lambda: {"success": 0, "failure": 0, "avg_time": 0})
        
        # Redundancy tracking
        self.redundant_messages: Dict[str, Dict[str, Any]] = {}  # message_id -> {python_result, c_result, consensus}
        
        # Layer synchronization
        self.sync_lock = threading.Lock()
        self.python_queue = asyncio.Queue()
        self.c_queue = mp.Queue()
        
        # Performance metrics
        self.metrics = {
            "python_msgs_processed": 0,
            "c_msgs_processed": 0,
            "redundant_agreements": 0,
            "redundant_conflicts": 0,
            "avg_python_latency": 0,
            "avg_c_latency": 0
        }
        
    async def initialize(self) -> bool:
        """Initialize both layers with full agent registration"""
        logger.info("Initializing Enhanced Tandem Orchestrator...")
        
        # Initialize agent registration system
        self.agent_registration = AgentRegistrationSystem(self)
        
        # Register all 31 agents
        registration_results = await self.agent_registration.initialize_all_agents()
        logger.info(f"Agent registration results: {registration_results['successfully_registered']}/{registration_results['total_agents']} agents registered")
        
        # Start Python orchestrator
        # Note: Skip initialization call if it doesn't exist
        try:
            if hasattr(self.python_orchestrator, 'initialize'):
                await self.python_orchestrator.initialize()
        except Exception as e:
            logger.warning(f"Python orchestrator initialization failed: {e}")
        
        # Connect to C binary layer
        binary_available = self.binary_bridge.connect()
        if not binary_available:
            logger.warning("C binary layer not available - running Python-only mode")
        
        # Start synchronization threads
        threading.Thread(target=self._sync_thread, daemon=True).start()
        asyncio.create_task(self._async_sync_task())
        
        # Start health monitoring
        asyncio.create_task(self._health_monitoring_task())
        
        logger.info(f"Enhanced Tandem Orchestrator initialized: {len(self.agent_registration.registered_agents)} agents ready")
        return True
    
    # ========================================================================
    # COMMAND SET EXECUTION
    # ========================================================================
    
    async def execute_command_set(self, command_set: CommandSet, use_dag_engine: bool = True) -> Dict[str, Any]:
        """
        Execute a high-level command set with intelligent layer routing
        
        This is where the magic happens - Python orchestrates while C executes
        """
        start_time = time.time()
        campaign_id = command_set.id
        self.active_campaigns[campaign_id] = command_set
        
        logger.info(f"Executing {command_set.type.value} campaign: {command_set.name}")
        
        # Determine execution strategy based on command type and mode
        if command_set.mode == ExecutionMode.SPEED_CRITICAL:
            result = await self._execute_c_only(command_set)
            
        elif command_set.mode == ExecutionMode.REDUNDANT:
            result = await self._execute_redundant(command_set)
            
        elif command_set.mode == ExecutionMode.INTELLIGENT:
            result = await self._execute_intelligent(command_set)
            
        elif command_set.mode == ExecutionMode.PYTHON_ONLY:
            result = await self._execute_python_only(command_set)
            
        elif command_set.mode == ExecutionMode.CONSENSUS:
            result = await self._execute_consensus(command_set)
            
        else:
            result = {"error": f"Unknown execution mode: {command_set.mode}"}
        
        # Record metrics
        execution_time = time.time() - start_time
        self._update_metrics(command_set, result, execution_time)
        
        del self.active_campaigns[campaign_id]
        return result
    
    async def _execute_intelligent(self, command_set: CommandSet) -> Dict[str, Any]:
        """
        Intelligent execution: Python orchestrates, C executes atomics
        
        This is the DEFAULT and RECOMMENDED mode for most operations
        """
        results = {}
        dag = command_set.to_dag()
        
        # Python analyzes the workflow
        execution_plan = await self._analyze_workflow(dag)
        
        # Decompose into atomic operations
        atomic_ops = self._decompose_to_atomics(command_set)
        
        # Execute based on intelligence analysis
        for step in command_set.steps:
            if self._should_use_c_layer(step):
                # Send atomic operation to C layer
                result = await self._send_to_c_layer(step)
            else:
                # Execute in Python (complex logic, ML, etc.)
                result = await self._execute_in_python(step)
            
            results[step.id] = result
            
            # Python makes decisions based on results
            if step.validation_fn:
                if not step.validation_fn(result):
                    if not step.can_fail:
                        logger.error(f"Step {step.id} validation failed")
                        break
        
        return {
            "campaign_id": command_set.id,
            "status": "completed",
            "results": results,
            "execution_plan": execution_plan
        }
    
    async def _execute_redundant(self, command_set: CommandSet) -> Dict[str, Any]:
        """
        Redundant execution: Critical messages go through both layers
        
        Ensures reliability for critical operations
        """
        msg_id = f"redundant_{command_set.id}"
        
        # Send to both layers in parallel
        python_task = asyncio.create_task(self._execute_python_only(command_set))
        c_task = asyncio.create_task(self._execute_c_only(command_set))
        
        # Wait for both results
        python_result, c_result = await asyncio.gather(python_task, c_task)
        
        # Compare results
        consensus = self._check_consensus(python_result, c_result)
        
        self.redundant_messages[msg_id] = {
            "python_result": python_result,
            "c_result": c_result,
            "consensus": consensus,
            "timestamp": datetime.now()
        }
        
        if consensus["agreement"]:
            self.metrics["redundant_agreements"] += 1
            return python_result  # Both agree, return either
        else:
            self.metrics["redundant_conflicts"] += 1
            # Conflict resolution strategy
            return await self._resolve_conflict(python_result, c_result, command_set)
    
    async def _execute_consensus(self, command_set: CommandSet) -> Dict[str, Any]:
        """
        Consensus execution: Both layers must agree before proceeding
        
        Maximum safety for critical operations
        """
        # Execute in both layers
        result = await self._execute_redundant(command_set)
        
        # If no consensus, retry with different strategy
        if result.get("conflict"):
            logger.warning("Consensus not reached, attempting resolution...")
            
            # Try breaking down into smaller operations
            atomic_ops = self._decompose_to_atomics(command_set)
            results = []
            
            for op in atomic_ops:
                op_result = await self._execute_redundant(op)
                if op_result.get("conflict"):
                    return {"error": "Consensus failure", "operation": op.id}
                results.append(op_result)
            
            return {"status": "consensus_achieved", "results": results}
        
        return result
    
    # ========================================================================
    # LAYER-SPECIFIC EXECUTION
    # ========================================================================
    
    async def _execute_python_only(self, command_set: CommandSet) -> Dict[str, Any]:
        """Execute entirely in Python layer"""
        if command_set.python_handler:
            return await command_set.python_handler(command_set)
        
        # Default Python execution
        results = {}
        for step in command_set.steps:
            msg = EnhancedAgentMessage(
                source_agent="tandem_orchestrator",
                target_agents=[step.agent],
                action=step.action,
                payload=step.payload,
                priority=command_set.priority
            )
            result = await self.python_orchestrator.send_message(msg)
            results[step.id] = result
        
        return {"status": "completed", "results": results}
    
    async def _execute_c_only(self, command_set: CommandSet) -> Dict[str, Any]:
        """Execute entirely in C layer"""
        if not self.binary_bridge.connected:
            return {"error": "C layer not available"}
        
        # Convert to binary format
        binary_msg = self._to_binary_format(command_set)
        
        # Send to C layer
        response = self.binary_bridge.send_message(binary_msg)
        
        if response:
            return self._parse_binary_response(response)
        return {"error": "C layer execution failed"}
    
    async def _send_to_c_layer(self, step: CommandStep) -> Dict[str, Any]:
        """Send individual step to C layer"""
        binary_msg = struct.pack(
            "!HH64s256s",  # Format: agent_id, action_id, agent_name, payload
            hash(step.agent) % 65536,
            hash(step.action) % 65536,
            step.agent.encode()[:64].ljust(64, b'\0'),
            json.dumps(step.payload).encode()[:256].ljust(256, b'\0')
        )
        
        response = self.binary_bridge.send_message(binary_msg)
        return self._parse_binary_response(response) if response else {"error": "C execution failed"}
    
    async def _execute_in_python(self, step: CommandStep) -> Dict[str, Any]:
        """Execute individual step in Python"""
        msg = EnhancedAgentMessage(
            source_agent="tandem_orchestrator",
            target_agents=[step.agent],
            action=step.action,
            payload=step.payload
        )
        return await self.python_orchestrator.send_message(msg)
    
    # ========================================================================
    # INTELLIGENCE LAYER
    # ========================================================================
    
    def _should_use_c_layer(self, step: CommandStep) -> bool:
        """
        Intelligent decision: Should this step use C layer?
        
        Factors:
        - Operation complexity (simple = C, complex = Python)
        - Data size (small = C, large = Python)
        - Required libraries (Python-only libs = Python)
        - Performance history (check metrics)
        """
        # Check if Python libraries required
        if hasattr(step, 'requires_libraries'):
            return False
        
        # Check operation complexity
        if step.action in ["send", "receive", "route", "forward", "ping"]:
            return True  # Simple operations -> C
        
        if step.action in ["analyze", "transform", "learn", "decide"]:
            return False  # Complex operations -> Python
        
        # Check data size
        payload_size = len(json.dumps(step.payload))
        if payload_size > 10000:  # Large payload
            return False  # Python handles better
        
        # Check performance history
        c_avg = self.execution_stats.get(f"c_{step.action}", {}).get("avg_time", float('inf'))
        py_avg = self.execution_stats.get(f"py_{step.action}", {}).get("avg_time", float('inf'))
        
        return c_avg < py_avg
    
    async def _analyze_workflow(self, dag: Dict[str, Any]) -> Dict[str, Any]:
        """
        Python's strategic analysis of workflow
        
        Determines optimal execution strategy
        """
        analysis = {
            "parallelizable_steps": [],
            "critical_path": [],
            "bottlenecks": [],
            "estimated_time": 0,
            "recommended_mode": ExecutionMode.INTELLIGENT
        }
        
        # Find parallelizable steps
        for node in dag["nodes"]:
            deps = [e["from"] for e in dag["edges"] if e["to"] == node["id"]]
            if len(deps) <= 1:
                analysis["parallelizable_steps"].append(node["id"])
        
        # Find critical path (longest dependency chain)
        # ... (graph algorithm implementation)
        
        return analysis
    
    def _decompose_to_atomics(self, command_set: CommandSet) -> List[CommandStep]:
        """
        Decompose high-level command set into atomic operations
        
        This is where Python's intelligence shines - breaking complex
        workflows into simple operations that C can execute at speed
        """
        atomics = []
        
        for step in command_set.steps:
            if step.action in ["workflow", "pipeline", "orchestrate"]:
                # Complex step - break it down
                sub_steps = self._break_down_complex_step(step)
                atomics.extend(sub_steps)
            else:
                # Already atomic
                atomics.append(step)
        
        return atomics
    
    def _break_down_complex_step(self, step: CommandStep) -> List[CommandStep]:
        """Break down complex step into atomic operations"""
        # This would contain logic to decompose complex operations
        # For now, return as-is
        return [step]
    
    # ========================================================================
    # CONSENSUS AND CONFLICT RESOLUTION
    # ========================================================================
    
    def _check_consensus(self, python_result: Dict, c_result: Dict) -> Dict[str, Any]:
        """Check if Python and C results agree"""
        # Simple comparison for now
        agreement = python_result.get("status") == c_result.get("status")
        
        return {
            "agreement": agreement,
            "python_status": python_result.get("status"),
            "c_status": c_result.get("status"),
            "discrepancies": self._find_discrepancies(python_result, c_result)
        }
    
    def _find_discrepancies(self, result1: Dict, result2: Dict) -> List[str]:
        """Find specific discrepancies between results"""
        discrepancies = []
        
        for key in set(result1.keys()) | set(result2.keys()):
            if result1.get(key) != result2.get(key):
                discrepancies.append(f"{key}: {result1.get(key)} vs {result2.get(key)}")
        
        return discrepancies
    
    async def _resolve_conflict(self, python_result: Dict, c_result: Dict, 
                               command_set: CommandSet) -> Dict[str, Any]:
        """
        Resolve conflicts between Python and C results
        
        Strategies:
        1. Retry both
        2. Use third arbiter
        3. Default to Python (more context)
        4. Default to C (more speed/accuracy for simple ops)
        """
        if command_set.priority == Priority.CRITICAL:
            # For critical operations, retry
            logger.warning("Critical operation conflict - retrying...")
            return await self.execute_command_set(command_set)
        
        # Default strategy: Trust Python for complex, C for simple
        if command_set.type in [CommandType.WORKFLOW, CommandType.ORCHESTRATION]:
            return python_result
        else:
            return c_result
    
    # ========================================================================
    # SYNCHRONIZATION
    # ========================================================================
    
    def _sync_thread(self):
        """Thread to sync with C layer"""
        while True:
            try:
                # Check C queue for messages
                if not self.c_queue.empty():
                    msg = self.c_queue.get()
                    # Convert and put in Python queue
                    asyncio.run_coroutine_threadsafe(
                        self.python_queue.put(msg),
                        asyncio.get_event_loop()
                    )
                time.sleep(0.001)  # 1ms sync interval
            except Exception as e:
                logger.error(f"Sync thread error: {e}")
    
    async def _async_sync_task(self):
        """Async task to process Python queue"""
        while True:
            try:
                msg = await self.python_queue.get()
                # Process message
                await self._process_sync_message(msg)
            except Exception as e:
                logger.error(f"Async sync error: {e}")
    
    async def _process_sync_message(self, msg: Dict[str, Any]):
        """Process synchronized message from C layer"""
        # Handle C layer updates
        if msg.get("type") == "agent_status_update":
            agent_name = msg.get("agent")
            status = msg.get("status")
            if agent_name in self.agent_registration.registered_agents:
                self.agent_registration.registered_agents[agent_name]["status"] = AgentStatus[status]
                self.agent_registration.registered_agents[agent_name]["last_seen"] = datetime.now()
        
        elif msg.get("type") == "health_check":
            # Update agent health scores based on C layer feedback
            agent_name = msg.get("agent")
            health_score = msg.get("health_score", 100)
            if agent_name in self.agent_registration.registered_agents:
                self.agent_registration.registered_agents[agent_name]["health_score"] = health_score
    
    async def _health_monitoring_task(self):
        """Background task for agent health monitoring"""
        while True:
            try:
                # Check agent health every 30 seconds
                await asyncio.sleep(30)
                
                if hasattr(self, 'agent_registration'):
                    current_time = datetime.now()
                    for agent_name, agent_info in self.agent_registration.registered_agents.items():
                        # Decrease health score if agent hasn't been seen recently
                        time_since_last_seen = current_time - agent_info["last_seen"]
                        if time_since_last_seen.total_seconds() > 300:  # 5 minutes
                            agent_info["health_score"] = max(0, agent_info["health_score"] - 10)
                        
                        # Reset status to IDLE if not updated recently
                        if (time_since_last_seen.total_seconds() > 60 and 
                            agent_info["status"] == AgentStatus.RUNNING):
                            agent_info["status"] = AgentStatus.IDLE
            
            except Exception as e:
                logger.error(f"Health monitoring task error: {e}")
    
    def discover_agents(self) -> Dict[str, Any]:
        """Discover all available agents and their capabilities"""
        if not hasattr(self, 'agent_registration'):
            return {"error": "Agent registration system not initialized"}
        
        discovery_results = {
            "timestamp": datetime.now().isoformat(),
            "total_agents": len(self.agent_registration.registered_agents),
            "agents_by_capability": dict(self.agent_registration.agent_capabilities),
            "agent_details": {}
        }
        
        for agent_name, agent_info in self.agent_registration.registered_agents.items():
            discovery_results["agent_details"][agent_name] = {
                "description": agent_info["config"]["description"],
                "capabilities": agent_info["config"]["capabilities"],
                "dependencies": agent_info["config"]["dependencies"],
                "hardware_affinity": agent_info["config"]["hardware_affinity"].value,
                "priority_level": agent_info["config"]["priority_level"].value,
                "status": agent_info["status"].name,
                "health_score": agent_info["health_score"],
                "auto_invoke_patterns": agent_info["config"]["auto_invoke_patterns"]
            }
        
        return discovery_results
    
    async def invoke_agent(self, agent_name: str, task: str, **kwargs) -> Dict[str, Any]:
        """High-level agent invocation interface"""
        if not hasattr(self, 'agent_registration'):
            return {"error": "Agent registration system not initialized"}
        
        if agent_name not in self.agent_registration.registered_agents:
            return {"error": f"Agent {agent_name} not found"}
        
        # Create a simple command set for the single agent task
        command_set = CommandSet(
            name=f"Invoke {agent_name}: {task}",
            type=CommandType.WORKFLOW,
            mode=ExecutionMode.INTELLIGENT,
            priority=self.agent_registration.registered_agents[agent_name]["config"]["priority_level"],
            steps=[
                CommandStep(
                    action=task,
                    agent=agent_name,
                    payload=kwargs
                )
            ]
        )
        
        return await self.execute_command_set(command_set, use_dag_engine=False)
    
    # ========================================================================
    # METRICS AND MONITORING
    # ========================================================================
    
    def _update_metrics(self, command_set: CommandSet, result: Dict[str, Any], 
                       execution_time: float):
        """Update performance metrics"""
        key = f"{command_set.type.value}_{command_set.mode.value}"
        
        stats = self.execution_stats[key]
        stats["success" if result.get("status") == "completed" else "failure"] += 1
        
        # Update rolling average
        total_runs = stats["success"] + stats["failure"]
        stats["avg_time"] = (stats["avg_time"] * (total_runs - 1) + execution_time) / total_runs
        
        # Store in history
        self.command_history.append({
            "timestamp": datetime.now(),
            "command_set": command_set.name,
            "execution_time": execution_time,
            "result": result.get("status")
        })
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current performance metrics"""
        agent_health = self.agent_registration.get_agent_health_status() if hasattr(self, 'agent_registration') else {}
        
        return {
            **self.metrics,
            "execution_stats": dict(self.execution_stats),
            "active_campaigns": len(self.active_campaigns),
            "history_size": len(self.command_history),
            "registered_agents": len(self.agent_registration.registered_agents) if hasattr(self, 'agent_registration') else 0,
            "agent_health": agent_health,
            "binary_bridge_connected": self.binary_bridge.connected
        }
    
    # ========================================================================
    # BINARY FORMAT CONVERSION
    # ========================================================================
    
    def _to_binary_format(self, command_set: CommandSet) -> bytes:
        """Convert command set to binary format for C layer"""
        # This would implement the actual binary protocol
        # For now, using pickle
        return pickle.dumps({
            "id": command_set.id,
            "steps": [{"agent": s.agent, "action": s.action, "payload": s.payload} 
                     for s in command_set.steps]
        })
    
    def _parse_binary_response(self, response: bytes) -> Dict[str, Any]:
        """Parse binary response from C layer"""
        try:
            # This would implement actual binary protocol parsing
            # For now, trying pickle
            return pickle.loads(response)
        except:
            return {"raw_response": response.hex()}


# ============================================================================
# AGENT REGISTRATION SYSTEM
# ============================================================================

class AgentRegistrationSystem:
    """Handles agent registration and discovery for the orchestration system"""
    
    def __init__(self, orchestrator: 'TandemOrchestrator'):
        self.orchestrator = orchestrator
        self.agents_dir = Path("/home/ubuntu/Documents/Claude/agents")
        self.registered_agents = {}
        self.agent_capabilities = {}
        
    async def initialize_all_agents(self) -> Dict[str, Any]:
        """Initialize and register all 31 agents from their .md files"""
        logger.info("Initializing all agents from agent definitions...")
        
        agent_files = list(self.agents_dir.glob("*.md"))
        
        # Filter out Template and other non-agent files
        excluded = {"Template.md", "README.md", "STATUSLINE_INTEGRATION.md"}
        agent_files = [f for f in agent_files if f.name not in excluded]
        
        registration_results = {
            "total_agents": len(agent_files),
            "successfully_registered": 0,
            "failed_registrations": [],
            "agents": {}
        }
        
        # Register each agent
        for agent_file in agent_files:
            try:
                agent_name = agent_file.stem
                agent_config = await self._parse_agent_definition(agent_file)
                
                # Register with the orchestrator's registry
                await self._register_agent_with_orchestrator(agent_name, agent_config)
                
                self.registered_agents[agent_name] = {
                    "config": agent_config,
                    "status": AgentStatus.IDLE,
                    "last_seen": datetime.now(),
                    "health_score": 100,
                    "file_path": str(agent_file)
                }
                
                registration_results["successfully_registered"] += 1
                registration_results["agents"][agent_name] = "registered"
                
                logger.info(f"Registered agent: {agent_name}")
                
            except Exception as e:
                logger.error(f"Failed to register agent {agent_file.name}: {e}")
                registration_results["failed_registrations"].append({
                    "agent": agent_file.name,
                    "error": str(e)
                })
                registration_results["agents"][agent_file.stem] = f"failed: {e}"
        
        logger.info(f"Agent registration complete: {registration_results['successfully_registered']}/{registration_results['total_agents']} agents registered")
        return registration_results
    
    async def _parse_agent_definition(self, agent_file: Path) -> Dict[str, Any]:
        """Parse agent definition from .md file"""
        with open(agent_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract YAML frontmatter
        if content.startswith('---'):
            try:
                parts = content.split('---', 2)
                if len(parts) >= 3:
                    # Parse YAML frontmatter if available
                    import yaml
                    frontmatter = yaml.safe_load(parts[1])
                    description = parts[2].strip()
                else:
                    frontmatter = {}
                    description = content
            except Exception as e:
                logger.warning(f"Could not parse YAML frontmatter for {agent_file.name}: {e}")
                frontmatter = {}
                description = content
        else:
            frontmatter = {}
            description = content
        
        # Extract agent description from content
        lines = description.split('\n')
        agent_description = ""
        for line in lines:
            if line.strip() and not line.startswith('#'):
                agent_description = line.strip()
                break
        
        # Build agent configuration
        config = {
            "description": agent_description or f"Agent from {agent_file.name}",
            "file_path": str(agent_file),
            "frontmatter": frontmatter,
            "capabilities": self._extract_capabilities(content),
            "dependencies": self._extract_dependencies(content),
            "hardware_affinity": self._extract_hardware_affinity(frontmatter),
            "communication_config": frontmatter.get("communication", {}),
            "auto_invoke_patterns": self._extract_auto_invoke_patterns(content),
            "priority_level": self._determine_priority_level(agent_file.stem)
        }
        
        return config
    
    def _extract_capabilities(self, content: str) -> List[str]:
        """Extract agent capabilities from content"""
        capabilities = []
        
        # Look for capability keywords
        capability_keywords = [
            "design", "build", "test", "deploy", "monitor", "secure", "analyze",
            "optimize", "debug", "document", "plan", "coordinate", "architect"
        ]
        
        content_lower = content.lower()
        for keyword in capability_keywords:
            if keyword in content_lower:
                capabilities.append(keyword)
        
        return capabilities
    
    def _extract_dependencies(self, content: str) -> List[str]:
        """Extract agent dependencies from content"""
        dependencies = []
        
        # Look for references to other agents
        known_agents = [
            "Director", "ProjectOrchestrator", "Architect", "Constructor", "Security",
            "Testbed", "Optimizer", "Debugger", "Deployer", "Monitor", "Database",
            "MLOps", "DataScience", "Web", "Mobile", "PyGUI", "TUI", "APIDesigner",
            "Patcher", "Linter", "Docgen", "Packager", "Infrastructure", "RESEARCHER",
            "Bastion", "Oversight", "SecurityChaosAgent", "GNU", "NPU", "PLANNER"
        ]
        
        for agent in known_agents:
            if agent.lower() in content.lower():
                dependencies.append(agent)
        
        return list(set(dependencies))  # Remove duplicates
    
    def _extract_hardware_affinity(self, frontmatter: Dict) -> HardwareAffinity:
        """Extract hardware affinity from frontmatter"""
        hardware_config = frontmatter.get("hardware", {})
        
        if "p_cores_ultra" in str(hardware_config).lower():
            return HardwareAffinity.P_CORE_ULTRA
        elif "p_cores" in str(hardware_config).lower():
            return HardwareAffinity.P_CORE
        elif "e_cores" in str(hardware_config).lower():
            return HardwareAffinity.E_CORE
        elif "lp_e_cores" in str(hardware_config).lower():
            return HardwareAffinity.LP_E_CORE
        else:
            return HardwareAffinity.AUTO
    
    def _extract_auto_invoke_patterns(self, content: str) -> List[str]:
        """Extract auto-invoke patterns from content"""
        patterns = []
        lines = content.split('\n')
        
        in_patterns_section = False
        for line in lines:
            line_stripped = line.strip()
            if "auto_invoke" in line_stripped.lower() or "pattern" in line_stripped.lower():
                in_patterns_section = True
            elif in_patterns_section and line_stripped.startswith('- '):
                pattern = line_stripped[2:].strip('"\'')
                if pattern:
                    patterns.append(pattern)
            elif in_patterns_section and not line_stripped:
                in_patterns_section = False
        
        return patterns
    
    def _determine_priority_level(self, agent_name: str) -> Priority:
        """Determine priority level based on agent type"""
        critical_agents = {"Director", "Security", "ProjectOrchestrator"}
        high_priority_agents = {"Architect", "Constructor", "Testbed", "Deployer"}
        
        if agent_name in critical_agents:
            return Priority.CRITICAL
        elif agent_name in high_priority_agents:
            return Priority.HIGH
        else:
            return Priority.MEDIUM
    
    async def _register_agent_with_orchestrator(self, agent_name: str, config: Dict[str, Any]):
        """Register agent with the enhanced orchestrator"""
        # Register with the enhanced orchestrator's registry
        self.orchestrator.registry.register_agent(agent_name, config)
        
        # Also register capabilities for lookup
        for capability in config.get("capabilities", []):
            if capability not in self.agent_capabilities:
                self.agent_capabilities[capability] = []
            self.agent_capabilities[capability].append(agent_name)
    
    def get_agents_by_capability(self, capability: str) -> List[str]:
        """Get agents that have a specific capability"""
        return self.agent_capabilities.get(capability, [])
    
    def get_agent_health_status(self) -> Dict[str, Any]:
        """Get health status of all registered agents"""
        health_status = {
            "total_agents": len(self.registered_agents),
            "healthy_agents": 0,
            "unhealthy_agents": 0,
            "agents": {}
        }
        
        for agent_name, agent_info in self.registered_agents.items():
            is_healthy = agent_info["health_score"] > 50
            health_status["agents"][agent_name] = {
                "status": agent_info["status"].name,
                "health_score": agent_info["health_score"],
                "last_seen": agent_info["last_seen"].isoformat(),
                "healthy": is_healthy
            }
            
            if is_healthy:
                health_status["healthy_agents"] += 1
            else:
                health_status["unhealthy_agents"] += 1
        
        return health_status


# ============================================================================
# READY-TO-USE WORKFLOWS
# ============================================================================

class StandardWorkflows:
    """Pre-built workflows for common operations"""
    
    @staticmethod
    def create_document_generation_workflow() -> CommandSet:
        """TUI + DOCGEN coordinated workflow"""
        return CommandSet(
            name="Document Generation Pipeline",
            type=CommandType.WORKFLOW,
            mode=ExecutionMode.INTELLIGENT,
            priority=Priority.HIGH,
            steps=[
                CommandStep(
                    id="ui_input",
                    action="get_user_input",
                    agent="tui",
                    payload={"prompt": "Enter documentation parameters"}
                ),
                CommandStep(
                    id="analyze",
                    action="analyze_codebase",
                    agent="docgen",
                    payload={"depth": "full"}
                ),
                CommandStep(
                    id="generate",
                    action="generate_docs",
                    agent="docgen",
                    payload={"format": "markdown"}
                ),
                CommandStep(
                    id="display",
                    action="display_output",
                    agent="tui",
                    payload={"type": "documentation"}
                )
            ],
            dependencies={
                "analyze": ["ui_input"],
                "generate": ["analyze"],
                "display": ["generate"]
            }
        )
    
    @staticmethod
    def create_security_audit_workflow() -> CommandSet:
        """Multi-agent security audit with redundancy"""
        return CommandSet(
            name="Security Audit Campaign",
            type=CommandType.CAMPAIGN,
            mode=ExecutionMode.REDUNDANT,  # Critical - use both layers
            priority=Priority.CRITICAL,
            steps=[
                CommandStep(
                    id="scan",
                    action="vulnerability_scan",
                    agent="security",
                    payload={"scope": "full"}
                ),
                CommandStep(
                    id="chaos",
                    action="chaos_test",
                    agent="securitychaosagent",
                    payload={"intensity": "moderate"}
                ),
                CommandStep(
                    id="report",
                    action="generate_report",
                    agent="docgen",
                    payload={"type": "security_audit"}
                )
            ],
            dependencies={
                "chaos": ["scan"],
                "report": ["scan", "chaos"]
            }
        )


# ============================================================================
# MAIN EXECUTION
# ============================================================================

async def main():
    """Example usage of Tandem Orchestrator"""
    
    # Initialize
    orchestrator = TandemOrchestrator()
    await orchestrator.initialize()
    
    # Create a document generation workflow
    doc_workflow = StandardWorkflows.create_document_generation_workflow()
    
    # Execute with intelligent routing
    result = await orchestrator.execute_command_set(doc_workflow)
    print(f"Workflow result: {result}")
    
    # Create a critical security audit (uses redundancy)
    security_workflow = StandardWorkflows.create_security_audit_workflow()
    result = await orchestrator.execute_command_set(security_workflow)
    print(f"Security audit result: {result}")
    
    # Show metrics
    metrics = orchestrator.get_metrics()
    print(f"Performance metrics: {json.dumps(metrics, indent=2)}")


if __name__ == "__main__":
    asyncio.run(main())