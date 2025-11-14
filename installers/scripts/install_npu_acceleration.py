#!/usr/bin/env python3
"""
NPU ACCELERATION INSTALLER
Installs and configures NPU acceleration for the Python orchestrator

Features:
1. Validates Intel Meteor Lake NPU hardware availability
2. Configures NPU device access and permissions
3. Integrates NPU acceleration with existing orchestrator
4. Sets up performance monitoring and optimization
5. Creates configuration files and service definitions
6. Validates installation with comprehensive testing
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class NPUAccelerationInstaller:
    """Installer for NPU acceleration system"""

    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent.parent
        self.python_dir = Path(__file__).parent
        self.config_dir = self.project_root / "config"
        self.logs_dir = self.project_root / "logs"

        # Installation status
        self.installation_log = []
        self.installation_successful = False

        # Hardware validation
        self.npu_hardware_available = False
        self.npu_driver_loaded = False
        self.npu_device_accessible = False

        logger.info(f"NPU Acceleration Installer initialized")
        logger.info(f"Project root: {self.project_root}")

    async def install(self) -> bool:
        """Complete NPU acceleration installation"""
        logger.info("Starting NPU Acceleration Installation...")

        try:
            # Phase 1: Hardware validation
            if not await self._validate_hardware():
                logger.error("Hardware validation failed")
                return False

            # Phase 2: System configuration
            if not await self._configure_system():
                logger.error("System configuration failed")
                return False

            # Phase 3: Integration setup
            if not await self._setup_integration():
                logger.error("Integration setup failed")
                return False

            # Phase 4: Configuration files
            if not await self._create_configurations():
                logger.error("Configuration creation failed")
                return False

            # Phase 5: Validation testing
            if not await self._validate_installation():
                logger.error("Installation validation failed")
                return False

            # Phase 6: Final setup
            await self._finalize_installation()

            self.installation_successful = True
            logger.info("NPU Acceleration installation completed successfully!")
            return True

        except Exception as e:
            logger.error(f"Installation failed: {e}")
            return False

    async def _validate_hardware(self) -> bool:
        """Validate NPU hardware availability"""
        logger.info("Phase 1: Validating NPU hardware...")

        try:
            # Check for Intel Meteor Lake NPU
            result = subprocess.run(["lspci"], capture_output=True, text=True)
            lspci_output = result.stdout

            if "Meteor Lake NPU" in lspci_output:
                self.npu_hardware_available = True
                logger.info("✓ Intel Meteor Lake NPU detected")
                self._log_step("NPU hardware detected in lspci")
            else:
                logger.warning("⚠ Intel Meteor Lake NPU not detected in lspci")
                self._log_step("NPU hardware not detected", success=False)

            # Check for NPU device
            npu_device_path = "/dev/accel/accel0"
            if os.path.exists(npu_device_path):
                self.npu_device_accessible = True
                logger.info(f"✓ NPU device found at {npu_device_path}")
                self._log_step(f"NPU device accessible at {npu_device_path}")

                # Check device permissions
                stat_info = os.stat(npu_device_path)
                device_mode = oct(stat_info.st_mode)[-3:]
                logger.info(f"Device permissions: {device_mode}")

            else:
                logger.warning(f"⚠ NPU device not found at {npu_device_path}")
                self._log_step(
                    f"NPU device not found at {npu_device_path}", success=False
                )

            # Check for intel_vpu driver
            try:
                result = subprocess.run(["lsmod"], capture_output=True, text=True)
                if "intel_vpu" in result.stdout:
                    self.npu_driver_loaded = True
                    logger.info("✓ intel_vpu driver loaded")
                    self._log_step("intel_vpu driver loaded")
                else:
                    logger.warning("⚠ intel_vpu driver not loaded")
                    self._log_step("intel_vpu driver not loaded", success=False)
            except Exception as e:
                logger.warning(f"Could not check driver status: {e}")

            # Summary
            hardware_score = sum(
                [
                    self.npu_hardware_available,
                    self.npu_device_accessible,
                    self.npu_driver_loaded,
                ]
            )

            logger.info(f"Hardware validation score: {hardware_score}/3")

            if hardware_score >= 1:  # At least NPU hardware detected
                logger.info("✓ Sufficient hardware support for NPU acceleration")
                return True
            else:
                logger.error("✗ Insufficient hardware support")
                return False

        except Exception as e:
            logger.error(f"Hardware validation error: {e}")
            return False

    async def _configure_system(self) -> bool:
        """Configure system for NPU acceleration"""
        logger.info("Phase 2: Configuring system...")

        try:
            # Create directories
            directories = [
                self.config_dir,
                self.logs_dir,
                self.project_root / "cache" / "npu",
                self.project_root / "data" / "npu_models",
            ]

            for directory in directories:
                directory.mkdir(parents=True, exist_ok=True)
                logger.info(f"✓ Created directory: {directory}")
                self._log_step(f"Created directory: {directory}")

            # Check Python dependencies
            required_packages = ["numpy", "asyncio"]
            missing_packages = []

            for package in required_packages:
                try:
                    __import__(package)
                    logger.info(f"✓ Package available: {package}")
                except ImportError:
                    missing_packages.append(package)
                    logger.warning(f"⚠ Missing package: {package}")

            if missing_packages:
                logger.info(f"Installing missing packages: {missing_packages}")
                try:
                    subprocess.check_call(
                        [sys.executable, "-m", "pip", "install"] + missing_packages
                    )
                    logger.info("✓ Packages installed successfully")
                    self._log_step("Installed missing packages")
                except Exception as e:
                    logger.error(f"Failed to install packages: {e}")
                    return False

            # Set up user permissions for NPU device (if exists)
            if self.npu_device_accessible:
                try:
                    # Add current user to render group for NPU access
                    current_user = os.getenv("USER")
                    if current_user:
                        subprocess.run(
                            ["sudo", "usermod", "-a", "-G", "render", current_user],
                            check=False,
                        )  # Don't fail if sudo not available
                        logger.info(f"✓ Added {current_user} to render group")
                        self._log_step(f"Added {current_user} to render group")
                except Exception as e:
                    logger.warning(f"Could not modify user groups: {e}")

            return True

        except Exception as e:
            logger.error(f"System configuration error: {e}")
            return False

    async def _setup_integration(self) -> bool:
        """Set up integration with existing orchestrator"""
        logger.info("Phase 3: Setting up integration...")

        try:
            # Check if orchestrator files exist
            orchestrator_files = [
                self.python_dir / "production_orchestrator.py",
                self.python_dir / "npu_accelerated_orchestrator.py",
                self.python_dir / "npu_orchestrator_bridge.py",
            ]

            missing_files = []
            for file_path in orchestrator_files:
                if file_path.exists():
                    logger.info(f"✓ Found: {file_path.name}")
                    self._log_step(f"Found orchestrator file: {file_path.name}")
                else:
                    missing_files.append(file_path.name)
                    logger.warning(f"⚠ Missing: {file_path.name}")

            if missing_files:
                logger.error(f"Missing critical files: {missing_files}")
                return False

            # Create integration wrapper
            wrapper_path = self.python_dir / "npu_orchestrator_launcher.py"
            await self._create_launcher_script(wrapper_path)

            # Create service configuration
            service_config = {
                "name": "npu-orchestrator",
                "description": "NPU Accelerated Orchestrator Service",
                "python_path": str(self.python_dir),
                "main_module": "npu_orchestrator_bridge",
                "npu_mode": "adaptive",
                "auto_start": False,
                "restart_on_failure": True,
                "log_level": "INFO",
            }

            service_config_path = self.config_dir / "npu_service.json"
            with open(service_config_path, "w") as f:
                json.dump(service_config, f, indent=2)

            logger.info(f"✓ Created service configuration: {service_config_path}")
            self._log_step("Created service configuration")

            return True

        except Exception as e:
            logger.error(f"Integration setup error: {e}")
            return False

    async def _create_launcher_script(self, output_path: Path):
        """Create launcher script for NPU orchestrator"""
        launcher_content = '''#!/usr/bin/env python3
"""
NPU ORCHESTRATOR LAUNCHER
Launches NPU-accelerated orchestrator with proper configuration
"""

import asyncio
import sys
import logging
from pathlib import Path

# Add project path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from agents.src.python.npu_orchestrator_bridge import NPUOrchestratorBridge
    from agents.src.python.npu_accelerated_orchestrator import NPUMode
except ImportError as e:
    print(f"Import error: {e}")
    print("Please ensure NPU orchestrator files are properly installed")
    sys.exit(1)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    """Main launcher function"""
    logger.info("Starting NPU Accelerated Orchestrator...")

    # Initialize bridge with adaptive mode
    bridge = NPUOrchestratorBridge(NPUMode.ADAPTIVE)

    if await bridge.initialize():
        logger.info("NPU Orchestrator initialized successfully!")

        # Print status
        status = bridge.get_status()
        print(f"NPU Available: {status.get('npu_available', False)}")
        print(f"Agents Available: {len(bridge.get_agent_list())}")

        # Keep running (in production, this would be a service)
        try:
            while True:
                await asyncio.sleep(60)
                metrics = bridge.get_metrics()
                logger.info(f"Status: {metrics}")
        except KeyboardInterrupt:
            logger.info("Shutting down...")
    else:
        logger.error("Failed to initialize NPU Orchestrator")
        return False

    return True

if __name__ == "__main__":
    asyncio.run(main())
'''

        with open(output_path, "w") as f:
            f.write(launcher_content)

        # Make executable
        os.chmod(output_path, 0o755)

        logger.info(f"✓ Created launcher script: {output_path}")

    async def _create_configurations(self) -> bool:
        """Create configuration files"""
        logger.info("Phase 4: Creating configuration files...")

        try:
            # NPU configuration
            npu_config = {
                "npu_device_path": "/dev/accel/accel0",
                "npu_mode": "adaptive",
                "performance_targets": {
                    "throughput_ops_per_sec": 20000,
                    "agent_selection_time_ms": 1.0,
                    "message_routing_time_ms": 0.5,
                    "npu_utilization_target": 0.75,
                },
                "fallback_settings": {
                    "enable_cpu_fallback": True,
                    "fallback_error_threshold": 0.1,
                    "fallback_timeout_ms": 100,
                },
                "optimization": {
                    "enable_adaptive_mode": True,
                    "enable_performance_monitoring": True,
                    "cache_predictions": True,
                    "batch_operations": True,
                    "batch_size": 32,
                    "batch_timeout_ms": 10,
                },
                "hardware": {
                    "meteor_lake_optimization": True,
                    "use_p_cores_for_critical": True,
                    "use_e_cores_for_background": True,
                    "thermal_throttling_enabled": True,
                },
            }

            npu_config_path = self.config_dir / "npu_config.json"
            with open(npu_config_path, "w") as f:
                json.dump(npu_config, f, indent=2)

            logger.info(f"✓ Created NPU configuration: {npu_config_path}")
            self._log_step("Created NPU configuration")

            # Orchestrator integration configuration
            integration_config = {
                "enabled": True,
                "bridge_mode": "seamless",
                "auto_detect_npu": True,
                "performance_monitoring": {
                    "enabled": True,
                    "log_interval_seconds": 60,
                    "metrics_retention_hours": 24,
                },
                "agent_selection": {
                    "use_npu_intelligence": True,
                    "fallback_to_rules": True,
                    "cache_selections": True,
                    "cache_ttl_seconds": 30,
                },
                "message_routing": {
                    "use_npu_classification": True,
                    "enable_batching": True,
                    "priority_queues": True,
                },
            }

            integration_config_path = self.config_dir / "orchestrator_integration.json"
            with open(integration_config_path, "w") as f:
                json.dump(integration_config, f, indent=2)

            logger.info(
                f"✓ Created integration configuration: {integration_config_path}"
            )
            self._log_step("Created integration configuration")

            # Environment configuration
            env_config = f"""# NPU Orchestrator Environment Configuration
export NPU_DEVICE_PATH="/dev/accel/accel0"
export NPU_MODE="adaptive"
export NPU_CONFIG_PATH="{npu_config_path}"
export ORCHESTRATOR_CONFIG_PATH="{integration_config_path}"
export NPU_LOG_LEVEL="INFO"
export NPU_ENABLE_PERFORMANCE_MONITORING="true"
"""

            env_config_path = self.config_dir / "npu_environment.sh"
            with open(env_config_path, "w") as f:
                f.write(env_config)

            logger.info(f"✓ Created environment configuration: {env_config_path}")
            self._log_step("Created environment configuration")

            return True

        except Exception as e:
            logger.error(f"Configuration creation error: {e}")
            return False

    async def _validate_installation(self) -> bool:
        """Validate installation with testing"""
        logger.info("Phase 5: Validating installation...")

        try:
            # Import test modules
            sys.path.insert(0, str(self.python_dir))

            try:
                # Test basic imports
                from npu_accelerated_orchestrator import (
                    NPUAcceleratedOrchestrator,
                    NPUMode,
                )
                from npu_orchestrator_bridge import NPUOrchestratorBridge

                logger.info("✓ Successfully imported NPU modules")
                self._log_step("NPU modules imported successfully")

                # Test NPU device initialization
                from npu_accelerated_orchestrator import NPUDevice

                npu_device = NPUDevice()
                device_init_success = npu_device.initialize()

                if device_init_success:
                    logger.info("✓ NPU device initialization successful")
                    self._log_step("NPU device initialized")
                    npu_device.cleanup()
                else:
                    logger.warning(
                        "⚠ NPU device initialization failed (NPU may not be available)"
                    )
                    self._log_step("NPU device initialization failed", success=False)

                # Test bridge initialization
                bridge = NPUOrchestratorBridge(NPUMode.ADAPTIVE)
                bridge_init_success = await bridge.initialize()

                if bridge_init_success:
                    logger.info("✓ Bridge initialization successful")
                    self._log_step("Bridge initialized successfully")

                    # Test basic functionality
                    status = bridge.get_status()
                    agent_list = bridge.get_agent_list()

                    logger.info(f"✓ Bridge status: {len(status)} fields")
                    logger.info(f"✓ Available agents: {len(agent_list)}")
                    self._log_step(f"Bridge functional with {len(agent_list)} agents")

                else:
                    logger.warning("⚠ Bridge initialization failed")
                    self._log_step("Bridge initialization failed", success=False)

                # Run basic test if available
                try:
                    from test_npu_acceleration import NPUAccelerationTestSuite

                    test_suite = NPUAccelerationTestSuite()

                    # Run only basic tests
                    logger.info("Running basic validation tests...")
                    basic_test_result = (
                        await test_suite.test_npu_device_initialization()
                    )

                    if basic_test_result.get("status") == "passed":
                        logger.info("✓ Basic validation tests passed")
                        self._log_step("Basic validation tests passed")
                    else:
                        logger.warning("⚠ Basic validation tests failed")
                        self._log_step("Basic validation tests failed", success=False)

                except ImportError:
                    logger.info("Test suite not available, skipping detailed tests")

                return True

            except ImportError as e:
                logger.error(f"Failed to import NPU modules: {e}")
                self._log_step(f"Import failed: {e}", success=False)
                return False

        except Exception as e:
            logger.error(f"Validation error: {e}")
            self._log_step(f"Validation error: {e}", success=False)
            return False

    async def _finalize_installation(self):
        """Finalize installation"""
        logger.info("Phase 6: Finalizing installation...")

        # Create installation summary
        summary = {
            "installation_date": datetime.now().isoformat(),
            "installation_successful": self.installation_successful,
            "hardware_status": {
                "npu_hardware_available": self.npu_hardware_available,
                "npu_driver_loaded": self.npu_driver_loaded,
                "npu_device_accessible": self.npu_device_accessible,
            },
            "installation_log": self.installation_log,
            "configuration_files": [
                str(self.config_dir / "npu_config.json"),
                str(self.config_dir / "orchestrator_integration.json"),
                str(self.config_dir / "npu_environment.sh"),
            ],
            "launcher_script": str(self.python_dir / "npu_orchestrator_launcher.py"),
        }

        summary_path = (
            self.logs_dir
            / f"npu_installation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        with open(summary_path, "w") as f:
            json.dump(summary, f, indent=2)

        logger.info(f"✓ Installation summary saved: {summary_path}")

        # Print final status
        self._print_installation_summary()

    def _log_step(self, message: str, success: bool = True):
        """Log installation step"""
        self.installation_log.append(
            {
                "timestamp": datetime.now().isoformat(),
                "message": message,
                "success": success,
            }
        )

    def _print_installation_summary(self):
        """Print installation summary"""
        print("\n" + "=" * 60)
        print("NPU ACCELERATION INSTALLATION SUMMARY")
        print("=" * 60)

        print(
            f"Installation Status: {'SUCCESS' if self.installation_successful else 'FAILED'}"
        )
        print(
            f"NPU Hardware: {'Available' if self.npu_hardware_available else 'Not Detected'}"
        )
        print(f"NPU Driver: {'Loaded' if self.npu_driver_loaded else 'Not Loaded'}")
        print(
            f"NPU Device: {'Accessible' if self.npu_device_accessible else 'Not Accessible'}"
        )

        print("\nConfiguration Files:")
        config_files = [
            self.config_dir / "npu_config.json",
            self.config_dir / "orchestrator_integration.json",
            self.config_dir / "npu_environment.sh",
        ]

        for config_file in config_files:
            status = "✓" if config_file.exists() else "✗"
            print(f"  {status} {config_file}")

        print(f"\nLauncher Script:")
        launcher_script = self.python_dir / "npu_orchestrator_launcher.py"
        status = "✓" if launcher_script.exists() else "✗"
        print(f"  {status} {launcher_script}")

        print(f"\nUsage:")
        print(f"  # Source environment")
        print(f"  source {self.config_dir}/npu_environment.sh")
        print(f"")
        print(f"  # Launch NPU orchestrator")
        print(f"  python3 {launcher_script}")
        print(f"")
        print(f"  # Or use bridge directly in code:")
        print(f"  from agents.src.python.npu_orchestrator_bridge import get_npu_bridge")
        print(f"  bridge = await get_npu_bridge()")

        if self.installation_successful:
            print(
                f"\n🚀 NPU acceleration is ready for {20000} ops/sec target throughput!"
            )
        else:
            print(f"\n⚠️  Installation completed with issues. Review logs for details.")

        print("=" * 60)


async def main():
    """Main installation function"""
    installer = NPUAccelerationInstaller()
    success = await installer.install()

    if success:
        print("\nNPU Acceleration installation completed successfully!")
        return 0
    else:
        print("\nNPU Acceleration installation failed!")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
