#!/bin/bash
# Root Directory Organization Script
# Cleans up and organizes the project root directory

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🧹 Organizing Root Directory${NC}"
echo "================================"

# Create organized directory structure
echo -e "${BLUE}📁 Creating organized directories...${NC}"
mkdir -p bin tests utilities maintenance network-tools learning-setup archive

# Move main executables to bin/
echo -e "${BLUE}🚀 Moving main executables to bin/...${NC}"
mv launch_hybrid_system.sh bin/ 2>/dev/null || true
mv check_system_status.sh bin/ 2>/dev/null || true
mv claude-installer.sh bin/ 2>/dev/null || true
mv claude-wrapper-ultimate.sh bin/ 2>/dev/null || true
mv claude-wrapper-fixed.sh bin/ 2>/dev/null || true
mv integrate_hybrid_bridge.sh bin/ 2>/dev/null || true
mv bring-online bin/ 2>/dev/null || true
mv switch bin/ 2>/dev/null || true
mv status bin/ 2>/dev/null || true

# Move test scripts to tests/
echo -e "${BLUE}🧪 Moving test scripts to tests/...${NC}"
mv test_*.* tests/ 2>/dev/null || true
mv comprehensive_integration_test.py tests/ 2>/dev/null || true
mv validate_*.sh tests/ 2>/dev/null || true
mv verify-*.sh tests/ 2>/dev/null || true
mv quick_test.py tests/ 2>/dev/null || true

# Move utility scripts to utilities/
echo -e "${BLUE}🔧 Moving utility scripts to utilities/...${NC}"
mv standardize-agents.py utilities/ 2>/dev/null || true
mv create-complete-registry.py utilities/ 2>/dev/null || true
mv fix-agent-registration.py utilities/ 2>/dev/null || true
mv enable-natural-invocation.sh utilities/ 2>/dev/null || true
mv pdf-text-extractor-tui.py utilities/ 2>/dev/null || true

# Move maintenance scripts to maintenance/
echo -e "${BLUE}🛠️  Moving maintenance scripts to maintenance/...${NC}"
mv github-sync.sh maintenance/ 2>/dev/null || true
mv apply-bash-output-fix.sh maintenance/ 2>/dev/null || true
mv install-wrapper.sh maintenance/ 2>/dev/null || true
mv fix-bash-output.patch maintenance/ 2>/dev/null || true

# Move network tools to network-tools/
echo -e "${BLUE}🌐 Moving network tools to network-tools/...${NC}"
mv advanced-network-fix.sh network-tools/ 2>/dev/null || true
mv check-network-status.sh network-tools/ 2>/dev/null || true
mv fix-wired-connection.sh network-tools/ 2>/dev/null || true
mv switch-to-systemd-network.sh network-tools/ 2>/dev/null || true

# Move learning setup to learning-setup/
echo -e "${BLUE}🧠 Moving learning setup to learning-setup/...${NC}"
mv integrated_learning_setup.py learning-setup/ 2>/dev/null || true
mv learning_config_manager.py learning-setup/ 2>/dev/null || true

# Move documentation and archive files
echo -e "${BLUE}📚 Moving documentation files to archive/...${NC}"
mv *_SUMMARY.md archive/ 2>/dev/null || true
mv *_STATUS.md archive/ 2>/dev/null || true
mv *_GUIDE.md archive/ 2>/dev/null || true
mv files.txt archive/ 2>/dev/null || true
mv all_md_agents.txt archive/ 2>/dev/null || true
mv claude.md.txt archive/ 2>/dev/null || true

# Create symbolic links for frequently used commands in root
echo -e "${BLUE}🔗 Creating convenient symbolic links...${NC}"
ln -sf bin/launch_hybrid_system.sh launch 2>/dev/null || true
ln -sf bin/check_system_status.sh status-check 2>/dev/null || true
ln -sf bin/claude-installer.sh install 2>/dev/null || true

# Create a clean README for the organized structure
cat > ROOT_DIRECTORY_STRUCTURE.md << 'EOF'
# Root Directory Structure

## Main Directories

### `bin/` - Main Executables
- `launch_hybrid_system.sh` - System launcher
- `check_system_status.sh` - Status checker  
- `claude-installer.sh` - Main installer
- `integrate_hybrid_bridge.sh` - Integration script
- `bring-online` - System startup
- `switch` - Mode switcher
- `status` - System status

### `tests/` - Testing Scripts
- `comprehensive_integration_test.py` - Main test suite
- `test_*.py` - Various test scripts
- `validate_*.sh` - Validation scripts
- `verify-*.sh` - Verification scripts

### `utilities/` - Utility Scripts
- `standardize-agents.py` - Agent standardization
- `create-complete-registry.py` - Registry creation
- `fix-agent-registration.py` - Registration fixes
- `pdf-text-extractor-tui.py` - TUI PDF extractor

### `maintenance/` - Maintenance Scripts
- `github-sync.sh` - Git synchronization
- `apply-bash-output-fix.sh` - Output fixes
- `install-wrapper.sh` - Wrapper installation

### `network-tools/` - Network Utilities
- `advanced-network-fix.sh` - Network diagnostics
- `fix-wired-connection.sh` - Connection fixes
- `switch-to-systemd-network.sh` - Network switching

### `learning-setup/` - Learning System Setup
- `integrated_learning_setup.py` - Main setup script
- `learning_config_manager.py` - Configuration manager

### `archive/` - Documentation Archive
- Various documentation and summary files
- Historical files and references

## Quick Access (Symbolic Links)
- `./launch` → `bin/launch_hybrid_system.sh`
- `./status-check` → `bin/check_system_status.sh` 
- `./install` → `bin/claude-installer.sh`

## Core Project Files (Stay in Root)
- `CLAUDE.md` - Project documentation
- `README.md` - Main project README
- `docker-compose.yml` - Container configuration
- `requirements.txt` - Python dependencies
- `package.json` - Node.js dependencies
- `venv/` - Virtual environment
- `agents/` - Agent definitions
- `database/` - Database system
- `docs/` - Documentation
- `config/` - Configuration files

## Usage Examples
```bash
# Launch system
./launch

# Check status
./status-check

# Install system
./install

# Run tests
./tests/comprehensive_integration_test.py

# Network diagnostics
./network-tools/advanced-network-fix.sh
```

This organization provides:
- ✅ Clean root directory
- ✅ Logical grouping of scripts
- ✅ Easy access via symbolic links
- ✅ Clear separation of concerns
- ✅ Maintainable structure
EOF

echo
echo -e "${GREEN}✅ Root directory organization complete!${NC}"
echo
echo -e "${BLUE}📋 Summary:${NC}"
echo "  📁 bin/ - Main executables (8 files)"
echo "  🧪 tests/ - Test scripts" 
echo "  🔧 utilities/ - Utility scripts"
echo "  🛠️  maintenance/ - Maintenance scripts"
echo "  🌐 network-tools/ - Network utilities"
echo "  🧠 learning-setup/ - Learning system setup"
echo "  📚 archive/ - Documentation archive"
echo
echo -e "${BLUE}🔗 Quick access commands:${NC}"
echo "  ./launch - Launch hybrid system"
echo "  ./status-check - Check system status"  
echo "  ./install - Install system"
echo
echo -e "${GREEN}Root directory is now clean and organized!${NC}"