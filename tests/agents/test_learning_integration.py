#!/usr/bin/env python3
"""
Comprehensive Learning System Integration Test
"""

import asyncio
import json
import os
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent / "agents" / "src" / "python"
sys.path.insert(0, str(project_root))


async def test_integration():
    """Test all learning system components"""
    print("Testing Learning System Integration...")

    test_results = {
        "database_connection": False,
        "learning_system": False,
        "orchestrator_bridge": False,
        "configuration": False,
        "ml_models": False,
    }

    try:
        # Test 1: Database connection
        print("\n1. Testing database connection...")
        import psycopg2

        # Get database config
        config_file = Path(__file__).parent.parent.parent / "config" / "database.json"
        if config_file.exists():
            with open(config_file) as f:
                db_config = json.load(f)
        else:
            db_config = {
                "host": os.environ.get("POSTGRES_HOST", "localhost"),
                "port": int(os.environ.get("POSTGRES_PORT", "5433")),
                "database": os.environ.get("POSTGRES_DB", "claude_auth"),
                "user": os.environ.get("POSTGRES_USER", "claude_auth"),
                "password": os.environ.get("POSTGRES_PASSWORD", "claude_auth_pass"),
            }

        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"
        )
        table_count = cursor.fetchone()[0]
        print(f"   ✓ Connected to database ({table_count} tables found)")
        test_results["database_connection"] = True
        cursor.close()
        conn.close()

    except Exception as e:
        print(f"   ✗ Database test failed: {e}")

    try:
        # Test 2: Learning system
        print("\n2. Testing PostgreSQL learning system...")
        from postgresql_learning_system import UltimatePostgreSQLLearningSystem

        learning_system = UltimatePostgreSQLLearningSystem(db_config)
        success = await learning_system.initialize()

        if success:
            print("   ✓ Learning system initialized")
            dashboard = await learning_system.get_ultimate_dashboard()
            print(f"   ✓ Dashboard status: {dashboard.get('status', 'unknown')}")
            test_results["learning_system"] = True

    except Exception as e:
        print(f"   ✗ Learning system test failed: {e}")

    try:
        # Test 3: Orchestrator bridge
        print("\n3. Testing orchestrator bridge...")
        from learning_orchestrator_bridge import (
            EnhancedLearningOrchestrator,
            LearningStrategy,
        )

        orchestrator = EnhancedLearningOrchestrator(LearningStrategy.ADAPTIVE)
        await orchestrator.initialize()
        print("   ✓ Orchestrator bridge initialized")
        test_results["orchestrator_bridge"] = True

    except Exception as e:
        print(f"   ✗ Orchestrator bridge test failed: {e}")

    # Test 4: Configuration
    config_dir = Path(__file__).parent.parent.parent / "config"
    if (config_dir / "database.json").exists() and (
        config_dir / "learning_config.json"
    ).exists():
        print("\n4. Testing configuration files...")
        print("   ✓ Configuration files present")
        test_results["configuration"] = True

    # Test 5: ML capabilities
    try:
        print("\n5. Testing ML models...")
        import numpy as np
        import sklearn

        print("   ✓ NumPy and scikit-learn available")

        try:
            import torch

            print("   ✓ PyTorch available")
        except ImportError:
            print("   ○ PyTorch not available (optional)")

        test_results["ml_models"] = True
    except Exception as e:
        print(f"   ○ ML models test: {e}")

    # Summary
    print("\n" + "=" * 50)
    print("Integration Test Summary:")
    print("=" * 50)

    passed = sum(1 for v in test_results.values() if v)
    total = len(test_results)

    for test, result in test_results.items():
        status = "✓" if result else "✗"
        print(f"  {status} {test.replace('_', ' ').title()}")

    print(f"\nTotal: {passed}/{total} tests passed")
    success_rate = (passed / total) * 100
    print(f"Success Rate: {success_rate:.1f}%")

    return success_rate >= 80


if __name__ == "__main__":
    success = asyncio.run(test_integration())
    sys.exit(0 if success else 1)
