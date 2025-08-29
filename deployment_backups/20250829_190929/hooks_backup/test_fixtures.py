#!/usr/bin/env python3
"""
Test Fixtures and Utilities for Claude Unified Hook System Tests
Provides reusable test data, mock objects, and utility functions
"""

import os
import sys
import json
import tempfile
import random
import string
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
import time

class TestFixtures:
    """Reusable test fixtures and test data generation"""
    
    @staticmethod
    def create_temp_project() -> Path:
        """Create comprehensive temporary project structure"""
        temp_dir = Path(tempfile.mkdtemp(prefix="claude_test_"))
        
        # Create project structure
        directories = [
            "agents", "config", "docs", ".shadowgit", "src", "tests",
            ".git", "database", "orchestration", "tools"
        ]
        
        for directory in directories:
            (temp_dir / directory).mkdir(exist_ok=True)
        
        # Create basic agents for testing
        TestFixtures._create_basic_test_agents(temp_dir / "agents")
        
        # Create project marker files
        project_files = {
            "CLAUDE.md": "# Test Project\nClaude agent framework test project.",
            "README.md": "# Test Project\nTest project for Claude hooks.",
            ".gitignore": "*.pyc\n__pycache__/\n.pytest_cache/",
            "requirements.txt": "pytest>=7.0.0\nasyncio\npsutil"
        }
        
        for filename, content in project_files.items():
            (temp_dir / filename).write_text(content)
        
        # Create configuration files
        config_files = {
            "config/hooks.json": json.dumps({
                "enabled": True,
                "max_agents": 10,
                "timeout": 30
            }, indent=2),
            "config/agents.json": json.dumps({
                "registry_path": "agents/",
                "auto_refresh": True
            }, indent=2)
        }
        
        for filepath, content in config_files.items():
            full_path = temp_dir / filepath
            full_path.parent.mkdir(exist_ok=True)
            full_path.write_text(content)
        
        return temp_dir
    
    @staticmethod
    def _create_basic_test_agents(agents_dir: Path):
        """Create basic test agents for standard testing"""
        basic_agents = {
            "DIRECTOR": {
                "description": "Strategic command and control agent",
                "category": "command_control",
                "patterns": ["direct", "coordinate", "orchestrate", "manage"],
                "invokes": ["PROJECTORCHESTRATOR", "SECURITY", "OPTIMIZER"]
            },
            "SECURITY": {
                "description": "Comprehensive security analysis agent",
                "category": "security", 
                "patterns": ["security", "audit", "vulnerability", "threat", "encrypt"],
                "invokes": ["MONITOR", "SECURITYAUDITOR"]
            },
            "OPTIMIZER": {
                "description": "Performance optimization specialist",
                "category": "development",
                "patterns": ["optimize", "performance", "speed", "efficiency"],
                "invokes": ["MONITOR", "TESTBED"]
            },
            "DEBUGGER": {
                "description": "Tactical failure analysis agent", 
                "category": "development",
                "patterns": ["debug", "error", "fix", "troubleshoot"],
                "invokes": ["TESTBED", "MONITOR"]
            },
            "TESTBED": {
                "description": "Elite test engineering agent",
                "category": "development", 
                "patterns": ["test", "validate", "verify", "qa", "quality"],
                "invokes": ["MONITOR"]
            },
            "MONITOR": {
                "description": "Observability and monitoring agent",
                "category": "infrastructure",
                "patterns": ["monitor", "observe", "track", "metrics"],
                "invokes": []
            },
            "DEPLOYER": {
                "description": "Deployment orchestration agent",
                "category": "infrastructure",
                "patterns": ["deploy", "release", "production", "rollout"],
                "invokes": ["MONITOR", "SECURITY"]
            },
            "ARCHITECT": {
                "description": "System design and architecture agent", 
                "category": "development",
                "patterns": ["architect", "design", "structure", "blueprint"],
                "invokes": ["SECURITY", "OPTIMIZER", "TESTBED"]
            }
        }
        
        for agent_name, agent_config in basic_agents.items():
            TestFixtures._create_agent_file(
                agents_dir, agent_name, agent_config
            )
    
    @staticmethod
    def _create_agent_file(agents_dir: Path, agent_name: str, config: Dict[str, Any]):
        """Create individual agent file with proper YAML frontmatter"""
        agent_file = agents_dir / f"{agent_name}.md"
        
        # Format proactive triggers
        triggers = '\n'.join(f'  - "{pattern}"' for pattern in config["patterns"])
        
        # Format invokes agents
        invokes = '\n'.join(f'  - "{agent}"' for agent in config["invokes"])
        
        agent_content = f"""---
name: {agent_name}
description: {config["description"]}
category: {config["category"]}
status: ACTIVE
tools: ["Task"]
proactive_triggers:
{triggers}
invokes_agents:
{invokes}
---

# {agent_name} Agent

{config["description"]}

## Capabilities

- Advanced {config["category"]} operations
- Pattern matching for: {', '.join(config["patterns"])}
- Coordinates with: {', '.join(config["invokes"]) if config["invokes"] else 'None'}

## Usage

Invoke {agent_name} for tasks requiring {config["category"]} expertise.
"""
        
        agent_file.write_text(agent_content)
    
    @staticmethod
    def generate_test_inputs(count: int) -> List[str]:
        """Generate diverse test inputs for pattern matching"""
        # Base realistic patterns
        base_patterns = [
            # Security patterns
            "audit the security vulnerabilities in the application",
            "perform penetration testing on API endpoints", 
            "encrypt sensitive customer data with AES-256",
            "check for SQL injection vulnerabilities",
            "implement two-factor authentication system",
            "analyze network traffic for suspicious activity",
            
            # Performance patterns  
            "optimize database query performance",
            "speed up application response times",
            "improve system latency and throughput",
            "cache frequently accessed data",
            "profile memory usage and garbage collection",
            "analyze CPU bottlenecks in production",
            
            # Development patterns
            "debug the critical production error",
            "test the new authentication feature",
            "architect a scalable microservices solution", 
            "deploy application to staging environment",
            "refactor legacy codebase for maintainability",
            "implement continuous integration pipeline",
            
            # Multi-agent coordination patterns
            "security audit with performance optimization",
            "deploy and monitor the new application version",
            "debug, fix, and test the payment processing bug",
            "architect, develop, and document the user management system",
            "comprehensive quality assurance with security review"
        ]
        
        # Generate additional synthetic patterns if needed
        patterns = base_patterns.copy()
        
        if count > len(base_patterns):
            additional_needed = count - len(base_patterns)
            
            # Generate synthetic patterns
            actions = ["analyze", "optimize", "debug", "test", "monitor", "secure", "deploy"]
            objects = ["system", "application", "database", "API", "network", "service", "component"]
            qualifiers = ["performance", "security", "reliability", "scalability", "maintainability"]
            
            for i in range(additional_needed):
                action = random.choice(actions)
                obj = random.choice(objects)
                qualifier = random.choice(qualifiers)
                
                synthetic_pattern = f"{action} {obj} {qualifier} with automated {random.choice(['testing', 'monitoring', 'analysis'])}"
                patterns.append(synthetic_pattern)
        
        return patterns[:count]
    
    @staticmethod
    def create_malicious_inputs() -> List[str]:
        """Generate malicious inputs for security testing"""
        return [
            # Path traversal attempts
            "../../../etc/passwd",
            "../../../../etc/shadow",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "/etc/passwd",
            "C:\\Windows\\System32\\config\\SAM",
            "\\\\server\\share\\sensitive\\file.txt",
            
            # Command injection attempts
            "; rm -rf /",
            "$(rm -rf /)",
            "`cat /etc/passwd`",
            "&& rm -rf /",
            "| cat /etc/shadow",
            "; powershell.exe -Command \"Get-Process\"",
            
            # SQL injection attempts
            "'; DROP TABLE users; --",
            "\" OR 1=1 --",
            "admin'; DELETE FROM passwords; --",
            "' UNION SELECT password FROM users --",
            
            # XSS attempts
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
            
            # Large input DoS
            "A" * 100000,
            "B" * 1000000,
            "x" * 10000 + "malicious payload",
            
            # Control characters and binary data
            "\x00\x01\x02\x03\x04\x05",
            "\x7f\x80\x81\x82",
            "\xff\xfe\xfd\xfc",
            
            # Format string attacks
            "%s%s%s%s%s%s%s%s%s%s",
            "%x%x%x%x%x%x%x%x%x%x",
            "{0}{1}{2}{3}{4}",
            
            # Unicode attacks  
            "\u202e\u202d",  # Right-to-left override
            "\ufeff\ufffe",  # Byte order marks
            "\u0000\u0001",  # Null bytes
            
            # JSON injection
            '{"malicious": "payload", "exec": "rm -rf /"}',
            '{"__proto__": {"admin": true}}',
            
            # XML/XXE injection
            "<?xml version=\"1.0\"?><!DOCTYPE root [<!ENTITY test SYSTEM 'file:///etc/passwd'>]><root>&test;</root>",
            
            # LDAP injection
            "admin)(&(password=*))",
            "*)(uid=*",
            
            # NoSQL injection
            "'; return {password: 1} //",
            "\" || 1==1 //",
        ]
    
    @staticmethod
    def create_performance_test_patterns(count: int = 1000) -> List[str]:
        """Generate patterns specifically for performance testing"""
        # Templates for generating many similar patterns
        templates = [
            "security audit {adjective} {system} with {method}",
            "optimize {component} performance for {metric}",
            "deploy {application} to {environment} with {monitoring}",
            "test {feature} functionality with {validation}",
            "monitor {service} {aspect} using {tool}",
            "debug {issue} in {location} affecting {impact}",
            "architect {solution} for {requirement} with {constraint}"
        ]
        
        # Word lists for template substitution
        adjectives = ["comprehensive", "detailed", "thorough", "complete", "advanced"]
        systems = ["application", "database", "network", "API", "service", "infrastructure"]
        methods = ["scanning", "analysis", "testing", "validation", "verification"]
        components = ["database", "cache", "API", "frontend", "backend", "middleware"]
        metrics = ["latency", "throughput", "response time", "memory usage", "CPU utilization"]
        environments = ["production", "staging", "development", "testing", "integration"]
        monitoring = ["logging", "metrics", "alerting", "tracing", "profiling"]
        features = ["authentication", "authorization", "payment", "search", "reporting"]
        validation = ["unit tests", "integration tests", "end-to-end tests", "load tests"]
        services = ["web server", "database", "cache", "queue", "scheduler"]
        aspects = ["performance", "availability", "reliability", "security", "scalability"]
        tools = ["prometheus", "grafana", "datadog", "newrelic", "elastic"]
        issues = ["memory leak", "deadlock", "race condition", "timeout", "crash"]
        locations = ["production", "staging", "user interface", "backend service", "database"]
        impacts = ["users", "performance", "availability", "data integrity", "security"]
        solutions = ["microservice", "monolith", "serverless", "container", "cloud"]
        requirements = ["scalability", "performance", "security", "reliability", "maintainability"]
        constraints = ["budget", "timeline", "resources", "compliance", "legacy systems"]
        
        # Word mapping for template substitution
        word_lists = {
            "adjective": adjectives,
            "system": systems,
            "method": methods,
            "component": components,
            "metric": metrics,
            "application": systems,
            "environment": environments,
            "monitoring": monitoring,
            "feature": features,
            "validation": validation,
            "service": services,
            "aspect": aspects,
            "tool": tools,
            "issue": issues,
            "location": locations,
            "impact": impacts,
            "solution": solutions,
            "requirement": requirements,
            "constraint": constraints
        }
        
        patterns = []
        
        for i in range(count):
            # Select random template
            template = random.choice(templates)
            
            # Replace placeholders with random words
            pattern = template
            for placeholder, word_list in word_lists.items():
                if f"{{{placeholder}}}" in pattern:
                    pattern = pattern.replace(f"{{{placeholder}}}", random.choice(word_list))
            
            patterns.append(pattern)
        
        return patterns
    
    @staticmethod
    def create_mock_agent_registry_data() -> Dict[str, Any]:
        """Create mock agent registry data for testing"""
        return {
            "agents": {
                "SECURITY": {
                    "name": "SECURITY", 
                    "description": "Security analysis agent",
                    "category": "security",
                    "status": "ACTIVE",
                    "patterns": ["security", "audit", "vulnerability"],
                    "tools": ["SecurityScanner", "Task"]
                },
                "OPTIMIZER": {
                    "name": "OPTIMIZER",
                    "description": "Performance optimization agent", 
                    "category": "development",
                    "status": "ACTIVE",
                    "patterns": ["optimize", "performance", "speed"],
                    "tools": ["Profiler", "Task"]
                },
                "MONITOR": {
                    "name": "MONITOR",
                    "description": "System monitoring agent",
                    "category": "infrastructure", 
                    "status": "ACTIVE",
                    "patterns": ["monitor", "observe", "track"],
                    "tools": ["MetricsCollector", "Task"]
                }
            },
            "metadata": {
                "last_updated": time.time(),
                "agent_count": 3,
                "version": "1.0"
            }
        }
    
    @staticmethod
    def create_mock_workflow_data() -> Dict[str, Any]:
        """Create mock workflow execution data"""
        return {
            "workflows": {
                "security_audit": {
                    "name": "Security Audit Workflow",
                    "agents": ["SECURITY", "SECURITYAUDITOR", "MONITOR"],
                    "execution_mode": "parallel",
                    "dependencies": {
                        "SECURITYAUDITOR": ["SECURITY"],
                        "MONITOR": ["SECURITY", "SECURITYAUDITOR"]
                    }
                },
                "performance_optimization": {
                    "name": "Performance Optimization Workflow",
                    "agents": ["OPTIMIZER", "MONITOR", "TESTBED"],
                    "execution_mode": "sequential", 
                    "dependencies": {
                        "MONITOR": ["OPTIMIZER"],
                        "TESTBED": ["OPTIMIZER", "MONITOR"]
                    }
                },
                "deployment": {
                    "name": "Deployment Workflow",
                    "agents": ["DEPLOYER", "SECURITY", "MONITOR"],
                    "execution_mode": "mixed",
                    "dependencies": {
                        "SECURITY": [],
                        "DEPLOYER": ["SECURITY"],
                        "MONITOR": ["DEPLOYER"]
                    }
                }
            }
        }
    
    @staticmethod  
    def generate_load_test_scenarios() -> List[Dict[str, Any]]:
        """Generate load test scenarios with different characteristics"""
        scenarios = [
            {
                "name": "burst_load",
                "description": "High-intensity burst of requests",
                "duration_seconds": 30,
                "requests_per_second": 50,
                "concurrent_clients": 10,
                "pattern_variety": "low"
            },
            {
                "name": "sustained_load", 
                "description": "Sustained moderate load",
                "duration_seconds": 120,
                "requests_per_second": 20,
                "concurrent_clients": 5,
                "pattern_variety": "medium"
            },
            {
                "name": "varied_load",
                "description": "Variable load with different patterns",
                "duration_seconds": 60,
                "requests_per_second": 30,
                "concurrent_clients": 8,
                "pattern_variety": "high"
            },
            {
                "name": "stress_test",
                "description": "High concurrency stress test", 
                "duration_seconds": 45,
                "requests_per_second": 100,
                "concurrent_clients": 20,
                "pattern_variety": "medium"
            }
        ]
        
        return scenarios
    
    @staticmethod
    def create_test_config_variations() -> List[Dict[str, Any]]:
        """Create different configuration variations for testing"""
        return [
            {
                "name": "minimal_config",
                "max_parallel_agents": 2,
                "cache_size": 10,
                "timeout": 5
            },
            {
                "name": "standard_config", 
                "max_parallel_agents": 8,
                "cache_size": 100,
                "timeout": 30
            },
            {
                "name": "high_performance_config",
                "max_parallel_agents": 16,
                "cache_size": 500,
                "timeout": 60
            },
            {
                "name": "memory_constrained_config",
                "max_parallel_agents": 4,
                "cache_size": 50,
                "timeout": 15
            }
        ]

@dataclass
class MockExecutionResult:
    """Mock execution result for testing"""
    success: bool = True
    agent: str = "TEST_AGENT"
    execution_time: float = 0.1
    output: str = "Mock execution completed"
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "success": self.success,
            "agent": self.agent,
            "execution_time": self.execution_time,
            "output": self.output,
            "error": self.error
        }

class MockTaskTool:
    """Mock Task tool for testing"""
    
    def __init__(self, should_fail: bool = False, delay: float = 0.1):
        self.should_fail = should_fail
        self.delay = delay
        self.call_count = 0
    
    async def execute(self, agent: str, prompt: str) -> MockExecutionResult:
        """Mock task execution"""
        self.call_count += 1
        
        if self.delay > 0:
            import asyncio
            await asyncio.sleep(self.delay)
        
        if self.should_fail:
            return MockExecutionResult(
                success=False,
                agent=agent,
                execution_time=self.delay,
                error="Mock execution failed"
            )
        
        return MockExecutionResult(
            success=True,
            agent=agent,
            execution_time=self.delay,
            output=f"Mock execution for {agent}: {prompt[:50]}..."
        )

class TestDataGenerator:
    """Advanced test data generation utilities"""
    
    @staticmethod
    def generate_agent_interaction_matrix(agents: List[str]) -> Dict[str, List[str]]:
        """Generate agent interaction patterns for testing"""
        interactions = {}
        
        for agent in agents:
            # Generate realistic interaction patterns
            if "DIRECTOR" in agent:
                # Directors coordinate with many agents
                interactions[agent] = random.sample(agents, min(len(agents) - 1, 5))
            elif "SECURITY" in agent:
                # Security agents often work with monitors and auditors  
                potential = [a for a in agents if "MONITOR" in a or "AUDIT" in a or "TEST" in a]
                interactions[agent] = potential[:3]
            elif "MONITOR" in agent:
                # Monitors often work independently
                interactions[agent] = []
            else:
                # Other agents have moderate interactions
                interactions[agent] = random.sample(agents, min(len(agents) - 1, 2))
        
        return interactions
    
    @staticmethod
    def generate_realistic_timing_data(base_time: float, variance: float, count: int) -> List[float]:
        """Generate realistic timing data with proper distribution"""
        import random
        
        timings = []
        for _ in range(count):
            # Generate log-normal distribution for realistic timing
            variation = random.lognormvariate(0, variance)
            timing = base_time * variation
            timings.append(max(0.001, timing))  # Ensure positive timing
        
        return timings
    
    @staticmethod
    def create_stress_test_inputs(complexity_level: str = "medium") -> List[str]:
        """Create inputs specifically designed for stress testing"""
        if complexity_level == "low":
            base_patterns = ["test", "check", "run", "analyze"] * 50
        elif complexity_level == "medium":
            base_patterns = [
                f"analyze {item} performance with {method}"
                for item in ["database", "API", "service", "application", "system"] 
                for method in ["monitoring", "profiling", "testing", "optimization"]
            ]
        else:  # high complexity
            base_patterns = [
                f"comprehensive {action} of {system} including {aspect1}, {aspect2}, and {aspect3} with {tool} integration"
                for action in ["analysis", "optimization", "testing", "monitoring"]
                for system in ["microservice architecture", "distributed database", "cloud infrastructure"]
                for aspect1 in ["security", "performance", "reliability"]
                for aspect2 in ["scalability", "maintainability", "observability"] 
                for aspect3 in ["compliance", "efficiency", "resilience"]
                for tool in ["automated testing", "continuous monitoring", "AI-driven analysis"]
            ][:200]  # Limit to reasonable size
        
        return base_patterns