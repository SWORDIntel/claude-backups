#!/usr/bin/env python3
"""
Test Local Inference Server
Validate Qwen 2.5-32B with Military NPU
"""

import requests
import json
import time
import sys

def test_health_endpoint():
    """Test if server is healthy"""
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        if response.status_code == 200:
            health = response.json()
            print("✅ Health check passed")
            print(f"   Model loaded: {health.get('model_loaded', False)}")
            print(f"   NPU available: {health.get('npu_available', False)}")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to server: {e}")
        return False

def test_chat_completion():
    """Test chat completion endpoint"""
    try:
        payload = {
            "model": "qwen-32b",
            "messages": [
                {"role": "user", "content": "Hello! Can you tell me about your capabilities?"}
            ],
            "max_tokens": 100,
            "temperature": 0.7
        }

        print("🧪 Testing chat completion...")
        print(f"📤 Request: {payload['messages'][0]['content']}")

        start_time = time.time()
        response = requests.post(
            "http://localhost:8000/v1/chat/completions",
            json=payload,
            timeout=30
        )
        end_time = time.time()

        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            usage = result.get('usage', {})

            print("✅ Inference successful!")
            print(f"📥 Response: {content[:200]}...")
            print(f"⏱️ Time: {end_time - start_time:.2f} seconds")
            print(f"🔢 Tokens: {usage.get('completion_tokens', 0)} generated")

            if usage.get('completion_tokens', 0) > 0 and end_time - start_time > 0:
                tokens_per_sec = usage['completion_tokens'] / (end_time - start_time)
                print(f"🚀 Speed: {tokens_per_sec:.1f} tokens/second")

            return True
        else:
            print(f"❌ Request failed: {response.status_code}")
            print(f"Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

def test_performance_benchmark():
    """Run a quick performance benchmark"""
    try:
        test_prompts = [
            "Explain quantum computing in simple terms.",
            "Write a Python function to calculate fibonacci numbers.",
            "What are the advantages of local AI inference?"
        ]

        total_tokens = 0
        total_time = 0
        successful_tests = 0

        print("\n🏁 Running performance benchmark...")

        for i, prompt in enumerate(test_prompts):
            print(f"\n📝 Test {i+1}/3: {prompt[:50]}...")

            payload = {
                "model": "qwen-32b",
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 150,
                "temperature": 0.5
            }

            try:
                start_time = time.time()
                response = requests.post(
                    "http://localhost:8000/v1/chat/completions",
                    json=payload,
                    timeout=45
                )
                end_time = time.time()

                if response.status_code == 200:
                    result = response.json()
                    usage = result.get('usage', {})
                    tokens = usage.get('completion_tokens', 0)
                    duration = end_time - start_time

                    total_tokens += tokens
                    total_time += duration
                    successful_tests += 1

                    print(f"   ✅ {tokens} tokens in {duration:.2f}s ({tokens/duration:.1f} tok/s)")
                else:
                    print(f"   ❌ Failed: {response.status_code}")

            except Exception as e:
                print(f"   ❌ Error: {e}")

        # Summary
        if successful_tests > 0:
            avg_speed = total_tokens / total_time if total_time > 0 else 0
            print(f"\n📊 Benchmark Summary:")
            print(f"   Successful tests: {successful_tests}/{len(test_prompts)}")
            print(f"   Total tokens: {total_tokens}")
            print(f"   Total time: {total_time:.2f}s")
            print(f"   Average speed: {avg_speed:.1f} tokens/second")

            # Evaluate performance
            if avg_speed >= 30:
                print("🎉 Excellent performance!")
            elif avg_speed >= 20:
                print("✅ Good performance")
            elif avg_speed >= 10:
                print("⚠️ Moderate performance")
            else:
                print("🐌 Performance needs optimization")

            return True
        else:
            print("❌ All benchmark tests failed")
            return False

    except Exception as e:
        print(f"❌ Benchmark failed: {e}")
        return False

def main():
    """Main test function"""
    print("🧪 Local AI Inference Testing")
    print("=" * 50)
    print("🎯 Target: Qwen 2.5-32B on Military NPU (26.4 TOPS)")
    print()

    # Wait a moment for server to start
    print("⏳ Waiting for server startup...")
    time.sleep(5)

    tests = [
        ("Health Check", test_health_endpoint),
        ("Chat Completion", test_chat_completion),
        ("Performance Benchmark", test_performance_benchmark)
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n🔍 Running: {test_name}")
        try:
            success = test_func()
            results.append((test_name, success))
        except Exception as e:
            print(f"❌ {test_name} crashed: {e}")
            results.append((test_name, False))

    # Final summary
    print("\n" + "=" * 50)
    print("📊 Test Results Summary")
    print("=" * 50)

    passed = sum(1 for _, success in results if success)
    total = len(results)

    for test_name, success in results:
        status = "PASS" if success else "FAIL"
        icon = "✅" if success else "❌"
        print(f"{icon} {test_name}: {status}")

    print(f"\n🎯 Results: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! Local inference is fully functional!")
        print("🚀 Your Military NPU is now serving AI responses!")
        return 0
    else:
        print("⚠️ Some tests failed. Check server logs for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())