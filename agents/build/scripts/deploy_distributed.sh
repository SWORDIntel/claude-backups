#!/bin/bash

# DISTRIBUTED CLAUDE AGENT COMMUNICATION SYSTEM DEPLOYMENT SCRIPT
# 
# Automated deployment and configuration for production-grade
# distributed agent communication with high-performance networking
# 
# Features:
# - Multi-node cluster setup
# - TLS certificate generation and distribution
# - Performance tuning (NUMA, CPU affinity, huge pages)
# - Service monitoring and health checks
# - Automated failover testing
# 
# Author: Agent Communication System
# Version: 1.0 Distributed

set -euo pipefail

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="distributed-claude-agents"
VERSION="1.0.0"

# Default configuration
DEFAULT_CLUSTER_SIZE=5
DEFAULT_NODE_ID=1
DEFAULT_BIND_ADDRESS="127.0.0.1"
DEFAULT_BASE_PORT=8800
DEFAULT_INSTALL_DIR="/opt/distributed-agents"
DEFAULT_DATA_DIR="/var/lib/distributed-agents"
DEFAULT_LOG_DIR="/var/log/distributed-agents"
DEFAULT_CONFIG_DIR="/etc/distributed-agents"
DEFAULT_CERT_DIR="/etc/distributed-agents/certs"

# Performance tuning defaults
DEFAULT_HUGE_PAGES=1024
DEFAULT_NETWORK_THREADS=16
DEFAULT_WORKER_THREADS=32

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║     DISTRIBUTED CLAUDE AGENT COMMUNICATION SYSTEM DEPLOYMENT    ║"
    echo "║                                                                  ║"
    echo "║  High-Performance Distributed Networking & Consensus            ║"
    echo "║  Target: 4.2M+ messages/sec with p99 latency < 250μs           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This script can run as non-root for local deployment."
    fi
}

check_dependencies() {
    local deps=("gcc" "make" "openssl" "numactl" "perf")
    local missing_deps=()
    
    log "Checking system dependencies..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies:"
        
        if command -v apt-get >/dev/null 2>&1; then
            echo "  sudo apt-get install gcc make libssl-dev libnuma-dev linux-tools-generic"
        elif command -v yum >/dev/null 2>&1; then
            echo "  sudo yum install gcc make openssl-devel numactl-devel perf"
        elif command -v dnf >/dev/null 2>&1; then
            echo "  sudo dnf install gcc make openssl-devel numactl-devel perf"
        fi
        
        return 1
    fi
    
    log_success "All dependencies are installed"
    return 0
}

detect_system_info() {
    log "Detecting system information..."
    
    ARCH=$(uname -m)
    KERNEL_VERSION=$(uname -r)
    CPU_COUNT=$(nproc)
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    NUMA_NODES=$(numactl --hardware | grep "available:" | awk '{print $2}' || echo "1")
    
    log_info "Architecture: $ARCH"
    log_info "Kernel: $KERNEL_VERSION"
    log_info "CPU Cores: $CPU_COUNT"
    log_info "Memory: ${MEMORY_GB}GB"
    log_info "NUMA Nodes: $NUMA_NODES"
    
    # Check if Intel hardware features are available
    if grep -q "avx512f" /proc/cpuinfo; then
        log_info "AVX-512 support: Available"
        HAVE_AVX512=true
    else
        log_warning "AVX-512 support: Not available"
        HAVE_AVX512=false
    fi
    
    if grep -q "sse4_2" /proc/cpuinfo; then
        log_info "SSE4.2/CRC32C support: Available"
        HAVE_CRC32C=true
    else
        log_warning "SSE4.2/CRC32C support: Not available"
        HAVE_CRC32C=false
    fi
}

# ============================================================================
# PERFORMANCE TUNING FUNCTIONS
# ============================================================================

setup_huge_pages() {
    local huge_pages=${1:-$DEFAULT_HUGE_PAGES}
    
    log "Setting up huge pages (${huge_pages} pages)..."
    
    if [[ $EUID -eq 0 ]]; then
        # Configure 2MB huge pages
        echo "$huge_pages" > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
        
        # Make it persistent
        if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
            echo "vm.nr_hugepages = $huge_pages" >> /etc/sysctl.conf
        fi
        
        # Check if huge pages were allocated
        local allocated=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
        if [[ $allocated -eq $huge_pages ]]; then
            log_success "Huge pages configured: $allocated pages"
        else
            log_warning "Only $allocated huge pages allocated out of $huge_pages requested"
        fi
    else
        log_warning "Cannot configure huge pages without root privileges"
    fi
}

optimize_network_settings() {
    log "Optimizing network settings..."
    
    if [[ $EUID -eq 0 ]]; then
        # Network buffer optimizations
        sysctl -w net.core.rmem_max=134217728
        sysctl -w net.core.wmem_max=134217728
        sysctl -w net.core.rmem_default=65536
        sysctl -w net.core.wmem_default=65536
        sysctl -w net.ipv4.tcp_rmem="4096 65536 134217728"
        sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
        
        # Connection handling optimizations
        sysctl -w net.core.somaxconn=65535
        sysctl -w net.core.netdev_max_backlog=30000
        sysctl -w net.ipv4.tcp_max_syn_backlog=65535
        
        # TCP optimizations for high throughput
        sysctl -w net.ipv4.tcp_congestion_control=bbr
        sysctl -w net.ipv4.tcp_slow_start_after_idle=0
        sysctl -w net.ipv4.tcp_fastopen=3
        
        log_success "Network settings optimized"
    else
        log_warning "Cannot optimize network settings without root privileges"
    fi
}

tune_cpu_performance() {
    log "Tuning CPU performance settings..."
    
    if [[ $EUID -eq 0 ]]; then
        # Set CPU governor to performance
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [[ -f $cpu ]]; then
                echo "performance" > "$cpu" 2>/dev/null || true
            fi
        done
        
        # Disable CPU power saving features for maximum performance
        if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
            echo "0" > /sys/devices/system/cpu/intel_pstate/no_turbo
        fi
        
        log_success "CPU performance settings optimized"
    else
        log_warning "Cannot tune CPU settings without root privileges"
    fi
}

# ============================================================================
# TLS CERTIFICATE MANAGEMENT
# ============================================================================

generate_ca_certificate() {
    local cert_dir="$1"
    local ca_key="$cert_dir/ca.key"
    local ca_cert="$cert_dir/ca.crt"
    
    log "Generating CA certificate..."
    
    mkdir -p "$cert_dir"
    
    # Generate CA private key
    openssl genpkey -algorithm RSA -out "$ca_key" -pkcs8 -aes256 \
        -pass pass:distributed-agents-ca 2>/dev/null
    
    # Generate CA certificate
    openssl req -new -x509 -key "$ca_key" -out "$ca_cert" -days 3650 \
        -passin pass:distributed-agents-ca \
        -subj "/C=US/ST=CA/L=San Francisco/O=Claude Agents/OU=Distributed System/CN=Claude Agents CA" \
        2>/dev/null
    
    chmod 600 "$ca_key"
    chmod 644 "$ca_cert"
    
    log_success "CA certificate generated: $ca_cert"
}

generate_node_certificate() {
    local cert_dir="$1"
    local node_id="$2"
    local node_ip="$3"
    
    local node_key="$cert_dir/node-${node_id}.key"
    local node_csr="$cert_dir/node-${node_id}.csr"
    local node_cert="$cert_dir/node-${node_id}.crt"
    local ca_key="$cert_dir/ca.key"
    local ca_cert="$cert_dir/ca.crt"
    
    log "Generating certificate for node $node_id ($node_ip)..."
    
    # Generate node private key
    openssl genpkey -algorithm RSA -out "$node_key" -pkcs8 2>/dev/null
    
    # Create certificate signing request
    openssl req -new -key "$node_key" -out "$node_csr" \
        -subj "/C=US/ST=CA/L=San Francisco/O=Claude Agents/OU=Distributed System/CN=$node_id" \
        2>/dev/null
    
    # Create certificate extensions file
    cat > "$cert_dir/node-${node_id}.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = node-${node_id}
DNS.2 = node-${node_id}.cluster.local
DNS.3 = localhost
IP.1 = ${node_ip}
IP.2 = 127.0.0.1
EOF

    # Generate node certificate
    openssl x509 -req -in "$node_csr" -CA "$ca_cert" -CAkey "$ca_key" \
        -CAcreateserial -out "$node_cert" -days 365 \
        -extensions v3_req -extfile "$cert_dir/node-${node_id}.ext" \
        -passin pass:distributed-agents-ca 2>/dev/null
    
    # Clean up temporary files
    rm -f "$node_csr" "$cert_dir/node-${node_id}.ext"
    
    chmod 600 "$node_key"
    chmod 644 "$node_cert"
    
    log_success "Node certificate generated: $node_cert"
}

setup_certificates() {
    local cert_dir="$1"
    local cluster_size="$2"
    local base_ip="$3"
    
    log "Setting up TLS certificates for $cluster_size nodes..."
    
    mkdir -p "$cert_dir"
    
    # Generate CA certificate if it doesn't exist
    if [[ ! -f "$cert_dir/ca.crt" ]]; then
        generate_ca_certificate "$cert_dir"
    fi
    
    # Generate node certificates
    for ((node_id=1; node_id<=cluster_size; node_id++)); do
        local node_ip="${base_ip%.*}.$node_id"
        if [[ ! -f "$cert_dir/node-${node_id}.crt" ]]; then
            generate_node_certificate "$cert_dir" "$node_id" "$node_ip"
        fi
    done
    
    log_success "All certificates generated in $cert_dir"
}

# ============================================================================
# BUILD AND INSTALLATION
# ============================================================================

build_system() {
    log "Building distributed agent communication system..."
    
    cd "$SCRIPT_DIR"
    
    # Clean previous build
    make -f Makefile.distributed clean
    
    # Set build flags based on detected capabilities
    local make_flags=""
    if [[ $HAVE_AVX512 == true ]]; then
        make_flags+=" USE_AVX512=1"
    fi
    
    # Build with profile-guided optimization if requested
    if [[ "${USE_PGO:-false}" == "true" ]]; then
        log "Building with Profile-Guided Optimization..."
        make -f Makefile.distributed pgo -j"$CPU_COUNT" $make_flags
    else
        make -f Makefile.distributed all -j"$CPU_COUNT" $make_flags
    fi
    
    log_success "Build completed successfully"
}

install_system() {
    local install_dir="$1"
    local config_dir="$2"
    local data_dir="$3"
    local log_dir="$4"
    
    log "Installing system to $install_dir..."
    
    # Create directories
    mkdir -p "$install_dir/bin"
    mkdir -p "$install_dir/lib"
    mkdir -p "$config_dir"
    mkdir -p "$data_dir"
    mkdir -p "$log_dir"
    
    # Install binaries
    cp distributed_agent_system "$install_dir/bin/"
    cp distributed_network_demo "$install_dir/bin/"
    cp libdistributed_agents.* "$install_dir/lib/" 2>/dev/null || true
    
    # Install configuration
    cp distributed_config.json "$config_dir/cluster_config.json"
    
    # Set permissions
    chmod +x "$install_dir/bin/"*
    
    if [[ $EUID -eq 0 ]]; then
        chown -R root:root "$install_dir"
        chmod -R 755 "$install_dir"
        
        # Create system user for the service
        if ! id distributed-agents >/dev/null 2>&1; then
            useradd -r -s /bin/false -d "$data_dir" distributed-agents
        fi
        
        chown -R distributed-agents:distributed-agents "$data_dir" "$log_dir"
    fi
    
    log_success "System installed to $install_dir"
}

create_systemd_service() {
    local install_dir="$1"
    local config_dir="$2"
    local node_id="$3"
    
    if [[ $EUID -ne 0 ]]; then
        log_warning "Cannot create systemd service without root privileges"
        return 0
    fi
    
    log "Creating systemd service for node $node_id..."
    
    local service_name="distributed-agents-node-${node_id}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    cat > "$service_file" <<EOF
[Unit]
Description=Distributed Claude Agent Communication System (Node $node_id)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=distributed-agents
Group=distributed-agents
ExecStart=$install_dir/bin/distributed_agent_system --node-id $node_id --config $config_dir/cluster_config.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=distributed-agents-node-$node_id

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$config_dir /var/lib/distributed-agents /var/log/distributed-agents

# Resource limits
LimitNOFILE=65536
LimitNPROC=32768
LimitMEMLOCK=infinity

# Performance settings
OOMScoreAdjust=-100
CPUSchedulingPolicy=2
CPUSchedulingPriority=50

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service_name"
    
    log_success "Systemd service created: $service_name"
}

# ============================================================================
# TESTING AND VALIDATION
# ============================================================================

run_system_tests() {
    local install_dir="$1"
    local config_dir="$2"
    
    log "Running system tests..."
    
    cd "$SCRIPT_DIR"
    
    # Build test executables
    make -f Makefile.distributed test -j"$CPU_COUNT"
    
    # Run unit tests
    for test_exe in test_*; do
        if [[ -x "$test_exe" ]]; then
            log "Running $test_exe..."
            if ./"$test_exe"; then
                log_success "$test_exe passed"
            else
                log_error "$test_exe failed"
                return 1
            fi
        fi
    done
    
    log_success "All system tests passed"
}

run_performance_benchmark() {
    local install_dir="$1"
    local threads="$2"
    
    log "Running performance benchmark with $threads threads..."
    
    cd "$SCRIPT_DIR"
    
    if [[ -x "performance_benchmark" ]]; then
        ./performance_benchmark --threads "$threads" --duration 30 --target-throughput 4200000
        
        log_success "Performance benchmark completed"
    else
        log_warning "Performance benchmark executable not found"
    fi
}

# ============================================================================
# CLUSTER MANAGEMENT
# ============================================================================

start_cluster_node() {
    local node_id="$1"
    local install_dir="$2"
    local config_dir="$3"
    local bind_address="$4"
    local bind_port="$5"
    
    log "Starting cluster node $node_id..."
    
    local cert_file="$config_dir/certs/node-${node_id}.crt"
    local key_file="$config_dir/certs/node-${node_id}.key"
    
    if [[ $EUID -eq 0 ]] && systemctl list-unit-files | grep -q "distributed-agents-node-${node_id}.service"; then
        # Use systemd service
        systemctl start "distributed-agents-node-${node_id}"
        log_success "Node $node_id started via systemd"
    else
        # Start directly
        "$install_dir/bin/distributed_network_demo" \
            --node-id "$node_id" \
            --bind-address "$bind_address" \
            --port "$bind_port" \
            --config "$config_dir/cluster_config.json" \
            --cert "$cert_file" \
            --key "$key_file" \
            --tls \
            --scenario 1 &
        
        local pid=$!
        echo "$pid" > "/tmp/distributed-agents-node-${node_id}.pid"
        
        log_success "Node $node_id started (PID: $pid)"
    fi
}

stop_cluster_node() {
    local node_id="$1"
    
    log "Stopping cluster node $node_id..."
    
    if [[ $EUID -eq 0 ]] && systemctl list-unit-files | grep -q "distributed-agents-node-${node_id}.service"; then
        # Use systemd service
        systemctl stop "distributed-agents-node-${node_id}"
        log_success "Node $node_id stopped via systemd"
    else
        # Stop directly
        local pid_file="/tmp/distributed-agents-node-${node_id}.pid"
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -TERM "$pid" 2>/dev/null; then
                sleep 2
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null
                fi
            fi
            rm -f "$pid_file"
        fi
        
        log_success "Node $node_id stopped"
    fi
}

deploy_cluster() {
    local cluster_size="$1"
    local base_address="$2"
    local base_port="$3"
    local install_dir="$4"
    local config_dir="$5"
    
    log "Deploying cluster with $cluster_size nodes..."
    
    # Start all nodes
    for ((node_id=1; node_id<=cluster_size; node_id++)); do
        local node_ip="${base_address%.*}.$node_id"
        local node_port=$((base_port + node_id))
        
        start_cluster_node "$node_id" "$install_dir" "$config_dir" "$node_ip" "$node_port"
        
        # Wait between node starts to allow proper cluster formation
        sleep 2
    done
    
    # Wait for cluster stabilization
    log "Waiting for cluster to stabilize..."
    sleep 10
    
    log_success "Cluster deployed with $cluster_size nodes"
}

# ============================================================================
# MONITORING AND HEALTH CHECKS
# ============================================================================

check_cluster_health() {
    local cluster_size="$1"
    local base_port="$2"
    
    log "Checking cluster health..."
    
    local healthy_nodes=0
    
    for ((node_id=1; node_id<=cluster_size; node_id++)); do
        local node_port=$((base_port + node_id))
        
        # Simple TCP port check
        if nc -z 127.0.0.1 "$node_port" 2>/dev/null; then
            log_success "Node $node_id is responding on port $node_port"
            ((healthy_nodes++))
        else
            log_warning "Node $node_id is not responding on port $node_port"
        fi
    done
    
    log_info "Healthy nodes: $healthy_nodes/$cluster_size"
    
    if [[ $healthy_nodes -ge $((cluster_size / 2 + 1)) ]]; then
        log_success "Cluster has quorum"
        return 0
    else
        log_error "Cluster does not have quorum"
        return 1
    fi
}

monitor_performance() {
    local duration="$1"
    
    log "Monitoring performance for $duration seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Monitor system resources
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        local network_rx=$(cat /proc/net/dev | grep -E "(eth|ens|enp)" | head -1 | awk '{print $2}')
        
        log_info "CPU: ${cpu_usage}%, Memory: ${mem_usage}%, Network RX: $network_rx bytes"
        
        sleep 5
    done
    
    log_success "Performance monitoring completed"
}

# ============================================================================
# MAIN DEPLOYMENT FUNCTIONS
# ============================================================================

usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Distributed Claude Agent Communication System Deployment Script"
    echo ""
    echo "Commands:"
    echo "  build                     Build the system"
    echo "  install                   Install the system"
    echo "  setup                     Setup system (performance tuning, certificates)"
    echo "  deploy                    Deploy full cluster"
    echo "  start [NODE_ID]          Start cluster node(s)"
    echo "  stop [NODE_ID]           Stop cluster node(s)"
    echo "  status                    Check cluster status"
    echo "  test                      Run system tests"
    echo "  benchmark                 Run performance benchmark"
    echo "  clean                     Clean up deployment"
    echo ""
    echo "Options:"
    echo "  -n, --cluster-size SIZE   Number of nodes in cluster (default: $DEFAULT_CLUSTER_SIZE)"
    echo "  -i, --install-dir DIR     Installation directory (default: $DEFAULT_INSTALL_DIR)"
    echo "  -c, --config-dir DIR      Configuration directory (default: $DEFAULT_CONFIG_DIR)"
    echo "  -d, --data-dir DIR        Data directory (default: $DEFAULT_DATA_DIR)"
    echo "  -l, --log-dir DIR         Log directory (default: $DEFAULT_LOG_DIR)"
    echo "  -a, --address ADDR        Base bind address (default: $DEFAULT_BIND_ADDRESS)"
    echo "  -p, --port PORT           Base port number (default: $DEFAULT_BASE_PORT)"
    echo "  --enable-tls              Enable TLS encryption"
    echo "  --enable-pgo              Build with Profile-Guided Optimization"
    echo "  --huge-pages N            Number of huge pages to allocate"
    echo "  --threads N               Number of worker threads"
    echo "  -v, --verbose             Verbose output"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build                                    # Build the system"
    echo "  $0 setup --enable-tls --huge-pages 2048    # Setup with TLS and huge pages"
    echo "  $0 deploy --cluster-size 5 --enable-tls    # Deploy 5-node cluster with TLS"
    echo "  $0 start 1                                  # Start node 1"
    echo "  $0 benchmark --threads 32                   # Run performance benchmark"
}

parse_args() {
    # Set defaults
    CLUSTER_SIZE=$DEFAULT_CLUSTER_SIZE
    INSTALL_DIR=$DEFAULT_INSTALL_DIR
    CONFIG_DIR=$DEFAULT_CONFIG_DIR
    DATA_DIR=$DEFAULT_DATA_DIR
    LOG_DIR=$DEFAULT_LOG_DIR
    BIND_ADDRESS=$DEFAULT_BIND_ADDRESS
    BASE_PORT=$DEFAULT_BASE_PORT
    ENABLE_TLS=false
    ENABLE_PGO=false
    HUGE_PAGES=$DEFAULT_HUGE_PAGES
    WORKER_THREADS=$DEFAULT_WORKER_THREADS
    VERBOSE=false
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--cluster-size)
                CLUSTER_SIZE="$2"
                shift 2
                ;;
            -i|--install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -c|--config-dir)
                CONFIG_DIR="$2"
                shift 2
                ;;
            -d|--data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            -l|--log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            -a|--address)
                BIND_ADDRESS="$2"
                shift 2
                ;;
            -p|--port)
                BASE_PORT="$2"
                shift 2
                ;;
            --enable-tls)
                ENABLE_TLS=true
                shift
                ;;
            --enable-pgo)
                ENABLE_PGO=true
                shift
                ;;
            --huge-pages)
                HUGE_PAGES="$2"
                shift 2
                ;;
            --threads)
                WORKER_THREADS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            build|install|setup|deploy|start|stop|status|test|benchmark|clean)
                COMMAND="$1"
                if [[ "$1" == "start" || "$1" == "stop" ]] && [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    NODE_ID="$2"
                    shift
                fi
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        log_error "No command specified"
        usage
        exit 1
    fi
    
    # Set environment variables for build
    if [[ $ENABLE_PGO == true ]]; then
        export USE_PGO=true
    fi
}

main() {
    parse_args "$@"
    
    print_banner
    check_root
    
    # Set verbose mode
    if [[ $VERBOSE == true ]]; then
        set -x
    fi
    
    # Detect system information
    detect_system_info
    
    case "$COMMAND" in
        build)
            log "Building distributed agent system..."
            check_dependencies || exit 1
            build_system
            ;;
            
        install)
            log "Installing distributed agent system..."
            build_system
            install_system "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
            ;;
            
        setup)
            log "Setting up system environment..."
            check_dependencies || exit 1
            setup_huge_pages "$HUGE_PAGES"
            optimize_network_settings
            tune_cpu_performance
            
            if [[ $ENABLE_TLS == true ]]; then
                setup_certificates "$CONFIG_DIR/certs" "$CLUSTER_SIZE" "$BIND_ADDRESS"
            fi
            ;;
            
        deploy)
            log "Deploying distributed cluster..."
            check_dependencies || exit 1
            build_system
            install_system "$INSTALL_DIR" "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
            setup_huge_pages "$HUGE_PAGES"
            optimize_network_settings
            tune_cpu_performance
            
            if [[ $ENABLE_TLS == true ]]; then
                setup_certificates "$CONFIG_DIR/certs" "$CLUSTER_SIZE" "$BIND_ADDRESS"
            fi
            
            deploy_cluster "$CLUSTER_SIZE" "$BIND_ADDRESS" "$BASE_PORT" "$INSTALL_DIR" "$CONFIG_DIR"
            ;;
            
        start)
            if [[ -n "${NODE_ID:-}" ]]; then
                log "Starting node $NODE_ID..."
                local node_ip="${BIND_ADDRESS%.*}.$NODE_ID"
                local node_port=$((BASE_PORT + NODE_ID))
                start_cluster_node "$NODE_ID" "$INSTALL_DIR" "$CONFIG_DIR" "$node_ip" "$node_port"
            else
                log "Starting all cluster nodes..."
                deploy_cluster "$CLUSTER_SIZE" "$BIND_ADDRESS" "$BASE_PORT" "$INSTALL_DIR" "$CONFIG_DIR"
            fi
            ;;
            
        stop)
            if [[ -n "${NODE_ID:-}" ]]; then
                log "Stopping node $NODE_ID..."
                stop_cluster_node "$NODE_ID"
            else
                log "Stopping all cluster nodes..."
                for ((node_id=1; node_id<=CLUSTER_SIZE; node_id++)); do
                    stop_cluster_node "$node_id"
                done
            fi
            ;;
            
        status)
            log "Checking cluster status..."
            check_cluster_health "$CLUSTER_SIZE" "$BASE_PORT"
            ;;
            
        test)
            log "Running system tests..."
            check_dependencies || exit 1
            build_system
            run_system_tests "$INSTALL_DIR" "$CONFIG_DIR"
            ;;
            
        benchmark)
            log "Running performance benchmark..."
            check_dependencies || exit 1
            build_system
            run_performance_benchmark "$INSTALL_DIR" "$WORKER_THREADS"
            ;;
            
        clean)
            log "Cleaning up deployment..."
            
            # Stop all nodes
            for ((node_id=1; node_id<=CLUSTER_SIZE; node_id++)); do
                stop_cluster_node "$node_id" 2>/dev/null || true
            done
            
            # Clean build artifacts
            cd "$SCRIPT_DIR"
            make -f Makefile.distributed clean 2>/dev/null || true
            
            # Remove temporary files
            rm -f /tmp/distributed-agents-node-*.pid
            
            log_success "Cleanup completed"
            ;;
            
        *)
            log_error "Unknown command: $COMMAND"
            usage
            exit 1
            ;;
    esac
    
    log_success "Command '$COMMAND' completed successfully"
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Trap signals for cleanup
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"