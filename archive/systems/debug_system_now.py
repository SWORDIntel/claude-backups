#!/usr/bin/env python3
"""
ENSHRINED DEBUGGING SYSTEM - Immediate Implementation
Fixes military mode activation and system launch issues
"""

import subprocess
import sys
import os
import time
import json
from pathlib import Path

def debug_system():
    """Debug and fix the current system"""
    print("🔥 ENSHRINED DEBUG SYSTEM ACTIVATED")
    print("=" * 50)

    base_path = "/home/john/claude-backups"
    os.chdir(base_path)

    # Check current system status
    print("1. Analyzing system state...")

    # Check processes
    try:
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        python_procs = [line for line in result.stdout.split('\n') if 'python3' in line and 'claude' in line]
        print(f"   Found {len(python_procs)} Claude-related processes")
        for proc in python_procs[:3]:
            print(f"   {proc}")
    except:
        print("   Could not check processes")

    # Check ports
    print("\n2. Checking port status...")
    ports = [3451, 8080, 8000, 7860]
    for port in ports:
        try:
            result = subprocess.run(['lsof', f'-ti:{port}'], capture_output=True, text=True)
            if result.stdout.strip():
                print(f"   Port {port}: ✅ IN USE")
            else:
                print(f"   Port {port}: ❌ AVAILABLE")
        except:
            print(f"   Port {port}: ❓ UNKNOWN")

    # Check critical files
    print("\n3. Checking critical files...")
    critical_files = [
        "COMPREHENSIVE_ZERO_TOKEN_MASTER_SYSTEM.py",
        "VOICE_UI_COMPLETE_SYSTEM.py",
        "PURE_LOCAL_OFFLINE_UI.py",
        "hardware/enable-npu-turbo.sh"
    ]

    for file in critical_files:
        if Path(file).exists():
            print(f"   {file}: ✅ EXISTS")
        else:
            print(f"   {file}: ❌ MISSING")

    # Check military mode capability
    print("\n4. Checking military mode...")
    try:
        result = subprocess.run(['sudo', '-n', 'echo', 'test'], capture_output=True, text=True)
        if result.returncode == 0:
            print("   Sudo access: ✅ AVAILABLE")

            # Try NPU activation
            if Path("hardware/enable-npu-turbo.sh").exists():
                print("   Attempting NPU activation...")
                result = subprocess.run(['sudo', 'bash', 'hardware/enable-npu-turbo.sh'],
                                      capture_output=True, text=True, timeout=30)
                if result.returncode == 0:
                    print("   NPU activation: ✅ SUCCESS")
                else:
                    print(f"   NPU activation: ❌ FAILED - {result.stderr[:100]}")
            else:
                print("   NPU script: ❌ NOT FOUND")
        else:
            print("   Sudo access: ❌ NOT AVAILABLE")
    except Exception as e:
        print(f"   Military mode check failed: {e}")

    # Check dependencies
    print("\n5. Checking Python dependencies...")
    deps = ['gradio', 'transformers', 'torch', 'psutil', 'numpy']
    missing = []

    for dep in deps:
        try:
            __import__(dep)
            print(f"   {dep}: ✅ AVAILABLE")
        except ImportError:
            print(f"   {dep}: ❌ MISSING")
            missing.append(dep)

    if missing:
        print(f"\n   Installing missing packages: {missing}")
        try:
            subprocess.run([sys.executable, '-m', 'pip', 'install'] + missing, check=True)
            print("   ✅ Dependencies installed")
        except:
            print("   ❌ Failed to install dependencies")

    # System recommendations
    print("\n" + "=" * 50)
    print("🎯 DEBUGGING COMPLETE - RECOMMENDATIONS:")
    print("=" * 50)

    # Check if main system is running
    try:
        import requests
        response = requests.get('http://localhost:8080', timeout=5)
        if response.status_code == 200:
            print("✅ MAIN SYSTEM OPERATIONAL on port 8080")
            if 'voice' in response.text.lower():
                print("✅ Voice functionality detected")
        else:
            print("❌ Main system not responding")
    except:
        print("❌ Main system not accessible on port 8080")

    # Check voice system
    try:
        import requests
        response = requests.get('http://localhost:8000', timeout=5)
        if response.status_code == 200:
            print("✅ VOICE SYSTEM OPERATIONAL on port 8000")
    except:
        print("❌ Voice system not accessible on port 8000")

    print("\n🚀 ACCESS POINTS:")
    print("Primary: http://localhost:8080 (Main UI)")
    print("Voice:   http://localhost:8000 (Voice UI)")
    print("Opus:    http://localhost:3451 (Local inference)")

    print("\n🔧 SYSTEM STATUS: DEBUGGING ENSHRINED")
    return True

if __name__ == "__main__":
    debug_system()