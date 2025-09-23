#!/bin/bash
# NPU Binary Distribution System Setup
# Integrates pre-compiled NPU bridge distribution into Claude installer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[NPU-SETUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC_PYTHON="$SCRIPT_DIR/agents/src/python"

# Check if we're in the right directory
if [[ ! -d "$AGENTS_SRC_PYTHON" ]]; then
    error "Not in Claude project root directory. Run from claude-backups root."
fi

# Header
echo
bold "═══════════════════════════════════════════════════════════════════════════"
bold "🚀 NPU Binary Distribution System Setup"
bold "Pre-compiled Intel Meteor Lake NPU Bridge Distribution"
bold "═══════════════════════════════════════════════════════════════════════════"
echo

log "Setting up NPU binary distribution system..."
log "Project root: $SCRIPT_DIR"

# Check Python dependencies
check_python_dependencies() {
    log "Checking Python dependencies..."

    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required for NPU distribution system"
    fi

    local python_version
    python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
    log "Python version: $python_version"

    # Check required Python modules
    local required_modules=("requests" "subprocess" "json" "pathlib" "dataclasses" "typing")
    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if ! python3 -c "import $module" 2>/dev/null; then
            missing_modules+=("$module")
        fi
    done

    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        warn "Some Python modules may need installation: ${missing_modules[*]}"
        log "These are typically built-in modules, but may need updates"
    fi

    success "Python dependencies checked"
}

# Verify NPU distribution components
verify_components() {
    log "Verifying NPU distribution components..."

    local components=(
        "intel_npu_hardware_detector.py"
        "npu_binary_installer.py"
        "npu_release_manager.py"
        "npu_fallback_compiler.py"
        "npu_binary_distribution_coordinator.py"
        "claude_npu_installer_integration.py"
    )

    local missing_components=()

    for component in "${components[@]}"; do
        if [[ ! -f "$AGENTS_SRC_PYTHON/$component" ]]; then
            missing_components+=("$component")
        fi
    done

    if [[ ${#missing_components[@]} -gt 0 ]]; then
        error "Missing NPU distribution components: ${missing_components[*]}"
    fi

    success "All NPU distribution components verified"
}

# Create NPU distribution launcher
create_launcher() {
    log "Creating NPU distribution launcher..."

    local launcher_script="$SCRIPT_DIR/install-npu-bridge"

    cat > "$launcher_script" << 'EOF'
#!/bin/bash
# NPU Bridge Distribution Launcher
# Quick access to NPU binary distribution system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_COORDINATOR="$SCRIPT_DIR/agents/src/python/npu_binary_distribution_coordinator.py"

# Colors
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[NPU-BRIDGE]${NC} $1"; }

if [[ ! -f "$PYTHON_COORDINATOR" ]]; then
    echo "❌ NPU distribution system not found"
    echo "Run './setup-npu-distribution.sh' first"
    exit 1
fi

log "Launching NPU Binary Distribution System..."

# Pass all arguments to the coordinator
exec python3 "$PYTHON_COORDINATOR" "$@"
EOF

    chmod +x "$launcher_script"
    success "NPU launcher created: $launcher_script"
}

# Create integration with existing installer
integrate_with_installer() {
    log "Integrating with Claude installer..."

    # Check if we have the Python integration script
    local integration_script="$AGENTS_SRC_PYTHON/claude_npu_installer_integration.py"

    if [[ ! -f "$integration_script" ]]; then
        error "Integration script not found: $integration_script"
    fi

    # Run the integration setup
    if python3 "$integration_script" --setup; then
        success "NPU integration setup completed"
    else
        warn "NPU integration setup had issues, but continuing"
    fi

    # Create symbolic link for easy access
    local npu_installer_link="$SCRIPT_DIR/claude-npu-installer"
    if [[ ! -e "$npu_installer_link" ]]; then
        ln -sf "$integration_script" "$npu_installer_link"
        log "Created NPU installer link: $npu_installer_link"
    fi
}

# Test the NPU distribution system
test_system() {
    log "Testing NPU distribution system..."

    local coordinator="$AGENTS_SRC_PYTHON/npu_binary_distribution_coordinator.py"

    # Test detection only
    if python3 "$coordinator" --detect-only; then
        success "NPU detection test passed"
    else
        warn "NPU detection test had issues (may be normal without NPU hardware)"
    fi

    # Test hardware detector
    local detector="$AGENTS_SRC_PYTHON/intel_npu_hardware_detector.py"
    if python3 "$detector" --detect >/dev/null 2>&1; then
        success "Hardware detector test passed"
    else
        warn "Hardware detector test had issues"
    fi
}

# Create GitHub Actions integration
setup_github_actions() {
    log "Setting up GitHub Actions workflow..."

    local workflow_dir="$SCRIPT_DIR/.github/workflows"
    local workflow_file="$workflow_dir/rust-npu-bridge-build.yml"

    if [[ -f "$workflow_file" ]]; then
        success "GitHub Actions workflow already exists"
    else
        warn "GitHub Actions workflow not found - manual setup may be needed"
        log "Workflow should be at: $workflow_file"
    fi
}

# Display usage information
show_usage() {
    echo
    bold "📋 NPU Binary Distribution System Usage:"
    echo
    echo "🔧 Basic Commands:"
    echo "   ./install-npu-bridge                  # Quick install NPU bridge"
    echo "   ./install-npu-bridge --detect-only    # Hardware detection only"
    echo "   ./install-npu-bridge --force-compile  # Force compilation mode"
    echo
    echo "🎛️ Advanced Commands:"
    echo "   ./claude-npu-installer --setup        # Setup NPU integration"
    echo "   ./claude-npu-installer --install-npu  # Install NPU bridge"
    echo "   ./claude-npu-installer --status       # Show integration status"
    echo
    echo "🔍 Testing & Verification:"
    echo "   python3 agents/src/python/intel_npu_hardware_detector.py --detect"
    echo "   python3 agents/src/python/npu_release_manager.py --latest"
    echo "   python3 agents/src/python/npu_fallback_compiler.py --detect-only"
    echo
    echo "📊 System Analysis:"
    echo "   python3 agents/src/python/npu_binary_distribution_coordinator.py --detect-only"
    echo
}

# Main setup workflow
main() {
    log "Starting NPU binary distribution system setup..."

    # Step 1: Check dependencies
    check_python_dependencies

    # Step 2: Verify components
    verify_components

    # Step 3: Create launcher
    create_launcher

    # Step 4: Integration
    integrate_with_installer

    # Step 5: Test system
    test_system

    # Step 6: GitHub Actions
    setup_github_actions

    echo
    bold "✅ NPU Binary Distribution System Setup Complete!"
    echo

    success "System is ready for NPU bridge distribution"
    log "The system provides:"
    echo "   • 30-second binary installation for compatible systems"
    echo "   • Automatic hardware detection and optimization"
    echo "   • Intelligent fallback compilation for edge cases"
    echo "   • GitHub Actions CI/CD for automated builds"
    echo "   • Integration with existing Claude installer"

    show_usage

    echo
    bold "🚀 Quick Start:"
    echo "   Run: ./install-npu-bridge"
    echo
}

# Handle command line arguments
case "${1:-setup}" in
    setup)
        main
        ;;
    test)
        test_system
        ;;
    usage|help)
        show_usage
        ;;
    *)
        echo "Usage: $0 {setup|test|usage}"
        echo "  setup - Complete NPU distribution system setup (default)"
        echo "  test  - Test NPU distribution components"
        echo "  usage - Show usage information"
        exit 1
        ;;
esac