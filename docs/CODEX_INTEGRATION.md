# OpenAI Codex Integration Guide

**Claude Agent Framework v7.0** now includes seamless integration with OpenAI's GPT-4 API for AI-powered code generation, review, and refactoring.

> **Note**: Original Codex models (code-davinci-002) have been deprecated by OpenAI. This integration uses GPT-4 which provides superior code generation capabilities.

---

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [Examples](#examples)
6. [API Reference](#api-reference)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Features

The Codex agent provides:

- **🤖 Code Generation**: Generate code from natural language descriptions
- **🔍 Code Review**: Automated code review with security and performance analysis
- **♻️ Refactoring**: Intelligent code refactoring with specific goals
- **📝 Documentation**: Automated docstring and comment generation
- **🎯 Context-Aware**: Understands Claude Agent Framework architecture and standards
- **🔗 Agent Integration**: Fully integrated with the 98-agent orchestration system

---

## Installation

### 1. Install OpenAI Python Package

```bash
pip install openai
```

Or if using the project's virtual environment:

```bash
source venv/bin/activate
pip install openai
```

### 2. Set API Key

Set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY="sk-your-api-key-here"
```

For permanent configuration, add to `~/.bashrc` or `~/.zshrc`:

```bash
echo 'export OPENAI_API_KEY="sk-your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

Or configure in `config/codex.yaml`:

```yaml
api:
  api_key: "your-api-key-here"  # Not recommended for security
```

### 3. Verify Installation

```bash
python3 -c "from claude_agents.implementations.development import CodexAgent; print('✓ Codex agent available')"
```

---

## Configuration

Configuration is stored in `config/codex.yaml`. Key settings:

### API Configuration

```yaml
api:
  model: "gpt-4"  # or "gpt-4-turbo-preview", "gpt-3.5-turbo"
  # api_key: Set via environment variable (recommended)
```

### Generation Settings

```yaml
generation:
  max_tokens: 2000
  temperature: 0.2  # Lower = more deterministic
  default_language: "python"
  include_context: true  # Include project context in prompts
```

### Review Settings

```yaml
review:
  focus_areas:
    - security
    - performance
    - best_practices
    - style
    - documentation
  min_quality_score: 7  # Minimum acceptable score (1-10)
```

### Project Context

The agent automatically includes project context in all requests:

```yaml
project_context:
  name: "Claude Agent Framework"
  version: "7.0.0"
  architecture: # ... (3-tier system description)
  standards: # ... (Python, Rust, C standards)
  imports: # ... (Correct import patterns)
  security: # ... (Security guidelines)
```

---

## Usage

### Python API

#### 1. Initialize Agent

```python
from claude_agents.implementations.development import CodexAgent

agent = CodexAgent()
if agent.initialize():
    print("✓ Codex agent ready")
else:
    print("✗ Failed to initialize (check API key)")
```

#### 2. Generate Code

```python
import asyncio

async def generate_example():
    result = await agent.generate_code(
        prompt="Create a Python function to validate email addresses",
        language="python",
        context="For use in user registration system"
    )

    if result["success"]:
        print(result["code"])
        print(f"Tokens used: {result['usage']['total_tokens']}")
    else:
        print(f"Error: {result['error']}")

asyncio.run(generate_example())
```

#### 3. Review Code

```python
async def review_example():
    code = '''
def process_data(data):
    result = eval(data)  # Dangerous!
    return result
    '''

    result = await agent.review_code(
        code=code,
        language="python",
        focus_areas=["security", "best_practices"]
    )

    if result["success"]:
        print(result["review"])
    else:
        print(f"Error: {result['error']}")

asyncio.run(review_example())
```

#### 4. Refactor Code

```python
async def refactor_example():
    code = '''
def calc(a,b,c):
    x=a+b
    y=x*c
    return y
    '''

    result = await agent.refactor_code(
        code=code,
        language="python",
        goals=["improve_readability", "add_type_hints", "add_documentation"]
    )

    if result["success"]:
        print(result["result"])
    else:
        print(f"Error: {result['error']}")

asyncio.run(refactor_example())
```

### Convenience Functions

For quick one-off operations:

```python
from claude_agents.implementations.development import generate, review, refactor
import asyncio

# Generate code
result = asyncio.run(generate("Create a binary search function"))

# Review code
result = asyncio.run(review("def foo(): pass"))

# Refactor code
result = asyncio.run(refactor("def foo(): pass", goals=["add_docstrings"]))
```

### Command Line Usage

Run the agent directly:

```bash
python3 agents/src/python/claude_agents/implementations/development/codex_agent_impl.py
```

---

## Examples

### Example 1: Generate Agent Implementation

```python
import asyncio
from claude_agents.implementations.development import CodexAgent

async def main():
    agent = CodexAgent()
    agent.initialize()

    result = await agent.generate_code(
        prompt="""
        Create a new agent implementation for monitoring system resources.
        The agent should:
        - Monitor CPU, memory, and disk usage
        - Alert when thresholds are exceeded
        - Follow Claude Agent Framework patterns
        """,
        language="python",
        context="Agent should inherit from AgentBase class"
    )

    if result["success"]:
        # Save generated code
        with open("resource_monitor_agent.py", "w") as f:
            f.write(result["code"])
        print("✓ Agent implementation generated")
        print(f"Tokens: {result['usage']['total_tokens']}")
    else:
        print(f"✗ Error: {result['error']}")

asyncio.run(main())
```

### Example 2: Automated Code Review in CI/CD

```python
import asyncio
import sys
from pathlib import Path
from claude_agents.implementations.development import CodexAgent

async def review_file(filepath: str):
    """Review a Python file for issues"""
    agent = CodexAgent()
    if not agent.initialize():
        print("Failed to initialize Codex agent")
        return False

    code = Path(filepath).read_text()

    result = await agent.review_code(
        code=code,
        language="python",
        focus_areas=["security", "performance", "best_practices"]
    )

    if not result["success"]:
        print(f"Review failed: {result['error']}")
        return False

    print(f"Review for {filepath}:")
    print(result["review"])

    # Check if critical issues found
    if "CRITICAL" in result["review"] or "SECURITY" in result["review"]:
        print("\n⚠ Critical issues found!")
        return False

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python review_script.py <file.py>")
        sys.exit(1)

    success = asyncio.run(review_file(sys.argv[1]))
    sys.exit(0 if success else 1)
```

### Example 3: Batch Refactoring

```python
import asyncio
from pathlib import Path
from claude_agents.implementations.development import CodexAgent

async def refactor_project(directory: str, goals: list):
    """Refactor all Python files in a directory"""
    agent = CodexAgent()
    agent.initialize()

    python_files = Path(directory).glob("**/*.py")

    for filepath in python_files:
        print(f"Refactoring {filepath}...")

        code = filepath.read_text()

        result = await agent.refactor_code(
            code=code,
            language="python",
            goals=goals
        )

        if result["success"]:
            # Backup original
            backup = filepath.with_suffix(".py.bak")
            filepath.rename(backup)

            # Write refactored code (parse it from result)
            # (In practice, you'd need to extract just the code from the result)
            print(f"✓ Refactored {filepath}")
        else:
            print(f"✗ Failed to refactor {filepath}: {result['error']}")

# Usage
asyncio.run(refactor_project(
    "agents/src/python/claude_agents",
    goals=["add_type_hints", "improve_documentation", "optimize_performance"]
))
```

---

## API Reference

### CodexAgent Class

#### `__init__()`
Initialize the Codex agent.

#### `initialize(config: Optional[Dict] = None) -> bool`
Initialize with API credentials.

**Parameters:**
- `config` (dict, optional): Configuration with 'openai_api_key' and 'model'

**Returns:**
- `bool`: True if initialization successful

#### `async generate_code(prompt: str, language: str = "python", context: str = "", max_tokens: int = 2000) -> Dict`
Generate code from natural language prompt.

**Parameters:**
- `prompt` (str): Description of code to generate
- `language` (str): Programming language
- `context` (str): Additional project context
- `max_tokens` (int): Maximum response tokens

**Returns:**
- Dict with keys: `success`, `code`, `model`, `usage`

#### `async review_code(code: str, language: str = "python", focus_areas: List[str] = None) -> Dict`
Review code and provide suggestions.

**Parameters:**
- `code` (str): Source code to review
- `language` (str): Programming language
- `focus_areas` (list): Areas to focus on

**Returns:**
- Dict with keys: `success`, `review`, `model`

#### `async refactor_code(code: str, language: str = "python", goals: List[str] = None) -> Dict`
Refactor code with specific goals.

**Parameters:**
- `code` (str): Source code to refactor
- `language` (str): Programming language
- `goals` (list): Refactoring goals

**Returns:**
- Dict with keys: `success`, `result`, `model`

### Convenience Functions

#### `get_codex_agent() -> CodexAgent`
Get or create singleton Codex agent instance.

#### `async generate(prompt: str, **kwargs) -> Dict`
Generate code (convenience function).

#### `async review(code: str, **kwargs) -> Dict`
Review code (convenience function).

#### `async refactor(code: str, **kwargs) -> Dict`
Refactor code (convenience function).

---

## Best Practices

### 1. API Key Security
- ✅ Use environment variables
- ✅ Never commit API keys to Git
- ✅ Use separate keys for dev/prod
- ❌ Don't hardcode keys in config files

### 2. Cost Management
- Monitor token usage (check `result['usage']`)
- Set `daily_token_limit` in config
- Use GPT-3.5-turbo for simple tasks (cheaper)
- Cache results when possible

### 3. Code Generation
- Provide clear, detailed prompts
- Include relevant context
- Review generated code before using
- Add tests for generated code
- Verify security implications

### 4. Code Review
- Use for pre-commit hooks
- Focus on specific areas when possible
- Combine with traditional linters
- Review AI suggestions critically

### 5. Error Handling
```python
try:
    result = await agent.generate_code(prompt)
    if not result["success"]:
        log_error(result["error"])
        # Fallback to manual implementation
except Exception as e:
    # Handle network/API errors
    log_exception(e)
```

---

## Troubleshooting

### API Key Not Found

**Error:** `OPENAI_API_KEY not found in config or environment`

**Solution:**
```bash
export OPENAI_API_KEY="sk-your-key"
# Or add to ~/.bashrc for persistence
```

### Import Error

**Error:** `ImportError: No module named 'openai'`

**Solution:**
```bash
pip install openai
```

### Rate Limiting

**Error:** `Rate limit exceeded`

**Solution:**
- Wait and retry with exponential backoff
- Reduce request frequency
- Upgrade API plan if needed

### Poor Code Quality

**Issue:** Generated code doesn't meet standards

**Solution:**
- Improve prompt specificity
- Add more project context
- Use GPT-4 instead of GPT-3.5
- Review and refine generated code

### Token Limit Exceeded

**Error:** `This model's maximum context length is X tokens`

**Solution:**
- Reduce `max_tokens` setting
- Split large requests into smaller chunks
- Simplify prompts

---

## Integration with Agent System

The Codex agent integrates seamlessly with the Claude Agent Framework:

```python
from claude_agents.orchestration import get_agent_registry

# Register Codex agent
registry = get_agent_registry()
codex_agent = CodexAgent()
codex_agent.initialize()

registry.register_agent(
    name="codex",
    agent=codex_agent,
    category="development",
    capabilities=["code_generation", "code_review", "refactoring"]
)

# Invoke via registry
result = await registry.invoke_agent(
    "codex",
    task="generate_code",
    params={"prompt": "Create a logging utility"}
)
```

---

## Cost Estimation

Approximate costs (as of November 2024):

| Model | Input | Output | Typical Request |
|-------|-------|--------|----------------|
| GPT-4 | $0.03/1K tokens | $0.06/1K tokens | $0.05-0.15 |
| GPT-4 Turbo | $0.01/1K tokens | $0.03/1K tokens | $0.02-0.06 |
| GPT-3.5 Turbo | $0.0015/1K tokens | $0.002/1K tokens | $0.005-0.015 |

**Note:** Prices subject to change. Check [OpenAI Pricing](https://openai.com/pricing) for current rates.

---

## Support & Resources

- **OpenAI Documentation**: https://platform.openai.com/docs
- **Claude Agent Framework**: [README.md](../README.md)
- **Issues**: [GitHub Issues](https://github.com/SWORDIntel/claude-backups/issues)
- **Configuration**: [config/codex.yaml](../config/codex.yaml)

---

## License

Part of the Claude Agent Framework v7.0 project.
