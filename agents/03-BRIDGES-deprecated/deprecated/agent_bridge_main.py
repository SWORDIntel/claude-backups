#!/usr/bin/env python3
"""
Main Agent Bridge Implementation
Connects Claude Code to the binary protocol and agent system
"""

import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional

# Add paths
sys.path.append('/home/ubuntu/Documents/Claude/agents/03-BRIDGES')
sys.path.append('/home/ubuntu/Documents/Claude/agents/04-SOURCE/python-modules')

from 03-BRIDGES.claude_agent_bridge import BinaryBridgeConnection, AgentConfig
from ENHANCED_AGENT_INTEGRATION import AgentMessage, AgentOrchestrator, Priority
from statusline_bridge import update_statusline, get_statusline

# Global bridge instance
_bridge_instance = None
_orchestrator_instance = None

def get_bridge():
    """Get or create bridge singleton"""
    global _bridge_instance
    if _bridge_instance is None:
        _bridge_instance = BinaryBridgeConnection()
    return _bridge_instance

def get_orchestrator():
    """Get or create orchestrator singleton"""
    global _orchestrator_instance
    if _orchestrator_instance is None:
        _orchestrator_instance = AgentOrchestrator()
    return _orchestrator_instance

def bridge():
    """Main bridge function for compatibility"""
    return get_bridge()

def task_agent_invoke(agent_name: str, task: str, **kwargs) -> Dict[str, Any]:
    """
    Invoke an agent with a specific task
    This is the main function called by Claude Code's Task tool
    
    Args:
        agent_name: Name of the agent to invoke
        task: Task description or prompt
        **kwargs: Additional parameters
    
    Returns:
        Dict with agent response
    """
    print(f"🤖 Invoking agent: {agent_name}")
    print(f"📋 Task: {task}")
    
    # Update statusline
    update_statusline("task_started", agent=agent_name)
    
    # Check if we can use the binary bridge
    bridge = get_bridge()
    if bridge.connect():
        # Send through binary protocol
        message = {
            "type": "agent_invoke",
            "agent": agent_name,
            "task": task,
            "params": kwargs
        }
        
        response = bridge.send_message(json.dumps(message).encode())
        if response:
            try:
                result = json.loads(response.decode())
                update_statusline("task_completed", agent=agent_name)
                return result
            except:
                update_statusline("task_error", agent=agent_name, error="Invalid response")
                return {"status": "error", "message": "Invalid response from binary bridge"}
    
    # Fallback to orchestrator
    orchestrator = get_orchestrator()
    
    # Create agent message
    msg = AgentMessage(
        source_agent="claude_code",
        target_agents=[agent_name],
        message_type="task",
        payload={"task": task, **kwargs},
        priority=Priority.HIGH
    )
    
    # Try to execute through orchestrator
    try:
        # This would normally execute the agent
        # For now, return a structured response
        response = {
            "status": "success",
            "agent": agent_name,
            "task": task,
            "response": f"Agent {agent_name} acknowledged task but execution not implemented",
            "metadata": {
                "binary_bridge": False,
                "orchestrator": True,
                "timestamp": str(asyncio.get_event_loop().time())
            }
        }
        
        # Check if agent definition exists
        agent_def_path = Path(f"/home/ubuntu/Documents/Claude/agents/01-AGENTS-DEFINITIONS/ACTIVE/{agent_name}.md")
        if agent_def_path.exists():
            response["agent_found"] = True
            response["agent_path"] = str(agent_def_path)
        else:
            response["agent_found"] = False
            response["message"] = f"Agent definition not found: {agent_name}.md"
        
        return response
        
    except Exception as e:
        return {
            "status": "error",
            "agent": agent_name,
            "error": str(e)
        }

def list_available_agents() -> list:
    """List all available agent definitions"""
    agents_dir = Path("/home/ubuntu/Documents/Claude/agents/01-AGENTS-DEFINITIONS/ACTIVE")
    agents = []
    
    if agents_dir.exists():
        for agent_file in agents_dir.glob("*.md"):
            agent_name = agent_file.stem
            if agent_name not in ["Template", "README"]:
                agents.append(agent_name)
    
    return sorted(agents)

def test_agent_system():
    """Test the agent system connectivity"""
    print("🧪 Testing Agent System")
    print("=" * 50)
    
    # Test binary bridge
    bridge = get_bridge()
    if bridge.connect():
        print("✅ Binary bridge connected")
        bridge.close()
    else:
        print("❌ Binary bridge not available")
    
    # List agents
    agents = list_available_agents()
    print(f"\n📚 Found {len(agents)} agent definitions:")
    for agent in agents[:5]:  # Show first 5
        print(f"   - {agent}")
    if len(agents) > 5:
        print(f"   ... and {len(agents) - 5} more")
    
    # Test invocation
    print("\n🔧 Testing agent invocation:")
    result = task_agent_invoke("Director", "Test connection")
    print(f"   Status: {result.get('status')}")
    print(f"   Agent found: {result.get('agent_found', False)}")
    
    return result

# Main entry point
if __name__ == "__main__":
    test_agent_system()