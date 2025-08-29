#!/usr/bin/env python3
"""
Claude Unified Hook System v3.0
Consolidates all hook functionality into a single, efficient system
Eliminates bridges and redundant components
"""

import os
import sys
import json
import re
import asyncio
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Set
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import logging
from difflib import SequenceMatcher

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('UnifiedHooks')

# ============================================================================
# CONFIGURATION
# ============================================================================

@dataclass
class UnifiedConfig:
    """Single configuration for entire hook system"""
    
    # Paths - dynamically discovered
    project_root: Path = None
    agents_dir: Path = None
    config_dir: Path = None
    cache_dir: Path = None
    shadow_repo: Path = None
    
    # Feature flags
    enable_fuzzy_matching: bool = True
    enable_semantic_matching: bool = True
    enable_natural_invocation: bool = True
    enable_shadowgit: bool = False  # Will be True when implemented
    enable_learning: bool = True
    
    # Performance
    cache_ttl_seconds: int = 3600
    max_parallel_agents: int = 8
    confidence_threshold: float = 0.7
    
    def __post_init__(self):
        """Initialize paths dynamically"""
        if not self.project_root:
            self.project_root = self._find_project_root()
        if not self.agents_dir:
            self.agents_dir = self.project_root / 'agents'
        if not self.config_dir:
            self.config_dir = Path.home() / '.config' / 'claude'
        if not self.cache_dir:
            self.cache_dir = Path.home() / '.cache' / 'claude-agents'
        if not self.shadow_repo:
            self.shadow_repo = self.project_root / '.shadowgit'
            
        # Create directories
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    def _find_project_root(self) -> Path:
        """Find project root by looking for markers"""
        current = Path.cwd()
        markers = ['CLAUDE.md', 'agents', '.git', '.claude']
        
        while current != current.parent:
            for marker in markers:
                if (current / marker).exists():
                    logger.info(f"Found project root at: {current}")
                    return current
            current = current.parent
        
        # Fallback to current directory
        logger.warning(f"Project root not found, using: {Path.cwd()}")
        return Path.cwd()

# ============================================================================
# AGENT REGISTRY (Consolidated from bridge + individual files)
# ============================================================================

class UnifiedAgentRegistry:
    """Single registry for all 76 agents"""
    
    # Complete agent definitions from CLAUDE.md
    AGENT_CATEGORIES = {
        "command_control": ["DIRECTOR", "PROJECTORCHESTRATOR"],
        "security": [
            "SECURITY", "BASTION", "SECURITYCHAOSAGENT", "SECURITYAUDITOR",
            "CSO", "CRYPTOEXPERT", "QUANTUMGUARD", "REDTEAMORCHESTRATOR",
            "APT41-DEFENSE-AGENT", "APT41-REDTEAM-AGENT", "NSA", "PSYOPS-AGENT",
            "GHOST-PROTOCOL-AGENT", "COGNITIVE_DEFENSE_AGENT", "BGP-BLUE-TEAM",
            "BGP-PURPLE-TEAM-AGENT", "BGP-RED-TEAM", "CHAOS-AGENT",
            "CLAUDECODE-PROMPTINJECTOR", "PROMPT-DEFENDER", "PROMPT-INJECTOR", "RED-TEAM"
        ],
        "development": [
            "ARCHITECT", "CONSTRUCTOR", "PATCHER", "DEBUGGER",
            "TESTBED", "LINTER", "OPTIMIZER", "QADIRECTOR"
        ],
        "infrastructure": [
            "INFRASTRUCTURE", "DEPLOYER", "MONITOR", "PACKAGER",
            "DOCKER-AGENT", "PROXMOX-AGENT", "CISCO-AGENT", "DDWRT-AGENT"
        ],
        "languages": [
            "C-INTERNAL", "CPP-INTERNAL-AGENT", "PYTHON-INTERNAL",
            "RUST-INTERNAL-AGENT", "GO-INTERNAL-AGENT", "JAVA-INTERNAL-AGENT",
            "TYPESCRIPT-INTERNAL-AGENT", "KOTLIN-INTERNAL-AGENT",
            "ASSEMBLY-INTERNAL-AGENT", "SQL-INTERNAL-AGENT", "ZIG-INTERNAL-AGENT"
        ],
        "platforms": [
            "APIDESIGNER", "DATABASE", "WEB", "MOBILE",
            "ANDROIDMOBILE", "PYGUI", "TUI"
        ],
        "ml_data": ["DATASCIENCE", "MLOPS", "NPU"],
        "hardware": ["GNA", "LEADENGINEER"],
        "network": ["IOT-ACCESS-CONTROL-AGENT"],
        "planning": ["PLANNER", "DOCGEN", "RESEARCHER", "StatusLine-Integration"],
        "quality": ["OVERSIGHT", "INTERGRATION", "AUDITOR"],
        "utility": [
            "ORCHESTRATOR", "CRYPTO", "QUANTUM", "CARBON-INTERNAL-AGENT",
            "WRAPPER-LIBERATION", "WRAPPER-LIBERATION-PRO"
        ]
    }
    
    def __init__(self, config: UnifiedConfig):
        self.config = config
        self.agents = {}
        self.metadata_cache = {}
        self.last_scan = None
        
        # Load agents
        self.refresh_registry()
    
    def refresh_registry(self):
        """Scan and load all agent definitions"""
        logger.info("Refreshing agent registry...")
        
        excluded = {
            "README.md", "Template.md", "TEMPLATE.md", "WHERE_I_AM.md",
            "DIRECTORY_STRUCTURE.md", "ORGANIZATION.md", "CLAUDE.md"
        }
        
        if not self.config.agents_dir.exists():
            logger.warning(f"Agents directory not found: {self.config.agents_dir}")
            return
        
        # Find all agent files
        agent_files = []
        for pattern in ["*.md", "*.MD"]:
            agent_files.extend(self.config.agents_dir.glob(pattern))
        
        agent_files = [f for f in agent_files if f.name not in excluded]
        
        # Load each agent
        for agent_file in agent_files:
            agent_name = agent_file.stem.upper()
            metadata = self._parse_agent_file(agent_file)
            
            self.agents[agent_name] = {
                "name": agent_name,
                "file": agent_file,
                "category": self._get_agent_category(agent_name),
                "description": metadata.get("description", ""),
                "tools": metadata.get("tools", []),
                "triggers": metadata.get("proactive_triggers", []),
                "invokes": metadata.get("invokes_agents", []),
                "status": metadata.get("status", "ACTIVE")
            }
        
        self.last_scan = datetime.now()
        logger.info(f"Loaded {len(self.agents)} agents")
    
    def _parse_agent_file(self, filepath: Path) -> Dict[str, Any]:
        """Parse agent metadata from markdown file"""
        if filepath in self.metadata_cache:
            return self.metadata_cache[filepath]
        
        metadata = {}
        try:
            content = filepath.read_text(encoding='utf-8')
            
            # Extract YAML frontmatter if present
            if content.startswith('---'):
                yaml_end = content.find('---', 3)
                if yaml_end > 0:
                    yaml_content = content[3:yaml_end]
                    # Simple YAML parsing (avoid dependency)
                    for line in yaml_content.split('\n'):
                        if ':' in line:
                            key, value = line.split(':', 1)
                            metadata[key.strip()] = value.strip()
            
            # Extract description from first paragraph
            if "description" not in metadata:
                lines = content.split('\n')
                for line in lines:
                    if line.strip() and not line.startswith('#'):
                        metadata["description"] = line.strip()
                        break
            
            self.metadata_cache[filepath] = metadata
        except Exception as e:
            logger.error(f"Error parsing {filepath}: {e}")
        
        return metadata
    
    def _get_agent_category(self, agent_name: str) -> str:
        """Get category for agent"""
        for category, agents in self.AGENT_CATEGORIES.items():
            if agent_name in agents:
                return category
        return "other"
    
    def get_agent(self, name: str) -> Optional[Dict]:
        """Get agent by name (case-insensitive)"""
        name_upper = name.upper()
        return self.agents.get(name_upper)
    
    def get_agents_by_category(self, category: str) -> List[Dict]:
        """Get all agents in a category"""
        return [a for a in self.agents.values() if a["category"] == category]

# ============================================================================
# PATTERN MATCHING (Consolidated from semantic + fuzzy + natural)
# ============================================================================

class UnifiedMatcher:
    """Combines all matching strategies into one"""
    
    def __init__(self, registry: UnifiedAgentRegistry, config: UnifiedConfig):
        self.registry = registry
        self.config = config
        
        # Keyword patterns for semantic matching
        self.keyword_patterns = {
            "security": ["security", "audit", "vulnerability", "threat", "crypto", "authentication"],
            "performance": ["optimize", "performance", "speed", "latency", "benchmark", "profile"],
            "testing": ["test", "qa", "quality", "validate", "verify", "coverage"],
            "deployment": ["deploy", "release", "package", "distribute", "rollout"],
            "debugging": ["debug", "error", "bug", "fix", "crash", "exception"],
            "architecture": ["design", "architecture", "structure", "pattern", "framework"],
            "documentation": ["document", "docs", "readme", "guide", "tutorial", "explain"],
            "monitoring": ["monitor", "observe", "track", "metrics", "telemetry", "logging"],
            "multi_step": ["multiple", "steps", "workflow", "pipeline", "sequence", "process"],
            "parallel": ["parallel", "concurrent", "simultaneously", "together", "async"]
        }
        
        # Direct agent triggers
        self.agent_triggers = {
            "DIRECTOR": ["strategy", "plan", "coordinate", "oversee", "direct"],
            "SECURITY": ["security", "vulnerability", "threat", "audit", "penetration"],
            "OPTIMIZER": ["optimize", "performance", "speed", "efficiency", "benchmark"],
            "DEBUGGER": ["debug", "error", "bug", "crash", "exception", "failure"],
            "ARCHITECT": ["design", "architecture", "structure", "blueprint", "pattern"],
            "MONITOR": ["monitor", "observe", "watch", "track", "metrics"],
            "DEPLOYER": ["deploy", "release", "rollout", "publish", "distribute"],
            "TESTBED": ["test", "testing", "qa", "validate", "verify"],
            "LINTER": ["lint", "code review", "style", "format", "standards"],
            "DOCGEN": ["document", "documentation", "docs", "readme", "guide"]
        }
    
    def match(self, user_input: str) -> Dict[str, Any]:
        """Unified matching combining all strategies"""
        input_lower = user_input.lower()
        
        result = {
            "agents": [],
            "confidence": 0.0,
            "strategy": None,
            "reasoning": [],
            "workflow": None
        }
        
        # Strategy 1: Direct agent mention
        direct_agents = self._match_direct_mentions(input_lower)
        if direct_agents:
            result["agents"].extend(direct_agents)
            result["confidence"] = 1.0
            result["strategy"] = "direct"
            result["reasoning"].append("Direct agent mention detected")
        
        # Strategy 2: Keyword/semantic matching
        if self.config.enable_semantic_matching:
            semantic_agents = self._match_semantic(input_lower)
            for agent, conf in semantic_agents:
                if agent not in result["agents"]:
                    result["agents"].append(agent)
                    result["confidence"] = max(result["confidence"], conf)
            if semantic_agents:
                result["strategy"] = result["strategy"] or "semantic"
                result["reasoning"].append("Semantic pattern matching")
        
        # Strategy 3: Fuzzy matching for typos
        if self.config.enable_fuzzy_matching and not result["agents"]:
            fuzzy_agents = self._match_fuzzy(user_input)
            if fuzzy_agents:
                result["agents"].extend(fuzzy_agents)
                result["confidence"] = 0.8
                result["strategy"] = "fuzzy"
                result["reasoning"].append("Fuzzy matching for possible typos")
        
        # Strategy 4: Workflow detection
        workflow = self._detect_workflow(input_lower)
        if workflow:
            result["workflow"] = workflow
            result["reasoning"].append(f"Workflow detected: {workflow}")
            
            # Add workflow-specific agents
            workflow_agents = self._get_workflow_agents(workflow)
            for agent in workflow_agents:
                if agent not in result["agents"]:
                    result["agents"].append(agent)
        
        # Strategy 5: Multi-agent coordination
        if any(word in input_lower for word in ["all", "every", "multiple", "parallel"]):
            if "security" in input_lower:
                result["agents"].extend(["SECURITY", "SECURITYAUDITOR", "GHOST-PROTOCOL-AGENT"])
            if "test" in input_lower:
                result["agents"].extend(["TESTBED", "LINTER", "QADIRECTOR"])
            result["reasoning"].append("Multi-agent coordination detected")
        
        # Ensure DIRECTOR for complex tasks
        if len(result["agents"]) > 3 and "DIRECTOR" not in result["agents"]:
            result["agents"].insert(0, "DIRECTOR")
            result["reasoning"].append("DIRECTOR added for coordination")
        
        # Remove duplicates while preserving order
        seen = set()
        unique_agents = []
        for agent in result["agents"]:
            if agent not in seen:
                seen.add(agent)
                unique_agents.append(agent)
        result["agents"] = unique_agents
        
        # Set final confidence
        if not result["confidence"] and result["agents"]:
            result["confidence"] = 0.7
        
        return result
    
    def _match_direct_mentions(self, input_text: str) -> List[str]:
        """Find directly mentioned agent names"""
        agents = []
        for agent_name in self.registry.agents.keys():
            if agent_name.lower() in input_text or agent_name.lower().replace('-', ' ') in input_text:
                agents.append(agent_name)
        return agents
    
    def _match_semantic(self, input_text: str) -> List[Tuple[str, float]]:
        """Match based on semantic patterns"""
        matched = []
        
        # Check agent-specific triggers
        for agent, triggers in self.agent_triggers.items():
            for trigger in triggers:
                if trigger in input_text:
                    matched.append((agent, 0.9))
                    break
        
        # Check category patterns
        for category, keywords in self.keyword_patterns.items():
            if any(kw in input_text for kw in keywords):
                # Add relevant agents from category
                if category == "security":
                    matched.extend([("SECURITY", 0.8), ("SECURITYAUDITOR", 0.7)])
                elif category == "performance":
                    matched.extend([("OPTIMIZER", 0.8), ("MONITOR", 0.7)])
                elif category == "testing":
                    matched.extend([("TESTBED", 0.8), ("LINTER", 0.7)])
                elif category == "deployment":
                    matched.extend([("DEPLOYER", 0.8), ("PACKAGER", 0.7)])
                elif category == "debugging":
                    matched.extend([("DEBUGGER", 0.9), ("MONITOR", 0.6)])
        
        return matched
    
    def _match_fuzzy(self, input_text: str) -> List[str]:
        """Fuzzy match for typos"""
        words = input_text.lower().split()
        matched = []
        
        for word in words:
            if len(word) < 3:
                continue
                
            for agent_name in self.registry.agents.keys():
                agent_lower = agent_name.lower()
                
                # Calculate similarity
                similarity = SequenceMatcher(None, word, agent_lower).ratio()
                
                # Also check without common suffixes
                agent_base = agent_lower.replace('-agent', '').replace('_agent', '')
                similarity_base = SequenceMatcher(None, word, agent_base).ratio()
                
                if max(similarity, similarity_base) > 0.8:
                    matched.append(agent_name)
        
        return matched
    
    def _detect_workflow(self, input_text: str) -> Optional[str]:
        """Detect workflow patterns"""
        workflows = {
            "bug_fix": ["bug", "fix", "error", "crash"],
            "new_feature": ["new feature", "implement", "create", "add feature"],
            "deployment": ["deploy", "release", "production", "rollout"],
            "security_audit": ["security audit", "vulnerability scan", "penetration test"],
            "performance": ["optimize", "performance", "speed up", "benchmark"],
            "documentation": ["document", "write docs", "readme", "guide"],
            "testing": ["test", "qa", "validate", "verify"],
            "refactor": ["refactor", "cleanup", "reorganize", "restructure"]
        }
        
        for workflow, keywords in workflows.items():
            if any(kw in input_text for kw in keywords):
                return workflow
        
        return None
    
    def _get_workflow_agents(self, workflow: str) -> List[str]:
        """Get agents for specific workflow"""
        workflow_agents = {
            "bug_fix": ["DEBUGGER", "PATCHER", "TESTBED", "MONITOR"],
            "new_feature": ["ARCHITECT", "CONSTRUCTOR", "TESTBED", "DOCGEN"],
            "deployment": ["DEPLOYER", "INFRASTRUCTURE", "MONITOR", "SECURITY"],
            "security_audit": ["SECURITY", "SECURITYAUDITOR", "GHOST-PROTOCOL-AGENT"],
            "performance": ["OPTIMIZER", "MONITOR", "NPU", "GNA"],
            "documentation": ["DOCGEN", "RESEARCHER", "PLANNER"],
            "testing": ["TESTBED", "LINTER", "QADIRECTOR", "DEBUGGER"],
            "refactor": ["ARCHITECT", "LINTER", "OPTIMIZER", "TESTBED"]
        }
        
        return workflow_agents.get(workflow, [])

# ============================================================================
# HOOK EXECUTION ENGINE
# ============================================================================

class UnifiedHookEngine:
    """Single execution engine for all hook operations"""
    
    def __init__(self, config: UnifiedConfig):
        self.config = config
        self.registry = UnifiedAgentRegistry(config)
        self.matcher = UnifiedMatcher(self.registry, config)
        
        # Execution history for learning
        self.execution_history = []
        
        # Cache for Task tool availability
        self._task_tool_available = None
    
    async def process_input(self, user_input: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Main entry point for processing user input"""
        logger.info(f"Processing input: {user_input[:100]}...")
        
        # Match agents
        match_result = self.matcher.match(user_input)
        
        if not match_result["agents"]:
            logger.warning("No agents matched")
            return {
                "success": False,
                "message": "No agents identified for this request",
                "suggestion": "Try being more specific or mentioning agent names directly"
            }
        
        logger.info(f"Matched agents: {match_result['agents']}")
        logger.info(f"Confidence: {match_result['confidence']}")
        logger.info(f"Strategy: {match_result['strategy']}")
        
        # Execute with matched agents
        execution_result = await self.execute_agents(
            agents=match_result["agents"],
            prompt=user_input,
            workflow=match_result["workflow"],
            context=context or {}
        )
        
        # Record for learning
        if self.config.enable_learning:
            self._record_execution(user_input, match_result, execution_result)
        
        return execution_result
    
    async def execute_agents(self, agents: List[str], prompt: str, 
                            workflow: Optional[str] = None,
                            context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute agents with given prompt"""
        
        results = {
            "success": True,
            "agents_executed": [],
            "results": {},
            "workflow": workflow,
            "errors": []
        }
        
        # Check if we can use Task tool
        if self._check_task_tool():
            # Execute via Task tool (when implemented)
            for agent in agents:
                try:
                    result = await self._execute_via_task_tool(agent, prompt)
                    results["agents_executed"].append(agent)
                    results["results"][agent] = result
                except Exception as e:
                    logger.error(f"Error executing {agent}: {e}")
                    results["errors"].append(f"{agent}: {str(e)}")
        else:
            # Fallback: Generate invocation commands
            results["task_tool_unavailable"] = True
            results["suggested_commands"] = []
            
            for agent in agents:
                command = self._generate_invocation_command(agent, prompt)
                results["suggested_commands"].append(command)
            
            results["message"] = (
                "Task tool not available. Please run these commands manually or "
                "ensure Claude Code is properly configured."
            )
        
        # Post-execution hooks
        if workflow:
            await self._run_workflow_hooks(workflow, results)
        
        return results
    
    def _check_task_tool(self) -> bool:
        """Check if Task tool is available"""
        if self._task_tool_available is not None:
            return self._task_tool_available
        
        # Try to detect Task tool availability
        try:
            # Check if we're in Claude Code environment
            if "CLAUDE_CODE" in os.environ:
                self._task_tool_available = True
            else:
                # Try to find Task tool module
                import importlib.util
                spec = importlib.util.find_spec("claude_code_task")
                self._task_tool_available = spec is not None
        except:
            self._task_tool_available = False
        
        return self._task_tool_available
    
    async def _execute_via_task_tool(self, agent: str, prompt: str) -> Dict[str, Any]:
        """Execute agent via Task tool (placeholder for actual implementation)"""
        # This would be implemented when Task tool integration is available
        logger.info(f"Would execute {agent} with prompt: {prompt[:50]}...")
        
        return {
            "status": "simulated",
            "agent": agent,
            "message": "Task tool execution simulated"
        }
    
    def _generate_invocation_command(self, agent: str, prompt: str) -> str:
        """Generate command to invoke agent"""
        agent_lower = agent.lower().replace('_', '-')
        
        # Escape prompt for shell
        prompt_escaped = prompt.replace('"', '\\"').replace("'", "\\'")
        
        return f'Task(subagent_type="{agent_lower}", prompt="{prompt_escaped}")'
    
    async def _run_workflow_hooks(self, workflow: str, results: Dict):
        """Run workflow-specific hooks"""
        if workflow == "bug_fix" and self.config.enable_learning:
            # Record bug fix for learning
            self._record_bug_fix(results)
        elif workflow == "security_audit":
            # Log security audit
            self._log_security_audit(results)
    
    def _record_execution(self, input_text: str, match_result: Dict, execution_result: Dict):
        """Record execution for learning system"""
        record = {
            "timestamp": datetime.now().isoformat(),
            "input": input_text,
            "matched_agents": match_result["agents"],
            "confidence": match_result["confidence"],
            "strategy": match_result["strategy"],
            "workflow": match_result["workflow"],
            "success": execution_result.get("success", False),
            "errors": execution_result.get("errors", [])
        }
        
        self.execution_history.append(record)
        
        # Persist to file if history gets large
        if len(self.execution_history) > 100:
            self._persist_history()
    
    def _persist_history(self):
        """Save execution history to file"""
        history_file = self.config.cache_dir / "execution_history.json"
        
        try:
            # Load existing history
            existing = []
            if history_file.exists():
                with open(history_file) as f:
                    existing = json.load(f)
            
            # Append new history
            existing.extend(self.execution_history)
            
            # Keep only last 1000 records
            existing = existing[-1000:]
            
            # Save
            with open(history_file, 'w') as f:
                json.dump(existing, f, indent=2)
            
            # Clear memory
            self.execution_history = []
            
            logger.info(f"Persisted {len(existing)} execution records")
        except Exception as e:
            logger.error(f"Failed to persist history: {e}")
    
    def _record_bug_fix(self, results: Dict):
        """Record bug fix for learning"""
        # This would integrate with the learning system
        pass
    
    def _log_security_audit(self, results: Dict):
        """Log security audit results"""
        # This would integrate with security logging
        pass

# ============================================================================
# SHADOWGIT INTEGRATION (Prepared for future activation)
# ============================================================================

class ShadowgitIntegration:
    """Shadowgit integration prepared but not active"""
    
    def __init__(self, config: UnifiedConfig, engine: UnifiedHookEngine):
        self.config = config
        self.engine = engine
        self.enabled = config.enable_shadowgit
        
        if self.enabled:
            self._initialize_shadowgit()
    
    def _initialize_shadowgit(self):
        """Initialize shadowgit when enabled"""
        logger.info("Shadowgit integration prepared (not active)")
        
        # Check for shadow repository
        if not self.config.shadow_repo.exists():
            logger.info(f"Shadow repository would be at: {self.config.shadow_repo}")
        
        # Check for compiled C engine
        c_engine = self.config.project_root / 'hooks' / 'shadowgit' / 'shadowgit.so'
        if not c_engine.exists():
            logger.info("C acceleration engine not compiled")
    
    async def analyze_file_change(self, filepath: str, content: str) -> Dict[str, Any]:
        """Analyze file change with agents (when enabled)"""
        if not self.enabled:
            return {"status": "shadowgit_disabled"}
        
        # Detect language
        language = self._detect_language(filepath)
        
        # Select appropriate agents
        agents = self._select_agents_for_language(language)
        
        # Run analysis
        result = await self.engine.execute_agents(
            agents=agents,
            prompt=f"Analyze code change in {filepath}",
            context={"content": content, "language": language}
        )
        
        return result
    
    def _detect_language(self, filepath: str) -> str:
        """Detect programming language from file extension"""
        ext_map = {
            '.py': 'python',
            '.c': 'c',
            '.cpp': 'cpp',
            '.rs': 'rust',
            '.go': 'go',
            '.java': 'java',
            '.ts': 'typescript',
            '.js': 'javascript',
            '.kt': 'kotlin'
        }
        
        ext = Path(filepath).suffix.lower()
        return ext_map.get(ext, 'unknown')
    
    def _select_agents_for_language(self, language: str) -> List[str]:
        """Select agents based on language"""
        language_agents = {
            'python': ['PYTHON-INTERNAL', 'LINTER', 'OPTIMIZER'],
            'c': ['C-INTERNAL', 'OPTIMIZER', 'DEBUGGER'],
            'cpp': ['CPP-INTERNAL-AGENT', 'OPTIMIZER', 'DEBUGGER'],
            'rust': ['RUST-INTERNAL-AGENT', 'TESTBED', 'OPTIMIZER'],
            'go': ['GO-INTERNAL-AGENT', 'TESTBED', 'LINTER'],
            'java': ['JAVA-INTERNAL-AGENT', 'TESTBED', 'LINTER'],
            'typescript': ['TYPESCRIPT-INTERNAL-AGENT', 'LINTER', 'WEB'],
            'javascript': ['TYPESCRIPT-INTERNAL-AGENT', 'LINTER', 'WEB'],
            'kotlin': ['KOTLIN-INTERNAL-AGENT', 'ANDROIDMOBILE', 'TESTBED']
        }
        
        base_agents = ['SECURITY', 'MONITOR']
        specific_agents = language_agents.get(language, ['LINTER'])
        
        return base_agents + specific_agents

# ============================================================================
# MAIN INTERFACE
# ============================================================================

class ClaudeUnifiedHooks:
    """Main interface for unified hook system"""
    
    def __init__(self, config: Optional[UnifiedConfig] = None):
        self.config = config or UnifiedConfig()
        self.engine = UnifiedHookEngine(self.config)
        self.shadowgit = ShadowgitIntegration(self.config, self.engine)
        
        logger.info("Claude Unified Hook System initialized")
        logger.info(f"Project root: {self.config.project_root}")
        logger.info(f"Agents available: {len(self.engine.registry.agents)}")
    
    async def process(self, user_input: str, **kwargs) -> Dict[str, Any]:
        """Process user input through unified system"""
        return await self.engine.process_input(user_input, context=kwargs)
    
    def get_agent_info(self, agent_name: str) -> Optional[Dict]:
        """Get information about specific agent"""
        return self.engine.registry.get_agent(agent_name)
    
    def list_agents(self, category: Optional[str] = None) -> List[Dict]:
        """List all agents or by category"""
        if category:
            return self.engine.registry.get_agents_by_category(category)
        return list(self.engine.registry.agents.values())
    
    def get_status(self) -> Dict[str, Any]:
        """Get system status"""
        return {
            "config": {
                "project_root": str(self.config.project_root),
                "agents_dir": str(self.config.agents_dir),
                "shadowgit_enabled": self.config.enable_shadowgit
            },
            "agents": {
                "total": len(self.engine.registry.agents),
                "categories": {
                    cat: len(self.engine.registry.get_agents_by_category(cat))
                    for cat in set(a["category"] for a in self.engine.registry.agents.values())
                }
            },
            "features": {
                "fuzzy_matching": self.config.enable_fuzzy_matching,
                "semantic_matching": self.config.enable_semantic_matching,
                "natural_invocation": self.config.enable_natural_invocation,
                "shadowgit": self.config.enable_shadowgit,
                "learning": self.config.enable_learning
            },
            "task_tool_available": self.engine._check_task_tool()
        }

# ============================================================================
# CLI INTERFACE
# ============================================================================

async def main():
    """CLI interface for testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Claude Unified Hook System")
    parser.add_argument("command", choices=["process", "list", "status", "test"],
                      help="Command to execute")
    parser.add_argument("--input", "-i", help="Input text for processing")
    parser.add_argument("--category", "-c", help="Filter agents by category")
    parser.add_argument("--agent", "-a", help="Get info about specific agent")
    parser.add_argument("--enable-shadowgit", action="store_true",
                      help="Enable shadowgit integration")
    
    args = parser.parse_args()
    
    # Create config
    config = UnifiedConfig(enable_shadowgit=args.enable_shadowgit)
    
    # Initialize system
    hooks = ClaudeUnifiedHooks(config)
    
    if args.command == "process":
        if not args.input:
            print("Error: --input required for process command")
            return
        
        result = await hooks.process(args.input)
        print(json.dumps(result, indent=2))
    
    elif args.command == "list":
        agents = hooks.list_agents(category=args.category)
        print(f"\nFound {len(agents)} agents:\n")
        for agent in agents:
            status = "✓" if agent["status"] == "ACTIVE" else "○"
            print(f"  {status} {agent['name']:30} [{agent['category']:15}] {agent['description'][:50]}...")
    
    elif args.command == "status":
        status = hooks.get_status()
        print(json.dumps(status, indent=2))
    
    elif args.command == "test":
        # Run test cases
        test_cases = [
            "I need to fix a bug in the authentication system",
            "Deploy the application to production",
            "Run security audit on the codebase",
            "Optimize the database queries for better performance",
            "Create documentation for the API",
            "Test the new feature implementation"
        ]
        
        print("\nRunning test cases:\n")
        for test_input in test_cases:
            print(f"Input: {test_input}")
            result = await hooks.process(test_input)
            print(f"  Agents: {result.get('agents_executed', result.get('suggested_commands', []))}")
            print(f"  Success: {result.get('success', False)}\n")

if __name__ == "__main__":
    asyncio.run(main())