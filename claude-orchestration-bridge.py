#!/usr/bin/env python3
"""
Claude Code Orchestration Bridge - Unified with Permission Bypass
Seamlessly integrates Python Tandem Orchestration with existing Claude Code workflows
while maintaining permission bypass for LiveCD environments
"""

import asyncio
import sys
import os
import json
import time
import subprocess
from pathlib import Path

# Add the Python orchestration system to path
SCRIPT_DIR = Path(__file__).parent
PYTHON_DIR = SCRIPT_DIR / "agents" / "src" / "python"
sys.path.append(str(PYTHON_DIR))

try:
    from production_orchestrator import ProductionOrchestrator, StandardWorkflows, CommandSet, CommandStep, CommandType, ExecutionMode, Priority
    from agent_registry import get_registry
except ImportError as e:
    print(f"Warning: Python orchestration system not available: {e}")
    sys.exit(1)

class ClaudeOrchestrationBridge:
    """
    Bridge that detects Claude Code usage patterns and automatically
    enhances them with orchestration capabilities while maintaining
    permission bypass for LiveCD compatibility
    """
    
    def __init__(self):
        self.orchestrator = None
        self.permission_bypass = os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true'
        self.claude_binary = self._find_claude_binary()
        self.pattern_triggers = {
            # Development workflow triggers
            "create": ["architect", "constructor"],
            "build": ["constructor", "testbed"],
            "test": ["testbed", "debugger"],
            "fix": ["debugger", "patcher"],
            "deploy": ["deployer", "monitor"],
            "document": ["docgen", "tui"],
            "review": ["linter", "security"],
            "optimize": ["optimizer", "monitor"],
            
            # Multi-agent workflow triggers
            "full development": "dev_cycle",
            "complete project": "dev_cycle", 
            "security audit": "security_audit",
            "documentation": "document_generation",
            "code review": ["linter", "security", "testbed"],
            
            # Agent coordination patterns
            "design and implement": ["architect", "constructor"],
            "test and fix": ["testbed", "debugger", "patcher"],
            "secure and deploy": ["security", "deployer"],
            "document and review": ["docgen", "linter"]
        }
    
    def _find_claude_binary(self):
        """Find the actual Claude binary (not wrapper)"""
        search_paths = [
            os.path.expanduser("~/.local/npm-global/bin/claude.original"),
            os.path.expanduser("~/.local/bin/claude.original"),
            "/usr/local/bin/claude.original",
            os.path.expanduser("~/.local/npm-global/bin/claude"),
            os.path.expanduser("~/.local/bin/claude"),
        ]
        
        for path in search_paths:
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
        
        # Try which command
        try:
            result = subprocess.run(['which', 'claude'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return None
    
    async def initialize(self):
        """Initialize the orchestration system"""
        self.orchestrator = ProductionOrchestrator()
        success = await self.orchestrator.initialize()
        return success
    
    def detect_workflow_intent(self, user_input):
        """
        Analyze user input to detect if orchestration would be beneficial
        """
        user_lower = user_input.lower()
        
        # Check for workflow keywords
        detected_patterns = []
        for trigger, agents in self.pattern_triggers.items():
            if trigger in user_lower:
                detected_patterns.append((trigger, agents))
        
        # Check for multi-agent indicators
        multi_agent_indicators = [
            "and then", "after that", "also", "plus", "in addition",
            "complete", "full", "comprehensive", "entire", "whole"
        ]
        
        has_multi_agent = any(indicator in user_lower for indicator in multi_agent_indicators)
        
        return detected_patterns, has_multi_agent
    
    async def suggest_orchestration(self, user_input, detected_patterns, has_multi_agent):
        """
        Suggest orchestration enhancements based on detected patterns
        """
        if not detected_patterns and not has_multi_agent:
            return None
        
        suggestions = []
        
        # Standard workflow suggestions
        for pattern, agents in detected_patterns:
            if isinstance(agents, str):  # Pre-built workflow
                suggestions.append({
                    "type": "workflow",
                    "name": agents,
                    "description": f"Run {pattern} workflow automatically",
                    "command": f"orchestration:{agents}"
                })
            elif isinstance(agents, list):  # Multi-agent coordination
                suggestions.append({
                    "type": "coordination",
                    "agents": agents,
                    "description": f"Coordinate {', '.join(agents)} for {pattern}",
                    "command": f"coordinate:{','.join(agents)}"
                })
        
        # Multi-agent suggestion for complex tasks
        if has_multi_agent and len(detected_patterns) > 1:
            suggestions.append({
                "type": "workflow",
                "name": "dev_cycle",
                "description": "Run complete development workflow",
                "command": "orchestration:dev_cycle"
            })
        
        return suggestions
    
    async def invoke_claude_with_task(self, task_description):
        """
        Invoke Claude Code with permission bypass for a specific task
        """
        if not self.claude_binary:
            return {"error": "Claude binary not found"}
        
        cmd = [self.claude_binary]
        
        # Add permission bypass if enabled
        if self.permission_bypass:
            cmd.append('--dangerously-skip-permissions')
        
        cmd.extend(['/task', task_description])
        
        try:
            result = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await result.communicate()
            
            return {
                "status": "completed" if result.returncode == 0 else "failed",
                "stdout": stdout.decode(),
                "stderr": stderr.decode(),
                "returncode": result.returncode
            }
        except Exception as e:
            return {"error": str(e)}
    
    async def execute_orchestration_command(self, command):
        """
        Execute orchestration command and return results
        """
        if not self.orchestrator:
            return {"error": "Orchestrator not initialized"}
        
        try:
            if command.startswith("orchestration:"):
                workflow_name = command.split(":", 1)[1]
                
                if workflow_name == "dev_cycle":
                    workflow = StandardWorkflows.create_development_workflow()
                elif workflow_name == "security_audit":
                    workflow = StandardWorkflows.create_security_audit_workflow()
                elif workflow_name == "document_generation":
                    workflow = StandardWorkflows.create_document_generation_workflow()
                else:
                    return {"error": f"Unknown workflow: {workflow_name}"}
                
                result = await self.orchestrator.execute_command_set(workflow)
                return result
            
            elif command.startswith("coordinate:"):
                agent_names = command.split(":", 1)[1].split(",")
                
                # Create a simple coordination workflow
                from production_orchestrator import CommandSet, CommandStep, CommandType
                
                steps = []
                for i, agent in enumerate(agent_names):
                    steps.append(CommandStep(
                        id=f"step_{i}",
                        agent=agent.strip(),
                        action="coordinate",
                        payload={"context": "User requested coordination"}
                    ))
                
                workflow = CommandSet(
                    name=f"Coordination: {', '.join(agent_names)}",
                    type=CommandType.WORKFLOW,
                    steps=steps
                )
                
                result = await self.orchestrator.execute_command_set(workflow)
                return result
            
        except Exception as e:
            return {"error": str(e)}
    
    def format_suggestion_output(self, suggestions):
        """
        Format suggestions for display to user
        """
        if not suggestions:
            return ""
        
        output = ["\n🤖 Orchestration Enhancement Available:"]
        
        for i, suggestion in enumerate(suggestions, 1):
            output.append(f"\n{i}. {suggestion['description']}")
            output.append(f"   Command: {suggestion['command']}")
        
        output.append(f"\nTo use: claude-orchestrate '<command>' or append --orchestrate to your Claude command")
        output.append("To disable: export CLAUDE_ORCHESTRATION=off")
        
        return "\n".join(output)

async def main():
    """
    Main bridge function - unified with permission bypass
    """
    
    # Check if orchestration is disabled
    if os.environ.get("CLAUDE_ORCHESTRATION", "").lower() == "off":
        sys.exit(0)
    
    # Get user input from command line or stdin
    if len(sys.argv) > 1:
        user_input = " ".join(sys.argv[1:])
    else:
        user_input = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
    
    if not user_input:
        print("╔════════════════════════════════════════════════════════════╗")
        print("║    Claude Unified Orchestration Bridge                      ║")
        print("║    Permission Bypass + Tandem Orchestration                 ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()
        print("Usage: claude-orchestrate '<your task description>'")
        print("   or: echo 'your task' | claude-orchestrate")
        print()
        print("Current Configuration:")
        print(f"  Permission Bypass: {'ENABLED' if os.environ.get('CLAUDE_PERMISSION_BYPASS', 'true').lower() == 'true' else 'DISABLED'}")
        print(f"  Orchestration: ENABLED")
        sys.exit(1)
    
    # Initialize bridge
    bridge = ClaudeOrchestrationBridge()
    
    print("🔍 Analyzing task for orchestration opportunities...")
    if bridge.permission_bypass:
        print("🔓 Permission bypass: ENABLED (LiveCD mode)")
    
    if not await bridge.initialize():
        print("❌ Could not initialize orchestration system")
        sys.exit(1)
    
    # Detect patterns
    detected_patterns, has_multi_agent = bridge.detect_workflow_intent(user_input)
    
    # Generate suggestions
    suggestions = await bridge.suggest_orchestration(user_input, detected_patterns, has_multi_agent)
    
    if not suggestions:
        print("✅ No orchestration enhancement needed - proceeding with standard Claude Code")
        sys.exit(0)
    
    # Show suggestions
    print(bridge.format_suggestion_output(suggestions))
    
    # If running interactively, ask user if they want to execute
    if sys.stdin.isatty():
        print(f"\nExecute suggestion 1? [y/N]: ", end="", flush=True)
        response = input().strip().lower()
        
        if response in ['y', 'yes']:
            print(f"\n🚀 Executing: {suggestions[0]['description']}")
            result = await bridge.execute_orchestration_command(suggestions[0]['command'])
            
            print(f"\n📊 Results:")
            print(f"Status: {result.get('status', 'unknown')}")
            print(f"Steps completed: {len(result.get('results', {}))}")
            
            if result.get('status') == 'completed':
                print("✅ Orchestration completed successfully!")
            else:
                print(f"⚠️  Orchestration finished with status: {result.get('status')}")
        else:
            print("👍 Proceeding with standard Claude Code workflow")

if __name__ == "__main__":
    asyncio.run(main())