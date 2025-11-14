#!/usr/bin/env python3
"""
PostgreSQL Learning Integration
Integrates the learning system with existing database infrastructure
"""

import asyncio
import os
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

try:
    import asyncpg
    import psycopg2
    from psycopg2.extras import RealDictCursor

    DATABASE_AVAILABLE = True
except ImportError:
    DATABASE_AVAILABLE = False
    print(
        "Warning: Install PostgreSQL drivers with: pip install asyncpg psycopg2-binary"
    )


class DatabaseLearningIntegration:
    """Manages integration between existing database and learning system"""

    def __init__(self, db_config=None):
        # Default database config - update these values
        self.db_config = db_config or {
            "host": os.getenv("DB_HOST", "localhost"),
            "port": int(os.getenv("DB_PORT", 5432)),
            "database": os.getenv("DB_NAME", "claude_agents"),
            "user": os.getenv("DB_USER", "postgres"),
            "password": os.getenv("DB_PASSWORD", "your_password"),
        }

    async def test_connection(self):
        """Test database connection"""
        if not DATABASE_AVAILABLE:
            return False, "PostgreSQL drivers not installed"

        try:
            conn = await asyncpg.connect(**self.db_config)
            version = await conn.fetchval("SELECT version()")
            await conn.close()
            return True, f"Connected successfully. {version}"
        except Exception as e:
            return False, f"Connection failed: {e}"

    async def check_existing_schema(self):
        """Check if the existing auth schema is present"""
        conn = await asyncpg.connect(**self.db_config)

        try:
            # Check for key tables from auth_db_setup.sql
            tables = await conn.fetch(
                """
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                    AND table_name IN ('users', 'user_sessions', 'roles', 'permissions')
            """
            )

            auth_tables = [row["table_name"] for row in tables]

            return {
                "auth_system_present": len(auth_tables) >= 4,
                "found_tables": auth_tables,
                "missing_tables": [
                    t
                    for t in ["users", "user_sessions", "roles", "permissions"]
                    if t not in auth_tables
                ],
                "postgresql_version": await conn.fetchval("SELECT version()"),
            }

        finally:
            await conn.close()

    async def setup_learning_integration(self):
        """Setup learning system integration with existing database"""
        conn = await asyncpg.connect(**self.db_config)

        try:
            print("Setting up learning system integration...")

            # Read and execute the learning schema SQL
            schema_path = (
                Path(__file__).parent.parent / "sql" / "learning_system_schema.sql"
            )

            if not schema_path.exists():
                return False, f"Schema file not found: {schema_path}"

            with open(schema_path, "r") as f:
                schema_sql = f.read()

            # Execute the schema setup
            await conn.execute(schema_sql)

            print("✓ Learning schema setup complete")
            return True, "Learning system integrated successfully"

        except Exception as e:
            return False, f"Setup failed: {e}"
        finally:
            await conn.close()

    async def verify_integration(self):
        """Verify that learning system is properly integrated"""
        conn = await asyncpg.connect(**self.db_config)

        try:
            # Check for learning tables
            learning_tables = await conn.fetch(
                """
                SELECT table_name, 
                       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
                FROM pg_tables 
                WHERE schemaname = 'public' 
                    AND table_name LIKE 'agent_%'
                ORDER BY table_name
            """
            )

            # Check for learning functions
            learning_functions = await conn.fetch(
                """
                SELECT routine_name 
                FROM information_schema.routines 
                WHERE routine_schema = 'public' 
                    AND routine_name LIKE '%learning%' 
                    OR routine_name LIKE '%agent%'
                ORDER BY routine_name
            """
            )

            # Check materialized views
            materialized_views = await conn.fetch(
                """
                SELECT schemaname, matviewname
                FROM pg_matviews 
                WHERE schemaname = 'public'
                    AND matviewname LIKE '%learning%'
            """
            )

            # Test sample operations
            test_results = {}

            # Test agent performance metrics
            try:
                await conn.execute(
                    """
                    INSERT INTO agent_performance_metrics (agent_name, total_invocations, successful_invocations)
                    VALUES ('TEST_AGENT', 1, 1)
                    ON CONFLICT (agent_name) DO UPDATE SET total_invocations = agent_performance_metrics.total_invocations + 1
                """
                )
                test_results["metrics_insert"] = "OK"
            except Exception as e:
                test_results["metrics_insert"] = f"FAILED: {e}"

            # Test learning functions
            try:
                result = await conn.fetchval(
                    """
                    SELECT get_optimal_agents('web_development', 3, 0.5)
                """
                )
                test_results["function_call"] = "OK"
            except Exception as e:
                test_results["function_call"] = f"FAILED: {e}"

            return {
                "learning_tables": [dict(row) for row in learning_tables],
                "learning_functions": [
                    row["routine_name"] for row in learning_functions
                ],
                "materialized_views": [
                    row["matviewname"] for row in materialized_views
                ],
                "test_results": test_results,
                "integration_status": (
                    "success"
                    if all("FAILED" not in str(v) for v in test_results.values())
                    else "partial"
                ),
            }

        finally:
            await conn.close()

    async def get_database_stats(self):
        """Get database statistics for monitoring"""
        conn = await asyncpg.connect(**self.db_config)

        try:
            # Overall database stats
            db_stats = await conn.fetchrow(
                """
                SELECT 
                    pg_database_size(current_database()) as total_size_bytes,
                    pg_size_pretty(pg_database_size(current_database())) as total_size,
                    (SELECT COUNT(*) FROM pg_stat_user_tables) as total_tables,
                    current_database() as database_name,
                    version() as postgresql_version
            """
            )

            # Table sizes
            table_stats = await conn.fetch(
                """
                SELECT 
                    schemaname,
                    tablename,
                    pg_total_relation_size(schemaname||'.'||tablename) as size_bytes,
                    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                    n_tup_ins as inserts,
                    n_tup_upd as updates,
                    n_tup_del as deletes
                FROM pg_tables t
                LEFT JOIN pg_stat_user_tables s ON t.tablename = s.relname AND t.schemaname = s.schemaname
                WHERE t.schemaname = 'public'
                ORDER BY pg_total_relation_size(t.schemaname||'.'||t.tablename) DESC
                LIMIT 20
            """
            )

            # Learning system specific stats
            learning_stats = {}
            try:
                learning_stats = await conn.fetchrow(
                    """
                    SELECT 
                        (SELECT COUNT(*) FROM agent_task_executions) as total_executions,
                        (SELECT COUNT(*) FROM agent_performance_metrics) as tracked_agents,
                        (SELECT COUNT(*) FROM agent_combination_patterns) as combination_patterns,
                        (SELECT COUNT(*) FROM agent_learning_insights WHERE is_active = true) as active_insights,
                        (SELECT AVG(success_rate) FROM agent_performance_metrics WHERE total_invocations > 0) as avg_agent_success
                """
                )
            except:
                learning_stats = {"error": "Learning tables not yet created"}

            return {
                "database": dict(db_stats) if db_stats else {},
                "tables": [dict(row) for row in table_stats],
                "learning_system": (
                    dict(learning_stats)
                    if isinstance(learning_stats, dict)
                    else learning_stats
                ),
            }

        finally:
            await conn.close()

    async def create_sample_learning_data(self):
        """Create sample learning data for testing"""
        conn = await asyncpg.connect(**self.db_config)

        try:
            # Sample task executions
            sample_executions = [
                {
                    "task_type": "web_development",
                    "description": "Create responsive dashboard with authentication",
                    "agents": ["WEB", "APIDESIGNER", "SECURITY", "TESTBED"],
                    "duration": 120.5,
                    "success": True,
                    "complexity": 3.0,
                },
                {
                    "task_type": "security_audit",
                    "description": "Comprehensive security analysis of API endpoints",
                    "agents": ["SECURITY", "SECURITYAUDITOR", "CRYPTOEXPERT"],
                    "duration": 85.2,
                    "success": True,
                    "complexity": 4.0,
                },
                {
                    "task_type": "bug_fix",
                    "description": "Fix memory leak in authentication service",
                    "agents": ["DEBUGGER", "PATCHER", "TESTBED"],
                    "duration": 45.8,
                    "success": True,
                    "complexity": 2.0,
                },
                {
                    "task_type": "deployment",
                    "description": "Deploy microservices to production environment",
                    "agents": ["DEPLOYER", "INFRASTRUCTURE", "MONITOR"],
                    "duration": 180.0,
                    "success": False,
                    "complexity": 3.5,
                },
            ]

            for i, exec_data in enumerate(sample_executions):
                await conn.execute(
                    """
                    INSERT INTO agent_task_executions (
                        task_type, task_description, agents_invoked, execution_sequence,
                        start_time, end_time, duration_seconds, success, complexity_score
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                """,
                    exec_data["task_type"],
                    exec_data["description"],
                    exec_data["agents"],  # Will be converted to JSONB
                    exec_data["agents"],  # Same for sequence
                    f"NOW() - INTERVAL '{(i+1)*30} minutes'",
                    f"NOW() - INTERVAL '{(i+1)*30 - exec_data['duration']/60} minutes'",
                    exec_data["duration"],
                    exec_data["success"],
                    exec_data["complexity"],
                )

            return f"Created {len(sample_executions)} sample executions"

        except Exception as e:
            return f"Failed to create sample data: {e}"
        finally:
            await conn.close()


async def main():
    """Main integration setup and verification"""
    integration = DatabaseLearningIntegration()

    print("=== PostgreSQL Learning System Integration ===\n")

    # Test connection
    print("1. Testing database connection...")
    success, message = await integration.test_connection()
    print(f"   {message}\n")

    if not success:
        print("❌ Database connection failed. Please check your configuration.")
        return

    # Check existing schema
    print("2. Checking existing database schema...")
    schema_info = await integration.check_existing_schema()
    print(f"   Auth system present: {schema_info['auth_system_present']}")
    print(f"   Found tables: {schema_info['found_tables']}")
    if schema_info["missing_tables"]:
        print(f"   Missing tables: {schema_info['missing_tables']}")
    print()

    # Setup learning integration
    print("3. Setting up learning system integration...")
    success, message = await integration.setup_learning_integration()
    print(f"   {message}\n")

    if not success:
        print("❌ Learning system setup failed.")
        return

    # Verify integration
    print("4. Verifying integration...")
    verification = await integration.verify_integration()
    print(f"   Integration status: {verification['integration_status']}")
    print(f"   Learning tables: {len(verification['learning_tables'])}")
    print(f"   Learning functions: {len(verification['learning_functions'])}")
    print(f"   Test results: {verification['test_results']}")
    print()

    # Get database statistics
    print("5. Database statistics...")
    stats = await integration.get_database_stats()
    print(f"   Total database size: {stats['database'].get('total_size', 'unknown')}")
    print(f"   Total tables: {stats['database'].get('total_tables', 'unknown')}")
    if "error" not in stats["learning_system"]:
        print(
            f"   Learning executions: {stats['learning_system'].get('total_executions', 0)}"
        )
        print(f"   Tracked agents: {stats['learning_system'].get('tracked_agents', 0)}")
    print()

    # Create sample data (optional)
    create_sample = (
        input("Create sample learning data for testing? (y/N): ").lower().strip()
    )
    if create_sample == "y":
        print("6. Creating sample learning data...")
        result = await integration.create_sample_learning_data()
        print(f"   {result}\n")

    print("✅ PostgreSQL Learning System Integration Complete!")
    print("\nNext steps:")
    print("1. Update your database connection configuration")
    print("2. Import and use PostgreSQLLearningSystem in your agents")
    print("3. Start recording task executions to build learning data")
    print("4. Monitor the learning dashboard for insights")


if __name__ == "__main__":
    asyncio.run(main())
