#!/usr/bin/env python3
"""
TESTBED Agent - Comprehensive Portability Validation Suite
Tests that ALL claude-backups systems are path-agnostic and portable
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


class PortabilityValidator:
    def __init__(self):
        self.results = []
        self.current_dir = Path.cwd()
        self.test_environments = []

    def log(self, message: str, level: str = "INFO"):
        """Log validation messages"""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        self.results.append(
            {"timestamp": timestamp, "level": level, "message": message}
        )

    def create_test_environments(self) -> List[Dict]:
        """Create multiple test environments with different users and paths"""
        environments = [
            {
                "name": "alice_home",
                "base_path": "/tmp/test_alice_home",
                "user": "alice",
                "project_path": "/tmp/test_alice_home/claude-backups",
            },
            {
                "name": "bob_opt",
                "base_path": "/tmp/test_bob_opt",
                "user": "bob",
                "project_path": "/tmp/test_bob_opt/opt/claude",
            },
            {
                "name": "system_usr",
                "base_path": "/tmp/test_system",
                "user": "system",
                "project_path": "/tmp/test_system/usr/local/claude-backups",
            },
            {
                "name": "deep_nested",
                "base_path": "/tmp/test_deep",
                "user": "testuser",
                "project_path": "/tmp/test_deep/very/deep/nested/path/claude-backups",
            },
        ]

        for env in environments:
            try:
                # Create environment directory structure
                os.makedirs(env["project_path"], exist_ok=True)
                os.makedirs(os.path.dirname(env["project_path"]), exist_ok=True)

                # Copy project to test location
                if os.path.exists(env["project_path"]):
                    shutil.rmtree(env["project_path"])
                shutil.copytree(str(self.current_dir), env["project_path"])

                self.log(
                    f"Created test environment: {env['name']} at {env['project_path']}"
                )

            except Exception as e:
                self.log(f"Failed to create environment {env['name']}: {e}", "ERROR")
                continue

        return environments

    def test_wrapper_portability(self, env: Dict) -> bool:
        """Test claude-wrapper-ultimate.sh portability"""
        self.log(f"Testing wrapper portability in {env['name']}")

        wrapper_path = os.path.join(env["project_path"], "claude-wrapper-ultimate.sh")
        if not os.path.exists(wrapper_path):
            self.log(f"Wrapper not found at {wrapper_path}", "ERROR")
            return False

        try:
            # Test wrapper help command
            result = subprocess.run(
                ["bash", wrapper_path, "--help"],
                cwd=env["project_path"],
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode == 0:
                self.log(f"✅ Wrapper help works in {env['name']}")

                # Check for hardcoded paths in output
                if "/home/john" in result.stdout or "/home/ubuntu" in result.stdout:
                    self.log(f"⚠️  Found hardcoded paths in wrapper output", "WARNING")
                    return False

                return True
            else:
                self.log(
                    f"❌ Wrapper failed in {env['name']}: {result.stderr}", "ERROR"
                )
                return False

        except Exception as e:
            self.log(f"❌ Wrapper test exception in {env['name']}: {e}", "ERROR")
            return False

    def test_installer_portability(self, env: Dict) -> bool:
        """Test installation scripts portability"""
        self.log(f"Testing installer portability in {env['name']}")

        installers = ["claude-installer.sh", "claude-enhanced-installer.py"]

        results = []
        for installer in installers:
            installer_path = os.path.join(env["project_path"], installer)
            if not os.path.exists(installer_path):
                self.log(f"Installer {installer} not found", "WARNING")
                continue

            try:
                # Test dry-run mode
                if installer.endswith(".py"):
                    cmd = ["python3", installer_path, "--detect-only"]
                else:
                    cmd = ["bash", installer_path, "--dry-run"]

                result = subprocess.run(
                    cmd,
                    cwd=env["project_path"],
                    capture_output=True,
                    text=True,
                    timeout=60,
                )

                if result.returncode == 0:
                    self.log(f"✅ {installer} dry-run works in {env['name']}")

                    # Check for hardcoded paths
                    output = result.stdout + result.stderr
                    hardcoded_patterns = [
                        r"/home/john",
                        r"/home/ubuntu",
                        r"/home/\w+/claude-backups",
                        r"HOME=/home/\w+",
                    ]

                    for pattern in hardcoded_patterns:
                        if re.search(pattern, output):
                            self.log(
                                f"⚠️  Found hardcoded path pattern '{pattern}' in {installer}",
                                "WARNING",
                            )
                            results.append(False)
                            break
                    else:
                        results.append(True)
                else:
                    self.log(f"❌ {installer} failed: {result.stderr}", "ERROR")
                    results.append(False)

            except Exception as e:
                self.log(f"❌ {installer} test exception: {e}", "ERROR")
                results.append(False)

        return all(results) if results else False

    def test_agent_loading(self, env: Dict) -> bool:
        """Test agent files load with portable paths"""
        self.log(f"Testing agent loading in {env['name']}")

        agents_dir = os.path.join(env["project_path"], "agents")
        if not os.path.exists(agents_dir):
            self.log(f"Agents directory not found at {agents_dir}", "ERROR")
            return False

        try:
            # Test agent discovery
            agent_files = list(Path(agents_dir).glob("*.md"))
            if len(agent_files) < 10:
                self.log(f"Too few agent files found: {len(agent_files)}", "ERROR")
                return False

            self.log(f"Found {len(agent_files)} agent files")

            # Test a few key agents for path issues
            key_agents = ["DIRECTOR.md", "ARCHITECT.md", "SECURITY.md"]
            for agent_name in key_agents:
                agent_path = os.path.join(agents_dir, agent_name)
                if os.path.exists(agent_path):
                    with open(agent_path, "r") as f:
                        content = f.read()

                    # Check for hardcoded paths
                    if "/home/john" in content or "/home/ubuntu" in content:
                        self.log(f"⚠️  Hardcoded paths found in {agent_name}", "WARNING")
                        return False

            self.log(f"✅ Agent files are path-agnostic in {env['name']}")
            return True

        except Exception as e:
            self.log(f"❌ Agent loading test exception: {e}", "ERROR")
            return False

    def test_python_scripts(self, env: Dict) -> bool:
        """Test Python scripts use dynamic path resolution"""
        self.log(f"Testing Python scripts in {env['name']}")

        python_scripts = [
            "agents/src/python/production_orchestrator.py",
            "agents/src/python/agent_registry.py",
            "integrated_learning_setup.py",
        ]

        results = []
        for script_rel in python_scripts:
            script_path = os.path.join(env["project_path"], script_rel)
            if not os.path.exists(script_path):
                self.log(f"Python script not found: {script_rel}", "WARNING")
                continue

            try:
                # Read script content
                with open(script_path, "r") as f:
                    content = f.read()

                # Check for hardcoded paths
                hardcoded_patterns = [
                    r"/home/john",
                    r"/home/ubuntu",
                    r'HOME\s*=\s*["\'][^"\']*john',
                    r'HOME\s*=\s*["\'][^"\']*ubuntu',
                ]

                path_issues = []
                for pattern in hardcoded_patterns:
                    matches = re.findall(pattern, content)
                    if matches:
                        path_issues.extend(matches)

                if path_issues:
                    self.log(
                        f"⚠️  Hardcoded paths in {script_rel}: {path_issues}", "WARNING"
                    )
                    results.append(False)
                else:
                    self.log(f"✅ {script_rel} is path-agnostic")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {script_rel}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else False

    def test_documentation_portability(self, env: Dict) -> bool:
        """Test documentation examples are portable"""
        self.log(f"Testing documentation portability in {env['name']}")

        doc_files = ["README.md", "CLAUDE.md", "INSTALL.md"]

        results = []
        for doc_file in doc_files:
            doc_path = os.path.join(env["project_path"], doc_file)
            if not os.path.exists(doc_path):
                continue

            try:
                with open(doc_path, "r") as f:
                    content = f.read()

                # Check for hardcoded user paths in examples
                hardcoded_examples = re.findall(
                    r"/home/(?:john|ubuntu)/[^\s\)]*", content
                )
                if hardcoded_examples:
                    self.log(
                        f"⚠️  Hardcoded examples in {doc_file}: {len(hardcoded_examples)} found",
                        "WARNING",
                    )
                    results.append(False)
                else:
                    self.log(f"✅ {doc_file} examples are portable")
                    results.append(True)

            except Exception as e:
                self.log(f"❌ Error checking {doc_file}: {e}", "ERROR")
                results.append(False)

        return all(results) if results else True  # True if no docs found

    def test_end_to_end_functionality(self, env: Dict) -> bool:
        """Test end-to-end system functionality"""
        self.log(f"Testing end-to-end functionality in {env['name']}")

        try:
            # Test basic wrapper functionality
            wrapper_path = os.path.join(
                env["project_path"], "claude-wrapper-ultimate.sh"
            )

            # Test status command
            result = subprocess.run(
                ["bash", wrapper_path, "--status"],
                cwd=env["project_path"],
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode == 0:
                self.log(f"✅ End-to-end status check works in {env['name']}")

                # Test agent listing
                result2 = subprocess.run(
                    ["bash", wrapper_path, "--agents"],
                    cwd=env["project_path"],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )

                if result2.returncode == 0 and "DIRECTOR" in result2.stdout:
                    self.log(f"✅ Agent listing works in {env['name']}")
                    return True
                else:
                    self.log(f"❌ Agent listing failed in {env['name']}", "ERROR")
                    return False
            else:
                self.log(
                    f"❌ Status check failed in {env['name']}: {result.stderr}", "ERROR"
                )
                return False

        except Exception as e:
            self.log(f"❌ End-to-end test exception in {env['name']}: {e}", "ERROR")
            return False

    def cleanup_test_environments(self, environments: List[Dict]):
        """Clean up test environments"""
        self.log("Cleaning up test environments")

        for env in environments:
            try:
                if os.path.exists(env["base_path"]):
                    shutil.rmtree(env["base_path"])
                    self.log(f"Cleaned up {env['name']}")
            except Exception as e:
                self.log(f"Failed to cleanup {env['name']}: {e}", "WARNING")

    def run_comprehensive_validation(self) -> Dict:
        """Run complete portability validation suite"""
        self.log("🚀 Starting Comprehensive Portability Validation")
        self.log("=" * 60)

        # Create test environments
        environments = self.create_test_environments()
        if not environments:
            return {"success": False, "error": "Failed to create test environments"}

        validation_results = {}

        for env in environments:
            self.log(f"\n🔍 Testing environment: {env['name']}")
            self.log("-" * 40)

            env_results = {
                "wrapper_portability": self.test_wrapper_portability(env),
                "installer_portability": self.test_installer_portability(env),
                "agent_loading": self.test_agent_loading(env),
                "python_scripts": self.test_python_scripts(env),
                "documentation": self.test_documentation_portability(env),
                "end_to_end": self.test_end_to_end_functionality(env),
            }

            validation_results[env["name"]] = env_results

            # Calculate environment score
            passed = sum(1 for result in env_results.values() if result)
            total = len(env_results)
            score = (passed / total) * 100

            self.log(
                f"📊 {env['name']} Score: {score:.1f}% ({passed}/{total} tests passed)"
            )

        # Clean up
        self.cleanup_test_environments(environments)

        # Calculate overall results
        return self.generate_final_report(validation_results)

    def generate_final_report(self, validation_results: Dict) -> Dict:
        """Generate comprehensive validation report"""
        self.log("\n" + "=" * 60)
        self.log("📋 COMPREHENSIVE PORTABILITY VALIDATION REPORT")
        self.log("=" * 60)

        total_tests = 0
        total_passed = 0
        environment_scores = {}

        for env_name, results in validation_results.items():
            passed = sum(1 for result in results.values() if result)
            total = len(results)
            score = (passed / total) * 100

            environment_scores[env_name] = score
            total_tests += total
            total_passed += passed

            status = (
                "✅ PASS" if score >= 80 else "⚠️  PARTIAL" if score >= 60 else "❌ FAIL"
            )
            self.log(f"{env_name:15} | {score:5.1f}% | {status}")

        overall_score = (total_passed / total_tests) * 100 if total_tests > 0 else 0

        self.log("-" * 60)
        self.log(
            f"OVERALL SCORE: {overall_score:.1f}% ({total_passed}/{total_tests} tests passed)"
        )

        # Determine system status
        if overall_score >= 90:
            status = "🟢 FULLY PORTABLE"
            message = "System is comprehensively portable across all test environments"
        elif overall_score >= 75:
            status = "🟡 MOSTLY PORTABLE"
            message = "System is mostly portable with minor issues to address"
        else:
            status = "🔴 PORTABILITY ISSUES"
            message = "System has significant portability issues that need attention"

        self.log(f"STATUS: {status}")
        self.log(f"ASSESSMENT: {message}")

        # Generate recommendations
        recommendations = self.generate_recommendations(validation_results)

        if recommendations:
            self.log("\n🔧 RECOMMENDATIONS:")
            for rec in recommendations:
                self.log(f"  • {rec}")

        self.log("\n✅ Validation complete!")

        return {
            "success": True,
            "overall_score": overall_score,
            "status": status,
            "message": message,
            "environment_scores": environment_scores,
            "detailed_results": validation_results,
            "recommendations": recommendations,
            "total_tests": total_tests,
            "total_passed": total_passed,
        }

    def generate_recommendations(self, validation_results: Dict) -> List[str]:
        """Generate specific recommendations based on validation results"""
        recommendations = []

        # Analyze common failure patterns
        wrapper_failures = sum(
            1
            for results in validation_results.values()
            if not results.get("wrapper_portability", True)
        )
        installer_failures = sum(
            1
            for results in validation_results.values()
            if not results.get("installer_portability", True)
        )
        python_failures = sum(
            1
            for results in validation_results.values()
            if not results.get("python_scripts", True)
        )
        doc_failures = sum(
            1
            for results in validation_results.values()
            if not results.get("documentation", True)
        )

        total_envs = len(validation_results)

        if wrapper_failures > 0:
            recommendations.append(
                f"Wrapper portability failed in {wrapper_failures}/{total_envs} environments - review claude-wrapper-ultimate.sh for hardcoded paths"
            )

        if installer_failures > 0:
            recommendations.append(
                f"Installer portability failed in {installer_failures}/{total_envs} environments - review installation scripts for path assumptions"
            )

        if python_failures > 0:
            recommendations.append(
                f"Python script portability failed in {python_failures}/{total_envs} environments - use __file__ and pathlib for dynamic path resolution"
            )

        if doc_failures > 0:
            recommendations.append(
                f"Documentation portability failed in {doc_failures}/{total_envs} environments - update examples to use placeholder paths like $HOME or /path/to/project"
            )

        return recommendations


def main():
    """Main validation entry point"""
    print("🧪 TESTBED Agent - Comprehensive Portability Validation")
    print("Testing claude-backups system portability across multiple environments\n")

    validator = PortabilityValidator()

    try:
        results = validator.run_comprehensive_validation()

        # Save detailed results
        results_file = "/tmp/portability_validation_results.json"
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
