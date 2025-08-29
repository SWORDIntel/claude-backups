# Claude Hook System Docker Testing Environment

## Overview

This comprehensive Docker-based testing environment validates the `claude_unified_hook_system_v2.py` across multiple dimensions:

- **Multi-version Python compatibility** (3.9, 3.10, 3.11, 3.12)
- **Security testing** in isolated environments
- **Performance testing** with monitoring and metrics
- **Agent coordination testing** with 76-agent registry
- **CI/CD integration** with Jenkins and GitHub Actions

## Architecture

```
tests/docker/
├── Dockerfiles for each environment
├── docker-compose.yml (orchestration)
├── test-fixtures/ (test data)
├── monitoring-configs/ (Prometheus/Grafana)
├── ci-cd/ (CI/CD configurations)
├── collectors/ (result aggregation)
├── scripts/ (test runner)
└── README.md (this file)
```

## Quick Start

### Prerequisites

- Docker 20.03+ with Buildx support
- Docker Compose 2.0+
- 8GB+ RAM recommended for full test suite
- 20GB+ disk space for all environments

### Basic Usage

```bash
# Run all tests with default configuration
./scripts/run-tests.sh

# Run compatibility tests only
./scripts/run-tests.sh --scope compatibility

# Run security tests with deep scanning
./scripts/run-tests.sh --scope security --security-scan

# Run performance tests with benchmarking
./scripts/run-tests.sh --scope performance --performance
```

### Docker Compose Profiles

```bash
# Run compatibility tests across Python versions
docker-compose --profile compatibility up

# Run security tests in isolation
docker-compose --profile security up

# Run performance tests with monitoring
docker-compose --profile performance up

# Run all test environments
docker-compose --profile all up
```

## Test Environments

### Python Compatibility Testing

Tests the hook system across Python versions to ensure compatibility:

- **python39-test**: Python 3.9 environment
- **python310-test**: Python 3.10 environment  
- **python311-test**: Python 3.11 environment (primary)
- **python312-test**: Python 3.12 environment (latest)

Each environment runs:
- Unit tests for all hook system functions
- Integration tests for agent coordination
- Compatibility validation for Python version-specific features

### Security Testing (Isolated)

Dedicated security environment with enhanced isolation:

- **Isolated network** (`claude-security-network`)
- **Security scanning tools**: Bandit, Safety, Semgrep
- **Malicious input testing** with comprehensive attack vectors
- **Vulnerability assessment** for all 12 implemented security fixes

**Security Test Coverage:**
- Path traversal protection
- Command injection prevention
- Input sanitization validation
- Rate limiting functionality
- Circuit breaker security
- Memory exhaustion protection
- Authentication validation
- Privilege dropping verification

### Performance Testing (Monitored)

Performance environment with comprehensive monitoring:

- **Prometheus** metrics collection
- **Grafana** dashboards for visualization
- **Load testing** with Locust
- **Benchmarking** with pytest-benchmark
- **Resource monitoring** (CPU, memory, I/O)

**Performance Validation:**
- **4-6x improvement targets** verification
- Response time under load
- Throughput measurements
- Cache effectiveness
- Memory usage patterns
- Circuit breaker performance

### Agent Coordination Testing

Validates the 76-agent coordination system:

- **Agent registry validation** (76 agents discovered)
- **Priority-based execution** testing
- **Workflow detection** accuracy
- **Pattern matching** performance
- **Natural language invocation** testing
- **Fuzzy matching** capabilities

## Test Data and Fixtures

### Security Test Fixtures

Located in `test-fixtures/security/`:

- **malicious_inputs.json**: Comprehensive attack vectors
  - Path traversal attempts
  - Command injection payloads
  - Script injection attempts
  - Buffer overflow inputs
  - JSON injection exploits
  - RegEx DoS patterns
  - Memory exhaustion attacks
  - Unicode exploitation

### Performance Test Scenarios

Located in `test-fixtures/performance/`:

- **load_test_scenarios.json**: Performance test configurations
  - Baseline performance testing
  - Moderate and high load scenarios
  - Stress and burst testing
  - Endurance testing (1-hour runs)
  - Cache effectiveness validation
  - Memory-bounded operations

### Coordination Test Scenarios

Located in `test-fixtures/coordination/`:

- **agent_test_scenarios.json**: Agent coordination validation
  - Single and multi-agent workflows
  - Priority-based execution testing
  - Pattern matching accuracy validation
  - Fuzzy and semantic matching tests
  - Natural language invocation testing
  - Circuit breaker coordination testing

## Monitoring and Observability

### Prometheus Metrics

The performance environment exposes metrics at `http://localhost:9090`:

- `claude_hooks_response_time_seconds`: Response time histograms
- `claude_hooks_requests_total`: Request counters
- `claude_hooks_cache_hits_total`: Cache hit counters
- `claude_hooks_active_agents_total`: Active agent count
- `claude_hooks_errors_total`: Error counters
- `claude_hooks_circuit_breaker_state`: Circuit breaker status

### Grafana Dashboard

Available at `http://localhost:3000` (admin/claude-testing):

- Response time percentiles (50th, 95th, 99th)
- Request throughput over time
- Cache hit ratio visualization
- Active agent monitoring
- Error rate tracking
- Performance improvement factor display

## CI/CD Integration

### Jenkins Pipeline

Located in `ci-cd/Jenkinsfile`:

- **Multi-stage pipeline** with parallel execution
- **Environment-specific testing** with matrix builds
- **Performance validation** against 4-6x improvement targets
- **Security validation** with zero-tolerance for vulnerabilities
- **Comprehensive reporting** with HTML dashboards
- **Email notifications** with detailed results

### GitHub Actions

Located in `ci-cd/github-actions.yml`:

- **Matrix strategy** for multi-version testing
- **Artifact management** for Docker images and results
- **Security scanning** with multiple tools
- **Performance benchmarking** with trend analysis
- **PR integration** with automated comments
- **Scheduled testing** for continuous validation

## Result Collection and Analysis

### Test Result Collector

The `test-collector` service aggregates results from all environments:

- **SQLite database** for structured result storage
- **JSON reports** for programmatic access
- **HTML dashboard** for human-readable results
- **Trend analysis** for performance regression detection

### Generated Reports

After test execution, the following reports are generated:

- `summary_report.json`: Overall test summary
- `compatibility_report.json`: Python version compatibility
- `performance_report.json`: Performance analysis and trends
- `security_report.json`: Security findings and validation
- `dashboard.html`: Interactive HTML dashboard

## Advanced Usage

### Custom Test Scenarios

Add new test scenarios by creating JSON files in `test-fixtures/`:

```json
{
  "custom_scenario": {
    "description": "Custom test description",
    "input": "test input string",
    "expected_agents": ["AGENT1", "AGENT2"],
    "expected_confidence": 0.8,
    "validation_criteria": {}
  }
}
```

### Performance Benchmarking

Run specific performance benchmarks:

```bash
# Run only cache performance tests
docker-compose run --rm performance-test python -m pytest /app/tests/performance/test_cache.py --benchmark-only

# Run with memory profiling
docker-compose run --rm performance-test python -m memory_profiler /app/claude_unified_hook_system_v2.py
```

### Security Deep Scanning

Run additional security tools:

```bash
# Run comprehensive security scan
docker-compose run --rm security-test bandit -r /app/ -f json -o /app/results/bandit_detailed.json

# Run with custom security rules
docker-compose run --rm security-test semgrep --config=/app/configs/custom-rules.yml /app/
```

## Troubleshooting

### Common Issues

1. **Docker build failures**: Ensure sufficient disk space (20GB+)
2. **Memory issues**: Increase Docker memory limit to 8GB+
3. **Port conflicts**: Ensure ports 3000, 9090, 6379 are available
4. **Permission errors**: Run with appropriate Docker permissions

### Debug Mode

Enable verbose logging for debugging:

```bash
# Enable debug output
VERBOSE=true ./scripts/run-tests.sh --verbose

# Keep containers running for inspection
./scripts/run-tests.sh --no-cleanup

# Access running containers
docker-compose exec performance-test bash
docker-compose exec security-test bash
```

### Log Analysis

Container logs are available for analysis:

```bash
# View specific container logs
docker-compose logs -f performance-test

# Export logs for analysis
docker-compose logs performance-test > performance-test.log

# Monitor all services
docker-compose logs -f
```

## Performance Targets and Validation

### Target Metrics

The testing environment validates these performance improvements:

- **4x Improvement**: Response time reduction from baseline
- **6x Improvement**: Throughput increase under load
- **Cache Hit Ratio**: >80% for repeated requests
- **Memory Usage**: Bounded growth under load
- **Error Rate**: <1% under normal conditions

### Validation Criteria

Tests pass when:
- **Success Rate**: >95% across all environments
- **Security Findings**: Zero critical vulnerabilities
- **Performance**: Meets or exceeds 4x improvement targets
- **Compatibility**: 100% success across Python versions
- **Coordination**: All 76 agents properly registered and functional

## Contributing

### Adding New Test Environments

1. Create new Dockerfile in the root directory
2. Add service definition to `docker-compose.yml`
3. Create test fixtures in `test-fixtures/`
4. Update CI/CD configurations
5. Update this documentation

### Adding New Test Scenarios

1. Add scenario definitions to appropriate fixture files
2. Create corresponding test implementations
3. Update validation criteria
4. Test with existing environments

### Monitoring Enhancements

1. Add new Prometheus metrics as needed
2. Update Grafana dashboard configurations
3. Enhance result collection logic
4. Document new metrics and visualizations

## Support

For issues with the testing environment:

1. Check the troubleshooting section above
2. Review container logs for detailed error information
3. Ensure all prerequisites are met
4. Verify the hook system file is present and valid

The testing environment is designed to provide comprehensive validation of the claude_unified_hook_system_v2.py with enterprise-grade testing practices, ensuring reliable and secure operation across all supported environments.