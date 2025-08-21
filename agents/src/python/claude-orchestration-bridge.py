#!/usr/bin/env python3
"""
Enhanced Claude Code Orchestration Bridge v3.0
Advanced AI-driven orchestration with intelligent agent selection,
dynamic workflow generation, and context-aware task optimization
"""

import asyncio
import sys
import os
import json
import time
import subprocess
import re
import hashlib
from pathlib import Path
from dataclasses import dataclass, field
from typing import Dict, List, Set, Optional, Tuple, Any
from collections import defaultdict, Counter
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Add the Python orchestration system to path
SCRIPT_DIR = Path(__file__).parent
PYTHON_DIR = SCRIPT_DIR / "agents" / "src" / "python"
AGENTS_DIR = SCRIPT_DIR / "agents"
sys.path.append(str(PYTHON_DIR))

try:
    from production_orchestrator import (
        ProductionOrchestrator, StandardWorkflows, CommandSet, CommandStep, 
        CommandType, ExecutionMode, Priority
    )
    from agent_registry import get_registry
except ImportError as e:
    logger.warning(f"Python orchestration system not available: {e}")
    sys.exit(1)

# ============================================================================
# COMPREHENSIVE AGENT INTELLIGENCE SYSTEM
# ============================================================================

@dataclass
class AgentCapability:
    """Enhanced agent capability definition"""
    name: str
    domain: str
    specializations: List[str]
    dependencies: List[str] = field(default_factory=list)
    performance_score: float = 100.0
    load_factor: float = 1.0
    execution_time_avg: float = 1.0
    success_rate: float = 100.0

class IntelligentAgentRegistry:
    """Advanced agent registry with capability mapping and performance tracking"""
    
    def __init__(self):
        self.agents = self._initialize_agent_database()
        self.domain_map = self._build_domain_map()
        self.capability_graph = self._build_capability_graph()
        self.performance_history = defaultdict(list)
        
    def _initialize_agent_database(self) -> Dict[str, AgentCapability]:
        """Initialize comprehensive agent database with capabilities"""
        agents = {
            # === ARCHITECTURE & DESIGN ===
            "ARCHITECT": AgentCapability(
                name="ARCHITECT", domain="architecture",
                specializations=["system_design", "architecture_patterns", "scalability", "design_decisions"],
                dependencies=["DIRECTOR"], performance_score=95.0
            ),
            "DIRECTOR": AgentCapability(
                name="DIRECTOR", domain="management",
                specializations=["project_leadership", "strategic_planning", "coordination", "decision_making"],
                performance_score=90.0
            ),
            "PLANNER": AgentCapability(
                name="PLANNER", domain="planning",
                specializations=["project_planning", "resource_allocation", "timeline_management", "risk_assessment"],
                dependencies=["DIRECTOR"], performance_score=88.0
            ),
            
            # === DEVELOPMENT & CONSTRUCTION ===
            "CONSTRUCTOR": AgentCapability(
                name="CONSTRUCTOR", domain="development",
                specializations=["code_implementation", "feature_development", "integration", "build_systems"],
                dependencies=["ARCHITECT"], performance_score=92.0
            ),
            "PYTHON-INTERNAL": AgentCapability(
                name="PYTHON-INTERNAL", domain="development",
                specializations=["python_development", "backend_systems", "api_development", "data_processing"],
                dependencies=["CONSTRUCTOR"], performance_score=94.0
            ),
            "C-INTERNAL": AgentCapability(
                name="C-INTERNAL", domain="development",
                specializations=["system_programming", "performance_optimization", "low_level_development", "embedded"],
                dependencies=["CONSTRUCTOR"], performance_score=91.0
            ),
            "WEB": AgentCapability(
                name="WEB", domain="development",
                specializations=["frontend_development", "web_frameworks", "ui_ux", "responsive_design"],
                dependencies=["CONSTRUCTOR"], performance_score=89.0
            ),
            "ANDROIDMOBILE": AgentCapability(
                name="ANDROIDMOBILE", domain="development",
                specializations=["mobile_development", "android_apps", "mobile_ui", "platform_integration"],
                dependencies=["CONSTRUCTOR"], performance_score=87.0
            ),
            
            # === USER INTERFACES ===
            "PYGUI": AgentCapability(
                name="PYGUI", domain="interface",
                specializations=["desktop_gui", "python_interfaces", "user_experience", "desktop_apps"],
                dependencies=["PYTHON-INTERNAL"], performance_score=86.0
            ),
            "TUI": AgentCapability(
                name="TUI", domain="interface",
                specializations=["terminal_interfaces", "cli_tools", "interactive_shells", "console_apps"],
                dependencies=["CONSTRUCTOR"], performance_score=88.0
            ),
            "APIDESIGNER": AgentCapability(
                name="APIDESIGNER", domain="interface",
                specializations=["api_design", "rest_apis", "graphql", "api_documentation", "integration"],
                dependencies=["ARCHITECT"], performance_score=91.0
            ),
            
            # === QUALITY ASSURANCE ===
            "TESTBED": AgentCapability(
                name="TESTBED", domain="quality",
                specializations=["testing_frameworks", "automated_testing", "test_coverage", "integration_testing"],
                dependencies=["CONSTRUCTOR"], performance_score=93.0
            ),
            "DEBUGGER": AgentCapability(
                name="DEBUGGER", domain="quality",
                specializations=["bug_fixing", "error_analysis", "debugging_tools", "performance_profiling"],
                dependencies=["TESTBED"], performance_score=90.0
            ),
            "LINTER": AgentCapability(
                name="LINTER", domain="quality",
                specializations=["code_quality", "static_analysis", "style_checking", "best_practices"],
                dependencies=["CONSTRUCTOR"], performance_score=85.0
            ),
            "QADIRECTOR": AgentCapability(
                name="QADIRECTOR", domain="quality",
                specializations=["qa_strategy", "quality_management", "test_planning", "quality_metrics"],
                dependencies=["DIRECTOR", "TESTBED"], performance_score=89.0
            ),
            
            # === SECURITY ===
            "SECURITY": AgentCapability(
                name="SECURITY", domain="security",
                specializations=["security_analysis", "vulnerability_assessment", "secure_coding", "threat_modeling"],
                performance_score=96.0
            ),
            "SECURITYAUDITOR": AgentCapability(
                name="SECURITYAUDITOR", domain="security",
                specializations=["security_audits", "compliance_checking", "penetration_testing", "risk_assessment"],
                dependencies=["SECURITY"], performance_score=94.0
            ),
            "SECURITYCHAOSAGENT": AgentCapability(
                name="SECURITYCHAOSAGENT", domain="security",
                specializations=["chaos_engineering", "resilience_testing", "failure_simulation", "stress_testing"],
                dependencies=["SECURITY", "TESTBED"], performance_score=87.0
            ),
            "CRYPTOEXPERT": AgentCapability(
                name="CRYPTOEXPERT", domain="security",
                specializations=["cryptography", "encryption", "key_management", "secure_protocols"],
                dependencies=["SECURITY"], performance_score=95.0
            ),
            "BASTION": AgentCapability(
                name="BASTION", domain="security",
                specializations=["access_control", "authentication", "authorization", "identity_management"],
                dependencies=["SECURITY"], performance_score=92.0
            ),
            "QUANTUMGUARD": AgentCapability(
                name="QUANTUMGUARD", domain="security",
                specializations=["quantum_cryptography", "post_quantum_security", "advanced_encryption"],
                dependencies=["CRYPTOEXPERT"], performance_score=93.0
            ),
            
            # === INFRASTRUCTURE & OPERATIONS ===
            "INFRASTRUCTURE": AgentCapability(
                name="INFRASTRUCTURE", domain="infrastructure",
                specializations=["cloud_infrastructure", "containerization", "orchestration", "scalability"],
                dependencies=["ARCHITECT"], performance_score=91.0
            ),
            "DEPLOYER": AgentCapability(
                name="DEPLOYER", domain="infrastructure",
                specializations=["deployment_automation", "ci_cd", "release_management", "environment_management"],
                dependencies=["INFRASTRUCTURE"], performance_score=89.0
            ),
            "MONITOR": AgentCapability(
                name="MONITOR", domain="infrastructure",
                specializations=["system_monitoring", "performance_metrics", "alerting", "observability"],
                dependencies=["INFRASTRUCTURE"], performance_score=88.0
            ),
            "DATABASE": AgentCapability(
                name="DATABASE", domain="data",
                specializations=["database_design", "data_modeling", "query_optimization", "data_integrity"],
                dependencies=["ARCHITECT"], performance_score=90.0
            ),
            
            # === DATA & ANALYTICS ===
            "DATASCIENCE": AgentCapability(
                name="DATASCIENCE", domain="data",
                specializations=["data_analysis", "machine_learning", "statistical_modeling", "data_visualization"],
                dependencies=["DATABASE"], performance_score=92.0
            ),
            "MLOPS": AgentCapability(
                name="MLOPS", domain="data",
                specializations=["ml_pipeline", "model_deployment", "ml_monitoring", "automated_training"],
                dependencies=["DATASCIENCE", "DEPLOYER"], performance_score=90.0
            ),
            "RESEARCHER": AgentCapability(
                name="RESEARCHER", domain="research",
                specializations=["research_methodology", "literature_review", "data_gathering", "analysis"],
                performance_score=89.0
            ),
            
            # === OPTIMIZATION & PERFORMANCE ===
            "OPTIMIZER": AgentCapability(
                name="OPTIMIZER", domain="performance",
                specializations=["performance_optimization", "code_optimization", "resource_efficiency", "bottleneck_analysis"],
                dependencies=["DEBUGGER"], performance_score=91.0
            ),
            "NPU": AgentCapability(
                name="NPU", domain="performance",
                specializations=["neural_processing", "ai_acceleration", "specialized_hardware", "edge_computing"],
                dependencies=["OPTIMIZER"], performance_score=88.0
            ),
            
            # === PACKAGING & DISTRIBUTION ===
            "PACKAGER": AgentCapability(
                name="PACKAGER", domain="distribution",
                specializations=["package_management", "distribution", "dependency_management", "release_packaging"],
                dependencies=["CONSTRUCTOR"], performance_score=86.0
            ),
            "PATCHER": AgentCapability(
                name="PATCHER", domain="maintenance",
                specializations=["patch_management", "hotfixes", "version_management", "rollback_procedures"],
                dependencies=["PACKAGER"], performance_score=87.0
            ),
            
            # === INTEGRATION & COORDINATION ===
            "INTERGRATION": AgentCapability(  # Note: keeping original spelling
                name="INTERGRATION", domain="integration",
                specializations=["system_integration", "api_integration", "data_integration", "workflow_integration"],
                dependencies=["ARCHITECT"], performance_score=88.0
            ),
            "PROJECTORCHESTRATOR": AgentCapability(
                name="PROJECTORCHESTRATOR", domain="orchestration",
                specializations=["project_coordination", "workflow_management", "resource_coordination", "team_coordination"],
                dependencies=["DIRECTOR"], performance_score=90.0
            ),
            
            # === DOCUMENTATION & COMMUNICATION ===
            "DOCGEN": AgentCapability(
                name="DOCGEN", domain="documentation",
                specializations=["documentation_generation", "api_docs", "user_guides", "technical_writing"],
                dependencies=["CONSTRUCTOR"], performance_score=87.0
            ),
            
            # === MANAGEMENT & OVERSIGHT ===
            "LEADENGINEER": AgentCapability(
                name="LEADENGINEER", domain="leadership",
                specializations=["technical_leadership", "engineering_management", "code_reviews", "mentoring"],
                dependencies=["DIRECTOR"], performance_score=91.0
            ),
            "OVERSIGHT": AgentCapability(
                name="OVERSIGHT", domain="governance",
                specializations=["compliance_monitoring", "governance", "audit_oversight", "risk_management"],
                dependencies=["DIRECTOR"], performance_score=88.0
            ),
            "ORGANIZATION": AgentCapability(
                name="ORGANIZATION", domain="governance",
                specializations=["organizational_design", "process_improvement", "workflow_optimization", "team_structure"],
                dependencies=["DIRECTOR"], performance_score=86.0
            ),
            "CSO": AgentCapability(
                name="CSO", domain="security",
                specializations=["security_strategy", "security_governance", "compliance", "security_leadership"],
                dependencies=["SECURITY", "DIRECTOR"], performance_score=93.0
            ),
            
            # === SPECIALIZED AGENTS ===
            "GNU": AgentCapability(
                name="GNU", domain="tooling",
                specializations=["gnu_tools", "build_systems", "compilation", "open_source_tools"],
                dependencies=["CONSTRUCTOR"], performance_score=84.0
            ),
            "GNA": AgentCapability(
                name="GNA", domain="tooling",
                specializations=["specialized_tooling", "custom_tools", "automation", "workflow_tools"],
                dependencies=["CONSTRUCTOR"], performance_score=83.0
            ),
            "REDTEAMORCHESTRATOR": AgentCapability(
                name="REDTEAMORCHESTRATOR", domain="security",
                specializations=["red_team_operations", "attack_simulation", "security_testing", "threat_hunting"],
                dependencies=["SECURITY"], performance_score=90.0
            )
        }
        
        return agents
    
    def _build_domain_map(self) -> Dict[str, List[str]]:
        """Build domain to agents mapping"""
        domain_map = defaultdict(list)
        for agent_name, agent in self.agents.items():
            domain_map[agent.domain].append(agent_name)
        return dict(domain_map)
    
    def _build_capability_graph(self) -> Dict[str, Set[str]]:
        """Build capability to agents mapping"""
        capability_graph = defaultdict(set)
        for agent_name, agent in self.agents.items():
            for spec in agent.specializations:
                capability_graph[spec].add(agent_name)
        return dict(capability_graph)
    
    def find_agents_by_capability(self, capability: str) -> List[str]:
        """Find agents with specific capability"""
        # Direct match
        if capability in self.capability_graph:
            return list(self.capability_graph[capability])
        
        # Fuzzy match
        matches = []
        capability_lower = capability.lower()
        for cap, agents in self.capability_graph.items():
            if capability_lower in cap.lower() or cap.lower() in capability_lower:
                matches.extend(agents)
        
        return list(set(matches))
    
    def find_agents_by_domain(self, domain: str) -> List[str]:
        """Find agents in specific domain"""
        return self.domain_map.get(domain, [])
    
    def get_agent_dependencies(self, agent_name: str) -> List[str]:
        """Get agent dependencies"""
        if agent_name in self.agents:
            return self.agents[agent_name].dependencies
        return []
    
    def calculate_agent_efficiency(self, agent_name: str) -> float:
        """Calculate agent efficiency score"""
        if agent_name not in self.agents:
            return 0.0
        
        agent = self.agents[agent_name]
        efficiency = (agent.performance_score * agent.success_rate) / (agent.load_factor * agent.execution_time_avg)
        return min(100.0, efficiency / 100.0 * 100)

# ============================================================================
# INTELLIGENT TASK ANALYSIS ENGINE
# ============================================================================

class TaskAnalysisEngine:
    """Advanced task analysis with NLP-style pattern recognition"""
    
    def __init__(self, agent_registry: IntelligentAgentRegistry):
        self.registry = agent_registry
        self.complexity_indicators = {
            "simple": ["fix", "update", "change", "modify", "adjust", "tweak", "patch"],
            "moderate": ["implement", "add", "create", "build", "integrate", "setup", "configure"],
            "complex": ["architect", "design", "refactor", "optimize", "migrate", "transform"],
            "enterprise": ["deploy", "scale", "enterprise", "production", "secure", "audit"]
        }
        
        self.domain_keywords = {
            "security": ["secure", "security", "audit", "vulnerability", "encrypt", "auth", "permission"],
            "performance": ["optimize", "performance", "speed", "efficient", "fast", "benchmark"],
            "infrastructure": ["deploy", "cloud", "container", "kubernetes", "infrastructure", "scale"],
            "testing": ["test", "testing", "qa", "quality", "verify", "validate", "check"],
            "development": ["code", "implement", "build", "develop", "program", "feature"],
            "data": ["data", "database", "analytics", "ml", "machine learning", "analysis"],
            "documentation": ["document", "docs", "documentation", "guide", "manual", "readme"],
            "ui": ["interface", "ui", "ux", "frontend", "gui", "user experience"],
            "api": ["api", "rest", "graphql", "endpoint", "service", "integration"]
        }
        
        self.workflow_patterns = {
            "full_development": [
                "DIRECTOR", "ARCHITECT", "CONSTRUCTOR", "TESTBED", "DEBUGGER", 
                "LINTER", "SECURITY", "DOCGEN", "DEPLOYER"
            ],
            "security_focused": [
                "SECURITY", "SECURITYAUDITOR", "CRYPTOEXPERT", "BASTION", "CSO"
            ],
            "performance_optimization": [
                "OPTIMIZER", "DEBUGGER", "MONITOR", "NPU", "TESTBED"
            ],
            "data_pipeline": [
                "DATASCIENCE", "DATABASE", "MLOPS", "MONITOR", "SECURITY"
            ],
            "infrastructure_deployment": [
                "INFRASTRUCTURE", "DEPLOYER", "MONITOR", "SECURITY", "OVERSIGHT"
            ],
            "quality_assurance": [
                "QADIRECTOR", "TESTBED", "LINTER", "DEBUGGER", "SECURITYAUDITOR"
            ]
        }
    
    def analyze_task_complexity(self, task_description: str) -> str:
        """Analyze task complexity level"""
        task_lower = task_description.lower()
        
        complexity_scores = {}
        for level, keywords in self.complexity_indicators.items():
            score = sum(1 for keyword in keywords if keyword in task_lower)
            if score > 0:
                complexity_scores[level] = score
        
        if not complexity_scores:
            return "moderate"  # Default
        
        # Return highest scoring complexity
        return max(complexity_scores.items(), key=lambda x: x[1])[0]
    
    def identify_domains(self, task_description: str) -> List[Tuple[str, float]]:
        """Identify relevant domains with confidence scores"""
        task_lower = task_description.lower()
        domain_scores = {}
        
        for domain, keywords in self.domain_keywords.items():
            score = 0
            for keyword in keywords:
                if keyword in task_lower:
                    # Weight longer keywords higher
                    score += len(keyword) / 5.0
            
            if score > 0:
                domain_scores[domain] = score
        
        # Normalize scores and return sorted
        if not domain_scores:
            return [("development", 1.0)]  # Default
        
        max_score = max(domain_scores.values())
        normalized = [(domain, score/max_score) for domain, score in domain_scores.items()]
        return sorted(normalized, key=lambda x: x[1], reverse=True)
    
    def suggest_workflow_pattern(self, domains: List[Tuple[str, float]], complexity: str) -> str:
        """Suggest appropriate workflow pattern"""
        primary_domain = domains[0][0] if domains else "development"
        
        # Map domains to workflow patterns
        if primary_domain == "security" or any(d[0] == "security" for d in domains[:2]):
            return "security_focused"
        elif primary_domain == "performance":
            return "performance_optimization"
        elif primary_domain == "data":
            return "data_pipeline"
        elif primary_domain == "infrastructure":
            return "infrastructure_deployment"
        elif primary_domain == "testing":
            return "quality_assurance"
        elif complexity in ["complex", "enterprise"]:
            return "full_development"
        else:
            return "custom"
    
    def extract_technical_requirements(self, task_description: str) -> Dict[str, List[str]]:
        """Extract technical requirements from task description"""
        requirements = {
            "languages": [],
            "frameworks": [],
            "platforms": [],
            "tools": []
        }
        
        # Language detection
        language_patterns = {
            "python": r'\b(python|py|django|flask|fastapi)\b',
            "javascript": r'\b(javascript|js|node|react|vue|angular)\b',
            "java": r'\b(java|spring|maven|gradle)\b',
            "c++": r'\b(c\+\+|cpp|cmake)\b',
            "go": r'\b(go|golang)\b',
            "rust": r'\b(rust|cargo)\b'
        }
        
        for lang, pattern in language_patterns.items():
            if re.search(pattern, task_description, re.IGNORECASE):
                requirements["languages"].append(lang)
        
        # Platform detection
        platform_patterns = {
            "web": r'\b(web|browser|html|css)\b',
            "mobile": r'\b(mobile|android|ios|app)\b',
            "cloud": r'\b(cloud|aws|azure|gcp|kubernetes)\b',
            "desktop": r'\b(desktop|gui|application)\b'
        }
        
        for platform, pattern in platform_patterns.items():
            if re.search(pattern, task_description, re.IGNORECASE):
                requirements["platforms"].append(platform)
        
        return requirements

# ============================================================================
# DYNAMIC WORKFLOW GENERATOR
# ============================================================================

class DynamicWorkflowGenerator:
    """Generate custom workflows based on task analysis"""
    
    def __init__(self, agent_registry: IntelligentAgentRegistry):
        self.registry = agent_registry
        
    def generate_workflow(self, task_analysis: Dict[str, Any]) -> CommandSet:
        """Generate optimized workflow based on task analysis"""
        
        complexity = task_analysis.get("complexity", "moderate")
        domains = task_analysis.get("domains", [("development", 1.0)])
        pattern = task_analysis.get("suggested_pattern", "custom")
        requirements = task_analysis.get("technical_requirements", {})
        
        if pattern != "custom" and pattern in self.registry.agents:
            # Use predefined pattern with optimizations
            return self._create_pattern_workflow(pattern, complexity, requirements)
        else:
            # Generate custom workflow
            return self._create_custom_workflow(domains, complexity, requirements)
    
    def _create_pattern_workflow(self, pattern: str, complexity: str, requirements: Dict) -> CommandSet:
        """Create workflow from predefined pattern"""
        
        # Define workflow patterns
        patterns = {
            "full_development": {
                "name": "Complete Development Lifecycle",
                "agents": ["DIRECTOR", "ARCHITECT", "CONSTRUCTOR", "TESTBED", "SECURITY", "DEPLOYER"],
                "parallel_groups": [["TESTBED", "LINTER"], ["SECURITY", "DOCGEN"]]
            },
            "security_focused": {
                "name": "Security Analysis & Hardening",
                "agents": ["SECURITY", "SECURITYAUDITOR", "CRYPTOEXPERT", "BASTION"],
                "parallel_groups": [["SECURITYAUDITOR", "CRYPTOEXPERT"]]
            },
            "performance_optimization": {
                "name": "Performance Analysis & Optimization",
                "agents": ["OPTIMIZER", "DEBUGGER", "MONITOR", "TESTBED"],
                "parallel_groups": [["OPTIMIZER", "MONITOR"]]
            },
            "data_pipeline": {
                "name": "Data Processing Pipeline",
                "agents": ["DATASCIENCE", "DATABASE", "MLOPS", "SECURITY"],
                "parallel_groups": [["DATASCIENCE", "DATABASE"]]
            }
        }
        
        if pattern not in patterns:
            return self._create_custom_workflow([("development", 1.0)], complexity, requirements)
        
        pattern_config = patterns[pattern]
        steps = []
        dependencies = {}
        
        # Create sequential steps with parallel groups
        for i, agent in enumerate(pattern_config["agents"]):
            step_id = f"step_{i}_{agent.lower()}"
            steps.append(CommandStep(
                id=step_id,
                agent=agent,
                action=self._determine_agent_action(agent, complexity, requirements),
                payload=self._build_agent_payload(agent, requirements),
                can_fail=(complexity == "simple")  # Allow failures for simple tasks
            ))
            
            # Add dependencies (sequential by default)
            if i > 0:
                prev_step = f"step_{i-1}_{pattern_config['agents'][i-1].lower()}"
                dependencies[step_id] = [prev_step]
        
        # Add parallel execution for specified groups
        for group in pattern_config.get("parallel_groups", []):
            # Remove dependencies within parallel groups
            group_step_ids = [f"step_{i}_{agent.lower()}" for i, agent in enumerate(pattern_config["agents"]) if agent in group]
            for step_id in group_step_ids[1:]:  # Keep first as anchor
                if step_id in dependencies:
                    del dependencies[step_id]
        
        return CommandSet(
            name=pattern_config["name"],
            type=CommandType.WORKFLOW if complexity in ["simple", "moderate"] else CommandType.CAMPAIGN,
            mode=ExecutionMode.INTELLIGENT,
            priority=Priority.HIGH if complexity == "enterprise" else Priority.MEDIUM,
            steps=steps,
            dependencies=dependencies,
            parallel_allowed=True,
            timeout=300.0 if complexity == "simple" else 1800.0
        )
    
    def _create_custom_workflow(self, domains: List[Tuple[str, float]], complexity: str, requirements: Dict) -> CommandSet:
        """Create custom workflow based on domain analysis"""
        
        selected_agents = []
        
        # Always start with planning for complex tasks
        if complexity in ["complex", "enterprise"]:
            selected_agents.extend(["DIRECTOR", "PLANNER", "ARCHITECT"])
        elif complexity == "moderate":
            selected_agents.append("ARCHITECT")
        
        # Add domain-specific agents
        for domain, confidence in domains[:3]:  # Top 3 domains
            domain_agents = self.registry.find_agents_by_domain(domain)
            
            # Select best agents from domain based on confidence and efficiency
            for agent in domain_agents[:2]:  # Top 2 per domain
                if agent not in selected_agents:
                    efficiency = self.registry.calculate_agent_efficiency(agent)
                    if efficiency * confidence > 0.5:  # Threshold for inclusion
                        selected_agents.append(agent)
        
        # Add core development agent if not present
        if not any(agent in ["CONSTRUCTOR", "PYTHON-INTERNAL", "C-INTERNAL"] for agent in selected_agents):
            selected_agents.append("CONSTRUCTOR")
        
        # Add quality assurance for complex tasks
        if complexity in ["complex", "enterprise"] and "TESTBED" not in selected_agents:
            selected_agents.append("TESTBED")
        
        # Add security review for enterprise tasks
        if complexity == "enterprise" and "SECURITY" not in selected_agents:
            selected_agents.append("SECURITY")
        
        # Create steps
        steps = []
        dependencies = {}
        
        for i, agent in enumerate(selected_agents):
            step_id = f"step_{i}_{agent.lower()}"
            steps.append(CommandStep(
                id=step_id,
                agent=agent,
                action=self._determine_agent_action(agent, complexity, requirements),
                payload=self._build_agent_payload(agent, requirements),
                can_fail=(complexity == "simple")
            ))
            
            # Smart dependency management
            if i > 0:
                deps = self._calculate_dependencies(agent, selected_agents[:i])
                if deps:
                    dependencies[step_id] = deps
        
        return CommandSet(
            name=f"Custom {complexity.title()} Workflow",
            type=CommandType.WORKFLOW if len(selected_agents) <= 5 else CommandType.CAMPAIGN,
            mode=ExecutionMode.INTELLIGENT,
            priority=self._determine_priority(complexity, domains),
            steps=steps,
            dependencies=dependencies,
            parallel_allowed=True,
            timeout=self._calculate_timeout(complexity, len(selected_agents))
        )
    
    def _determine_agent_action(self, agent: str, complexity: str, requirements: Dict) -> str:
        """Determine appropriate action for agent based on context"""
        action_map = {
            "DIRECTOR": "coordinate_project",
            "ARCHITECT": "design_system",
            "CONSTRUCTOR": "implement_solution",
            "TESTBED": "execute_tests",
            "SECURITY": "security_review",
            "DEPLOYER": "deploy_system",
            "DEBUGGER": "analyze_issues",
            "OPTIMIZER": "optimize_performance",
            "DOCGEN": "generate_documentation"
        }
        
        base_action = action_map.get(agent, "execute_task")
        
        # Modify action based on complexity
        if complexity == "enterprise":
            return f"{base_action}_enterprise"
        elif complexity == "complex":
            return f"{base_action}_advanced"
        
        return base_action
    
    def _build_agent_payload(self, agent: str, requirements: Dict) -> Dict[str, Any]:
        """Build context-aware payload for agent"""
        payload = {
            "requirements": requirements,
            "timestamp": time.time(),
            "context": "orchestrated_workflow"
        }
        
        # Agent-specific payload enhancements
        if agent in ["CONSTRUCTOR", "PYTHON-INTERNAL", "C-INTERNAL"]:
            payload["languages"] = requirements.get("languages", ["python"])
            payload["frameworks"] = requirements.get("frameworks", [])
        
        elif agent == "SECURITY":
            payload["security_level"] = "enterprise" if "security" in str(requirements) else "standard"
            payload["compliance_check"] = True
        
        elif agent == "TESTBED":
            payload["test_types"] = ["unit", "integration", "performance"]
            payload["coverage_threshold"] = 80
        
        return payload
    
    def _calculate_dependencies(self, agent: str, previous_agents: List[str]) -> List[str]:
        """Calculate smart dependencies based on agent relationships"""
        agent_deps = self.registry.get_agent_dependencies(agent)
        
        # Find dependencies that are in previous agents
        resolved_deps = []
        for dep in agent_deps:
            # Find the latest step for this dependency
            dep_steps = [f"step_{i}_{prev_agent.lower()}" 
                        for i, prev_agent in enumerate(previous_agents) 
                        if prev_agent == dep]
            if dep_steps:
                resolved_deps.append(dep_steps[-1])
        
        # If no explicit dependencies, depend on immediately previous step
        if not resolved_deps and previous_agents:
            last_agent = previous_agents[-1]
            last_step = f"step_{len(previous_agents)-1}_{last_agent.lower()}"
            resolved_deps.append(last_step)
        
        return resolved_deps
    
    def _determine_priority(self, complexity: str, domains: List[Tuple[str, float]]) -> Priority:
        """Determine workflow priority"""
        if complexity == "enterprise":
            return Priority.CRITICAL
        elif complexity == "complex":
            return Priority.HIGH
        elif any(domain == "security" for domain, _ in domains):
            return Priority.HIGH
        else:
            return Priority.MEDIUM
    
    def _calculate_timeout(self, complexity: str, num_agents: int) -> float:
        """Calculate appropriate timeout based on complexity and agent count"""
        base_timeout = {
            "simple": 60.0,
            "moderate": 300.0, 
            "complex": 900.0,
            "enterprise": 1800.0
        }.get(complexity, 300.0)
        
        # Add time per agent
        return base_timeout + (num_agents * 30.0)

# ============================================================================
# ENHANCED ORCHESTRATION BRIDGE
# ============================================================================

class EnhancedClaudeOrchestrationBridge:
    """
    Advanced orchestration bridge with intelligent agent selection,
    dynamic workflow generation, and context-aware optimization
    """
    
    def __init__(self):
        self.orchestrator = None
        self.agent_registry = IntelligentAgentRegistry()
        self.task_analyzer = TaskAnalysisEngine(self.agent_registry)
        self.workflow_generator = DynamicWorkflowGenerator(self.agent_registry)
        
        # Configuration
        self.permission_bypass = os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true'
        self.claude_binary = self._find_claude_binary()
        self.project_context = self._analyze_project_context()
        
        # Performance tracking
        self.execution_history = []
        self.performance_cache = {}
        
        logger.info("Enhanced Claude Orchestration Bridge v3.0 initialized")
        logger.info(f"Registered {len(self.agent_registry.agents)} agents across {len(self.agent_registry.domain_map)} domains")
    
    def _find_claude_binary(self) -> Optional[str]:
        """Find Claude binary with enhanced search"""
        search_paths = [
            os.path.expanduser("~/.local/npm-global/bin/claude.original"),
            os.path.expanduser("~/.local/bin/claude.original"),
            "/usr/local/bin/claude.original",
            os.path.expanduser("~/.local/npm-global/bin/claude"),
            os.path.expanduser("~/.local/bin/claude"),
            "/usr/local/bin/claude"
        ]
        
        for path in search_paths:
            if os.path.isfile(path) and os.access(path, os.X_OK):
                logger.info(f"Found Claude binary: {path}")
                return path
        
        # Try which command
        try:
            result = subprocess.run(['which', 'claude'], capture_output=True, text=True)
            if result.returncode == 0:
                binary_path = result.stdout.strip()
                logger.info(f"Found Claude binary via which: {binary_path}")
                return binary_path
        except:
            pass
        
        logger.warning("Claude binary not found")
        return None
    
    def _analyze_project_context(self) -> Dict[str, Any]:
        """Analyze current project context for smarter suggestions"""
        context = {
            "project_type": "unknown",
            "languages": [],
            "frameworks": [],
            "has_tests": False,
            "has_docs": False,
            "security_files": False,
            "ci_cd": False
        }
        
        try:
            cwd = Path.cwd()
            
            # Detect project type
            if (cwd / "package.json").exists():
                context["project_type"] = "nodejs"
                context["languages"].append("javascript")
            elif (cwd / "requirements.txt").exists() or (cwd / "pyproject.toml").exists():
                context["project_type"] = "python"
                context["languages"].append("python")
            elif (cwd / "Cargo.toml").exists():
                context["project_type"] = "rust"
                context["languages"].append("rust")
            elif (cwd / "go.mod").exists():
                context["project_type"] = "go"
                context["languages"].append("go")
            
            # Check for test directories
            test_patterns = ["test", "tests", "__tests__", "spec"]
            context["has_tests"] = any((cwd / pattern).exists() for pattern in test_patterns)
            
            # Check for documentation
            doc_patterns = ["docs", "doc", "documentation", "README.md", "readme.md"]
            context["has_docs"] = any((cwd / pattern).exists() for pattern in doc_patterns)
            
            # Check for security files
            security_patterns = [".security", "security.md", "SECURITY.md", ".dependabot"]
            context["security_files"] = any((cwd / pattern).exists() for pattern in security_patterns)
            
            # Check for CI/CD
            ci_patterns = [".github", ".gitlab-ci.yml", "Jenkinsfile", ".travis.yml"]
            context["ci_cd"] = any((cwd / pattern).exists() for pattern in ci_patterns)
            
            logger.info(f"Project context analyzed: {context['project_type']} project")
            
        except Exception as e:
            logger.warning(f"Failed to analyze project context: {e}")
        
        return context
    
    async def initialize(self) -> bool:
        """Initialize orchestration system"""
        try:
            self.orchestrator = ProductionOrchestrator()
            success = await self.orchestrator.initialize()
            
            if success:
                logger.info("Production orchestrator initialized successfully")
            else:
                logger.warning("Production orchestrator initialization failed")
            
            return success
        except Exception as e:
            logger.error(f"Failed to initialize orchestrator: {e}")
            return False
    
    def analyze_task_comprehensive(self, user_input: str) -> Dict[str, Any]:
        """Comprehensive task analysis with context awareness"""
        
        # Basic analysis
        complexity = self.task_analyzer.analyze_task_complexity(user_input)
        domains = self.task_analyzer.identify_domains(user_input)
        suggested_pattern = self.task_analyzer.suggest_workflow_pattern(domains, complexity)
        technical_requirements = self.task_analyzer.extract_technical_requirements(user_input)
        
        # Enhanced analysis with project context
        context_boost = self._apply_project_context(domains, technical_requirements)
        
        # Agent recommendations
        recommended_agents = self._recommend_agents(domains, complexity, technical_requirements)
        
        # Workflow suggestions
        workflow_suggestions = self._generate_workflow_suggestions(
            complexity, domains, recommended_agents, user_input
        )
        
        return {
            "complexity": complexity,
            "domains": domains,
            "suggested_pattern": suggested_pattern,
            "technical_requirements": technical_requirements,
            "context_boost": context_boost,
            "recommended_agents": recommended_agents,
            "workflow_suggestions": workflow_suggestions,
            "confidence_score": self._calculate_confidence_score(domains, complexity)
        }
    
    def _apply_project_context(self, domains: List[Tuple[str, float]], 
                             requirements: Dict[str, List[str]]) -> Dict[str, Any]:
        """Apply project context to enhance recommendations"""
        
        boost = {"languages": [], "frameworks": [], "agents": [], "priorities": []}
        
        # Language context boost
        project_languages = self.project_context.get("languages", [])
        for lang in project_languages:
            if lang not in requirements.get("languages", []):
                boost["languages"].append(lang)
        
        # Agent recommendations based on project state
        if not self.project_context.get("has_tests", False):
            boost["agents"].extend(["TESTBED", "QADIRECTOR"])
            boost["priorities"].append("testing_setup")
        
        if not self.project_context.get("has_docs", False):
            boost["agents"].append("DOCGEN")
            boost["priorities"].append("documentation")
        
        if not self.project_context.get("security_files", False):
            boost["agents"].extend(["SECURITY", "SECURITYAUDITOR"])
            boost["priorities"].append("security_audit")
        
        # CI/CD recommendations
        if not self.project_context.get("ci_cd", False):
            boost["agents"].extend(["DEPLOYER", "INFRASTRUCTURE"])
            boost["priorities"].append("automation")
        
        return boost
    
    def _recommend_agents(self, domains: List[Tuple[str, float]], complexity: str, 
                         requirements: Dict[str, List[str]]) -> List[Dict[str, Any]]:
        """Recommend optimal agents with reasoning"""
        
        recommendations = []
        
        # Get agents for top domains
        for domain, confidence in domains[:3]:
            domain_agents = self.agent_registry.find_agents_by_domain(domain)
            
            for agent_name in domain_agents[:2]:  # Top 2 per domain
                agent = self.agent_registry.agents[agent_name]
                efficiency = self.agent_registry.calculate_agent_efficiency(agent_name)
                
                recommendations.append({
                    "agent": agent_name,
                    "domain": domain,
                    "confidence": confidence,
                    "efficiency": efficiency,
                    "specializations": agent.specializations,
                    "reasoning": f"Expert in {domain} with {efficiency:.1f}% efficiency",
                    "estimated_time": agent.execution_time_avg
                })
        
        # Sort by overall score (confidence * efficiency)
        recommendations.sort(key=lambda x: x["confidence"] * x["efficiency"], reverse=True)
        
        return recommendations[:8]  # Top 8 recommendations
    
    def _generate_workflow_suggestions(self, complexity: str, domains: List[Tuple[str, float]], 
                                     recommended_agents: List[Dict], user_input: str) -> List[Dict[str, Any]]:
        """Generate intelligent workflow suggestions"""
        
        suggestions = []
        
        # Quick single-agent suggestions for simple tasks
        if complexity == "simple" and recommended_agents:
            top_agent = recommended_agents[0]
            suggestions.append({
                "type": "single_agent",
                "title": f"Quick {top_agent['domain'].title()} Task",
                "description": f"Execute with {top_agent['agent']} for focused {top_agent['domain']} work",
                "agents": [top_agent['agent']],
                "estimated_time": f"{top_agent['estimated_time']:.1f} minutes",
                "complexity": "simple",
                "command": f"single:{top_agent['agent']}"
            })
        
        # Multi-agent workflow for moderate+ tasks
        if complexity in ["moderate", "complex", "enterprise"]:
            # Create balanced workflow
            selected_agents = []
            
            # Add management for complex tasks
            if complexity in ["complex", "enterprise"]:
                selected_agents.append("DIRECTOR")
            
            # Add top agents from different domains
            used_domains = set()
            for rec in recommended_agents:
                if rec["domain"] not in used_domains and len(selected_agents) < 6:
                    selected_agents.append(rec["agent"])
                    used_domains.add(rec["domain"])
            
            total_time = sum(rec["estimated_time"] for rec in recommended_agents[:len(selected_agents)])
            
            suggestions.append({
                "type": "multi_agent_workflow",
                "title": f"Comprehensive {complexity.title()} Workflow",
                "description": f"Coordinated execution across {len(selected_agents)} specialized agents",
                "agents": selected_agents,
                "estimated_time": f"{total_time:.1f} minutes",
                "complexity": complexity,
                "command": f"workflow:custom_{complexity}"
            })
        
        # Security-focused workflow if security domain detected
        security_domains = [d for d, c in domains if d == "security"]
        if security_domains:
            suggestions.append({
                "type": "security_workflow",
                "title": "Security Analysis & Hardening",
                "description": "Comprehensive security audit and recommendations",
                "agents": ["SECURITY", "SECURITYAUDITOR", "CRYPTOEXPERT", "BASTION"],
                "estimated_time": "15-30 minutes",
                "complexity": "complex",
                "command": "workflow:security_audit"
            })
        
        # Performance optimization workflow
        if any(d == "performance" for d, c in domains):
            suggestions.append({
                "type": "performance_workflow", 
                "title": "Performance Analysis & Optimization",
                "description": "Deep performance analysis and optimization recommendations",
                "agents": ["OPTIMIZER", "DEBUGGER", "MONITOR", "TESTBED"],
                "estimated_time": "20-40 minutes",
                "complexity": "complex",
                "command": "workflow:performance_optimization"
            })
        
        return suggestions
    
    def _calculate_confidence_score(self, domains: List[Tuple[str, float]], complexity: str) -> float:
        """Calculate overall confidence in recommendations"""
        if not domains:
            return 0.5
        
        # Base confidence on domain detection strength
        domain_confidence = sum(conf for _, conf in domains) / len(domains)
        
        # Adjust for complexity
        complexity_factor = {
            "simple": 0.9,
            "moderate": 0.8,
            "complex": 0.7,
            "enterprise": 0.6
        }.get(complexity, 0.7)
        
        return min(1.0, domain_confidence * complexity_factor)
    
    async def execute_orchestration_workflow(self, command: str, task_description: str) -> Dict[str, Any]:
        """Execute orchestration workflow with enhanced error handling"""
        
        start_time = time.time()
        
        try:
            if command.startswith("single:"):
                agent_name = command.split(":", 1)[1]
                result = await self._execute_single_agent(agent_name, task_description)
            
            elif command.startswith("workflow:"):
                workflow_type = command.split(":", 1)[1]
                result = await self._execute_predefined_workflow(workflow_type, task_description)
            
            elif command.startswith("custom:"):
                # Generate custom workflow on the fly
                analysis = self.analyze_task_comprehensive(task_description)
                workflow = self.workflow_generator.generate_workflow(analysis)
                result = await self.orchestrator.execute_command_set(workflow)
            
            else:
                return {"error": f"Unknown command format: {command}"}
            
            # Track performance
            execution_time = time.time() - start_time
            self._track_performance(command, execution_time, result)
            
            return result
            
        except Exception as e:
            logger.error(f"Workflow execution failed: {e}")
            return {
                "error": str(e),
                "command": command,
                "execution_time": time.time() - start_time
            }
    
    async def _execute_single_agent(self, agent_name: str, task_description: str) -> Dict[str, Any]:
        """Execute single agent task"""
        
        if agent_name not in self.agent_registry.agents:
            return {"error": f"Unknown agent: {agent_name}"}
        
        # Create simple single-step workflow
        workflow = CommandSet(
            name=f"Single Agent Task: {agent_name}",
            type=CommandType.ATOMIC,
            mode=ExecutionMode.INTELLIGENT,
            priority=Priority.MEDIUM,
            steps=[
                CommandStep(
                    id="single_task",
                    agent=agent_name,
                    action="execute_task",
                    payload={
                        "task_description": task_description,
                        "context": "single_agent_execution"
                    }
                )
            ]
        )
        
        return await self.orchestrator.execute_command_set(workflow)
    
    async def _execute_predefined_workflow(self, workflow_type: str, task_description: str) -> Dict[str, Any]:
        """Execute predefined workflow with task context"""
        
        # Map workflow types to generators
        workflow_map = {
            "security_audit": lambda: StandardWorkflows.create_security_audit_workflow(),
            "document_generation": lambda: StandardWorkflows.create_document_generation_workflow(),
            "performance_optimization": self._create_performance_workflow,
            "custom_simple": lambda: self._create_simple_workflow(task_description),
            "custom_moderate": lambda: self._create_moderate_workflow(task_description),
            "custom_complex": lambda: self._create_complex_workflow(task_description),
            "custom_enterprise": lambda: self._create_enterprise_workflow(task_description)
        }
        
        if workflow_type not in workflow_map:
            return {"error": f"Unknown workflow type: {workflow_type}"}
        
        workflow = workflow_map[workflow_type]()
        return await self.orchestrator.execute_command_set(workflow)
    
    def _create_performance_workflow(self) -> CommandSet:
        """Create performance optimization workflow"""
        return CommandSet(
            name="Performance Optimization Workflow",
            type=CommandType.WORKFLOW,
            mode=ExecutionMode.INTELLIGENT,
            priority=Priority.HIGH,
            steps=[
                CommandStep(id="analyze", agent="OPTIMIZER", action="analyze_performance"),
                CommandStep(id="debug", agent="DEBUGGER", action="identify_bottlenecks"),
                CommandStep(id="monitor", agent="MONITOR", action="collect_metrics"),
                CommandStep(id="test", agent="TESTBED", action="performance_testing"),
                CommandStep(id="optimize", agent="OPTIMIZER", action="apply_optimizations")
            ],
            dependencies={
                "debug": ["analyze"],
                "monitor": ["analyze"],
                "test": ["debug", "monitor"],
                "optimize": ["test"]
            }
        )
    
    def _create_simple_workflow(self, task_description: str) -> CommandSet:
        """Create simple workflow based on task"""
        analysis = self.analyze_task_comprehensive(task_description)
        return self.workflow_generator._create_custom_workflow(
            analysis["domains"], "simple", analysis["technical_requirements"]
        )
    
    def _create_moderate_workflow(self, task_description: str) -> CommandSet:
        """Create moderate complexity workflow"""
        analysis = self.analyze_task_comprehensive(task_description)
        return self.workflow_generator._create_custom_workflow(
            analysis["domains"], "moderate", analysis["technical_requirements"]
        )
    
    def _create_complex_workflow(self, task_description: str) -> CommandSet:
        """Create complex workflow"""
        analysis = self.analyze_task_comprehensive(task_description)
        return self.workflow_generator._create_custom_workflow(
            analysis["domains"], "complex", analysis["technical_requirements"]
        )
    
    def _create_enterprise_workflow(self, task_description: str) -> CommandSet:
        """Create enterprise-grade workflow"""
        analysis = self.analyze_task_comprehensive(task_description)
        return self.workflow_generator._create_custom_workflow(
            analysis["domains"], "enterprise", analysis["technical_requirements"]
        )
    
    def _track_performance(self, command: str, execution_time: float, result: Dict[str, Any]):
        """Track performance for future optimization"""
        
        performance_record = {
            "command": command,
            "execution_time": execution_time,
            "success": result.get("status") == "completed",
            "timestamp": time.time(),
            "steps_executed": len(result.get("results", {}))
        }
        
        self.execution_history.append(performance_record)
        
        # Keep only last 100 records
        if len(self.execution_history) > 100:
            self.execution_history = self.execution_history[-100:]
        
        # Update performance cache
        if command not in self.performance_cache:
            self.performance_cache[command] = []
        
        self.performance_cache[command].append(execution_time)
        if len(self.performance_cache[command]) > 10:
            self.performance_cache[command] = self.performance_cache[command][-10:]
    
    def format_enhanced_suggestions(self, analysis: Dict[str, Any]) -> str:
        """Format enhanced suggestions for display"""
        
        suggestions = analysis.get("workflow_suggestions", [])
        confidence = analysis.get("confidence_score", 0.0)
        
        if not suggestions:
            return "\n🤖 No specific orchestration recommendations for this task."
        
        output = [
            "\n🚀 Enhanced Orchestration Analysis:",
            f"   Confidence Score: {confidence:.1%}",
            f"   Task Complexity: {analysis['complexity'].title()}",
            f"   Primary Domains: {', '.join([d for d, c in analysis['domains'][:2]])}",
            ""
        ]
        
        for i, suggestion in enumerate(suggestions, 1):
            output.extend([
                f"{i}. 🎯 {suggestion['title']}",
                f"   📝 {suggestion['description']}",
                f"   👥 Agents: {', '.join(suggestion['agents'][:3])}{'...' if len(suggestion['agents']) > 3 else ''}",
                f"   ⏱️  Estimated Time: {suggestion['estimated_time']}",
                f"   🔧 Command: claude-orchestrate '{suggestion['command']}'",
                ""
            ])
        
        # Show recommended agents
        recommended = analysis.get("recommended_agents", [])[:3]
        if recommended:
            output.extend([
                "🎖️  Top Agent Recommendations:",
                ""
            ])
            for agent in recommended:
                output.append(f"   • {agent['agent']}: {agent['reasoning']} ({agent['efficiency']:.1f}% efficiency)")
            output.append("")
        
        # Show context boost if available
        context_boost = analysis.get("context_boost", {})
        if any(context_boost.values()):
            output.extend([
                "📊 Project Context Enhancements:",
                ""
            ])
            if context_boost.get("priorities"):
                priorities = context_boost["priorities"][:2]
                output.append(f"   🎯 Suggested Priorities: {', '.join(priorities)}")
            output.append("")
        
        output.extend([
            "💡 Usage Tips:",
            "   • Add --dry-run to preview workflow without execution",
            "   • Use --verbose for detailed step-by-step output", 
            "   • Set CLAUDE_ORCHESTRATION=off to disable",
            ""
        ])
        
        return "\n".join(output)

# ============================================================================
# MAIN ENHANCED BRIDGE EXECUTION
# ============================================================================

async def main():
    """Enhanced main function with comprehensive task analysis"""
    
    # Check if orchestration is disabled
    if os.environ.get("CLAUDE_ORCHESTRATION", "").lower() == "off":
        logger.info("Orchestration disabled via environment variable")
        sys.exit(0)
    
    # Parse command line arguments
    dry_run = "--dry-run" in sys.argv
    verbose = "--verbose" in sys.argv
    
    # Clean arguments
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    
    # Get user input
    if args:
        user_input = " ".join(args)
    else:
        user_input = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
    
    if not user_input:
        print("╔══════════════════════════════════════════════════════════════════════╗")
        print("║           Enhanced Claude Orchestration Bridge v3.0                   ║")
        print("║      AI-Driven Agent Selection & Dynamic Workflow Generation          ║")
        print("╚══════════════════════════════════════════════════════════════════════╝")
        print()
        print("🚀 Features:")
        print("   • Intelligent analysis of 44 specialized agents")
        print("   • Dynamic workflow generation based on task complexity")
        print("   • Context-aware suggestions from project analysis")
        print("   • Performance tracking and optimization")
        print()
        print("Usage: claude-orchestrate '<task description>' [options]")
        print("   or: echo 'task' | claude-orchestrate")
        print()
        print("Options:")
        print("   --dry-run    Preview workflow without execution")
        print("   --verbose    Detailed step-by-step output")
        print()
        print("Environment:")
        print(f"   Permission Bypass: {'ENABLED' if os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true' else 'DISABLED'}")
        print(f"   Orchestration: ENABLED")
        print(f"   Project Type: {Path.cwd().name}")
        sys.exit(1)
    
    # Initialize enhanced bridge
    bridge = EnhancedClaudeOrchestrationBridge()
    
    print("🔍 Analyzing task with AI-powered orchestration engine...")
    if bridge.permission_bypass:
        print("🔓 Permission bypass: ENABLED (LiveCD mode)")
    
    if verbose:
        print(f"📁 Project context: {bridge.project_context['project_type']} project")
        print(f"🤖 Agent registry: {len(bridge.agent_registry.agents)} agents available")
    
    # Initialize orchestrator
    if not await bridge.initialize():
        logger.error("Failed to initialize orchestration system")
        print("❌ Could not initialize orchestration system")
        sys.exit(1)
    
    # Comprehensive task analysis
    print("🧠 Running comprehensive task analysis...")
    analysis = bridge.analyze_task_comprehensive(user_input)
    
    if verbose:
        print(f"📊 Analysis Results:")
        print(f"   Complexity: {analysis['complexity']}")
        print(f"   Confidence: {analysis['confidence_score']:.1%}")
        print(f"   Domains: {[d for d, c in analysis['domains']]}")
    
    # Show enhanced suggestions
    suggestions_output = bridge.format_enhanced_suggestions(analysis)
    print(suggestions_output)
    
    # Check if any workflow suggestions available
    suggestions = analysis.get("workflow_suggestions", [])
    if not suggestions:
        print("✅ No orchestration enhancement needed - proceeding with standard Claude Code")
        sys.exit(0)
    
    # Dry run mode
    if dry_run:
        print("🔍 DRY RUN MODE - Workflow preview:")
        for i, suggestion in enumerate(suggestions, 1):
            print(f"\n{i}. {suggestion['title']}")
            print(f"   Agents: {' → '.join(suggestion['agents'])}")
            print(f"   Estimated: {suggestion['estimated_time']}")
        print("\nRemove --dry-run to execute workflow")
        sys.exit(0)
    
    # Interactive execution
    if sys.stdin.isatty():
        print(f"\n🎯 Execute top recommendation? [y/N]: ", end="", flush=True)
        response = input().strip().lower()
        
        if response in ['y', 'yes']:
            top_suggestion = suggestions[0]
            print(f"\n🚀 Executing: {top_suggestion['title']}")
            
            if verbose:
                print(f"📋 Command: {top_suggestion['command']}")
                print(f"👥 Agents: {', '.join(top_suggestion['agents'])}")
            
            # Execute workflow
            start_time = time.time()
            result = await bridge.execute_orchestration_workflow(
                top_suggestion['command'], 
                user_input
            )
            execution_time = time.time() - start_time
            
            # Display results
            print(f"\n📊 Execution Results:")
            print(f"   Status: {result.get('status', 'unknown')}")
            print(f"   Duration: {execution_time:.1f} seconds")
            print(f"   Steps completed: {len(result.get('results', {}))}")
            
            if result.get('status') == 'completed':
                print("✅ Orchestration completed successfully!")
                
                if verbose and 'results' in result:
                    print("\n📋 Detailed Results:")
                    for step_id, step_result in result['results'].items():
                        status = step_result.get('status', 'unknown')
                        print(f"   {step_id}: {status}")
            else:
                print(f"⚠️  Orchestration finished with status: {result.get('status')}")
                if 'error' in result:
                    print(f"   Error: {result['error']}")
        else:
            print("👍 Proceeding with standard Claude Code workflow")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Execution interrupted by user")
        print("\n👋 Orchestration cancelled by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        print(f"❌ Fatal error: {e}")
        sys.exit(1)