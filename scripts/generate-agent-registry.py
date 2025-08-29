#!/usr/bin/env python3
"""
Dynamic Agent Registry Generator
Scans agent definitions and creates registry configuration
"""

import os
import sys
import json
import yaml
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional

def extract_agent_metadata(agent_file: Path) -> Optional[Dict[str, Any]]:
    """Extract metadata from agent markdown file"""
    try:
        content = agent_file.read_text(encoding='utf-8')
        metadata = {}
        
        # Try YAML frontmatter first
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                try:
                    yaml_data = yaml.safe_load(parts[1]) or {}
                    metadata.update(yaml_data)
                except yaml.YAMLError as e:
                    print(f"  YAML parse error in {agent_file.name}: {e}")
        
        # Extract from structured sections if no YAML
        if not metadata:
            # Look for key-value pairs in the content
            lines = content.split('\n')
            for line in lines:
                line = line.strip()
                if ':' in line and not line.startswith('#'):
                    try:
                        key, value = line.split(':', 1)
                        key = key.strip().lower()
                        value = value.strip().strip('"\'')
                        if key in ['name', 'category', 'priority', 'status', 'uuid']:
                            metadata[key] = value
                    except:
                        continue
        
        # Extract basic info with smart defaults
        agent_name = agent_file.stem.upper()
        name = metadata.get('name', agent_name)
        uuid = metadata.get('uuid', f"auto-{agent_file.stem.lower()}-001")
        
        # Determine category from agent name if not specified
        category = metadata.get('category', infer_category_from_name(agent_name))
        
        # Clean priority and status values
        priority = str(metadata.get('priority', 'MEDIUM')).split('#')[0].strip()
        status = str(metadata.get('status', 'PRODUCTION')).split('#')[0].strip()
        
        # Extract capabilities
        capabilities = []
        capability_patterns = ['capabilities:', 'invoke_for:', '## Capabilities', '## Purpose']
        for pattern in capability_patterns:
            if pattern in content:
                capability_section = extract_section(content, pattern)
                if capability_section:
                    capabilities.extend([item.strip() for item in capability_section if item.strip()])
                    break
        
        # If no capabilities found, infer from name
        if not capabilities:
            capabilities = infer_capabilities_from_name(agent_name)
        
        # Determine clusters
        clusters = determine_clusters(agent_file.stem.lower())
        
        return {
            "name": name,
            "uuid": uuid,
            "category": category,
            "priority": priority,
            "status": status,
            "health": 100.0,
            "active_tasks": 0,
            "capabilities": len(capabilities),
            "capability_list": capabilities[:5],  # Store first 5 for reference
            "clusters": clusters,
            "file_path": str(agent_file),
            "file_name": agent_file.name,
            "last_modified": datetime.fromtimestamp(agent_file.stat().st_mtime).isoformat()
        }
        
    except Exception as e:
        print(f"Warning: Failed to parse {agent_file.name}: {e}")
        return None

def infer_category_from_name(agent_name: str) -> str:
    """Infer category from agent name"""
    name_lower = agent_name.lower()
    
    if any(word in name_lower for word in ['director', 'orchestrator', 'planner']):
        return 'COMMAND_CONTROL'
    elif any(word in name_lower for word in ['security', 'bastion', 'crypto', 'quantum', 'redteam', 'apt41', 'psyops', 'ghost', 'cognitive']):
        return 'SECURITY'
    elif any(word in name_lower for word in ['architect', 'constructor', 'patcher', 'debugger', 'linter', 'testbed']):
        return 'DEVELOPMENT'
    elif any(word in name_lower for word in ['infrastructure', 'deployer', 'monitor', 'docker', 'proxmox']):
        return 'INFRASTRUCTURE'
    elif any(word in name_lower for word in ['web', 'mobile', 'android', 'gui', 'tui', 'api']):
        return 'PLATFORMS'
    elif any(word in name_lower for word in ['internal', 'typescript', 'python', 'rust', 'java', 'kotlin', 'assembly']):
        return 'LANGUAGE_SPECIFIC'
    elif any(word in name_lower for word in ['data', 'ml', 'npu', 'sql', 'database']):
        return 'DATA_ML'
    elif any(word in name_lower for word in ['cisco', 'bgp', 'iot', 'ddwrt']):
        return 'NETWORK_SYSTEMS'
    elif any(word in name_lower for word in ['gna', 'leadengineer', 'optimizer']):
        return 'HARDWARE'
    elif any(word in name_lower for word in ['researcher', 'docgen', 'qa']):
        return 'PLANNING_DOCS'
    else:
        return 'GENERAL'

def infer_capabilities_from_name(agent_name: str) -> List[str]:
    """Infer basic capabilities from agent name"""
    name_lower = agent_name.lower()
    
    capability_map = {
        'director': ['strategic_planning', 'project_coordination', 'decision_making'],
        'orchestrator': ['workflow_coordination', 'agent_management', 'task_orchestration'],
        'architect': ['system_design', 'architecture_planning', 'technical_specifications'],
        'security': ['security_analysis', 'vulnerability_scanning', 'threat_assessment'],
        'constructor': ['project_scaffolding', 'boilerplate_generation', 'setup_automation'],
        'patcher': ['bug_fixes', 'code_patches', 'hotfixes'],
        'debugger': ['bug_investigation', 'issue_analysis', 'troubleshooting'],
        'testbed': ['test_creation', 'test_execution', 'quality_assurance'],
        'linter': ['code_quality', 'style_checking', 'static_analysis'],
        'optimizer': ['performance_optimization', 'resource_tuning', 'efficiency_improvement']
    }
    
    for key, caps in capability_map.items():
        if key in name_lower:
            return caps
    
    # Generic capabilities
    return ['general_assistance', 'task_execution', 'problem_solving']

def extract_section(content: str, section_name: str) -> List[str]:
    """Extract items from a markdown section"""
    lines = content.split('\n')
    items = []
    in_section = False
    
    for line in lines:
        if section_name in line:
            in_section = True
            continue
        
        if in_section:
            stripped = line.strip()
            if not stripped:
                continue
            
            # Check for section end
            if not line.startswith(' ') and not line.startswith('\t') and not stripped.startswith('-'):
                break
            
            # Extract list items
            if stripped.startswith('- '):
                item = stripped[2:].strip().strip('"')
                items.append(item)
    
    return items

def determine_clusters(agent_name: str) -> List[str]:
    """Determine which clusters an agent belongs to"""
    clusters = []
    name_lower = agent_name.lower()
    
    cluster_map = {
        "management": ["director", "projectorchestrator", "planner", "oversight"],
        "security": ["security", "bastion", "securitychaos", "cso", "cryptoexpert", 
                    "quantumguard", "redteam", "apt41", "nsa", "psyops", "ghost", "cognitive"],
        "development": ["constructor", "patcher", "testbed", "linter", "debugger", 
                       "optimizer", "packager", "docgen"],
        "architecture": ["architect", "apidesigner", "database"],
        "infrastructure": ["infrastructure", "deployer", "monitor", "docker", "proxmox"],
        "platforms": ["web", "mobile", "androidmobile", "pygui", "tui", "apidesigner"],
        "data": ["database", "datascience", "mlops", "npu", "researcher", "sql"],
        "language_specialists": ["c-internal", "python-internal", "typescript-internal", 
                               "rust-internal", "go-internal", "java-internal", 
                               "kotlin-internal", "assembly-internal"],
        "network": ["cisco", "bgp", "iot", "ddwrt"],
        "hardware": ["gna", "leadengineer", "npu"]
    }
    
    for cluster, agents in cluster_map.items():
        if any(agent in name_lower for agent in agents):
            clusters.append(cluster)
    
    # Default cluster if no match
    if not clusters:
        clusters.append("general")
    
    return clusters

def scan_agents_directory(agents_dir: Path) -> List[Dict[str, Any]]:
    """Scan agents directory (root only) and extract all agent metadata"""
    agents = []
    
    # Find all markdown files in root directory only (maxdepth 1)
    agent_files = [f for f in agents_dir.iterdir() if f.is_file() and f.suffix.lower() == '.md']
    
    # Filter out non-agent files - be very specific about what to exclude
    excluded_files = {
        "TEMPLATE.md", "Template.md", "template.md",
        "README.md", "readme.md", 
        "WHERE_I_AM.md", "where_i_am.md",
        "STATUSLINE_INTEGRATION.md",
        "DIRECTORY_STRUCTURE.md", 
        "STANDARDIZED_TEMPLATE.md"
    }
    
    # Also exclude files that don't look like agent names (contain spaces, special chars, etc)
    def is_agent_file(filename: str) -> bool:
        name = filename.lower()
        
        # Exclude known non-agent files
        if filename in excluded_files:
            return False
            
        # Exclude files with spaces or weird characters (likely docs)
        if ' ' in name or any(char in name for char in ['(', ')', '[', ']']):
            return False
            
        # Must be uppercase or contain "agent" or be a known pattern
        if (filename.isupper() or 
            'agent' in name or 
            any(keyword in name for keyword in ['internal', 'orchestrator', 'director'])):
            return True
            
        return False
    
    agent_files = [f for f in agent_files if is_agent_file(f.name)]
    
    print(f"Scanning agents directory: {agents_dir}")
    print(f"Found {len(agent_files)} potential agent definition files")
    
    # Sort for consistent output
    agent_files.sort(key=lambda x: x.name)
    
    for agent_file in agent_files:
        try:
            metadata = extract_agent_metadata(agent_file)
            if metadata:
                agents.append(metadata)
                print(f"✓ Processed: {metadata['name']} ({agent_file.name})")
            else:
                print(f"⚠ Skipped: {agent_file.name} (no valid metadata)")
        except Exception as e:
            print(f"✗ Failed: {agent_file.name} - {e}")
    
    print(f"Successfully processed {len(agents)} agent files")
    return agents

def generate_statistics(agents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Generate registry statistics"""
    total_agents = len(agents)
    healthy_agents = [a for a in agents if a["health"] >= 70]
    
    # Category breakdown
    categories = {}
    for agent in agents:
        cat = agent["category"]
        categories[cat] = categories.get(cat, 0) + 1
    
    # Priority breakdown
    priorities = {}
    for agent in agents:
        pri = agent["priority"]
        priorities[pri] = priorities.get(pri, 0) + 1
    
    return {
        "total_agents": total_agents,
        "healthy_agents": len(healthy_agents),
        "available_agents": len([a for a in agents if a["active_tasks"] <= 5]),
        "unhealthy_agents": [a["name"] for a in agents if a["health"] < 70],
        "categories": categories,
        "priorities": priorities,
        "avg_health_score": sum(a["health"] for a in agents) / total_agents if total_agents > 0 else 0,
        "total_tasks_completed": 0,
        "total_errors": 0,
        "error_rate": 0,
        "binary_protocol_active": False,
        "orchestration_rules": 3
    }

def create_agent_registry(agents_dir: str, output_file: str = None) -> Dict[str, Any]:
    """Create complete agent registry configuration"""
    agents_path = Path(agents_dir)
    
    if not agents_path.exists():
        raise FileNotFoundError(f"Agents directory not found: {agents_dir}")
    
    print(f"Scanning agents directory: {agents_path}")
    
    # Scan and process agents
    agents = scan_agents_directory(agents_path)
    
    # Generate statistics
    stats = generate_statistics(agents)
    
    # Create registry configuration
    registry_config = {
        "metadata": {
            "version": "7.0",
            "total_agents": len(agents),
            "database_enabled": False,
            "database_port": 5432,
            "registry_status": "active",
            "last_updated": datetime.now().isoformat(),
            "binary_protocol": False,
            "python_fallback": True,
            "generated_by": "dynamic_registry_generator",
            "source_directory": str(agents_path)
        },
        "agents": agents,
        "statistics": stats,
        "configuration": {
            "communication": {
                "protocol": "ultra_fast_binary_v3",
                "throughput": "4.2M_msg_sec",
                "latency": "200ns_p99",
                "fallback_mode": "python_async"
            },
            "orchestration": {
                "clusters_enabled": True,
                "health_monitoring": True,
                "auto_scaling": False,
                "coordination_patterns": [
                    "sequential",
                    "parallel", 
                    "pipeline",
                    "hierarchical"
                ]
            },
            "learning": {
                "ml_enabled": True,
                "adaptation_rate": 0.1,
                "pattern_recognition": True,
                "performance_optimization": True
            }
        }
    }
    
    # Write to output file if specified
    if output_file:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(registry_config, f, indent=2)
        print(f"Registry configuration written to: {output_path}")
    
    return registry_config

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate dynamic agent registry")
    parser.add_argument("--agents-dir", default="./agents", 
                       help="Path to agents directory")
    parser.add_argument("--output", default="./config/agent-registry.json",
                       help="Output registry file")
    parser.add_argument("--print", action="store_true",
                       help="Print registry to stdout")
    
    args = parser.parse_args()
    
    try:
        registry = create_agent_registry(args.agents_dir, args.output if not args.print else None)
        
        if args.print:
            print(json.dumps(registry, indent=2))
        
        print(f"\n✅ Registry generation complete!")
        print(f"   Total agents: {registry['metadata']['total_agents']}")
        print(f"   Categories: {len(registry['statistics']['categories'])}")
        print(f"   Healthy agents: {registry['statistics']['healthy_agents']}")
        
    except Exception as e:
        print(f"❌ Error generating registry: {e}")
        sys.exit(1)