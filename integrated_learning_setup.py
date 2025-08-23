#!/bin/bash
"""
INTEGRATED ENHANCED LEARNING SYSTEM SETUP v4.0
Complete setup combining Python enhancements with system integration
"""

set -e  # Exit on error

echo "=================================================="
echo "Integrated Enhanced Agent Learning System Setup v4.0"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory detection
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DATABASE_DIR="$PROJECT_ROOT/database"
CONFIG_DIR="$PROJECT_ROOT/config"
AGENTS_DIR="$PROJECT_ROOT/agents"
PYTHON_DIR="$PROJECT_ROOT/agents/src/python"

# Parse command line arguments
RESET_MODE=false
CUSTOM_PORT=""
SKIP_DEPS=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET_MODE=true
            shift
            ;;
        --port)
            CUSTOM_PORT="$2"
            shift 2
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Integrated Enhanced PostgreSQL Learning System Setup

This script sets up the complete learning system with PostgreSQL integration,
combining Python enhancements with system-level configuration.

Usage:
  $0 [options]

Options:
  --help, -h     Show this help message
  --port PORT    Override PostgreSQL port (default: auto-detect)
  --reset        Reset existing data before setup
  --skip-deps    Skip dependency installation
  --verbose      Enable verbose output

Environment Variables:
  POSTGRES_HOST      Database host (default: localhost)
  POSTGRES_PORT      Database port (default: auto-detect 5433/5432)
  POSTGRES_DB        Database name (default: claude_auth)
  POSTGRES_USER      Database user (default: claude_auth)
  POSTGRES_PASSWORD  Database password (default: claude_auth_pass)

Examples:
  # Standard setup
  $0
  
  # Use specific port
  $0 --port 5432
  
  # Reset and setup with verbose output
  $0 --reset --verbose

Features:
  • Automatic PostgreSQL port detection (5433 for local, 5432 for system)
  • Dependency installation with multiple fallback methods
  • Deprecated file migration (SQLite → PostgreSQL)
  • Comprehensive error handling and recovery
  • Import of existing learning data
  • Creation of convenience scripts
  • Claude-Code bridge integration
  • Real-time monitoring setup
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check command availability
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to detect PostgreSQL port
detect_postgres_port() {
    if [ ! -z "$CUSTOM_PORT" ]; then
        echo "$CUSTOM_PORT"
        return
    fi
    
    if [ ! -z "$POSTGRES_PORT" ]; then
        echo "$POSTGRES_PORT"
        return
    fi
    
    # Check if port 5433 is open (local instance)
    if nc -z localhost 5433 2>/dev/null; then
        echo "5433"
        return
    fi
    
    # Check if port 5432 is open (system PostgreSQL)
    if nc -z localhost 5432 2>/dev/null; then
        echo "5432"
        return
    fi
    
    # Default to 5433 for local instance
    echo "5433"
}

# Function to check Python package
check_python_package() {
    if python3 -c "import $1" 2>/dev/null; then
        [ "$VERBOSE" = true ] && echo -e "${GREEN}✓ Python package $1 is installed${NC}"
        return 0
    else
        [ "$VERBOSE" = true ] && echo -e "${YELLOW}○ Python package $1 is not installed${NC}"
        return 1
    fi
}

# Function to start local PostgreSQL if needed
start_local_postgres() {
    local port=$1
    
    if [ "$port" = "5433" ]; then
        if [ -f "$DATABASE_DIR/manage_database.sh" ]; then
            if ! nc -z localhost 5433 2>/dev/null; then
                echo "Starting local PostgreSQL instance on port 5433..."
                "$DATABASE_DIR/manage_database.sh" start
                sleep 3
                
                if nc -z localhost 5433 2>/dev/null; then
                    echo -e "${GREEN}✓ Local PostgreSQL started on port 5433${NC}"
                    return 0
                else
                    echo -e "${RED}✗ Failed to start local PostgreSQL${NC}"
                    return 1
                fi
            else
                echo -e "${GREEN}✓ Local PostgreSQL already running on port 5433${NC}"
                return 0
            fi
        fi
    fi
    
    return 0
}

# Function to migrate deprecated files
migrate_deprecated_files() {
    echo ""
    echo "📦 Checking for deprecated SQLite files..."
    
    DEPRECATED_DIR="$PYTHON_DIR/deprecated"
    mkdir -p "$DEPRECATED_DIR"
    
    local migrated=0
    
    # Check for old SQLite learning system
    if [ -f "$PYTHON_DIR/agent_learning_system.py" ]; then
        echo "  Moving agent_learning_system.py to deprecated/"
        mv "$PYTHON_DIR/agent_learning_system.py" "$DEPRECATED_DIR/"
        ((migrated++))
    fi
    
    # Check for SQLite database files
    for db_file in "$PYTHON_DIR"/*.db; do
        if [ -f "$db_file" ]; then
            echo "  Moving $(basename "$db_file") to deprecated/"
            mv "$db_file" "$DEPRECATED_DIR/"
            ((migrated++))
        fi
    done
    
    if [ $migrated -gt 0 ]; then
        # Create README in deprecated folder
        cat > "$DEPRECATED_DIR/README.md" << EOF
# Deprecated Files

These files have been replaced by PostgreSQL-based implementations.

## Migrated Files
- SQLite-based learning system files
- Old database files (.db)

## Replacement
Use \`postgresql_learning_system.py\` and the integrated PostgreSQL setup instead.

## Migration Date
$(date)
EOF
        echo -e "${YELLOW}⚠ Moved $migrated deprecated files to deprecated/${NC}"
    else
        echo -e "${GREEN}✓ No deprecated files found${NC}"
    fi
}

echo ""
echo "Step 1: System Requirements Check"
echo "===================================="

# Check PostgreSQL
if check_command psql; then
    PG_VERSION=$(psql --version | awk '{print $3}' | sed 's/\..*//g')
    if [ "$PG_VERSION" -ge 13 ]; then
        echo -e "${GREEN}✓ PostgreSQL version $PG_VERSION is compatible${NC}"
    else
        echo -e "${YELLOW}⚠ PostgreSQL version $PG_VERSION may need upgrade (13+ recommended)${NC}"
    fi
else
    echo -e "${RED}PostgreSQL is required. Install with:${NC}"
    echo "  sudo apt-get install postgresql postgresql-contrib"
    exit 1
fi

# Check Python
if check_command python3; then
    PY_VERSION=$(python3 --version | awk '{print $2}')
    echo -e "${GREEN}✓ Python $PY_VERSION found${NC}"
else
    echo -e "${RED}Python 3.8+ is required${NC}"
    exit 1
fi

# Check for netcat (for port checking)
if ! check_command nc; then
    echo -e "${YELLOW}Installing netcat for port detection...${NC}"
    sudo apt-get install -y netcat-openbsd 2>/dev/null || true
fi

echo ""
echo "Step 2: Database Configuration"
echo "================================"

# Detect PostgreSQL port
DB_PORT=$(detect_postgres_port)
DB_NAME="${POSTGRES_DB:-claude_auth}"
DB_USER="${POSTGRES_USER:-claude_auth}"
DB_HOST="${POSTGRES_HOST:-localhost}"

echo "Database configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"

# Check for local socket connection if using port 5433
if [ "$DB_PORT" = "5433" ] && [ -d "$DATABASE_DIR/data/run" ]; then
    DB_HOST="$DATABASE_DIR/data/run"
    echo -e "${GREEN}✓ Using local socket connection${NC}"
fi

# Start local PostgreSQL if needed
start_local_postgres "$DB_PORT"

# Get or prompt for password
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -n "Enter PostgreSQL password for user $DB_USER: "
    read -s DB_PASSWORD
    echo ""
else
    DB_PASSWORD="$POSTGRES_PASSWORD"
fi

export PGPASSWORD=$DB_PASSWORD

echo ""
echo "Step 3: Python Environment Setup"
echo "=================================="

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${GREEN}✓ Virtual environment exists${NC}"
fi

# Activate virtual environment
source venv/bin/activate

if [ "$SKIP_DEPS" = false ]; then
    echo ""
    echo "Step 4: Installing Python Dependencies"
    echo "======================================="
    
    # Upgrade pip
    pip install --quiet --upgrade pip
    
    # Core requirements
    echo "Installing core dependencies..."
    pip install --quiet psycopg2-binary>=2.9.0 || echo -e "${YELLOW}⚠ psycopg2-binary installation issue${NC}"
    pip install --quiet asyncpg>=0.27.0 || echo -e "${YELLOW}⚠ asyncpg installation issue${NC}"
    pip install --quiet numpy>=1.21.0 || echo -e "${YELLOW}⚠ numpy installation issue${NC}"
    pip install --quiet scikit-learn>=1.0.0 || echo -e "${YELLOW}⚠ scikit-learn installation issue${NC}"
    pip install --quiet joblib>=1.0.0 || echo -e "${YELLOW}⚠ joblib installation issue${NC}"
    pip install --quiet aiofiles || echo -e "${YELLOW}⚠ aiofiles installation issue${NC}"
    
    # Optional but recommended
    echo "Installing optional dependencies..."
    pip install --quiet pandas matplotlib seaborn 2>/dev/null || echo -e "${YELLOW}○ Optional analysis packages skipped${NC}"
    
    # Try to install PyTorch (CPU version)
    if [ "$VERBOSE" = true ]; then
        echo "Attempting PyTorch installation (this may take a while)..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || \
            echo -e "${YELLOW}○ PyTorch installation skipped (optional for deep learning)${NC}"
    else
        pip install --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Python dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠ Skipping dependency installation${NC}"
fi

# Migrate deprecated files
migrate_deprecated_files

echo ""
echo "Step 5: Database Setup"
echo "======================="

# Check if database exists
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo -e "${GREEN}✓ Database $DB_NAME exists${NC}"
    
    if [ "$RESET_MODE" = true ]; then
        echo -e "${YELLOW}Resetting database (--reset flag enabled)...${NC}"
        dropdb -h $DB_HOST -p $DB_PORT -U $DB_USER --if-exists $DB_NAME
        createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
        echo -e "${GREEN}✓ Database reset complete${NC}"
    fi
else
    echo "Creating database $DB_NAME..."
    createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
    echo -e "${GREEN}✓ Database created${NC}"
fi

echo ""
echo "Step 6: Running Enhanced Python Setup"
echo "======================================="

# Create temporary Python setup runner
cat > "$PYTHON_DIR/run_enhanced_setup.py" << EOF
#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path

# Add project to path
sys.path.insert(0, '$PYTHON_DIR')

# Set environment variables
os.environ['POSTGRES_HOST'] = '$DB_HOST'
os.environ['POSTGRES_PORT'] = '$DB_PORT'
os.environ['POSTGRES_DB'] = '$DB_NAME'
os.environ['POSTGRES_USER'] = '$DB_USER'
os.environ['POSTGRES_PASSWORD'] = '$DB_PASSWORD'

# Import and run the enhanced setup
try:
    from setup_learning_system import EnhancedPostgreSQLLearningSetup
    
    setup = EnhancedPostgreSQLLearningSetup()
    
    # Run individual steps
    print("Installing learning schema...")
    if setup.install_learning_schema():
        print("✓ Schema installed")
    
    print("Initializing agents...")
    if setup.initialize_agents():
        print("✓ Agents initialized")
    
    print("Setting up learning functions...")
    if setup.setup_learning_functions():
        print("✓ Functions created")
    
    print("Importing existing learning data...")
    if setup.import_existing_learning_data():
        print("✓ Data imported")
        
    print("Creating convenience scripts...")
    setup.create_convenience_scripts()
    
    sys.exit(0)
    
except Exception as e:
    print(f"Error in enhanced setup: {e}")
    sys.exit(1)
EOF

python3 "$PYTHON_DIR/run_enhanced_setup.py"
PYTHON_SETUP_RESULT=$?

echo ""
echo "Step 7: Creating Configuration Files"
echo "======================================"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create database config
cat > "$CONFIG_DIR/database.json" << EOF
{
  "host": "$DB_HOST",
  "port": $DB_PORT,
  "database": "$DB_NAME",
  "user": "$DB_USER",
  "password": "$DB_PASSWORD"
}
EOF
echo -e "${GREEN}✓ Database configuration saved${NC}"

# Create learning system config
cat > "$CONFIG_DIR/learning_config.json" << EOF
{
  "learning_mode": "adaptive",
  "optimization_objective": "balanced",
  "auto_retrain_threshold": 50,
  "alert_thresholds": {
    "success_rate_min": 0.7,
    "duration_p95_max": 120,
    "error_rate_max": 0.2
  },
  "exploration_budget": 0.2,
  "learning_rate": 0.1,
  "confidence_threshold": 0.7,
  "model_update_frequency": 3600,
  "monitoring_interval": 60,
  "features": {
    "ml_models_enabled": true,
    "deep_learning_available": $(check_python_package torch && echo "true" || echo "false"),
    "real_time_monitoring": true,
    "auto_optimization": true,
    "deprecated_migration": true
  }
}
EOF
echo -e "${GREEN}✓ Learning configuration saved${NC}"

echo ""
echo "Step 8: Environment Setup"
echo "=========================="

# Create .env file
cat > .env << EOF
# Database Configuration
POSTGRES_HOST=$DB_HOST
POSTGRES_PORT=$DB_PORT
POSTGRES_DB=$DB_NAME
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASSWORD

# Learning System Configuration
LEARNING_MODE=adaptive
AUTO_INITIALIZE=true
ENABLE_MONITORING=true
ENABLE_ML_MODELS=true

# Agent System Paths
AGENT_BASE_PATH=$AGENTS_DIR
PYTHONPATH=$PYTHON_DIR:\$PYTHONPATH

# Feature Flags
ENABLE_DEEP_LEARNING=$(check_python_package torch && echo "true" || echo "false")
ENABLE_DEPRECATED_MIGRATION=true
ENABLE_AUTO_PORT_DETECTION=true
EOF
echo -e "${GREEN}✓ Environment variables configured${NC}"

# Add to bashrc if not already there
if ! grep -q "claude_learning_system" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Claude Agent Learning System v4.0" >> ~/.bashrc
    echo "export AGENT_BASE_PATH=$AGENTS_DIR" >> ~/.bashrc
    echo "export PYTHONPATH=$PYTHON_DIR:\$PYTHONPATH" >> ~/.bashrc
    echo "" >> ~/.bashrc
    echo "# Convenience aliases" >> ~/.bashrc
    echo "alias claude-learning='cd $PYTHON_DIR && python3 claude_code_learning_bridge.py'" >> ~/.bashrc
    echo "alias claude-dashboard='cd $PYTHON_DIR && python3 learning_cli.py dashboard'" >> ~/.bashrc
    echo "alias claude-status='cd $PYTHON_DIR && python3 learning_cli.py status'" >> ~/.bashrc
    echo "alias claude-insights='cd $PYTHON_DIR && python3 learning_cli.py insights'" >> ~/.bashrc
    echo "alias claude-export='cd $DATABASE_DIR/scripts && ./learning_sync.sh export'" >> ~/.bashrc
    echo -e "${GREEN}✓ Shell aliases added to ~/.bashrc${NC}"
fi

echo ""
echo "Step 9: Creating Integration Scripts"
echo "====================================="

# Create main launcher script
cat > "$PYTHON_DIR/launch_learning_system.sh" << 'EOF'
#!/bin/bash
# Quick launcher for the learning system

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment if it exists
if [ -d "../../venv" ]; then
    source ../../venv/bin/activate
elif [ -d "venv" ]; then
    source venv/bin/activate
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f "../../.env" ]; then
    export $(cat ../../.env | grep -v '^#' | xargs)
fi

# Launch the bridge
python3 claude_code_learning_bridge.py "$@"
EOF
chmod +x "$PYTHON_DIR/launch_learning_system.sh"

# Create monitoring script
cat > "$PYTHON_DIR/monitor_learning_system.sh" << 'EOF'
#!/bin/bash
# Real-time monitoring for the learning system

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment
if [ -d "../../venv" ]; then
    source ../../venv/bin/activate
fi

# Load environment
if [ -f "../../.env" ]; then
    export $(cat ../../.env | grep -v '^#' | xargs)
fi

# Start monitoring
watch -n 5 "python3 learning_cli.py status --brief"
EOF
chmod +x "$PYTHON_DIR/monitor_learning_system.sh"

echo -e "${GREEN}✓ Integration scripts created${NC}"

echo ""
echo "Step 10: System Validation"
echo "==========================="

# Create comprehensive test script
cat > test_integrated_system.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import sys
import json
import os
from pathlib import Path

# Add Python directory to path
sys.path.append(os.environ.get('PYTHONPATH', '/home/ubuntu/Documents/Claude/agents/src/python'))

async def test_system():
    print("Testing Integrated Learning System...")
    test_results = {
        'database': False,
        'learning_system': False,
        'claude_bridge': False,
        'ml_models': False,
        'dashboard': False
    }
    
    try:
        # Test 1: Database connection
        print("\n1. Testing database connection...")
        import psycopg2
        with open('config/database.json') as f:
            db_config = json.load(f)
        
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM agent_metadata")
        agent_count = cursor.fetchone()[0]
        print(f"   ✓ Connected to database ({agent_count} agents registered)")
        test_results['database'] = True
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"   ✗ Database test failed: {e}")
    
    try:
        # Test 2: Learning system
        print("\n2. Testing learning system...")
        from postgresql_learning_system import PostgreSQLLearningSystem
        
        learning_system = PostgreSQLLearningSystem(db_config)
        await learning_system.initialize()
        print("   ✓ Learning system initialized")
        test_results['learning_system'] = True
        
    except Exception as e:
        print(f"   ✗ Learning system test failed: {e}")
    
    try:
        # Test 3: Claude-Code bridge
        print("\n3. Testing Claude-Code bridge...")
        from claude_code_learning_bridge import ClaudeCodeAgentLearningBridge
        
        bridge = ClaudeCodeAgentLearningBridge(auto_initialize=False)
        bridge.db_config = db_config
        await bridge.initialize()
        
        if bridge.initialized:
            print("   ✓ Claude-Code bridge initialized")
            test_results['claude_bridge'] = True
        else:
            print("   ✗ Bridge initialization incomplete")
            
    except Exception as e:
        print(f"   ✗ Bridge test failed: {e}")
    
    try:
        # Test 4: ML models
        print("\n4. Testing ML models...")
        if test_results['learning_system']:
            models = await learning_system.ml_engine.get_active_models()
            if models:
                print(f"   ✓ {len(models)} ML models available")
                test_results['ml_models'] = True
            else:
                print("   ○ No ML models trained yet")
        
    except Exception as e:
        print(f"   ○ ML models test skipped: {e}")
    
    try:
        # Test 5: Dashboard
        print("\n5. Testing dashboard...")
        if test_results['claude_bridge']:
            dashboard = await bridge.get_dashboard()
            if dashboard:
                print(f"   ✓ Dashboard available (status: {dashboard.get('status', 'unknown')})")
                test_results['dashboard'] = True
                
    except Exception as e:
        print(f"   ✗ Dashboard test failed: {e}")
    
    # Summary
    print("\n" + "="*50)
    print("Test Summary:")
    print("="*50)
    
    passed = sum(1 for v in test_results.values() if v)
    total = len(test_results)
    
    for test, result in test_results.items():
        status = "✓" if result else "✗"
        print(f"  {status} {test.replace('_', ' ').title()}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    return passed == total

if __name__ == "__main__":
    success = asyncio.run(test_system())
    sys.exit(0 if success else 1)
EOF

echo "Running system validation..."
python3 test_integrated_system.py
TEST_RESULT=$?

# Cleanup temporary files
rm -f test_integrated_system.py "$PYTHON_DIR/run_enhanced_setup.py"

echo ""
echo "=============================================="
if [ $TEST_RESULT -eq 0 ] && [ $PYTHON_SETUP_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ SETUP COMPLETE!${NC}"
    echo "=============================================="
    echo ""
    echo "The Integrated Enhanced Agent Learning System v4.0 is ready!"
    echo ""
    echo -e "${BLUE}Quick Start Commands:${NC}"
    echo "  claude-learning    - Start the learning bridge"
    echo "  claude-dashboard   - View the learning dashboard"
    echo "  claude-status      - Check system status"
    echo "  claude-insights    - View learning insights"
    echo "  claude-export      - Export learning data"
    echo ""
    echo -e "${BLUE}Python Usage:${NC}"
    echo "  from claude_code_learning_bridge import task_agent_invoke_with_learning"
    echo "  result = await task_agent_invoke_with_learning('director', 'Plan my project')"
    echo ""
    echo -e "${BLUE}Configuration Files:${NC}"
    echo "  $CONFIG_DIR/database.json"
    echo "  $CONFIG_DIR/learning_config.json"
    echo "  ./.env"
    echo ""
    echo -e "${BLUE}Management Scripts:${NC}"
    echo "  $PYTHON_DIR/launch_learning_system.sh"
    echo "  $PYTHON_DIR/monitor_learning_system.sh"
    echo "  $PYTHON_DIR/check_learning_status.sh"
    echo ""
    echo -e "${YELLOW}To activate in current shell:${NC}"
    echo "  source ~/.bashrc"
    echo "  source venv/bin/activate"
    echo ""
    echo -e "${GREEN}Happy Learning! 🚀${NC}"
else
    echo -e "${RED}Setup completed with errors${NC}"
    echo "=============================================="
    echo ""
    echo "Please check the output above for error details."
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  1. Check PostgreSQL is running on port $DB_PORT"
    echo "  2. Verify database credentials"
    echo "  3. Ensure Python dependencies installed correctly"
    echo "  4. Check file permissions in $PROJECT_ROOT"
    echo ""
    echo "For detailed logs, run with --verbose flag"
    echo "For help: $0 --help"
fi

exit $TEST_RESULT
