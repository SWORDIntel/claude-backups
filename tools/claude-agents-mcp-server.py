#!/usr/bin/env python3
"""
Claude Agents MCP Server
Exposes project agents as a Model Context Protocol server for global access
"""

import asyncio
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

import yaml

# Add agents directory to path
AGENTS_DIR = Path(__file__).parent / "agents"
sys.path.insert(0, str(AGENTS_DIR / "src" / "python"))

from agent_registry import AgentRegistry
from production_orchestrator import ProductionOrchestrator


class ClaudeAgentsMCPServer:
    """MCP Server that exposes all project agents as tools"""

    def __init__(self):
        self.agents_dir = AGENTS_DIR
        self.registry = AgentRegistry(str(self.agents_dir))
        self.orchestrator = None
        self.agents = {}

    async def initialize(self):
        """Initialize the MCP server and discover agents"""
        # Initialize orchestrator
        self.orchestrator = ProductionOrchestrator()
        await self.orchestrator.initialize()

        # Discover all agents
        await self.registry.discover_agents()
        self.agents = self.registry.agents

        print(f"Discovered {len(self.agents)} agents")
        return self

    def get_tools_manifest(self) -> Dict[str, Any]:
        """Generate MCP tools manifest for all agents"""
        tools = []

        for agent_name, agent_info in self.agents.items():
            # Create tool definition for each agent
            tool = {
                "name": f"agent_{agent_name.lower()}",
                "description": agent_info.get("description", f"{agent_name} agent"),
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "description": "Action to perform",
                            "enum": agent_info.get(
                                "capabilities", ["analyze", "execute", "report"]
                            ),
                        },
                        "input": {
                            "type": "string",
                            "description": "Input for the agent",
                        },
                        "options": {
                            "type": "object",
                            "description": "Additional options for the agent",
                        },
                    },
                    "required": ["action", "input"],
                },
            }
            tools.append(tool)

        return {"name": "claude-agents", "version": "1.0.0", "tools": tools}

    async def handle_tool_call(self, tool_name: str, arguments: Dict) -> Dict:
        """Handle MCP tool calls and route to appropriate agent"""
        # Extract agent name from tool name
        agent_name = tool_name.replace("agent_", "").upper()

        if agent_name not in self.agents:
            return {"error": f"Agent {agent_name} not found"}

        # Invoke agent through orchestrator
        result = await self.orchestrator.invoke_agent(
            agent_name.lower(),
            arguments.get("action", "execute"),
            {"input": arguments.get("input"), "options": arguments.get("options", {})},
        )

        return result

    def start_server(self, port: int = 8080):
        """Start the MCP server"""
        from aiohttp import web

        async def handle_manifest(request):
            """Return tools manifest"""
            return web.json_response(self.get_tools_manifest())

        async def handle_tool_call(request):
            """Handle tool invocation"""
            data = await request.json()
            result = await self.handle_tool_call(
                data.get("tool"), data.get("arguments", {})
            )
            return web.json_response(result)

        app = web.Application()
        app.router.add_get("/manifest", handle_manifest)
        app.router.add_post("/tools/invoke", handle_tool_call)

        print(f"Starting MCP server on port {port}")
        print(f"Agents available: {', '.join(self.agents.keys())}")
        web.run_app(app, port=port)


async def main():
    """Main entry point"""
    server = ClaudeAgentsMCPServer()
    await server.initialize()
    server.start_server()


if __name__ == "__main__":
    asyncio.run(main())
