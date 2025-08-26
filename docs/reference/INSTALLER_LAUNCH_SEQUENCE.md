# Claude Installer Launch Sequence Documentation

## Overview
The claude-installer.sh orchestrates the installation and launch of multiple components in a specific order. The installer has three modes:
- **Full Mode** (default): Installs all components
- **Quick Mode**: Minimal installation
- **Custom Mode**: User selects components

## Launch Order for Full Installation

### Phase 1: Prerequisites & Core Installation
1. **Prerequisites Check** (`check_prerequisites`)
   - Validates system requirements
   - Checks Python, Git, curl availability
   - Detects Docker/Docker Compose availability
   - Sets up environment variables

2. **Docker Installation** (if needed and allowed)
   - Attempts to install Docker and Docker Compose
   - Configures Docker permissions
   - Adds user to docker group

3. **Node.js/npm Installation** (`install_npm_package`)
   - Checks for existing Node.js/npm
   - Installs via 4 fallback methods if needed:
     - Package manager (apt/yum/dnf)
     - NVM (Node Version Manager)
     - NodeSource repository
     - Official Node.js installer
   - Installs Claude Code CLI package

4. **Agent Installation** (`install_agents`)
   - Copies all agent .md files from source
   - Creates agent directory structure
   - Preserves existing agents if present

### Phase 2: Configuration & Extensions
5. **Hooks Installation** (`install_hooks`)
   - Installs Claude Code hooks for agent invocation
   - Sets up hook configuration

6. **Statusline Installation** (`install_statusline`)
   - Installs Neovim statusline integration
   - Configures statusline for agent monitoring

7. **Global CLAUDE.md** (`install_global_claude_md`)
   - Copies CLAUDE.md template to user's home directory
   - Sets up agent auto-invocation guide

8. **Claude Directory Setup** (`setup_claude_directory`)
   - Creates ~/.claude directory structure
   - Sets up symlinks to project directories
   - Copies configuration files from repo

9. **Agent Registration** (`register_agents_with_task_tool`)
   - Copies agent-registry.json from repo
   - Copies settings.json configuration
   - Copies available-agents.txt reference
   - Registers 60+ agents with Task tool

10. **Precision Orchestration Style** (`setup_precision_style`)
    - Runs precision orchestration style setup script
    - Configures default output style
    - Creates claude-precision wrapper

### Phase 3: Environment & Dependencies
11. **Virtual Environment** (`setup_virtual_environment`)
    - Creates Python virtual environment
    - Installs Python dependencies
    - Sets up venv activation

12. **Database System** (`setup_database_system`)
    - **Docker Path** (if Docker available):
      - Launches PostgreSQL via docker-compose
      - Initializes database schema
      - Sets up pgvector extension
      - Configures authentication database
    - **Native Path** (fallback):
      - Checks for existing PostgreSQL
      - Creates local database instance
      - Runs SQL setup scripts
    - Creates database launcher scripts

13. **Learning System** (`setup_learning_system`)
    - **Docker Path** (preferred):
      - Uses launch-learning-system.sh
      - Starts containerized learning services
      - Launches FastAPI learning server
      - Initializes ML models
    - **Native Path** (fallback):
      - Installs Python ML dependencies (sklearn, numpy, etc.)
      - Sets up PostgreSQL learning tables
      - Creates learning system launcher
    - **Components Started**:
      - PostgreSQL with learning schema
      - FastAPI server (if Docker)
      - ML model initialization
      - Learning analytics engine

14. **Tandem Orchestration** (`setup_tandem_orchestration`)
    - Sets up Python orchestration system
    - Creates tandem-orchestrator launcher
    - Initializes production_orchestrator.py
    - Sets up agent_registry.py
    - Configures execution modes

### Phase 4: Natural Language & Production
15. **Natural Invocation** (`setup_natural_invocation`)
    - Runs enable-natural-invocation.sh script
    - Sets up natural language agent invocation
    - Configures hooks.json for NLP patterns
    - Enables "invoke agent X" style commands

16. **Production Environment** (`setup_production_environment`)
    - Runs setup_production_env.sh if exists
    - Configures production settings
    - Sets up monitoring and logging
    - Initializes performance metrics

### Phase 5: Integration & Finalization
17. **Claude Wrapper** (`create_wrapper`)
    - Creates main claude wrapper script
    - Sets up permission bypass
    - Configures orchestration integration

18. **Sync Setup** (`setup_sync`)
    - Creates sync-agents.sh script
    - Configures agent synchronization

19. **GitHub Sync** (`setup_github_sync`)
    - References existing github-sync.sh
    - Sets up repository synchronization

20. **Environment Configuration** (`setup_environment`)
    - Updates shell RC files (.bashrc/.zshrc)
    - Sets environment variables
    - Adds aliases and functions

### Phase 6: Validation & Additional Tools
21. **Tests** (`run_tests`)
    - Runs system validation tests
    - Verifies component installation

22. **Agent Validation** (`validate_agents`)
    - Validates agent file integrity
    - Checks agent metadata

23. **Global Agents Bridge** (`install_global_agents_bridge`)
    - Installs claude-agent command
    - Enables direct agent invocation
    - Sets up bridge to 60+ agents

24. **Agent Registry Cron** (`setup_agent_registry_cron`)
    - Sets up automatic registry updates
    - Configures 5-minute update interval
    - Runs initial agent registration

## Components Launched During Installation

### Persistent Services
1. **PostgreSQL Database** (if Docker)
   - Port: 5433
   - Database: claude_auth
   - With pgvector extension
   - Learning system tables

2. **Learning System** (if Docker)
   - FastAPI server
   - ML model services
   - Learning analytics engine

### Scripts & Launchers Created
1. `claude` - Main CLI wrapper with orchestration
2. `claude-precision` - Precision style wrapper
3. `claude-learning-system` - Learning system controller
4. `claude-agent` - Global agents bridge
5. `tandem-orchestrator` - Python orchestration
6. `sync-agents.sh` - Agent synchronization
7. `python-orchestrator` - Direct orchestrator access

### Environment Modifications
1. PATH additions for local binaries
2. Shell aliases (coder, director, architect, security)
3. Environment variables for project paths
4. Docker group membership (if applicable)

## Quick Mode Installation (Minimal)

For quick mode, only these components are installed:
1. Prerequisites check
2. npm package installation
3. Agent installation
4. Hooks installation
5. Global CLAUDE.md
6. Claude directory setup
7. Agent registration
8. Wrapper creation
9. Environment setup

## Verification Commands

After installation, these commands verify components:
```bash
# Check overall status
claude --status

# Verify learning system
claude-learning-system status

# List available agents
claude --list-agents
claude-agent list

# Check natural invocation
claude invoke director "test"

# Verify database (if Docker)
docker ps | grep postgres

# Check orchestration
python-orchestrator status
```

## Important Notes

1. **Natural Invocation** requires enable-natural-invocation.sh in the project root
2. **Learning System** prefers Docker but falls back to native PostgreSQL
3. **Database** runs on port 5433 to avoid conflicts with existing PostgreSQL
4. **Agent Registry** auto-updates every 5 minutes via cron
5. **Orchestration** uses Python-first approach with C integration capability

## Troubleshooting

If components don't launch:
1. Check logs: `~/.claude_install.log`
2. Verify Docker: `docker --version && docker-compose --version`
3. Check Python: `python3 --version`
4. Verify PostgreSQL: `psql --version`
5. Review permissions: User must be in docker group for Docker features