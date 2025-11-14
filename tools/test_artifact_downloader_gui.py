#!/usr/bin/env python3
"""
Claude Artifact Downloader GUI Test Suite
=========================================

Test suite demonstrating integration points with PYTHON-INTERNAL and
DEBUGGER agents, along with comprehensive GUI testing.

Usage: python3 test_artifact_downloader_gui.py [--headless] [--verbose]
"""

import json
import os
import sys
import tempfile
import threading
import time
from pathlib import Path
from unittest.mock import Mock, patch

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "agents" / "src" / "python"))

# Import GUI components
try:
    from tools.claude_artifact_downloader_gui import (
        AgentIntegration,
        BatchOperation,
        ClaudeArtifactDownloaderGUI,
        DownloadJob,
        DownloadManager,
        FileValidator,
        LogHandler,
    )

    GUI_AVAILABLE = True
except ImportError as e:
    print(f"GUI import failed: {e}")
    GUI_AVAILABLE = False

try:
    import tkinter as tk
    from tkinter import scrolledtext, ttk

    TKINTER_AVAILABLE = True
except ImportError:
    print("tkinter not available - running in headless mode")
    TKINTER_AVAILABLE = False


class MockTask:
    """Mock Task tool for agent integration testing"""

    def __init__(self, subagent_type: str, prompt: str):
        self.subagent_type = subagent_type
        self.prompt = prompt
        self.result = self._generate_mock_result()

    def _generate_mock_result(self):
        """Generate appropriate mock result based on agent type"""
        if self.subagent_type.lower() == "python-internal":
            return {
                "status": "success",
                "agent": "PYTHON-INTERNAL",
                "action": "environment_check",
                "result": {
                    "python_version": "3.11.5",
                    "packages_available": ["requests", "tkinter", "pathlib"],
                    "environment_status": "healthy",
                    "recommendations": [
                        "Consider updating pip",
                        "Install optional packages",
                    ],
                },
            }
        elif self.subagent_type.lower() == "debugger":
            return {
                "status": "success",
                "agent": "DEBUGGER",
                "action": "error_analysis",
                "result": {
                    "error_trace": "No recent errors detected",
                    "performance_metrics": {
                        "cpu_usage": "12%",
                        "memory_usage": "256MB",
                        "response_time": "45ms",
                    },
                    "recommendations": ["System operating normally"],
                },
            }
        else:
            return {
                "status": "success",
                "agent": self.subagent_type.upper(),
                "result": f"Mock response for {self.subagent_type}",
            }


class GUITestSuite:
    """Comprehensive GUI test suite"""

    def __init__(self, headless=False, verbose=False):
        self.headless = headless
        self.verbose = verbose
        self.test_results = []
        self.temp_dir = None

    def log(self, message):
        """Log test message"""
        if self.verbose:
            print(f"[TEST] {message}")

    def create_test_environment(self):
        """Create test environment"""
        self.log("Creating test environment...")

        # Create temporary directory
        self.temp_dir = tempfile.mkdtemp(prefix="claude_downloader_test_")
        self.log(f"Test directory: {self.temp_dir}")

        # Create test files
        test_files = {
            "test.txt": "This is a test file for validation",
            "test.json": '{"test": "data", "version": "1.0"}',
            "test.py": "#!/usr/bin/env python3\nprint('Hello from test script')\n",
        }

        for filename, content in test_files.items():
            file_path = Path(self.temp_dir) / filename
            with open(file_path, "w") as f:
                f.write(content)

        self.log(f"Created {len(test_files)} test files")

    def cleanup_test_environment(self):
        """Clean up test environment"""
        if self.temp_dir:
            import shutil

            shutil.rmtree(self.temp_dir, ignore_errors=True)
            self.log("Test environment cleaned up")

    def test_download_job_creation(self):
        """Test download job creation"""
        self.log("Testing download job creation...")

        try:
            job = DownloadJob(
                id="test_job_1",
                url="https://example.com/test.zip",
                output_path=str(Path(self.temp_dir) / "test_download.zip"),
                name="Test Download Job",
                description="Test job for validation",
            )

            assert job.id == "test_job_1"
            assert job.status == "pending"
            assert job.progress == 0.0
            assert job.created_at is not None

            self.test_results.append(("download_job_creation", True, None))
            self.log("✓ Download job creation test passed")

        except Exception as e:
            self.test_results.append(("download_job_creation", False, str(e)))
            self.log(f"✗ Download job creation test failed: {e}")

    def test_file_validator(self):
        """Test file validation functionality"""
        self.log("Testing file validator...")

        try:
            # Test with created test file
            test_file = Path(self.temp_dir) / "test.txt"

            # Get file info
            file_info = FileValidator.get_file_info(str(test_file))
            assert "size" in file_info
            assert "modified" in file_info
            assert "extension" in file_info

            # Calculate hash
            file_hash = FileValidator.calculate_hash(str(test_file))
            assert len(file_hash) == 64  # SHA256 hex string

            # Check safety
            is_safe, msg = FileValidator.is_safe_file(str(test_file))
            assert is_safe  # Text file should be safe

            self.test_results.append(("file_validator", True, None))
            self.log("✓ File validator test passed")

        except Exception as e:
            self.test_results.append(("file_validator", False, str(e)))
            self.log(f"✗ File validator test failed: {e}")

    def test_batch_operations(self):
        """Test batch operations"""
        self.log("Testing batch operations...")

        try:
            batch = BatchOperation(
                id="test_batch_1", name="Test Batch", jobs=["job1", "job2", "job3"]
            )

            assert batch.id == "test_batch_1"
            assert batch.name == "Test Batch"
            assert len(batch.jobs) == 3
            assert batch.status == "pending"
            assert batch.created_at is not None

            self.test_results.append(("batch_operations", True, None))
            self.log("✓ Batch operations test passed")

        except Exception as e:
            self.test_results.append(("batch_operations", False, str(e)))
            self.log(f"✗ Batch operations test failed: {e}")

    def test_agent_integration_mock(self):
        """Test agent integration with mocked Task tool"""
        self.log("Testing agent integration...")

        try:
            # Create mock log handler
            if TKINTER_AVAILABLE:
                root = tk.Tk()
                root.withdraw()  # Hide window
                log_widget = scrolledtext.ScrolledText(root)
                logger = LogHandler(log_widget)
            else:
                logger = Mock()
                logger.info = lambda x: None
                logger.error = lambda x: None

            agent_integration = AgentIntegration(logger)

            # Test PYTHON-INTERNAL integration
            result = agent_integration.invoke_python_internal("validate_environment")
            assert "status" in result

            # Test DEBUGGER integration
            result = agent_integration.invoke_debugger("analyze_file", "test.py")
            assert "status" in result

            if TKINTER_AVAILABLE:
                root.destroy()

            self.test_results.append(("agent_integration", True, None))
            self.log("✓ Agent integration test passed")

        except Exception as e:
            self.test_results.append(("agent_integration", False, str(e)))
            self.log(f"✗ Agent integration test failed: {e}")

    def test_download_manager(self):
        """Test download manager"""
        self.log("Testing download manager...")

        try:
            # Create mock logger
            if TKINTER_AVAILABLE:
                root = tk.Tk()
                root.withdraw()
                log_widget = scrolledtext.ScrolledText(root)
                logger = LogHandler(log_widget)
            else:
                logger = Mock()
                logger.info = lambda x: None
                logger.error = lambda x: None

            manager = DownloadManager(logger)

            # Create test job
            job = DownloadJob(
                id="test_download",
                url="https://httpbin.org/json",  # Safe test URL
                output_path=str(Path(self.temp_dir) / "test_api_response.json"),
                name="Test API Download",
            )

            # Add job to manager
            success = manager.add_job(job)
            assert success
            assert job.id in manager.jobs

            if TKINTER_AVAILABLE:
                root.destroy()

            self.test_results.append(("download_manager", True, None))
            self.log("✓ Download manager test passed")

        except Exception as e:
            self.test_results.append(("download_manager", False, str(e)))
            self.log(f"✗ Download manager test failed: {e}")

    def test_gui_initialization(self):
        """Test GUI initialization in headless mode"""
        if self.headless or not TKINTER_AVAILABLE or not GUI_AVAILABLE:
            self.log(
                "Skipping GUI initialization test (headless mode or GUI not available)"
            )
            return

        self.log("Testing GUI initialization...")

        try:
            # Create GUI instance but don't show it
            app = ClaudeArtifactDownloaderGUI()

            # Verify key components exist
            assert hasattr(app, "root")
            assert hasattr(app, "notebook")
            assert hasattr(app, "download_manager")
            assert hasattr(app, "logger")
            assert hasattr(app, "agent_integration")

            # Test some basic functionality
            assert app.auto_validate.get() in [True, False]
            assert app.auto_preview.get() in [True, False]

            # Clean up
            app.root.destroy()

            self.test_results.append(("gui_initialization", True, None))
            self.log("✓ GUI initialization test passed")

        except Exception as e:
            self.test_results.append(("gui_initialization", False, str(e)))
            self.log(f"✗ GUI initialization test failed: {e}")

    def run_all_tests(self):
        """Run all tests"""
        self.log("Starting Claude Artifact Downloader GUI test suite...")

        # Setup
        self.create_test_environment()

        try:
            # Run tests
            self.test_download_job_creation()
            self.test_file_validator()
            self.test_batch_operations()
            self.test_agent_integration_mock()
            self.test_download_manager()
            self.test_gui_initialization()

        finally:
            # Cleanup
            self.cleanup_test_environment()

        # Report results
        self.report_results()

    def report_results(self):
        """Report test results"""
        print("\n" + "=" * 60)
        print("CLAUDE ARTIFACT DOWNLOADER GUI TEST RESULTS")
        print("=" * 60)

        passed = 0
        failed = 0

        for test_name, success, error in self.test_results:
            status = "PASS" if success else "FAIL"
            print(f"{test_name:30} | {status}")
            if not success and error:
                print(f"{'':30} | Error: {error}")

            if success:
                passed += 1
            else:
                failed += 1

        print("-" * 60)
        print(f"Total Tests: {len(self.test_results)}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        print(
            f"Success Rate: {(passed/len(self.test_results)*100):.1f}%"
            if self.test_results
            else "0%"
        )
        print("=" * 60)

        success = failed == 0

        if success:
            print("\n🎉 All tests passed! System is ready for use.")
        else:
            print(f"\n❌ {failed} test(s) failed. Please check the errors above.")

        return success


def demonstrate_integration_points():
    """Demonstrate integration points with agents"""
    print("\n" + "=" * 60)
    print("INTEGRATION POINTS DEMONSTRATION")
    print("=" * 60)

    print("\n1. PYTHON-INTERNAL Agent Integration:")
    print("   - Environment validation")
    print("   - Dependency management")
    print("   - Virtual environment setup")
    print("   - Package installation")

    # Mock PYTHON-INTERNAL invocation
    mock_task = MockTask("python-internal", "validate_environment")
    print(f"   Mock result: {json.dumps(mock_task.result, indent=2)}")

    print("\n2. DEBUGGER Agent Integration:")
    print("   - Error analysis and tracing")
    print("   - Performance monitoring")
    print("   - Download process debugging")
    print("   - Log analysis")

    # Mock DEBUGGER invocation
    mock_task = MockTask("debugger", "analyze_download_process")
    print(f"   Mock result: {json.dumps(mock_task.result, indent=2)}")

    print("\n3. Integration Architecture:")
    print("   - GUI communicates via AgentIntegration class")
    print("   - Results displayed in Integration tab")
    print("   - Real-time status updates")
    print("   - Error recovery and retry logic")

    print("\n4. Workflow Integration:")
    print("   - Download validation → DEBUGGER analysis")
    print("   - Environment issues → PYTHON-INTERNAL assistance")
    print("   - Batch operations → Multi-agent coordination")
    print("   - Error handling → Automatic agent invocation")


def main():
    """Main test function"""
    import argparse

    parser = argparse.ArgumentParser(description="Test Claude Artifact Downloader GUI")
    parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    parser.add_argument(
        "--demo-only", action="store_true", help="Only show integration demo"
    )

    args = parser.parse_args()

    # Check environment
    if not GUI_AVAILABLE:
        print("GUI components not available - running limited tests")
        args.headless = True

    if not TKINTER_AVAILABLE and not args.headless:
        print("tkinter not available - forcing headless mode")
        args.headless = True

    # Show integration points
    demonstrate_integration_points()

    if args.demo_only:
        return

    # Run tests
    test_suite = GUITestSuite(headless=args.headless, verbose=args.verbose)
    success = test_suite.run_all_tests()

    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    sys.exit(main())
