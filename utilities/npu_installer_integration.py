#!/usr/bin/env python3
"""
NPU Installer Integration
Adds Intel AI Boost NPU support to the Claude installer system
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


class NPUIntegration:
    """Handles Intel AI Boost NPU installation and integration"""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.venv_path = None
        self.npu_available = False
        self.openvino_version = None

    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp"""
        if self.verbose or level in ["ERROR", "WARNING"]:
            print(f"[NPU-{level}] {message}")

    def detect_npu_hardware(self) -> Dict[str, Any]:
        """Detect Intel NPU hardware availability"""
        self.log("Detecting Intel NPU hardware...")

        hardware_info = {
            "npu_detected": False,
            "cpu_model": "Unknown",
            "supports_ai_boost": False,
            "pci_devices": [],
        }

        try:
            # Check CPU model for Intel Core Ultra (Meteor Lake)
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()
                if "Intel(R) Core(TM) Ultra" in cpuinfo:
                    hardware_info["supports_ai_boost"] = True
                    # Extract CPU model
                    for line in cpuinfo.split("\n"):
                        if "model name" in line:
                            hardware_info["cpu_model"] = line.split(":")[1].strip()
                            break

            # Check for NPU via PCI devices
            try:
                lspci_output = subprocess.check_output(
                    ["lspci"], universal_newlines=True
                )
                for line in lspci_output.split("\n"):
                    if "Intel" in line and any(
                        keyword in line.lower() for keyword in ["npu", "ai", "neural"]
                    ):
                        hardware_info["pci_devices"].append(line.strip())
                        hardware_info["npu_detected"] = True
            except subprocess.CalledProcessError:
                self.log("Could not run lspci to detect NPU", "WARNING")

            # Check for Intel NPU device files
            npu_devices = list(Path("/dev").glob("accel*"))
            if npu_devices:
                hardware_info["npu_detected"] = True
                hardware_info["device_files"] = [str(d) for d in npu_devices]

        except Exception as e:
            self.log(f"Hardware detection error: {e}", "WARNING")

        return hardware_info

    def setup_virtual_environment(self, base_path: Path) -> Optional[Path]:
        """Set up virtual environment for OpenVINO"""
        self.log("Setting up virtual environment for NPU acceleration...")

        venv_path = base_path / ".venv"

        try:
            # Create virtual environment
            subprocess.run(
                [sys.executable, "-m", "venv", str(venv_path)],
                check=True,
                capture_output=True,
            )

            # Get python executable in venv
            if os.name == "nt":  # Windows
                python_venv = venv_path / "Scripts" / "python.exe"
                pip_venv = venv_path / "Scripts" / "pip.exe"
            else:  # Unix-like
                python_venv = venv_path / "bin" / "python"
                pip_venv = venv_path / "bin" / "pip"

            # Upgrade pip
            subprocess.run(
                [str(pip_venv), "install", "--upgrade", "pip", "setuptools", "wheel"],
                check=True,
                capture_output=True,
            )

            self.venv_path = venv_path
            self.log(f"Virtual environment created at: {venv_path}")
            return venv_path

        except subprocess.CalledProcessError as e:
            self.log(f"Failed to create virtual environment: {e}", "ERROR")
            return None

    def install_openvino(self, venv_path: Path) -> bool:
        """Install OpenVINO in virtual environment"""
        self.log("Installing OpenVINO for NPU acceleration...")

        if os.name == "nt":  # Windows
            pip_venv = venv_path / "Scripts" / "pip.exe"
            python_venv = venv_path / "Scripts" / "python.exe"
        else:  # Unix-like
            pip_venv = venv_path / "bin" / "pip"
            python_venv = venv_path / "bin" / "python"

        try:
            # Install OpenVINO
            self.log("Installing OpenVINO runtime...")
            subprocess.run(
                [str(pip_venv), "install", "openvino", "numpy"],
                check=True,
                capture_output=True,
            )

            # Test OpenVINO installation
            test_script = """
import openvino as ov
core = ov.Core()
devices = core.available_devices
print(f"Available devices: {devices}")
if 'NPU' in devices:
    npu_name = core.get_property('NPU', 'FULL_DEVICE_NAME')
    print(f"NPU Device: {npu_name}")
print("OpenVINO installation successful")
"""

            result = subprocess.run(
                [str(python_venv), "-c", test_script],
                capture_output=True,
                universal_newlines=True,
            )

            if result.returncode == 0:
                self.log("OpenVINO installation verified successfully")
                self.log(f"OpenVINO test output: {result.stdout.strip()}")

                # Extract version
                try:
                    version_result = subprocess.run(
                        [
                            str(python_venv),
                            "-c",
                            "import openvino as ov; print(ov.__version__)",
                        ],
                        capture_output=True,
                        universal_newlines=True,
                    )
                    if version_result.returncode == 0:
                        self.openvino_version = version_result.stdout.strip()
                        self.log(f"OpenVINO version: {self.openvino_version}")
                except:
                    pass

                return True
            else:
                self.log(f"OpenVINO test failed: {result.stderr}", "ERROR")
                return False

        except subprocess.CalledProcessError as e:
            self.log(f"OpenVINO installation failed: {e}", "ERROR")
            return False

    def create_npu_launcher(self, venv_path: Path, install_dir: Path) -> bool:
        """Create NPU-accelerated orchestrator launcher"""
        self.log("Creating NPU orchestrator launcher...")

        launcher_content = f"""#!/bin/bash
# NPU-Accelerated Claude Orchestrator Launcher
# Auto-generated by NPU installer integration

# Virtual environment setup
VENV_PATH="{venv_path}"
NPU_PYTHON="$VENV_PATH/bin/python"

# Project paths
PROJECT_ROOT="{Path.cwd()}"
NPU_ORCHESTRATOR="$PROJECT_ROOT/agents/src/python/npu_optimized_final.py"

# Colors for output
GREEN='\\033[0;32m'
CYAN='\\033[0;36m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
RESET='\\033[0m'

# Check if NPU orchestrator exists
if [[ ! -f "$NPU_ORCHESTRATOR" ]]; then
    echo -e "${{RED}}Error: NPU orchestrator not found at $NPU_ORCHESTRATOR${{RESET}}"
    echo "Please ensure the NPU acceleration system is properly installed."
    exit 1
fi

# Check virtual environment
if [[ ! -f "$NPU_PYTHON" ]]; then
    echo -e "${{RED}}Error: NPU virtual environment not found${{RESET}}"
    echo "Please run the NPU installer to set up the environment."
    exit 1
fi

# Launch NPU orchestrator
echo -e "${{CYAN}}🚀 Launching NPU-Accelerated Claude Orchestrator${{RESET}}"
echo -e "${{GREEN}}Intel AI Boost NPU: Enabled${{RESET}}"
echo -e "${{GREEN}}OpenVINO Version: {self.openvino_version or 'Unknown'}${{RESET}}"
echo

# Execute with proper environment
export PYTHONPATH="$PROJECT_ROOT/agents/src/python:$PYTHONPATH"
cd "$PROJECT_ROOT/agents/src/python"

exec "$NPU_PYTHON" "$NPU_ORCHESTRATOR" "$@"
"""

        try:
            launcher_path = install_dir / "claude-npu"
            launcher_path.write_text(launcher_content)
            launcher_path.chmod(0o755)

            self.log(f"NPU launcher created at: {launcher_path}")
            return True

        except Exception as e:
            self.log(f"Failed to create NPU launcher: {e}", "ERROR")
            return False

    def create_npu_test_script(self, venv_path: Path, install_dir: Path) -> bool:
        """Create NPU test and validation script"""
        self.log("Creating NPU test script...")

        test_script_content = f"""#!/bin/bash
# NPU System Test and Validation
# Tests Intel AI Boost NPU integration

VENV_PATH="{venv_path}"
NPU_PYTHON="$VENV_PATH/bin/python"
PROJECT_ROOT="{Path.cwd()}"

# Colors
GREEN='\\033[0;32m'
CYAN='\\033[0;36m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BOLD='\\033[1m'
RESET='\\033[0m'

echo -e "${{BOLD}}${{CYAN}}Intel AI Boost NPU System Test${{RESET}}"
echo "=============================================="

# Test 1: OpenVINO availability
echo -e "${{CYAN}}Test 1: OpenVINO Runtime${{RESET}}"
if "$NPU_PYTHON" -c "import openvino as ov; print('✅ OpenVINO available')" 2>/dev/null; then
    VERSION=$("$NPU_PYTHON" -c "import openvino as ov; print(ov.__version__)" 2>/dev/null)
    echo -e "${{GREEN}}✅ OpenVINO $VERSION installed${{RESET}}"
else
    echo -e "${{RED}}❌ OpenVINO not available${{RESET}}"
    exit 1
fi

# Test 2: NPU Hardware Detection
echo -e "${{CYAN}}Test 2: NPU Hardware Detection${{RESET}}"
"$NPU_PYTHON" -c "
import openvino as ov
core = ov.Core()
devices = core.available_devices
print(f'Available devices: {{devices}}')

if 'NPU' in devices:
    try:
        npu_name = core.get_property('NPU', 'FULL_DEVICE_NAME')
        print(f'✅ NPU Device: {{npu_name}}')
    except:
        print('✅ NPU device detected')
else:
    print('⚠️  NPU not detected - CPU/GPU fallback available')

for device in ['CPU', 'GPU']:
    if device in devices:
        try:
            device_name = core.get_property(device, 'FULL_DEVICE_NAME')
            print(f'✅ {{device}}: {{device_name}}')
        except:
            print(f'✅ {{device}}: Available')
"

# Test 3: NPU Orchestrator Functionality
echo -e "${{CYAN}}Test 3: NPU Orchestrator${{RESET}}"
if [[ -f "$PROJECT_ROOT/agents/src/python/npu_baseline_test.py" ]]; then
    echo "Running NPU baseline test..."
    cd "$PROJECT_ROOT/agents/src/python"
    "$NPU_PYTHON" npu_baseline_test.py | tail -10
    echo -e "${{GREEN}}✅ NPU orchestrator test completed${{RESET}}"
else
    echo -e "${{YELLOW}}⚠️  NPU test files not found${{RESET}}"
fi

echo
echo -e "${{BOLD}}${{GREEN}}NPU System Test Complete${{RESET}}"
echo "Use 'claude-npu' command to launch NPU-accelerated orchestrator"
"""

        try:
            test_script_path = install_dir / "claude-npu-test"
            test_script_path.write_text(test_script_content)
            test_script_path.chmod(0o755)

            self.log(f"NPU test script created at: {test_script_path}")
            return True

        except Exception as e:
            self.log(f"Failed to create NPU test script: {e}", "ERROR")
            return False

    def integrate_with_installer(self, install_dir: Path = None) -> Dict[str, Any]:
        """Main integration function"""
        if install_dir is None:
            install_dir = Path.home() / ".local" / "bin"

        install_dir.mkdir(parents=True, exist_ok=True)

        self.log("Starting NPU integration process...")

        # Step 1: Hardware detection
        hardware_info = self.detect_npu_hardware()
        self.log(f"NPU Hardware Detection: {hardware_info}")

        # Step 2: Virtual environment setup
        venv_path = self.setup_virtual_environment(Path.cwd())
        if not venv_path:
            return {"success": False, "error": "Virtual environment setup failed"}

        # Step 3: OpenVINO installation
        if not self.install_openvino(venv_path):
            return {"success": False, "error": "OpenVINO installation failed"}

        # Step 4: Create launchers
        launcher_success = self.create_npu_launcher(venv_path, install_dir)
        test_success = self.create_npu_test_script(venv_path, install_dir)

        # Final validation
        if launcher_success and test_success:
            self.log("NPU integration completed successfully!")

            return {
                "success": True,
                "hardware_info": hardware_info,
                "venv_path": str(venv_path),
                "openvino_version": self.openvino_version,
                "launchers": {
                    "npu_orchestrator": str(install_dir / "claude-npu"),
                    "npu_test": str(install_dir / "claude-npu-test"),
                },
            }
        else:
            return {"success": False, "error": "Launcher creation failed"}


def main():
    """Main function for standalone execution"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Intel AI Boost NPU Integration for Claude"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument(
        "--install-dir", type=str, help="Installation directory for launchers"
    )
    parser.add_argument(
        "--test-only", action="store_true", help="Only run hardware tests"
    )

    args = parser.parse_args()

    npu = NPUIntegration(verbose=args.verbose)

    if args.test_only:
        # Just run hardware detection
        hardware_info = npu.detect_npu_hardware()
        print("NPU Hardware Detection Results:")
        print(f"  NPU Detected: {hardware_info['npu_detected']}")
        print(f"  CPU Model: {hardware_info['cpu_model']}")
        print(f"  AI Boost Support: {hardware_info['supports_ai_boost']}")
        if hardware_info["pci_devices"]:
            print(f"  PCI Devices: {hardware_info['pci_devices']}")
        return

    # Full integration
    install_dir = Path(args.install_dir) if args.install_dir else None
    result = npu.integrate_with_installer(install_dir)

    if result["success"]:
        print("🎉 NPU Integration Success!")
        print(f"OpenVINO Version: {result['openvino_version']}")
        print(f"Virtual Environment: {result['venv_path']}")
        print("\nLaunchers created:")
        for name, path in result["launchers"].items():
            print(f"  {name}: {path}")
        print("\nTest your installation with: claude-npu-test")
    else:
        print(f"❌ NPU Integration Failed: {result['error']}")
        sys.exit(1)


if __name__ == "__main__":
    main()
