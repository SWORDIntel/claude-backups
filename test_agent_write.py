#!/usr/bin/env python3
"""
Test script to verify agents can write files in .md mode
"""

import os
import subprocess
import time

def test_file_creation():
    """Test if we can create a file directly"""
    test_file = "/home/ubuntu/Documents/Claude/test_output.txt"
    
    # Remove test file if it exists
    if os.path.exists(test_file):
        os.remove(test_file)
    
    # Create test file
    with open(test_file, 'w') as f:
        f.write("Test content from Python script\n")
        f.write(f"Created at: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Verify file was created
    if os.path.exists(test_file):
        print(f"✓ File created successfully: {test_file}")
        with open(test_file, 'r') as f:
            print(f"Content: {f.read()}")
        return True
    else:
        print("✗ File creation failed")
        return False

def check_agent_mode():
    """Check current agent mode"""
    result = subprocess.run(['./switch.sh', 'status'], 
                          capture_output=True, text=True)
    
    if 'md AGENTS' in result.stdout or '.md AGENTS' in result.stdout:
        print("✓ System is in .md agent mode")
        return True
    elif 'BINARY SYSTEM' in result.stdout:
        print("✗ System is in binary mode - switch to .md mode first")
        return False
    else:
        print("? Unable to determine mode")
        return None

if __name__ == "__main__":
    print("=== Agent File Write Test ===\n")
    
    # Check mode
    mode_ok = check_agent_mode()
    
    # Test file creation
    if mode_ok:
        print("\nTesting file creation...")
        if test_file_creation():
            print("\n✓ TEST PASSED: Agents should be able to write files")
        else:
            print("\n✗ TEST FAILED: File creation issue detected")
    else:
        print("\n⚠ Cannot test - wrong mode or mode unknown")