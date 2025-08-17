#!/usr/bin/env python3
"""
Auto-integration module for Claude Agent Communication System
Automatically connects new agents to the communication system
"""

import sys
import os
sys.path.append('/home/ubuntu/Documents/Claude/agents/src/python')

from ENHANCED_AGENT_INTEGRATION import AgentSystem, AgentMessage, Priority

class AutoIntegration:
    def __init__(self):
        self.system = AgentSystem()
        self.connected_agents = set()
    
    def integrate_agent(self, agent_name, agent_type="CUSTOM"):
        """Automatically integrate a new agent into the system"""
        if agent_name not in self.connected_agents:
            agent = self.system.create_agent(
                name=agent_name,
                type=agent_type
            )
            self.connected_agents.add(agent_name)
            print(f"✓ Agent '{agent_name}' integrated successfully")
            return agent
        else:
            print(f"⚠ Agent '{agent_name}' already integrated")
            return self.system.get_agent(agent_name)
    
    async def test_communication(self):
        """Test communication between all agents"""
        test_msg = AgentMessage(
            source_agent="test_client",
            target_agents=["director", "monitor"],
            action="health_check",
            payload={"test": True},
            priority=Priority.MEDIUM
        )
        
        result = await self.system.send_message(test_msg)
        return result

# Auto-integration on import
auto_integration = AutoIntegration()

def integrate_with_claude_agent_system(agent_name, agent_type="CUSTOM"):
    """Helper function for easy integration"""
    return auto_integration.integrate_agent(agent_name, agent_type)
