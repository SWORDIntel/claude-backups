#!/bin/bash
# Docker Setup Validation Script
# Validates all critical components before starting containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔍 Claude Docker Setup Validation"
echo "================================="
echo

cd "$PROJECT_ROOT"

# Track validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

validate_file() {
    local file=$1
    local description=$2
    local required=${3:-true}
    
    if [ -f "$file" ]; then
        echo "✅ $description: $file"
    else
        if [ "$required" = "true" ]; then
            echo "❌ $description: MISSING - $file"
            ((VALIDATION_ERRORS++))
        else
            echo "⚠️  $description: OPTIONAL - $file (missing)"
            ((VALIDATION_WARNINGS++))
        fi
    fi
}

validate_directory() {
    local dir=$1
    local description=$2
    local create=${3:-false}
    
    if [ -d "$dir" ]; then
        echo "✅ $description: $dir"
    else
        if [ "$create" = "true" ]; then
            echo "📁 Creating $description: $dir"
            mkdir -p "$dir"
            echo "✅ $description: Created"
        else
            echo "❌ $description: MISSING - $dir"
            ((VALIDATION_ERRORS++))
        fi
    fi
}

echo "📋 File Validation:"
echo "==================="

# Core Docker files
validate_file "docker-compose.yml" "Docker Compose configuration"
validate_file ".env.docker" "Environment template"
validate_file "database/docker/docker-start.sh" "Docker startup script"

# Dockerfiles
validate_file "database/docker/Dockerfile.learning" "Learning system Dockerfile"
validate_file "database/docker/Dockerfile.bridge" "Bridge Dockerfile" 

# Configuration files
validate_file "database/docker/config/postgresql.conf" "PostgreSQL configuration"
validate_file "database/docker/config/prometheus.yml" "Prometheus configuration"

# SQL initialization files
validate_file "database/sql/auth_db_setup.sql" "Auth database schema"
validate_file "database/sql/learning_system_schema_pg16_compatible.sql" "Learning schema (PG16 compatible)"
validate_file "database/sql/postgresql_16_json_compatibility_layer.sql" "JSON compatibility layer"

# Python learning system
validate_file "agents/src/python/postgresql_learning_system.py" "Learning system main module"
validate_file "requirements.txt" "Python requirements"

echo
echo "📁 Directory Validation:"
echo "========================"

# Required directories
validate_directory "logs" "Logs directory" true
validate_directory "database/data/postgresql" "PostgreSQL data directory" true
validate_directory "database/docker/config" "Docker config directory" true
validate_directory "agents/src/python" "Python source directory"
validate_directory "config" "Configuration directory" true

echo
echo "🔧 Configuration Validation:"
echo "============================"

# Check docker-compose syntax
if command -v docker-compose &> /dev/null; then
    if docker-compose config -q &> /dev/null; then
        echo "✅ Docker Compose syntax: Valid"
    else
        echo "❌ Docker Compose syntax: Invalid"
        echo "   Run: docker-compose config"
        ((VALIDATION_ERRORS++))
    fi
else
    if docker compose config -q &> /dev/null; then
        echo "✅ Docker Compose syntax: Valid (docker compose)"
    else
        echo "❌ Docker Compose syntax: Invalid"
        echo "   Run: docker compose config"
        ((VALIDATION_ERRORS++))
    fi
fi

# Check .env file
if [ -f ".env" ]; then
    echo "✅ Environment file: .env exists"
    if grep -q "claude_secure_pass_change_me" .env; then
        echo "⚠️  Security warning: Default password detected in .env"
        ((VALIDATION_WARNINGS++))
    fi
else
    echo "⚠️  Environment file: .env not found (will use .env.docker)"
    ((VALIDATION_WARNINGS++))
fi

# Check SQL file compatibility
if grep -q "JSON_ARRAY" database/sql/learning_system_schema_pg16_compatible.sql 2>/dev/null; then
    echo "❌ SQL compatibility: Found JSON_ARRAY() in PG16 compatible file"
    echo "   Should use json_build_array() instead"
    ((VALIDATION_ERRORS++))
else
    echo "✅ SQL compatibility: PostgreSQL 16 compatible"
fi

echo
echo "🐳 Docker Environment Check:"
echo "============================"

# Check Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker: Installed"
    if docker info &> /dev/null; then
        echo "✅ Docker: Running"
    else
        echo "❌ Docker: Not running or no permission"
        echo "   Run: sudo systemctl start docker"
        echo "   Or: sudo usermod -aG docker $USER && newgrp docker"
        ((VALIDATION_ERRORS++))
    fi
else
    echo "❌ Docker: Not installed"
    echo "   Install: curl -fsSL https://get.docker.com | sh"
    ((VALIDATION_ERRORS++))
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose: Installed (standalone)"
elif docker compose version &> /dev/null; then
    echo "✅ Docker Compose: Installed (plugin)"
else
    echo "❌ Docker Compose: Not installed"
    echo "   Install: sudo apt-get install docker-compose-plugin"
    ((VALIDATION_ERRORS++))
fi

echo
echo "📊 Validation Summary:"
echo "====================="

if [ $VALIDATION_ERRORS -eq 0 ]; then
    echo "✅ All critical validations passed!"
    if [ $VALIDATION_WARNINGS -gt 0 ]; then
        echo "⚠️  $VALIDATION_WARNINGS warnings (non-critical)"
    fi
    echo
    echo "🚀 Ready to start Docker environment:"
    echo "   ./database/docker/docker-start.sh"
    exit 0
else
    echo "❌ $VALIDATION_ERRORS critical errors found"
    if [ $VALIDATION_WARNINGS -gt 0 ]; then
        echo "⚠️  $VALIDATION_WARNINGS warnings"
    fi
    echo
    echo "🔧 Fix the errors above before starting Docker environment"
    exit 1
fi