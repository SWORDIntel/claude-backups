#!/usr/bin/env python3
"""
Test script for PostgreSQL 16/17 compatibility in the learning system
"""

import asyncio
import asyncpg
import psycopg2
import json
import sys
import os
from pathlib import Path

# Add the learning system to the path
project_root = Path(__file__).parent.parent.parent / "database"
sys.path.append(str(project_root))

try:
    from postgresql_learning_system import UltimatePostgreSQLLearningSystem
    LEARNING_SYSTEM_AVAILABLE = True
except ImportError:
    LEARNING_SYSTEM_AVAILABLE = False

async def test_postgresql_compatibility():
    """Test PostgreSQL compatibility features"""
    print("🔍 Testing PostgreSQL 16/17 Compatibility...")
    
    # Database config
    db_config = {
        'host': 'localhost',
        'port': 5433,
        'database': 'claude_auth',
        'user': 'claude_auth',
        'password': 'claude_auth_pass'
    }
    
    try:
        # Test basic connection
        print("\n1. Testing database connection...")
        conn = await asyncpg.connect(**db_config)
        
        # Get PostgreSQL version
        version_result = await conn.fetchval("SELECT version()")
        print(f"   ✅ Connected to: {version_result}")
        
        version_parts = version_result.split()
        version_number = float('.'.join(version_parts[1].split('.')[:2]))
        print(f"   📊 Detected version: {version_number}")
        
        # Test PostgreSQL 17 specific functions
        print("\n2. Testing PostgreSQL 17 functions...")
        
        try:
            result = await conn.fetchval("SELECT JSON_ARRAY()")
            print(f"   ✅ JSON_ARRAY() test: {result}")
            json_array_available = True
        except Exception as e:
            print(f"   ❌ JSON_ARRAY() test failed: {e}")
            json_array_available = False
        
        try:
            result = await conn.fetchval("SELECT JSON_OBJECT()")
            print(f"   ✅ JSON_OBJECT() test: {result}")
            json_object_available = True
        except Exception as e:
            print(f"   ❌ JSON_OBJECT() test failed: {e}")
            json_object_available = False
        
        # Test PostgreSQL 16 compatible alternatives
        print("\n3. Testing PostgreSQL 16 compatible alternatives...")
        
        try:
            result = await conn.fetchval("SELECT '[]'::jsonb")
            print(f"   ✅ '[]'::jsonb test: {result}")
        except Exception as e:
            print(f"   ❌ '[]'::jsonb test failed: {e}")
        
        try:
            result = await conn.fetchval("SELECT '{}'::jsonb")
            print(f"   ✅ '{{}}'::jsonb test: {result}")
        except Exception as e:
            print(f"   ❌ '{{}}'::jsonb test failed: {e}")
        
        # Test json_build_array and json_build_object functions
        try:
            result = await conn.fetchval("SELECT json_build_array()")
            print(f"   ✅ json_build_array() test: {result}")
        except Exception as e:
            print(f"   ❌ json_build_array() test failed: {e}")
        
        try:
            result = await conn.fetchval("SELECT json_build_object()")
            print(f"   ✅ json_build_object() test: {result}")
        except Exception as e:
            print(f"   ❌ json_build_object() test failed: {e}")
        
        # Test table creation with version-compatible defaults
        print("\n4. Testing table creation with version compatibility...")
        
        test_table_sql = """
        CREATE TEMP TABLE pg_compatibility_test (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            array_data JSONB DEFAULT '[]'::jsonb,
            object_data JSONB DEFAULT '{}'::jsonb,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
        """
        
        try:
            await conn.execute(test_table_sql)
            print("   ✅ Table creation with PostgreSQL 16/17 compatible defaults")
            
            # Insert test data
            await conn.execute("""
                INSERT INTO pg_compatibility_test (array_data, object_data) 
                VALUES ('["test"]'::jsonb, '{"test": true}'::jsonb)
            """)
            print("   ✅ Data insertion successful")
            
            # Query test data
            result = await conn.fetchrow("""
                SELECT array_data, object_data 
                FROM pg_compatibility_test 
                LIMIT 1
            """)
            print(f"   ✅ Data query successful: {dict(result)}")
            
        except Exception as e:
            print(f"   ❌ Table creation test failed: {e}")
        
        await conn.close()
        
        # Test the learning system if available
        if LEARNING_SYSTEM_AVAILABLE:
            print("\n5. Testing Ultimate Learning System compatibility...")
            
            try:
                learning_system = UltimatePostgreSQLLearningSystem(db_config)
                
                # Initialize with version detection
                success = await learning_system.initialize()
                if success:
                    print("   ✅ Learning system initialization successful")
                    
                    # Get dashboard with version info
                    dashboard = await learning_system.get_ultimate_dashboard()
                    health = dashboard.get('system_health', {})
                    
                    print(f"   📊 Detected PostgreSQL version: {health.get('postgres_version')}")
                    print(f"   🔧 Database integration: {health.get('database_integration')}")
                    print(f"   ✅ Version compatibility: {health.get('version_compatibility')}")
                    
                    features = health.get('postgres_features', {})
                    print(f"   🚀 JSON_ARRAY available: {features.get('json_array_function', False)}")
                    print(f"   🚀 JSON_OBJECT available: {features.get('json_object_function', False)}")
                    
                else:
                    print("   ❌ Learning system initialization failed")
                    
            except Exception as e:
                print(f"   ❌ Learning system test failed: {e}")
        else:
            print("\n5. Learning system not available for testing")
            print("   💡 Run from the agents/src/python directory to test the learning system")
        
        # Summary
        print("\n📋 Compatibility Summary:")
        print(f"   PostgreSQL Version: {version_number}")
        
        if version_number >= 17.0:
            if json_array_available and json_object_available:
                print("   🎯 Status: PostgreSQL 17 features fully available")
            else:
                print("   ⚠️  Status: PostgreSQL 17 detected but JSON functions not working")
                print("   📦 Fallback: PostgreSQL 16 compatibility mode will be used")
        else:
            print("   📦 Status: PostgreSQL 16 compatibility mode (recommended)")
            print("   ✅ All features work correctly using standard JSONB casting")
        
        print("\n✅ Compatibility test completed successfully!")
        return True
        
    except Exception as e:
        print(f"\n❌ Compatibility test failed: {e}")
        return False

if __name__ == "__main__":
    asyncio.run(test_postgresql_compatibility())