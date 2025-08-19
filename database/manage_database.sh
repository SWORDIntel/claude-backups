#!/bin/bash
# Database Management Convenience Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    "setup")
        echo "🗄️  Setting up authentication database..."
        sudo "$SCRIPT_DIR/scripts/deploy_auth_database.sh"
        ;;
    "test")
        echo "🧪 Running performance tests..."
        cd "$SCRIPT_DIR"
        python3 tests/auth_db_performance_test.py
        ;;
    "redis")
        echo "📊 Setting up Redis..."
        cd "$SCRIPT_DIR"
        python3 python/auth_redis_setup.py
        ;;
    "status")
        echo "📋 Database Status:"
        echo "  SQL Scripts: $SCRIPT_DIR/sql/"
        echo "  Python Utils: $SCRIPT_DIR/python/"
        echo "  Test Suite: $SCRIPT_DIR/tests/"
        echo "  Documentation: $SCRIPT_DIR/docs/"
        ;;
    *)
        echo "Usage: $0 {setup|test|redis|status}"
        echo ""
        echo "Commands:"
        echo "  setup  - Deploy authentication database"
        echo "  test   - Run performance tests"
        echo "  redis  - Setup Redis configuration"
        echo "  status - Show directory structure"
        ;;
esac
