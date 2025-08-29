#!/usr/bin/env python3
"""
Claude Fuzzy Agent Matcher Integration v3.0
Comprehensive ML-style fuzzy matching for Claude Code with full 58+ agent registry
"""

import json
import sys
import os
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set, Any
from enum import Enum
from dataclasses import dataclass, field
import logging
from collections import defaultdict

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import semantic matcher if available
try:
    sys.path.insert(0, '/home/ubuntu/Documents/Claude')
    from agent_semantic_matcher import EnhancedAgentMatcher
    SEMANTIC_AVAILABLE = True
except ImportError:
    logger.warning("Semantic matcher not available, using advanced keyword matching")
    SEMANTIC_AVAILABLE = False

# ============================================================================
# EXECUTION MODES & PRIORITIES
# ============================================================================

class ExecutionMode(Enum):
    """Execution mode selection for Tandem system"""
    INTELLIGENT = "INTELLIGENT"  # Auto-select best path
    PYTHON_ONLY = "PYTHON_ONLY"  # Pure Python execution
    SPEED_CRITICAL = "SPEED_CRITICAL"  # Maximum performance via C
    REDUNDANT = "REDUNDANT"  # Both layers for critical ops

class Priority(Enum):
    """Agent priority levels"""
    CRITICAL = 5
    HIGH = 4
    MEDIUM = 3
    LOW = 2
    NORMAL = 1

# ============================================================================
# COMPLETE AGENT REGISTRY - All 58+ Agents
# ============================================================================

class AgentRegistry:
    """Comprehensive agent registry with all project agents"""
    
    def __init__(self):
        self.agents = self._initialize_agents()
        self.capability_map = self._build_capability_map()
        self.keyword_map = self._build_keyword_map()
        self.pattern_map = self._build_pattern_map()
        self.category_map = self._build_category_map()
        
    def _initialize_agents(self) -> Dict[str, Dict[str, Any]]:
        """Initialize all 58+ agents with their capabilities"""
        return {
            # ORCHESTRATORS
            "director": {
                "type": "ORCHESTRATOR",
                "capabilities": ["strategic_planning", "resource_allocation", "multi_phase_projects", "roadmap"],
                "priority": Priority.CRITICAL,
                "keywords": ["plan", "strategic", "coordinate", "architect", "roadmap", "vision"],
                "patterns": [r"plan\s+(?:project|system)", r"strategic\s+\w+", r"high.?level"]
            },
            "projectorchestrator": {
                "type": "ORCHESTRATOR",
                "capabilities": ["tactical_coordination", "task_distribution", "dependency_management"],
                "priority": Priority.HIGH,
                "keywords": ["orchestrate", "coordinate", "distribute", "workflow", "pipeline", "tasks"],
                "patterns": [r"coordinate\s+(?:agents|tasks)", r"manage\s+dependencies"]
            },
            "redteamorchestrator": {
                "type": "SECURITY_ORCHESTRATOR",
                "capabilities": ["penetration_testing", "attack_simulation", "vulnerability_assessment"],
                "priority": Priority.HIGH,
                "keywords": ["redteam", "penetration", "attack", "exploit", "vulnerability"],
                "patterns": [r"red\s?team", r"pen\s?test", r"attack\s+simulation"]
            },
            
            # SECURITY AGENTS
            "cso": {
                "type": "SECURITY",
                "capabilities": ["security_strategy", "compliance", "risk_management", "security_architecture"],
                "priority": Priority.CRITICAL,
                "keywords": ["security", "compliance", "risk", "threat", "ciso", "policy"],
                "patterns": [r"security\s+(?:audit|review|assessment)", r"compliance\s+check"]
            },
            "security": {
                "type": "SECURITY",
                "capabilities": ["vulnerability_scanning", "threat_detection", "security_monitoring"],
                "priority": Priority.HIGH,
                "keywords": ["vulnerability", "threat", "scan", "secure", "protect"],
                "patterns": [r"security\s+scan", r"vulnerability\s+assessment"]
            },
            "securityauditor": {
                "type": "SECURITY",
                "capabilities": ["code_audit", "security_review", "compliance_verification"],
                "priority": Priority.HIGH,
                "keywords": ["audit", "review", "compliance", "verification", "assessment"],
                "patterns": [r"security\s+audit", r"code\s+review", r"compliance\s+check"]
            },
            "securitychaosagent": {
                "type": "SECURITY",
                "capabilities": ["chaos_testing", "security_fuzzing", "stress_testing"],
                "priority": Priority.HIGH,
                "keywords": ["chaos", "fuzzing", "stress", "random", "break"],
                "patterns": [r"chaos\s+testing", r"fuzz\s+test", r"stress\s+test"]
            },
            "cryptoexpert": {
                "type": "SECURITY",
                "capabilities": ["encryption", "cryptography", "key_management", "secure_communication"],
                "priority": Priority.HIGH,
                "keywords": ["crypto", "encryption", "decrypt", "cipher", "key", "certificate"],
                "patterns": [r"encrypt(?:ion)?", r"decrypt(?:ion)?", r"crypto(?:graphy)?"]
            },
            "quantumguard": {
                "type": "SECURITY",
                "capabilities": ["quantum_resistance", "post_quantum_crypto", "quantum_security"],
                "priority": Priority.HIGH,
                "keywords": ["quantum", "post-quantum", "quantum-resistant", "qkd"],
                "patterns": [r"quantum\s+(?:resistant|safe|security)", r"post.?quantum"]
            },
            "bastion": {
                "type": "SECURITY",
                "capabilities": ["access_control", "ssh_management", "jumphost", "perimeter_security"],
                "priority": Priority.CRITICAL,
                "keywords": ["bastion", "jumphost", "ssh", "access", "perimeter"],
                "patterns": [r"bastion\s+host", r"jump\s?(?:host|box)", r"ssh\s+access"]
            },
            
            # SPECIALIZED SECURITY
            "nsa": {
                "type": "INTELLIGENCE",
                "capabilities": ["signal_intelligence", "network_analysis", "advanced_cryptanalysis"],
                "priority": Priority.CRITICAL,
                "keywords": ["sigint", "signals", "intelligence", "intercept", "analysis"],
                "patterns": [r"signal\s+intelligence", r"network\s+analysis", r"traffic\s+analysis"]
            },
            "apt41-defense-agent": {
                "type": "THREAT_DEFENSE",
                "capabilities": ["apt_defense", "advanced_threat_protection", "nation_state_defense"],
                "priority": Priority.CRITICAL,
                "keywords": ["apt", "advanced-threat", "nation-state", "defense", "attribution"],
                "patterns": [r"apt\s+defense", r"advanced\s+persistent\s+threat", r"nation.?state"]
            },
            "bgp-purple-team-agent": {
                "type": "NETWORK_SECURITY",
                "capabilities": ["bgp_security", "routing_security", "purple_team_ops"],
                "priority": Priority.HIGH,
                "keywords": ["bgp", "routing", "purple-team", "network", "autonomous-system"],
                "patterns": [r"bgp\s+(?:security|hijack)", r"purple\s+team", r"routing\s+security"]
            },
            "psyops_agent": {
                "type": "PSYCHOLOGICAL_OPS",
                "capabilities": ["social_engineering", "psychological_operations", "influence_campaigns"],
                "priority": Priority.HIGH,
                "keywords": ["psyops", "social-engineering", "influence", "deception", "misinformation"],
                "patterns": [r"psy(?:chological)?\s+ops", r"social\s+engineering", r"influence\s+campaign"]
            },
            
            # DEVELOPMENT AGENTS
            "leadengineer": {
                "type": "ENGINEERING",
                "capabilities": ["technical_leadership", "architecture_decisions", "code_review", "mentoring"],
                "priority": Priority.HIGH,
                "keywords": ["lead", "engineer", "technical", "architecture", "review", "mentor"],
                "patterns": [r"lead\s+engineer", r"technical\s+(?:lead|leadership)", r"code\s+review"]
            },
            "constructor": {
                "type": "DEVELOPMENT",
                "capabilities": ["code_generation", "scaffolding", "boilerplate", "project_setup"],
                "priority": Priority.MEDIUM,
                "keywords": ["construct", "generate", "scaffold", "boilerplate", "create", "build"],
                "patterns": [r"generate\s+(?:code|project)", r"scaffold(?:ing)?", r"create\s+(?:project|app)"]
            },
            "debugger": {
                "type": "DEVELOPMENT",
                "capabilities": ["error_diagnosis", "stack_trace_analysis", "memory_debugging", "profiling"],
                "priority": Priority.HIGH,
                "keywords": ["debug", "error", "bug", "trace", "diagnose", "fix", "crash"],
                "patterns": [r"debug(?:ging)?", r"(?:error|bug)\s+fix", r"stack\s+trace", r"crash\s+analysis"]
            },
            "patcher": {
                "type": "DEVELOPMENT",
                "capabilities": ["bug_fixing", "hotfixes", "patch_management", "quick_fixes"],
                "priority": Priority.HIGH,
                "keywords": ["patch", "fix", "hotfix", "repair", "remedy", "correct"],
                "patterns": [r"(?:hot)?fix", r"patch(?:ing)?", r"quick\s+fix", r"bug\s+fix"]
            },
            "linter": {
                "type": "DEVELOPMENT",
                "capabilities": ["code_style", "static_analysis", "best_practices", "code_quality"],
                "priority": Priority.MEDIUM,
                "keywords": ["lint", "style", "format", "clean", "quality", "standard"],
                "patterns": [r"lint(?:ing)?", r"code\s+(?:style|quality)", r"static\s+analysis"]
            },
            
            # LANGUAGE-SPECIFIC INTERNAL AGENTS
            "python-internal": {
                "type": "LANGUAGE",
                "capabilities": ["python_development", "python_optimization", "python_debugging"],
                "priority": Priority.MEDIUM,
                "keywords": ["python", "py", "pip", "django", "flask", "pandas"],
                "patterns": [r"python(?:3)?", r"\.py\b", r"pip\s+install"]
            },
            "rust-internal": {
                "type": "LANGUAGE",
                "capabilities": ["rust_development", "memory_safety", "rust_optimization"],
                "priority": Priority.MEDIUM,
                "keywords": ["rust", "cargo", "rustc", "lifetime", "borrow"],
                "patterns": [r"rust(?:lang)?", r"cargo\s+\w+", r"\.rs\b"]
            },
            "go-internal": {
                "type": "LANGUAGE",
                "capabilities": ["go_development", "concurrency", "go_optimization"],
                "priority": Priority.MEDIUM,
                "keywords": ["golang", "go", "goroutine", "channel", "defer"],
                "patterns": [r"go(?:lang)?", r"\.go\b", r"go\s+mod"]
            },
            "typescript-internal": {
                "type": "LANGUAGE",
                "capabilities": ["typescript_development", "type_safety", "javascript_interop"],
                "priority": Priority.MEDIUM,
                "keywords": ["typescript", "ts", "tsx", "types", "interface"],
                "patterns": [r"typescript", r"\.tsx?", r"type\s+\w+\s+="]
            },
            "cpp_internal_agent": {
                "type": "LANGUAGE",
                "capabilities": ["cpp_development", "performance_optimization", "memory_management"],
                "priority": Priority.MEDIUM,
                "keywords": ["cpp", "c++", "stl", "template", "pointer"],
                "patterns": [r"c\+\+", r"\.cpp\b", r"std::", r"template\s*<"]
            },
            "c-internal": {
                "type": "LANGUAGE",
                "capabilities": ["c_development", "system_programming", "embedded_development"],
                "priority": Priority.MEDIUM,
                "keywords": ["c", "malloc", "pointer", "struct", "embedded"],
                "patterns": [r"\bc\b", r"\.c\b", r"malloc|free", r"struct\s+\w+"]
            },
            "java-internal": {
                "type": "LANGUAGE",
                "capabilities": ["java_development", "jvm_optimization", "enterprise_java"],
                "priority": Priority.MEDIUM,
                "keywords": ["java", "jvm", "spring", "maven", "gradle"],
                "patterns": [r"java(?:script)?", r"\.java\b", r"public\s+class"]
            },
            "kotlin-internal": {
                "type": "LANGUAGE",
                "capabilities": ["kotlin_development", "android_development", "coroutines"],
                "priority": Priority.MEDIUM,
                "keywords": ["kotlin", "android", "coroutine", "suspend"],
                "patterns": [r"kotlin", r"\.kt\b", r"suspend\s+fun"]
            },
            "zig-internal": {
                "type": "LANGUAGE",
                "capabilities": ["zig_development", "compile_time_execution", "manual_memory"],
                "priority": Priority.LOW,
                "keywords": ["zig", "comptime", "allocator"],
                "patterns": [r"zig(?:lang)?", r"\.zig\b", r"comptime"]
            },
            "assembly-internal-agent": {
                "type": "LANGUAGE",
                "capabilities": ["assembly_programming", "low_level_optimization", "reverse_engineering"],
                "priority": Priority.LOW,
                "keywords": ["assembly", "asm", "nasm", "masm", "register"],
                "patterns": [r"assembly|asm", r"\.(?:asm|s)\b", r"mov\s+\w+,"]
            },
            "carbon-internal": {
                "type": "LANGUAGE",
                "capabilities": ["carbon_development", "experimental_language", "cpp_interop"],
                "priority": Priority.LOW,
                "keywords": ["carbon", "carbon-lang", "experimental"],
                "patterns": [r"carbon(?:-lang)?", r"\.carbon\b"]
            },
            
            # UI/FRONTEND AGENTS
            "web": {
                "type": "UI",
                "capabilities": ["frontend_development", "react", "vue", "angular", "web_design"],
                "priority": Priority.MEDIUM,
                "keywords": ["web", "frontend", "react", "vue", "angular", "html", "css", "javascript"],
                "patterns": [r"(?:web|frontend)\s+(?:app|development)", r"react|vue|angular"]
            },
            "androidmobile": {
                "type": "MOBILE",
                "capabilities": ["android_development", "mobile_apps", "kotlin_android"],
                "priority": Priority.MEDIUM,
                "keywords": ["android", "mobile", "app", "apk", "gradle"],
                "patterns": [r"android\s+(?:app|development)", r"mobile\s+app", r"\.apk\b"]
            },
            "pygui": {
                "type": "UI",
                "capabilities": ["desktop_gui", "tkinter", "pyqt", "kivy", "desktop_apps"],
                "priority": Priority.LOW,
                "keywords": ["gui", "desktop", "tkinter", "pyqt", "kivy", "window"],
                "patterns": [r"(?:desktop|gui)\s+app", r"tkinter|pyqt|kivy"]
            },
            "tui": {
                "type": "UI",
                "capabilities": ["terminal_ui", "ncurses", "rich_cli", "console_apps"],
                "priority": Priority.LOW,
                "keywords": ["tui", "terminal", "console", "ncurses", "cli"],
                "patterns": [r"terminal\s+ui", r"console\s+app", r"ncurses"]
            },
            
            # DATA & ML AGENTS
            "datascience": {
                "type": "DATA",
                "capabilities": ["data_analysis", "machine_learning", "visualization", "statistics"],
                "priority": Priority.MEDIUM,
                "keywords": ["data", "analysis", "statistics", "visualization", "pandas", "numpy"],
                "patterns": [r"data\s+(?:science|analysis)", r"machine\s+learning", r"statistic"]
            },
            "mlops": {
                "type": "ML_OPERATIONS",
                "capabilities": ["ml_pipeline", "model_deployment", "ml_monitoring", "ml_versioning"],
                "priority": Priority.MEDIUM,
                "keywords": ["mlops", "pipeline", "model", "deployment", "kubeflow", "mlflow"],
                "patterns": [r"ml\s*ops", r"model\s+(?:deployment|serving)", r"ml\s+pipeline"]
            },
            "researcher": {
                "type": "RESEARCH",
                "capabilities": ["research", "analysis", "documentation", "literature_review"],
                "priority": Priority.MEDIUM,
                "keywords": ["research", "analyze", "study", "investigate", "paper", "literature"],
                "patterns": [r"research(?:ing)?", r"literature\s+review", r"study\s+\w+"]
            },
            
            # INFRASTRUCTURE AGENTS
            "infrastructure": {
                "type": "OPERATIONS",
                "capabilities": ["terraform", "kubernetes", "docker", "cloud_setup", "iaac"],
                "priority": Priority.HIGH,
                "keywords": ["infrastructure", "terraform", "kubernetes", "k8s", "docker", "cloud"],
                "patterns": [r"infrastructure(?:\s+as\s+code)?", r"terraform|kubernetes|k8s", r"cloud\s+setup"]
            },
            "docker-agent": {
                "type": "CONTAINERIZATION",
                "capabilities": ["docker_management", "container_orchestration", "dockerfile_creation"],
                "priority": Priority.MEDIUM,
                "keywords": ["docker", "container", "dockerfile", "compose", "swarm"],
                "patterns": [r"docker(?:file)?", r"container(?:ization)?", r"docker\s+compose"]
            },
            "proxmox-agent": {
                "type": "VIRTUALIZATION",
                "capabilities": ["vm_management", "virtualization", "proxmox_clustering"],
                "priority": Priority.MEDIUM,
                "keywords": ["proxmox", "vm", "virtual", "hypervisor", "kvm"],
                "patterns": [r"proxmox", r"virtual\s+machine", r"vm\s+\w+"]
            },
            "cisco-agent": {
                "type": "NETWORKING",
                "capabilities": ["network_configuration", "cisco_ios", "routing_switching"],
                "priority": Priority.MEDIUM,
                "keywords": ["cisco", "network", "router", "switch", "ios", "vlan"],
                "patterns": [r"cisco\s+\w+", r"network\s+config", r"vlan|routing"]
            },
            "ddwrt-agent": {
                "type": "NETWORKING",
                "capabilities": ["router_firmware", "ddwrt_configuration", "network_optimization"],
                "priority": Priority.LOW,
                "keywords": ["ddwrt", "router", "firmware", "wireless", "openwrt"],
                "patterns": [r"dd.?wrt", r"router\s+firmware", r"openwrt"]
            },
            
            # OPERATIONS AGENTS
            "deployer": {
                "type": "OPERATIONS",
                "capabilities": ["deployment", "rollback", "blue_green", "canary", "ci_cd"],
                "priority": Priority.HIGH,
                "keywords": ["deploy", "rollback", "release", "production", "staging"],
                "patterns": [r"deploy(?:ment)?", r"release\s+to\s+\w+", r"blue.?green|canary"]
            },
            "monitor": {
                "type": "OPERATIONS",
                "capabilities": ["health_monitoring", "alerting", "metrics_collection", "observability"],
                "priority": Priority.HIGH,
                "keywords": ["monitor", "alert", "metrics", "health", "observability", "logging"],
                "patterns": [r"monitor(?:ing)?", r"alert(?:ing)?", r"metrics|observability"]
            },
            "packager": {
                "type": "OPERATIONS",
                "capabilities": ["package_creation", "dependency_management", "artifact_building"],
                "priority": Priority.MEDIUM,
                "keywords": ["package", "bundle", "artifact", "dependency", "npm", "pip"],
                "patterns": [r"packag(?:e|ing)", r"(?:npm|pip|cargo)\s+\w+", r"bundle\s+\w+"]
            },
            
            # SPECIALIZED AGENTS
            "database": {
                "type": "DATA",
                "capabilities": ["schema_design", "query_optimization", "migration", "database_admin"],
                "priority": Priority.MEDIUM,
                "keywords": ["database", "sql", "query", "schema", "migration", "postgres", "mysql"],
                "patterns": [r"database|db", r"sql\s+\w+", r"schema\s+\w+", r"query\s+optimization"]
            },
            "apidesigner": {
                "type": "API",
                "capabilities": ["api_design", "openapi_spec", "rest_design", "graphql"],
                "priority": Priority.MEDIUM,
                "keywords": ["api", "rest", "graphql", "openapi", "swagger", "endpoint"],
                "patterns": [r"api\s+(?:design|development)", r"rest(?:ful)?", r"graphql", r"openapi|swagger"]
            },
            "docgen": {
                "type": "DOCUMENTATION",
                "capabilities": ["documentation_generation", "api_docs", "readme_creation", "technical_writing"],
                "priority": Priority.LOW,
                "keywords": ["documentation", "docs", "readme", "manual", "guide"],
                "patterns": [r"document(?:ation)?", r"readme", r"(?:user|api)\s+guide"]
            },
            "testbed": {
                "type": "TESTING",
                "capabilities": ["unit_testing", "integration_testing", "performance_testing", "test_automation"],
                "priority": Priority.MEDIUM,
                "keywords": ["test", "testing", "unit", "integration", "qa", "automation"],
                "patterns": [r"test(?:ing)?", r"unit\s+test", r"integration\s+test", r"test\s+automation"]
            },
            "qadirector": {
                "type": "QUALITY",
                "capabilities": ["qa_strategy", "test_planning", "quality_metrics", "test_management"],
                "priority": Priority.HIGH,
                "keywords": ["qa", "quality", "test-planning", "metrics", "coverage"],
                "patterns": [r"qa\s+(?:strategy|planning)", r"quality\s+assurance", r"test\s+coverage"]
            },
            "optimizer": {
                "type": "PERFORMANCE",
                "capabilities": ["performance_tuning", "resource_optimization", "benchmarking", "profiling"],
                "priority": Priority.HIGH,
                "keywords": ["optimize", "performance", "speed", "efficiency", "benchmark", "profile"],
                "patterns": [r"optimiz(?:e|ation)", r"performance\s+\w+", r"benchmark(?:ing)?"]
            },
            "oversight": {
                "type": "COMPLIANCE",
                "capabilities": ["audit_logging", "compliance_checking", "policy_enforcement", "governance"],
                "priority": Priority.HIGH,
                "keywords": ["oversight", "audit", "compliance", "policy", "governance", "regulation"],
                "patterns": [r"oversight|audit", r"compliance\s+\w+", r"policy\s+enforcement"]
            },
            "planner": {
                "type": "PLANNING",
                "capabilities": ["project_planning", "timeline_management", "resource_planning", "scheduling"],
                "priority": Priority.MEDIUM,
                "keywords": ["plan", "planning", "schedule", "timeline", "roadmap", "milestone"],
                "patterns": [r"plan(?:ning)?", r"schedule\s+\w+", r"timeline|roadmap"]
            },
            "integration": {
                "type": "INTEGRATION",
                "capabilities": ["system_integration", "api_integration", "third_party_integration"],
                "priority": Priority.MEDIUM,
                "keywords": ["integration", "integrate", "connect", "bridge", "interface"],
                "patterns": [r"integrat(?:e|ion)", r"connect\s+\w+", r"third.?party"]
            },
            
            # HARDWARE/SPECIALIZED
            "npu": {
                "type": "HARDWARE",
                "capabilities": ["neural_processing", "ai_acceleration", "model_inference"],
                "priority": Priority.MEDIUM,
                "keywords": ["npu", "neural", "ai-acceleration", "inference", "tensor"],
                "patterns": [r"npu|neural\s+processing", r"ai\s+acceleration", r"model\s+inference"]
            },
            "gna": {
                "type": "HARDWARE",
                "capabilities": ["gaussian_neural_acceleration", "low_power_ai", "audio_processing"],
                "priority": Priority.LOW,
                "keywords": ["gna", "gaussian", "neural-acceleration", "audio-ai"],
                "patterns": [r"gna|gaussian\s+neural", r"low.?power\s+ai"]
            },
            "iot-access-control-agent": {
                "type": "IOT",
                "capabilities": ["iot_security", "device_management", "access_control", "mqtt"],
                "priority": Priority.MEDIUM,
                "keywords": ["iot", "device", "sensor", "mqtt", "embedded", "arduino"],
                "patterns": [r"iot|internet\s+of\s+things", r"device\s+management", r"mqtt"]
            }
        }
    
    def _build_capability_map(self) -> Dict[str, List[str]]:
        """Build capability to agent mapping"""
        cap_map = defaultdict(list)
        for agent_name, agent_data in self.agents.items():
            for capability in agent_data["capabilities"]:
                cap_map[capability].append(agent_name)
        return dict(cap_map)
    
    def _build_keyword_map(self) -> Dict[str, List[str]]:
        """Build keyword to agent mapping"""
        kw_map = defaultdict(list)
        for agent_name, agent_data in self.agents.items():
            for keyword in agent_data["keywords"]:
                kw_map[keyword.lower()].append(agent_name)
        return dict(kw_map)
    
    def _build_pattern_map(self) -> Dict[str, List[Tuple[str, re.Pattern]]]:
        """Build compiled pattern to agent mapping"""
        pattern_map = defaultdict(list)
        for agent_name, agent_data in self.agents.items():
            for pattern_str in agent_data["patterns"]:
                compiled = re.compile(pattern_str, re.IGNORECASE)
                pattern_map[agent_name].append(compiled)
        return dict(pattern_map)
    
    def _build_category_map(self) -> Dict[str, List[str]]:
        """Build category to agent mapping"""
        cat_map = defaultdict(list)
        for agent_name, agent_data in self.agents.items():
            cat_map[agent_data["type"]].append(agent_name)
        return dict(cat_map)

# ============================================================================
# FUZZY MATCHER
# ============================================================================

class ClaudeFuzzyMatcher:
    """
    Advanced fuzzy matching for Claude Code agent invocation
    """
    
    def __init__(self):
        self.registry = AgentRegistry()
        self.semantic_matcher = None
        if SEMANTIC_AVAILABLE:
            try:
                self.semantic_matcher = EnhancedAgentMatcher()
            except Exception as e:
                logger.warning(f"Could not initialize semantic matcher: {e}")
        
        # Workflow patterns
        self.workflow_patterns = self._initialize_workflow_patterns()
        
    def _initialize_workflow_patterns(self) -> Dict[str, Dict[str, Any]]:
        """Initialize complex workflow patterns"""
        return {
            "security_assessment": {
                "patterns": [r"security\s+(?:audit|assessment|review)", r"vulnerability\s+scan"],
                "agents": ["cso", "securityauditor", "security", "cryptoexpert"],
                "coordinator": "cso"
            },
            "deployment_pipeline": {
                "patterns": [r"deploy(?:ment)?\s+to\s+production", r"release\s+pipeline"],
                "agents": ["deployer", "testbed", "monitor", "infrastructure"],
                "coordinator": "deployer"
            },
            "performance_tuning": {
                "patterns": [r"performance\s+(?:optimization|tuning)", r"optimize\s+(?:speed|memory)"],
                "agents": ["optimizer", "monitor", "debugger", "profiler"],
                "coordinator": "optimizer"
            },
            "full_stack_development": {
                "patterns": [r"full.?stack", r"end.?to.?end\s+application"],
                "agents": ["web", "apidesigner", "database", "infrastructure"],
                "coordinator": "leadengineer"
            },
            "incident_response": {
                "patterns": [r"production\s+(?:down|issue)", r"incident\s+response", r"emergency"],
                "agents": ["debugger", "monitor", "patcher", "deployer"],
                "coordinator": "leadengineer"
            },
            "code_review": {
                "patterns": [r"code\s+review", r"pull\s+request\s+review"],
                "agents": ["leadengineer", "linter", "securityauditor", "testbed"],
                "coordinator": "leadengineer"
            },
            "red_team_exercise": {
                "patterns": [r"red\s+team", r"penetration\s+test", r"attack\s+simulation"],
                "agents": ["redteamorchestrator", "apt41-defense-agent", "securitychaosagent", "cryptoexpert"],
                "coordinator": "redteamorchestrator"
            },
            "ml_pipeline": {
                "patterns": [r"ml\s+pipeline", r"machine\s+learning\s+deployment"],
                "agents": ["mlops", "datascience", "optimizer", "monitor"],
                "coordinator": "mlops"
            }
        }
    
    def match(self, user_input: str) -> Dict[str, Any]:
        """
        Perform comprehensive fuzzy matching on user input
        """
        input_lower = user_input.lower()
        results = {
            "confidence": 0.0,
            "matched_agents": [],
            "workflow": None,
            "reasoning": [],
            "execution_mode": ExecutionMode.INTELLIGENT
        }
        
        # Check for explicit agent mentions
        explicit_agents = self._check_explicit_mentions(input_lower)
        if explicit_agents:
            results["matched_agents"] = explicit_agents
            results["confidence"] = 1.0
            results["reasoning"].append(f"Explicit agent mention: {', '.join(explicit_agents)}")
            return results
        
        # Check workflow patterns
        workflow = self._check_workflow_patterns(input_lower)
        if workflow:
            results["workflow"] = workflow["name"]
            results["matched_agents"] = workflow["agents"]
            results["confidence"] = 0.9
            results["reasoning"].append(f"Matched workflow: {workflow['name']}")
            return results
        
        # Pattern matching
        pattern_matches = self._match_patterns(user_input)
        
        # Keyword matching
        keyword_matches = self._match_keywords(input_lower)
        
        # Semantic matching (if available)
        semantic_matches = []
        if self.semantic_matcher:
            try:
                semantic_results = self.semantic_matcher.match(user_input)
                semantic_matches = list(semantic_results.get('semantic_agents', {}).keys())[:3]
            except:
                pass
        
        # Combine and score matches
        all_matches = self._combine_matches(pattern_matches, keyword_matches, semantic_matches)
        
        if all_matches:
            results["matched_agents"] = list(all_matches.keys())[:5]
            results["confidence"] = min(max(all_matches.values()), 1.0)
            results["reasoning"] = self._generate_reasoning(all_matches, user_input)
        
        # Determine execution mode based on task
        results["execution_mode"] = self._determine_execution_mode(user_input, results["matched_agents"])
        
        return results
    
    def _check_explicit_mentions(self, input_lower: str) -> List[str]:
        """Check for explicit agent mentions"""
        mentioned = []
        for agent_name in self.registry.agents.keys():
            if agent_name.lower() in input_lower or agent_name.replace("-", "").lower() in input_lower:
                mentioned.append(agent_name)
        return mentioned
    
    def _check_workflow_patterns(self, input_lower: str) -> Optional[Dict[str, Any]]:
        """Check for workflow patterns"""
        for workflow_name, workflow_data in self.workflow_patterns.items():
            for pattern_str in workflow_data["patterns"]:
                if re.search(pattern_str, input_lower, re.IGNORECASE):
                    return {
                        "name": workflow_name,
                        "agents": workflow_data["agents"],
                        "coordinator": workflow_data["coordinator"]
                    }
        return None
    
    def _match_patterns(self, user_input: str) -> Dict[str, float]:
        """Match against regex patterns"""
        matches = defaultdict(float)
        for agent_name, patterns in self.registry.pattern_map.items():
            for pattern in patterns:
                if pattern.search(user_input):
                    matches[agent_name] += 0.3
        return dict(matches)
    
    def _match_keywords(self, input_lower: str) -> Dict[str, float]:
        """Match against keywords"""
        matches = defaultdict(float)
        words = set(input_lower.split())
        
        for word in words:
            if word in self.registry.keyword_map:
                for agent in self.registry.keyword_map[word]:
                    matches[agent] += 0.2
        
        return dict(matches)
    
    def _combine_matches(self, pattern_matches: Dict[str, float], 
                        keyword_matches: Dict[str, float],
                        semantic_matches: List[str]) -> Dict[str, float]:
        """Combine all match types with scoring"""
        combined = defaultdict(float)
        
        # Add pattern matches
        for agent, score in pattern_matches.items():
            combined[agent] += score
        
        # Add keyword matches
        for agent, score in keyword_matches.items():
            combined[agent] += score
        
        # Add semantic matches with decreasing scores
        for i, agent in enumerate(semantic_matches):
            if agent in self.registry.agents:
                combined[agent] += 0.5 * (0.8 ** i)  # Decreasing weight
        
        # Apply priority multipliers
        for agent in combined:
            priority = self.registry.agents[agent]["priority"]
            combined[agent] *= (priority.value / 3)  # Normalize by medium priority
        
        # Sort and filter
        sorted_agents = sorted(combined.items(), key=lambda x: x[1], reverse=True)
        return dict(sorted_agents[:10])  # Top 10
    
    def _generate_reasoning(self, matches: Dict[str, float], user_input: str) -> List[str]:
        """Generate reasoning for matches"""
        reasoning = []
        for agent, score in list(matches.items())[:3]:
            agent_data = self.registry.agents[agent]
            caps = ", ".join(agent_data["capabilities"][:3])
            reasoning.append(f"{agent}: {caps} (score: {score:.2f})")
        return reasoning
    
    def _determine_execution_mode(self, user_input: str, agents: List[str]) -> ExecutionMode:
        """Determine optimal execution mode"""
        input_lower = user_input.lower()
        
        # Speed critical patterns
        if any(word in input_lower for word in ["urgent", "critical", "emergency", "asap", "performance"]):
            return ExecutionMode.SPEED_CRITICAL
        
        # Redundant for security operations
        if any(agent in agents for agent in ["cso", "securityauditor", "cryptoexpert", "nsa"]):
            if "audit" in input_lower or "compliance" in input_lower:
                return ExecutionMode.REDUNDANT
        
        # Python only for complex ML/data tasks
        if any(agent in agents for agent in ["datascience", "mlops", "researcher"]):
            return ExecutionMode.PYTHON_ONLY
        
        return ExecutionMode.INTELLIGENT
    
    def get_invocation_command(self, user_input: str) -> Optional[str]:
        """Generate Task tool invocation command"""
        results = self.match(user_input)
        
        if results["confidence"] < 0.3:
            return None
        
        agents = results["matched_agents"]
        if not agents:
            return None
        
        # Single agent invocation
        if len(agents) == 1:
            return f'Task(subagent_type="{agents[0]}", prompt="{user_input}", mode="{results["execution_mode"].value}")'
        
        # Workflow invocation
        if results["workflow"]:
            workflow = self.workflow_patterns[results["workflow"]]
            coordinator = workflow["coordinator"]
            return f'Task(subagent_type="{coordinator}", prompt="Coordinate {results["workflow"]}: {user_input}", mode="{results["execution_mode"].value}")'
        
        # Multi-agent coordination
        coordinator = "projectorchestrator"
        if any(a in agents for a in ["director", "leadengineer"]):
            coordinator = agents[0]  # Use the highest priority orchestrator
        
        agent_list = ", ".join(agents[:3])
        return f'Task(subagent_type="{coordinator}", prompt="Coordinate {agent_list}: {user_input}", mode="{results["execution_mode"].value}")'


# ============================================================================
# PUBLIC API
# ============================================================================

def fuzzy_match_agents(user_input: str) -> Dict[str, Any]:
    """Public API for fuzzy matching agents"""
    matcher = ClaudeFuzzyMatcher()
    return matcher.match(user_input)

def get_agent_command(user_input: str) -> Optional[str]:
    """Get the Task command for agent invocation"""
    matcher = ClaudeFuzzyMatcher()
    return matcher.get_invocation_command(user_input)

def list_all_agents() -> List[str]:
    """List all available agents"""
    registry = AgentRegistry()
    return sorted(registry.agents.keys())

def get_agent_info(agent_name: str) -> Optional[Dict[str, Any]]:
    """Get detailed information about an agent"""
    registry = AgentRegistry()
    return registry.agents.get(agent_name)

def find_agents_by_capability(capability: str) -> List[str]:
    """Find agents with specific capability"""
    registry = AgentRegistry()
    return registry.capability_map.get(capability, [])

def find_agents_by_type(agent_type: str) -> List[str]:
    """Find agents by type/category"""
    registry = AgentRegistry()
    return registry.category_map.get(agent_type, [])


# ============================================================================
# CLI INTERFACE
# ============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Claude Fuzzy Agent Matcher v3.0")
    parser.add_argument("input", nargs="?", help="User input to match")
    parser.add_argument("--list", action="store_true", help="List all agents")
    parser.add_argument("--info", help="Get info about specific agent")
    parser.add_argument("--capability", help="Find agents by capability")
    parser.add_argument("--type", help="Find agents by type")
    parser.add_argument("--test", action="store_true", help="Run test suite")
    
    args = parser.parse_args()
    
    if args.list:
        print("\n🤖 All Available Agents (58+):")
        print("=" * 70)
        registry = AgentRegistry()
        for agent_type, agents in registry.category_map.items():
            print(f"\n📁 {agent_type}:")
            for agent in sorted(agents):
                agent_data = registry.agents[agent]
                print(f"  • {agent:25} Priority: {agent_data['priority'].name:8} Capabilities: {len(agent_data['capabilities'])}")
    
    elif args.info:
        info = get_agent_info(args.info)
        if info:
            print(f"\n🤖 Agent: {args.info}")
            print("=" * 70)
            print(f"Type: {info['type']}")
            print(f"Priority: {info['priority'].name}")
            print(f"Capabilities: {', '.join(info['capabilities'])}")
            print(f"Keywords: {', '.join(info['keywords'][:10])}")
        else:
            print(f"Agent '{args.info}' not found")
    
    elif args.capability:
        agents = find_agents_by_capability(args.capability)
        print(f"\n🔍 Agents with capability '{args.capability}':")
        for agent in agents:
            print(f"  • {agent}")
    
    elif args.type:
        agents = find_agents_by_type(args.type)
        print(f"\n📁 Agents of type '{args.type}':")
        for agent in agents:
            print(f"  • {agent}")
    
    elif args.test:
        # Run test suite
        test_inputs = [
            "There's a security vulnerability in our authentication system",
            "Deploy the new features to production with zero downtime",
            "Optimize the database queries for better performance",
            "Build a React frontend with TypeScript and REST API",
            "Production is down, customers can't login",
            "Perform a red team exercise on our infrastructure",
            "Setup ML pipeline for fraud detection",
            "Review this pull request for security issues",
            "Create a mobile app for Android and iOS",
            "Monitor system health and setup alerts",
            "Analyze quantum-resistant encryption options",
            "Debug the memory leak in the C++ service",
            "Setup Docker containers with Kubernetes orchestration",
            "Implement BGP routing security measures"
        ]
        
        print("\n🧪 Fuzzy Matcher Test Suite")
        print("=" * 70)
        
        matcher = ClaudeFuzzyMatcher()
        for test_input in test_inputs:
            print(f"\n📝 Input: {test_input}")
            print("-" * 70)
            
            results = matcher.match(test_input)
            print(f"✓ Confidence: {results['confidence']:.2f}")
            print(f"🤖 Agents: {', '.join(results['matched_agents'][:3])}")
            
            if results['workflow']:
                print(f"📋 Workflow: {results['workflow']}")
            
            if results['reasoning']:
                print(f"💭 Reasoning: {results['reasoning'][0]}")
            
            print(f"⚡ Mode: {results['execution_mode'].value}")
            
            command = matcher.get_invocation_command(test_input)
            if command:
                print(f"💻 Command: {command[:100]}...")
    
    elif args.input:
        # Match user input
        print(f"\n🔍 Matching: {args.input}")
        print("=" * 70)
        
        results = fuzzy_match_agents(args.input)
        print(f"\n✓ Confidence: {results['confidence']:.2f}")
        print(f"🤖 Matched Agents: {', '.join(results['matched_agents'])}")
        
        if results['workflow']:
            print(f"📋 Workflow: {results['workflow']}")
        
        print(f"⚡ Execution Mode: {results['execution_mode'].value}")
        
        if results['reasoning']:
            print("\n💭 Reasoning:")
            for reason in results['reasoning']:
                print(f"  • {reason}")
        
        command = get_agent_command(args.input)
        if command:
            print(f"\n💻 Task Command:")
            print(f"  {command}")
    
    else:
        parser.print_help()
