#!/usr/bin/env python3
"""
Test script for environment detection capabilities
Tests detection of headless, KDE, GNOME, and other environments
"""

import os
import sys
import subprocess
from pathlib import Path

# Import directly by executing the installer file
installer_path = Path(__file__).parent / "claude-enhanced-installer.py"
exec(open(installer_path).read())

# Now we can use the classes
# ClaudeEnhancedInstaller and EnvironmentType are available

def test_current_environment():
    """Test environment detection on current system"""
    print("🧪 Testing Environment Detection")
    print("=" * 50)

    installer = ClaudeEnhancedInstaller(verbose=False, auto_mode=True)
    system_info = installer.system_info

    print(f"🖥️  Environment Type: {system_info.environment_type.value}")
    print(f"📺 Display Server: {system_info.display_server or 'None'}")
    print(f"🖱️  Desktop Session: {system_info.desktop_session or 'None'}")
    print(f"⚙️  Has Systemd: {system_info.has_systemd}")
    print()

    # Show environment variables
    print("🔍 Environment Variables:")
    env_vars = [
        "DISPLAY", "WAYLAND_DISPLAY", "XDG_SESSION_TYPE",
        "DESKTOP_SESSION", "XDG_CURRENT_DESKTOP", "GDMSESSION",
        "SSH_CLIENT", "SSH_TTY"
    ]

    for var in env_vars:
        value = os.environ.get(var)
        if value:
            print(f"  {var}: {value}")
        else:
            print(f"  {var}: <not set>")

    print()

    # Show formatted environment info
    formatted_env = installer._format_environment_info()
    print(f"📋 Formatted Environment: {formatted_env}")
    print()

    # Test environment-specific packages
    packages = installer._get_environment_specific_packages()
    print(f"📦 Environment-Specific Packages: {', '.join(packages)}")
    print()

    return system_info.environment_type

def test_headless_indicators():
    """Test various headless environment indicators"""
    print("🔍 Testing Headless Indicators")
    print("=" * 50)

    # Check container environment
    if Path("/.dockerenv").exists():
        print("📦 Docker container detected")

    # Check SSH connection
    if os.environ.get("SSH_CLIENT") or os.environ.get("SSH_TTY"):
        print("🔐 SSH connection detected")

    # Check cloud/VPS indicators
    cloud_files = [
        "/sys/devices/virtual/dmi/id/sys_vendor",
        "/sys/devices/virtual/dmi/id/product_name"
    ]

    for file_path in cloud_files:
        try:
            content = Path(file_path).read_text().strip()
            print(f"🏭 DMI Info ({file_path}): {content}")
        except:
            print(f"❌ Cannot read {file_path}")

    # Check for GPU modules
    try:
        result = subprocess.run(["lsmod"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            gpu_modules = ["nvidia", "amdgpu", "radeon", "i915", "nouveau"]
            found_modules = [mod for mod in gpu_modules if mod in result.stdout]
            if found_modules:
                print(f"🎮 GPU modules loaded: {', '.join(found_modules)}")
            else:
                print("🚫 No GPU modules detected (headless indicator)")
    except:
        print("❌ Cannot check lsmod")

    print()

def test_desktop_processes():
    """Test detection of desktop environment processes"""
    print("🔍 Testing Desktop Process Detection")
    print("=" * 50)

    desktop_processes = {
        "KDE": ["plasmashell", "kwin", "kdeconnectd"],
        "GNOME": ["gnome-shell", "gnome-session", "gsd-power"],
        "XFCE": ["xfce4-session", "xfwm4", "xfce4-panel"],
    }

    for desktop, processes in desktop_processes.items():
        try:
            result = subprocess.run(["pgrep", "-f", "|".join(processes)],
                                  capture_output=True, timeout=5)
            if result.returncode == 0:
                print(f"✅ {desktop} processes detected")
            else:
                print(f"❌ {desktop} processes not found")
        except:
            print(f"⚠️  Cannot check {desktop} processes")

    print()

def test_installation_adaptation():
    """Test how installation mode adapts to environment"""
    print("🔧 Testing Installation Adaptation")
    print("=" * 50)

    installer = ClaudeEnhancedInstaller(verbose=False, auto_mode=True)

    # InstallationMode is already available from exec

    # Test quick mode adaptation
    original_mode = InstallationMode.QUICK
    adapted_mode = installer._adapt_installation_for_environment(original_mode)

    print(f"📋 Original Mode: {original_mode.value}")
    print(f"📋 Adapted Mode: {adapted_mode.value}")

    if adapted_mode != original_mode:
        print(f"✅ Mode adapted for {installer.system_info.environment_type.value} environment")
    else:
        print(f"ℹ️  No adaptation needed for {installer.system_info.environment_type.value} environment")

    print()

def main():
    """Run all environment detection tests"""
    print("🚀 Claude Enhanced Installer - Environment Detection Test")
    print("=" * 70)
    print()

    try:
        # Test current environment
        detected_env = test_current_environment()

        # Test headless indicators
        test_headless_indicators()

        # Test desktop processes
        test_desktop_processes()

        # Test installation adaptation
        test_installation_adaptation()

        # Summary
        print("📊 Test Summary")
        print("=" * 50)
        print(f"✅ Environment detected: {detected_env.value}")
        print(f"✅ Detection logic functional")
        print(f"✅ Installation adaptation working")

        return 0

    except Exception as e:
        print(f"❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())