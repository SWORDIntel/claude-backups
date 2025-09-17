#!/usr/bin/env python3
"""
Learning System Diagnostic Tool
Comprehensive health check for the Claude Agent Learning System
"""

import subprocess
import json
import sys
from datetime import datetime, timedelta
import os

def run_command(cmd, description=""):
    """Run a command and return result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "command": cmd,
            "description": description
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Command timed out",
            "command": cmd,
            "description": description
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "command": cmd,
            "description": description
        }

def check_docker_status():
    """Check PostgreSQL Docker container status"""
    print("🐳 DOCKER CONTAINER STATUS")
    print("=" * 50)

    # Check container running
    result = run_command("docker ps | grep claude-postgres", "Check container running")
    if result["success"]:
        print("✅ PostgreSQL container is running")
        print(f"   {result['stdout']}")
    else:
        print("❌ PostgreSQL container not running")
        return False

    # Check container health
    result = run_command("docker inspect claude-postgres --format='{{.State.Health.Status}}'", "Check health")
    if result["success"] and "healthy" in result["stdout"]:
        print("✅ Container health: HEALTHY")
    else:
        print(f"⚠️  Container health: {result['stdout']}")

    # Check port mapping
    result = run_command("docker port claude-postgres", "Check port mapping")
    if result["success"]:
        print("✅ Port mapping:")
        print(f"   {result['stdout']}")

    print()
    return True

def check_database_connection():
    """Check database connectivity and basic structure"""
    print("🗄️  DATABASE CONNECTION & STRUCTURE")
    print("=" * 50)

    # Test basic connection
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c 'SELECT version();'",
        "Test database connection"
    )
    if result["success"]:
        print("✅ Database connection successful")
        version_line = result["stdout"].split('\n')[2] if len(result["stdout"].split('\n')) > 2 else result["stdout"]
        print(f"   {version_line}")
    else:
        print("❌ Database connection failed")
        print(f"   Error: {result['stderr']}")
        return False

    # Check learning schema exists
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c \"SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'enhanced_learning';\"",
        "Check learning schema"
    )
    if result["success"] and "enhanced_learning" in result["stdout"]:
        print("✅ enhanced_learning schema exists")
    else:
        print("❌ enhanced_learning schema missing")
        return False

    # Check tables exist
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c \"\\dt enhanced_learning.*\"",
        "Check learning tables"
    )
    if result["success"]:
        print("✅ Learning tables found:")
        lines = result["stdout"].split('\n')
        for line in lines:
            if '|' in line and 'table' in line:
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 2:
                    print(f"   - {parts[1]}")
    else:
        print("❌ Learning tables check failed")

    print()
    return True

def check_learning_data():
    """Check learning data and recent activity"""
    print("📊 LEARNING DATA STATUS")
    print("=" * 50)

    # Check agent_metrics records
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \"SELECT COUNT(*) FROM enhanced_learning.agent_metrics;\"",
        "Count agent metrics"
    )
    if result["success"]:
        count = result["stdout"].strip()
        print(f"📈 Agent metrics records: {count}")
        if int(count) == 0:
            print("   ⚠️  No learning data collected yet")
        else:
            print("   ✅ Learning data present")

    # Check learning_analytics records
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \"SELECT COUNT(*) FROM enhanced_learning.learning_analytics;\"",
        "Count learning analytics"
    )
    if result["success"]:
        count = result["stdout"].strip()
        print(f"📊 Learning analytics records: {count}")

    # Check recent activity (last 24 hours)
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \"SELECT COUNT(*) FROM enhanced_learning.agent_metrics WHERE timestamp > NOW() - INTERVAL '24 hours';\"",
        "Recent activity check"
    )
    if result["success"]:
        count = result["stdout"].strip()
        print(f"🕒 Records in last 24h: {count}")
        if int(count) == 0:
            print("   ⚠️  No recent learning activity")
        else:
            print("   ✅ Recent learning activity detected")

    # Check unique agents
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \"SELECT COUNT(DISTINCT agent_name) FROM enhanced_learning.agent_metrics;\"",
        "Unique agents check"
    )
    if result["success"]:
        count = result["stdout"].strip()
        print(f"🤖 Unique agents in system: {count}")

    print()

def check_extensions():
    """Check PostgreSQL extensions"""
    print("🔌 DATABASE EXTENSIONS")
    print("=" * 50)

    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c \"SELECT extname, extversion FROM pg_extension;\"",
        "List extensions"
    )
    if result["success"]:
        print("✅ Installed extensions:")
        lines = result["stdout"].split('\n')
        for line in lines:
            if '|' in line and not line.startswith('-') and 'extname' not in line:
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 2 and parts[0]:
                    print(f"   - {parts[0]} (v{parts[1]})")

    # Specifically check for pgvector
    result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c \"SELECT extname FROM pg_extension WHERE extname = 'vector';\"",
        "Check pgvector"
    )
    if result["success"] and "vector" in result["stdout"]:
        print("✅ pgvector extension available")
    else:
        print("❌ pgvector extension missing")

    print()

def check_learning_scripts():
    """Check learning system scripts availability"""
    print("📜 LEARNING SCRIPTS STATUS")
    print("=" * 50)

    scripts_to_check = [
        "agents/src/python/postgresql_learning_system.py",
        "agents/src/python/advanced_learning_analytics.py",
        "agents/src/python/learning_orchestrator_bridge.py",
        "agents/src/python/claude_agents/cli/learning_cli.py",
        "agents/src/python/enhanced_learning_collector.py"
    ]

    for script in scripts_to_check:
        if os.path.exists(script):
            print(f"✅ {script}")
        else:
            print(f"❌ {script} (missing)")

    print()

def check_environment():
    """Check environment variables and configuration"""
    print("🌐 ENVIRONMENT CONFIGURATION")
    print("=" * 50)

    env_vars = [
        "POSTGRES_PORT",
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD"
    ]

    for var in env_vars:
        value = os.environ.get(var)
        if value:
            # Mask password
            display_value = "*" * len(value) if "PASSWORD" in var else value
            print(f"✅ {var}: {display_value}")
        else:
            print(f"⚠️  {var}: Not set")

    print()

def generate_summary():
    """Generate overall system health summary"""
    print("📋 SYSTEM HEALTH SUMMARY")
    print("=" * 50)

    # Quick health indicators
    docker_ok = run_command("docker ps | grep claude-postgres", "")["success"]
    db_ok = run_command("docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c 'SELECT 1;'", "")["success"]

    # Data presence
    data_result = run_command(
        "docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c \"SELECT COUNT(*) FROM enhanced_learning.agent_metrics;\"",
        ""
    )
    has_data = data_result["success"] and int(data_result["stdout"].strip()) > 0

    print(f"🐳 Docker Container: {'✅ RUNNING' if docker_ok else '❌ STOPPED'}")
    print(f"🗄️  Database Access: {'✅ CONNECTED' if db_ok else '❌ FAILED'}")
    print(f"📊 Learning Data: {'✅ ACTIVE' if has_data else '⚠️  EMPTY'}")

    if docker_ok and db_ok:
        print("\n🎉 Learning system is operational!")
        if not has_data:
            print("💡 Tip: No learning data yet. Use agents to start collecting metrics.")
    else:
        print("\n⚠️  Learning system needs attention!")
        print("💡 Try: docker-compose up -d postgres")

    print()

def main():
    """Main diagnostic routine"""
    print("🧠 Claude Agent Learning System Diagnostic")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print()

    try:
        check_docker_status()
        check_database_connection()
        check_extensions()
        check_learning_data()
        check_learning_scripts()
        check_environment()
        generate_summary()

    except KeyboardInterrupt:
        print("\n\nDiagnostic interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Diagnostic failed with error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()