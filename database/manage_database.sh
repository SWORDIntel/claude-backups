#!/bin/bash
# Database Management Convenience Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    "setup")
        echo "🗄️  Setting up PostgreSQL 17 authentication database..."
        sudo "$SCRIPT_DIR/scripts/deploy_auth_database.sh"
        ;;
    "test")
        echo "🧪 Running PostgreSQL 17 enhanced performance tests..."
        echo "Target: >2000 auth/sec, <25ms P95 latency"
        cd "$SCRIPT_DIR"
        python3 tests/auth_db_performance_test.py
        ;;
    "redis")
        echo "📊 Setting up Redis caching layer..."
        cd "$SCRIPT_DIR"
        python3 python/auth_redis_setup.py
        ;;
    "status")
        echo "📋 Database Status (PostgreSQL 17):"
        echo "  Database Version: PostgreSQL 17"
        echo "  Performance Target: >2000 auth/sec, <25ms P95"
        echo "  SQL Scripts: $SCRIPT_DIR/sql/"
        echo "  Python Utils: $SCRIPT_DIR/python/"
        echo "  Test Suite: $SCRIPT_DIR/tests/"
        echo "  Documentation: $SCRIPT_DIR/docs/"
        ;;
    *)
        echo "Usage: $0 {setup|test|redis|status}"
        echo ""
        echo "Commands (PostgreSQL 17):"
        echo "  setup  - Deploy PostgreSQL 17 authentication database"
        echo "  test   - Run enhanced performance tests (>2000 auth/sec)"
        echo "  redis  - Setup Redis caching layer"
        echo "  status - Show directory structure and PostgreSQL 17 info"
        ;;
esac
