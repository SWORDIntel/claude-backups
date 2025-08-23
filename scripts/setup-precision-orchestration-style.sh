#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# PRECISION ORCHESTRATION OUTPUT STYLE SETUP
# Version: 7.0.1 - Fixed for claude-code compatibility
# Description: Automated setup for claude-code precision orchestration style
# Repository: https://github.com/SWORDIntel/claude-backups
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration - FIXED PATHS FOR CLAUDE-CODE
readonly STYLE_NAME="precision-orchestration"  # Note: claude uses hyphen
readonly VERSION="7.0.1"

# Detect project root and use .claude directory if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == */scripts ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# Use project .claude if exists, otherwise use home directory
if [[ -d "$PROJECT_ROOT/.claude" ]]; then
    readonly CONFIG_DIR="${PROJECT_ROOT}/.claude/output-styles"
    readonly BACKUP_DIR="${PROJECT_ROOT}/.claude/backups"
else
    readonly CONFIG_DIR="${HOME}/.claude/output-styles"
    readonly BACKUP_DIR="${HOME}/.claude/backups"
fi

readonly CONFIG_FILE="${CONFIG_DIR}/${STYLE_NAME}.md"  # .md extension expected
readonly TEMP_FILE="/tmp/${STYLE_NAME}_${RANDOM}.yaml"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
header() { 
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Check if claude-code is available
check_claude() {
    if ! command -v claude-code &> /dev/null && ! command -v claude &> /dev/null; then
        warn "claude-code not found in PATH, but configuration will still be installed"
        echo -e "${YELLOW}You can activate the style later with: claude --output-style ${STYLE_NAME}${NC}"
    else
        log "claude-code detected"
    fi
}

# Backup existing configuration
backup_existing() {
    if [ -f "$CONFIG_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="${BACKUP_DIR}/${STYLE_NAME}_$(date +%Y%m%d_%H%M%S).md"
        cp "$CONFIG_FILE" "$backup_file"
        log "Backed up existing configuration to: $backup_file"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION CONTENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_configuration() {
    cat > "$TEMP_FILE" << 'EOF'
---
output_style: precision_orchestration
mode: ADAPTIVE_INTELLIGENT
version: 7.0.1
---

# Claude-Code Output Style Configuration v7.0
# Optimized for Complex Agent Architecture
# Status: PRODUCTION READY

output_style:
  name: "PRECISION_ORCHESTRATION"
  version: "7.0.1"
  mode: "ADAPTIVE_INTELLIGENT"
  
  # ============================================================================
  # CORE OUTPUT PARAMETERS
  # ============================================================================
  
  formatting:
    structure: "HIERARCHICAL_PROGRESSIVE"
    density: "HIGH_INFORMATION"
    verbosity: "QUANTIFIED_PRECISE"
    response_pattern: "DIRECT_ACTION_FIRST"
    
  technical_precision:
    commands: "EXACT_PARAMETERS"
    paths: "ABSOLUTE_REFERENCES"
    versions: "EXPLICIT_NUMBERS"
    metrics: "QUANTIFIED_ALWAYS"
    uncertainties: "CLEARLY_STATED"
    
  # ============================================================================
  # AGENT ORCHESTRATION DIRECTIVES
  # ============================================================================
  
  agent_invocation:
    default_mode: "INTELLIGENT"
    auto_invoke: true
    parallel_threshold: 3
    consensus_required: ["SECURITY", "DEPLOYER", "CSO"]
    
    patterns:
      multi_step: 
        agents: ["DIRECTOR", "PROJECTORCHESTRATOR"]
        mode: "TANDEM"
        
      security_critical:
        agents: ["CSO", "SECURITYAUDITOR", "CRYPTOEXPERT"]
        mode: "CONSENSUS"
        
      performance_optimization:
        agents: ["OPTIMIZER", "MONITOR", "LEADENGINEER"]
        mode: "PARALLEL"
        
      bug_fixing:
        agents: ["DEBUGGER", "PATCHER", "TESTBED"]
        mode: "PIPELINE"
        
      documentation:
        agents: ["DOCGEN", "RESEARCHER"]
        mode: "HYBRID"
        
  # ============================================================================
  # RESPONSE TEMPLATES
  # ============================================================================
  
  response_templates:
    
    status_report: |
      Current State: [SPECIFIC_DESCRIPTION]
      Progress: [X]% complete - [TASKS_COMPLETED]/[TOTAL_TASKS]
      Active Agents: [AGENT_LIST_WITH_STATUS]
      Next Action: [EXACT_COMMAND_WITH_PARAMETERS]
      Blockers: [IMPEDIMENTS_IF_ANY]
      Performance: [THROUGHPUT]msg/sec, [LATENCY]ms P99
      
    technical_solution: |
      SOLUTION:
      1. [EXACT_COMMAND --with-parameters]
         Expected Output: [SPECIFIC_RESULT]
         Verification: [TEST_COMMAND]
         Performance Impact: [METRIC_CHANGE]
      
      FALLBACK:
      - Primary: [ALTERNATIVE_COMMAND]
      - Recovery: [ROLLBACK_PROCEDURE]
      - Monitoring: [HEALTH_CHECK_COMMAND]
      
    error_handling: |
      ERROR DETECTION:
      - Symptom: [OBSERVABLE_BEHAVIOR]
      - Root Cause: [TECHNICAL_REASON]
      - Affected Components: [AGENT_LIST]
      
      RESOLUTION:
      1. [FIX_COMMAND]
      2. [VERIFICATION_STEP]
      3. [PREVENTIVE_MEASURE]
      
      Agent Assignment: [SPECIFIC_AGENT] via Task()
      
  # ============================================================================
  # DOCUMENTATION INTEGRATION
  # ============================================================================
  
  documentation:
    mode: "MILITARY_DOSSIER"
    classification: "CONTEXT_APPROPRIATE"
    structure: "BLUF_FIRST"
    
    components:
      header: |
        CLASSIFICATION: [LEVEL]
        DTG: [TIMESTAMP]
        OPERATION: [CODENAME]
        
      executive_summary: |
        BLUF: [ONE_LINE_SUMMARY]
        IMPACT: [QUANTIFIED_EFFECT]
        ACTION_REQUIRED: [SPECIFIC_TASK]
        
      technical_details: |
        SPECIFICATIONS:
        - Performance: [METRICS]
        - Resources: [REQUIREMENTS]
        - Dependencies: [AGENT_LIST]
        
  # ============================================================================
  # PERFORMANCE TRACKING
  # ============================================================================
  
  metrics:
    always_include:
      - execution_time_ms
      - agents_invoked_count
      - success_rate_percentage
      - resource_utilization
      - throughput_msg_per_sec
      
    thresholds:
      response_time: "<500ms"
      agent_coordination: "<1000ms"
      consensus_building: "<3000ms"
      pipeline_execution: "<5000ms"
      
  # ============================================================================
  # CONTEXT AWARENESS
  # ============================================================================
  
  context_handling:
    project_knowledge: "PRIORITIZE_ALWAYS"
    past_conversations: "REFERENCE_WHEN_RELEVANT"
    documentation_first: true
    verify_assumptions: true
    
    search_order:
      1: "project_knowledge_search"
      2: "conversation_search"
      3: "google_drive_search"
      4: "web_search"
      
  # ============================================================================
  # OUTPUT OPTIMIZATION
  # ============================================================================
  
  optimization:
    compression: "REMOVE_REDUNDANCY"
    batching: "GROUP_RELATED_TASKS"
    caching: "STORE_FREQUENT_PATTERNS"
    prefetch: "ANTICIPATE_NEXT_STEPS"
    
    agent_selection:
      strategy: "CAPABILITY_MATCHING"
      fallback: "DIRECTOR_ESCALATION"
      load_balance: true
      affinity: "MAINTAIN_CONTEXT"
      
  # ============================================================================
  # INTERACTION MODES
  # ============================================================================
  
  interaction:
    voice_enabled: true
    cli_shortcuts: true
    batch_mode: true
    interactive_mode: true
    
    command_formats:
      direct: "claude-agent [AGENT] '[TASK]'"
      task: "Task(subagent_type='[AGENT]', prompt='[TASK]')"
      voice: "Claude, ask [AGENT] to [TASK]"
      pipeline: "claude-dev-pipeline [FILE]"
      
  # ============================================================================
  # QUALITY GATES
  # ============================================================================
  
  quality_requirements:
    code_coverage: ">85%"
    test_passing: "100%"
    security_audit: "PASSED"
    documentation_complete: true
    performance_validated: true
    
    enforcement:
      pre_deployment: ["TESTBED", "SECURITY", "DOCGEN"]
      post_deployment: ["MONITOR", "OPTIMIZER"]
      continuous: ["LINTER", "PATCHER"]
      
  # ============================================================================
  # RUNTIME BEHAVIOR
  # ============================================================================
  
  runtime:
    auto_recovery: true
    graceful_degradation: true
    circuit_breaker: true
    retry_policy: "EXPONENTIAL_BACKOFF"
    timeout_ms: 30000
    
    fallback_chain:
      1: "C_LAYER_BINARY"
      2: "PYTHON_BRIDGE"
      3: "DIRECT_INVOCATION"
      4: "MANUAL_EXECUTION"
EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_configuration() {
    log "Installing configuration file..."
    
    # Create directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Copy configuration to claude's expected location
    cp "$TEMP_FILE" "$CONFIG_FILE"
    
    # Also create in alternative locations for compatibility
    for dir in \
        "$HOME/.config/claude-code/output-styles" \
        "$HOME/.config/claude/output-styles" \
        "$PROJECT_ROOT/.claude/config/output-styles" \
        "$PROJECT_ROOT/agents/config/output-styles"; do
        if [ -d "$(dirname "$dir")" ]; then
            mkdir -p "$dir" 2>/dev/null || true
            # Create both .md and .yaml versions
            cp "$TEMP_FILE" "${dir}/${STYLE_NAME}.md" 2>/dev/null || true
            cp "$TEMP_FILE" "${dir}/precision_orchestration.yaml" 2>/dev/null || true
        fi
    done
    
    success "Configuration installed to ${CONFIG_FILE}"
}

verify_installation() {
    log "Verifying installation..."
    
    # Check if file exists
    if [ -f "$CONFIG_FILE" ]; then
        success "Configuration file exists at: $CONFIG_FILE"
        
        # Check file size to ensure it's not empty
        local file_size=$(stat -f%z "$CONFIG_FILE" 2>/dev/null || stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 1000 ]; then
            success "Configuration file appears complete (${file_size} bytes)"
        else
            warn "Configuration file seems small (${file_size} bytes)"
        fi
    else
        error "Configuration file not found at expected location"
        return 1
    fi
    
    # Check for claude command
    if command -v claude &> /dev/null; then
        success "Claude command available"
        echo -e "${CYAN}Activate with: ${BOLD}claude --output-style ${STYLE_NAME}${NC}"
    elif command -v claude-code &> /dev/null; then
        success "Claude-code command available"
        echo -e "${CYAN}Activate with: ${BOLD}claude-code --output-style ${STYLE_NAME}${NC}"
    else
        warn "Claude command not found in PATH"
    fi
}

create_activation_script() {
    log "Creating activation helper..."
    
    local activate_script="$HOME/.local/bin/activate-precision-style"
    mkdir -p "$HOME/.local/bin"
    
    cat > "$activate_script" << EOF
#!/bin/bash
# Quick activation script for precision orchestration style
echo "Activating Precision Orchestration style..."
claude --output-style ${STYLE_NAME} "\$@"
EOF
    
    chmod +x "$activate_script"
    success "Created activation helper: $activate_script"
}

show_usage_instructions() {
    header "Installation Complete!"
    
    echo -e "${GREEN}The Precision Orchestration style has been successfully installed.${NC}\n"
    
    echo -e "${BOLD}Configuration Location:${NC}"
    echo -e "  ${BLUE}${CONFIG_FILE}${NC}\n"
    
    echo -e "${BOLD}To activate in claude-code:${NC}"
    echo -e "  ${CYAN}# Via command line:${NC}"
    echo -e "  ${BOLD}claude --output-style ${STYLE_NAME}${NC}\n"
    
    echo -e "  ${CYAN}# Or within claude-code:${NC}"
    echo -e "  ${BOLD}/output-style:set ${STYLE_NAME}${NC}\n"
    
    echo -e "${BOLD}Verify activation:${NC}"
    echo -e "  ${BOLD}/output-style:status${NC}\n"
    
    echo -e "${BOLD}Test the style:${NC}"
    echo -e "  ${BOLD}/task \"Coordinate DIRECTOR and ARCHITECT for system design\"${NC}\n"
    
    echo -e "${BOLD}Key Features Enabled:${NC}"
    echo -e "  ${GREEN}✓${NC} Quantified metrics (4.2M msg/sec tracking)"
    echo -e "  ${GREEN}✓${NC} Automatic agent orchestration"
    echo -e "  ${GREEN}✓${NC} Military-grade documentation (BLUF format)"
    echo -e "  ${GREEN}✓${NC} Performance tracking with P99 latency"
    echo -e "  ${GREEN}✓${NC} Multi-layer fallback system"
    echo -e "  ${GREEN}✓${NC} Intelligent agent selection"
    echo -e "  ${GREEN}✓${NC} Consensus building for critical operations\n"
    
    echo -e "${BOLD}Quick Tips:${NC}"
    echo -e "  • The style uses '${STYLE_NAME}' (with hyphen) as the identifier"
    echo -e "  • Configuration is in Markdown format with YAML content"
    echo -e "  • All agent invocations will show quantified metrics"
    echo -e "  • Responses follow military documentation standards\n"
    
    echo -e "${BOLD}Repository Integration:${NC}"
    echo -e "  Add to repo: ${BLUE}scripts/setup-precision-style.sh${NC}"
    echo -e "  Run after clone: ${BOLD}bash scripts/setup-precision-style.sh${NC}\n"
}

cleanup() {
    [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    header "Precision Orchestration Style Setup v${VERSION}"
    
    # Check prerequisites
    log "Checking environment..."
    check_claude
    
    # Backup existing configuration
    backup_existing
    
    # Create configuration
    log "Creating configuration..."
    create_configuration
    
    # Install configuration
    install_configuration
    
    # Verify installation
    verify_installation
    
    # Create activation helper
    create_activation_script
    
    # Show usage instructions
    show_usage_instructions
    
    success "Setup complete! Style ready for activation."
    return 0
}

# Handle command-line arguments
case "${1:-}" in
    --help|-h)
        echo "Precision Orchestration Style Setup v${VERSION}"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h       Show this help message"
        echo "  --verify         Verify existing installation"
        echo "  --reinstall      Force reinstallation"
        echo "  --uninstall      Remove the configuration"
        echo "  --test           Test if style is active"
        echo ""
        echo "This script installs the Precision Orchestration output style"
        echo "for claude-code, optimized for complex agent architectures."
        echo ""
        echo "Features:"
        echo "  • Quantified metrics in all responses"
        echo "  • Automatic agent orchestration"
        echo "  • Military-grade documentation"
        echo "  • Performance tracking (4.2M msg/sec)"
        echo "  • Multi-layer fallback systems"
        exit 0
        ;;
    --verify)
        header "Verifying Installation"
        verify_installation
        exit $?
        ;;
    --reinstall)
        header "Force Reinstalling"
        main
        exit $?
        ;;
    --uninstall)
        header "Uninstalling"
        rm -f "$CONFIG_FILE"
        rm -f "$HOME/.local/bin/activate-precision-style"
        success "Configuration removed"
        echo "Removed: $CONFIG_FILE"
        exit 0
        ;;
    --test)
        header "Testing Style"
        if [ -f "$CONFIG_FILE" ]; then
            success "Configuration file exists"
            echo -e "\nTest with: ${BOLD}claude --output-style ${STYLE_NAME} 'test task'${NC}"
        else
            error "Configuration not installed"
            echo "Run: $0"
        fi
        exit $?
        ;;
    *)
        main
        exit $?
        ;;
esac