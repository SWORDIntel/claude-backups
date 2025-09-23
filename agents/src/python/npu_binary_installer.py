#!/usr/bin/env python3
"""
NPU Bridge Binary Installer
High-speed installation system for pre-compiled NPU coordination bridge
Target: 30-second installation with hardware detection
"""

import os
import sys
import json
import tarfile
import tempfile
import platform
import subprocess
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import hashlib
import time

class NPUBinaryInstaller:
    """
    Fast binary installer for NPU coordination bridge
    Downloads pre-compiled binaries and installs in <30 seconds
    """

    GITHUB_REPO = "SWORDIntel/claude-backups"
    BASE_URL = f"https://github.com/{GITHUB_REPO}/releases"

    def __init__(self,
                 install_dir: Optional[str] = None,
                 version: str = "latest",
                 force_target: Optional[str] = None):
        self.install_dir = Path(install_dir or "/usr/local")
        self.version = version
        self.force_target = force_target
        self.temp_dir = None

        # Installation paths
        self.bin_dir = self.install_dir / "bin"
        self.lib_dir = self.install_dir / "lib"
        self.config_dir = self.install_dir / "etc" / "npu-bridge"

        # Performance tracking
        self.start_time = time.time()
        self.download_start = None
        self.download_size = 0

    def log(self, message: str, level: str = "INFO"):
        """Structured logging with timing"""
        elapsed = time.time() - self.start_time
        print(f"[{elapsed:6.2f}s] [{level}] {message}")

    def detect_hardware(self) -> Tuple[str, List[str]]:
        """
        Detect hardware capabilities for optimal binary selection
        Returns: (target_triple, feature_list)
        """
        if self.force_target:
            return self.force_target, ["intel-npu"]

        self.log("Detecting hardware capabilities...")

        # Base target
        target = "x86_64-unknown-linux-gnu"
        features = ["intel-npu"]

        try:
            # Check CPU flags
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()

            if "avx512f" in cpuinfo:
                features.extend(["avx512", "meteor-lake"])
                self.log("Detected AVX-512 support (Meteor Lake optimized)")
            elif "avx2" in cpuinfo:
                features.extend(["avx2", "fma"])
                self.log("Detected AVX2/FMA support (Haswell+ optimized)")
            else:
                target = "x86_64-unknown-linux-musl"
                features.append("static")
                self.log("Using portable static build")

        except FileNotFoundError:
            self.log("Cannot read /proc/cpuinfo, using portable build", "WARN")
            target = "x86_64-unknown-linux-musl"
            features.append("static")

        # Check for Intel NPU
        npu_detected = False
        try:
            # Check for Intel graphics (NPU usually comes with Intel iGPU)
            result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=5)
            if "Intel" in result.stdout and ("VGA" in result.stdout or "Display" in result.stdout):
                npu_detected = True
                self.log("Intel graphics detected - NPU support likely available")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Check for NPU device files
        if Path("/dev/accel").exists():
            accel_devices = list(Path("/dev/accel").glob("accel*"))
            if accel_devices:
                npu_detected = True
                self.log(f"NPU acceleration devices detected: {len(accel_devices)}")

        if not npu_detected:
            self.log("No Intel NPU detected - basic functionality only", "WARN")

        return target, features

    def get_latest_version(self) -> str:
        """Get latest release version from GitHub API"""
        if self.version != "latest":
            return self.version

        self.log("Fetching latest release version...")

        api_url = f"https://api.github.com/repos/{self.GITHUB_REPO}/releases/latest"

        try:
            with urllib.request.urlopen(api_url, timeout=10) as response:
                data = json.loads(response.read().decode())
                version = data["tag_name"]
                self.log(f"Latest version: {version}")
                return version
        except Exception as e:
            self.log(f"Failed to fetch latest version: {e}", "ERROR")
            # Fallback to hardcoded version
            return "v2.0.0"

    def download_binary(self, target: str, features: List[str]) -> Path:
        """Download pre-compiled binary package"""
        version = self.get_latest_version()

        # Construct package name
        package_name = f"npu-coordination-bridge-{version}-{target}"
        package_url = f"{self.BASE_URL}/download/{version}/{package_name}.tar.gz"

        self.log(f"Downloading: {package_name}")
        self.log(f"URL: {package_url}")

        # Create temporary directory
        self.temp_dir = tempfile.mkdtemp(prefix="npu-bridge-install-")
        package_path = Path(self.temp_dir) / f"{package_name}.tar.gz"

        # Download with progress and retry logic
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                self.log(f"Download attempt {attempt}/{max_attempts}")
                self.download_start = time.time()

                # Use urllib with timeout and progress
                with urllib.request.urlopen(package_url, timeout=30) as response:
                    total_size = int(response.headers.get('Content-Length', 0))
                    self.download_size = total_size

                    if total_size > 0:
                        self.log(f"Package size: {total_size / 1024 / 1024:.1f} MB")

                    with open(package_path, 'wb') as f:
                        downloaded = 0
                        chunk_size = 8192

                        while True:
                            chunk = response.read(chunk_size)
                            if not chunk:
                                break
                            f.write(chunk)
                            downloaded += len(chunk)

                            # Progress indicator (every 1MB)
                            if downloaded % (1024 * 1024) == 0 and total_size > 0:
                                progress = (downloaded / total_size) * 100
                                speed = downloaded / (time.time() - self.download_start) / 1024 / 1024
                                self.log(f"Progress: {progress:.1f}% ({speed:.1f} MB/s)")

                download_time = time.time() - self.download_start
                speed = (package_path.stat().st_size / 1024 / 1024) / download_time
                self.log(f"Download completed: {speed:.1f} MB/s")

                # Verify download
                if package_path.stat().st_size < 1024:  # Less than 1KB is suspicious
                    raise ValueError("Downloaded file too small")

                return package_path

            except Exception as e:
                self.log(f"Download attempt {attempt} failed: {e}", "WARN")
                if attempt == max_attempts:
                    raise RuntimeError(f"Failed to download after {max_attempts} attempts")
                time.sleep(2)  # Wait before retry

    def extract_package(self, package_path: Path) -> Path:
        """Extract downloaded package"""
        self.log("Extracting package...")

        extract_dir = package_path.parent

        try:
            with tarfile.open(package_path, 'r:gz') as tar:
                # Security check - ensure no path traversal
                for member in tar.getmembers():
                    if member.name.startswith('/') or '..' in member.name:
                        raise ValueError(f"Unsafe path in archive: {member.name}")

                tar.extractall(path=extract_dir)

            # Find extracted directory
            extracted_dirs = [d for d in extract_dir.iterdir()
                            if d.is_dir() and d.name.startswith("npu-coordination-bridge")]

            if not extracted_dirs:
                raise ValueError("No extracted directory found")

            extracted_dir = extracted_dirs[0]
            self.log(f"Package extracted to: {extracted_dir}")

            return extracted_dir

        except Exception as e:
            raise RuntimeError(f"Failed to extract package: {e}")

    def install_binaries(self, extracted_dir: Path) -> None:
        """Install binaries to target directories"""
        self.log("Installing binaries...")

        # Create installation directories
        self.bin_dir.mkdir(parents=True, exist_ok=True)
        self.lib_dir.mkdir(parents=True, exist_ok=True)
        self.config_dir.mkdir(parents=True, exist_ok=True)

        installed_files = []

        # Install server binary
        server_binary = extracted_dir / "npu-bridge-server"
        if server_binary.exists():
            target_binary = self.bin_dir / "npu-bridge-server"
            self._copy_file(server_binary, target_binary)
            target_binary.chmod(0o755)
            installed_files.append(target_binary)
            self.log(f"Installed server: {target_binary}")

        # Install libraries
        for lib_pattern in ["libnpu_coordination_bridge.*", "*.so", "*.dylib", "*.dll"]:
            for lib_file in extracted_dir.glob(lib_pattern):
                if lib_file.is_file():
                    target_lib = self.lib_dir / lib_file.name
                    self._copy_file(lib_file, target_lib)
                    target_lib.chmod(0o644)
                    installed_files.append(target_lib)
                    self.log(f"Installed library: {target_lib}")

        # Install build info
        build_info = extracted_dir / "BUILD_INFO.json"
        if build_info.exists():
            target_info = self.config_dir / "BUILD_INFO.json"
            self._copy_file(build_info, target_info)
            installed_files.append(target_info)

        # Create installation manifest
        manifest = {
            "version": self.version,
            "install_time": time.time(),
            "install_dir": str(self.install_dir),
            "installed_files": [str(f) for f in installed_files],
            "installer_version": "1.0.0"
        }

        manifest_file = self.config_dir / "install_manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)

        self.log(f"Installation manifest: {manifest_file}")

    def _copy_file(self, src: Path, dst: Path) -> None:
        """Copy file with error handling"""
        try:
            import shutil
            shutil.copy2(src, dst)
        except Exception as e:
            raise RuntimeError(f"Failed to copy {src} to {dst}: {e}")

    def verify_installation(self) -> bool:
        """Verify installation success"""
        self.log("Verifying installation...")

        # Check server binary
        server_binary = self.bin_dir / "npu-bridge-server"
        if not server_binary.exists():
            self.log("Server binary not found", "ERROR")
            return False

        # Test execution (basic help)
        try:
            result = subprocess.run([str(server_binary), "--version"],
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                self.log(f"Server version: {result.stdout.strip()}")
            else:
                self.log("Server binary may need runtime dependencies", "WARN")
        except Exception as e:
            self.log(f"Cannot verify server execution: {e}", "WARN")

        # Check for libraries
        lib_count = len(list(self.lib_dir.glob("libnpu_coordination_bridge.*")))
        if lib_count == 0:
            self.log("No NPU bridge libraries found", "WARN")
        else:
            self.log(f"Found {lib_count} NPU bridge libraries")

        return True

    def cleanup(self) -> None:
        """Clean up temporary files"""
        if self.temp_dir and Path(self.temp_dir).exists():
            import shutil
            shutil.rmtree(self.temp_dir)
            self.log("Cleaned up temporary files")

    def run_performance_test(self) -> None:
        """Run quick performance test"""
        server_binary = self.bin_dir / "npu-bridge-server"
        if not server_binary.exists():
            return

        self.log("Running performance test...")
        try:
            # Run 5-second benchmark
            result = subprocess.run([
                str(server_binary),
                "--benchmark",
                "--duration", "5000",
                "--operation", "inference"
            ], capture_output=True, text=True, timeout=15)

            if result.returncode == 0:
                self.log("Performance test completed successfully")
                # Extract performance metrics from output
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'ops/sec' in line or 'throughput' in line:
                        self.log(f"Performance: {line.strip()}")
            else:
                self.log("Performance test failed (may need NPU hardware)", "WARN")

        except Exception as e:
            self.log(f"Performance test error: {e}", "WARN")

    def install(self) -> bool:
        """Main installation workflow"""
        try:
            self.log("Starting NPU Bridge Binary Installation")
            self.log(f"Target directory: {self.install_dir}")

            # Detect hardware
            target, features = self.detect_hardware()
            self.log(f"Target: {target}, Features: {', '.join(features)}")

            # Download binary
            package_path = self.download_binary(target, features)

            # Extract package
            extracted_dir = self.extract_package(package_path)

            # Install binaries
            self.install_binaries(extracted_dir)

            # Verify installation
            if not self.verify_installation():
                self.log("Installation verification failed", "ERROR")
                return False

            # Optional performance test
            if os.getenv("RUN_PERFORMANCE_TEST") == "1":
                self.run_performance_test()

            total_time = time.time() - self.start_time
            self.log(f"Installation completed successfully in {total_time:.1f} seconds! 🚀")

            # Show usage info
            self.log("Usage: npu-bridge-server --help")
            if str(self.bin_dir) not in os.environ.get("PATH", ""):
                self.log(f"Add to PATH: export PATH={self.bin_dir}:$PATH")

            return True

        except Exception as e:
            self.log(f"Installation failed: {e}", "ERROR")
            return False
        finally:
            self.cleanup()


def main():
    """Command-line interface"""
    import argparse

    parser = argparse.ArgumentParser(
        description="NPU Bridge Binary Installer - Fast pre-compiled binary installation"
    )
    parser.add_argument(
        "--install-dir",
        default="/usr/local",
        help="Installation directory (default: /usr/local)"
    )
    parser.add_argument(
        "--version",
        default="latest",
        help="Version to install (default: latest)"
    )
    parser.add_argument(
        "--target",
        help="Force specific target (e.g., x86_64-unknown-linux-gnu)"
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Run performance test after installation"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Verbose output"
    )

    args = parser.parse_args()

    # Set environment variables
    if args.test:
        os.environ["RUN_PERFORMANCE_TEST"] = "1"

    # Create installer
    installer = NPUBinaryInstaller(
        install_dir=args.install_dir,
        version=args.version,
        force_target=args.target
    )

    # Run installation
    success = installer.install()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()