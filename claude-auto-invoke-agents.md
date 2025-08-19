# Claude Code Auto-Invocation Guide

## Automatic Agent Invocation Patterns

Claude Code will automatically invoke the appropriate specialized agents based on these patterns:

### Security Domain
**Trigger Keywords**: security, vulnerability, audit, compliance, threat, risk, encryption, crypto
- **CSO**: Enterprise security strategy, compliance frameworks, risk assessment
- **SecurityAuditor**: Code audits, vulnerability scanning, security testing
- **CryptoExpert**: Cryptography implementation, encryption protocols, key management
- **Security**: General security analysis and recommendations
- **Bastion**: Network security, VPN, firewall configuration
- **SecurityChaosAgent**: Chaos testing, resilience testing, failure scenarios

### Development Domain
**Trigger Keywords**: build, code, implement, develop, create, architecture
- **LeadEngineer**: Technical leadership, architecture decisions, performance optimization
- **Architect**: System design, technical architecture, design patterns
- **Constructor**: Project initialization, scaffolding, boilerplate generation
- **Patcher**: Bug fixes, hotfixes, surgical code changes
- **Debugger**: Error analysis, debugging, root cause analysis

### Testing Domain
**Trigger Keywords**: test, quality, QA, validate, verify, coverage
- **QADirector**: Test strategy, quality assurance planning, test coordination
- **Testbed**: Test implementation, test execution, coverage analysis

### Infrastructure Domain
**Trigger Keywords**: deploy, CI/CD, infrastructure, monitoring, performance
- **Infrastructure**: System setup, configuration management, environment setup
- **Deployer**: Deployment orchestration, release management, rollouts
- **Monitor**: Observability, metrics, logging, alerting
- **Optimizer**: Performance tuning, optimization, resource efficiency

### Data & ML Domain
**Trigger Keywords**: data, ML, machine learning, AI, analytics, database
- **DataScience**: Data analysis, statistical analysis, ML models
- **MLOps**: ML pipelines, model deployment, experiment tracking
- **Database**: Database design, query optimization, data modeling
- **NPU**: AI acceleration, neural processing, hardware optimization

### Documentation Domain
**Trigger Keywords**: document, docs, README, help, explain
- **Docgen**: Documentation generation, API docs, user guides
- **RESEARCHER**: Technology research, best practices, tool evaluation

### Specialized Development
**Trigger Keywords**: API, mobile, GUI, terminal, web, frontend
- **APIDesigner**: API design, REST/GraphQL, API contracts
- **Mobile**: iOS/Android development, React Native, mobile optimization
- **PyGUI**: Python GUI development, Tkinter, PyQt, Streamlit
- **TUI**: Terminal UI, CLI tools, ncurses applications
- **Web**: Web development, React/Vue/Angular, frontend optimization

## Auto-Invocation Rules

### 1. Pattern Matching
When Claude detects keywords or phrases matching agent specialties, it will automatically suggest or invoke the appropriate agent.

### 2. Multi-Step Task Detection
For complex tasks requiring multiple steps, Claude will automatically invoke:
- **Director**: For strategic planning
- **ProjectOrchestrator**: For tactical coordination
- **Relevant specialist agents**: Based on task requirements

### 3. Context-Aware Invocation
Claude analyzes the full context of your request to determine:
- Primary agent needed
- Supporting agents for comprehensive solution
- Execution order for multi-agent workflows

## Usage Examples

### Example 1: Security Request
```
User: "Review this code for security vulnerabilities"
Claude: *Automatically invokes SecurityAuditor, then Security for comprehensive analysis*
```

### Example 2: Full Development Cycle
```
User: "Create a new REST API with authentication"
Claude: *Invokes Director → ProjectOrchestrator → APIDesigner → Security → Testbed*
```

### Example 3: Performance Issue
```
User: "This function is running slowly"
Claude: *Invokes Debugger → Optimizer → Monitor for analysis and optimization*
```

## Enabling Auto-Invocation

Auto-invocation is enabled by default through:

1. **CLAUDE.md context**: Loaded at session start
2. **Agent proactive_triggers**: Defined in each agent
3. **Pattern recognition**: Built into Claude's processing
4. **Workflow detection**: Multi-step task analysis

## Manual Override

To disable auto-invocation for a specific request:
```
User: "Without using agents, explain how to..."
```

To explicitly choose an agent:
```
User: "Use the Optimizer agent to..."
```

## Best Practices

1. **Be descriptive**: More context helps Claude choose the right agents
2. **Mention goals**: Stating your end goal helps with agent orchestration
3. **Specify constraints**: Mention performance, security, or quality requirements
4. **Trust the system**: Let Claude coordinate multiple agents when needed

## Dynamic Updates

The agent system refreshes every 60 seconds, automatically discovering:
- New agents added to the project
- Updated agent capabilities
- Modified invocation patterns
- Enhanced workflows

This ensures Claude always has access to the latest agent capabilities without manual intervention.