#!/usr/bin/env python3
"""
Standardize ALL agents to match Claude Code documentation standard
Ensures uniform format for proper discovery and integration
"""

import os
import re
import yaml
from pathlib import Path
from typing import Dict, Any

class AgentStandardizer:
    """Standardize all agents to uniform Claude Code format"""
    
    def __init__(self):
        self.agents_dir = Path('/home/ubuntu/Documents/Claude/agents')
        self.standard_template = self.get_standard_template()
        
    def get_standard_template(self) -> str:
        """Get the standard agent template"""
        return '''---
# Claude Code Agent Definition v7.0
name: {name}
version: 7.0.0
uuid: {uuid}
category: {category}
priority: {priority}
status: PRODUCTION

metadata:
  role: "{role}"
  expertise: "{expertise}"
  focus: "{focus}"
  
capabilities:
{capabilities}

tools:
  - Task
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - LS
  - WebFetch

communication:
  protocol: ultra_fast_binary_v3
  integration_modes:
    primary_mode: "PYTHON_TANDEM_ORCHESTRATION"
    binary_protocol: "${{CLAUDE_AGENTS_ROOT}}/binary-communications-system/ultra_hybrid_enhanced.c"
    python_orchestrator: "${{CLAUDE_AGENTS_ROOT}}/src/python/production_orchestrator.py"
    fallback_mode: "DIRECT_TASK_TOOL"
    
  operational_status:
    python_layer: "ACTIVE"
    binary_layer: "STANDBY"
    
  tandem_orchestration:
    agent_registry: "${{CLAUDE_AGENTS_ROOT}}/src/python/agent_registry.py"
    execution_modes:
      - "INTELLIGENT: Python orchestrates workflows"
      - "PYTHON_ONLY: Current default due to hardware restrictions"
    mock_execution: "Immediate functionality without C dependencies"

proactive_triggers:
{triggers}

invokes_agents:
{invokes}

hardware_optimization:
  meteor_lake:
    p_cores: "{p_cores_usage}"
    e_cores: "{e_cores_usage}"
    thermal_target: "{thermal_target}"

success_metrics:
{metrics}
---

# {name} Agent

{content}
'''
    
    def extract_agent_info(self, file_path: Path) -> Dict[str, Any]:
        """Extract information from existing agent file"""
        content = file_path.read_text()
        info = {
            'name': file_path.stem,
            'uuid': f'{file_path.stem.lower()}-2025-claude-code',
            'category': 'GENERAL',
            'priority': 'NORMAL',
            'role': f'{file_path.stem} Agent',
            'expertise': 'Specialized capabilities',
            'focus': 'Project-specific tasks',
            'capabilities': [],
            'triggers': [],
            'invokes': [],
            'p_cores_usage': 'ADAPTIVE',
            'e_cores_usage': 'BACKGROUND',
            'thermal_target': '85°C',
            'metrics': [],
            'original_content': ''
        }
        
        # Extract metadata from YAML frontmatter if exists
        if content.startswith('---'):
            yaml_match = re.search(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
            if yaml_match:
                try:
                    yaml_data = yaml.safe_load(yaml_match.group(1))
                    
                    # Extract from various possible locations
                    if 'agent_template' in yaml_data:
                        template = yaml_data['agent_template']
                        metadata = template.get('metadata', {})
                        info['name'] = metadata.get('name', info['name'])
                        info['uuid'] = metadata.get('uuid', info['uuid'])
                        info['category'] = metadata.get('category', info['category'])
                        info['priority'] = metadata.get('priority', info['priority'])
                        info['role'] = metadata.get('role', info['role'])
                        info['expertise'] = metadata.get('expertise', info['expertise'])
                        info['focus'] = metadata.get('focus', info['focus'])
                    
                    # Extract direct metadata
                    if 'metadata' in yaml_data:
                        metadata = yaml_data['metadata']
                        info['name'] = metadata.get('name', info['name'])
                        info['role'] = metadata.get('role', info['role'])
                        info['expertise'] = metadata.get('expertise', info['expertise'])
                        
                    # Remove YAML from content
                    info['original_content'] = re.sub(r'^---.*?---\s*\n', '', content, flags=re.DOTALL)
                except:
                    info['original_content'] = content
            else:
                info['original_content'] = content
        else:
            info['original_content'] = content
            
        # Extract patterns from content
        self._extract_patterns(content, info)
        
        return info
    
    def _extract_patterns(self, content: str, info: Dict):
        """Extract patterns from agent content"""
        # Extract category
        category_match = re.search(r'category:\s*(\w+)', content, re.IGNORECASE)
        if category_match:
            info['category'] = category_match.group(1).upper()
            
        # Extract priority
        priority_match = re.search(r'priority:\s*(\w+)', content, re.IGNORECASE)
        if priority_match:
            info['priority'] = priority_match.group(1).upper()
            
        # Extract role/expertise
        role_match = re.search(r'role:\s*"([^"]+)"', content)
        if role_match:
            info['role'] = role_match.group(1)
            
        expertise_match = re.search(r'expertise:\s*"([^"]+)"', content)
        if expertise_match:
            info['expertise'] = expertise_match.group(1)
            
        # Set default capabilities based on category
        if 'SECURITY' in info['category']:
            info['capabilities'] = [
                '  - "Security analysis and vulnerability assessment"',
                '  - "Compliance auditing and risk management"',
                '  - "Threat modeling and mitigation"'
            ]
        elif 'DEVELOPMENT' in info['category'] or 'C-INTERNAL' in info['category']:
            info['capabilities'] = [
                '  - "Code generation and optimization"',
                '  - "Architecture design and review"',
                '  - "Performance analysis and tuning"'
            ]
        elif 'TESTBED' in info['category']:
            info['capabilities'] = [
                '  - "Test planning and execution"',
                '  - "Quality assurance and validation"',
                '  - "Performance and stress testing"'
            ]
        else:
            info['capabilities'] = [
                '  - "Analysis and assessment"',
                '  - "Planning and coordination"',
                '  - "Execution and monitoring"'
            ]
            
        # Default triggers
        info['triggers'] = [
            f'  - pattern: "{info["name"].lower()}|{info["category"].lower()}"',
            '    confidence: HIGH',
            '    action: AUTO_INVOKE'
        ]
        
        # Default invocations
        info['invokes'] = ['  - Director', '  - ProjectOrchestrator']
        
        # Default metrics
        info['metrics'] = [
            '  response_time: "<500ms"',
            '  success_rate: ">95%"',
            '  accuracy: ">98%"'
        ]
    
    def standardize_agent(self, file_path: Path) -> bool:
        """Standardize a single agent file"""
        if file_path.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION']:
            return False
            
        print(f"Standardizing {file_path.stem}...")
        
        # Extract info from existing file
        info = self.extract_agent_info(file_path)
        
        # Generate standardized content
        standardized = self.standard_template.format(
            name=info['name'],
            uuid=info['uuid'],
            category=info['category'],
            priority=info['priority'],
            role=info['role'],
            expertise=info['expertise'],
            focus=info['focus'],
            capabilities='\n'.join(info['capabilities']),
            triggers='\n'.join(info['triggers']),
            invokes='\n'.join(info['invokes']),
            p_cores_usage=info['p_cores_usage'],
            e_cores_usage=info['e_cores_usage'],
            thermal_target=info['thermal_target'],
            metrics='\n'.join(info['metrics']),
            content=info['original_content']
        )
        
        # Backup original
        backup_path = file_path.parent / 'backups' / 'pre-standardization' / file_path.name
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        backup_path.write_text(file_path.read_text())
        
        # Write standardized version
        file_path.write_text(standardized)
        
        return True
    
    def standardize_all(self):
        """Standardize all agent files"""
        print("🔧 Standardizing ALL agents to Claude Code format")
        print("=" * 60)
        
        agent_files = list(self.agents_dir.glob('*.md'))
        standardized_count = 0
        
        for agent_file in agent_files:
            if self.standardize_agent(agent_file):
                standardized_count += 1
                
        print(f"\n✅ Standardized {standardized_count} agents")
        print("\nAll agents now have:")
        print("  • Uniform YAML frontmatter structure")
        print("  • Consistent metadata fields")
        print("  • Standard communication configuration")
        print("  • Tandem orchestration integration")
        print("  • Hardware optimization settings")
        print("  • Success metrics definitions")
        
        return standardized_count


if __name__ == "__main__":
    standardizer = AgentStandardizer()
    
    # First, let's just analyze without changing
    print("📋 Analyzing agent formats...")
    agent_files = list(standardizer.agents_dir.glob('*.md'))
    
    needs_standardization = []
    for agent_file in agent_files:
        if agent_file.stem in ['README', 'Template', 'STATUSLINE_INTEGRATION']:
            continue
            
        content = agent_file.read_text()
        # Check if already has standard structure
        if not re.search(r'^# Claude Code Agent Definition v7.0', content, re.MULTILINE):
            needs_standardization.append(agent_file.stem)
            
    print(f"\nAgents needing standardization: {len(needs_standardization)}")
    if needs_standardization:
        print("Agents:", ', '.join(needs_standardization[:10]))
        if len(needs_standardization) > 10:
            print(f"  ... and {len(needs_standardization) - 10} more")
    
    response = input("\n⚠️  Standardize all agents? This will backup originals. (y/n): ")
    if response.lower() == 'y':
        standardizer.standardize_all()
    else:
        print("Standardization cancelled.")