#!/usr/bin/env python3
"""
Claude Code Registry Bridge
Direct integration between Claude Code and the Unified Agent Registry
"""

import asyncio
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


# Dynamic path discovery
def find_project_root():
    """Find project root dynamically"""
    current = Path.cwd()
    markers = [".claude", "agents", "CLAUDE.md", ".git"]

    while current != current.parent:
        for marker in markers:
            if (current / marker).exists():
                return current
        current = current.parent

    return Path.cwd()


PROJECT_ROOT = find_project_root()
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / "agents"))


class ClaudeRegistryBridge:
    """Bridge between Claude Code and Agent Registry"""

    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.agents_dir = self.project_root / "agents"
        self.config_dir = Path.home() / ".config" / "claude"
        self.registry_file = self.config_dir / "project-agents.json"
        self.cache_dir = Path.home() / ".cache" / "claude-agents"

        # Initialize directories
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Load or initialize registry
        self.registry = self._load_or_create_registry()

    def _load_or_create_registry(self) -> Dict[str, Any]:
        """Load existing registry or create from agent files"""
        if self.registry_file.exists():
            with open(self.registry_file) as f:
                return json.load(f)

        # Build registry from agent files
        return self._build_registry()

    def _build_registry(self) -> Dict[str, Any]:
        """Build registry from agent markdown files"""
        registry = {
            "version": "2.0.0",
            "updated": datetime.now().isoformat(),
            "custom_agents": {},
            "agent_mappings": {},
            "categories": {},
            "capabilities": {},
        }

        # Excluded files
        excluded = {
            "README.md",
            "Template.md",
            "STATUSLINE_INTEGRATION.md",
            "WHERE_I_AM.md",
            "DIRECTORY_STRUCTURE.md",
            "ORGANIZATION.md",
            "INTEGRATION_COMPLETE.md",
            "INTEGRATION_EXAMPLE.md",
            "CLAUDE.md",
        }

        # Find all agent files
        agent_files = []
        if self.agents_dir.exists():
            for pattern in ["*.md", "*.MD"]:
                agent_files.extend(self.agents_dir.glob(pattern))

        agent_files = [f for f in agent_files if f.name not in excluded]

        # Process each agent file
        for agent_file in agent_files:
            agent_name = agent_file.stem.lower()

            # Parse agent metadata
            metadata = self._parse_agent_file(agent_file)

            # Add to registry
            registry["custom_agents"][agent_name] = {
                "type": agent_name,
                "name": metadata.get("name", agent_name),
                "description": metadata.get("description", f"{agent_name} agent"),
                "tools": metadata.get("tools", []),
                "source": "project",
                "implementation": "adaptive",
                "category": metadata.get("category", "general"),
                "file_path": str(agent_file.relative_to(self.project_root)),
            }

            # Create mappings
            registry["agent_mappings"][agent_name] = agent_name
            registry["agent_mappings"][agent_name.replace("-", "_")] = agent_name
            registry["agent_mappings"][agent_name.replace("_", "-")] = agent_name

            # Add to categories
            category = metadata.get("category", "general")
            if category not in registry["categories"]:
                registry["categories"][category] = []
            registry["categories"][category].append(agent_name)

        # Save registry
        with open(self.registry_file, "w") as f:
            json.dump(registry, f, indent=2)

        print(f"✅ Built registry with {len(registry['custom_agents'])} agents")
        return registry

    def _parse_agent_file(self, agent_file: Path) -> Dict[str, Any]:
        """Parse agent markdown file for metadata"""
        metadata = {
            "name": agent_file.stem,
            "category": "general",
            "description": "",
            "tools": [],
        }

        try:
            content = agent_file.read_text()
            lines = content.split("\n")

            # Extract category from common patterns
            categories = {
                "constructor": "development",
                "patcher": "development",
                "testbed": "development",
                "linter": "development",
                "debugger": "development",
                "optimizer": "development",
                "security": "security",
                "database": "data",
                "web": "ui",
                "mobile": "ui",
                "tui": "ui",
                "director": "management",
                "apidesigner": "architecture",
                "deployer": "infrastructure",
                "monitor": "infrastructure",
            }

            for key, cat in categories.items():
                if key in agent_file.stem.lower():
                    metadata["category"] = cat
                    break

            # Extract description from first paragraph or header
            for line in lines[:20]:  # Check first 20 lines
                if line.startswith("#") and not line.startswith("##"):
                    metadata["description"] = line.strip("#").strip()
                    break

            # Extract tools if mentioned
            tool_keywords = ["tool", "uses", "requires", "dependencies"]
            for line in lines:
                if any(keyword in line.lower() for keyword in tool_keywords):
                    # Basic extraction - could be enhanced
                    if "git" in line.lower():
                        metadata["tools"].append("git")
                    if "docker" in line.lower():
                        metadata["tools"].append("docker")
                    if "python" in line.lower():
                        metadata["tools"].append("python")

        except Exception as e:
            print(f"Warning: Could not fully parse {agent_file.name}: {e}")

        return metadata

    def invoke_agent(
        self, agent_name: str, task: str, context: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """Invoke an agent through the registry"""

        # Resolve agent name
        agent_name = agent_name.lower()
        if agent_name in self.registry["agent_mappings"]:
            agent_name = self.registry["agent_mappings"][agent_name]

        if agent_name not in self.registry["custom_agents"]:
            return {
                "error": f"Agent '{agent_name}' not found",
                "available_agents": list(self.registry["custom_agents"].keys()),
                "categories": list(self.registry["categories"].keys()),
            }

        agent = self.registry["custom_agents"][agent_name]

        # Attempt to invoke through various methods
        result = None

        # Method 1: Try direct Python import if available
        if result is None:
            result = self._try_python_invocation(agent_name, task, context)

        # Method 2: Try subprocess invocation
        if result is None:
            result = self._try_subprocess_invocation(agent_name, task, context)

        # Method 3: Return agent info as fallback
        if result is None:
            result = {
                "agent": agent_name,
                "task": task,
                "status": "ready",
                "info": agent,
                "message": f"Agent {agent_name} is ready but requires manual invocation",
            }

        return result

    def _try_python_invocation(
        self, agent_name: str, task: str, context: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """Try to invoke agent through Python import"""
        try:
            # Check for cluster direct implementations
            if agent_name in [
                "constructor",
                "patcher",
                "testbed",
                "linter",
                "debugger",
            ]:
                from DEVELOPMENT_CLUSTER_DIRECT import invoke_development_agent

                return invoke_development_agent(agent_name, task, context)

            # Try to import agent module dynamically
            module_name = f"{agent_name}_agent"
            agent_module = __import__(module_name, fromlist=[agent_name])

            # Look for standard invocation methods
            if hasattr(agent_module, "invoke"):
                return agent_module.invoke(task, context)
            elif hasattr(agent_module, "run"):
                return agent_module.run(task, context)
            elif hasattr(agent_module, "execute"):
                return agent_module.execute(task, context)

        except ImportError:
            pass
        except Exception as e:
            return {"error": f"Python invocation failed: {e}"}

        return None

    def _try_subprocess_invocation(
        self, agent_name: str, task: str, context: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """Try to invoke agent through subprocess"""
        try:
            # Look for agent script
            agent_script = self.agents_dir / f"{agent_name}.py"
            if not agent_script.exists():
                agent_script = self.agents_dir / f"{agent_name}_agent.py"

            if agent_script.exists():
                cmd = [sys.executable, str(agent_script), "--task", task]
                if context:
                    cmd.extend(["--context", json.dumps(context)])

                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=str(self.project_root),
                )

                return {
                    "success": result.returncode == 0,
                    "output": result.stdout,
                    "error": result.stderr if result.returncode != 0 else None,
                    "agent": agent_name,
                }
        except subprocess.TimeoutExpired:
            return {"error": "Agent execution timed out"}
        except Exception as e:
            return {"error": f"Subprocess invocation failed: {e}"}

        return None

    def list_agents(self) -> List[Dict[str, Any]]:
        """List all available agents"""
        agents = []
        for name, info in self.registry["custom_agents"].items():
            agents.append(
                {
                    "name": name,
                    "category": info.get("category", "general"),
                    "description": info.get("description", ""),
                    "tools": info.get("tools", []),
                }
            )
        return sorted(agents, key=lambda x: (x["category"], x["name"]))

    def get_agents_by_category(self, category: str) -> List[str]:
        """Get agents in a specific category"""
        return self.registry["categories"].get(category, [])

    def refresh_registry(self) -> Dict[str, Any]:
        """Rebuild the registry from agent files"""
        self.registry = self._build_registry()
        return self.registry


# CLI interface
def main():
    """Command-line interface for the bridge"""
    import argparse

    parser = argparse.ArgumentParser(description="Claude Code Registry Bridge")
    parser.add_argument(
        "command",
        choices=["list", "invoke", "refresh", "info", "categories"],
        help="Command to execute",
    )
    parser.add_argument("--agent", help="Agent name for invoke/info commands")
    parser.add_argument("--task", help="Task for invoke command")
    parser.add_argument("--context", help="JSON context for invoke command")
    parser.add_argument("--category", help="Category for filtering")

    args = parser.parse_args()

    bridge = ClaudeRegistryBridge()

    if args.command == "list":
        agents = bridge.list_agents()
        if args.category:
            agents = [a for a in agents if a["category"] == args.category]

        print(f"Available Agents ({len(agents)}):")
        print("-" * 50)
        for agent in agents:
            print(f"• {agent['name']:<20} [{agent['category']}]")
            if agent["description"]:
                print(f"  {agent['description']}")

    elif args.command == "categories":
        print("Agent Categories:")
        print("-" * 50)
        for category, agents in bridge.registry["categories"].items():
            print(f"• {category:<20} ({len(agents)} agents)")
            for agent in agents[:5]:  # Show first 5
                print(f"  - {agent}")
            if len(agents) > 5:
                print(f"  ... and {len(agents) - 5} more")

    elif args.command == "invoke":
        if not args.agent or not args.task:
            print("Error: --agent and --task required for invoke")
            sys.exit(1)

        context = {}
        if args.context:
            try:
                context = json.loads(args.context)
            except json.JSONDecodeError:
                print("Error: Invalid JSON context")
                sys.exit(1)

        result = bridge.invoke_agent(args.agent, args.task, context)
        print(json.dumps(result, indent=2))

    elif args.command == "info":
        if not args.agent:
            print("Error: --agent required for info")
            sys.exit(1)

        agent_name = args.agent.lower()
        if agent_name in bridge.registry["agent_mappings"]:
            agent_name = bridge.registry["agent_mappings"][agent_name]

        if agent_name in bridge.registry["custom_agents"]:
            info = bridge.registry["custom_agents"][agent_name]
            print(f"Agent: {agent_name}")
            print("-" * 50)
            for key, value in info.items():
                print(f"{key:<15}: {value}")
        else:
            print(f"Agent '{args.agent}' not found")

    elif args.command == "refresh":
        print("Refreshing agent registry...")
        registry = bridge.refresh_registry()
        print(f"✅ Registry refreshed with {len(registry['custom_agents'])} agents")


if __name__ == "__main__":
    main()
