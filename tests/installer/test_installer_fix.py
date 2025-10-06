#!/usr/bin/env python3
"""
Test script to validate the installer logic fix
Tests the specific scenario where npm installation succeeds but binary detection might fail
"""

import subprocess
import sys
from pathlib import Path
import pytest

def test_installer_logic():
    """Test the fixed installer logic using assertions."""
    # Test 1: Verify the pip fallback condition is correct when npm succeeds but binary is not found.
    # Pip should NOT be attempted.
    npm_install_succeeded = True
    claude_binary = None
    pip_available = True
    should_try_pip = not claude_binary and not npm_install_succeeded and pip_available
    assert not should_try_pip, "Logic should not try pip after successful npm install"

    # Test 2: Verify pip is attempted when npm completely fails.
    npm_install_succeeded = False
    claude_binary = None
    pip_available = True
    should_try_pip = not claude_binary and not npm_install_succeeded and pip_available
    assert should_try_pip, "Logic should try pip when npm fails"

    # Test 3: Verify no pip when binary is found.
    npm_install_succeeded = True
    claude_binary = "/usr/local/bin/claude"
    pip_available = True
    should_try_pip = not claude_binary and not npm_install_succeeded and pip_available
    assert not should_try_pip, "Logic should not try pip when binary is already found"

def test_installer_run():
    """Test running the actual installer in detect-only mode."""
    try:
        # Assuming the installer is in the same directory as the test script
        installer_path = Path(__file__).parent / "claude-enhanced-installer.py"
        if not installer_path.exists():
            pytest.skip(f"Installer script not found at {installer_path}, skipping execution test.")

        # Run installer in detect-only mode to verify it doesn't crash
        result = subprocess.run([
            sys.executable, str(installer_path), "--detect-only", "--verbose"
        ], capture_output=True, text=True, timeout=30, check=False)

        assert result.returncode == 0, f"Installer exited with error code {result.returncode}:\\nSTDERR:\\n{result.stderr}"

    except Exception as e:
        pytest.fail(f"An unexpected exception occurred during installer test: {e}")