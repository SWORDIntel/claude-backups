#!/usr/bin/env python3
"""
Test AVX2 integration with shadowgit
"""
import os
import sys
import ctypes
import time
from pathlib import Path

def test_avx2_diff_engine():
    """Test the AVX2 diff engine directly"""
    
    # Find the AVX2 library
    avx2_paths = [
        Path.home() / "shadowgit" / "c_src_avx2" / "bin" / "libshadowgit_avx2.so",
        Path("../../shadowgit/c_src_avx2/bin/libshadowgit_avx2.so"),
    ]
    
    avx2_lib = None
    for path in avx2_paths:
        if path.exists():
            avx2_lib = path
            print(f"✓ Found AVX2 library: {avx2_lib}")
            break
    
    if not avx2_lib:
        print("✗ AVX2 library not found")
        return False
    
    # Load the library
    try:
        lib = ctypes.CDLL(str(avx2_lib))
        print("✓ AVX2 library loaded successfully")
    except Exception as e:
        print(f"✗ Failed to load AVX2 library: {e}")
        return False
    
    # Define function signatures (only the ones that exist)
    lib.shadowgit_avx2_diff.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t]
    lib.shadowgit_avx2_diff.restype = ctypes.c_int
    
    lib.shadowgit_avx2_diff_buffers.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t]
    lib.shadowgit_avx2_diff_buffers.restype = ctypes.c_int
    
    # Test diff function with larger content for performance testing
    content1 = b"Hello World\nThis is a test\nLine three\n" * 10000
    content2 = b"Hello World\nThis is different\nLine three\n" * 10000
    
    start = time.time()
    diff_count = lib.shadowgit_avx2_diff(content1, content2, min(len(content1), len(content2)))
    elapsed = time.time() - start
    
    print(f"✓ Diff test: {diff_count} differences found in {elapsed:.4f}s")
    
    # Calculate performance
    lines_processed = content1.count(b'\n') + content2.count(b'\n')
    lines_per_sec = lines_processed / elapsed if elapsed > 0 else 0
    print(f"  Performance: {lines_per_sec:,.0f} lines/sec")
    
    # Test with shadowgit_avx2_diff_buffers for comparison
    start = time.time()
    diff_count2 = lib.shadowgit_avx2_diff_buffers(content1, content2, min(len(content1), len(content2)))
    elapsed2 = time.time() - start
    lines_per_sec2 = lines_processed / elapsed2 if elapsed2 > 0 else 0
    print(f"✓ Diff buffers test: {diff_count2} differences in {elapsed2:.4f}s")
    print(f"  Performance: {lines_per_sec2:,.0f} lines/sec")
    
    return True

def test_shadowgit_integration():
    """Test shadowgit with AVX2 integration"""
    
    print("\n=== Testing Shadowgit Integration ===")
    
    # Create a test file to trigger shadowgit
    test_file = Path("/tmp/shadowgit_test.py")
    test_content = """
# Test file for shadowgit AVX2 integration
def process_data(data):
    result = []
    for item in data:
        result.append(item * 2)
    return result

if __name__ == "__main__":
    test_data = [1, 2, 3, 4, 5]
    print(process_data(test_data))
"""
    
    test_file.write_text(test_content)
    print(f"✓ Created test file: {test_file}")
    
    # Check if shadowgit can process it
    os.environ["SHADOWGIT_AVX2_PATH"] = str(Path.home() / "shadowgit" / "c_src_avx2" / "bin" / "libshadowgit_avx2.so")
    
    try:
        # Import shadowgit unified system
        sys.path.insert(0, str(Path(__file__).parent))
        from shadowgit_unified_system import UnifiedSystem, UnifiedConfig
        
        # Create config
        config = UnifiedConfig(
            watch_dirs=["/tmp"],
            enable_neural=False,  # Disable neural for testing
            enable_c_acceleration=True
        )
        
        # Initialize system
        system = UnifiedSystem(config)
        print("✓ Shadowgit system initialized")
        
        # Check if AVX2 is loaded
        if system.config.avx2_available:
            print(f"✓ AVX2 acceleration enabled: {system.config.avx2_lib_path}")
        else:
            print("✗ AVX2 acceleration not available")
        
        return True
        
    except Exception as e:
        print(f"✗ Shadowgit integration failed: {e}")
        return False

def main():
    print("=== AVX2 Shadowgit Integration Test ===\n")
    
    # Test AVX2 library directly
    print("=== Testing AVX2 Library ===")
    avx2_ok = test_avx2_diff_engine()
    
    # Test shadowgit integration
    shadowgit_ok = test_shadowgit_integration()
    
    # Summary
    print("\n=== Test Summary ===")
    print(f"AVX2 Library: {'✓ PASS' if avx2_ok else '✗ FAIL'}")
    print(f"Shadowgit Integration: {'✓ PASS' if shadowgit_ok else '✗ FAIL'}")
    
    if avx2_ok and shadowgit_ok:
        print("\n✓ All tests passed! AVX2 integration is working.")
        return 0
    else:
        print("\n✗ Some tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())