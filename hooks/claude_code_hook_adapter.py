#!/usr/bin/env python3
# Create: claude_code_hook_adapter.py

"""
This adapter allows Claude Code to directly trigger Python hooks
through the /hooks command interface
"""

import os
import sys
import json
import time
from pathlib import Path
from typing import Dict, Any, Optional

class ClaudeCodeHookAdapter:
    """
    Adapter for Claude Code /hooks command
    Maps Claude Code hook triggers to Python hook system
    """
    
    # Claude Code sets these environment variables
    CLAUDE_ENV_VARS = [
        'CLAUDE_TASK_ID',
        'CLAUDE_AGENT_NAME', 
        'CLAUDE_TASK_CONTEXT',
        'CLAUDE_EDITED_FILES',
        'CLAUDE_CURRENT_FILE'
    ]
    
    def __init__(self):
        self.context = self._extract_claude_context()
        self.hook_dir = Path.home() / '.claude' / 'hooks'
        
    def _extract_claude_context(self) -> Dict[str, Any]:
        """Extract context from Claude Code environment"""
        
        context = {
            'timestamp': time.time(),
            'claude_code_version': os.environ.get('CLAUDE_VERSION', 'unknown')
        }
        
        # Extract all Claude-specific environment variables
        for var in self.CLAUDE_ENV_VARS:
            if var in os.environ:
                context[var.lower()] = os.environ[var]
        
        # Try to get current working directory and files
        context['cwd'] = os.getcwd()
        
        # If Claude provides edited files list
        if 'CLAUDE_EDITED_FILES' in os.environ:
            files = os.environ['CLAUDE_EDITED_FILES'].split(',')
            context['edited_files'] = files
            
            # Read file contents if they exist
            context['file_contents'] = {}
            for file in files:
                if Path(file).exists():
                    with open(file) as f:
                        context['file_contents'][file] = f.read()
        
        return context
    
    def trigger_hook(self, hook_phase: str) -> Dict[str, Any]:
        """
        Trigger a hook phase when called by Claude Code
        
        This is what Claude Code calls via /hooks command
        """
        
        # Map Claude Code hook names to our phases
        phase_map = {
            'pre-task': 'pre_task',
            'pre_task': 'pre_task',
            'post-edit': 'post_edit',
            'post_edit': 'post_edit',
            'post-task': 'post_task',
            'post_task': 'post_task'
        }
        
        internal_phase = phase_map.get(hook_phase, hook_phase)
        
        # Import and execute our hook system
        from agent_hooks import AgentHookSystem
        from hooks.pre_task_hooks import PreTaskHooks
        from hooks.post_edit_hooks import PostEditHooks
        from hooks.post_task_hooks import PostTaskHooks
        
        hook_system = AgentHookSystem()
        
        # Register appropriate hooks based on phase
        if internal_phase == 'pre_task':
            hook_system.register_hook('pre_task', 'validate', PreTaskHooks.validate_prompt, 10)
            hook_system.register_hook('pre_task', 'setup', PreTaskHooks.setup_environment, 20)
            hook_system.register_hook('pre_task', 'deps', PreTaskHooks.check_dependencies, 30)
            
        elif internal_phase == 'post_edit':
            hook_system.register_hook('post_edit', 'extract', PostEditHooks.extract_code_blocks, 10)
            hook_system.register_hook('post_edit', 'cache', PostEditHooks.save_to_cache, 20)
            hook_system.register_hook('post_edit', 'validate', PostEditHooks.validate_output, 30)
            
        elif internal_phase == 'post_task':
            hook_system.register_hook('post_task', 'cleanup', PostTaskHooks.cleanup_environment, 10)
            hook_system.register_hook('post_task', 'report', PostTaskHooks.generate_report, 20)
            hook_system.register_hook('post_task', 'archive', PostTaskHooks.archive_artifacts, 30)
        
        # Execute hooks with Claude context
        result = hook_system.execute_hooks(internal_phase, self.context)
        
        # Return result to Claude Code
        return {
            'phase': hook_phase,
            'success': True,
            'context': self.context,
            'result': result,
            'timestamp': time.time()
        }
    
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

# Call Python adapter
python3 {__file__} --trigger "$HOOK_PHASE"
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
        print(json.dumps(result, indent=2))
