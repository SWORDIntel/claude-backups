#!/usr/bin/env python3
"""
Agent Registry System for Tandem Orchestration
Discovers, registers, and manages all agents in the ecosystem
"""

import os
import yaml
import json
import asyncio
import time
from typing import Dict, List, Any, Optional, Set
from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

@dataclass
class AgentCapability:
    """Represents an agent's capability"""
    name: str
    description: str
    input_types: List[str] = field(default_factory=list)
    output_types: List[str] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    estimated_duration: str = "unknown"

@dataclass
class AgentMetadata:
    """Complete agent metadata"""
    name: str
    uuid: str
    version: str = "7.0.0"
    category: str = "GENERAL"
    priority: str = "MEDIUM"
    status: str = "PRODUCTION"
    color: str = "blue"
    
    # Capabilities
    capabilities: List[AgentCapability] = field(default_factory=list)
    auto_invoke_patterns: List[str] = field(default_factory=list)
    
    # Technical specs
    hardware_requirements: Dict[str, Any] = field(default_factory=dict)
    communication_settings: Dict[str, Any] = field(default_factory=dict)
    
    # Runtime info
    last_seen: Optional[datetime] = None
    health_score: float = 100.0
    active_tasks: int = 0
    total_tasks_completed: int = 0

class AgentRegistry:
    """Central registry for all agents in the system"""
    
    def __init__(self, agents_dir: str = "/home/ubuntu/Documents/Claude/agents"):
        self.agents_dir = Path(agents_dir)
        self.agents: Dict[str, AgentMetadata] = {}
        self.capabilities_index: Dict[str, List[str]] = {}  # capability -> [agent_names]
        self.category_index: Dict[str, List[str]] = {}      # category -> [agent_names]
        self.health_monitor_active = False
        
    async def initialize(self) -> bool:
        """Initialize the registry and discover all agents"""
        logger.info("Initializing Agent Registry...")
        
        try:
            # Discover agents from .md files
            await self._discover_agents()
            
            # Build capability indices
            self._build_indices()
            
            # Start health monitoring
            asyncio.create_task(self._health_monitor())
            self.health_monitor_active = True
            
            logger.info(f"Agent Registry initialized with {len(self.agents)} agents")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Agent Registry: {e}")
            return False
    
    async def _discover_agents(self):
        """Discover agents from their .md definition files"""
        agent_files = list(self.agents_dir.glob("*.md"))
        
        # Filter out non-agent files
        excluded = {"Template.md", "README.md", "STATUSLINE_INTEGRATION.md"}
        agent_files = [f for f in agent_files if f.name not in excluded]
        
        logger.info(f"Discovering agents from {len(agent_files)} .md files...")
        
        for agent_file in agent_files:
            try:
                agent_metadata = await self._parse_agent_file(agent_file)
                if agent_metadata:
                    self.agents[agent_metadata.name.lower()] = agent_metadata
                    logger.debug(f"Registered agent: {agent_metadata.name}")
            except Exception as e:
                logger.warning(f"Failed to parse {agent_file.name}: {e}")
    
    async def _parse_agent_file(self, agent_file: Path) -> Optional[AgentMetadata]:
        """Parse an agent .md file and extract metadata"""
        try:
            content = agent_file.read_text()
            
            # Extract YAML frontmatter
            if content.startswith('---'):
                parts = content.split('---', 2)
                if len(parts) >= 3:
                    yaml_content = parts[1]
                    
                    # Parse YAML frontmatter
                    try:
                        frontmatter = yaml.safe_load(yaml_content)
                    except yaml.YAMLError:
                        # If YAML parsing fails, extract from structured content
                        frontmatter = self._extract_from_structured_content(content)
                else:
                    frontmatter = self._extract_from_structured_content(content)
            else:
                frontmatter = self._extract_from_structured_content(content)
            
            return self._build_agent_metadata(agent_file.stem, frontmatter, content)
            
        except Exception as e:
            logger.error(f"Error parsing {agent_file}: {e}")
            return None
    
    def _extract_from_structured_content(self, content: str) -> Dict[str, Any]:
        """Extract metadata from structured markdown content"""
        metadata = {}
        
        # Look for agent_metadata section
        if "agent_metadata:" in content:
            lines = content.split('\n')
            in_metadata = False
            
            for line in lines:
                if "agent_metadata:" in line:
                    in_metadata = True
                    continue
                    
                if in_metadata:
                    if line.startswith('  ') and ':' in line:
                        key, value = line.strip().split(':', 1)
                        metadata[key.strip()] = value.strip().strip('"')
                    elif line.strip() and not line.startswith('  '):
                        break
        
        # Extract communication settings
        if "communication:" in content:
            comm_section = self._extract_section(content, "communication:")
            metadata["communication"] = comm_section
        
        # Extract hardware requirements
        if "hardware:" in content:
            hw_section = self._extract_section(content, "hardware:")
            metadata["hardware"] = hw_section
        
        # Extract operational directives for auto-invocation
        if "auto_invoke_conditions:" in content:
            patterns = self._extract_auto_invoke_patterns(content)
            metadata["auto_invoke_patterns"] = patterns
        
        return metadata
    
    def _extract_section(self, content: str, section_name: str) -> Dict[str, Any]:
        """Extract a structured section from markdown content"""
        lines = content.split('\n')
        section_data = {}
        in_section = False
        current_indent = 0
        
        for line in lines:
            if section_name in line:
                in_section = True
                current_indent = len(line) - len(line.lstrip())
                continue
                
            if in_section:
                line_indent = len(line) - len(line.lstrip())
                
                # End of section
                if line.strip() and line_indent <= current_indent and not line.strip().startswith('-'):
                    break
                
                # Parse key-value pairs
                if ':' in line and not line.strip().startswith('-'):
                    key = line.split(':')[0].strip()
                    value = line.split(':', 1)[1].strip()
                    if value:
                        section_data[key] = value
        
        return section_data
    
    def _extract_auto_invoke_patterns(self, content: str) -> List[str]:
        """Extract auto-invocation patterns from content"""
        patterns = []
        
        # Look for pattern definitions
        if "pattern:" in content:
            lines = content.split('\n')
            for line in lines:
                if "pattern:" in line and '"' in line:
                    # Extract pattern from quotes
                    start = line.find('"') + 1
                    end = line.find('"', start)
                    if start > 0 and end > start:
                        pattern = line[start:end]
                        patterns.append(pattern)
        
        return patterns
    
    def _build_agent_metadata(self, agent_name: str, frontmatter: Dict[str, Any], content: str) -> AgentMetadata:
        """Build AgentMetadata from parsed data"""
        # Get basic metadata
        metadata = frontmatter.get("agent_metadata", {}) if isinstance(frontmatter.get("agent_metadata"), dict) else {}
        
        # Handle the case where frontmatter might be the metadata directly
        if not metadata and frontmatter:
            metadata = frontmatter
        
        # Extract capabilities from operational directives
        capabilities = self._extract_capabilities(content, agent_name)
        
        return AgentMetadata(
            name=metadata.get("name", agent_name.upper()),
            uuid=metadata.get("uuid", f"auto-{hash(agent_name) % 1000000:06d}"),
            version=metadata.get("version", "7.0.0"),
            category=metadata.get("category", "GENERAL"),
            priority=metadata.get("priority", "MEDIUM"),
            status=metadata.get("status", "PRODUCTION"),
            color=metadata.get("color", "blue"),
            capabilities=capabilities,
            auto_invoke_patterns=self._extract_auto_invoke_patterns(content),
            hardware_requirements=frontmatter.get("hardware", {}),
            communication_settings=frontmatter.get("communication", {}),
            last_seen=datetime.now(),
            health_score=100.0
        )
    
    def _extract_capabilities(self, content: str, agent_name: str) -> List[AgentCapability]:
        """Extract capabilities from agent content"""
        capabilities = []
        
        # Look for invoke_for patterns in agent registry sections
        if "invoke_for:" in content:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if "invoke_for:" in line and agent_name.lower() in line.lower():
                    # Look for the list that follows
                    j = i + 1
                    while j < len(lines) and lines[j].strip().startswith('-'):
                        capability_desc = lines[j].strip().lstrip('- ').strip('"')
                        capabilities.append(AgentCapability(
                            name=capability_desc.replace(' ', '_'),
                            description=capability_desc
                        ))
                        j += 1
                    break
        
        # If no specific capabilities found, infer from agent type
        if not capabilities:
            capabilities = self._infer_capabilities_from_name(agent_name)
        
        return capabilities
    
    def _infer_capabilities_from_name(self, agent_name: str) -> List[AgentCapability]:
        """Infer basic capabilities from agent name"""
        name_lower = agent_name.lower()
        
        capability_map = {
            "director": ["strategic_planning", "project_management", "decision_making"],
            "projectorchestrator": ["workflow_coordination", "agent_management", "task_orchestration"],
            "architect": ["system_design", "architecture_planning", "technical_specifications"],
            "constructor": ["project_scaffolding", "boilerplate_generation", "setup_automation"],
            "patcher": ["bug_fixes", "code_patches", "hotfixes"],
            "debugger": ["bug_investigation", "issue_analysis", "troubleshooting"],
            "testbed": ["test_creation", "test_execution", "quality_assurance"],
            "linter": ["code_quality", "style_checking", "static_analysis"],
            "optimizer": ["performance_optimization", "resource_tuning", "efficiency_improvement"],
            "security": ["security_analysis", "vulnerability_scanning", "threat_assessment"],
            "deployer": ["deployment_automation", "release_management", "environment_setup"],
            "monitor": ["system_monitoring", "performance_tracking", "alerting"],
            "tui": ["terminal_interfaces", "cli_applications", "user_interaction"],
            "docgen": ["documentation_generation", "api_documentation", "user_guides"],
            "web": ["web_development", "frontend_applications", "ui_components"],
            "mobile": ["mobile_development", "ios_android", "react_native"],
            "database": ["database_design", "query_optimization", "data_modeling"],
            "apidesigner": ["api_design", "openapi_specs", "rest_apis"],
            "infrastructure": ["infrastructure_setup", "system_configuration", "devops"],
            "mlops": ["ml_pipelines", "model_deployment", "ml_operations"],
            "datascience": ["data_analysis", "machine_learning", "data_processing"]
        }
        
        capabilities = []
        for key, caps in capability_map.items():
            if key in name_lower:
                for cap in caps:
                    capabilities.append(AgentCapability(
                        name=cap,
                        description=cap.replace('_', ' ').title()
                    ))
                break
        
        # Default capability if nothing matches
        if not capabilities:
            capabilities.append(AgentCapability(
                name="general_assistance",
                description="General assistance and task execution"
            ))
        
        return capabilities
    
    def _build_indices(self):
        """Build capability and category indices for fast lookup"""
        self.capabilities_index.clear()
        self.category_index.clear()
        
        for agent_name, agent in self.agents.items():
            # Build capability index
            for capability in agent.capabilities:
                if capability.name not in self.capabilities_index:
                    self.capabilities_index[capability.name] = []
                self.capabilities_index[capability.name].append(agent_name)
            
            # Build category index
            if agent.category not in self.category_index:
                self.category_index[agent.category] = []
            self.category_index[agent.category].append(agent_name)
    
    def find_agents_by_capability(self, capability: str) -> List[str]:
        """Find agents that have a specific capability"""
        return self.capabilities_index.get(capability, [])
    
    def find_agents_by_category(self, category: str) -> List[str]:
        """Find agents in a specific category"""
        return self.category_index.get(category, [])
    
    def find_agents_by_pattern(self, text: str) -> List[str]:
        """Find agents that should auto-invoke based on text patterns"""
        matching_agents = []
        
        text_lower = text.lower()
        for agent_name, agent in self.agents.items():
            for pattern in agent.auto_invoke_patterns:
                if any(keyword in text_lower for keyword in pattern.lower().split('|')):
                    matching_agents.append(agent_name)
                    break
        
        return matching_agents
    
    def get_agent_info(self, agent_name: str) -> Optional[AgentMetadata]:
        """Get detailed information about an agent"""
        return self.agents.get(agent_name.lower())
    
    def update_agent_health(self, agent_name: str, health_score: float):
        """Update an agent's health score"""
        agent = self.agents.get(agent_name.lower())
        if agent:
            agent.health_score = max(0, min(100, health_score))
            agent.last_seen = datetime.now()
    
    def increment_agent_tasks(self, agent_name: str):
        """Increment task counters for an agent"""
        agent = self.agents.get(agent_name.lower())
        if agent:
            agent.active_tasks += 1
            agent.total_tasks_completed += 1
    
    def decrement_agent_tasks(self, agent_name: str):
        """Decrement active task counter for an agent"""
        agent = self.agents.get(agent_name.lower())
        if agent:
            agent.active_tasks = max(0, agent.active_tasks - 1)
    
    def get_healthy_agents(self, min_health: float = 70.0) -> List[str]:
        """Get list of healthy agents above minimum health threshold"""
        return [
            name for name, agent in self.agents.items()
            if agent.health_score >= min_health
        ]
    
    def get_available_agents(self, max_active_tasks: int = 5) -> List[str]:
        """Get list of agents that are not overloaded"""
        return [
            name for name, agent in self.agents.items()
            if agent.active_tasks <= max_active_tasks and agent.health_score > 50
        ]
    
    async def _health_monitor(self):
        """Background task to monitor agent health"""
        while self.health_monitor_active:
            try:
                current_time = datetime.now()
                
                for agent_name, agent in self.agents.items():
                    # Reduce health score for agents not seen recently
                    if agent.last_seen:
                        time_since_seen = current_time - agent.last_seen
                        if time_since_seen > timedelta(minutes=30):
                            # Gradually reduce health score
                            reduction = min(10, time_since_seen.total_seconds() / 180)  # 10 points per 30 min
                            agent.health_score = max(0, agent.health_score - reduction)
                    
                    # Reset active tasks for agents with very old last_seen
                    if agent.last_seen and (current_time - agent.last_seen) > timedelta(hours=1):
                        agent.active_tasks = 0
                
                # Sleep for 60 seconds before next health check
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error(f"Health monitor error: {e}")
                await asyncio.sleep(60)
    
    def get_registry_stats(self) -> Dict[str, Any]:
        """Get registry statistics"""
        total_agents = len(self.agents)
        healthy_agents = len(self.get_healthy_agents())
        available_agents = len(self.get_available_agents())
        
        categories = {}
        for agent in self.agents.values():
            categories[agent.category] = categories.get(agent.category, 0) + 1
        
        total_capabilities = sum(len(agent.capabilities) for agent in self.agents.values())
        
        return {
            "total_agents": total_agents,
            "healthy_agents": healthy_agents,
            "available_agents": available_agents,
            "categories": categories,
            "total_capabilities": total_capabilities,
            "avg_health_score": sum(agent.health_score for agent in self.agents.values()) / total_agents if total_agents > 0 else 0
        }
    
    def stop_health_monitoring(self):
        """Stop the health monitoring background task"""
        self.health_monitor_active = False


# Global registry instance
_registry_instance = None

def get_registry() -> AgentRegistry:
    """Get the global agent registry instance"""
    global _registry_instance
    if _registry_instance is None:
        _registry_instance = AgentRegistry()
    return _registry_instance

async def initialize_registry() -> bool:
    """Initialize the global agent registry"""
    registry = get_registry()
    return await registry.initialize()