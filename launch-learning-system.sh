#!/bin/bash

# Claude Learning System - Single File Launcher
# Complete setup and launch script for the learning system
# Location: Root of project for easy access

set -e

echo "================================================================="
echo "🚀 CLAUDE LEARNING SYSTEM v3.1 - LAUNCHER"
echo "================================================================="
echo "Single-command setup and launch for the complete learning system"
echo "Features: PostgreSQL 16 + FastAPI + ML Pipeline + Monitoring"
echo "================================================================="

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

warning() {
    echo -e "${PURPLE}⚠${NC} $1"
}

# Check if script is run from project root
check_project_root() {
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -d "database" ]] || [[ ! -d "agents" ]]; then
        error "Please run this script from the project root directory"
        error "Expected files: docker-compose.yml, database/, agents/"
        exit 1
    fi
    success "Running from correct project root: $PROJECT_ROOT"
}

# Check Docker installation and permissions
check_docker() {
    header "Docker Environment Check"
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    success "Docker found: $(docker --version)"
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    success "Docker Compose found: $(docker-compose --version)"
    
    # Test Docker permissions
    if docker ps &> /dev/null; then
        success "Docker permissions OK"
    elif sudo docker ps &> /dev/null; then
        warning "Docker requires sudo - adding user to docker group"
        sudo usermod -aG docker "$USER"
        warning "You'll need to logout/login for docker group membership to take effect"
        warning "For now, using sudo for docker commands..."
        DOCKER_SUDO="sudo"
    else
        error "Cannot access Docker daemon"
        exit 1
    fi
}

# Create required directories
setup_directories() {
    header "Directory Setup"
    
    directories=(
        "database/data/models"
        "database/data/training" 
        "database/data/checkpoints"
        "logs/learning"
        "logs/ml_pipeline"
        "config/learning"
        "database/data/postgresql"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        info "Created: $dir"
    done
    
    success "All directories created"
}

# Generate configuration files
generate_configs() {
    header "Configuration Generation"
    
    # Generate ML pipeline config
    info "Generating ML pipeline configuration..."
    if [[ -f "database/docker/ml_pipeline_config.py" ]]; then
        python3 database/docker/ml_pipeline_config.py
        success "ML pipeline configuration generated"
    else
        warning "ML pipeline config script not found"
    fi
    
    # Create environment file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        info "Creating .env file..."
        cat > .env << EOF
# PostgreSQL Configuration
POSTGRES_USER=claude_user
POSTGRES_PASSWORD=claude_secure_pass
POSTGRES_DB=claude_auth

# Python Configuration  
PYTHONPATH=/app:/app/learning

# Learning System Configuration
LEARNING_ENV=docker
LEARNING_API_PORT=8080
LEARNING_API_HOST=0.0.0.0

# Monitoring Configuration
PROMETHEUS_PORT=9091
EOF
        success "Environment file created"
    else
        info ".env file already exists"
    fi
}

# Health check function
wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_attempts=30
    local attempt=1
    
    info "Waiting for $service_name to be healthy..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f "$health_url" &> /dev/null; then
            success "$service_name is healthy"
            return 0
        fi
        
        if [[ $attempt -eq 1 ]]; then
            echo -n "    Attempt: "
        fi
        echo -n "$attempt "
        
        sleep 2
        ((attempt++))
    done
    
    echo
    error "$service_name failed to become healthy after $max_attempts attempts"
    return 1
}

# Start services with proper sequencing
start_services() {
    header "Starting Learning System Services"
    
    # Stop any existing containers
    info "Stopping any existing containers..."
    ${DOCKER_SUDO} docker-compose down &> /dev/null || true
    
    # Start PostgreSQL first
    info "Starting PostgreSQL database..."
    ${DOCKER_SUDO} docker-compose up -d postgres
    
    # Wait for PostgreSQL to be ready
    info "Waiting for PostgreSQL to initialize..."
    sleep 15
    
    # Check PostgreSQL health
    if ${DOCKER_SUDO} docker-compose exec -T postgres pg_isready -U claude_user -d claude_auth &> /dev/null; then
        success "PostgreSQL is ready"
    else
        error "PostgreSQL failed to start properly"
        show_logs postgres
        return 1
    fi
    
    # Start learning system
    info "Starting Learning System API..."
    ${DOCKER_SUDO} docker-compose up -d learning-system
    
    # Wait for learning system
    if wait_for_service "Learning System" "http://localhost:8080/health"; then
        success "Learning System is operational"
    else
        warning "Learning System may need more time to start"
        show_logs learning-system
    fi
    
    # Start agent bridge
    info "Starting Agent Bridge..."
    ${DOCKER_SUDO} docker-compose up -d agent-bridge
    
    # Wait for agent bridge
    if wait_for_service "Agent Bridge" "http://localhost:8081/health"; then
        success "Agent Bridge is operational"
    else
        warning "Agent Bridge may need more time to start"
        show_logs agent-bridge
    fi
    
    # Start monitoring
    info "Starting Prometheus monitoring..."
    ${DOCKER_SUDO} docker-compose up -d prometheus
    
    # Wait for Prometheus
    if wait_for_service "Prometheus" "http://localhost:9091/api/v1/query?query=up"; then
        success "Prometheus monitoring is operational"
    else
        warning "Prometheus monitoring may need more time"
    fi
    
    success "All services started!"
}

# Show container logs
show_logs() {
    local service=$1
    echo -e "\n${YELLOW}--- $service logs (last 10 lines) ---${NC}"
    ${DOCKER_SUDO} docker-compose logs --tail=10 "$service" || true
    echo -e "${YELLOW}--- End of $service logs ---${NC}"
}

# Show system status
show_status() {
    header "System Status"
    
    info "Container Status:"
    ${DOCKER_SUDO} docker-compose ps
    
    echo
    info "Service Health Check:"
    
    # Check each service
    services=(
        "PostgreSQL Database|http://localhost:5433|Database connection"
        "Learning System API|http://localhost:8080/health|ML-powered learning system" 
        "Agent Bridge|http://localhost:8081/health|Agent communication bridge"
        "Prometheus Monitoring|http://localhost:9091|Metrics and monitoring"
    )
    
    for service_info in "${services[@]}"; do
        IFS='|' read -r name url description <<< "$service_info"
        
        if curl -f "$url" &> /dev/null; then
            success "$name: $description"
        else
            error "$name: Not responding"
        fi
    done
}

# Run basic functionality tests
run_tests() {
    header "Basic Functionality Tests"
    
    # Test 1: Health endpoint
    info "Testing Learning System health endpoint..."
    health_response=$(curl -s http://localhost:8080/health 2>/dev/null || echo "FAILED")
    
    if echo "$health_response" | grep -q "status" 2>/dev/null; then
        success "Health endpoint responding"
    else
        error "Health endpoint not responding"
        return 1
    fi
    
    # Test 2: Performance recording
    info "Testing agent performance recording..."
    perf_response=$(curl -s -X POST http://localhost:8080/agent/performance \
        -H "Content-Type: application/json" \
        -d '{
            "agent_id": "director",
            "task_type": "planning",
            "execution_time": 1.5,
            "success": true,
            "metrics": {"complexity": 5}
        }' 2>/dev/null || echo "FAILED")
    
    if echo "$perf_response" | grep -q "status\|accepted" 2>/dev/null; then
        success "Performance recording working"
    else
        warning "Performance recording may have issues"
    fi
    
    # Test 3: Task recommendation
    info "Testing ML task recommendation..."
    rec_response=$(curl -s -X POST http://localhost:8080/task/recommend \
        -H "Content-Type: application/json" \
        -d '{
            "task_description": "Create a web application",
            "complexity": "medium"
        }' 2>/dev/null || echo "FAILED")
    
    if echo "$rec_response" | grep -q "primary_agent\|recommendation" 2>/dev/null; then
        success "Task recommendation working"
    else
        warning "Task recommendation may need initial training data"
    fi
    
    return 0
}

# Show usage information
show_usage_info() {
    header "Learning System Access Information"
    
    echo -e "${GREEN}🌐 Web Interfaces:${NC}"
    echo "  • Learning System API: http://localhost:8080"
    echo "  • API Documentation: http://localhost:8080/docs"
    echo "  • Agent Bridge: http://localhost:8081"
    echo "  • Prometheus Monitoring: http://localhost:9091"
    echo
    
    echo -e "${GREEN}🔧 API Endpoints:${NC}"
    echo "  • Health Check: GET http://localhost:8080/health"
    echo "  • Record Performance: POST http://localhost:8080/agent/performance"
    echo "  • Get Recommendations: POST http://localhost:8080/task/recommend"
    echo "  • Analytics Dashboard: GET http://localhost:8080/analytics/dashboard"
    echo "  • Retrain Models: POST http://localhost:8080/model/retrain"
    echo
    
    echo -e "${GREEN}🛠 Management Commands:${NC}"
    echo "  • View logs: docker-compose logs [service-name]"
    echo "  • Stop services: docker-compose down"
    echo "  • Restart service: docker-compose restart [service-name]"
    echo "  • View containers: docker-compose ps"
    echo
    
    echo -e "${GREEN}📊 Example API Calls:${NC}"
    echo "  • curl http://localhost:8080/health"
    echo "  • curl -X POST http://localhost:8080/agent/performance \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -d '{\"agent_id\":\"director\",\"task_type\":\"planning\",\"execution_time\":2.0,\"success\":true}'"
    echo
    
    echo -e "${YELLOW}📝 Notes:${NC}"
    echo "  • All services are containerized and isolated"
    echo "  • Data persists in ./database/data/ directory" 
    echo "  • Logs are available in ./logs/ directory"
    echo "  • Configuration files are in ./config/ directory"
    echo "  • Press Ctrl+C to stop this script (services keep running)"
}

# Monitor services (optional interactive mode)
monitor_services() {
    header "Service Monitor (Press Ctrl+C to exit)"
    
    trap 'echo -e "\n${YELLOW}Exiting monitor...${NC}"; exit 0' INT
    
    while true; do
        clear
        echo -e "${BLUE}=== Claude Learning System - Live Monitor ===${NC}"
        echo "$(date)"
        echo
        
        # Quick status check
        ${DOCKER_SUDO} docker-compose ps
        
        echo -e "\n${YELLOW}Service Health:${NC}"
        for endpoint in "8080/health" "8081/health" "9091/api/v1/query?query=up"; do
            if curl -f "http://localhost:$endpoint" &> /dev/null; then
                echo -e "  ${GREEN}✓${NC} localhost:${endpoint%/*}"
            else
                echo -e "  ${RED}✗${NC} localhost:${endpoint%/*}"
            fi
        done
        
        echo -e "\n${YELLOW}Press Ctrl+C to exit monitor${NC}"
        sleep 5
    done
}

# Main execution function
main() {
    local command=${1:-"start"}
    
    case $command in
        "start"|"launch"|"run"|"")
            check_project_root
            check_docker
            setup_directories
            generate_configs
            start_services
            show_status
            run_tests
            show_usage_info
            
            echo -e "\n${GREEN}🎉 Learning System Launch Complete!${NC}"
            echo -e "${YELLOW}Services are running in the background${NC}"
            echo
            
            read -p "Would you like to monitor services? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                monitor_services
            fi
            ;;
            
        "stop"|"down")
            info "Stopping all learning system services..."
            ${DOCKER_SUDO} docker-compose down
            success "All services stopped"
            ;;
            
        "status"|"ps")
            show_status
            ;;
            
        "logs")
            service=${2:-"all"}
            if [[ $service == "all" ]]; then
                ${DOCKER_SUDO} docker-compose logs --tail=20
            else
                ${DOCKER_SUDO} docker-compose logs --tail=20 "$service"
            fi
            ;;
            
        "restart")
            info "Restarting learning system services..."
            ${DOCKER_SUDO} docker-compose restart
            success "Services restarted"
            ;;
            
        "test")
            run_tests
            ;;
            
        "help"|"-h"|"--help")
            echo "Claude Learning System Launcher"
            echo
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  start    - Start all learning system services (default)"
            echo "  stop     - Stop all services"
            echo "  status   - Show service status"
            echo "  logs     - Show service logs"
            echo "  restart  - Restart all services"
            echo "  test     - Run functionality tests"
            echo "  help     - Show this help message"
            ;;
            
        *)
            error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"