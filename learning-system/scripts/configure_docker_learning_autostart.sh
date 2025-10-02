#!/bin/bash
# Docker Learning System Auto-Start Configuration
# Configures automatic startup of the learning system

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}${CYAN}Docker Learning System Auto-Start Configuration${RESET}"
echo "============================================================"

# Configuration file path
CONFIG_DIR="$HOME/.config/claude"
CONFIG_FILE="$CONFIG_DIR/learning_config.json"
ENV_FILE="$CONFIG_DIR/.env"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create or update learning configuration
echo -e "${CYAN}Setting up learning system configuration...${RESET}"

cat > "$CONFIG_FILE" << 'EOF'
{
  "learning_system": {
    "enabled": true,
    "docker_auto_start": true,
    "database": {
      "host": "localhost",
      "port": 5433,
      "database": "claude_agents_auth",
      "user": "claude_agent"
    },
    "containers": {
      "postgres": {
        "image": "postgres:16",
        "container_name": "claude-postgres",
        "restart_policy": "unless-stopped",
        "auto_start": true
      },
      "learning": {
        "container_name": "claude-learning",
        "restart_policy": "unless-stopped",
        "auto_start": true
      }
    },
    "monitoring": {
      "health_checks": true,
      "performance_metrics": true,
      "auto_recovery": true
    }
  },
  "npu_acceleration": {
    "enabled": true,
    "openvino_version": "2025.3.0",
    "performance_target": 29000
  }
}
EOF

# Create environment file
echo -e "${CYAN}Creating environment configuration...${RESET}"

cat > "$ENV_FILE" << 'EOF'
# Claude Learning System Environment Configuration
LEARNING_DOCKER_AUTO_START=true
LEARNING_SYSTEM_ENABLED=true
CLAUDE_LEARNING_DB_HOST=localhost
CLAUDE_LEARNING_DB_PORT=5433
CLAUDE_LEARNING_DB_NAME=claude_agents_auth
CLAUDE_LEARNING_DB_USER=claude_agent

# NPU Acceleration
NPU_ACCELERATION_ENABLED=true
OPENVINO_VERSION=2025.3.0

# Docker Configuration
DOCKER_RESTART_POLICY=unless-stopped
DOCKER_AUTO_RECOVERY=true
EOF

# Create startup script
STARTUP_SCRIPT="$CONFIG_DIR/start_learning_system.sh"
echo -e "${CYAN}Creating learning system startup script...${RESET}"

cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash
# Claude Learning System Startup Script
# Automatically starts Docker learning containers

set -euo pipefail

# Load environment
if [[ -f "$HOME/.config/claude/.env" ]]; then
    source "$HOME/.config/claude/.env"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}🚀 Starting Claude Learning System...${RESET}"

# Check if auto-start is enabled
if [[ "${LEARNING_DOCKER_AUTO_START:-false}" != "true" ]]; then
    echo -e "${YELLOW}Learning system auto-start is disabled${RESET}"
    echo "Set LEARNING_DOCKER_AUTO_START=true in ~/.config/claude/.env to enable"
    exit 0
fi

# Check Docker access
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot access Docker daemon${RESET}"
    echo "Fix Docker permissions with: sudo usermod -aG docker \$USER"
    exit 1
fi

# Project root detection
PROJECT_ROOT=""
for possible_root in \
    "$HOME/claude-backups" \
    "$HOME/Documents/Claude" \
    "$(pwd)" \
    "$(dirname "$(readlink -f "$0")")/../.."; do

    if [[ -f "$possible_root/database/docker/docker-compose.yml" ]]; then
        PROJECT_ROOT="$possible_root"
        break
    fi
done

if [[ -z "$PROJECT_ROOT" ]]; then
    echo -e "${RED}❌ Could not find project root with database/docker/docker-compose.yml${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Found project root: $PROJECT_ROOT${RESET}"

# Start Docker containers
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/database/docker/docker-compose.yml"

if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    echo -e "${CYAN}Starting PostgreSQL learning database...${RESET}"

    cd "$PROJECT_ROOT/database"
    docker-compose -f docker/docker-compose.yml up -d postgres

    # Wait for database to be ready
    echo -e "${CYAN}Waiting for database to be ready...${RESET}"
    for i in {1..30}; do
        if docker exec claude-postgres pg_isready -U claude_agent >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Database is ready${RESET}"
            break
        fi
        sleep 1
    done

    # Check container status
    if docker ps | grep -q claude-postgres; then
        echo -e "${GREEN}✅ Learning database started successfully${RESET}"

        # Display connection info
        echo -e "${CYAN}Database connection:${RESET}"
        echo "  Host: localhost"
        echo "  Port: 5433"
        echo "  Database: claude_agents_auth"
        echo "  User: claude_agent"
    else
        echo -e "${RED}❌ Failed to start learning database${RESET}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Docker compose file not found: $DOCKER_COMPOSE_FILE${RESET}"
    echo "Learning system containers may need manual setup"
fi

echo -e "${GREEN}🎉 Learning system startup complete!${RESET}"
EOF

chmod +x "$STARTUP_SCRIPT"

# Create systemd user service for auto-start
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_DIR/claude-learning.service"

echo -e "${CYAN}Creating systemd user service...${RESET}"
mkdir -p "$SYSTEMD_DIR"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Claude Learning System
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=$STARTUP_SCRIPT
RemainAfterExit=yes
Environment=HOME=$HOME
Environment=USER=$USER

[Install]
WantedBy=default.target
EOF

# Enable and start the service
echo -e "${CYAN}Enabling systemd service...${RESET}"
systemctl --user daemon-reload
systemctl --user enable claude-learning.service

# Create shell integration
SHELL_INTEGRATION="$CONFIG_DIR/shell_integration.sh"
echo -e "${CYAN}Creating shell integration...${RESET}"

cat > "$SHELL_INTEGRATION" << 'EOF'
# Claude Learning System Shell Integration
# Add this to your ~/.bashrc or ~/.zshrc

# Auto-load Claude learning environment
if [[ -f "$HOME/.config/claude/.env" ]]; then
    source "$HOME/.config/claude/.env"
fi

# Alias for easy learning system management
alias claude-learning-start="$HOME/.config/claude/start_learning_system.sh"
alias claude-learning-status="docker ps | grep claude"
alias claude-learning-logs="docker logs claude-postgres"
alias claude-learning-connect="docker exec -it claude-postgres psql -U claude_agent -d claude_agents_auth"

# Function to check learning system health
claude-learning-health() {
    echo "🔍 Claude Learning System Health Check"
    echo "====================================="

    # Check Docker access
    if docker ps >/dev/null 2>&1; then
        echo "✅ Docker access: OK"
    else
        echo "❌ Docker access: FAILED"
        return 1
    fi

    # Check containers
    if docker ps | grep -q claude-postgres; then
        echo "✅ PostgreSQL container: RUNNING"

        # Check database connectivity
        if docker exec claude-postgres pg_isready -U claude_agent >/dev/null 2>&1; then
            echo "✅ Database connectivity: OK"
        else
            echo "❌ Database connectivity: FAILED"
        fi
    else
        echo "❌ PostgreSQL container: NOT RUNNING"
        echo "Start with: claude-learning-start"
    fi

    # Check environment
    if [[ "${LEARNING_DOCKER_AUTO_START:-false}" == "true" ]]; then
        echo "✅ Auto-start: ENABLED"
    else
        echo "⚠️  Auto-start: DISABLED"
        echo "Enable with: export LEARNING_DOCKER_AUTO_START=true"
    fi
}
EOF

# Summary
echo ""
echo -e "${BOLD}${GREEN}✅ Docker Learning System Auto-Start Configuration Complete!${RESET}"
echo ""
echo -e "${CYAN}Configuration files created:${RESET}"
echo "  • Learning config: $CONFIG_FILE"
echo "  • Environment: $ENV_FILE"
echo "  • Startup script: $STARTUP_SCRIPT"
echo "  • Systemd service: $SERVICE_FILE"
echo "  • Shell integration: $SHELL_INTEGRATION"
echo ""
echo -e "${CYAN}Next steps:${RESET}"
echo "  1. Fix Docker permissions (if needed):"
echo "     sudo usermod -aG docker \$USER"
echo "     newgrp docker"
echo ""
echo "  2. Start the learning system:"
echo "     $STARTUP_SCRIPT"
echo ""
echo "  3. Add shell integration to your ~/.bashrc or ~/.zshrc:"
echo "     echo 'source $SHELL_INTEGRATION' >> ~/.bashrc"
echo ""
echo "  4. The system will auto-start on login via systemd user service"
echo ""
echo -e "${GREEN}Learning system auto-start is now configured!${RESET}"