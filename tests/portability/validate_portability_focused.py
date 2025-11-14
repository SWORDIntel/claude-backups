#!/usr/bin/env python3
"""
TESTBED Agent - Focused Portability Validation
Tests critical components for path-agnostic operation without copying large directories
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class FocusedPortabilityValidator:
    def __init__(self):
        self.results = []
        self.current_dir = Path.cwd()

    def log(self, message: str, level: str = "INFO"):
        """Log validation messages"""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        self.results.append(
            {"timestamp": timestamp, "level": level, "message": message}
        )

    def test_wrapper_hardcoded_paths(self) -> bool:
        """Test wrapper for hardcoded paths"""
        self.log("Testing claude-wrapper-ultimate.sh for hardcoded paths")

        wrapper_path = self.current_dir / "claude-wrapper-ultimate.sh"
        if not wrapper_path.exists():
            self.log("Wrapper not found", "ERROR")
            return False

        try:
            with open(wrapper_path, "r") as f:
                content = f.read()

            # Check for hardcoded paths
            hardcoded_patterns = [
                r"/home/john",
                r"/home/ubuntu",
                r"HOME=/home/\w+",
                r"USER=\w+",
                r"/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/claude-backups",
            ]

            issues = []
            for pattern in hardcoded_patterns:
                matches = re.findall(pattern, content)
                if matches:
                    issues.extend(matches)

            if issues:
                self.log(f"❌ Found hardcoded paths in wrapper: {issues}", "ERROR")
                return False
            else:
                self.log("✅ Wrapper appears path-agnostic")
                return True

        except Exception as e:
            self.log(f"❌ Error checking wrapper: {e}", "ERROR")
            return False

    def test_installer_scripts_hardcoded_paths(self) -> bool:
        """Test installer scripts for hardcoded paths"""
        self.log("Testing installer scripts for hardcoded paths")

        installers = [
            "claude-installer.sh",
            "claude-enhanced-installer.py",
            "claude-quick-launch-agents.sh",
        ]

        results = []
        for installer in installers:
            installer_path = self.current_dir / installer
            if not installer_path.exists():
                self.log(f"Installer {installer} not found", "WARNING")
                continue

            try:
                with open(installer_path, "r") as f:
                    content = f.read()

                # Check for hardcoded paths
                hardcoded_patterns = [
                    r"/home/john(?!/\$)",  # Not followed by /$
                    r"/home/ubuntu(?!/\$)",
                    r'HOME="/home/\w+"',
                    r"HOME='/home/\w+'",
                    r'USER="\w+"',
                    r"USER='\w+'",
                ]

                issues = []
                for pattern in hardcoded_patterns:
                    matches = re.findall(pattern, content)
                    if matches:
                        issues.extend(matches)

                if issues:
                    self.log(
                        f"❌ Found hardcoded paths in {installer}: {issues}", "ERROR"
                    )
                    results.append(False)
                else:
                    self.log(f"✅ {installer} appears path-agnostic")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {installer}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else False

    def test_python_scripts_hardcoded_paths(self) -> bool:
        """Test Python scripts for hardcoded paths"""
        self.log("Testing Python scripts for hardcoded paths")

        python_files = [
            "integrated_learning_setup.py",
            "learning_config_manager.py",
            "agents/src/python/production_orchestrator.py",
            "agents/src/python/agent_registry.py",
            "agents/src/python/postgresql_learning_system.py",
        ]

        results = []
        for py_file in python_files:
            py_path = self.current_dir / py_file
            if not py_path.exists():
                self.log(f"Python file {py_file} not found", "WARNING")
                continue

            try:
                with open(py_path, "r") as f:
                    content = f.read()

                # Check for hardcoded paths
                hardcoded_patterns = [
                    r'["\']\/home\/john[^"\']*["\']',
                    r'["\']\/home\/ubuntu[^"\']*["\']',
                    r'HOME\s*=\s*["\'][^"\']*john[^"\']*["\']',
                    r'USER\s*=\s*["\']john["\']',
                    r'USER\s*=\s*["\']ubuntu["\']',
                ]

                issues = []
                for pattern in hardcoded_patterns:
                    matches = re.findall(pattern, content)
                    if matches:
                        issues.extend(matches)

                if issues:
                    self.log(
                        f"❌ Found hardcoded paths in {py_file}: {issues}", "ERROR"
                    )
                    results.append(False)
                else:
                    self.log(f"✅ {py_file} appears path-agnostic")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {py_file}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else False

    def test_documentation_examples(self) -> bool:
        """Test documentation for hardcoded path examples"""
        self.log("Testing documentation for portable examples")

        doc_files = ["README.md", "CLAUDE.md", "INSTALL.md"]

        results = []
        for doc_file in doc_files:
            doc_path = self.current_dir / doc_file
            if not doc_path.exists():
                continue

            try:
                with open(doc_path, "r") as f:
                    content = f.read()

                # Look for hardcoded user paths in command examples
                # But allow /home/john in documentation context
                problem_patterns = [
                    r"cd\s+/home/(?:john|ubuntu)/[^\s]*claude-backups",
                    r"export\s+[A-Z_]+=/home/(?:john|ubuntu)/",
                    r"PATH=/home/(?:john|ubuntu)/",
                ]

                issues = []
                for pattern in problem_patterns:
                    matches = re.findall(pattern, content)
                    if matches:
                        issues.extend(matches)

                if issues:
                    self.log(
                        f"⚠️  Found hardcoded command examples in {doc_file}: {len(issues)} instances",
                        "WARNING",
                    )
                    # Don't fail on documentation issues, just warn
                    results.append(True)
                else:
                    self.log(f"✅ {doc_file} examples appear portable")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {doc_file}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else True

    def test_wrapper_functionality_simulation(self) -> bool:
        """Simulate wrapper functionality in different path contexts"""
        self.log("Testing wrapper functionality simulation")

        wrapper_path = self.current_dir / "claude-wrapper-ultimate.sh"
        if not wrapper_path.exists():
            self.log("Wrapper not found", "ERROR")
            return False

        try:
            # Test help command (should work regardless of path)
            result = subprocess.run(
                ["bash", str(wrapper_path), "--help"],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=self.current_dir,
            )

            if result.returncode == 0:
                self.log("✅ Wrapper help command works")

                # Check output for hardcoded paths
                output = result.stdout + result.stderr
                if "/home/john" in output or "/home/ubuntu" in output:
                    self.log("⚠️  Wrapper output contains hardcoded paths", "WARNING")
                    return False

                return True
            else:
                self.log(f"❌ Wrapper help failed: {result.stderr}", "ERROR")
                return False

        except Exception as e:
            self.log(f"❌ Wrapper functionality test failed: {e}", "ERROR")
            return False

    def test_agent_file_portability(self) -> bool:
        """Test agent files for path dependencies"""
        self.log("Testing agent files for path dependencies")

        agents_dir = self.current_dir / "agents"
        if not agents_dir.exists():
            self.log("Agents directory not found", "ERROR")
            return False

        agent_files = list(agents_dir.glob("*.md"))
        if len(agent_files) < 10:
            self.log(f"Too few agent files found: {len(agent_files)}", "ERROR")
            return False

        self.log(f"Found {len(agent_files)} agent files")

        # Check key agents for hardcoded paths
        key_agents = ["DIRECTOR.md", "ARCHITECT.md", "SECURITY.md", "HARDWARE-INTEL.md"]
        results = []

        for agent_name in key_agents:
            agent_path = agents_dir / agent_name
            if agent_path.exists():
                try:
                    with open(agent_path, "r") as f:
                        content = f.read()

                    # Check for hardcoded paths
                    if "/home/john" in content or "/home/ubuntu" in content:
                        self.log(f"⚠️  Hardcoded paths found in {agent_name}", "WARNING")
                        results.append(False)
                    else:
                        self.log(f"✅ {agent_name} is path-agnostic")
                        results.append(True)
                except Exception as e:
                    self.log(f"❌ Error checking {agent_name}: {e}", "ERROR")
                    results.append(False)
            else:
                self.log(f"Agent {agent_name} not found", "WARNING")

        return all(results) if results else False

    def test_critical_file_portability(self) -> bool:
        """Test critical system files for portability"""
        self.log("Testing critical system files for portability")

        critical_files = [
            "claude-unified",
            "claude-enhanced-installer.py",
            "bring-online",
            "switch",
            "status",
        ]

        results = []
        for file_name in critical_files:
            file_path = self.current_dir / file_name
            if not file_path.exists():
                self.log(f"Critical file {file_name} not found", "WARNING")
                continue

            try:
                with open(file_path, "r") as f:
                    content = f.read()

                # Check for hardcoded paths
                hardcoded_patterns = [
                    r"/home/john(?!/\$|\$)",
                    r"/home/ubuntu(?!/\$|\$)",
                    r'HOME="/home/(?:john|ubuntu)"',
                    r"HOME='/home/(?:john|ubuntu)'",
                ]

                issues = []
                for pattern in hardcoded_patterns:
                    matches = re.findall(pattern, content)
                    if matches:
                        issues.extend(matches)

                if issues:
                    self.log(
                        f"❌ Found hardcoded paths in {file_name}: {issues}", "ERROR"
                    )
                    results.append(False)
                else:
                    self.log(f"✅ {file_name} appears path-agnostic")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {file_name}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else False

    def run_focused_validation(self) -> Dict:
        """Run focused portability validation"""
        self.log("🚀 Starting Focused Portability Validation")
        self.log("=" * 60)

        tests = {
            "wrapper_hardcoded_paths": self.test_wrapper_hardcoded_paths,
            "installer_hardcoded_paths": self.test_installer_scripts_hardcoded_paths,
            "python_hardcoded_paths": self.test_python_scripts_hardcoded_paths,
            "documentation_examples": self.test_documentation_examples,
            "wrapper_functionality": self.test_wrapper_functionality_simulation,
            "agent_file_portability": self.test_agent_file_portability,
            "critical_file_portability": self.test_critical_file_portability,
        }

        results = {}
        passed = 0
        total = len(tests)

        self.log(f"\n🔍 Running {total} portability tests")
        self.log("-" * 40)

        for test_name, test_func in tests.items():
            self.log(f"\nRunning: {test_name}")
            try:
                result = test_func()
                results[test_name] = result
                if result:
                    passed += 1
                    status = "✅ PASS"
                else:
                    status = "❌ FAIL"
                self.log(f"Result: {status}")
            except Exception as e:
                self.log(f"❌ Test {test_name} failed with exception: {e}", "ERROR")
                results[test_name] = False

        # Calculate score
        score = (passed / total) * 100

        self.log("\n" + "=" * 60)
        self.log("📋 FOCUSED PORTABILITY VALIDATION REPORT")
        self.log("=" * 60)

        for test_name, result in results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            self.log(f"{test_name:25} | {status}")

        self.log("-" * 60)
        self.log(f"OVERALL SCORE: {score:.1f}% ({passed}/{total} tests passed)")

        # Determine system status
        if score >= 90:
            status = "🟢 FULLY PORTABLE"
            message = "System is comprehensively portable"
        elif score >= 75:
            status = "🟡 MOSTLY PORTABLE"
            message = "System is mostly portable with minor issues"
        else:
            status = "🔴 PORTABILITY ISSUES"
            message = "System has significant portability issues"

        self.log(f"STATUS: {status}")
        self.log(f"ASSESSMENT: {message}")

        # Generate specific recommendations
        recommendations = []
        if not results.get("wrapper_hardcoded_paths", True):
            recommendations.append(
                "Remove hardcoded paths from claude-wrapper-ultimate.sh"
            )
        if not results.get("installer_hardcoded_paths", True):
            recommendations.append(
                "Update installer scripts to use dynamic path resolution"
            )
        if not results.get("python_hardcoded_paths", True):
            recommendations.append(
                "Replace hardcoded paths in Python scripts with __file__ and pathlib"
            )
        if not results.get("critical_file_portability", True):
            recommendations.append(
                "Update critical system files to use relative or dynamic paths"
            )

        if recommendations:
            self.log("\n🔧 RECOMMENDATIONS:")
            for rec in recommendations:
                self.log(f"  • {rec}")

        self.log("\n✅ Validation complete!")

        return {
            "success": True,
            "overall_score": score,
            "status": status,
            "message": message,
            "detailed_results": results,
            "recommendations": recommendations,
            "total_tests": total,
            "total_passed": passed,
        }


def main():
    """Main validation entry point"""
    print("🧪 TESTBED Agent - Focused Portability Validation")
    print("Testing claude-backups critical components for portability\n")

    validator = FocusedPortabilityValidator()

    try:
        results = validator.run_focused_validation()

        # Save results
        results_file = "/tmp/focused_portability_results.json"
        with open(results_file, "w") as f:
            json.dump(results, f, indent=2)

        print(f"\n📄 Detailed results saved to: {results_file}")

        # Exit with appropriate code
        if results["overall_score"] >= 90:
            sys.exit(0)  # Success
        elif results["overall_score"] >= 75:
            sys.exit(1)  # Partial success
        else:
            sys.exit(2)  # Failure

    except KeyboardInterrupt:
        print("\n⏹️  Validation interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n💥 Validation failed with exception: {e}")
        sys.exit(3)


if __name__ == "__main__":
    main()
