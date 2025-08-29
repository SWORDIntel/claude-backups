#!/usr/bin/env python3
"""
Claude Code Hook Adapter - Fixed Version
Integrates with the Unified Agent Registry System
"""

import os
import sys
import json
import time
import asyncio
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime

# Dynamic path discovery - no absolute paths
def find_project_root():
    """Find project root dynamically"""
    current = Path.cwd()
    
    # Look for .claude directory or agent markers
    markers = ['.claude', 'agents', 'CLAUDE.md', '.git']
    
    while current != current.parent:
        for marker in markers:
            if (current / marker).exists():
                return current
        current = current.parent
    
    # Fallback to current directory
    return Path.cwd()

# Add project to path dynamically
PROJECT_ROOT = find_project_root()
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / 'agents'))

class ClaudeCodeHookAdapter:
    """
    Adapter for Claude Code /hooks command
    Maps Claude Code hook triggers to the Unified Agent Registry
    """
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.agents_dir = self.project_root / 'agents'
        self.claude_config_dir = Path.home() / '.config' / 'claude'
        self.registry_file = self.claude_config_dir / 'project-agents.json'
        self.hook_dir = Path.home() / '.claude' / 'hooks'
        self.context = self._extract_claude_context()
        self.registry = self._load_registry()
        
    def _extract_claude_context(self) -> Dict[str, Any]:
        """Extract context from Claude Code environment"""
        context = {
            'timestamp': time.time(),
            'claude_code_version': os.environ.get('CLAUDE_VERSION', 'unknown'),
            'cwd': str(Path.cwd()),
            'project_root': str(self.project_root)
        }
        
        # Extract Claude-specific environment variables
        claude_env_vars = [
            'CLAUDE_TASK_ID',
            'CLAUDE_AGENT_NAME', 
            'CLAUDE_TASK_CONTEXT',
            'CLAUDE_EDITED_FILES',
            'CLAUDE_CURRENT_FILE',
            'CLAUDE_HOOK_PHASE',
            'CLAUDE_CONTEXT_FILE'
        ]
        
        for var in claude_env_vars:
            if var in os.environ:
                context[var.lower()] = os.environ[var]
        
        # Process edited files if available
        if 'CLAUDE_EDITED_FILES' in os.environ:
            files = os.environ['CLAUDE_EDITED_FILES'].split(',')
            context['edited_files'] = files
            
            # Read file contents if they exist
            context['file_contents'] = {}
            for file in files:
                file_path = Path(file)
                if file_path.exists():
                    try:
                        with open(file_path) as f:
                            context['file_contents'][file] = f.read()
                    except Exception as e:
                        context['file_contents'][file] = f"Error reading: {e}"
        
        return context
    
    def _load_registry(self) -> Dict[str, Any]:
        """Load the agent registry"""
        if self.registry_file.exists():
            with open(self.registry_file) as f:
                return json.load(f)
        return {"custom_agents": {}, "agent_mappings": {}, "categories": {}}
    
    def trigger_hook(self, hook_phase: str) -> Dict[str, Any]:
        """
        Trigger a hook phase when called by Claude Code
        """
        # Map Claude Code hook names to internal phases
        phase_map = {
            'pre-task': 'pre_task',
            'pre_task': 'pre_task',
            'post-edit': 'post_edit',
            'post_edit': 'post_edit',
            'post-task': 'post_task',
            'post_task': 'post_task'
        }
        
        internal_phase = phase_map.get(hook_phase, hook_phase)
        
        # Execute phase-specific logic
        result = {
            'phase': hook_phase,
            'success': True,
            'context': self.context,
            'timestamp': time.time(),
            'agents_triggered': []
        }
        
        if internal_phase == 'pre_task':
            result['actions'] = self._handle_pre_task()
        elif internal_phase == 'post_edit':
            result['actions'] = self._handle_post_edit()
        elif internal_phase == 'post_task':
            result['actions'] = self._handle_post_task()
        
        return result
    
    def _handle_pre_task(self) -> List[Dict[str, Any]]:
        """Handle pre-task phase"""
        actions = []
        
        # 1. Validate task context
        validation = self._validate_task_context()
        actions.append({
            'type': 'validation',
            'status': 'success' if validation['valid'] else 'warning',
            'details': validation
        })
        
        # 2. Setup environment
        env_setup = self._setup_environment()
        actions.append({
            'type': 'environment_setup',
            'status': 'success',
            'details': env_setup
        })
        
        # 3. Select appropriate agents
        task_context = self.context.get('claude_task_context', '')
        selected_agents = self._select_agents_for_task(task_context)
        actions.append({
            'type': 'agent_selection',
            'status': 'success',
            'agents': selected_agents
        })
        
        return actions
    
    def _handle_post_edit(self) -> List[Dict[str, Any]]:
        """Handle post-edit phase"""
        actions = []
        
        # 1. Extract code changes
        if 'edited_files' in self.context:
            for file in self.context['edited_files']:
                actions.append({
                    'type': 'file_processed',
                    'file': file,
                    'status': 'success'
                })
        
        # 2. Run validation if development cluster agents are available
        if self._is_agent_available('linter'):
            validation_result = self._run_validation()
            actions.append({
                'type': 'validation',
                'status': 'success' if validation_result['passed'] else 'warning',
                'details': validation_result
            })
        
        # 3. Cache results
        cache_result = self._cache_results()
        actions.append({
            'type': 'cache_update',
            'status': 'success',
            'details': cache_result
        })
        
        return actions
    
    def _handle_post_task(self) -> List[Dict[str, Any]]:
        """Handle post-task phase"""
        actions = []
        
        # 1. Cleanup temporary files
        cleanup_result = self._cleanup_environment()
        actions.append({
            'type': 'cleanup',
            'status': 'success',
            'details': cleanup_result
        })
        
        # 2. Generate report
        report = self._generate_report()
        actions.append({
            'type': 'report_generation',
            'status': 'success',
            'report': report
        })
        
        # 3. Archive artifacts if needed
        if self.context.get('claude_task_id'):
            archive_result = self._archive_artifacts()
            actions.append({
                'type': 'archive',
                'status': 'success',
                'details': archive_result
            })
        
        return actions
    
    def _validate_task_context(self) -> Dict[str, Any]:
        """Validate the task context"""
        validation = {
            'valid': True,
            'warnings': [],
            'info': []
        }
        
        # Check for task ID
        if not self.context.get('claude_task_id'):
            validation['warnings'].append('No CLAUDE_TASK_ID found')
        
        # Check for project root
        if not self.project_root.exists():
            validation['warnings'].append('Project root not found')
            validation['valid'] = False
        
        # Check for agent registry
        if not self.registry_file.exists():
            validation['info'].append('Agent registry not found - will use defaults')
        
        return validation
    
    def _setup_environment(self) -> Dict[str, Any]:
        """Setup the environment for task execution"""
        setup = {
            'directories_created': [],
            'paths_added': [],
            'environment_vars': {}
        }
        
        # Create necessary directories
        dirs_to_create = [
            self.claude_config_dir,
            self.hook_dir,
            Path.home() / '.cache' / 'claude-agents'
        ]
        
        for dir_path in dirs_to_create:
            if not dir_path.exists():
                dir_path.mkdir(parents=True, exist_ok=True)
                setup['directories_created'].append(str(dir_path))
        
        # Set environment variables
        env_vars = {
            'CLAUDE_PROJECT_ROOT': str(self.project_root),
            'CLAUDE_AGENTS_DIR': str(self.agents_dir),
            'CLAUDE_CONFIG_DIR': str(self.claude_config_dir)
        }
        
        for key, value in env_vars.items():
            os.environ[key] = value
            setup['environment_vars'][key] = value
        
        return setup
    
    def _select_agents_for_task(self, task_context: str) -> List[str]:
        """Select appropriate agents based on task context"""
        selected = []
        
        if not task_context:
            return ['director']  # Default to director for unknown tasks
        
        task_lower = task_context.lower()
        
        # Pattern-based agent selection
        patterns = {
            'debug': ['debugger', 'linter'],
            'test': ['testbed', 'linter'],
            'build': ['constructor', 'packager'],
            'deploy': ['deployer', 'monitor'],
            'optimize': ['optimizer'],
            'document': ['docgen'],
            'api': ['apidesigner'],
            'database': ['database'],
            'security': ['security'],
            'ui': ['web', 'mobile', 'tui'],
            'plan': ['director', 'projectorchestrator']
        }
        
        for pattern, agents in patterns.items():
            if pattern in task_lower:
                selected.extend(agents)
        
        # Remove duplicates while preserving order
        seen = set()
        result = []
        for agent in selected:
            if agent not in seen:
                seen.add(agent)
                result.append(agent)
        
        return result if result else ['director']
    
    def _is_agent_available(self, agent_name: str) -> bool:
        """Check if an agent is available in the registry"""
        return agent_name in self.registry.get('custom_agents', {})
    
    def _run_validation(self) -> Dict[str, Any]:
        """Run validation on edited files"""
        result = {
            'passed': True,
            'issues': [],
            'files_checked': []
        }
        
        if 'edited_files' not in self.context:
            return result
        
        for file in self.context['edited_files']:
            file_path = Path(file)
            if file_path.exists() and file_path.suffix in ['.py', '.js', '.ts', '.c', '.cpp']:
                result['files_checked'].append(file)
                # Basic validation - could be enhanced with actual linting
                if file_path.stat().st_size > 100000:  # File > 100KB
                    result['issues'].append(f"{file}: Large file warning")
        
        result['passed'] = len(result['issues']) == 0
        return result
    
    def _cache_results(self) -> Dict[str, Any]:
        """Cache task results"""
        cache_dir = Path.home() / '.cache' / 'claude-agents'
        cache_file = cache_dir / f"task_{self.context.get('claude_task_id', 'unknown')}.json"
        
        cache_data = {
            'timestamp': time.time(),
            'context': self.context,
            'edited_files': self.context.get('edited_files', [])
        }
        
        try:
            with open(cache_file, 'w') as f:
                json.dump(cache_data, f, indent=2, default=str)
            return {'cached': True, 'location': str(cache_file)}
        except Exception as e:
            return {'cached': False, 'error': str(e)}
    
    def _cleanup_environment(self) -> Dict[str, Any]:
        """Cleanup temporary files and resources"""
        cleanup = {
            'temp_files_removed': 0,
            'cache_cleared': False
        }
        
        # Clean up old cache files (older than 7 days)
        cache_dir = Path.home() / '.cache' / 'claude-agents'
        if cache_dir.exists():
            cutoff_time = time.time() - (7 * 24 * 60 * 60)  # 7 days
            for cache_file in cache_dir.glob('task_*.json'):
                if cache_file.stat().st_mtime < cutoff_time:
                    cache_file.unlink()
                    cleanup['temp_files_removed'] += 1
        
        return cleanup
    
    def _generate_report(self) -> Dict[str, Any]:
        """Generate task completion report"""
        report = {
            'task_id': self.context.get('claude_task_id', 'unknown'),
            'timestamp': datetime.now().isoformat(),
            'edited_files': self.context.get('edited_files', []),
            'project_root': str(self.project_root),
            'status': 'completed'
        }
        
        # Add metrics if available
        if 'edited_files' in self.context:
            report['files_modified'] = len(self.context['edited_files'])
        
        return report
    
    def _archive_artifacts(self) -> Dict[str, Any]:
        """Archive task artifacts"""
        archive_dir = self.project_root / '.claude' / 'archives'
        archive_dir.mkdir(parents=True, exist_ok=True)
        
        task_id = self.context.get('claude_task_id', f"task_{int(time.time())}")
        archive_file = archive_dir / f"{task_id}.json"
        
        archive_data = {
            'task_id': task_id,
            'timestamp': time.time(),
            'context': self.context,
            'project_state': {
                'cwd': str(Path.cwd()),
                'project_root': str(self.project_root)
            }
        }
        
        try:
            with open(archive_file, 'w') as f:
                json.dump(archive_data, f, indent=2, default=str)
            return {'archived': True, 'location': str(archive_file)}
        except Exception as e:
            return {'archived': False, 'error': str(e)}
    
    def register_as_claude_hook(self):
        """Register this adapter as a Claude Code hook handler"""
        
        # Create wrapper script that Claude Code can call
        wrapper_script = self.hook_dir / 'claude_hook_wrapper.sh'
        
        wrapper_content = f'''#!/bin/bash
# Claude Code Hook Wrapper
# This script is called by Claude Code /hooks command

HOOK_PHASE="$1"
CONTEXT_FILE="$2"

# Export Claude context
export CLAUDE_HOOK_PHASE="$HOOK_PHASE"
export CLAUDE_CONTEXT_FILE="$CONTEXT_FILE"

# Find Python adapter dynamically
SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Call Python adapter
python3 "$PROJECT_ROOT/claude_code_hook_adapter.py" --trigger "$HOOK_PHASE"
'''
        
        wrapper_script.parent.mkdir(parents=True, exist_ok=True)
        wrapper_script.write_text(wrapper_content)
        wrapper_script.chmod(0o755)
        
        print(f"✅ Registered hook wrapper at: {wrapper_script}")
        
        # Create .claude-hooks file for Claude Code to discover
        claude_hooks_file = Path.home() / '.claude-hooks'
        
        hooks_config = {
            "version": "1.0",
            "provider": "claude-agent-framework",
            "hooks": {
                "pre-task": str(wrapper_script) + " pre-task",
                "post-edit": str(wrapper_script) + " post-edit",
                "post-task": str(wrapper_script) + " post-task"
            }
        }
        
        with open(claude_hooks_file, 'w') as f:
            json.dump(hooks_config, f, indent=2)
        
        print(f"✅ Created Claude hooks config at: {claude_hooks_file}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--trigger', help='Trigger a hook phase')
    parser.add_argument('--register', action='store_true', help='Register with Claude Code')
    
    args = parser.parse_args()
    
    adapter = ClaudeCodeHookAdapter()
    
    if args.register:
        adapter.register_as_claude_hook()
    elif args.trigger:
        result = adapter.trigger_hook(args.trigger)
        print(json.dumps(result, indent=2, default=str))
    else:
        # Default action - show status
        print("Claude Code Hook Adapter")
        print(f"Project Root: {adapter.project_root}")
        print(f"Registry: {adapter.registry_file.exists() and 'Found' or 'Not Found'}")
        print(f"Agents Available: {len(adapter.registry.get('custom_agents', {}))}")
