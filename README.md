# Claude Agent Framework v7.0

[![CI/CD Pipeline](https://github.com/SWORDIntel/claude-backups/actions/workflows/test-shadowgit.yml/badge.svg)](https://github.com/SWORDIntel/claude-backups/actions/workflows/test-shadowgit.yml)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Production-ready multi-agent AI orchestration system with hardware acceleration and AI-powered development tools.**

Claude Agent Framework is an enterprise-grade platform for building intelligent, coordinated agent systems with unprecedented performance through Intel NPU acceleration and seamless OpenAI Codex integration.

---

## 🎯 Key Features

- **🤖 98 Specialized Agents** - Pre-built agents for development, security, infrastructure, and operations
- **⚡ Hardware Accelerated** - 7-10x speedup with Intel NPU (11-26 TOPS) and AVX2/AVX-512 SIMD
- **🧠 AI-Powered Development** - Integrated OpenAI Codex for code generation, review, and refactoring
- **🏗️ Three-Tier Architecture** - Clean separation: Binary Layer (C/Rust) → Hook Layer (Python) → Agent Layer
- **🔒 Enterprise Security** - Zero vulnerabilities, comprehensive auditing, military-grade optimization
- **📊 Production Tested** - 82% test coverage, complete CI/CD pipeline, performance validated
- **🔌 Extensible** - Easy to add custom agents, seamless integration with existing systems

---

## 🚀 Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups

# Run unified installer
./install

# Activate virtual environment
source venv/bin/activate

# Verify installation
python3 -c "from claude_agents import get_agent, list_agents; print('✓ Ready')"
```

**That's it!** The installer automatically:
- Sets up Python virtual environment
- Installs all dependencies
- Builds C/Rust components
- Configures hardware acceleration
- Creates convenience scripts

### First Steps

```python
# Import agent system
from claude_agents.orchestration import get_agent_registry
from claude_agents import get_agent, list_agents

# List available agents
agents = list_agents()
print(f"Available agents: {len(agents)}")

# Get specific agent
agent = get_agent("python-internal")

# Invoke agent
result = agent.execute(task="analyze code quality")
```

📖 **Detailed Guide**: [docs/QUICKSTART.md](docs/QUICKSTART.md)

---

## 🔌 Integration with Claude Code

**This framework is specifically designed for [Claude Code](https://claude.ai/code)**, Anthropic's official CLI for Claude AI. The 98 specialized agents are built to enhance Claude Code sessions with advanced capabilities.

### What is Claude Code?

Claude Code is an interactive CLI tool that helps with software engineering tasks. The Claude Agent Framework v7.0 extends Claude Code with:
- **98 specialized agents** for development, security, infrastructure, and operations
- **Hardware acceleration** via Intel NPU and AVX2/AVX-512 SIMD
- **Multi-agent orchestration** with parallel execution
- **Production-ready tools** for real-world development workflows

### Using Agents in Claude Code

The framework integrates seamlessly with Claude Code's `Task` tool for agent invocation:

#### Basic Agent Invocation

```python
# Within a Claude Code session, use the Task tool:
Task(
    subagent_type="python-internal",
    prompt="Analyze this codebase for performance bottlenecks"
)

# Invoke security auditor
Task(
    subagent_type="security",
    prompt="Perform security audit on authentication module"
)

# Run tests with specialized agent
Task(
    subagent_type="testbed",
    prompt="Run comprehensive test suite and analyze coverage"
)
```

#### Multi-Agent Coordination

```python
# Parallel execution for independent tasks
Task(subagent_type="architect", prompt="Design new microservice architecture")
Task(subagent_type="security", prompt="Analyze security requirements")
Task(subagent_type="database", prompt="Design database schema")

# Sequential workflow (agents coordinate automatically)
Task(
    subagent_type="constructor",
    prompt="Initialize new Python project with best practices"
)
# Constructor will automatically invoke other agents as needed
```

#### Hardware-Aware Execution

The framework automatically detects your hardware and optimizes performance:

```python
# Agent automatically uses available acceleration
Task(
    subagent_type="shadowgit",  # Uses AVX2/AVX-512 if available
    prompt="Analyze git history and find performance regressions"
)

# NPU acceleration for ML workloads (if Intel NPU available)
Task(
    subagent_type="npu",
    prompt="Optimize neural network inference with NPU acceleration"
)
```

### Configuration via CLAUDE.md

The framework is configured through `CLAUDE.md` in the project root:

```yaml
---
name: claude
version: 7.0.0
status: PRODUCTION
modules: 11
agents: 98
tools:
  - Task
  - Read
  - Write
  - Edit
  - Bash
sdk_version: "2.0+"
checkpoint_support: true
parallel_orchestration: true
---

# Your project-specific instructions for Claude Code
```

### Available Agent Categories

**Development Agents:**
- `architect` - System design and architecture
- `constructor` - Project initialization and scaffolding
- `debugger` - Bug detection and debugging assistance
- `optimizer` - Performance optimization
- `linter` - Code quality and style enforcement
- `patcher` - Bug fixes and patches

**Security Agents:**
- `security` - Security auditing and vulnerability scanning
- `cryptoexpert` - Cryptographic implementation
- `auditor` - Compliance and security audits
- `quantumguard` - Quantum-resistant security

**Infrastructure Agents:**
- `deployer` - Deployment automation
- `infrastructure` - Infrastructure management
- `database` - Database design and optimization
- `docker` - Container orchestration
- `monitor` - System monitoring

**Language-Specific Agents:**
- `python-internal` - Python development
- `c-internal` - C development
- `rust-internal` - Rust development
- `java-internal` - Java development
- `typescript-internal` - TypeScript development

**Specialized Agents:**
- `shadowgit` - Git operations with 7-10x NPU acceleration
- `npu` - Intel NPU hardware optimization
- `mlops` - ML operations and deployment
- `datascience` - Data science workflows

📖 **Complete Agent List**: [docs/AGENT_ECOSYSTEM.md](docs/AGENT_ECOSYSTEM.md)

### Example Workflow

Here's a complete development workflow using Claude Code with the agent framework:

```bash
# 1. Start Claude Code in your project
claude

# 2. Within Claude Code session, invoke agents:
```

```python
# Design architecture
Task(
    subagent_type="architect",
    prompt="Design a microservices architecture for user authentication"
)

# Initialize project structure
Task(
    subagent_type="constructor",
    prompt="Create Python microservice with FastAPI, PostgreSQL, and Redis"
)

# Implement features
Task(
    subagent_type="python-internal",
    prompt="Implement JWT authentication with refresh tokens"
)

# Security review
Task(
    subagent_type="security",
    prompt="Review authentication implementation for vulnerabilities"
)

# Run tests
Task(
    subagent_type="testbed",
    prompt="Generate and run comprehensive test suite"
)

# Deploy
Task(
    subagent_type="deployer",
    prompt="Deploy to production with Docker and Kubernetes"
)
```

### Best Practices

**1. Use Specific Agents for Specific Tasks**
- Choose the most appropriate agent for each task
- Avoid using generic agents when specialized ones are available

**2. Leverage Parallel Execution**
- Invoke multiple independent agents simultaneously
- Let Claude Code handle coordination and synchronization

**3. Trust Agent Recommendations**
- Agents may suggest additional steps or invoke other agents
- This is intentional for comprehensive task completion

**4. Monitor Performance**
- Hardware acceleration is automatic
- Check logs for acceleration mode used (AVX-512, AVX2, SSE4.2, or scalar)

**5. Configure Per-Project**
- Use `CLAUDE.md` for project-specific agent configuration
- Set hardware preferences, concurrency limits, and custom behaviors

### Troubleshooting

**Agent Not Found:**
```bash
# List all available agents
python3 -c "from claude_agents import list_agents; print('\n'.join(list_agents()))"
```

**Hardware Acceleration Not Working:**
```bash
# Check hardware capabilities
python3 hardware/milspec_hardware_analyzer.py

# View CPU features
python3 -c "from hooks.shadowgit.python import ShadowgitAVX2; sg = ShadowgitAVX2(); print(sg.hw_caps)"
```

**Performance Issues:**
```bash
# Enable verbose logging
export CLAUDE_AGENTS_LOG_LEVEL=DEBUG

# Check NPU status
bash hardware/enable-npu-turbo.sh
```

📖 **Detailed Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🤖 AI-Powered Development with Codex

**NEW in v7.0**: Seamless OpenAI GPT-4 integration for intelligent code generation and review.

### Setup Codex

```bash
# Install OpenAI package
pip install openai

# Set API key
export OPENAI_API_KEY="sk-your-api-key-here"
```

### Generate Code

```python
from claude_agents.implementations.development import CodexAgent
import asyncio

async def demo():
    agent = CodexAgent()
    agent.initialize()

    # Generate code from natural language
    result = await agent.generate_code(
        prompt="Create a function to validate email addresses with regex",
        language="python"
    )

    if result["success"]:
        print(result["code"])

asyncio.run(demo())
```

### Review Code

```python
# Automated code review with security analysis
result = await agent.review_code(
    code="""
    def process_data(user_input):
        return eval(user_input)  # Security issue!
    """,
    focus_areas=["security", "best_practices"]
)

print(result["review"])
```

### Interactive Examples

```bash
# Run comprehensive examples
python3 examples/codex_usage_examples.py
```

**Codex Features**:
- 🎯 **Context-Aware**: Understands your project structure and standards
- 🔍 **Security-Focused**: Identifies vulnerabilities and suggests fixes
- ♻️ **Smart Refactoring**: Improves code quality with specific goals
- 📝 **Documentation**: Auto-generates docstrings and comments
- 🏗️ **Agent Generation**: Creates complete agent implementations

📖 **Full Guide**: [docs/CODEX_INTEGRATION.md](docs/CODEX_INTEGRATION.md)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│               AGENT LAYER (Python)                  │
│  98 Specialized Agents - Task Orchestration         │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│             HOOK LAYER (Python + C)                 │
│  Business Logic - NPU/AVX2 Acceleration             │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│            BINARY LAYER (C + Rust)                  │
│  High-Performance Primitives - SIMD Optimized       │
└─────────────────────────────────────────────────────┘
```

**Key Components**:
- **Agent Registry**: Dynamic agent discovery and coordination
- **ShadowGit**: Git intelligence with 7-10x NPU acceleration
- **Crypto-POW**: Hardware-accelerated cryptographic operations
- **Codex Agent**: AI-powered code generation and review

📖 **Details**: [docs/architecture/](docs/architecture/)

---

## 📚 Documentation

### Getting Started
- **[Quick Start Guide](docs/QUICKSTART.md)** - Detailed installation and first steps
- **[Architecture Overview](docs/architecture/README.md)** - System design and components
- **[Configuration Guide](docs/CONFIGURATION.md)** - System configuration

### Development
- **[Development Guide](docs/DEVELOPMENT.md)** - Contributing and building
- **[Agent Creation](docs/guides/AGENT_CREATION.md)** - Build custom agents
- **[API Reference](docs/api/)** - Complete API documentation

### AI & Codex
- **[Codex Integration](docs/CODEX_INTEGRATION.md)** - AI-powered development complete guide
- **[Codex Examples](examples/codex_usage_examples.py)** - Interactive examples
- **[Codex Configuration](config/codex.yaml)** - Settings and customization

### Advanced Topics
- **[Hardware Acceleration](docs/guides/HARDWARE_ACCELERATION.md)** - NPU and SIMD optimization
- **[Performance Tuning](docs/guides/PERFORMANCE.md)** - Optimization strategies
- **[Security Best Practices](docs/guides/SECURITY.md)** - Security guidelines
- **[Integration Guide](docs/INTEGRATION_VALIDATION_REPORT.md)** - Component integration

---

## ⚡ Performance

| Component | Baseline | Optimized | Speedup |
|-----------|----------|-----------|---------|
| File Hashing (100 files) | 140ms | 20ms | **7x** |
| Similarity Matrix | 120ms | 15ms | **8x** |
| Git Diff Analysis | 500ms | 50ms | **10x** |
| Agent Coordination | 1000µs | 50-100µs | **10-20x** |

**Hardware Support**:
- Intel NPU (11-26 TOPS) - Automatic detection and optimization
- AVX2/AVX-512 SIMD - Hardware-accelerated operations
- Multi-core scheduling - Intelligent P-core/E-core allocation

📖 **Benchmarks**: [docs/PERFORMANCE_METRICS.md](docs/PERFORMANCE_METRICS.md)

---

## 🔧 Configuration

### Basic Configuration

Edit `config/agent_config.yaml`:

```yaml
# Agent System Configuration
agents:
  max_concurrent: 10
  timeout: 300
  log_level: INFO

# Hardware Optimization
hardware:
  enable_npu: true
  enable_avx2: true
  prefer_p_cores: true
```

### Codex Configuration

Edit `config/codex.yaml`:

```yaml
# OpenAI API Settings
api:
  model: "gpt-4"  # or gpt-4-turbo, gpt-3.5-turbo
  # api_key: Set via OPENAI_API_KEY environment variable

# Generation Settings
generation:
  max_tokens: 2000
  temperature: 0.2
  default_language: "python"
```

📖 **Full Configuration**: [docs/CONFIGURATION.md](docs/CONFIGURATION.md)

---

## 🎓 Examples

### Agent Coordination

```python
from claude_agents.orchestration import get_agent_registry

registry = get_agent_registry()

# Invoke multiple agents in parallel
results = await registry.invoke_parallel([
    ("security", {"task": "audit_code"}),
    ("optimizer", {"task": "analyze_performance"}),
    ("debugger", {"task": "find_issues"})
])
```

### Hardware Acceleration

```python
from hooks.shadowgit.python import ShadowGitAVX2

# Automatically uses NPU if available
sg = ShadowGitAVX2()

# 7-10x faster file hashing
hashes = sg.hash_files_batch(['file1.py', 'file2.py', 'file3.py'])
```

### Code Generation with Codex

```python
from claude_agents.implementations.development import generate
import asyncio

# Generate agent implementation
result = await generate("""
    Create a monitoring agent that tracks CPU, memory, and disk usage.
    Include alerts for threshold violations.
""")

print(result["code"])
```

📖 **More Examples**: [examples/](examples/)

---

## 🧪 Testing

```bash
# Run all tests
pytest -v

# Run specific test suite
pytest tests/integration/

# Run with coverage report
pytest --cov=claude_agents --cov-report=html

# Performance benchmarks
python3 tests/performance/benchmark_suite.py
```

**Test Coverage**: 82% (target: 80%+)

📖 **Testing Guide**: [docs/TESTING.md](docs/TESTING.md)

---

## 🔗 Adapting for OpenAI Codex

### Integration Patterns

The Claude Agent Framework is designed for seamless Codex integration:

#### 1. As a Development Assistant

```python
# Use Codex to generate agent code
from claude_agents.implementations.development import CodexAgent

agent = CodexAgent()
agent.initialize()

# Generate custom agent implementation
result = await agent.generate_code("""
    Create a new agent for monitoring system resources.
    Follow Claude Agent Framework patterns.
    Include proper error handling and async operations.
""")
```

#### 2. Automated Code Review in CI/CD

```python
# .github/workflows/codex-review.yml
# Use Codex agent for automated PR reviews

from claude_agents.implementations.development import review

# Review changed files
for file in changed_files:
    result = await review(
        code=open(file).read(),
        focus_areas=["security", "performance", "best_practices"]
    )
    post_review_comment(result["review"])
```

#### 3. Interactive Development

```bash
# Run interactive Codex examples
python3 examples/codex_usage_examples.py

# Select from menu:
# 1. Generate functions
# 2. Review code
# 3. Refactor code
# 4. Generate complete agents
# 5. Batch operations
```

#### 4. Agent-Powered Refactoring

```python
# Batch refactor project files
from claude_agents.implementations.development import refactor

for python_file in project_files:
    result = await refactor(
        code=open(python_file).read(),
        goals=["add_type_hints", "improve_documentation", "optimize"]
    )
    if result["success"]:
        save_refactored_code(python_file, result["result"])
```

### Configuration for Codex Adaptation

**1. Set Project Context** (`config/codex.yaml`):

```yaml
project_context:
  name: "Your Project Name"
  standards:
    python:
      version: "3.11+"
      style: "black"
      imports: "your.project.patterns"
```

**2. Customize Focus Areas**:

```yaml
review:
  focus_areas:
    - security
    - your_custom_concern
    - project_specific_pattern
```

**3. Integration with CI/CD**:

```bash
# Pre-commit hook
./scripts/codex-pre-commit.sh

# Automated review
python3 -m claude_agents.implementations.development.codex_agent_impl
```

### Best Practices for Codex Integration

- ✅ **Use Environment Variables** for API keys (never commit)
- ✅ **Set Cost Limits** in `config/codex.yaml`
- ✅ **Review AI Suggestions** before accepting
- ✅ **Add Tests** for generated code
- ✅ **Monitor Token Usage** for cost control
- ✅ **Cache Results** for repeated operations
- ✅ **Use GPT-3.5** for simple tasks (cost savings)

📖 **Comprehensive Guide**: [docs/CODEX_INTEGRATION.md](docs/CODEX_INTEGRATION.md)

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

**Development Setup**:

```bash
# Clone and install for development
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups
./install --dev

# Install development dependencies
pip install -r requirements-dev.txt

# Run code formatters
black agents/src/python/claude_agents/
isort agents/src/python/claude_agents/

# Run linters
pylint agents/src/python/claude_agents/
mypy agents/src/python/claude_agents/
```

---

## 📊 Project Status

- ✅ **Production Ready** - Fully tested and validated
- ✅ **82% Test Coverage** - Comprehensive test suite
- ✅ **Zero Vulnerabilities** - Security audited
- ✅ **CI/CD Pipeline** - Automated testing and deployment
- ✅ **Hardware Validated** - Intel Meteor Lake optimized
- ✅ **AI Integration** - OpenAI Codex ready

---

## 🎯 Use Cases

- **Enterprise Development**: Large-scale multi-agent coordination
- **AI-Powered Coding**: Leverage Codex for code generation and review
- **Performance-Critical Systems**: Hardware-accelerated operations
- **Security Auditing**: Automated security analysis and testing
- **Infrastructure Management**: Intelligent resource orchestration
- **Code Quality**: Automated review, refactoring, and optimization

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **Documentation**: [docs/](docs/)
- **Issue Tracker**: [GitHub Issues](https://github.com/SWORDIntel/claude-backups/issues)
- **CI/CD**: [GitHub Actions](https://github.com/SWORDIntel/claude-backups/actions)
- **OpenAI Codex**: [docs/CODEX_INTEGRATION.md](docs/CODEX_INTEGRATION.md)
- **Interactive Portal**: [html/index.html](html/index.html)

---

## 💡 Support

- 📖 **Documentation**: [docs/](docs/)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/SWORDIntel/claude-backups/discussions)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/SWORDIntel/claude-backups/issues)

---

**Built with ❤️ for the developer community. Powered by Intel NPU and OpenAI Codex.**
