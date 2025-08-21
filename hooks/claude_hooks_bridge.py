#!/usr/bin/env python3
# Create: claude_hooks_bridge.py

import sys
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
from agent_hooks import AgentHookSystem
from hooks.pre_task_hooks import PreTaskHooks
from hooks.post_edit_hooks import PostEditHooks
from hooks.post_task_hooks import PostTaskHooks

class ClaudeHooksBridge:
    """Bridge between Claude Code /hooks command and Python hook system"""
    
    HOOKS_DIR = Path.home() / '.claude' / 'hooks'
    HOOKS_REGISTRY = HOOKS_DIR / 'registry.json'
    
    def __init__(self):
        self.HOOKS_DIR.mkdir(parents=True, exist_ok=True)
        self.hook_system = AgentHookSystem()
        self.register_claude_hooks()
        
    def register_claude_hooks(self):
        """Register hooks that Claude Code can trigger"""
        
        # Create hook files for Claude Code to detect
        hooks_config = {
            "pre-task": {
                "description": "Validates and prepares tasks before execution",
                "handler": "claude_hooks_bridge.py --phase pre-task",
                "enabled": True
            },
            "post-edit": {
                "description": "Processes results after code edits",
                "handler": "claude_hooks_bridge.py --phase post-edit",
                "enabled": True
            },
            "post-task": {
                "description": "Cleanup and reporting after task completion",
                "handler": "claude_hooks_bridge.py --phase post-task",
                "enabled": True
            }
        }
        
        # Write registry for Claude Code
        with open(self.HOOKS_REGISTRY, 'w') as f:
            json.dump(hooks_config, f, indent=2)
        
        # Register Python handlers
        self.hook_system.register_hook('pre_task', 'validate', PreTaskHooks.validate_prompt, 10)
        self.hook_system.register_hook('pre_task', 'setup', PreTaskHooks.setup_environment, 20)
        self.hook_system.register_hook('post_edit', 'extract', PostEditHooks.extract_code_blocks, 10)
        self.hook_system.register_hook('post_edit', 'cache', PostEditHooks.save_to_cache, 20)
        self.hook_system.register_hook('post_task', 'report', PostTaskHooks.generate_report, 10)
        self.hook_system.register_hook('post_task', 'cleanup', PostTaskHooks.cleanup_environment, 20)
    
    def handle_claude_hook(self, phase: str, context_file: Optional[str] = None):
        """Handle hook trigger from Claude Code"""
        
        # Read context from Claude Code
        context = {}
        if context_file and Path(context_file).exists():
            with open(context_file) as f:
                context = json.load(f)
        else:
            # Try to read from stdin (Claude Code might pipe data)
            if not sys.stdin.isatty():
                context = json.loads(sys.stdin.read())
        
        # Map Claude Code phases to our hook system
        phase_mapping = {
            'pre-task': 'pre_task',
            'post-edit': 'post_edit',
            'post-task': 'post_task'
        }
        
        internal_phase = phase_mapping.get(phase, phase)
        
        # Execute hooks for this phase
        result = self.hook_system.execute_hooks(internal_phase, context)
        
        # Write result back for Claude Code
        output_file = Path(f'/tmp/claude_hook_{phase}_{os.getpid()}.json')
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        
        print(f"Hook results written to: {output_file}")
        return result

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Claude Code Hooks Bridge')
    parser.add_argument('--phase', required=True, choices=['pre-task', 'post-edit', 'post-task'])
    parser.add_argument('--context', help='Path to context JSON file')
    parser.add_argument('--install', action='store_true', help='Install hooks for Claude Code')
    
    args = parser.parse_args()
    
    bridge = ClaudeHooksBridge()
    
    if args.install:
        print("Installing hooks for Claude Code...")
        bridge.install_claude_hooks()
    else:
        bridge.handle_claude_hook(args.phase, args.context)
