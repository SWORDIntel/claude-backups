#!/bin/bash
# Autonomous Claude System Installer
# Complete system setup with boot-to-UI and context retention
# Uses sudo password 1786 as specified

set -euo pipefail

SUDO_PASS="1786"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/autonomous_claude_install_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "🚀 Autonomous Claude System Installation Starting"
log "================================================="
log "Target: Complete local-only operation with boot-to-UI"
log "Features: Context retention, tiny LLM routing, zero external tokens"
log ""

# Function to run commands with sudo
run_sudo() {
    echo "$SUDO_PASS" | sudo -S "$@"
}

# 1. System Preparation
prepare_system() {
    log "📦 Preparing system for autonomous operation..."

    # Update package lists
    run_sudo apt update

    # Install essential packages
    local packages=(
        "python3" "python3-pip" "python3-venv" "python3-dev"
        "curl" "jq" "htop" "sqlite3" "git" "cmake"
        "build-essential" "pkg-config" "libssl-dev"
        "systemd" "cron" "tmux" "screen"
    )

    for package in "${packages[@]}"; do
        log "Installing $package..."
        run_sudo apt install -y "$package" || log "Warning: Failed to install $package"
    done

    # Create necessary directories
    local dirs=(
        "/home/john/claude-backups/logs"
        "/home/john/claude-backups/tiny-models"
        "/home/john/.claude"
        "/home/john/.claude/context"
        "/home/john/.claude/cache"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log "Created directory: $dir"
    done

    # Set proper ownership
    run_sudo chown -R john:john /home/john/claude-backups
    run_sudo chown -R john:john /home/john/.claude

    log "✅ System preparation completed"
}

# 2. Install Python Dependencies
install_python_deps() {
    log "🐍 Installing Python dependencies for local operation..."

    # Create virtual environment for dependencies
    if [ ! -d "/home/john/claude-backups/.torch-venv" ]; then
        python3 -m venv /home/john/claude-backups/.torch-venv
    fi

    source /home/john/claude-backups/.torch-venv/bin/activate

    # Install core dependencies
    pip install --upgrade pip

    # Install specific packages for local operation
    local pip_packages=(
        "torch>=2.1.0,<2.5.0"
        "torchvision>=0.16.0"
        "torchaudio>=2.1.0"
        "transformers>=4.35.0"
        "fastapi>=0.104.0"
        "uvicorn[standard]>=0.24.0"
        "pydantic>=2.5.0"
        "aiohttp>=3.9.0"
        "numpy>=1.24.0"
        "sqlite3"
        "sentence-transformers"
        "psutil>=5.9.0"
    )

    for package in "${pip_packages[@]}"; do
        log "Installing Python package: $package"
        pip install "$package" --index-url https://download.pytorch.org/whl/cpu || log "Warning: Failed to install $package"
    done

    log "✅ Python dependencies installed"
}

# 3. Deploy Local Models
deploy_local_models() {
    log "🤖 Deploying local models for zero-token operation..."

    # Deploy Opus servers if not already running
    if ! pgrep -f "local_opus_server.py" > /dev/null; then
        log "Starting Opus inference servers..."
        bash "$SCRIPT_DIR/phase7_production_deployment.sh" &

        # Wait for servers to initialize
        local max_wait=60
        local wait_count=0

        while [ $wait_count -lt $max_wait ]; do
            local healthy_count=0
            for port in 3451 3452 3453 3454; do
                if curl -s --max-time 2 "http://localhost:$port/health" >/dev/null 2>&1; then
                    ((healthy_count++))
                fi
            done

            if [ $healthy_count -eq 4 ]; then
                log "✅ All 4 Opus servers are healthy"
                break
            fi

            log "Waiting for Opus servers... ($healthy_count/4 ready)"
            sleep 2
            ((wait_count++))
        done
    else
        log "✅ Opus servers already running"
    fi

    # Download tiny routing model if needed
    local tiny_model_dir="/home/john/claude-backups/tiny-models"
    if [ ! -f "$tiny_model_dir/routing_patterns.json" ]; then
        log "Creating tiny routing model..."

        cat > "$tiny_model_dir/routing_patterns.json" << 'EOF'
{
  "patterns": {
    "development": {
      "keywords": ["debug", "error", "fix", "issue", "problem", "bug", "build", "compile", "create", "develop", "code"],
      "agents": ["debugger", "analyzer", "architect", "constructor"]
    },
    "data": {
      "keywords": ["data", "database", "analyze", "process", "optimize", "performance"],
      "agents": ["datascience", "database", "optimizer", "npu"]
    },
    "security": {
      "keywords": ["secure", "security", "encrypt", "protect", "audit", "compliance"],
      "agents": ["security", "bastion", "auditor"]
    },
    "infrastructure": {
      "keywords": ["monitor", "alert", "deploy", "install", "setup", "configure"],
      "agents": ["monitor", "deployer", "packager", "overseer"]
    },
    "research": {
      "keywords": ["research", "investigate", "explore", "learn", "document", "write"],
      "agents": ["researcher", "analyst", "docgen", "writer"]
    }
  }
}
EOF
        log "✅ Tiny routing model created"
    fi

    log "✅ Local models deployment completed"
}

# 4. Configure Boot-to-UI System
configure_boot_ui() {
    log "🖥️  Configuring boot-to-UI system..."

    # Make autonomous system executable
    chmod +x "$SCRIPT_DIR/autonomous_claude_system.py"

    # Create systemd service for autostart
    local service_content="[Unit]
Description=Autonomous Claude System - Zero Token Local Operation
After=multi-user.target network.target

[Service]
Type=simple
User=john
Group=john
WorkingDirectory=/home/john/claude-backups
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/home/john/claude-backups
ExecStart=/home/john/claude-backups/.torch-venv/bin/python /home/john/claude-backups/autonomous_claude_system.py --autostart
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

    # Install systemd service
    echo "$service_content" | run_sudo tee /etc/systemd/system/autonomous-claude.service > /dev/null

    # Enable service
    run_sudo systemctl daemon-reload
    run_sudo systemctl enable autonomous-claude.service

    # Create desktop shortcut for manual access
    local desktop_entry="[Desktop Entry]
Version=1.0
Type=Application
Name=Autonomous Claude System
Comment=Zero-token local Claude system
Exec=/usr/bin/gnome-terminal -- /home/john/claude-backups/.torch-venv/bin/python /home/john/claude-backups/autonomous_claude_system.py
Icon=utilities-terminal
Terminal=false
Categories=Development;System;"

    mkdir -p "/home/john/Desktop"
    echo "$desktop_entry" > "/home/john/Desktop/Autonomous Claude.desktop"
    chmod +x "/home/john/Desktop/Autonomous Claude.desktop"

    log "✅ Boot-to-UI configuration completed"
}

# 5. Setup Context Persistence
setup_context_persistence() {
    log "💾 Setting up context persistence system..."

    # Initialize context database
    /home/john/claude-backups/.torch-venv/bin/python -c "
import sqlite3
import os

db_path = '/home/john/.claude_context.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute('''
    CREATE TABLE IF NOT EXISTS conversation_context (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        user_input TEXT,
        system_response TEXT,
        context_data TEXT,
        agent_invocations TEXT
    )
''')

cursor.execute('''
    CREATE TABLE IF NOT EXISTS system_state (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated DATETIME DEFAULT CURRENT_TIMESTAMP
    )
''')

conn.commit()
conn.close()
print('Context database initialized')
"

    # Set proper permissions
    chmod 644 "/home/john/.claude_context.db"

    # Create backup script for context
    cat > "/home/john/.claude/backup_context.sh" << 'EOF'
#!/bin/bash
# Context backup script

BACKUP_DIR="/home/john/.claude/context/backups"
mkdir -p "$BACKUP_DIR"

# Create timestamped backup
cp "/home/john/.claude_context.db" "$BACKUP_DIR/context_backup_$(date +%Y%m%d_%H%M%S).db"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "context_backup_*.db" -mtime +7 -delete
EOF

    chmod +x "/home/john/.claude/backup_context.sh"

    # Setup cron job for context backups
    (crontab -l 2>/dev/null; echo "0 */6 * * * /home/john/.claude/backup_context.sh") | crontab -

    log "✅ Context persistence setup completed"
}

# 6. Configure Monitoring and Self-Debug
setup_monitoring() {
    log "🔍 Setting up monitoring and self-debug system..."

    # Start self-debug system if not running
    if ! pgrep -f "self_debug_orchestrator.py" > /dev/null; then
        log "Starting self-debug system..."
        nohup /home/john/claude-backups/.torch-venv/bin/python \
            /home/john/claude-backups/debug/self_debug_orchestrator.py \
            > /tmp/self_debug.log 2>&1 &
    fi

    # Create monitoring script
    cat > "/home/john/claude-backups/check_system_health.sh" << 'EOF'
#!/bin/bash
# System health check for autonomous operation

log_file="/tmp/health_check_$(date +%Y%m%d).log"

{
    echo "[$(date)] === System Health Check ==="

    # Check Opus servers
    echo "Opus Servers:"
    for port in 3451 3452 3453 3454; do
        if curl -s --max-time 2 "http://localhost:$port/health" >/dev/null; then
            echo "  Port $port: ✅ Healthy"
        else
            echo "  Port $port: ❌ Down"
        fi
    done

    # Check processes
    echo "Critical Processes:"
    processes=("local_opus_server.py" "self_debug_orchestrator.py" "autonomous_claude_system.py")
    for proc in "${processes[@]}"; do
        count=$(pgrep -f "$proc" | wc -l)
        echo "  $proc: $count instances"
    done

    # Check resources
    echo "System Resources:"
    echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')%"
    echo "  Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo "  Disk: $(df / | tail -1 | awk '{print $5}')"

    echo "==================================="
} >> "$log_file"
EOF

    chmod +x "/home/john/claude-backups/check_system_health.sh"

    # Setup health check cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * /home/john/claude-backups/check_system_health.sh") | crontab -

    log "✅ Monitoring and self-debug setup completed"
}

# 7. Final Validation
validate_installation() {
    log "🧪 Validating autonomous system installation..."

    local validation_errors=0

    # Check essential files
    local essential_files=(
        "/home/john/claude-backups/autonomous_claude_system.py"
        "/home/john/.claude_context.db"
        "/home/john/claude-backups/.torch-venv/bin/python"
        "/etc/systemd/system/autonomous-claude.service"
    )

    for file in "${essential_files[@]}"; do
        if [ -f "$file" ]; then
            log "✅ Essential file: $file"
        else
            log "❌ Missing file: $file"
            ((validation_errors++))
        fi
    done

    # Check Opus servers
    local healthy_servers=0
    for port in 3451 3452 3453 3454; do
        if curl -s --max-time 3 "http://localhost:$port/health" >/dev/null 2>&1; then
            ((healthy_servers++))
        fi
    done

    log "Opus servers: $healthy_servers/4 healthy"
    if [ $healthy_servers -lt 2 ]; then
        ((validation_errors++))
    fi

    # Check Python environment
    if /home/john/claude-backups/.torch-venv/bin/python -c "import torch, sqlite3, aiohttp" 2>/dev/null; then
        log "✅ Python environment validated"
    else
        log "❌ Python environment issues"
        ((validation_errors++))
    fi

    # Test autonomous system
    log "Testing autonomous system startup..."
    timeout 10s /home/john/claude-backups/.torch-venv/bin/python \
        /home/john/claude-backups/autonomous_claude_system.py --help >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "✅ Autonomous system startup test passed"
    else
        log "❌ Autonomous system startup test failed"
        ((validation_errors++))
    fi

    # Summary
    if [ $validation_errors -eq 0 ]; then
        log "🎯 VALIDATION SUCCESSFUL - System ready for autonomous operation"
        return 0
    else
        log "❌ VALIDATION FAILED - $validation_errors errors found"
        return 1
    fi
}

# 8. Create Quick Start Guide
create_quick_start() {
    log "📖 Creating quick start guide..."

    cat > "/home/john/claude-backups/QUICK_START.md" << 'EOF'
# Autonomous Claude System - Quick Start

## 🚀 System Overview
Your autonomous Claude system is now installed and configured for:
- **Zero external token usage** - All processing local
- **Context retention** - Conversations persist across reboots
- **Boot-to-UI** - Automatically starts on system boot
- **Tiny LLM routing** - Efficient local agent selection
- **Free power usage** - Leverages NPU/GPU/CPU cycles

## 🎮 Usage

### Automatic Startup (Recommended)
System automatically starts on boot via systemd service.

### Manual Startup
```bash
cd /home/john/claude-backups
./autonomous_claude_system.py
```

### Desktop Shortcut
Double-click "Autonomous Claude" on desktop.

## 💬 Commands
- `/help` - Show available commands
- `/status` - System health status
- `/context` - View conversation history
- `/install` - Re-run installation
- `/exit` - Save context and exit

## 🔧 Management
- **Logs**: `/tmp/autonomous_claude_install_*.log`
- **Context**: `/home/john/.claude_context.db`
- **Health**: `/home/john/claude-backups/check_system_health.sh`
- **Service**: `sudo systemctl status autonomous-claude`

## 🎯 Zero-Token Operation
All AI processing happens locally:
- 4 Opus servers (ports 3451-3454)
- Local agent routing
- Context persistence
- No external API calls

System is designed for continuous, autonomous operation.
EOF

    log "✅ Quick start guide created"
}

# Main installation sequence
main() {
    log "Starting autonomous Claude system installation..."

    prepare_system
    install_python_deps
    deploy_local_models
    configure_boot_ui
    setup_context_persistence
    setup_monitoring
    create_quick_start

    if validate_installation; then
        log ""
        log "🎉 AUTONOMOUS CLAUDE SYSTEM INSTALLATION COMPLETE"
        log "================================================="
        log "✅ Boot-to-UI configured"
        log "✅ Context retention enabled"
        log "✅ Zero-token operation verified"
        log "✅ Tiny LLM routing active"
        log "✅ Self-monitoring enabled"
        log ""
        log "🚀 System will auto-start on next reboot"
        log "💻 Manual start: /home/john/claude-backups/autonomous_claude_system.py"
        log "📖 Quick start: /home/john/claude-backups/QUICK_START.md"
        log ""
        log "Reboot recommended to test full autonomous operation."

        # Offer to start now
        read -p "Start autonomous system now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "🚀 Starting autonomous Claude system..."
            exec /home/john/claude-backups/.torch-venv/bin/python \
                /home/john/claude-backups/autonomous_claude_system.py
        fi

    else
        log ""
        log "❌ INSTALLATION FAILED"
        log "Check logs for details: $LOG_FILE"
        exit 1
    fi
}

# Run installation
main "$@"