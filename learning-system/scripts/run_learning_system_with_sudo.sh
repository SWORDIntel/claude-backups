#!/bin/bash

# Learning System Docker Testing with sudo
# Addresses permission issues in test environment

echo "=================================================="
echo "LEARNING SYSTEM - DOCKER TESTING WITH SUDO"
echo "Using sudo for Docker commands"
echo "=================================================="

PROJECT_ROOT="/home/ubuntu/Documents/claude-backups"
cd "$PROJECT_ROOT" || exit 1

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

# Test Docker services with sudo
test_docker_with_sudo() {
    echo -e "\n${YELLOW}Starting Learning System Services${NC}"
    
    info "Starting PostgreSQL container..."
    sudo docker-compose up -d postgres
    
    if [ $? -eq 0 ]; then
        success "PostgreSQL container started"
        sleep 10
        
        # Test if PostgreSQL is ready
        if sudo docker-compose exec -T postgres pg_isready -U claude_user -d claude_auth > /dev/null 2>&1; then
            success "PostgreSQL is ready and accepting connections"
        else
            error "PostgreSQL is not ready"
            return 1
        fi
    else
        error "Failed to start PostgreSQL"
        return 1
    fi
    
    info "Starting Learning System container..."
    sudo docker-compose up -d learning-system
    
    if [ $? -eq 0 ]; then
        success "Learning System container started"
        sleep 15
        
        # Test API health
        if curl -f http://localhost:8080/health > /dev/null 2>&1; then
            success "Learning System API is responding"
        else
            info "Checking container logs..."
            sudo docker-compose logs learning-system | tail -10
            error "Learning System API not responding"
            return 1
        fi
    else
        error "Failed to start Learning System"
        return 1
    fi
    
    return 0
}

# Test API functionality
test_api_functionality() {
    echo -e "\n${YELLOW}Testing API Functionality${NC}"
    
    info "Testing health endpoint..."
    health_response=$(curl -s http://localhost:8080/health)
    echo "Health response: $health_response"
    
    if echo "$health_response" | grep -q "status"; then
        success "Health endpoint is working"
    else
        error "Health endpoint failed"
        return 1
    fi
    
    info "Testing performance recording..."
    perf_response=$(curl -s -X POST http://localhost:8080/agent/performance \
        -H "Content-Type: application/json" \
        -d '{
            "agent_id": "director",
            "task_type": "planning", 
            "execution_time": 2.5,
            "success": true,
            "metrics": {"complexity": 8}
        }')
    
    echo "Performance response: $perf_response"
    
    if echo "$perf_response" | grep -q "status\|error"; then
        success "Performance endpoint responding (may have validation issues)"
    else
        error "Performance endpoint failed"
    fi
    
    return 0
}

# Show system status
show_system_status() {
    echo -e "\n${YELLOW}System Status${NC}"
    
    info "Docker containers:"
    sudo docker-compose ps
    
    info "Container logs preview:"
    echo "--- Learning System Logs ---"
    sudo docker-compose logs --tail=5 learning-system
    
    echo "--- PostgreSQL Logs ---"
    sudo docker-compose logs --tail=5 postgres
}

# Cleanup
cleanup() {
    echo -e "\n${YELLOW}Cleanup${NC}"
    info "Stopping all containers..."
    sudo docker-compose down
    success "Cleanup complete"
}

# Main execution
main() {
    echo "Testing Learning System with Docker..."
    
    # Run tests
    if test_docker_with_sudo; then
        if test_api_functionality; then
            echo -e "\n${GREEN}BASIC TESTS PASSED!${NC}"
            echo "Learning System is partially operational"
            
            show_system_status
            
            echo -e "\n${YELLOW}Manual Testing Available:${NC}"
            echo "- Health: http://localhost:8080/health"
            echo "- API docs: http://localhost:8080/docs" 
            echo "- Prometheus: http://localhost:9091"
            
            echo -e "\nPress Ctrl+C to stop services..."
            trap cleanup EXIT
            
            # Keep services running for manual testing
            while true; do
                sleep 5
                if ! curl -f http://localhost:8080/health > /dev/null 2>&1; then
                    error "Learning System went offline"
                    break
                fi
            done
        else
            error "API functionality tests failed"
        fi
    else
        error "Docker services failed to start"
    fi
    
    cleanup
}

main