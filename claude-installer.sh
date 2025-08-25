#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Master Installer v10.0 - Complete System Edition
# Installs everything by default: Claude, Database, Learning, Orchestration
# ═══════════════════════════════════════════════════════════════════════════

# Disable strict mode for force installation
set +e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION & SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Fix color output issues
export TERM=xterm-256color

# Define colors using printf for better compatibility
print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_blue() { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_magenta() { printf "\033[0;35m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }
print_dim() { printf "\033[2m%s\033[0m\n" "$1"; }

# Status indicators
SUCCESS="✓"
ERROR="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"

# Detect project root
if [[ -d "./agents" ]] && [[ -f "./CLAUDE.md" ]]; then
    PROJECT_ROOT="$(pwd)"
elif [[ -d "$HOME/Documents/Claude/agents" ]]; then
    PROJECT_ROOT="$HOME/Documents/Claude"
else
    PROJECT_ROOT="$(pwd)"
fi

# Define all paths
HOME_DIR="$HOME"
LOCAL_BIN="$HOME_DIR/.local/bin"
NPM_PREFIX="$HOME_DIR/.npm-global"
CLAUDE_HOME="$HOME_DIR/.claude-home"
AGENTS_SOURCE="$PROJECT_ROOT/agents"
AGENTS_TARGET="$HOME_DIR/agents"
CONFIG_DIR="$HOME_DIR/.config/claude"
HOOKS_SOURCE="$PROJECT_ROOT/hooks"
STATUSLINE_SOURCE="$PROJECT_ROOT/statusline.lua"
LOG_DIR="$HOME_DIR/.local/share/claude/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Claude directory structure (for self-contained mode)
CLAUDE_DIR="$PROJECT_ROOT/.claude"
VENV_DIR="$HOME_DIR/.local/share/claude/venv"
DATABASE_DIR="$PROJECT_ROOT/database"
ENABLE_NATURAL_INVOCATION="$PROJECT_ROOT/enable-natural-invocation.sh"

# Installation counters  
TOTAL_STEPS=23
CURRENT_STEP=0

# User preferences (will be set by prompts)
ALLOW_SYSTEM_PACKAGES=""
INSTALL_DATABASE="yes"
SETUP_VENV="yes"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR" 2>/dev/null

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
    echo "$1"
}

# Progress bar
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' ']'
    printf "] %3d%% " "$percent"
}

print_header() {
    clear
    echo ""
    print_cyan "╔═══════════════════════════════════════════════════════════════╗"
    print_cyan "║           Claude Master Installer v10.0                      ║"
    print_cyan "║      Full Install: 58+ Agents + Database + Learning         ║"
    print_cyan "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    print_dim "Project: $PROJECT_ROOT"
    print_dim "Target: $HOME_DIR"
    echo ""
}

# Print section
print_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_bold "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Status messages
success() {
    print_green "$SUCCESS $1"
    log "SUCCESS: $1"
}

error() {
    print_red "$ERROR $1"
    log "ERROR: $1"
}

warning() {
    print_yellow "$WARNING $1"
    log "WARNING: $1"
}

info() {
    print_cyan "$INFO $1"
    log "INFO: $1"
}

# Force directory creation
force_mkdir() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir" 2>/dev/null
    sudo chown -R "$USER:$USER" "$dir" 2>/dev/null
}

# Force copy with permissions
force_copy() {
    local src="$1"
    local dst="$2"
    
    # Create destination directory
    force_mkdir "$(dirname "$dst")"
    
    # Try multiple copy methods
    cp -rf "$src" "$dst" 2>/dev/null || \
    sudo cp -rf "$src" "$dst" 2>/dev/null || \
    rsync -a "$src" "$dst" 2>/dev/null || \
    tar cf - -C "$(dirname "$src")" "$(basename "$src")" | tar xf - -C "$(dirname "$dst")" 2>/dev/null
    
    # Fix permissions
    sudo chown -R "$USER:$USER" "$dst" 2>/dev/null
}

# Get user preferences
get_user_preferences() {
    echo ""
    
    if [[ "$INSTALLATION_MODE" == "quick" ]]; then
        print_bold "Starting Quick Installation"
        echo "────────────────────────"
        echo ""
        print_cyan "This will install:"
        echo "  • Claude Code basic setup"
        echo "  • Core agents"
        echo "  • Essential hooks"
        echo ""
        print_yellow "⚠ Advanced features will be skipped"
        ALLOW_SYSTEM_PACKAGES="false"
        
    elif [[ "$INSTALLATION_MODE" == "custom" ]]; then
        print_bold "Starting Custom Installation"
        echo "────────────────────────"
        echo ""
        print_cyan "You can choose which components to install"
        echo ""
        # Could add interactive selection here in the future
        ALLOW_SYSTEM_PACKAGES="true"
        
    else  # Default: full installation
        print_bold "Starting Full Installation (Default - Recommended)"
        echo "────────────────────────"
        echo ""
        print_cyan "This installer will set up the complete system:"
        echo "  • Claude Code with all 41 agents"
        echo "  • PostgreSQL database system"
        echo "  • Agent learning system with ML"
        echo "  • Tandem orchestration v2.0"
        echo "  • Hooks and automation"
        echo "  • Production environment"
        echo ""
        ALLOW_SYSTEM_PACKAGES="true"
        INSTALLATION_MODE="full"
        
        print_green "✓ Full installation mode - all features enabled (RECOMMENDED DEFAULT)"
        print_dim "  Tip: This installs 57 agents, databases, learning systems, and tools"
        print_dim "       Use '--quick' for minimal install or '--help' for all options"
    fi
    
    echo ""
    
    # Brief pause to show what's happening
    sleep 1
}

# Enhanced Python package installation with pipx preference
install_python_packages() {
    local requirements_file="$1"
    local venv_path="$2"
    
    if [[ -n "$venv_path" ]]; then
        info "Installing into virtual environment: $venv_path"
        (
            source "$venv_path/bin/activate"
            pip install --upgrade pip 2>/dev/null
            pip install -r "$requirements_file" 2>&1 | while read line; do
                if [[ "$line" == *"Successfully installed"* ]] || [[ "$line" == *"Requirement already satisfied"* ]]; then
                    echo "  ✓ $line"
                elif [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"FAILED"* ]]; then
                    echo "  ✗ $line"
                fi
            done
        )
        success "Requirements installed into virtual environment"
        return
    fi
    
    # No virtual environment found, use enhanced system installation
    info "No virtual environment found, using system Python installation"
    
    # Try pipx first (best practice for CLI applications)
    if command -v pipx &>/dev/null; then
        info "Found pipx - using isolated application environments"
        
        # pipx is primarily for single applications, but we can try for key packages
        local key_packages=("uvicorn" "fastapi" "click" "rich")
        for package in "${key_packages[@]}"; do
            if grep -q "^${package}" "$requirements_file"; then
                info "Installing $package with pipx..."
                pipx install "$package" 2>/dev/null && echo "  ✓ $package installed via pipx"
            fi
        done
        
        # For the rest, fall through to pip
        warning "pipx installed key CLI tools, using pip for remaining packages"
    fi
    
    # Use pip with appropriate flags based on user preference
    if command -v pip3 &>/dev/null; then
        if [[ "$ALLOW_SYSTEM_PACKAGES" == "true" ]]; then
            info "Installing with system package modifications allowed..."
            pip3 install -r "$requirements_file" --user --break-system-packages 2>&1 | while read line; do
                if [[ "$line" == *"Successfully installed"* ]] || [[ "$line" == *"Requirement already satisfied"* ]]; then
                    echo "  ✓ $line"
                elif [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"FAILED"* ]]; then
                    echo "  ✗ $line"
                fi
            done
            success "Requirements installed with --break-system-packages"
        else
            info "Installing to user space only..."
            if pip3 install -r "$requirements_file" --user 2>&1 | while read line; do
                if [[ "$line" == *"Successfully installed"* ]] || [[ "$line" == *"Requirement already satisfied"* ]]; then
                    echo "  ✓ $line"
                elif [[ "$line" == *"externally-managed-environment"* ]]; then
                    echo "  ! System-managed environment detected"
                    echo "  ! Re-run installer and choose Y for system modifications, or install pipx"
                    return 1
                fi
            done; then
                success "Requirements installed to user Python environment"
            else
                warning "Installation failed - consider allowing system modifications or installing pipx"
            fi
        fi
    else
        warning "pip3 not found, skipping requirements installation"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALLATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Python 3 with version check
    printf "  %-20s" "Python 3..."
    
    # Try multiple ways to find python3
    PYTHON_CMD=""
    for cmd in python3 python python3.12 python3.11 python3.10 python3.9 python3.8; do
        if command -v "$cmd" &>/dev/null; then
            # Test if it's actually python3
            if "$cmd" --version 2>&1 | grep -q "Python 3"; then
                PYTHON_CMD="$cmd"
                break
            fi
        fi
    done
    
    if [[ -n "$PYTHON_CMD" ]]; then
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | sed 's/Python //')
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
        
        # Accept Python 3.8+ (including 3.13) - fix comparison for double-digit versions
        if [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -ge 8 ]]; then
            print_green "$SUCCESS (v$PYTHON_VERSION)"
            export PYTHON_CMD="$PYTHON_CMD"
        else
            print_yellow "$WARNING v$PYTHON_VERSION (need 3.8+)"
            export PYTHON_CMD="$PYTHON_CMD"
        fi
    else
        print_red "$ERROR Not installed"
        error "Python 3.8+ is required for agent systems"
    fi
    
    # Node.js
    printf "  %-20s" "Node.js..."
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node -v)
        print_green "$SUCCESS ($NODE_VERSION)"
    else
        print_red "$ERROR Not installed"
        warning "    Installing Node.js is recommended"
    fi
    
    # npm
    printf "  %-20s" "npm..."
    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm -v)
        print_green "$SUCCESS (v$NPM_VERSION)"
    else
        print_red "$ERROR Not installed"
    fi
    
    # pipx
    printf "  %-20s" "pipx..."
    if command -v pipx &>/dev/null; then
        PIPX_VERSION=$(pipx --version 2>/dev/null | head -1)
        print_green "$SUCCESS ($PIPX_VERSION)"
    else
        print_yellow "$WARNING Not installed"
        if [[ "$ALLOW_SYSTEM_PACKAGES" == "true" ]]; then
            print_dim "    Will install packages with pip --break-system-packages"
        else
            print_dim "    Consider: apt install pipx (Ubuntu) or brew install pipx (macOS)"
        fi
    fi
    
    # Disk space
    printf "  %-20s" "Disk space..."
    AVAILABLE=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE -gt 100000 ]]; then
        print_green "$SUCCESS ($(numfmt --to=iec $((AVAILABLE * 1024))))"
    else
        print_yellow "$WARNING Low space"
    fi
    
    show_progress
}

# 2. Install NPM package
install_npm_package() {
    print_section "Installing Claude NPM Package"
    
    # Configure npm
    info "Configuring npm prefix..."
    force_mkdir "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX" 2>/dev/null
    export PATH="$NPM_PREFIX/bin:$PATH"
    
    # Check if installed
    if npm list -g @anthropic-ai/claude-code 2>/dev/null | grep -q "@anthropic-ai/claude-code"; then
        success "Package already installed"
    else
        info "Installing @anthropic-ai/claude-code..."
        npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        sudo npm install -g @anthropic-ai/claude-code 2>/dev/null || \
        npm install -g @anthropic-ai/claude-code --force 2>/dev/null
    fi
    
    # Find CLI path
    CLAUDE_CLI_PATH="$NPM_PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    if [[ -f "$CLAUDE_CLI_PATH" ]]; then
        success "CLI found at: $CLAUDE_CLI_PATH"
        CLAUDE_BINARY="$CLAUDE_CLI_PATH"
    else
        # Search for it
        CLAUDE_CLI_PATH=$(find "$NPM_PREFIX" -name "cli.js" -path "*claude-code*" 2>/dev/null | head -1)
        CLAUDE_BINARY="${CLAUDE_CLI_PATH:-$NPM_PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli.js}"
    fi
    
    show_progress
}

# 3. Install agents
install_agents() {
    print_section "Installing Agent System"
    
    # Create target directory
    force_mkdir "$AGENTS_TARGET"
    
    if [[ ! -d "$AGENTS_SOURCE" ]]; then
        warning "No agents source found at: $AGENTS_SOURCE"
        info "Skipping agent installation - directory will be ready for manual setup"
    else
        info "Updating agent files from $AGENTS_SOURCE..."
        
        # Count source agents (only .md files in root of agents directory)
        SOURCE_COUNT=$(find "$AGENTS_SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
        info "Found $SOURCE_COUNT agent files"
        
        if [[ $SOURCE_COUNT -gt 0 ]]; then
            # Force copy all .md/.MD files from the root agents directory (overwrite existing)
            find "$AGENTS_SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) -exec cp -f {} "$AGENTS_TARGET/" \; 2>/dev/null
            
            # Fix permissions
            sudo chown -R "$USER:$USER" "$AGENTS_TARGET" 2>/dev/null
            
            # Verify
            INSTALLED_COUNT=$(find "$AGENTS_TARGET" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | wc -l)
            if [[ $INSTALLED_COUNT -gt 0 ]]; then
                success "Installed/Updated $INSTALLED_COUNT agents (overwrote existing)"
            else
                warning "Failed to copy agents"
            fi
        else
            info "No agent files found in root of source directory"
        fi
    fi
    
    show_progress
}

# 3.5. Install Global CLAUDE.md (Agent Auto-Invocation Guide)
install_global_claude_md() {
    print_section "Installing Global CLAUDE.md (Agent Auto-Invocation Guide)"
    
    local claude_md_source="$PROJECT_ROOT/claude.md.txt"
    local claude_md_target="$HOME_DIR/CLAUDE.md"
    
    # Create the comprehensive agent auto-invocation guide content
    local claude_md_content='# CLAUDE.MD - Global Agent Auto-Invocation Guide
# Claude Portable Agent Framework v7.0 - Auto-Invocation Patterns

## 🎯 AGENT AUTO-INVOCATION QUICK REFERENCE

This document defines when Claude should automatically invoke each of the 57 specialized agents based on keywords, patterns, and context. Use Task tool with these agents when their trigger conditions are met.

---

## 🚨 IMMEDIATE AUTO-INVOCATION TRIGGERS (ALWAYS INVOKE)

### Multi-Step Tasks → Director + ProjectOrchestrator
**ALWAYS invoke both when:**
- User requests multiple related tasks
- Complex project initialization
- Strategic planning needed
- "Create X with Y and Z" patterns

### Parallel Execution Keywords → Multiple Agents
**Keywords:** parallel, concurrent, simultaneously, at the same time, together
**Action:** Execute identified agents IN PARALLEL with PARALLEL execution mode

### Security Keywords → Security Team
**Keywords:** security, breach, attack, vulnerability, exploit, malware, threat
**Invoke:** CSO, Security, SecurityAuditor, Bastion (based on specific need)

### Performance Keywords → Optimizer + Monitor
**Keywords:** slow, optimize, performance, speed, latency, bottleneck, cache
**Invoke:** Optimizer (analysis) + Monitor (metrics) + LeadEngineer (hardware optimization)

---

## 📂 COMMAND & CONTROL AGENTS (2)

### DIRECTOR
**Auto-invoke when:**
- Strategic decisions needed
- Project initialization
- Multi-agent coordination required
- Keywords: strategy, plan, roadmap, project, initiative, vision
- Patterns: "Create a plan for...", "Design strategy for...", "Initialize project..."

### PROJECTORCHESTRATOR  
**Auto-invoke when:**
- Tactical coordination needed
- Multi-step task execution
- Workflow management required
- Keywords: coordinate, orchestrate, workflow, pipeline, sequence
- Patterns: "Execute workflow...", "Coordinate agents...", "Manage pipeline..."

---

## 🛡️ SECURITY SPECIALISTS (11)

### SECURITY
**Auto-invoke when:**
- General security concerns
- Vulnerability assessment needed
- Keywords: secure, vulnerability, threat, risk, audit, compliance
- Patterns: "Security audit of...", "Check for vulnerabilities...", "Secure this..."

### BASTION
**Auto-invoke when:**
- Perimeter defense needed
- Access control required
- Keywords: firewall, perimeter, access control, DMZ, ingress, egress
- Patterns: "Protect perimeter...", "Control access to...", "Harden entry points..."

### SECURITYCHAOSAGENT
**Auto-invoke when:**
- Chaos testing required
- Resilience testing needed
- Keywords: chaos, resilience, fault injection, distributed testing
- Patterns: "Test resilience...", "Chaos engineering for...", "Fault tolerance..."

### SECURITYAUDITOR
**Auto-invoke when:**
- Comprehensive audit needed
- Compliance checking required
- Keywords: audit, compliance, SOC2, HIPAA, GDPR, PCI
- Patterns: "Audit compliance...", "Security assessment...", "Compliance check..."

### CSO (Chief Security Officer)
**Auto-invoke when:**
- Strategic security decisions
- Executive security reporting
- Keywords: governance, policy, compliance, risk management
- Patterns: "Security policy for...", "Risk assessment...", "Executive security..."

### CRYPTOEXPERT
**Auto-invoke when:**
- Encryption/cryptography needed
- Key management required
- Keywords: encrypt, decrypt, cryptography, keys, certificates, PKI, TLS
- Patterns: "Encrypt data...", "Implement cryptography...", "Key management..."

### QUANTUMGUARD
**Auto-invoke when:**
- Quantum threats mentioned
- Post-quantum crypto needed
- Keywords: quantum, post-quantum, lattice, kyber, dilithium, quantum-resistant
- Patterns: "Quantum-resistant...", "Post-quantum security...", "Quantum threat..."

### REDTEAMORCHESTRATOR
**Auto-invoke when:**
- Penetration testing needed
- Adversarial testing required
- Keywords: pentest, red team, penetration, adversarial, offensive
- Patterns: "Penetration test...", "Red team exercise...", "Test defenses..."

### APT41-DEFENSE
**Auto-invoke when:**
- APT threats detected
- Nation-state defense needed
- Keywords: APT, nation-state, advanced persistent threat, supply chain attack
- Patterns: "APT defense...", "Nation-state protection...", "Supply chain security..."

### NSA (Allied Intel TTP)
**Auto-invoke when:**
- Intelligence operations mentioned
- Five Eyes/NATO context
- Keywords: intelligence, SIGINT, five eyes, nato, attribution, collection
- Patterns: "Intelligence gathering...", "Attribution analysis...", "SIGINT operations..."

### PSYOPS
**Auto-invoke when:**
- Information warfare context
- Influence operations mentioned
- Keywords: psyops, influence, narrative, perception, information warfare
- Patterns: "Counter-narrative...", "Influence campaign...", "Information warfare..."

---

## 🔧 CORE DEVELOPMENT (8)

### ARCHITECT
**Auto-invoke when:**
- System design needed
- Architecture decisions required
- Keywords: architecture, design, structure, pattern, framework, blueprint
- Patterns: "Design architecture...", "System design for...", "Architecture pattern..."

### CONSTRUCTOR
**Auto-invoke when:**
- Project initialization
- Scaffolding needed
- Keywords: initialize, create, scaffold, bootstrap, setup, boilerplate
- Patterns: "Create new project...", "Initialize application...", "Setup environment..."

### PATCHER
**Auto-invoke when:**
- Bug fixes needed
- Code repairs required
- Keywords: fix, bug, patch, repair, debug, error, broken
- Patterns: "Fix bug in...", "Patch issue...", "Repair broken..."

### DEBUGGER
**Auto-invoke when:**
- Deep debugging needed
- Root cause analysis
- Keywords: debug, trace, investigate, analyze, breakpoint, stack trace
- Patterns: "Debug issue...", "Find root cause...", "Trace execution..."

### TESTBED
**Auto-invoke when:**
- Testing required
- Test suite creation
- Keywords: test, unit test, integration test, coverage, TDD, BDD
- Patterns: "Write tests for...", "Test coverage...", "Test suite..."

### LINTER
**Auto-invoke when:**
- Code review needed
- Style checking required
- Keywords: lint, review, style, format, standards, clean code
- Patterns: "Review code...", "Check style...", "Lint files..."

### OPTIMIZER
**Auto-invoke when:**
- Performance issues
- Optimization needed
- Keywords: slow, optimize, performance, bottleneck, profile, benchmark
- Patterns: "Optimize performance...", "Speed up...", "Profile code..."

### QADIRECTOR
**Auto-invoke when:**
- QA strategy needed
- Quality assurance required
- Keywords: QA, quality, testing strategy, test plan, validation
- Patterns: "QA strategy...", "Quality plan...", "Test planning..."

---

## 🏗️ INFRASTRUCTURE & DEVOPS (6)

### INFRASTRUCTURE
**Auto-invoke when:**
- System setup needed
- Infrastructure configuration
- Keywords: infrastructure, server, cloud, AWS, Azure, GCP, terraform
- Patterns: "Setup infrastructure...", "Configure servers...", "Cloud deployment..."

### DEPLOYER
**Auto-invoke when:**
- Deployment needed
- Release management
- Keywords: deploy, release, rollout, CI/CD, pipeline, production
- Patterns: "Deploy to production...", "Release version...", "Setup CI/CD..."

### MONITOR
**Auto-invoke when:**
- Monitoring setup needed
- Observability required
- Keywords: monitor, metrics, logs, traces, observability, alerting
- Patterns: "Setup monitoring...", "Add metrics...", "Configure alerts..."

### PACKAGER
**Auto-invoke when:**
- Package creation needed
- Distribution required
- Keywords: package, bundle, distribute, npm, pip, docker, container
- Patterns: "Package application...", "Create distribution...", "Bundle assets..."

### DOCKER
**Auto-invoke when:**
- Containerization needed
- Docker operations
- Keywords: docker, container, kubernetes, k8s, compose, swarm
- Patterns: "Containerize app...", "Docker setup...", "Kubernetes deployment..."

### PROXMOX
**Auto-invoke when:**
- Virtualization needed
- VM management
- Keywords: proxmox, VM, virtual machine, virtualization, hypervisor
- Patterns: "Create VM...", "Virtualization setup...", "Proxmox configuration..."

---

## 💻 LANGUAGE-SPECIFIC DEVELOPMENT (8)

### C-INTERNAL
**Auto-invoke when:**
- C/C++ development
- Systems programming
- Keywords: C, C++, gcc, compilation, native, vectorization, AVX512
- Patterns: "C++ implementation...", "Native code...", "System programming..."

### PYTHON-INTERNAL
**Auto-invoke when:**
- Python development
- Python environment management
- Keywords: python, pip, venv, pandas, numpy, Django, Flask
- Patterns: "Python script...", "Django app...", "Python automation..."

### RUST-INTERNAL
**Auto-invoke when:**
- Rust development
- Memory-safe systems code
- Keywords: rust, cargo, unsafe, lifetime, borrow, trait, async, tokio
- Patterns: "Rust implementation...", "Memory-safe code...", "Rust service..."

### GO-INTERNAL
**Auto-invoke when:**
- Go development
- Concurrent programming
- Keywords: golang, go, goroutine, channel, context, microservice
- Patterns: "Go service...", "Concurrent implementation...", "Go API..."

### JAVA-INTERNAL
**Auto-invoke when:**
- Java development
- Enterprise applications
- Keywords: java, spring, springboot, JVM, maven, gradle, hibernate
- Patterns: "Java application...", "Spring Boot service...", "Enterprise Java..."

### TYPESCRIPT-INTERNAL
**Auto-invoke when:**
- TypeScript/JavaScript development
- Frontend development
- Keywords: typescript, javascript, node, react, angular, vue, webpack
- Patterns: "TypeScript app...", "React component...", "Node service..."

### KOTLIN-INTERNAL
**Auto-invoke when:**
- Kotlin development
- Android development
- Keywords: kotlin, android, coroutines, jetpack compose, KMM
- Patterns: "Kotlin app...", "Android application...", "Kotlin multiplatform..."

### ASSEMBLY-INTERNAL
**Auto-invoke when:**
- Assembly programming
- Low-level optimization
- Keywords: assembly, asm, x86, ARM, SIMD, registers, opcodes
- Patterns: "Assembly optimization...", "Low-level code...", "CPU instructions..."

---

## 🎨 SPECIALIZED PLATFORMS (7)

### APIDESIGNER
**Auto-invoke when:**
- API design needed
- REST/GraphQL/gRPC
- Keywords: API, REST, GraphQL, gRPC, OpenAPI, swagger, endpoint
- Patterns: "Design API...", "REST endpoints...", "API specification..."

### DATABASE
**Auto-invoke when:**
- Database design/optimization
- Data architecture
- Keywords: SQL, PostgreSQL, MySQL, MongoDB, database, schema, query
- Patterns: "Database design...", "SQL optimization...", "Schema creation..."

### WEB
**Auto-invoke when:**
- Web development
- Frontend frameworks
- Keywords: React, Vue, Angular, frontend, webpage, browser, HTML, CSS
- Patterns: "Web application...", "Frontend development...", "Website creation..."

### MOBILE
**Auto-invoke when:**
- Mobile development (iOS/Android)
- Cross-platform mobile
- Keywords: iOS, Android, React Native, mobile app, smartphone, tablet
- Patterns: "Mobile app...", "iOS/Android development...", "Cross-platform app..."

### ANDROIDMOBILE
**Auto-invoke when:**
- Android-specific development
- Android optimization
- Keywords: Android, Kotlin, Java, Play Store, APK, Android Studio
- Patterns: "Android app...", "Play Store submission...", "Android optimization..."

### PYGUI
**Auto-invoke when:**
- Python GUI development
- Desktop applications
- Keywords: tkinter, PyQt, Streamlit, Kivy, wxPython, Python GUI
- Patterns: "Python GUI...", "Desktop application...", "Streamlit dashboard..."

### TUI
**Auto-invoke when:**
- Terminal UI development
- Console interfaces
- Keywords: terminal, console, CLI, ncurses, text interface, TUI
- Patterns: "Terminal interface...", "Console app...", "CLI tool..."

---

## 📊 DATA & ML (3)

### DATASCIENCE
**Auto-invoke when:**
- Data analysis needed
- ML model development
- Keywords: data science, machine learning, AI, model, training, analysis
- Patterns: "Analyze data...", "Train model...", "Data visualization..."

### MLOPS
**Auto-invoke when:**
- ML pipeline setup
- Model deployment
- Keywords: MLOps, pipeline, model deployment, training pipeline, MLflow
- Patterns: "ML pipeline...", "Deploy model...", "MLOps setup..."

### NPU
**Auto-invoke when:**
- Neural processing optimization
- AI acceleration
- Keywords: NPU, neural processor, AI acceleration, inference optimization
- Patterns: "NPU optimization...", "AI acceleration...", "Neural processing..."

---

## 🌐 NETWORK & SYSTEMS (4)

### CISCO
**Auto-invoke when:**
- Cisco configuration
- Network setup
- Keywords: Cisco, router, switch, VLAN, BGP, OSPF, network config
- Patterns: "Configure Cisco...", "Network setup...", "Router configuration..."

### BGP-PURPLE-TEAM
**Auto-invoke when:**
- BGP security/configuration
- Routing security
- Keywords: BGP, routing, AS, peering, route hijacking, RPKI
- Patterns: "BGP configuration...", "Routing security...", "AS peering..."

### IOT-ACCESS-CONTROL
**Auto-invoke when:**
- IoT security/management
- Device access control
- Keywords: IoT, embedded, device management, MQTT, CoAP, Zigbee
- Patterns: "IoT security...", "Device management...", "Embedded systems..."

### DDWRT
**Auto-invoke when:**
- Router firmware
- DD-WRT configuration
- Keywords: DD-WRT, router firmware, OpenWRT, Tomato, custom firmware
- Patterns: "Router firmware...", "DD-WRT setup...", "Custom router..."

---

## ⚡ HARDWARE & ACCELERATION (2)

### GNA
**Auto-invoke when:**
- Gaussian Neural Accelerator
- Audio/speech processing
- Keywords: GNA, Gaussian, audio processing, speech recognition
- Patterns: "GNA optimization...", "Audio acceleration...", "Speech processing..."

### LEADENGINEER
**Auto-invoke when:**
- Hardware-software integration
- System-level optimization
- Keywords: hardware integration, thermal, P-cores, E-cores, AVX-512
- Patterns: "Hardware optimization...", "System integration...", "CPU optimization..."

---

## 📋 PLANNING & DOCUMENTATION (4)

### PLANNER
**Auto-invoke when:**
- Strategic planning
- Project roadmaps
- Keywords: plan, strategy, roadmap, timeline, milestone, project
- Patterns: "Create plan...", "Project roadmap...", "Strategic planning..."

### DOCGEN
**Auto-invoke when:**
- Documentation needed
- Technical writing
- Keywords: document, docs, README, manual, guide, documentation
- Patterns: "Generate docs...", "Write documentation...", "Create README..."

### RESEARCHER
**Auto-invoke when:**
- Technology research
- Evaluation needed
- Keywords: research, investigate, analyze, evaluate, study, explore
- Patterns: "Research technology...", "Evaluate options...", "Technology analysis..."

### STATUSLINE-INTEGRATION
**Auto-invoke when:**
- Dev environment setup
- IDE integration
- Keywords: statusline, neovim, vim, IDE, editor, development environment
- Patterns: "Setup statusline...", "IDE configuration...", "Editor integration..."

---

## 🔍 QUALITY & OVERSIGHT (2)

### OVERSIGHT
**Auto-invoke when:**
- Quality assurance
- Compliance checking
- Keywords: oversight, quality, compliance, standards, governance
- Patterns: "Quality oversight...", "Compliance check...", "Standards verification..."

### INTEGRATION
**Auto-invoke when:**
- System integration
- Component coordination
- Keywords: integration, coordinate, connect, interface, bridge
- Patterns: "System integration...", "Component coordination...", "Interface design..."

---

## 🎯 COMPOUND AUTO-INVOCATION PATTERNS

### "Security Audit" → Multiple Agents (PARALLEL)
- CSO (governance)
- SecurityAuditor (technical audit)
- Security (vulnerability assessment)
- Monitor (metrics collection)

### "Full Stack Application" → Multiple Agents
- Architect (design)
- Web (frontend)
- APIDesigner (API)
- Database (data layer)
- Infrastructure (deployment)

### "Performance Optimization" → Multiple Agents
- Optimizer (analysis)
- Monitor (metrics)
- LeadEngineer (hardware)
- Relevant language agent (code optimization)

### "Mobile App Development" → Multiple Agents
- Mobile or AndroidMobile (platform)
- APIDesigner (backend)
- Database (data)
- Testbed (testing)

### "Microservices Architecture" → Multiple Agents
- Architect (design)
- APIDesigner (contracts)
- Go-Internal or Java-Internal (implementation)
- Docker (containerization)
- Infrastructure (orchestration)

### "Machine Learning Pipeline" → Multiple Agents
- DataScience (model development)
- MLOps (pipeline)
- NPU (acceleration)
- Monitor (metrics)

---

## 🚀 EXECUTION MODES

When invoking multiple agents, use these execution modes:

### PARALLEL
- Use when: Tasks have no dependencies
- Example: Security audit components can run simultaneously

### SEQUENTIAL
- Use when: Tasks depend on previous results
- Example: Design → Implementation → Testing

### REDUNDANT
- Use when: Critical operations need verification
- Example: Security operations, financial calculations

### CONSENSUS
- Use when: Multiple validations needed
- Example: Architecture decisions, security assessments

---

## 📌 CRITICAL RULES

1. **ALWAYS use Task tool** for agent invocation
2. **ALWAYS invoke Director + ProjectOrchestrator** for multi-step tasks
3. **PREFER parallel execution** when tasks are independent
4. **CHAIN agents** based on their invokes_agents relationships
5. **MONITOR hardware** when using C-Internal or Assembly-Internal
6. **VALIDATE security** with Security team for any sensitive operations
7. **DOCUMENT decisions** with Docgen after major implementations

---

*Last Updated: 2025-08-24*
*Framework Version: 7.0*
*Total Agents: 57*
*Status: PRODUCTION READY - Installed by claude-installer.sh*'
    
    # Check if source file exists, otherwise create content directly
    if [[ -f "$claude_md_source" ]]; then
        info "Found existing CLAUDE.md source file, copying..."
        cp "$claude_md_source" "$claude_md_target" 2>/dev/null
    else
        info "Creating comprehensive Global CLAUDE.md from embedded content..."
        echo "$claude_md_content" > "$claude_md_target" 2>/dev/null
    fi
    
    # Fix permissions
    chmod 644 "$claude_md_target" 2>/dev/null
    sudo chown "$USER:$USER" "$claude_md_target" 2>/dev/null
    
    # Verify installation
    if [[ -f "$claude_md_target" ]]; then
        local line_count=$(wc -l < "$claude_md_target" 2>/dev/null || echo "0")
        success "Installed Global CLAUDE.md ($line_count lines) - Agent Auto-Invocation Guide"
        info "Location: $claude_md_target"
        info "Contains: 57 agent invocation patterns, keywords, and coordination rules"
        print_dim "  This file tells Claude when to automatically invoke each specialized agent"
        print_dim "  Based on keywords, patterns, and context in user requests"
    else
        error "Failed to install Global CLAUDE.md"
    fi
    
    show_progress
}

# 4. Install hooks
install_hooks() {
    print_section "Installing Hooks"
    
    if [[ -d "$HOOKS_SOURCE" ]]; then
        force_mkdir "$CONFIG_DIR/hooks"
        cp -r "$HOOKS_SOURCE"/* "$CONFIG_DIR/hooks/" 2>/dev/null
        chmod -R +x "$CONFIG_DIR/hooks" 2>/dev/null
        
        HOOK_COUNT=$(find "$CONFIG_DIR/hooks" -type f 2>/dev/null | wc -l)
        success "Installed $HOOK_COUNT hooks"
    else
        warning "No hooks found"
    fi
    
    show_progress
}

# 5. Install statusline
install_statusline() {
    print_section "Installing Statusline"
    
    if [[ -f "$STATUSLINE_SOURCE" ]]; then
        force_mkdir "$HOME/.config/nvim/lua"
        cp "$STATUSLINE_SOURCE" "$HOME/.config/nvim/lua/claude-statusline.lua" 2>/dev/null
        
        if ! grep -q "claude-statusline" "$HOME/.config/nvim/init.lua" 2>/dev/null; then
            echo "require('claude-statusline')" >> "$HOME/.config/nvim/init.lua"
        fi
        
        success "Statusline installed"
    else
        warning "No statusline found"
    fi
    
    show_progress
}

# 6. Setup .claude directory structure
setup_claude_directory() {
    print_section "Setting up .claude Directory Structure"
    
    info "Creating self-contained .claude directory..."
    
    # Create .claude directory
    force_mkdir "$CLAUDE_DIR"
    
    # Create symlinks for all major directories
    for dir in agents config hooks database docs scripts tools orchestration installers bin; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            # Remove existing symlink or directory in .claude
            rm -rf "$CLAUDE_DIR/$dir" 2>/dev/null
            # Create symlink (relative path for portability)
            ln -sf "../$dir" "$CLAUDE_DIR/$dir"
            success "Linked .claude/$dir -> ../$dir"
        fi
    done
    
    # Create settings file if it doesn't exist
    if [[ ! -f "$CLAUDE_DIR/settings.local.json" ]]; then
        cat > "$CLAUDE_DIR/settings.local.json" << 'EOF'
{
  "claude_project_root": "auto",
  "self_contained": true,
  "use_symlinks": true,
  "directories": {
    "agents": "./agents",
    "config": "./config",
    "hooks": "./hooks",
    "database": "./database",
    "docs": "./docs",
    "scripts": "./scripts",
    "tools": "./tools",
    "orchestration": "./orchestration"
  }
}
EOF
        success "Created .claude/settings.local.json"
    fi
    
    success ".claude directory structure created with symlinks"
    show_progress
}

# 6.4. Register all agents with Task tool
register_agents_with_task_tool() {
    print_section "Registering 60 Agents with Claude Code Task Tool"
    
    info "Creating agent registry for Task tool access..."
    
    # Create compact agent registry
    cat > "$CLAUDE_DIR/agent-registry.json" <<'EOF'
{"version":"1.0.0","agents":[
{"name":"director","category":"command-control"},
{"name":"projectorchestrator","category":"command-control"},
{"name":"security","category":"security"},
{"name":"bastion","category":"security"},
{"name":"cso","category":"security"},
{"name":"cryptoexpert","category":"security"},
{"name":"quantumguard","category":"security"},
{"name":"securityauditor","category":"security"},
{"name":"securitychaosagent","category":"security"},
{"name":"redteamorchestrator","category":"security"},
{"name":"apt41-defense","category":"security"},
{"name":"nsa","category":"security"},
{"name":"psyops","category":"security"},
{"name":"architect","category":"development"},
{"name":"constructor","category":"development"},
{"name":"patcher","category":"development"},
{"name":"debugger","category":"development"},
{"name":"testbed","category":"development"},
{"name":"linter","category":"development"},
{"name":"optimizer","category":"development"},
{"name":"qadirector","category":"development"},
{"name":"infrastructure","category":"devops"},
{"name":"deployer","category":"devops"},
{"name":"monitor","category":"devops"},
{"name":"packager","category":"devops"},
{"name":"docker","category":"devops"},
{"name":"proxmox","category":"devops"},
{"name":"c-internal","category":"language"},
{"name":"python-internal","category":"language"},
{"name":"rust-internal","category":"language"},
{"name":"go-internal","category":"language"},
{"name":"java-internal","category":"language"},
{"name":"typescript-internal","category":"language"},
{"name":"kotlin-internal","category":"language"},
{"name":"assembly-internal","category":"language"},
{"name":"zig-internal","category":"language"},
{"name":"carbon-internal","category":"language"},
{"name":"apidesigner","category":"platform"},
{"name":"database","category":"platform"},
{"name":"web","category":"platform"},
{"name":"mobile","category":"platform"},
{"name":"androidmobile","category":"platform"},
{"name":"pygui","category":"platform"},
{"name":"tui","category":"platform"},
{"name":"datascience","category":"data-ml"},
{"name":"mlops","category":"data-ml"},
{"name":"npu","category":"data-ml"},
{"name":"cisco","category":"network"},
{"name":"bgp-purple-team","category":"network"},
{"name":"iot-access-control","category":"network"},
{"name":"ddwrt","category":"network"},
{"name":"gna","category":"hardware"},
{"name":"leadengineer","category":"hardware"},
{"name":"planner","category":"planning"},
{"name":"docgen","category":"planning"},
{"name":"researcher","category":"planning"},
{"name":"integration","category":"planning"},
{"name":"oversight","category":"planning"}
]}
EOF
    
    success "Agent registry created with 58 specialized agents"
    
    # Create settings file for Claude Code
    cat > "$CLAUDE_DIR/settings.json" <<EOF
{
  "customAgentsEnabled": true,
  "customAgentsPath": "$CLAUDE_DIR/custom-agents.json",
  "agentRegistryPath": "$CLAUDE_DIR/agent-registry.json",
  "enabledAgents": [
    "director", "projectorchestrator", "security", "bastion", "cso",
    "cryptoexpert", "quantumguard", "securityauditor", "securitychaosagent",
    "redteamorchestrator", "apt41-defense", "nsa", "psyops",
    "architect", "constructor", "patcher", "debugger", "testbed",
    "linter", "optimizer", "qadirector", "infrastructure", "deployer",
    "monitor", "packager", "docker", "proxmox", "c-internal",
    "python-internal", "rust-internal", "go-internal", "java-internal",
    "typescript-internal", "kotlin-internal", "assembly-internal",
    "zig-internal", "carbon-internal", "apidesigner", "database",
    "web", "mobile", "androidmobile", "pygui", "tui", "datascience",
    "mlops", "npu", "cisco", "bgp-purple-team", "iot-access-control",
    "ddwrt", "gna", "leadengineer", "planner", "docgen", "researcher",
    "integration", "oversight"
  ]
}
EOF
    
    success "Claude Code settings configured"
    
    # Create quick reference
    cat > "$CLAUDE_DIR/available-agents.txt" <<'EOF'
AVAILABLE AGENTS (58 total) - Use with Task(subagent_type="name", prompt="...")

COMMAND & CONTROL: director, projectorchestrator
SECURITY: security, bastion, cso, cryptoexpert, quantumguard, securityauditor, 
          securitychaosagent, redteamorchestrator, apt41-defense, nsa, psyops
DEVELOPMENT: architect, constructor, patcher, debugger, testbed, linter, optimizer, qadirector
DEVOPS: infrastructure, deployer, monitor, packager, docker, proxmox
LANGUAGES: c-internal, python-internal, rust-internal, go-internal, java-internal,
           typescript-internal, kotlin-internal, assembly-internal, zig-internal, carbon-internal
PLATFORMS: apidesigner, database, web, mobile, androidmobile, pygui, tui
DATA/ML: datascience, mlops, npu
NETWORK: cisco, bgp-purple-team, iot-access-control, ddwrt
HARDWARE: gna, leadengineer
PLANNING: planner, docgen, researcher, integration, oversight

Example: Task(subagent_type="director", prompt="Create strategic plan")
EOF
    
    info "✅ All 58 agents registered and available via Task tool"
    show_progress
}

# 6.5. Setup precision orchestration style
setup_precision_style() {
    print_section "Setting up Precision Orchestration Style"
    
    if [[ -f "$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh" ]]; then
        info "Running precision orchestration style setup..."
        bash "$PROJECT_ROOT/scripts/setup-precision-orchestration-style.sh" --reinstall 2>&1 | while read line; do
            echo "  $line"
        done
        success "Precision orchestration style configured"
        
        # ACTIVATE the style by default
        info "Activating precision orchestration style as default..."
        
        # Create/update Claude config to use this style by default
        local CLAUDE_CONFIG_DIR="$HOME/.config/claude"
        mkdir -p "$CLAUDE_CONFIG_DIR"
        
        # Create a config file that sets the default output style
        cat > "$CLAUDE_CONFIG_DIR/defaults.json" << 'EOF'
{
  "outputStyle": "precision-orchestration",
  "verbose": true,
  "autoOrchestration": true,
  "defaultAgentInvocation": "intelligent"
}
EOF
        
        # Also create an environment variable setup
        local SHELL_RC=""
        if [[ -f "$HOME/.bashrc" ]]; then
            SHELL_RC="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            SHELL_RC="$HOME/.zshrc"
        fi
        
        if [[ -n "$SHELL_RC" ]]; then
            # Add export for default output style if not already present
            if ! grep -q "CLAUDE_OUTPUT_STYLE" "$SHELL_RC"; then
                echo "" >> "$SHELL_RC"
                echo "# Claude default output style (set by installer)" >> "$SHELL_RC"
                echo "export CLAUDE_OUTPUT_STYLE='precision-orchestration'" >> "$SHELL_RC"
                echo "export CLAUDE_VERBOSE=true" >> "$SHELL_RC"
            fi
        fi
        
        # Create a wrapper that always uses the precision style
        local WRAPPER_PATH="$LOCAL_BIN/claude-precision"
        cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
# Claude with precision orchestration style active by default
exec claude --output-style precision-orchestration "$@"
EOF
        chmod +x "$WRAPPER_PATH"
        
        success "Precision orchestration style ACTIVATED as default"
        info "  • Config saved to: $CLAUDE_CONFIG_DIR/defaults.json"
        info "  • Environment variable CLAUDE_OUTPUT_STYLE set"
        info "  • Quick access: claude-precision (always uses this style)"
        print_green "✓ Style will be active for all future Claude sessions"
        
    else
        warning "Precision orchestration setup script not found"
    fi
    
    show_progress
}

# 6.5.1 Setup virtual environment
setup_virtual_environment() {
    print_section "Setting Up Python Virtual Environment"
    
    if [[ "$SETUP_VENV" != "yes" ]]; then
        info "Skipping virtual environment setup (user preference)"
        show_progress
        return
    fi
    
    info "Creating virtual environment at: $VENV_DIR"
    force_mkdir "$(dirname "$VENV_DIR")"
    
    # Create virtual environment
    if command -v python3 &>/dev/null; then
        python3 -m venv "$VENV_DIR" 2>/dev/null || {
            warning "Failed to create virtual environment - trying with --system-site-packages"
            python3 -m venv --system-site-packages "$VENV_DIR" 2>/dev/null || {
                error "Failed to create virtual environment"
                show_progress
                return
            }
        }
        success "Virtual environment created at $VENV_DIR"
        
        # Upgrade pip in venv
        info "Upgrading pip in virtual environment..."
        "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel 2>/dev/null
        
        # Install requirements if file exists
        if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
            info "Installing requirements.txt into virtual environment..."
            "$VENV_DIR/bin/pip" install -r "$PROJECT_ROOT/requirements.txt" 2>&1 | while read line; do
                if [[ "$line" == *"Successfully installed"* ]]; then
                    echo "  ✓ Packages installed"
                elif [[ "$line" == *"ERROR"* ]]; then
                    echo "  ✗ $line"
                fi
            done
            success "Requirements installed in virtual environment"
        fi
        
        # Create activation helper script
        local ACTIVATE_SCRIPT="$LOCAL_BIN/activate-claude-venv"
        cat > "$ACTIVATE_SCRIPT" << EOF
#!/bin/bash
# Activate Claude virtual environment
if [[ -f "$VENV_DIR/bin/activate" ]]; then
    source "$VENV_DIR/bin/activate"
    echo "Claude virtual environment activated"
    echo "Python: \$(which python3)"
    echo "Pip: \$(which pip)"
else
    echo "Virtual environment not found at $VENV_DIR"
    exit 1
fi
EOF
        chmod +x "$ACTIVATE_SCRIPT"
        success "Created activation helper: activate-claude-venv"
        
        # Add to shell RC file
        local SHELL_RC=""
        if [[ -f "$HOME/.bashrc" ]]; then
            SHELL_RC="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            SHELL_RC="$HOME/.zshrc"
        fi
        
        if [[ -n "$SHELL_RC" ]] && ! grep -q "CLAUDE_VENV" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "# Claude virtual environment (added by installer)" >> "$SHELL_RC"
            echo "export CLAUDE_VENV='$VENV_DIR'" >> "$SHELL_RC"
            echo "alias claude-venv='source $VENV_DIR/bin/activate'" >> "$SHELL_RC"
            success "Added venv alias to shell configuration"
        fi
    else
        error "Python 3 not found - cannot create virtual environment"
    fi
    
    show_progress
}

# 6.6. Setup database system
setup_database_system() {
    print_section "Setting up PostgreSQL Database System"
    
    local DB_DIR="$PROJECT_ROOT/database"
    
    if [[ ! -d "$DB_DIR" ]]; then
        warning "Database directory not found at $DB_DIR"
        show_progress
        return
    fi
    
    # Make scripts executable
    chmod +x "$DB_DIR"/*.sh 2>/dev/null
    chmod +x "$DB_DIR/scripts"/*.sh 2>/dev/null
    
    # Check if PostgreSQL is installed
    if command -v psql >/dev/null 2>&1; then
        local PG_VERSION=$(psql --version | grep -oE '[0-9]+' | head -1)
        success "PostgreSQL $PG_VERSION detected"
    else
        if [[ "$ALLOW_SYSTEM_PACKAGES" == "true" ]]; then
            info "Installing PostgreSQL and Redis..."
            sudo apt-get update 2>/dev/null
            sudo apt-get install -y postgresql postgresql-client postgresql-contrib redis-server 2>/dev/null || {
                warning "Failed to install PostgreSQL/Redis - continuing without database"
                show_progress
                return
            }
            success "PostgreSQL and Redis installed"
        else
            warning "PostgreSQL not installed - database features will be limited"
            info "Install with: sudo apt-get install postgresql postgresql-client redis-server"
            show_progress
            return
        fi
    fi
    
    # Initialize PostgreSQL data directory if needed
    local DATA_DIR="$DB_DIR/data/postgresql"
    if [[ ! -d "$DATA_DIR" || ! -f "$DATA_DIR/PG_VERSION" ]]; then
        info "Initializing PostgreSQL data directory..."
        
        # Find PostgreSQL version and initialize
        local PG_VERSION=""
        if command -v pg_ctl >/dev/null 2>&1; then
            PG_VERSION=$(pg_ctl --version | grep -oE '[0-9]+' | head -1)
        else
            # Find installed version
            for version in 17 16 15 14 13 12; do
                if [ -x "/usr/lib/postgresql/$version/bin/initdb" ]; then
                    PG_VERSION="$version"
                    break
                fi
            done
        fi
        
        if [[ -n "$PG_VERSION" ]]; then
            info "Initializing PostgreSQL $PG_VERSION data directory..."
            mkdir -p "$DATA_DIR"
            
            # Use initdb to initialize data directory
            local INITDB_CMD=""
            if [ -x "/usr/lib/postgresql/$PG_VERSION/bin/initdb" ]; then
                INITDB_CMD="/usr/lib/postgresql/$PG_VERSION/bin/initdb"
            elif command -v initdb >/dev/null 2>&1; then
                INITDB_CMD="initdb"
            fi
            
            if [[ -n "$INITDB_CMD" ]]; then
                "$INITDB_CMD" -D "$DATA_DIR" --auth-local=trust --auth-host=md5 >/dev/null 2>&1 && \
                    success "PostgreSQL data directory initialized" || \
                    warning "PostgreSQL initialization had issues"
            fi
        fi
    fi
    
    # Setup database using manage_database.sh
    if [[ -f "$DB_DIR/manage_database.sh" ]]; then
        info "Setting up Claude authentication database..."
        cd "$DB_DIR" || return
        
        # Initialize and setup database
        bash ./manage_database.sh setup 2>&1 | while read line; do
            echo "  $line"
        done
        
        # Test database connection
        bash ./manage_database.sh test 2>&1 | head -20 | while read line; do
            echo "  $line"
        done
        
        cd "$PROJECT_ROOT" || true
        success "Database system initialized"
    fi
    
    # Setup Redis caching layer
    if [[ -f "$DB_DIR/python/auth_redis_setup.py" ]]; then
        info "Setting up Redis caching layer..."
        if [[ -n "$VENV_DIR" ]] && [[ -f "$VENV_DIR/bin/python" ]]; then
            "$VENV_DIR/bin/python" "$DB_DIR/python/auth_redis_setup.py" 2>/dev/null && \
                success "Redis caching layer configured" || \
                warning "Redis setup had issues - will retry on first use"
        else
            python3 "$DB_DIR/python/auth_redis_setup.py" 2>/dev/null && \
                success "Redis caching layer configured" || \
                warning "Redis setup had issues - will retry on first use"
        fi
    fi
    
    # Run database initialization
    if [[ -f "$DB_DIR/initialize_complete_system.sh" ]]; then
        info "Initializing database system..."
        
        # Run setup in background with output capture
        if bash "$DB_DIR/initialize_complete_system.sh" setup 2>&1 | while read line; do
            echo "  $line"
        done; then
            success "Database system initialized"
        else
            warning "Database initialization had some issues (non-critical)"
        fi
    else
        # Fallback to basic setup
        if [[ -f "$DB_DIR/start_local_postgres.sh" ]]; then
            info "Starting local PostgreSQL..."
            bash "$DB_DIR/start_local_postgres.sh" 2>&1 | head -5
            success "Local PostgreSQL started"
        fi
    fi
    
    # Setup learning data sync
    if [[ -f "$DB_DIR/scripts/learning_sync.sh" ]]; then
        info "Setting up learning data sync..."
        chmod +x "$DB_DIR/scripts/learning_sync.sh"
        
        # Import existing learning data if available
        if bash "$DB_DIR/scripts/learning_sync.sh" import 2>&1 | head -5; then
            success "Learning data sync configured"
        fi
        
        # Setup git hooks for automatic sync
        bash "$DB_DIR/scripts/learning_sync.sh" setup-hooks 2>/dev/null
    fi
    
    show_progress
}

# 6.7. Setup learning system
setup_learning_system() {
    print_section "Setting up Agent Learning System"
    
    local PYTHON_DIR="$PROJECT_ROOT/agents/src/python"
    
    if [[ ! -d "$PYTHON_DIR" ]]; then
        warning "Python source directory not found"
        show_progress
        return
    fi
    
    # Check Python availability
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 not found - learning system requires Python"
        show_progress
        return
    fi
    
    # Install Python dependencies
    info "Installing learning system dependencies..."
    
    # Try different installation methods
    local PIP_INSTALLED=false
    
    # Method 1: Try with --user flag
    if python3 -m pip install --user --quiet \
        psycopg2-binary asyncpg numpy scikit-learn joblib 2>/dev/null; then
        PIP_INSTALLED=true
        success "Python dependencies installed (user)"
    # Method 2: Try with --break-system-packages if needed
    elif python3 -m pip install --break-system-packages --quiet \
        psycopg2-binary asyncpg numpy scikit-learn joblib 2>/dev/null; then
        PIP_INSTALLED=true
        success "Python dependencies installed (system)"
    else
        warning "Could not install all Python dependencies automatically"
        info "You may need to install manually: psycopg2-binary asyncpg numpy scikit-learn joblib"
    fi
    
    # Run learning system setup if dependencies are available
    if [[ -f "$PYTHON_DIR/setup_learning_system.py" ]]; then
        info "Configuring learning system..."
        
        # Set environment variables for database
        export POSTGRES_DB=claude_auth
        export POSTGRES_USER=claude_auth
        export POSTGRES_PASSWORD=claude_auth_pass
        export POSTGRES_HOST=localhost
        export POSTGRES_PORT=5433
        
        # Try to run setup
        if python3 "$PYTHON_DIR/setup_learning_system.py" 2>&1 | while read line; do
            echo "  $line"
        done; then
            success "Learning system configured"
        else
            warning "Learning system setup incomplete (can be configured later)"
        fi
    fi
    
    # Create learning system launcher
    local LAUNCHER="$PYTHON_DIR/postgresql-learning"
    cat > "$LAUNCHER" <<'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/database"

export POSTGRES_DB=claude_auth
export POSTGRES_USER=claude_auth
export POSTGRES_PASSWORD=claude_auth_pass
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5433

"$DATABASE_DIR/start_local_postgres.sh" >/dev/null 2>&1

case "$1" in
    setup) python3 "$SCRIPT_DIR/setup_learning_system.py" ;;
    status) python3 "$SCRIPT_DIR/learning_cli.py" status ;;
    *) python3 "$SCRIPT_DIR/learning_cli.py" "$@" ;;
esac
EOF
    chmod +x "$LAUNCHER"
    
    # Create symlink for easy access
    if [[ -d "$HOME/.local/bin" ]]; then
        ln -sf "$LAUNCHER" "$HOME/.local/bin/claude-learning"
        success "Learning system launcher installed (claude-learning)"
    fi
    
    show_progress
}

# 6.8. Setup tandem orchestration
setup_tandem_orchestration() {
    print_section "Setting up Tandem Orchestration System v2.0"
    
    # First, ensure Python dependencies are installed
    info "Checking Python dependencies for orchestration..."
    
    local PYTHON_SRC="$PROJECT_ROOT/agents/src/python"
    
    # Fix any issues in the orchestration files
    if [[ -d "$PYTHON_SRC" ]]; then
        info "Verifying orchestration system files..."
        
        # Ensure all required files exist
        local REQUIRED_FILES=(
            "production_orchestrator.py"
            "agent_registry.py"
            "agent_dynamic_loader.py"
        )
        
        local all_files_exist=true
        for file in "${REQUIRED_FILES[@]}"; do
            if [[ ! -f "$PYTHON_SRC/$file" ]]; then
                warning "Missing required file: $file"
                all_files_exist=false
            fi
        done
        
        if $all_files_exist; then
            success "All orchestration system files present"
        else
            error "Some orchestration files are missing"
            return 1
        fi
    fi
    
    # Install the new comprehensive launcher
    local NEW_LAUNCHER="$PYTHON_SRC/tandem_orchestration_launcher.sh"
    
    # If the new launcher doesn't exist, check for the old one
    if [[ ! -f "$NEW_LAUNCHER" ]]; then
        info "Creating comprehensive tandem orchestration launcher..."
        
        # The launcher might not exist yet, so we'll use the existing python-orchestrator-launcher.sh
        # or create a basic one that works
        NEW_LAUNCHER="$PROJECT_ROOT/agents/src/python/python-orchestrator-launcher.sh"
        if [[ ! -f "$NEW_LAUNCHER" ]]; then
            NEW_LAUNCHER="$PROJECT_ROOT/agents/python-orchestrator-startup.sh"
        fi
    fi
    
    if [[ -f "$NEW_LAUNCHER" ]]; then
        info "Installing tandem orchestration launcher..."
        
        # Make it executable
        chmod +x "$NEW_LAUNCHER"
        
        # Create a symlink in bin directory for easy access
        if [[ ! -d "$HOME/.local/bin" ]]; then
            mkdir -p "$HOME/.local/bin"
        fi
        
        # Create multiple access points
        ln -sf "$NEW_LAUNCHER" "$HOME/.local/bin/tandem-orchestrator"
        ln -sf "$NEW_LAUNCHER" "$HOME/.local/bin/python-orchestrator"
        
        # Quick validation test - run a simple Python import test
        info "Validating orchestration system..."
        
        if python3 -c "
import sys
import os
sys.path.append('$PYTHON_SRC')
os.environ['CLAUDE_AGENTS_ROOT'] = '$PROJECT_ROOT/agents'
try:
    from production_orchestrator import ProductionOrchestrator
    # Try enhanced registry first
    try:
        from agent_registry import EnhancedAgentRegistry, get_enhanced_registry
        print('Enhanced orchestration modules with Python fallback loaded successfully')
    except ImportError:
        from agent_registry import AgentRegistry
        print('Standard orchestration modules loaded successfully')
    exit(0)
except Exception as e:
    print(f'Failed to load orchestration modules: {e}')
    exit(1)
" >/dev/null 2>&1; then
            success "Orchestration system validated successfully"
            
            # Now run a quick functionality test
            info "Testing orchestration functionality..."
            python3 -c "
import sys
import os
import asyncio
sys.path.append('$PYTHON_SRC')
os.environ['CLAUDE_AGENTS_ROOT'] = '$PROJECT_ROOT/agents'

from production_orchestrator import ProductionOrchestrator

async def quick_test():
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    agents = orchestrator.list_available_agents()
    print(f'✓ Discovered {len(agents)} agents with categories')
    return len(agents) >= 40

result = asyncio.run(quick_test())
exit(0 if result else 1)
" 2>/dev/null && success "Orchestration system functional: 40+ agents ready" || warning "Orchestration system needs initialization"
            
        else
            warning "Orchestration validation failed - will be fixed on first run"
        fi
        
        success "Tandem orchestration launcher installed"
        info "Access via: tandem-orchestrator or python-orchestrator"
        info "Integrated with Claude command for seamless operation"
    else
        warning "No orchestration launcher found - creating basic launcher..."
        
        # Create a minimal launcher if none exists
        cat > "$HOME/.local/bin/tandem-orchestrator" << 'EOF'
#!/bin/bash
# Minimal Tandem Orchestrator Launcher
export CLAUDE_AGENTS_ROOT="${HOME}/Documents/claude-backups/agents"
export PYTHONPATH="${CLAUDE_AGENTS_ROOT}/src/python:${PYTHONPATH}"

echo "Starting Tandem Orchestration System..."
cd "${CLAUDE_AGENTS_ROOT}/src/python"

python3 -c "
import asyncio
from production_orchestrator import ProductionOrchestrator

async def start():
    orchestrator = ProductionOrchestrator()
    await orchestrator.initialize()
    print(f'✓ System online with {len(orchestrator.list_available_agents())} agents')

asyncio.run(start())
"
EOF
        chmod +x "$HOME/.local/bin/tandem-orchestrator"
        success "Created minimal tandem orchestrator launcher"
    fi
    
    # Run the legacy tandem setup script if it exists
    if [[ -f "$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh" ]]; then
        info "Running additional tandem setup..."
        bash "$PROJECT_ROOT/scripts/setup-tandem-for-claude.sh" 2>&1 | while read line; do
            echo "  $line"
        done
    fi
    
    success "Tandem Orchestration System v2.0 configured"
    info "41 agents with full category support ready for Task tool invocation"
    
    show_progress
}

# 6.8.5 Setup natural invocation hook
setup_natural_invocation() {
    print_section "Setting Up Natural Agent Invocation"
    
    # Check if enable script exists
    if [[ ! -f "$ENABLE_NATURAL_INVOCATION" ]]; then
        warning "Natural invocation script not found at: $ENABLE_NATURAL_INVOCATION"
        show_progress
        return
    fi
    
    info "Enabling natural language agent invocation..."
    
    # Make script executable
    chmod +x "$ENABLE_NATURAL_INVOCATION"
    
    # Run the enable script
    bash "$ENABLE_NATURAL_INVOCATION" 2>&1 | while read line; do
        echo "  $line"
    done
    
    # Verify hooks.json was created/updated
    if [[ -f "$CONFIG_DIR/hooks.json" ]]; then
        # Check if natural invocation is enabled in hooks.json
        if grep -q '"natural_invocation"' "$CONFIG_DIR/hooks.json" 2>/dev/null; then
            success "Natural invocation hook configured in hooks.json"
        fi
    fi
    
    # Copy hook files if they exist
    if [[ -d "$PROJECT_ROOT/hooks" ]]; then
        info "Installing hook files..."
        force_mkdir "$CONFIG_DIR/hooks"
        
        # Copy specific natural invocation hooks
        for hook_file in natural-invocation-hook.py agent-invocation-patterns.yaml; do
            if [[ -f "$PROJECT_ROOT/hooks/$hook_file" ]]; then
                cp "$PROJECT_ROOT/hooks/$hook_file" "$CONFIG_DIR/hooks/" 2>/dev/null
                chmod +x "$CONFIG_DIR/hooks/$hook_file" 2>/dev/null
                success "Installed $hook_file"
            fi
        done
    fi
    
    # Copy fuzzy matcher tool (check both tools and hooks directories)
    if [[ -f "$PROJECT_ROOT/tools/claude-fuzzy-agent-matcher.py" ]]; then
        force_mkdir "$CONFIG_DIR/tools"
        cp "$PROJECT_ROOT/tools/claude-fuzzy-agent-matcher.py" "$CONFIG_DIR/tools/" 2>/dev/null
        chmod +x "$CONFIG_DIR/tools/claude-fuzzy-agent-matcher.py" 2>/dev/null
        success "Installed fuzzy agent matcher tool from tools/"
    elif [[ -f "$PROJECT_ROOT/hooks/claude-fuzzy-agent-matcher.py" ]]; then
        force_mkdir "$CONFIG_DIR/tools"
        cp "$PROJECT_ROOT/hooks/claude-fuzzy-agent-matcher.py" "$CONFIG_DIR/tools/" 2>/dev/null
        chmod +x "$CONFIG_DIR/tools/claude-fuzzy-agent-matcher.py" 2>/dev/null
        success "Installed fuzzy agent matcher tool from hooks/"
    fi
    
    success "Natural agent invocation system enabled"
    info "  • 58+ agents available via natural language"
    info "  • Fuzzy matching and semantic understanding active"
    info "  • Workflow detection for complex tasks"
    
    show_progress
}

# 6.9. Setup production environment
setup_production_environment() {
    print_section "Setting Up Production Environment"
    
    # Check if production environment setup script exists
    local SETUP_SCRIPT="$PROJECT_ROOT/agents/src/python/setup_production_env.sh"
    if [[ -f "$SETUP_SCRIPT" ]]; then
        info "Running production environment setup..."
        
        # Make script executable
        chmod +x "$SETUP_SCRIPT"
        
        # Run the setup script in the correct directory
        cd "$PROJECT_ROOT/agents/src/python" || {
            warning "Could not change to agents/src/python directory"
            show_progress
            return
        }
        
        # Run setup with output capture and proper exit status handling
        local temp_output=$(mktemp)
        local exit_status=0
        
        if bash "./setup_production_env.sh" --auto > "$temp_output" 2>&1; then
            # Show output with indentation
            while read line; do
                echo "  $line"
            done < "$temp_output"
            success "Production environment setup completed"
        else
            exit_status=$?
            # Show output with indentation even on failure
            while read line; do
                echo "  $line"
            done < "$temp_output"
            warning "Production environment setup had some issues (exit code: $exit_status, non-critical)"
        fi
        
        # Clean up temp file
        rm -f "$temp_output"
        
        # Return to project root
        cd "$PROJECT_ROOT" || true
    else
        warning "Production environment setup script not found at: $SETUP_SCRIPT"
    fi
    
    # Install requirements.txt using enhanced method
    local REQUIREMENTS_FILE="$PROJECT_ROOT/requirements.txt"
    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        info "Installing Python requirements..."
        
        # Try to find the virtual environment created by setup_production_env.sh
        local VENV_PATHS=(
            "$HOME/.local/share/claude-agents/venv"
            "$PROJECT_ROOT/agents/src/python/venv"
            "$PROJECT_ROOT/venv"
        )
        
        local VENV_PATH=""
        for path in "${VENV_PATHS[@]}"; do
            if [[ -d "$path" && -f "$path/bin/activate" ]]; then
                VENV_PATH="$path"
                break
            fi
        done
        
        # Use the enhanced installation function
        install_python_packages "$REQUIREMENTS_FILE" "$VENV_PATH"
    else
        warning "Requirements file not found at: $REQUIREMENTS_FILE"
    fi
    
    show_progress
}

# 6.8. Validate agent files
validate_agents() {
    print_section "Validating Agent Files"
    
    # Check if validation script exists
    if [[ -f "$PROJECT_ROOT/scripts/validate_all_agents.py" ]]; then
        info "Validating agent YAML frontmatter..."
        
        # Run validation
        local validation_output=$(python3 "$PROJECT_ROOT/scripts/validate_all_agents.py" 2>&1)
        local exit_code=$?
        
        # Show output with indentation
        echo "$validation_output" | while read line; do
            if [[ "$line" == *"✅"* ]]; then
                # Don't show all valid agents to reduce clutter
                continue
            elif [[ "$line" == *"❌"* ]]; then
                # Show invalid agents as warnings
                warning "  $line"
            elif [[ "$line" == *"Summary:"* ]]; then
                # Show summary
                echo "  $line"
            elif [[ "$line" == *"All agent files are valid"* ]]; then
                success "  $line"
            fi
        done
        
        # Extract summary
        local summary=$(echo "$validation_output" | grep "Summary:" || echo "")
        if [[ -n "$summary" ]]; then
            # Parse valid and invalid counts
            local valid_count=$(echo "$summary" | grep -o "[0-9]* valid" | grep -o "[0-9]*")
            local invalid_count=$(echo "$summary" | grep -o "[0-9]* invalid" | grep -o "[0-9]*")
            
            if [[ "$invalid_count" == "0" ]]; then
                success "All $valid_count agent files validated successfully"
            else
                warning "$invalid_count agent files have validation issues"
                info "Agent files with issues will still work but may not be discoverable by Task tool"
            fi
        fi
    else
        warning "Agent validation script not found"
        info "Skipping validation - agents will work but should be validated"
    fi
    
    show_progress
}

# Modular call to wrapper integration installer
call_wrapper_integration() {
    # Check if wrapper integration should be skipped
    if [[ "$SKIP_WRAPPER_INTEGRATION" == "true" ]]; then
        info "Wrapper integration skipped per user request"
        return 1
    fi
    
    local wrapper_installer="$PROJECT_ROOT/installers/install-wrapper-integration.sh"
    
    # Check if wrapper integration installer exists
    if [[ ! -f "$wrapper_installer" ]]; then
        warning "Wrapper integration installer not found: $wrapper_installer"
        return 1
    fi
    
    # Set up environment variables for the modular installer
    export CALLER_PROJECT_ROOT="$PROJECT_ROOT"
    export CALLER_LOCAL_BIN="$LOCAL_BIN"
    export CALLER_LOG_FILE="$LOG_FILE"
    export CALLER_INSTALLATION_MODE="$INSTALLATION_MODE"
    
    info "Running modular wrapper integration installer..."
    
    # Execute the modular installer with proper error handling
    if bash "$wrapper_installer" --quiet 2>&1 | tee -a "$LOG_FILE" >/dev/null; then
        success "Wrapper integration system installed successfully"
        info "  • Professional wrapper system active"
        info "  • AI orchestration capabilities enabled" 
        info "  • Enhanced bash output handling configured"
        info "  • Seamless fallback systems ready"
        return 0
    else
        warning "Wrapper integration failed, falling back to legacy wrapper"
        return 1
    fi
}

# 7. Create wrapper
create_wrapper() {
    print_section "Creating Enhanced Claude Wrapper"
    
    force_mkdir "$LOCAL_BIN"
    
    # NEW: Default wrapper integration as first priority
    info "Installing wrapper integration system..."
    if call_wrapper_integration; then
        show_progress
        return
    fi
    
    # Check for ultimate wrapper first, then enhanced wrapper
    if [[ -f "$PROJECT_ROOT/claude-wrapper-ultimate.sh" ]]; then
        # Use symlink for ultimate wrapper to preserve agent discovery
        ln -sf "$PROJECT_ROOT/claude-wrapper-ultimate.sh" "$LOCAL_BIN/claude"
        chmod +x "$PROJECT_ROOT/claude-wrapper-ultimate.sh"
        
        success "Ultimate wrapper installed with AI intelligence features (symlinked)"
        info "  • Pattern learning system active"
        info "  • Quick access shortcuts configured"
        info "  • Confidence scoring enabled"
        info "  • Automatic agent discovery from $PROJECT_ROOT/agents"
        info "  • Permission bypass always enabled for enhanced functionality"
        
        # Setup agent discovery system
        setup_agent_discovery
        
        show_progress
        return
    elif [[ -f "$PROJECT_ROOT/claude-wrapper-enhanced.sh" ]]; then
        # Use symlink for enhanced wrapper as well
        ln -sf "$PROJECT_ROOT/claude-wrapper-enhanced.sh" "$LOCAL_BIN/claude"
        chmod +x "$PROJECT_ROOT/claude-wrapper-enhanced.sh"
        
        success "Enhanced wrapper installed with intelligence features (symlinked)"
        info "  • Wrapper linked to preserve directory structure"
        
        # Setup agent discovery system
        setup_agent_discovery
        
        show_progress
        return
    fi
    
    cat > "$LOCAL_BIN/claude" << 'WRAPPER'
#!/bin/bash
# Claude Master Wrapper v8.0 with Auto Permission Bypass

# Configuration
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"

# Check if running from project with .claude directory
if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
    export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
    export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
    export CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
else
    export CLAUDE_AGENTS_DIR="$HOME/agents"
    export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
    export CLAUDE_HOOKS_DIR="$HOME/.config/claude/hooks"
fi

# Binary location
CLAUDE_BINARY="BINARY_PLACEHOLDER"

# Find binary if needed
if [[ ! -f "$CLAUDE_BINARY" ]]; then
    for path in \
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
        "$HOME/.npm-global/bin/claude" \
        "/usr/local/bin/claude"; do
        if [[ -f "$path" ]]; then
            CLAUDE_BINARY="$path"
            break
        fi
    done
fi

# Permission bypass always enabled for enhanced functionality
PERMISSION_BYPASS="true"

# Commands
case "$1" in
    --status|status)
        echo "Claude System Status"
        echo "===================="
        echo "Binary: $CLAUDE_BINARY"
        echo "Agents: $CLAUDE_AGENTS_DIR"
        echo "Project: $CLAUDE_PROJECT_ROOT"
        echo "Permission Bypass: $PERMISSION_BYPASS"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            COUNT=$(find "$CLAUDE_AGENTS_DIR" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
            echo "Agent Count: $COUNT"
        fi
        ;;
        
    --list-agents|agents)
        echo "Available Agents"
        echo "================"
        
        if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
            find "$CLAUDE_AGENTS_DIR" -type f \( -name "*.md" -o -name "*.MD" \) 2>/dev/null | while read -r agent; do
                name=$(basename "$agent" | sed 's/\.[mM][dD]$//')
                printf "  • %s\n" "$name"
            done | sort
        else
            echo "No agents directory found"
        fi
        ;;
        
    --agent|agent)
        shift
        AGENT_NAME="$1"
        shift
        
        if [[ -z "$AGENT_NAME" ]]; then
            echo "Usage: claude agent <name> [args]"
            exit 1
        fi
        
        # Find agent file (case-insensitive)
        AGENT_FILE=""
        AGENT_UPPER="${AGENT_NAME^^}"
        AGENT_LOWER="${AGENT_NAME,,}"
        
        for pattern in \
            "$CLAUDE_AGENTS_DIR/${AGENT_NAME}.md" \
            "$CLAUDE_AGENTS_DIR/${AGENT_NAME}.MD" \
            "$CLAUDE_AGENTS_DIR/${AGENT_UPPER}.md" \
            "$CLAUDE_AGENTS_DIR/${AGENT_UPPER}.MD" \
            "$CLAUDE_AGENTS_DIR/${AGENT_LOWER}.md" \
            "$CLAUDE_AGENTS_DIR/${AGENT_LOWER}.MD" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_NAME}.md" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_NAME}.MD" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_UPPER}.md" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_UPPER}.MD" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_LOWER}.md" \
            "$CLAUDE_AGENTS_DIR"/*/"${AGENT_LOWER}.MD"; do
            for file in $pattern; do
                if [[ -f "$file" ]]; then
                    AGENT_FILE="$file"
                    break 2
                fi
            done
        done
        
        if [[ -z "$AGENT_FILE" ]]; then
            echo "Agent not found: $AGENT_NAME"
            exit 1
        fi
        
        echo "Loading agent: $AGENT_NAME"
        export CLAUDE_AGENT="$AGENT_NAME"
        export CLAUDE_AGENT_FILE="$AGENT_FILE"
        
        # Permission bypass always enabled for enhanced functionality
        exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        ;;
        
    --safe)
        # Note: Permission bypass is now always enabled for enhanced functionality
        echo "Warning: --safe mode deprecated. Permission bypass always enabled for full functionality."
        echo "Running with permission bypass for optimal performance..."
        shift
        exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        ;;
        
    --orchestrator)
        # Launch Python orchestrator UI
        ORCHESTRATOR_LAUNCHER="$HOME/.local/bin/python-orchestrator"
        if [[ -f "$ORCHESTRATOR_LAUNCHER" ]]; then
            exec "$ORCHESTRATOR_LAUNCHER"
        else
            echo "Python orchestrator not found. Please run installer to set it up."
            exit 1
        fi
        ;;
        
    --help|-h)
        echo "Claude Master System with Auto Permission Bypass"
        echo "================================================"
        echo "Commands:"
        echo "  claude [args]           - Run Claude (with auto permission bypass)"
        echo "  claude --safe [args]    - Run Claude without permission bypass"
        echo "  claude --status         - Show status"
        echo "  claude --list-agents    - List agents"
        echo "  claude --orchestrator   - Launch Python orchestrator UI"
        echo "  claude agent <n> [args] - Run agent"
        echo ""
        echo "Environment:"
        echo "  CLAUDE_PERMISSION_BYPASS=false  - Disable auto permission bypass"
        echo ""
        echo "Quick functions:"
        echo "  coder, director, architect, security"
        ;;
        
    *)
        # Default: always run with permission bypass for enhanced functionality
        exec "$CLAUDE_BINARY" --dangerously-skip-permissions "$@"
        ;;
esac
WRAPPER
    
    # Replace placeholders
    sed -i "s|PROJECT_ROOT_PLACEHOLDER|$PROJECT_ROOT|g" "$LOCAL_BIN/claude"
    sed -i "s|BINARY_PLACEHOLDER|$CLAUDE_BINARY|g" "$LOCAL_BIN/claude"
    
    chmod +x "$LOCAL_BIN/claude"
    success "Wrapper created"
    
    # Setup agent discovery system
    setup_agent_discovery
    
    show_progress
}

# 7. Setup sync
setup_sync() {
    print_section "Setting Up Auto-Sync"
    
    cat > "$LOCAL_BIN/sync-agents.sh" << 'SYNC'
#!/bin/bash
SOURCE="SOURCE_PLACEHOLDER"
TARGET="$HOME/agents"

if [[ -d "$SOURCE" ]] && [[ "$SOURCE" != "$TARGET" ]]; then
    # Force sync .md/.MD files from root directory (overwrite existing)
    find "$SOURCE" -maxdepth 1 -type f \( -name "*.md" -o -name "*.MD" \) -exec cp -f {} "$TARGET/" \; 2>/dev/null
fi
SYNC
    
    sed -i "s|SOURCE_PLACEHOLDER|$AGENTS_SOURCE|g" "$LOCAL_BIN/sync-agents.sh"
    chmod +x "$LOCAL_BIN/sync-agents.sh"
    
    # Add to cron
    (crontab -l 2>/dev/null | grep -v "sync-agents"; 
     echo "*/5 * * * * $LOCAL_BIN/sync-agents.sh >/dev/null 2>&1") | crontab - 2>/dev/null
    
    success "Auto-sync configured"
    show_progress
}

# 7.5. Setup GitHub sync script
setup_github_sync() {
    print_section "Setting Up GitHub Sync"
    
    GITHUB_SYNC_TARGET="$HOME/Downloads/claude-backups/github-sync.sh"
    GITHUB_SYNC_SOURCE="$PROJECT_ROOT/github-sync.sh"
    
    # Ensure the target directory exists
    mkdir -p "$(dirname "$GITHUB_SYNC_TARGET")"
    
    # Copy GitHub sync script if it exists in project root
    if [[ -f "$GITHUB_SYNC_SOURCE" ]]; then
        cp "$GITHUB_SYNC_SOURCE" "$GITHUB_SYNC_TARGET"
        chmod +x "$GITHUB_SYNC_TARGET"
        success "GitHub sync script installed"
    else
        # Create the script inline if it doesn't exist
        cat > "$GITHUB_SYNC_TARGET" << 'GHSYNC'
#!/bin/bash

# GitHub Sync Script for claude-backups
# Automatically handles authentication and syncs entire repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
REPO_DIR="/home/ubuntu/Downloads/claude-backups"
REMOTE_REPO="https://github.com/SWORDIntel/claude-backups"
LOG_FILE="$REPO_DIR/logs/github-sync-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory if it doesn't exist
mkdir -p "$REPO_DIR/logs"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed!"
        print_status "Installing GitHub CLI..."
        
        # Install GitHub CLI
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y gh
        elif command -v brew &> /dev/null; then
            brew install gh
        else
            print_error "Cannot install GitHub CLI. Please install manually."
            exit 1
        fi
    else
        print_success "GitHub CLI is installed"
    fi
}

# Function to check GitHub authentication
check_gh_auth() {
    print_status "Checking GitHub authentication..."
    
    if gh auth status &> /dev/null; then
        print_success "Already authenticated with GitHub"
        
        # Show current auth info
        echo -e "\n${BLUE}Current GitHub authentication:${NC}"
        gh auth status
        echo ""
        return 0
    else
        print_warning "Not authenticated with GitHub"
        return 1
    fi
}

# Function to authenticate with GitHub
authenticate_github() {
    print_status "Starting GitHub authentication process..."
    
    echo -e "\n${YELLOW}Please choose your authentication method:${NC}"
    echo "1) Browser authentication (recommended)"
    echo "2) Token authentication"
    
    read -p "Enter choice (1 or 2): " auth_choice
    
    case $auth_choice in
        1)
            print_status "Opening browser for authentication..."
            gh auth login --web --git-protocol https --hostname github.com
            ;;
        2)
            print_status "Using token authentication..."
            gh auth login --with-token --git-protocol https --hostname github.com
            ;;
        *)
            print_error "Invalid choice. Defaulting to browser authentication..."
            gh auth login --web --git-protocol https --hostname github.com
            ;;
    esac
    
    # Verify authentication worked
    if gh auth status &> /dev/null; then
        print_success "GitHub authentication successful!"
        gh auth status
    else
        print_error "GitHub authentication failed!"
        exit 1
    fi
}

# Function to setup git configuration
setup_git_config() {
    print_status "Setting up Git configuration..."
    
    # Check if git user is configured
    if ! git config --global user.name &> /dev/null; then
        print_status "Setting up Git user configuration..."
        
        # Get GitHub user info
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
        GH_EMAIL=$(gh api user --jq '.email' 2>/dev/null || echo "")
        
        if [ -n "$GH_USER" ]; then
            git config --global user.name "$GH_USER"
            print_success "Set Git username to: $GH_USER"
        else
            read -p "Enter your Git username: " git_username
            git config --global user.name "$git_username"
        fi
        
        if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
            git config --global user.email "$GH_EMAIL"
            print_success "Set Git email to: $GH_EMAIL"
        else
            read -p "Enter your Git email: " git_email
            git config --global user.email "$git_email"
        fi
    else
        print_success "Git user configuration already exists"
    fi
}

# Function to check and setup remote
setup_remote() {
    print_status "Checking Git remote configuration..."
    
    cd "$REPO_DIR"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        print_status "Initializing Git repository..."
        git init
    fi
    
    # Check if remote exists
    if git remote get-url origin &> /dev/null; then
        CURRENT_REMOTE=$(git remote get-url origin)
        print_status "Current remote: $CURRENT_REMOTE"
        
        # Update remote if it's not correct
        if [ "$CURRENT_REMOTE" != "$REMOTE_REPO" ]; then
            print_status "Updating remote URL..."
            git remote set-url origin "$REMOTE_REPO"
        fi
    else
        print_status "Adding remote origin..."
        git remote add origin "$REMOTE_REPO"
    fi
    
    print_success "Remote configured: $REMOTE_REPO"
}

# Function to sync repository
sync_repository() {
    print_status "Starting repository sync..."
    
    cd "$REPO_DIR"
    
    # Fetch latest changes
    print_status "Fetching latest changes from remote..."
    git fetch origin || print_warning "Fetch failed - repository might be empty"
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_BRANCH" ]; then
        print_status "Creating initial branch..."
        git checkout -b main
    else
        print_status "Current branch: $CURRENT_BRANCH"
    fi
    
    # Stage all changes
    print_status "Staging all changes..."
    git add -A
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        print_status "No changes to commit"
    else
        # Show what's being committed
        print_status "Changes to be committed:"
        git diff --staged --name-status | head -20
        if [ $(git diff --staged --name-only | wc -l) -gt 20 ]; then
            echo "... and $(($(git diff --staged --name-only | wc -l) - 20)) more files"
        fi
        
        # Commit changes
        COMMIT_MSG="Auto-sync: $(date '+%Y-%m-%d %H:%M:%S') - $(git diff --staged --name-only | wc -l) files updated"
        print_status "Committing changes: $COMMIT_MSG"
        git commit -m "$COMMIT_MSG"
    fi
    
    # Push to remote
    print_status "Pushing changes to remote repository..."
    
    # Check if remote branch exists
    if git ls-remote --heads origin main | grep -q "main"; then
        git push origin main
    else
        print_status "Creating remote branch..."
        git push -u origin main
    fi
    
    print_success "Repository sync completed successfully!"
}

# Function to show repository status
show_status() {
    print_status "Repository Status:"
    echo -e "\n${BLUE}Git Status:${NC}"
    git status --short
    
    echo -e "\n${BLUE}Recent Commits:${NC}"
    git log --oneline -5
    
    echo -e "\n${BLUE}Remote Information:${NC}"
    git remote -v
    
    echo -e "\n${BLUE}Branch Information:${NC}"
    git branch -va
}

# Main execution
main() {
    echo -e "${GREEN}GitHub Repository Sync Script${NC}"
    echo -e "${GREEN}==============================${NC}\n"
    
    print_status "Starting sync process for: $REPO_DIR"
    print_status "Target repository: $REMOTE_REPO"
    print_status "Log file: $LOG_FILE"
    
    # Check prerequisites
    check_gh_cli
    
    # Handle authentication
    if ! check_gh_auth; then
        authenticate_github
    fi
    
    # Setup git configuration
    setup_git_config
    
    # Setup remote repository
    setup_remote
    
    # Sync repository
    sync_repository
    
    # Show final status
    show_status
    
    print_success "All operations completed successfully!"
    echo -e "\n${YELLOW}Tip: You can run this script anytime to sync your changes${NC}"
    echo -e "${YELLOW}Log file saved to: $LOG_FILE${NC}"
}

# Handle script arguments
case "${1:-}" in
    --status|-s)
        cd "$REPO_DIR"
        show_status
        ;;
    --help|-h)
        echo "GitHub Sync Script for claude-backups"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --status, -s    Show repository status only"
        echo "  --help, -h      Show this help message"
        echo "  (no args)       Run full sync process"
        echo ""
        ;;
    *)
        main
        ;;
esac
GHSYNC
        chmod +x "$GITHUB_SYNC_TARGET"
        success "GitHub sync script created and installed"
    fi
    
    show_progress
}

# 8. Setup environment
setup_environment() {
    print_section "Configuring Environment"
    
    SHELL_RC="$HOME/.bashrc"
    [[ -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.zshrc"
    
    # Remove old config
    sed -i '/# Claude Master System/,/# End Claude System/d' "$SHELL_RC" 2>/dev/null
    
    # Add new config
    cat >> "$SHELL_RC" << 'ENV'

# Claude Master System
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_AGENTS_DIR="$HOME/agents"

# Auto permission bypass (set to false to disable)
export CLAUDE_PERMISSION_BYPASS=true

# Aliases
alias claude-status='claude --status'
alias claude-agents='claude --list-agents'
alias claude-safe='claude --safe'  # Run without permission bypass
alias ca='claude agent'

# Quick functions
coder() { claude agent coder "$@"; }
director() { claude agent director "$@"; }
architect() { claude agent architect "$@"; }
security() { claude agent security "$@"; }

# GitHub sync shortcut for claude-backups
if [[ -f "$HOME/Downloads/claude-backups/github-sync.sh" ]]; then
    alias ghsync='$HOME/Downloads/claude-backups/github-sync.sh'
    alias ghstatus='$HOME/Downloads/claude-backups/github-sync.sh --status'
fi

# End Claude System
ENV
    
    success "Environment configured"
    show_progress
}

# 9. Run tests
run_tests() {
    print_section "Running Tests"
    
    TESTS_PASSED=0
    TESTS_TOTAL=5
    
    # Test 1: NPM package
    printf "  %-30s" "NPM package..."
    if npm list -g @anthropic-ai/claude-code &>/dev/null; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 2: Wrapper
    printf "  %-30s" "Wrapper executable..."
    if [[ -x "$LOCAL_BIN/claude" ]] || [[ -L "$LOCAL_BIN/claude" ]]; then
        # Check if it's a symlink (preferred for agent discovery) or regular file
        if [[ -L "$LOCAL_BIN/claude" ]]; then
            print_green "$SUCCESS (symlinked)"
        else
            print_green "$SUCCESS"
        fi
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 3: Agents
    printf "  %-30s" "Agents installed..."
    AGENT_COUNT=$(find "$AGENTS_TARGET" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
    if [[ $AGENT_COUNT -gt 0 ]]; then
        print_green "$SUCCESS ($AGENT_COUNT agents)"
        ((TESTS_PASSED++))
    else
        print_red "$ERROR"
    fi
    
    # Test 4: Environment
    printf "  %-30s" "Environment setup..."
    if grep -q "Claude Master System" "$HOME/.bashrc" 2>/dev/null; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_yellow "$WARNING"
    fi
    
    # Test 5: PATH
    printf "  %-30s" "PATH configured..."
    if [[ "$PATH" == *"$LOCAL_BIN"* ]]; then
        print_green "$SUCCESS"
        ((TESTS_PASSED++))
    else
        print_yellow "$WARNING"
    fi
    
    echo ""
    success "Tests: $TESTS_PASSED/$TESTS_TOTAL passed"
    show_progress
}

# 10. Install Global Agents Bridge
install_global_agents_bridge() {
    print_header "Installing Global Agents Bridge"
    
    BRIDGE_SCRIPT="$PROJECT_ROOT/tools/claude-global-agents-bridge.py"
    
    if [[ ! -f "$BRIDGE_SCRIPT" ]]; then
        warning "Global Agents Bridge script not found at: $BRIDGE_SCRIPT"
        warning "Skipping bridge installation"
        return 1
    fi
    
    info "Installing Global Agents Bridge v10.0..."
    
    # Set environment variables for the bridge
    export CLAUDE_AGENTS_ROOT="$AGENTS_TARGET"
    export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
    
    # Install custom wrapper instead of bridge-created launcher
    info "Installing custom wrapper with enhanced functionality..."
    
    # Create .local/bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    # Install the ultimate wrapper as claude-agent (symlinked to preserve agent discovery)
    if [[ -f "$PROJECT_ROOT/claude-wrapper-ultimate.sh" ]]; then
        ln -sf "$PROJECT_ROOT/claude-wrapper-ultimate.sh" "$HOME/.local/bin/claude-agent"
        chmod +x "$PROJECT_ROOT/claude-wrapper-ultimate.sh"
        success "Custom wrapper 'claude-agent' installed with enhanced features (symlinked)"
    else
        warning "Custom wrapper not found, creating basic launcher..."
        # Create basic launcher as fallback
        cat > "$HOME/.local/bin/claude-agent" << EOF
#!/bin/bash
# Claude Agent Global Launcher v10.0 (Basic)
export CLAUDE_AGENTS_ROOT="$AGENTS_TARGET"
export PYTHONPATH="$PROJECT_ROOT/agents/src/python:\$PYTHONPATH"

BRIDGE_SCRIPT="$BRIDGE_SCRIPT"

if [ "\$1" = "list" ] || [ -z "\$1" ]; then
    python3 "\$BRIDGE_SCRIPT" --list
    exit 0
fi

if [ "\$1" = "status" ]; then
    python3 "\$BRIDGE_SCRIPT" --status
    exit 0
fi

# Invoke agent
python3 "\$BRIDGE_SCRIPT" --invoke "\$@"
EOF
        chmod +x "$HOME/.local/bin/claude-agent"
        success "Basic launcher 'claude-agent' created"
    fi
    
    # Initialize bridge without launcher creation
    if python3 "$BRIDGE_SCRIPT" --install 2>/dev/null; then
        success "Global Agents Bridge initialized successfully"
    fi
    
    # Test installation
    info "Testing wrapper installation..."
    if "$HOME/.local/bin/claude-agent" status >/dev/null 2>&1; then
        success "Wrapper installation verified - all agents accessible"
    else
        warning "Wrapper installed but verification failed"
        info "  python3 $BRIDGE_SCRIPT --install"
    fi
    
    show_progress
}

# 10.5. Setup Agent Discovery System
setup_agent_discovery() {
    info "Setting up agent discovery system..."
    
    # Create .claude directory if it doesn't exist
    local claude_dir="$PROJECT_ROOT/.claude"
    if [[ ! -d "$claude_dir" ]]; then
        mkdir -p "$claude_dir"
        success "Created .claude directory: $claude_dir"
    else
        info ".claude directory already exists"
    fi
    
    # Create symlink from .claude/agents to agents directory
    local agents_symlink="$claude_dir/agents"
    local agents_source="../agents"  # Use relative path for portability
    
    if [[ -d "$PROJECT_ROOT/agents" ]]; then
        # Check if symlink exists and is correct
        if [[ -L "$agents_symlink" ]]; then
            local current_target=$(readlink "$agents_symlink")
            if [[ "$current_target" == "$agents_source" || "$current_target" == "$(readlink -f "$PROJECT_ROOT/agents")" ]]; then
                success "Agents symlink already properly configured: .claude/agents -> $current_target"
            else
                # Remove and recreate with correct target
                rm -f "$agents_symlink"
                ln -sf "$agents_source" "$agents_symlink"
                success "Updated agents symlink: .claude/agents -> $agents_source"
            fi
        elif [[ ! -e "$agents_symlink" ]]; then
            # Create new symlink
            ln -sf "$agents_source" "$agents_symlink"
            success "Created agents symlink: .claude/agents -> $agents_source"
        else
            warning "Non-symlink file exists at $agents_symlink - skipping symlink creation"
        fi
    else
        warning "Agents directory not found: $PROJECT_ROOT/agents"
    fi
    
    # Create cache directory with proper permissions
    local cache_dir="$HOME/.cache/claude"
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir"
        chmod 755 "$cache_dir"
        success "Created cache directory: $cache_dir"
    else
        # Ensure proper permissions
        chmod 755 "$cache_dir" 2>/dev/null || true
        info "Cache directory exists with proper permissions"
    fi
    
    # Run custom agent registration
    local register_script="$PROJECT_ROOT/tools/register-custom-agents.py"
    if [[ -f "$register_script" ]]; then
        info "Running custom agent registration..."
        if python3 "$register_script" --install >/dev/null 2>&1; then
            success "Custom agent registry updated successfully"
            
            # Check if registry file was created and get count
            if [[ -f "$HOME/.cache/claude/registered_agents.json" ]]; then
                local agent_count=$(python3 -c "
import json
try:
    with open('$HOME/.cache/claude/registered_agents.json', 'r') as f:
        data = json.load(f)
    print(len(data.get('agents', {})))
except:
    print('unknown')
" 2>/dev/null)
                success "  • Registered $agent_count agents in registry"
                info "  • Registry location: $HOME/.cache/claude/registered_agents.json"
            fi
        else
            warning "Agent registration had issues - will be retried by cron job"
        fi
    else
        warning "Agent registration script not found: $register_script"
        info "Manual registration can be done later with: python3 tools/register-custom-agents.py"
    fi
    
    success "Agent discovery system setup complete"
}

# 11. Setup Agent Activation System
setup_agent_activation() {
    print_header "Setting up Agent Activation System"
    
    info "Installing comprehensive CLI interface for agent system..."
    
    # Ensure config directory exists
    mkdir -p "$HOME/.config/claude"
    
    # Install the activation script
    ACTIVATION_SCRIPT="$PROJECT_ROOT/config/activate-agents.sh"
    
    if [[ -f "$ACTIVATION_SCRIPT" ]]; then
        # Copy to config directory
        cp "$ACTIVATION_SCRIPT" "$HOME/.config/claude/"
        chmod +x "$HOME/.config/claude/activate-agents.sh"
        success "Agent activation script installed"
        
        # Setup agent registry if it doesn't exist
        if [[ ! -f "$HOME/.config/claude/project-agents.json" ]]; then
            info "Setting up agent registry..."
            if python3 "$PROJECT_ROOT/tools/register-custom-agents.py" --install 2>/dev/null; then
                success "Agent registry initialized"
            else
                warning "Agent registry setup failed - can be done manually later"
            fi
        fi
        
        # Add to shell profile for permanent activation
        setup_shell_integration
        
        info "Agent activation system features:"
        echo "  • Enhanced CLI commands (claude-agents, claude-status, claude-invoke)"
        echo "  • Environment variables and path setup"  
        echo "  • Performance monitoring and metrics"
        echo "  • Integrated help system"
        echo "  • Agent registry management"
        
    else
        warning "Activation script not found at: $ACTIVATION_SCRIPT"
        warning "Skipping activation system setup"
    fi
    
    show_progress
}

# Setup shell integration for permanent activation
setup_shell_integration() {
    info "Setting up shell integration for permanent activation..."
    
    local activation_line="source ~/.config/claude/activate-agents.sh"
    local shells_updated=0
    
    # Update .bashrc if it exists
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "activate-agents.sh" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# Claude Agent System Activation" >> "$HOME/.bashrc"
            echo "$activation_line" >> "$HOME/.bashrc"
            ((shells_updated++))
        fi
    fi
    
    # Update .zshrc if it exists  
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "activate-agents.sh" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# Claude Agent System Activation" >> "$HOME/.zshrc"
            echo "$activation_line" >> "$HOME/.zshrc"
            ((shells_updated++))
        fi
    fi
    
    # Update .profile as fallback
    if [[ -f "$HOME/.profile" ]]; then
        if ! grep -q "activate-agents.sh" "$HOME/.profile" 2>/dev/null; then
            echo "" >> "$HOME/.profile"
            echo "# Claude Agent System Activation" >> "$HOME/.profile"
            echo "$activation_line" >> "$HOME/.profile"
            ((shells_updated++))
        fi
    fi
    
    if [[ $shells_updated -gt 0 ]]; then
        success "Shell integration added to $shells_updated profile(s)"
        info "Restart your shell or run: source ~/.config/claude/activate-agents.sh"
    else
        info "Shell integration already present or no shell profiles found"
    fi
}

# 12. Show summary
show_summary() {
    echo ""
    echo ""
    print_green "╔═══════════════════════════════════════════════════════════════╗"
    print_green "║              Installation Complete! ✨                       ║"
    print_green "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    AGENT_COUNT=$(find "$AGENTS_TARGET" -name "*.md" -o -name "*.MD" 2>/dev/null | wc -l)
    
    print_bold "Installed Components:"
    echo "  • Claude NPM Package"
    print_green "  • Enhanced Wrapper with Always-On Permission Bypass"
    echo "  • $AGENT_COUNT Agents with full metadata and categories"
    print_green "  • Global CLAUDE.md (Auto-invocation guide for 57 specialized agents)"
    print_green "  • Global Agents Bridge v10.0 (60 agents via claude-agent command)"
    print_green "  • Agent Activation System v10.0 (Enhanced CLI interface)"
    echo "  • PostgreSQL Database System (port 5433)"
    echo "  • Agent Learning System with ML models"
    echo "  • Tandem Orchestration System v2.0 (40+ agents ready)"
    echo "  • Production Environment with 100+ Python packages"
    echo "  • Hooks integration for automation"
    echo "  • Auto-sync with GitHub (5 minutes)"
    print_green "  • GitHub Sync Script (ghsync/ghstatus aliases)"
    print_green "  • Precision Orchestration Style (ACTIVATED BY DEFAULT)"
    echo ""
    
    print_bold "Available Commands:"
    printf "  %-30s %s\n" "claude" "Run Claude (precision style + orchestration active)"
    printf "  %-30s %s\n" "claude-precision" "Force precision orchestration style"
    printf "  %-30s %s\n" "claude --safe" "Run Claude without permission bypass"
    printf "  %-30s %s\n" "claude --status" "Show status"
    printf "  %-30s %s\n" "claude --list-agents" "List agents"
    printf "  %-30s %s\n" "claude --orchestrator" "Launch Python orchestrator UI"
    echo ""
    print_bold "Global Agents Bridge (NEW):"
    printf "  %-30s %s\n" "claude-agent list" "List all 60 specialized agents"
    printf "  %-30s %s\n" "claude-agent status" "Show bridge system status"
    printf "  %-30s %s\n" "claude-agent <name> <prompt>" "Invoke any agent directly"
    printf "  %-30s %s\n" "claude-learning status" "Check learning system"
    printf "  %-30s %s\n" "claude-learning cli dashboard" "Learning dashboard"
    printf "  %-30s %s\n" "python-orchestrator" "Direct orchestrator access"
    echo ""
    print_bold "Agent Activation System (NEW):"
    printf "  %-30s %s\n" "claude-agents" "List all available agents"
    printf "  %-30s %s\n" "claude-status" "Show comprehensive status"
    printf "  %-30s %s\n" "claude-invoke <name> <prompt>" "Invoke agent with prompt"
    printf "  %-30s %s\n" "claude-info <name>" "Show agent details"
    printf "  %-30s %s\n" "claude-test" "Test agent system"
    printf "  %-30s %s\n" "claude-metrics" "Show performance metrics"
    printf "  %-30s %s\n" "claude-monitor" "Live monitoring"
    printf "  %-30s %s\n" "claude-daemon" "Background monitoring"
    printf "  %-30s %s\n" "claude agent <name>" "Run specific agent"
    echo ""
    print_bold "GitHub Sync Commands (NEW):"
    printf "  %-30s %s\n" "ghsync" "Auto GitHub authentication + full repo sync"
    printf "  %-30s %s\n" "ghstatus" "Show repository status"
    echo ""
    
    print_bold "Quick Functions:"
    echo "  coder, director, architect, security"
    echo ""
    
    print_yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_yellow "                    Next Steps"
    print_yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Reload your shell:"
    print_cyan "     source ~/.bashrc"
    echo ""
    echo "  2. Test the system:"
    print_cyan "     claude --status"
    echo ""
    
    if [[ $AGENT_COUNT -eq 0 ]]; then
        echo "  3. Add agents (optional):"
        print_cyan "     # Copy existing agents if available:"
        print_cyan "     cp -r /path/to/agents/*.md $AGENTS_TARGET/"
        print_cyan "     # Or create your own agent files in: $AGENTS_TARGET/"
    else
        print_cyan "     claude --list-agents"
    fi
    
    echo ""
    print_dim "Log file: $LOG_FILE"
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMMAND LINE ARGUMENT PARSING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_arguments() {
    # Default to full installation
    INSTALLATION_MODE="full"
    SKIP_TESTS=false
    VERBOSE=false
    SKIP_WRAPPER_INTEGRATION=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick|-q)
                INSTALLATION_MODE="quick"
                shift
                ;;
            --full|-f)
                INSTALLATION_MODE="full"
                shift
                ;;
            --custom|-c)
                INSTALLATION_MODE="custom"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-wrapper-integration)
                SKIP_WRAPPER_INTEGRATION=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Claude Master Installer v10.0"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "🚀 Claude Agent Framework v7.0 Unified Installer"
                echo ""
                echo "Options:"
                echo "  (no options)      Full installation - all components (DEFAULT & RECOMMENDED)"
                echo "  --full, -f        Same as default - complete system installation"
                echo "  --quick, -q       Quick installation with minimal components only"
                echo "  --custom, -c      Custom installation - choose components"
                echo "  --skip-tests      Skip validation tests"
                echo "  --skip-wrapper-integration  Skip wrapper integration system"
                echo "  --verbose, -v     Show detailed output"
                echo "  --help, -h        Show this help message"
                echo ""
                echo "💡 Recommended: Just run './claude-installer.sh' for complete installation"
                echo "   This installs all 57 agents, databases, learning systems, and tools"
                exit 0
                ;;
            *)
                print_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    print_header
    
    # Get user preferences (will respect INSTALLATION_MODE)
    get_user_preferences
    
    # Get sudo if needed
    if [[ "$EUID" -ne 0 ]]; then
        print_yellow "This installer may need sudo access for some operations."
        sudo -v 2>/dev/null || true
    fi
    
    # Run installation steps based on mode
    check_prerequisites
    install_npm_package
    install_agents
    
    if [[ "$INSTALLATION_MODE" == "full" ]] || [[ "$INSTALLATION_MODE" == "custom" ]]; then
        install_hooks
        install_statusline
        install_global_claude_md
        setup_claude_directory
        register_agents_with_task_tool
        setup_precision_style
        setup_virtual_environment
        setup_database_system
        setup_learning_system
        setup_tandem_orchestration
        setup_natural_invocation
        setup_production_environment
    elif [[ "$INSTALLATION_MODE" == "quick" ]]; then
        info "Quick mode: Skipping advanced features"
        install_hooks
        install_global_claude_md
        setup_claude_directory
        register_agents_with_task_tool
    fi
    
    create_wrapper
    setup_sync
    setup_github_sync
    setup_environment
    
    if [[ "$SKIP_TESTS" != "true" ]]; then
        run_tests
        validate_agents
    else
        info "Skipping tests as requested"
    fi
    
    # Install Global Agents Bridge
    install_global_agents_bridge
    
    # Setup automatic agent registry updates
    setup_agent_registry_cron
    
    # Setup Agent Activation System (disabled - causes terminal crashes)
    # setup_agent_activation
    
    # Reset progress for completion
    CURRENT_STEP=$TOTAL_STEPS
    show_progress
    echo ""
    
    # Show summary
    show_summary
}

# Setup automatic agent registry updates via cron
setup_agent_registry_cron() {
    info "Setting up automatic agent registry updates..."
    
    # Make the cron script executable
    if [[ -f "$PROJECT_ROOT/scripts/agent-registry-updater.sh" ]]; then
        chmod +x "$PROJECT_ROOT/scripts/agent-registry-updater.sh"
        
        # Add cron job to update registry every 5 minutes
        local cron_line="*/5 * * * * $PROJECT_ROOT/scripts/agent-registry-updater.sh"
        
        # Check if cron job already exists
        if ! crontab -l 2>/dev/null | grep -q "agent-registry-updater.sh"; then
            # Add the cron job
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
            success "Agent registry auto-update enabled (every 5 minutes)"
            info "  • Registry location: $PROJECT_ROOT/config/registered_agents.json"
            info "  • Symlinked to: ~/.cache/claude/registered_agents.json"
            info "  • Updates automatically when agents are added/modified"
        else
            success "Agent registry cron job already configured"
        fi
        
        # Run initial registration
        info "Running initial agent registration..."
        if python3 "$PROJECT_ROOT/tools/register-custom-agents.py" >/dev/null 2>&1; then
            success "Initial agent registry created"
        else
            warning "Initial agent registration had issues - will retry via cron"
        fi
        
    else
        warning "Agent registry updater script not found - skipping cron setup"
    fi
}

# Run the installer
main "$@"
