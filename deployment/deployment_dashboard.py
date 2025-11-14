#!/usr/bin/env python3
"""
Learning System Deployment Dashboard v3.1
Real-time monitoring and validation interface
"""

import asyncio
import json
import logging
import os
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List

import asyncpg

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class DeploymentDashboard:
    """Comprehensive deployment monitoring and validation"""

    def __init__(self):
        self.db_connection_string = "postgresql://claude_agent:claude_secure_password@localhost:5433/claude_agents_auth"
        self.db_pool = None

    async def initialize(self):
        """Initialize database connection"""
        try:
            self.db_pool = await asyncpg.create_pool(
                self.db_connection_string, min_size=2, max_size=5
            )
            logger.info("Dashboard database connection initialized")
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")

    async def check_system_health(self) -> Dict[str, Any]:
        """Comprehensive system health check"""
        health_status = {
            "timestamp": datetime.utcnow().isoformat(),
            "overall_status": "healthy",
            "components": {},
        }

        # Check Docker containers
        health_status["components"]["docker"] = await self._check_docker_health()

        # Check Database connectivity
        health_status["components"]["database"] = await self._check_database_health()

        # Check Learning system
        health_status["components"][
            "learning_system"
        ] = await self._check_learning_system()

        # Check Wrapper integration
        health_status["components"]["wrapper"] = await self._check_wrapper_integration()

        # Check Log files
        health_status["components"]["log_files"] = await self._check_log_files()

        # Determine overall status
        component_statuses = [
            comp["status"] for comp in health_status["components"].values()
        ]
        if all(status == "healthy" for status in component_statuses):
            health_status["overall_status"] = "healthy"
        elif any(status == "critical" for status in component_statuses):
            health_status["overall_status"] = "critical"
        else:
            health_status["overall_status"] = "warning"

        return health_status

    async def _check_docker_health(self) -> Dict[str, Any]:
        """Check Docker container health"""
        try:
            # Check PostgreSQL container
            postgres_status = subprocess.run(
                [
                    "docker",
                    "ps",
                    "--filter",
                    "name=claude-postgres",
                    "--format",
                    "{{.Status}}",
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if (
                postgres_status.returncode == 0
                and "healthy" in postgres_status.stdout.lower()
            ):
                return {
                    "status": "healthy",
                    "postgres_container": "running",
                    "details": postgres_status.stdout.strip(),
                }
            else:
                return {
                    "status": "critical",
                    "postgres_container": "unhealthy",
                    "details": postgres_status.stderr or "Container not running",
                }

        except Exception as e:
            return {"status": "critical", "error": str(e)}

    async def _check_database_health(self) -> Dict[str, Any]:
        """Check database connectivity and schema"""
        try:
            if not self.db_pool:
                return {"status": "critical", "error": "Database pool not initialized"}

            async with self.db_pool.acquire() as conn:
                # Test basic connectivity
                result = await conn.fetchval("SELECT 1")

                # Check learning schema exists
                tables = await conn.fetch(
                    """
                    SELECT table_name FROM information_schema.tables 
                    WHERE table_schema = 'learning'
                """
                )

                table_names = [row["table_name"] for row in tables]
                expected_tables = [
                    "agent_metrics",
                    "task_embeddings",
                    "interaction_logs",
                    "learning_feedback",
                    "model_performance",
                ]

                missing_tables = set(expected_tables) - set(table_names)

                if missing_tables:
                    return {
                        "status": "warning",
                        "connection": "ok",
                        "missing_tables": list(missing_tables),
                        "existing_tables": table_names,
                    }
                else:
                    # Check recent data
                    recent_records = await conn.fetchval(
                        """
                        SELECT COUNT(*) FROM learning.agent_metrics 
                        WHERE created_at >= NOW() - INTERVAL '1 hour'
                    """
                    )

                    return {
                        "status": "healthy",
                        "connection": "ok",
                        "tables": table_names,
                        "recent_records": recent_records,
                    }

        except Exception as e:
            return {"status": "critical", "error": str(e)}

    async def _check_learning_system(self) -> Dict[str, Any]:
        """Check learning system functionality"""
        try:
            # Try to connect to learning API
            import aiohttp

            async with aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=5)
            ) as session:
                try:
                    async with session.get("http://localhost:8080/health") as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            return {
                                "status": "healthy",
                                "api_endpoint": "responsive",
                                "api_data": data,
                            }
                        else:
                            return {
                                "status": "warning",
                                "api_endpoint": f"status_code_{resp.status}",
                            }
                except:
                    return {
                        "status": "warning",
                        "api_endpoint": "not_accessible",
                        "note": "Learning API container may not be running",
                    }

        except ImportError:
            # Fallback without aiohttp
            return {"status": "warning", "note": "Cannot check API without aiohttp"}
        except Exception as e:
            return {"status": "warning", "error": str(e)}

    async def _check_wrapper_integration(self) -> Dict[str, Any]:
        """Check claude wrapper integration"""
        try:
            wrapper_path = Path.home() / "claude-backups" / "claude-wrapper-ultimate.sh"

            if not wrapper_path.exists():
                return {"status": "critical", "error": "Wrapper file not found"}

            # Check if wrapper has learning integration
            with open(wrapper_path, "r") as f:
                content = f.read()

            has_learning_vars = "LEARNING_CAPTURE_ENABLED" in content
            has_capture_function = "capture_execution()" in content
            has_database_logging = "asyncpg.connect" in content

            if has_learning_vars and has_capture_function and has_database_logging:
                status = "healthy"
            elif has_learning_vars or has_capture_function:
                status = "warning"
            else:
                status = "critical"

            return {
                "status": status,
                "wrapper_exists": True,
                "learning_integration": {
                    "environment_vars": has_learning_vars,
                    "capture_function": has_capture_function,
                    "database_logging": has_database_logging,
                },
            }

        except Exception as e:
            return {"status": "critical", "error": str(e)}

    async def _check_log_files(self) -> Dict[str, Any]:
        """Check log file creation and structure"""
        try:
            log_dir = Path.home() / ".claude-home" / "learning_logs"

            if not log_dir.exists():
                return {
                    "status": "warning",
                    "directory_exists": False,
                    "note": "Log directory will be created on first execution",
                }

            log_files = list(log_dir.glob("*.jsonl"))

            if not log_files:
                return {
                    "status": "warning",
                    "directory_exists": True,
                    "log_files": 0,
                    "note": "No log files yet - execute Claude to generate",
                }

            # Check most recent log file
            latest_log = max(log_files, key=lambda x: x.stat().st_mtime)

            # Try to parse a few lines
            valid_lines = 0
            total_lines = 0

            try:
                with open(latest_log, "r") as f:
                    for line in f:
                        total_lines += 1
                        if total_lines > 10:  # Check max 10 lines
                            break
                        try:
                            json.loads(line.strip())
                            valid_lines += 1
                        except:
                            pass
            except:
                pass

            return {
                "status": "healthy" if valid_lines > 0 else "warning",
                "directory_exists": True,
                "log_files": len(log_files),
                "latest_log": str(latest_log.name),
                "valid_json_lines": valid_lines,
                "total_lines_checked": total_lines,
            }

        except Exception as e:
            return {"status": "warning", "error": str(e)}

    async def get_learning_statistics(self) -> Dict[str, Any]:
        """Get comprehensive learning statistics"""
        if not self.db_pool:
            return {"error": "Database not available"}

        try:
            async with self.db_pool.acquire() as conn:
                # Basic stats
                stats = await conn.fetchrow(
                    """
                    SELECT 
                        COUNT(*) as total_executions,
                        COUNT(DISTINCT agent_name) as unique_agents,
                        AVG(duration_ms) as avg_duration_ms,
                        AVG(success_score) as success_rate,
                        MIN(created_at) as first_execution,
                        MAX(created_at) as last_execution
                    FROM learning.agent_metrics
                """
                )

                # Agent performance
                agent_stats = await conn.fetch(
                    """
                    SELECT 
                        agent_name,
                        COUNT(*) as executions,
                        AVG(success_score) as success_rate,
                        AVG(duration_ms) as avg_duration_ms
                    FROM learning.agent_metrics
                    GROUP BY agent_name
                    ORDER BY executions DESC
                    LIMIT 10
                """
                )

                # Recent activity (last 24 hours)
                recent_activity = await conn.fetch(
                    """
                    SELECT 
                        DATE_TRUNC('hour', created_at) as hour,
                        COUNT(*) as executions,
                        AVG(success_score) as success_rate
                    FROM learning.agent_metrics
                    WHERE created_at >= NOW() - INTERVAL '24 hours'
                    GROUP BY hour
                    ORDER BY hour DESC
                """
                )

                return {
                    "overall_stats": dict(stats) if stats else {},
                    "agent_performance": [dict(row) for row in agent_stats],
                    "recent_activity": [dict(row) for row in recent_activity],
                }

        except Exception as e:
            return {"error": str(e)}

    async def validate_deployment(self) -> Dict[str, Any]:
        """Run comprehensive deployment validation"""
        logger.info("Starting deployment validation...")

        validation_results = {
            "validation_timestamp": datetime.utcnow().isoformat(),
            "tests": {},
        }

        # Test 1: System Health
        health = await self.check_system_health()
        validation_results["tests"]["system_health"] = {
            "passed": health["overall_status"] == "healthy",
            "details": health,
        }

        # Test 2: Database Connection
        try:
            async with self.db_pool.acquire() as conn:
                test_result = await conn.fetchval("SELECT 'connection_ok'::text")
                validation_results["tests"]["database_connection"] = {
                    "passed": test_result == "connection_ok",
                    "details": {"connection_test": test_result},
                }
        except Exception as e:
            validation_results["tests"]["database_connection"] = {
                "passed": False,
                "details": {"error": str(e)},
            }

        # Test 3: Wrapper Function Test
        try:
            wrapper_path = Path.home() / "claude-backups" / "claude-wrapper-ultimate.sh"
            test_cmd = [
                "bash",
                "-c",
                f"source {wrapper_path} && type capture_execution",
            ]
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=5)

            validation_results["tests"]["wrapper_function"] = {
                "passed": result.returncode == 0,
                "details": {
                    "return_code": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                },
            }
        except Exception as e:
            validation_results["tests"]["wrapper_function"] = {
                "passed": False,
                "details": {"error": str(e)},
            }

        # Test 4: Log Directory Access
        log_dir = Path.home() / ".claude-home" / "learning_logs"
        try:
            log_dir.mkdir(parents=True, exist_ok=True)
            test_file = log_dir / "test.tmp"
            test_file.write_text("test")
            test_file.unlink()

            validation_results["tests"]["log_directory"] = {
                "passed": True,
                "details": {"directory": str(log_dir), "writable": True},
            }
        except Exception as e:
            validation_results["tests"]["log_directory"] = {
                "passed": False,
                "details": {"error": str(e)},
            }

        # Calculate overall validation result
        all_tests_passed = all(
            test["passed"] for test in validation_results["tests"].values()
        )
        validation_results["overall_passed"] = all_tests_passed
        validation_results["summary"] = {
            "total_tests": len(validation_results["tests"]),
            "passed_tests": sum(
                1 for test in validation_results["tests"].values() if test["passed"]
            ),
            "failed_tests": sum(
                1 for test in validation_results["tests"].values() if not test["passed"]
            ),
        }

        return validation_results

    async def generate_deployment_report(self) -> str:
        """Generate comprehensive deployment report"""
        health = await self.check_system_health()
        validation = await self.validate_deployment()
        stats = await self.get_learning_statistics()

        report = f"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    CLAUDE LEARNING SYSTEM DEPLOYMENT REPORT                 ║
║                               Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 OVERALL STATUS: {health['overall_status'].upper()}
🧪 VALIDATION: {'✅ PASSED' if validation['overall_passed'] else '❌ FAILED'}

📊 SYSTEM COMPONENTS:
"""

        for component, status in health["components"].items():
            status_icon = (
                "✅"
                if status["status"] == "healthy"
                else "⚠️" if status["status"] == "warning" else "❌"
            )
            report += f"   {status_icon} {component.upper()}: {status['status']}\n"

        report += f"""
🔢 LEARNING STATISTICS:
   Total Executions: {stats.get('overall_stats', {}).get('total_executions', 0)}
   Unique Agents: {stats.get('overall_stats', {}).get('unique_agents', 0)}
   Success Rate: {stats.get('overall_stats', {}).get('success_rate', 0):.1%}
   Avg Duration: {stats.get('overall_stats', {}).get('avg_duration_ms', 0):.0f}ms

🧪 VALIDATION RESULTS:
   Tests Run: {validation['summary']['total_tests']}
   Passed: {validation['summary']['passed_tests']}
   Failed: {validation['summary']['failed_tests']}

📋 NEXT STEPS:
"""

        if health["overall_status"] == "healthy" and validation["overall_passed"]:
            report += """   🚀 System is ready for production use!
   🎯 Execute Claude commands to start learning data collection
   📊 Monitor dashboard at http://localhost:8080/dashboard
   📈 Check learning statistics regularly
"""
        else:
            report += "   🔧 Address the following issues:\n"
            for test_name, test_result in validation["tests"].items():
                if not test_result["passed"]:
                    report += f"      ❌ Fix {test_name}: {test_result.get('details', {}).get('error', 'Check details')}\n"

        return report


async def main():
    """Main dashboard interface"""
    dashboard = DeploymentDashboard()
    await dashboard.initialize()

    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1].lower()

        if command == "health":
            health = await dashboard.check_system_health()
            print(json.dumps(health, indent=2))
        elif command == "validate":
            validation = await dashboard.validate_deployment()
            print(json.dumps(validation, indent=2))
        elif command == "stats":
            stats = await dashboard.get_learning_statistics()
            print(json.dumps(stats, indent=2))
        elif command == "report":
            report = await dashboard.generate_deployment_report()
            print(report)
        else:
            print(f"Unknown command: {command}")
            print("Available commands: health, validate, stats, report")
    else:
        # Default: show full report
        report = await dashboard.generate_deployment_report()
        print(report)


if __name__ == "__main__":
    asyncio.run(main())
