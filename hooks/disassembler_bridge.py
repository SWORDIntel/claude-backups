#!/usr/bin/env python3
"""
DISASSEMBLER Integration Test Suite
Validates complete ULTRATHINK pipeline
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Add hooks directory to path
project_root = os.environ.get("CLAUDE_PROJECT_ROOT", "/home/john/claude-backups")
sys.path.insert(0, os.path.join(project_root, "hooks"))

from disassembler_bridge import DisassemblerBridge
from disassembler_hook import DisassemblerHook


class IntegrationTester:
    """Test complete DISASSEMBLER integration"""

    def __init__(self):
        self.project_root = Path(project_root)
        self.hook = DisassemblerHook(str(self.project_root))
        self.bridge = DisassemblerBridge(str(self.project_root))
        self.test_results = []

    def run_all_tests(self):
        """Execute all integration tests"""
        print("=" * 60)
        print("DISASSEMBLER ULTRATHINK INTEGRATION TEST SUITE")
        print("=" * 60)

        # Test 1: Framework detection
        self.test_framework_detection()

        # Test 2: Binary detection
        self.test_binary_detection()

        # Test 3: Create test binary
        test_binary = self.create_test_binary()

        if test_binary:
            # Test 4: Hook analysis
            self.test_hook_analysis(test_binary)

            # Test 5: Bridge processing
            self.test_bridge_processing(test_binary)

            # Cleanup
            test_binary.unlink()

        # Test 6: Cache functionality
        self.test_cache_functionality()

        # Test 7: IOC database
        self.test_ioc_database()

        # Print results
        self.print_results()

    def test_framework_detection(self):
        """Test ULTRATHINK framework detection"""
        print("\n[TEST 1] Framework Detection...")

        ghidra_script = self.project_root / "hooks" / "ghidra-integration.sh"

        if ghidra_script.exists():
            self.test_results.append(
                ("Framework Detection", "PASS", "ghidra-integration.sh found")
            )

            # Check if executable
            if os.access(str(ghidra_script), os.X_OK):
                self.test_results.append(
                    ("Script Executable", "PASS", "Script has execute permission")
                )
            else:
                self.test_results.append(
                    ("Script Executable", "FAIL", "Script not executable")
                )
        else:
            self.test_results.append(
                (
                    "Framework Detection",
                    "FAIL",
                    f"ghidra-integration.sh not found at {ghidra_script}",
                )
            )

        # Check Ghidra availability
        status = self.hook.get_status()
        if status["ghidra_available"]:
            self.test_results.append(
                (
                    "Ghidra Detection",
                    "PASS",
                    f"Ghidra found: {status.get('ghidra_type', 'unknown')}",
                )
            )
        else:
            self.test_results.append(
                ("Ghidra Detection", "WARN", "Ghidra not detected - analysis limited")
            )

    def test_binary_detection(self):
        """Test binary file detection"""
        print("\n[TEST 2] Binary Detection...")

        # Test known binary paths
        test_paths = ["/bin/ls", "/bin/cat", "/usr/bin/python3"]

        detected = 0
        for path in test_paths:
            if Path(path).exists() and self.hook.is_binary(path):
                detected += 1

        if detected > 0:
            self.test_results.append(
                (
                    "Binary Detection",
                    "PASS",
                    f"Detected {detected}/{len(test_paths)} system binaries",
                )
            )
        else:
            self.test_results.append(
                ("Binary Detection", "FAIL", "Could not detect system binaries")
            )

    def create_test_binary(self) -> Path:
        """Create a simple test binary"""
        print("\n[TEST 3] Creating Test Binary...")

        try:
            # Create simple C program
            with tempfile.NamedTemporaryFile(suffix=".c", mode="w", delete=False) as f:
                f.write(
                    """
                    #include <stdio.h>
                    int main() {
                        printf("Test binary for DISASSEMBLER\\n");
                        return 0;
                    }
                """
                )
                c_file = Path(f.name)

            # Compile
            binary_file = Path(tempfile.gettempdir()) / "test_disassembler_binary"
            result = subprocess.run(
                ["gcc", "-o", str(binary_file), str(c_file)], capture_output=True
            )

            c_file.unlink()  # Clean up C file

            if result.returncode == 0:
                self.test_results.append(
                    ("Test Binary Creation", "PASS", "Compiled test binary")
                )
                return binary_file
            else:
                self.test_results.append(
                    (
                        "Test Binary Creation",
                        "FAIL",
                        f"Compilation failed: {result.stderr.decode()}",
                    )
                )
                return None

        except Exception as e:
            self.test_results.append(
                ("Test Binary Creation", "SKIP", f"GCC not available: {e}")
            )

            # Try to use existing binary as test
            if Path("/bin/echo").exists():
                return Path("/bin/echo")
            return None

    def test_hook_analysis(self, binary_path: Path):
        """Test hook analysis functionality"""
        print(f"\n[TEST 4] Hook Analysis of {binary_path.name}...")

        try:
            # Check if binary detected
            if not self.hook.is_binary(str(binary_path)):
                self.test_results.append(
                    (
                        "Hook Binary Detection",
                        "FAIL",
                        f"Failed to detect {binary_path.name} as binary",
                    )
                )
                return

            self.test_results.append(
                (
                    "Hook Binary Detection",
                    "PASS",
                    f"Correctly identified {binary_path.name} as binary",
                )
            )

            # Check if should analyze
            if self.hook.should_analyze(str(binary_path)):
                self.test_results.append(
                    ("Hook Analysis Check", "PASS", "File marked for analysis")
                )
            else:
                self.test_results.append(
                    (
                        "Hook Analysis Check",
                        "INFO",
                        "File already cached or not eligible",
                    )
                )

            # Try analysis (may fail if ghidra not installed)
            result = self.hook.analyze_with_ultrathink(str(binary_path), mode="static")

            if result["status"] == "completed":
                self.test_results.append(
                    ("ULTRATHINK Analysis", "PASS", f"Analysis completed successfully")
                )

                # Check for results
                if result.get("phases_completed"):
                    self.test_results.append(
                        (
                            "Phase Completion",
                            "PASS",
                            f"Completed {len(result['phases_completed'])} phases",
                        )
                    )
                if result.get("threat_score") is not None:
                    self.test_results.append(
                        (
                            "Threat Scoring",
                            "PASS",
                            f"Threat score: {result['threat_score']}",
                        )
                    )
                if result.get("meme_score") is not None:
                    self.test_results.append(
                        ("Meme Scoring", "PASS", f"Meme score: {result['meme_score']}")
                    )

            elif result[
                "status"
            ] == "error" and "ghidra-integration.sh not found" in result.get(
                "error", ""
            ):
                self.test_results.append(
                    (
                        "ULTRATHINK Analysis",
                        "SKIP",
                        "ghidra-integration.sh not installed",
                    )
                )
            else:
                self.test_results.append(
                    (
                        "ULTRATHINK Analysis",
                        "FAIL",
                        f"Analysis failed: {result.get('error', 'Unknown error')}",
                    )
                )

        except Exception as e:
            self.test_results.append(("Hook Analysis", "ERROR", str(e)))

    def test_bridge_processing(self, binary_path: Path):
        """Test bridge coordination"""
        print(f"\n[TEST 5] Bridge Processing of {binary_path.name}...")

        try:
            # Process binary through bridge
            result = self.bridge.process_binary(str(binary_path), {"mode": "static"})

            if result["status"] == "completed":
                self.test_results.append(
                    ("Bridge Processing", "PASS", "Binary processed successfully")
                )

                # Check threat assessment
                if "threat_assessment" in result:
                    assessment = result["threat_assessment"]
                    self.test_results.append(
                        (
                            "Threat Assessment",
                            "PASS",
                            f"Risk: {assessment['risk_level']}, APT: {assessment['apt_classification']}",
                        )
                    )

                # Check agent coordination
                if "agent_coordination" in result:
                    tasks = result["agent_coordination"]
                    self.test_results.append(
                        (
                            "Agent Coordination",
                            "PASS",
                            f"Prepared {len(tasks)} agent tasks",
                        )
                    )

            elif result["status"] == "skipped":
                self.test_results.append(
                    (
                        "Bridge Processing",
                        "SKIP",
                        result.get("reason", "Unknown reason"),
                    )
                )
            else:
                self.test_results.append(
                    ("Bridge Processing", "FAIL", result.get("error", "Unknown error"))
                )

        except Exception as e:
            self.test_results.append(("Bridge Processing", "ERROR", str(e)))

    def test_cache_functionality(self):
        """Test caching system"""
        print("\n[TEST 6] Cache Functionality...")

        try:
            # Check cache file
            if self.hook.cache_file.exists():
                cache_size = len(self.hook.cache)
                self.test_results.append(
                    (
                        "Cache System",
                        "PASS",
                        f"Cache operational with {cache_size} entries",
                    )
                )
            else:
                self.test_results.append(
                    ("Cache System", "INFO", "Cache file not yet created")
                )

            # Test cache save
            self.hook._save_cache()
            self.test_results.append(("Cache Save", "PASS", "Cache save successful"))

        except Exception as e:
            self.test_results.append(("Cache System", "ERROR", str(e)))

    def test_ioc_database(self):
        """Test IOC database"""
        print("\n[TEST 7] IOC Database...")

        try:
            # Get statistics
            stats = self.bridge.get_statistics()

            self.test_results.append(
                (
                    "IOC Database",
                    "PASS",
                    f"Database operational - {stats['total_analyses']} analyses recorded",
                )
            )

            if stats.get("iocs_by_type"):
                total_iocs = sum(stats["iocs_by_type"].values())
                self.test_results.append(
                    ("IOC Storage", "PASS", f"{total_iocs} IOCs stored")
                )

        except Exception as e:
            self.test_results.append(("IOC Database", "ERROR", str(e)))

    def print_results(self):
        """Print test results summary"""
        print("\n" + "=" * 60)
        print("TEST RESULTS SUMMARY")
        print("=" * 60)

        pass_count = sum(1 for _, status, _ in self.test_results if status == "PASS")
        fail_count = sum(1 for _, status, _ in self.test_results if status == "FAIL")
        skip_count = sum(1 for _, status, _ in self.test_results if status == "SKIP")
        warn_count = sum(1 for _, status, _ in self.test_results if status == "WARN")

        for test_name, status, message in self.test_results:
            # Color code status
            if status == "PASS":
                status_str = f"\033[92m[{status}]\033[0m"  # Green
            elif status == "FAIL":
                status_str = f"\033[91m[{status}]\033[0m"  # Red
            elif status == "WARN":
                status_str = f"\033[93m[{status}]\033[0m"  # Yellow
            elif status == "SKIP":
                status_str = f"\033[94m[{status}]\033[0m"  # Blue
            else:
                status_str = f"[{status}]"

            print(f"{status_str:20} {test_name:25} {message}")

        print("\n" + "-" * 60)
        print(
            f"PASSED: {pass_count} | FAILED: {fail_count} | SKIPPED: {skip_count} | WARNINGS: {warn_count}"
        )
        print("-" * 60)

        if fail_count == 0:
            print("\033[92m✓ ALL CRITICAL TESTS PASSED\033[0m")
        else:
            print("\033[91m✗ SOME TESTS FAILED - Review issues above\033[0m")

        print("\nNEXT STEPS:")
        if not (self.project_root / "hooks" / "ghidra-integration.sh").exists():
            print("1. Ensure ghidra-integration.sh is installed in hooks/")
        if not self.hook.get_status()["ghidra_available"]:
            print("2. Install Ghidra: sudo snap install ghidra")
        print("3. Test with real malware samples for full validation")


def main():
    tester = IntegrationTester()
    tester.run_all_tests()


if __name__ == "__main__":
    main()
##
