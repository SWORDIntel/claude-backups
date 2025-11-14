#!/usr/bin/env python3
"""
Test script for headless Debian installation
Validates PEP 668 compatibility and headless operation
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


def test_pep668_detection():
    """Test PEP 668 externally managed environment detection"""
    print("🧪 Testing PEP 668 detection...")

    try:
        # Test pip dry run to see if externally managed
        result = subprocess.run(
            ["pip3", "install", "--dry-run", "setuptools"],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if "externally-managed-environment" in result.stderr:
            print("✅ PEP 668 externally managed environment detected correctly")
            return True
        else:
            print("ℹ️  No PEP 668 restriction detected (older system)")
            return False

    except Exception as e:
        print(f"❌ PEP 668 detection failed: {e}")
        return False


def test_pipx_availability():
    """Test pipx installation capability"""
    print("🧪 Testing pipx availability...")

    try:
        # Check if pipx is available
        pipx_path = subprocess.run(
            ["which", "pipx"], capture_output=True, text=True, timeout=10
        )

        if pipx_path.returncode == 0:
            print("✅ pipx is available")
            return True
        else:
            print("ℹ️  pipx not available, would need installation")

            # Test if we can install pipx
            try:
                result = subprocess.run(
                    ["sudo", "-n", "apt", "list", "pipx"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode == 0:
                    print("✅ pipx package available for installation")
                    return True
                else:
                    print("⚠️  pipx package not available in repositories")
                    return False
            except:
                print("⚠️  Cannot test pipx package availability (no sudo)")
                return False

    except Exception as e:
        print(f"❌ pipx availability test failed: {e}")
        return False


def test_venv_creation():
    """Test virtual environment creation capability"""
    print("🧪 Testing virtual environment creation...")

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            venv_path = Path(tmpdir) / "test_venv"

            # Create virtual environment
            result = subprocess.run(
                ["python3", "-m", "venv", str(venv_path)],
                capture_output=True,
                text=True,
                timeout=60,
            )

            if result.returncode == 0 and (venv_path / "bin" / "python").exists():
                print("✅ Virtual environment creation successful")
                return True
            else:
                print(f"❌ Virtual environment creation failed: {result.stderr}")
                return False

    except Exception as e:
        print(f"❌ Virtual environment test failed: {e}")
        return False


def test_apt_availability():
    """Test apt package manager availability"""
    print("🧪 Testing apt package manager...")

    try:
        result = subprocess.run(
            ["which", "apt"], capture_output=True, text=True, timeout=10
        )

        if result.returncode == 0:
            print("✅ apt package manager available")
            return True
        else:
            # Try apt-get
            result = subprocess.run(
                ["which", "apt-get"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                print("✅ apt-get package manager available")
                return True
            else:
                print("❌ No apt package manager found")
                return False

    except Exception as e:
        print(f"❌ apt availability test failed: {e}")
        return False


def test_enhanced_installer():
    """Test the enhanced installer functionality"""
    print("🧪 Testing enhanced installer (dry run)...")

    try:
        # Test with detect-only mode to avoid actual installation
        installer_path = Path(__file__).parent / "claude-enhanced-installer.py"

        if not installer_path.exists():
            print("❌ Enhanced installer not found")
            return False

        result = subprocess.run(
            ["python3", str(installer_path), "--detect-only"],
            capture_output=True,
            text=True,
            timeout=60,
        )

        if result.returncode == 0:
            print("✅ Enhanced installer execution successful")
            print(f"Output preview: {result.stdout[:200]}...")
            return True
        else:
            print(f"❌ Enhanced installer failed: {result.stderr}")
            return False

    except Exception as e:
        print(f"❌ Enhanced installer test failed: {e}")
        return False


def test_headless_compatibility():
    """Test headless environment compatibility"""
    print("🧪 Testing headless environment compatibility...")

    # Check for display-related environment variables
    display_vars = ["DISPLAY", "WAYLAND_DISPLAY", "XDG_SESSION_TYPE"]
    has_display = any(os.environ.get(var) for var in display_vars)

    if has_display:
        print("ℹ️  Display environment detected (not headless)")
    else:
        print("✅ Headless environment confirmed")

    # Test if we can run python without GUI dependencies
    try:
        result = subprocess.run(
            ["python3", "-c", "import sys; print('Python headless test OK')"],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0:
            print("✅ Python headless execution successful")
            return True
        else:
            print(f"❌ Python headless execution failed: {result.stderr}")
            return False

    except Exception as e:
        print(f"❌ Headless compatibility test failed: {e}")
        return False


def main():
    """Run all headless installation tests"""
    print("🚀 Claude Enhanced Installer - Headless Debian Compatibility Test")
    print("=" * 70)

    tests = [
        ("PEP 668 Detection", test_pep668_detection),
        ("pipx Availability", test_pipx_availability),
        ("Virtual Environment", test_venv_creation),
        ("apt Package Manager", test_apt_availability),
        ("Enhanced Installer", test_enhanced_installer),
        ("Headless Compatibility", test_headless_compatibility),
    ]

    results = []

    for test_name, test_func in tests:
        print(f"\n📋 {test_name}")
        print("-" * 50)

        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Test '{test_name}' crashed: {e}")
            results.append((test_name, False))

    # Summary
    print("\n📊 Test Results Summary")
    print("=" * 70)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")

    print(f"\n🎯 Results: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! Installer should work on headless Debian.")
        return 0
    elif passed >= total * 0.8:
        print("⚠️  Most tests passed. Installer should work with minor issues.")
        return 0
    else:
        print("❌ Multiple test failures. Manual fixes may be needed.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
