# NPU Launcher System Documentation

## Overview

Professional NPU-accelerated Claude orchestrator built using CONSTRUCTOR v8.0 standards.
Provides Intel AI Boost NPU acceleration with comprehensive error handling and monitoring.

## Configuration

- **Project Root**: `/home/john/claude-backups`
- **Virtual Environment**: `/home/john/claude-backups/agents/src/python/.venv`
- **Installation Directory**: `/home/john/.local/bin`
- **OpenVINO Version**: `Unknown`
- **NPU Available**: `False`
- **Performance Target**: `25,000 ops/sec`

## Components

### 1. Main Launcher (`claude-npu`)
Primary NPU-accelerated orchestrator with:
- Comprehensive system validation
- Performance monitoring
- Health checking
- Error recovery
- Logging and diagnostics

### 2. Integration Wrapper (`claude-with-npu`)
Integrates NPU acceleration with existing Claude wrapper:
- Drop-in replacement for `claude` command
- Automatic NPU detection for performance tasks
- Seamless fallback to regular Claude

### 3. Health Checker (`claude-npu-health`)
System health monitoring and validation:
- Hardware capability assessment
- OpenVINO installation validation
- Performance baseline testing
- Health scoring system

## Usage

### Basic Usage
```bash
# Launch NPU-accelerated orchestrator
claude-npu

# Run with specific arguments
claude-npu --performance-test

# Skip initial performance check
claude-npu --skip-perf-check
```

### Integration Usage
```bash
# Use NPU acceleration automatically
claude-with-npu /task "optimize performance"

# Explicit NPU acceleration
claude --npu /task "complex analysis"
```

### Health Monitoring
```bash
# Check system health
claude-npu-health

# Validate system before use
claude-npu --validate

# View configuration
claude-npu --config
```

## Performance

### Target Performance
- **Primary Target**: 25,000 operations per second
- **Baseline Requirement**: 2,500 operations per second minimum
- **Hardware Acceleration**: Intel AI Boost NPU with OpenVINO runtime

### Monitoring
- Health checks every 30 seconds
- Performance baselines validated on startup
- Automatic fallback to CPU if NPU unavailable

## Error Handling

### Validation Failures
- Missing virtual environment → Installation guide provided
- OpenVINO issues → Detailed error reporting
- Performance below threshold → Warning with recommendations

### Runtime Failures
- NPU hardware issues → Automatic CPU fallback
- Process crashes → Comprehensive logging
- Memory issues → Resource monitoring and alerts

## Integration with Claude Framework

### Agent Ecosystem
Integrates with all 89 agents in the Claude framework:
- Maintains agent coordination capabilities
- Preserves existing Task tool functionality
- Enhances performance for all agent operations

### Wrapper Compatibility
Works alongside existing wrapper system:
- claude-wrapper-ultimate.sh integration
- Preserves all existing functionality
- Adds NPU acceleration as optional enhancement

## Troubleshooting

### Common Issues

1. **NPU Not Detected**
   - Verify Intel Core Ultra CPU (Meteor Lake)
   - Check `/dev/accel*` device files
   - Run `claude-npu-health` for detailed diagnosis

2. **Performance Below Target**
   - Check thermal throttling
   - Verify NPU driver installation
   - Review system resource usage

3. **OpenVINO Issues**
   - Validate virtual environment
   - Check OpenVINO installation
   - Verify device permissions

### Diagnostic Commands
```bash
# Full system validation
claude-npu --validate

# Performance benchmark
claude-npu --performance-test

# Health monitoring
claude-npu-health

# Configuration review
claude-npu --config
```

## Build Information

- **Builder Version**: 8.0.0
- **Build Time**: 2025-09-16 00:37:17
- **CONSTRUCTOR Standards**: v8.0 compliant
- **Integration Level**: Production grade

## Support

For issues or questions:
1. Run `claude-npu-health` for diagnostics
2. Check logs at `/home/john/claude-backups/logs/npu_launcher.log`
3. Review configuration at `/home/john/claude-backups/config/npu_launcher.json`
