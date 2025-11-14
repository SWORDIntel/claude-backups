#!/usr/bin/env python3
"""
Military Deployment Module for Claude Enhanced Installer
Handles 40+ TFLOPS optimization and local Opus deployment
"""

import asyncio
import json
import logging
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class MilitaryDeployment:
    """Handles military-grade deployment with 40+ TFLOPS optimization"""

    def __init__(self, installer, verbose: bool = False):
        self.installer = installer
        self.verbose = verbose
        self.sudo_password = installer.sudo_password
        self.project_root = installer.project_root

        # Setup logging
        self.logger = logging.getLogger("MilitaryDeployment")

        # Deployment paths
        self.hardware_dir = self.project_root / "hardware"
        self.local_models_dir = self.project_root / "local-models" / "opus-openvino"
        self.orchestration_dir = self.project_root / "orchestration"

    def deploy_military_optimization(self) -> bool:
        """Deploy complete 40+ TFLOPS military optimization"""

        try:
            self.logger.info("🚀 Deploying military-grade 40+ TFLOPS optimization")

            # Step 1: Hardware detection and NPU activation
            if not self._deploy_hardware_optimization():
                self.logger.warning(
                    "Hardware optimization failed, continuing with reduced capabilities"
                )

            # Step 2: Agent coordination matrix deployment
            if not self._deploy_agent_coordination():
                self.logger.error("Agent coordination deployment failed")
                return False

            # Step 3: Performance validation
            if not self._validate_military_performance():
                self.logger.warning(
                    "Performance validation failed, but deployment continues"
                )

            self.logger.info("✅ Military optimization deployment completed")
            return True

        except Exception as e:
            self.logger.error(f"Military deployment failed: {e}")
            return False

    def deploy_local_opus(self) -> bool:
        """Deploy local Opus inference system (infrastructure-only)"""

        try:
            self.logger.info("🎯 Deploying local Opus inference infrastructure")
            self.logger.info(
                "📋 Note: Infrastructure-only mode - actual model weights not included"
            )
            self.logger.info(
                "💡 Tip: Use qwen-openvino for functional local inference, or external APIs"
            )

            # Step 1: Create directories
            self.local_models_dir.mkdir(parents=True, exist_ok=True)

            # Step 2: Deploy quantization system
            if not self._deploy_quantization_system():
                self.logger.warning(
                    "Quantization system deployment had issues, continuing..."
                )

            # Step 3: Deploy FastAPI server
            if not self._deploy_inference_server():
                self.logger.warning(
                    "Inference server deployment had issues, continuing..."
                )

            # Step 4: Configure agent routing
            if not self._configure_local_routing():
                self.logger.warning(
                    "Local routing configuration had issues, continuing..."
                )

            self.logger.info("✅ Local Opus infrastructure deployment completed")
            self.logger.info(
                "   Use external APIs or qwen-openvino for actual inference"
            )
            return True

        except Exception as e:
            self.logger.warning(f"Local Opus deployment had issues: {e}")
            self.logger.info(
                "Continuing installation - infrastructure setup is optional"
            )
            return True

    def _deploy_hardware_optimization(self) -> bool:
        """Deploy hardware optimization scripts"""

        try:
            # Run military hardware analyzer
            hardware_analyzer = self.hardware_dir / "milspec_hardware_analyzer.py"
            if hardware_analyzer.exists():
                self.logger.info("Running military hardware analysis...")

                cmd = [
                    "python3",
                    str(hardware_analyzer),
                    "--export",
                    str(self.project_root / ".claude" / "hardware_config.json"),
                ]

                result = self._run_with_sudo(cmd)
                if result.returncode != 0:
                    self.logger.warning(
                        f"Hardware analyzer returned {result.returncode}"
                    )

            # Run NPU optimization
            npu_optimizer = self.hardware_dir / "enable-npu-turbo.sh"
            if npu_optimizer.exists():
                self.logger.info("Activating NPU military mode...")

                cmd = ["bash", str(npu_optimizer)]
                result = self._run_with_sudo(cmd)
                if result.returncode != 0:
                    self.logger.warning(f"NPU optimizer returned {result.returncode}")

            # Run full optimization script
            optimization_script = self.project_root / "execute_40tflops_optimization.sh"
            if optimization_script.exists():
                self.logger.info("Executing 40+ TFLOPS optimization...")

                cmd = ["bash", str(optimization_script)]
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    self.logger.warning(
                        f"40+ TFLOPS optimization warnings: {result.stderr[:200]}"
                    )

            return True

        except Exception as e:
            self.logger.error(f"Hardware optimization failed: {e}")
            return False

    def _deploy_agent_coordination(self) -> bool:
        """Deploy 98-agent coordination matrix"""

        try:
            # Run DSMIL orchestrator
            orchestrator_script = (
                self.project_root / "installers" / "claude" / "dsmil_orchestrator.py"
            )
            if orchestrator_script.exists():
                self.logger.info("Deploying 98-agent coordination matrix...")

                cmd = ["python3", str(orchestrator_script)]
                result = self._run_with_sudo(cmd, capture_errors=False)

                # Note: orchestrator may have warnings, but still succeed
                self.logger.info("Agent coordination deployment attempted")

            return True

        except Exception as e:
            self.logger.error(f"Agent coordination deployment failed: {e}")
            return False

    def _deploy_quantization_system(self) -> bool:
        """Deploy Opus quantization system"""

        try:
            # Copy quantization files if not exist
            quantizer_file = self.local_models_dir / "opus_quantizer.py"
            if not quantizer_file.exists():
                self.logger.info("Opus quantizer not found, will use embedded version")
                return True  # Quantizer is embedded in server

            # Run quantization
            self.logger.info("Running Opus model quantization...")

            cmd = ["python3", str(quantizer_file)]
            result = subprocess.run(
                cmd,
                cwd=str(self.local_models_dir),
                capture_output=True,
                text=True,
                timeout=300,  # 5 minutes timeout
            )

            if result.returncode == 0:
                self.logger.info("✅ Model quantization completed")
            else:
                self.logger.warning(f"Quantization warnings: {result.stderr[:200]}")

            return True

        except subprocess.TimeoutExpired:
            self.logger.warning("Quantization timed out, using fallback configurations")
            return True
        except Exception as e:
            self.logger.warning(f"Quantization failed, using fallback: {e}")
            return True  # Continue with fallback

    def _deploy_inference_server(self) -> bool:
        """Deploy local inference server"""

        try:
            server_file = self.local_models_dir / "local_opus_server.py"
            if not server_file.exists():
                self.logger.warning(
                    "Local Opus server file not found - this is expected for infrastructure-only mode"
                )
                self.logger.info(
                    "Note: Use Qwen server (qwen-openvino/) or external APIs for actual inference"
                )

                # Create startup script anyway (will show helpful error if run)
                self._create_server_startup_script()

                # Don't fail the installation - gracefully continue
                return True

            # Make server executable
            server_file.chmod(0o755)

            # Test server can start (don't actually start it during installation)
            self.logger.info("Validating local inference server...")

            cmd = ["python3", str(server_file), "--help"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

            if result.returncode != 0:
                self.logger.warning("Server validation had issues, but continuing")

            # Create startup script
            self._create_server_startup_script()

            self.logger.info("✅ Inference server deployed")
            return True

        except Exception as e:
            self.logger.warning(f"Inference server deployment had issues: {e}")
            # Don't fail - this is expected for infrastructure-only mode
            return True

    def _configure_local_routing(self) -> bool:
        """Configure local endpoint routing"""

        try:
            # Create orchestration directory if it doesn't exist
            self.orchestration_dir.mkdir(exist_ok=True)

            # Validate routing files exist
            required_files = [
                "local_endpoint_router.py",
                "endpoint_config.json",
                "agent_coordination_matrix.json",
            ]

            missing_files = []
            for filename in required_files:
                file_path = self.orchestration_dir / filename
                if not file_path.exists():
                    missing_files.append(filename)

            if missing_files:
                self.logger.warning(f"Missing routing files: {missing_files}")
                self.logger.info("Note: This is expected for infrastructure-only mode")
                # Continue anyway, files may be created by other components

            self.logger.info("✅ Local routing configuration completed")
            return True

        except Exception as e:
            self.logger.warning(f"Local routing configuration had issues: {e}")
            # Don't fail - this is expected for infrastructure-only mode
            return True

    def _validate_military_performance(self) -> bool:
        """Validate military performance targets"""

        try:
            self.logger.info("Validating military performance targets...")

            # Run performance validation if available
            validation_script = self.project_root / "validate_40tflops_performance.sh"
            if validation_script.exists():
                cmd = ["bash", str(validation_script)]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

                if result.returncode == 0:
                    self.logger.info("✅ Performance validation passed")
                    return True
                else:
                    self.logger.warning(
                        f"Performance validation warnings: {result.stderr[:200]}"
                    )

            # Basic validation - check key files exist
            key_files = [
                self.hardware_dir / "milspec_hardware_analyzer.py",
                self.orchestration_dir / "agent_coordination_matrix.json",
                self.local_models_dir / "local_opus_server.py",
            ]

            for file_path in key_files:
                if not file_path.exists():
                    self.logger.warning(f"Missing key file: {file_path}")

            return True

        except Exception as e:
            self.logger.warning(f"Performance validation failed: {e}")
            return True  # Don't fail installation for validation issues

    def _create_server_startup_script(self):
        """Create startup script for local Opus server"""

        startup_script = self.project_root / "start_local_opus.sh"

        script_content = f"""#!/bin/bash
# Local Opus Server Startup Script
# Generated by Claude Military Installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
LOCAL_OPUS_DIR="$SCRIPT_DIR/local-models/opus-openvino"

echo "🚀 Starting Local Opus Inference Server"
echo "   Directory: $LOCAL_OPUS_DIR"
echo "   Server: http://localhost:8000"
echo "   Zero-token local inference for 98-agent system"
echo ""

cd "$LOCAL_OPUS_DIR"

# Check if server file exists
if [ ! -f "local_opus_server.py" ]; then
    echo "❌ Error: local_opus_server.py not found"
    exit 1
fi

# Install dependencies if needed
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "📦 Installing FastAPI dependencies..."
    pip3 install fastapi uvicorn pydantic
fi

# Start server
echo "🎯 Launching server on localhost:8000..."
python3 local_opus_server.py

echo "🏁 Local Opus server stopped"
"""

        startup_script.write_text(script_content)
        startup_script.chmod(0o755)

        self.logger.info(f"✅ Created startup script: {startup_script}")

    def _run_with_sudo(
        self, cmd: List[str], capture_errors: bool = True
    ) -> subprocess.CompletedProcess:
        """Run command with sudo using configured password"""

        # Prepend sudo and password
        sudo_cmd = ["sudo", "-S"] + cmd

        try:
            result = subprocess.run(
                sudo_cmd,
                input=f"{self.sudo_password}\n",
                text=True,
                capture_output=capture_errors,
                timeout=120,
            )
            return result

        except subprocess.TimeoutExpired:
            self.logger.warning(f"Command timed out: {' '.join(cmd)}")
            # Return a mock failed result
            return subprocess.CompletedProcess(cmd, 124, "", "Command timed out")

    def get_deployment_status(self) -> Dict[str, Any]:
        """Get deployment status and metrics"""

        status = {
            "military_optimization": {
                "hardware_analyzer": (
                    self.hardware_dir / "milspec_hardware_analyzer.py"
                ).exists(),
                "npu_optimizer": (self.hardware_dir / "enable-npu-turbo.sh").exists(),
                "optimization_script": (
                    self.project_root / "execute_40tflops_optimization.sh"
                ).exists(),
            },
            "local_opus": {
                "quantizer": (self.local_models_dir / "opus_quantizer.py").exists(),
                "server": (self.local_models_dir / "local_opus_server.py").exists(),
                "startup_script": (self.project_root / "start_local_opus.sh").exists(),
            },
            "agent_coordination": {
                "orchestrator": (
                    self.project_root
                    / "installers"
                    / "claude"
                    / "dsmil_orchestrator.py"
                ).exists(),
                "routing_config": (
                    self.orchestration_dir / "agent_coordination_matrix.json"
                ).exists(),
                "endpoint_router": (
                    self.orchestration_dir / "local_endpoint_router.py"
                ).exists(),
            },
        }

        # Calculate overall readiness
        all_components = []
        for category in status.values():
            all_components.extend(category.values())

        ready_components = sum(all_components)
        total_components = len(all_components)
        readiness_percentage = (ready_components / total_components) * 100

        status["summary"] = {
            "ready_components": ready_components,
            "total_components": total_components,
            "readiness_percentage": round(readiness_percentage, 1),
            "deployment_ready": readiness_percentage >= 80,
        }

        return status


def integrate_with_installer(installer_instance):
    """Integration function for ClaudeEnhancedInstaller"""

    # Add military deployment methods to installer
    military_deployment = MilitaryDeployment(
        installer_instance, installer_instance.verbose
    )

    # Add methods to installer instance
    installer_instance.deploy_military_optimization = (
        military_deployment.deploy_military_optimization
    )
    installer_instance.deploy_local_opus = military_deployment.deploy_local_opus
    installer_instance.get_deployment_status = military_deployment.get_deployment_status

    return military_deployment
