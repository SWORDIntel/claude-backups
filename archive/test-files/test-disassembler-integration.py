#!/usr/bin/env python3
"""
Test script for DISASSEMBLER hook integration
Demonstrates the complete workflow
"""

import os
import sys
import asyncio
import tempfile
import json

# Add hooks directory to path
hooks_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, hooks_dir)

async def test_disassembler_integration():
    """Test the complete DISASSEMBLER integration workflow"""

    print("🔍 Testing DISASSEMBLER Hook Integration")
    print("=" * 50)

    try:
        # Import the hook and bridge
        from disassembler_hook import DisassemblerHook
        from disassembler_bridge import DisassemblerBridge

        print("✅ Successfully imported hook and bridge modules")

        # Initialize components
        hook = DisassemblerHook()
        bridge = DisassemblerBridge()

        print("✅ Successfully initialized hook and bridge")

        # Test 1: File type detection
        print("\n📁 Test 1: File type detection")
        test_files = [
            '/bin/ls',           # Should be detected as binary
            '/etc/passwd',       # Should not be detected as binary
            '/usr/bin/python3',  # Should be detected as binary
            __file__            # Should not be detected as binary
        ]

        for test_file in test_files:
            if os.path.exists(test_file):
                is_binary = hook.is_binary_file(test_file)
                print(f"  {test_file}: {'Binary' if is_binary else 'Not binary'}")

        # Test 2: Analysis workflow
        print("\n🔬 Test 2: Analysis workflow")

        # Find a real binary to test with
        test_binary = None
        for candidate in ['/bin/ls', '/usr/bin/cat', '/bin/echo']:
            if os.path.exists(candidate):
                test_binary = candidate
                break

        if test_binary:
            print(f"  Testing with: {test_binary}")

            # Test hook analysis
            hook_result = await hook.analyze_file(test_binary)
            print(f"  Hook analysis status: {hook_result.get('status', 'unknown')}")

            # Test bridge processing
            bridge_result = await bridge.process_binary_file(test_binary)
            print(f"  Bridge processing status: {bridge_result.get('status', 'unknown')}")

            # Show security score if available
            security_score = bridge_result.get('summary', {}).get('security_score')
            if security_score is not None:
                print(f"  Security score: {security_score}/100")
        else:
            print("  No suitable test binary found")

        # Test 3: Cache functionality
        print("\n💾 Test 3: Cache functionality")
        cache_summary = hook.get_analysis_summary()
        print(f"  Cache entries: {cache_summary.get('total_analyzed', 0)}")
        print(f"  Successful analyses: {cache_summary.get('successful', 0)}")

        # Test 4: Ghidra integration check
        print("\n🛠️  Test 4: Ghidra integration check")
        ghidra_script = os.path.join(hooks_dir, 'ghidra-integration.sh')
        if os.path.exists(ghidra_script):
            print(f"  ✅ Ghidra script found: {ghidra_script}")
        else:
            print(f"  ⚠️  Ghidra script not found: {ghidra_script}")

        print("\n🎉 Integration test completed successfully!")

    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("Make sure the hook files are in the same directory")
    except Exception as e:
        print(f"❌ Test error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    asyncio.run(test_disassembler_integration())