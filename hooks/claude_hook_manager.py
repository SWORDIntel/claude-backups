#!/usr/bin/env python3
# Create: claude_hook_manager.py

import os
import json
import subprocess
from pathlib import Path
from typing import Dict, List

class ClaudeHookManager:
    """Manage hooks for Claude Code integration"""
    
    def __init__(self):
        self.claude_home = Path.home() / '.claude'
        self.hooks_dir = self.claude_home / 'hooks'
        self.config_file = self.hooks_dir / 'config.json'
        
    def register_with_claude(self):
        """Register hooks with Claude Code"""
        
        # Create Claude Code hook registration file
        registration = {
            "hook_provider": "claude-agent-framework",
            "version": "7.0.0",
            "hooks": {
                "/hooks/pre-task": {
                    "handler": str(self.hooks_dir / "pre-task" / "validate_and_setup.sh"),
                    "description": "Validate and prepare task execution"
                },
                "/hooks/post-edit": {
                    "handler": str(self.hooks_dir / "post-edit" / "process_changes.sh"),
                    "description": "Process code changes and extract artifacts"
                },
                "/hooks/post-task": {
                    "handler": str(self.hooks_dir / "post-task" / "cleanup_and_report.sh"),
                    "description": "Cleanup and generate reports"
                }
            }
        }
        
        # Write to Claude Code's expected location
        claude_registry = self.claude_home / 'hook_registry.json'
        with open(claude_registry, 'w') as f:
            json.dump(registration, f, indent=2)
        
        print(f"✅ Registered hooks with Claude Code at {claude_registry}")
        
    def test_hook(self, phase: str, test_context: Dict = None):
        """Test a specific hook phase"""
        
        if test_context is None:
            test_context = {
                "task": "Test task",
                "agent": "test_agent",
                "timestamp": "2024-01-01T00:00:00"
            }
        
        context_file = Path(f'/tmp/test_context_{phase}.json')
        with open(context_file, 'w') as f:
            json.dump(test_context, f)
        
        # Run the hook
        hook_script = self.hooks_dir / phase / f"{phase.replace('-', '_')}.sh"
        if hook_script.exists():
            result = subprocess.run(
                [str(hook_script), str(context_file)],
                capture_output=True,
                text=True
            )
            
            print(f"Hook Output:\n{result.stdout}")
            if result.stderr:
                print(f"Hook Errors:\n{result.stderr}")
            
            return result.returncode == 0
        else:
            print(f"❌ Hook script not found: {hook_script}")
            return False
    
    def list_hooks(self):
        """List all registered hooks"""
        
        if self.config_file.exists():
            with open(self.config_file) as f:
                config = json.load(f)
            
            print("\n📌 Registered Claude Code Hooks:\n")
            for phase, phase_config in config.get('hooks', {}).items():
                status = "✅ Enabled" if phase_config.get('enabled', False) else "❌ Disabled"
                print(f"  {phase}: {status}")
                
                for script in phase_config.get('scripts', []):
                    print(f"    - {script['name']}")
                    print(f"      Path: {script['path']}")
                    print(f"      Required: {script.get('required', False)}")
                    print(f"      Timeout: {script.get('timeout', 30)}s")
    
    def enable_hook(self, phase: str):
        """Enable a specific hook phase"""
        
        if self.config_file.exists():
            with open(self.config_file) as f:
                config = json.load(f)
        else:
            config = {"hooks": {}}
        
        if phase in config.get('hooks', {}):
            config['hooks'][phase]['enabled'] = True
            
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            print(f"✅ Enabled {phase} hook")
        else:
            print(f"❌ Hook phase {phase} not found")
    
    def disable_hook(self, phase: str):
        """Disable a specific hook phase"""
        
        if self.config_file.exists():
            with open(self.config_file) as f:
                config = json.load(f)
            
            if phase in config.get('hooks', {}):
                config['hooks'][phase]['enabled'] = False
                
                with open(self.config_file, 'w') as f:
                    json.dump(config, f, indent=2)
                
                print(f"✅ Disabled {phase} hook")

if __name__ == "__main__":
    import sys
    
    manager = ClaudeHookManager()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "register":
            manager.register_with_claude()
        elif command == "list":
            manager.list_hooks()
        elif command == "test" and len(sys.argv) > 2:
            phase = sys.argv[2]
            manager.test_hook(phase)
        elif command == "enable" and len(sys.argv) > 2:
            phase = sys.argv[2]
            manager.enable_hook(phase)
        elif command == "disable" and len(sys.argv) > 2:
            phase = sys.argv[2]
            manager.disable_hook(phase)
        else:
            print("Usage: claude_hook_manager.py [register|list|test|enable|disable] [phase]")
    else:
        # Interactive mode
        manager.register_with_claude()
        manager.list_hooks()
