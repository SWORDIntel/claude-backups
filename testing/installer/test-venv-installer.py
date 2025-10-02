#!/usr/bin/env python3
"""
Test script for Claude Virtual Environment Installer
Validates installation and virtual environment functionality
"""

import os
import subprocess
import sys
from pathlib import Path
import tempfile
import shutil


class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    RESET = '\033[0m'


def print_success(message):
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")


def print_error(message):
    print(f"{Colors.RED}✗ {message}{Colors.RESET}")


def print_warning(message):
    print(f"{Colors.YELLOW}⚠ {message}{Colors.RESET}")


def print_info(message):
    print(f"{Colors.CYAN}ℹ {message}{Colors.RESET}")


def print_header(title):
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{title}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.RESET}")


def run_command(cmd, check=True, timeout=30):
    """Run a command and return result"""
    try:
        result = subprocess.run(
            cmd,
            shell=isinstance(cmd, str),
            capture_output=True,
            text=True,
            timeout=timeout
        )

        if check and result.returncode != 0:
            print_error(f"Command failed: {cmd}")
            print_error(f"Error: {result.stderr}")
            return None

        return result
    except subprocess.TimeoutExpired:
        print_error(f"Command timed out: {cmd}")
        return None
    except Exception as e:
        print_error(f"Command error: {e}")
        return None


def test_python_environment():
    """Test Python environment and PEP 668 status"""
    print_header("Testing Python Environment")

    # Test Python version
    result = run_command([sys.executable, "--version"])
    if result:
        print_success(f"Python version: {result.stdout.strip()}")
    else:
        print_error("Failed to get Python version")
        return False

    # Test venv module
    result = run_command([sys.executable, "-c", "import venv; print('venv available')"])
    if result and result.returncode == 0:
        print_success("Virtual environment module available")
    else:
        print_error("Virtual environment module not available")
        return False

    # Test PEP 668 status
    result = run_command([sys.executable, "-m", "pip", "install", "--dry-run", "requests"], check=False)
    if result and "externally-managed-environment" in result.stderr:
        print_warning("PEP 668 externally-managed environment detected")
        print_info("Virtual environment installation is required")
    else:
        print_info("System allows direct pip installation")

    return True


def test_installer_detection():
    """Test installer file detection"""
    print_header("Testing Installer Detection")

    script_dir = Path(__file__).parent
    installer_files = [
        "claude-enhanced-installer-venv.py",
        "claude-venv-installer.sh"
    ]

    all_found = True
    for filename in installer_files:
        installer_path = script_dir / filename
        if installer_path.exists():
            print_success(f"Found: {installer_path}")
        else:
            print_error(f"Missing: {installer_path}")
            all_found = False

    return all_found


def test_installer_syntax():
    """Test installer Python syntax"""
    print_header("Testing Installer Syntax")

    script_dir = Path(__file__).parent
    installer_path = script_dir / "claude-enhanced-installer-venv.py"

    if not installer_path.exists():
        print_error("Installer not found")
        return False

    # Test syntax
    result = run_command([sys.executable, "-m", "py_compile", str(installer_path)])
    if result and result.returncode == 0:
        print_success("Installer syntax is valid")
    else:
        print_error("Installer has syntax errors")
        return False

    # Test help
    result = run_command([sys.executable, str(installer_path), "--help"])
    if result and result.returncode == 0:
        print_success("Installer help command works")
    else:
        print_error("Installer help command failed")
        return False

    return True


def test_virtual_environment_creation():
    """Test virtual environment creation in temporary directory"""
    print_header("Testing Virtual Environment Creation")

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        venv_path = temp_path / "test-venv"

        print_info(f"Creating test virtual environment at: {venv_path}")

        # Create venv
        result = run_command([sys.executable, "-m", "venv", str(venv_path)])
        if not result or result.returncode != 0:
            print_error("Failed to create virtual environment")
            return False

        print_success("Virtual environment created")

        # Test venv structure
        expected_files = ["bin/python", "bin/pip"] if os.name != 'nt' else ["Scripts/python.exe", "Scripts/pip.exe"]

        for expected_file in expected_files:
            file_path = venv_path / expected_file
            if file_path.exists():
                print_success(f"Found: {expected_file}")
            else:
                print_error(f"Missing: {expected_file}")
                return False

        # Test venv Python
        venv_python = venv_path / ("bin/python" if os.name != 'nt' else "Scripts/python.exe")
        result = run_command([str(venv_python), "--version"])
        if result and result.returncode == 0:
            print_success(f"Virtual environment Python works: {result.stdout.strip()}")
        else:
            print_error("Virtual environment Python not working")
            return False

        # Test pip in venv
        result = run_command([str(venv_python), "-m", "pip", "--version"])
        if result and result.returncode == 0:
            print_success("Virtual environment pip works")
        else:
            print_error("Virtual environment pip not working")
            return False

        print_success("Virtual environment test completed successfully")
        return True


def test_installer_detection_mode():
    """Test installer detection mode"""
    print_header("Testing Installer Detection Mode")

    script_dir = Path(__file__).parent
    installer_path = script_dir / "claude-enhanced-installer-venv.py"

    if not installer_path.exists():
        print_error("Installer not found")
        return False

    result = run_command([sys.executable, str(installer_path), "--detect-only"])
    if result and result.returncode == 0:
        print_success("Detection mode works")
        print_info("Detection output:")
        for line in result.stdout.split('\n'):
            if line.strip():
                print(f"  {line}")
    else:
        print_error("Detection mode failed")
        return False

    return True


def test_bash_launcher():
    """Test bash launcher script"""
    print_header("Testing Bash Launcher")

    script_dir = Path(__file__).parent
    launcher_path = script_dir / "claude-venv-installer.sh"

    if not launcher_path.exists():
        print_error("Bash launcher not found")
        return False

    # Test help
    result = run_command([str(launcher_path), "--help"])
    if result and result.returncode == 0:
        print_success("Bash launcher help works")
    else:
        print_error("Bash launcher help failed")
        return False

    # Test check-only mode
    result = run_command([str(launcher_path), "--check-only"])
    if result and result.returncode == 0:
        print_success("Bash launcher check-only mode works")
    else:
        print_error("Bash launcher check-only mode failed")
        return False

    return True


def test_agent_system_detection():
    """Test agent system detection"""
    print_header("Testing Agent System Detection")

    script_dir = Path(__file__).parent
    agents_dir = script_dir / "agents"

    if not agents_dir.exists():
        print_warning("Agents directory not found - creating test structure")
        agents_dir.mkdir()
        (agents_dir / "TEST.md").write_text("# Test Agent\nTest agent file\n")

    # Count agent files
    agent_files = list(agents_dir.glob("*.md"))
    if agent_files:
        print_success(f"Found {len(agent_files)} agent files")
        for agent_file in agent_files[:5]:  # Show first 5
            print_info(f"  {agent_file.name}")
        if len(agent_files) > 5:
            print_info(f"  ... and {len(agent_files) - 5} more")
    else:
        print_warning("No agent files found")

    # Check for src directory
    src_dir = agents_dir / "src"
    if src_dir.exists():
        print_success("Agent src directory found")

        # Check for Python files
        python_dir = src_dir / "python"
        if python_dir.exists():
            python_files = list(python_dir.glob("*.py"))
            print_success(f"Found {len(python_files)} Python files in agent src")
        else:
            print_warning("Agent Python src directory not found")
    else:
        print_warning("Agent src directory not found")

    return True


def main():
    """Main test function"""
    print_header("Claude Virtual Environment Installer Test Suite")

    tests = [
        ("Python Environment", test_python_environment),
        ("Installer Detection", test_installer_detection),
        ("Installer Syntax", test_installer_syntax),
        ("Virtual Environment Creation", test_virtual_environment_creation),
        ("Installer Detection Mode", test_installer_detection_mode),
        ("Bash Launcher", test_bash_launcher),
        ("Agent System Detection", test_agent_system_detection),
    ]

    passed = 0
    total = len(tests)

    for test_name, test_func in tests:
        print()
        try:
            if test_func():
                passed += 1
                print_success(f"✓ {test_name} PASSED")
            else:
                print_error(f"✗ {test_name} FAILED")
        except Exception as e:
            print_error(f"✗ {test_name} ERROR: {e}")

    print()
    print_header("Test Results")

    if passed == total:
        print_success(f"All {total} tests passed! ✨")
        print_info("The virtual environment installer is ready for use")
        print_info("Run: ./claude-venv-installer.sh --full")
    else:
        print_warning(f"{passed}/{total} tests passed")
        if passed < total:
            print_error("Some tests failed - please review the issues above")

    print()
    print_info("Next steps:")
    print_info("1. Run: ./claude-venv-installer.sh --detect-only")
    print_info("2. Run: ./claude-venv-installer.sh --full")
    print_info("3. Test: claude --help")

    return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)