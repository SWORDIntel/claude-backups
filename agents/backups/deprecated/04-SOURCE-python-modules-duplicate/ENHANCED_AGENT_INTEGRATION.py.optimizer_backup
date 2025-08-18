#!/usr/bin/env python3
"""
Enhanced Agent Integration System
Provides seamless communication and coordination between all agents
"""

import asyncio
import json
import uuid
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import networkx as nx
from collections import defaultdict
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AgentStatus(Enum):
    """Agent execution status"""
    IDLE = "idle"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    BLOCKED = "blocked"


class Priority(Enum):
    """Message priority levels"""
    CRITICAL = 1
    HIGH = 3
    MEDIUM = 5
    LOW = 7
    BACKGROUND = 10


@dataclass
class AgentMessage:
    """Standard message format for inter-agent communication"""
    message_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = field(default_factory=datetime.now)
    source_agent: str = ""
    target_agents: List[str] = field(default_factory=list)
    action: str = ""
    payload: Dict[str, Any] = field(default_factory=dict)
    context: Dict[str, Any] = field(default_factory=dict)
    priority: Priority = Priority.MEDIUM
    correlation_id: Optional[str] = None
    requires_ack: bool = False
    timeout: int = 300  # seconds


@dataclass
class AgentCapability:
    """Define agent capabilities and requirements"""
    name: str
    description: str
    input_schema: Dict[str, Any]
    output_schema: Dict[str, Any]
    required_tools: List[str]
    estimated_duration: int  # seconds
    resource_requirements: Dict[str, int]  # cpu, memory


class AgentRegistry:
    """Central registry of all available agents"""
    
    def __init__(self):
        self.agents = {}
        self.capabilities = defaultdict(list)
        self._initialize_agents()
    
    def _initialize_agents(self):
        """Initialize all known agents with their capabilities"""
        
        # Director Agent
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
                    resource_requirements={"cpu": 2, "memory": 4}
                )
            ],
            "dependencies": [],
            "color": "gold"
        })
        
        # ProjectOrchestrator Agent
        self.register_agent("PROJECT_ORCHESTRATOR", {
            "description": "Tactical cross-agent synthesis",
            "capabilities": [
                AgentCapability(
                    name="workflow_orchestration",
                    description="Coordinate agent execution workflows",
                    input_schema={"workflow": "object", "agents": "array"},
                    output_schema={"execution_plan": "object", "dependencies": "object"},
                    required_tools=["Read", "Grep", "Glob", "LS"],
                    estimated_duration=120,
                    resource_requirements={"cpu": 1, "memory": 2}
                )
            ],
            "dependencies": ["DIRECTOR"],
            "color": "cyan"
        })
        
        # Architect Agent
        self.register_agent("ARCHITECT", {
            "description": "Technical architecture specialist",
            "capabilities": [
                AgentCapability(
                    name="system_design",
                    description="Design system architecture",
                    input_schema={"requirements": "object", "constraints": "object"},
                    output_schema={"architecture": "object", "diagrams": "array"},
                    required_tools=["Read", "Write", "Edit", "WebFetch"],
                    estimated_duration=600,
                    resource_requirements={"cpu": 2, "memory": 4}
                )
            ],
            "dependencies": ["DIRECTOR"],
            "color": "red"
        })
        
        # Add all other agents...
        self._register_remaining_agents()
    
    def _register_remaining_agents(self):
        """Register remaining agents with their specifications"""
        
        agents_config = {
            "CONSTRUCTOR": {
                "description": "Project initialization specialist",
                "dependencies": ["ARCHITECT"],
                "color": "green"
            },
            "SECURITY": {
                "description": "Security analysis specialist",
                "dependencies": [],
                "color": "red",
                "veto_power": True
            },
            "TESTBED": {
                "description": "Test engineering specialist",
                "dependencies": ["CONSTRUCTOR", "PATCHER"],
                "color": "purple"
            },
            "OPTIMIZER": {
                "description": "Performance engineering specialist",
                "dependencies": ["TESTBED"],
                "color": "purple"
            },
            "DEBUGGER": {
                "description": "Failure analysis specialist",
                "dependencies": ["TESTBED"],
                "color": "yellow"
            },
            "DEPLOYER": {
                "description": "Deployment orchestration specialist",
                "dependencies": ["PACKAGER", "SECURITY"],
                "color": "purple"
            },
            "MONITOR": {
                "description": "Observability specialist",
                "dependencies": ["DEPLOYER"],
                "color": "yellow"
            },
            "DATABASE": {
                "description": "Data architecture specialist",
                "dependencies": ["ARCHITECT"],
                "color": "green"
            },
            "ML_OPS": {
                "description": "ML pipeline specialist",
                "dependencies": ["PYTHON_INTERNAL", "DATABASE"],
                "color": "magenta"
            },
            "WEB": {
                "description": "Frontend development specialist",
                "dependencies": ["API_DESIGNER"],
                "color": "blue"
            },
            "PATCHER": {
                "description": "Bug fix specialist",
                "dependencies": ["LINTER", "SECURITY"],
                "color": "default"
            },
            "LINTER": {
                "description": "Code quality specialist",
                "dependencies": ["CONSTRUCTOR"],
                "color": "green"
            },
            "DOCGEN": {
                "description": "Documentation specialist",
                "dependencies": ["API_DESIGNER", "TESTBED"],
                "color": "blue"
            },
            "PACKAGER": {
                "description": "Build automation specialist",
                "dependencies": ["TESTBED", "OPTIMIZER"],
                "color": "default"
            },
            "API_DESIGNER": {
                "description": "API design specialist",
                "dependencies": ["ARCHITECT", "DATABASE"],
                "color": "orange"
            },
            "C_INTERNAL": {
                "description": "C/C++ optimization specialist",
                "dependencies": ["ARCHITECT", "LINTER"],
                "color": "orange"
            },
            "PYTHON_INTERNAL": {
                "description": "Python optimization specialist",
                "dependencies": ["ARCHITECT", "LINTER"],
                "color": "default"
            },
            "MOBILE": {
                "description": "Mobile development specialist",
                "dependencies": ["API_DESIGNER"],
                "color": "cyan"
            },
            "PYGUI": {
                "description": "Desktop GUI specialist",
                "dependencies": ["ARCHITECT", "PYTHON_INTERNAL"],
                "color": "teal"
            }
        }
        
        for agent_name, config in agents_config.items():
            self.register_agent(agent_name, config)
    
    def register_agent(self, agent_id: str, config: dict):
        """Register an agent with its configuration"""
        self.agents[agent_id] = config
        
        # Index capabilities for quick lookup
        for capability in config.get("capabilities", []):
            self.capabilities[capability.name].append(agent_id)
    
    def get_agent_config(self, agent_id: str) -> dict:
        """Get agent configuration"""
        return self.agents.get(agent_id, {})
    
    def find_agents_with_capability(self, capability: str) -> List[str]:
        """Find agents that provide a specific capability"""
        return self.capabilities.get(capability, [])


class AgentOrchestrator:
    """Main orchestration engine for agent coordination"""
    
    def __init__(self):
        self.registry = AgentRegistry()
        self.message_queue = asyncio.Queue()
        self.state_store = {}
        self.active_agents = {}
        self.dependency_graph = self._build_dependency_graph()
        
    def _build_dependency_graph(self) -> nx.DiGraph:
        """Build dependency graph from agent registry"""
        graph = nx.DiGraph()
        
        for agent_id, config in self.registry.agents.items():
            graph.add_node(agent_id)
            for dependency in config.get("dependencies", []):
                graph.add_edge(dependency, agent_id)
        
        return graph
    
    async def execute_workflow(self, workflow: dict) -> dict:
        """Execute a complete workflow with multiple agents"""
        
        workflow_id = str(uuid.uuid4())
        logger.info(f"Starting workflow {workflow_id}: {workflow['name']}")
        
        # Initialize workflow state
        self.state_store[workflow_id] = {
            "status": "running",
            "started_at": datetime.now(),
            "completed_steps": [],
            "results": {}
        }
        
        try:
            # Determine required agents
            required_agents = self._extract_required_agents(workflow)
            
            # Calculate execution order
            execution_waves = self._calculate_execution_waves(required_agents)
            
            # Execute waves in sequence
            for wave_index, wave in enumerate(execution_waves):
                logger.info(f"Executing wave {wave_index + 1}: {wave}")
                await self._execute_wave(workflow_id, wave, workflow)
            
            # Mark workflow as completed
            self.state_store[workflow_id]["status"] = "completed"
            self.state_store[workflow_id]["completed_at"] = datetime.now()
            
            return self.state_store[workflow_id]["results"]
            
        except Exception as e:
            logger.error(f"Workflow {workflow_id} failed: {str(e)}")
            self.state_store[workflow_id]["status"] = "failed"
            self.state_store[workflow_id]["error"] = str(e)
            raise
    
    def _extract_required_agents(self, workflow: dict) -> List[str]:
        """Extract all required agents from workflow"""
        agents = set()
        
        for step in workflow.get("steps", []):
            agents.update(step.get("agents", []))
        
        return list(agents)
    
    def _calculate_execution_waves(self, agents: List[str]) -> List[List[str]]:
        """Calculate parallel execution waves based on dependencies"""
        
        # Create subgraph with only required agents
        subgraph = self.dependency_graph.subgraph(agents)
        
        # Topological sort with level extraction
        waves = []
        remaining = set(agents)
        
        while remaining:
            # Find agents with no dependencies in remaining set
            wave = [
                agent for agent in remaining
                if all(pred not in remaining 
                       for pred in subgraph.predecessors(agent))
            ]
            
            if not wave:
                # Circular dependency detected
                raise ValueError(f"Circular dependency detected among agents: {remaining}")
            
            waves.append(wave)
            remaining -= set(wave)
        
        return waves
    
    async def _execute_wave(self, workflow_id: str, agents: List[str], workflow: dict):
        """Execute a wave of agents in parallel"""
        
        tasks = []
        for agent_id in agents:
            # Find relevant step for this agent
            step = self._find_step_for_agent(workflow, agent_id)
            if step:
                task = asyncio.create_task(
                    self._execute_agent(workflow_id, agent_id, step)
                )
                tasks.append(task)
        
        # Wait for all agents in wave to complete
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Check for failures
        for agent_id, result in zip(agents, results):
            if isinstance(result, Exception):
                raise RuntimeError(f"Agent {agent_id} failed: {result}")
            
            # Store result
            self.state_store[workflow_id]["results"][agent_id] = result
    
    def _find_step_for_agent(self, workflow: dict, agent_id: str) -> Optional[dict]:
        """Find workflow step for specific agent"""
        for step in workflow.get("steps", []):
            if agent_id in step.get("agents", []):
                return step
        return None
    
    async def _execute_agent(self, workflow_id: str, agent_id: str, step: dict) -> dict:
        """Execute individual agent with monitoring"""
        
        logger.info(f"Executing agent {agent_id} for workflow {workflow_id}")
        
        # Mark agent as active
        self.active_agents[agent_id] = {
            "status": AgentStatus.RUNNING,
            "workflow_id": workflow_id,
            "started_at": datetime.now()
        }
        
        try:
            # Prepare agent context
            context = self._prepare_agent_context(workflow_id, agent_id, step)
            
            # Create agent message
            message = AgentMessage(
                source_agent="ORCHESTRATOR",
                target_agents=[agent_id],
                action=step.get("action", "execute"),
                payload=step.get("parameters", {}),
                context=context,
                priority=Priority[step.get("priority", "MEDIUM")]
            )
            
            # Send message to agent
            await self.message_queue.put(message)
            
            # Simulate agent execution (in real implementation, this would call actual agent)
            result = await self._simulate_agent_execution(agent_id, message)
            
            # Mark agent as completed
            self.active_agents[agent_id]["status"] = AgentStatus.COMPLETED
            self.active_agents[agent_id]["completed_at"] = datetime.now()
            
            return result
            
        except Exception as e:
            # Mark agent as failed
            self.active_agents[agent_id]["status"] = AgentStatus.FAILED
            self.active_agents[agent_id]["error"] = str(e)
            raise
    
    def _prepare_agent_context(self, workflow_id: str, agent_id: str, step: dict) -> dict:
        """Prepare execution context for agent"""
        
        context = {
            "workflow_id": workflow_id,
            "agent_id": agent_id,
            "step_name": step.get("name", ""),
            "dependencies_results": {}
        }
        
        # Include results from dependencies
        agent_config = self.registry.get_agent_config(agent_id)
        for dependency in agent_config.get("dependencies", []):
            if dependency in self.state_store[workflow_id]["results"]:
                context["dependencies_results"][dependency] = \
                    self.state_store[workflow_id]["results"][dependency]
        
        return context
    
    async def _simulate_agent_execution(self, agent_id: str, message: AgentMessage) -> dict:
        """Simulate agent execution (placeholder for actual implementation)"""
        
        # Simulate processing time
        agent_config = self.registry.get_agent_config(agent_id)
        await asyncio.sleep(0.1)  # Reduced for demonstration
        
        # Return simulated result
        return {
            "agent_id": agent_id,
            "status": "success",
            "output": f"Processed by {agent_id}",
            "metrics": {
                "duration": 0.1,
                "memory_used": 100
            }
        }


class AgentCommunicationBridge:
    """Bridge for enabling direct agent-to-agent communication"""
    
    def __init__(self, orchestrator: AgentOrchestrator):
        self.orchestrator = orchestrator
        self.callbacks = {}
        
    def register_callback(self, agent_id: str, callback: Callable):
        """Register callback for agent to receive messages"""
        self.callbacks[agent_id] = callback
    
    async def send_message(self, message: AgentMessage):
        """Send message to target agents"""
        
        for target in message.target_agents:
            if target in self.callbacks:
                # Direct callback invocation
                await self.callbacks[target](message)
            else:
                # Queue for orchestrator processing
                await self.orchestrator.message_queue.put(message)
    
    async def request_capability(self, capability: str, parameters: dict) -> Any:
        """Request specific capability from any available agent"""
        
        # Find agents with capability
        capable_agents = self.orchestrator.registry.find_agents_with_capability(capability)
        
        if not capable_agents:
            raise ValueError(f"No agent found with capability: {capability}")
        
        # Select best agent (could be based on load, performance, etc.)
        selected_agent = capable_agents[0]
        
        # Create request message
        message = AgentMessage(
            source_agent="REQUESTER",
            target_agents=[selected_agent],
            action=capability,
            payload=parameters,
            requires_ack=True
        )
        
        # Send and wait for response
        await self.send_message(message)
        
        # In real implementation, would wait for actual response
        return {"agent": selected_agent, "result": "capability_executed"}


# Example usage and test workflow
async def main():
    """Example workflow execution"""
    
    # Initialize orchestrator
    orchestrator = AgentOrchestrator()
    bridge = AgentCommunicationBridge(orchestrator)
    
    # Define a complex workflow
    workflow = {
        "name": "Full Stack Application Development",
        "description": "Build complete web application with ML backend",
        "steps": [
            {
                "name": "Architecture Design",
                "agents": ["ARCHITECT", "DATABASE", "API_DESIGNER"],
                "action": "design",
                "parameters": {
                    "requirements": "E-commerce platform with recommendation engine",
                    "scale": "10000 users"
                },
                "priority": "HIGH"
            },
            {
                "name": "Implementation",
                "agents": ["CONSTRUCTOR", "WEB", "PYTHON_INTERNAL", "ML_OPS"],
                "action": "implement",
                "parameters": {
                    "framework": "React + FastAPI",
                    "ml_model": "collaborative_filtering"
                },
                "priority": "MEDIUM"
            },
            {
                "name": "Quality Assurance",
                "agents": ["LINTER", "TESTBED", "SECURITY", "OPTIMIZER"],
                "action": "validate",
                "parameters": {
                    "coverage_target": 0.85,
                    "performance_target": "100ms p99"
                },
                "priority": "HIGH"
            },
            {
                "name": "Deployment",
                "agents": ["PACKAGER", "DEPLOYER", "MONITOR"],
                "action": "deploy",
                "parameters": {
                    "environment": "production",
                    "strategy": "blue_green"
                },
                "priority": "CRITICAL"
            }
        ]
    }
    
    # Execute workflow
    try:
        results = await orchestrator.execute_workflow(workflow)
        print(f"Workflow completed successfully!")
        print(f"Results: {json.dumps(results, indent=2, default=str)}")
    except Exception as e:
        print(f"Workflow failed: {e}")
    
    # Example of direct capability request
    ml_result = await bridge.request_capability(
        "model_training",
        {"dataset": "user_interactions.csv", "algorithm": "xgboost"}
    )
    print(f"ML Training result: {ml_result}")


if __name__ == "__main__":
    asyncio.run(main())