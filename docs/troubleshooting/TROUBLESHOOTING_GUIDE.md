# Claude Agent Framework - Troubleshooting Guide

## 🚨 Quick Fixes for Common Issues

### Issue: Command 'claude' not found
```bash
# Solution 1: Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Solution 2: Recreate symlink
ln -sf $CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x $CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh

# Solution 3: Use full path
$CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh --help
```

### Issue: No agents found / 0 agents detected
```bash
# Solution 1: Register agents manually
cd $CLAUDE_PROJECT_ROOT
claude --register-agents

# Solution 2: Check agents directory
ls -la agents/*.md | wc -l  # Should show 71

# Solution 3: Set agents directory explicitly
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"
claude --agents
```

### Issue: Permission denied errors
```bash
# Solution 1: Disable permission bypass
export CLAUDE_PERMISSION_BYPASS=false
claude --safe [command]

# Solution 2: Fix file permissions
chmod +x claude-wrapper-ultimate.sh
chmod +r agents/*.md

# Solution 3: Check directory permissions
ls -la ~/.local/bin/
ls -la ~/.cache/claude/
```

### Issue: Yoga.wasm error
```bash
# Solution 1: Auto-fix
claude --fix

# Solution 2: Set environment variable
export CLAUDE_NO_YOGA=1
export NODE_OPTIONS="--no-warnings"

# Solution 3: Reinstall Claude
npm uninstall -g @anthropic-ai/claude-code
npm cache clean --force
npm install -g @anthropic-ai/claude-code --force
```

## 🔍 Diagnostic Commands

### System Health Check
```bash
# Full system status
claude --status

# Check specific components
claude --status | grep -E "Binary|Agents|Registry|Venv"

# Debug mode status
CLAUDE_DEBUG=true claude --status
```

### Agent System Diagnostics
```bash
# List all agents
claude --agents

# Check agent count
find $CLAUDE_PROJECT_ROOT/agents -name "*.md" | wc -l

# Verify agent registry
cat ~/.cache/claude/registered_agents.json | python3 -m json.tool | head -20

# Test specific agent
claude --agent-info director
claude agent director "test"
```

### Path Verification
```bash
# Check all paths
echo "Project Root: ${CLAUDE_PROJECT_ROOT:-not set}"
echo "Agents Dir: ${CLAUDE_AGENTS_DIR:-not set}"
echo "Claude Home: ${CLAUDE_HOME:-not set}"
echo "Cache Dir: ${CLAUDE_CACHE_DIR:-not set}"

# Verify paths exist
for dir in "$CLAUDE_PROJECT_ROOT" "$CLAUDE_AGENTS_DIR" "$CLAUDE_HOME"; do
    [[ -d "$dir" ]] && echo "✓ $dir exists" || echo "✗ $dir missing"
done
```

## 🐛 Issue Categories

### 1. Installation Issues

#### Problem: Installer fails
```bash
# Check prerequisites
node --version  # Should be 14+
npm --version   # Should be installed
python3 --version  # Should be 3.8+

# Manual installation
cd $CLAUDE_PROJECT_ROOT
ln -sf $(pwd)/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x claude-wrapper-ultimate.sh
```

#### Problem: Symlink not working
```bash
# Check symlink
ls -la ~/.local/bin/claude

# Recreate with absolute path
rm ~/.local/bin/claude
ln -sf $CLAUDE_PROJECT_ROOT/claude-wrapper-ultimate.sh ~/.local/bin/claude

# Test symlink
~/.local/bin/claude --version
```

### 2. Agent Discovery Issues

#### Problem: Agents not auto-registering
```bash
# Force registration
claude --register-agents

# Check cache
rm -rf ~/.cache/claude/
claude --agents  # Will recreate cache

# Debug discovery
CLAUDE_DEBUG=true claude --register-agents 2>&1 | grep "Registering"
```

#### Problem: Wrong agents directory
```bash
# Check current directory
pwd

# Set correct directory
cd $CLAUDE_PROJECT_ROOT
export CLAUDE_PROJECT_ROOT=$(pwd)
export CLAUDE_AGENTS_DIR="$CLAUDE_PROJECT_ROOT/agents"

# Verify
claude --status | grep "Agents:"
```

### 3. Virtual Environment Issues

#### Problem: Venv not activating
```bash
# Check venv paths
ls -la ./venv/bin/activate
ls -la ./.venv/bin/activate
ls -la ../venv/bin/activate

# Set venv explicitly
export CLAUDE_VENV="/path/to/your/venv"

# Manual activation
source /path/to/your/venv/bin/activate
claude --status
```

#### Problem: Python packages missing
```bash
# Install in venv
source $CLAUDE_VENV/bin/activate
pip install -r requirements.txt

# Or create new venv
python3 -m venv ~/.local/share/claude/venv
source ~/.local/share/claude/venv/bin/activate
pip install psycopg2-binary pandas numpy scikit-learn
```

### 4. Database Issues

#### Problem: PostgreSQL connection failed
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Start PostgreSQL
sudo systemctl start postgresql

# Check configuration
cat config/database.json

# Test connection
psql -U claude -d claude_agents -c "SELECT version();"
```

#### Problem: pgvector extension missing
```bash
# Install pgvector
sudo apt-get install postgresql-15-pgvector  # Or your PostgreSQL version

# Enable extension
sudo -u postgres psql claude_agents -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### 5. Performance Issues

#### Problem: Slow agent discovery
```bash
# Check cache
ls -la ~/.cache/claude/registered_agents.json

# Clear and rebuild cache
rm -rf ~/.cache/claude/
time claude --register-agents

# Use cache directly
claude --agents  # Should be instant after first run
```

#### Problem: High memory usage
```bash
# Check memory
free -h
ps aux | grep claude

# Limit memory
export CLAUDE_MAX_MEMORY="1G"

# Clear cache
rm -rf ~/.cache/claude/
rm -rf /tmp/claude-*
```

### 6. Execution Issues

#### Problem: Bash commands not producing output
```bash
# Check bashrc for issues
grep -n "exec\|redirect" ~/.bashrc

# Test basic command
/bin/bash -c "echo test"

# Use explicit shell
SHELL=/bin/bash claude agent director "test"
```

#### Problem: Claude binary not found
```bash
# Check installation
which claude
npm list -g @anthropic-ai/claude-code

# Reinstall
npm install -g @anthropic-ai/claude-code

# Find claude binary
find / -name "claude" -type f 2>/dev/null | grep -E "bin|npm"
```

## 🛠️ Advanced Troubleshooting

### Enable Full Debug Mode
```bash
# Maximum verbosity
export CLAUDE_DEBUG=true
export CLAUDE_DEBUG_LEVEL=3
export CLAUDE_TRACE_ENABLED=true
export NODE_OPTIONS="--trace-warnings"

# Run with debug
claude --debug --status 2>&1 | tee debug.log
```

### Trace Execution Path
```bash
# Trace wrapper execution
bash -x claude-wrapper-ultimate.sh --status 2>&1 | head -50

# Trace Python orchestrator
python3 -m trace -t agents/src/python/production_orchestrator.py

# System call trace
strace -e trace=file claude --agents 2>&1 | grep -E "open|stat"
```

### Check File Integrity
```bash
# Verify wrapper
md5sum claude-wrapper-ultimate.sh
wc -l claude-wrapper-ultimate.sh  # Should be ~1100 lines

# Check agents
for agent in agents/*.md; do
    [[ -s "$agent" ]] || echo "Empty: $agent"
done

# Verify permissions
find . -type f -name "*.sh" ! -executable
find agents -type f -name "*.md" ! -readable
```

### Reset Everything
```bash
# Complete reset
unset $(env | grep CLAUDE | cut -d= -f1)
rm -rf ~/.cache/claude/
rm -f ~/.local/bin/claude
rm -f ~/.local/bin/claude-*

# Reinstall
cd $CLAUDE_PROJECT_ROOT
./claude-installer.sh --full

# Or manual
ln -sf $(pwd)/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x claude-wrapper-ultimate.sh
source ~/.bashrc
```

## 📊 Error Messages and Solutions

### "Cannot find module 'yoga.wasm'"
```bash
export CLAUDE_NO_YOGA=1
claude --fix
```

### "Permission denied"
```bash
chmod +x claude-wrapper-ultimate.sh
claude --safe [command]
```

### "No such file or directory"
```bash
cd $CLAUDE_PROJECT_ROOT
pwd  # Verify location
ls -la claude-wrapper-ultimate.sh
```

### "Agent not found"
```bash
claude --agents  # List available
claude --register-agents  # Refresh
claude --agent-info [name]  # Check specific
```

### "Database connection failed"
```bash
sudo systemctl restart postgresql
psql -U postgres -c "CREATE DATABASE claude_agents;"
psql -U postgres -c "CREATE USER claude WITH PASSWORD 'password';"
```

## 🔄 Recovery Procedures

### Complete System Recovery
```bash
#!/bin/bash
# Save as recover-claude.sh

echo "Claude System Recovery Script"
echo "=============================="

# 1. Set paths
export CLAUDE_ROOT="$CLAUDE_PROJECT_ROOT"
export PATH="$HOME/.local/bin:$PATH"

# 2. Clean old installation
echo "Cleaning old installation..."
rm -rf ~/.cache/claude/
rm -f ~/.local/bin/claude*

# 3. Reinstall wrapper
echo "Installing wrapper..."
cd "$CLAUDE_ROOT"
ln -sf $(pwd)/claude-wrapper-ultimate.sh ~/.local/bin/claude
chmod +x claude-wrapper-ultimate.sh

# 4. Register agents
echo "Registering agents..."
claude --register-agents

# 5. Verify
echo "Verifying installation..."
claude --status
claude --agents | head -5

echo "Recovery complete!"
```

### Database Recovery
```bash
#!/bin/bash
# Database recovery

# Backup existing
pg_dump claude_agents > backup_$(date +%Y%m%d).sql

# Reset database
sudo -u postgres dropdb claude_agents
sudo -u postgres createdb claude_agents

# Restore schema
psql -U postgres claude_agents < database/sql/auth_db_setup.sql

# Enable extensions
psql -U postgres claude_agents -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql -U postgres claude_agents -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## 📝 Logging and Monitoring

### Enable Logging
```bash
# Set log file
export CLAUDE_LOG_FILE="$HOME/claude.log"
export CLAUDE_LOG_LEVEL="DEBUG"

# Run with logging
claude --debug --status 2>&1 | tee -a $CLAUDE_LOG_FILE
```

### Monitor Performance
```bash
# Time operations
time claude --agents
time claude --register-agents

# Monitor resources
watch -n 1 'ps aux | grep claude'
htop  # Filter for claude processes
```

### Analyze Logs
```bash
# Check errors
grep -i error ~/claude.log

# Check warnings
grep -i warning ~/claude.log

# Agent invocations
grep "agent:" ~/claude.log
```

## 🆘 Getting Help

### Self-Help Resources
1. Run `claude --help` for command reference
2. Check `docs/` directory for documentation
3. Read CLAUDE.md for project context
4. Review agent files in `agents/` directory

### Debug Information to Provide
When reporting issues, include:
```bash
# System info
uname -a
node --version
npm --version
python3 --version

# Claude info
claude --status
env | grep CLAUDE
ls -la ~/.local/bin/claude
ls -la $CLAUDE_PROJECT_ROOT/

# Error messages
claude --debug [failing-command] 2>&1
```

### Common Success Indicators
- ✅ `claude --status` shows all green checkmarks
- ✅ `claude --agents` lists 71 agents
- ✅ `claude agent director "test"` responds
- ✅ Registry file exists at `~/.cache/claude/registered_agents.json`
- ✅ No errors in `claude --debug --status`

---

*Troubleshooting Guide v1.0*  
*Last Updated: 2025-08-25*  
*Framework Version: 7.0*  
*Wrapper Version: 13.1*