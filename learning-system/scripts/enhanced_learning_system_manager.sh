#!/bin/bash

# Enhanced Learning System Manager
# Manages Docker containers and learning system components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/database/docker"
PYTHON_DIR="${SCRIPT_DIR}/agents/src/python"
CLAUDE_VENV="/home/john/.local/share/claude/venv"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to check Docker daemon
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_color $RED "Error: Docker is not running or not accessible"
        exit 1
    fi
}

# Function to check if PostgreSQL container is running
check_postgres() {
    if docker ps | grep -q "claude-postgres"; then
        return 0
    else
        return 1
    fi
}

# Function to start the learning system
start_system() {
    print_color $BLUE "Starting Enhanced Learning System..."
    
    # Check Docker
    check_docker
    
    # Start PostgreSQL container
    print_color $YELLOW "Starting PostgreSQL container..."
    cd "${DOCKER_DIR}"
    docker-compose up -d postgres
    
    # Wait for PostgreSQL to be ready
    print_color $YELLOW "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec claude-postgres pg_isready -U claude_agent >/dev/null 2>&1; then
            print_color $GREEN "PostgreSQL is ready!"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_color $RED "PostgreSQL failed to start in time"
        exit 1
    fi
    
    # Check if tables exist
    print_color $YELLOW "Checking database schema..."
    table_count=$(docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'learning';" 2>/dev/null | tr -d ' ')
    
    if [ "$table_count" -eq "0" ] || [ -z "$table_count" ]; then
        print_color $YELLOW "Initializing database schema..."
        docker exec -i claude-postgres psql -U claude_agent -d claude_agents_auth < "${DOCKER_DIR}/init-learning-system-enhanced.sql"
        print_color $GREEN "Database schema initialized with enhanced tables!"
    else
        print_color $GREEN "Database schema already exists (${table_count} tables)"
    fi
    
    # Start the learning collector as a background process
    if [ -f "${CLAUDE_VENV}/bin/activate" ]; then
        print_color $YELLOW "Starting learning collector with Claude venv..."
        source "${CLAUDE_VENV}/bin/activate"
    fi
    
    print_color $GREEN "Enhanced Learning System is running!"
    print_color $BLUE "PostgreSQL: port 5433"
    print_color $BLUE "Schema: 9 enhanced tables with comprehensive tracking"
}

# Function to stop the learning system
stop_system() {
    print_color $BLUE "Stopping Enhanced Learning System..."
    
    # Stop PostgreSQL container
    if check_postgres; then
        print_color $YELLOW "Stopping PostgreSQL container..."
        cd "${DOCKER_DIR}"
        docker-compose stop postgres
        print_color $GREEN "PostgreSQL stopped"
    else
        print_color $YELLOW "PostgreSQL container is not running"
    fi
    
    print_color $GREEN "Enhanced Learning System stopped"
}

# Function to show system status
show_status() {
    print_color $BLUE "Enhanced Learning System Status"
    print_color $BLUE "================================"
    
    # Docker status
    if docker info >/dev/null 2>&1; then
        print_color $GREEN "Docker: Running"
    else
        print_color $RED "Docker: Not running"
    fi
    
    # PostgreSQL status
    if check_postgres; then
        print_color $GREEN "PostgreSQL: Running on port 5433"
        
        # Get table count
        table_count=$(docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'learning';" 2>/dev/null | tr -d ' ')
        print_color $GREEN "Tables: ${table_count} tables in learning schema"
        
        # Get record counts
        if [ "$table_count" -gt "0" ]; then
            print_color $YELLOW "\nTable Statistics:"
            docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c "
                SELECT 
                    table_name,
                    (SELECT COUNT(*) FROM learning.agent_metrics) as agent_metrics,
                    (SELECT COUNT(*) FROM learning.task_embeddings) as task_embeddings,
                    (SELECT COUNT(*) FROM learning.interaction_logs) as interactions,
                    (SELECT COUNT(*) FROM learning.learning_feedback) as feedback,
                    (SELECT COUNT(*) FROM learning.model_performance) as models,
                    (SELECT COUNT(*) FROM learning.agent_coordination_patterns) as patterns,
                    (SELECT COUNT(*) FROM learning.system_health_metrics) as health,
                    (SELECT COUNT(*) FROM learning.performance_baselines) as baselines,
                    (SELECT COUNT(*) FROM learning.git_operations_tracking) as git_ops
                FROM information_schema.tables 
                WHERE table_schema = 'learning'
                LIMIT 1;
            " 2>/dev/null | head -15
        fi
    else
        print_color $RED "PostgreSQL: Not running"
    fi
    
    # OpenVINO status
    if [ -f "${CLAUDE_VENV}/bin/python" ]; then
        openvino_status=$(${CLAUDE_VENV}/bin/python -c "import openvino; print('Available')" 2>/dev/null || echo "Not available")
        print_color $BLUE "\nOpenVINO: ${openvino_status}"
    fi
}

# Function to test the system
test_system() {
    print_color $BLUE "Testing Enhanced Learning System..."
    
    if ! check_postgres; then
        print_color $RED "PostgreSQL is not running. Please start the system first."
        exit 1
    fi
    
    # Activate Claude venv if available
    if [ -f "${CLAUDE_VENV}/bin/activate" ]; then
        source "${CLAUDE_VENV}/bin/activate"
    fi
    
    # Run the test
    print_color $YELLOW "Running collector test..."
    cd "${PYTHON_DIR}"
    python3 enhanced_learning_collector.py
    
    print_color $GREEN "Test completed!"
}

# Function to reset the database
reset_database() {
    print_color $YELLOW "Warning: This will delete all learning data!"
    read -p "Are you sure you want to reset the database? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_color $BLUE "Reset cancelled"
        return
    fi
    
    if ! check_postgres; then
        print_color $RED "PostgreSQL is not running"
        exit 1
    fi
    
    print_color $YELLOW "Dropping and recreating schema..."
    docker exec claude-postgres psql -U claude_agent -d claude_agents_auth -c "DROP SCHEMA IF EXISTS learning CASCADE;"
    docker exec -i claude-postgres psql -U claude_agent -d claude_agents_auth < "${DOCKER_DIR}/init-learning-system-enhanced.sql"
    
    print_color $GREEN "Database reset complete!"
}

# Function to export learning data
export_data() {
    if ! check_postgres; then
        print_color $RED "PostgreSQL is not running"
        exit 1
    fi
    
    local export_dir="${SCRIPT_DIR}/learning_exports"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="${export_dir}/learning_data_${timestamp}.sql"
    
    mkdir -p "${export_dir}"
    
    print_color $YELLOW "Exporting learning data..."
    docker exec claude-postgres pg_dump -U claude_agent -d claude_agents_auth --schema=learning > "${export_file}"
    
    print_color $GREEN "Data exported to: ${export_file}"
}

# Main menu
show_menu() {
    echo ""
    print_color $BLUE "Enhanced Learning System Manager"
    print_color $BLUE "================================"
    echo "1. Start System"
    echo "2. Stop System"
    echo "3. Show Status"
    echo "4. Test System"
    echo "5. Reset Database"
    echo "6. Export Data"
    echo "7. Exit"
    echo ""
}

# Main loop
if [ $# -eq 0 ]; then
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) start_system ;;
            2) stop_system ;;
            3) show_status ;;
            4) test_system ;;
            5) reset_database ;;
            6) export_data ;;
            7) print_color $GREEN "Goodbye!"; exit 0 ;;
            *) print_color $RED "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
else
    # Handle command line arguments
    case "$1" in
        start) start_system ;;
        stop) stop_system ;;
        status) show_status ;;
        test) test_system ;;
        reset) reset_database ;;
        export) export_data ;;
        *) 
            echo "Usage: $0 [start|stop|status|test|reset|export]"
            echo "  start  - Start the enhanced learning system"
            echo "  stop   - Stop the learning system"
            echo "  status - Show system status"
            echo "  test   - Test the learning collector"
            echo "  reset  - Reset the database (deletes all data)"
            echo "  export - Export learning data"
            exit 1
            ;;
    esac
fi