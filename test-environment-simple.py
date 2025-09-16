#!/usr/bin/env python3
"""
Simple environment detection test - just detection, no installation
"""

import os
import sys
from pathlib import Path

def detect_environment():
    """Simplified environment detection"""

    # Check environment variables
    display = os.environ.get("DISPLAY")
    wayland_display = os.environ.get("WAYLAND_DISPLAY")
    xdg_session_type = os.environ.get("XDG_SESSION_TYPE", "").lower()
    desktop_session = os.environ.get("DESKTOP_SESSION", "").lower()
    xdg_current_desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()

    print("🧪 Environment Detection Test")
    print("=" * 40)

    # Basic detection
    if wayland_display:
        env_type = "wayland"
        display_server = "wayland"
    elif display:
        env_type = "x11"
        display_server = "x11"
    else:
        # Check for headless indicators
        if (os.environ.get("SSH_CLIENT") or
            os.environ.get("SSH_TTY") or
            Path("/.dockerenv").exists()):
            env_type = "headless"
            display_server = None
        else:
            env_type = "unknown"
            display_server = None

    # Desktop environment detection
    session_info = f"{desktop_session} {xdg_current_desktop}".lower()

    desktop_env = "unknown"
    if "kde" in session_info or "plasma" in session_info:
        desktop_env = "kde"
    elif "gnome" in session_info:
        desktop_env = "gnome"
    elif "xfce" in session_info:
        desktop_env = "xfce"

    # Results
    print(f"🖥️  Environment Type: {env_type}")
    print(f"📺 Display Server: {display_server or 'None'}")
    print(f"🎨 Desktop Environment: {desktop_env}")
    print()

    # Environment variables
    print("🔍 Key Environment Variables:")
    vars_to_check = [
        "DISPLAY", "WAYLAND_DISPLAY", "XDG_SESSION_TYPE",
        "DESKTOP_SESSION", "XDG_CURRENT_DESKTOP", "SSH_CLIENT"
    ]

    for var in vars_to_check:
        value = os.environ.get(var)
        print(f"  {var}: {value or '<not set>'}")

    print()

    # Headless indicators
    print("🔍 Headless Indicators:")
    print(f"  Docker container: {Path('/.dockerenv').exists()}")
    print(f"  SSH connection: {bool(os.environ.get('SSH_CLIENT') or os.environ.get('SSH_TTY'))}")

    return env_type, display_server, desktop_env

def main():
    env_type, display_server, desktop_env = detect_environment()

    print("📋 Summary:")
    if env_type == "headless":
        print("  ✅ Headless server environment detected")
        print("  📦 Recommend: Full installation with Docker database")
    elif env_type in ["wayland", "x11"]:
        print(f"  ✅ GUI environment detected ({env_type}/{desktop_env})")
        print("  🎨 Recommend: Full installation with GUI optimizations")
    else:
        print("  ⚠️  Unknown environment")
        print("  🔧 Recommend: Standard installation")

    return 0

if __name__ == "__main__":
    sys.exit(main())