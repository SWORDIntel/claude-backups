#!/usr/bin/env python3
"""
Enhanced Agent Integration System - Meteor Lake Optimized Edition
Provides seamless communication and coordination between all agents
with hardware-aware scheduling and vector routing integration
"""

import asyncio
import json
import uuid
import time
import os
import psutil
import numpy as np
from typing import Dict, List, Any, Optional, Callable, Tuple, Set
from dataclasses import dataclass, field
from enum import Enum, IntEnum
from datetime import datetime, timedelta
import networkx as nx
from collections import defaultdict, deque
import logging
import pickle
import hashlib
import ctypes
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
import multiprocessing as mp
from functools import lru_cache, wraps
import heapq

# Configure logging with performance metrics
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(cpu_core)s] - %(message)s'
)
logger = logging.getLogger(__name__)

# Add CPU core to log records
old_factory = logging.getLogRecordFactory()
def record_factory(*args, **kwargs):
    record = old_factory(*args, **kwargs)
    record.cpu_core = f"CPU-{os.sched_getaffinity(0).pop() if os.sched_getaffinity(0) else 'N/A'}"
    return record
logging.setLogRecordFactory(record_factory)


class AgentStatus(IntEnum):
    """Agent execution status with priority ordering"""
    IDLE = 0
    SCHEDULED = 1
    RUNNING = 2
    COMPLETED = 3
    FAILED = 4
    BLOCKED = 5
    SUSPENDED = 6
    RECOVERING = 7


class Priority(IntEnum):
    """Message priority levels with hardware affinity"""
    CRITICAL = 1    # P-cores ultra (11,14,15,16)
    HIGH = 3        # P-cores standard (0-10)
    MEDIUM = 5      # E-cores (12-19)
    LOW = 7         # E-cores
    BACKGROUND = 10 # LP E-cores (20-21)


class HardwareAffinity(Enum):
    """Hardware core affinity for Meteor Lake"""
    P_CORE_ULTRA = "p_ultra"  # Cores 11,14,15,16
    P_CORE = "p_core"         # Cores 0-10
    E_CORE = "e_core"         # Cores 12-19
    LP_E_CORE = "lp_e_core"   # Cores 20-21
    AUTO = "auto"             # Automatic selection


@dataclass
class MeteorLakeTopology:
    """Meteor Lake CPU topology configuration"""
    p_cores_ultra: List[int] = field(default_factory=lambda: [11, 14, 15, 16])
    p_cores_standard: List[int] = field(default_factory=lambda: list(range(0, 11)))
    e_cores: List[int] = field(default_factory=lambda: list(range(12, 20)))
    lp_e_cores: List[int] = field(default_factory=lambda: [20, 21])
    
    def get_cores_for_priority(self, priority: Priority) -> List[int]:
        """Get CPU cores for given priority"""
        if priority == Priority.CRITICAL:
            return self.p_cores_ultra
        elif priority == Priority.HIGH:
            return self.p_cores_standard
        elif priority in [Priority.MEDIUM, Priority.LOW]:
            return self.e_cores
        else:
            return self.lp_e_cores
    
    def get_optimal_core(self, workload_type: str) -> int:
        """Get optimal core for workload type"""
        cpu_percent = psutil.cpu_percent(percpu=True)
        
        if workload_type == "compute_intensive":
            # Find least loaded P-core
            p_core_loads = [(cpu_percent[i], i) for i in self.p_cores_ultra + self.p_cores_standard]
            return min(p_core_loads)[1]
        elif workload_type == "io_intensive":
            # Use E-cores for I/O
            e_core_loads = [(cpu_percent[i], i) for i in self.e_cores]
            return min(e_core_loads)[1]
        else:
            # Background tasks on LP E-cores
            lp_core_loads = [(cpu_percent[i], i) for i in self.lp_e_cores]
            return min(lp_core_loads)[1]


@dataclass
class EnhancedAgentMessage:
    """Enhanced message format with vector embeddings and hardware affinity"""
    message_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = field(default_factory=datetime.now)
    source_agent: str = ""
    target_agents: List[str] = field(default_factory=list)
    action: str = ""
    payload: Dict[str, Any] = field(default_factory=dict)
    context: Dict[str, Any] = field(default_factory=dict)
    priority: Priority = Priority.MEDIUM
    hardware_affinity: HardwareAffinity = HardwareAffinity.AUTO
    correlation_id: Optional[str] = None
    requires_ack: bool = False
    timeout: int = 300  # seconds
    
    # Enhanced fields
    vector_embedding: Optional[np.ndarray] = None  # For semantic routing
    encryption_key: Optional[bytes] = None         # For secure messages
    compression_type: Optional[str] = None         # lz4, zstd, etc.
    trace_id: Optional[str] = None                # Distributed tracing
    retry_count: int = 0
    max_retries: int = 3
    
    def to_bytes(self) -> bytes:
        """Serialize message for network transport"""
        return pickle.dumps(self)
    
    @classmethod
    def from_bytes(cls, data: bytes) -> 'EnhancedAgentMessage':
        """Deserialize message from bytes"""
        return pickle.loads(data)
    
    def compute_hash(self) -> str:
        """Compute message hash for deduplication"""
        content = f"{self.source_agent}{self.action}{json.dumps(self.payload, sort_keys=True)}"
        return hashlib.sha256(content.encode()).hexdigest()


@dataclass
class AgentCapability:
    """Enhanced agent capability definition"""
    name: str
    description: str
    input_schema: Dict[str, Any]
    output_schema: Dict[str, Any]
    required_tools: List[str]
    estimated_duration: int  # seconds
    resource_requirements: Dict[str, int]  # cpu, memory, gpu
    
    # Enhanced fields
    hardware_preference: HardwareAffinity = HardwareAffinity.AUTO
    parallelizable: bool = False
    cacheable: bool = True
    vector_dimension: int = 768  # For semantic matching
    success_rate: float = 1.0     # Historical success rate
    avg_latency_ms: float = 0.0   # Average execution time


class VectorRoutingEngine:
    """Semantic vector-based message routing"""
    
    def __init__(self, dimension: int = 768):
        self.dimension = dimension
        self.agent_vectors = {}
        self.message_cache = {}
        self._initialize_embeddings()
    
    def _initialize_embeddings(self):
        """Initialize agent capability embeddings"""
        # In production, these would be learned from data
        np.random.seed(42)
        
        agent_types = [
            "DIRECTOR", "PROJECT_ORCHESTRATOR", "ARCHITECT", "CONSTRUCTOR",
            "SECURITY", "TESTBED", "OPTIMIZER", "DEBUGGER", "DEPLOYER",
            "MONITOR", "DATABASE", "ML_OPS", "WEB", "PATCHER", "LINTER",
            "DOCGEN", "PACKAGER", "API_DESIGNER", "C_INTERNAL", "PYTHON_INTERNAL"
        ]
        
        for agent in agent_types:
            # Create characteristic vector for each agent
            self.agent_vectors[agent] = self._create_agent_vector(agent)
    
    def _create_agent_vector(self, agent_type: str) -> np.ndarray:
        """Create characteristic vector for agent type"""
        # Simplified: In production, use actual embeddings
        base_vector = np.random.randn(self.dimension)
        
        # Add agent-specific characteristics
        if "DIRECTOR" in agent_type:
            base_vector[0:100] *= 2.0  # Strategic planning
        elif "SECURITY" in agent_type:
            base_vector[100:200] *= 2.0  # Security focus
        elif "ML_OPS" in agent_type:
            base_vector[200:300] *= 2.0  # ML operations
        elif "DATABASE" in agent_type:
            base_vector[300:400] *= 2.0  # Data management
        
        return base_vector / np.linalg.norm(base_vector)
    
    def compute_message_embedding(self, message: EnhancedAgentMessage) -> np.ndarray:
        """Compute vector embedding for message"""
        if message.vector_embedding is not None:
            return message.vector_embedding
        
        # Hash-based pseudo-embedding (simplified)
        msg_hash = message.compute_hash()
        np.random.seed(int(msg_hash[:8], 16))
        embedding = np.random.randn(self.dimension)
        
        # Incorporate action semantics
        if "design" in message.action.lower():
            embedding[0:100] += 1.0
        if "test" in message.action.lower():
            embedding[100:200] += 1.0
        if "deploy" in message.action.lower():
            embedding[200:300] += 1.0
        
        return embedding / np.linalg.norm(embedding)
    
    def find_best_agents(self, message: EnhancedAgentMessage, top_k: int = 3) -> List[Tuple[str, float]]:
        """Find best agents for message using vector similarity"""
        msg_embedding = self.compute_message_embedding(message)
        
        similarities = []
        for agent, agent_vec in self.agent_vectors.items():
            # Cosine similarity
            similarity = np.dot(msg_embedding, agent_vec)
            similarities.append((agent, similarity))
        
        # Sort by similarity
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]


class CircuitBreaker:
    """Circuit breaker pattern for agent fault tolerance"""
    
    def __init__(self, failure_threshold: int = 5, timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failure_count = defaultdict(int)
        self.last_failure_time = {}
        self.circuit_state = defaultdict(lambda: "closed")  # closed, open, half-open
    
    def record_success(self, agent_id: str):
        """Record successful execution"""
        self.failure_count[agent_id] = 0
        self.circuit_state[agent_id] = "closed"
    
    def record_failure(self, agent_id: str):
        """Record failed execution"""
        self.failure_count[agent_id] += 1
        self.last_failure_time[agent_id] = time.time()
        
        if self.failure_count[agent_id] >= self.failure_threshold:
            self.circuit_state[agent_id] = "open"
            logger.warning(f"Circuit breaker opened for agent {agent_id}")
    
    def can_execute(self, agent_id: str) -> bool:
        """Check if agent can execute"""
        state = self.circuit_state[agent_id]
        
        if state == "closed":
            return True
        elif state == "open":
            # Check if timeout has passed
            if time.time() - self.last_failure_time.get(agent_id, 0) > self.timeout:
                self.circuit_state[agent_id] = "half-open"
                return True
            return False
        elif state == "half-open":
            return True
        
        return False


class EnhancedAgentRegistry:
    """Enhanced central registry with performance metrics"""
    
    def __init__(self):
        self.agents = {}
        self.capabilities = defaultdict(list)
        self.performance_metrics = defaultdict(dict)
        self.circuit_breaker = CircuitBreaker()
        self.vector_engine = VectorRoutingEngine()
        self._initialize_agents()
    
    def _initialize_agents(self):
        """Initialize all known agents with enhanced capabilities"""
        
        # Director Agent - Ultra P-cores
        self.register_agent("DIRECTOR", {
            "description": "Strategic executive orchestrator",
            "capabilities": [
                AgentCapability(
                    name="strategic_planning",
                    description="Create multi-phase execution plans",
                    input_schema={"project_description": "string", "constraints": "object"},
                    output_schema={"plan": "object", "phases": "array"},
                    required_tools=["Read", "Write", "ProjectKnowledgeSearch"],
                    estimated_duration=300,
                    resource_requirements={"cpu": 4, "memory": 8},
                    hardware_preference=HardwareAffinity.P_CORE_ULTRA,
                    parallelizable=False,
                    cacheable=True
                )
            ],
            "dependencies": [],
            "color": "gold",
            "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
        })
        
        # Continue with other agents...
        self._register_remaining_agents()
    
    def _register_remaining_agents(self):
        """Register remaining agents with enhanced specifications"""
        
        agents_config = {
            "PROJECT_ORCHESTRATOR": {
                "description": "Tactical cross-agent synthesis",
                "dependencies": ["DIRECTOR"],
                "color": "cyan",
                "hardware_affinity": HardwareAffinity.P_CORE
            },
            "ARCHITECT": {
                "description": "Technical architecture specialist",
                "dependencies": ["DIRECTOR"],
                "color": "red",
                "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
            },
            "CONSTRUCTOR": {
                "description": "Project initialization specialist",
                "dependencies": ["ARCHITECT"],
                "color": "green",
                "hardware_affinity": HardwareAffinity.P_CORE
            },
            "SECURITY": {
                "description": "Security analysis specialist",
                "dependencies": [],
                "color": "red",
                "veto_power": True,
                "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
            },
            "TESTBED": {
                "description": "Test engineering specialist",
                "dependencies": ["CONSTRUCTOR", "PATCHER"],
                "color": "purple",
                "hardware_affinity": HardwareAffinity.E_CORE
            },
            "OPTIMIZER": {
                "description": "Performance engineering specialist",
                "dependencies": ["TESTBED"],
                "color": "purple",
                "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
            },
            "DEBUGGER": {
                "description": "Failure analysis specialist",
                "dependencies": ["TESTBED"],
                "color": "yellow",
                "hardware_affinity": HardwareAffinity.P_CORE
            },
            "DEPLOYER": {
                "description": "Deployment orchestration specialist",
                "dependencies": ["PACKAGER", "SECURITY"],
                "color": "purple",
                "hardware_affinity": HardwareAffinity.E_CORE
            },
            "MONITOR": {
                "description": "Observability specialist",
                "dependencies": ["DEPLOYER"],
                "color": "yellow",
                "hardware_affinity": HardwareAffinity.LP_E_CORE
            },
            "DATABASE": {
                "description": "Data architecture specialist",
                "dependencies": ["ARCHITECT"],
                "color": "green",
                "hardware_affinity": HardwareAffinity.P_CORE
            },
            "ML_OPS": {
                "description": "ML pipeline specialist",
                "dependencies": ["PYTHON_INTERNAL", "DATABASE"],
                "color": "magenta",
                "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
            },
            "C_INTERNAL": {
                "description": "C/C++ optimization specialist",
                "dependencies": ["ARCHITECT", "LINTER"],
                "color": "orange",
                "hardware_affinity": HardwareAffinity.P_CORE_ULTRA
            },
            "PYTHON_INTERNAL": {
                "description": "Python optimization specialist",
                "dependencies": ["ARCHITECT", "LINTER"],
                "color": "default",
                "hardware_affinity": HardwareAffinity.P_CORE
            }
        }
        
        for agent_name, config in agents_config.items():
            self.register_agent(agent_name, config)
    
    def register_agent(self, agent_id: str, config: dict):
        """Register an agent with enhanced configuration"""
        self.agents[agent_id] = config
        
        # Initialize performance metrics
        self.performance_metrics[agent_id] = {
            "total_executions": 0,
            "successful_executions": 0,
            "failed_executions": 0,
            "total_latency_ms": 0,
            "avg_latency_ms": 0,
            "p99_latency_ms": 0,
            "last_execution": None
        }
        
        # Index capabilities for quick lookup
        for capability in config.get("capabilities", []):
            self.capabilities[capability.name].append(agent_id)
    
    def get_agent_health(self, agent_id: str) -> Dict[str, Any]:
        """Get agent health status"""
        metrics = self.performance_metrics.get(agent_id, {})
        can_execute = self.circuit_breaker.can_execute(agent_id)
        
        success_rate = 0
        if metrics.get("total_executions", 0) > 0:
            success_rate = metrics.get("successful_executions", 0) / metrics["total_executions"]
        
        return {
            "agent_id": agent_id,
            "healthy": can_execute,
            "success_rate": success_rate,
            "avg_latency_ms": metrics.get("avg_latency_ms", 0),
            "last_execution": metrics.get("last_execution"),
            "circuit_state": self.circuit_breaker.circuit_state[agent_id]
        }


class EnhancedAgentOrchestrator:
    """Enhanced orchestration engine with hardware-aware scheduling"""
    
    def __init__(self, max_workers: int = 22):  # Total Meteor Lake cores
        self.registry = EnhancedAgentRegistry()
        self.topology = MeteorLakeTopology()
        self.message_queue = asyncio.PriorityQueue()
        self.state_store = {}
        self.active_agents = {}
        self.dependency_graph = self._build_dependency_graph()
        
        # Thread pools for different core types
        self.p_core_executor = ThreadPoolExecutor(max_workers=12, thread_name_prefix="p-core")
        self.e_core_executor = ThreadPoolExecutor(max_workers=8, thread_name_prefix="e-core")
        self.lp_e_core_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="lp-e-core")
        
        # Performance monitoring
        self.execution_history = deque(maxlen=1000)
        self.latency_histogram = defaultdict(list)
        
        # Message deduplication
        self.processed_messages = set()
        self.message_cache = {}
    
    def _build_dependency_graph(self) -> nx.DiGraph:
        """Build enhanced dependency graph with weights"""
        graph = nx.DiGraph()
        
        for agent_id, config in self.registry.agents.items():
            graph.add_node(agent_id, **config)
            for dependency in config.get("dependencies", []):
                # Add edge with weight based on typical execution time
                weight = 1.0  # Default weight
                if "ML_OPS" in agent_id or "ML_OPS" in dependency:
                    weight = 2.0  # ML operations take longer
                graph.add_edge(dependency, agent_id, weight=weight)
        
        return graph
    
    async def execute_workflow(self, workflow: dict, trace_id: Optional[str] = None) -> dict:
        """Execute workflow with distributed tracing and optimization"""
        
        workflow_id = str(uuid.uuid4())
        trace_id = trace_id or str(uuid.uuid4())
        
        logger.info(f"Starting workflow {workflow_id}: {workflow['name']} [trace={trace_id}]")
        
        # Initialize workflow state with enhanced tracking
        self.state_store[workflow_id] = {
            "status": "running",
            "started_at": datetime.now(),
            "completed_steps": [],
            "results": {},
            "trace_id": trace_id,
            "metrics": {
                "total_agents": 0,
                "completed_agents": 0,
                "failed_agents": 0,
                "total_latency_ms": 0
            }
        }
        
        try:
            # Optimize workflow execution plan
            execution_plan = await self._optimize_execution_plan(workflow)
            
            # Execute optimized plan
            for phase in execution_plan["phases"]:
                await self._execute_phase(workflow_id, phase, workflow, trace_id)
            
            # Mark workflow as completed
            self.state_store[workflow_id]["status"] = "completed"
            self.state_store[workflow_id]["completed_at"] = datetime.now()
            
            # Calculate total execution time
            duration = (self.state_store[workflow_id]["completed_at"] - 
                       self.state_store[workflow_id]["started_at"]).total_seconds()
            self.state_store[workflow_id]["metrics"]["total_duration_s"] = duration
            
            return self.state_store[workflow_id]
            
        except Exception as e:
            logger.error(f"Workflow {workflow_id} failed: {str(e)}")
            self.state_store[workflow_id]["status"] = "failed"
            self.state_store[workflow_id]["error"] = str(e)
            raise
    
    async def _optimize_execution_plan(self, workflow: dict) -> dict:
        """Optimize workflow execution using graph algorithms"""
        
        required_agents = self._extract_required_agents(workflow)
        
        # Use graph algorithms to find optimal execution order
        subgraph = self.dependency_graph.subgraph(required_agents)
        
        # Find critical path
        critical_path = []
        if subgraph.nodes():
            try:
                # Find longest path (critical path)
                critical_path = nx.dag_longest_path(subgraph, weight='weight')
            except nx.NetworkXError:
                logger.warning("Could not compute critical path")
        
        # Calculate parallel execution phases
        phases = self._calculate_parallel_phases(required_agents, critical_path)
        
        return {
            "critical_path": critical_path,
            "phases": phases,
            "estimated_duration": self._estimate_duration(phases)
        }
    
    def _calculate_parallel_phases(self, agents: List[str], critical_path: List[str]) -> List[Dict]:
        """Calculate optimal parallel execution phases"""
        
        phases = []
        remaining = set(agents)
        phase_num = 0
        
        while remaining:
            # Find agents that can run in this phase
            phase_agents = []
            
            for agent in remaining:
                # Check if all dependencies are satisfied
                deps = self.registry.agents[agent].get("dependencies", [])
                if all(dep not in remaining for dep in deps):
                    phase_agents.append(agent)
            
            if not phase_agents:
                # Circular dependency detected
                raise ValueError(f"Circular dependency detected among agents: {remaining}")
            
            # Assign hardware affinity based on priority
            phase_config = {
                "phase": phase_num,
                "agents": phase_agents,
                "hardware_assignment": self._assign_hardware(phase_agents),
                "critical": any(agent in critical_path for agent in phase_agents)
            }
            
            phases.append(phase_config)
            remaining -= set(phase_agents)
            phase_num += 1
        
        return phases
    
    def _assign_hardware(self, agents: List[str]) -> Dict[str, List[int]]:
        """Assign optimal hardware cores to agents"""
        
        assignments = {}
        
        for agent in agents:
            config = self.registry.agents[agent]
            affinity = config.get("hardware_affinity", HardwareAffinity.AUTO)
            
            if affinity == HardwareAffinity.P_CORE_ULTRA:
                assignments[agent] = self.topology.p_cores_ultra
            elif affinity == HardwareAffinity.P_CORE:
                assignments[agent] = self.topology.p_cores_standard
            elif affinity == HardwareAffinity.E_CORE:
                assignments[agent] = self.topology.e_cores
            elif affinity == HardwareAffinity.LP_E_CORE:
                assignments[agent] = self.topology.lp_e_cores
            else:
                # Auto assignment based on workload
                assignments[agent] = self._auto_assign_cores(agent)
        
        return assignments
    
    def _auto_assign_cores(self, agent: str) -> List[int]:
        """Automatically assign cores based on agent characteristics"""
        
        # Check agent capabilities
        config = self.registry.agents[agent]
        
        # Critical agents get P-cores
        if "SECURITY" in agent or "DIRECTOR" in agent:
            return self.topology.p_cores_ultra
        
        # Compute-intensive agents get P-cores
        if "ML_OPS" in agent or "OPTIMIZER" in agent:
            return self.topology.p_cores_standard
        
        # I/O bound agents get E-cores
        if "MONITOR" in agent or "DEPLOYER" in agent:
            return self.topology.e_cores
        
        # Background tasks get LP E-cores
        if "LINTER" in agent or "DOCGEN" in agent:
            return self.topology.lp_e_cores
        
        # Default to E-cores
        return self.topology.e_cores
    
    def _estimate_duration(self, phases: List[Dict]) -> float:
        """Estimate total workflow duration"""
        
        total_duration = 0
        
        for phase in phases:
            # Find maximum duration in phase (parallel execution)
            max_duration = 0
            
            for agent in phase["agents"]:
                # Get historical average or estimate
                metrics = self.registry.performance_metrics[agent]
                avg_duration = metrics.get("avg_latency_ms", 1000) / 1000  # Convert to seconds
                
                if avg_duration == 0:
                    # Use estimate from capabilities
                    capabilities = self.registry.agents[agent].get("capabilities", [])
                    if capabilities:
                        avg_duration = capabilities[0].estimated_duration
                    else:
                        avg_duration = 10  # Default 10 seconds
                
                max_duration = max(max_duration, avg_duration)
            
            # Add overhead for critical path
            if phase["critical"]:
                max_duration *= 1.1
            
            total_duration += max_duration
        
        return total_duration
    
    async def _execute_phase(self, workflow_id: str, phase: Dict, workflow: dict, trace_id: str):
        """Execute a phase with hardware-optimized parallelism"""
        
        phase_start = time.time()
        tasks = []
        
        for agent_id in phase["agents"]:
            # Find relevant step for this agent
            step = self._find_step_for_agent(workflow, agent_id)
            if step:
                # Get assigned cores
                assigned_cores = phase["hardware_assignment"][agent_id]
                
                # Create execution task with core affinity
                task = asyncio.create_task(
                    self._execute_agent_with_affinity(
                        workflow_id, agent_id, step, assigned_cores, trace_id
                    )
                )
                tasks.append((agent_id, task))
        
        # Wait for all agents in phase to complete
        results = await asyncio.gather(*[task for _, task in tasks], return_exceptions=True)
        
        # Process results
        for (agent_id, _), result in zip(tasks, results):
            if isinstance(result, Exception):
                # Handle failure with circuit breaker
                self.registry.circuit_breaker.record_failure(agent_id)
                
                # Retry if possible
                if self.registry.circuit_breaker.can_execute(agent_id):
                    logger.warning(f"Retrying agent {agent_id} after failure")
                    # Implement retry logic here
                else:
                    raise RuntimeError(f"Agent {agent_id} failed: {result}")
            else:
                # Record success
                self.registry.circuit_breaker.record_success(agent_id)
                self.state_store[workflow_id]["results"][agent_id] = result
                
                # Update metrics
                latency = (time.time() - phase_start) * 1000
                self._update_agent_metrics(agent_id, True, latency)
    
    async def _execute_agent_with_affinity(self, workflow_id: str, agent_id: str, 
                                          step: dict, cores: List[int], trace_id: str) -> dict:
        """Execute agent with CPU core affinity"""
        
        logger.info(f"Executing agent {agent_id} on cores {cores} [trace={trace_id}]")
        
        # Set process affinity
        if hasattr(os, 'sched_setaffinity'):
            try:
                os.sched_setaffinity(0, set(cores))
            except Exception as e:
                logger.warning(f"Could not set CPU affinity: {e}")
        
        # Mark agent as active
        self.active_agents[agent_id] = {
            "status": AgentStatus.RUNNING,
            "workflow_id": workflow_id,
            "started_at": datetime.now(),
            "cores": cores
        }
        
        try:
            # Prepare enhanced context
            context = self._prepare_enhanced_context(workflow_id, agent_id, step, trace_id)
            
            # Create enhanced message
            message = EnhancedAgentMessage(
                source_agent="ORCHESTRATOR",
                target_agents=[agent_id],
                action=step.get("action", "execute"),
                payload=step.get("parameters", {}),
                context=context,
                priority=Priority[step.get("priority", "MEDIUM")],
                hardware_affinity=self.registry.agents[agent_id].get(
                    "hardware_affinity", HardwareAffinity.AUTO
                ),
                trace_id=trace_id
            )
            
            # Add vector embedding for routing
            message.vector_embedding = self.registry.vector_engine.compute_message_embedding(message)
            
            # Execute on appropriate thread pool
            if cores[0] in self.topology.p_cores_ultra + self.topology.p_cores_standard:
                executor = self.p_core_executor
            elif cores[0] in self.topology.e_cores:
                executor = self.e_core_executor
            else:
                executor = self.lp_e_core_executor
            
            # Execute agent
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                executor,
                self._execute_agent_sync,
                agent_id,
                message
            )
            
            # Mark agent as completed
            self.active_agents[agent_id]["status"] = AgentStatus.COMPLETED
            self.active_agents[agent_id]["completed_at"] = datetime.now()
            
            return result
            
        except Exception as e:
            # Mark agent as failed
            self.active_agents[agent_id]["status"] = AgentStatus.FAILED
            self.active_agents[agent_id]["error"] = str(e)
            raise
    
    def _execute_agent_sync(self, agent_id: str, message: EnhancedAgentMessage) -> dict:
        """Synchronous agent execution (runs in thread pool)"""
        
        start_time = time.time()
        
        # Check message deduplication
        msg_hash = message.compute_hash()
        if msg_hash in self.processed_messages:
            logger.info(f"Skipping duplicate message {msg_hash}")
            return self.message_cache.get(msg_hash, {})
        
        # Simulate actual agent execution
        # In production, this would call the actual agent implementation
        time.sleep(0.1)  # Simulate work
        
        result = {
            "agent_id": agent_id,
            "status": "success",
            "output": f"Processed by {agent_id}",
            "trace_id": message.trace_id,
            "metrics": {
                "duration_ms": (time.time() - start_time) * 1000,
                "cpu_usage": psutil.cpu_percent(),
                "memory_mb": psutil.Process().memory_info().rss / 1024 / 1024
            }
        }
        
        # Cache result
        self.processed_messages.add(msg_hash)
        self.message_cache[msg_hash] = result
        
        return result
    
    def _prepare_enhanced_context(self, workflow_id: str, agent_id: str, 
                                 step: dict, trace_id: str) -> dict:
        """Prepare enhanced execution context"""
        
        context = {
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "step_name": step.get("name", ""),
            "trace_id": trace_id,
            "dependencies_results": {},
            "performance_hints": {},
            "hardware_info": {
                "cpu_count": psutil.cpu_count(),
                "memory_available_mb": psutil.virtual_memory().available / 1024 / 1024,
                "load_average": os.getloadavg()
            }
        }
        
        # Include results from dependencies
        agent_config = self.registry.get_agent_config(agent_id)
        for dependency in agent_config.get("dependencies", []):
            if dependency in self.state_store[workflow_id]["results"]:
                context["dependencies_results"][dependency] = \
                    self.state_store[workflow_id]["results"][dependency]
        
        # Add performance hints based on historical data
        metrics = self.registry.performance_metrics[agent_id]
        context["performance_hints"] = {
            "expected_duration_ms": metrics.get("avg_latency_ms", 1000),
            "success_rate": metrics.get("successful_executions", 0) / 
                           max(metrics.get("total_executions", 1), 1)
        }
        
        return context
    
    def _update_agent_metrics(self, agent_id: str, success: bool, latency_ms: float):
        """Update agent performance metrics"""
        
        metrics = self.registry.performance_metrics[agent_id]
        
        metrics["total_executions"] += 1
        if success:
            metrics["successful_executions"] += 1
        else:
            metrics["failed_executions"] += 1
        
        metrics["total_latency_ms"] += latency_ms
        metrics["avg_latency_ms"] = metrics["total_latency_ms"] / metrics["total_executions"]
        metrics["last_execution"] = datetime.now()
        
        # Update latency histogram
        self.latency_histogram[agent_id].append(latency_ms)
        
        # Calculate P99
        if len(self.latency_histogram[agent_id]) >= 100:
            sorted_latencies = sorted(self.latency_histogram[agent_id])
            p99_index = int(len(sorted_latencies) * 0.99)
            metrics["p99_latency_ms"] = sorted_latencies[p99_index]
    
    def _find_step_for_agent(self, workflow: dict, agent_id: str) -> Optional[dict]:
        """Find workflow step for specific agent"""
        for step in workflow.get("steps", []):
            if agent_id in step.get("agents", []):
                return step
        return None
    
    def _extract_required_agents(self, workflow: dict) -> List[str]:
        """Extract all required agents from workflow"""
        agents = set()
        
        for step in workflow.get("steps", []):
            agents.update(step.get("agents", []))
        
        return list(agents)
    
    async def get_system_metrics(self) -> Dict[str, Any]:
        """Get comprehensive system metrics"""
        
        return {
            "timestamp": datetime.now().isoformat(),
            "active_workflows": len([s for s in self.state_store.values() 
                                    if s["status"] == "running"]),
            "active_agents": len([a for a in self.active_agents.values() 
                                if a["status"] == AgentStatus.RUNNING]),
            "message_queue_size": self.message_queue.qsize(),
            "cpu_usage": {
                "p_cores": [psutil.cpu_percent(percpu=True)[i] 
                          for i in self.topology.p_cores_standard + self.topology.p_cores_ultra],
                "e_cores": [psutil.cpu_percent(percpu=True)[i] 
                          for i in self.topology.e_cores],
                "lp_e_cores": [psutil.cpu_percent(percpu=True)[i] 
                             for i in self.topology.lp_e_cores]
            },
            "memory": {
                "total_mb": psutil.virtual_memory().total / 1024 / 1024,
                "available_mb": psutil.virtual_memory().available / 1024 / 1024,
                "percent": psutil.virtual_memory().percent
            },
            "agent_health": {
                agent_id: self.registry.get_agent_health(agent_id)
                for agent_id in self.registry.agents.keys()
            }
        }


# Example usage
async def main():
    """Example workflow execution with enhanced features"""
    
    # Initialize enhanced orchestrator
    orchestrator = EnhancedAgentOrchestrator()
    
    # Define a complex workflow
    workflow = {
        "name": "Full Stack ML Application",
        "description": "Build ML-powered application with optimization",
        "steps": [
            {
                "name": "Architecture Design",
                "agents": ["DIRECTOR", "ARCHITECT", "DATABASE", "API_DESIGNER"],
                "action": "design",
                "parameters": {
                    "requirements": "Real-time ML inference system",
                    "scale": "100k requests/sec",
                    "latency_target": "50ms p99"
                },
                "priority": "CRITICAL"
            },
            {
                "name": "ML Pipeline",
                "agents": ["ML_OPS", "PYTHON_INTERNAL", "OPTIMIZER"],
                "action": "implement_ml",
                "parameters": {
                    "model": "transformer",
                    "optimization": "quantization",
                    "hardware": "meteor_lake"
                },
                "priority": "HIGH"
            },
            {
                "name": "Performance Optimization",
                "agents": ["C_INTERNAL", "OPTIMIZER"],
                "action": "optimize",
                "parameters": {
                    "target": "latency",
                    "use_avx512": True,
                    "use_npu": True
                },
                "priority": "CRITICAL"
            },
            {
                "name": "Security Validation",
                "agents": ["SECURITY", "TESTBED"],
                "action": "validate",
                "parameters": {
                    "compliance": ["SOC2", "GDPR"],
                    "penetration_test": True
                },
                "priority": "HIGH"
            },
            {
                "name": "Deployment",
                "agents": ["PACKAGER", "DEPLOYER", "MONITOR"],
                "action": "deploy",
                "parameters": {
                    "environment": "production",
                    "strategy": "canary",
                    "rollback_threshold": 0.01
                },
                "priority": "MEDIUM"
            }
        ]
    }
    
    # Execute workflow with tracing
    trace_id = str(uuid.uuid4())
    
    try:
        result = await orchestrator.execute_workflow(workflow, trace_id)
        
        print(f"Workflow completed successfully!")
        print(f"Trace ID: {trace_id}")
        print(f"Duration: {result['metrics']['total_duration_s']:.2f} seconds")
        print(f"Agents executed: {result['metrics']['completed_agents']}")
        
        # Get system metrics
        metrics = await orchestrator.get_system_metrics()
        print(f"\nSystem Metrics:")
        print(f"CPU Usage - P-cores: {np.mean(metrics['cpu_usage']['p_cores']):.1f}%")
        print(f"CPU Usage - E-cores: {np.mean(metrics['cpu_usage']['e_cores']):.1f}%")
        print(f"Memory Available: {metrics['memory']['available_mb']:.0f} MB")
        
    except Exception as e:
        print(f"Workflow failed: {e}")


if __name__ == "__main__":
    # Set up multiprocessing for Meteor Lake
    mp.set_start_method('spawn', force=True)
    
    # Run the example
    asyncio.run(main())
