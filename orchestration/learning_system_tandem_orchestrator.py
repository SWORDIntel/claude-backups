#!/usr/bin/env python3
"""
Learning System Tandem Orchestrator
Coordinates parallel execution of learning system setup tasks
Uses production_orchestrator for efficient multi-agent coordination
"""

import asyncio
import sys
import os
import time
from pathlib import Path
from typing import Dict, Any, List
from dataclasses import dataclass
from enum import Enum
import logging
import json
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent.parent / "agents" / "src" / "python"))

try:
    # Try direct import first (production_orchestrator.py exists in agents/src/python)
    from production_orchestrator import (
        ProductionOrchestrator,
        CommandSet,
        CommandStep,
        ExecutionMode
    )
    ORCHESTRATOR_AVAILABLE = True
except ImportError as e:
    ORCHESTRATOR_AVAILABLE = False
    print(f"Warning: Production orchestrator import failed: {e}")
    print("Using sequential execution mode")

# Always define ExecutionResult (not exported by production_orchestrator)
@dataclass
class ExecutionResult:
    success: bool
    agent: str
    action: str
    result: Dict[str, Any]
    execution_time: float = 0.0

if not ORCHESTRATOR_AVAILABLE:
    # Create fallback classes only if orchestrator unavailable
    
    @dataclass 
    class CommandStep:
        agent: str
        action: str
        params: Dict[str, Any]
        timeout: int = 60
    
    class ExecutionMode:
        PARALLEL = "parallel"
        SEQUENTIAL = "sequential"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TaskPriority(Enum):
    CRITICAL = 1
    HIGH = 2
    MEDIUM = 3
    LOW = 4

@dataclass
class LearningSystemTask:
    name: str
    agent: str
    action: str
    params: Dict[str, Any]
    priority: TaskPriority
    dependencies: List[str] = None
    estimated_time: int = 60  # seconds

class LearningSystemOrchestrator:
    """Orchestrates learning system setup using parallel execution"""
    
    def __init__(self):
        self.orchestrator = ProductionOrchestrator() if ORCHESTRATOR_AVAILABLE else None
        self.tasks_completed = set()
        self.tasks_in_progress = set()
        self.results = {}
        
    async def initialize(self):
        """Initialize the orchestrator"""
        if self.orchestrator:
            await self.orchestrator.initialize()
            logger.info("Tandem orchestrator initialized")
        else:
            logger.warning("Running without tandem orchestrator")
    
    def create_learning_system_tasks(self) -> List[LearningSystemTask]:
        """Create all tasks for learning system setup"""
        tasks = [
            # Track 1: Docker Infrastructure (DOCKER-AGENT)
            LearningSystemTask(
                name="fix_docker_volumes",
                agent="docker",
                action="fix_volume_mounts",
                params={
                    "file": "docker-compose.yml",
                    "fixes": {
                        "learning-system": {
                            "volumes": ["./agents/src/python:/app/learning:ro"]
                        }
                    }
                },
                priority=TaskPriority.CRITICAL,
                estimated_time=30
            ),
            
            LearningSystemTask(
                name="update_dockerfile_learning",
                agent="docker",
                action="update_dockerfile",
                params={
                    "file": "database/docker/Dockerfile.learning",
                    "updates": {
                        "cmd": ["python", "/app/learning_api_server.py"],
                        "env": {"PYTHONPATH": "/app:/app/learning"}
                    }
                },
                priority=TaskPriority.HIGH,
                dependencies=["fix_docker_volumes"],
                estimated_time=30
            ),
            
            LearningSystemTask(
                name="build_containers",
                agent="docker",
                action="build_and_test",
                params={
                    "services": ["postgres", "learning-system", "agent-bridge"],
                    "sequential": True
                },
                priority=TaskPriority.HIGH,
                dependencies=["update_dockerfile_learning"],
                estimated_time=180
            ),
            
            # Track 2: API Development (APIDESIGNER)
            LearningSystemTask(
                name="design_api_spec",
                agent="apidesigner",
                action="create_openapi_spec",
                params={
                    "service": "learning-system",
                    "endpoints": [
                        "/health",
                        "/agent/performance",
                        "/agent/{agent_id}/recommendations",
                        "/task/recommend",
                        "/analytics/dashboard",
                        "/model/retrain"
                    ],
                    "output": "database/docker/openapi_spec.yaml"
                },
                priority=TaskPriority.MEDIUM,
                estimated_time=60
            ),
            
            LearningSystemTask(
                name="implement_api_wrapper",
                agent="apidesigner",
                action="implement_fastapi",
                params={
                    "spec": "database/docker/openapi_spec.yaml",
                    "output": "database/docker/learning_api_server.py",
                    "existing": True
                },
                priority=TaskPriority.HIGH,
                dependencies=["design_api_spec"],
                estimated_time=90
            ),
            
            # Track 3: Python Integration (PYTHON-INTERNAL)
            LearningSystemTask(
                name="setup_python_env",
                agent="python-internal",
                action="setup_environment",
                params={
                    "requirements": [
                        "fastapi>=0.104.0",
                        "uvicorn>=0.24.0",
                        "psycopg2-binary>=2.9.9",
                        "asyncpg>=0.29.0",
                        "scikit-learn>=1.3.0",
                        "numpy>=1.24.0",
                        "pandas>=2.0.0",
                        "joblib>=1.3.0",
                        "prometheus-client>=0.18.0"
                    ],
                    "venv_path": "agents/src/python/venv_learning"
                },
                priority=TaskPriority.CRITICAL,
                estimated_time=120
            ),
            
            LearningSystemTask(
                name="validate_imports",
                agent="python-internal",
                action="validate_modules",
                params={
                    "modules": [
                        "postgresql_learning_system",
                        "learning_orchestrator_bridge",
                        "learning_api_server",
                        "ml_pipeline_config"
                    ],
                    "path": "/app/learning"
                },
                priority=TaskPriority.HIGH,
                dependencies=["setup_python_env"],
                estimated_time=30
            ),
            
            # Track 4: ML Pipeline (MLOPS)
            LearningSystemTask(
                name="configure_ml_pipeline",
                agent="mlops",
                action="setup_pipeline",
                params={
                    "config_file": "database/docker/ml_pipeline_config.py",
                    "models": [
                        "agent_selector",
                        "performance_predictor",
                        "task_classifier",
                        "anomaly_detector",
                        "embedding_generator"
                    ]
                },
                priority=TaskPriority.MEDIUM,
                estimated_time=90
            ),
            
            LearningSystemTask(
                name="setup_continuous_training",
                agent="mlops",
                action="configure_training",
                params={
                    "schedule": "hourly",
                    "data_source": "postgresql://claude_auth",
                    "model_storage": "/app/data/models",
                    "monitoring": True
                },
                priority=TaskPriority.MEDIUM,
                dependencies=["configure_ml_pipeline"],
                estimated_time=60
            ),
            
            # Track 5: Project Setup (CONSTRUCTOR)
            LearningSystemTask(
                name="create_directory_structure",
                agent="constructor",
                action="setup_directories",
                params={
                    "directories": [
                        "database/data/models",
                        "database/data/training",
                        "database/data/checkpoints",
                        "logs/learning",
                        "logs/ml_pipeline",
                        "config/learning"
                    ]
                },
                priority=TaskPriority.HIGH,
                estimated_time=20
            ),
            
            LearningSystemTask(
                name="generate_config_files",
                agent="constructor",
                action="create_configs",
                params={
                    "configs": {
                        "config/learning/ml_pipeline.json": "ml_pipeline_config",
                        "config/learning/learning_system.yaml": "learning_system_config",
                        "database/docker/config/prometheus.yml": "prometheus_config"
                    }
                },
                priority=TaskPriority.MEDIUM,
                dependencies=["create_directory_structure"],
                estimated_time=30
            )
        ]
        
        return tasks
    
    async def execute_task(self, task: LearningSystemTask) -> ExecutionResult:
        """Execute a single task"""
        logger.info(f"Executing task: {task.name} with agent: {task.agent}")
        
        if self.orchestrator:
            # Use tandem orchestrator for parallel execution
            step = CommandStep(
                agent=task.agent,
                action=task.action,
                params=task.params,
                timeout=task.estimated_time
            )
            
            result = await self.orchestrator.execute_step(step)
            return result
        else:
            # Fallback to mock execution
            await asyncio.sleep(min(task.estimated_time / 10, 2))
            return ExecutionResult(
                success=True,
                agent=task.agent,
                action=task.action,
                result={"status": "completed", "mock": True},
                execution_time=task.estimated_time / 10
            )
    
    async def execute_parallel_tasks(self, tasks: List[LearningSystemTask]) -> Dict[str, Any]:
        """Execute tasks in parallel based on dependencies"""
        
        # Group tasks by priority and dependencies
        priority_groups = defaultdict(list)
        for task in tasks:
            if not task.dependencies or all(dep in self.tasks_completed for dep in task.dependencies):
                priority_groups[task.priority].append(task)
        
        results = {}
        
        # Execute tasks in priority order
        for priority in sorted(priority_groups.keys(), key=lambda x: x.value):
            group_tasks = priority_groups[priority]
            
            if group_tasks:
                logger.info(f"Executing {len(group_tasks)} tasks at priority {priority.name}")
                
                # Execute tasks in parallel within same priority
                if self.orchestrator and len(group_tasks) > 1:
                    # Create command set for parallel execution
                    command_set = CommandSet(
                        name=f"Priority_{priority.name}_Tasks",
                        mode=ExecutionMode.PARALLEL,
                        steps=[
                            CommandStep(
                                agent=task.agent,
                                action=task.action,
                                params=task.params,
                                timeout=task.estimated_time
                            )
                            for task in group_tasks
                        ]
                    )
                    
                    set_result = await self.orchestrator.execute_command_set(command_set)
                    
                    for task, result in zip(group_tasks, set_result.step_results):
                        results[task.name] = result
                        self.tasks_completed.add(task.name)
                else:
                    # Sequential execution for single task or no orchestrator
                    for task in group_tasks:
                        result = await self.execute_task(task)
                        results[task.name] = result
                        self.tasks_completed.add(task.name)
        
        return results
    
    async def run_complete_setup(self) -> Dict[str, Any]:
        """Run complete learning system setup with parallel execution"""
        
        await self.initialize()
        
        all_tasks = self.create_learning_system_tasks()
        logger.info(f"Created {len(all_tasks)} tasks for learning system setup")
        
        # Separate into parallel tracks
        tracks = {
            "docker": [],
            "api": [],
            "python": [],
            "mlops": [],
            "constructor": []
        }
        
        for task in all_tasks:
            if task.agent == "docker":
                tracks["docker"].append(task)
            elif task.agent == "apidesigner":
                tracks["api"].append(task)
            elif task.agent == "python-internal":
                tracks["python"].append(task)
            elif task.agent == "mlops":
                tracks["mlops"].append(task)
            elif task.agent == "constructor":
                tracks["constructor"].append(task)
        
        # Execute tracks in parallel where possible
        results = {}
        start_time = time.time()
        
        # Phase 1: Critical setup tasks (parallel)
        critical_tasks = [t for t in all_tasks if t.priority == TaskPriority.CRITICAL]
        if critical_tasks:
            logger.info(f"Phase 1: Executing {len(critical_tasks)} critical tasks")
            phase1_results = await self.execute_parallel_tasks(critical_tasks)
            results.update(phase1_results)
        
        # Phase 2: High priority tasks (parallel)
        high_tasks = [t for t in all_tasks if t.priority == TaskPriority.HIGH and t.name not in self.tasks_completed]
        if high_tasks:
            logger.info(f"Phase 2: Executing {len(high_tasks)} high priority tasks")
            phase2_results = await self.execute_parallel_tasks(high_tasks)
            results.update(phase2_results)
        
        # Phase 3: Medium priority tasks (parallel)
        medium_tasks = [t for t in all_tasks if t.priority == TaskPriority.MEDIUM and t.name not in self.tasks_completed]
        if medium_tasks:
            logger.info(f"Phase 3: Executing {len(medium_tasks)} medium priority tasks")
            phase3_results = await self.execute_parallel_tasks(medium_tasks)
            results.update(phase3_results)
        
        # Phase 4: Low priority tasks
        low_tasks = [t for t in all_tasks if t.priority == TaskPriority.LOW and t.name not in self.tasks_completed]
        if low_tasks:
            logger.info(f"Phase 4: Executing {len(low_tasks)} low priority tasks")
            phase4_results = await self.execute_parallel_tasks(low_tasks)
            results.update(phase4_results)
        
        execution_time = time.time() - start_time
        
        # Generate summary
        summary = {
            "total_tasks": len(all_tasks),
            "completed_tasks": len(self.tasks_completed),
            "execution_time": execution_time,
            "parallel_execution": ORCHESTRATOR_AVAILABLE,
            "results": results,
            "success_rate": sum(1 for r in results.values() if r.success) / len(results) if results else 0
        }
        
        logger.info(f"Learning system setup completed in {execution_time:.2f} seconds")
        logger.info(f"Success rate: {summary['success_rate']*100:.1f}%")
        
        return summary

async def main():
    """Main entry point"""
    orchestrator = LearningSystemOrchestrator()
    
    print("=" * 60)
    print("LEARNING SYSTEM TANDEM ORCHESTRATOR")
    print("Parallel execution for maximum speed")
    print("=" * 60)
    
    try:
        results = await orchestrator.run_complete_setup()
        
        print("\n" + "=" * 60)
        print("EXECUTION SUMMARY")
        print("=" * 60)
        print(f"Total Tasks: {results['total_tasks']}")
        print(f"Completed: {results['completed_tasks']}")
        print(f"Execution Time: {results['execution_time']:.2f} seconds")
        print(f"Success Rate: {results['success_rate']*100:.1f}%")
        print(f"Parallel Mode: {results['parallel_execution']}")
        
        # Save results
        output_path = Path("database/docker/learning_setup_results.json")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\nResults saved to: {output_path}")
        
    except Exception as e:
        logger.error(f"Setup failed: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())