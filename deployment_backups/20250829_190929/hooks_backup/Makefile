# Makefile for Claude Unified Hook System Tests
# TESTBED Agent - Build and Test Automation

.PHONY: help install test test-unit test-integration test-performance test-security \
        test-docker test-all test-coverage test-parallel test-reports clean \
        lint format type-check security-scan setup-env docker-build docker-test \
        benchmark load-test validate

# Configuration
PYTHON := python3
PIP := pip3
PYTEST := python -m pytest
PROJECT_NAME := claude-unified-hooks
COVERAGE_MIN := 85
TEST_TIMEOUT := 300

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
help: ## Show this help message
	@echo "$(BLUE)Claude Unified Hook System - Test Automation$(NC)"
	@echo "=============================================="
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Test Categories:$(NC)"
	@echo "  unit         - Unit tests (fast, ~2 min)"
	@echo "  integration  - Integration tests (~5 min)"  
	@echo "  performance  - Performance tests (~10 min)"
	@echo "  security     - Security vulnerability tests (~5 min)"
	@echo "  docker       - Docker environment tests (~3 min)"
	@echo "  all          - All test categories (~20 min)"

# Environment setup
setup-env: ## Setup test environment and install dependencies
	@echo "$(BLUE)Setting up test environment...$(NC)"
	$(PIP) install --upgrade pip setuptools wheel
	$(PIP) install -r requirements-test.txt
	@if [ ! -f .env ]; then \
		echo "PYTHONPATH=." > .env; \
		echo "COVERAGE_FILE=.coverage" >> .env; \
		echo "PYTEST_CURRENT_TEST=true" >> .env; \
	fi
	@echo "$(GREEN)Environment setup complete!$(NC)"

install: setup-env ## Install all dependencies
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

# Individual test categories
test-unit: ## Run unit tests
	@echo "$(BLUE)Running unit tests...$(NC)"
	$(PYTEST) -m "unit" -v --tb=short --maxfail=5 \
		--timeout=$(TEST_TIMEOUT) \
		--junit-xml=test_results/unit_results.xml

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	$(PYTEST) -m "integration" -v --tb=short --maxfail=3 \
		--timeout=$(TEST_TIMEOUT) \
		--junit-xml=test_results/integration_results.xml

test-performance: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	$(PYTEST) -m "performance" -v --tb=short --maxfail=2 \
		--timeout=600 \
		--junit-xml=test_results/performance_results.xml

test-security: ## Run security vulnerability tests
	@echo "$(BLUE)Running security tests...$(NC)"
	$(PYTEST) -m "security" -v --tb=short --maxfail=1 \
		--timeout=$(TEST_TIMEOUT) \
		--junit-xml=test_results/security_results.xml

test-docker: ## Run Docker environment tests
	@echo "$(BLUE)Running Docker tests...$(NC)"
	@if [ -f /.dockerenv ] || [ "$${DOCKER_CONTAINER}" = "true" ]; then \
		$(PYTEST) -m "docker" -v --tb=short \
			--timeout=$(TEST_TIMEOUT) \
			--junit-xml=test_results/docker_results.xml; \
	else \
		echo "$(YELLOW)Skipping Docker tests (not in Docker environment)$(NC)"; \
	fi

# Comprehensive test runs
test: test-unit test-integration ## Run core tests (unit + integration)
	@echo "$(GREEN)Core tests completed!$(NC)"

test-all: ## Run all test categories
	@echo "$(BLUE)Running comprehensive test suite...$(NC)"
	@mkdir -p test_results
	$(PYTHON) test_runner.py --verbose
	@echo "$(GREEN)All tests completed!$(NC)"

test-coverage: ## Run tests with coverage reporting
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@mkdir -p test_results htmlcov
	$(PYTEST) --cov=claude_unified_hook_system_v2 \
		--cov-report=html:htmlcov \
		--cov-report=xml:test_results/coverage.xml \
		--cov-report=term-missing \
		--cov-fail-under=$(COVERAGE_MIN) \
		--junit-xml=test_results/coverage_results.xml
	@echo "$(GREEN)Coverage report generated in htmlcov/index.html$(NC)"

test-parallel: ## Run tests in parallel for faster execution
	@echo "$(BLUE)Running tests in parallel...$(NC)"
	@mkdir -p test_results
	$(PYTEST) -n auto --dist=loadscope \
		--junit-xml=test_results/parallel_results.xml \
		-v

# Specialized test runs
benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running performance benchmarks...$(NC)"
	$(PYTEST) -m "performance" --benchmark-only \
		--benchmark-sort=mean \
		--benchmark-html=test_results/benchmark_report.html \
		-v

load-test: ## Run load testing scenarios
	@echo "$(BLUE)Running load tests...$(NC)"
	$(PYTEST) -m "slow" --tb=short \
		--timeout=1200 \
		--junit-xml=test_results/load_test_results.xml \
		-v

stress-test: ## Run stress tests with high resource usage
	@echo "$(BLUE)Running stress tests...$(NC)"
	$(PYTEST) -k "stress" --tb=short \
		--timeout=1800 \
		--maxfail=1 \
		-v

# Code quality checks
lint: ## Run linting checks
	@echo "$(BLUE)Running linting checks...$(NC)"
	flake8 claude_unified_hook_system_v2.py test_*.py --max-line-length=100
	@echo "$(GREEN)Linting passed!$(NC)"

format: ## Format code with black
	@echo "$(BLUE)Formatting code...$(NC)"
	black claude_unified_hook_system_v2.py test_*.py conftest.py test_fixtures.py
	@echo "$(GREEN)Code formatted!$(NC)"

type-check: ## Run type checking with mypy
	@echo "$(BLUE)Running type checks...$(NC)"
	mypy claude_unified_hook_system_v2.py --ignore-missing-imports
	@echo "$(GREEN)Type checking passed!$(NC)"

security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	bandit -r claude_unified_hook_system_v2.py -f json -o test_results/bandit_report.json
	safety check --json --output test_results/safety_report.json || true
	@echo "$(GREEN)Security scan completed! Check test_results/ for reports.$(NC)"

# Docker operations
docker-build: ## Build Docker test environment
	@echo "$(BLUE)Building Docker test environment...$(NC)"
	docker build -t $(PROJECT_NAME)-test -f Dockerfile.test .
	@echo "$(GREEN)Docker image built!$(NC)"

docker-test: ## Run tests in Docker container
	@echo "$(BLUE)Running tests in Docker...$(NC)"
	docker run --rm -v "$$(pwd)/test_results:/app/test_results" \
		$(PROJECT_NAME)-test make test-all
	@echo "$(GREEN)Docker tests completed!$(NC)"

# Test reports and analysis
test-reports: ## Generate comprehensive test reports
	@echo "$(BLUE)Generating test reports...$(NC)"
	@mkdir -p test_results
	$(PYTHON) test_runner.py --verbose > test_results/test_execution.log 2>&1 || true
	@if [ -f test_results/coverage.xml ]; then \
		echo "$(GREEN)Coverage report available in htmlcov/index.html$(NC)"; \
	fi
	@if [ -f test_results/benchmark_report.html ]; then \
		echo "$(GREEN)Benchmark report available in test_results/benchmark_report.html$(NC)"; \
	fi
	@echo "$(GREEN)Test reports generated in test_results/$(NC)"

validate: ## Validate test environment and requirements
	@echo "$(BLUE)Validating test environment...$(NC)"
	$(PYTHON) -c "import claude_unified_hook_system_v2; print('✅ Main module imports successfully')"
	$(PYTHON) -c "import pytest; print('✅ Pytest available')"
	$(PYTHON) -c "import asyncio; print('✅ Asyncio available')"
	$(PYTHON) -c "import psutil; print('✅ Psutil available')"
	@echo "$(GREEN)Environment validation completed!$(NC)"

# CI/CD Integration
ci-test: ## Run tests in CI/CD environment
	@echo "$(BLUE)Running CI/CD tests...$(NC)"
	@mkdir -p test_results
	$(PYTEST) --co -q | wc -l | xargs -I {} echo "Discovered {} tests"
	$(PYTEST) -x --tb=short --maxfail=1 \
		--junit-xml=test_results/ci_results.xml \
		--cov=claude_unified_hook_system_v2 \
		--cov-report=xml:test_results/coverage.xml \
		--cov-fail-under=$(COVERAGE_MIN)
	@echo "$(GREEN)CI/CD tests completed!$(NC)"

# Quick development workflow
quick-test: ## Run quick subset of tests for development
	@echo "$(BLUE)Running quick development tests...$(NC)"
	$(PYTEST) -m "unit and not slow" --tb=short --maxfail=3 -q
	@echo "$(GREEN)Quick tests completed!$(NC)"

dev-test: ## Run tests with development settings
	@echo "$(BLUE)Running development tests...$(NC)"
	$(PYTEST) -x --tb=short --no-cov -v \
		--timeout=60

# Debugging helpers
debug-test: ## Run specific test with debugging
	@echo "$(BLUE)Running test with debugging enabled...$(NC)"
	$(PYTEST) --pdb -s -v $(TEST)

test-specific: ## Run specific test (usage: make test-specific TEST=test_name)
	@echo "$(BLUE)Running specific test: $(TEST)$(NC)"
	$(PYTEST) -k "$(TEST)" -v --tb=short

# Cleanup operations
clean: ## Clean up test artifacts and cache
	@echo "$(BLUE)Cleaning up test artifacts...$(NC)"
	rm -rf __pycache__ .pytest_cache .coverage htmlcov
	rm -rf test_results/*.xml test_results/*.json test_results/*.html
	rm -rf .mypy_cache .tox *.egg-info
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Cleanup completed!$(NC)"

clean-all: clean ## Deep clean including logs and temporary files
	@echo "$(BLUE)Performing deep cleanup...$(NC)"
	rm -rf test_results/ htmlcov/ .coverage.* *.log
	rm -rf temp_*/ test_temp_*/
	@echo "$(GREEN)Deep cleanup completed!$(NC)"

# Performance monitoring
monitor-resources: ## Monitor system resources during tests
	@echo "$(BLUE)Monitoring resources during test execution...$(NC)"
	@$(PYTHON) -c "import psutil; import time; \
		p = psutil.Process(); \
		print(f'Initial Memory: {p.memory_info().rss/1024/1024:.1f}MB'); \
		print(f'CPU Count: {psutil.cpu_count()}'); \
		print(f'Available Memory: {psutil.virtual_memory().available/1024/1024/1024:.1f}GB')"

# Test data management
generate-test-data: ## Generate test data files
	@echo "$(BLUE)Generating test data...$(NC)"
	$(PYTHON) -c "from test_fixtures import TestDataGenerator; \
		import json; \
		data = TestDataGenerator.generate_performance_test_data(); \
		json.dump(data, open('test_data.json', 'w'), indent=2)"
	@echo "$(GREEN)Test data generated in test_data.json$(NC)"

# Documentation for tests
test-docs: ## Generate test documentation
	@echo "$(BLUE)Generating test documentation...$(NC)"
	@mkdir -p docs/tests
	$(PYTHON) -c "import test_claude_unified_hooks; help(test_claude_unified_hooks)" > docs/tests/test_reference.txt
	@echo "$(GREEN)Test documentation generated in docs/tests/$(NC)"

# Health check
health-check: ## Perform system health check before tests
	@echo "$(BLUE)Performing system health check...$(NC)"
	@$(PYTHON) -c "import sys; print(f'Python: {sys.version}')"
	@$(PYTHON) -c "import psutil; print(f'Memory: {psutil.virtual_memory().percent}% used')"
	@$(PYTHON) -c "import psutil; print(f'Disk: {psutil.disk_usage(\".\")/1024**3:.1f}GB free')"
	@$(PYTHON) -c "import multiprocessing; print(f'CPUs: {multiprocessing.cpu_count()}')"
	@echo "$(GREEN)Health check completed!$(NC)"

# All-in-one development target
dev: clean validate health-check quick-test ## Complete development workflow
	@echo "$(GREEN)Development workflow completed!$(NC)"

# Production readiness check
production-ready: clean validate test-coverage security-scan lint type-check ## Full production readiness check
	@echo "$(GREEN)Production readiness check completed!$(NC)"