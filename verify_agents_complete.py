#!/usr/bin/env python3
"""
Comprehensive agent verification script for:
1. Task tool compatibility (Claude Code)
2. Tandem orchestration system integration
3. Binary system support with Python fallback
4. YAML frontmatter format
5. Agent naming standardization (CAPITALS)
"""

import os
import yaml
import re
from pathlib import Path
from typing import Dict, List, Tuple, Any
import json

class AgentVerifier:
    def __init__(self, agents_dir: str = "/home/ubuntu/Documents/Claude/agents"):
        self.agents_dir = Path(agents_dir)
        self.results = {}
        self.issues = []
        
    def verify_all_agents(self) -> Dict[str, Any]:
        """Verify all agents in the directory"""
        agent_files = list(self.agents_dir.glob("*.md"))
        
        # Filter out non-agent files
        excluded = {"Template.md", "README.md", "WHERE_I_AM.md", 
                   "STATUSLINE_INTEGRATION.md", "TEMPLATE.md"}
        agent_files = [f for f in agent_files if f.name not in excluded]
        
        print(f"Found {len(agent_files)} agent files to verify")
        print("-" * 80)
        
        for agent_file in sorted(agent_files):
            self.verify_agent(agent_file)
            
        return self.generate_report()
    
    def verify_agent(self, agent_file: Path) -> Dict[str, Any]:
        """Verify a single agent file"""
        agent_name = agent_file.stem
        print(f"Verifying {agent_name}...")
        
        result = {
            "name": agent_name,
            "file": str(agent_file),
            "checks": {
                "yaml_frontmatter": False,
                "task_tool": False,
                "tandem_execution": False,
                "binary_system": False,
                "python_fallback": False,
                "c_implementation": False,
                "name_capitalized": False,
                "communication_section": False,
                "fallback_patterns": False
            },
            "issues": []
        }
        
        try:
            content = agent_file.read_text()
            
            # Check 1: YAML frontmatter
            if content.startswith('---'):
                result["checks"]["yaml_frontmatter"] = True
                # Extract YAML
                parts = content.split('---', 2)
                if len(parts) >= 3:
                    try:
                        frontmatter = yaml.safe_load(parts[1])
                        result["metadata"] = frontmatter
                    except yaml.YAMLError as e:
                        result["issues"].append(f"YAML parse error: {e}")
            else:
                result["issues"].append("Missing YAML frontmatter")
            
            # Check 2: Task tool in tools list
            if re.search(r'tools:.*?[\s\-]+Task\b', content, re.DOTALL | re.IGNORECASE):
                result["checks"]["task_tool"] = True
            else:
                result["issues"].append("Task tool not found in tools list")
            
            # Check 3: Tandem execution support
            if 'tandem_execution:' in content:
                result["checks"]["tandem_execution"] = True
                # Check for execution modes
                if 'INTELLIGENT' in content and 'PYTHON_ONLY' in content:
                    result["has_execution_modes"] = True
            else:
                result["issues"].append("Missing tandem_execution configuration")
            
            # Check 4: Binary system integration
            if 'binary_protocol:' in content or 'binary_communications' in content:
                result["checks"]["binary_system"] = True
            else:
                result["issues"].append("Missing binary system integration")
            
            # Check 5: Python fallback implementation
            if 'python_implementation:' in content or 'fallback_strategy:' in content:
                result["checks"]["python_fallback"] = True
            else:
                result["issues"].append("Missing Python fallback implementation")
            
            # Check 6: C implementation reference
            if 'c_implementation:' in content or re.search(r'src/c/\w+_agent', content):
                result["checks"]["c_implementation"] = True
            else:
                result["issues"].append("Missing C implementation reference")
            
            # Check 7: Name capitalization
            if agent_name.isupper():
                result["checks"]["name_capitalized"] = True
            else:
                result["issues"].append(f"Agent name not capitalized: {agent_name}")
            
            # Check 8: Communication section
            if 'communication:' in content:
                result["checks"]["communication_section"] = True
            else:
                result["issues"].append("Missing communication section")
            
            # Check 9: Fallback patterns section
            if 'fallback_patterns:' in content:
                result["checks"]["fallback_patterns"] = True
            else:
                result["issues"].append("Missing fallback_patterns section")
            
            # Calculate compliance score
            passed = sum(1 for v in result["checks"].values() if v)
            total = len(result["checks"])
            result["compliance_score"] = f"{passed}/{total}"
            result["compliance_percentage"] = (passed / total) * 100
            
        except Exception as e:
            result["error"] = str(e)
            result["issues"].append(f"Error reading file: {e}")
        
        self.results[agent_name] = result
        
        # Print summary for this agent
        passed = sum(1 for v in result["checks"].values() if v)
        total = len(result["checks"])
        status = "✅" if passed == total else "⚠️" if passed >= total * 0.7 else "❌"
        print(f"  {status} {agent_name}: {passed}/{total} checks passed")
        
        if result["issues"] and passed < total:
            print(f"     Issues: {', '.join(result['issues'][:2])}")
        
        return result
    
    def generate_report(self) -> Dict[str, Any]:
        """Generate comprehensive report"""
        total_agents = len(self.results)
        fully_compliant = sum(1 for r in self.results.values() 
                             if all(r["checks"].values()))
        
        # Group by compliance level
        high_compliance = []  # 90-100%
        medium_compliance = []  # 70-89%
        low_compliance = []  # <70%
        
        for name, result in self.results.items():
            pct = result.get("compliance_percentage", 0)
            if pct >= 90:
                high_compliance.append(name)
            elif pct >= 70:
                medium_compliance.append(name)
            else:
                low_compliance.append(name)
        
        # Check specific requirements
        task_tool_count = sum(1 for r in self.results.values() 
                             if r["checks"]["task_tool"])
        tandem_count = sum(1 for r in self.results.values() 
                          if r["checks"]["tandem_execution"])
        fallback_count = sum(1 for r in self.results.values() 
                           if r["checks"]["python_fallback"])
        
        report = {
            "summary": {
                "total_agents": total_agents,
                "fully_compliant": fully_compliant,
                "high_compliance": len(high_compliance),
                "medium_compliance": len(medium_compliance),
                "low_compliance": len(low_compliance),
                "task_tool_ready": task_tool_count,
                "tandem_ready": tandem_count,
                "fallback_ready": fallback_count
            },
            "compliance_groups": {
                "high": high_compliance,
                "medium": medium_compliance,
                "low": low_compliance
            },
            "specific_issues": {
                "missing_task_tool": [],
                "missing_tandem": [],
                "missing_fallback": [],
                "not_capitalized": []
            },
            "agent_details": self.results
        }
        
        # Identify specific issues
        for name, result in self.results.items():
            if not result["checks"]["task_tool"]:
                report["specific_issues"]["missing_task_tool"].append(name)
            if not result["checks"]["tandem_execution"]:
                report["specific_issues"]["missing_tandem"].append(name)
            if not result["checks"]["python_fallback"]:
                report["specific_issues"]["missing_fallback"].append(name)
            if not result["checks"]["name_capitalized"]:
                report["specific_issues"]["not_capitalized"].append(name)
        
        return report
    
    def print_report(self, report: Dict[str, Any]):
        """Print formatted report"""
        print("\n" + "=" * 80)
        print("AGENT VERIFICATION REPORT")
        print("=" * 80)
        
        s = report["summary"]
        print(f"\nSummary:")
        print(f"  Total Agents: {s['total_agents']}")
        print(f"  Fully Compliant: {s['fully_compliant']} ({s['fully_compliant']/s['total_agents']*100:.1f}%)")
        print(f"  Task Tool Ready: {s['task_tool_ready']} ({s['task_tool_ready']/s['total_agents']*100:.1f}%)")
        print(f"  Tandem Ready: {s['tandem_ready']} ({s['tandem_ready']/s['total_agents']*100:.1f}%)")
        print(f"  Fallback Ready: {s['fallback_ready']} ({s['fallback_ready']/s['total_agents']*100:.1f}%)")
        
        print(f"\nCompliance Levels:")
        print(f"  High (90-100%): {s['high_compliance']} agents")
        print(f"  Medium (70-89%): {s['medium_compliance']} agents")
        print(f"  Low (<70%): {s['low_compliance']} agents")
        
        if report["specific_issues"]["missing_task_tool"]:
            print(f"\n⚠️ Missing Task Tool ({len(report['specific_issues']['missing_task_tool'])} agents):")
            for agent in report["specific_issues"]["missing_task_tool"][:5]:
                print(f"    - {agent}")
            if len(report["specific_issues"]["missing_task_tool"]) > 5:
                print(f"    ... and {len(report['specific_issues']['missing_task_tool']) - 5} more")
        
        if report["specific_issues"]["missing_tandem"]:
            print(f"\n⚠️ Missing Tandem Execution ({len(report['specific_issues']['missing_tandem'])} agents):")
            for agent in report["specific_issues"]["missing_tandem"][:5]:
                print(f"    - {agent}")
            if len(report["specific_issues"]["missing_tandem"]) > 5:
                print(f"    ... and {len(report['specific_issues']['missing_tandem']) - 5} more")
        
        if report["specific_issues"]["missing_fallback"]:
            print(f"\n⚠️ Missing Python Fallback ({len(report['specific_issues']['missing_fallback'])} agents):")
            for agent in report["specific_issues"]["missing_fallback"][:5]:
                print(f"    - {agent}")
            if len(report["specific_issues"]["missing_fallback"]) > 5:
                print(f"    ... and {len(report['specific_issues']['missing_fallback']) - 5} more")
        
        if report["compliance_groups"]["low"]:
            print(f"\n❌ Low Compliance Agents (need immediate attention):")
            for agent in report["compliance_groups"]["low"]:
                print(f"    - {agent}")
        
        print("\n" + "=" * 80)
        
        # Save detailed report
        report_file = Path("/home/ubuntu/Documents/Claude/agent_verification_report.json")
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        print(f"\nDetailed report saved to: {report_file}")

if __name__ == "__main__":
    verifier = AgentVerifier()
    report = verifier.verify_all_agents()
    verifier.print_report(report)
    
    # Return exit code based on compliance
    if report["summary"]["fully_compliant"] == report["summary"]["total_agents"]:
        print("\n✅ All agents are fully compliant!")
        exit(0)
    else:
        need_fixing = report["summary"]["total_agents"] - report["summary"]["fully_compliant"]
        print(f"\n⚠️ {need_fixing} agents need updates")
        exit(1)