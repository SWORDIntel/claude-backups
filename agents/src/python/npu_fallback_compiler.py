#!/usr/bin/env python3
"""
NPU Bridge Fallback Compilation System
Intelligent fallback for when pre-built binaries are unavailable
Handles edge cases and custom compilation requirements
"""

import os
import sys
import subprocess
import platform
import tempfile
import shutil
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class CompilationConfig:
    """Compilation configuration"""
    target_triple: str
    rust_version: str
    features: List[str]
    optimization_level: str
    lto_enabled: bool
    codegen_units: int
    target_cpu: str
    target_features: List[str]
    environment_vars: Dict[str, str]
    compiler_flags: List[str]
    linker_flags: List[str]

@dataclass
class CompilationResult:
    """Compilation result metadata"""
    success: bool
    duration_seconds: float
    output_files: List[str]
    binary_size_bytes: int
    error_log: str
    warnings: List[str]
    performance_features: List[str]
    fallback_reason: str

class NPUFallbackCompiler:
    """
    Intelligent fallback compilation system for NPU bridge
    Handles custom compilation when pre-built binaries fail
    """

    def __init__(self, source_dir: str, output_dir: str = None):
        self.source_dir = Path(source_dir)
        self.output_dir = Path(output_dir or tempfile.mkdtemp(prefix="npu-compile-"))
        self.cargo_toml_path = self.source_dir / "Cargo.toml"

        # Verify source directory
        if not self.cargo_toml_path.exists():
            raise ValueError(f"No Cargo.toml found in {source_dir}")

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Compilation state
        self.compilation_log = []
        self.detected_capabilities = self._detect_system_capabilities()

    def _detect_system_capabilities(self) -> Dict[str, Any]:
        """Detect system compilation capabilities"""
        capabilities = {
            "platform": platform.platform(),
            "architecture": platform.architecture(),
            "cpu_count": os.cpu_count(),
            "has_rust": False,
            "rust_version": None,
            "has_gcc": False,
            "gcc_version": None,
            "has_clang": False,
            "clang_version": None,
            "cpu_features": [],
            "available_targets": [],
            "memory_mb": self._get_available_memory(),
            "disk_space_mb": self._get_available_disk_space(),
        }

        # Check Rust installation
        try:
            result = subprocess.run(
                ["rustc", "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                capabilities["has_rust"] = True
                capabilities["rust_version"] = result.stdout.strip()

                # Get available targets
                target_result = subprocess.run(
                    ["rustc", "--print", "target-list"], capture_output=True, text=True, timeout=10
                )
                if target_result.returncode == 0:
                    capabilities["available_targets"] = target_result.stdout.strip().split('\n')

        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Check GCC
        try:
            result = subprocess.run(
                ["gcc", "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                capabilities["has_gcc"] = True
                capabilities["gcc_version"] = result.stdout.split('\n')[0]
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Check Clang
        try:
            result = subprocess.run(
                ["clang", "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                capabilities["has_clang"] = True
                capabilities["clang_version"] = result.stdout.split('\n')[0]
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Detect CPU features
        capabilities["cpu_features"] = self._detect_cpu_features()

        return capabilities

    def _detect_cpu_features(self) -> List[str]:
        """Detect available CPU features"""
        features = []

        try:
            if platform.system().lower() == "linux":
                with open("/proc/cpuinfo", "r") as f:
                    cpuinfo = f.read()

                # Extract flags line
                for line in cpuinfo.split('\n'):
                    if line.startswith('flags'):
                        flags = line.split(':')[1].strip().split()
                        return flags

        except FileNotFoundError:
            pass

        return features

    def _get_available_memory(self) -> int:
        """Get available memory in MB"""
        try:
            if platform.system().lower() == "linux":
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        if line.startswith("MemAvailable:"):
                            return int(line.split()[1]) // 1024  # Convert KB to MB
        except FileNotFoundError:
            pass

        return 4096  # Default assumption

    def _get_available_disk_space(self) -> int:
        """Get available disk space in MB"""
        try:
            statvfs = os.statvfs(self.output_dir)
            available_bytes = statvfs.f_frsize * statvfs.f_bavail
            return available_bytes // (1024 * 1024)  # Convert to MB
        except OSError:
            return 10240  # Default assumption

    def detect_fallback_reason(self) -> List[str]:
        """Detect why fallback compilation is needed"""
        reasons = []

        # Check system requirements
        if not self.detected_capabilities["has_rust"]:
            reasons.append("rust_not_installed")

        if self.detected_capabilities["memory_mb"] < 2048:
            reasons.append("insufficient_memory")

        if self.detected_capabilities["disk_space_mb"] < 1024:
            reasons.append("insufficient_disk_space")

        # Check for uncommon architecture
        arch = platform.machine().lower()
        if arch not in ["x86_64", "amd64"]:
            reasons.append(f"unsupported_architecture_{arch}")

        # Check for old CPU without modern instruction sets
        cpu_features = self.detected_capabilities["cpu_features"]
        if "avx2" not in cpu_features and "avx" not in cpu_features:
            reasons.append("legacy_cpu_no_vector_extensions")

        # Check for unusual platform
        system = platform.system().lower()
        if system not in ["linux", "windows", "darwin"]:
            reasons.append(f"unsupported_platform_{system}")

        return reasons

    def generate_compilation_config(self, fallback_reasons: List[str]) -> CompilationConfig:
        """Generate compilation configuration based on system capabilities"""
        cpu_features = self.detected_capabilities["cpu_features"]
        available_targets = self.detected_capabilities["available_targets"]

        # Determine target triple
        system = platform.system().lower()
        if system == "linux":
            # Check if musl is preferred for portability
            if "static_linking_required" in fallback_reasons:
                target_triple = "x86_64-unknown-linux-musl"
            else:
                target_triple = "x86_64-unknown-linux-gnu"
        elif system == "windows":
            target_triple = "x86_64-pc-windows-msvc"
        elif system == "darwin":
            target_triple = "x86_64-apple-darwin"
        else:
            target_triple = "x86_64-unknown-linux-gnu"  # Default fallback

        # Ensure target is available
        if target_triple not in available_targets:
            logger.warning(f"Target {target_triple} not available, using default")
            target_triple = "x86_64-unknown-linux-gnu"

        # Determine optimization level based on constraints
        if "insufficient_memory" in fallback_reasons:
            optimization_level = "2"  # Lower memory usage
            lto_enabled = False
            codegen_units = 16  # More parallel units, less memory per unit
        else:
            optimization_level = "3"
            lto_enabled = True
            codegen_units = 1

        # Determine CPU target and features
        if "avx512f" in cpu_features and "legacy_cpu" not in str(fallback_reasons):
            target_cpu = "skylake-avx512"
            target_features = ["+avx512f", "+avx512dq", "+fma"]
        elif "avx2" in cpu_features:
            target_cpu = "haswell"
            target_features = ["+avx2", "+fma"]
        elif "avx" in cpu_features:
            target_cpu = "sandybridge"
            target_features = ["+avx"]
        else:
            target_cpu = "x86-64"
            target_features = []

        # Determine features
        features = ["python-bindings"]  # Always include Python bindings

        # Add hardware features if supported
        if "avx512f" in cpu_features:
            features.append("avx512")
        elif "avx2" in cpu_features:
            features.append("avx2")

        # Intel NPU feature (assume available on Intel systems)
        processor = self.detected_capabilities.get("processor", "").lower()
        if "intel" in processor or any("intel" in flag for flag in cpu_features):
            features.append("intel-npu")

        # Environment variables
        env_vars = {
            "CARGO_TARGET_DIR": str(self.output_dir / "target"),
            "RUST_BACKTRACE": "1",
        }

        # Compiler-specific settings
        compiler_flags = [f"-O{optimization_level}"]
        linker_flags = []

        if self.detected_capabilities["has_gcc"]:
            env_vars["CC"] = "gcc"
            env_vars["CXX"] = "g++"
        elif self.detected_capabilities["has_clang"]:
            env_vars["CC"] = "clang"
            env_vars["CXX"] = "clang++"

        # Add CPU-specific flags
        if target_cpu != "x86-64":
            compiler_flags.append(f"-march={target_cpu}")

        if target_features:
            features_str = ",".join(target_features)
            env_vars["RUSTFLAGS"] = f"-C target-cpu={target_cpu} -C target-feature={features_str} -C opt-level={optimization_level}"
        else:
            env_vars["RUSTFLAGS"] = f"-C target-cpu={target_cpu} -C opt-level={optimization_level}"

        if lto_enabled:
            env_vars["RUSTFLAGS"] += " -C lto=fat"

        if codegen_units != 16:  # 16 is default
            env_vars["RUSTFLAGS"] += f" -C codegen-units={codegen_units}"

        return CompilationConfig(
            target_triple=target_triple,
            rust_version=self.detected_capabilities.get("rust_version", "unknown"),
            features=features,
            optimization_level=optimization_level,
            lto_enabled=lto_enabled,
            codegen_units=codegen_units,
            target_cpu=target_cpu,
            target_features=target_features,
            environment_vars=env_vars,
            compiler_flags=compiler_flags,
            linker_flags=linker_flags
        )

    def install_dependencies(self) -> bool:
        """Install required compilation dependencies"""
        logger.info("Installing compilation dependencies...")

        # Install Rust if not available
        if not self.detected_capabilities["has_rust"]:
            logger.info("Installing Rust toolchain...")
            if not self._install_rust():
                return False

        # Install target if needed
        config = self.generate_compilation_config(self.detect_fallback_reason())
        if config.target_triple not in self.detected_capabilities["available_targets"]:
            logger.info(f"Installing Rust target: {config.target_triple}")
            if not self._install_rust_target(config.target_triple):
                return False

        # Install system dependencies
        if not self._install_system_dependencies():
            return False

        return True

    def _install_rust(self) -> bool:
        """Install Rust toolchain"""
        try:
            # Download and run rustup installer
            logger.info("Downloading rustup installer...")
            result = subprocess.run([
                "curl", "--proto", "=https", "--tlsv1.2", "-sSf",
                "https://sh.rustup.rs", "-o", "/tmp/rustup.sh"
            ], check=True, timeout=60)

            # Run installer
            logger.info("Running rustup installer...")
            result = subprocess.run([
                "sh", "/tmp/rustup.sh", "-y", "--default-toolchain", "stable"
            ], check=True, timeout=300)

            # Source environment
            rustup_env = os.path.expanduser("~/.cargo/env")
            if os.path.exists(rustup_env):
                # Add to current environment
                os.environ["PATH"] = f"{os.path.expanduser('~/.cargo/bin')}:{os.environ.get('PATH', '')}"

            return True

        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            logger.error(f"Failed to install Rust: {e}")
            return False

    def _install_rust_target(self, target: str) -> bool:
        """Install specific Rust target"""
        try:
            result = subprocess.run([
                "rustup", "target", "add", target
            ], check=True, timeout=120)
            return True
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            logger.error(f"Failed to install target {target}: {e}")
            return False

    def _install_system_dependencies(self) -> bool:
        """Install system-level dependencies"""
        system = platform.system().lower()

        if system == "linux":
            return self._install_linux_dependencies()
        elif system == "darwin":
            return self._install_macos_dependencies()
        elif system == "windows":
            return self._install_windows_dependencies()

        return True  # Unknown system, assume dependencies are available

    def _install_linux_dependencies(self) -> bool:
        """Install Linux dependencies"""
        # Try to detect package manager and install dependencies
        dependencies = [
            "build-essential", "pkg-config", "libssl-dev", "libudev-dev"
        ]

        # Try apt (Debian/Ubuntu)
        if shutil.which("apt-get"):
            try:
                logger.info("Installing dependencies via apt...")
                subprocess.run([
                    "sudo", "apt-get", "update", "-qq"
                ], check=True, timeout=60)
                subprocess.run([
                    "sudo", "apt-get", "install", "-y"
                ] + dependencies, check=True, timeout=300)
                return True
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        # Try yum (RHEL/CentOS/Fedora)
        if shutil.which("yum"):
            try:
                logger.info("Installing dependencies via yum...")
                rhel_deps = ["gcc", "gcc-c++", "pkgconfig", "openssl-devel", "libudev-devel"]
                subprocess.run([
                    "sudo", "yum", "install", "-y"
                ] + rhel_deps, check=True, timeout=300)
                return True
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        # Try pacman (Arch)
        if shutil.which("pacman"):
            try:
                logger.info("Installing dependencies via pacman...")
                arch_deps = ["base-devel", "openssl", "pkgconf"]
                subprocess.run([
                    "sudo", "pacman", "-S", "--noconfirm"
                ] + arch_deps, check=True, timeout=300)
                return True
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        logger.warning("Could not install system dependencies automatically")
        return False

    def _install_macos_dependencies(self) -> bool:
        """Install macOS dependencies"""
        # Try Homebrew
        if shutil.which("brew"):
            try:
                logger.info("Installing dependencies via Homebrew...")
                subprocess.run([
                    "brew", "install", "pkg-config", "openssl"
                ], check=True, timeout=300)
                return True
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        logger.warning("Homebrew not available, dependencies may need manual installation")
        return False

    def _install_windows_dependencies(self) -> bool:
        """Install Windows dependencies"""
        # On Windows, Rust typically handles this automatically
        logger.info("Windows dependency installation handled by Rust toolchain")
        return True

    def compile_npu_bridge(self, config: CompilationConfig) -> CompilationResult:
        """Compile NPU bridge with given configuration"""
        logger.info(f"Compiling NPU bridge with target: {config.target_triple}")

        start_time = __import__("time").time()
        output_files = []
        error_log = ""
        warnings = []

        try:
            # Prepare environment
            env = os.environ.copy()
            env.update(config.environment_vars)

            # Build command
            cmd = [
                "cargo", "build",
                "--release",
                "--target", config.target_triple,
                "--features", ",".join(config.features)
            ]

            # Run compilation
            logger.info(f"Running: {' '.join(cmd)}")
            logger.info(f"Features: {', '.join(config.features)}")
            logger.info(f"Target CPU: {config.target_cpu}")

            result = subprocess.run(
                cmd,
                cwd=self.source_dir,
                env=env,
                capture_output=True,
                text=True,
                timeout=1800  # 30 minutes max
            )

            # Parse output
            if result.stderr:
                error_log = result.stderr
                # Extract warnings
                for line in result.stderr.split('\n'):
                    if 'warning:' in line.lower():
                        warnings.append(line.strip())

            success = result.returncode == 0

            if success:
                # Find output files
                target_dir = self.output_dir / "target" / config.target_triple / "release"

                # Look for library files
                for pattern in ["libnpu_coordination_bridge.*", "npu-bridge-server*"]:
                    for file_path in target_dir.glob(pattern):
                        if file_path.is_file():
                            output_files.append(str(file_path))

                logger.info(f"Compilation successful, {len(output_files)} files generated")
            else:
                logger.error(f"Compilation failed with code {result.returncode}")

        except subprocess.TimeoutExpired:
            success = False
            error_log = "Compilation timed out after 30 minutes"
            logger.error(error_log)

        except Exception as e:
            success = False
            error_log = str(e)
            logger.error(f"Compilation error: {e}")

        duration = __import__("time").time() - start_time

        # Calculate binary size
        binary_size = 0
        for file_path in output_files:
            try:
                binary_size += Path(file_path).stat().st_size
            except OSError:
                pass

        # Determine performance features
        performance_features = []
        if "avx512" in config.features:
            performance_features.append("AVX-512")
        elif "avx2" in config.features:
            performance_features.append("AVX2")
        if "intel-npu" in config.features:
            performance_features.append("Intel NPU")
        if config.lto_enabled:
            performance_features.append("LTO")

        return CompilationResult(
            success=success,
            duration_seconds=duration,
            output_files=output_files,
            binary_size_bytes=binary_size,
            error_log=error_log,
            warnings=warnings,
            performance_features=performance_features,
            fallback_reason=", ".join(self.detect_fallback_reason())
        )

    def create_installation_package(self, compilation_result: CompilationResult, package_path: str) -> bool:
        """Create installation package from compilation result"""
        if not compilation_result.success:
            logger.error("Cannot create package from failed compilation")
            return False

        package_dir = Path(package_path).parent / "npu-bridge-fallback-build"
        package_dir.mkdir(parents=True, exist_ok=True)

        try:
            # Copy binaries
            for file_path in compilation_result.output_files:
                src_path = Path(file_path)
                dst_path = package_dir / src_path.name
                shutil.copy2(src_path, dst_path)
                logger.info(f"Copied: {src_path.name}")

            # Create build info
            build_info = {
                "compilation_result": asdict(compilation_result),
                "system_capabilities": self.detected_capabilities,
                "build_timestamp": __import__("time").time(),
                "fallback_build": True,
            }

            with open(package_dir / "BUILD_INFO.json", 'w') as f:
                json.dump(build_info, f, indent=2)

            # Create installation script
            install_script = f'''#!/bin/bash
set -euo pipefail

INSTALL_DIR="${{1:-/usr/local}}"
BIN_DIR="${{INSTALL_DIR}}/bin"
LIB_DIR="${{INSTALL_DIR}}/lib"

echo "Installing NPU Bridge (Fallback Build) to ${{INSTALL_DIR}}"

mkdir -p "${{BIN_DIR}}" "${{LIB_DIR}}"

# Install binaries
for binary in npu-bridge-server*; do
    if [[ -f "$binary" && -x "$binary" ]]; then
        cp "$binary" "${{BIN_DIR}}/"
        chmod +x "${{BIN_DIR}}/$binary"
        echo "Installed: ${{BIN_DIR}}/$binary"
    fi
done

# Install libraries
for lib in libnpu_coordination_bridge.*; do
    if [[ -f "$lib" ]]; then
        cp "$lib" "${{LIB_DIR}}/"
        echo "Installed: ${{LIB_DIR}}/$lib"
    fi
done

echo "Fallback build installation complete!"
echo "Build features: {", ".join(compilation_result.performance_features)}"
echo "Build reason: {compilation_result.fallback_reason}"
'''

            with open(package_dir / "install.sh", 'w') as f:
                f.write(install_script)
            os.chmod(package_dir / "install.sh", 0o755)

            # Create tarball
            import tarfile
            with tarfile.open(package_path, 'w:gz') as tar:
                tar.add(package_dir, arcname=package_dir.name)

            logger.info(f"Installation package created: {package_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to create package: {e}")
            return False

    def run_fallback_compilation(self, install_dir: str = "/usr/local") -> bool:
        """Run complete fallback compilation workflow"""
        logger.info("Starting fallback compilation workflow...")

        # Detect why fallback is needed
        fallback_reasons = self.detect_fallback_reason()
        logger.info(f"Fallback reasons: {', '.join(fallback_reasons) if fallback_reasons else 'forced compilation'}")

        # Install dependencies
        if not self.install_dependencies():
            logger.error("Failed to install dependencies")
            return False

        # Generate compilation config
        config = self.generate_compilation_config(fallback_reasons)
        logger.info(f"Compilation config: {config.target_triple} with {', '.join(config.features)}")

        # Compile
        result = self.compile_npu_bridge(config)

        if result.success:
            logger.info(f"Compilation successful in {result.duration_seconds:.1f} seconds")
            logger.info(f"Binary size: {result.binary_size_bytes / 1024 / 1024:.1f} MB")
            logger.info(f"Performance features: {', '.join(result.performance_features)}")

            # Create package
            package_path = self.output_dir / "npu-bridge-fallback.tar.gz"
            if self.create_installation_package(result, str(package_path)):
                # Install directly
                return self._install_from_package(package_path, install_dir)
            else:
                return False
        else:
            logger.error("Compilation failed")
            if result.error_log:
                logger.error(f"Error details: {result.error_log}")
            return False

    def _install_from_package(self, package_path: Path, install_dir: str) -> bool:
        """Install from created package"""
        try:
            # Extract package
            temp_dir = tempfile.mkdtemp(prefix="npu-install-")

            import tarfile
            with tarfile.open(package_path, 'r:gz') as tar:
                tar.extractall(temp_dir)

            # Find extracted directory
            extracted_dirs = [d for d in Path(temp_dir).iterdir() if d.is_dir()]
            if not extracted_dirs:
                raise ValueError("No extracted directory found")

            extracted_dir = extracted_dirs[0]

            # Run installation script
            install_script = extracted_dir / "install.sh"
            result = subprocess.run([
                str(install_script), install_dir
            ], check=True, timeout=60)

            logger.info(f"Installation completed to {install_dir}")
            return True

        except Exception as e:
            logger.error(f"Installation failed: {e}")
            return False
        finally:
            if 'temp_dir' in locals():
                shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    """Command-line interface for fallback compiler"""
    import argparse

    parser = argparse.ArgumentParser(
        description="NPU Bridge Fallback Compilation System"
    )
    parser.add_argument(
        "--source-dir",
        default="/home/john/claude-backups/agents/src/rust/npu_coordination_bridge",
        help="Source directory containing Cargo.toml"
    )
    parser.add_argument(
        "--output-dir",
        help="Output directory for compilation"
    )
    parser.add_argument(
        "--install-dir",
        default="/usr/local",
        help="Installation directory"
    )
    parser.add_argument(
        "--detect-only",
        action="store_true",
        help="Only detect capabilities and fallback reasons"
    )
    parser.add_argument(
        "--install-deps",
        action="store_true",
        help="Install compilation dependencies"
    )
    parser.add_argument(
        "--compile",
        action="store_true",
        help="Run compilation workflow"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Verbose output"
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        compiler = NPUFallbackCompiler(args.source_dir, args.output_dir)

        if args.detect_only:
            print("🔍 System Capabilities:")
            caps = compiler.detected_capabilities
            print(f"   Platform: {caps['platform']}")
            print(f"   Rust: {'✅' if caps['has_rust'] else '❌'} {caps.get('rust_version', '')}")
            print(f"   GCC: {'✅' if caps['has_gcc'] else '❌'} {caps.get('gcc_version', '')}")
            print(f"   Memory: {caps['memory_mb']} MB")
            print(f"   CPU Features: {len(caps['cpu_features'])} detected")

            fallback_reasons = compiler.detect_fallback_reason()
            if fallback_reasons:
                print(f"\n⚠️  Fallback Reasons:")
                for reason in fallback_reasons:
                    print(f"   - {reason}")
            else:
                print("\n✅ No fallback reasons detected")

        elif args.install_deps:
            success = compiler.install_dependencies()
            if success:
                print("✅ Dependencies installed successfully")
            else:
                print("❌ Failed to install dependencies")
                sys.exit(1)

        elif args.compile:
            success = compiler.run_fallback_compilation(args.install_dir)
            if success:
                print("✅ Fallback compilation and installation successful")
            else:
                print("❌ Fallback compilation failed")
                sys.exit(1)

        else:
            # Default: run full workflow
            success = compiler.run_fallback_compilation(args.install_dir)
            if success:
                print("✅ Fallback compilation completed successfully")
            else:
                print("❌ Fallback compilation failed")
                sys.exit(1)

    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()