#!/usr/bin/env python3
"""
Quick PostgreSQL 17 Database Test
"""
import asyncio
import time

import asyncpg


async def test_database():
    """Quick database functionality test"""
    print("🗄️ Testing PostgreSQL 17 database connection...")

    try:
        # Connect to database
        conn = await asyncpg.connect(
            host="localhost",
            port=5432,
            user="claude_auth",
            password="claude_auth_password123",
            database="claude_auth",
        )
        print("✅ Database connection successful")

        # Test basic query
        result = await conn.fetchrow("SELECT version();")
        print(f"✅ PostgreSQL version: {result['version']}")

        # Test our tables
        tables = await conn.fetch(
            "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
        )
        print(f"✅ Found {len(tables)} tables: {[t['tablename'] for t in tables]}")

        # Test user count
        user_count = await conn.fetchval("SELECT COUNT(*) FROM users;")
        print(f"✅ Users in database: {user_count}")

        # Test role count
        role_count = await conn.fetchval("SELECT COUNT(*) FROM roles;")
        print(f"✅ Roles in database: {role_count}")

        # Test authentication function
        start_time = time.time()
        auth_result = await conn.fetchrow(
            "SELECT * FROM authenticate_user($1, $2)", "admin", "dummy_hash"
        )
        auth_time = (time.time() - start_time) * 1000
        print(f"✅ Authentication function test: {auth_time:.2f}ms")

        # Test performance metrics view
        try:
            perf_metrics = await conn.fetch(
                "SELECT * FROM auth_performance_metrics LIMIT 3;"
            )
            print(f"✅ Performance metrics view: {len(perf_metrics)} entries")
        except Exception as e:
            print(f"⚠️  Performance metrics: {str(e)[:50]}...")

        await conn.close()
        print("✅ Database test completed successfully!")
        return True

    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False


if __name__ == "__main__":
    success = asyncio.run(test_database())
    exit(0 if success else 1)
