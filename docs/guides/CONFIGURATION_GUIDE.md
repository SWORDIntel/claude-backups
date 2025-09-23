# Claude Agent Framework - Configuration Guide

## Environment Variables

### Core Configuration

#### CLAUDE_PROJECT_ROOT
- **Purpose**: Defines the project root directory
- **Default**: Auto-detected (current dir, script dir, common locations)
- **Example**: 
```bash
export CLAUDE_PROJECT_ROOT="$(pwd)"  # or your project path
```

#### CLAUDE_AGENTS_DIR
- **Purpose**: Location of agent definition files
- **Default**: `$CLAUDE_PROJECT_ROOT/agents`
- **Example**:
```bash
export CLAUDE_AGENTS_DIR="/custom/path/to/agents"
```

#### CLAUDE_HOME
- **Purpose**: Claude home directory for user data
- **Default**: `$HOME/.claude-home`
- **Example**:
```bash
export CLAUDE_HOME="$HOME/.claude"
```

#### CLAUDE_VENV
- **Purpose**: Python virtual environment path
- **Default**: Auto-detected (./venv, ./.venv, ../venv)
- **Example**:
```bash
export CLAUDE_VENV="$HOME/.local/share/claude/venv"
```

### Feature Flags

#### CLAUDE_PERMISSION_BYPASS
- **Purpose**: Enable automatic permission bypass
- **Default**: `true`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_PERMISSION_BYPASS=false  # Disable for production
```

#### CLAUDE_AUTO_FIX
- **Purpose**: Enable automatic issue resolution
- **Default**: `true`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_AUTO_FIX=true  # Auto-fix yoga.wasm and other issues
```

#### CLAUDE_ORCHESTRATION
- **Purpose**: Enable Tandem Orchestration System
- **Default**: `true`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_ORCHESTRATION=true
```

#### CLAUDE_LEARNING
- **Purpose**: Enable ML Learning System
- **Default**: `true`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_LEARNING=true
```

#### CLAUDE_DEBUG
- **Purpose**: Enable debug output
- **Default**: `false`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_DEBUG=true  # Verbose debug output
```

### Output Control

#### CLAUDE_OUTPUT_STYLE
- **Purpose**: Set output formatting style
- **Default**: `precision-orchestration`
- **Example**:
```bash
export CLAUDE_OUTPUT_STYLE='precision-orchestration'
```

#### CLAUDE_VERBOSE
- **Purpose**: Enable verbose output
- **Default**: `true`
- **Values**: `true` | `false`
- **Example**:
```bash
export CLAUDE_VERBOSE=false  # Quieter output
```

#### CLAUDE_QUIET_MODE
- **Purpose**: Suppress verbose headers
- **Default**: `true` (in wrapper)
- **Example**:
```bash
export CLAUDE_QUIET_MODE=true
```

#### CLAUDE_SUPPRESS_BANNER
- **Purpose**: Suppress banner headers
- **Default**: `true` (in wrapper)
- **Example**:
```bash
export CLAUDE_SUPPRESS_BANNER=true
```

### Cache Configuration

#### CLAUDE_CACHE_DIR
- **Purpose**: Directory for cached data
- **Default**: `$HOME/.cache/claude`
- **Example**:
```bash
export CLAUDE_CACHE_DIR="/tmp/claude-cache"
```

#### CLAUDE_REGISTRY_CACHE
- **Purpose**: Agent registry cache file
- **Default**: `$CLAUDE_CACHE_DIR/agent_registry.cache`
- **Example**:
```bash
export CLAUDE_REGISTRY_CACHE="$HOME/.cache/claude/agents.json"
```

## Configuration Files

### 1. ~/.bashrc Configuration
Add to your `~/.bashrc` for persistent settings:

```bash
# === Claude Agent Framework Configuration ===

# Core paths
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_PROJECT_ROOT="$(pwd)"  # or your project path
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"

# Virtual environment
export CLAUDE_VENV="$HOME/.local/share/claude/venv"
alias claude-venv='source $CLAUDE_VENV/bin/activate'

# Feature flags
export CLAUDE_PERMISSION_BYPASS=true
export CLAUDE_AUTO_FIX=true
export CLAUDE_ORCHESTRATION=true
export CLAUDE_LEARNING=true

# Output control
export CLAUDE_OUTPUT_STYLE='precision-orchestration'
export CLAUDE_VERBOSE=true

# Aliases
alias claude-status='claude --status'
alias claude-agents='claude --agents'
alias claude-safe='claude --safe'
alias ca='claude agent'

# Quick agent functions
director() { claude agent director "$@"; }
architect() { claude agent architect "$@"; }
security() { claude agent security "$@"; }
optimizer() { claude agent optimizer "$@"; }

# GitHub sync shortcuts
alias ghsync='$CLAUDE_PROJECT_ROOT/github-sync.sh'
alias ghstatus='$CLAUDE_PROJECT_ROOT/github-sync.sh --status'

# Natural invocation (if configured)
[[ -f ~/.config/claude/natural-invocation.env ]] && source ~/.config/claude/natural-invocation.env
```

### 2. Database Configuration
Location: `config/database.json`

```json
{
  "host": "localhost",
  "port": 5432,
  "database": "claude_agents",
  "user": "claude",
  "password": "secure_password",
  "pool": {
    "min": 2,
    "max": 10
  },
  "ssl": false
}
```

### 3. Learning System Configuration
Location: `config/learning_config.json`

```json
{
  "enabled": true,
  "database": {
    "use_pgvector": true,
    "embedding_dimension": 256
  },
  "ml": {
    "model_type": "sklearn",
    "update_frequency": "daily",
    "min_samples": 100
  },
  "monitoring": {
    "track_performance": true,
    "track_errors": true,
    "retention_days": 30
  }
}
```

### 4. Tandem Orchestration Configuration
Location: `agents/config/tandem_config.json`

```json
{
  "execution_modes": {
    "default": "INTELLIGENT",
    "critical_operations": "REDUNDANT",
    "performance_critical": "SPEED_CRITICAL"
  },
  "python_orchestrator": {
    "enabled": true,
    "max_parallel_agents": 5,
    "timeout_seconds": 300
  },
  "c_layer": {
    "enabled": false,
    "fallback_to_python": true
  }
}
```

### 5. Agent Registry Configuration
Location: `~/.cache/claude/registry_config.json`

```json
{
  "auto_register": true,
  "cache_ttl_seconds": 3600,
  "scan_patterns": ["*.md", "*.MD"],
  "exclude_patterns": ["TEMPLATE.md", "WHERE_I_AM.md"],
  "metadata_extraction": {
    "extract_yaml": true,
    "extract_markdown": true,
    "extract_tools": true
  }
}
```

## Natural Agent Invocation

### Setup Natural Invocation
Create `~/.config/claude/natural-invocation.env`:

```bash
#!/bin/bash
# Natural Agent Invocation Configuration

# Enable natural language patterns
export CLAUDE_NATURAL_INVOCATION=true

# Define trigger patterns
export CLAUDE_TRIGGER_SECURITY="security|audit|vulnerability|threat"
export CLAUDE_TRIGGER_OPTIMIZE="optimize|performance|speed|slow"
export CLAUDE_TRIGGER_DEBUG="debug|error|bug|fix|broken"
export CLAUDE_TRIGGER_DEPLOY="deploy|release|production|rollout"

# Auto-invoke patterns
claude_auto() {
    local input="$1"
    case "$input" in
        *security*|*audit*)
            claude agent security "$input"
            ;;
        *optimize*|*performance*)
            claude agent optimizer "$input"
            ;;
        *debug*|*error*)
            claude agent debugger "$input"
            ;;
        *deploy*|*release*)
            claude agent deployer "$input"
            ;;
        *)
            claude "$input"
            ;;
    esac
}

# Alias for natural invocation
alias ai='claude_auto'
```

## Performance Tuning

### 1. Cache Optimization
```bash
# Increase cache TTL for stable environments
export CLAUDE_CACHE_TTL=7200  # 2 hours

# Use RAM disk for cache (faster)
export CLAUDE_CACHE_DIR="/dev/shm/claude-cache"
```

### 2. Parallel Execution
```bash
# Increase parallel agent limit
export CLAUDE_MAX_PARALLEL=10

# Enable parallel discovery
export CLAUDE_PARALLEL_DISCOVERY=true
```

### 3. Memory Management
```bash
# Set memory limits
export CLAUDE_MAX_MEMORY="2G"

# Enable garbage collection
export CLAUDE_GC_ENABLED=true
```

### 4. CPU Affinity
```bash
# Pin to P-cores for performance
export CLAUDE_CPU_AFFINITY="0-5"  # P-cores on Meteor Lake

# Use E-cores for background
export CLAUDE_BACKGROUND_AFFINITY="12-19"  # E-cores
```

## Security Configuration

### Production Settings
```bash
# Disable permission bypass
export CLAUDE_PERMISSION_BYPASS=false

# Enable audit logging
export CLAUDE_AUDIT_LOG="/var/log/claude/audit.log"

# Restrict agent access
export CLAUDE_ALLOWED_AGENTS="security,monitor,oversight"

# Enable secure mode
export CLAUDE_SECURE_MODE=true
```

### Network Security
```bash
# Bind to localhost only
export CLAUDE_BIND_ADDRESS="127.0.0.1"

# Enable TLS
export CLAUDE_TLS_ENABLED=true
export CLAUDE_TLS_CERT="/etc/claude/cert.pem"
export CLAUDE_TLS_KEY="/etc/claude/key.pem"
```

## Logging Configuration

### Log Levels
```bash
export CLAUDE_LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

### Log Destinations
```bash
# File logging
export CLAUDE_LOG_FILE="/var/log/claude/claude.log"

# Syslog
export CLAUDE_USE_SYSLOG=true
export CLAUDE_SYSLOG_FACILITY="local0"

# JSON logging
export CLAUDE_LOG_FORMAT="json"
```

### Log Rotation
```bash
# Max log size
export CLAUDE_LOG_MAX_SIZE="100M"

# Keep N old logs
export CLAUDE_LOG_BACKUP_COUNT=5

# Compression
export CLAUDE_LOG_COMPRESS=true
```

## Development Configuration

### Debug Settings
```bash
# Enable all debug features
export CLAUDE_DEBUG=true
export CLAUDE_DEBUG_LEVEL=3
export CLAUDE_TRACE_ENABLED=true
export CLAUDE_PROFILE_ENABLED=true
```

### Test Configuration
```bash
# Use test database
export CLAUDE_TEST_MODE=true
export CLAUDE_TEST_DB="claude_test"

# Mock agents
export CLAUDE_USE_MOCK_AGENTS=true

# Test fixtures
export CLAUDE_FIXTURES_DIR="./tests/fixtures"
```

## Troubleshooting Configuration Issues

### Check Current Configuration
```bash
# Show all Claude environment variables
env | grep CLAUDE

# Show effective configuration
claude --status

# Test configuration
claude --debug --status
```

### Reset to Defaults
```bash
# Unset all Claude variables
unset $(env | grep CLAUDE | cut -d= -f1)

# Reload defaults
source ~/.bashrc
```

### Validate Configuration
```bash
# Check paths exist
for path in $CLAUDE_PROJECT_ROOT $CLAUDE_AGENTS_DIR $CLAUDE_HOME; do
    [[ -d "$path" ]] && echo "✓ $path" || echo "✗ $path not found"
done

# Test agent discovery
claude --register-agents

# Verify wrapper works
claude --help
```

---

*Configuration Guide v1.0*  
*Last Updated: 2025-08-25*  
*Framework Version: 7.0*