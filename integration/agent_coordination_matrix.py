#!/usr/bin/env python3
"""
Intelligent Agent Coordination Matrix v3.1
Manages agent invocation, parallel execution, and performance optimization
"""

import asyncio
import concurrent.futures
import json
import logging
import os
import subprocess
import sys
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import asyncpg

# Add project root to Python path for imports
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

try:
    from path_utilities import get_agents_dir
except ImportError:
    # Fallback if path_utilities not available
    def get_agents_dir():
        return Path(__file__).parent / "agents"


logger = logging.getLogger(__name__)


class ExecutionMode(Enum):
    """Agent execution modes"""

    PARALLEL = "parallel"
    SEQUENTIAL = "sequential"
    REDUNDANT = "redundant"
    CONSENSUS = "consensus"
    FASTEST = "fastest"
    MOST_RELIABLE = "most_reliable"


class AgentCapability(Enum):
    """Agent capability categories"""

    STRATEGIC = "strategic"
    SECURITY = "security"
    DEVELOPMENT = "development"
    TESTING = "testing"
    DEPLOYMENT = "deployment"
    MONITORING = "monitoring"
    ANALYSIS = "analysis"
    COORDINATION = "coordination"


@dataclass
class AgentSpec:
    """Agent specification and metadata"""

    name: str
    capabilities: Set[AgentCapability]
    priority: int = 50  # 1-100, higher = more priority
    reliability_score: float = 0.95  # 0-1
    avg_execution_time: float = 1000  # milliseconds
    specializations: Set[str] = field(default_factory=set)
    dependencies: Set[str] = field(default_factory=set)
    parallelizable: bool = True


@dataclass
class CoordinationPlan:
    """Execution plan for multi-agent coordination"""

    session_id: str
    primary_agents: List[str]
    supporting_agents: List[str]
    execution_mode: ExecutionMode
    estimated_duration: float
    success_probability: float
    parallel_groups: List[List[str]] = field(default_factory=list)


class AgentCoordinationMatrix:
    """Intelligent agent coordination and execution management"""

    def __init__(self, db_connection_string: str = None):
        self.db_connection_string = (
            db_connection_string
            or "postgresql://claude_agent:claude_secure_password@localhost:5433/claude_agents_auth"
        )
        self.db_pool: Optional[asyncpg.pool.Pool] = None
        self.agent_registry: Dict[str, AgentSpec] = {}
        self.load_agent_registry()

    def load_agent_registry(self):
        """Load agent registry from file system"""
        agents_dir = Path(__file__).parent / "agents"
        if not agents_dir.exists():
            agents_dir = get_agents_dir()

        # Strategic agents
        self.agent_registry.update(
            {
                "DIRECTOR": AgentSpec(
                    name="DIRECTOR",
                    capabilities={
                        AgentCapability.STRATEGIC,
                        AgentCapability.COORDINATION,
                    },
                    priority=95,
                    specializations={"planning", "strategy", "leadership"},
                ),
                "PROJECTORCHESTRATOR": AgentSpec(
                    name="PROJECTORCHESTRATOR",
                    capabilities={
                        AgentCapability.COORDINATION,
                        AgentCapability.STRATEGIC,
                    },
                    priority=90,
                    specializations={"coordination", "tactical", "execution"},
                ),
            }
        )

        # Security agents
        security_agents = [
            "SECURITY",
            "BASTION",
            "SECURITYCHAOSAGENT",
            "SECURITYAUDITOR",
            "CSO",
            "CRYPTOEXPERT",
            "QUANTUMGUARD",
            "REDTEAMORCHESTRATOR",
            "APT41-DEFENSE-AGENT",
            "NSA",
            "PSYOPS-AGENT",
            "GHOST-PROTOCOL-AGENT",
        ]
        for agent in security_agents:
            self.agent_registry[agent] = AgentSpec(
                name=agent,
                capabilities={AgentCapability.SECURITY},
                priority=85,
                specializations={"security", "audit", "defense"},
            )

        # Development agents
        dev_agents = [
            "ARCHITECT",
            "CONSTRUCTOR",
            "PATCHER",
            "DEBUGGER",
            "TESTBED",
            "LINTER",
            "OPTIMIZER",
            "QADIRECTOR",
        ]
        for agent in dev_agents:
            self.agent_registry[agent] = AgentSpec(
                name=agent,
                capabilities={AgentCapability.DEVELOPMENT},
                priority=75,
                specializations={"development", "engineering", "code"},
            )

        # Language specialists
        lang_agents = [
            "C-INTERNAL",
            "PYTHON-INTERNAL",
            "RUST-INTERNAL-AGENT",
            "GO-INTERNAL-AGENT",
            "JAVA-INTERNAL-AGENT",
            "TYPESCRIPT-INTERNAL-AGENT",
        ]
        for agent in lang_agents:
            self.agent_registry[agent] = AgentSpec(
                name=agent,
                capabilities={AgentCapability.DEVELOPMENT},
                priority=70,
                specializations={"programming", "language-specific"},
                parallelizable=True,
            )

    async def initialize(self):
        """Initialize database connection and load historical performance data"""
        try:
            self.db_pool = await asyncpg.create_pool(
                self.db_connection_string, min_size=2, max_size=10
            )
            await self.update_agent_performance_metrics()
            logger.info("Agent coordination matrix initialized")
        except Exception as e:
            logger.error(f"Failed to initialize coordination matrix: {e}")

    async def update_agent_performance_metrics(self):
        """Update agent performance metrics from database"""
        if not self.db_pool:
            return

        try:
            async with self.db_pool.acquire() as conn:
                performance_data = await conn.fetch(
                    """
                    SELECT agent_name,
                           AVG(duration_ms) as avg_duration,
                           AVG(success_score) as reliability_score,
                           COUNT(*) as execution_count
                    FROM learning.agent_metrics
                    WHERE status != 'started' 
                      AND execution_start >= NOW() - INTERVAL '7 days'
                    GROUP BY agent_name
                """
                )

                for row in performance_data:
                    agent_name = row["agent_name"]
                    if agent_name in self.agent_registry:
                        spec = self.agent_registry[agent_name]
                        spec.avg_execution_time = (
                            float(row["avg_duration"]) if row["avg_duration"] else 1000
                        )
                        spec.reliability_score = (
                            float(row["reliability_score"])
                            if row["reliability_score"]
                            else 0.95
                        )

                logger.info(
                    f"Updated performance metrics for {len(performance_data)} agents"
                )

        except Exception as e:
            logger.error(f"Failed to update performance metrics: {e}")

    def analyze_task_requirements(self, task_description: str) -> Set[AgentCapability]:
        """Analyze task to determine required agent capabilities"""
        task_lower = task_description.lower()
        capabilities = set()

        # Keyword mapping to capabilities
        keyword_mapping = {
            AgentCapability.SECURITY: [
                "security",
                "audit",
                "vulnerability",
                "threat",
                "crypto",
                "authentication",
                "authorization",
                "penetration",
                "compliance",
            ],
            AgentCapability.DEVELOPMENT: [
                "code",
                "develop",
                "implement",
                "build",
                "create",
                "program",
                "refactor",
                "debug",
                "fix",
                "architecture",
                "design",
            ],
            AgentCapability.TESTING: [
                "test",
                "validate",
                "verify",
                "quality",
                "qa",
                "coverage",
                "unit test",
                "integration",
                "regression",
            ],
            AgentCapability.DEPLOYMENT: [
                "deploy",
                "release",
                "package",
                "distribution",
                "container",
                "docker",
                "kubernetes",
                "infrastructure",
            ],
            AgentCapability.MONITORING: [
                "monitor",
                "observe",
                "metrics",
                "logging",
                "performance",
                "health",
                "alerting",
                "dashboard",
            ],
            AgentCapability.STRATEGIC: [
                "plan",
                "strategy",
                "roadmap",
                "coordinate",
                "manage",
                "organize",
                "lead",
                "direct",
            ],
        }

        for capability, keywords in keyword_mapping.items():
            if any(keyword in task_lower for keyword in keywords):
                capabilities.add(capability)

        # Default to development if no clear capability detected
        if not capabilities:
            capabilities.add(AgentCapability.DEVELOPMENT)

        return capabilities

    def select_optimal_agents(
        self,
        required_capabilities: Set[AgentCapability],
        max_agents: int = 5,
        execution_mode: ExecutionMode = ExecutionMode.PARALLEL,
    ) -> List[str]:
        """Select optimal agents based on capabilities and performance"""

        candidate_agents = []

        # Score agents based on capability match and performance
        for agent_name, spec in self.agent_registry.items():
            if not required_capabilities.intersection(spec.capabilities):
                continue

            capability_score = len(
                required_capabilities.intersection(spec.capabilities)
            ) / len(required_capabilities)
            performance_score = (spec.reliability_score * 0.6) + (
                (100 - spec.priority) / 100 * 0.4
            )

            # Adjust for execution time if parallel execution
            time_penalty = 0
            if (
                execution_mode == ExecutionMode.PARALLEL
                and spec.avg_execution_time > 5000
            ):
                time_penalty = 0.1

            total_score = (
                (capability_score * 0.5) + (performance_score * 0.5) - time_penalty
            )

            candidate_agents.append((agent_name, total_score, spec))

        # Sort by score and select top agents
        candidate_agents.sort(key=lambda x: x[1], reverse=True)
        selected_agents = [agent[0] for agent in candidate_agents[:max_agents]]

        return selected_agents

    def create_coordination_plan(
        self,
        task_description: str,
        execution_mode: ExecutionMode = ExecutionMode.PARALLEL,
    ) -> CoordinationPlan:
        """Create comprehensive coordination plan for task execution"""

        # Analyze task requirements
        required_capabilities = self.analyze_task_requirements(task_description)

        # Always include coordination agents for complex tasks
        if len(required_capabilities) > 1:
            coordination_agents = ["DIRECTOR", "PROJECTORCHESTRATOR"]
        else:
            coordination_agents = []

        # Select primary agents
        primary_agents = self.select_optimal_agents(
            required_capabilities,
            max_agents=3 if coordination_agents else 5,
            execution_mode=execution_mode,
        )

        # Create parallel execution groups
        parallel_groups = []
        if execution_mode == ExecutionMode.PARALLEL:
            # Group agents by capability for parallel execution
            capability_groups = {}
            for agent in primary_agents:
                spec = self.agent_registry[agent]
                for cap in spec.capabilities:
                    if cap not in capability_groups:
                        capability_groups[cap] = []
                    capability_groups[cap].append(agent)

            parallel_groups = list(capability_groups.values())

        # Estimate execution time and success probability
        if primary_agents:
            avg_times = [
                self.agent_registry[agent].avg_execution_time
                for agent in primary_agents
            ]
            avg_reliability = [
                self.agent_registry[agent].reliability_score for agent in primary_agents
            ]

            if execution_mode == ExecutionMode.PARALLEL:
                estimated_duration = max(avg_times)  # Limited by slowest agent
            else:
                estimated_duration = sum(avg_times)  # Sum of all agents

            success_probability = min(avg_reliability) * 0.9  # Conservative estimate
        else:
            estimated_duration = 5000
            success_probability = 0.8

        return CoordinationPlan(
            session_id=str(uuid.uuid4()),
            primary_agents=coordination_agents + primary_agents,
            supporting_agents=[],
            execution_mode=execution_mode,
            estimated_duration=estimated_duration,
            success_probability=success_probability,
            parallel_groups=parallel_groups,
        )

    async def execute_coordination_plan(
        self, plan: CoordinationPlan, task_description: str
    ) -> Dict[str, Any]:
        """Execute coordination plan with specified agents"""
        results = {}
        start_time = datetime.utcnow()

        try:
            if plan.execution_mode == ExecutionMode.PARALLEL and plan.parallel_groups:
                # Execute parallel groups
                for group_idx, agent_group in enumerate(plan.parallel_groups):
                    group_results = await self._execute_agent_group_parallel(
                        agent_group,
                        task_description,
                        f"{plan.session_id}-group-{group_idx}",
                    )
                    results.update(group_results)
            else:
                # Sequential execution
                for agent in plan.primary_agents:
                    agent_result = await self._execute_single_agent(
                        agent, task_description, f"{plan.session_id}-{agent}"
                    )
                    results[agent] = agent_result

            # Calculate overall success
            successful_agents = sum(
                1 for result in results.values() if result.get("success", False)
            )
            overall_success = successful_agents / len(results) if results else 0

            # Log coordination results
            await self._log_coordination_results(plan, results, overall_success)

            return {
                "session_id": plan.session_id,
                "success": overall_success > 0.5,
                "results": results,
                "execution_time": (datetime.utcnow() - start_time).total_seconds()
                * 1000,
                "agents_executed": list(results.keys()),
            }

        except Exception as e:
            logger.error(f"Coordination plan execution failed: {e}")
            return {
                "session_id": plan.session_id,
                "success": False,
                "error": str(e),
                "results": results,
            }

    async def _execute_agent_group_parallel(
        self, agents: List[str], task: str, session_id: str
    ) -> Dict[str, Any]:
        """Execute group of agents in parallel"""
        tasks = []
        for agent in agents:
            task_coro = self._execute_single_agent(agent, task, f"{session_id}-{agent}")
            tasks.append(task_coro)

        results = await asyncio.gather(*tasks, return_exceptions=True)

        agent_results = {}
        for agent, result in zip(agents, results):
            if isinstance(result, Exception):
                agent_results[agent] = {"success": False, "error": str(result)}
            else:
                agent_results[agent] = result

        return agent_results

    async def _execute_single_agent(
        self, agent_name: str, task: str, session_id: str
    ) -> Dict[str, Any]:
        """Execute single agent with task"""
        start_time = datetime.utcnow()

        try:
            # Use claude-agent command to invoke agent
            cmd = ["claude-agent", agent_name.lower().replace("-", ""), task]

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                timeout=30,  # 30 second timeout
            )

            stdout, stderr = await process.communicate()

            success = process.returncode == 0
            duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000

            # Log to database
            if self.db_pool:
                try:
                    async with self.db_pool.acquire() as conn:
                        await conn.execute(
                            """
                            INSERT INTO learning.agent_metrics 
                            (agent_name, session_id, execution_start, execution_end, 
                             duration_ms, status, success_score, execution_context)
                            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                        """,
                            agent_name,
                            session_id,
                            start_time,
                            datetime.utcnow(),
                            int(duration_ms),
                            "completed" if success else "failed",
                            1.0 if success else 0.0,
                            json.dumps({"task": task}),
                        )
                except Exception as db_error:
                    logger.warning(f"Failed to log agent execution: {db_error}")

            return {
                "success": success,
                "duration_ms": duration_ms,
                "stdout": stdout.decode() if stdout else "",
                "stderr": stderr.decode() if stderr else "",
                "returncode": process.returncode,
            }

        except asyncio.TimeoutError:
            return {
                "success": False,
                "error": "Agent execution timeout",
                "duration_ms": 30000,
            }
        except Exception as e:
            return {"success": False, "error": str(e), "duration_ms": 0}

    async def _log_coordination_results(
        self, plan: CoordinationPlan, results: Dict[str, Any], success_rate: float
    ):
        """Log coordination results to database"""
        if not self.db_pool:
            return

        try:
            async with self.db_pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO learning.interaction_logs
                    (source_agent, target_agent, message_type, payload, timestamp)
                    VALUES ('PROJECTORCHESTRATOR', $1, 'coordination_plan', $2, $3)
                """,
                    ",".join(plan.primary_agents),
                    json.dumps(
                        {
                            "session_id": plan.session_id,
                            "execution_mode": plan.execution_mode.value,
                            "agents": plan.primary_agents,
                            "success_rate": success_rate,
                            "results_summary": {
                                agent: {
                                    "success": result.get("success"),
                                    "duration": result.get("duration_ms"),
                                }
                                for agent, result in results.items()
                            },
                        }
                    ),
                    datetime.utcnow(),
                )
        except Exception as e:
            logger.error(f"Failed to log coordination results: {e}")


# Global coordination matrix instance
coordination_matrix = AgentCoordinationMatrix()


async def coordinate_agents(
    task_description: str, execution_mode: str = "parallel"
) -> Dict[str, Any]:
    """Main coordination interface"""
    await coordination_matrix.initialize()

    mode_map = {
        "parallel": ExecutionMode.PARALLEL,
        "sequential": ExecutionMode.SEQUENTIAL,
        "redundant": ExecutionMode.REDUNDANT,
        "consensus": ExecutionMode.CONSENSUS,
    }

    exec_mode = mode_map.get(execution_mode.lower(), ExecutionMode.PARALLEL)

    plan = coordination_matrix.create_coordination_plan(task_description, exec_mode)
    results = await coordination_matrix.execute_coordination_plan(
        plan, task_description
    )

    return results


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        task = " ".join(sys.argv[1:])
        results = asyncio.run(coordinate_agents(task))
        print(json.dumps(results, indent=2))
