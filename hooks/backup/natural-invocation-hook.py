#!/usr/bin/env python3
"""
Enhanced Natural Agent Invocation Hook v2.0
Automatic agent discovery and invocation for Claude Code with full 58+ agent support
"""

import json
import logging
import os
import re
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment-based configuration
BASE_PATH = os.environ.get("CLAUDE_BASE_PATH", Path.home() / ".config" / "claude")
AGENTS_PATH = os.environ.get("CLAUDE_AGENTS_PATH", Path.home() / "agents")
BACKUP_PATH = os.environ.get(
    "CLAUDE_BACKUP_PATH", Path.home() / "Documents" / "claude-backups"
)

# Add paths for imports
sys.path.insert(0, str(BASE_PATH))
sys.path.insert(0, str(BACKUP_PATH))
sys.path.insert(0, str(BACKUP_PATH / "tools"))

# Import enhanced matchers with fallback
try:
    from agent_semantic_matcher import EnhancedAgentMatcher
    from claude_fuzzy_agent_matcher import (
        AgentRegistry,
        ClaudeFuzzyMatcher,
        ExecutionMode,
    )

    ENHANCED_MATCHING = True
    logger.info("Enhanced matching enabled")
except ImportError:
    logger.warning("Enhanced matchers not available, using fallback")
    ENHANCED_MATCHING = False

    # Fallback implementation
    class ExecutionMode(Enum):
        INTELLIGENT = "INTELLIGENT"
        PYTHON_ONLY = "PYTHON_ONLY"
        SPEED_CRITICAL = "SPEED_CRITICAL"
        REDUNDANT = "REDUNDANT"

    class ClaudeFuzzyMatcher:
        def __init__(self):
            self.registry = None

        def match(self, user_input: str) -> dict:
            return {
                "confidence": 0.0,
                "matched_agents": [],
                "workflow": None,
                "reasoning": [],
                "execution_mode": ExecutionMode.INTELLIGENT,
            }

        def get_invocation_command(self, user_input: str) -> Optional[str]:
            return None


@dataclass
class InvocationContext:
    """Context for agent invocation"""

    user_input: str
    agents: List[str]
    confidence: float
    workflow: Optional[str] = None
    execution_mode: ExecutionMode = ExecutionMode.INTELLIGENT
    reasoning: List[str] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)


class EnhancedNaturalInvocationHook:
    """
    Advanced natural agent invocation with full system integration
    """

    def __init__(self):
        self.agents_root = Path(AGENTS_PATH)
        self.base_path = Path(BASE_PATH)

        # Initialize matchers
        if ENHANCED_MATCHING:
            self.fuzzy_matcher = ClaudeFuzzyMatcher()
            self.semantic_matcher = EnhancedAgentMatcher()
        else:
            self.fuzzy_matcher = None
            self.semantic_matcher = None

        # Load agent registry
        self.agent_registry = self._load_agent_registry()

        # Pattern triggers for all 58+ agents
        self.pattern_triggers = self._initialize_pattern_triggers()

        # Workflow patterns
        self.workflow_patterns = self._initialize_workflow_patterns()

        # Cache for agent files
        self.agent_cache = {}

    def _load_agent_registry(self) -> Dict[str, Dict[str, Any]]:
        """Load complete agent registry"""
        registry = {}

        # Try to load from registry file
        registry_file = self.base_path / "agent-registry.json"
        if registry_file.exists():
            try:
                with open(registry_file, "r") as f:
                    registry = json.load(f)
            except:
                pass

        # Scan agent files if directory exists
        if self.agents_root.exists():
            for agent_file in self.agents_root.glob("*.md"):
                agent_name = agent_file.stem.lower()
                if agent_name not in registry:
                    registry[agent_name] = {
                        "file": str(agent_file),
                        "type": "UNKNOWN",
                        "capabilities": [],
                    }

        return registry

    def _initialize_pattern_triggers(self) -> Dict[str, Dict[str, Any]]:
        """Initialize comprehensive pattern triggers for all agents"""
        return {
            # ORCHESTRATORS
            "director": {
                "patterns": [
                    "coordinate",
                    "manage",
                    "orchestrate",
                    "plan",
                    "strategic",
                    "roadmap",
                ],
                "regex": [
                    r"high[\s-]?level",
                    r"big[\s-]?picture",
                    r"overall\s+strategy",
                ],
                "priority": 5,
            },
            "projectorchestrator": {
                "patterns": [
                    "project",
                    "workflow",
                    "pipeline",
                    "process",
                    "tasks",
                    "coordinate",
                ],
                "regex": [r"multi[\s-]?agent", r"task\s+coordination"],
                "priority": 4,
            },
            "redteamorchestrator": {
                "patterns": [
                    "red team",
                    "penetration",
                    "attack simulation",
                    "adversarial",
                ],
                "regex": [r"red[\s-]?team", r"pen[\s-]?test"],
                "priority": 4,
            },
            # SECURITY
            "cso": {
                "patterns": [
                    "security",
                    "audit",
                    "vulnerability",
                    "compliance",
                    "risk",
                ],
                "regex": [r"security\s+(?:audit|review)", r"compliance\s+check"],
                "priority": 5,
            },
            "security": {
                "patterns": ["secure", "protect", "threat", "vulnerability", "scan"],
                "regex": [r"security\s+scan", r"threat\s+detection"],
                "priority": 4,
            },
            "securityauditor": {
                "patterns": [
                    "security audit",
                    "code review",
                    "compliance",
                    "verification",
                ],
                "regex": [r"security\s+audit", r"compliance\s+verification"],
                "priority": 4,
            },
            "securitychaosagent": {
                "patterns": ["chaos testing", "fuzzing", "stress test", "break"],
                "regex": [r"chaos\s+test", r"fuzz(?:ing)?", r"stress\s+test"],
                "priority": 3,
            },
            "cryptoexpert": {
                "patterns": [
                    "crypto",
                    "encryption",
                    "decrypt",
                    "cipher",
                    "certificate",
                    "ssl",
                ],
                "regex": [r"encrypt(?:ion)?", r"decrypt(?:ion)?", r"crypto(?:graphy)?"],
                "priority": 4,
            },
            "quantumguard": {
                "patterns": ["quantum", "post-quantum", "quantum-safe", "pqc"],
                "regex": [r"quantum[\s-]?(?:safe|resistant)", r"post[\s-]?quantum"],
                "priority": 4,
            },
            "bastion": {
                "patterns": [
                    "bastion",
                    "jumphost",
                    "ssh",
                    "access control",
                    "perimeter",
                ],
                "regex": [r"bastion\s+host", r"jump[\s-]?(?:host|box)"],
                "priority": 5,
            },
            # INTELLIGENCE
            "nsa": {
                "patterns": [
                    "sigint",
                    "signals",
                    "intelligence",
                    "intercept",
                    "surveillance",
                ],
                "regex": [r"signal\s+intelligence", r"traffic\s+analysis"],
                "priority": 5,
            },
            "apt41-defense-agent": {
                "patterns": ["apt", "advanced threat", "nation state", "attribution"],
                "regex": [r"apt\s+defense", r"nation[\s-]?state"],
                "priority": 5,
            },
            "bgp-purple-team-agent": {
                "patterns": ["bgp", "routing", "purple team", "network security"],
                "regex": [r"bgp\s+security", r"purple[\s-]?team"],
                "priority": 4,
            },
            "psyops_agent": {
                "patterns": ["psyops", "social engineering", "influence", "deception"],
                "regex": [r"psy(?:chological)?\s+ops", r"social\s+engineering"],
                "priority": 4,
            },
            # DEVELOPMENT
            "leadengineer": {
                "patterns": [
                    "lead",
                    "technical lead",
                    "architecture",
                    "code review",
                    "mentor",
                ],
                "regex": [r"lead\s+engineer", r"technical\s+lead"],
                "priority": 4,
            },
            "constructor": {
                "patterns": [
                    "build",
                    "create",
                    "scaffold",
                    "generate",
                    "setup",
                    "construct",
                ],
                "regex": [r"create\s+(?:new\s+)?(?:project|app)", r"scaffold(?:ing)?"],
                "priority": 3,
            },
            "debugger": {
                "patterns": [
                    "debug",
                    "trace",
                    "investigate",
                    "troubleshoot",
                    "diagnose",
                    "error",
                ],
                "regex": [r"debug(?:ging)?", r"stack\s+trace", r"error\s+analysis"],
                "priority": 4,
            },
            "patcher": {
                "patterns": ["fix", "patch", "repair", "resolve", "correct", "hotfix"],
                "regex": [r"(?:hot)?fix", r"patch(?:ing)?", r"bug\s+fix"],
                "priority": 4,
            },
            "linter": {
                "patterns": [
                    "lint",
                    "format",
                    "style",
                    "clean",
                    "beautify",
                    "standards",
                ],
                "regex": [r"code\s+(?:style|format)", r"lint(?:ing)?"],
                "priority": 2,
            },
            # LANGUAGE-SPECIFIC
            "python-internal": {
                "patterns": ["python", "py", "pip", "django", "flask", "pandas"],
                "regex": [r"\.py\b", r"python(?:3)?", r"pip\s+install"],
                "priority": 3,
            },
            "rust-internal": {
                "patterns": ["rust", "cargo", "rustc", "lifetime", "borrow"],
                "regex": [r"\.rs\b", r"cargo\s+\w+", r"rust(?:lang)?"],
                "priority": 3,
            },
            "go-internal": {
                "patterns": ["golang", "go", "goroutine", "channel", "defer"],
                "regex": [r"\.go\b", r"go\s+mod", r"go(?:lang)?"],
                "priority": 3,
            },
            "typescript-internal": {
                "patterns": ["typescript", "ts", "tsx", "types", "interface"],
                "regex": [r"\.tsx?", r"type\s+\w+\s+="],
                "priority": 3,
            },
            "cpp_internal_agent": {
                "patterns": ["cpp", "c++", "stl", "template", "pointer"],
                "regex": [r"\.cpp\b", r"std::", r"c\+\+"],
                "priority": 3,
            },
            "c-internal": {
                "patterns": ["c language", "malloc", "pointer", "struct", "embedded"],
                "regex": [r"\bc\b", r"\.c\b", r"malloc|free"],
                "priority": 3,
            },
            "java-internal": {
                "patterns": ["java", "jvm", "spring", "maven", "gradle"],
                "regex": [r"\.java\b", r"public\s+class"],
                "priority": 3,
            },
            "kotlin-internal": {
                "patterns": ["kotlin", "android", "coroutine", "suspend"],
                "regex": [r"\.kt\b", r"suspend\s+fun"],
                "priority": 3,
            },
            "zig-internal": {
                "patterns": ["zig", "comptime", "allocator"],
                "regex": [r"\.zig\b", r"zig(?:lang)?"],
                "priority": 2,
            },
            "assembly-internal-agent": {
                "patterns": ["assembly", "asm", "nasm", "masm", "register"],
                "regex": [r"\.(?:asm|s)\b", r"mov\s+\w+,"],
                "priority": 2,
            },
            "carbon-internal": {
                "patterns": ["carbon", "carbon-lang", "experimental"],
                "regex": [r"\.carbon\b", r"carbon(?:-lang)?"],
                "priority": 2,
            },
            # UI/FRONTEND
            "web": {
                "patterns": [
                    "web",
                    "frontend",
                    "react",
                    "vue",
                    "angular",
                    "html",
                    "css",
                ],
                "regex": [r"(?:web|frontend)\s+(?:app|development)"],
                "priority": 3,
            },
            "androidmobile": {
                "patterns": ["android", "mobile", "app", "apk", "gradle"],
                "regex": [r"android\s+app", r"mobile\s+development"],
                "priority": 3,
            },
            "pygui": {
                "patterns": ["gui", "desktop", "tkinter", "pyqt", "kivy"],
                "regex": [r"desktop\s+app", r"gui\s+application"],
                "priority": 2,
            },
            "tui": {
                "patterns": [
                    "tui",
                    "terminal ui",
                    "console",
                    "ncurses",
                    "cli interface",
                ],
                "regex": [r"terminal\s+ui", r"console\s+interface"],
                "priority": 2,
            },
            # DATA & ML
            "datascience": {
                "patterns": [
                    "data science",
                    "analysis",
                    "statistics",
                    "visualization",
                    "pandas",
                ],
                "regex": [r"data\s+(?:science|analysis)", r"statistical\s+analysis"],
                "priority": 3,
            },
            "mlops": {
                "patterns": ["mlops", "ml pipeline", "model deployment", "kubeflow"],
                "regex": [r"ml\s*ops", r"model\s+deployment"],
                "priority": 3,
            },
            "researcher": {
                "patterns": [
                    "research",
                    "investigate",
                    "explore",
                    "study",
                    "literature",
                ],
                "regex": [r"research(?:ing)?", r"literature\s+review"],
                "priority": 3,
            },
            # INFRASTRUCTURE
            "infrastructure": {
                "patterns": [
                    "infrastructure",
                    "terraform",
                    "kubernetes",
                    "k8s",
                    "cloud",
                ],
                "regex": [r"infrastructure(?:\s+as\s+code)?", r"terraform|kubernetes"],
                "priority": 4,
            },
            "docker-agent": {
                "patterns": ["docker", "container", "dockerfile", "compose"],
                "regex": [r"docker(?:file)?", r"container(?:ization)?"],
                "priority": 3,
            },
            "proxmox-agent": {
                "patterns": ["proxmox", "vm", "virtual machine", "hypervisor"],
                "regex": [r"proxmox", r"virtual\s+machine"],
                "priority": 3,
            },
            "cisco-agent": {
                "patterns": ["cisco", "network", "router", "switch", "vlan"],
                "regex": [r"cisco\s+\w+", r"network\s+config"],
                "priority": 3,
            },
            "ddwrt-agent": {
                "patterns": ["ddwrt", "router firmware", "openwrt"],
                "regex": [r"dd[\s-]?wrt", r"router\s+firmware"],
                "priority": 2,
            },
            # OPERATIONS
            "deployer": {
                "patterns": ["deploy", "release", "rollout", "production", "staging"],
                "regex": [r"deploy(?:ment)?", r"release\s+to\s+\w+"],
                "priority": 4,
            },
            "monitor": {
                "patterns": ["monitor", "track", "observe", "metrics", "alerting"],
                "regex": [r"monitor(?:ing)?", r"observability"],
                "priority": 3,
            },
            "packager": {
                "patterns": ["package", "bundle", "artifact", "dependency"],
                "regex": [r"packag(?:e|ing)", r"bundle\s+\w+"],
                "priority": 3,
            },
            # SPECIALIZED
            "database": {
                "patterns": ["database", "sql", "query", "schema", "migration"],
                "regex": [r"database|db", r"sql\s+query"],
                "priority": 3,
            },
            "apidesigner": {
                "patterns": ["api", "endpoint", "rest", "graphql", "swagger"],
                "regex": [r"api\s+design", r"rest(?:ful)?"],
                "priority": 3,
            },
            "docgen": {
                "patterns": ["documentation", "docs", "readme", "guide", "manual"],
                "regex": [r"document(?:ation)?", r"readme"],
                "priority": 2,
            },
            "testbed": {
                "patterns": ["test", "testing", "validate", "verify", "qa"],
                "regex": [r"test(?:ing)?", r"unit\s+test"],
                "priority": 3,
            },
            "qadirector": {
                "patterns": ["qa", "quality assurance", "test planning", "coverage"],
                "regex": [r"qa\s+strategy", r"test\s+planning"],
                "priority": 4,
            },
            "optimizer": {
                "patterns": [
                    "optimize",
                    "performance",
                    "speed",
                    "efficiency",
                    "benchmark",
                ],
                "regex": [r"optimiz(?:e|ation)", r"performance\s+tuning"],
                "priority": 4,
            },
            "oversight": {
                "patterns": [
                    "oversight",
                    "audit",
                    "compliance",
                    "governance",
                    "policy",
                ],
                "regex": [r"compliance\s+check", r"policy\s+enforcement"],
                "priority": 4,
            },
            "planner": {
                "patterns": ["plan", "planning", "schedule", "timeline", "roadmap"],
                "regex": [r"plan(?:ning)?", r"project\s+timeline"],
                "priority": 3,
            },
            "integration": {
                "patterns": [
                    "integration",
                    "integrate",
                    "connect",
                    "bridge",
                    "interface",
                ],
                "regex": [r"integrat(?:e|ion)", r"api\s+integration"],
                "priority": 3,
            },
            # HARDWARE
            "npu": {
                "patterns": [
                    "npu",
                    "neural processing",
                    "ai acceleration",
                    "inference",
                ],
                "regex": [r"npu|neural\s+processing", r"ai\s+acceleration"],
                "priority": 3,
            },
            "gna": {
                "patterns": ["gna", "gaussian neural", "low power ai"],
                "regex": [r"gna|gaussian\s+neural"],
                "priority": 2,
            },
            "iot-access-control-agent": {
                "patterns": ["iot", "device", "sensor", "mqtt", "embedded"],
                "regex": [r"iot|internet\s+of\s+things", r"device\s+management"],
                "priority": 3,
            },
        }

    def _initialize_workflow_patterns(self) -> Dict[str, Dict[str, Any]]:
        """Initialize workflow detection patterns"""
        return {
            "security_assessment": {
                "triggers": [
                    "security audit",
                    "vulnerability assessment",
                    "compliance check",
                ],
                "agents": ["cso", "securityauditor", "security", "cryptoexpert"],
                "coordinator": "cso",
                "confidence_boost": 0.2,
            },
            "incident_response": {
                "triggers": [
                    "production down",
                    "emergency",
                    "critical issue",
                    "outage",
                ],
                "agents": ["debugger", "monitor", "patcher", "deployer"],
                "coordinator": "leadengineer",
                "confidence_boost": 0.3,
            },
            "deployment_pipeline": {
                "triggers": ["deploy to production", "release pipeline", "ci/cd"],
                "agents": ["deployer", "testbed", "monitor", "infrastructure"],
                "coordinator": "deployer",
                "confidence_boost": 0.2,
            },
            "full_stack_development": {
                "triggers": [
                    "full stack",
                    "end to end application",
                    "frontend and backend",
                ],
                "agents": ["web", "apidesigner", "database", "infrastructure"],
                "coordinator": "leadengineer",
                "confidence_boost": 0.15,
            },
            "ml_pipeline": {
                "triggers": [
                    "ml pipeline",
                    "machine learning deployment",
                    "model training",
                ],
                "agents": ["mlops", "datascience", "optimizer", "monitor"],
                "coordinator": "mlops",
                "confidence_boost": 0.2,
            },
            "quantum_migration": {
                "triggers": ["quantum safe", "post quantum", "pqc migration"],
                "agents": ["quantumguard", "cryptoexpert", "security"],
                "coordinator": "quantumguard",
                "confidence_boost": 0.25,
            },
            "red_team_exercise": {
                "triggers": ["red team", "penetration test", "attack simulation"],
                "agents": [
                    "redteamorchestrator",
                    "apt41-defense-agent",
                    "securitychaosagent",
                ],
                "coordinator": "redteamorchestrator",
                "confidence_boost": 0.3,
            },
        }

    def analyze_input(self, user_input: str) -> InvocationContext:
        """
        Comprehensive input analysis using all available methods
        """
        context = InvocationContext(user_input=user_input, agents=[], confidence=0.0)

        # Try enhanced fuzzy matching first
        if self.fuzzy_matcher and ENHANCED_MATCHING:
            try:
                results = self.fuzzy_matcher.match(user_input)
                context.agents = results.get("matched_agents", [])
                context.confidence = results.get("confidence", 0.0)
                context.workflow = results.get("workflow")
                context.execution_mode = results.get(
                    "execution_mode", ExecutionMode.INTELLIGENT
                )
                context.reasoning = results.get("reasoning", [])

                if context.confidence > 0.7:
                    return context
            except Exception as e:
                logger.warning(f"Fuzzy matching failed: {e}")

        # Fallback to pattern-based matching
        matched_agents = self._pattern_match(user_input)
        if matched_agents:
            context.agents = [a[0] for a in matched_agents[:5]]
            context.confidence = matched_agents[0][1] if matched_agents else 0.0
            context.reasoning.append("Pattern-based matching")

        # Check for workflow patterns
        workflow = self._detect_workflow(user_input)
        if workflow:
            context.workflow = workflow["name"]
            context.agents = workflow["agents"]
            context.confidence = max(context.confidence, workflow["confidence"])
            context.reasoning.append(f"Workflow detected: {workflow['name']}")

        # Check for explicit agent mentions
        explicit = self._find_explicit_mentions(user_input)
        if explicit:
            context.agents = explicit
            context.confidence = 1.0
            context.reasoning.append("Explicit agent mention")

        return context

    def _pattern_match(self, user_input: str) -> List[Tuple[str, float]]:
        """Pattern-based agent matching"""
        input_lower = user_input.lower()
        matches = []

        for agent_name, config in self.pattern_triggers.items():
            score = 0.0

            # Check patterns
            for pattern in config.get("patterns", []):
                if pattern in input_lower:
                    position = input_lower.index(pattern)
                    # Score based on position and pattern length
                    pattern_score = (1 - position / len(input_lower)) * (
                        len(pattern) / 20
                    )
                    score = max(score, pattern_score)

            # Check regex patterns
            for regex_pattern in config.get("regex", []):
                if re.search(regex_pattern, input_lower):
                    score = max(score, 0.8)

            # Apply priority multiplier
            priority = config.get("priority", 3)
            score *= priority / 3

            if score > 0.3:
                matches.append((agent_name, min(score, 1.0)))

        return sorted(matches, key=lambda x: x[1], reverse=True)

    def _detect_workflow(self, user_input: str) -> Optional[Dict[str, Any]]:
        """Detect workflow patterns"""
        input_lower = user_input.lower()

        for workflow_name, workflow_config in self.workflow_patterns.items():
            for trigger in workflow_config["triggers"]:
                if trigger in input_lower:
                    return {
                        "name": workflow_name,
                        "agents": workflow_config["agents"],
                        "coordinator": workflow_config["coordinator"],
                        "confidence": 0.8 + workflow_config["confidence_boost"],
                    }

        return None

    def _find_explicit_mentions(self, user_input: str) -> List[str]:
        """Find explicit agent mentions"""
        input_lower = user_input.lower()
        mentioned = []

        for agent_name in self.pattern_triggers.keys():
            # Check for direct mention
            if agent_name.replace("-", " ").replace("_", " ") in input_lower:
                mentioned.append(agent_name)
            # Check for "use X agent" pattern
            elif re.search(
                rf"\b(?:use|invoke|call|activate)\s+(?:the\s+)?{re.escape(agent_name)}\b",
                input_lower,
            ):
                mentioned.append(agent_name)

        return mentioned

    def format_invocation(self, context: InvocationContext) -> str:
        """
        Format the agent invocation for Claude Code
        """
        if not context.agents:
            return ""

        # Single agent invocation
        if len(context.agents) == 1:
            agent = context.agents[0]
            return f"""Task(
    subagent_type="{agent}",
    prompt="{context.user_input}",
    mode="{context.execution_mode.value}"
)"""

        # Multi-agent workflow
        if context.workflow:
            coordinator = self.workflow_patterns.get(context.workflow, {}).get(
                "coordinator", "projectorchestrator"
            )
            agents_str = ", ".join(context.agents[:3])
            return f"""Task(
    subagent_type="{coordinator}",
    prompt="Coordinate {context.workflow.replace('_', ' ')}: {context.user_input}",
    mode="{context.execution_mode.value}",
    workflow="{context.workflow}",
    agents=[{', '.join([f'"{a}"' for a in context.agents[:3]])}]
)"""

        # Multiple agents without specific workflow
        agents_str = ", ".join(context.agents[:3])
        return f"""Task(
    subagent_type="projectorchestrator",
    prompt="Coordinate {agents_str}: {context.user_input}",
    mode="{context.execution_mode.value}",
    agents=[{', '.join([f'"{a}"' for a in context.agents[:3]])}]
)"""

    def suggest_invocation(
        self, user_input: str, threshold: float = 0.6
    ) -> Optional[str]:
        """
        Generate invocation suggestion if confidence is high enough
        """
        context = self.analyze_input(user_input)

        if context.confidence < threshold:
            return None

        suggestion = f"""
# 🎯 Natural Agent Invocation Detected
# Confidence: {context.confidence:.1%}
# Agents: {', '.join(context.agents[:3])}
"""

        if context.workflow:
            suggestion += f"# Workflow: {context.workflow.replace('_', ' ').title()}\n"

        if context.reasoning:
            suggestion += f"# Reasoning: {'; '.join(context.reasoning[:2])}\n"

        suggestion += f"""
# Suggested invocation:
{self.format_invocation(context)}
"""

        return suggestion

    def get_agent_info(self, agent_name: str) -> Dict[str, Any]:
        """Get detailed information about an agent"""
        # Check cache first
        if agent_name in self.agent_cache:
            return self.agent_cache[agent_name]

        info = {
            "name": agent_name,
            "exists": False,
            "file": None,
            "capabilities": [],
            "priority": 3,
        }

        # Check registry
        if agent_name in self.agent_registry:
            info.update(self.agent_registry[agent_name])
            info["exists"] = True

        # Check pattern triggers
        if agent_name in self.pattern_triggers:
            trigger_info = self.pattern_triggers[agent_name]
            info["patterns"] = trigger_info.get("patterns", [])
            info["priority"] = trigger_info.get("priority", 3)

        # Try to find agent file
        agent_file = self.agents_root / f"{agent_name.upper()}.md"
        if not agent_file.exists():
            # Try variations
            for file in self.agents_root.glob("*.md"):
                if file.stem.lower() == agent_name.lower().replace("-", "").replace(
                    "_", ""
                ):
                    agent_file = file
                    break

        if agent_file.exists():
            info["exists"] = True
            info["file"] = str(agent_file)

            try:
                content = agent_file.read_text()
                # Extract capabilities from content
                if "capabilities:" in content:
                    caps_match = re.search(
                        r"capabilities:\s*\[(.*?)\]", content, re.DOTALL
                    )
                    if caps_match:
                        caps = [
                            c.strip().strip("\"'")
                            for c in caps_match.group(1).split(",")
                        ]
                        info["capabilities"] = caps
            except:
                pass

        # Cache the result
        self.agent_cache[agent_name] = info

        return info


# Hook functions for Claude Code integration
def hook_pre_task(context: Dict[str, Any]) -> Dict[str, Any]:
    """Pre-task hook for agent discovery"""
    hook = EnhancedNaturalInvocationHook()

    user_message = context.get("user_message", "")
    if not user_message:
        return context

    suggestion = hook.suggest_invocation(user_message)
    if suggestion:
        context["agent_suggestion"] = suggestion
        context["natural_invocation"] = True
        context["invocation_context"] = hook.analyze_input(user_message)

    return context


def hook_post_edit(context: Dict[str, Any]) -> Dict[str, Any]:
    """Post-edit hook for follow-up suggestions"""
    file_path = context.get("file_path", "")

    suggestions = []

    # Language-specific suggestions
    if file_path.endswith(".py"):
        suggestions.append(
            "Consider 'python-internal' agent for Python-specific optimization"
        )
    elif file_path.endswith(".rs"):
        suggestions.append(
            "Consider 'rust-internal' agent for Rust memory safety checks"
        )
    elif file_path.endswith(".go"):
        suggestions.append("Consider 'go-internal' agent for Go concurrency patterns")
    elif file_path.endswith((".ts", ".tsx")):
        suggestions.append("Consider 'typescript-internal' agent for type safety")

    # General suggestions
    if any(
        file_path.endswith(ext) for ext in [".py", ".js", ".ts", ".go", ".rs", ".java"]
    ):
        suggestions.append("Consider 'testbed' agent to validate changes")
        suggestions.append("Consider 'linter' agent for code style")

    if suggestions:
        context["follow_up_suggestions"] = suggestions

    return context


def hook_conversation_analysis(messages: List[Dict[str, str]]) -> Optional[str]:
    """Analyze conversation for agent suggestions"""
    if not messages:
        return None

    hook = EnhancedNaturalInvocationHook()

    # Combine recent messages
    recent_context = " ".join([m.get("content", "") for m in messages[-5:]])

    context = hook.analyze_input(recent_context)

    if context.confidence > 0.7:
        agents_str = ", ".join(context.agents[:3])
        suggestion = f"Based on the conversation, these agents might help: {agents_str}"
        if context.workflow:
            suggestion += f" (Workflow: {context.workflow.replace('_', ' ')})"
        suggestion += f" - Confidence: {context.confidence:.0%}"
        return suggestion

    return None


# CLI interface for testing
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Enhanced Natural Agent Invocation Hook"
    )
    parser.add_argument("input", nargs="*", help="User input to analyze")
    parser.add_argument("--test", action="store_true", help="Run test suite")
    parser.add_argument("--agents", action="store_true", help="List all agents")
    parser.add_argument("--info", help="Get info about specific agent")

    args = parser.parse_args()

    hook = EnhancedNaturalInvocationHook()

    if args.agents:
        print("\n🤖 Registered Agents:")
        print("=" * 70)
        for agent_name in sorted(hook.pattern_triggers.keys()):
            info = hook.get_agent_info(agent_name)
            priority = info.get("priority", 3)
            exists = "✓" if info["exists"] else "✗"
            print(f"  {exists} {agent_name:30} Priority: {priority}")

    elif args.info:
        info = hook.get_agent_info(args.info)
        print(f"\n🤖 Agent: {args.info}")
        print("=" * 70)
        print(f"Exists: {info['exists']}")
        print(f"Priority: {info.get('priority', 3)}")
        if info.get("patterns"):
            print(f"Patterns: {', '.join(info['patterns'][:5])}")
        if info.get("capabilities"):
            print(f"Capabilities: {', '.join(info['capabilities'][:5])}")
        if info.get("file"):
            print(f"File: {info['file']}")

    elif args.test:
        test_cases = [
            "I need to debug this Python memory leak",
            "Deploy the application to production with zero downtime",
            "Perform a security audit with penetration testing",
            "Build a React frontend with TypeScript and REST API",
            "Production is down, customers can't login",
            "Setup quantum-resistant encryption",
            "Red team exercise on our BGP infrastructure",
            "Optimize the ML pipeline for better performance",
            "Create a mobile app for Android and iOS",
            "Monitor system health and setup alerts",
            "Implement post-quantum cryptography migration",
            "Debug the segfault in the C++ service",
            "Configure Proxmox cluster with HA",
            "Social engineering awareness training",
        ]

        print("\n🧪 Natural Invocation Test Suite")
        print("=" * 70)

        for test_input in test_cases:
            print(f"\n📝 Input: {test_input}")
            print("-" * 60)

            context = hook.analyze_input(test_input)

            if context.agents:
                print(f"✓ Agents: {', '.join(context.agents[:3])}")
                print(f"✓ Confidence: {context.confidence:.1%}")
                if context.workflow:
                    print(f"✓ Workflow: {context.workflow}")
                print(f"✓ Mode: {context.execution_mode.value}")

                command = hook.format_invocation(context)
                print(f"💻 Command:")
                for line in command.split("\n"):
                    print(f"   {line}")
            else:
                print("✗ No agent match")

    elif args.input:
        user_input = " ".join(args.input)

        print(f"\n🔍 Analyzing: {user_input}")
        print("=" * 70)

        context = hook.analyze_input(user_input)

        if context.agents:
            print(f"\n✓ Confidence: {context.confidence:.1%}")
            print(f"🤖 Agents: {', '.join(context.agents)}")

            if context.workflow:
                print(f"📋 Workflow: {context.workflow}")

            print(f"⚡ Execution Mode: {context.execution_mode.value}")

            if context.reasoning:
                print("\n💭 Reasoning:")
                for reason in context.reasoning:
                    print(f"  • {reason}")

            suggestion = hook.suggest_invocation(user_input)
            if suggestion:
                print("\n💡 Suggestion:")
                print(suggestion)
        else:
            print("\n✗ No agents matched (confidence too low)")

    else:
        parser.print_help()
