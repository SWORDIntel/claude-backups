#!/bin/bash

echo "=================================================="
echo "LEARNING SYSTEM INTEGRATION TEST"
echo "Using Tandem Orchestrator for parallel execution"
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

# Test 1: Docker Services
test_docker_services() {
    echo -e "\n${YELLOW}Test 1: Docker Services${NC}"
    
    info "Starting PostgreSQL..."
    docker-compose up -d postgres
    sleep 10
    
    if docker-compose exec -T postgres pg_isready -U claude_user -d claude_auth > /dev/null 2>&1; then
        success "PostgreSQL is ready"
    else
        error "PostgreSQL failed to start"
        return 1
    fi
    
    info "Starting Learning System..."
    docker-compose up -d learning-system
    sleep 5
    
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        success "Learning System API is responding"
    else
        error "Learning System API failed to start"
        return 1
    fi
    
    info "Starting Agent Bridge..."
    docker-compose up -d agent-bridge
    sleep 5
    
    if curl -f http://localhost:8081/health > /dev/null 2>&1; then
        success "Agent Bridge is responding"
    else
        error "Agent Bridge failed to start"
        return 1
    fi
    
    info "Starting Prometheus..."
    docker-compose up -d prometheus
    sleep 5
    
    if curl -f http://localhost:9091/api/v1/query?query=up > /dev/null 2>&1; then
        success "Prometheus is collecting metrics"
    else
        error "Prometheus failed to start"
        return 1
    fi
    
    return 0
}

# Test 2: API Endpoints
test_api_endpoints() {
    echo -e "\n${YELLOW}Test 2: API Endpoints${NC}"
    
    info "Testing Learning System health endpoint..."
    health_response=$(curl -s http://localhost:8080/health)
    if echo "$health_response" | grep -q "healthy"; then
        success "Health endpoint working"
    else
        error "Health endpoint failed"
        return 1
    fi
    
    info "Testing agent performance recording..."
    perf_response=$(curl -s -X POST http://localhost:8080/agent/performance \
        -H "Content-Type: application/json" \
        -d '{
            "agent_id": "director",
            "task_type": "planning",
            "execution_time": 2.5,
            "success": true,
            "metrics": {"complexity": 8}
        }')
    
    if echo "$perf_response" | grep -q "accepted"; then
        success "Performance recording working"
    else
        error "Performance recording failed"
        return 1
    fi
    
    info "Testing task recommendation..."
    rec_response=$(curl -s -X POST http://localhost:8080/task/recommend \
        -H "Content-Type: application/json" \
        -d '{
            "task_description": "Create a security audit",
            "complexity": "high"
        }')
    
    if echo "$rec_response" | grep -q "primary_agent"; then
        success "Task recommendation working"
    else
        error "Task recommendation failed"
        return 1
    fi
    
    return 0
}

# Test 3: Tandem Orchestrator
test_tandem_orchestrator() {
    echo -e "\n${YELLOW}Test 3: Tandem Orchestrator${NC}"
    
    info "Testing orchestrator initialization..."
    cd agents/src/python
    
    python3 -c "
import sys
import asyncio
sys.path.append('.')
from production_orchestrator import ProductionOrchestrator

async def test():
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    return True

result = asyncio.run(test())
sys.exit(0 if result else 1)
" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        success "Orchestrator initialized"
    else
        error "Orchestrator initialization failed"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    info "Running learning system orchestrator..."
    if [ -f "orchestration/learning_system_tandem_orchestrator.py" ]; then
        timeout 30 python3 orchestration/learning_system_tandem_orchestrator.py > /tmp/orchestrator_output.txt 2>&1
        
        if grep -q "Success rate" /tmp/orchestrator_output.txt; then
            success "Tandem orchestrator executed successfully"
            cat /tmp/orchestrator_output.txt | tail -10
        else
            error "Tandem orchestrator execution failed"
            return 1
        fi
    else
        error "Tandem orchestrator script not found"
        return 1
    fi
    
    return 0
}

# Test 4: ML Pipeline
test_ml_pipeline() {
    echo -e "\n${YELLOW}Test 4: ML Pipeline${NC}"
    
    info "Testing ML pipeline configuration..."
    python3 database/docker/ml_pipeline_config.py > /dev/null 2>&1
    
    if [ -f "config/ml_pipeline.json" ]; then
        success "ML pipeline configuration created"
    else
        error "ML pipeline configuration failed"
        return 1
    fi
    
    info "Testing model training endpoint..."
    train_response=$(curl -s -X POST http://localhost:8080/model/retrain)
    
    if echo "$train_response" | grep -q "training_started"; then
        success "Model training endpoint working"
    else
        error "Model training endpoint failed"
        return 1
    fi
    
    return 0
}

# Test 5: Database Schema
test_database_schema() {
    echo -e "\n${YELLOW}Test 5: Database Schema${NC}"
    
    info "Checking learning_analytics table..."
    table_exists=$(docker-compose exec -T postgres psql -U claude_user -d claude_auth -c "\dt learning_analytics" 2>/dev/null | grep -c "learning_analytics")
    
    if [ "$table_exists" -gt 0 ]; then
        success "Learning analytics table exists"
    else
        error "Learning analytics table not found"
        return 1
    fi
    
    info "Checking pgvector extension..."
    vector_exists=$(docker-compose exec -T postgres psql -U claude_user -d claude_auth -c "SELECT * FROM pg_extension WHERE extname='vector'" 2>/dev/null | grep -c "vector")
    
    if [ "$vector_exists" -gt 0 ]; then
        success "pgvector extension installed"
    else
        info "pgvector extension not found (optional)"
    fi
    
    return 0
}

# Main test execution
main() {
    echo "Starting Learning System Integration Tests"
    echo "==========================================="
    
    total_tests=0
    passed_tests=0
    
    # Run tests
    tests=(
        "test_docker_services"
        "test_api_endpoints"
        "test_tandem_orchestrator"
        "test_ml_pipeline"
        "test_database_schema"
    )
    
    for test in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        if $test; then
            passed_tests=$((passed_tests + 1))
        fi
    done
    
    # Summary
    echo -e "\n=================================================="
    echo "TEST SUMMARY"
    echo "=================================================="
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $((total_tests - passed_tests))"
    
    if [ "$passed_tests" -eq "$total_tests" ]; then
        echo -e "${GREEN}ALL TESTS PASSED!${NC}"
        echo "Learning System is fully operational with Tandem Orchestration"
        exit 0
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        echo "Please check the logs above for details"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo -e "\nCleaning up..."
    docker-compose down
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Run main
main